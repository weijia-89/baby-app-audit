#!/usr/bin/env python3
"""Pick an Appium WebView/Chrome context from a context list.

Live Appium sessions call this after driver.contexts is available. Unit tests
cover the picker without starting Appium.
"""


def pick_webview_context(contexts, package):
    """Return the best non-native context, or None.

    Preference:
      1. WEBVIEW_<package>
      2. WEBVIEW_chrome / WEBVIEW_com.android.chrome (Chrome Custom Tab)
      3. any other WEBVIEW_*
      4. CHROMIUM
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
