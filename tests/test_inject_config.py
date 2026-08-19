#!/usr/bin/env python3
"""Check inject-config JSON files parse and each has a steps list."""
import json
import sys
from pathlib import Path

CFG = Path(__file__).resolve().parents[1] / "scripts" / "inject-config"


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
            texts = [s.get("tap_text") for s in data["steps"] if "tap_text" in s]
            if "DONE" not in texts:
                print("babyplus must tap DONE", file=sys.stderr)
                return 1
            bounds = [s.get("tap_bounds") for s in data["steps"] if "tap_bounds" in s]
            # Gender TalkBack dump has no Girl node. Open CustomMaterialSpinner
            # (right-edge tap) then tap the lower half of the Boy/Girl popup
            # (frame [63,971][1025,1219] on the API 29 AVD).
            if len(bounds) < 2:
                print("babyplus must tap spinner then Girl", file=sys.stderr)
                return 1
            if "[63,1095][1025,1219]" not in bounds:
                print("babyplus must tap Girl in the spinner popup", file=sys.stderr)
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
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
