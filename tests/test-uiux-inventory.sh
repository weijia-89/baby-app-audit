#!/usr/bin/env bash
# Deterministic tests for scripts/uiux_inventory.py.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/uiux-inv.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Fixture evidence tree:
#   baby-plus-test-20260821 -> 2 good PNGs
#   nubo-test-20260818-soak -> 1 good PNG (soak suffix must fold into nubo)
#   mimilog-test-20260817   -> 1 zero-byte PNG (counted, flagged)
#   stray-dir               -> ignored entirely (not an app test dir)
mkdir -p "$tmp/results/baby-plus-test-20260821/artifacts/uiux" \
         "$tmp/results/nubo-test-20260818-soak/artifacts/uiux" \
         "$tmp/results/mimilog-test-20260817/artifacts/uiux" \
         "$tmp/results/stray-dir/artifacts/uiux"
printf 'PNGDATA' > "$tmp/results/baby-plus-test-20260821/artifacts/uiux/article-about-you.png"
printf 'PNGDATA' > "$tmp/results/baby-plus-test-20260821/artifacts/uiux/article-launch.png"
printf 'PNGDATA' > "$tmp/results/baby-plus-test-20260821/artifacts/uiux/screen3.png"
printf 'PNGDATA' > "$tmp/results/nubo-test-20260818-soak/artifacts/uiux/article-home.png"
: > "$tmp/results/mimilog-test-20260817/artifacts/uiux/broken.png"
echo notpng > "$tmp/results/baby-plus-test-20260821/artifacts/uiux/notes.txt"

# Symlinks must never pull outside-tree content into the inventory.
outside="$tmp/outside"; mkdir -p "$outside"
printf 'SECRET' > "$outside/leak.png"
mkdir -p "$tmp/results/pixy-test-20260812/artifacts" "$tmp/results/nubo-test-20260818-soak/artifacts/uiux"
ln -s "$tmp/results/nubo-test-20260818-soak/artifacts/uiux" "$tmp/results/pixy-test-20260812/uiux-link"
ln -s "$outside" "$tmp/results/pixy-test-20260812/artifacts/uiux"
ln -s "$outside/leak.png" "$tmp/results/baby-plus-test-20260821/artifacts/uiux/leak.png"

REPO_ROOT="$repo_root" FIXTURE="$tmp/results" python3 - <<'PY'
import json, os, sys
sys.path.insert(0, os.path.join(os.environ["REPO_ROOT"], "scripts"))
import uiux_inventory as inv

tree = inv.scan(os.environ["FIXTURE"])

by_slug = {row["slug"]: row for row in tree}
assert set(by_slug) == {"baby-plus", "nubo", "mimilog"}, sorted(by_slug)

bp = by_slug["baby-plus"]
assert bp["png_count"] == 3 and bp["zero_byte"] == 0, bp
assert bp["labeled"] == 2 and bp["png_count"] - bp["labeled"] == 1, bp

# The symlinked PNG is excluded from counts.
assert "leak.png" not in json.dumps(tree)
# The app whose uiux dir itself was replaced by a symlink is skipped.
pixy = [r for r in tree if r["slug"] == "pixy"]
assert pixy == [], pixy

nubo = by_slug["nubo"]
assert nubo["png_count"] == 1 and nubo["test_dirs"] == ["nubo-test-20260818-soak"], nubo

mm = by_slug["mimilog"]
assert mm["png_count"] == 1 and mm["zero_byte"] == 1, mm

# Markdown rendering includes every app row and flags the zero byte.
md = inv.markdown(tree)
for needle in ("baby-plus", "nubo", "mimilog", "1 zero-byte", "| Labeled |"):
    assert needle in md, needle

# CLI contract: --results/--format work end-to-end and JSON is stable.
import subprocess
cli = subprocess.run(
    [sys.executable, os.path.join(os.environ["REPO_ROOT"], "scripts",
                                  "uiux_inventory.py"),
     "--results", os.environ["FIXTURE"], "--format", "json"],
    capture_output=True, text=True)
assert cli.returncode == 0, cli.stderr
parsed = json.loads(cli.stdout)
assert {r["slug"] for r in parsed} == {"baby-plus", "nubo", "mimilog"}
md_cli = subprocess.run(
    [sys.executable, os.path.join(os.environ["REPO_ROOT"], "scripts",
                                  "uiux_inventory.py"),
     "--results", os.environ["FIXTURE"], "--format", "markdown"],
    capture_output=True, text=True)
assert md_cli.returncode == 0
assert "MimiLog" in md_cli.stdout and "no PNGs yet" in md_cli.stdout  # Pixy absent by default names

# Determinism: two scans produce identical JSON bytes.
again = subprocess.run(
    [sys.executable, os.path.join(os.environ["REPO_ROOT"], "scripts",
                                  "uiux_inventory.py"),
     "--results", os.environ["FIXTURE"], "--format", "json"],
    capture_output=True, text=True)
assert again.stdout == cli.stdout

# Missing-app reporting: an app with no directories shows as absent.
apps = {"Baby+": "baby-plus", "Nubo": "nubo", "MimiLog": "mimilog", "Pixy": "pixy"}
md2 = inv.markdown(tree, app_names=apps)
assert "| Pixy |" in md2 and "no PNGs yet" in md2
PY

echo "uiux-inventory tests passed"
