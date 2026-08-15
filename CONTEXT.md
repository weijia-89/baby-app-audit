# CONTEXT — state for next agent

Read this file first. It saves you from re-discovering things.

## Repo basics

- Path: `/Users/dubs/Projects/apk-privacy-harness`
- Remote: `github.com/weijia-89/baby-app-audit` (public)
- Default branch: `main`
- Current version: `3.1.1`
- Apps tested: Nurture Lock, Nubo, Pebbi, Baby Buddy
- Skills: simple-english (pragmatic mode), tic, deai (`deai-scan.py` at `/Users/dubs/Projects/deai.skill/deai-scan.py`)
- User voice: first person "I", contractions, plain words, " - " not em-dash, short declarative sentences

## Current state (after this commit)

- 17 files on main (tracked in git)
- ARTICLE.md and ORIGINAL.md deleted by operator — do not recreate
- All loop 3 fixes merged (PR #9)
- CHANGELOG: 3.1.1 entry covers loop 3 adversarial review fixes

## CI gates that must pass

- Part headers 0-10 + 5.5 in APK_PRIVACY_TEST_HARNESS.md
- `"$schema"` declaration in harness doc
- `HARNESS_VERSION="3.1.1"` in run-tests.sh, test.yml
- `## 3.1.1` in CHANGELOG.md
- Banned vocab 0 hits on 5 docs: APK_PRIVACY_TEST_HARNESS.md, README.md, METHODOLOGY.md, CHANGELOG.md, results/RESULTS-20260803.md
- JSON validation on results/schema.json and results/RESULTS-20260803.json
- `bash -n scripts/run-tests.sh` + shellcheck

## Known CI issues

- Port conflict fixed: each matrix app gets unique port (8080-8083)
- test-matrix still runs on macos-latest — no emulator in CI, only structural validation

## Known CI gotchas

- `localonly/` is gitignored, but `localonly/candidates.md` and `localonly/skeletons/*.json` are tracked project data. CI depends on them. Use `git add -f` to stage changes.
- `jsonschema` (Python) must be installed before running `test-decode-traffic.sh` — Tests 12 and 13 invoke strict-mode schema validation that fails without it.
- App list delimiter changed from space to semicolon in v3.2.0. `APK_HARNESS_APPS` entries must be separated by `;`, not spaces.
- CI smoke test normalizes hyphens to spaces before grepping `candidates.md`. If you rename an app, verify both the hyphenated slug and the spaced name appear where the test looks.
- `APK_PRIVACY_TEST_HARNESS.md` code blocks are untouchable but contain stale versions. Read `run-tests.sh` as the source of truth for current behavior.

## DO NOT REVERT (from PR #9)

- `validate_input`: strict for package_name/app_type, relaxed for app_name
- Part 7 cleanup: `adb root || true` + post-rm verification
- `set -uo pipefail` (no `-e`) in cleanup
- shred comment: "if available"
- EXODUS_IMAGE unpinned, EXODUS_DIGEST optional
- results/schema.json name: free-form string
- test_foss_app: case-based repo_url
- Proxy readback after set
- mitmproxy readiness: curl poll, not kill -0

## S4.2 canon summary

See `CANON-SUMMARY.md` for 10-line digest. Full canon at `/Users/dubs/Downloads/Baby-app-audit methodology _ verified claims canon _S4_2_.md`.

Key constraints from canon:
- Confirmed data transmission is the standard of proof (not tracker library presence)
- All counts from network capture are lower bounds
- 2025 COPPA amendments add biometric and government identifiers
- Real-time-bidding ≠ data-broker sale — keep separate
- Do not claim "first to do X" or "no prior art"
- Static UI capability findings and data-transmission findings are separate evidence streams. Static dark-pattern searching is not current scope.
- Captured reproductive-health data is sensitive — encrypt at rest, minimize retention
- All external tools must be version-pinned

## Files to check before editing

- `scripts/run-tests.sh` — 548 lines, executable, ShellCheck-clean
- `APK_PRIVACY_TEST_HARNESS.md` — reference doc, untouchable code blocks
- `.github/workflows/test.yml` — CI gates, 207 lines
- `.github/workflows/canary.yml` — weekly canary, 62 lines
- `results/schema.json` — JSON schema
- `CHANGELOG.md` — version history
- `README.md` — user-written, findings table, Discussion and Roadmap

## Skills pipeline for any .md change

1. Write content (simple-english pragmatic mode)
2. tic for style
3. `python3 /Users/dubs/Projects/deai.skill/deai-scan.py <file>`
4. Fix AI slop (em-dash → " - ", passive → active, latinate → plain)
5. Banned vocab check

## Prompt construction notes

When the user asks for two prompts (task prompt + review prompt):
- Prompt A = what to build (task instructions)
- Prompt B = how to review Prompt A (meta-review of the prompt itself, NOT a code review of the repo)
- Always state explicitly: "Review this prompt, not the codebase"
- Each posture: minimum 15 items, 75+ total
- P0-P2 bugs = fix and re-review. P3 = operator decision.
- Output only the corrected prompt after review. No verbose work narration.
