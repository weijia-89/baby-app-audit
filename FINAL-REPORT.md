# Baby App Privacy Audit - Results

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-12
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

## What we found

We tested 16 baby and parenting apps. Most say they protect their privacy. We checked whether their words match what the app actually does with your data.

Nine apps make a privacy promise. Seven of them sent data off the device. Only Baby Buddy and MimiLog did what they said.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open source | PASS | 💖 | 100% | No tracking libraries; all traffic stays on localhost in default configuration |
| MimiLog | "Fully offline" | PASS | 💖 | 100% | One Firebase configuration call; no valid project, so no data exchanged |
| Amila | No claim | No claim | ❕ | 90% | Firebase Installations, Remote Config, and Google Fonts calls on launch |
| Baby+ | "AdID not auto-enabled" | FAIL | ❕ | 90% | Philips server, Firebase, and Google calls on launch |
| Heartful Baby | "HIPAA-compliant" | FAIL | ❕ | 90% | One Firebase logging batch on launch |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 🚫 | 90% | Firebase and RevenueCat calls on launch; Facebook SDK found in code |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | Nine Facebook Graph API calls and one Crashlytics batch on launch |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | Sends session analytics, screen views, and onboarding events to Firebase on first launch |
| Nurture Lock | "100% offline" | FAIL | 🚫 | 95% | Calls `api.revenuecat.com` on launch; 8 tracking libraries in the APK |
| Pebbi | No claim (control) | No claim | 🚫 | 100% | Extensive data collection via Firebase, Google AdServices, and FCM registration |
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | Three Facebook Graph API calls and one Firebase Installations registration |
| BabyCenter | No claim | No claim | 🚫 | 95% | AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |
| BellyBloom | No claim | No claim | 🚫 | 90% | Adjust, DoubleClick, Facebook, and Firebase calls on launch |
| Nanit | No claim | No claim | ❕ | 90% | Firebase Installations and Remote Config plus the Nanit API on launch; no ad SDK traffic |
| Pregnancy+ | No claim | No claim | ❕ | 90% | Firebase Installations and Remote Config on launch; no ad SDK traffic |
| What to Expect | No claim | No claim | 🚫 | 90% | AppsFlyer, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |

Result key:

- **💖** means the app passed and behaved as described.
- **❕** means the app failed, but the capture showed phone-home traffic without identifying user data.
- **🚫** means the app failed and the capture showed identifying data or extensive tracking.

An app with no privacy claim cannot fail, because there is no promise to break. Its result says "no claim"; the privacy mark still shows what we observed.

No test ended inconclusive.

**Network captures:** each app block below links to its own sanitized network log (`results/network-log-<app>.json`). These logs list the hosts, paths, and response status codes of captured traffic. They contain no query strings, headers, or bodies, because those carried authentication tokens. The raw captures (`results/decode-traffic-<app>.json`) stay local only.

## Proprietary apps we tested

### Nurture Lock
- **Claim:** "100% offline"
- **Result:** FAIL (95% confidence)
- **What we found:** The app calls `api.revenuecat.com` on launch. It carries 8 tracking libraries: RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, and Tenjin. The "offline" claim is false.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nurture-lock.json)
- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Nubo
- **Claim:** "Local-first"
- **Result:** FAIL (95% confidence)
- **What we found:** The app sends data to Firebase and Google on launch. "Local-first" overstates what it does.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nubo.json)
- **Network log:** [network-log-nubo.json](results/network-log-nubo.json)

### Pebbi
- **Claim:** No privacy claim (positive control)
- **Result:** No claim (100% confidence)
- **What we found:** The app makes no privacy promise, so it cannot fail. It sends data to Firebase, Google, and a third-party analytics host. We expected this because it makes no privacy promise.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pebbi.json)
- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

### Amila
- **Claim:** No claim
- **Result:** No claim (90% confidence)
- **What we found:** The app makes no privacy promise, so it cannot fail. The launch capture shows calls to Firebase and Google Fonts. Static analysis found tracking libraries in the code.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-amila.json)
- **Network log:** [network-log-amila.json](results/network-log-amila.json)

### Baby Daybook
- **Claim:** "AdID not auto-enabled"
- **Result:** FAIL (90% confidence)
- **What we found:** The launch capture shows calls to RevenueCat, Firebase, and Google. Static analysis found the Facebook SDK in the code. The "AdID not auto-enabled" claim does not cover this traffic.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-baby-daybook.json)
- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### Baby+
- **Claim:** "AdID not auto-enabled"
- **Result:** FAIL (90% confidence)
- **What we found:** The launch capture shows calls to Philips servers, Firebase, and Google. Static analysis found the Facebook SDK in the code. The "AdID not auto-enabled" claim does not cover this traffic.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-baby-plus.json)
- **Network log:** [network-log-baby-plus.json](results/network-log-baby-plus.json)

### MimiLog
- **Claim:** "Fully offline"
- **Result:** PASS (100% confidence)
- **What we found:** The app made one call to a Google Firebase configuration endpoint, then sent no further data. The device held no valid Firebase project, so it exchanged no data. The claim holds.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-mimilog.json)
- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nara
- **Claim:** "Complete privacy"
- **Result:** FAIL (90% confidence)
- **What we found:** The app calls Facebook and Crashlytics on launch. We captured 10 flows: 9 to the Facebook Graph API and 1 Crashlytics report batch. The "complete privacy" claim is false.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nara.json)
- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Heartful Baby
- **Claim:** "HIPAA-compliant"
- **Result:** FAIL (90% confidence)
- **What we found:** The app calls Google Firebase logging on launch. We captured a POST to the Firebase logging batch endpoint. The "HIPAA-compliant" claim is false.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-heartful-baby.json)
- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Pixy
- **Claim:** "Bank-level encryption"
- **Result:** FAIL (90% confidence)
- **What we found:** The app calls Facebook and Firebase on launch. We captured 4 flows: 3 to the Facebook Graph API and 1 Firebase Installations registration. The encryption claim does not cover this.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pixy.json)
- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

### Baby Buddy
- **Claim:** Open source
- **Result:** PASS (100% confidence)
- **What we found:** The app sent no traffic off the device. All activity stayed on localhost between the app and its own server.
- **Note:** Open source code, self-hosted. The app sent nothing off the device, so its network log is empty.
- **Network log:** [network-log-baby-buddy.json](results/network-log-baby-buddy.json)

## Popular Google Play apps - Wave 1 burst tests

These five apps are the first wave of popular Google Play targets. They make no privacy promise, so their result says "No claim"; the privacy mark still shows what we observed in the launch capture.

The Play Store pages make no no-data-sharing or offline promise. We acquired these APKs from a mirror and ran burst tests on an API 29 emulator. None of the five kept traffic on the device. BellyBloom 1.0.9 requires Android 12L (API 32), so the tested build is 1.0.8, which shares the same package signature.

| App | Package | Play Store signal | Data-safety statement |
| --- | --- | --- | --- |
| [BabyCenter](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) | `com.babycenter.pregnancytracker` | 4.9 stars, 1.54M reviews, 10M+ downloads, #3 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Nanit](https://play.google.com/store/apps/details?id=com.nanit.baby) | `com.nanit.baby` | 3.9 stars, 10.6K reviews, 500K+ downloads, #5 top grossing parenting | Shares Personal info, App activity, and App info and performance. No privacy promise found. |
| [What to Expect](https://play.google.com/store/apps/details?id=com.wte.view) | `com.wte.view` | 4.9 stars, 121K reviews, 5M+ downloads, #7 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Pregnancy+](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) | `com.hp.pregnancy.lite` | 4.8 stars, 3.64M reviews, 50M+ downloads, #10 top free parenting | Shares Location and Device or other IDs. No privacy promise found. |
| [BellyBloom](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) | `com.bellyBloom.pregnancy.tracker` | 4.6 stars, 988 reviews, 1M+ downloads | Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted. |

### BabyCenter
- **Claim:** No claim
- **Result:** No claim (95% confidence)
- **What we found:** The app calls AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, and Firebase on launch. We captured 21 flows, 18 to tracking destinations. The manifest declares ACCESS_ADSERVICES_AD_ID plus an install-referrer receiver. The dark-pattern scan found 4 patterns.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-babycenter.json)
- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom
- **Claim:** No claim
- **Result:** No claim (90% confidence)
- **What we found:** The app calls Adjust, DoubleClick, Facebook, and Firebase on launch. We captured 8 flows, all to tracking destinations. We used version 1.0.8 because 1.0.9 requires Android 12L (API 32). The dark-pattern scan found 2 patterns.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-bellybloom.json)
- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit
- **Claim:** No claim
- **Result:** No claim (90% confidence)
- **What we found:** The app calls Google Firebase Installations and Remote Config plus the Nanit API on launch. We captured 5 flows, 3 to tracking destinations. No advertising SDK traffic appeared in the launch window. Full features need the camera and an account; the capture covers onboarding only. The dark-pattern scan found 2 patterns.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nanit.json)
- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+
- **Claim:** No claim
- **Result:** No claim (90% confidence)
- **What we found:** The app calls Google Firebase Installations and Remote Config on launch. We captured 3 flows, all to tracking destinations. No advertising SDK traffic appeared in the launch window. Automation accepted the consent screens; the capture disabled sensitivity. The dark-pattern scan found 2 patterns.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pregnancyplus.json)
- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect
- **Claim:** No claim
- **Result:** No claim (90% confidence)
- **What we found:** The app calls AppsFlyer (six endpoints), Microsoft Clarity, Scorecard Research, and Firebase on launch. We captured 14 flows, 13 to tracking destinations. The manifest declares ACCESS_ADSERVICES_AD_ID and AD_SERVICES_CONFIG. The dark-pattern scan found 3 patterns.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-whattoexpect.json)
- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

## Dark pattern scan

We scanned each app for consent screens that push you to share data. The scanner gave mostly weak signals. We do not trust these as final verdicts without a hands-on screen test. The most common false signal was the word "timer", which is also the Danish word for "hours".

## Cross-app view

Every app that failed shares one piece of code: Firebase. Nara and Pixy also embed Facebook. The words "complete privacy" and "HIPAA-compliant" sit next to code that sends data to third parties.

## Limits

- We did not tap the apps by hand. Some data paths stayed hidden.
- The dark pattern scan is a best-guess tool. A real screen test is still needed.
- The captures cover the launch and early-use window of each app. Behavior later in a session could differ.

## Advice

**For parents:** Do not trust "offline" or "local-first" claims. Baby Buddy is the only app we tested that sent nothing off the device.

**For developers:** If you say "offline", remove the analytics and attribution code. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable claims. Someone should test them.

## Artifacts

Machine-readable results: [results/RESULTS-20260803.json](results/RESULTS-20260803.json)

Per-app dark-pattern scans (committed, sanitized): see the links in each app block above. Per-app sanitized network logs (committed): see the network-log links in each app block above. Raw network captures (`results/decode-traffic-<app>.json`) are generated locally and kept out of the repository because they contain captured authentication tokens.
