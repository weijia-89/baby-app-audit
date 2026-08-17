#!/usr/bin/env python3
"""Add a Google account to the audit emulator using credentials from .secrets/google.json.

The Google sign-in UI is a WebView, so the native uiautomator injector cannot see its
fields. This script drives it with coordinate taps + `adb shell input text`, reading the
credentials from a gitignored secrets file. Google will usually challenge 2FA, which the
operator completes on their device/phone; the script then waits and verifies the account
landed on the device.

Usage:
  scripts/add-google-account.py [--device emulator-5554] [--ui .secrets/google-ui.json]

The optional --ui JSON holds the tap coordinates for the email and password fields, keyed
by the device's wm size (e.g. "1080x1920"). If absent, sensible defaults are derived from
the screen size. Edit that file after a live run if the taps land wrong.
"""
import argparse
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECRETS = os.path.join(ROOT, ".secrets", "google.json")
DEFAULT_UI = os.path.join(ROOT, ".secrets", "google-ui.json")


def adb(device, *args):
    cmd = ["adb"]
    if device:
        cmd += ["-s", device]
    cmd += list(args)
    return subprocess.run(cmd, capture_output=True, text=True)


def wm_size(device):
    out = adb(device, "shell", "wm", "size").stdout.strip()
    # "Physical size: 1080x1920" or "Override size: ..."
    for line in out.splitlines():
        if "size:" in line:
            return line.split(":")[1].strip()
    return "1080x1920"


def tap(device, x, y):
    adb(device, "shell", "input", "tap", str(x), str(y))


def type_text(device, text):
    # input text escapes are limited; use the unicode-aware path via `input text`
    adb(device, "shell", "input", "text", text.replace(" ", "%s"))


def swipe_up(device, dy=80):
    adb(device, "shell", "input", "swipe", "540", "900", "540", str(900 - dy))


def screencap(device, path):
    cmd = ["adb"]
    if device:
        cmd += ["-s", device]
    cmd += ["exec-out", "screencap", "-p"]
    p = subprocess.run(cmd, capture_output=True)
    with open(path, "wb") as f:
        f.write(p.stdout)


def load_ui(device, ui_path, size):
    W, H = (int(v) for v in size.split("x"))
    defaults = {
        "email": (int(W * 0.5), int(H * 0.32)),
        "email_next": (int(W * 0.5), int(H * 0.45)),
        "password": (int(W * 0.5), int(H * 0.40)),
        "password_next": (int(W * 0.5), int(H * 0.55)),
    }
    if ui_path and os.path.exists(ui_path):
        with open(ui_path) as f:
            data = json.load(f)
        for key, val in data.get(size, data.get("default", {})).items():
            defaults[key] = tuple(val)
    return defaults


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default=os.environ.get("DEVICE", "emulator-5554"))
    ap.add_argument("--ui", default=DEFAULT_UI)
    args = ap.parse_args()

    if not os.path.exists(SECRETS):
        sys.exit(f"Missing {SECRETS}. Create it with email/password (see AGENTS notes).")
    with open(SECRETS) as f:
        creds = json.load(f)
    email = creds.get("email")
    password = creds.get("password")
    if not email or email.startswith("REPLACE") or not password or password.startswith("REPLACE"):
        sys.exit("Fill .secrets/google.json with the real email and password first.")

    size = wm_size(args.device)
    print(f"[add-google-account] device={args.device} screen={size}")
    ui = load_ui(args.device, args.ui, size)

    # Launch Google account add (MinuteMaid). Do not use the IMAP min-fa activity.
    print("[add-google-account] launching ADD_ACCOUNT_SETTINGS...")
    adb(
        args.device,
        "shell",
        "am",
        "start",
        "-a",
        "android.settings.ADD_ACCOUNT_SETTINGS",
    )
    time.sleep(4)

    print("[add-google-account] entering email...")
    tap(args.device, *ui["email"])
    time.sleep(1)
    type_text(args.device, email)
    time.sleep(1)
    tap(args.device, *ui["email_next"])
    time.sleep(3)

    print("[add-google-account] entering password...")
    tap(args.device, *ui["password"])
    time.sleep(1)
    type_text(args.device, password)
    time.sleep(1)
    tap(args.device, *ui["password_next"])
    time.sleep(3)

    print("[add-google-account] credentials submitted. Complete any 2FA challenge and "
          "on-screen prompts (e.g. 'Agree') on the emulator/your phone.")

    deadline = time.time() + 180
    while time.time() < deadline:
        dump = adb(args.device, "shell", "dumpsys", "account").stdout
        if "type=com.google" in dump:
            print("[add-google-account] Google account present on device.")
            return
        screencap(args.device, "/tmp/google-add-state.png")
        print(
            f"[add-google-account] not added yet ({int(deadline - time.time())}s left). "
            f"Screenshot: /tmp/google-add-state.png"
        )
        time.sleep(10)

    screencap(args.device, "/tmp/google-add-state.png")
    print(
        "[add-google-account] Timed out waiting for account. Finish any on-screen "
        "prompts, then re-run or verify with dumpsys account. "
        "Screenshot: /tmp/google-add-state.png"
    )


if __name__ == "__main__":
    main()
