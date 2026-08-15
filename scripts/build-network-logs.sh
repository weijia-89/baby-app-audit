#!/usr/bin/env bash
set -euo pipefail

# Build a sanitized per-app network log straight from the raw mitmproxy capture.
#
# Usage: scripts/build-network-logs.sh <slug> <capture.mitm> [capture_date]
#
# The output results/network-log-<slug>.json keeps every flow from the raw
# capture with query strings removed, path segments that look like tokens
# replaced by [REDACTED], and request/response details reduced to sizes,
# JSON body keys, and header presence flags. Raw values (FIDs, refresh
# tokens, api keys, install IDs) never reach the output.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
slug="${1:?usage: build-network-logs.sh <slug> <capture.mitm> [capture_date]}"
mitm="${2:?missing capture.mitm path}"
date="${3:-$(date +%F)}"
har="$(mktemp /tmp/netlog-XXXXXX.har)"

trap 'rm -f "$har"' EXIT

mitmdump -q -s "$repo_root/scripts/har_dump.py" --set "har_output=$har" -nr "$mitm" >/dev/null

python3 - "$repo_root" "$slug" "$mitm" "$date" "$har" <<'PY'
import json
import os
import re
import sys

repo_root, slug, mitm, capture_date, har = sys.argv[1:6]

TOKEN = re.compile(r"[A-Za-z0-9_\-\.]{20,}")

app_packages = {
    "babycenter": "com.babycenter.pregnancytracker",
    "nanit": "com.nanit.baby",
    "whattoexpect": "com.wte.view",
    "pregnancyplus": "com.hp.pregnancy.lite",
    "bellybloom": "com.bellyBloom.pregnancy.tracker",
    "nurture-lock": "com.angry.shark.studio.nurturelock",
    "nubo": "com.clicksie.nuboapp",
    "pebbi": "com.pebbi.android",
    "amila": "com.amila.parenting",
    "nara": "com.naraorganics.nara",
    "heartful-baby": "com.heartfulsprout.baby",
    "pixy": "com.pixykid.app",
}
package = app_packages.get(slug)
if package is None:
    meta = json.load(open(os.path.join(repo_root, "results/product-metadata.json")))
    for key, value in meta.get("products", {}).items():
        if slug in key.lower() or str(value.get("slug", "")).lower() == slug.lower():
            package = key
            break

HEADERS_OF_NOTE = {"x-android-package", "x-android-cert", "x-goog-api-key",
                   "x-firebase-client", "authorization", "x-apikey"}


def redact_path(url):
    if "?" in url:
        url = url.split("?", 1)[0]
    parts = []
    for seg in url.split("/"):
        if len(seg) >= 20 and (seg.isalnum() or "-" in seg or "_" in seg or "." in seg):
            seg = "[REDACTED]"
        parts.append(seg)
    return "/".join(parts)


def body_keys(text):
    if not text:
        return None
    try:
        obj = json.loads(text)
    except (ValueError, TypeError):
        return None
    if isinstance(obj, dict):
        return sorted(obj.keys())
    if isinstance(obj, list) and obj and isinstance(obj[0], dict):
        return ["[list of " + str(len(obj)) + "]"]
    return ["[non-object]"]


def flow_key(method, path, status):
    return (method, path, status)


har = json.load(open(har))
flows_by_key = {}
order = []
for entry in har["log"]["entries"]:
    req, res = entry["request"], entry.get("response", {})
    status = res.get("status")
    if status is None:
        continue
    url = req.get("url", "")
    path = redact_path(TOKEN.sub("[REDACTED]", url))
    method = req.get("method", "GET")
    key = flow_key(method, path, status)
    if key in flows_by_key:
        flows_by_key[key]["count"] += 1
        continue
    headers = {}
    for h in req.get("headers", []):
        name = h.get("name", "").lower()
        if name in HEADERS_OF_NOTE:
            headers["x-android-package" if name == "x-android-package" else name] = h.get("value", "")
    if headers.get("x-android-package") == package:
        origin = "app"
    elif any(name != "x-android-package" for name in headers):
        origin = "device"
    else:
        origin = "session"
    rq_body = req.get("postData", {}).get("text", "")
    rs_body = res.get("content", {}).get("text", "")
    flow = {
        "method": method,
        "host": req.get("host", url.split("/")[2] if "://" in url else ""),
        "path": path,
        "status": status,
        "origin": origin,
        "count": 1,
        "request": {
            "size": req.get("bodySize", 0),
            "content_type": next((h.get("value") for h in req.get("headers", [])
                                  if h.get("name", "").lower() == "content-type"), None),
            "body_keys": body_keys(rq_body),
            "headers": sorted(headers.keys()),
        },
        "response": {
            "size": res.get("content", {}).get("size", 0),
            "content_type": res.get("content", {}).get("mimeType"),
            "body_keys": body_keys(rs_body),
        },
    }
    flows_by_key[key] = flow
    order.append(key)

flows = [flows_by_key[k] for k in order]
total = sum(f["count"] for f in flows)
out = {
    "$schema": "network-log/1.0",
    "schema_version": "1.0",
    "app": slug,
    "package_name": package,
    "capture_date": capture_date,
    "capture": mitm,
    "redaction": "Query strings removed; token-like path segments replaced by [REDACTED]; body values, headers, and cookies never included; body JSON keys only.",
    "flows": flows,
    "summary": {
        "total_flows": total,
        "unique_destinations": sorted({f["host"] for f in flows}),
    },
}
open(os.path.join(repo_root, "results", f"network-log-{slug}.json"), "w").write(
    json.dumps(out, indent=2) + "\n"
)
print(f"{slug}: {total} flows, {len(flows)} unique rows, {len(out['summary']['unique_destinations'])} destinations")
PY