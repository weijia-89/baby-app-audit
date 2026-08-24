# Baby App Audit

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

An audit of baby and parenting apps to see how much data companies collect.

---

## What This Is

Parents use baby tracking apps to record feeding, sleep, and diaper changes. Most parents do not want that data saved in a database for later resale.

Some apps claim data never leaves the phone. No independent audit has backed that claim. Given the history of [certain applications](https://doi.org/10.3390/jcp3030016) with [broken privacy promises](https://www.bitdefender.com/en-us/blog/labs/notes-on-throughtek-kalay-vulnerabilities-and-their-impact), I completed an actual audit.

## What Was Tested

| App | Type | Claim |
| --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" |
| Nubo | Native Android | "Local-first" |
| Pebbi | Native Android | No claim (positive control) |
| Baby Buddy | FOSS / Web | Open-source |
| Amila | Native Android | No claim |
| Baby Daybook | Native Android | "AdID not auto-enabled" |
| Baby+ | Native Android | "AdID not auto-enabled" |
| MimiLog | Native Android | "Fully offline" |
| Nara | Native Android | "Complete privacy" |
| Heartful Baby | Native Android | "HIPAA-compliant" |
| Pixy | Native Android | "Bank-level encryption" |
| BabyCenter | Native Android | No claim |
| BellyBloom | Native Android | No claim |
| Nanit | Native Android | No claim |
| Pregnancy+ | Native Android | No claim |
| What to Expect | Native Android | No claim |

These were apps my partner and I researched. The internet recommended them as "private."

Baby Buddy is a FOSS option. I added it as a control since the codebase is fully auditable. But I subjected it to the same review and network scrutiny as the rest.

I also found 16+ additional candidates. They are in `localonly/candidates.md` and split into Tier 1 (test next), Tier 2 (test later), Tier 3 (low priority), wearable/IoT, and out-of-scope.

## How I Test

* An LLM paired with a test harness that runs an Android emulator.
* mitmproxy captures and logs network traffic.
* jadx decompiles code.

For web apps like Baby Buddy, I run the app locally and capture browser traffic.

**Tool versions (2026-08-09):** mitmproxy 12.2.3, jadx 1.5.6, objection 1.12.5, adb 37.0.1, apkeep 1.0.0.

## Test Steps (If You Want to Do It Yourself)

1. Install the app on the emulator (or run locally for web apps).
2. Pull the APK file from the device (for native apps).
3. Compute a SHA-256 hash of the APK.
4. Run the app and use it normally.
5. Watch mitmproxy for outbound requests.
6. Run a static scan for analytics, replay, advertising, diagnostics, and permissions.
7. Capture dynamic traffic.
8. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling).
9. Enter fictional baby data and monitor every call for that data.
10. Run the full analytics and PII fanout scan.

Note - Radio checks need physical hardware. I did not perform them. They are also an impractical way to siphon data. Future work may add them if accessories use these protocols to sync with the app. The current focus is on the apps alone.

## Quick Start

Install the tools:

```bash
brew install --cask android-platform-tools
brew install mitmproxy jadx apkeep
brew install --cask docker
pipx install objection
```

`apkeep` downloads APKs from APKPure when an app is not already on disk. The test runner calls it to fetch each app before the audit. Split APKs (`.xapk`) need to be extracted first; use `unzip` then `adb install-multiple` with the base APK plus the matching `config.<abi>.apk` and locale packs you need.

Set up the emulator once:

```bash
# Create an API 28 AVD with Google APIs (arm64)
avdmanager create avd -n apk-test-api28 -k "system-images;android-28;google_apis;arm64-v8a"
emulator -avd apk-test-api28 -writable-system -no-snapshot &
# Install the mitmproxy CA certificate as a system certificate (see Part 0 of the harness)
```

Run the test:

```bash
bash scripts/run-tests.sh
```

Validate the tooling without an emulator (used by CI):

```bash
bash scripts/run-tests.sh --check
```

Google sign-in needs the audit proxy off. Optional Appium login:

```bash
appium '--allow-insecure=*:chromedriver_autodownload'
.test-venv/bin/python scripts/appium-webview-login.py --package com.hp.babyapp
```

Read the full harness for manual steps:

```bash
open APK_PRIVACY_TEST_HARNESS.md
```

---

## Results

Full results with evidence: [FINAL-REPORT.md](FINAL-REPORT.md) and machine-readable [results/RESULTS-20260803.json](results/RESULTS-20260803.json). See [CHANGELOG.md](CHANGELOG.md) for history.

### How to read the results

The full picture is in [FINAL-REPORT.md](FINAL-REPORT.md). Each app has its own section with evidence: what the app claims, what we captured, and how the verdict was reached.

The privacy marks say what the app actually did:

- **💖** means the app passed and behaved as described.
- **❕** means the app failed, but the capture showed phone-home traffic without identifying user data.
- **🚫** means the app failed and the capture showed identifying data or extensive tracking.

An app with no privacy claim cannot fail, because there is no promise to break. Its result says "no claim"; the privacy mark still shows what we observed.

Every failed app links to its own sanitized network log (`results/network-log-<app>.json`). The logs list hosts, redacted paths, status codes, flow counts, request and response sizes, JSON body keys, header-flag names, and redaction slugs for each captured flow. They contain no query strings, header values, or body values. The slugs state what was removed and why. The method, host, path, status, count, and sizes remain, so the record still proves that the call was sent. The logs are generated from the raw `.mitm` captures by `scripts/build-network-logs.sh`; the raw captures stay local only.

The machine-readable summary is [results/RESULTS-20260803.json](results/RESULTS-20260803.json). Each app row carries an `evidence_source`: `raw-replay` (every flow in the preserved capture was replayed and mined) or `session-summary` (raw capture no longer exists; results rest on the original session summaries). The eight session-summary apps are lower-bound evidence until the planned legacy re-capture. See [CHANGELOG.md](CHANGELOG.md) for history.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open-source | PASS | 💖 | 100% | No tracking libraries. All traffic stays on localhost in default configuration |
| MimiLog | "Fully offline" | PASS | 💖 | 100% | One Firebase configuration call; the device held no valid Firebase project, so no data was exchanged |
| Amila | No claim | No claim | ❕ | 90% | Firebase Installations, Firebase Remote Config, and Google Fonts calls on launch |
| Baby+ | "AdID not auto-enabled" | FAIL | ❕ | 90% | Philips server, Firebase, and Google calls on launch. The AdID claim does not cover this traffic |
| Heartful Baby | "HIPAA-compliant" | FAIL | ❕ | 90% | One Firebase logging batch on launch |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 🚫 | 90% | Firebase and RevenueCat calls on launch; Facebook SDK found in code. The AdID claim does not cover this traffic |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | Nine Facebook Graph API calls and one Crashlytics report batch on launch |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | Sends session analytics, screen views, and onboarding events to Google Firebase on first launch |
| Nurture Lock | "100% offline" | FAIL | 🚫 | 95% | Phones home to RevenueCat with device identifiers on launch. 8 tracking libraries found in the APK |
| Pebbi | No claim (positive control) | No claim | 🚫 | 100% | Extensive data collection via Firebase, Google AdServices, and FCM registration |
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | Three Facebook Graph API calls on launch |
| BabyCenter | No claim | No claim | 🚫 | 95% | AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |
| BellyBloom | No claim | No claim | 🚫 | 90% | Adjust, DoubleClick, Facebook, and Firebase calls on launch |
| Nanit | No claim | No claim | 🚫 | 95% | Firebase, Microsoft Clarity, Localytics, Cordial, and Coralogix flows plus the Nanit API on launch; no ad-network SDK |
| Pregnancy+ | No claim | No claim | 🚫 | 95% | Firebase, Facebook, Microsoft Clarity, Adapty, and OneSignal flows on launch, including install attribution |
| What to Expect | No claim | No claim | 🚫 | 90% | AppsFlyer, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |

The full procedure is in [APK_PRIVACY_TEST_HARNESS.md](APK_PRIVACY_TEST_HARNESS.md). Method, consent, and known limits (no radio checks, no static scan for Nubo) are in [METHODOLOGY.md](METHODOLOGY.md).

Pairip **CLOSE** (stub Play Store) and Pairip native crashes on this emulator are environment blockers. They are not privacy PASS or FAIL. See METHODOLOGY.md "Environment blockers".

## Discussion and Roadmap

This project tests baby and parenting apps against their privacy claims. The current work covers 16 apps. The full results are in [FINAL-REPORT.md](FINAL-REPORT.md).

### What the project can do

* **Live data collection:** `scripts/decode-traffic.sh` decodes network captures into structured JSON with per-app metadata.
* **Cross-app comparison:** `scripts/compare-apps.sh` compares network traffic across apps to find shared trackers.
* **Test results:** `FINAL-REPORT.md` has the verdict table plus a short per-app block. Host, path, status, and sizes stay in `results/network-log-<app>.json`.
* **Full analytics and PII fanout:** `scripts/scan-analytics-pii.sh` scans every committed network log, including unclassified hosts, for analytics roles and PII indicators.
* **CI checks:** the test matrix covers 16 apps, and unit tests check the decoder and comparison scripts.

### What is next

* **Independent verification welcome:** the harness and method are open for others to confirm the findings.
* **Wave 1 coverage:** the next test set targets five high-download Google Play parenting apps. The final report records each app's data-safety statement before testing.
* **Open-source plan:** publishing the harness and method is on the roadmap.
* **Code review (PR #22):** a review hardened the harness. HAR timestamps are now UTC, SDK hosts count as trackers, and archived static dark-pattern false positives (0dp layouts, benign "timer" strings) are recorded as historical context only.

If you have suggestions for coverage or issues with the method, I welcome them.
## Artifacts

Network capture logs:
- `results/baby-buddy-test-20260803/` - Baby Buddy mitmproxy capture
- `results/nurture-lock-test-20260803/capture.mitm` - Nurture Lock capture
- `results/nubo-test-20260803/capture.mitm` - Nubo capture

Sanitized network logs:
- `results/network-log-<app>.json` - per-flow host, redacted path, status, count, sizes, JSON body keys, header-flag names, and redaction slugs for each tested app; built from the raw `.mitm` captures by `scripts/build-network-logs.sh`
- `results/analytics-pii-20260803.json` - full fanout scan across every committed network log
- Raw decoded captures stay local because they contain authentication tokens and installation IDs.

## Sources

### Tools

- [mitmproxy](https://mitmproxy.org) - captures and decrypts HTTPS traffic between each app and its servers. I chose it over Charles or Fiddler because it is open source, scriptable from the CLI (`mitmdump`), and installs its CA certificate into the emulator's system store.
- [jadx](https://github.com/skylot/jadx) - decompiles each APK back to readable Java. I chose it over apktool because it reconstructs source, which makes tracking libraries easier to spot than reading smali assembly.
- [objection](https://github.com/sensepost/objection) - instruments the running app on the emulator for runtime checks. I chose it over raw Frida scripts because it runs on top of Frida with ready-made commands, which is simpler for this audit.
- [apkeep](https://github.com/EFForg/apkeep) - downloads APKs from [APKPure](https://apkpure.com) and [APKMirror](https://www.apkmirror.com). I used a mirror source because Google Play does not offer APK downloads outside the store client. I chose apkeep over a browser download because it is scriptable and supports split-APK (`.xapk`) handling.
- [Android SDK platform tools](https://developer.android.com/tools/releases/platform-tools) (adb) - installs APKs, drives the emulator, and pulls package data. This is the standard Google tool for device control; the harness calls it directly.
- Android emulator with a Google-APIs ARM64 system image - the test device. I used an emulator rather than a physical phone because installing a custom CA certificate requires `adb root` and a writable system partition, which only works on a dedicated test device.
- [Exodus Privacy](https://exodus-privacy.eu.org) - cross-checks tracked permissions and known tracking libraries in each APK. The [standalone Docker image](https://hub.docker.com/r/exodusprivacy/exodus-standalone) runs the tracker scan locally so APK contents never leave the machine. I used it as a second opinion alongside the jadx source read.
- [APKPure](https://apkpure.com) - APK source. See apkeep above. [APKMirror](https://www.apkmirror.com) and [APKCombo](https://apkcombo.com) are the mirrors I fall back to when an APK is not on APKPure.

### Referenced projects

- [Baby Buddy](https://github.com/babybuddy/babybuddy) - the FOSS control app (Django, self-hosted). [Documentation](https://docs.baby-buddy.net), [license (BSD-2-Clause)](https://github.com/babybuddy/babybuddy/blob/master/LICENSE). The Android companion used for first-launch pictures is [babybuddy-for-android](https://github.com/babybuddy/babybuddy-for-android) (MIT).

---

## License

This project is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for the full license text.
