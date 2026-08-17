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
        stem = path.stem
        if stem.count(".") < 1:
            print(f"filename is not a package name: {path}", file=sys.stderr)
            return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
