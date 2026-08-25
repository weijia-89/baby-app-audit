#!/usr/bin/env python3
"""Inventory the local screenshot (uiux) evidence tree.

Walks results/*-test-*/artifacts/uiux, folds soak/variant directory names
into their app slug, counts PNGs and zero-byte files, and renders either
JSON or a markdown table for the ROADMAP backfill section.

Offline and deterministic: same tree in, same bytes out.

Accepted limit: files are counted by size only - PNG content is never
decoded, so a truncated capture that still has bytes counts as good.
Symlinked test directories and PNGs are excluded so the inventory can
never import counts from outside the evidence tree.
"""
import argparse
import json
import os
import re
from pathlib import Path

# App slug -> display name used in FINAL-REPORT / ROADMAP tables.
APP_NAMES = {
    "nurture-lock": "Nurture Lock",
    "nubo": "Nubo",
    "pebbi": "Pebbi",
    "baby-buddy": "Baby Buddy",
    "amila": "Amila",
    "baby-daybook": "Baby Daybook",
    "baby-plus": "Baby+",
    "mimilog": "MimiLog",
    "nara": "Nara",
    "heartful-baby": "Heartful Baby",
    "pixy": "Pixy",
    "babycenter": "BabyCenter",
    "bellybloom": "BellyBloom",
    "nanit": "Nanit",
    "pregnancyplus": "Pregnancy+",
    "whattoexpect": "What to Expect",
}

TEST_DIR_RE = re.compile(
    r"^(?P<slug>[a-z0-9-]+?)-test-(?P<date>\d{8})(?P<suffix>.*)$"
)


def slug_for(dir_name):
    """Map '<app>-test-<date><suffix>' to its app slug; None otherwise."""
    match = TEST_DIR_RE.match(dir_name)
    if not match:
        return None
    slug = match.group("slug")
    return slug if slug in APP_NAMES else None


def scan(results_dir):
    """Return per-slug rows sorted by slug: png/zero-byte counts + test dirs."""
    rows = {}
    root = Path(results_dir)
    for entry in sorted(root.iterdir()) if root.is_dir() else []:
        if not entry.is_dir() or entry.is_symlink():
            # Symlinked test directories could point anywhere on disk; the
            # inventory describes only real members of the evidence tree.
            continue
        slug = slug_for(entry.name)
        if slug is None:
            continue
        uiux = entry / "artifacts" / "uiux"
        # A symlinked artifacts/uiux points outside the evidence tree; the
        # whole test directory leaves the inventory rather than importing
        # foreign counts.
        if uiux.is_symlink():
            continue
        row = rows.setdefault(
            slug, {"slug": slug, "name": APP_NAMES[slug],
                   "png_count": 0, "zero_byte": 0, "labeled": 0,
                   "total_bytes": 0, "test_dirs": []}
        )
        row["test_dirs"].append(entry.name)
        if not uiux.is_dir():
            continue
        for png in sorted(uiux.glob("*.png")):
            if png.is_symlink():
                continue
            size = png.stat().st_size
            row["png_count"] += 1
            if png.name.startswith("article-"):
                row["labeled"] += 1
            row["total_bytes"] += size
            if size == 0:
                row["zero_byte"] += 1
    return [rows[key] for key in sorted(rows)]


def markdown(rows, app_names=None):
    """Render the inventory as a ROADMAP-ready markdown table."""
    names = dict(APP_NAMES)
    if app_names:
        names.update(app_names)
    seen_slugs = {row["slug"] for row in rows}
    lines = [
        "| App | Test dirs with PNGs | PNGs | Labeled | Zero-byte |",
        "| --- | --- | --- | --- | --- |",
    ]
    for slug in sorted(set(names) | seen_slugs):
        name = names.get(slug, slug)
        match = next((r for r in rows if r["slug"] == slug), None)
        if match is None:
            lines.append(f"| {name} | no PNGs yet | 0 | 0 | 0 |")
            continue
        dirs = ", ".join(match["test_dirs"])
        zb = f"{match['zero_byte']} zero-byte" if match["zero_byte"] else "0"
        lines.append(
            f"| {name} | {dirs} | {match['png_count']} | "
            f"{match['labeled']} | {zb} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", default="results")
    parser.add_argument("--format", choices=("json", "markdown"), default="json")
    args = parser.parse_args()
    rows = scan(args.results)
    if args.format == "markdown":
        print(markdown(rows), end="")
    else:
        print(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
