# I Tested 4 Baby Tracking Apps for Privacy. Here's What I Found.

**Subtitle:** A methodical, adversarial review of how baby data flows (or doesn't) from your phone to the internet.

**Author:** Wei Jia  
**Date:** 2026-08-03  
**Repository:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

---

## TL;DR

I tested four baby tracking apps to see if they send your baby's data to the internet. Three of the four failed.

- **Nurture Lock:** FAIL - claims "100% offline", phones home to RevenueCat on every launch
- **Nubo:** FAIL - claims "local-first", sends Firebase Analytics session data on first launch
- **Pebbi:** FAIL - positive control, as expected
- **Baby Buddy:** PASS - open-source, no trackers, all traffic stays local

[Link to full results](results/RESULTS-20260803.md)

---

## Why I Did This

Parents track everything. Feeding times, sleep schedules, diaper changes. They use apps to do it. Those apps hold sensitive data: names, birth dates, health patterns.

Some apps claim "100% offline." I wanted to know if that is true.

This matters because:
1. Baby data is valuable. [Add context about data brokers, targeted advertising.]
2. Parents trust these claims. [Add context about privacy expectations.]
3. The claims are testable. [Add context about technical verifiability.]

---

## The Apps

| App | Claim | Type | Why I Tested It |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | Native Android | Primary target - the strongest claim |
| Nubo | "Local-first" | Native Android | Secondary target - weaker claim |
| Pebbi | No claim (known leaky) | Native Android | Positive control - validates my test |
| Baby Buddy | Open-source | FOSS / Web | Alternative model - code is public |

---

## How I Tested

I built a test harness and hardened it through 226 adversarial findings across 4 review loops. The process:

### The Setup

I ran everything on a Mac with Apple Silicon. No cloud. I used:

- An Android emulator (API 28, arm64) with a writable system image.
- mitmproxy to capture all network traffic.
- jadx to decompile APKs.
- apkeep to download APKs from a mirror.

exodus-standalone and objection are documented in the harness but were not needed in the final run: the system certificate was installed directly, and the exodus Docker image does not run on this architecture.

### The Test

For each app:

1. **Install and pull the APK.** Get the file from the device. Hash it for integrity.
2. **Offline test.** Use the app normally. Watch for any data leaving the phone.
3. **Static scan.** Analyze the APK without running it. Find trackers and permissions.
4. **Dynamic capture.** Watch real traffic. Record every destination and payload.
5. **Covert channel check.** Look for Bluetooth, NFC, ultrasound, and DNS tunneling. Radio checks require hardware and remain open items.

For Baby Buddy, I also:
- Ran the app locally on localhost.
- Audited the open-source code directly.

### The Hardening

I didn't just run the test. I adversarially reviewed the test itself:

- **4 review loops.** 226 findings total.
- **7 expert postures.** Software engineer, AI engineer, QA, security, DevOps, privacy engineer, SRE.
- **2 new postures in Loop 2.** Privacy and SRE expertise added after Loop 1.

See the [full methodology](METHODOLOGY.md).

---

## The Results

### Nurture Lock

**Claim:** "100% offline"

[Insert findings here.]

**Verdict:** FAIL

**Evidence:** [Link to results file.]

### Nubo

**Claim:** "Local-first"

[Insert findings here.]

**Verdict:** FAIL

**Evidence:** [Link to results file.]

### Pebbi

**Claim:** None (known to share data)

[Insert findings here.]

**Verdict:** FAIL (expected - validates my test harness)

**Evidence:** [Link to results file.]

### Baby Buddy

**Claim:** Open-source, self-hostable

[Insert findings here.]

**Verdict:** PASS

**Evidence:** [Link to results file.]

---

## What This Means

### For Parents

[Insert practical advice.]

### For Developers

[Insert implications for app developers.]

### For Regulators

[Insert implications for GDPR, COPPA, etc.]

---

## Limitations

My test has limits:

1. **One device, one Android version.** I tested on API 28. Behavior can differ on other versions.
2. **One network condition.** I tested on a stable connection. Offline/airplane mode behavior can differ.
3. **One build per app.** I tested the version available at the time. Updates can change behavior.
4. **Covert channels are hard.** BLE, NFC, and ultrasound require specialized hardware to detect fully.
5. **Source audit vs. build verification.** For Baby Buddy, I audited the source but did not verify the build reproducibility.

---

## Reproducibility

You can run this test yourself. Everything is open-source:

- **Test harness:** `APK_PRIVACY_TEST_HARNESS.md`
- **Methodology:** `METHODOLOGY.md`
- **Results:** `results/`
- **Code:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

I welcome independent verification. If you run the test and get different results, please open an issue.

---

## Acknowledgments

This test was designed with input from seven synthetic expert perspectives. The methodology was hardened through 226 adversarial findings.

---

## License

GPL-3.0. See [LICENSE](LICENSE).

---

*This article is part of an ongoing investigation into baby tracking app privacy. For updates, watch the [GitHub repository](https://github.com/weijia-89/baby-app-audit).*
