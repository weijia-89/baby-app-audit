#!/usr/bin/env bash
# Deterministic tests for scripts/gapps_state.py (Play-store unlock slice).
# All fixtures are captured strings from this project's real sessions.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REPO_ROOT="$repo_root" python3 - <<'PY'
import sys
import os

sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "scripts"))
import gapps_state as gs

# --- parse_vending_version -------------------------------------------------
STUB_DUMPSYS = """Package [com.android.vending] (f1e2...):
    userId=10012
    versionName=1.8
    versionCode=8 minSdk=21 targetSdk=28
"""
REAL_DUMPSYS = """Package [com.android.vending] (ab12...):
    userId=10012
    versionName=34.2.14--release
    versionCode=83421410 minSdk=23 targetSdk=33
"""
assert gs.parse_vending_version(STUB_DUMPSYS) == "1.8"
assert gs.parse_vending_version(REAL_DUMPSYS) == "34.2.14--release"
assert gs.parse_vending_version("no version here") is None
assert gs.parse_vending_version("") is None

# --- is_stub_vending --------------------------------------------------------
assert gs.is_stub_vending("1.8") is True
assert gs.is_stub_vending(None) is True
assert gs.is_stub_vending("") is True
assert gs.is_stub_vending("34.2.14--release") is False
assert gs.is_stub_vending("5.0.31") is False

# --- classify_pairip ---------------------------------------------------------
# Real captured dialog text from the 2026-08-25 MimiLog probe.
BLOCKED_XML = (
    '<node text="Something went wrong" />'
    '<node text="Check that Google Play is enabled on your device and that '
    'you&#39;re using an up-to-date version before opening the app." />'
    '<node text="Close" />'
)
BLOCKED_RESUMED = (
    "mResumedActivity: ActivityRecord{8e823ff u0 com.mimiapp.mimilog/"
    "com.pairip.licensecheck.LicenseActivity t106}"
)
OK_RESUMED = (
    "mResumedActivity: ActivityRecord{90b931f u0 com.hp.babyapp/"
    "com.hp.babyplus.baby20.onboarding.OnBoardingActivity t108}"
)

assert gs.classify_pairip(BLOCKED_RESUMED, BLOCKED_XML) == "license_blocked"
assert gs.classify_pairip(BLOCKED_RESUMED, "") == "license_checking"
assert gs.classify_pairip(OK_RESUMED, "<node />") == "ok"
# Dialog can linger after the license activity resumes away.
assert gs.classify_pairip(OK_RESUMED, BLOCKED_XML) == "license_blocked"
assert gs.classify_pairip("", "") == "unknown"

# --- parse_build_identity ---------------------------------------------------
MIMILOG_DUMPSYS = """Package [com.mimiapp.mimilog] (abcd):
    versionName=1.0.0
    versionCode=1 minSdk=21 targetSdk=28
    pkg=/data/app/com.mimiapp.mimilog-ASIB/base.apk
"""
identity = gs.parse_build_identity(MIMILOG_DUMPSYS)
assert identity == {"versionName": "1.0.0", "versionCode": "1"}, identity
assert gs.parse_build_identity("empty") == {"versionName": None, "versionCode": None}

# --- snapshot_guard ----------------------------------------------------------
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as td:
    avd = Path(td) / "avd"
    (avd / "snapshots" / "pre-gapps").mkdir(parents=True)
    ok, msg = gs.snapshot_guard(str(avd), "pre-gapps")
    assert ok is True, msg
    ok, msg = gs.snapshot_guard(str(avd), "gapps-ready")
    assert ok is False and "gapps-ready" in msg
    # A zero-length snapshot directory is not a usable backup.
    empty = Path(td) / "avd2"
    (empty / "snapshots" / "pre-gapps").mkdir(parents=True)
    (empty / "snapshots" / "pre-gapps").rmdir()
    (empty / "snapshots" / "pre-gapps").touch()
    ok, _ = gs.snapshot_guard(str(empty), "pre-gapps")
    assert ok is False

print("gapps_state deterministic tests passed")
PY

echo "test-gapps-state passed"
