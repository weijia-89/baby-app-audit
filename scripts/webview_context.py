#!/usr/bin/env python3
"""Pick a WebView or Chrome context from an Appium context list."""


def pick_webview_context(contexts, package):
    """Return the best non-native context, or None.

    Order: WEBVIEW_<package>, Chrome WebView, other WEBVIEW_*, CHROMIUM.
    """
    names = [str(c) for c in contexts]
    want = f"WEBVIEW_{package}"
    if want in names:
        return want
    for alias in ("WEBVIEW_chrome", "WEBVIEW_com.android.chrome"):
        if alias in names:
            return alias
    for name in names:
        if name.startswith("WEBVIEW_"):
            return name
    if "CHROMIUM" in names:
        return "CHROMIUM"
    return None


if __name__ == "__main__":
    import sys

    sample = sys.argv[1:] or ["NATIVE_APP"]
    pkg = "com.hp.babyapp"
    print(pick_webview_context(sample, pkg) or "")
