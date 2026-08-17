#!/usr/bin/env python3
"""Automated synthetic baby-profile injector for the APK privacy test harness.

This replaces the former "operator enters the values by hand" step. It drives the
app's own UI while the capture proxy is live so the synthetic markers actually
leave the device and land in the raw .mitm the scan searches.

Method (no per-app coordinates required, but overridable):
  1. uiautomator dumps the current view to XML.
  2. Every EditText is matched to a synthetic value by hint/text/resource-id
     keyword (name -> baby name, note/comment -> synth_token, feed -> synth_feed,
     weight/date/age/volume/sleep/diaper -> the numeric/string sentinels).
  3. The field is focused (tap center) and the value typed; DPAD_CENTER commits.
  4. A forward button (continue/next/save/add/create/sign up/done/finish/ok) is
     tapped to advance multi-screen onboarding.
  5. Repeat for MAX_SCREENS or until no progress.

Per-app overrides live in scripts/inject-config/<package>.json and can pin exact
values, skip fields, or add pre-tap coordinates for pickers the heuristic misses.

Nothing here proves a transmission by itself: the scan on the captured .mitm is the
judge. This script only maximizes the chance the markers are entered somewhere the
app will sync.

Usage: inject-synthetic-profile.py <package> [profile_json] [device_serial]
"""
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adb_text import bounds_center, encode_adb_text

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROFILE_DEFAULT = os.path.join(REPO_ROOT, "results", "synthetic-baby-profile.json")

DEVICE = os.environ.get("ANDROID_SERIAL", "emulator-5554")
MAX_SCREENS = int(os.environ.get("INJECT_MAX_SCREENS", "10"))
SCREEN_PAUSE = float(os.environ.get("INJECT_SCREEN_PAUSE", "2.0"))
FIELD_PAUSE = float(os.environ.get("INJECT_FIELD_PAUSE", "0.6"))

FORWARD_RE = re.compile(
    r"\b(continue|next|save|done|finish|add|create|sign\s*up|get\s*started|"
    r"submit|ok|confirm|start|log\s*in|let'?s\s*go|→|forward)\b",
    re.IGNORECASE,
)
# Navigation CTAs to try when a screen has no editable fields (splash/intro gates).
NAV_RE = re.compile(
    r"\b(get\s*started|let'?s\s*go|start|continue|create|sign\s*up|add|next|"
    r"enter|begin|→|open|set\s*up|try)\b",
    re.IGNORECASE,
)
# Buttons that would dismiss/abandon the flow - never auto-tapped.
EXCLUDE_RE = re.compile(
    r"\b(close|exit|cancel|skip|no\s*thanks|not\s*now|later|deny|maybe\s*later|"
    r"not\s*interested|dismiss)\b",
    re.IGNORECASE,
)


def adb(args, timeout=30):
    cmd = ["adb", "-s", DEVICE] + args
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def load_profile(path):
    prof = json.load(open(path))
    b = prof.get("baby", {})
    return {
        "name": b.get("name", "Privatia Rigatoni"),
        "token": b.get("free_text_note", "PRIVATIA-RIGATONI-SYNTH"),
        "feed": b.get("formula_brand_note", "Rigatoni-8823-synthfeed"),
        "birth_weight": b.get("birth_weight", "6 lbs 8 oz"),
        "birth_date": b.get("birth_date", "2026-03-14"),
        "age": str(prof.get("mother_age", 30)),
        "vol": str(b.get("feeding_example_volume_ml", 482)),
        "sleep": str(b.get("sleep_example_minutes", 777)),
        "diaper": str(b.get("diaper_example_weight_g", 1234)),
    }


def pick_value(hint, text, rid, vals, overrides):
    s = " ".join([hint or "", text or "", rid or ""]).lower()
    # explicit per-app override by resource-id or hint substring
    for key, val in (overrides.get("field_values", {}) or {}).items():
        if key.lower() in s:
            return val
    if any(k in s for k in ["note", "comment", "about", "description", "message", "bio", "memo", "reason", "remark"]):
        return vals["token"]
    if any(k in s for k in ["feed", "formula", "bottle", "milk", "nursing"]):
        return vals["feed"]
    if "baby" in s and "name" in s:
        return vals["name"]
    if "name" in s:
        return vals["name"]
    if "diaper" in s:
        return vals["diaper"]
    if any(k in s for k in ["weight"]) and "diaper" not in s:
        return vals["birth_weight"]
    if any(k in s for k in ["date", "birth", "dob", "due"]):
        return vals["birth_date"]
    if "age" in s:
        return vals["age"]
    if any(k in s for k in ["sleep"]):
        return vals["sleep"]
    if any(k in s for k in ["volume", "amount", "ml", "oz"]):
        return vals["vol"]
    return None


def dump_view():
    out = "/sdcard/inject_uidump.xml"
    adb(["shell", "uiautomator", "dump", out])
    local = "/tmp/inject_uidump.xml"
    adb(["pull", out, local])
    try:
        return ET.parse(local)
    except Exception:
        return None


def find_node_by_text(ns, text):
    for n in ns:
        if (n.get("text") or "") == text:
            return n
    for n in ns:
        if text.lower() in (n.get("text") or "").lower():
            return n
    return None


def tap_text(text):
    """Tap the first visible node whose text equals or contains `text`."""
    tree = dump_view()
    n = find_node_by_text(nodes(tree), text)
    if n is None:
        return False
    c = center(n.get("bounds"))
    if not c:
        return False
    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
    time.sleep(FIELD_PAUSE)
    return True


def type_into_focused(val):
    """Replace the focused field. Spaces must be %s for adb input text."""
    adb(["shell", "input", "keyevent", "123"])
    dels = ["67"] * 40
    adb(["shell", "input", "keyevent", *dels])
    adb(["shell", "input", "text", encode_adb_text(val)])
    time.sleep(FIELD_PAUSE)
    adb(["shell", "input", "keyevent", "23"])
    time.sleep(FIELD_PAUSE)
    adb(["shell", "input", "keyevent", "111"])
    time.sleep(FIELD_PAUSE)


def fill_field_by_keyword(kw, val):
    """Focus the first EditText whose hint/text/resource-id contains `kw` and type `val`."""
    tree = dump_view()
    for e in nodes(tree):
        if "EditText" not in (e.get("class") or ""):
            continue
        s = " ".join([e.get("hint") or "", e.get("text") or "", e.get("resource-id") or ""]).lower()
        if kw.lower() in s:
            c = center(e.get("bounds"))
            if not c:
                continue
            adb(["shell", "input", "tap", str(c[0]), str(c[1])])
            time.sleep(FIELD_PAUSE)
            type_into_focused(val)
            return True
    return False


def center(bounds):
    return bounds_center(bounds)


def nodes(tree):
    if tree is None:
        return []
    return [n for n in tree.iter()]


def main():
    package = sys.argv[1]
    profile = sys.argv[2] if len(sys.argv) > 2 else PROFILE_DEFAULT
    if len(sys.argv) > 3:
        global DEVICE
        DEVICE = sys.argv[3]
    vals = load_profile(profile)
    overrides = {}
    cfg = os.path.join(REPO_ROOT, "scripts", "inject-config", f"{package}.json")
    if os.path.exists(cfg):
        overrides = json.load(open(cfg))

    entries = []
    launched = adb(["shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(3)

    # Per-app flow mode: a committed "steps" list built from the UI/UX capture
    # drives the exact onboarding (tap_text / fill / wait). This is precise and
    # reusable - no re-driving the app by hand each run.
    steps = overrides.get("steps")
    if steps:
        for step in steps:
            if "tap_text" in step:
                ok = tap_text(step["tap_text"])
                entries.append({"action": "tap_text", "value": step["tap_text"], "ok": ok})
            elif "fill" in step:
                for kw, val in step["fill"].items():
                    ok = fill_field_by_keyword(kw, val)
                    entries.append({"action": "fill", "field": kw, "value": val, "ok": ok})
            elif "wait" in step:
                time.sleep(step["wait"])
            elif "screenshot" in step:
                adb(["shell", "screencap", "-p", "/sdcard/step.png"])
            elif "fill_nth" in step:
                # Fill the Nth native EditText with value N (fields have no hints).
                vals = step["fill_nth"]
                tree = dump_view()
                edits = [e for e in nodes(tree) if "EditText" in (e.get("class") or "")]
                for i, v in enumerate(vals):
                    if i >= len(edits):
                        entries.append({"action": "fill_nth", "index": i, "value": v, "ok": False})
                        continue
                    c = center(edits[i].get("bounds"))
                    if not c:
                        entries.append({"action": "fill_nth", "index": i, "value": v, "ok": False})
                        continue
                    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                    time.sleep(FIELD_PAUSE)
                    type_into_focused(v)
                    entries.append({"action": "fill_nth", "index": i, "value": v, "ok": True})
            elif "tap_bounds" in step:
                c = center(step["tap_bounds"])
                if c:
                    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                    time.sleep(FIELD_PAUSE)
                    entries.append({"action": "tap_bounds", "value": step["tap_bounds"], "ok": True})
            elif "swipe" in step:
                coords = step["swipe"]
                if not isinstance(coords, (list, tuple)) or len(coords) < 4:
                    entries.append({"action": "swipe", "value": coords, "ok": False})
                    continue
                x1, y1, x2, y2 = coords[0], coords[1], coords[2], coords[3]
                dur = coords[4] if len(coords) > 4 else 400
                adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
                time.sleep(SCREEN_PAUSE)
                entries.append({"action": "swipe", "value": coords, "ok": True})
        summary = {"package": package, "mode": "steps", "entries": entries, "screens": len(steps)}
        print(json.dumps(summary, indent=2))
        return 0

    filled = set()
    for screen in range(MAX_SCREENS):
        tree = dump_view()
        ns = nodes(tree)
        edit_texts = [n for n in ns if "EditText" in (n.get("class") or "")]
        progressed = False

        for e in edit_texts:
            hint = e.get("hint") or ""
            text = e.get("text") or ""
            rid = e.get("resource-id") or ""
            key = f"{rid}|{hint}|{e.get('bounds')}"
            if key in filled:
                continue
            val = pick_value(hint, text, rid, vals, overrides)
            if val is None:
                # Last-resort: spray the high-confidence token into any still-empty
                # free-text field so a transmission has something to carry.
                if overrides.get("spray_token_on_unknown", True):
                    val = vals["token"]
                else:
                    continue
            c = center(e.get("bounds"))
            if not c:
                continue
            adb(["shell", "input", "tap", str(c[0]), str(c[1])])
            time.sleep(FIELD_PAUSE)
            type_into_focused(val)
            filled.add(key)
            entries.append({"field": rid or hint or "(unnamed)", "value": val})
            progressed = True

        # forward button
        btn = None
        for n in ns:
            t = n.get("text") or ""
            if FORWARD_RE.search(t) and n.get("clickable") == "true":
                btn = n
                break
        if btn is None:
            for n in ns:
                if FORWARD_RE.search(n.get("text") or ""):
                    btn = n
                    break
        if btn is not None:
            c = center(btn.get("bounds"))
            if c:
                adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                time.sleep(SCREEN_PAUSE)
                progressed = True
        elif not edit_texts:
            # Splash/intro gate with no form yet: tap a primary navigation CTA to
            # advance, but never a dismiss button. Bounded by MAX_SCREENS.
            for n in ns:
                t = n.get("text") or ""
                if not t.strip():
                    continue
                if n.get("clickable") != "true" and "Button" not in (n.get("class") or ""):
                    continue
                if EXCLUDE_RE.search(t):
                    continue
                if NAV_RE.search(t):
                    c = center(n.get("bounds"))
                    if c:
                        adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                        time.sleep(SCREEN_PAUSE)
                        progressed = True
                        break

        if not progressed:
            break

    summary = {"package": package, "entries": entries, "screens": screen + 1}
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
