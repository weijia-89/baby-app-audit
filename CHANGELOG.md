# Changelog

## 3.1.2 - 2026-08-05

### Added
- `results/product-metadata.json` - stores product metadata outside the code.
- `results/product-metadata.schema.json` - schema for the metadata file.
- `tests/test-decode-traffic.sh` - 11 unit tests for the decoder.
- `tests/fixtures/test-capture.har` - test data for unit tests.
- CI now runs unit tests and checks product-metadata.json.
- Canary checks now validate product-metadata.json and its schema.
- decode-traffic.sh now checks that the output directory exists before writing.

### Changed
- decode-traffic.sh loads product metadata from a config file. It used to be hardcoded.
- Schema validation in decode-traffic.sh now uses an environment variable. It used to use shell string expansion.
- Python inline script in decode-traffic.sh now uses a relative path. It used to use `__file__`.
- Removed ROADMAP-PROMPT-v2.md and v3.md from git. Added them to .gitignore.
- Added a single `roadmap.md` file for the project roadmap.

### Fixed
- Python `__file__` error when running inline scripts.
- Single quote injection risk in schema file paths.
- Unit test cleanup now uses `trap EXIT` for reliability.
- Test HAR now includes matching flows so the decoder runs the full path.
- Missing config file now falls back to default values.
- Corrupted config file now falls back to default values.

## 3.1.1 - 2026-08-03

### Added
- Part 8.5 - tracks retention, security end-of-life, CVE, and device identity per product.
- `scripts/decode-traffic.sh` v2 - decodes HAR files into JSON with product metadata.
- `results/decode-traffic.schema.json` v2 - schema for decoded traffic.
- `localonly/candidates.md` - 16+ apps sorted into tiers.
- `localonly/skeletons/` - starter test entries for Tier 1-2 apps.
- `localonly/entries/TIMESTAMP_LOG.md` - template for audit logs.
- `--live` flag in `run-tests.sh` - turns on live traffic capture.
- Tool version recording in `run-tests.sh` - logs mitmproxy, adb, jadx, docker, objection versions.
- Port range 8080-8095 - supports up to 16 apps with unique ports.
- CI matrix now covers 11 apps.
- CI checks that Part headers are >= 11.

### Changed
- Removed Part 5.5 as a standalone section. Merged FOSS paths into Parts 1-3 with [FOSS] tags.
- CI babybuddy check now looks for [FOSS] tags instead of Part 5.5.
- `run-tests.sh` app list can now be set with `APK_HARNESS_APPS` environment variable.

### Fixed
- `validate_input` now uses strict mode for package names and app types. It uses relaxed mode for app names.
- Part 7 cleanup uses `adb root || true` with post-removal checks. Uses `set -uo pipefail` without `-e`.
- Part 7 shred comment now says "if available".
- EXODUS_IMAGE is no longer pinned. EXODUS_DIGEST is optional.
- `results/schema.json` name field is now a free-form string.
- `test_foss_app` now uses case-based repo_url matching.
- Proxy config now reads back after setting. Marks PROXY_NOT_SET if values do not match.
- mitmproxy readiness now polls the web port with curl for 15 seconds.
- ShellCheck now passes on run-tests.sh.

## 3.1.0 - 2026-08-03

### Added
- Nurture Lock dynamic test - caught RevenueCat API call on launch.
- Nurture Lock static analysis - found 8 tracking libraries.
- Nubo package name found - `com.clicksie.nuboapp`.
- Nubo dynamic test - Firebase sends session data, screen views, and onboarding tracking on first launch.
- Pebbi dynamic test - Firebase and version-policy checks every ~30 seconds.
- Pebbi static analysis - found Firebase, AdServices, Install Referrer, RevenueCat, PairIP LicenseCheck.
- APK downloads through apkeep from APKPure.
- System certificate install through `-writable-system` emulator flag.

### Changed
- Nurture Lock verdict - UNTESTED to FAIL. The "100% offline" claim is false.
- Nubo verdict - UNTESTED to FAIL. The "local-first" claim is false.
- Pebbi verdict - UNTESTED to FAIL. Expected for a positive control.
- Baby Buddy dynamic test now complete. Confidence 60% to 100%.
- All "we" changed to "I" in public docs.

### Anomaly
- Nubo Firebase Analytics batches had `com.pebbi.android` data and Pebbi's Firebase project ID. May be a shared library or test artifact.

### Corrected
- `.gitignore` now excludes apks/, decompiled/, capture files, runtime logs, and localonly/.
- Capture files and runtime logs removed from git tracking.
- CI checks now verify results JSON structure, schema match, version agreement, and script syntax.
- Secret scan (gitleaks) added to CI.
- RESULTS-20260803.md - fixed typos, redacted Firebase IDs and project identifiers.
- METHODOLOGY.md - rewritten in first person. Corrected consent claims and tooling claims.
- ARTICLE.md - added author and date. Fixed dead links and tooling claims.
- README.md - updated tool versions. Added emulator setup. Corrected exodus and covert-channel claims.
- Harness version now 3.1.0 across all files.
- `scripts/run-tests.sh` hardened - real package names, MITM_PID export, idempotent cleanup, work-dir opt-out, adb timeouts, split-APK dedup, JSON output with jq, honest observation window, flow export with retry, launch checks, `--check` dry-run mode.
- `results/RESULTS-20260803.json` added - machine-readable results.

## 3.0.0-loop3 - 2026-08-03

### Added
- Baby Buddy as fourth test target.
- Part 5.5 - FOSS testing with browser, Android client, and source audit paths.
- Part 9 - privacy engineering.
- Part 10 - SRE practices.
- `scripts/run-tests.sh` - automated test runs.
- `results/schema.json` - machine-readable results schema.
- `results/TEMPLATE.md` - results template.
- GitHub Actions workflows for CI and weekly canary tests.
- Article template for publication.

### Changed
- Hardened agent plan with formal DAG, JSON schema, and 15 enforced rules.
- Added consensus for critical verdicts.
- Added Byzantine fault tolerance for subagent failures.
- Added prompt injection scan.
- Pinned all tool versions.
- Added trap handlers for SIGINT and SIGTERM cleanup.
- Added input validation to stop injection.

### Fixed
- 226 findings from 4 adversarial review loops.
- Added missing tool checks for jq and git.
- Fixed race conditions in process cleanup.
- Fixed false positives in grep patterns.
- Added repository cleanup after audit.

## 2.0.0-loop1 - 2026-08-03

### Added
- Environment variable configuration.
- Error handling with `set -euo pipefail`.
- Smoke tests for all tools.
- Working directory structure with artifacts.
- Part 7 - cleanup and teardown.
- Part 8 - audit log with hash chain.
- Static scan with pinned Docker image.
- Dynamic capture with mitmproxy.
- Covert channel analysis for BLE, NFC, and ultrasound.

## 1.0.0 - Original

### Added
- Initial test harness document.
- Three test targets - Nurture Lock, Nubo, Pebbi.
- Manual test procedure for macOS.
- Agent plan for subagent execution.
