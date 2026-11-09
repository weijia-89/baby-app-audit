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

The full picture is in [FINAL-REPORT.md](FINAL-REPORT.md). Each app has its own section with evidence: what the app claims, what the capture showed, and which axis was stored.

The Axis column is the claim. The gate column is the stored flag status. A session row is not an app finding.

- **pass** means the tested sentence was met.
- **fail** means a UID, a decoded body field that names the package, or an R4 line contradicts the sentence.
- **untested** means the capture did not meet the gate for that sentence.
- **not-assessable** means the sentence is not something this capture can decide.
- **inconclusive** means the window holds traffic the records cannot attribute to the app.
- **G1-G10 not stored** means the verdict file does not store the negative-gate flags.

Every failed app links to its own sanitized network log (`results/network-log-<app>.json`). The logs list hosts, redacted paths, status codes, flow counts, request and response sizes, JSON body keys, header-flag names, and redaction slugs for each captured flow. They contain no query strings, header values, or body values. The slugs state what was removed and why. The method, host, path, status, count, and sizes remain, so the record still proves that the call was sent. The logs are generated from the raw `.mitm` captures by `scripts/build-network-logs.sh`; the raw captures stay local only.

The machine-readable summary is [results/RESULTS-20260803.json](results/RESULTS-20260803.json). Each app row carries an `evidence_source`: `raw-replay` (the preserved capture was replayed) or `session-summary` (the row is not a replayed capture). Baby Buddy and MimiLog are still `session-summary`. Nubo and Baby+ joined Amila at `raw-replay` on 2026-08-25. Baby Daybook, Nurture Lock, and Pebbi followed on 2026-10-04. See [ROADMAP.md](ROADMAP.md) and [CHANGELOG.md](CHANGELOG.md).

| App | Privacy claim | Axis | Gate | Key findings |
| --- | --- | --- | --- | --- |
| Baby Buddy | Open source | untested | G1-G10 not stored | Android app untested. The tested session was the localhost Django site. |
| MimiLog | "Fully offline" | untested | G1-G10 not stored | Offline claim untested. The package declares no INTERNET. One measurement call in the window has no package header. |
| Amila | No claim | inconclusive | G1-G10 not stored | Firebase calls are in the 2026-08-25 window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Baby+ | "AdID not auto-enabled" | untested | G1-G10 not stored | Advertising-id setting untested. Facebook and Google ad calls are in the finished-profile window. |
| Heartful Baby | "HIPAA-compliant" | not-assessable | G1-G10 not stored | HIPAA status is not assessable. One logging batch is in the launch window. RTDB hosts only; flags not stored. |
| Baby Daybook | "AdID not auto-enabled" | untested | G1-G10 not stored | Advertising-id setting untested. Firebase calls carry the package header only. RTDB hosts only; flags not stored. RevenueCat and Sentry in that window are session. |
| Nara | "Complete privacy" | inconclusive | G1-G10 not stored | Insufficient attribution. Facebook and Crashlytics calls in the launch window are session. |
| Nubo | "Local-first" | inconclusive | G1-G10 not stored | A Firebase Installations POST is in the window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Nurture Lock | "100% offline" | untested | G1-G10 not stored | Offline claim untested. RevenueCat in the 2026-10-04 log is session. Unattributed Clarity traffic in window; source unresolved. |
| Pebbi | No claim (control) | untested | G1-G10 not stored | The 2026-10-04 mitm-only window is untested. 2026-10-10 records: pebbi-4.4.1-full.mitm and pebbi-tcpdump-coldstart.pcap. tcpdump saw DNS and TLS to app.pebbi.co; contents not read. |
| Pixy | "Bank-level encryption" | untested | G1-G10 not stored | Encryption sub-claims untested. Facebook calls in the launch window are session. |
| BabyCenter | No claim | inconclusive | G1-G10 not stored | Insufficient attribution. The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). |
| BellyBloom | No claim | inconclusive | G1-G10 not stored | Ad and attribution calls are in the window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Nanit | No claim | inconclusive | G1-G10 not stored | Unattributed Clarity traffic in window; source unresolved. Coralogix and Cordial calls are in the window. |
| Pregnancy+ | No claim | inconclusive | G1-G10 not stored | Unattributed Clarity traffic in window; source unresolved. |
| What to Expect | No claim | inconclusive | G1-G10 not stored | The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). One Clarity asset-upload call observed; 2,753 bytes, a 71 by 71 PNG. |

The full procedure is in [APK_PRIVACY_TEST_HARNESS.md](APK_PRIVACY_TEST_HARNESS.md). Method, consent, and known limits (no radio checks, no static scan for Nubo) are in [METHODOLOGY.md](METHODOLOGY.md).

Pairip **CLOSE** (stub Play Store) and Pairip native crashes on this emulator are environment blockers. They are not a privacy axis. Since 2026-09-20 a real Play Store on the test emulator makes all four license checks pass. See METHODOLOGY.md "Environment blockers".

## Discussion and Roadmap

This project tests baby and parenting apps against their privacy claims. The current work covers 16 apps. The full results are in [FINAL-REPORT.md](FINAL-REPORT.md).

### What the project can do

* **Live data collection:** `scripts/decode-traffic.sh` decodes network captures into structured JSON with per-app metadata.
* **Cross-app comparison:** `scripts/compare-apps.sh` compares network traffic across apps to find shared trackers.
* **Test results:** `FINAL-REPORT.md` has the verdict table plus a short per-app block. Host, path, status, and sizes stay in `results/network-log-<app>.json`.
* **Full analytics and PII fanout:** `scripts/scan-analytics-pii.sh` scans every committed network log, including unclassified hosts, for analytics roles and PII indicators. `results/analytics-pii-20260803.json` field `calls_scanned` is 507 request shapes. That count is not 507 transmissions.
* **CI checks:** the test matrix covers 16 apps, and unit tests check the decoder and comparison scripts.

### What is next

* Baby Buddy is still `session-summary`. The tested session was the localhost Django site. The Android app is untested. MimiLog is still `session-summary`. The license window is closed on an account-review hold, and the package declares no `INTERNET`. See `ROADMAP.md`.
* Pebbi's committed capture is the 2026-10-04 mitm file. That window is untested. On 2026-10-10 the profile saved. Cite `pebbi-4.4.1-full.mitm` and `pebbi-tcpdump-coldstart.pcap`. tcpdump saw `app.pebbi.co`. The TLS was not read.
* I welcome checks of the method and the findings.
* This git repo is already public.

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
