#!/usr/bin/env python3
"""Capture per-screen UI/UX for an app's onboarding flow.

Records every screen's uiautomator dump + screenshot under
results/<slug>-test-<date>/artifacts/uiux/screenN.xml|.png so the per-app
injection flow (scripts/inject-config/<package>.json) can be built from the
recorded UI without re-driving the app by hand.

Usage: capture-uiux.py <package> [slug] [device_serial]
Env: ANDROID_SERIAL, CAP_DATE (default 20260816), UIUX_SCREENS (default 15)
"""
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEVICE = os.environ.get("ANDROID_SERIAL", "emulator-5554")
DATE = os.environ.get("CAP_DATE", "20260816")
MAX_SCREENS = int(os.environ.get("UIUX_SCREENS", "15"))
SCREEN_PAUSE = float(os.environ.get("UIUX_PAUSE", "1.5"))

FORWARD_RE = re.compile(
    r"\b(continue|next|save|done|finish|add|create|sign\s*up|get\s*started|"
    r"submit|ok|confirm|start|log\s*in|let'?s\s*go|→|forward)\b",
    re.IGNORECASE,
)
NAV_RE = re.compile(
    r"\b(get\s*started|let'?s\s*go|start|continue|create|sign\s*up|add|next|"
    r"enter|begin|→|open|set\s*up|try)\b",
    re.IGNORECASE,
)
EXCLUDE_RE = re.compile(
    r"\b(exit|cancel|skip|no\s*thanks|not\s*now|later|deny|maybe\s*later|"
    r"not\s*interested|dismiss)\b",
    re.IGNORECASE,
)


def adb(args, timeout=30):
    return subprocess.run(
        ["adb", "-s", DEVICE] + args, capture_output=True, text=True, timeout=timeout
    )


def center(bounds):
    m = re.search(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds or "")
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return ((x1 + x2) // 2, (y1 + y2) // 2)


def dump_view(local):
    adb(["shell", "uiautomator", "dump", "/sdcard/uiux.xml"])
    adb(["pull", "/sdcard/uiux.xml", local])


def nodes(local):
    try:
        return list(ET.parse(local).iter())
    except Exception:
        return []


def find_button(ns, regex):
    for n in ns:
        if regex.search(n.get("text") or ""):
            if n.get("clickable") == "true" or "Button" in (n.get("class") or ""):
                return n
    for n in ns:
        if regex.search(n.get("text") or ""):
            return n
    return None


def main():
    package = sys.argv[1]
    slug = sys.argv[2] if len(sys.argv) > 2 else package.split(".")[-1]
    if len(sys.argv) > 3:
        global DEVICE
        DEVICE = sys.argv[3]
    outdir = os.path.join(REPO_ROOT, "results", f"{slug}-test-{DATE}", "artifacts", "uiux")
    os.makedirs(outdir, exist_ok=True)

    adb(["shell", "am", "force-stop", package])
    time.sleep(1)
    adb(["shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(4)

    seen = set()
    for i in range(MAX_SCREENS):
        xml = os.path.join(outdir, f"screen{i:02d}.xml")
        png = os.path.join(outdir, f"screen{i:02d}.png")
        dump_view(xml)
        adb(["shell", "screencap", "-p", "/sdcard/uiux.png"])
        adb(["pull", "/sdcard/uiux.png", png])
        ns = nodes(xml)
        edit = sum(1 for n in ns if "EditText" in (n.get("class") or ""))
        sig = xml  # crude; rely on screen count
        print(f"screen{i:02d}: edittext={edit}")

        # advance: prefer forward CTA, then nav CTA, then any non-excluded button
        btn = find_button(ns, FORWARD_RE) or find_button(ns, NAV_RE)
        if btn is None:
            for n in ns:
                t = n.get("text") or ""
                if not t.strip():
                    continue
                if n.get("clickable") != "true" and "Button" not in (n.get("class") or ""):
                    continue
                if EXCLUDE_RE.search(t):
                    continue
                btn = n
                break
        if btn is None:
            print(f"screen{i:02d}: no advance button - stop")
            break
        c = center(btn.get("bounds"))
        if not c:
            break
        adb(["shell", "input", "tap", str(c[0]), str(c[1])])
        time.sleep(SCREEN_PAUSE)

    print(f"UI/UX captured to {outdir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
