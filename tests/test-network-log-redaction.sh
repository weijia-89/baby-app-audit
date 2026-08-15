#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/network-log-redaction-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/mitmdump" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

har_output=""
capture_next=0
for arg in "$@"; do
    if [ "$capture_next" -eq 1 ]; then
        case "$arg" in
            har_output=*) har_output="${arg#har_output=}" ;;
        esac
        capture_next=0
    elif [ "$arg" = "--set" ]; then
        capture_next=1
    fi
done

cp "$FAKE_HAR" "$har_output"
EOF
chmod +x "$fake_bin/mitmdump"

har="$tmp_dir/input.har"
capture="$tmp_dir/input.mitm"
output="$tmp_dir/network-log.json"
: > "$capture"

cat > "$har" <<'EOF'
{
  "log": {
    "version": "1.2",
    "creator": {"name": "test", "version": "1.0"},
    "entries": [
      {
        "request": {
          "method": "POST",
          "url": "https://analytics.example/track/abcdefghijklmnopqrstuvwxyz1234567890?baby_name=TestBaby",
          "headers": [
            {"name": "Authorization", "value": "SECRET_HEADER"},
            {"name": "Content-Type", "value": "application/json"}
          ],
          "postData": {"text": "{\"baby_name\":\"TestBaby\",\"token\":\"SECRET_BODY\"}"},
          "bodySize": 55
        },
        "response": {
          "status": 200,
          "headers": [{"name": "Set-Cookie", "value": "SECRET_COOKIE"}],
          "content": {
            "size": 40,
            "mimeType": "application/json",
            "text": "{\"token\":\"SECRET_RESPONSE\",\"ok\":true}"
          }
        }
      }
    ]
  }
}
EOF

PATH="$fake_bin:$PATH" FAKE_HAR="$har" NETWORK_LOG_OUTPUT="$output" \
    bash "$repo_root/scripts/build-network-logs.sh" fixture "$capture" 2026-08-14

OUTPUT="$output" python3 - <<'PY'
import json
import os

text = open(os.environ["OUTPUT"]).read()
assert "SECRET_HEADER" not in text
assert "SECRET_BODY" not in text
assert "SECRET_RESPONSE" not in text
assert "SECRET_COOKIE" not in text
assert "TestBaby" not in text

data = json.loads(text)
flow = data["flows"][0]
assert flow["method"] == "POST"
assert flow["host"] == "analytics.example"
assert flow["status"] == 200
assert flow["request"]["size"] == 55
assert flow["response"]["size"] == 40
assert "[REDACTED:path-token-or-id]" in flow["path"]
assert "[REDACTED:query-string:privacy]" in flow["redactions"]
assert "[REDACTED:path-token-or-id:secret-or-PII]" in flow["redactions"]
assert "[REDACTED:request-body-values:secret-or-PII]" in flow["redactions"]
assert "[REDACTED:request-header-values:secret-or-PII]" in flow["redactions"]
assert "[REDACTED:response-body-values:secret-or-PII]" in flow["redactions"]
assert "[REDACTED:response-header-values:secret-or-PII]" in flow["redactions"]
PY

# Origin classification: a request carrying the app's own package header is
# "app"; a different package is "device"; no package header is "session". The
# previous logic mislabeled an app request that also carried Authorization.
har2="$tmp_dir/input2.har"
capture2="$tmp_dir/input2.mitm"
output2="$tmp_dir/network-log-amila.json"
: > "$capture2"
cat > "$har2" <<'EOF'
{
  "log": {
    "version": "1.2",
    "creator": {"name": "test", "version": "1.0"},
    "entries": [
      {
        "request": {
          "method": "POST",
          "url": "https://api.amila.example/v1/event",
          "headers": [
            {"name": "X-Android-Package", "value": "com.amila.parenting"},
            {"name": "Authorization", "value": "SECRET_HEADER"}
          ],
          "postData": {"text": "{\"token\":\"SECRET_BODY\"}"},
          "bodySize": 25
        },
        "response": {
          "status": 200,
          "headers": [{"name": "Set-Cookie", "value": "SECRET_COOKIE"}],
          "content": {"size": 3, "mimeType": "application/json", "text": "{}"}
        }
      },
      {
        "request": {
          "method": "GET",
          "url": "https://api.other.example/x",
          "headers": [{"name": "X-Android-Package", "value": "com.other.app"}],
          "postData": {"text": ""},
          "bodySize": 0
        },
        "response": {
          "status": 200,
          "headers": [],
          "content": {"size": 0, "mimeType": null}
        }
      },
      {
        "request": {
          "method": "GET",
          "url": "https://api.session.example/y",
          "headers": [{"name": "Authorization", "value": "SECRET_HEADER"}],
          "postData": {"text": ""},
          "bodySize": 0
        },
        "response": {
          "status": 200,
          "headers": [],
          "content": {"size": 0, "mimeType": null}
        }
      }
    ]
  }
}
EOF

PATH="$fake_bin:$PATH" FAKE_HAR="$har2" NETWORK_LOG_OUTPUT="$output2" \
    bash "$repo_root/scripts/build-network-logs.sh" amila "$capture2" 2026-08-14

OUTPUT2="$output2" python3 - <<'PY'
import json
import os

text = open(os.environ["OUTPUT2"]).read()
assert "SECRET_HEADER" not in text
assert "SECRET_BODY" not in text
assert "SECRET_COOKIE" not in text

data = json.loads(text)
origins = {f["host"]: f["origin"] for f in data["flows"]}
assert origins["api.amila.example"] == "app", origins
assert origins["api.other.example"] == "device", origins
assert origins["api.session.example"] == "session", origins
PY

echo "Network log redaction test passed"
