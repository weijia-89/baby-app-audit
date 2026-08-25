#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The committed analytics fanout must match what the scanner produces from
# the committed network logs. A stale fanout (logs rebuilt after the last
# regen) fails here instead of drifting silently.
tmp_fanout="$(mktemp "${TMPDIR:-/tmp}/analytics-fresh.XXXXXX.json")"
trap 'rm -f "$tmp_fanout"' EXIT
bash "$repo_root/scripts/scan-analytics-pii.sh" "$repo_root/results" "$tmp_fanout" > /dev/null

REPO_ROOT="$repo_root" TMP_FANOUT="$tmp_fanout" python3 - <<'PY'
import json
import os

root = os.environ["REPO_ROOT"]
committed = json.loads(open(os.path.join(root, "results/analytics-pii-20260803.json")).read())
fresh = json.loads(open(os.environ["TMP_FANOUT"]).read())
assert committed == fresh, (
    "results/analytics-pii-20260803.json is stale: rerun "
    "`bash scripts/scan-analytics-pii.sh results/ results/analytics-pii-20260803.json` "
    "after any network-log rebuild"
)
PY

REPO_ROOT="$repo_root" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["REPO_ROOT"])
results = json.loads((root / "results/RESULTS-20260803.json").read_text())
analytics = json.loads((root / "results/analytics-pii-20260803.json").read_text())
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
    "BabyCenter": "major",
    "BellyBloom": "major",
    "Nanit": "major",
    "Pregnancy+": "major",
    "What to Expect": "major",
}

apps = {app["name"]: app for app in results["apps"]}
assert len(results["apps"]) == len(expected), "result list contains duplicate or missing app records"
assert set(apps) == set(expected), f"unexpected app set: {sorted(apps)}"
assert {name: app["privacy_class"] for name, app in apps.items()} == expected
assert all((app["verdict"] == "pass") == (app["privacy_class"] == "pass") for app in apps.values())
assert analytics["scope"]["apps_scanned"] == len(expected)
assert analytics["scope"]["calls_scanned"] > 0
assert any(v["vendor"] == "Unclassified host" for v in analytics["vendors"])
assert all(call["sent_call"] is True for app in analytics["apps"] for call in app["calls"])

assert {name: app["evidence_source"] for name, app in apps.items()} == {
    "BabyCenter": "raw-replay", "BellyBloom": "raw-replay", "Nanit": "raw-replay",
    "Pregnancy+": "raw-replay", "What to Expect": "raw-replay", "Heartful Baby": "raw-replay",
    "Nara": "raw-replay", "Pixy": "raw-replay",
    "Nurture Lock": "session-summary", "Nubo": "raw-replay", "Pebbi": "session-summary",
    "Amila": "raw-replay", "Baby Buddy": "session-summary",
    "Baby Daybook": "session-summary", "Baby+": "raw-replay", "MimiLog": "session-summary",
}

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
    log["package_name"]: log
    for log in (
        json.loads(p.read_text())
        for p in sorted((root / "results").glob("network-log-*.json"))
    )
}
for name, app in apps.items():
    dests = app.get("offline_test", {}).get("outbound_destinations", [])
    pkg = app["package_name"]
    assert pkg in network_logs, f"no network log for {name} ({pkg})"
    assert set(dests) <= set(network_logs[pkg]["summary"]["unique_destinations"]), (
        f"{name}: offline_test destination not in network log"
    )
    flow_file = app.get("offline_test", {}).get("flow_file", "")
    if flow_file.endswith(".mitm"):
        total = network_logs[pkg]["summary"]["total_flows"]
        count = app.get("offline_test", {}).get("outbound_requests_count")
        assert count == total, (
            f"{name}: outbound_requests_count {count} != {flow_file} replay total {total}"
        )

# A capture path written into a committed log must exist with exact casing.
# A case-insensitive laptop filesystem hides this; a Linux checkout does not.
# Capture trees are local-only (gitignored), so a missing directory skips:
# CI checkouts never carry raw captures. When the directory IS present, the
# committed name must match an entry exactly.
for path in sorted((root / "results").glob("network-log-*.json")):
    log = json.loads(path.read_text())
    capture = log.get("capture", "")
    if capture.startswith("results/") and " " not in capture:
        parent, name = os.path.split(capture)
        parent_dir = root / parent
        if not parent_dir.is_dir():
            continue
        assert name in os.listdir(parent_dir), (
            f"{path.name}: capture path does not exist (exact case): {capture}"
        )

for log in (
    json.loads(p.read_text())
    for p in sorted((root / "results").glob("network-log-*.json"))
):
    flows = log["flows"]
    if not flows or "request" not in flows[0]:
        continue
    for flow in flows:
        assert flow["origin"] in ("app", "device", "session"), (
            f"{log['app']}: bad origin {flow['origin']}"
        )
        assert "?" not in flow["path"], f"{log['app']}: query string in path"
        assert "[REDACTED]" not in flow["host"], f"{log['app']}: redacted host"
        assert "count" in flow and flow["count"] >= 1, (
            f"{log['app']}: missing or zero count"
        )
        for side in ("request", "response"):
            detail = flow.get(side) or {}
            assert "size" in detail and "content_type" in detail, (
                f"{log['app']}: {side} detail incomplete"
            )
            assert isinstance(detail["size"], int) and not isinstance(detail["size"], bool), (
                f"{log['app']}: {side} size not an integer"
            )
            assert detail["content_type"] is None or isinstance(detail["content_type"], str), (
                f"{log['app']}: {side} content_type not string or null"
            )
            for header in detail.get("headers", []):
                assert len(header) <= 40, (
                    f"{log['app']}: oversized header name {header!r}"
                )
PY

echo "Result artifact classification checks passed"
