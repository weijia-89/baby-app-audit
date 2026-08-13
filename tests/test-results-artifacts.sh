#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPO_ROOT="$repo_root" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
results = json.loads((root / "results/RESULTS-20260803.json").read_text())
expected = {
    "Nurture Lock": "major",
    "Nubo": "major",
    "Pebbi": "major",
    "Baby Buddy": "pass",
    "Amila": "minor",
    "Baby Daybook": "major",
    "Baby+": "minor",
    "MimiLog": "pass",
    "Nara": "major",
    "Heartful Baby": "minor",
    "Pixy": "major",
}

apps = {app["name"]: app for app in results["apps"]}
assert len(results["apps"]) == len(expected), "result list contains duplicate or missing app records"
assert set(apps) == set(expected), f"unexpected app set: {sorted(apps)}"
assert {name: app["privacy_class"] for name, app in apps.items()} == expected
assert all((app["verdict"] == "pass") == (app["privacy_class"] == "pass") for app in apps.values())

network_schema = json.loads((root / "results/network-log.schema.json").read_text())
assert network_schema["properties"]["flows"]["items"]["properties"]["status"] == {
    "oneOf": [{"type": "integer"}, {"const": "unknown"}]
}

report = (root / "FINAL-REPORT.md").read_text()
for emoji in ("💖", "❕", "🚫"):
    assert emoji in report, f"missing report class {emoji}"
emoji_for = {"pass": "💖", "minor": "❕", "major": "🚫"}
report_lines = report.splitlines()
for name, cls in expected.items():
    row = next(line for line in report_lines if line.startswith(f"| {name} |"))
    assert emoji_for[cls] in row, f"report row for {name} does not show class {emoji_for[cls]}"

network_logs = {
    log["package_name"]: log["summary"]["unique_destinations"]
    for log in (
        json.loads(p.read_text())
        for p in sorted((root / "results").glob("network-log-*.json"))
    )
}
for name, app in apps.items():
    dests = app.get("offline_test", {}).get("outbound_destinations", [])
    pkg = app["package_name"]
    assert pkg in network_logs, f"no network log for {name} ({pkg})"
    assert set(dests) <= set(network_logs[pkg]), (
        f"{name}: offline_test destination not in network log"
    )
PY

echo "Result artifact classification checks passed"
