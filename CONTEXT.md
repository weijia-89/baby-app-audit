# CONTEXT  -  state for next agent

Read this file first. It saves you from re-discovering things.
Refreshed 2026-11-07 against `.github/workflows/test.yml` and repo `AGENTS.md`.

## Repo basics

- Working checkout: `/Users/dubs/Projects/baby-app-audit-sprint4` (one of several sibling checkouts of the same repo)
- Remote: `github.com/weijia-89/baby-app-audit` (public)
- Default branch: `main`
- Harness version: `3.2.0` (enforced in `scripts/run-tests.sh:11`, `.github/workflows/test.yml:15`, `canary.yml:10`)
- Apps tested: 16. Verdicts and evidence source per app: `results/RESULTS-20260803.json` and `FINAL-REPORT.md`
- Skills: simple-english (pragmatic mode), tic, deai (`deai-scan.py` at `/Users/dubs/Projects/deai.skill/deai-scan.py`)
- User voice: first person "I", contractions, plain words, " - " not em-dash, short declarative sentences

## Current state (2026-11-07)

- Sprint 5 closed with two standing exceptions (PR 67). 14 of 16 apps are `raw-replay` on the capture each row names in `results/RESULTS-20260803.json`. Baby Buddy and MimiLog stay `session-summary`.
- MimiLog's capture window is closed: Google's "Complete account setup / Review your account" hold on the test account blocks store reinstall. The operator clears that review; the harness does not bypass it. Package declares no `INTERNET`.
- PR 66 merged the marker-scan schema (`results/synthetic-baby-data.schema.json`), the strict checker (`scripts/check-marker-scans.py`), and five committed 2026-10-04 reports under `results/marker-scans/`.
- PR 68 synced the harness version citations in `FINAL-REPORT.md` and the `APK_PRIVACY_TEST_HARNESS.md` setup block to 3.2.0.
- Pebbi finding on record: it talks to `app.pebbi.co` outside the system HTTP proxy (root tcpdump saw DNS+TLS). A quiet proxy window is not proof of silence for Pebbi. Contents unread (TLS).

## CI gates that must pass (from `.github/workflows/test.yml`)

- Part headers `## Part 0` through `## Part 10`, plus `## Part 8.5`, in `APK_PRIVACY_TEST_HARNESS.md`
- `"$schema"` declaration in `APK_PRIVACY_TEST_HARNESS.md`
- Version agreement: `HARNESS_VERSION="3.2.0"` in `scripts/run-tests.sh`; `HARNESS_VERSION: "3.2.0"` in `.github/workflows/test.yml`; `## 3.2.0` section in `CHANGELOG.md`; `3.2.0` in `results/RESULTS-20260803.md`
- Banned vocab 0 hits on: `APK_PRIVACY_TEST_HARNESS.md`, `README.md`, `METHODOLOGY.md`, `CHANGELOG.md`, `ROADMAP.md`, `FINAL-REPORT.md`, `results/RESULTS-20260803.md`, `localonly/entries/TIMESTAMP_LOG.md`, `localonly/candidates.md`
- JSON validation: `results/schema.json`, `results/decode-traffic.schema.json`, `results/network-log.schema.json`, `results/analytics-pii.schema.json`, `results/synthetic-baby-data.schema.json`, `results/analytics-pii-20260803.json`, `results/RESULTS-20260803.json`, and every committed `results/network-log-*.json`
- Secret scan (gitleaks)
- `bash -n` on `scripts/run-tests.sh`, `scripts/decode-traffic.sh`, `scripts/compare-apps.sh`, `scripts/evidence-inventory.sh` (and `localonly/bursts/run-burst.sh` when present), plus `bash -n` on all `tests/*.sh`
- Unit Tests job runs the shell suites; the marker-scan checker runs in strict mode inside `scripts/run-tests.sh --check` (5 committed reports)

## Known CI issues

- Port conflict fixed: each matrix app gets a unique port (8080-8083)
- The matrix runs structural validation only; there is no emulator in CI

## Known CI gotchas

- `localonly/` is gitignored, but `localonly/candidates.md`, `localonly/entries/TIMESTAMP_LOG.md`, and `localonly/skeletons/*.json` are tracked project data. CI depends on them. Use `git add -f` to stage changes.
- `jsonschema` (Python) must be installed before running `test-decode-traffic.sh`  -  Tests 12 and 13 invoke strict-mode schema validation that fails without it.
- App list delimiter changed from space to semicolon in v3.2.0. `APK_HARNESS_APPS` entries must be separated by `;`, not spaces.
- CI smoke test normalizes hyphens to spaces before grepping `candidates.md`. If you rename an app, verify both the hyphenated slug and the spaced name appear where the test looks.
- `scripts/run-tests.sh` is the source of truth for current behavior. The version line in `APK_PRIVACY_TEST_HARNESS.md` was re-synced to 3.2.0 on 2026-10-24 (PR 68); other doc examples can still drift  -  check the script before trusting a doc snippet.

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

## Evidence rules (hard rules, from repo AGENTS.md)

- Raw captures, decode files, and network logs are permanent evidence. Never delete or sweep `results/`. Zero-byte `.mitm` files are kept.
- A negative marker verdict means "not observed in this capture window under marker search of the raw file". It never proves the app never sends the value.
- A 0-flow mitm capture is not proof an app stayed silent (apps can bypass the proxy; Pebbi does).
- Never commit gitignored evidence, `.secrets/`, `.trainer/`, raw `.mitm`, or decode JSON. Never read `.secrets/`.

## S4.2 canon summary

See `CANON-SUMMARY.md` for 10-line digest. Full canon at `/Users/dubs/Downloads/Baby-app-audit methodology _ verified claims canon _S4_2_.md`.

Key constraints from canon:
- Confirmed data transmission is the standard of proof (not tracker library presence)
- All counts from network capture are lower bounds
- 2025 COPPA amendments add biometric and government identifiers
- Real-time-bidding ≠ data-broker sale - keep separate
- Do not claim "first to do X" or "no prior art"
- Static UI capability findings and data-transmission findings are separate evidence streams. Static dark-pattern searching is not current scope.
- Captured reproductive-health data is sensitive - encrypt at rest, minimize retention
- All external tools must be version-pinned

## Files to check before editing

- `scripts/run-tests.sh`  -  the harness runner and its pre-flight checks
- `APK_PRIVACY_TEST_HARNESS.md`  -  reference doc
- `.github/workflows/test.yml`  -  CI gates
- `.github/workflows/canary.yml`  -  weekly canary
- `results/schema.json`  -  JSON schema
- `results/synthetic-baby-data.schema.json`  -  marker-scan report schema
- `CHANGELOG.md`  -  version history
- `README.md`  -  user-written, findings table, Discussion and Roadmap

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
