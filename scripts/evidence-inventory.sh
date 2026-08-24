#!/usr/bin/env bash
set -euo pipefail

# Check that evidence files still exist.
#
# Usage: scripts/evidence-inventory.sh --check
#
# Do not delete raw captures, decode files, or network logs (AGENTS.md).
# Fail if a committed network-log-<app>.json is missing.
# Zero-byte .mitm: warn only (keep failed mitmdump starts).
# Warn (do not fail) on empty decode flow lists or empty HAR files.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---check}"
[ "$MODE" = "--check" ] || {
  echo "usage: evidence-inventory.sh --check" >&2
  exit 2
}

# Test override must stay under $repo_root/.tmp.
if [ -n "${EVIDENCE_RESULTS_DIR:-}" ]; then
  results="$(cd "$EVIDENCE_RESULTS_DIR" && pwd)"
  tmp_root="$(cd "$repo_root/.tmp" 2>/dev/null && pwd)" || {
    echo "[ERROR] evidence: EVIDENCE_RESULTS_DIR set but $repo_root/.tmp is missing" >&2
    exit 1
  }
  case "$results" in
    "$tmp_root"/*) ;;
    *)
      echo "[ERROR] evidence: EVIDENCE_RESULTS_DIR must be under $tmp_root" >&2
      exit 1
      ;;
  esac
else
  results="$repo_root/results"
fi
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
        path = os.path.join(results, name)
        try:
            pkg = json.load(open(path))["package_name"]
        except (OSError, ValueError, KeyError, TypeError) as exc:
            print(f"[WARN] evidence: unreadable network log {name}: {exc}", file=sys.stderr)
            continue
        if pkg in logs:
            print(
                f"[WARN] evidence: duplicate package_name {pkg} in {logs[pkg]} and {name}",
                file=sys.stderr,
            )
        logs[pkg] = name

for app in apps:
    pkg = app["package_name"]
    if pkg not in logs:
        print(
            f"[ERROR] evidence: no network log for {app['name']} ({pkg}) - committed artifact missing",
            file=sys.stderr,
        )
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
        if not os.path.isfile(fpath):
            continue
        try:
            size = os.path.getsize(fpath)
        except OSError as exc:
            print(f"[WARN] evidence: cannot stat {entry}/{fname}: {exc}")
            continue
        if fname.lower().endswith(".mitm"):
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
                fpath = os.path.join(capdir, fname)
                try:
                    if (
                        os.path.isfile(fpath)
                        and fname.lower().endswith(".mitm")
                        and os.path.getsize(fpath) > 0
                    ):
                        raw_preserved.add(entry.split("-test-")[0].lower())
                except OSError:
                    continue
for fname in sorted(os.listdir(results)):
    if not fname.startswith("decode-traffic-") or not fname.endswith(".json"):
        continue
    try:
        flows = json.load(open(os.path.join(results, fname))).get("flows", [])
    except (OSError, ValueError, TypeError):
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
