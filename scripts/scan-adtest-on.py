#!/usr/bin/env python3
"""Search raw .mitm captures for the literal flag adtest=on.

Writes hit counts only. A count is a search result, not a privacy verdict.
"""

import json
import sys
from pathlib import Path

FLAG = b"adtest=on"
IDENT = set(b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")


def public_name(path):
    text = str(path)
    marker = "/results/"
    if marker in text:
        return "results/" + text.split(marker, 1)[1]
    return path.name


def count_flag(data):
    count = 0
    start = 0
    flag_len = len(FLAG)
    while True:
        index = data.find(FLAG, start)
        if index < 0:
            return count
        end = index + flag_len
        before_ok = index == 0 or data[index - 1] not in IDENT
        after_ok = end == len(data) or data[end] not in IDENT
        if before_ok and after_ok:
            count += 1
        start = end


def targets(raw):
    path = Path(raw)
    if path.is_dir():
        return sorted(path.rglob("*.mitm"))
    return [path]


def scan_one(path):
    item = {"file": public_name(path)}
    try:
        data = path.read_bytes()
    except OSError:
        item["error"] = "unreadable"
        return item
    item["hit_count"] = count_flag(data)
    return item


def main(argv):
    if len(argv) < 3:
        sys.stderr.write("usage: scan-adtest-on.py OUTPUT.json FILE_OR_DIR...\n")
        return 2
    rows = []
    for raw in argv[2:]:
        for path in targets(raw):
            rows.append(scan_one(path))
    rows.sort(key=lambda item: item["file"])
    payload = {
        "flag": "adtest=on",
        "limit": "A hit count is a search result. It is not a privacy verdict.",
        "files": rows,
    }
    Path(argv[1]).write_text(json.dumps(payload, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
