#!/usr/bin/env python3
"""Unit tests for WebView context picking. No Appium required."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from webview_context import pick_webview_context


def test_prefers_matching_package():
    ctx = pick_webview_context(
        ["NATIVE_APP", "WEBVIEW_com.other", "WEBVIEW_com.hp.babyapp"],
        "com.hp.babyapp",
    )
    assert ctx == "WEBVIEW_com.hp.babyapp", ctx


def test_falls_back_to_any_webview():
    ctx = pick_webview_context(
        ["NATIVE_APP", "WEBVIEW_chrome"],
        "com.hp.babyapp",
    )
    assert ctx == "WEBVIEW_chrome", ctx


def test_none_when_native_only():
    ctx = pick_webview_context(["NATIVE_APP"], "com.hp.babyapp")
    assert ctx is None, ctx


def test_chrome_custom_tab_alias():
    ctx = pick_webview_context(
        ["NATIVE_APP", "CHROMIUM"],
        "com.hp.babyapp",
    )
    assert ctx == "CHROMIUM", ctx


def test_empty_list():
    assert pick_webview_context([], "com.hp.babyapp") is None


def test_package_beats_chrome_alias():
    ctx = pick_webview_context(
        ["NATIVE_APP", "WEBVIEW_chrome", "WEBVIEW_com.hp.babyapp"],
        "com.hp.babyapp",
    )
    assert ctx == "WEBVIEW_com.hp.babyapp", ctx


if __name__ == "__main__":
    test_prefers_matching_package()
    test_falls_back_to_any_webview()
    test_none_when_native_only()
    test_chrome_custom_tab_alias()
    test_empty_list()
    test_package_beats_chrome_alias()
    print("ok")
