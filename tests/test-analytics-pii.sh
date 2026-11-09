#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scanner="$repo_root/scripts/scan-analytics-pii.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/analytics-pii-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/network-log-fixture.json" <<'EOF'
{
  "$schema": "network-log/1.0",
  "schema_version": "1.0",
  "app": "fixture",
  "package_name": "com.example.fixture",
  "capture_date": "2026-08-14",
  "redaction": {
    "policy": "Values are replaced with descriptive slugs.",
    "slugs": {
      "request_body": "[REDACTED:request-body-values:secret-or-PII]"
    }
  },
  "flows": [
    {
      "method": "POST",
      "host": "graph.facebook.com",
      "path": "https://graph.facebook.com/v16.0/123/activities",
      "status": 200,
      "origin": "session",
      "count": 1,
      "request": {
        "size": 321,
        "content_type": "application/x-www-form-urlencoded",
        "body_keys": null,
        "headers": []
      },
      "response": {
        "size": 16,
        "content_type": "application/json",
        "body_keys": ["success"]
      },
      "redactions": ["[REDACTED:request-body-values:secret-or-PII]"]
    },
    {
      "method": "GET",
      "host": "www.clarity.ms",
      "path": "https://www.clarity.ms/tag/mobile/test",
      "status": 200,
      "origin": "session",
      "count": 1,
      "request": {
        "size": 0,
        "content_type": null,
        "body_keys": null,
        "headers": []
      },
      "response": {
        "size": 100,
        "content_type": "application/json",
        "body_keys": ["screenCapture", "webViewCapture"]
      }
    },
    {
      "method": "POST",
      "host": "ingest.unknown-analytics.example",
      "path": "https://ingest.unknown-analytics.example/track",
      "status": 202,
      "origin": "device",
      "count": 1,
      "request": {
        "size": 44,
        "content_type": "application/json",
        "body_keys": null,
        "headers": ["authorization"]
      },
      "response": {
        "size": 0,
        "content_type": null,
        "body_keys": null
      },
      "redactions": [
        "[REDACTED:request-body-values:secret-or-PII]",
        "[REDACTED:request-header-values:secret-or-PII]"
      ]
    },
    {
      "method": "POST",
      "host": "www.clarity.ms",
      "path": "https://www.clarity.ms/c/upload/asset",
      "status": 200,
      "origin": "session",
      "count": 1,
      "request": {
        "size": 10,
        "content_type": "application/octet-stream",
        "body_keys": null,
        "headers": []
      },
      "response": {
        "size": 0,
        "content_type": null,
        "body_keys": null
      }
    },
    {
      "method": "POST",
      "host": "www.clarity.ms",
      "path": "https://www.clarity.ms/c/upload-asset",
      "status": 200,
      "origin": "session",
      "count": 1,
      "request": {
        "size": 11,
        "content_type": "application/octet-stream",
        "body_keys": null,
        "headers": []
      },
      "response": {
        "size": 0,
        "content_type": null,
        "body_keys": null
      }
    }
  ],
  "summary": {
    "total_flows": 5,
    "unique_destinations": [
      "graph.facebook.com",
      "www.clarity.ms",
      "ingest.unknown-analytics.example"
    ]
  }
}
EOF

output="$tmp_dir/analytics-pii.json"

# Second fixture: vendor match edge cases.
# - Host that embeds a vendor name across a label must not match that vendor.
# - Dashed subdomains of a real vendor must still match.
cat > "$tmp_dir/network-log-vendors.json" <<'EOF'
{
  "$schema": "network-log/1.0",
  "schema_version": "1.0",
  "app": "vendors",
  "package_name": "com.example.vendors",
  "capture_date": "2026-08-14",
  "redaction": {
    "policy": "Values are replaced with descriptive slugs.",
    "slugs": { "request_body": "[REDACTED:request-body-values:secret-or-PII]" }
  },
  "flows": [
    {
      "method": "GET", "host": "evilgoogle.com.attacker.net",
      "path": "https://evilgoogle.com.attacker.net/evil", "status": 200,
      "origin": "session", "count": 1,
      "request": {"size": 0, "content_type": null, "body_keys": null, "headers": []},
      "response": {"size": 0, "content_type": null, "body_keys": null}
    },
    {
      "method": "POST", "host": "api16-access-ttp.tiktokpangle.us",
      "path": "https://api16-access-ttp.tiktokpangle.us/api/ad/union/sdk/settings/", "status": 200,
      "origin": "session", "count": 1,
      "request": {"size": 100, "content_type": "application/json", "body_keys": null, "headers": []},
      "response": {"size": 0, "content_type": null, "body_keys": null}
    },
    {
      "method": "POST", "host": "firebase-settings.crashlytics.com",
      "path": "https://firebase-settings.crashlytics.com/sdk/batch", "status": 200,
      "origin": "session", "count": 1,
      "request": {"size": 50, "content_type": "application/json", "body_keys": null, "headers": []},
      "response": {"size": 0, "content_type": null, "body_keys": null}
    },
    {
      "method": "POST", "host": "ingress.eu1.rum-ingress-coralogix.com",
      "path": "https://ingress.eu1.rum-ingress-coralogix.com/rum/v1/ingest", "status": 200,
      "origin": "session", "count": 1,
      "request": {"size": 200, "content_type": "application/json", "body_keys": null, "headers": []},
      "response": {"size": 0, "content_type": null, "body_keys": null}
    }
  ],
  "summary": {
    "total_flows": 4,
    "unique_destinations": [
      "evilgoogle.com.attacker.net",
      "api16-access-ttp.tiktokpangle.us",
      "firebase-settings.crashlytics.com",
      "ingress.eu1.rum-ingress-coralogix.com"
    ]
  }
}
EOF

# Skip a corrupt log; do not crash the scan.
printf '{ this is not valid json' > "$tmp_dir/network-log-bad.json"

bash "$scanner" "$tmp_dir" "$output"

OUTPUT="$output" python3 - <<'PY'
import json
import os

data = json.load(open(os.environ["OUTPUT"]))
assert data["scope"]["apps_scanned"] == 2
assert data["scope"]["calls_scanned"] == 9
assert "likely" not in json.dumps(data).lower()

app = data["apps"][0]
assert app["call_count"] == 5
assert app["pii_call_count"] == 5
assert app["unassessed_call_count"] == 4

calls = {call["host"]: call for call in app["calls"]}
facebook = calls["graph.facebook.com"]
assert facebook["sent_call"] is True
assert "app_activity_events" in facebook["pii_categories"]
assert "call_sent_body_scrubbed" in facebook["assessments"]

clarity_calls = [call for call in app["calls"] if call["host"] == "www.clarity.ms"]
clarity = next(call for call in clarity_calls if call["path"].endswith("/tag/mobile/test"))
assert "screen_content_and_interactions" in clarity["pii_categories"]
assert "capability_observed" in clarity["assessments"]
upload_slash = next(call for call in clarity_calls if call["path"].endswith("/upload/asset"))
upload_dash = next(call for call in clarity_calls if call["path"].endswith("/upload-asset"))
assert "screen_images_or_assets" in upload_slash["pii_categories"], upload_slash
assert "screen_images_or_assets" in upload_dash["pii_categories"], upload_dash

unknown = calls["ingest.unknown-analytics.example"]
assert unknown["vendor"] == "Unclassified host"
assert unknown["sent_call"] is True
assert "call_sent_body_scrubbed" in unknown["assessments"]
assert "call_sent_header_value_scrubbed" in unknown["assessments"]

vendor = next(item for item in data["vendors"] if item["vendor"] == "Facebook")
assert vendor["call_count"] == 1
assert "app_activity_events" in vendor["pii_categories"]

# Vendor match edge cases (second fixture).
vapp = next(a for a in data["apps"] if a["app"] == "vendors")
vcalls = {c["host"]: c["vendor"] for c in vapp["calls"]}
assert vcalls["evilgoogle.com.attacker.net"] == "Unclassified host", \
    "hostile host was misattributed: " + vcalls["evilgoogle.com.attacker.net"]
assert vcalls["api16-access-ttp.tiktokpangle.us"] == "TikTok Pangle"
assert vcalls["firebase-settings.crashlytics.com"] == "Google/Firebase"
assert vcalls["ingress.eu1.rum-ingress-coralogix.com"] == "Coralogix"
PY

echo "Analytics PII fanout test passed"

# Literal adtest=on search. A planted marker fails closed until the scanner exists.
adtest_scanner="$repo_root/scripts/scan-adtest-on.py"
adtest_dir="$(mktemp -d "${TMPDIR:-/tmp}/adtest-on-test.XXXXXX")"
trap 'chmod u+rwx "$adtest_dir"/locked.mitm 2>/dev/null || true; rm -rf "$tmp_dir" "$adtest_dir"' EXIT
adtest_out="$adtest_dir/adtest-on-scan.json"
printf 'prefix adtest=on&sid=SECRETTOKENVALUE suffix' > "$adtest_dir/planted.mitm"
printf 'notadtest=on adtest=online adtest=off' > "$adtest_dir/clean.mitm"
printf 'locked' > "$adtest_dir/locked.mitm"
chmod 000 "$adtest_dir/locked.mitm"

python3 "$adtest_scanner" "$adtest_out" \
  "$adtest_dir/planted.mitm" \
  "$adtest_dir/clean.mitm" \
  "$adtest_dir/locked.mitm"

ADTEST_OUT="$adtest_out" python3 - <<'PY'
import json
import os

data = json.load(open(os.environ["ADTEST_OUT"]))
text = json.dumps(data)
assert "SECRETTOKENVALUE" not in text
assert "sid=" not in text
files = {item["file"]: item for item in data["files"]}
assert files["planted.mitm"]["hit_count"] == 1, files["planted.mitm"]
assert files["clean.mitm"]["hit_count"] == 0, files["clean.mitm"]
locked = files["locked.mitm"]
assert locked.get("error"), locked
assert locked.get("hit_count") in (None, 0) or "hit_count" not in locked
assert "sent nothing" not in text.lower()
PY

echo "adtest=on scan test passed"
