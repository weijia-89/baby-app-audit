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

# Truth-table spec: every combination of foreground activity, dialog title,
# and dialog body has one defined answer. Written as a table so an
# unspecified combination is itself a test failure.
PAIRIP_RESUMED = BLOCKED_RESUMED
TABLE = []
for resumed in (PAIRIP_RESUMED, OK_RESUMED, ""):
    for title in (0, 1):
        for body in (0, 1):
            text = ""
            if title:
                text += '<node text="Something went wrong" />'
            if body:
                text += '<node text="Check that Google Play" />'
            if resumed == PAIRIP_RESUMED:
                expected = "license_blocked" if (title or body) else "license_checking"
            elif not resumed.strip():
                expected = "unknown"
            elif title and body:
                expected = "license_blocked"
            else:
                expected = "ok"
            TABLE.append((resumed, text, expected))
for idx, (resumed, text, expected) in enumerate(TABLE):
    got = gs.classify_pairip(resumed, text)
    assert got == expected, f"table row {idx}: expected {expected}, got {got}" 

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

# --- md5_matches --------------------------------------------------------------
# OpenGApps publishes an MD5 next to each build, not a SHA-256 manifest. The
# digest must match the target's basename and equal the file's real MD5.
import hashlib

with tempfile.TemporaryDirectory() as md:
    def _write(name, data):
        p = Path(md) / name
        p.write_bytes(data)
        return str(p)

    z = _write("gapps.zip", b"real-content")
    good_sum = hashlib.md5(b"real-content").hexdigest()
    sums = f"{good_sum}  gapps.zip\n"
    assert gs.md5_matches(sums, z) is True
    assert gs.md5_matches(f"{'0' * 32}  gapps.zip\n", z) is False
    # single-space separator also accepted
    assert gs.md5_matches(f"{good_sum} gapps.zip\n", z) is True
    # no entry for the target's name -> never pass
    assert gs.md5_matches(f"{good_sum}  other.zip\n", z) is False
    assert gs.md5_matches("", z) is False
    assert gs.md5_matches("not-a-sums-line\n", z) is False

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

# --- gapps_tarballs -----------------------------------------------------------
TAR_LISTING = (
    "Archive:  /tmp/host-side/gapps.zip\n"
    "  Length      Date    Time    Name\n"
    "---------  ---------- -----   ----\n"
    " 44330583  05-05-2017 10:06   Core/gmscore-arm64.tar.lz\n"
    " 26349589  05-05-2017 10:06   Core/vending-arm64.tar.lz\n"
    "     2884  05-05-2017 10:06   Core/vending-common.tar.lz\n"
    "  1234567  05-05-2017 10:06   Core/gsfcore-all.tar.lz\n"
    "---------                     -------\n"
    "                   4 files\n"
)
assert gs.gapps_tarballs(TAR_LISTING) == [
    "Core/gmscore-arm64.tar.lz",
    "Core/vending-arm64.tar.lz",
    "Core/vending-common.tar.lz",
    "Core/gsfcore-all.tar.lz",
], gs.gapps_tarballs(TAR_LISTING)
assert gs.gapps_tarballs("") == []
assert gs.gapps_tarballs("Core/gmscore-arm64.tar.lz\nCore/gmscore-arm64.tar.lz\nCore/gsfcore-all.tar.lz\nInject/readme.txt\n") == [
    "Core/gmscore-arm64.tar.lz",
    "Core/gmscore-arm64.tar.lz",
    "Core/gsfcore-all.tar.lz",
]

# --- validate_component --------------------------------------------------------
assert gs.validate_component("com.mimiapp.mimilog/.MainActivity") == "com.mimiapp.mimilog/.MainActivity"
assert gs.validate_component("com.hp.babyapp/com.hp.babyplus.baby20.splash.SplashScreenActivity") is not None
assert gs.validate_component("") is None
assert gs.validate_component("Warning: intent failed") is None
assert gs.validate_component("Using default activity: None") is None
assert gs.validate_component("no spaces allowed here") is None

# --- select_tarball -----------------------------------------------------------
# OpenGApps names members like Core/gmscore-arm64.tar.lz, Core/gsfcore-all
# .tar.lz, Core/vending-arm64.tar.lz. '-common' items hold data, never the apk.
entries = [
    "/tmp/w/Core/gmscore-arm64.tar.lz",
    "/tmp/w/Core/gsfcore-all.tar.lz",
    "/tmp/w/Core/vending-arm64.tar.lz",
    "/tmp/w/Core/vending-common.tar.lz",
]
assert gs.select_tarball(entries, "gmscore", "arm64-v8a").endswith("gmscore-arm64.tar.lz")
assert gs.select_tarball(entries, "gsfcore", "arm64-v8a").endswith("gsfcore-all.tar.lz")
assert gs.select_tarball(entries, "vending", "arm64-v8a").endswith("vending-arm64.tar.lz")
# '-common' is never the apk: refuse even when it is the only candidate.
assert gs.select_tarball(["/tmp/w/Core/vending-common.tar.lz"], "vending", "arm64-v8a") is None
# Wrong architecture with no '-all' fallback must refuse, not flash cross-arch.
assert gs.select_tarball(entries, "gmscore", "x86_64") is None
assert gs.select_tarball(entries, "gmscore", "") is None
# '-all' is the fallback when the ABI-specific member is absent.
assert gs.select_tarball(["/tmp/w/Core/extra-all.tar.lz"], "extra", "arm64-v8a").endswith("extra-all.tar.lz")
assert gs.select_tarball([], "gmscore", "arm64-v8a") is None

# --- select_apk_path -----------------------------------------------------------
# Prefer the density-independent nodpi build when several densities ship the
# same apk.
GMS_LISTING = (
    "gmscore-arm64/nodpi/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk\n"
    "gmscore-arm64/320/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk\n"
    "gmscore-arm64/480/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk\n"
)
assert gs.select_apk_path(GMS_LISTING, "PrebuiltGmsCore.apk").endswith(
    "nodpi/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk")
assert gs.select_apk_path(
    "gsfcore-all/nodpi/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk\n",
    "GoogleServicesFramework.apk").endswith("GoogleServicesFramework.apk")
# A single non-nodpi member is still chosen when no nodpi build exists.
assert gs.select_apk_path(
    "vending-arm64/priv-app/Phonesky/Phonesky.apk\n", "Phonesky.apk").endswith("Phonesky.apk")
assert gs.select_apk_path(GMS_LISTING, "Missing.apk") is None
assert gs.select_apk_path("", "Phonesky.apk") is None

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
