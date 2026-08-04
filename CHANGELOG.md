# Changelog

## 3.1.1 - 2026-08-03

### Fixed
- `validate_input`: strict mode for package_name/app_type, relaxed mode for app_name (spaces allowed).
- Part 7 cleanup: `adb root || true` with post-rm verification. `set -uo pipefail` (no `-e`).
- Part 7 shred comment: "if available" (not "if not available").
- EXODUS_IMAGE unpinned. EXODUS_DIGEST optional. Never add hardcoded digest.
- `results/schema.json` name: free-form string, no enum.
- `test_foss_app`: case-based repo_url resolution.
- Proxy config: reads back after set; marks PROXY_NOT_SET if mismatch.
- mitmproxy readiness: polls web port with curl (15s), not kill -0.
- ShellCheck compliance across run-tests.sh.

## 3.1.0 - 2026-08-03

### Added
- Nurture Lock dynamic test: RevenueCat subscriber API call captured on launch.
- Nurture Lock static analysis: 8 tracking libraries confirmed (RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, Tenjin).
- Nubo package name resolved: `com.clicksie.nuboapp`.
- Nubo dynamic test: Firebase (Installations, Crashlytics, Analytics, FCM) on first launch with session data, screen views, splash timing, onboarding tracking.
- Pebbi dynamic test: Firebase, version-policy phoning home every ~30s, FCM registration.
- Pebbi static analysis: Firebase, AdServices, Install Referrer, RevenueCat, PairIP LicenseCheck.
- APK downloads via apkeep (APKPure source).
- System certificate installation via `-writable-system` emulator flag.

### Changed
- Nurture Lock verdict: UNTESTED -> FAIL ("100% offline" claim is false)
- Nubo verdict: UNTESTED -> FAIL ("local-first" claim is false)
- Pebbi verdict: UNTESTED -> FAIL (as expected for positive control)
- Baby Buddy: dynamic test now completed, confidence 60% -> 100%
- All "we" language replaced with "I" in public docs

### Anomaly
- Nubo Firebase Analytics batches contained `com.pebbi.android` data and Pebbi's Firebase project ID. Possible shared library or test artifact.

### Corrected
- `.gitignore` added - apks/, decompiled/, capture files (can contain tokens), runtime logs, and localonly/ are excluded from git.
- Capture files and runtime logs removed from git tracking (evidence preserved locally).
- CI review-file checks replaced: the internal review docs were removed by design (evidence lives in git history and `localonly/`). The checks now confirm results JSON structure, schema conformance, version agreement, and script syntax.
- Secret scan (gitleaks) added to CI.
- RESULTS-20260803.md: typos fixed (app.pebbi.co, Pebbi, feebbi), Firebase installation ID and project identifiers redacted from the public document.
- METHODOLOGY.md rewritten in first person ("we" removed) and corrected: no consent claim (no real user data), exodus-standalone not run, radio covert-channel checks not performed.
- ARTICLE.md: first person, author/date filled, dead references fixed (METHODOLOGY.md, results links), tooling claims corrected.
- README.md: tool versions updated to tested versions, emulator setup steps added, exodus/covert-channel claims corrected, Python/Django badges removed.
- Harness version unified to 3.1.0 across run-tests.sh, workflows, results, template, and harness document.
- `scripts/run-tests.sh` hardened: real package names for Nubo/Pebbi, MITM_PID exported for trap cleanup, idempotent cleanup, work-dir opt-out (KEEP_WORK_DIR), adb timeouts, split-APK pull dedup, JSON output built with jq (schema-conformant), honest observation window instead of a silent placeholder, flow export with retry and correct parsing, launch verification, `--check` dry-run mode.
- `results/RESULTS-20260803.json` added - machine-readable results conforming to schema.json.

## 3.0.0-loop3 - 2026-08-03

### Added
- Baby Buddy as fourth test target (FOSS / web app).
- Part 5.5: FOSS testing with browser, Android client, and source audit paths.
- Part 9: Privacy engineering (GDPR, data minimization, right to erasure).
- Part 10: SRE (canary tests, circuit breakers, SLOs).
- `scripts/run-tests.sh`: Automated test execution.
- `results/schema.json`: Machine-readable results schema.
- `results/TEMPLATE.md`: Results template.
- GitHub Actions workflows for CI and weekly canary tests.
- Article template for publication.

### Changed
- Hardened agent plan with formal DAG, JSON schema, 15 enforced rules.
- Added consensus mechanism for critical verdicts.
- Added Byzantine fault tolerance for subagent failures.
- Added prompt injection scan (Rule 12).
- Pinned all tool versions for reproducibility.
- Added trap handlers for SIGINT/SIGTERM cleanup.
- Added input validation to prevent injection.

### Fixed
- 226 findings from 4 adversarial review loops.
- Added missing tool checks (jq, git).
- Fixed race conditions in process cleanup.
- Fixed false positives in grep patterns.
- Added repository cleanup after audit.

## 2.0.0-loop1 - 2026-08-03

### Added
- Environment variable configuration.
- Error handling with `set -euo pipefail`.
- Smoke tests for all tools.
- Working directory structure with artifacts.
- Part 7: Cleanup and teardown.
- Part 8: Audit log with hash chain.
- Static scan with pinned Docker image.
- Dynamic capture with mitmproxy.
- Covert channel analysis (BLE, NFC, ultrasound).

## 1.0.0 - Original

### Added
- Initial test harness document.
- Three test targets: Nurture Lock, Nubo, Pebbi.
- Manual test procedure for macOS.
- Agent plan for subagent execution.
