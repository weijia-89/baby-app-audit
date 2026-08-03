# Baby App Audit

[![Test Harness](https://img.shields.io/badge/harness-v3.0.0--loop3-blue)](APK_PRIVACY_TEST_HARNESS.md)
[![Reviews](https://img.shields.io/badge/reviews-4%20loops%2C%20226%20findings-green)](REVIEW_LOOP_1.md)
[![Postures](https://img.shields.io/badge/postures-7%20principals-orange)](#methodology)
[![Apps](https://img.shields.io/badge/apps-4%20tested-purple)](#apps-tested)
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

A hardened, reproducible test harness for auditing baby tracking apps on Android. Built through 4 adversarial review loops with 226 findings across 7 expert postures.

**Live PR:** [#1 — Harden APK Privacy Test Harness](https://github.com/weijia-89/baby-app-audit/pull/1)

---

## What We Test

We answer one question for each app: **Does data leave the phone?**

| App | Package | Type | Claim | Status |
| --- | --- | --- | --- | --- |
| [Nurture Lock](https://play.google.com/store/apps/details?id=com.angry.shark.studio.nurturelock) | `com.angry.shark.studio.nurturelock` | Native Android | "100% offline" | [Results](results/TEMPLATE.md) |
| Nubo | TBD | Native Android | "Local-first" | [Results](results/TEMPLATE.md) |
| Pebbi | TBD | Native Android | Known to share data | [Results](results/TEMPLATE.md) |
| [Baby Buddy](https://github.com/babybuddy/babybuddy) | `com.babybuddy.android` or web | FOSS / Web | Open-source | [Results](results/TEMPLATE.md) |

---

## How It Works

The harness runs on macOS Apple Silicon with an Android emulator. It captures all network traffic, scans for trackers, and audits source code.

### Test Parts

1. **Setup** — Install tools, start emulator, configure proxy.
2. **Acquisition** — Pull APK from device with hash verification.
3. **Offline Test** — Use the app. Watch for outbound requests.
4. **Static Scan** — Analyze APK for trackers and permissions.
5. **Dynamic Capture** — Record real traffic and payloads.
5.5. **FOSS Audit** — For Baby Buddy: browser test + source code audit.
6. **Covert Channels** — Check BLE, NFC, ultrasound, DNS tunneling.
7. **Cleanup** — Remove CA, uninstall apps, shred artifacts.
8. **Audit Log** — Append-only log with hash chain.
9. **Privacy** — GDPR-aligned data governance.
10. **SRE** — Canary tests, circuit breakers, SLOs.

[Read the full harness](APK_PRIVACY_TEST_HARNESS.md)

---

## Methodology

The harness was hardened through 4 adversarial review loops:

| Loop | Postures | Findings | Net New |
| --- | --- | --- | --- |
| Loop 1 | SWE, AI, QA, Security, DevOps | 90 | — |
| Loop 2 | +Privacy, +SRE | 105 | 58 (55%) |
| Loop 3 | Self-review | 10 | — |
| Loop 4 | Baby Buddy addition | 21 | — |
| **Total** | **7 principals** | **226** | **58** |

### Expert Postures

- **Principal Software Engineer** — Reproducibility, error handling, idempotency.
- **Principal AI Engineer** — Agent readiness, hallucination guards, state management.
- **Principal QA / SDET** — Test coverage, negative testing, regression prevention.
- **Principal Cybersecurity Engineer** — Supply chain, certificate management, threat modeling.
- **Principal DevOps / Platform Engineer** — Infrastructure, tooling, monitoring.
- **Principal Privacy Engineer** — GDPR, data minimization, right to erasure.
- **Principal SRE** — SLOs, circuit breakers, cascade failure prevention.

[Read the Simple English methodology doc](TESTING_METHODOLOGY_SIMPLE_ENGLISH.md)

---

## Repository Structure

```
baby-app-audit/
├── APK_PRIVACY_TEST_HARNESS.md          # v3.0.0 — The hardened test harness (1,281 lines)
├── ORIGINAL.md                          # v1.0.0 — The original document (395 lines)
├── TESTING_METHODOLOGY_SIMPLE_ENGLISH.md # How and why we tested (STE-compliant)
├── ARTICLE.md                           # Article template for publication
├── README.md                            # This file
│
├── .github/
│   └── workflows/
│       ├── test.yml                     # CI workflow for test validation
│       └── canary.yml                   # Weekly canary test schedule
│
├── results/
│   ├── schema.json                      # Machine-readable results schema
│   └── TEMPLATE.md                      # Results template
│
├── REVIEW_LOOP_1.md                     # 90 findings, 5 postures
├── REVIEW_LOOP_2.md                     # 105 findings, 7 postures
├── REVIEW_LOOP_3.md                     # 10 final findings
├── REVIEW_LOOP_4_BABY_BUDDY.md          # 21 Baby Buddy findings
│
├── PR_COMMENTS_LOOP_1.md                # Loop 1 PR documentation
├── PR_COMMENTS_LOOP_2.md                # Loop 2 PR documentation
└── PR_COMMENTS_LOOP_3.md                # Loop 3 PR documentation
```

---

## Quick Start

### Prerequisites

- macOS with Apple Silicon (M1/M2/M3)
- 4 CPU cores, 8 GB RAM, 20 GB free disk
- Homebrew
- Docker Desktop

### Install Tools

```bash
brew install --cask android-platform-tools
brew install mitmproxy@10.0.0 jadx@1.4.0
brew install --cask docker@4.30.0
pipx install objection==1.11.0
```

### Run the Test

```bash
# 1. Read the harness
open APK_PRIVACY_TEST_HARNESS.md

# 2. Set up environment variables
export WORK_DIR="${HOME}/apk-privacy-test-$(date +%Y%m%d-%H%M%S)"
export PROXY_HOST="10.0.2.2"
export PROXY_PORT="8080"

# 3. Follow the steps in the document
```

---

## CI / Automated Testing

This repository includes GitHub Actions workflows:

- **`test.yml`** — Validates harness structure on every push and PR.
- **`canary.yml`** — Runs weekly canary tests to verify harness health.

[View workflows](.github/workflows/)

---

## Results

Test results are stored in the `results/` directory using a JSON schema for machine readability.

| App | Verdict | Evidence |
| --- | --- | --- |
| Nurture Lock | TBD | [Template](results/TEMPLATE.md) |
| Nubo | TBD | [Template](results/TEMPLATE.md) |
| Pebbi | TBD | [Template](results/TEMPLATE.md) |
| Baby Buddy | TBD | [Template](results/TEMPLATE.md) |

---

## Contributing

We welcome independent verification. If you run the test and get different results, please open an issue.

### Review Process

All changes go through adversarial review. The minimum bar is:

1. **5-posture review** for structural changes.
2. **7-posture review** for privacy or SRE changes.
3. **Self-review** for documentation updates.

---

## License

[Choose a license and add it here.]

---

## Acknowledgments

This test harness was designed with input from seven synthetic expert perspectives and hardened through 226 adversarial findings.

---

*For updates, watch this repository or read the [article template](ARTICLE.md).*
