#!/usr/bin/env bash
# Unit tests for detect-dark-patterns.sh
# Usage: bash tests/test-dark-patterns.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DETECTOR="$REPO_DIR/scripts/detect-dark-patterns.sh"
FAILED=0

# Use venv python if available (for jsonschema)
if [ -f "$REPO_DIR/.test-venv/bin/python" ]; then
    PYTHON="$REPO_DIR/.test-venv/bin/python"
else
    PYTHON="python3"
fi

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

cleanup() {
    rm -rf "$REPO_DIR/tests/fixtures/dark-pattern-apk"
    rm -f "$REPO_DIR/tests/fixtures/dark-patterns-output.json"
    rm -f "$REPO_DIR/tests/fixtures/dark-patterns-bad.json"
}
trap cleanup EXIT

mkdir -p "$REPO_DIR/tests/fixtures"

echo "=== detect-dark-patterns.sh unit tests ==="

# Test 1: Missing arguments
echo "Test 1: Missing arguments"
if bash "$DETECTOR" 2>/dev/null; then
    fail "Should exit with error on missing args"
else
    pass "Exits with error on missing args"
fi

# Test 2: Nonexistent APK
echo "Test 2: Nonexistent APK file"
if bash "$DETECTOR" /nonexistent/app.apk 2>/dev/null; then
    fail "Should exit with error on missing APK"
else
    pass "Exits with error on missing APK"
fi

# Test 3: Pre-checked consent checkbox
echo "Test 3: Detects pre-checked consent checkbox"
APK_DIR="$REPO_DIR/tests/fixtures/dark-pattern-apk"
mkdir -p "$APK_DIR/res/layout"
cat > "$APK_DIR/res/layout/consent.xml" <<'EOF'
<LinearLayout>
    <CheckBox android:id="@+id/consent_checkbox"
              android:checked="true"
              android:text="I agree to share my data" />
</LinearLayout>
EOF
OUTPUT="$REPO_DIR/tests/fixtures/dark-patterns-output.json"
if bash "$DETECTOR" "$APK_DIR" "$OUTPUT" >/dev/null 2>&1; then
    if python3 -m json.tool "$OUTPUT" >/dev/null 2>&1; then
        if python3 -c "import json; d=json.load(open('$OUTPUT')); print(any(p.get('pattern_type')=='pre_checked_consent' for p in d.get('patterns',[])))" | grep -q "True"; then
            pass "Pre-checked consent detected"
        else
            fail "Pre-checked consent not detected"
        fi
    else
        fail "Output is not valid JSON"
    fi
else
    fail "Should succeed on valid APK directory"
fi

# Test 4: Hidden consent flow
echo "Test 4: Detects hidden consent flow"
rm -rf "$APK_DIR"
mkdir -p "$APK_DIR/res/layout"
cat > "$APK_DIR/res/layout/main.xml" <<'EOF'
<FrameLayout>
    <WebView android:id="@+id/privacy_webview"
             android:visibility="gone"
             android:layout_width="1dp"
             android:layout_height="1dp" />
</FrameLayout>
EOF
if bash "$DETECTOR" "$APK_DIR" "$OUTPUT" >/dev/null 2>&1; then
    if python3 -c "import json; d=json.load(open('$OUTPUT')); print(any(p.get('pattern_type')=='hidden_consent_flow' for p in d.get('patterns',[])))" | grep -q "True"; then
        pass "Hidden consent flow detected"
    else
        fail "Hidden consent flow not detected"
    fi
else
    fail "Should succeed on valid APK directory"
fi

# Test 5: Deceptive button order
echo "Test 5: Detects deceptive button ordering"
rm -rf "$APK_DIR"
mkdir -p "$APK_DIR/res/values"
cat > "$APK_DIR/res/values/strings.xml" <<'EOF'
<resources>
    <string name="btn_accept_all">Accept All</string>
    <string name="btn_continue">Continue</string>
    <string name="btn_maybe_later">Maybe Later</string>
</resources>
EOF
if bash "$DETECTOR" "$APK_DIR" "$OUTPUT" >/dev/null 2>&1; then
    if python3 -c "import json; d=json.load(open('$OUTPUT')); print(any(p.get('pattern_type')=='deceptive_button_order' for p in d.get('patterns',[])))" | grep -q "True"; then
        pass "Deceptive button order detected"
    else
        fail "Deceptive button order not detected"
    fi
else
    fail "Should succeed on valid APK directory"
fi

# Test 6: Output validates against schema
echo "Test 6: Output validates against schema"
rm -rf "$APK_DIR"
mkdir -p "$APK_DIR/res/layout" "$APK_DIR/res/values"
cat > "$APK_DIR/res/layout/consent.xml" <<'EOF'
<LinearLayout>
    <CheckBox android:checked="true" android:text="Agree" />
</LinearLayout>
EOF
cat > "$APK_DIR/res/values/strings.xml" <<'EOF'
<resources>
    <string name="btn_accept">Accept All</string>
</resources>
EOF
SCHEMA="$REPO_DIR/results/dark-patterns.schema.json"
if bash "$DETECTOR" "$APK_DIR" "$OUTPUT" >/dev/null 2>&1; then
    if $PYTHON -c "import json, jsonschema; schema=json.load(open('$SCHEMA')); data=json.load(open('$OUTPUT')); jsonschema.validate(data, schema)" 2>/dev/null; then
        pass "Output conforms to schema"
    else
        fail "Output does not conform to schema"
    fi
else
    fail "Should succeed and produce schema-valid output"
fi

# Test 7: No patterns found produces valid empty result
echo "Test 7: No patterns found produces valid empty result"
rm -rf "$APK_DIR"
mkdir -p "$APK_DIR/res/layout"
cat > "$APK_DIR/res/layout/main.xml" <<'EOF'
<LinearLayout>
    <TextView android:text="Hello" />
</LinearLayout>
EOF
if bash "$DETECTOR" "$APK_DIR" "$OUTPUT" >/dev/null 2>&1; then
    COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d.get('patterns', [])))" 2>/dev/null) || COUNT=""
    if [ "$COUNT" = "0" ]; then
        pass "Empty patterns array handled correctly"
    else
        fail "Expected 0 patterns, got $COUNT"
    fi
else
    fail "Should succeed even with no patterns"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
