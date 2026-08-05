# How I Tested Baby Tracking Apps

**Purpose:** This document explains how I tested four baby tracking apps for privacy leaks.

---

## Why I Tested These Apps

Parents use baby tracking apps to record feeding, sleep, and diaper changes. These apps hold sensitive data about babies. Some apps claim that data never leaves the phone. I wanted to know if that claim is true.

If an app says "100% offline" but sends data to a server, the claim is false. One outbound packet is enough to prove it false.

---

## What I Tested

I tested four baby tracking apps.

| App | Type | Why I Tested It |
| --- | --- | --- |
| Nurture Lock | Native Android | Claims "100% offline" |
| Nubo | Native Android | Claims local-first |
| Pebbi | Native Android | Known to share data |
| Baby Buddy | FOSS / Web | Open-source option |

Nurture Lock was the primary target. It says data never leaves the phone.

Pebbi was included as a positive control. I use it to check that the test detects outbound traffic. If Pebbi shows zero traffic, the test method is faulty.

Baby Buddy is different because its source code is public.

---

## Where I Tested

I ran all tests on a Mac with Apple Silicon. I used the Android emulator to run the apps.

The test environment included these tools:

* **mitmproxy** - captures network traffic between the phone and the internet.
* **adb** - connects to the Android emulator.
* **jadx** - decompiles APK files to read the source code.
* **objection** - available to bypass certificate pinning if needed. Not required in this run because the system certificate was installed directly.

exodus-standalone is documented in the harness but was not run on this platform (the Docker image is linux/amd64 only).

---

## How I Tested

### Step 1: Set up the test environment

I installed all tools on the Mac. I started the Android emulator. I configured the emulator to route all network traffic through mitmproxy. This lets me see every request the app makes.

### Step 2: Install the app and pull the APK

I installed the app on the emulator. I pulled the APK file from the emulator. I computed a SHA-256 hash of the file. This proves the file has not changed.

### Step 3: Run the offline test

I started mitmproxy. I opened the app. I created a baby profile and logged events. I watched the mitmproxy web view for any outbound requests.

If the app sends any data, the "offline" claim is false.

### Step 4: Run the static scan

I decompiled the APK with jadx. I searched the code for URLs and tracking libraries. exodus-standalone was attempted but cannot run on this architecture. The static evidence in this run comes from jadx and string-signature analysis.

### Step 5: Run the dynamic capture

I repeated the same actions from Step 3. I captured all network traffic. For each request, I recorded:

* The destination address.
* The data in the request body.
* Whether the destination is a known tracker.

If the app uses certificate pinning, I use objection to bypass it.

### Step 6: For Baby Buddy - source code audit and dynamic test

Because Baby Buddy is open source, I cloned the repository from https://github.com/babybuddy/babybuddy. I searched the code for network calls, analytics libraries, and third-party SDKs.

I ran Baby Buddy locally with `python manage.py runserver`. I captured traffic with mitmproxy. I logged in and navigated the app.

**Source audit results:**
- 67 network references found. These are all in Django documentation comments or configuration examples. No active tracking code.
- 0 tracker libraries found. I searched for Google Analytics, Mixpanel, Segment, Sentry, Firebase, Matomo, Plausible, and others. None present.
- No data exfiltration endpoints in application code.

**Dynamic test results:**
- All traffic stayed on localhost. No outbound requests.
- No calls to external APIs, CDNs, or analytics services.
- Static files served locally.

**Verdict:** Baby Buddy does not send data off-device in its default configuration. See README.md for full findings.

### Step 7: Check for covert channels

I documented checks for data leaving the phone through non-standard paths:

* Bluetooth Low Energy (BLE) beacons.
* NFC transmissions.
* Ultrasonic audio signals.
* DNS tunneling.

Radio checks (BLE, NFC, ultrasound) require physical hardware and were not performed in the 2026-08-03 run. DNS tunneling analysis was limited by the captured traffic. These remain open items.

---

## What I Measured

I answered five questions for each app:

1. Did any data leave the phone?
2. How many trackers did the static scan find?
3. What permissions did the app request?
4. What outside addresses did the app contact?
5. Does the app match its own privacy claim?

---

## How I Ensured the Test Was Reliable

### Canary test

Before testing the target app, I run Pebbi through the full test. Pebbi is included as a positive control. If the test shows zero traffic for Pebbi, I investigate whether the test method is working correctly.

### Smoke tests

I checked that every tool works before starting the test. If a required tool is missing, the harness reports the gap and continues in best-effort mode, recording which tools were missing. The run is marked PARTIAL_FAILURE if any app test cannot complete.

### Artifact archiving

I saved all test artifacts in a structured directory. I archived them with timestamps and SHA-256 hashes. This creates an evidence chain for future reference.

### Audit logging

I maintained a test log for each run. Captures are stored locally and are never committed to the repository without scrubbing.

---

## What I Did With Sensitive Data

The test harness does not use real baby data. All traffic captured on the emulator is synthetic - generated by the apps themselves with test profiles. I followed these rules:

* **Data minimization:** I captured only app traffic, not all emulator traffic.
* **Purpose limitation:** I used the data only for privacy testing.
* **Retention:** Local capture artifacts are kept for a maximum of 90 days and then deleted.
* **Redaction:** Captures that contain tokens or identifiers (Firebase installation IDs, JWTs, anonymous IDs) are kept only under `results/mitm-capture/`, which is excluded from the repository by `.gitignore`. Public documents redact such values.
* **No consent requirement:** Because no real user data was used, no parent consent was needed or obtained. No claims of consent are made.

---

## Reproducibility

You can run this test yourself. Everything is open-source:

- **Test harness:** `APK_PRIVACY_TEST_HARNESS.md`
- **Results:** `results/`
- **Code:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

I welcome independent verification. If you run the test and get different results, please open an issue.

---

## Dark Pattern Detection

I added static dark pattern detection to the test harness in Sprint 3. This is a separate evidence stream from data transmission findings.

### What I detect

The script `scripts/detect-dark-patterns.sh` scans decompiled APK resources for these patterns:

1. **Pre-checked consent** - Checkboxes or toggles that default to "checked" on consent-related screens.
2. **Hidden consent flows** - WebViews or dialogs that load privacy terms but are hidden from view.
3. **Deceptive button order** - Affirmative action buttons ("Accept All", "Continue") that appear without a clear decline option.
4. **Obfuscated disclaimers** - Text that is too small or low contrast to read easily.
5. **Pressure tactics** - Urgency language ("limited time", "act now") in user-facing strings.

### How I detect them

I search XML layout files and string resources for tell-tale signs:

* `android:checked="true"` near consent-related text.
* `android:visibility="gone"` on WebViews that load privacy URLs.
* Very small layout dimensions (`layout_width="1dp"`) that hide content.
* Button labels like "Accept All" without matching "Decline" or "Reject" strings.
* Text sizes below 8sp on disclaimer text.
* Light text colors (RGB all > 200) that create low contrast.

### Limits

* Static analysis only. I do not run the app to see the actual UI.
* Patterns are heuristic. A finding does not prove intent.
* False positives are possible. A checked checkbox might be for a functional setting, not data consent.
* I do not detect runtime dark patterns (e.g., dialogs that block the back button).

### Separation from transmission findings

Dark pattern findings are kept in a separate JSON file (`results/dark-patterns.schema.json`). They do not affect the pass/fail verdict on data transmission. An app can have dark patterns but still pass the privacy test if it sends no data.

---

## Sources

* Baby Buddy repository: https://github.com/babybuddy/babybuddy
* Baby Buddy documentation: https://docs.baby-buddy.net
* Baby Buddy license (BSD-2-Clause): https://github.com/babybuddy/babybuddy/blob/master/LICENSE
* mitmproxy: https://mitmproxy.org
* Exodus Privacy: https://exodus-privacy.eu.org
