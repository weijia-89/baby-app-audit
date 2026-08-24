#!/usr/bin/env python3
"""Type the synthetic baby profile into an app UI during capture.

While the proxy runs, fill form fields so markers can appear in the .mitm.
This script does not decide if data left the device. The scan of the .mitm does.

Steps:
  1. Dump the UI with uiautomator.
  2. Match each EditText to a profile value by hint, text, or resource-id.
  3. Tap the field and type the value.
  4. Tap a forward button (continue, next, save, done, ...).
  5. Repeat until MAX_SCREENS or no change.

Optional overrides: scripts/inject-config/<package>.json

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
from adb_text import bounds_center, bounds_tap_for_edit, bounds_usable, encode_adb_text

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
# Buttons to try on splash screens with no input fields.
NAV_RE = re.compile(
    r"\b(get\s*started|let'?s\s*go|start|continue|create|sign\s*up|add|next|"
    r"enter|begin|→|open|set\s*up|try)\b",
    re.IGNORECASE,
)
# Never tap these dismiss buttons.
EXCLUDE_RE = re.compile(
    r"\b(close|exit|cancel|skip|no\s*thanks|not\s*now|later|deny|maybe\s*later|"
    r"not\s*interested|dismiss)\b",
    re.IGNORECASE,
)
# Activity must stay in the app package. No spaces or shell chars.
AM_START_RE = re.compile(
    r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+/[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$"
)
# Allowed keys: BACK, DPAD_CENTER, TAB, ENTER, DEL, ESCAPE.
ALLOWED_KEYEVENTS = frozenset({4, 23, 61, 66, 67, 111})
WAIT_MAX_SEC = 30.0


def adb(args, timeout=30):
    cmd = ["adb", "-s", DEVICE] + args
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def load_profile(path):
    with open(path, encoding="utf-8") as fh:
        prof = json.load(fh)
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
    # Optional match by resource-id or hint text.
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
    """Match node text first, then content-desc (TalkBack labels)."""
    needle = text.lower()
    for n in ns:
        if (n.get("text") or "") == text:
            return n
    for n in ns:
        if (n.get("content-desc") or "") == text:
            return n
    for n in ns:
        if needle in (n.get("text") or "").lower():
            return n
    for n in ns:
        if needle in (n.get("content-desc") or "").lower():
            return n
    return None


def find_node_by_id(ns, rid):
    """Match resource-id exactly, then by suffix."""
    want = rid or ""
    if not want:
        return None
    for n in ns:
        full = n.get("resource-id") or ""
        if full == want or full.endswith("id/" + want) or full.endswith("/" + want):
            return n
    return None


def tap_text(text):
    """Tap the first node with matching text or content-desc."""
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


def tap_id(rid):
    """Tap the first enabled node whose resource-id equals or ends with `rid`."""
    tree = dump_view()
    n = find_node_by_id(nodes(tree), rid)
    if n is None or not node_enabled(n):
        return False
    if not bounds_usable(n.get("bounds") or ""):
        return False
    c = center(n.get("bounds"))
    if not c:
        return False
    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
    time.sleep(FIELD_PAUSE)
    return True


def parse_am_start(step, package):
    """Return component only when it is in the target package."""
    comp = step.get("am_start")
    if not isinstance(comp, str) or not AM_START_RE.match(comp):
        return None
    pkg_part, cls_part = comp.split("/", 1)
    if pkg_part != package:
        return None
    if not cls_part.startswith(package + "."):
        return None
    return comp


def parse_keyevent(step):
    """Return an allowed key code, or None."""
    raw = step.get("keyevent")
    try:
        code = int(raw)
    except (TypeError, ValueError):
        return None
    if code not in ALLOWED_KEYEVENTS:
        return None
    return code


def parse_wait(step):
    """Return wait seconds, capped so a recipe cannot hang."""
    raw = step.get("wait")
    try:
        sec = float(raw)
    except (TypeError, ValueError):
        return None
    if sec < 0:
        return 0.0
    return min(sec, WAIT_MAX_SEC)


def parse_swipe(step):
    """Return swipe [x1,y1,x2,y2,ms] or None if not numeric."""
    coords = step.get("swipe")
    if not isinstance(coords, (list, tuple)) or len(coords) < 4:
        return None
    try:
        x1, y1, x2, y2 = (int(coords[0]), int(coords[1]), int(coords[2]), int(coords[3]))
        dur = int(coords[4]) if len(coords) > 4 else 400
    except (TypeError, ValueError):
        return None
    for v in (x1, y1, x2, y2):
        if v < 0 or v > 10000:
            return None
    dur = max(1, min(dur, 5000))
    return [x1, y1, x2, y2, dur]


def node_enabled(n):
    v = (n.get("enabled") or "true").lower()
    return v not in ("false", "0")


def _step_dismiss(step, default=True):
    if "dismiss" not in step:
        return default
    v = step["dismiss"]
    if isinstance(v, bool):
        return v
    if isinstance(v, str) and v.strip().lower() in ("false", "0", "no"):
        return False
    return bool(v)


def parse_fill_nth(step):
    """Return (values, dismiss). Default dismiss=True hides the keyboard.

    Set dismiss false for Flutter sheets that close on ESCAPE (e.g. MimiLog Bottle).
    """
    vals = step.get("fill_nth")
    if not isinstance(vals, (list, tuple)):
        return [], True
    return list(vals), _step_dismiss(step, True)


def type_into_focused(val, dismiss=True):
    """Replace text in the focused field. Spaces become %s for adb.

    dismiss=False skips DPAD_CENTER and ESCAPE (ESCAPE can close Flutter sheets).
    """
    adb(["shell", "input", "keyevent", "123"])
    dels = ["67"] * 40
    adb(["shell", "input", "keyevent", *dels])
    adb(["shell", "input", "text", encode_adb_text(val)])
    time.sleep(FIELD_PAUSE)
    if not dismiss:
        return
    adb(["shell", "input", "keyevent", "23"])
    time.sleep(FIELD_PAUSE)
    adb(["shell", "input", "keyevent", "111"])
    time.sleep(FIELD_PAUSE)


def fill_field_by_keyword(kw, val):
    """Focus the first EditText whose hint, text, or resource-id contains `kw`, then type `val`."""
    tree = dump_view()
    for e in nodes(tree):
        if "EditText" not in (e.get("class") or ""):
            continue
        s = " ".join([e.get("hint") or "", e.get("text") or "", e.get("resource-id") or ""]).lower()
        if kw.lower() in s:
            c = bounds_tap_for_edit(e.get("bounds") or "")
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
        with open(cfg, encoding="utf-8") as fh:
            overrides = json.load(fh)

    entries = []
    if overrides.get("force_stop"):
        adb(["shell", "am", "force-stop", package])
        time.sleep(1)
    launched = adb(["shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"])
    time.sleep(3)

    # Use the committed "steps" list (tap_text / fill / wait).
    steps = overrides.get("steps")
    if steps:
        for step in steps:
            if "tap_text" in step:
                ok = tap_text(step["tap_text"])
                entries.append({"action": "tap_text", "value": step["tap_text"], "ok": ok})
            elif "tap_id" in step:
                ok = tap_id(step["tap_id"])
                entries.append({"action": "tap_id", "value": step["tap_id"], "ok": ok})
            elif "am_start" in step:
                comp = parse_am_start(step, package)
                if not comp:
                    entries.append({"action": "am_start", "value": step.get("am_start"), "ok": False})
                else:
                    proc = adb(["shell", "am", "start", "-n", comp])
                    blob = (proc.stdout or "") + (proc.stderr or "")
                    ok = proc.returncode == 0 and "Error" not in blob and "Exception" not in blob
                    entries.append({"action": "am_start", "value": comp, "ok": ok})
            elif "keyevent" in step:
                code = parse_keyevent(step)
                if code is None:
                    entries.append({"action": "keyevent", "value": step.get("keyevent"), "ok": False})
                else:
                    proc = adb(["shell", "input", "keyevent", str(code)])
                    entries.append({"action": "keyevent", "value": code, "ok": proc.returncode == 0})
            elif "fill" in step:
                for kw, val in step["fill"].items():
                    ok = fill_field_by_keyword(kw, val)
                    entries.append({"action": "fill", "field": kw, "value": val, "ok": ok})
            elif "wait" in step:
                sec = parse_wait(step)
                if sec is None:
                    entries.append({"action": "wait", "value": step.get("wait"), "ok": False})
                else:
                    time.sleep(sec)
            elif "screenshot" in step:
                adb(["shell", "screencap", "-p", "/sdcard/step.png"])
            elif "fill_nth" in step:
                # Fill EditText N with value N when fields have no hints.
                # Re-dump UI after each field; the keyboard moves later fields.
                field_vals, dismiss = parse_fill_nth(step)
                for i, v in enumerate(field_vals):
                    tree = dump_view()
                    edits = [
                        e
                        for e in nodes(tree)
                        if "EditText" in (e.get("class") or "") and node_enabled(e)
                    ]
                    if i >= len(edits):
                        entries.append({"action": "fill_nth", "index": i, "value": v, "ok": False})
                        continue
                    c = bounds_tap_for_edit(edits[i].get("bounds") or "")
                    if not c:
                        entries.append({"action": "fill_nth", "index": i, "value": v, "ok": False})
                        continue
                    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                    time.sleep(FIELD_PAUSE)
                    type_into_focused(v, dismiss=dismiss)
                    entries.append({"action": "fill_nth", "index": i, "value": v, "ok": True})
            elif "tap_bounds" in step:
                c = center(step["tap_bounds"])
                if c:
                    adb(["shell", "input", "tap", str(c[0]), str(c[1])])
                    time.sleep(FIELD_PAUSE)
                    entries.append({"action": "tap_bounds", "value": step["tap_bounds"], "ok": True})
            elif "swipe" in step:
                nums = parse_swipe(step)
                if not nums:
                    entries.append({"action": "swipe", "value": step.get("swipe"), "ok": False})
                    continue
                x1, y1, x2, y2, dur = nums
                adb(["shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur)])
                time.sleep(SCREEN_PAUSE)
                entries.append({"action": "swipe", "value": nums, "ok": True})
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
                # Last resort: put the high-confidence token in any empty text field.
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
            # No form yet: tap a forward button (not dismiss). Stop at MAX_SCREENS.
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
