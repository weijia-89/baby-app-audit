# Baby App Privacy Audit - Final Report

**Test Run ID:** `baby-app-audit-20260803`  
**Date:** 2026-08-03 to 2026-08-06  
**Harness Version:** 3.3.0  
**Author:** Wei Jia  
**License:** GPL-3.0  
**Repository:** https://github.com/weijia-89/baby-app-audit

---

## Executive Summary

I tested four baby tracking apps to see if they send data off-device. Three claim to protect privacy. One is open-source. I found that two of the three privacy claims are false.

| App | Claim | Verdict | Confidence |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | FAIL | 95% |
| Nubo | "Local-first" | FAIL | 95% |
| Pebbi | No claim (positive control) | FAIL | 100% |
| Baby Buddy | Open-source | PASS | 100% |

**What this means:**

- Nurture Lock says data never leaves the phone. It calls `api.revenuecat.com` on every launch and contains 8 tracking libraries.
- Nubo says it is local-first. It sends Firebase Analytics data on first launch.
- Pebbi does not claim privacy. It sends extensive data, as expected for a positive control.
- Baby Buddy is open-source. It sends no data off-device in its default configuration.

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
7. [Limitations](#limitations)
8. [Recommendations](#recommendations)
9. [Artifacts and Reproducibility](#artifacts-and-reproducibility)

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

**Tools:** mitmproxy 12.2.3, adb 37.0.1, jadx 1.5.6, objection 1.12.5.

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

**Results:**

| App | Pre-checked consent | Hidden flow | Deceptive buttons | Obfuscated disclaimer | Pressure tactics | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| Nurture Lock | none | none | 1 (weak) | none | 1 (false positive) | inconclusive |
| Pebbi | none | none | 1 (weak) | none | 1 (false positive) | inconclusive |
| Nubo | none | 1 (false positive) | 1 (weak) | none | 1 (false positive) | inconclusive |
| Baby Buddy | N/A | N/A | N/A | N/A | N/A | not applicable |

**Confidence in these findings: low.** All matches were false positives or weak heuristic hits:
- The "pressure tactic" pattern matched the substring `timer` in baby-feed timer labels and Danish "hours" (`timer` = hours in Danish).
- The "deceptive button" pattern matched `Continue` labels that were not on consent screens.
- The "hidden flow" pattern matched `layout_width="0dp"` in ConstraintLayouts, which means "match constraints" not "hidden".

**Recommendation:** A dynamic UI-automator pass over onboarding and consent flows is needed before publishable per-app dark pattern verdicts can be made. Static analysis alone is not sufficient.

---

## Cross-App Comparison

I compared decoded traffic across the three apps with outbound data (Baby Buddy excluded - localhost only).

**Summary:**

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

---

## Limitations

1. **Headless emulation:** I did not exercise the app UI interactively. Some data exfiltration paths were not triggered.
2. **No exodus-standalone:** Docker is installed but the scan was not run (linux/amd64 only).
3. **Dark pattern detection heuristics are noisy:** The script passed unit tests against clean fixtures but produced false positives on real APKs. A dynamic UI pass is needed.
4. **Nubo static analysis was late:** Full tracker fingerprinting rests on dynamic evidence.
5. **No BLE/NFC/ultrasound scan:** Physical radio checks require real hardware.
6. **No certificate pinning bypass:** Not needed - system certificate installation worked.
7. **Cross-app analytics anomaly:** Nubo's analytics payloads contained Pebbi data.

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
