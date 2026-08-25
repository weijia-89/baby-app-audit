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

# False-positive class: a NORMAL app can print its own generic error text.
GENERIC_ERROR = '<node text="Something went wrong. Please try again." />'
assert gs.classify_pairip(OK_RESUMED, GENERIC_ERROR) == "ok", (
    "generic app errors must not read as a Pairip block")
# The real Pairip dialog carries both strings; either alone is not a block
# for a NORMAL app, but sitting on the Pairip activity itself means the
# license gate is live even if the dump caught only a text fragment.
HALF_DIALOG = '<node text="Something went wrong" /><node text="Close" />'
assert gs.classify_pairip(OK_RESUMED, HALF_DIALOG) == "ok"
assert gs.classify_pairip(BLOCKED_RESUMED, HALF_DIALOG) == "license_blocked"
# Non-Pairip activities that merely mention licensecheck stay ok.
OTHER_RESUMED = (
    "mResumedActivity: ActivityRecord{1 u0 com.other.app/"
    "com.other.app.licensecheck.MainActivity t9}"
)
assert gs.classify_pairip(OTHER_RESUMED, GENERIC_ERROR) == "ok"

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

# --- checksum_report_ok -------------------------------------------------------
# Real `shasum -a 256 -c` output looks like "<name>: OK".
good_report = "gapps-arm64.zip: OK\n"
assert gs.checksum_report_ok(good_report, "gapps-arm64.zip") is True
assert gs.checksum_report_ok("other.zip: OK\n", "gapps-arm64.zip") is False
assert gs.checksum_report_ok("gapps-arm64.zip: FAILED\n", "gapps-arm64.zip") is False
assert gs.checksum_report_ok("shasum: gapps-arm64.zip: no such file\n", "gapps-arm64.zip") is False
assert gs.checksum_report_ok("", "gapps-arm64.zip") is False
assert gs.checksum_report_ok("ABCD1234  gapps-arm64.zip\n", "gapps-arm64.zip") is False  # not a -c report
mixed = "a.zip: OK\nb.zip: FAILED open or read\n"
assert gs.checksum_report_ok(mixed, "a.zip") is False  # any failure poisons the run

# --- zip_listing_has_escape -----------------------------------------------------
assert gs.zip_listing_has_escape("  100  2026-01-01 ../evil.sh\n") is True
assert gs.zip_listing_has_escape("  100  2026-01-01 /abs/path.sh\n") is True
assert gs.zip_listing_has_escape("  100  2026-01-01 core/Phonesky.apk\n") is False
assert gs.zip_listing_has_escape("") is False
# Real `unzip -l` output carries an absolute path in its Archive: header;
# that is metadata about the host file, not a member path.
REAL_LISTING = (
    "Archive:  /tmp/host-side/gapps.zip\n"
    "  Length      Date    Time    Name\n"
    "---------  ---------- -----   ----\n"
    "        1  08-25-2026 14:01   Core/gmscore/arm64_v8a/GmsCore.apk\n"
    "---------                     -------\n"
    "        2                     2 files\n"
)
assert gs.zip_listing_has_escape(REAL_LISTING) is False, (
    "Archive: header path must not be treated as a member")
ESCAPE_IN_REAL = REAL_LISTING.replace(
    "Core/gmscore/arm64_v8a/GmsCore.apk", "../evil.sh")
assert gs.zip_listing_has_escape(ESCAPE_IN_REAL) is True

# Escape members whose names contain spaces must also be caught; a
# last-token parser silently misses them.
SPACED = REAL_LISTING.replace(
    "Core/gmscore/arm64_v8a/GmsCore.apk", "../evil dir/run.sh")
assert gs.zip_listing_has_escape(SPACED) is True, (
    "parent-escape with a space in the name went undetected")

# --- select_abi_candidate: no ABI signal refuses ambiguity --------------------
amb = ["/tmp/w/a/GmsCore.apk", "/tmp/w/b/GmsCore.apk"]
assert gs.select_abi_candidate(amb, "") is None
assert gs.select_abi_candidate(amb, None) is None

# --- validate_component --------------------------------------------------------
assert gs.validate_component("com.mimiapp.mimilog/.MainActivity") == "com.mimiapp.mimilog/.MainActivity"
assert gs.validate_component("com.hp.babyapp/com.hp.babyplus.baby20.splash.SplashScreenActivity") is not None
assert gs.validate_component("") is None
assert gs.validate_component("Warning: intent failed") is None
assert gs.validate_component("Using default activity: None") is None
assert gs.validate_component("no spaces allowed here") is None

# --- select_abi_candidate -------------------------------------------------------
cands = [
    "/tmp/w/Core/gmscore/x86_64/GmsCore.apk",
    "/tmp/w/Core/gmscore/arm64_v8a/GmsCore.apk",
    "/tmp/w/Core/gmscore/armeabi_v7a/GmsCore.apk",
]
got = gs.select_abi_candidate(cands, "arm64-v8a")
assert got is not None and "arm64_v8a" in got, got
# Device ABI token uses hyphens; archive dirs use underscores - both must match.
assert gs.select_abi_candidate(cands, "x86_64").endswith("x86_64/GmsCore.apk")
# Single candidate passes through even without an ABI segment.
assert gs.select_abi_candidate(["/tmp/w/Phonesky.apk"], "arm64-v8a") == "/tmp/w/Phonesky.apk"
assert gs.select_abi_candidate([], "arm64-v8a") is None
# Ambiguous candidates with no ABI info at all -> refuse rather than guess.
amb = ["/tmp/w/a/GmsCore.apk", "/tmp/w/b/GmsCore.apk"]
assert gs.select_abi_candidate(amb, "arm64-v8a") is None

# --- evaluate_prerequisites ------------------------------------------------------
ok, fails = gs.evaluate_prerequisites(device=True, snapshot=True, ca=True)
assert ok is True and fails == []
ok, fails = gs.evaluate_prerequisites(device=False, snapshot=False, ca=True)
assert ok is False
assert fails == ["emulator not connected", "snapshot pre-gapps missing"], fails
ok, fails = gs.evaluate_prerequisites(device=True, snapshot=True, ca=False)
assert ok is False and fails == ["mitm CA c8750f0d absent (captures will be empty)"]

print("gapps_state deterministic tests passed")
PY

echo "test-gapps-state passed"
