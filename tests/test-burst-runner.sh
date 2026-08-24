#!/usr/bin/env bash
# Tests for the burst runner.
# Usage: bash tests/test-burst-runner.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RUNNER="$REPO_DIR/localonly/bursts/run-burst.sh"
FAILED=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

echo "=== Burst Runner Tests ==="

# Test 1: Missing arguments
echo "Test 1: Missing arguments"
if bash "$RUNNER" 2>/dev/null; then
    fail "Should exit with error on missing args"
else
    pass "Exits with error on missing args"
fi

# Test 2: Invalid burst number (non-numeric)
echo "Test 2: Non-numeric burst number"
if bash "$RUNNER" "abc" 2>/dev/null; then
    fail "Should exit with error on non-numeric burst number"
else
    pass "Exits with error on non-numeric burst number"
fi

# Test 3: Nonexistent burst config
echo "Test 3: Nonexistent burst config"
if bash "$RUNNER" "999" 2>/dev/null; then
    fail "Should exit with error on missing config"
else
    pass "Exits with error on missing config"
fi

# Test 4: Dry run with valid burst config
echo "Test 4: Dry run with valid burst config"
if BURST_DRY_RUN=1 bash "$RUNNER" "1" >/dev/null 2>&1; then
    pass "Dry run succeeds with valid config"
else
    fail "Dry run failed with valid config"
fi

# Test 5: Config with malformed app entry (wrong field count)
echo "Test 5: Malformed app config"
TEMP_CONFIG=$(mktemp /tmp/burst-test-XXXXXX.sh)
cat > "$TEMP_CONFIG" <<'EOF'
BURST_NUMBER="99"
BURST_NAME="Test Burst"
BURST_DATE="2026-08-06"
BURST_APPS=(
    "bad-entry|only-two-fields"
)
EOF
mkdir -p "$REPO_DIR/localonly/bursts"
cp "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-99-config.sh"
if BURST_DRY_RUN=1 bash "$RUNNER" "99" 2>/dev/null; then
    fail "Should exit with error on malformed app config"
else
    pass "Exits with error on malformed app config"
fi
rm -f "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-99-config.sh"

# Test 6: Config with invalid slug
echo "Test 6: Invalid slug characters"
TEMP_CONFIG=$(mktemp /tmp/burst-test-XXXXXX.sh)
cat > "$TEMP_CONFIG" <<'EOF'
BURST_NUMBER="98"
BURST_NAME="Test Burst"
BURST_DATE="2026-08-06"
BURST_APPS=(
    "bad/slug|com.test.app|native|Test"
)
EOF
cp "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-98-config.sh"
if BURST_DRY_RUN=1 bash "$RUNNER" "98" 2>/dev/null; then
    fail "Should exit with error on invalid slug"
else
    pass "Exits with error on invalid slug"
fi
rm -f "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-98-config.sh"

# Test 7: Config with invalid package name
echo "Test 7: Invalid package name"
TEMP_CONFIG=$(mktemp /tmp/burst-test-XXXXXX.sh)
cat > "$TEMP_CONFIG" <<'EOF'
BURST_NUMBER="97"
BURST_NAME="Test Burst"
BURST_DATE="2026-08-06"
BURST_APPS=(
    "testapp|not.a.valid.package.name!|native|Test"
)
EOF
cp "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-97-config.sh"
if BURST_DRY_RUN=1 bash "$RUNNER" "97" 2>/dev/null; then
    fail "Should exit with error on invalid package name"
else
    pass "Exits with error on invalid package name"
fi
rm -f "$TEMP_CONFIG" "$REPO_DIR/localonly/bursts/burst-97-config.sh"

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
