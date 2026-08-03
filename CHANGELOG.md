# Changelog

## 3.0.0-loop3 — 2026-08-03

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

## 2.0.0-loop1 — 2026-08-03

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

## 1.0.0 — Original

### Added
- Initial test harness document.
- Three test targets: Nurture Lock, Nubo, Pebbi.
- Manual test procedure for macOS.
- Agent plan for subagent execution.
