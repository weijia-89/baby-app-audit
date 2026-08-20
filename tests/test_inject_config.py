#!/usr/bin/env python3
"""Check inject-config JSON files parse and each has a steps list."""
import json
import re
import sys
from pathlib import Path

CFG = Path(__file__).resolve().parents[1] / "scripts" / "inject-config"
BOUNDS_RE = re.compile(r"^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$")


def _parse_bounds(raw):
    if not isinstance(raw, str):
        return None
    m = BOUNDS_RE.match(raw)
    if not m:
        return None
    return tuple(int(x) for x in m.groups())


def _babyplus_recipe_invalid(data, silent=False):
    """Return True if Baby+ steps cannot open Girl then save on this AVD."""

    def fail(msg):
        if not silent:
            print(msg, file=sys.stderr)
        return True
    steps = data.get("steps") or []
    kinds = []
    for s in steps:
        if "fill" in s:
            kinds.append("fill")
        elif "keyevent" in s:
            kinds.append("keyevent")
        elif "tap_bounds" in s:
            kinds.append("tap_bounds")
        elif "tap_id" in s:
            kinds.append("tap_id")
        elif "wait" in s:
            try:
                if float(s["wait"]) > 30:
                    return fail("babyplus wait exceeds 30 seconds")
            except (TypeError, ValueError):
                return fail("babyplus wait is not a number")
    fills = [s.get("fill") for s in steps if "fill" in s]
    if not any(isinstance(f, dict) and "baby_1_name" in f for f in fills):
        return fail("babyplus must fill baby_1_name")
    keys = [s.get("keyevent") for s in steps if "keyevent" in s]
    if 111 not in keys and "111" not in keys:
        return fail("babyplus must hide the keyboard before the spinner")
    try:
        fill_i = kinds.index("fill")
        key_i = kinds.index("keyevent")
        b1 = kinds.index("tap_bounds")
        b2 = kinds.index("tap_bounds", b1 + 1)
        id_i = kinds.index("tap_id")
    except ValueError:
        return fail("babyplus must fill, hide keyboard, tap spinner, tap Girl, then DONE")
    if not (fill_i < key_i < b1 < b2 < id_i):
        return fail("babyplus step order must be name, keyboard hide, spinner, Girl, DONE")
    bounds = [s.get("tap_bounds") for s in steps if "tap_bounds" in s]
    spinner = _parse_bounds(bounds[0])
    girl = _parse_bounds(bounds[1])
    if spinner is None or girl is None:
        return fail("babyplus tap_bounds must be four integers")
    # Chevron is the right edge of CustomMaterialSpinner [63,820][1025,987].
    if spinner[0] < 900 or spinner[1] < 800 or spinner[3] > 1000:
        return fail("babyplus spinner tap must be the right-edge chevron")
    # Popup content [63,971][1025,1219]; Girl is the lower row (y1 >= 1095).
    if girl != (63, 1095, 1025, 1219):
        return fail("babyplus Girl tap must be the lower popup row")
    ids = [s.get("tap_id") for s in steps if "tap_id" in s]
    if "done_button" not in ids:
        return fail("babyplus must tap done_button by id")
    return False


def main():
    paths = sorted(CFG.glob("*.json"))
    if not paths:
        print("no inject-config json files", file=sys.stderr)
        return 1
    for path in paths:
        data = json.loads(path.read_text())
        if "steps" not in data or not isinstance(data["steps"], list):
            print(f"missing steps list: {path}", file=sys.stderr)
            return 1
        if path.name == "com.hp.babyapp.json":
            if _babyplus_recipe_invalid(data):
                return 1
        if path.name == "com.mimiapp.mimilog.json":
            nth = [s for s in data["steps"] if "fill_nth" in s]
            if not nth or nth[0].get("dismiss") is not False:
                print("mimilog fill_nth must set dismiss false", file=sys.stderr)
                return 1
        if path.name == "com.clicksie.nuboapp.json":
            ids = [s.get("tap_id") for s in data["steps"] if "tap_id" in s]
            if ids.count("btnMilkL") < 2 or ids.count("btnMilkR") < 2:
                print("nubo must start and stop left and right milk sessions", file=sys.stderr)
                return 1
            if ids.count("btnSleep") < 2:
                print("nubo must start and stop a sleep session", file=sys.stderr)
                return 1
            if "btnBottle" not in ids or "btnPee" not in ids or "btnPoop" not in ids:
                print("nubo must log bottle, pee, and poop events", file=sys.stderr)
                return 1
            if ids.count("btnPump") < 2:
                print("nubo must start and stop a pump session", file=sys.stderr)
                return 1
            notes = [s for s in data["steps"] if "am_start" in s or "fill_nth" in s]
            if not notes:
                print("nubo must open a note and type the synth token", file=sys.stderr)
                return 1
            nth = [s for s in data["steps"] if "fill_nth" in s]
            if not nth or len(nth[0].get("fill_nth") or []) < 2:
                print("nubo note must fill title and body", file=sys.stderr)
                return 1
            if not any("keyevent" in s for s in data["steps"]):
                print("nubo must hide the keyboard before Save", file=sys.stderr)
                return 1
            if data.get("force_stop") is not True:
                print("nubo must force_stop so Notes does not block home", file=sys.stderr)
                return 1
            for s in data["steps"]:
                if "wait" in s:
                    try:
                        if float(s["wait"]) > 30:
                            print("nubo wait exceeds 30 seconds", file=sys.stderr)
                            return 1
                    except (TypeError, ValueError):
                        print("nubo wait is not a number", file=sys.stderr)
                        return 1
                if "am_start" in s:
                    comp = s["am_start"]
                    if not str(comp).startswith("com.clicksie.nuboapp/com.clicksie.nuboapp."):
                        print("nubo am_start must stay inside the nubo package", file=sys.stderr)
                        return 1
        stem = path.stem
        if stem.count(".") < 1:
            print(f"filename is not a package name: {path}", file=sys.stderr)
            return 1
    nubo = CFG / "com.clicksie.nuboapp.json"
    if not nubo.is_file():
        print("missing nubo inject config", file=sys.stderr)
        return 1
    reversed_girl = {
        "steps": [
            {"fill": {"baby_1_name": "Privatia Rigatoni"}},
            {"keyevent": 111},
            {"tap_bounds": "[63,1095][1025,1219]"},
            {"tap_bounds": "[940,860][1020,940]"},
            {"tap_id": "done_button"},
        ]
    }
    if not _babyplus_recipe_invalid(reversed_girl, silent=True):
        print("reversed spinner/Girl recipe must fail", file=sys.stderr)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
