# We Tested 4 Baby Tracking Apps for Privacy. Here's What We Found.

**Subtitle:** A methodical, adversarial review of how baby data flows (or doesn't) from your phone to the internet.

**Author:** [Your Name]  
**Date:** [Publication Date]  
**Repository:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

---

## TL;DR

We tested four baby tracking apps to see if they send your baby's data to the internet. [One-sentence summary of the most surprising finding.]

- **Nurture Lock:** [pass / fail / untested]
- **Nubo:** [pass / fail / untested]
- **Pebbi:** [pass / fail — expected to fail]
- **Baby Buddy:** [pass / fail / untested]

[Link to full results](results/TEMPLATE.md)

---

## Why We Did This

Parents track everything. Feeding times, sleep schedules, diaper changes. They use apps to do it. Those apps hold sensitive data: names, birth dates, health patterns.

Some apps claim "100% offline." We wanted to know if that's true.

This matters because:
1. Baby data is valuable. [Add context about data brokers, targeted advertising.]
2. Parents trust these claims. [Add context about privacy expectations.]
3. The claims are testable. [Add context about technical verifiability.]

---

## The Apps

| App | Claim | Type | Why We Tested It |
| --- | --- | --- | --- |
| Nurture Lock | "100% offline" | Native Android | Primary target — the strongest claim |
| Nubo | "Local-first" | Native Android | Secondary target — weaker claim |
| Pebbi | No claim (known leaky) | Native Android | Positive control — validates our test |
| Baby Buddy | Open-source | FOSS / Web | Alternative model — code is public |

---

## How We Tested

We built a test harness and hardened it through 226 adversarial findings across 7 expert perspectives. The process:

### The Setup

We ran everything on a Mac with Apple Silicon. No cloud. We used:

- An Android emulator (API 28, arm64).
- mitmproxy to capture all network traffic.
- exodus-standalone to scan for trackers.
- jadx to decompile APKs.
- objection to bypass certificate pinning.

### The Test

For each app:

1. **Install and pull the APK.** Get the file from the device. Hash it for integrity.
2. **Offline test.** Use the app normally. Watch for any data leaving the phone.
3. **Static scan.** Analyze the APK without running it. Find trackers and permissions.
4. **Dynamic capture.** Watch real traffic. Record every destination and payload.
5. **Covert channel check.** Look for Bluetooth, NFC, ultrasound, and DNS tunneling.

For Baby Buddy, we also:
- Tested the web app in a browser.
- Audited the open-source code directly.

### The Hardening

We didn't just run the test. We adversarially reviewed the test itself:

- **4 review loops.** 226 findings total.
- **7 expert postures.** Software engineer, AI engineer, QA, security, DevOps, privacy engineer, SRE.
- **2 new postures in Loop 2.** Privacy and SRE expertise added after Loop 1.

See the [full methodology](TESTING_METHODOLOGY_SIMPLE_ENGLISH.md).

---

## The Results

### Nurture Lock

**Claim:** "100% offline"

[Insert findings here.]

**Verdict:** [pass / fail]

**Evidence:** [Link to results file.]

### Nubo

**Claim:** "Local-first"

[Insert findings here.]

**Verdict:** [pass / fail]

**Evidence:** [Link to results file.]

### Pebbi

**Claim:** None (known to share data)

[Insert findings here.]

**Verdict:** fail (expected — validates our test harness)

**Evidence:** [Link to results file.]

### Baby Buddy

**Claim:** Open-source, self-hostable

[Insert findings here.]

**Verdict:** [pass / fail]

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

Our test has limits:

1. **One device, one Android version.** We tested on API 28. Behavior may differ on other versions.
2. **One network condition.** We tested on a stable connection. Offline/airplane mode behavior may differ.
3. **One build per app.** We tested the version available at the time. Updates may change behavior.
4. **Covert channels are hard.** BLE, NFC, and ultrasound require specialized hardware to detect fully.
5. **Source audit vs. build verification.** For Baby Buddy, we audited the source but did not verify the build reproducibility.

---

## Reproducibility

You can run this test yourself. Everything is open-source:

- **Test harness:** `APK_PRIVACY_TEST_HARNESS.md`
- **Methodology:** `TESTING_METHODOLOGY_SIMPLE_ENGLISH.md`
- **Results template:** `results/TEMPLATE.md`
- **Code:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

We welcome independent verification. If you run the test and get different results, please open an issue.

---

## Acknowledgments

This test was designed with input from seven synthetic expert perspectives. The methodology was hardened through 226 adversarial findings.

---

## License

[Choose a license.]

---

*This article is part of an ongoing investigation into baby tracking app privacy. For updates, watch the [GitHub repository](https://github.com/weijia-89/baby-app-audit).*
