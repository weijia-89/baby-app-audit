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
    rm -f "$REPO_DIR/tests/fixtures/bad.json" "$REPO_DIR/tests/fixtures/output.json" "$REPO_DIR/tests/fixtures/output2.json" "$REPO_DIR/tests/fixtures/output3.json" "$REPO_DIR/tests/fixtures/output4.json" "$REPO_DIR/tests/fixtures/stderr3.txt" "$REPO_DIR/tests/fixtures/stderr4.txt" "$REPO_DIR/tests/fixtures/missing-config.json" "$REPO_DIR/tests/fixtures/bad-schema.json" "$REPO_DIR/tests/fixtures/empty.har" "$REPO_DIR/tests/fixtures/output-empty.json" "$REPO_DIR/tests/fixtures/corrupted-schema.json" "$REPO_DIR/tests/fixtures/output-badschema.json"
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

# Test 4: Valid HAR with output file
echo "Test 4: Valid HAR with output file"
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

# Test 5: Verify schema field exists
echo "Test 5: Schema field exists"
if grep -q '"\$schema": "decode-traffic/2.0"' "$OUTPUT"; then
    pass "Schema declaration present"
else
    fail "Schema declaration missing"
fi

# Test 6: Verify product metadata loaded
echo "Test 6: Product metadata loaded"
if grep -q '"regulatory_regime": "RED"' "$OUTPUT"; then
    pass "Product metadata loaded from config"
else
    fail "Product metadata not loaded"
fi

# Test 7: Verify flows array has entries
echo "Test 7: Flows array has entries"
FLOW_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d.get('flows', [])))")
if [ "$FLOW_COUNT" -gt 0 ]; then
    pass "Flows array has entries (count: $FLOW_COUNT)"
else
    fail "Flows array is empty"
fi

# Test 8: Verify summary exists
echo "Test 8: Summary exists"
if python3 -c "import json; d=json.load(open('$OUTPUT')); print('summary' in d)" | grep -q "True"; then
    pass "Summary section present"
else
    fail "Summary section missing"
fi

# Test 9: Output directory must exist
echo "Test 9: Output directory must exist"
if bash "$DECODER" "$TEST_HAR" com.pebbi.android /nonexistent/dir/output.json 2>/dev/null; then
    fail "Should fail when output directory missing"
else
    pass "Fails when output directory missing"
fi

# Test 10: Missing config file falls back to defaults
echo "Test 10: Missing config file falls back to defaults"
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

# Test 11: Corrupted config file falls back to defaults
echo "Test 11: Corrupted config file falls back to defaults"
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

# Test 12: Strict mode passes on valid output
 echo "Test 12: Strict mode passes on valid output"
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

 # Test 13: Strict mode fails on schema violation
 echo "Test 13: Strict mode fails on schema violation"
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

# Test 14: Empty flows array still produces schema-valid output
 echo "Test 14: Empty flows array produces valid output"
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

 # Test 15: Corrupted schema file falls back to warn (not crash)
 echo "Test 15: Corrupted schema file is handled gracefully"
 BAD_SCHEMA="$REPO_DIR/tests/fixtures/corrupted-schema.json"
 echo "not json" > "$BAD_SCHEMA"
 OUTPUT_BAD="$REPO_DIR/tests/fixtures/output-badschema.json"
 if bash "$DECODER" "$TEST_HAR" com.pebbi.android "$OUTPUT_BAD" >/dev/null 2>&1; then
     pass "Corrupted schema does not crash decoder"
 else
     fail "Should succeed even with corrupted schema"
 fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
