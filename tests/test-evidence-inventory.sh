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

# A new window gets every canon capture-manifest field. A missing value is unknown.
set +e
bash "$root/scripts/run-tests.sh" --write-capture-manifest "$tmp2/new-window.mitm" \
  >"$tmp2/manifest-write.txt" 2>"$tmp2/manifest-write.err"
rc=$?
set -e
test "$rc" -eq 0
test -f "$tmp2/new-window.capture-manifest.json"
python3 - "$root" "$tmp2/new-window.capture-manifest.json" <<'PY'
import json, sys
root, path = sys.argv[1:]
canon = [
    "avd_image", "api_level", "system_ca_present", "http_proxy_readback",
    "r1_mode", "pcapdroid_version", "uid_path", "app_filter", "r2_mode",
    "r3_mode", "lockdown_state", "source", "captive_portal_mode",
    "private_dns_mode", "firebase_debug_condition", "r4_log",
    "webview_version", "user_agent", "installed_packages",
    "uid_unknown_count", "conversion_events", "decoders",
]
schema = json.loads(open(root + "/results/capture-manifest.schema.json").read())
assert schema["required"] == canon, schema["required"]
assert schema.get("additionalProperties") is False
doc = json.loads(open(path).read())
assert list(doc) == canon, list(doc)
assert all(v == "unknown" for v in doc.values()), doc
print("PASS new window manifest is all unknown")
PY

# Recording a read value keeps the field and names a file.
printf '%s\n' "http_proxy=10.0.2.2:8080" >"$tmp2/proxy.log"
set +e
bash "$root/scripts/run-tests.sh" --record-manifest-field \
  "$tmp2/new-window.capture-manifest.json" http_proxy_readback \
  "10.0.2.2:8080 (source: $tmp2/proxy.log)" \
  >"$tmp2/manifest-record.txt" 2>"$tmp2/manifest-record.err"
rc=$?
set -e
test "$rc" -eq 0
python3 - "$tmp2/new-window.capture-manifest.json" <<'PY'
import json, sys
doc = json.loads(open(sys.argv[1]).read())
assert doc["http_proxy_readback"].startswith("10.0.2.2:8080 (source: ")
assert doc["api_level"] == "unknown"
print("PASS manifest field record names a file")
PY

# Committed backfill validates. A dropped field fails.
set +e
bash "$root/scripts/run-tests.sh" --check-capture-manifests \
  >"$tmp2/manifest-check.txt" 2>"$tmp2/manifest-check.err"
rc=$?
set -e
test "$rc" -eq 0
grep -q "check_capture_manifests" "$root/scripts/run-tests.sh"
python3 - "$root" <<'PY'
import json, re
from pathlib import Path
root = Path(__import__("sys").argv[1])
canon = [
    "avd_image", "api_level", "system_ca_present", "http_proxy_readback",
    "r1_mode", "pcapdroid_version", "uid_path", "app_filter", "r2_mode",
    "r3_mode", "lockdown_state", "source", "captive_portal_mode",
    "private_dns_mode", "firebase_debug_condition", "r4_log",
    "webview_version", "user_agent", "installed_packages",
    "uid_unknown_count", "conversion_events", "decoders",
]
expected = """
amila-test-20260816__amila-flow.json
amila-test-20260816__amila-inject.json
amila-test-20260816__amila.json
amila-test-20260817__Amila.json
amila-test-20260825__Amila.json
amila-test-20260825-silence__Amila-silence-tcpdump.json
amila-test-20260825-silence__Amila-silence.json
baby-buddy-test-20260803__baby-buddy.json
baby-daybook-test-20260816__baby-daybook.json
baby-daybook-test-20260817__Baby-Daybook.json
baby-daybook-test-20261004__baby-daybook.json
baby-plus-test-20260816__Baby+-about-baby-done-attempt.json
baby-plus-test-20260816__Baby+-about-you.json
baby-plus-test-20260816__Baby+.json
baby-plus-test-20260816__baby-plus.json
baby-plus-test-20260819__BabyPlus-about-you-soak.json
baby-plus-test-20260819__BabyPlus-post-done-upgrade-soak.json
baby-plus-test-20260821__BabyPlus-about-you-capture.json
baby-plus-test-20260821__BabyPlus-about-you-full.json
baby-plus-test-20260821__BabyPlus-upgrade-soak.json
baby-plus-test-20260825__BabyPlus-final.json
baby-plus-test-20260825__BabyPlus-onboard-tcpdump.json
baby-plus-test-20260825__BabyPlus-relaunch-tcpdump.json
baby-plus-test-20260825__BabyPlus-retry.json
baby-plus-test-20260825__BabyPlus.json
babycenter-test-20260814__Babycenter.json
bellybloom-test-20260814__Bellybloom.json
heartful-baby-test-20260812__Heartful-baby.json
mimilog-test-20260816__mimilog.json
mimilog-test-20260817__MimiLog-feeding.json
mimilog-test-20260817__MimiLog.json
mimilog-test-20260825__MimiLog.json
mimilog-test-20261004__mimilog.json
nanit-test-20260814__Nanit.json
nara-test-20260811__Nara.json
nara-test-20260812__Nara.json
nubo-test-20260803__nubo.json
nubo-test-20260817__Nubo.json
nubo-test-20260818-soak__Nubo-finished-use-soak.json
nubo-test-20260823__Nubo-backup-google.json
nubo-test-20260823__nubo-backup-wlan0.json
nubo-test-20260824__nubo-backup-wlan0.json
nubo-test-20260825__Nubo-pair-tcpdump.json
nubo-test-20260825__Nubo-pair.json
nurture-lock-test-20260803__nurture-lock.json
nurture-lock-test-20261004__nurture-lock.json
pebbi-test-20260816__pebbi-inject.json
pebbi-test-20260816__pebbi.json
pebbi-test-20260817__Pebbi-profile.json
pebbi-test-20260817__Pebbi.json
pebbi-test-20261004__pebbi-profile.json
pebbi-test-20261004__pebbi.json
pebbi-test-20261010__pebbi-4.4.1-full.json
pebbi-test-20261010__pebbi-tcpdump-coldstart.json
pebbi-test-20261010__pebbi.json
pixy-test-20260812__Pixy.json
pregnancyplus-test-20260814__Pregnancyplus.json
whattoexpect-test-20260814__Whattoexpect.json
""".strip().split()
man_dir = root / "results" / "capture-manifests"
got = sorted(p.name for p in man_dir.glob("*.json"))
assert got == sorted(expected), (set(expected) - set(got), set(got) - set(expected))
sourced = re.compile(r"^.+ \(source: results/[^)]+\)$")
host_tcpdump = {
    "amila-test-20260825-silence__Amila-silence-tcpdump.json",
    "baby-plus-test-20260825__BabyPlus-onboard-tcpdump.json",
    "baby-plus-test-20260825__BabyPlus-relaunch-tcpdump.json",
    "nubo-test-20260823__nubo-backup-wlan0.json",
    "nubo-test-20260824__nubo-backup-wlan0.json",
    "nubo-test-20260825__Nubo-pair-tcpdump.json",
}
for name in expected:
    doc = json.loads((man_dir / name).read_text())
    assert list(doc) == canon, name
    for key, value in doc.items():
        assert isinstance(value, str), (name, key)
        if value == "unknown":
            continue
        assert sourced.match(value), (name, key, value)
        assert "RESULTS-20260803.json" not in value, (name, key)
        assert "android_api_level" not in value, (name, key)
    assert doc["avd_image"] == "unknown", name
    assert doc["system_ca_present"] == "unknown", name
    ua = doc["user_agent"]
    api = doc["api_level"]
    if "Android 10" in ua:
        assert api.startswith("29 (source: "), (name, api)
        assert "; wv)" not in ua, name
    if "Android 9" in ua:
        assert api.startswith("28 (source: "), (name, api)
    if name in host_tcpdump:
        assert doc["r2_mode"].startswith("host_tcpdump (source: "), name
        assert doc["r2_mode"].endswith(".pcap)"), name
    else:
        assert doc["r2_mode"] == "unknown", name
bc = json.loads((man_dir / "babycenter-test-20260814__Babycenter.json").read_text())
wte = json.loads((man_dir / "whattoexpect-test-20260814__Whattoexpect.json").read_text())
for doc, har_name in ((bc, "Babycenter.har"), (wte, "Whattoexpect.har")):
    assert doc["api_level"].startswith("29 (source: ")
    assert har_name in doc["api_level"]
    assert har_name in doc["user_agent"]
    assert "Dalvik/2.1.0" in doc["user_agent"]
    assert "Android 10" in doc["user_agent"]
    assert "; wv)" not in doc["user_agent"]
pixy = json.loads((man_dir / "pixy-test-20260812__Pixy.json").read_text())
assert pixy["api_level"].startswith("28 (source: ")
assert "Pixy.har" in pixy["api_level"]
assert "Android 9" in pixy["user_agent"]
pebbi = json.loads((man_dir / "pebbi-test-20261010__pebbi-tcpdump-coldstart.json").read_text())
assert pebbi["r2_mode"] == "unknown"
for log in (root / "results").glob("network-log-*.json"):
    capture = json.loads(log.read_text()).get("capture", "")
    rel = capture.removeprefix("results/")
    testdir = rel.split("/")[0]
    stem = Path(rel).stem
    assert (man_dir / f"{testdir}__{stem}.json").is_file(), capture
print("PASS backfill manifests match the captures")
PY

python3 - "$tmp2" "$root/results/capture-manifest.schema.json" <<'PY'
import json, sys
from pathlib import Path
tmp = Path(sys.argv[1])
schema = json.loads(Path(sys.argv[2]).read_text())
bad_dir = tmp / "bad-manifests"
bad_dir.mkdir()
doc = {k: "unknown" for k in schema["required"]}
doc.pop("api_level")
(bad_dir / "broken.json").write_text(json.dumps(doc))
print(bad_dir)
PY
set +e
CAPTURE_MANIFEST_DIR="$tmp2/bad-manifests" bash "$root/scripts/run-tests.sh" --check-capture-manifests \
  >"$tmp2/manifest-bad.txt" 2>"$tmp2/manifest-bad.err"
rc=$?
set -e
test "$rc" -eq 1
echo "PASS capture manifest rejects a dropped field"
