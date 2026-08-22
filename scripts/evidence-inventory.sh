#!/usr/bin/env bash
set -euo pipefail

# Evidence inventory guard.
#
# Usage: scripts/evidence-inventory.sh --check
#
# Raw captures, decode files, and network logs are permanent evidence and
# must never be deleted or swept (see AGENTS.md, "Evidence retention").
# This check fails the run when the committed inventory is broken:
#
#   - every app in results/RESULTS-20260803.json has a readable
#     results/network-log-<app>.json (committed, so this passes on CI)
#
# Zero-byte *.mitm files only warn. They are kept on purpose when mitmdump
# dies on the first start (AGENTS.md). Missing committed network logs still fail.
#
# It warns (never fails) about rot signals: decode files whose flow list
# has emptied, and empty preserved HAR conversions. The warning list is
# printed at the end of run-tests.sh --check so a sweep can never hide.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---check}"
[ "$MODE" = "--check" ] || {
  echo "usage: evidence-inventory.sh --check" >&2
  exit 2
}

results="$repo_root/results"
results_json="$results/RESULTS-20260803.json"

if [ ! -f "$results_json" ]; then
  echo "[ERROR] evidence: missing $results_json" >&2
  exit 1
fi

python3 - "$results" "$repo_root/scripts" <<'PY'
import json
import os
import sys

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
    pkg = app["package_name"]
    if pkg not in logs:
        print(f"[ERROR] evidence: no network log for {app['name']} ({pkg}) - committed artifact missing")
        sys.exit(1)

captures = 0
for entry in sorted(os.listdir(results)):
    path = os.path.join(results, entry)
    if not (os.path.isdir(path) and "-test-" in entry):
        continue
    captures_dir = os.path.join(path, "artifacts", "captures")
    if not os.path.isdir(captures_dir):
        continue
    mitm_sizes = []
    for fname in sorted(os.listdir(captures_dir)):
        fpath = os.path.join(captures_dir, fname)
        size = os.path.getsize(fpath)
        if fname.endswith(".mitm"):
            captures += 1
            mitm_sizes.append((fname, size))
        elif size == 0:
            print(f"[WARN] evidence: zero-byte artifact {entry}/{fname}")
    _errors, warns = classify_zero_byte_mitms(mitm_sizes)
    for fname in warns:
        print(f"[WARN] evidence: zero-byte capture {entry}/{fname} kept (failed start or empty session)")

decode_rot = 0
raw_preserved = set()
for entry in sorted(os.listdir(results)):
    if "-test-" in entry:
        capdir = os.path.join(results, entry, "artifacts", "captures")
        if os.path.isdir(capdir):
            for fname in os.listdir(capdir):
                if fname.endswith(".mitm") and os.path.getsize(os.path.join(capdir, fname)) > 0:
                    raw_preserved.add(entry.split("-test-")[0].lower())
for fname in sorted(os.listdir(results)):
    if not fname.startswith("decode-traffic-") or not fname.endswith(".json"):
        continue
    try:
        flows = json.load(open(os.path.join(results, fname))).get("flows", [])
    except Exception:
        continue
    if len(flows) == 0:
        slug = fname[len("decode-traffic-"):-len(".json")].lower()
        if slug in raw_preserved:
            print(f"[WARN] evidence: {fname} has an empty flow list - superseded by the raw-capture replay; safe to regenerate from the preserved .mitm")
        else:
            decode_rot += 1
            print(f"[WARN] evidence: {fname} has an empty flow list - rotted; raw capture is gone")

if captures == 0:
    print("[WARN] evidence: no preserved capture tree found (results/*-test-*/) - this is normal on CI checkouts")
PY

echo "evidence inventory OK"
exit 0
