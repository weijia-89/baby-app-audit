# Baby App Privacy Audit - Results

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-12
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

## What we found

We tested 11 baby and parenting apps. Most say they protect your privacy. We checked whether their words match what the app actually does with your data.

Nine apps make a privacy promise. Seven of them sent data off the device. Only Baby Buddy and MimiLog did what they said.

| App | Privacy claim | Result | Confidence |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | FAIL | 95% |
| Nubo | "Local-first" | FAIL | 95% |
| Pebbi | No claim (control) | FAIL | 100% |
| Baby Buddy | Open source | PASS | 100% |
| Amila | No claim | FAIL | 90% |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 90% |
| Baby+ | "AdID not auto-enabled" | FAIL | 90% |
| MimiLog | "Fully offline" | PASS | 100% |
| Nara | "Complete privacy" | FAIL | 90% |
| Heartful Baby | "HIPAA-compliant" | FAIL | 90% |
| Pixy | "Bank-level encryption" | FAIL | 90% |

Result key:

- **PASS** means the app behaved as described.
- **FAIL** means the app broke its own privacy claim.

No test ended inconclusive.

**Network captures:** each app block below links to its own sanitized network log (`results/network-log-<app>.json`). These logs list the hosts, paths, and response status codes of captured traffic. They contain no query strings, headers, or bodies, because those carried authentication tokens. The raw captures (`results/decode-traffic-<app>.json`) stay local only.

## Apps we tested

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
- **Result:** FAIL (100% confidence)
- **What we found:** The app sends data to Firebase, Google, and a third-party analytics host. We expected this because it makes no privacy promise.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pebbi.json)
- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

### Baby Buddy
- **Claim:** Open source
- **Result:** PASS (100% confidence)
- **What we found:** The app sent no traffic off the device. All activity stayed on localhost between the app and its own server.
- **Note:** Open source code, self-hosted. The app sent nothing off the device, so its network log is empty.
- **Network log:** [network-log-baby-buddy.json](results/network-log-baby-buddy.json)

### Amila
- **Claim:** No claim
- **Result:** FAIL (90% confidence)
- **What we found:** The launch capture shows calls to Firebase and Google Fonts. Static analysis found tracking libraries in the code.
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
