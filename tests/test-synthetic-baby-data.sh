#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$repo_root/.tmp"
scanner="$repo_root/scripts/scan-synthetic-baby-data.sh"
tmp_dir="$(mktemp -d "$repo_root/.tmp/synth-baby-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

# Fixture A: markers in request bodies (third-party, first-party, and 482).
# Control traffic and name-only-in-response must not alone prove transmission.
cat > "$tmp_dir/capture-positive.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.synthtest",
  "capture_timestamp": "2026-08-14T00:00:00Z",
  "flows": [
    {
      "timestamp": "2026-08-14T00:00:01Z",
      "request": {
        "method": "POST",
        "url": "https://analytics.evil-tracker.example/v1/baby",
        "host": "analytics.evil-tracker.example",
        "headers": {"content-type": "application/json"},
        "body": "{\"baby_name\":\"Privatia Rigatoni\",\"note\":\"PRIVATIA-RIGATONI-SYNTH\"}"
      },
      "response": {"status": 200, "body": "{\"ok\":true}"}
    },
    {
      "timestamp": "2026-08-14T00:00:02Z",
      "request": {
        "method": "POST",
        "url": "https://api.example.com/baby/feed",
        "host": "api.example.com",
        "headers": {"content-type": "application/json"},
        "body": "{\"volume_ml\":482,\"brand\":\"Rigatoni-8823-synthfeed\"}"
      },
      "response": {"status": 200, "body": "{\"ok\":true}"}
    },
    {
      "timestamp": "2026-08-14T00:00:03Z",
      "request": {
        "method": "GET",
        "url": "https://storage.googleapis.com/normal-asset.json",
        "host": "storage.googleapis.com",
        "headers": {},
        "body": ""
      },
      "response": {"status": 200, "body": "{\"asset\":\"normal\"}"}
    },
    {
      "timestamp": "2026-08-14T00:00:04Z",
      "request": {
        "method": "POST",
        "url": "https://api.example.com/baby/echo",
        "host": "api.example.com",
        "headers": {"content-type": "application/json"},
        "body": "{\"ping\":1}"
      },
      "response": {"status": 200, "body": "{\"baby_name\":\"Privatia Rigatoni\"}"}
    }
  ]
}
EOF

# Fixture B: launch traffic with no baby markers.
cat > "$tmp_dir/capture-negative.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.cleanapp",
  "capture_timestamp": "2026-08-14T00:00:00Z",
  "flows": [
    {
      "timestamp": "2026-08-14T00:00:01Z",
      "request": {
        "method": "POST",
        "url": "https://firebaseinstallations.googleapis.com/v1/projects/demo/installations",
        "host": "firebaseinstallations.googleapis.com",
        "headers": {"content-type": "application/json"},
        "body": "{\"appId\":\"demo\"}"
      },
      "response": {"status": 200, "body": "{\"fid\":\"abc\"}"}
    }
  ]
}
EOF

# Fixture F: a finding URL carries a query parameter named key, plus a token path segment.
cat > "$tmp_dir/capture-query-key.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.querykey",
  "capture_timestamp": "2026-08-14T00:00:00Z",
  "flows": [
    {
      "timestamp": "2026-08-14T00:00:01Z",
      "request": {
        "method": "POST",
        "url": "https://maps.googleapis.com/maps/api/Ab12cd34Ef56/json?key=fixture-query-value",
        "host": "maps.googleapis.com",
        "headers": {"content-type": "application/json"},
        "body": "{\"baby_name\":\"Privatia Rigatoni\"}"
      },
      "response": {"status": 200, "body": ""}
    }
  ]
}
EOF

mkdir -p "$tmp_dir/reports"
out_a="$tmp_dir/reports/positive.json"
out_b="$tmp_dir/reports/negative.json"
out_key="$tmp_dir/reports/query-key.json"

# Fixture C: Clarity gzip body. The marker is inside the gzip bytes, not the base64 text.
# Fixture D: raw protobuf with the name marker. Fixture E: protobuf that cannot be decoded.
python3 - "$tmp_dir/capture-clarity-gzip.json" "$tmp_dir/capture-protobuf.json" "$tmp_dir/capture-protobuf-bad.json" <<'PY'
import base64
import gzip
import json
import sys

def dump(path, package, host, url, headers, body):
    doc = {
        "$schema": "decode-traffic/2.0",
        "schema_version": "2.0",
        "package_name": package,
        "app": package,
        "capture_timestamp": "2026-08-14T00:00:00Z",
        "flows": [
            {
                "timestamp": "2026-08-14T00:00:01Z",
                "request": {
                    "method": "POST",
                    "url": url,
                    "host": host,
                    "headers": headers,
                    "body": body,
                },
                "response": {"status": 204, "body": ""},
            }
        ],
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(doc, handle)

marker = '{"baby_name":"Privatia Rigatoni"}'
gzip_body = base64.b64encode(gzip.compress(marker.encode("utf-8"))).decode("ascii")
name = b"Privatia Rigatoni"
proto_body = base64.b64encode(bytes([0x0A, len(name)]) + name).decode("ascii")
bad_body = base64.b64encode(b"\x07").decode("ascii")
dump(
    sys.argv[1],
    "com.example.claritygzip",
    "www.clarity.ms",
    "https://www.clarity.ms/collect",
    {"content-type": "application/json", "accept": "application/x-clarity-gzip"},
    gzip_body,
)
dump(
    sys.argv[2],
    "com.example.protobuf",
    "app-measurement.com",
    "https://app-measurement.com/a",
    {"content-type": "application/x-protobuf"},
    proto_body,
)
dump(
    sys.argv[3],
    "com.example.protobufbad",
    "app-measurement.com",
    "https://app-measurement.com/a",
    {"content-type": "application/x-protobuf"},
    bad_body,
)
PY

bash "$scanner" "$tmp_dir/capture-positive.json" "$out_a"
bash "$scanner" "$tmp_dir/capture-negative.json" "$out_b"
bash "$scanner" "$tmp_dir/capture-query-key.json" "$out_key"
out_c="$tmp_dir/reports/clarity-gzip.json"
out_d="$tmp_dir/reports/protobuf.json"
out_e="$tmp_dir/reports/protobuf-bad.json"
bash "$scanner" "$tmp_dir/capture-clarity-gzip.json" "$out_c"
bash "$scanner" "$tmp_dir/capture-protobuf.json" "$out_d"
bash "$scanner" "$tmp_dir/capture-protobuf-bad.json" "$out_e"

OUT_A="$out_a" OUT_B="$out_b" OUT_KEY="$out_key" python3 - <<'PY'
import json
import os

a = json.load(open(os.environ["OUT_A"]))
b = json.load(open(os.environ["OUT_B"]))
key_report = json.load(open(os.environ["OUT_KEY"]))

# Query parameter named key must not survive into the written finding URL.
key_blob = json.dumps(key_report)
if "key=" in key_blob or "?key" in key_blob:
    print("FAIL: query parameter named key is still in the written JSON")
    raise SystemExit(1)
key_path = key_report["apps"][0]["findings"][0]["path"]
if "?" in key_path:
    print("FAIL: query string is still in the finding path")
    raise SystemExit(1)
if "Ab12cd34Ef56" in key_path:
    print("FAIL: token path segment is still in the written JSON")
    raise SystemExit(1)
if "[REDACTED:path-token-or-id]" not in key_path:
    print("FAIL: path token was not redacted")
    raise SystemExit(1)
assert key_report["apps"][0]["verdict"] == "transmission_observed"

# Positive fixture: must report transmission.
assert a["captures_scanned"] == 1
assert a["apps_with_transmission"] == 1
app = a["apps"][0]
assert app["transmission_observed"] is True
assert app["verdict"] == "transmission_observed"
assert "analytics.evil-tracker.example" in app["recipients"]
assert "api.example.com" in app["recipients"]

# Name marker must hit a third-party host on the request side.
name_finding = next(
    f for f in app["findings"]
    if f["marker_id"] == "name" and f["host"] == "analytics.evil-tracker.example"
)
assert name_finding["side"] == "request"
assert name_finding["vendor"] == "Unclassified host"
assert name_finding["recipient_class"] == "unknown_host"

# Marker 482 must appear in a request body.
num_finding = next(f for f in app["findings"] if f["marker_id"] == "feed_volume")
assert num_finding["side"] == "request"

# Control flow must not create a finding.
assert all(f["host"] != "storage.googleapis.com" for f in app["findings"])

# Response-only name hit is recorded; verdict still needs a request/URL hit.
assert any(f["side"] == "response" for f in app["findings"])
assert any(f["side"] in ("request", "url") for f in app["findings"])

# Negative fixture: no transmission. The finding list stays present and empty.
neg = b["apps"][0]
assert neg["transmission_observed"] is False
assert neg["verdict"] == "no_transmission_detected"
assert neg["findings"] == []
assert neg["flows_scanned"] == 1
assert neg["claim_limit"].startswith("not observed in this capture window")
assert "does not prove the app never sends" in neg["claim_limit"]
assert not neg["capture"].startswith("/")
assert not b["profile_source"].startswith("/")
assert b["profile_source"] == "results/synthetic-baby-profile.json"
assert b["method"].startswith("marker search of the raw local capture")
assert not app["capture"].startswith("/")
assert app["claim_limit"].startswith("a high or medium name")

print("Synthetic baby-data scan test passed")
PY

OUT_C="$out_c" OUT_D="$out_d" OUT_E="$out_e" OUT_B="$out_b" python3 - <<'PY'
import json
import os

gzip_report = json.load(open(os.environ["OUT_C"]))
proto_report = json.load(open(os.environ["OUT_D"]))
bad_report = json.load(open(os.environ["OUT_E"]))
plain = json.load(open(os.environ["OUT_B"]))

gzip_app = gzip_report["apps"][0]
gzip_hit = any(
    finding["marker_id"] == "name" and finding["side"] == "request"
    for finding in gzip_app["findings"]
)
assert gzip_hit, gzip_app["findings"]
assert gzip_app["verdict"] == "transmission_observed"

proto_app = proto_report["apps"][0]
proto_count = proto_app.get("unscannable_count")
proto_hit = any(
    finding["marker_id"] == "name" and finding["side"] == "request"
    for finding in proto_app["findings"]
)
assert isinstance(proto_count, int) and proto_count >= 0, proto_count
assert proto_hit or proto_count >= 1, proto_app

bad_app = bad_report["apps"][0]
assert bad_app["verdict"] == "no_transmission_detected"
assert isinstance(bad_app.get("unscannable_count"), int)
assert bad_app["unscannable_count"] >= 1, bad_app

plain_app = plain["apps"][0]
assert plain_app.get("unscannable_count") == 0, plain_app
print("Body decode and unscannable count test passed")
PY

python3 "$repo_root/scripts/check-marker-scans.py" "$tmp_dir/reports"
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
    python3 "$repo_root/scripts/check-marker-scans.py" --strict "$tmp_dir/reports"
fi

# An absolute capture path must fail the checker.
bad_dir="$tmp_dir/bad"
mkdir -p "$bad_dir"
python3 - "$out_b" "$bad_dir/absolute.json" <<'PY'
import json
import os
import sys
report = json.load(open(sys.argv[1]))
report["apps"][0]["capture"] = "/tmp/secret-capture.mitm"
json.dump(report, open(sys.argv[2], "w"))
PY
if python3 "$repo_root/scripts/check-marker-scans.py" "$bad_dir"; then
    echo "ERROR: absolute capture path was accepted" >&2
    exit 1
fi

# A negative with no unscannable count must fail the checker.
missing_dir="$tmp_dir/missing-count"
mkdir -p "$missing_dir"
python3 - "$out_b" "$missing_dir/missing-count.json" <<'PY'
import json
import sys
report = json.load(open(sys.argv[1]))
removed = report["apps"][0].pop("unscannable_count", None)
if removed is None:
    print("ERROR: negative report has no unscannable count to remove", file=sys.stderr)
    raise SystemExit(1)
json.dump(report, open(sys.argv[2], "w"))
PY
if python3 "$repo_root/scripts/check-marker-scans.py" "$missing_dir"; then
    echo "ERROR: negative with no unscannable count was accepted" >&2
    exit 1
fi
if python3 -c 'import jsonschema' >/dev/null 2>&1; then
    if python3 "$repo_root/scripts/check-marker-scans.py" --strict "$missing_dir"; then
        echo "ERROR: strict checker accepted a negative with no unscannable count" >&2
        exit 1
    fi
fi
