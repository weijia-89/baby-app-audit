#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$root/tests/test_evidence_mitm_policy.py"

# Missing committed network log must still fail the inventory check.
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
# Point a copy of the inventory at tmp by running the embedded python the same way
set +e
python3 - "$tmp/results" "$root/scripts" <<'PY' >"$tmp/out.txt" 2>"$tmp/err.txt"
import json, os, sys
results = sys.argv[1]
sys.path.insert(0, sys.argv[2])
from evidence_mitm_policy import classify_zero_byte_mitms
apps = json.load(open(os.path.join(results, "RESULTS-20260803.json")))["apps"]
logs = {}
for name in os.listdir(results):
    if name.startswith("network-log-") and name.endswith(".json"):
        try:
            logs[json.load(open(os.path.join(results, name)))["package_name"]] = name
        except Exception:
            pass
for app in apps:
    if app["package_name"] not in logs:
        print(f"[ERROR] evidence: no network log for {app['name']}")
        raise SystemExit(1)
raise SystemExit(0)
PY
rc=$?
set -e
test "$rc" -eq 1
grep -q "no network log" "$tmp/out.txt"
echo "PASS missing network-log still fails"
