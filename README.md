# Baby App Audit

GPL-3.0

---

## What This Is

This repository contains tools to test baby tracking apps for privacy leaks. We test four apps. We answer one question for each app: does data leave the phone?

## What We Test

| App | Type | Claim | Status |
| --- | --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" | Not tested — requires emulator |
| Nubo | Native Android | "Local-first" | Not tested — requires emulator |
| Pebbi | Native Android | No claim | Not tested — requires emulator |
| Baby Buddy | FOSS / Web | Open-source | Source audit complete — see findings |

## Baby Buddy Findings

We audited Baby Buddy (https://github.com/babybuddy/babybuddy) on 2026-08-03. We tested commit `16b8848c7bc2031fc5936f8da89c8056ec5624d2`.

### Source Code Audit

We cloned the repository and searched for:
- Network calls (HTTP/HTTPS, fetch, WebSocket, etc.)
- Analytics or tracking libraries
- Third-party data sharing

**Results:**
- 67 network references found. These are all in Django documentation comments or configuration examples. No active tracking code.
- 0 tracker libraries found. We searched for Google Analytics, Mixpanel, Segment, Sentry, Firebase, Matomo, Plausible, and others. None present.
- No data exfiltration endpoints in application code.
- License: BSD-2-Clause (permissive open-source license).

### Dynamic Test

We ran Baby Buddy locally on `http://localhost:8000`. We captured traffic with mitmproxy. We logged in and navigated the app.

**Results:**
- All traffic stayed on localhost. No outbound requests.
- No calls to external APIs, CDNs, or analytics services.
- Static files served locally.

### Verdict

**PASS.** Baby Buddy does not send data off-device in its default configuration. The source code contains no tracking libraries. The app is self-hostable and does not require external services.

**Caveat:** We tested the default configuration. A user could configure external services (AWS S3, etc.) via environment variables. Those configurations are optional and documented.

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

## Results

Results are in the `results/` directory. Each app gets a JSON file with findings.

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

## License

This project is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for the full license text.
