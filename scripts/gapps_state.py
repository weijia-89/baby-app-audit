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

    A block needs the Pairip signature: its license activity in the
    foreground, or both dialog strings ("Something went wrong" plus the
    "Check that Google Play" body). Generic app errors alone are not a
    Pairip block - normal apps print similar text.
    """
    resumed = resumed_activity or ""
    text = ui_text or ""
    on_pairip_activity = "com.pairip.licensecheck" in resumed
    dialog_title = "Something went wrong" in text
    dialog_body = "Check that Google Play" in text
    blocked = dialog_title and dialog_body
    if "com.pairip.licensecheck" in resumed:
        if not (dialog_title or dialog_body):
            return "license_checking"
        return "license_blocked"
    if not resumed.strip():
        return "unknown"
    if blocked:
        return "license_blocked"
    return "ok"


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
    """True when archive members contain absolute or parent-escape paths.

    `unzip -l` decorates the listing with host-side metadata: the Archive:
    header (an absolute path on THIS machine) and dash separator lines.
    Those are skipped; only member lines are inspected.
    """
    for line in (listing_text or "").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("Archive:"):
            continue
        if set(stripped) <= {"-", " ", "="}:
            continue
        if stripped.startswith("Length") and "Name" in stripped:
            continue
        token = stripped.split()[-1]
        if token.startswith("/") or token == "..":
            return True
        # Substring sweep catches escapes inside names that contain spaces,
        # where last-token parsing would only see the final segment.
        if "../" in stripped:
            return True
    return False


_COMPONENT_RE = re.compile(
    r"^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+"
    r"/\.?[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)*$"
)


def validate_component(text):
    """Return the component string when it is a well-formed pkg/.Class path.

    `cmd package resolve-activity` can print warnings or blank lines; those
    must never reach `am start`. Anything that is not a clean component
    returns None.
    """
    text = (text or "").strip()
    if not text or " " in text:
        return None
    return text if _COMPONENT_RE.match(text) else None


def select_abi_candidate(paths, abi):
    """Pick the archive member matching the device ABI, refusing to guess.

    Archive trees use underscore ABI segments (arm64_v8a) while the device
    property uses hyphens (arm64-v8a); both spellings are matched. With one
    candidate there is nothing to choose. With several and no ABI signal,
    returning None refuses rather than flashing a wrong-architecture store.
    """
    candidates = [p for p in (paths or []) if p]
    if not candidates:
        return None
    if len(candidates) == 1:
        return candidates[0]
    tokens = [abi, abi.replace("-", "_")] if abi else []
    for token in tokens:
        matches = [p for p in candidates if token in p]
        if len(matches) == 1:
            return matches[0]
    return None


def evaluate_prerequisites(device, snapshot, ca):
    """Evaluate slice prerequisites; deterministic failure ordering.

    Returns (ok, failures) where failures are plain-language strings in
    stable order so reports never shuffle between runs.
    """
    failures = []
    if not device:
        failures.append("emulator not connected")
    if not snapshot:
        failures.append("snapshot pre-gapps missing")
    if not ca:
        failures.append(f"mitm CA {_ca_hash()} absent (captures will be empty)")
    return (len(failures) == 0, failures)


_CA_HASH = "c8750f0d"


def _ca_hash():
    return _CA_HASH


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
