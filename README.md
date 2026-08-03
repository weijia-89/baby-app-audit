# Baby App Audit

[![Test Harness](https://img.shields.io/badge/harness-v3.0.0--loop3-blue)](APK_PRIVACY_TEST_HARNESS.md)
[![Apps](https://img.shields.io/badge/apps-4%20tested-purple)](#apps-tested)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

A hardened, reproducible test harness for auditing baby tracking apps on Android.

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

## Repository Structure

```
baby-app-audit/
├── APK_PRIVACY_TEST_HARNESS.md          # v3.0.0 — The hardened test harness
├── ORIGINAL.md                          # v1.0.0 — The original document
├── ARTICLE.md                           # Article template for publication
├── README.md                            # This file
├── LICENSE                              # GPL-3.0
│
├── .github/
│   └── workflows/
│       ├── test.yml                     # CI workflow for test validation
│       └── canary.yml                   # Weekly canary test schedule
│
├── results/
│   ├── schema.json                      # Machine-readable results schema
│   ├── TEMPLATE.md                      # Results template
│   └── RESULTS-*.md                     # Actual test results
│
└── scripts/
    └── run-tests.sh                     # Test execution script
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

## License

This project is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for the full license text.

---

## Acknowledgments

This test harness was hardened through adversarial review across seven expert perspectives.
