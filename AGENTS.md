# AGENTS.md — APK Privacy Test Harness

## Skills Pipeline for .md Changes

Any change to a `.md` file must run through this pipeline before commit.

```bash
# 1. Write content (simple-english pragmatic mode)
# 2. Check style manually with the simple-english rules. No TIC script is present in this checkout.
# 3. Scan for AI tells
python3 /Users/dubs/Projects/deai.skill/deai-scan.py <file>
# 4. Fix AI slop manually:
#    - em-dash -> " - "
#    - passive -> active
#    - latinate -> plain
```

Steps 1, 2, and 4 are manual. Step 3 is automated. Run all four before committing any `.md` file.

## Review Depth

Reviews come in two depths. Pick based on risk.

### Lightweight (P1 Only)

Use for small fixes, doc updates, config changes.

```bash
# Run the banned-vocabulary check from .github/workflows/test.yml
# ("Check for banned vocabulary" step - single source of truth)
bash -n scripts/run-tests.sh && bash scripts/run-tests.sh --check
bash -n scripts/compare-apps.sh && bash scripts/compare-apps.sh --check
```

### Deep (P1 + P2 + P3)

Use for new features, security changes, schema changes.

```bash
# P1: all lightweight checks above, plus:
# P2: shellcheck on all scripts
shellcheck scripts/*.sh
# P2: JSON schema validation
python3 -m json.tool results/schema.json > /dev/null
python3 -m json.tool results/decode-traffic.schema.json > /dev/null
python3 -m json.tool results/comparison.schema.json > /dev/null
python3 -m json.tool results/network-log.schema.json > /dev/null
# P2: run all unit tests
bash tests/test-decode-traffic.sh
bash tests/test-compare-apps.sh
# P3: full harness dry run
bash scripts/run-tests.sh --check

Set `REVIEW_DEPTH=light` or `REVIEW_DEPTH=deep` in your environment to signal intent.

## CI Gates

These must pass on every push:

- Part headers 0-10 + 8.5 in APK_PRIVACY_TEST_HARNESS.md
- `"$schema"` declaration in harness doc
- `HARNESS_VERSION` agreement across run-tests.sh and test.yml
- `## 3.3.0` in CHANGELOG.md
- Banned vocab 0 hits on all public .md files
- JSON validation on results/*.json
- `bash -n` + shellcheck on all scripts
- All unit tests pass

## Evidence retention (HARD RULE)

Raw captures, decode files, and network logs are permanent evidence. Never delete, sweep, or "clean" them.

- The evidence tree is: `results/*-test-*/` (captures, HARs, logs, reports), `results/decode-traffic-*.json`, `results/network-log-*.json`, `results/*.mitm`, `results/mitm-capture/`.
- NEVER run `rm`, `rm -rf`, `find -delete`, or a cleanup pass over `results/`. There is no retention window: METHODOLOGY's old 90-day deletion policy no longer applies; evidence stays on disk indefinitely (gitignored for secrets, never committed).
- The only legitimate deletion is the harness's own `WORK_DIR` under `${HOME}/apk-privacy-test-*` (it deletes only what it created). `KEEP_WORK_DIR=1` preserves even that.
- Never sweep or run a "git tree clean of test artifacts" pass unless a verified backup restores the files.
- Mechanical backstop: `scripts/evidence-inventory.sh --check` fails the harness pre-flight when a committed network log is missing or a preserved capture is zero-byte. It warns on rotted decode files. Run it directly before any deletion: `bash scripts/evidence-inventory.sh --check`.
- Lost-capture knowledge: the pre-2026-08-14 legacy sessions (nurture-lock, nubo, pebbi, amila, baby-buddy, baby-daybook, baby-plus, mimilog) have NO raw captures left on disk. Their results are decode-level (`evidence_source: session-summary`); do not re-derive full-depth claims from them, and never describe them as raw-replay evidence. See ROADMAP.md for the recapture milestone.

## Secret hygiene — result artifacts

Captured traffic artifacts contain live secrets. `.gitignore` excludes them on purpose.

- `results/decode-traffic-*.json` and `*.mitm` captures contain captured Firebase JWTs, refresh tokens, and installation IDs.
- NEVER `git add -f` or commit these files. Force-adding them leaks secrets AND fails CI (gitleaks detects the JWTs).
- If a report needs to link per-app artifacts, link the committed, sanitized `results/network-log-*.json` logs instead.
- Raw network captures are generated locally and stay local only. See `METHODOLOGY.md` (Redaction) for the full policy.

## Sprint 6 Closeout

Sprint 6 closeout finalizes the baby-app-audit project's sprint cycle. All prerequisites verified:

- FINAL-REPORT.md complete with standardized Burst verdicts
- CHANGELOG 4.0.0 status marked Complete
- README "What is next" section updated
- Git tree clean of test artifacts (comparison-burst-5.log removed)
- Merge commit to main: fix/burst-2-har-dump-fix integrated
- Pipeline checks: run-tests.sh --check passes, schema validation, unit tests

Outputs delivered:
- Sprint-6 closeout documented in this AGENTS.md section and the merge commit
- Branch merged to main with all sprint 4 changes
- AGENTS.md updated with sprint-6 section
