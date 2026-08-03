# Baby App Audit

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.14-blue.svg)](https://python.org)
[![Django](https://img.shields.io/badge/django-5.2-green.svg)](https://djangoproject.com)

Test baby tracking apps for privacy leaks. This tool checks if data leaves your phone.

---

## What This Is

This repository contains tools to test baby tracking apps for privacy leaks. We test four apps. We answer one question for each app: does data leave the phone?

Parents use baby tracking apps to record feeding, sleep, and diaper changes. These apps hold sensitive data about babies. Some apps claim that data never leaves the phone. We wanted to know if that claim is true.

If an app says "100% offline" but sends data to a server, the claim is false. One outbound packet is enough to prove it false.

## What We Test

| App | Type | Claim |
| --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" |
| Nubo | Native Android | "Local-first" |
| Pebbi | Native Android | No claim (positive control) |
| Baby Buddy | FOSS / Web | Open-source |

## How It Works

The test harness runs on macOS with Apple Silicon. It uses an Android emulator to run native apps. It captures all network traffic with mitmproxy. It scans APK files with exodus-standalone. It decompiles code with jadx. It bypasses certificate pinning with objection.

For web apps like Baby Buddy, we run the app locally and capture browser traffic.

## Test Steps

1. Install the app on the emulator (or run locally for web apps).
2. Pull the APK file from the device (for native apps).
3. Compute a SHA-256 hash of the APK.
4. Run the app and use it normally.
5. Watch mitmproxy for outbound requests.
6. Run a static scan for trackers and permissions.
7. Capture dynamic traffic.
8. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling).

## Quick Start

Install the tools:

```bash
brew install --cask android-platform-tools
brew install mitmproxy@10.0.0 jadx@1.4.0
brew install --cask docker@4.30.0
pipx install objection==1.11.0
```

Run the test:

```bash
bash scripts/run-tests.sh
```

Read the full harness for manual steps:

```bash
open APK_PRIVACY_TEST_HARNESS.md
```

## Requirements

- macOS with Apple Silicon
- 4 CPU cores
- 8 GB RAM
- 20 GB free disk space

---

## Results

### Baby Buddy

We audited Baby Buddy (https://github.com/babybuddy/babybuddy) on 2026-08-03. We tested commit `16b8848c7bc2031fc5936f8da89c8056ec5624d2`.

#### Source Code Audit

We cloned the repository and searched for:
- Network calls (HTTP/HTTPS, fetch, WebSocket, etc.)
- Analytics or tracking libraries
- Third-party data sharing

**Results:**
- 67 network references found. These are all in Django documentation comments or configuration examples. No active tracking code.
- 0 tracker libraries found. We searched for Google Analytics, Mixpanel, Segment, Sentry, Firebase, Matomo, Plausible, and others. None present.
- No data exfiltration endpoints in application code.

#### Dynamic Network Test

We ran Baby Buddy locally on `http://localhost:8000`. We set up mitmproxy to capture traffic. We logged in and navigated the app.

**Results:**
- All traffic stayed on localhost. No outbound requests.
- No calls to external APIs, CDNs, or analytics services.
- Static files served locally.

**Note:** We verified network isolation by checking that all HTTP requests went to `127.0.0.1:8000` or `localhost:8000`. The mitmproxy capture confirms no external destinations.

#### Verdict

**PASS.** Baby Buddy does not send data off-device in its default configuration. The source code contains no tracking libraries. The app is self-hostable and does not require external services.

**Caveat:** We tested the default configuration. A user could configure external services (AWS S3, etc.) via environment variables. Those configurations are optional and documented.

### Nurture Lock, Nubo, Pebbi

**Status:** Not tested. These require an Android emulator setup.

To test these apps:
1. Install Android SDK platform-tools
2. Create an Android emulator (API 28, arm64)
3. Install apps from Google Play
4. Run `bash scripts/run-tests.sh`

## Artifacts

Network capture logs for Baby Buddy test:
- `results/baby-buddy-test-20260803/baby-buddy-flows.mitm` — mitmproxy capture file
- `results/baby-buddy-test-20260803/flows.txt` — Human-readable flow list

## Sources

- Baby Buddy repository: https://github.com/babybuddy/babybuddy
- Baby Buddy documentation: https://docs.baby-buddy.net
- Baby Buddy license (BSD-2-Clause): https://github.com/babybuddy/babybuddy/blob/master/LICENSE
- mitmproxy: https://mitmproxy.org
- Exodus Privacy: https://exodus-privacy.eu.org

---

## License

This project is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for the full license text.
