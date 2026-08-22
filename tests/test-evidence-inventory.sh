#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$root/tests/test_evidence_mitm_policy.py"

# Missing committed network log must still fail the real inventory script.
tmp="$(mktemp -d "$root/.tmp/evidence-missing-log-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
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
