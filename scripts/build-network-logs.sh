#!/usr/bin/env bash
set -euo pipefail

# Build a sanitized per-app network log straight from the raw mitmproxy capture.
#
# Usage: scripts/build-network-logs.sh <slug> <capture.mitm> [capture_date]
#
# The output results/network-log-<slug>.json keeps every flow from the raw
# capture with query strings removed, token-like path segments replaced by
# descriptive redaction slugs, and request/response details reduced to sizes,
# JSON body keys, and header presence flags. Raw values (FIDs, refresh tokens,
# API keys, install IDs) never reach the output. Call metadata remains.

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
from urllib.parse import urlparse

# A path segment is treated as a token/ID (and redacted) when it is 12+ chars
# of alphanumerics/dots/dashes and not a pure word. This catches Firebase IDs,
# install IDs, and hex tokens while leaving normal SEO words and version
# strings mostly intact. The threshold is deliberately low: over-redaction of a
# path segment is safe, under-redaction of a real token would leak PII.
TOKEN_RE = re.compile(r'^[A-Za-z0-9._\-]{12,}$')

repo_root, slug, mitm, capture_date, har = sys.argv[1:6]

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
    query_removed = "?" in url
    if query_removed:
        url = url.split("?", 1)[0]
    segs = url.split("/")
    path_redactions = 0
    # segs[0] is "scheme:", segs[2] is the host. Only redact path segments
    # (index > 2) so the host is never mangled inside the path string.
    for i in range(3, len(segs)):
        seg = segs[i]
        if TOKEN_RE.match(seg) and not seg.isalpha():
            segs[i] = "[REDACTED:path-token-or-id]"
            path_redactions += 1
    return "/".join(segs), query_removed, path_redactions


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
    path, query_removed, path_redactions = redact_path(url)
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
    # Origin is decided solely by the X-Android-Package header, the only
    # reliable caller identity in the capture. A request carrying the app's own
    # package is "app"; one carrying a different package is "device"; one with
    # no package header at all is "session". The previous check mislabeled an
    # app request that also carried an Authorization header as "device".
    if "x-android-package" in headers and headers["x-android-package"] == package:
        origin = "app"
    elif "x-android-package" in headers:
        origin = "device"
    else:
        origin = "session"
    rq_body = req.get("postData", {}).get("text", "")
    rs_body = res.get("content", {}).get("text", "")
    redactions = []
    if query_removed:
        redactions.append("[REDACTED:query-string:privacy]")
    if path_redactions:
        redactions.append("[REDACTED:path-token-or-id:secret-or-PII]")
    if rq_body or req.get("bodySize", 0) > 0:
        redactions.append("[REDACTED:request-body-values:secret-or-PII]")
    if req.get("headers"):
        redactions.append("[REDACTED:request-header-values:secret-or-PII]")
    if rs_body or res.get("content", {}).get("size", 0) > 0:
        redactions.append("[REDACTED:response-body-values:secret-or-PII]")
    if res.get("headers"):
        redactions.append("[REDACTED:response-header-values:secret-or-PII]")
    flow = {
        "method": method,
        "host": urlparse(url).hostname or req.get("host") or "",
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
        "redactions": sorted(set(redactions)),
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
    "redaction": {
        "policy": "Sensitive values never appear. Call metadata remains so the sent call can be assessed.",
        "slugs": {
            "query": "[REDACTED:query-string:privacy]",
            "path": "[REDACTED:path-token-or-id:secret-or-PII]",
            "request_body": "[REDACTED:request-body-values:secret-or-PII]",
            "request_headers": "[REDACTED:request-header-values:secret-or-PII]",
            "response_body": "[REDACTED:response-body-values:secret-or-PII]",
            "response_headers": "[REDACTED:response-header-values:secret-or-PII]",
        },
        "body_keys": "Names only. Values are scrubbed.",
    },
    "flows": flows,
    "summary": {
        "total_flows": total,
        "unique_destinations": sorted({f["host"] for f in flows}),
    },
}
output_path = os.environ.get("NETWORK_LOG_OUTPUT", os.path.join(repo_root, "results", f"network-log-{slug}.json"))
output_dir = os.path.dirname(output_path) or "."
os.makedirs(output_dir, exist_ok=True)
open(output_path, "w").write(
    json.dumps(out, indent=2) + "\n"
)
print(f"{slug}: {total} flows, {len(flows)} unique rows, {len(out['summary']['unique_destinations'])} destinations -> {output_path}")
PY
