#!/usr/bin/env python3
"""Pure classifiers for the Play-store unlock slice.

No adb calls here. Every function takes captured text and returns plain
values so tests stay deterministic and offline.
"""
import re
from pathlib import Path

VENDING_PACKAGE = "com.android.vending"
STUB_MAJOR_MIN_REAL = 5

_VERSION_RE = re.compile(r"versionName=(\S+)")
_CODE_RE = re.compile(r"versionCode=(\d+)")


def parse_vending_version(dumpsys_text):
    """Return the Play Store versionName from dumpsys output, or None."""
    match = _VERSION_RE.search(dumpsys_text or "")
    return match.group(1) if match else None


def is_stub_vending(version):
    """True when the store is absent or too old to license apps.

    The stock test image ships a stub 1.x store that cannot sign in.
    Real stores ship 5.x and newer; treat anything below major 5 as stub.
    """
    if not version:
        return True
    major = re.match(r"(\d+)", version)
    if not major:
        return True
    return int(major.group(1)) < STUB_MAJOR_MIN_REAL


def classify_pairip(resumed_activity, ui_text):
    """Classify one app-launch probe from its resumed-activity line and UI dump.

    Returns one of: ok, license_blocked, license_checking, unknown.
    """
    resumed = resumed_activity or ""
    text = ui_text or ""
    blocked = "Something went wrong" in text
    if "pairip.licensecheck.LicenseActivity" in resumed:
        return "license_blocked" if blocked else "license_checking"
    if not resumed.strip():
        return "unknown"
    return "license_blocked" if blocked else "ok"


def parse_build_identity(dumpsys_text):
    """Extract versionName/versionCode for RESULTS provenance rows."""
    text = dumpsys_text or ""
    name = _VERSION_RE.search(text)
    code = _CODE_RE.search(text)
    return {
        "versionName": name.group(1) if name else None,
        "versionCode": code.group(1) if code else None,
    }


def checksum_report_ok(report_text, zip_name):
    """True only when a `shasum -c` report lists zip_name as OK and nothing failed.

    Any FAILED/missing line poisons the run even if it names another file,
    because partial checksum files mean we cannot trust what was verified.
    """
    lines = [ln for ln in (report_text or "").splitlines() if ln.strip()]
    if not lines:
        return False
    saw_target = False
    for line in lines:
        low = line.lower()
        if "failed" in low or "no such file" in low:
            return False
        if not low.rstrip().endswith(": ok") and ": ok" not in low:
            return False
        if zip_name in line:
            saw_target = True
    return saw_target


def zip_listing_has_escape(listing_text):
    """True when an archive listing contains absolute or parent-escape paths."""
    for line in (listing_text or "").splitlines():
        stripped = line.strip()
        # Archive listing lines end with the member path; take the last token.
        token = stripped.split()[-1] if stripped else ""
        if token.startswith("/") or "../" in token or token == "..":
            return True
    return False


def snapshot_guard(avd_dir, required_snapshot):
    """Check a usable quickboot snapshot exists before any system change.

    Returns (ok, message). A zero-length snapshot file is not a backup;
    real snapshots are directories (or non-empty files) under snapshots/.
    """
    snapshot = Path(avd_dir) / "snapshots" / required_snapshot
    if snapshot.is_dir():
        return True, f"snapshot present: {required_snapshot}"
    try:
        if snapshot.is_file() and snapshot.stat().st_size > 0:
            return True, f"snapshot present: {required_snapshot}"
    except OSError as exc:
        return False, f"snapshot unreadable: {required_snapshot}: {exc}"
    return False, (
        f"no usable snapshot {required_snapshot!r} under "
        f"{snapshot.parent}; save one before modifying the system image"
    )
