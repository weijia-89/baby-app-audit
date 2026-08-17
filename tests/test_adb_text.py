#!/usr/bin/env python3
"""Unit tests for adb text encoding and bounds parsing. No device required."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from adb_text import bounds_center, encode_adb_text, escape_uiautomator_text


def test_encode_spaces():
    assert encode_adb_text("Privatia Rigatoni") == "Privatia%sRigatoni"


def test_encode_empty():
    assert encode_adb_text("") == ""
    assert encode_adb_text(None) == ""


def test_encode_strips_quotes_and_newlines():
    assert encode_adb_text('a"b\nc') == "ab%sc"


def test_center_ok():
    assert bounds_center("[63,820][1025,987]") == (544, 903)


def test_center_bad():
    assert bounds_center("") is None
    assert bounds_center("nope") is None


def test_escape_uiautomator():
    assert escape_uiautomator_text("LOGIN") == "LOGIN"
    assert escape_uiautomator_text('a"b\\c') == 'a\\"b\\\\c'


if __name__ == "__main__":
    test_encode_spaces()
    test_encode_empty()
    test_encode_strips_quotes_and_newlines()
    test_escape_uiautomator()
    test_center_ok()
    test_center_bad()
    print("ok")
