#!/usr/bin/env bash
# Tests for compare-apps.sh.
# Usage: bash tests/test-compare-apps.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COMPARER="$REPO_DIR/scripts/compare-apps.sh"
FAILED=0

# Prefer venv python when present (jsonschema).
if [ -f "$REPO_DIR/.test-venv/bin/python" ]; then
    PYTHON="$REPO_DIR/.test-venv/bin/python"
else
    PYTHON="python3"
fi

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

cleanup() {
    rm -f "$REPO_DIR/tests/fixtures/app-a-$$.json"
    rm -f "$REPO_DIR/tests/fixtures/app-b-$$.json"
    rm -f "$REPO_DIR/tests/fixtures/app-c-$$.json"
    rm -f "$REPO_DIR/tests/fixtures/app-invalid-$$.json"
    rm -f "$REPO_DIR/tests/fixtures/compare-output-$$.json"
}
trap cleanup EXIT

mkdir -p "$REPO_DIR/tests/fixtures"

echo "=== compare-apps.sh unit tests ==="

# Test 1: Missing arguments
echo "Test 1: Missing arguments"
if bash "$COMPARER" 2>/dev/null; then
    fail "Should exit with error on missing args"
else
    pass "Exits with error on missing args"
fi

# Test 2: Nonexistent JSON file
echo "Test 2: Nonexistent JSON file"
if bash "$COMPARER" /nonexistent/app.json 2>/dev/null; then
    fail "Should exit with error on missing file"
else
    pass "Exits with error on missing file"
fi

# Test 3: Shared tracker detected
echo "Test 3: Detects shared tracker across apps"
cat > "$REPO_DIR/tests/fixtures/app-a-$$.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.a",
  "capture_timestamp": "2026-08-01T00:00:00Z",
  "flows": [],
  "summary": {
    "total_flows": 5,
    "tracker_flows": 2,
    "unique_destinations": ["firebase.google.com", "example.com"],
    "unique_trackers": ["Firebase"]
  },
  "product_metadata": {
    "regulatory_regime": "COPPA"
  }
}
EOF
cat > "$REPO_DIR/tests/fixtures/app-b-$$.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.b",
  "capture_timestamp": "2026-08-01T00:00:00Z",
  "flows": [],
  "summary": {
    "total_flows": 3,
    "tracker_flows": 1,
    "unique_destinations": ["firebase.google.com", "other.com"],
    "unique_trackers": ["Firebase"]
  },
  "product_metadata": {
    "regulatory_regime": "GDPR"
  }
}
EOF
OUTPUT="$REPO_DIR/tests/fixtures/compare-output-$$.json"
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$OUTPUT" >/dev/null 2>&1; then
    if python3 -c "import json; d=json.load(open('$OUTPUT')); print('Firebase' in d.get('shared_trackers', []))" | grep -q "True"; then
        pass "Shared tracker detected"
    else
        fail "Shared tracker not detected"
    fi
else
    fail "Should succeed on valid inputs"
fi

# Test 4: Similar endpoint detected
echo "Test 4: Detects similar endpoint across apps"
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$OUTPUT" >/dev/null 2>&1; then
    HOSTS=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print([e.get('host') for e in d.get('similar_endpoints', [])])")
    if echo "$HOSTS" | grep -q "firebase.google.com"; then
        pass "Similar endpoint detected"
    else
        fail "Similar endpoint not detected - got $HOSTS"
    fi
else
    fail "Should succeed on valid inputs"
fi

# Test 5: Data volume comparison
echo "Test 5: Data volume comparison is correct"
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$OUTPUT" >/dev/null 2>&1; then
    A_FLOWS=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(d.get('data_volume', {}).get('com.example.a', {}).get('total_flows', -1))")
    B_FLOWS=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(d.get('data_volume', {}).get('com.example.b', {}).get('total_flows', -1))")
    if [ "$A_FLOWS" = "5" ] && [ "$B_FLOWS" = "3" ]; then
        pass "Data volume comparison correct"
    else
        fail "Data volume incorrect: A=$A_FLOWS B=$B_FLOWS"
    fi
else
    fail "Should succeed on valid inputs"
fi

# Test 6: JSON output validates against schema (requires jsonschema)
echo "Test 6: Output validates against schema"
if python3 -c "import jsonschema" 2>/dev/null; then
    SCHEMA="$REPO_DIR/results/comparison.schema.json"
    if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$OUTPUT" >/dev/null 2>&1; then
        if $PYTHON -c "import json, jsonschema; schema=json.load(open('$SCHEMA')); data=json.load(open('$OUTPUT')); jsonschema.validate(data, schema)" 2>/dev/null; then
            pass "Output conforms to schema"
        else
            fail "Output does not conform to schema"
        fi
    else
        fail "Should succeed and produce schema-valid output"
    fi
else
    pass "Skipped - jsonschema not installed"
fi

# Test 7: Three apps comparison works
echo "Test 7: Three apps comparison works"
cat > "$REPO_DIR/tests/fixtures/app-c-$$.json" <<'EOF'
{
  "$schema": "decode-traffic/2.0",
  "schema_version": "2.0",
  "package_name": "com.example.c",
  "capture_timestamp": "2026-08-01T00:00:00Z",
  "flows": [],
  "summary": {
    "total_flows": 10,
    "tracker_flows": 0,
    "unique_destinations": ["example.com"],
    "unique_trackers": []
  },
  "product_metadata": {
    "regulatory_regime": "MDR"
  }
}
EOF
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$REPO_DIR/tests/fixtures/app-c-$$.json" "$OUTPUT" >/dev/null 2>&1; then
    APP_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d.get('apps', [])))" 2>/dev/null) || APP_COUNT=""
    if [ "$APP_COUNT" = "3" ]; then
        pass "Three-app comparison works"
    else
        fail "Expected 3 apps, got $APP_COUNT"
    fi
else
    fail "Should succeed with three apps"
fi

# Test 8: Single app rejection
echo "Test 8: Rejects single app input"
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-a-$$.json" 2>/dev/null; then
    fail "Should reject single app input"
else
    pass "Rejects single app input"
fi

# Test 9: Invalid JSON structure rejection
echo "Test 9: Rejects JSON with missing required fields"
cat > "$REPO_DIR/tests/fixtures/app-invalid-$$.json" <<'EOF'
{
  "valid_json": true,
  "but_missing": "required_fields"
}
EOF
if bash "$COMPARER" "$REPO_DIR/tests/fixtures/app-invalid-$$.json" "$REPO_DIR/tests/fixtures/app-b-$$.json" "$OUTPUT" 2>/dev/null; then
    fail "Should reject JSON with missing required fields"
else
    pass "Rejects JSON with missing required fields"
fi

# Test 10: --version flag
echo "Test 10: --version flag"
VERSION=$(bash "$COMPARER" --version 2>/dev/null)
if [ "$VERSION" = "1.0" ]; then
    pass "Version flag returns correct version"
else
    fail "Version flag returned '$VERSION', expected '1.0'"
fi

# Test 11: Integration with decode-traffic output
echo "Test 11: Integration with decode-traffic.sh output"
# Decode the committed test-capture.har.
HAR_FILE="$REPO_DIR/tests/fixtures/test-capture.har"
if [ -f "$HAR_FILE" ]; then
    DECODED_A="$REPO_DIR/tests/fixtures/decoded-a-$$.json"
    DECODED_B="$REPO_DIR/tests/fixtures/decoded-b-$$.json"
    bash "$REPO_DIR/scripts/decode-traffic.sh" "$HAR_FILE" com.pebbi.android "$DECODED_A" >/dev/null 2>&1 || true
    bash "$REPO_DIR/scripts/decode-traffic.sh" "$HAR_FILE" com.pebbi.android "$DECODED_B" >/dev/null 2>&1 || true
    if [ -f "$DECODED_A" ] && [ -f "$DECODED_B" ]; then
        if bash "$COMPARER" "$DECODED_A" "$DECODED_B" "$OUTPUT" >/dev/null 2>&1; then
            pass "Integration with decode-traffic.sh works"
        else
            fail "Integration with decode-traffic.sh failed"
        fi
    else
        pass "Integration test skipped (decode-traffic.sh dependency missing)"
    fi
    rm -f "$DECODED_A" "$DECODED_B"
else
    pass "Integration test skipped (test-capture.har not found)"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
