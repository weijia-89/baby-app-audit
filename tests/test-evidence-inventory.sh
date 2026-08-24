#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/.tmp"
python3 -m py_compile "$root/scripts/evidence_mitm_policy.py"
python3 "$root/tests/test_evidence_mitm_policy.py"

# Check that CI still runs the inventory tests.
wf="$root/.github/workflows/test.yml"
grep -q 'bash -n scripts/evidence-inventory.sh' "$wf"
grep -q 'bash tests/test-evidence-inventory.sh' "$wf"
echo "PASS CI wires evidence-inventory checks"

tmp="$(mktemp -d "$root/.tmp/evidence-missing-log-XXXXXX")"
tmp2="$(mktemp -d "$root/.tmp/evidence-zero-byte-XXXXXX")"
trap 'rm -rf "$tmp" "$tmp2"' EXIT

# Missing committed network log must fail.
mkdir -p "$tmp/results"
python3 - <<PY
import json
from pathlib import Path
root = Path("$tmp/results")
(root / "RESULTS-20260803.json").write_text(json.dumps({
    "apps": [{"name": "Ghost", "package_name": "com.example.ghost"}]
}))
PY
set +e
EVIDENCE_RESULTS_DIR="$tmp/results" bash "$root/scripts/evidence-inventory.sh" --check \
  >"$tmp/out.txt" 2>"$tmp/err.txt"
rc=$?
set -e
test "$rc" -eq 1
grep -q "no network log" "$tmp/err.txt"
echo "PASS missing network-log still fails"

# Zero-byte .mitm must warn and exit 0 when network logs exist.
mkdir -p "$tmp2/results/ghost-test-20260823/artifacts/captures"
python3 - <<PY
import json
from pathlib import Path
root = Path("$tmp2/results")
(root / "RESULTS-20260803.json").write_text(json.dumps({
    "apps": [{"name": "Ghost", "package_name": "com.example.ghost"}]
}))
(root / "network-log-ghost.json").write_text(json.dumps({
    "package_name": "com.example.ghost", "flows": []
}))
(root / "ghost-test-20260823" / "artifacts" / "captures" / "Ghost.mitm").write_bytes(b"")
PY
set +e
EVIDENCE_RESULTS_DIR="$tmp2/results" bash "$root/scripts/evidence-inventory.sh" --check \
  >"$tmp2/out.txt" 2>"$tmp2/err.txt"
rc=$?
set -e
test "$rc" -eq 0
grep -q "zero-byte capture" "$tmp2/out.txt"
grep -q "evidence inventory OK" "$tmp2/out.txt"
echo "PASS zero-byte mitm warns and exits 0"

# Reject EVIDENCE_RESULTS_DIR outside .tmp.
set +e
EVIDENCE_RESULTS_DIR="/tmp" bash "$root/scripts/evidence-inventory.sh" --check \
  >"$tmp2/out-outside.txt" 2>"$tmp2/err-outside.txt"
rc=$?
set -e
test "$rc" -eq 1
grep -q "must be under" "$tmp2/err-outside.txt"
echo "PASS EVIDENCE_RESULTS_DIR outside .tmp rejected"

# Duplicate package_name must warn; exit 0 if all apps still covered.
mkdir -p "$tmp2/results-dup"
python3 - <<PY
import json
from pathlib import Path
root = Path("$tmp2/results-dup")
root.mkdir(parents=True, exist_ok=True)
(root / "RESULTS-20260803.json").write_text(json.dumps({
    "apps": [{"name": "Ghost", "package_name": "com.example.ghost"}]
}))
(root / "network-log-ghost-a.json").write_text(json.dumps({
    "package_name": "com.example.ghost", "flows": []
}))
(root / "network-log-ghost-b.json").write_text(json.dumps({
    "package_name": "com.example.ghost", "flows": []
}))
PY
set +e
EVIDENCE_RESULTS_DIR="$tmp2/results-dup" bash "$root/scripts/evidence-inventory.sh" --check \
  >"$tmp2/out-dup.txt" 2>"$tmp2/err-dup.txt"
rc=$?
set -e
test "$rc" -eq 0
grep -q "duplicate package_name" "$tmp2/err-dup.txt"
echo "PASS duplicate package_name warns"
