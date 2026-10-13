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

mkdir -p "$tmp_dir/reports"
out_a="$tmp_dir/reports/positive.json"
out_b="$tmp_dir/reports/negative.json"

bash "$scanner" "$tmp_dir/capture-positive.json" "$out_a"
bash "$scanner" "$tmp_dir/capture-negative.json" "$out_b"

OUT_A="$out_a" OUT_B="$out_b" python3 - <<'PY'
import json
import os

a = json.load(open(os.environ["OUT_A"]))
b = json.load(open(os.environ["OUT_B"]))

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
