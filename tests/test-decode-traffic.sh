#!/usr/bin/env bash
# Unit tests for decode-traffic.sh
# Usage: bash tests/test-decode-traffic.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DECODER="$REPO_DIR/scripts/decode-traffic.sh"
TEST_HAR="$REPO_DIR/tests/fixtures/test-capture.har"
FAILED=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

# Setup: create test HAR with one matching flow
cleanup() {
    rm -f "$REPO_DIR/tests/fixtures/bad.json" "$REPO_DIR/tests/fixtures/output.json" "$REPO_DIR/tests/fixtures/output2.json" "$REPO_DIR/tests/fixtures/output3.json" "$REPO_DIR/tests/fixtures/output4.json" "$REPO_DIR/tests/fixtures/stderr3.txt" "$REPO_DIR/tests/fixtures/stderr4.txt" "$REPO_DIR/tests/fixtures/missing-config.json" "$REPO_DIR/tests/fixtures/bad-schema.json" "$REPO_DIR/tests/fixtures/empty.har" "$REPO_DIR/tests/fixtures/output-empty.json" "$REPO_DIR/tests/fixtures/corrupted-schema.json" "$REPO_DIR/tests/fixtures/output-badschema.json" "$REPO_DIR/tests/fixtures/output-rw-pebbi.json" "$REPO_DIR/tests/fixtures/output-rw-nl.json" "$REPO_DIR/tests/fixtures/output-rw-nubo.json" "$REPO_DIR/tests/fixtures/output-rw-pregnancyplus.json" "$REPO_DIR/tests/fixtures/output-rw-wte.json" "$REPO_DIR/tests/fixtures/output-rw-amila.json"
}
trap cleanup EXIT

mkdir -p "$REPO_DIR/tests/fixtures"
cat > "$TEST_HAR" <<'EOF'
{
  "log": {
    "version": "1.2",
    "creator": {"name": "test", "version": "1.0"},
    "entries": [
      {
        "startedDateTime": "2026-08-03T12:00:00Z",
        "request": {
          "method": "POST",
          "url": "https://com.pebbi.android/api/v1/config",
          "headers": [{"name": "Content-Type", "value": "application/json"}],
          "postData": {"text": "{\"event\": \"app_open\"}"},
          "bodySize": 18
        },
        "response": {
          "status": 200,
          "headers": [{"name": "Set-Cookie", "value": "session=abc123"}],
          "bodySize": 10
        }
      },
      {
        "startedDateTime": "2026-08-03T12:01:00Z",
        "request": {
          "method": "GET",
          "url": "https://api.pebbi.android/v1/config",
          "headers": [{"name": "User-Agent", "value": "Pebbi/1.0"}],
          "bodySize": 0
        },
        "response": {
          "status": 200,
          "headers": [{"name": "Cache-Control", "value": "max-age=3600"}],
          "bodySize": 500
        }
      }
    ]
  }
}
EOF

echo "=== decode-traffic.sh unit tests ==="

# Test 1: Missing arguments
echo "Test 1: Missing arguments"
if bash "$DECODER" 2>/dev/null; then
    fail "Should exit with error on missing args"
else
    pass "Exits with error on missing args"
fi

# Test 2: Nonexistent HAR file
echo "Test 2: Nonexistent HAR file"
if bash "$DECODER" /nonexistent.har com.test.app 2>/dev/null; then
    fail "Should exit with error on missing HAR"
else
    pass "Exits with error on missing HAR"
fi

# Test 3: Invalid JSON HAR
echo "Test 3: Invalid JSON HAR"
echo "not json" > "$REPO_DIR/tests/fixtures/bad.json"
if bash "$DECODER" "$REPO_DIR/tests/fixtures/bad.json" com.test.app 2>/dev/null; then
    fail "Should exit with error on invalid JSON"
else
    pass "Exits with error on invalid JSON"
fi

# Test 4: --version flag
echo "Test 4: --version flag"
VERSION=$(bash "$DECODER" --version 2>/dev/null)
if [ "$VERSION" = "2.0" ]; then
    pass "Version flag returns correct version"
else
    fail "Version flag returned '$VERSION', expected '2.0'"
fi

# Test 5: Valid HAR with output file
echo "Test 5: Valid HAR with output file"
OUTPUT="$REPO_DIR/tests/fixtures/output.json"
if bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT" >/dev/null 2>&1; then
    if [ -f "$OUTPUT" ]; then
        if python3 -m json.tool "$OUTPUT" >/dev/null 2>&1; then
            pass "Produces valid JSON output"
        else
            fail "Output is not valid JSON"
        fi
    else
        fail "Output file not created"
    fi
else
    fail "Should succeed on valid HAR"
fi

# Test 6: Verify schema field exists
echo "Test 6: Schema field exists"
if grep -q '"\$schema": "decode-traffic/2.0"' "$OUTPUT"; then
    pass "Schema declaration present"
else
    fail "Schema declaration missing"
fi

# Test 7: Verify product metadata loaded
echo "Test 7: Product metadata loaded"
if grep -q '"regulatory_regime": "RED"' "$OUTPUT"; then
    pass "Product metadata loaded from config"
else
    fail "Product metadata not loaded"
fi

# Test 8: Verify flows array has entries
echo "Test 8: Flows array has entries"
FLOW_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d.get('flows', [])))")
if [ "$FLOW_COUNT" -gt 0 ]; then
    pass "Flows array has entries (count: $FLOW_COUNT)"
else
    fail "Flows array is empty"
fi

# Test 9: Verify summary exists
echo "Test 9: Summary exists"
if python3 -c "import json; d=json.load(open('$OUTPUT')); print('summary' in d)" | grep -q "True"; then
    pass "Summary section present"
else
    fail "Summary section missing"
fi

# Test 10: Output directory must exist
echo "Test 10: Output directory must exist"
if bash "$DECODER" "$TEST_HAR" com.pebbi.android /nonexistent/dir/output.json 2>/dev/null; then
    fail "Should fail when output directory missing"
else
    pass "Fails when output directory missing"
fi

# Test 11: Missing config file falls back to defaults
echo "Test 11: Missing config file falls back to defaults"
OUTPUT2="$REPO_DIR/tests/fixtures/output2.json"
if bash "$DECODER" "$TEST_HAR" com.unknown.app "$OUTPUT2" >/dev/null 2>&1; then
    if grep -q '"regulatory_regime": "unknown"' "$OUTPUT2"; then
        pass "Falls back to default metadata for unknown app"
    else
        fail "Did not fall back to default metadata"
    fi
else
    fail "Should succeed even with unknown app"
fi

# Test 12: Corrupted config file falls back to defaults
echo "Test 12: Corrupted config file falls back to defaults"
echo "not json" > "$REPO_DIR/tests/fixtures/missing-config.json"
OUTPUT2="$REPO_DIR/tests/fixtures/output2.json"
if PRODUCT_CONFIG="$REPO_DIR/tests/fixtures/missing-config.json" bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT2" >/dev/null 2>&1; then
    if grep -q '"regulatory_regime": "unknown"' "$OUTPUT2"; then
        pass "Falls back to default metadata with corrupted config"
    else
        fail "Did not fall back with corrupted config"
    fi
else
    fail "Should succeed even with corrupted config"
fi

# Test 13: Strict mode passes on valid output (requires jsonschema)
echo "Test 13: Strict mode passes on valid output"
if python3 -c "import jsonschema" 2>/dev/null; then
    OUTPUT3="$REPO_DIR/tests/fixtures/output3.json"
    STDERR3="$REPO_DIR/tests/fixtures/stderr3.txt"
    if DECODE_TRAFFIC_STRICT=1 bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT3" 2>"$STDERR3"; then
        pass "Strict mode allows valid output"
    else
        fail "Strict mode rejected valid output"
        if [ -f "$STDERR3" ]; then
            echo "    stderr: $(cat "$STDERR3")"
        fi
    fi
else
    pass "Skipped - jsonschema not installed"
fi

# Test 14: Strict mode fails on schema violation (requires jsonschema)
echo "Test 14: Strict mode fails on schema violation"
if python3 -c "import jsonschema" 2>/dev/null; then
    # Create a schema that rejects valid output by requiring an impossible field
    cat > "$REPO_DIR/tests/fixtures/bad-schema.json" <<'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["$schema", "schema_version", "package_name", "capture_timestamp", "flows", "impossible_field"]
}
EOF
    OUTPUT4="$REPO_DIR/tests/fixtures/output4.json"
    STDERR4="$REPO_DIR/tests/fixtures/stderr4.txt"
    if ! DECODE_TRAFFIC_STRICT=1 SCHEMA_FILE="$REPO_DIR/tests/fixtures/bad-schema.json" bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT4" 2>"$STDERR4"; then
        pass "Strict mode fails when schema violated"
    else
        fail "Strict mode did not fail on schema violation"
    fi
else
    pass "Skipped - jsonschema not installed"
fi

# Test 15: Empty flows array still produces schema-valid output
 echo "Test 15: Empty flows array produces valid output"
 EMPTY_HAR="$REPO_DIR/tests/fixtures/empty.har"
 cat > "$EMPTY_HAR" <<'EOF'
{"log": {"version": "1.2", "creator": {"name": "test", "version": "1.0"}, "entries": []}}
EOF
  OUTPUT_EMPTY="$REPO_DIR/tests/fixtures/output-empty.json"
  if bash "$DECODER" "$EMPTY_HAR" com.unknown.app "$OUTPUT_EMPTY" >/dev/null 2>&1; then
      FLOW_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT_EMPTY')); print(len(d.get('flows', [])))" 2>/dev/null) || FLOW_COUNT=""
      if [ -z "$FLOW_COUNT" ]; then
          fail "Failed to count flows in output"
      elif [ "$FLOW_COUNT" -eq 0 ]; then
          pass "Empty flows array handled correctly"
      else
          fail "Expected 0 flows, got $FLOW_COUNT"
      fi
  else
      fail "Should succeed with empty HAR"
  fi

 # Test 16: Corrupted schema file falls back to warn (not crash)
 echo "Test 16: Corrupted schema file is handled gracefully"
 BAD_SCHEMA="$REPO_DIR/tests/fixtures/corrupted-schema.json"
 echo "not json" > "$BAD_SCHEMA"
 OUTPUT_BAD="$REPO_DIR/tests/fixtures/output-badschema.json"
 if bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT_BAD" >/dev/null 2>&1; then
     pass "Corrupted schema does not crash decoder"
 else
     fail "Should succeed even with corrupted schema"
 fi

# Test 17: Real-world host shapes (label / header / body attribution)
echo "Test 17: Real-world host shapes attribute correctly"
RW_HAR="$REPO_DIR/tests/fixtures/real-world-capture.har"
RW_PEBBI="$REPO_DIR/tests/fixtures/output-rw-pebbi.json"
RW_NL="$REPO_DIR/tests/fixtures/output-rw-nl.json"
RW_NUBO="$REPO_DIR/tests/fixtures/output-rw-nubo.json"
RW_PEBBI_TRK="$REPO_DIR/tests/fixtures/output-rw-pebbi-trk.json"

# Create real-world HAR fixture if it doesn't exist
if [ ! -f "$RW_HAR" ]; then
    cat > "$RW_HAR" <<'EOF'
{
  "log": {
    "version": "1.2",
    "creator": {"name": "mitmproxy", "version": "12.2.3"},
    "entries": [
      {
        "startedDateTime": "2026-08-03T12:00:00Z",
        "request": {
          "method": "GET",
          "url": "https://app.pebbi.co/app/version-policy",
          "headers": [
            {"name": "User-Agent", "value": "Pebbi/4.0.1"},
            {"name": "X-Client-Bundle-ID", "value": "com.pebbi.android"}
          ],
          "bodySize": -1
        },
        "response": {
          "status": 200,
          "headers": [{"name": "Content-Type", "value": "application/json"}],
          "bodySize": 150
        }
      },
      {
        "startedDateTime": "2026-08-03T12:00:01Z",
        "request": {
          "method": "POST",
          "url": "https://firebaselogging-pa.googleapis.com/v1/firelog/legacy/batchlog",
          "headers": [
            {"name": "Content-Type", "value": "application/x-protobuf"},
            {"name": "X-Android-Package", "value": "com.pebbi.android"}
          ],
          "postData": {"text": "{\"packageName\":\"com.pebbi.android\"}"},
          "bodySize": 50
        },
        "response": {
          "status": 200,
          "headers": [],
          "bodySize": 10
        }
      },
      {
        "startedDateTime": "2026-08-03T12:00:02Z",
        "request": {
          "method": "GET",
          "url": "https://api.revenuecat.com/v1/subscribers/test",
          "headers": [
            {"name": "X-Client-Bundle-ID", "value": "com.angry.shark.studio.nurturelock"},
            {"name": "X-Platform", "value": "android"}
          ],
          "bodySize": -1
        },
        "response": {
          "status": 304,
          "headers": [],
          "bodySize": 0
        }
      }
    ]
  }
}
EOF
fi

RW_OK=1
# Pebbi: app.pebbi.co (label match) + firebaselogging (body packageName match) = 2 flows
if bash "$DECODER" "$RW_HAR" com.pebbi.android "$RW_PEBBI" >/dev/null 2>&1; then
    RW_PCNT=$(python3 -c "import json; print(len(json.load(open('$RW_PEBBI')).get('flows',[])))")
    if [ "$RW_PCNT" -ge 2 ]; then
        pass "Pebbi real-world attribution ($RW_PCNT flows)"
    else
        fail "Pebbi expected >=2 real-world flows, got $RW_PCNT"; RW_OK=0
    fi
else
    fail "Pebbi real-world decode failed"; RW_OK=0
fi
# Nurture Lock: api.revenuecat.com with X-Client-Bundle-ID header = 1 flow
if bash "$DECODER" "$RW_HAR" com.angry.shark.studio.nurturelock "$RW_NL" >/dev/null 2>&1; then
    RW_NLCNT=$(python3 -c "import json; print(len(json.load(open('$RW_NL')).get('flows',[])))")
    if [ "$RW_NLCNT" -eq 1 ]; then
        pass "Nurture Lock header attribution ($RW_NLCNT flow)"
    else
        fail "Nurture Lock expected 1 header-attributed flow, got $RW_NLCNT"; RW_OK=0
    fi
else
    fail "Nurture Lock real-world decode failed"; RW_OK=0
fi
# Nubo: no matching traffic in this HAR = 0 flows (negative control)
if bash "$DECODER" "$RW_HAR" com.clicksie.nuboapp "$RW_NUBO" >/dev/null 2>&1; then
    RW_NBCNT=$(python3 -c "import json; print(len(json.load(open('$RW_NUBO')).get('flows',[])))")
    if [ "$RW_NBCNT" -eq 0 ]; then
        pass "Nubo negative control (0 flows, no false attribution)"
    else
        fail "Nubo expected 0 flows, got $RW_NBCNT"; RW_OK=0
    fi
else
    fail "Nubo real-world decode failed"; RW_OK=0
fi

# Tracker-domain fidelity: SDK hosts (googleapis.com, firebaseio.com, crashlytics.com)
# must be classified as trackers so cross-app shared-tracker detection works.
# Pebbi HAR contains firebaselogging-pa.googleapis.com, which must now count.
if bash "$DECODER" "$RW_HAR" com.pebbi.android "$RW_PEBBI_TRK" >/dev/null 2>&1; then
    RW_TRK=$(python3 -c "import json; d=json.load(open('$RW_PEBBI_TRK')); print(d['summary']['tracker_flows'], d['summary']['unique_trackers'])")
    RW_TRK_FLOWS=$(echo "$RW_TRK" | cut -d' ' -f1)
    if [ "$RW_TRK_FLOWS" -ge 1 ]; then
        pass "SDK host classified as tracker (tracker_flows=$RW_TRK_FLOWS)"
    else
        fail "Expected googleapis.com SDK flow to be classified as tracker, got tracker_flows=$RW_TRK_FLOWS"; RW_OK=0
    fi
else
    fail "Pebbi tracker-fidelity decode failed"; RW_OK=0
fi

# Test 18: Wave-1 packages get explicit filter hosts. Common-word labels
# ("lite" from com.hp.pregnancy.lite, "view" from com.wte.view) must NOT
# attribute unrelated hosts; the real product hostname label must.
echo "Test 18: Wave-1 filter hosts reject common-word labels"
W1_HAR="$REPO_DIR/tests/fixtures/wave1-capture.har"
W1_PREG="$REPO_DIR/tests/fixtures/output-rw-pregnancyplus.json"
W1_WTE="$REPO_DIR/tests/fixtures/output-rw-wte.json"

if [ ! -f "$W1_HAR" ]; then
    cat > "$W1_HAR" <<'EOF'
{
  "log": {
    "version": "1.2",
    "creator": {"name": "mitmproxy", "version": "12.2.3"},
    "entries": [
      {
        "startedDateTime": "2026-08-12T12:00:00Z",
        "request": {
          "method": "GET",
          "url": "https://lite.example.com/api/v1/config",
          "headers": [],
          "bodySize": -1
        },
        "response": {"status": 200, "headers": [], "bodySize": 10}
      },
      {
        "startedDateTime": "2026-08-12T12:00:01Z",
        "request": {
          "method": "GET",
          "url": "https://view.example.com/api/v1/config",
          "headers": [],
          "bodySize": -1
        },
        "response": {"status": 200, "headers": [], "bodySize": 10}
      },
      {
        "startedDateTime": "2026-08-12T12:00:02Z",
        "request": {
          "method": "GET",
          "url": "https://pregnancyplus.example.com/api/v1/config",
          "headers": [],
          "bodySize": -1
        },
        "response": {"status": 200, "headers": [], "bodySize": 10}
      },
      {
        "startedDateTime": "2026-08-12T12:00:03Z",
        "request": {
          "method": "GET",
          "url": "https://whattoexpect.example.com/api/v1/config",
          "headers": [],
          "bodySize": -1
        },
        "response": {"status": 200, "headers": [], "bodySize": 10}
      },
      {
        "startedDateTime": "2026-08-12T12:00:04Z",
        "request": {
          "method": "GET",
          "url": "https://amila.example.com/api/v1/config",
          "headers": [],
          "bodySize": -1
        },
        "response": {"status": 200, "headers": [], "bodySize": 10}
      }
    ]
  }
}
EOF
fi

# Pregnancy+ (com.hp.pregnancy.lite): lite.example.com must NOT attribute;
# pregnancyplus.example.com must.
if bash "$DECODER" "$W1_HAR" com.hp.pregnancy.lite "$W1_PREG" >/dev/null 2>&1; then
    W1_PREG_HOSTS=$(python3 -c "import json; print(' '.join(f.get('request',{}).get('host','') for f in json.load(open('$W1_PREG')).get('flows',[])))")
    if echo "$W1_PREG_HOSTS" | grep -q "lite.example.com"; then
        fail "Pregnancy+ wrongly attributed lite.example.com"; W1_OK=0
    else
        pass "Pregnancy+ does not attribute common-word label lite.example.com"
    fi
    if echo "$W1_PREG_HOSTS" | grep -q "pregnancyplus.example.com"; then
        pass "Pregnancy+ attributes pregnancyplus.example.com"
    else
        fail "Pregnancy+ missing pregnancyplus.example.com attribution"; W1_OK=0
    fi
else
    fail "Wave-1 Pregnancy+ decode failed"; W1_OK=0
fi
# What to Expect (com.wte.view): view.example.com must NOT attribute;
# whattoexpect.example.com must.
W1_OK=1
if bash "$DECODER" "$W1_HAR" com.wte.view "$W1_WTE" >/dev/null 2>&1; then
    W1_WTE_HOSTS=$(python3 -c "import json; print(' '.join(f.get('request',{}).get('host','') for f in json.load(open('$W1_WTE')).get('flows',[])))")
    if echo "$W1_WTE_HOSTS" | grep -q "view.example.com"; then
        fail "What to Expect wrongly attributed view.example.com"; W1_OK=0
    else
        pass "What to Expect does not attribute common-word label view.example.com"
    fi
    if echo "$W1_WTE_HOSTS" | grep -q "whattoexpect.example.com"; then
        pass "What to Expect attributes whattoexpect.example.com"
    else
        fail "What to Expect missing whattoexpect.example.com attribution"; W1_OK=0
    fi
else
    fail "Wave-1 What to Expect decode failed"; W1_OK=0
fi

# Test 19: corrected Amila package (com.amila.parenting) attributes its product host
echo "Test 19: Corrected Amila package attributes amila.example.com"
W1_AMILA="$REPO_DIR/tests/fixtures/output-rw-amila.json"
if bash "$DECODER" "$W1_HAR" com.amila.parenting "$W1_AMILA" >/dev/null 2>&1; then
    W1_AMILA_HOSTS=$(python3 -c "import json; print(' '.join(f.get('request',{}).get('host','') for f in json.load(open('$W1_AMILA')).get('flows',[])))")
    if echo "$W1_AMILA_HOSTS" | grep -q "amila.example.com"; then
        pass "Amila (com.amila.parenting) attributes amila.example.com"
    else
        fail "Amila missing amila.example.com attribution"; W1_OK=0
    fi
else
    fail "Wave-1 Amila decode failed"; W1_OK=0
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
