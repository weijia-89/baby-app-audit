# Baby App Audit

GPL-3.0

---

## What This Is

This repository contains tools to test baby tracking apps for privacy leaks. We test four apps. We answer one question for each app: does data leave the phone?

## What We Test

| App | Type | Claim |
| --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" |
| Nubo | Native Android | "Local-first" |
| Pebbi | Native Android | No claim (positive control) |
| Baby Buddy | FOSS / Web | Open-source |

## How It Works

The test harness runs on macOS with Apple Silicon. It uses an Android emulator to run the apps. It captures all network traffic with mitmproxy. It scans APK files with exodus-standalone. It decompiles code with jadx. It bypasses certificate pinning with objection.

For Baby Buddy, we also audit the source code directly.

## Test Steps

1. Install the app on the emulator.
2. Pull the APK file from the device.
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
