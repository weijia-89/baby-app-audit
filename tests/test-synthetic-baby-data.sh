#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scanner="$repo_root/scripts/scan-synthetic-baby-data.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/synth-baby-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

# Fixture A: positive control. The fictional baby data appears in request bodies
# to a third-party host, in a first-party-style host, and as a numeric sentinel.
# A control flow (normal traffic) and a response-echo flow (name only in the
# reply, not the request) must NOT create false transmissions on their own.
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

# Fixture B: negative control. Realistic launch traffic, none of it the fictional
# baby data.
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

out_a="$tmp_dir/positive.json"
out_b="$tmp_dir/negative.json"

bash "$scanner" "$tmp_dir/capture-positive.json" "$out_a"
bash "$scanner" "$tmp_dir/capture-negative.json" "$out_b"

OUT_A="$out_a" OUT_B="$out_b" python3 - <<'PY'
import json
import os

a = json.load(open(os.environ["OUT_A"]))
b = json.load(open(os.environ["OUT_B"]))

# Positive fixture: transmission must be detected.
assert a["captures_scanned"] == 1
assert a["apps_with_transmission"] == 1
app = a["apps"][0]
assert app["transmission_observed"] is True
assert app["verdict"] == "transmission_observed"
assert "analytics.evil-tracker.example" in app["recipients"]
assert "api.example.com" in app["recipients"]

# The name marker must be attributed to the third-party host with a request side.
name_finding = next(
    f for f in app["findings"]
    if f["marker_id"] == "name" and f["host"] == "analytics.evil-tracker.example"
)
assert name_finding["side"] == "request"
assert name_finding["vendor"] == "Unclassified host"
assert name_finding["recipient_class"] == "unknown_host"

# The numeric sentinel (482) must be found in a request body.
num_finding = next(f for f in app["findings"] if f["marker_id"] == "feed_volume")
assert num_finding["side"] == "request"

# The control flow (googleapis, normal body) must NOT produce a finding.
assert all(f["host"] != "storage.googleapis.com" for f in app["findings"])

# The response-echo flow (name only in the reply) is recorded but must not, by
# itself, be what flips the verdict. Confirm a response-side finding exists and
# that a request/url finding also exists (so the verdict is driven by a real send).
assert any(f["side"] == "response" for f in app["findings"])
assert any(f["side"] in ("request", "url") for f in app["findings"])

# Negative fixture: no transmission.
assert b["apps"][0]["transmission_observed"] is False
assert b["apps"][0]["verdict"] == "no_transmission_detected"
assert b["apps"][0]["findings"] == []

print("Synthetic baby-data scan test passed")
PY
