# Changelog

## 4.0.0 - Sprint 4 - In Progress

### Added
- Burst 1 re-test complete: original 4 apps (Nurture Lock, Nubo, Pebbi, Baby Buddy) tested with Sprint 3 criteria.
- `scripts/har_dump.py`: Minimal mitmproxy addon for `.mitm` capture → HAR conversion. Enables downstream `decode-traffic.sh` processing in the burst pipeline.
- `results/comparison-burst-1.json`: Cross-app comparison for Burst 1 (3 native apps, 0 shared trackers).
- Sprint 3 fields added to `results/product-metadata.json`: `dark_patterns_notes`, `static_analysis_notes`, `source_audit_notes`.
- Dark pattern scans re-run for Burst 1: nurture-lock (2 patterns), nubo (3 patterns), pebbi (2 patterns).
- Decode traffic reports generated for all native apps in Burst 1.

### Changed
- `scripts/run-tests.sh`: Switch `mitmweb` → `mitmdump` for headless proxy operation. No browser tabs open during automated testing.
- `.github/workflows/test.yml`: Update canary tool verification from `mitmweb` to `mitmdump`.
- `localonly/bursts/run-burst.sh`: Add HAR conversion + `decode-traffic.sh` invocation after each app test.

### Fixed
- `localonly/bursts/run-burst.sh`: Fix `local` variable scope bug in subshell context.

### Planned
- Burst 2: Tier 1 apps + Privacy-first batch 1 (BabyTrack, Amila, Wachanga, Baby Daybook, Baby+, Cradly)
- Burst 3: Tier 2 apps (NighP, Milli, Baby Connect, SNUGL, Talli Baby)
- Burst 4: FOSS candidates (LunaTracker, MimiLog, Sara Baby Tracker, Dymn Baby)
- Burst 5: Privacy-first batch 2 (BabyLog, Nara, Heartful Baby, Nestling, Pixy, Nurture Lock variant)
- Burst 6: Wearable / IoT (Owlet Sock, Owlet Cam, Nanit, Miku, Snuza)
- Final report synthesizing all burst findings
- Methodology publication and tool open-sourcing

## 3.3.0 - 2026-08-05

### Added
- Owlet ecosystem testing: Owlet Sock and Owlet Cam added to candidates.md with MDR/RED regime, verified CVE data from NVD, and test plan.
- `scripts/detect-dark-patterns.sh` v1: Static dark pattern detection in APK resources.
- `results/dark-patterns.schema.json`: Schema for dark pattern detection output.
- `tests/test-dark-patterns.sh`: 7 unit tests for the dark pattern detector.
- `scripts/compare-apps.sh` v1: Cross-app data comparison for decoded traffic JSON files.
- `results/comparison.schema.json`: Schema for cross-app comparison output.
- `tests/test-compare-apps.sh`: 7 unit tests for the comparison script.
- Dark pattern detection methodology documented in METHODOLOGY.md.
- `localonly/skeletons/owlet-sock.json` and `owlet-cam.json`: Skeleton entries for wearable devices.
- `localonly/entries/owlet-test-plan.md`: Documented test plan for Owlet ecosystem.

### Changed
- `decode-traffic.sh` FILTER_HOST now includes Owlet apps (`com.owletcare.sock`, `com.owletcare.cam`).
- `results/product-metadata.json` now includes entries for Owlet Sock and Owlet Cam with retention, CVE, and regime data.
- `localonly/candidates.md` per-product config table updated with verified Owlet CVE data.

### Fixed
- Corrected CVE mapping: CVE-2023-6321 and CVE-2023-6323 both affect Owlet Cam, not Owlet Sock.

## 3.2.0 - 2026-08-05

### Added
- Schema enforcement gate in CI. `decode-traffic.sh` now supports `DECODE_TRAFFIC_STRICT=1` mode.
- Strict mode exits with code 1 when output does not conform to `results/decode-traffic.schema.json`.
- CI unit-tests job now runs strict-mode validation on every build.
- `SCHEMA_FILE` environment variable overrides the default schema path.
- Two new unit tests for strict mode (valid pass, invalid fail).
- Tier 1 apps added to harness: BabyTrack, Amila, Wachanga.

### Changed
- decode-traffic.sh schema validation now captures exit code correctly. It used to mask failures.
- decode-traffic.sh schema file path is now overridable via `SCHEMA_FILE` env var.
- `run-tests.sh` app list delimiter changed from space to semicolon. This fixes word-splitting on app names with spaces.

### Fixed
- `run-tests.sh` no longer breaks multi-word app names (e.g., "Baby Buddy", "Nurture Lock") due to bash word splitting.
- `decode-traffic.sh` now uses `printf` instead of `echo` for JSON output to avoid flag injection.
- `decode-traffic.sh` FILTER_HOST now includes Tier 1 apps (BabyTrack, Amila, Wachanga).
- `tests/test-decode-traffic.sh` cleanup trap now removes all test fixtures.
- `tests/test-decode-traffic.sh` Tests 12 and 13 now use distinct output files.
- `tests/test-decode-traffic.sh` Tests 12 and 13 now capture stderr for debugging.
- CI `unit-tests` job now has `timeout-minutes: 10`.
- CI schema validation gate now pins `jsonschema==4.26.0`.
- CI schema validation gate now writes to workspace instead of `/tmp`.
- CI now validates `localonly/skeletons/*.json` are valid JSON.
- CI `generate-summary` now reads app list dynamically from `test-matrix` output.
- CI `download-artifact` now uses `if-no-files-found: ignore`.
- CI `canary.yml` now actually runs unit tests and harness dry-run.
- `run-tests.sh` now detects and converts deprecated space-delimited `APK_HARNESS_APPS`.

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
- Part 8.5: Per-product retention, security EOL/CVE, and device identity tracking.
- `scripts/decode-traffic.sh` v2: Decodes HAR captures into structured JSON with product metadata.
- `results/decode-traffic.schema.json` v2: Schema for decoded traffic with retention_schedule, security_eol, cve_list, regulatory_regime.
- `localonly/candidates.md`: 16+ discovered apps in Tier 1-3, wearable/IoT, and out-of-scope lists.
- `localonly/skeletons/`: Skeleton test entries for Tier 1-2 apps.
- `localonly/entries/TIMESTAMP_LOG.md`: Audit log entry template.
- `--live` flag in `run-tests.sh`: Enables live traffic capture mode.
- Tool version recording in `run-tests.sh`: Records mitmproxy, adb, jadx, docker, objection versions.
- Port allocation 8080-8095: Supports up to 16 apps with unique PROXY_PORT per app.
- CI matrix expanded to 11 apps: nurturelock, nubo, pebbi, babybuddy, babytrack, amila, wachanga, nighp, milli, baby-connect, snugl.
- CI regression check: Part header count >= 11.

### Changed
- Removed standalone Part 5.5; merged FOSS paths into Parts 1-3 with **[FOSS]** tags.
- CI babybuddy check: changed from "Part 5.5" grep to **[FOSS]** tag grep.
- `run-tests.sh`: App list configurable via `APK_HARNESS_APPS` env var.

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
