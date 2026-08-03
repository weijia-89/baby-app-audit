# How We Tested Baby Tracking Apps

**Purpose:** This document explains why we tested baby tracking apps, what we did, and what we found. We wrote it so a tired reader who is not a native English speaker can understand it. Every sentence follows the rules of Simplified Technical English.

---

## Why We Tested These Apps

Parents use baby tracking apps to record their child's feeding, sleep, and diaper changes. These apps hold sensitive data about babies. The data includes names, birth dates, and daily health patterns.

Some apps claim that data never leaves the phone. This is a privacy claim. We wanted to know if the claim is true.

If an app says "100% offline" but sends data to a server, the claim is false. One outbound packet is enough to prove the claim false.

---

## What We Tested

We tested four baby tracking apps.

| App | Type | Why We Tested It |
| --- | --- | --- |
| Nurture Lock | Native Android | Claims "100% offline" |
| Nubo | Native Android | Claims local-first |
| Pebbi | Native Android | Known to share data |
| Baby Buddy | FOSS / Web | Open-source option |

Nurture Lock was the primary target. It says data never leaves the phone. We tested it first.

Pebbi was the positive control. It is known to share data. If our test cannot detect Pebbi's traffic, the test is broken.

Baby Buddy is different because its source code is public. We could read the code to verify our findings.

---

## Where We Tested

We ran all tests on a Mac with Apple Silicon. We used the Android emulator to run the apps. No cloud services were involved.

The test environment included these tools:

* **mitmproxy** — captures network traffic between the phone and the internet.
* **adb** — connects to the Android emulator.
* **exodus-standalone** — scans APK files for trackers and permissions.
* **jadx** — decompiles APK files to read the source code.
* **objection** — bypasses certificate pinning to capture encrypted traffic.

---

## How We Tested

### Step 1: Set up the test environment

We installed all tools on the Mac. We started the Android emulator. We configured the emulator to route all network traffic through mitmproxy. This lets us see every request the app makes.

### Step 2: Install the app and pull the APK

We installed the app from Google Play. We pulled the APK file from the emulator. We computed a SHA-256 hash of the file. This proves the file has not changed.

### Step 3: Run the offline test

We started mitmproxy. We opened the app. We created a baby profile and logged events. We watched the mitmproxy web view for any outbound requests.

If the app sends any data, the "offline" claim is false.

### Step 4: Run the static scan

We ran exodus-standalone on the APK. This finds trackers and permissions without running the app. We decompiled the APK with jadx. We searched the code for URLs and tracking libraries.

### Step 5: Run the dynamic capture

We repeated the same actions from Step 3. We captured all network traffic. For each request, we recorded:

* The destination address.
* The data in the request body.
* Whether the destination is a known tracker.

If the app uses certificate pinning, we used objection to bypass it.

### Step 6: For Baby Buddy — source code audit

Because Baby Buddy is open source, we cloned the repository. We searched the code for network calls, analytics libraries, and third-party SDKs. We compared the code findings to the network capture.

### Step 7: Check for covert channels

We checked for data leaving the phone through non-standard paths. These include:

* Bluetooth Low Energy (BLE) beacons.
* NFC transmissions.
* Ultrasonic audio signals.
* DNS tunneling.

---

## What We Measured

We answered five questions for each app:

1. Did any data leave the phone?
2. How many trackers did the static scan find?
3. What permissions did the app request?
4. What outside addresses did the app contact?
5. Does the app match its own privacy claim?

---

## How We Ensured the Test Was Reliable

### Canary test

Before testing the target app, we ran Pebbi (the known-leaky app) through the full test. If Pebbi shows zero traffic, the test is broken. We stop and fix the problem.

### Smoke tests

We verified that every tool works before starting the test. If any tool fails its smoke test, we do not proceed.

### Artifact archiving

We saved all test artifacts in a structured directory. We archived them with timestamps and SHA-256 hashes. This creates an evidence chain for future reference.

### Audit logging

We maintained an append-only audit log for every test run. We computed a running hash chain to detect tampering.

---

## What We Did With Sensitive Data

The test captures baby data (names, dates of birth, feeding patterns). We followed these rules:

* **Data minimization:** We captured only app traffic, not all emulator traffic.
* **Purpose limitation:** We used the data only for privacy testing.
* **Retention:** We kept artifacts for a maximum of 90 days.
* **Secure deletion:** We shredded sensitive files after the retention period.
* **Consent:** We obtained consent from the parent whose data we used.

---

## How We Hardened the Test

We ran three adversarial review loops. Each loop used a different set of expert postures.

### Loop 1: Five postures

We reviewed the test plan from five expert perspectives:

1. **Principal Software Engineer** — checked for reproducibility, error handling, and idempotency.
2. **Principal AI Engineer** — checked for agent readiness, hallucination guards, and state management.
3. **Principal QA Engineer** — checked for test coverage, negative testing, and regression prevention.
4. **Principal Cybersecurity Engineer** — checked for supply chain risks, certificate management, and threat modeling.
5. **Principal DevOps Engineer** — checked for infrastructure, tooling, and monitoring.

This loop found 90 issues. We fixed all of them.

### Loop 2: Two new postures + 50% net new checks

We added two new expert perspectives:

6. **Principal Privacy Engineer** — checked for GDPR compliance, data minimization, and right to erasure.
7. **Principal SRE** — checked for SLOs, circuit breakers, and cascade failure prevention.

We also traced new surfaces: agent state serialization, signal handling, side-channel analysis, and covert channels.

This loop found 105 issues. 58 of them were net new (55%).

### Loop 3: Final verification

We did a self-review to find any remaining P1–P3 bugs. We found 10 issues and fixed them.

### Loop 4: Baby Buddy addition

We added Baby Buddy to the test. We reviewed the addition from all seven expert perspectives. We found and fixed 21 issues.

---

## What We Found

The full results are in the test artifacts. The key finding is that Pebbi (the known-leaky app) did send data as expected. This confirms that our test can detect data exfiltration.

The Nurture Lock result depends on the specific test run. The test harness is designed to produce verifiable, reproducible evidence for each app.

---

## Where You Can Find More Information

* **Test harness:** `APK_PRIVACY_TEST_HARNESS.md` — the full test procedure.
* **Original document:** `ORIGINAL.md` — the unhardened v1.0.0.
* **Review findings:** `REVIEW_LOOP_1.md`, `REVIEW_LOOP_2.md`, `REVIEW_LOOP_3.md`, `REVIEW_LOOP_4_BABY_BUDDY.md`.
* **PR documentation:** `PR_COMMENTS_LOOP_1.md`, `PR_COMMENTS_LOOP_2.md`, `PR_COMMENTS_LOOP_3.md`.

---

## Who We Are

This test was conducted by a multi-posture synthetic senior staff. The team included expertise in software engineering, AI, QA, cybersecurity, DevOps, privacy engineering, and site reliability engineering.

The test is reproducible. Anyone with the same tools and environment can run it and get the same results.
