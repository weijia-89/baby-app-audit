# How We Tested Baby Tracking Apps

**Purpose:** This document explains how we tested four baby tracking apps for privacy leaks.

---

## Why We Tested These Apps

Parents use baby tracking apps to record feeding, sleep, and diaper changes. These apps hold sensitive data about babies. Some apps claim that data never leaves the phone. We wanted to know if that claim is true.

If an app says "100% offline" but sends data to a server, the claim is false. One outbound packet is enough to prove it false.

---

## What We Tested

We tested four baby tracking apps.

| App | Type | Why We Tested It |
| --- | --- | --- |
| Nurture Lock | Native Android | Claims "100% offline" |
| Nubo | Native Android | Claims local-first |
| Pebbi | Native Android | Known to share data |
| Baby Buddy | FOSS / Web | Open-source option |

Nurture Lock was the primary target. It says data never leaves the phone.

Pebbi was included as a positive control. We will use it to validate that our test can detect outbound traffic. If Pebbi shows zero traffic, our test method may be broken.

Baby Buddy is different because its source code is public.

---

## Where We Tested

We ran all tests on a Mac with Apple Silicon. We used the Android emulator to run the apps.

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

### Step 6: For Baby Buddy — source code audit and dynamic test

Because Baby Buddy is open source, we cloned the repository from https://github.com/babybuddy/babybuddy. We searched the code for network calls, analytics libraries, and third-party SDKs.

We ran Baby Buddy locally with `python manage.py runserver`. We captured traffic with mitmproxy. We logged in and navigated the app.

**Source audit results:**
- 67 network references found. These are all in Django documentation comments or configuration examples. No active tracking code.
- 0 tracker libraries found. We searched for Google Analytics, Mixpanel, Segment, Sentry, Firebase, Matomo, Plausible, and others. None present.
- No data exfiltration endpoints in application code.

**Dynamic test results:**
- All traffic stayed on localhost. No outbound requests.
- No calls to external APIs, CDNs, or analytics services.
- Static files served locally.

**Verdict:** Baby Buddy does not send data off-device in its default configuration. See README.md for full findings.

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

Before testing the target app, we will run Pebbi through the full test. Pebbi is included as a positive control. If our test shows zero traffic for Pebbi, we will investigate whether our test method is working correctly.

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

## Reproducibility

You can run this test yourself. Everything is open-source:

- **Test harness:** `APK_PRIVACY_TEST_HARNESS.md`
- **Results:** `results/`
- **Code:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

We welcome independent verification. If you run the test and get different results, please open an issue.

---

## Sources

* Baby Buddy repository: https://github.com/babybuddy/babybuddy
* Baby Buddy documentation: https://docs.baby-buddy.net
* Baby Buddy license (BSD-2-Clause): https://github.com/babybuddy/babybuddy/blob/master/LICENSE
* mitmproxy: https://mitmproxy.org
* Exodus Privacy: https://exodus-privacy.eu.org
