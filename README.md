# Baby App Audit

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

Test baby tracking apps for privacy leaks. This tool checks if data leaves your phone.

---

## What This Is

I test baby tracking apps for privacy leaks. I test four apps. I answer one question for each app: does data leave the phone?

Parents use baby tracking apps to record feeding, sleep, and diaper changes. These apps hold sensitive data about babies. Some apps claim that data never leaves the phone. I wanted to know if that claim is true.

If an app says "100% offline" but sends data to a server, the claim is false. One outbound packet is enough to prove it false.

## What I Test

| App | Type | Claim |
| --- | --- | --- |
| Nurture Lock | Native Android | "100% offline" |
| Nubo | Native Android | "Local-first" |
| Pebbi | Native Android | No claim (positive control) |
| Baby Buddy | FOSS / Web | Open-source |

## How It Works

The test harness runs on macOS with Apple Silicon. It uses an Android emulator to run native apps. It captures all network traffic with mitmproxy. It decompiles code with jadx. exodus-standalone is documented in the harness but was not run on this platform (Docker image is linux/amd64 only). Objection was not needed because the system certificate was installed directly.

For web apps like Baby Buddy, I run the app locally and capture browser traffic.

**Tested tool versions (2026-08-03):** mitmproxy 12.2.3, jadx 1.5.6, objection 1.12.5, adb 37.0.1, apkeep 1.0.0.

## Test Steps

1. Install the app on the emulator (or run locally for web apps).
2. Pull the APK file from the device (for native apps).
3. Compute a SHA-256 hash of the APK.
4. Run the app and use it normally.
5. Watch mitmproxy for outbound requests.
6. Run a static scan for trackers and permissions.
7. Capture dynamic traffic.
8. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling). Radio checks (BLE, NFC, ultrasound) require physical hardware and were not performed in the 2026-08-03 run.

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

## Requirements

- macOS with Apple Silicon (tested). CI checks run on Linux and macOS runners.
- 4 CPU cores
- 8 GB RAM
- 20 GB free disk space

---

## Results

Full results with evidence: [results/RESULTS-20260803.md](results/RESULTS-20260803.md) and machine-readable [results/RESULTS-20260803.json](results/RESULTS-20260803.json). See [CHANGELOG.md](CHANGELOG.md) for history and [ARTICLE.md](ARTICLE.md) for the publication draft.

### Baby Buddy

I audited Baby Buddy (https://github.com/babybuddy/babybuddy) on 2026-08-03. I tested commit `16b8848c7bc2031fc5936f8da89c8056ec5624d2`.

#### Source Code Audit

I cloned the repository and searched for:
- Network calls (HTTP/HTTPS, fetch, WebSocket, etc.)
- Analytics or tracking libraries
- Third-party data sharing

**Results:**
- 67 network references found. These are all in Django documentation comments or configuration examples. No active tracking code.
- 0 tracker libraries found. I searched for Google Analytics, Mixpanel, Segment, Sentry, Firebase, Matomo, Plausible, and others. None present.
- No data exfiltration endpoints in application code.

#### Dynamic Network Test

I ran Baby Buddy locally on `http://localhost:8000`. I set up mitmproxy to capture traffic. I logged in and navigated the app.

**Results:**
- All traffic stayed on localhost. No outbound requests.
- No calls to external APIs, CDNs, or analytics services.
- Static files served locally.

**Note:** I verified network isolation by checking that all HTTP requests went to `127.0.0.1:8000` or `localhost:8000`. The mitmproxy capture confirms no external destinations.

#### Verdict

**PASS.** Baby Buddy does not send data off-device in its default configuration. The source code contains no tracking libraries. The app is self-hostable and does not require external services.

**Caveat:** I tested the default configuration. A user can configure external services, such as AWS S3, with environment variables. Those configurations are optional and documented.

### Nurture Lock

I tested Nurture Lock (package `com.angry.shark.studio.nurturelock`, version 1.0.13) on 2026-08-03.

**Claim:** "100% offline"  
**Verdict:** **FAIL** - the claim is false

#### Static Analysis

I decompiled the APK with jadx (9,817 Java files) and found 8 tracking libraries:
- RevenueCat (subscription analytics)
- Mixpanel (product analytics)
- Firebase (Google tracking)
- AppsFlyer (mobile attribution)
- Adjust (mobile attribution)
- OneSignal (push notifications)
- CleverTap (engagement analytics)
- Tenjin (mobile attribution)

The app requests `INTERNET` and `ACCESS_NETWORK_STATE` permissions.

#### Dynamic Analysis

I installed the app on an Android emulator (API 28, arm64) and captured traffic with mitmproxy. The system certificate was installed to intercept HTTPS.

**On launch, Nurture Lock calls `api.revenuecat.com`:**
- `GET /v1/subscribers/$RCAnonymousID:.../offerings` - subscription offerings
- `GET /v1/subscribers/$RCAnonymousID:...` - subscriber profile

Headers sent with each request:
- `X-Client-Bundle-ID: com.angry.shark.studio.nurturelock`
- `X-Client-Version: 1.0.13`
- `X-Platform: android`
- `X-Client-Locale: en-US`
- `X-Platform-Device: Android SDK built for arm64`

No further outbound traffic was captured during the test window.

**Conclusion:** An app that claims "100% offline" must not phone home to RevenueCat with device identifiers on every launch. The claim is false. One outbound connection is all it takes.

### Pebbi

I tested Pebbi (package `com.pebbi.android`, version 4.0.1) on 2026-08-03 as a positive control.

**Verdict:** **FAIL** - Pebbi sends extensive data, as expected.

#### Static Analysis

I decompiled the APK with jadx (17,231 Java files) and found:
- Firebase (Crashlytics, Analytics, Sessions, Installations, Remote Config)
- Google AdServices (Advertising ID access)
- Google Play Install Referrer (install attribution)
- RevenueCat (subscription analytics)
- PairIP LicenseCheck (third-party license verification)

#### Dynamic Analysis

Outbound connections captured:
- `firebase-settings.crashlytics.com` - crashlytics configuration
- `app.pebbi.co/app/version-policy` - version check every ~30s
- `android.apis.google.com/c2dm/register3` - FCM push registration
- `firebaselogging-pa.googleapis.com/v1/firelog/legacy/batchlog` - session analytics, device fingerprint

Firebase analytics sends: session IDs, Firebase installation ID, JWT auth, device model, OS version, timezone, network type, and app version.

### Nubo

I tested Nubo (package `com.clicksie.nuboapp`, version 1.4) on 2026-08-03.

**Claim:** "Local-first"  
**Verdict:** **FAIL** - Nubo sends extensive data on first launch

I installed the app on an Android emulator (API 28, arm64) and captured all traffic with mitmproxy.

**Outbound connections on first launch:**
- `firebaseinstallations.googleapis.com` - device registration (Firebase Installation ID + JWT)
- `firebase-settings.crashlytics.com` - crashlytics config (reports, ANRs, sessions enabled)
- `android.apis.google.com/c2dm/register3` - FCM push notification registration
- `app-measurement.com/a` - Firebase Analytics batch with session data, screen views, timing metrics
- `app-measurement.com/config` - Firebase Analytics configuration

**Endpoints sent:**
- Screen views: Splash, LicenseActivity, Onboarding
- Performance: sprite_ms (~503ms), boot_ms (~244ms)
- Route: "onboarding"
- Onboarding events: `onboarding_step_viewed` (step: welcome), `onboarding_dwell` (15s threshold)
- Session IDs and timing data

**Conclusion:** An app that claims "local-first" must not send session analytics, screen views, and onboarding progress to Google Firebase Infrastructure on first launch. This claim is false.

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
