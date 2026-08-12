# AGENTS.md — APK Privacy Test Harness

## Skills Pipeline for .md Changes

Any change to a `.md` file must run through this pipeline before commit.

```bash
# 1. Write content (simple-english pragmatic mode)
# 2. Check style
bash /Users/dubs/Projects/toren/tic.skills/tic.sh <file>
# 3. Scan for AI tells
python3 /Users/dubs/Projects/deai.skill/deai-scan.py <file>
# 4. Fix AI slop manually:
#    - em-dash -> " - "
#    - passive -> active
#    - latinate -> plain
```

Steps 1 and 4 are manual. Steps 2, 3, 5 are automated. Run all five before committing any `.md` file.

## Review Depth

Reviews come in two depths. Pick based on risk.

### Lightweight (P1 Only)

Use for small fixes, doc updates, config changes.

```bash
# Run P1 checks only: syntax, banned vocab, schema, version agreement
bash -n scripts/run-tests.sh && bash scripts/run-tests.sh --check
bash -n scripts/detect-dark-patterns.sh && bash scripts/detect-dark-patterns.sh --check
bash -n scripts/compare-apps.sh && bash scripts/compare-apps.sh --check
grep -qiE "\b(WORD_A|WORD_B)\b" APK_PRIVACY_TEST_HARNESS.md README.md METHODOLOGY.md CHANGELOG.md && exit 1
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
python3 -m json.tool results/dark-patterns.schema.json > /dev/null
python3 -m json.tool results/comparison.schema.json > /dev/null
# P2: run all unit tests
bash tests/test-decode-traffic.sh
bash tests/test-dark-patterns.sh
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

## Secret hygiene — result artifacts

Captured traffic artifacts contain live secrets. `.gitignore` excludes them on purpose.

- `results/decode-traffic-*.json` and `*.mitm` captures contain captured Firebase JWTs, refresh tokens, and installation IDs.
- NEVER `git add -f` or commit these files. Force-adding them leaks secrets AND fails CI (gitleaks detects the JWTs).
- If a report needs to link per-app artifacts, link the committed, sanitized `results/dark-patterns-*.json` scans instead.
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