#!/usr/bin/env bash
set -euo pipefail

# Build a redacted network log from a raw .mitm capture.
#
# Usage: scripts/build-network-logs.sh <slug> <capture.mitm> [capture_date]
#
# Output: results/network-log-<slug>.json
# Keep every flow, including one with no response. Keep query names.
# Replace token-like path parts and query values.
# Keep sizes, JSON keys, and header flags. Do not keep secrets.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
slug="${1:?usage: build-network-logs.sh <slug> <capture.mitm> [capture_date]}"
mitm="${2:?missing capture.mitm path}"
date="${3:-$(date +%F)}"
har="$(mktemp /tmp/netlog-XXXXXX.har)"

trap 'rm -f "$har" "${har}.sidecar.json"' EXIT

mitmdump -q -s "$repo_root/scripts/har_dump.py" --set "har_output=$har" -nr "$mitm" >/dev/null

python3 - "$repo_root" "$slug" "$mitm" "$date" "$har" <<'PY'
import json
import os
import re
import sys
from urllib.parse import parse_qsl, unquote, urlparse

# Redact a path part if it looks like an ID (12+ chars, not a plain word).
# Prefer over-redact. Under-redact can leak secrets.
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
    "baby-plus": "com.hp.babyapp",
    "mimilog": "com.mimiapp.mimilog",
    "baby-daybook": "com.drillyapps.babydaybook",
    "amila": "com.amila.parenting",
    "nara": "com.naraorganics.nara",
    "heartful-baby": "com.heartfulsprout.baby",
    "pixy": "com.pixykid.app",
    "baby-buddy": "org.babybuddy.babybuddy",
}
package = app_packages.get(slug)
if package is None:
    try:
        meta = json.load(open(os.path.join(repo_root, "results/product-metadata.json")))
    except (json.JSONDecodeError, OSError):
        meta = {}
    for key, value in meta.get("products", {}).items():
        if slug in key.lower() or str(value.get("slug", "")).lower() == slug.lower():
            package = key
            break
if package is None:
    print(
        f"ERROR: no package known for slug {slug!r}",
        file=sys.stderr,
    )
    sys.exit(1)

HEADERS_OF_NOTE = {"x-android-package", "x-android-cert", "x-goog-api-key",
                   "x-firebase-client", "authorization", "x-apikey"}


def segment_has_token(seg):
    """True when the segment, or a piece of it, looks like an id.

    Percent-encoding can hide '$' and ':' inside one path segment.
    Decode first. Then test the whole segment and each id-shaped piece.
    A plain word (letters only) stays.
    """
    decoded = unquote(seg)
    pieces = [decoded, *re.split(r"[^A-Za-z0-9._\-]+", decoded)]
    for piece in pieces:
        if piece and TOKEN_RE.match(piece) and not piece.isalpha():
            return True
    return False


def redact_path(url):
    """Return path, whether a query was removed, redaction count, and names.

    The path has no query string. Names are kept. Values are not returned.
    """
    query_removed = "?" in url
    base = url
    raw_query = ""
    if query_removed:
        base, raw_query = url.split("?", 1)
        raw_query = raw_query.split("#", 1)[0]
    query_names = []
    if raw_query:
        query_names = [
            name for name, _value in parse_qsl(raw_query, keep_blank_values=True)
        ]
    segs = base.split("/")
    path_redactions = 0
    # Redact path segments only (keep scheme and host).
    for i in range(3, len(segs)):
        if segment_has_token(segs[i]):
            segs[i] = "[REDACTED:path-token-or-id]"
            path_redactions += 1
    return "/".join(segs), query_removed, path_redactions, query_names


def describe_body(text):
    """Body fields for one side of a call.

    No text means an empty body: body_keys null, unscannable false.
    A failed json.loads used to return null too. That now sets
    body_decoder and unscannable, and omits body_keys.
    """
    if not text:
        return {"body_keys": None, "body_decoder": None, "unscannable": False}
    try:
        obj = json.loads(text)
    except (ValueError, TypeError):
        return {"body_decoder": "unknown", "unscannable": True}
    if isinstance(obj, dict):
        keys = sorted(obj.keys())
    elif isinstance(obj, list) and obj and isinstance(obj[0], dict):
        keys = ["[list of " + str(len(obj)) + "]"]
    else:
        keys = ["[non-object]"]
    return {"body_keys": keys, "body_decoder": "json", "unscannable": False}


def flow_key(method, host, path, status, origin, package_header, query_names):
    return (method, host, path, status, origin, package_header, tuple(query_names))


def portable_capture(path):
    marker = "/results/"
    index = path.find(marker)
    if index == -1:
        return path
    return path[index + 1:]


har_path = har
try:
    har = json.load(open(har_path))
except (json.JSONDecodeError, OSError) as exc:
    print(f"ERROR: failed to read HAR from {har_path}: {exc}", file=sys.stderr)
    sys.exit(1)
if not isinstance(har, dict) or "log" not in har or "entries" not in har.get("log", {}):
    print(f"ERROR: HAR {har_path} has no log.entries", file=sys.stderr)
    sys.exit(1)
sidecar_path = har_path + ".sidecar.json"
sidecar = {"response_less": [], "non_http": [], "tls_unread": []}
if os.path.exists(sidecar_path):
    try:
        loaded = json.load(open(sidecar_path))
    except (json.JSONDecodeError, OSError) as exc:
        print(f"ERROR: failed to read sidecar {sidecar_path}: {exc}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(loaded, dict):
        print(f"ERROR: sidecar {sidecar_path} is not an object", file=sys.stderr)
        sys.exit(1)
    sidecar = loaded
entries = list(har["log"]["entries"])
for item in sidecar.get("response_less") or []:
    if isinstance(item, dict) and isinstance(item.get("request"), dict):
        entries.append(item)
flows_by_key = {}
order = []
for entry in entries:
    if not isinstance(entry, dict) or not isinstance(entry.get("request"), dict):
        continue
    req = entry["request"]
    res = entry.get("response") if isinstance(entry.get("response"), dict) else {}
    status = res.get("status") if entry.get("response") else None
    outcome = "no_response" if status is None else None
    url = req.get("url", "")
    path, query_removed, path_redactions, query_names = redact_path(url)
    method = req.get("method", "GET")
    host = urlparse(url).hostname or req.get("host") or ""
    headers = {}
    for h in req.get("headers", []):
        name = h.get("name", "").lower()
        if name in HEADERS_OF_NOTE:
            headers[name] = h.get("value", "")
    # Origin is decided solely by the X-Android-Package header, the only
    # reliable caller identity in the capture. A request carrying the app's own
    # package is "app"; one carrying a different package is "device"; one with
    # no package header at all is "session". The previous check mislabeled an
    # app request that also carried an Authorization header as "device".
    package_header = headers.get("x-android-package") or None
    if package_header == package:
        origin = "app"
    elif package_header:
        origin = "device"
    else:
        origin = "session"
    key = flow_key(method, host, path, status, origin, package_header, query_names)
    if key in flows_by_key:
        flows_by_key[key]["count"] += 1
        continue
    rq_body = (req.get("postData") or {}).get("text", "")
    rs_body = (res.get("content") or {}).get("text", "")
    redactions = []
    if query_removed:
        redactions.append("[REDACTED:query-string:privacy]")
    if path_redactions:
        redactions.append("[REDACTED:path-token-or-id:secret-or-PII]")
    if rq_body or (req.get("bodySize") or 0) > 0:
        redactions.append("[REDACTED:request-body-values:secret-or-PII]")
    if req.get("headers"):
        redactions.append("[REDACTED:request-header-values:secret-or-PII]")
    if rs_body or ((res.get("content") or {}).get("size") or 0) > 0:
        redactions.append("[REDACTED:response-body-values:secret-or-PII]")
    if res.get("headers"):
        redactions.append("[REDACTED:response-header-values:secret-or-PII]")
    request_body = describe_body(rq_body)
    response_body = describe_body(rs_body)
    flow = {
        "method": method,
        "host": host,
        "path": path,
        "status": status,
        "origin": origin,
        "x_android_package": package_header,
        "query_params": query_names,
        "count": 1,
        "request": {
            "size": req.get("bodySize") or 0,
            "content_type": next((h.get("value") for h in req.get("headers", [])
                                  if h.get("name", "").lower() == "content-type"), None),
            "headers": sorted(headers.keys()),
        },
        "response": {
            "size": (res.get("content") or {}).get("size") or 0,
            "content_type": (res.get("content") or {}).get("mimeType"),
        },
        "redactions": sorted(set(redactions)),
    }
    flow["request"].update(request_body)
    flow["response"].update(response_body)
    if outcome:
        flow["outcome"] = outcome
    flows_by_key[key] = flow
    order.append(key)

flows = [flows_by_key[k] for k in order]
total = sum(f["count"] for f in flows)


def record_list(value):
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


out = {
    "$schema": "network-log/1.0",
    "schema_version": "1.0",
    "app": os.environ.get("NETWORK_LOG_APP") or slug,
    "package_name": package,
    "capture_date": capture_date,
    "capture": portable_capture(mitm),
    "tls_unread": record_list(sidecar.get("tls_unread")),
    "non_http": record_list(sidecar.get("non_http")),
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
