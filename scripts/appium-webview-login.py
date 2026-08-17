#!/usr/bin/env python3
"""Drive Baby+ (or another package) login through Appium UiAutomator2 + WebView.

Requires a running Appium 3 server with the uiautomator2 driver:
  appium '--allow-insecure=*:chromedriver_autodownload'
  .test-venv/bin/python scripts/appium-webview-login.py --package com.hp.babyapp

Does not print secrets. Does not read .secrets. Device Google account picker is preferred.
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adb_text import escape_uiautomator_text
from webview_context import pick_webview_context

DEFAULT_APPIUM = os.environ.get("APPIUM_URL", "http://127.0.0.1:4723")
DEFAULT_DEVICE = os.environ.get("ANDROID_SERIAL", "emulator-5554")


def build_driver(device, package, server):
    from appium import webdriver
    from appium.options.android import UiAutomator2Options

    opts = UiAutomator2Options()
    opts.platform_name = "Android"
    opts.udid = device
    opts.automation_name = "UiAutomator2"
    opts.app_package = package
    opts.app_wait_activity = "*.onboarding.*"
    opts.no_reset = True
    opts.auto_grant_permissions = True
    opts.set_capability("chromedriverAutodownload", True)
    opts.set_capability("ensureWebviewsHavePages", True)
    opts.set_capability("nativeWebScreenshot", True)
    return webdriver.Remote(server, options=opts)


def tap_text(driver, text):
    from appium.webdriver.common.appiumby import AppiumBy

    safe = escape_uiautomator_text(text)
    el = driver.find_element(AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().text("{safe}")')
    el.click()
    return True


def wait_for_text(driver, text, timeout=30):
    from appium.webdriver.common.appiumby import AppiumBy

    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            safe = escape_uiautomator_text(text)
            driver.find_element(AppiumBy.ANDROID_UIAUTOMATOR, f'new UiSelector().text("{safe}")')
            return True
        except Exception as exc:
            last = type(exc).__name__
            time.sleep(1)
    print(f"wait_for_text_timeout={text} last={last}")
    return False


def wait_text_gone(driver, text, timeout=90):
    from appium.webdriver.common.appiumby import AppiumBy

    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            driver.find_element(
                AppiumBy.ANDROID_UIAUTOMATOR,
                f'new UiSelector().textContains("{escape_uiautomator_text(text)}")',
            )
        except Exception:
            return True
        time.sleep(2)
    return False


def tap_google_account_row(driver):
    """Tap the device Google account in the GMS picker. Do not log the address."""
    from appium.webdriver.common.appiumby import AppiumBy

    sel = 'new UiSelector().packageName("com.google.android.gms").textContains("@gmail.com")'
    el = driver.find_element(AppiumBy.ANDROID_UIAUTOMATOR, sel)
    el.click()
    return True


def wait_webview(driver, package, timeout=45):
    deadline = time.time() + timeout
    last = []
    while time.time() < deadline:
        try:
            last = list(driver.contexts)
        except Exception:
            last = []
        picked = pick_webview_context(last, package)
        if picked:
            driver.switch_to.context(picked)
            return picked, last
        time.sleep(1.5)
    return None, last


def try_webview_google(driver):
    """Click a Google sign-in control inside the current WebView. No password typing."""
    from selenium.webdriver.common.by import By

    xpaths = [
        "//*[contains(translate(., 'GOOGLE', 'google'), 'google')]",
        "//button[contains(., 'Google')]",
        "//a[contains(., 'Google')]",
        "//*[@id='identifierId']",
        "//input[@type='email']",
    ]
    for xp in xpaths:
        try:
            els = driver.find_elements(By.XPATH, xp)
        except Exception:
            continue
        if not els:
            continue
        try:
            els[0].click()
            return xp
        except Exception:
            continue
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", default="com.hp.babyapp")
    ap.add_argument("--device", default=DEFAULT_DEVICE)
    ap.add_argument("--server", default=DEFAULT_APPIUM)
    ap.add_argument("--tap-text", action="append", default=None,
                    help="Native button text to tap. Repeat for a chain. Default: LOGIN then LOGIN WITH GOOGLE.")
    ap.add_argument("--wait-webview", type=int, default=45)
    args = ap.parse_args()

    try:
        driver = build_driver(args.device, args.package, args.server)
    except Exception as exc:
        sys.exit(
            "Could not reach Appium. Start: appium '--allow-insecure=*:chromedriver_autodownload' "
            f"({exc})"
        )

    try:
        driver.activate_app(args.package)
        taps = args.tap_text or ["LOGIN", "LOGIN WITH GOOGLE"]
        if not wait_for_text(driver, taps[0], timeout=40):
            print(f"splash_not_ready={taps[0]}")
        for label in taps:
            print(f"native_tap={label}")
            try:
                tap_text(driver, label)
                print(f"native_tap_ok={label}")
            except Exception as exc:
                print(f"native_tap_failed={label} {exc}")
            time.sleep(5)
        try:
            tap_google_account_row(driver)
            print("native_tap_ok=google_account_row")
        except Exception as exc:
            print(f"native_tap_failed=google_account_row {type(exc).__name__}")
        if wait_text_gone(driver, "Please Wait", timeout=90):
            print("please_wait_gone=true")
        else:
            print("please_wait_gone=false")
        ctx, all_ctx = wait_webview(driver, args.package, args.wait_webview)
        print(f"contexts={all_ctx}")
        print(f"picked={ctx}")
        if ctx:
            clicked = try_webview_google(driver)
            print(f"webview_click={clicked}")
            print(f"final_context={driver.current_context}")
        else:
            print("no_webview_after_google_picker")
    finally:
        try:
            driver.quit()
        except Exception:
            pass


if __name__ == "__main__":
    main()
