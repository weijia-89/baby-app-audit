#!/usr/bin/env bash
# Deterministic tests for scripts/firebase_silence.py.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$repo_root" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "scripts"))
import firebase_silence as fs

N = fs.FIREBASE_NEEDLES

# Control traffic is mandatory before any negative claim.
r = fs.evaluate_silence(pcap_hosts=set(), mitm_hosts=set(),
                        control_seen=False, window_profile_done=True)
assert r["verdict"] == "inconclusive" and "control" in r["reasons"][0], r

# A data hit is not_silent when control_seen is false. Flags are literals,
# the same way this file passes them. The hit list must not come back empty.
r = fs.evaluate_silence({"example.firebaseio.com"}, set(), False, True)
assert r["verdict"] == "not_silent", r
assert "example.firebaseio.com" in r["hits"], r

# A data hit is not_silent when window_profile_done is false.
r = fs.evaluate_silence(set(), {"example.firebasedatabase.googleapis.com"}, True, False)
assert r["verdict"] == "not_silent", r
assert "example.firebasedatabase.googleapis.com" in r["hits"], r

# The data-host list is named here. RTDB, Firestore, and Storage.
assert fs.FIREBASE_NEEDLES == (
    "firebaseio.com",
    "firebasedatabase.googleapis.com",
    "firestore.googleapis.com",
    "firebasestorage.googleapis.com",
), fs.FIREBASE_NEEDLES

# Firestore and Storage are data hosts, including when both flags are false.
r = fs.evaluate_silence({"x.firestore.googleapis.com"}, set(), False, False)
assert r["verdict"] == "not_silent" and "x.firestore.googleapis.com" in r["hits"], r
r = fs.evaluate_silence(set(), {"b.firebasestorage.googleapis.com"}, False, False)
assert r["verdict"] == "not_silent" and "b.firebasestorage.googleapis.com" in r["hits"], r

# Window requirement comes after control.
r = fs.evaluate_silence(set(), set(), True, False)
assert r["verdict"] == "inconclusive" and "window" in r["reasons"][0], r

# A hit in EITHER record inside a finished-profile window = not_silent.
r = fs.evaluate_silence({"firebaseio.com"}, set(), True, True)
assert r["verdict"] == "not_silent" and "firebaseio.com" in r["hits"], r
r = fs.evaluate_silence(set(), {"xx.firebasedatabase.googleapis.com"}, True, True)
assert r["verdict"] == "not_silent", r
# Needle matching is substring + case-insensitive on hosts.
r = fs.evaluate_silence({"FirebaseIO.COM"}, set(), True, True)
assert r["verdict"] == "not_silent", r

# Data-endpoint silence with telemetry flow must say so explicitly.
r = fs.evaluate_silence(
    {"firebaselogging-pa.googleapis.com", "app-measurement.com"},
    set(), True, True)
assert r["verdict"] == "silent_in_window", r
assert r["telemetry_present"] is True, r
assert any("telemetry" in reason.lower() for reason in r["reasons"]), r

# Non-Firebase noise never triggers.
r = fs.evaluate_silence({"googleads.g.doubleclick.net", "connectivitycheck.gstatic.com"},
                        {"play.googleapis.com"}, True, True)
assert r["verdict"] == "silent_in_window" and r["hits"] == [], r

import hashlib, socket, struct, tempfile
import firebase_verdict as fv

def _icmp_pcap(pairs):
    def frame(src, dst, typ):
        icmp = bytes([typ, 0, 0, 0, 0, 1, 0, 1])
        ip_len = 20 + len(icmp)
        ip = struct.pack(
            ">BBHHHBBH4s4s", 0x45, 0, ip_len, 0, 0, 64, 1, 0,
            socket.inet_aton(src), socket.inet_aton(dst))
        eth = b"\x00" * 12 + struct.pack(">H", 0x0800)
        return eth + ip + icmp
    blob = struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 262144, 1)
    for src, dst in pairs:
        for typ, a, b in ((8, src, dst), (0, dst, src)):
            pkt = frame(a, b, typ)
            blob += struct.pack("<IIII", 0, 0, len(pkt), len(pkt)) + pkt
    return blob

tmpdir = tempfile.mkdtemp()
pcap_path = os.path.join(tmpdir, "ctrl.pcap")
with open(pcap_path, "wb") as fh:
    fh.write(_icmp_pcap([("10.0.2.16", "8.8.8.8")]))
facts = fv.pcap_facts(pcap_path)
assert facts["snaplen"] == 262144 and facts["linktype"] == 1, facts
assert facts["control_hosts"] == ["8.8.8.8"], facts
assert facts["echo_requests"] == [{"src": "10.0.2.16", "dst": "8.8.8.8", "count": 1}], facts

# A sibling verdict file is not a flag source. This pcap has no echo.
empty_path = os.path.join(tmpdir, "empty.pcap")
with open(empty_path, "wb") as fh:
    fh.write(struct.pack("<IHHIIII", 0xA1B2C3D4, 2, 4, 0, 0, 262144, 1))
with open(os.path.join(tmpdir, "silence-verdict.json"), "w", encoding="utf-8") as fh:
    fh.write('{"reasons":["control traffic seen, finished-profile window"]}')
assert fv.pcap_facts(empty_path)["control_hosts"] == []

assert fv.window_profile_done_from(None) == (False, "absent")
reason_log = os.path.join(tmpdir, "steps.json")
with open(reason_log, "w", encoding="utf-8") as fh:
    fh.write('{"reasons":["finished-profile window"]}')
assert fv.window_profile_done_from(reason_log) == (False, "no_field")
done_log = os.path.join(tmpdir, "done.json")
with open(done_log, "w", encoding="utf-8") as fh:
    fh.write('{"window_profile_done": true}')
assert fv.window_profile_done_from(done_log) == (True, "field")

rec_hash = hashlib.sha256(open(pcap_path, "rb").read()).hexdigest()
body = fv.assemble(
    records=[{"name": "ctrl.pcap", "sha256": rec_hash, "kind": "pcap"}],
    pcap_hosts=["app-measurement.com"],
    mitm_hosts=[],
    control_seen=True,
    window_profile_done=False,
    uid_available=False,
    step_log="absent",
)
assert body["verdict"] == "untested", body
assert body["control_seen"] is True and body["window_profile_done"] is False
assert body["uid_available"] is False and "uid" not in body
assert "G3" in body["failing_gates"] and "G4" in body["failing_gates"]
assert body["records"][0]["sha256"] == rec_hash
assert body["caller_version"] == fv.VERSION
assert body["caller_path"] == "scripts/firebase_verdict.py"
assert any("step log is absent" in r for r in body["reasons"]), body
assert any("G3" in r for r in body["reasons"]), body

hit = fv.assemble(
    records=[{"name": "x.pcap", "sha256": "ab", "kind": "pcap"}],
    pcap_hosts=[],
    mitm_hosts=["proj.firestore.googleapis.com"],
    control_seen=False,
    window_profile_done=False,
    uid_available=False,
    step_log="absent",
)
assert hit["verdict"] == "not_silent", hit
assert "proj.firestore.googleapis.com" in hit["hits"], hit

out = fv.derive(pcap_path, mitm_path=None, step_log_path=None)
assert out["control_seen"] is True and out["control_hosts"] == ["8.8.8.8"], out
assert out["verdict"] == "untested" and out["uid_available"] is False, out
assert out["records"][0]["sha256"] == rec_hash

out2 = fv.derive(empty_path, mitm_path=None, step_log_path=None)
assert out2["control_seen"] is False and out2["verdict"] == "untested", out2
assert "G1" in out2["failing_gates"], out2
assert any("empty.pcap" in r and "control" in r for r in out2["reasons"]), out2

print("firebase-silence tests passed")
PY
echo "test-firebase-silence passed"
