# Baby App Audit

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

An audit of a number of infant milestone apps to see how much data companies collect on use. 

---

## What This Is

Parents use baby tracking apps to record feeding, sleep, and diaper changes. The last thing most parents want is to have all of that data recorded in a DB somewhere for later resale down-the-line. 

Some of these apps claim that data never leaves the phone but that hasn't been backed by independent audits. And given the history of [certain applications](https://doi.org/10.3390/jcp3030016) with [broken privacy promises](https://www.bitdefender.com/en-us/blog/labs/notes-on-throughtek-kalay-vulnerabilities-and-their-impact), it felt important to complete an actual audit.

## What Was Tested
| App | Type | Claim |
| --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" |
| Nubo | Native Android | "Local-first" |
| Pebbi | Native Android | No claim (positive control) |
| Baby Buddy | FOSS / Web | Open-source |

These were just the apps that my partner and I had done some research on and which the internet recommended as 'private.' 

Baby Buddy, as a FOSS option, was added as control since the codebase is fully auditable. But it was subjected to the same review and network activity scrutiny as the rest.

## How Did I Test

* With an LLM paired with a test harness that runs an Android emulator. 
* Network traffic captured and logged by mitmproxy. 
* Code decompiled with jadx.

For web apps like Baby Buddy, the app was also run locally and browser traffic was captured.

**Tested tool versions (2026-08-03):** mitmproxy 12.2.3, jadx 1.5.6, objection 1.12.5, adb 37.0.1, apkeep 1.0.0.

## Test Steps (If You Want to Do It Yourself)

1. Install the app on the emulator (or run locally for web apps).
2. Pull the APK file from the device (for native apps).
3. Compute a SHA-256 hash of the APK.
4. Run the app and use it normally.
5. Watch mitmproxy for outbound requests.
6. Run a static scan for trackers and permissions.
7. Capture dynamic traffic.
8. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling). 

Note - Radio checks (BLE, NFC, ultrasound) require physical hardware and were not performed. It's also an incredibly impractical way of siphoning data. Future iterations may add this in especially if there are accessories that use these protocols to sync with the app but the current focus is on the apps alone.

## Quick Start

Install the tools:

```bash
brew install --cask android-platform-tools
brew install mitmproxy jadx
brew install --cask docker
pipx install objection
```

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

Read the full harness for manual steps:

```bash
open APK_PRIVACY_TEST_HARNESS.md
```

---

## Results

Full results with evidence: [results/RESULTS-20260803.md](results/RESULTS-20260803.md) and machine-readable [results/RESULTS-20260803.json](results/RESULTS-20260803.json). See [CHANGELOG.md](CHANGELOG.md) for history and [ARTICLE.md](ARTICLE.md) for the publication draft.

| App | Claim | Verdict | Key findings |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | FAIL (95%) | Phones home to RevenueCat with device identifiers on launch. 8 tracking libraries found in the APK |
| Nubo | "Local-first" | FAIL (95%) | Sends session analytics, screen views, and onboarding events to Google Firebase on first launch |
| Pebbi | No claim (positive control) | FAIL (100%) | Extensive data collection via Firebase, Google AdServices, and FCM registration |
| Baby Buddy | Open-source | PASS (100%) | No tracking libraries. All traffic stays on localhost in default configuration |

### Notes

**Nurture Lock** - the "100% offline" claim is false. The APK contains 8 tracking libraries: RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, and Tenjin. On launch the app calls `api.revenuecat.com` with the bundle ID, version, platform, and locale. One outbound connection is enough to break the claim. Details: [Nurture Lock section](results/RESULTS-20260803.md#nurture-lock).

**Nubo** - the "local-first" claim is false. First launch registers with Firebase Installations and Crashlytics, then sends Firebase Analytics batches with session IDs, screen views, timing data, and onboarding progress. Details: [Nubo section](results/RESULTS-20260803.md#nubo).

**Pebbi** - tested as a positive control with no privacy claim. It sends extensive data: Firebase Crashlytics, Analytics, Sessions, Installations, and Remote Config, plus Google AdServices and Play Install Referrer. The `app.pebbi.co/app/version-policy` endpoint phones home every ~30 seconds. Details: [Pebbi section](results/RESULTS-20260803.md#pebbi).

**Baby Buddy** - the FOSS control passed. Source audit found 67 network references, all in Django docs or configuration examples, and 0 tracking libraries. Dynamic test captured all traffic on localhost only. Details: [Baby Buddy section](results/RESULTS-20260803.md#baby-buddy).

**Method and limits:** the full procedure is in [APK_PRIVACY_TEST_HARNESS.md](APK_PRIVACY_TEST_HARNESS.md). Method, consent, and known limitations (no radio checks, no static scan for Nubo) are in [METHODOLOGY.md](METHODOLOGY.md). Version history in [CHANGELOG.md](CHANGELOG.md).

## Discussion and Roadmap

Future iterations of this audit will include more apps, more FOSS alternatives, and more specificity on the data being siphoned (e.g. data related to user analytics vs actual data on infant developmental milestones).

If folks have any suggestions of what they want to see next in terms of coverage, please let me know. And any issues with the methodology will be warmly accepted and considered.

## Artifacts

Network capture logs:
- `results/baby-buddy-test-20260803/` - Baby Buddy mitmproxy capture
- `results/nurture-lock-test-20260803/capture.mitm` - Nurture Lock capture
- `results/nubo-test-20260803/capture.mitm` - Nubo capture

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
