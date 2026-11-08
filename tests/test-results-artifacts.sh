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
# Claim axes are stored on the result row. privacy_class is derived from the
# capture log, not from a report emoji. origin "app" is the package header
# alone, and that label never promotes. Body key names are not values: a
# packageName key in a scrubbed log does not show that the value names the app.
AXES = {"pass", "fail", "untested", "not-assessable", "inconclusive"}

def derived_privacy_class(log):
    for flow in log.get("flows", []):
        if "uid" in flow and flow.get("uid") not in (None, "", -1):
            return "major"
        if flow.get("r4"):
            return "major"
    return "untested"

assert derived_privacy_class({"flows": [{"uid": 10001}]}) == "major"
assert derived_privacy_class({"flows": [{"r4": "Uploading data. app"}]}) == "major"
assert derived_privacy_class({"flows": [{"origin": "app"}]}) == "untested"
assert derived_privacy_class({"flows": []}) == "untested"

apps = {app["name"]: app for app in results["apps"]}
assert len(results["apps"]) == 16, "result list contains duplicate or missing app records"
assert analytics["scope"]["apps_scanned"] == 16
assert analytics["scope"]["calls_scanned"] > 0
assert any(v["vendor"] == "Unclassified host" for v in analytics["vendors"])
assert all(call["sent_call"] is True for app in analytics["apps"] for call in app["calls"])

assert {name: app["evidence_source"] for name, app in apps.items()} == {
    "BabyCenter": "raw-replay", "BellyBloom": "raw-replay", "Nanit": "raw-replay",
    "Pregnancy+": "raw-replay", "What to Expect": "raw-replay", "Heartful Baby": "raw-replay",
    "Nara": "raw-replay", "Pixy": "raw-replay",
    "Nurture Lock": "raw-replay", "Nubo": "raw-replay", "Pebbi": "raw-replay",
    "Amila": "raw-replay", "Baby Buddy": "session-summary",
    "Baby Daybook": "raw-replay", "Baby+": "raw-replay", "MimiLog": "session-summary",
}

env = results["test_environment"]
assert "android_api_level" not in env, "run-level API integer cannot describe mixed captures"
note = env.get("api_level", "")
assert "API 29" in note and "2026-08-14" in note and "unknown" in note, note
objection = env.get("tool_versions", {}).get("objection", "")
assert "system certificate installed" not in objection, objection
for app in apps.values():
    assert app["verdict"] in AXES, app["name"]
    assert "verdict_confidence" not in app, app["name"]
    assert app.get("gate") == "G1-G10 not stored", app["name"]

network_schema = json.loads((root / "results/network-log.schema.json").read_text())
assert network_schema["properties"]["flows"]["items"]["properties"]["status"] == {
    "oneOf": [{"type": "integer"}, {"const": "unknown"}]
}

report = (root / "FINAL-REPORT.md").read_text()
readme = (root / "README.md").read_text()
header = "| App | Privacy claim | Axis | Gate | Key findings |"
assert header in report, "FINAL-REPORT verdict table has no axis column"
assert header in readme, "README verdict table has no axis column"

def first_verdict_rows(text):
    rows = {}
    in_table = False
    for line in text.splitlines():
        if line.strip() == header:
            in_table = True
            continue
        if not in_table:
            continue
        if not line.startswith("|"):
            break
        cells = [cell.strip() for cell in line.split("|")]
        name = cells[1] if len(cells) > 1 else ""
        if name in ("App", "") or set(name) <= {"-", " "}:
            continue
        rows.setdefault(name, (line.strip(), cells))
    return rows

report_rows = first_verdict_rows(report)
readme_rows = first_verdict_rows(readme)
forbidden = (
    "sent nothing",
    "no data was exchanged",
    "screens, taps",
    "upload-asset",
    "app embeds Clarity",
    "origin app",
)
for name in apps:
    assert name in report_rows, f"FINAL-REPORT verdict table missing {name}"
    assert name in readme_rows, f"README verdict table missing {name}"
    assert report_rows[name][0] == readme_rows[name][0], (
        f"verdict row drift for {name}\nreport: {report_rows[name][0]}\nreadme: {readme_rows[name][0]}"
    )
    cells = report_rows[name][1]
    assert len(cells) >= 6, name
    assert cells[3] == apps[name]["verdict"], f"{name} axis {cells[3]!r} != {apps[name]['verdict']!r}"
    assert cells[4] == apps[name]["gate"], name
    assert "%" not in cells[3] and "%" not in cells[4], name
    for phrase in forbidden:
        assert phrase not in report_rows[name][0], f"{name} prints {phrase}"

required = (
    "Insufficient attribution",
    "The Clarity config endpoint was fetched; the project config enables capture features.",
    "Clarity collect call(s) observed; contents not assessable (body not JSON-parseable).",
    "One Clarity asset-upload call observed; content not decoded.",
    "Unattributed Clarity traffic in window; source unresolved.",
    "pebbi-tcpdump-coldstart.pcap",
    "2026-10-04 mitm-only window is untested",
    "RTDB hosts only; flags not stored",
    "localhost Django",
)
for phrase in required:
    assert phrase in report, phrase
    assert phrase in readme, phrase

for label, text in (("FINAL-REPORT.md", report), ("README.md", readme)):
    for line in text.splitlines():
        if "Firebase" in line:
            assert "RTDB hosts only; flags not stored" in line, f"{label}: {line}"
    low = text.lower()
    for phrase in forbidden:
        assert phrase not in low, f"{label} prints {phrase}"

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
    derived = derived_privacy_class(network_logs[pkg])
    assert app["privacy_class"] == derived, (
        f"{name}: privacy_class {app['privacy_class']!r} != capture derivation {derived!r}"
    )
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
        segments = capture.split("/")
        assert ".." not in segments and "." not in segments, (
            f"{path.name}: capture path escapes results/: {capture}"
        )
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
