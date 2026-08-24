# How I Tested Baby Tracking Apps

**Purpose:** This document explains how I tested baby tracking apps for privacy leaks.

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

I started mitmproxy. I opened the app. I created a fictional baby profile and logged fictional events. I watched the mitmproxy web view for any outbound requests.

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
* **Retention:** Raw captures, decode files, and network logs are permanent evidence. They stay on disk indefinitely under `results/` (gitignored because they contain live tokens) and are never swept or deleted. The harness deletes only its own work directory under `${HOME}/apk-privacy-test-*`, which it created; `KEEP_WORK_DIR=1` preserves even that. `scripts/evidence-inventory.sh --check` enforces the inventory on every harness run.
* **Redaction:** Captures that contain tokens or identifiers (Firebase installation IDs, JWTs, anonymous IDs) are kept only under `results/mitm-capture/`, which is excluded from the repository by `.gitignore`. Public documents redact such values. Committed network logs are generated from the raw `.mitm` captures by `scripts/build-network-logs.sh`. The builder replaces removed values with slugs such as `[REDACTED:request-body-values:secret-or-PII]`. It keeps the method, host, path, status, count, sizes, body-key names, and header names, so the sent call remains visible. A scrubbed body is not evidence that PII was absent.
* **No consent requirement:** Because no real user data was used, no parent consent was needed or obtained. No claims of consent are made.

---

## Reproducibility

You can run this test yourself. Everything is open-source:

- **Test harness:** `APK_PRIVACY_TEST_HARNESS.md`
- **Results:** `results/`
- **Code:** [github.com/weijia-89/baby-app-audit](https://github.com/weijia-89/baby-app-audit)

I welcome independent verification. If you run the test and get different results, please open an issue.

---

## Synthetic baby-data transmission test

Static dark-pattern searching is no longer part of the project. This operator test has one purpose: determine whether fictional baby data leaves the device. It closes the launch-capture gap described in the Final Report Limits section.

The fictional profile is one identity: "Privatia Rigatoni", born 2026-03-14 at 6 lbs 8 oz, with sentinel feeding, sleep, and diaper values. The full profile and marker strings live in `results/synthetic-baby-profile.json`. Keep those markers the same across apps. If an app asks for a field that is not in `baby`, check `field_aliases` first (same value, other name or date format). Only then add a net-new field. Do not invent a second baby.

### Procedure

1. Start the emulator and route its traffic through mitmproxy (same setup as Step 1 of How I Tested).
2. Install the app under test and pull its APK for the hash record (Step 2).
3. The automated injector (`scripts/inject-synthetic-profile.py`, wired into `run-tests.sh --live`) enters the values into the app's own data-entry screens while the capture proxy is live: baby name, birth date and weight, one feeding of 482 mL with the formula note, one sleep session of 777 minutes, one diaper weight of 1234 g, and the free-text note `PRIVATIA-RIGATONI-SYNTH` in any note field. If the app uses timers instead of amount fields, start the activity and stop it so the session is finished. No manual entry is required.
4. When a field only offers a short list (chips, pickers, units), pick from those options. Prefer the profile sentinel when it is tappable. If the preferred value will not stick, use a value that does stick. Write down the exact number or unit that was saved. Scan for that value as well as the usual profile markers. A fixed target (for example Nubo formula-per-click 90) is not required for a finished inject.
5. Where an app forces account creation, create a fictional account with the same profile values. Note in the report that the transmission may be to the app's own server.
6. Save the raw capture as `results/<app>-test-<date>/artifacts/captures/<app>.mitm`. Keep it local. It holds live tokens and must never be committed.
7. Build the sanitized network log with `scripts/build-network-logs.sh` and commit only that.
8. Run the transmission scan against the raw local capture:

   `bash scripts/scan-synthetic-baby-data.sh results/<app>-test-<date>/artifacts/captures/<app>.mitm`

   The script reads the markers from `results/synthetic-baby-profile.json`, greps the raw capture for each one, and reports which fictional values appear in a request body, a response body, or a request URL, with the recipient host, path, method, and status. It emits no adjacent body content, so its report is safe to commit. If you entered a non-sentinel amount or unit because the UI forced it, also search the raw capture for that exact string and record the result.
9. Record the verdict per app in the Final Report: `transmission_observed` (a marker left the device) or `no_transmission_detected` (the capture shows the entered values did not leave). Name the exact amounts and units that were entered, and say whether those strings left the device.

### Environment blockers (not privacy verdicts)

Some apps never reach a profile form on this API 29 Google APIs emulator:

- Pairip `LicenseActivity` with only **CLOSE** (stub Play Store `com.android.vending` 1.8): Pebbi cold start, Nurture Lock, BellyBloom on this AVD.
- Pairip native crash (`VMRunner` UnsatisfiedLinkError): Baby Daybook on this AVD.

These are environment blockers. They are not privacy PASS. They are not privacy FAIL. Do not treat a CLOSE-only dump or a crash before inject as a completed profile or as proof that data stayed on the device. The Final Report launch marks for those apps come from earlier captures, not from the CLOSE or crash screen.

The committed, sanitized network logs are NOT searched by this test. Their bodies are replaced by redaction slugs, so the fictional values would be invisible there. Only the raw local capture can prove exfiltration.

### What proves Firebase is silent

A 0-byte capture through the Android system HTTP proxy does not prove Firebase (or Google Mobile Services) stayed quiet. Many apps ignore that proxy. Flutter apps often do. Google Play services can send traffic on a different path.

To claim Firebase sent nothing in a test window, you need all of these:

1. A control that the Firebase hosts are reachable from the same device at the same time. If `firebaseinstallations.googleapis.com` and `app-measurement.com` cannot be reached, an empty capture can mean "no network", not "no SDK call".
2. A capture the app cannot skip. Record packets on the emulator interface (`tcpdump` on `eth0`) or use a VPN that takes all TCP and UDP. Do not rely on the system HTTP proxy alone.
3. A host list check on that packet file: no TLS ClientHello or DNS lookup for Firebase and Crashlytics hosts during the window. Repeat the check for the app UID in `dumpsys netstats`.
4. The window must cover a finished profile and at least one finished activity (start then stop or save). An empty launch-only window is too short.
5. Two independent records that agree (packet file plus logcat Firebase lines, or packet file plus a second VPN capture).

If the APK has no Firebase SDK (no `FirebaseInitProvider`, no `google-services.json`, no Firebase classes), that is stronger than an empty proxy file. Still run the packet check, because Play services on the device can send on the app's behalf.

Do not use real baby data. Do not infer consent pressure or user intent from this test.

## Analytics and PII fanout scan

Run `scripts/scan-analytics-pii.sh` against every committed `results/network-log-*.json` file. The scan includes known vendors and unclassified hosts. It records analytics, attribution, advertising, diagnostics, messaging, and replay-related calls.

For every call, the scan records whether the call was sent. It also records PII categories and whether the body or header values were scrubbed. A call with scrubbed content is not a no-PII result.

---

## Sources

* Baby Buddy repository: https://github.com/babybuddy/babybuddy
* Baby Buddy documentation: https://docs.baby-buddy.net
* Baby Buddy license (BSD-2-Clause): https://github.com/babybuddy/babybuddy/blob/master/LICENSE
* mitmproxy: https://mitmproxy.org
* Exodus Privacy: https://exodus-privacy.eu.org
