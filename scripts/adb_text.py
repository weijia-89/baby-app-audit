#!/usr/bin/env python3
"""Encode text for adb and parse UI bounds. No device calls."""
import re


def encode_adb_text(val):
    """Escape text for `adb shell input text`. Use %s for spaces."""
    safe = (val or "").replace("\n", " ").replace('"', "")
    return safe.replace(" ", "%s")


def escape_uiautomator_text(val):
    """Escape text for a UiSelector text(\"...\") argument."""
    return (val or "").replace("\\", "\\\\").replace('"', '\\"')


def bounds_center(bounds):
    return bounds_tap(bounds, "center")


def bounds_tap(bounds, align="center"):
    """Return a tap point inside UI bounds.

    For tall fields, use align=top so the keyboard does not cover the tap.
    """
    m = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    x = (x1 + x2) // 2
    if align == "top":
        inset = min(48, max(8, (y2 - y1) // 8))
        return (x, y1 + inset)
    return (x, (y1 + y2) // 2)


def bounds_tap_for_edit(bounds):
    """Tap near the top of a tall field so the keyboard does not cover it."""
    m = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return None
    y1, y2 = int(m.group(2)), int(m.group(4))
    if (y2 - y1) > 400:
        return bounds_tap(bounds, "top")
    return bounds_tap(bounds, "center")


def bounds_usable(bounds):
    """False if bounds are missing or zero size."""
    m = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return False
    x1, y1, x2, y2 = map(int, m.groups())
    return (x2 - x1) >= 8 and (y2 - y1) >= 8
