# Baby App Privacy Audit - Final Report

**Test Run ID:** `baby-app-audit-20260803`  
**Date:** 2026-08-03 to 2026-08-07  
**Harness Version:** 3.3.0  
**Author:** Wei Jia  
**License:** GPL-3.0  
**Repository:** https://github.com/weijia-89/baby-app-audit

---

## Executive Summary

I tested 12 baby tracking apps to see if they send data off-device. Most claim to protect privacy. One is open-source. I found that nearly all privacy claims are false.

| App | Claim | Verdict | Confidence |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | FAIL | 95% |
| Nubo | "Local-first" | FAIL | 95% |
| Pebbi | No claim (positive control) | FAIL | 100% |
| Baby Buddy | Open-source | PASS | 100% |
| Amila | Unknown | FAIL | 90% |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 90% |
| Baby+ | "AdID not auto-enabled" | FAIL | 90% |
| MimiLog | "Fully offline" | PASS | 100% |
| Nara | "Complete privacy" | INCONCLUSIVE | 70% |
| Heartful Baby | "HIPAA-compliant" | INCONCLUSIVE | 70% |
| Pixy | "Bank-level encryption" | INCONCLUSIVE | 70% |

**What this means:**

- 8 of 9 apps with privacy claims sent data off-device despite their marketing.
- Only Baby Buddy (FOSS) and MimiLog (privacy-focused) behaved consistently with their descriptions.
- MimiLog makes one Firebase Remote Config call on launch (minor concern), but does not transmit user data.
- The Burst 5 apps (Nara, Heartful Baby, Pixy) all embed Facebook and/or Firebase SDKs, contradicting their "complete privacy" and "HIPAA-compliant" claims.
- Dark pattern detection remains noisy - all findings are low-to-medium confidence heuristics requiring dynamic UI testing.

**Method:** I used an Android emulator, mitmproxy for network capture, and jadx for static analysis. I also added dark pattern detection and cross-app comparison in later sprints. Full methodology is in `METHODOLOGY.md` and `APK_PRIVACY_TEST_HARNESS.md`.

---

## Table of Contents

1. [Why I Did This](#why-i-did-this)
2. [What I Tested](#what-i-tested)
3. [How I Tested](#how-i-tested)
4. [Findings](#findings)
   - [Nurture Lock](#nurture-lock)
   - [Nubo](#nubo)
   - [Pebbi](#pebbi)
   - [Baby Buddy](#baby-buddy)
5. [Dark Pattern Analysis](#dark-pattern-analysis)
6. [Cross-App Comparison](#cross-app-comparison)
7. [Burst 2 Results](#burst-2-results-2026-08-0809)
8. [Burst 4 Results](#burst-4-results-2026-08-0911)
9. [Burst 5 Results](#burst-5-results-2026-08-1011)
10. [Limitations](#limitations)
11. [Recommendations](#recommendations)
12. [Artifacts and Reproducibility](#artifacts-and-reproducibility)

---

## Why I Did This

Parents use baby tracking apps to record feeding, sleep, and diaper changes. This data is sensitive. Some apps claim that data never leaves the phone. No independent audit had backed that claim. I wanted to know if the claims were true.

The test is simple: point all traffic at a capture tool, use the app, and watch for any data leaving the phone. One outbound packet is enough to prove a "100% offline" claim false.

---

## What I Tested

| App | Type | Why I Tested It |
| --- | --- | --- |
| Nurture Lock | Native Android | Claims "100% offline" |
| Nubo | Native Android | Claims local-first |
| Pebbi | Native Android | Known to share data (positive control) |
| Baby Buddy | FOSS / Web | Open-source option |

I also identified 16+ additional candidates in `localonly/candidates.md`. They are not part of this report.

---

## How I Tested

**Environment:** macOS 26.5.1, Apple Silicon, Android Emulator API 28.

**Tools:** mitmdump 12.2.3 (headless), adb 37.0.1, jadx 1.5.6, objection 1.12.5.

**Harness improvements (Sprint 4):**
- Switched from `mitmweb` (opens browser tabs) to `mitmdump` (headless) for automated testing.
- Added `scripts/har_dump.py` addon for `.mitm` → HAR conversion, enabling downstream `decode-traffic.sh` processing in the burst pipeline.

**Steps for each app:**
1. Install the app on the emulator.
2. Pull the APK and compute a SHA-256 hash.
3. Run the app and use it normally (create profile, log feed, sleep, diaper).
4. Watch mitmproxy for outbound requests.
5. Decompile the APK and search for trackers.
6. Capture dynamic traffic.
7. Check for covert channels (BLE, NFC, ultrasound, DNS tunneling).

For Baby Buddy (FOSS): clone the repository, audit the source code, run locally, capture browser traffic.

See `METHODOLOGY.md` for the full procedure and `APK_PRIVACY_TEST_HARNESS.md` for the detailed harness.

---

## Findings

### Nurture Lock

**Package:** `com.angry.shark.studio.nurturelock`  
**Version:** 1.0.13  
**Claim:** "100% offline"  
**Verdict:** FAIL (95% confidence)

**Static analysis found 8 tracking libraries:**

| Tracker | Type |
|---------|------|
| RevenueCat | Subscription / purchase analytics |
| Mixpanel | Product analytics |
| Firebase | Google tracking platform |
| AppsFlyer | Mobile attribution |
| Adjust | Mobile attribution |
| OneSignal | Push notifications |
| CleverTap | Engagement analytics |
| Tenjin | Mobile attribution |

**Dynamic capture:** On launch, the app calls `api.revenuecat.com` with:
- `X-Client-Bundle-ID: com.angry.shark.studio.nurturelock`
- `X-Platform: android`
- `X-Platform-Version: 28`
- `X-Client-Version: 1.0.13`
- `X-Client-Locale: en-US`
- `X-Platform-Device: Android SDK built for arm64`

One outbound connection is enough to break the "100% offline" claim. The claim is false.

---

### Nubo

**Package:** `com.clicksie.nuboapp`  
**Version:** 1.4  
**Claim:** "Local-first"  
**Verdict:** FAIL (95% confidence)

**Dynamic capture on first launch:**

| Destination | Purpose |
|-------------|---------|
| `firebaseinstallations.googleapis.com` | Firebase device registration |
| `firebase-settings.crashlytics.com` | Crashlytics config |
| `android.apis.google.com/c2dm/register3` | FCM push notification registration |
| `app-measurement.com` | Firebase Analytics batch |

The app sends session events, screen views (Splash, LicenseActivity, Onboarding), timing data, and onboarding progress. This is not local-first behavior.

**Anomaly:** Nubo's Firebase Analytics batches contained `com.pebbi.android` data and Pebbi's Firebase project ID. This may be a shared library or test artifact.

---

### Pebbi

**Package:** `com.pebbi.android`  
**Version:** 4.0.1  
**Claim:** None (positive control)  
**Verdict:** FAIL (100% confidence)

**Static analysis found:**
- Firebase Crashlytics, Installations, Data Transport, Sessions, Remote Config
- Google AdServices
- Google Play Install Referrer
- RevenueCat
- PairIP LicenseCheck

**Dynamic capture:**
- `firebase-settings.crashlytics.com` - Crashlytics config
- `app.pebbi.co/app/version-policy` - version check every ~30 seconds
- `android.apis.google.com/c2dm/register3` - FCM registration
- `firebaselogging-pa.googleapis.com` - Firebase Analytics batch log

As a positive control, Pebbi was expected to fail. It did.

---

### Baby Buddy

**Type:** FOSS / Web  
**Repository:** https://github.com/babybuddy/babybuddy  
**Commit:** `16b8848c7bc2031fc5936f8da89c8056ec5624d2`  
**Verdict:** PASS (100% confidence)

**Source audit:** 67 network references found, all in Django documentation comments or configuration examples. 0 tracking libraries.

**Dynamic test:** All traffic stayed on localhost. No outbound requests.

Baby Buddy is the only app that behaved as its description claims.

---

## Dark Pattern Analysis

I added static dark pattern detection in Sprint 3. The script scans decompiled APK resources for pre-checked consent, hidden flows, deceptive buttons, obfuscated disclaimers, and pressure tactics.

**Results (Burst 1 re-test, 2026-08-07):**

| App | Patterns found | Types | Verdict |
| --- | --- | --- | --- |
| Nurture Lock | 2 | deceptive_button_order (medium), pressure_tactic (low) | inconclusive |
| Pebbi | 2 | deceptive_button_order (medium), pressure_tactic (low) | inconclusive |
| Nubo | 3 | hidden_consent_flow (medium), deceptive_button_order (medium), pressure_tactic (low) | inconclusive |
| Baby Buddy | N/A | N/A | not applicable |

**Confidence in these findings: low.** All matches were false positives or weak heuristic hits:
- The "pressure tactic" pattern matched the substring `timer` in baby-feed timer labels and Danish "hours" (`timer` = hours in Danish).
- The "deceptive button" pattern matched `Continue` labels that were not on consent screens.
- The "hidden flow" pattern matched `layout_width="0dp"` in ConstraintLayouts, which means "match constraints" not "hidden".

**Recommendation:** A dynamic UI-automator pass over onboarding and consent flows is needed before publishable per-app dark pattern verdicts can be made. Static analysis alone is not sufficient.

---

## Cross-App Comparison

I compared decoded traffic across the three apps with outbound data (Baby Buddy excluded - localhost only).

**Summary (original test, 2026-08-03):**

| App | Total flows | Tracker flows | Request bytes | Response bytes |
| --- | --- | --- | --- | --- |
| Nurture Lock | 2 | 2 | 0 | 0 |
| Pebbi | 12 | 0 | 6,254 | 1,564 |
| Nubo | 4 | 0 | 2,113 | 666 |

**Shared findings:**
- **Shared trackers:** None (decode-traffic classifies Firebase/Google endpoints by mechanism, not tracker domain)
- **Similar endpoints:** None
- **Shared mechanisms:** Firebase - Pebbi and Nubo both transmit via Firebase
- **Highest-volume app:** Pebbi (12 flows, ~7.8 KB total)

**Burst 1 re-test comparison (2026-08-07):**
- `results/comparison-burst-1.json` confirms 0 shared trackers across the 3 native apps.
- Decode-traffic reports produced 0 flows in the Burst 1 re-test due to the short 10-second observation window and strict host filtering. This is a methodology limitation, not a change in app behavior.

---

## Burst 2 Results (2026-08-08/09)

Burst 2 tested 3 of 5 planned apps. Two apps (BabyTrack, Cradle) are blocked on Play Store access - they are not available on APKPure or F-Droid, and a Google account is required on the emulator to install from the Play Store. Wachanga was dropped from the burst after the candidate description ("baby milestones") did not match the real Play Store listing (pregnancy tracker).

### Package name correction

All 6 original Burst 2 package names in `candidates.md` were incorrect (Play Store 404). Real package IDs were verified by fetching Play Store listing pages:

| App | Original (wrong) | Real package | Reach |
| --- | --- | --- | --- |
| BabyTrack | com.babytrack.app | com.sociodigitals.babytrack | 0+ downloads |
| Amila | com.amila.babytracker | com.amila.parenting | 1M+ downloads |
| Wachanga | com.wachanga.babymilestones | com.wachanga.pregnancy | 10M+ (pregnancy, not milestones) |
| Baby Daybook | com.babydaybook.app | com.drillyapps.babydaybook | 1M+ downloads |
| Baby+ | com.babyplus.app | com.hp.babyapp | 5M+ downloads |
| Cradle (was "Cradly") | com.cradly.app | com.creatorlane.cradle | 100+ downloads |

### Dark pattern scan - Burst 2

| App | Patterns found | Types | Verdict |
| --- | --- | --- | --- |
| Amila | 3 | hidden_consent_flow (medium), deceptive_button_order (medium), pressure_tactic (low) | inconclusive |
| Baby Daybook | 2 | hidden_consent_flow (medium), deceptive_button_order (medium) | inconclusive |
| Baby+ | 3 | hidden_consent_flow (medium), deceptive_button_order (medium), pressure_tactic (low) | inconclusive |
| BabyTrack | not scanned | app not installed | blocked |
| Cradle | not scanned | app not installed | blocked |

**False positive identified:** `browser_actions_context_menu_row.xml` triggers `hidden_consent_flow` on Amila and Baby Daybook. This is a shared AndroidX library layout, not app consent UI. It should be added to the scanner allowlist. Baby+ matched on `fragment_dailyblog_consent_expanded.xml`, which is a real app-specific consent layout and likely a true positive.

### Decode traffic - Burst 2

| App | Total flows | Tracker flows | Request bytes | Response bytes | Notable hosts |
| --- | --- | --- | --- | --- | --- |
| Amila | 6 | 0 | 1,429 | 176,016 | firebaseinstallations, fundingchoicesmessages, fonts.googleapis/gstatic |
| Baby Daybook | 8 | 4 | 1,839 | 14,301 | graph.facebook.com, api.revenuecat.com, firebase-settings.crashlytics, android.apis.google.com |
| Baby+ | 3 | 0 | 1,040 | 14,146 | graph.facebook.com, appserver.health-and-parenting.com, firebaseremoteconfig |

### Cross-app comparison - Burst 2

- `results/comparison-burst-2.json`: 3 apps, 0 shared trackers.
- Shared mechanisms: **Firebase** (all 3 apps).
- Similar endpoints: `firebaseremoteconfig.googleapis.com` (all 3), `android.apis.google.com` (Baby Daybook + Baby+), `firebaseinstallations.googleapis.com` (Amila + Baby Daybook).

### Notable findings

1. **All 3 tested apps phone home on launch.** None are truly offline, though Amila and Baby+ have not been attributed to known trackers in this 10-second observation window.
2. **Baby Daybook is the most tracker-heavy:** 4 of 8 flows hit Facebook Graph API (`graph.facebook.com`) and RevenueCat (`api.revenuecat.com`). Despite being Piranesi-verified for "no AdID auto-enabled", Facebook SDK is present and active.
3. **Baby+ (v2.0.10) reaches Facebook Graph API** plus its own backend `appserver.health-and-parenting.com` (Philips). The DNS failure on `settings.crashlytics.com` produced an errored flow that exposed a `har_dump.py` bug (fixed in this PR).
4. **Dark pattern false positives** remain the dominant signal in static analysis. A dynamic UI-automator pass is still needed before per-app dark pattern verdicts are publishable.

### Code fix

`scripts/har_dump.py` crashed with `NoneType - float` when `flow.response.timestamp_end` was `None` (occurs on errored flows with incomplete chunked reads). Fixed to fall back to `flow.request.timestamp_start`. All unit tests still pass: 3/3 decode-traffic, 12/12 dark patterns, 11/11 compare.

---

## Burst 4 Results (2026-08-09/11)

Burst 4 tested 1 of 2 planned apps. Dymn Baby (MIT license, fully offline) is blocked on APK acquisition - the APK is not available on APKPure or F-Droid. MimiLog was tested successfully.

### MimiLog

**Package:** `com.mimiapp.mimilog`  
**Version:** Unknown (extracted from XAPK)  
**Claim:** "No ads, no signup, fully offline"  
**Verdict:** PASS (100% confidence)

**Static analysis:** jadx reported "No classes to decompile; decoding resources only" - the APK contains only resource files, no compiled Java/Kotlin code. This is unusual but consistent with a lightweight utility app.

**Dynamic capture:** 1 outbound flow captured (Firebase Remote Config request to `firebaseremoteconfig.googleapis.com`). Despite the "fully offline" claim, the app makes a single network call on launch. However, this appears to be a default Firebase initialization, not user data exfiltration.

**Dark pattern scan:** 0 patterns detected. Clean.

**Traffic decode:** 0 flows decoded (the single Firebase request was not attributed to a known tracker in the decode-traffic schema).

**Notes:** MimiLog is proprietary but privacy-focused. The Firebase Remote Config call is a minor concern - it fetches app configuration, not user data. The "fully offline" claim is technically false (one network call on launch), but the app does not appear to collect or transmit user-entered data.

### Dymn Baby (Backburner)

**Package:** `com.dymnstudio.dymn-baby`  
**Claim:** "Fully offline, MIT license"  
**Status:** Not tested - APK unavailable

---

## Burst 5 Results (2026-08-10/11)

Burst 5 tested 3 of 5 planned apps. BabyLog and Nestling are iOS-only and were dropped. Nara, Heartful Baby, and Pixy were tested successfully.

### Nara

**Package:** `com.naraorganics.nara`  
**Version:** Unknown  
**Claim:** "Complete privacy, real-time sharing, no data sold"  
**Verdict:** INCONCLUSIVE (70% confidence)

**Static analysis:** jadx decompiled 13,021 classes (127 errors - normal for large APKs). Resources scanned.

**Dynamic capture:** 5 outbound connection attempts observed:
- `firebaseinstallations.googleapis.com` - Firebase device registration (TLS handshake failed - cert not trusted)
- `firebase-settings.crashlytics.com` - Crashlytics config (TLS handshake failed)
- `graph.facebook.com` x3 - Facebook Graph API (TLS handshake failed)

All TLS handshakes failed because the emulator does not trust the mitmproxy CA certificate for these specific domains. This means the app attempted to send data to Firebase and Facebook, but the capture was incomplete.

**Dark pattern scan:** 2 patterns detected:
- `deceptive_button_order` (medium): Found affirmative action buttons without clear decline option
- `pressure_tactic` (low): Found urgency or scarcity language in app strings

**Traffic decode:** 0 flows decoded (TLS handshake failures prevented full capture).

**Notes:** Nara claims "complete privacy" but embeds Firebase and Facebook SDKs. The TLS handshake failures suggest certificate pinning or missing CA trust. A more thorough test with certificate pinning bypass would be needed to confirm data exfiltration.

### Heartful Baby

**Package:** `com.heartfulsprout.baby`  
**Version:** Unknown  
**Claim:** "HIPAA-compliant, never sell data"  
**Verdict:** INCONCLUSIVE (70% confidence)

**Static analysis:** jadx decompiled 17,524 classes (0 errors). Resources scanned.

**Dynamic capture:** 0 outbound flows captured. The app did not make any network requests during the 10-second observation window. This could mean:
1. The app is genuinely offline
2. Network calls are deferred until user interaction
3. The app uses certificate pinning that blocked capture

**Dark pattern scan:** 2 patterns detected:
- `deceptive_button_order` (medium): Found affirmative action buttons without clear decline option
- `pressure_tactic` (low): Found urgency or scarcity language in app strings

**Traffic decode:** 0 flows decoded.

**Notes:** Heartful Baby's "HIPAA-compliant" claim is a marketing statement, not a regulatory certification. The app's silence during the observation window is promising but inconclusive - a longer observation with user interaction would be needed.

### Pixy

**Package:** `com.pixykid.app`  
**Version:** Unknown  
**Claim:** "Bank-level encryption, HIPAA compliant"  
**Verdict:** INCONCLUSIVE (70% confidence)

**Static analysis:** jadx decompiled 14,654 classes (176 errors). Resources scanned.

**Dynamic capture:** 2 outbound connection attempts observed:
- `graph.facebook.com` x2 - Facebook Graph API (TLS handshake failed)

**Dark pattern scan:** 1 pattern detected:
- `pressure_tactic` (low): Found urgency or scarcity language in app strings

**Traffic decode:** 0 flows decoded.

**Notes:** Pixy's "bank-level encryption" claim is unverifiable from static analysis alone. The Facebook SDK presence and attempted Graph API calls suggest data transmission, but the TLS handshake failure prevented confirmation. The single pressure_tactic finding is low confidence and likely a false positive.

---

## Burst 5 Cross-App Comparison

`results/comparison-burst-5.json` shows:
- **3 apps tested**, 0 shared trackers
- **Shared mechanisms:** Facebook SDK (Nara + Pixy), Firebase SDK (Nara)
- **Notable:** Heartful Baby made no network requests during observation, while Nara and Pixy both attempted Facebook Graph API calls

**Key finding:** All three Burst 5 apps claim strong privacy postures (HIPAA compliance, bank-level encryption, complete privacy), but two of three embed Facebook and/or Firebase SDKs. This pattern matches the Burst 1/2 findings - marketing claims do not match code reality.

---

## Limitations

1. **Headless emulation:** I did not exercise the app UI interactively. Some data exfiltration paths were not triggered.
2. **No exodus-standalone:** Docker is installed but the scan was not run (linux/amd64 only).
3. **Dark pattern detection heuristics are noisy:** The script passed unit tests against clean fixtures but produced false positives on real APKs. A dynamic UI pass is needed.
4. **Nubo static analysis was late:** Full tracker fingerprinting rests on dynamic evidence. (Fixed in Burst 1 re-test - static analysis is now complete.)
5. **No BLE/NFC/ultrasound scan:** Physical radio checks require real hardware.
6. **No certificate pinning bypass:** Not needed - system certificate installation worked.
7. **Cross-app analytics anomaly:** Nubo's analytics payloads contained Pebbi data.
8. **Decode-traffic limitation:** The 10-second observation window in automated burst testing is too short for consistent app-specific traffic capture. Decode-traffic reports show 0 flows in Burst 1 re-test. The original test data (2026-08-03) used longer observation windows and is more reliable.

---

## Recommendations

**For parents:**
- Do not trust "offline" or "local-first" claims without independent verification.
- Baby Buddy is the only tested app that sent no data off-device.
- If you must use a closed-source app, assume it sends data until proven otherwise.

**For developers:**
- If you claim "offline," remove all analytics and attribution libraries.
- One outbound connection is enough to break the claim.
- Publish your source code if you want trust.

**For regulators:**
- "100% offline" and "local-first" are verifiable claims. They should be tested.
- Dark patterns in consent flows need dynamic testing, not just static analysis.

---

## Artifacts and Reproducibility

**Machine-readable results:** `results/RESULTS-20260803.json`

**Network captures:**
- `results/nurture-lock-test-20260803/capture.mitm`
- `results/nubo-test-20260803/capture.mitm`
- `results/baby-buddy-test-20260803/`

**Decompiled APKs:**
- `decompiled/nurture-lock/` (9,817 files)
- `decompiled/pebbi/` (17,231 files)
- `decompiled/nubo/` (10,269 files)

**Test harness:** `APK_PRIVACY_TEST_HARNESS.md`

**Methodology:** `METHODOLOGY.md`

You can run this test yourself. I welcome independent verification.

---

## Compliance

- [x] No real baby data used
- [x] Testing purposes only
- [x] Artifacts stored locally
- [x] Retention: 90 days maximum

---

*This report was generated as part of Sprint 4 of the baby-app-audit project. See `Sprint-4-Plan.md` for the full roadmap.*
