#!/usr/bin/env python3
"""Saved caller for one Firebase window.

Computes control_seen and window_profile_done from the records it is given.
Stores both flags, the sha256 of each record, and this file's path and version.
A data host returns not_silent even when a flag is false.

This caller does not compute a UID. The pcaps it reads have no per-UID field.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import socket
import struct
import subprocess
import tempfile

import firebase_silence as fs

VERSION = "1"
CALLER_PATH = "scripts/firebase_verdict.py"
GATES_NOT_RUN = ("G2", "G4a", "G5", "G6", "G7", "G8", "G9")


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _qname(buf, start):
    labels = []
    pos = start
    hops = 0
    while pos < len(buf) and hops < 20:
        hops += 1
        length = buf[pos]
        if length == 0:
            return ".".join(labels), pos + 1
        if length & 0xC0:
            return ".".join(labels), pos + 2
        pos += 1
        labels.append(buf[pos:pos + length].decode("ascii", "replace"))
        pos += length
    return ".".join(labels), pos


def _dns_names(payload):
    names = []
    if len(payload) < 12:
        return names
    questions = struct.unpack_from(">H", payload, 4)[0]
    pos = 12
    for _ in range(min(questions, 8)):
        name, pos = _qname(payload, pos)
        if name:
            names.append(name.lower())
        if pos + 4 > len(payload):
            break
        pos += 4
    return names


def _sni(payload):
    if len(payload) < 6 or payload[0] != 0x16:
        return []
    rec_len = struct.unpack_from(">H", payload, 3)[0]
    body = payload[5:5 + rec_len]
    if len(body) < 4 or body[0] != 0x01:
        return []
    pos = 4 + 2 + 32
    if pos >= len(body):
        return []
    pos += 1 + body[pos]
    if pos + 2 > len(body):
        return []
    cs_len = struct.unpack_from(">H", body, pos)[0]
    pos += 2 + cs_len
    if pos >= len(body):
        return []
    pos += 1 + body[pos]
    if pos + 2 > len(body):
        return []
    ext_len = struct.unpack_from(">H", body, pos)[0]
    pos += 2
    end = min(len(body), pos + ext_len)
    found = []
    while pos + 4 <= end:
        etype, elen = struct.unpack_from(">HH", body, pos)
        pos += 4
        chunk = body[pos:pos + elen]
        pos += elen
        if etype == 0 and len(chunk) >= 5:
            name_len = struct.unpack_from(">H", chunk, 3)[0]
            name = chunk[5:5 + name_len].decode("ascii", "replace").lower()
            if name:
                found.append(name)
    return found


def pcap_facts(path):
    """Host and ICMP facts from a classic pcap. No UID field is read."""
    data = open(path, "rb").read()
    if len(data) < 24:
        raise ValueError(f"{path} is too small to be a pcap")
    magic, _maj, _min, _tz, _sig, snaplen, linktype = struct.unpack_from("<IHHIIII", data, 0)
    if magic != 0xA1B2C3D4:
        raise ValueError(f"{path} is not a little-endian classic pcap")
    requests = {}
    replies = {}
    dns = set()
    sni = set()
    ipv4 = set()
    off = 24
    while off + 16 <= len(data):
        _ts, _us, incl, _orig = struct.unpack_from("<IIII", data, off)
        off += 16
        pkt = data[off:off + incl]
        off += incl
        if linktype != 1 or len(pkt) < 14:
            continue
        eth_type = struct.unpack_from(">H", pkt, 12)[0]
        ipoff = 14
        if eth_type == 0x8100 and len(pkt) >= 18:
            eth_type = struct.unpack_from(">H", pkt, 16)[0]
            ipoff = 18
        if eth_type != 0x0800 or len(pkt) < ipoff + 20:
            continue
        ip = pkt[ipoff:]
        ihl = (ip[0] & 0x0F) * 4
        if ip[0] >> 4 != 4 or len(ip) < ihl:
            continue
        src = socket.inet_ntoa(ip[12:16])
        dst = socket.inet_ntoa(ip[16:20])
        ipv4.add(src)
        ipv4.add(dst)
        l4 = ip[ihl:]
        proto = ip[9]
        if proto == 1 and l4:
            key = (src, dst)
            if l4[0] == 8:
                requests[key] = requests.get(key, 0) + 1
            elif l4[0] == 0:
                replies[key] = replies.get(key, 0) + 1
        elif proto == 17 and len(l4) >= 8:
            sport, dport = struct.unpack_from(">HH", l4, 0)
            if sport == 53 or dport == 53:
                dns.update(_dns_names(l4[8:]))
        elif proto == 6 and len(l4) >= 20:
            doff = (l4[12] >> 4) * 4
            sni.update(_sni(l4[doff:]))
    echo_requests = [
        {"src": src, "dst": dst, "count": count}
        for (src, dst), count in sorted(requests.items())
    ]
    echo_replies = [
        {"src": src, "dst": dst, "count": count}
        for (src, dst), count in sorted(replies.items())
    ]
    return {
        "linktype": linktype,
        "snaplen": snaplen,
        "echo_requests": echo_requests,
        "echo_replies": echo_replies,
        "control_hosts": sorted({row["dst"] for row in echo_requests}),
        "dns": sorted(dns),
        "sni": sorted(sni),
        "ipv4": sorted(ipv4),
    }


def window_profile_done_from(path):
    """Return (flag, status). Status is absent, no_field, or field.

    A reason string is not a flag. Only a JSON boolean window_profile_done
    counts.
    """
    if not path or not os.path.isfile(path):
        return False, "absent"
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.loads(handle.read())
    except (OSError, json.JSONDecodeError):
        return False, "no_field"
    if isinstance(data, dict) and data.get("window_profile_done") is True:
        return True, "field"
    return False, "no_field"


def mitm_hosts(path):
    """Host names from a mitmproxy dump. Bodies are not printed."""
    addon = (
        "SEEN=set()\n"
        "def _emit(flow):\n"
        "    host=getattr(flow.request,'pretty_host',None)\n"
        "    if host and host not in SEEN:\n"
        "        SEEN.add(host)\n"
        "        print(host)\n"
        "def request(flow):\n"
        "    _emit(flow)\n"
        "def response(flow):\n"
        "    _emit(flow)\n"
        "def error(flow):\n"
        "    _emit(flow)\n"
    )
    handle = tempfile.NamedTemporaryFile("w", suffix=".py", delete=False)
    try:
        handle.write(addon)
        handle.close()
        proc = subprocess.run(
            ["mitmdump", "-n", "-q", "-r", path, "-s", handle.name],
            check=True,
            capture_output=True,
            text=True,
        )
    finally:
        os.unlink(handle.name)
    return sorted({line.strip().lower() for line in proc.stdout.splitlines() if line.strip()})


def assemble(records, pcap_hosts, mitm_hosts, control_seen, window_profile_done,
             uid_available, step_log, control_hosts=None, pcap_name="pcap",
             mitm_name=None):
    """Build the verdict dict. Does not read a verdict file or a UID."""
    evaluated = fs.evaluate_silence(
        pcap_hosts, mitm_hosts, control_seen, window_profile_done)
    failing = []
    reasons = []
    if not control_seen:
        failing.append("G1")
        if mitm_name:
            reasons.append(
                f"No control host in {pcap_name} or {mitm_name}. control_seen is false.")
        else:
            reasons.append(f"No control host in {pcap_name}. control_seen is false.")
    elif control_hosts:
        shown = ", ".join(control_hosts)
        reasons.append(f"control_seen is true. Control host: {shown}.")
    if not uid_available:
        failing.append("G3")
        reasons.append(
            "G3 fails: these records have no per-UID capture. "
            "uid_available is false. A negative needs G1 through G10.")
    if not window_profile_done:
        failing.append("G4")
        if step_log == "absent":
            reasons.append("The step log is absent. window_profile_done is false.")
        elif step_log == "no_field":
            reasons.append(
                "The step log has no window_profile_done field. "
                "The flag is false. It was not read from reason text.")
        else:
            reasons.append("window_profile_done is false.")
    if evaluated["verdict"] == "not_silent":
        verdict = "not_silent"
        reasons.insert(0, evaluated["reasons"][0])
    else:
        # shortcut: no negative from this caller, G2 and G4a-G9 are not computed, upgrade when those gates are wired
        verdict = "untested"
    body = {
        "verdict": verdict,
        "reasons": reasons,
        "hits": evaluated["hits"],
        "telemetry_present": evaluated["telemetry_present"],
        "control_seen": bool(control_seen),
        "window_profile_done": bool(window_profile_done),
        "uid_available": bool(uid_available),
        "failing_gates": failing,
        "gates_not_run": list(GATES_NOT_RUN),
        "data_needles": list(fs.FIREBASE_NEEDLES),
        "pcap_hosts": sorted({h.lower() for h in pcap_hosts}),
        "mitm_hosts": sorted({h.lower() for h in mitm_hosts}),
        "records": records,
        "caller_path": CALLER_PATH,
        "caller_version": VERSION,
        "flags_from_reason_text": False,
    }
    if control_hosts is not None:
        body["control_hosts"] = sorted(control_hosts)
    return body


def _record(path, kind):
    return {"name": os.path.basename(path), "sha256": sha256_file(path), "kind": kind}


def derive(pcap_path, mitm_path=None, step_log_path=None):
    facts = pcap_facts(pcap_path)
    names = sorted(set(facts["dns"]) | set(facts["sni"]))
    proxy_hosts = mitm_hosts(mitm_path) if mitm_path else []
    control_seen = bool(facts["control_hosts"])
    window_done, step_status = window_profile_done_from(step_log_path)
    records = [_record(pcap_path, "pcap")]
    if mitm_path:
        records.append(_record(mitm_path, "mitm"))
    if step_log_path and os.path.isfile(step_log_path):
        records.append(_record(step_log_path, "step_log"))
    # uid_available stays false. This pcap format has no per-UID table.
    body = assemble(
        records=records,
        pcap_hosts=names,
        mitm_hosts=proxy_hosts,
        control_seen=control_seen,
        window_profile_done=window_done,
        uid_available=False,
        step_log=step_status,
        control_hosts=facts["control_hosts"],
        pcap_name=os.path.basename(pcap_path),
        mitm_name=os.path.basename(mitm_path) if mitm_path else None,
    )
    local = [ip for ip in ("10.0.2.16", "10.0.2.20") if ip in facts["ipv4"]]
    body["pcap"] = {
        "linktype": facts["linktype"],
        "snaplen": facts["snaplen"],
        "echo_requests": facts["echo_requests"],
        "echo_replies": facts["echo_replies"],
        "local_addresses_present": local,
    }
    return body


def write_verdict(body, out_path):
    text = json.dumps(body, indent=2, sort_keys=True) + "\n"
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(text)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Re-derive a Firebase window verdict")
    parser.add_argument("--pcap", required=True)
    parser.add_argument("--mitm")
    parser.add_argument("--step-log")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    body = derive(args.pcap, args.mitm, args.step_log)
    write_verdict(body, args.out)
    print(body["verdict"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
