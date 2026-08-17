#!/usr/bin/env python3
"""Helpers for adb input text and uiautomator bounds. No device I/O."""
import re


def encode_adb_text(val):
    """Escape a string for `adb shell input text`. Spaces must be %s."""
    safe = (val or "").replace("\n", " ").replace('"', "")
    return safe.replace(" ", "%s")


def bounds_center(bounds):
    m = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return ((x1 + x2) // 2, (y1 + y2) // 2)
