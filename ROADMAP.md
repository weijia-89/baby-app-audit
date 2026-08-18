# Roadmap

## Sprint 1  -  Done

- Live data collection pipeline with schema-valid output
- Harness restructure with FOSS tags
- App expansion to 16+ candidates with skeleton entries
- Research prompts and shared output schema

## Sprint 2  -  Done

- Tier 1 app full test runs with live captures
- Automated schema enforcement in CI
- FOSS path validation for BabyBuddy

## Sprint 3  -  Done

- Wearable ecosystem deep-dive (Owlet)
- Dark pattern detection automation - archived; no longer part of the current plan
- Cross-app data comparison

## Sprint 4  -  Current  -  Testing Phase

**Goal:** Systematically test all candidate apps in bursts, applying Sprint 3 criteria to both new and previously tested apps.

### Burst 1  -  Done
- Re-audit original 4 apps (Nurture Lock, Nubo, Pebbi, Baby Buddy) with new Sprint 3 criteria
- Validate harness on known targets before expanding
- Archived static dark-pattern scans: nurture-lock (2), nubo (3), pebbi (2). No new dark-pattern search is planned.
- Decode traffic reports generated for all native apps
- Cross-app comparison: comparison-burst-1.json

### Burst 2  -  Partial (3 of 5 apps tested, 2 backburner)
- Tier 1 apps: BabyTrack (backburner), Amila (done), Wachanga (dropped: wrong category)
- Privacy-first batch 1: Baby Daybook (done), Baby+ (done), Cradle (backburner)
- Archived static dark-pattern scans: amila (3), baby-daybook (2), baby-plus (3). No new dark-pattern search is planned.
- Cross-app comparison: comparison-burst-2.json (3 apps, 0 shared trackers, shared mechanism: Firebase)
- Baby+ tested with older v2.0.10 (current v3.2 ships armeabi_v7a-only, incompatible with arm64 emulator)

### Burst 3  -  Dropped (no privacy/offline claims)
- All 5 Tier 2 apps (NighP, Milli, Baby Connect, SNUGL, Talli Baby) dropped: none make privacy or offline promises

### Burst 4  -  Partial (1 of 2 apps tested, 1 backburner)
- MimiLog (done): fully offline, no ads, no signup; no outbound flows in capture; 1 Firebase Remote Config attempt never completed
- Dymn Baby (backburner): APK not on APKPure or F-Droid; pending GitHub release
- Dropped: LunaTracker (WebDAV/cloud), Sara Baby Tracker (Firebase sync)

### Burst 5  -  Planned (3 apps, Android-only)
- Nara (complete privacy, no data sold)
- Heartful Baby (HIPAA-compliant, never sell data)
- Pixy (bank-level encryption, HIPAA compliant)
- Dropped: BabyLog (iOS only), Nestling (iOS only), Nurture Lock variant (already tested in Burst 1)

### Burst 6  -  Dropped (no privacy/offline claims)
- All 5 wearable/IoT apps (Owlet Sock, Owlet Cam, Nanit, Miku, Snuza) dropped: none make privacy or offline promises

### Backburner  -  Play Store-only or unavailable apps
Apps that make privacy/offline claims but cannot be acquired via APKPure or F-Droid. Require Google account on emulator or manual APK download to test.
- **BabyTrack** (com.sociodigitals.babytrack): claims offline, encrypted, no ads. 0+ downloads. Solo dev (Indonesia). Not indexed by AppBrain or AppStoreSpy.
- **Cradle** (com.creatorlane.cradle): claims privacy-first, encrypted at rest, no data sold. 130 total downloads (8/month). Brand-new app (Aug 2026).
- **Dymn Baby** (com.dymnstudio.dymn-baby): MIT license, fully offline. APK not on APKPure or F-Droid. Pending GitHub release download.

**General rule:** Any future app that can only be acquired from the Play Store (not on APKPure, F-Droid, or other mirrors) goes to backburner. The operator must either (a) add a Google account to the emulator, or (b) manually download the APK from a browser and place it in `apks/`. Neither option blocks the rest of the testing pipeline - only APK acquisition.

### Final Report and Publication  -  Planned
- Synthesize all burst findings into final report
- Publish methodology and open-source the tool

## Network capture sufficiency audit - 2026-08-15

**Goal:** Verify raw network capture exists for every app in the testing plan.

**Findings:**
- Apps with raw .mitm captures present: Pregnancyplus, Nanit, Heartful Baby, Bellybloom, Nara, Pixy, WhatToExpect, Babycenter.
- Apps with only decode-level evidence, no raw capture: Nurture Lock, Nubo, Pebbi, Baby Buddy, Amila, Baby Daybook, Baby+, MimiLog.
- Evidence inventory warns: decode-traffic files for nurture-lock, nubo, pebbi, baby-daybook, mimilog are rotted with empty flow list; raw captures are gone.
- Synthetic baby-data transmission test cannot be completed for apps without raw captures. The scan tool requires raw local capture.

**Action:**
- Backfill raw captures for all legacy apps listed in Sprint 5 Legacy re-capture.
- Do not rerun capture for apps with existing non-zero .mitm files and evidence_source raw-replay.

## Current next step - Synthetic baby data and analytics fanout

**Goal:** Test whether fictional baby data leaves the device and scan every captured analytics or tracking call for PII indicators.

### Analytics and PII fanout (done)

- `scripts/scan-analytics-pii.sh` scans every committed network log, keeps unclassified hosts, and records every sent call with its data categories and assessment limit.
- `results/analytics-pii-20260803.json` is the machine-readable inventory for all 16 apps and 212 captured calls.
- High-risk findings (screen capture, screen-image upload, contact data, auth tokens, device identifiers) are bolded in the Final Report.

### Synthetic baby-data transmission test (in progress)

**Goal:** Prove or disprove that entered baby data leaves the device, and to which recipient.

- Fictional profile is fixed: "Privatia Rigatoni", born 2026-03-14 at 6 lbs 8 oz, with sentinel feeding (482 mL), sleep (777 min), and diaper (1234 g) values. The profile and its marker strings are in `results/synthetic-baby-profile.json`.
- `scripts/scan-synthetic-baby-data.sh` greps the raw local capture (`.mitm` or `decode-traffic-*.json`) for the marker strings and reports which fictional values appear in a request body, a response body, or a request URL, with the recipient host, path, method, and status. It emits no adjacent body content, so the report is safe to commit.
- The committed, sanitized network logs are NOT searched: their bodies are redacted, so the fictional values would be invisible there. Only the raw local capture can show exfiltration.
- Procedure is documented in `METHODOLOGY.md` (Synthetic baby-data transmission test).

**Status:** Profile, scan tool, and unit test are committed. Live captures across the 16 apps are pending operator execution on the emulator, after which the per-app verdicts feed the Final Report.

**Success criterion:** Every app exercised with the fictional profile has a verdict in the Final Report: `transmission_observed` (a marker left the device, with recipient) or `no_transmission_detected` (the capture shows the entered values did not leave).

### Per-app injection flows (automated, in progress)

**Goal:** every app gets a reusable, committed flow (`scripts/inject-config/<package>.json`) that drives its onboarding to enter the synthetic profile and taps save so the markers actually transmit. Built from a **one-time UI/UX capture** so we never re-drive the app by hand.

**Repeatable workflow (wired into `run-tests.sh --live` via `inject-synthetic-profile.py`):**
1. **Baseline** - capture launch traffic with no data entered; build the sanitized network log. (`results/<slug>-test-<date>/artifacts/captures/<slug>.mitm` -> `network-log-<slug>.json`)
2. **UI/UX capture** - `scripts/capture-uiux.py <package>` walks the onboarding and records every screen's `uiautomator` dump + screenshot under `results/<slug>-test-<date>/artifacts/uiux/screenN.xml|.png`. One-time, reusable artifact.
3. **Build flow** - read the captured dumps/screenshots and write `scripts/inject-config/<package>.json` with a `steps` list (tap_text / fill / wait) that reaches the baby-profile form and taps save.
4. **Inject + capture + scan** - `run-tests.sh --live` runs the flow while mitmdump + proxy are live; `scan-synthetic-baby-data.sh` gives the real verdict.

**Per-app status (Batch 2 = pebbi, amila, baby-daybook, baby-plus, mimilog):**

| App | Package | Baseline | UI/UX | Flow | Verdict |
|-----|---------|----------|-------|------|---------|
| Pebbi | com.pebbi.android | done | WebView/splash, 0 native EditText (CLOSE only, 15 screens) | BLOCKED: WebView; native injector cannot drive; needs WebView automation or account | - |
| Amila | com.amila.parenting | done | 2 native EditText (Baby name, Birthday) + 16+ checkbox + Done | built + validated (`inject-config/com.amila.parenting.json`) | no_transmission_detected (profile stored locally; app syncs only after login) |
| Baby Daybook | com.drillyapps.babydaybook | done | 2 native EditText (same layout as Amila) + 16+ checkbox + Done | built + validated (`inject-config/com.drillyapps.babydaybook.json`) | no_transmission_detected (same) |
| Baby+ | com.hp.babyapp | done | Logged in. About You + About Baby captured. Gender control has no TalkBack name (see FINAL-REPORT Baby+) | About You CONTINUE works (`inject-config/com.hp.babyapp.json`). About Baby DONE blocked: required gender is one unlabeled EditText | pending (DONE not reached) |
| MimiLog | com.mimiapp.mimilog | done | Native Flutter. Create profile then Dashboard. Labels in `content-desc`. No Google. Package has no `INTERNET`. | onboarded recipe `inject-config/com.mimiapp.mimilog.json` (Bottle 482 mL, `dismiss: false`) | no_transmission_detected on system HTTP proxy (0 flows). Play license is not a baby-profile upload. |

**Validation result (2026-08-16):** the injector + per-app `steps` flows are proven end-to-end on Amila and Baby Daybook - they fill the baby name, check the 16+ box, tap Done, and the capture + scan report the correct `no_transmission_detected`. Those two apps keep the profile local and only sync after account login. A Google account is on the emulator. Baby+ Google login succeeded with the proxy off. Baby+ **DONE** is blocked by an unlabeled gender control (accessibility finding in FINAL-REPORT). Pebbi still needs a live Appium login run (`scripts/appium-webview-login.py`). MimiLog (2026-08-17) does not need Appium.

Note: the earlier generic heuristic injector still works for apps whose onboarding form is reachable from launch, but the per-app `steps` flows are what make the verdicts meaningful and repeatable (no re-driving the app by hand).

## Sprint 5  -  Planned  -  Legacy re-capture and evidence parity

**Goal:** Bring the 8 legacy apps (nurture-lock, nubo, pebbi, amila, baby-buddy, baby-daybook, baby-plus, mimilog) up to the same evidence depth as the wave-1/wave-2 apps. Their raw `.mitm` captures disappeared before the retention rule existed (AGENTS.md "Evidence retention"); their results are decode-level only, and two of them (Amila, Baby+) are the same shape of thin evidence that flipped Nanit and Pregnancy+ to major.

### Legacy re-capture  -  Planned
- Re-run the harness on all 8 legacy apps with the new retention rule in force; preserve `results/<app>-test-<date>/artifacts/captures/*.mitm` permanently (evidence-inventory guard now enforces this).
- Expected caveat: current APK versions differ from the tested builds (e.g. we tested Baby+ at v2.0.10 and BellyBloom at v1.0.8). Record the tested APK hash in RESULTS and note version drift in the report; if archived APKs exist locally, prefer them for continuity.
- After each capture: run `scripts/build-network-logs.sh` to produce enriched network logs, then re-audit `privacy_class` and evidence at full depth (expect: Amila and Baby+ may flip minor -> major like Nanit/Pregnancy+ did).
- After each capture: run `scripts/scan-analytics-pii.sh` to inventory all analytics and PII-bearing calls, including unknown hosts.
- Update `RESULTS-20260803.json` `evidence_source` for the 8 apps from `session-summary` to `raw-replay`, refresh the FINAL-REPORT blocks, and re-run all gates (unit tests, evidence inventory, schema validation).
- Success criterion: all 16 apps have `evidence_source: raw-replay` and a preserved, non-zero-byte capture tree; zero apps classified on decode-level evidence alone.
