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

**Backfilled inject and limited options (rule, 2026-08-24):** When we return to an app for a later inject, re-scan, or article picture pass, follow the same bar as a first pass:

1. Prefer profile sentinel values when the UI accepts them.
2. When a field only offers a short list (chips, pickers, units), pick from those options. If the preferred sentinel will not stick, keep the value that sticks.
3. Write the exact number or unit that was saved into `FINAL-REPORT.md` (and this roadmap row when it is the live note).
4. Scan the raw capture for that exact string as well as the usual profile markers. Say whether those strings left the device.
5. A fixed target (for example Nubo formula-per-click 90) is not required for a finished inject. Missing a preferred chip is not an unfinished test when the stuck value is recorded and scanned.
6. Pairip CLOSE, Play stub blocks, and native Pairip crashes stay environment blockers. They are never privacy PASS or FAIL.

Example: Nubo 2026-08-23 entered formula-per-click **15** (90 did not stick). That value is what to name and search for. Backup Now finished on 2026-08-24 (last backup time `08/24/2026 18:49:05` after GMS Continue).

**Status:** Profile, scan tool, and unit test are committed. Live captures across the 16 apps are pending operator execution on the emulator, after which the per-app verdicts feed the Final Report. PR 49 merged the limited-picker rule into `AGENTS.md`, `METHODOLOGY.md`, and the Nubo live notes.

**Success criterion:** Every app exercised with the fictional profile has a verdict in the Final Report: `transmission_observed` (a marker left the device, with recipient) or `no_transmission_detected` (the capture shows the entered values did not leave). When the entered amount or unit differs from the profile sentinel, the report also names that entered value and whether it left the device.

### Queue after PR 51 (2026-08-24)

| Slice | Scope | Status |
| --- | --- | --- |
| D | Pairip / Play stub tooling-only: docs and harness messaging so Pairip CLOSE and Baby Daybook native crash are never read as privacy PASS/FAIL. No fake verdicts. | Done (PR 50). |
| Nubo Backup Now | Optional live pass: finish or document GMS consent. Formula 90 optional; **15** already counts. Shut qemu when the pass ends. | Done (PR 51). Last backup time `08/24/2026 18:49:05`. |
| Sprint 5 | Legacy re-capture and evidence parity (see section below). | In progress (Amila Done 2026-08-25). |

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
| Pebbi | com.pebbi.android | done | 2026-08-17: Pairip CLOSE on cold start. Appium warm path: Welcome, units, Add New Baby (name EditText + date picker + icon gender). No WebView. | BLOCKED: Play license on cold start (vending 1.8 stub). Form reached once; Complete Setup not saved | no_transmission_detected on 8-flow proxy capture; profile not saved |
| Amila | com.amila.parenting | done | 2 native EditText (Baby name, Birthday) + 16+ checkbox + Done | built + validated (`inject-config/com.amila.parenting.json`) | 2026-08-25 live recapture: `no_transmission_detected` (name on home; profile sync still login-gated). Recipe taps reported ok; form shots still showed the form until home opened. |
| Baby Daybook | com.drillyapps.babydaybook | done | 2 native EditText (same layout as Amila) + 16+ checkbox + Done | built + validated (`inject-config/com.drillyapps.babydaybook.json`) | no_transmission_detected (same) |
| Baby+ | com.hp.babyapp | done | Logged in. About You (2026-08-16 and 2026-08-21). About Baby name + Girl + DONE. Then MainActivity Important Update (GO TO PLAYSTORE). Gender TalkBack dump still has no Boy/Girl nodes; Girl is in a PopupWindow | Recipe taps spinner then Girl then `done_button` (`inject-config/com.hp.babyapp.json`) | `transmission_observed` on About You PUT (`firstName` to maker server) in both `Baby+-about-you.mitm` (2026-08-16, 1 flow) and `BabyPlus-about-you-full.mitm` (2026-08-21). Re-scan after HAR `postData` fix (2026-08-23). 2026-08-19 upgrade soak still `no_transmission_detected` (name only in a maker **response**; About You not on screen that day). Force-upgrade still blocks home. |
| MimiLog | com.mimiapp.mimilog | done | Native Flutter. Create profile then Dashboard. Labels in `content-desc`. No Google. Package has no `INTERNET`. | onboarded recipe `inject-config/com.mimiapp.mimilog.json` (Bottle 482 mL, `dismiss: false`) | no_transmission_detected on system HTTP proxy (0 flows). Play license is not a baby-profile upload. |
| Nubo | com.clicksie.nuboapp | done | 2026-08-17 create profile; 2026-08-18 home timers + Logs | built (`inject-config/com.clicksie.nuboapp.json`): start/stop milk L/R, sleep, pump; bottle/pee/poop taps; NoteActivity save | no_transmission_detected on 15-flow 2026-08-18 soak (emulator-wide proxy). 0-byte 2026-08-17 file kept. 2026-08-24 Backup Now finished in UI (Drive consent Continue); no new `.mitm` (proxy `:0`); not Firebase-silence |

**Validation result (2026-08-16):** the injector + per-app `steps` flows are proven end-to-end on Amila and Baby Daybook - they fill the baby name, check the 16+ box, tap Done, and the capture + scan report the correct `no_transmission_detected`. Those two apps keep the profile local and only sync after account login. A Google account is on the emulator. Baby+ Google login succeeded with the proxy off. Baby+ **DONE** (2026-08-19): Girl is not in the uiautomator dump. Open the spinner, tap the lower popup row, then DONE. Pebbi (2026-08-17) is native after Pairip, not WebView login. Cold start needs a real Play Store license, not the API 29 stub. Nurture Lock on this AVD is Pairip CLOSE only. Nubo 1.4 is installed from `apks/nubo.apk`. Profile saved 2026-08-17. Full activity inject 2026-08-18 (see table). MimiLog (2026-08-17) does not need Appium.

Note: the earlier generic heuristic injector still works for apps whose onboarding form is reachable from launch, but the per-app `steps` flows are what make the verdicts meaningful and repeatable (no re-driving the app by hand).

## Sprint 5  -  Planned  -  Legacy re-capture and evidence parity

**Goal:** Bring the apps that `results/RESULTS-20260803.json` still marks `session-summary` up to the same committed evidence depth as the `raw-replay` apps. After the 2026-08-25 overnight batch, five names remain: MimiLog, Nurture Lock, Pebbi, Baby Buddy, and Baby Daybook. This section names priorities. It does not invent a privacy PASS or FAIL.

**What is true on disk vs in RESULTS (2026-08-25, this machine):** Amila, Nubo, and Baby+ joined the `raw-replay` set today. Nubo was promoted by replaying its preserved 2026-08-03 launch capture. Baby+ was promoted after a live finished-profile recapture that needed a system-store mitm CA reinstall first (`-writable-system` boot; two 0-byte same-day attempts are kept). MimiLog hit a Pairip license dialog CLOSE-loop on cold start, for the installed build and an archived-build sideload test, so it stays `session-summary`.


### Play-store unlock slice  -  Harness merged; flash pending
- PR 55 merged the harness (2026-08-25): `scripts/gapps_state.py`, `scripts/playstore-setup.sh`, and both deterministic suites now run in CI.
- Remaining step needs an operator-supplied GApps zip plus its published SHA256SUMS. Then: `backup pre-gapps` -> `install-zip` -> `verify` -> `pairip-probe` on MimiLog, Pebbi, Nurture Lock, and Baby Daybook.
- Goal: pass the Pairip license check on MimiLog, Pebbi, Nurture Lock, and Baby Daybook by putting a real Google Play store on the rootable test emulator (operator approved 2026-08-25), while keeping root so captures stay readable.
- Scope guard: only the four blocked apps run on the playstore-enabled snapshot. No full retest of already-promoted apps; their verdicts describe captured sessions and stay valid. Any result from the new stack is tagged as captured on a playstore-enabled image.
- Safety: `scripts/playstore-setup.sh` refuses system changes without a `pre-gapps` snapshot, verifies zip checksums before install, and re-checks the mitm CA after reboot. Deterministic classifiers live in `scripts/gapps_state.py` with fixtures from real sessions (`tests/test-gapps-state.sh`, runs in CI).

| App | RESULTS `evidence_source` | Kept `.mitm` on this machine | Sprint 5 note |
| --- | --- | --- | --- |
| Nurture Lock | session-summary | `nurture-lock-test-20260803` (136052 bytes) | Pairip CLOSE on this AVD. Environment blocker. Not privacy PASS or FAIL. Do not install a real Play Store unless the operator asks. |
| Nubo | raw-replay (2026-08-25) | Replay of `nubo-test-20260803` (94146, 11 flows). Soak `nubo-test-20260818-soak` (628913) kept. Zero-byte `Nubo.mitm` (2026-08-17) and `Nubo-backup-google.mitm` (2026-08-23) kept. | Promoted by replaying the preserved launch capture; Firebase Installations row has origin `app`. Backup Now finished in the app UI (PR 51). Not Firebase-silence. |
| Pebbi | session-summary | `pebbi-test-20260816` and `pebbi-test-20260817` (largest `Pebbi-profile.mitm` 386435) | Pairip CLOSE on cold start. Environment blocker. Not privacy PASS or FAIL. |
| Baby Buddy | session-summary | `baby-buddy-test-20260803` (2265 bytes) | Web PASS stays the Django capture. Companion pictures exist (PR 48). Not a new privacy capture. |
| Amila | raw-replay | `amila-test-20260825` (`Amila.mitm` 106226 bytes). Earlier `amila-test-20260816` and `amila-test-20260817` kept. | Live inject 2026-08-25. Name **Privatia Rigatoni** on home. Scan `no_transmission_detected`. Network log rebuilt. Not Firebase-silence. |
| Baby Daybook | session-summary | `baby-daybook-test-20260816` and `baby-daybook-test-20260817` | Pairip native crash on this AVD. Environment blocker. Not privacy PASS or FAIL. |
| Baby+ | raw-replay (2026-08-25) | `baby-plus-test-20260825` (`BabyPlus-final.mitm` 1373381, 40 flows). Zero-byte `BabyPlus.mitm` and `BabyPlus-retry.mitm` from 2026-08-25 kept; they predate the CA reinstall. Earlier `20260816`, `20260819`, `20260821` kept. | Live finished-profile recapture (name Privatia Rigatoni twice, gender Girl). Install register POST to Philips server plus Facebook and Google ad hosts. Name PUT not seen leaving today; the 2026-08-21 capture saw it once. Force-upgrade gate did not appear this run. |
| MimiLog | session-summary | `mimilog-test-20260816` (7771). Zero-byte 2026-08-17 files and 0-byte `MimiLog.mitm` from 2026-08-25 kept. | 2026-08-25: Pairip `LicenseActivity` shows "Something went wrong" and CLOSE-loops on cold start. Same on the archived xapk after a sideload test. Network log rebuilt from the kept capture; manifest declares no `INTERNET`. Pass mark unchanged, evidence text refreshed. |

Prefer the next live recapture that is not Pairip-blocked on this AVD (not Pebbi, Nurture Lock, BellyBloom CLOSE, or Daybook Pairip crash). One app, one PR. Stop for operator merge between slices.

### Legacy re-capture  -  Planned
- Re-run the harness on each session-summary app that still needs a promotable capture. Keep `results/<app>-test-<date>/artifacts/captures/*.mitm` forever, including zero-byte files (evidence-inventory guard).
- Expected caveat: current APK versions differ from the tested builds (for example Baby+ v2.0.10). Record the tested APK hash in RESULTS and note version drift in the report. If archived APKs exist locally, prefer them for continuity.
- After each capture: run `scripts/build-network-logs.sh` to produce enriched network logs, then re-audit `privacy_class` at full depth. Amila and Baby+ can still change class after a full replay, the same way Nanit and Pregnancy+ did. That change is a later slice, not this docs PR.
- After each capture: run `scripts/scan-analytics-pii.sh` to inventory analytics and PII-bearing calls, including unknown hosts.
- Update `RESULTS-20260803.json` `evidence_source` from `session-summary` to `raw-replay` only after that replay. Then refresh the Final Report blocks. Re-run unit tests, evidence inventory, and schema validation.
- Success criterion: all 16 apps have `evidence_source: raw-replay` and a preserved capture tree. Zero apps classified on decode-level evidence alone. Keep zero-byte `.mitm` files.

## Final sprint - operator sit-down

One session. Keep the windowed API 29 emulator (`emulator-5554`). Do not restart it headless. Google sign-in: proxy off, then restore `10.0.2.2:8080` before capture.

| Blocker | Why an operator is required | What to do |
| --- | --- | --- |
| Pebbi Play license / Pairip | Cold start opens Pairip `LicenseActivity`. Play Store on this AVD is stub 1.8. Complete Setup stayed disabled when female was not tapped. | Install a real Play Store, open 4.0.1, tap female, save the profile, then capture+scan. |
| Nurture Lock Pairip | Local 1.0.13 only. CLOSE only. No inject. | Same Play license path, or skip if the licensed build still cannot leave Pairip. |
| Baby Daybook Pairip native crash | `VMRunner` UnsatisfiedLinkError on this AVD. Not a privacy verdict. | Try a device or AVD that loads Pairip, then inject. |
| Baby+ About Baby gender | Done 2026-08-19. Dump still has no Boy/Girl nodes. PopupWindow frame `[63,971][1025,1219]`; Girl is the lower row. | Recipe updated. About You picture + capture done 2026-08-21 after app-data clear. Force-upgrade still blocks home after DONE. |
| Nubo capture+scan of finished use | Done 2026-08-18 (evening soak). New file only. 0-byte `results/nubo-test-20260817/artifacts/captures/Nubo.mitm` kept. 2026-08-23: Google login for backup with proxy off. Backup Now did not finish that day. Formula stayed at the chip that stuck (15). Preferred sentinel 90 did not stick. 2026-08-24: Backup Now finished after GMS Continue. | Ran inject on `com.clicksie.nuboapp`. The system HTTP proxy stayed up about 21 minutes. The new file has 15 flows and did not grow after 18:58. Those flows are the whole emulator proxy (Play, GMS, YouTube, host control), not Nubo-only. Scan: `no_transmission_detected` (no high/medium name or note marker in a request or URL). 2026-08-23: account picker completed with proxy `:0`. Backup Now then Yes left a spinner and `com.google.android.gms/.signin.activity.ConsentActivity`. 0-byte `results/nubo-test-20260823/artifacts/captures/Nubo-backup-google.mitm` kept. `wlan0` pcap 41518 bytes (no `eth0`). 2026-08-24: proxy `:0`; last backup `08/24/2026 18:49:05`; `wlan0` pcap 1339264 bytes. Entered formula-per-click **15** (90 chip would not stick). Record that value and whether it left the device; do not treat missing 90 as an unfinished inject. This is still not the Firebase-silence bar in METHODOLOGY.md. |

## Screenshots for every prior test

The later public article needs a picture of each step we actually ran, not only Nubo. Keep PNGs under `results/<app>-test-<date>/artifacts/uiux/` (binary `adb exec-out screencap`). Do not commit those files.

**Already on disk (Nubo 2026-08-18, this operator machine only):** `article-01-logs.png`, `article-02-chart.png`, `article-03-device.png`, `article-04-logs-again.png`, plus `after-inject.png` and `after-inject3.png`. These files were not overwritten.

**Captured this slice (gitignored PNGs; binary `adb exec-out screencap`):**

| App | Labeled PNG (under that app's `artifacts/uiux/`) | Notes |
| --- | --- | --- |
| Nubo | soak dir `nubo-test-20260818-soak` plus `nubo-test-20260823` plus `nubo-test-20260824`: `article-home.png`, `article-settings.png`, `article-backup.png`, `article-backup-now.png`, `article-backup-yes.png`, `article-backup-wait.png`, `article-backup-consent-scrolled.png`, `article-backup-consent-bottom.png`, `article-backup-after-gms.png`, `article-backup-done.png` | 2026-08-18 finished inject. 2026-08-23: Google login with proxy off; Backup Now hung on GMS spinner. 2026-08-24: GMS Continue, last backup time set. Formula stayed 15. |
| Amila | `article-home-done.png`, `article-form.png` (2026-08-17 copies). 20260825: `article-launch.png`, `article-after-inject.png`, `article-home-done.png`, `article-home-current.png`, `article-app-home.png` | 2026-08-25 live recapture. Home shows **Privatia Rigatoni**. |
| MimiLog | `article-bottle-save.png` | Copy of the 482 mL bottle log. |
| Baby+ | 20260816: `article-about-baby.png`, `article-launch.png`, `article-relaunch.png`. 20260819: `article-about-baby-girl.png`, `article-gender-required-dialog.png`, `article-gender-icons-unlabeled.png`, `article-gender-popup-boy-girl.png`, `article-upgrade-gate.png`. 20260821: `article-about-you.png`, `article-about-you-filled-full.png`, `article-gender-popup-full.png`, `article-about-baby-girl-full.png`, `article-upgrade-gate.png` | About You captured after `pm clear`. Girl + DONE. Force-upgrade again. |
| Pebbi | `article-pairip-close.png`, `article-form.png`, `article-pairip-close-relaunch.png` | Pairip CLOSE is not a privacy verdict. |
| Nurture Lock | `article-pairip-close.png`, `article-pairip-close-relaunch.png` | Pairip CLOSE is not a privacy verdict. |
| Baby Daybook | `article-pairip-crash.png`, `article-pairip-crash-relaunch.png` | "keeps stopping". Not a privacy verdict. |
| BabyCenter | `article-launch.png` | WelcomeActivity stayed on a white spinner. |
| BellyBloom | `article-launch.png`, `article-pairip-close.png` | Pairip CLOSE on this AVD. |
| Nanit | `article-launch.png` | Get started / Log in. |
| Pregnancy+ | `article-launch.png` | Welcome / account buttons. |
| What to Expect | `article-launch.png` | Stage picker. |
| Heartful Baby | `article-launch.png` | Sideload of `apks/heartful-baby.apk` then "keeps stopping". |
| Nara | `article-launch.png` | Sideload of `apks/nara.apk` then "keeps stopping". |
| Pixy | `article-launch.png` | Sideload of `apks/pixy.apk` then "keeps stopping". |
| Baby Buddy | 20260823: `article-launch.png`, `article-login-form.png` | Sideload of GitHub release `apks/babybuddy-for-android-v2.6.4.apk` (package `eu.pkgsoftware.babybuddywidgets`, version 2.6.4, MIT). First screen is "Login to Baby Buddy" (server URL, login name, password). We did not type a URL or log in. This companion is not the Django web app we audited. PASS still rests on the 2026-08-03 localhost web session. No new privacy verdict. |

**Success for this slice:** every FINAL-REPORT app has a labeled PNG. Baby+ has About You, About Baby, Girl, and upgrade-gate pictures.

**Verified 2026-08-25** with `scripts/uiux_inventory.py --results results --format markdown`: all 16 apps have at least one PNG on disk (258 total, 0 zero-byte). The tool is tested (`tests/test-uiux-inventory.sh`, runs in CI); run it locally for a current count. Backfill rule stays: every new capture session adds labeled PNGs for launch, form, saved state, and any blocker screen.

## App surface and sync-condition coverage (snapshot 2026-08-18)

This is a planning report, not a new privacy verdict. Percents are rough from screens we reached, not from line coverage.

**What most captures actually are:** a first-launch window of about one to five minutes through the system HTTP proxy. That window can show install, ads, and Firebase setup. It does not prove we waited as long as a delayed sync, and it does not prove we hit every button that starts a backup.

**Sync conditions we usually did not trigger on purpose:**

- Wait 15 to 60 minutes idle (many SDKs batch then).
- Background the app, lock the phone, or reconnect Wi-Fi.
- Tap Backup, Restore, Share, Collaborate, or Sign in (except Baby+ Google login for About You).
- Pair hardware (Nubo device, Nanit camera, and similar).
- A packet capture the app cannot skip (needed before we say Firebase sent nothing). See METHODOLOGY.md.

**Per-app snapshot**

| App | About how much of the app we used | Finished profile + activity? | Waited for a delayed sync? | Hit the usual sync buttons? |
| --- | --- | --- | --- | --- |
| Nubo | Home timers, Logs, saved note, Settings, Edit profile, Backup & Restore. 2026-08-23: Google account picked with proxy off. 2026-08-24: Backup Now finished after GMS Drive Continue (last backup `08/24/2026 18:49:05`). Chart/Device still from earlier pictures. Not BLE pair. Formula-per-click entered as **15** (preferred 90 did not stick; that is enough when recorded and scanned). | Yes. Inject plus about 21 minutes with the system HTTP proxy still on. The flow file did not grow after 18:58. | 2026-08-18 proxy stayed up. 2026-08-23: 0-byte HTTP-proxy file for backup; small `wlan0` pcap during hung consent. 2026-08-24: proxy `:0`; `wlan0` pcap 1339264 bytes during finished backup. | Opened Backup. Signed in with proxy off. 2026-08-24 Backup Now completed in the app UI. |
| MimiLog | Create profile (earlier), Dashboard Bottle 482 mL, nap 777, note. | Yes, local save. | No. Package has no `INTERNET`. | None. Play license is not a baby-data upload. |
| Amila | Name, birthday, 16+ box, Done. 2026-08-25 home showed **Privatia Rigatoni**. One bottle row appeared during the session (`5s, 8oz`). | Profile save, yes. Full feeding/sleep/diaper suite, no. | Short proxy window after inject (~20s observe plus flush). | Login/sync after account, no. |
| Baby+ | Google login (proxy off). About You parent name + CONTINUE (2026-08-21). About Baby name + Girl + DONE. Then force-upgrade gate. | About You + baby form saved; home blocked by upgrade. | Proxy up about 21 minutes on the upgrade screen after inject. File stayed 589,030 bytes (no growth after inject). | Play Store button not tapped. |
| Pebbi | Welcome, units, Add New Baby. Complete Setup not saved. Pairip on cold start. | No. | No. | No. |
| Nurture Lock | Pairip CLOSE only. | No. | No. | No. |
| Baby Daybook | Pairip native crash. No inject. | No. | No. | No. |
| Baby Buddy | Django web audit (2026-08-03) plus Android companion first-launch pictures (2026-08-23). Companion stayed on the login form. Zero app-originated outbound in the web replay. | Synthetic inject not in the live batch. Companion: no server URL, no login. | No designed soak. | Self-hosted web app; no vendor sync by design. Companion would talk to a server you host; we did not connect one. |
| BabyCenter, BellyBloom, Nanit, Pregnancy+, What to Expect, Heartful Baby, Nara, Pixy | First-launch capture only. | No synthetic profile in those windows. | Launch window only, not a 15-60 min idle. | No account, camera, or backup flows in the live inject batch. |

**Final-sprint work from this report**

1. Baby Buddy first-launch pictures are on disk (2026-08-23): GitHub `babybuddy-for-android` v2.6.4 sideloaded on emulator-5554. Login screen only. Did not connect a server. PASS is still the Django web capture, not this companion.
2. Baby+ About You picture and capture are done (2026-08-21). Batch re-scan of preserved `.mitm` after HAR `postData` fix (2026-08-23): only Baby+ About You captures flip to `transmission_observed` (2026-08-16 and 2026-08-21). All other non-zero captures in the tree stayed `no_transmission_detected`. Force-upgrade still blocks home.
3. For Nubo: Google sign-in for backup is done (2026-08-23, proxy off). Backup Now finished 2026-08-24 after GMS Drive Continue (last backup `08/24/2026 18:49:05`). Formula-per-click entered as **15** (preferred 90 did not stick). That entered value is enough under the limited-options rule above; name it and scan for it. `wlan0` pcaps exist; `eth0` is missing on this AVD. The 2026-08-23 0-byte `.mitm` is still kept. Do not treat HTTP-proxy silence or a TLS pcap as Firebase silence.
4. Do not treat a 0-byte file, a 0-flow file, or a short emulator-wide HTTP-proxy file as "Firebase sent nothing." See METHODOLOGY.md.
5. Slice D is merged (PR 50): Pairip CLOSE and Daybook crash are environment blockers, not privacy PASS/FAIL.
