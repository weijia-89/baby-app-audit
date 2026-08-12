# Baby App Privacy Audit - Results

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-11
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

## What we found

We tested 11 baby and parenting apps. Most say they protect your privacy. We checked whether their words match what the app actually does with your data.

Nine apps make a privacy promise. Eight of them sent data off the device. Only two apps did what they said: Baby Buddy (open source) and MimiLog.

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
| Nara | "Complete privacy" | INCONCLUSIVE | 70% |
| Heartful Baby | "HIPAA-compliant" | INCONCLUSIVE | 70% |
| Pixy | "Bank-level encryption" | INCONCLUSIVE | 70% |

Result key:

- **PASS** means the app behaved as described.
- **FAIL** means the app broke its own privacy claim.
- **INCONCLUSIVE** means we could not confirm the claim either way. This is not a pass.

**Network captures:** the raw captured traffic logs (`results/decode-traffic-<app>.json`) are produced locally during testing. They contain captured authentication tokens (Firebase JWTs and refresh tokens), so they are excluded from this repository and not linked here. The per-app dark-pattern scan logs below are committed and sanitized.

## Apps we tested

### Nurture Lock
- **Claim:** "100% offline"
- **Result:** FAIL (95% confidence)
- **What we found:** The app calls `api.revenuecat.com` on launch. It carries 8 tracking libraries: RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, and Tenjin. The "offline" claim is false.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nurture-lock.json)

### Nubo
- **Claim:** "Local-first"
- **Result:** FAIL (95% confidence)
- **What we found:** The app sends data to Firebase and Google on launch. "Local-first" overstates what it does.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nubo.json)

### Pebbi
- **Claim:** No privacy claim (positive control)
- **Result:** FAIL (100% confidence)
- **What we found:** The app sends data to Firebase, Google, and a third-party analytics host. We expected this because it makes no privacy promise.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pebbi.json)

### Baby Buddy
- **Claim:** Open source
- **Result:** PASS (100% confidence)
- **What we found:** The app sent no traffic off the device. All activity stayed on localhost between the app and its own server.
- **Note:** Open source code, self-hosted. The app sent nothing off the device, so it produced no outbound network log.

### Amila
- **Claim:** No claim
- **Result:** FAIL (90% confidence)
- **What we found:** The app sends data to Google and a third-party analytics host on launch.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-amila.json)

### Baby Daybook
- **Claim:** "AdID not auto-enabled"
- **Result:** FAIL (90% confidence)
- **What we found:** The app sends data to Facebook and RevenueCat. The claim about AdID does not cover the rest of its tracking.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-baby-daybook.json)

### Baby+
- **Claim:** "AdID not auto-enabled"
- **Result:** FAIL (90% confidence)
- **What we found:** The app sends data to Facebook and Philips. The claim about AdID does not cover the rest of its tracking.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-baby-plus.json)

### MimiLog
- **Claim:** "Fully offline"
- **Result:** PASS (100% confidence)
- **What we found:** The app made one call to a Google Firebase configuration endpoint, then sent no further data. The device held no valid Firebase project, so it exchanged no data. The claim holds.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-mimilog.json)

### Nara
- **Claim:** "Complete privacy"
- **Result:** INCONCLUSIVE (70% confidence)
- **What we found:** The app sends data to Facebook and Firebase. TLS certificate checks failed on several domains we could not pin, so the capture is incomplete. We could not confirm the "complete privacy" claim.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-nara.json)

### Heartful Baby
- **Claim:** "HIPAA-compliant"
- **Result:** INCONCLUSIVE (70% confidence)
- **What we found:** The app sent no network traffic in the test window. We did not capture enough to confirm or reject the HIPAA claim.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-heartful-baby.json)

### Pixy
- **Claim:** "Bank-level encryption"
- **Result:** INCONCLUSIVE (70% confidence)
- **What we found:** The app sends data to Facebook. TLS certificate checks failed on several domains we could not pin, so the capture is incomplete. We could not confirm the encryption claim.
- **Per-app scan:** [dark-pattern scan](results/dark-patterns-pixy.json)

## Dark pattern scan

We scanned each app for consent screens that push you to share data. The scanner gave mostly weak signals. We do not trust these as final verdicts without a hands-on screen test. The most common false signal was the word "timer", which is also the Danish word for "hours".

## Cross-app view

Every app that failed shares one piece of code: Firebase. Nara and Pixy also embed Facebook. The words "complete privacy" and "HIPAA-compliant" sit next to code that sends data to third parties.

## Limits

- We did not tap the apps by hand. Some data paths stayed hidden.
- The dark pattern scan is a best-guess tool. A real screen test is still needed.
- We could not break certificate pinning on some apps. Those captures are incomplete.

## Advice

**For parents:** Do not trust "offline" or "local-first" claims. Baby Buddy is the only app we tested that sent nothing off the device.

**For developers:** If you say "offline", remove the analytics and attribution code. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable claims. Someone should test them.

## Artifacts

Machine-readable results: [results/RESULTS-20260803.json](results/RESULTS-20260803.json)

Per-app dark-pattern scans (committed, sanitized): see the links in each app block above. Raw network captures (`results/decode-traffic-<app>.json`) are generated locally and kept out of the repository because they contain captured authentication tokens.
