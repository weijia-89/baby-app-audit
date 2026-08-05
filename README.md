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

These were apps my partner and I researched. The internet recommended them as "private."

Baby Buddy is a FOSS option. I added it as a control since the codebase is fully auditable. But I subjected it to the same review and network scrutiny as the rest.

I also found 16+ additional candidates. They are in `localonly/candidates.md` and split into Tier 1 (test next), Tier 2 (test later), Tier 3 (low priority), wearable/IoT, and out-of-scope.

## How I Test

* An LLM paired with a test harness that runs an Android emulator.
* mitmproxy captures and logs network traffic.
* jadx decompiles code.

For web apps like Baby Buddy, I run the app locally and capture browser traffic.

**Tool versions (2026-08-03):** mitmproxy 12.2.3, jadx 1.5.6, objection 1.12.5, adb 37.0.1, apkeep 1.0.0.

## Test Steps (If You Want to Do It Yourself)

1. Install the app on the emulator (or run locally for web apps).
2. Pull the APK file from the device (for native apps).
3. Compute a SHA-256 hash of the APK.
4. Run the app and use it normally.
5. Watch mitmproxy for outbound requests.
6. Run a static scan for trackers and permissions.
7. Capture dynamic traffic.
8. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling).

Note - Radio checks need physical hardware. I did not perform them. They are also an impractical way to siphon data. Future work may add them if accessories use these protocols to sync with the app. The current focus is on the apps alone.

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

Full results with evidence: [results/RESULTS-20260803.md](results/RESULTS-20260803.md) and machine-readable [results/RESULTS-20260803.json](results/RESULTS-20260803.json). See [CHANGELOG.md](CHANGELOG.md) for history.

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

**Method and limits:** the full procedure is in [APK_PRIVACY_TEST_HARNESS.md](APK_PRIVACY_TEST_HARNESS.md). Method, consent, and known limits (no radio checks, no static scan for Nubo) are in [METHODOLOGY.md](METHODOLOGY.md). Version history in [CHANGELOG.md](CHANGELOG.md).

## Discussion and Roadmap

This project is on a multi-sprint roadmap. Sprint 1 is complete.

### What Sprint 1 added

* **Live data collection:** `scripts/decode-traffic.sh` v2 decodes HAR captures into structured JSON with per-product metadata.
* **Per-product tracking:** Part 8.5 tracks retention, security EOL/CVE, and device identity for each product.
* **Expanded candidates:** 16+ new apps in `localonly/candidates.md` across Tier 1-3, wearable/IoT, and out-of-scope lists.
* **Research prompts:** Four prompts in `prompts/` for finding apps, building scoring rubrics, mapping prior art, and researching device identities.
* **CI expansion:** Test matrix now covers 11 apps with ports 8080-8090.
* **Unit tests:** `tests/test-decode-traffic.sh` has 11 tests for the decoder script.
* **External config:** Product metadata now lives in `results/product-metadata.json` instead of hardcoded values.

### What Sprint 2 added

* **Schema enforcement:** CI now blocks builds if `decode-traffic.sh` output violates the schema. Set `DECODE_TRAFFIC_STRICT=1` to enable.
* **Tier 1 harness support:** BabyTrack, Amila, and Wachanga are now in the default app list with skeleton entries.
* **FOSS path validation:** Baby Buddy end-to-end test passes. Source clone, commit hash recording, and network reference audit all work.
* **Bug fix:** `run-tests.sh` no longer word-splits on app names with spaces.

### What Sprint 3 added

* **Owlet ecosystem:** Owlet Sock (MDR) and Owlet Cam (RED) added to candidates.md with verified CVE data from NVD, regime classification, and test plan.
* **Dark pattern detection:** `scripts/detect-dark-patterns.sh` scans APK resources for pre-checked consent, hidden flows, deceptive buttons, obfuscated disclaimers, and pressure tactics.
* **Cross-app comparison:** `scripts/compare-apps.sh` compares decoded traffic across apps to find shared trackers, similar endpoints, and data volume differences.
* **New schemas:** `results/dark-patterns.schema.json` and `results/comparison.schema.json` define the output format for the new tools.
* **Unit tests:** `tests/test-dark-patterns.sh` (7 tests) and `tests/test-compare-apps.sh` (7 tests) cover the new scripts.

### What is next

* **Sprint 4:** Generate the final report. Publish the methodology. Open-source the tool.

If you have suggestions for coverage or issues with the methodology, I welcome them.

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
