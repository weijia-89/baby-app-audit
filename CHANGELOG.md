# Changelog

## 4.6.20 - 2026-08-24

### Changed
- `ROADMAP.md`: queue after PR 51. Slice D Done (PR 50). Nubo Backup Now Done (PR 51). Next work is Sprint 5 legacy re-capture.
- `ROADMAP.md`: table names which of the eight `session-summary` apps already have a kept `.mitm` on disk. Pairip CLOSE and Baby Daybook Pairip crash stay environment blockers. No new privacy PASS or FAIL.
- `FINAL-REPORT.md` Limits: eight `raw-replay` and eight `session-summary` in RESULTS. Points at `ROADMAP.md` Sprint 5. Does not add per-call URLs.
- `README.md` What is next: Sprint 5 recapture is the next slice.

## 4.6.19 - 2026-08-24

### Changed
- `FINAL-REPORT.md`: shorter public layout. Summary table and per-app Claim / Result / service tables stay. Dropped per-call URLs and status codes (those stay in `results/network-log-<app>.json`). Session diaries and inject method moved to a synthetic-marker table and `ROADMAP.md`. `README.md` points at that split.

## 4.6.18 - 2026-08-24

### Added
- Nubo Backup Now live pass (2026-08-24) on windowed emulator-5554 (`apk-test-api29`). Settings still showed Logout for `thebabyaudit@gmail.com`. HTTP proxy stayed `:0` for GMS consent. Backup Now, Yes, then GMS `ConsentActivity` Drive-files screen. Continue was in the WebView dump after scroll (`[556,1809][946,1922]`). After Continue, `tvLastBackupValue` read `08/24/2026 18:49:05`. Formula-per-click stayed **15** (not changed).

### Changed
- `ROADMAP.md` and `FINAL-REPORT.md`: gitignored pictures under `results/nubo-test-20260824/artifacts/uiux/`. `wlan0` pcap `nubo-backup-wlan0.pcap` is 1339264 bytes (TLS to Google IPv4s; no `eth0`). No new `.mitm` this pass (proxy off). This is a finished Backup Now in the app UI. It is not a Firebase-silence result and not a change to the 2026-08-03 FAIL mark.

## 4.6.17 - 2026-08-24

### Changed
- Slice D: Pairip CLOSE and Baby Daybook Pairip native crash are documented as environment blockers, not privacy PASS or FAIL (`METHODOLOGY.md`, `FINAL-REPORT.md`, `README.md`, `ROADMAP.md`, `AGENTS.md`). BellyBloom CLOSE called out the same way.
- Code comments in `scripts/` and `tests/`: short plain English. Removed empty section labels. Behavior unchanged.
- `scripts/run-tests.sh`: inject warn text says continuing capture is not a privacy PASS/FAIL.

## 4.6.16 - 2026-08-24

### Changed
- `ROADMAP.md`: backfilled inject rule for short lists (chips, pickers, units). Prefer the profile sentinel when it sticks; otherwise keep the value that sticks, name it in the Final Report, and scan for transmission. Fixed targets such as formula-per-click 90 are not required. Pairip CLOSE and native Pairip crashes stay environment blockers, not privacy PASS/FAIL. Queue table: Slice D next after PR 49.

## 4.6.15 - 2026-08-24

### Changed
- Testing rule for short lists (chips, pickers, units): pick from the options the app offers, prefer the profile sentinel when it sticks, otherwise keep the value that sticks. Record the exact number or unit in `FINAL-REPORT.md` and say whether that string left the device. A fixed target such as Nubo formula-per-click 90 is not required for a finished inject. Docs: `AGENTS.md`, `METHODOLOGY.md`, `FINAL-REPORT.md`, `ROADMAP.md`, `scripts/inject-config/README.md`, `results/synthetic-baby-profile.json`.

## 4.6.14 - 2026-08-23

### Added
- Nubo Backup / formula-90 live pass (2026-08-23) on emulator-5554. Google sign-in for backup with the HTTP proxy off (`thebabyaudit@gmail.com` already on the device). Settings then showed Logout. Backup Now opened a Yes/No dialog, then a spinner while `ConsentActivity` stayed in front. The Drive/GMS consent dump had no uiautomator nodes. Formula-per-click stayed 15: the 90 chip is not clickable; a full-width `viewMap1` overlay eats taps, and an Appium click on text 90 also left `selected=false`.

### Changed
- `ROADMAP.md` and `FINAL-REPORT.md`: record gitignored pictures under `results/nubo-test-20260823/artifacts/uiux/`. Kept 0-byte `Nubo-backup-google.mitm` (failed HTTP-proxy capture for this backup). Pulled `nubo-backup-wlan0.pcap` (41518 bytes) from `wlan0` (`eth0` does not exist on this AVD). TLS to Google IPs during the hung consent window is not a finished backup and is not the Firebase-silence bar.

## 4.6.13 - 2026-08-23

### Added
- Baby Buddy Android companion first-launch pictures (2026-08-23). Sideloaded GitHub release `babybuddy-for-android` v2.6.4 (`eu.pkgsoftware.babybuddywidgets`, SHA-256 `1357e6f3c564d0e0886556eef142dbeb6bf542c867870b7687ab69e2dc68eb99`) onto emulator-5554. Binary screenshots: `results/baby-buddy-test-20260823/artifacts/uiux/article-launch.png` and `article-login-form.png` (gitignored). Login form only. We did not enter a server URL or log in. This is not a new privacy capture. The Django web PASS stays the same.

### Changed
- `ROADMAP.md` and `FINAL-REPORT.md`: record the companion PNGs and say the PASS still comes from the 2026-08-03 localhost web session.

## 4.6.12 - 2026-08-23

### Changed
- Batch re-scan of preserved local `.mitm` files after the HAR `postData` fix (29 non-zero captures; 6 zero-byte starts kept). Only Baby+ About You captures report `transmission_observed`: `Baby+-about-you.mitm` (2026-08-16, 1-flow PUT) and `BabyPlus-about-you-full.mitm` (2026-08-21). All other non-zero captures stay `no_transmission_detected`.
- `ROADMAP.md` and `FINAL-REPORT.md`: record the 2026-08-16 About You PUT as `transmission_observed`. Correct the 2026-08-19 upgrade-soak note - re-scan still finds no high/medium name marker in a request or URL (name only in a maker response).

## 4.6.11 - 2026-08-22

### Added
- `scripts/evidence_mitm_policy.py` and `tests/test-evidence-inventory.sh` for zero-byte `.mitm` classification.

### Fixed
- `scripts/evidence-inventory.sh`: zero-byte `.mitm` files now warn only (kept failed starts). Missing committed network logs still fail the check. Errors print to stderr. The script skips non-file capture entries.
- Tests call the real inventory script via `EVIDENCE_RESULTS_DIR` (must resolve under `.tmp/`).
- Inventory rejects an `EVIDENCE_RESULTS_DIR` outside `.tmp/`, warns on unreadable network logs, and tolerates `OSError` on capture `stat`.
- End-to-end test: zero-byte `.mitm` with a present network log exits 0 and prints WARN.
- Warn on duplicate `package_name` across network logs; coerce non-integer sizes in the policy to empty so WARN cannot be skipped.

### Changed
- `ROADMAP.md`: Baby+ inject table and final-sprint notes use `transmission_observed` for the 2026-08-21 About You PUT after the HAR `postData` fix.

## 4.6.10 - 2026-08-21

### Added
- Baby+ About You live pass (2026-08-21): cleared `com.hp.babyapp`, Google login with proxy off, About You PNG on disk, parent name Privatia Rigatoni, CONTINUE, About Baby Girl + `done_button`, then force-upgrade. Local evidence under `results/baby-plus-test-20260821/` (gitignored).
- `scripts/har_postdata.py` plus `tests/test_har_dump_postdata.py` / `tests/test-har-dump.sh` so HAR conversion keeps request body text.

### Fixed
- `scripts/har_dump.py` now writes HAR `postData.text`. Without that field, `scan-synthetic-baby-data.sh` on `.mitm` files could not see request bodies and missed the Baby+ About You PUT.
- `scan-synthetic-baby-data.sh` now decodes HAR `encoding=base64` request and response bodies before marker search, and uses a unique temp HAR file per convert.
- Repo-root path checks for the scan profile and output now use resolved-path containment (`relative_to`), not `startswith`, so a sibling directory with a matching prefix cannot pass.
- `har_dump.py` response bodies use the same `encode_body_text` helper as request packing.

### Changed
- `FINAL-REPORT.md` and `ROADMAP.md`: About You picture and capture are present. Capture `BabyPlus-about-you-full.mitm` has 14 flows and 589,030 bytes. Size reached that value during inject (About You CONTINUE plus About Baby DONE). It did not grow across a 21-minute idle on the upgrade screen. Scan after the HAR fix: `transmission_observed`. High-confidence name marker in a **request** PUT to `appserver.health-and-parenting.com` (`firstName`). Name also appears in a later maker-server **response**. Flows are the whole emulator HTTP proxy (maker server, Google ads, S3 backup GETs), not Baby+-only. Two earlier 0-byte mitm starts on this date were kept. Play Store was not tapped. This is not a Firebase-silence claim.

## 4.6.9 - 2026-08-19

### Added
- Baby+ live pass (2026-08-19): name Privatia Rigatoni, Girl selected, DONE. App opened MainActivity with an Important Update screen (GO TO PLAYSTORE). Local pictures and captures stay under `results/baby-plus-test-20260819/` (gitignored).
- Inject recipe for Baby+ now hides the keyboard, opens the gender spinner (right-edge tap), taps Girl in the popup, then taps `done_button` by id (`tests/test_inject_config.py` checks order and bounds).

### Fixed
- Baby+ inject test no longer accepts a reversed spinner/Girl order or a tap on the terms line that contains the word Done. The save step uses `done_button`. ROADMAP Nubo verdict cell now matches the 2026-08-18 soak.

### Changed
- `FINAL-REPORT.md` and `ROADMAP.md`: Baby+ DONE is no longer blocked. About You was not on screen (account already past that form). First proxy file stayed 0 bytes because mitmdump exited with the start script. A second file `BabyPlus-post-done-upgrade-soak.mitm` (716,753 bytes, 25 flows) ran about 21 minutes on the upgrade screen. The file grew at 19:00 (relaunch plus a host control) and again at 19:12 (`play.googleapis.com`). It did not grow after 19:12. Scan: `no_transmission_detected`. The baby-name marker appeared in a **response** from the maker server, not in a request or URL. Flows are the whole emulator HTTP proxy (maker, Facebook, Firebase, ads, Cognito, S3 backup hosts, Play), not Baby+-only. This is not a Firebase-silence claim.

## 4.6.8 - 2026-08-18

### Added
- Nubo finished-use soak: new local capture `results/nubo-test-20260818-soak/` (gitignored). The HTTP proxy stayed up about 21 minutes after the inject save. The flow file did not grow after 18:58 (15 flows). Scan JSON is local only. Those flows are all traffic through the emulator HTTP proxy, including Play, GMS, YouTube, and a host control GET, not Nubo-only.
- Article screenshots for prior tests (gitignored PNGs). Inventory is in ROADMAP.md.

### Changed
- `FINAL-REPORT.md` Nubo live line: 15-flow system-proxy scan, not a Firebase-silence claim.
- `ROADMAP.md`: screenshot table, Nubo soak row, remaining blockers.

## 4.6.7 - 2026-08-18

### Added
- `ROADMAP.md`: screenshot set for every prior test (article evidence, gitignored PNGs). Snapshot of how much of each app we used, whether we waited for a delayed sync, and which sync buttons we did not tap.
- `.github/workflows/test.yml`: banned-word check now includes `ROADMAP.md` and `FINAL-REPORT.md`.

### Changed
- `FINAL-REPORT.md` and `AGENTS.md`: point at the coverage snapshot and the screenshot backfill.

## 4.6.6 - 2026-08-18

### Added
- Injector steps: `tap_id`, `am_start` (same package only), `keyevent`, and `force_stop`. A tall text field is tapped near the top so the keyboard does not cover the tap. `am_start` rejects shell characters and classes outside the target package. Key codes are an allowlist. Wait steps cap at 30 seconds. Disabled buttons are not treated as taps.
- Nubo recipe `scripts/inject-config/com.clicksie.nuboapp.json`. Milk, sleep, and pump each start and stop. Bottle, pee, and poop each log one event. A note is saved.
- Profile extras Nubo asks for that were not already stored under another name: `formula_click_increment` (90, not 482 mL), `nursing_timeout_minutes` (45, not 777), `sleep_idle_timeout_hours` (5), `fluid_unit` (ml), `birth_date_us` (`03/14/26`, same birth as `2026-03-14`).

### Changed
- `METHODOLOGY.md`: alias-first profile fields; what it takes to claim Firebase sent nothing (packet capture the app cannot skip, reachable-host control, finished-activity window).
- Injector re-dumps the view between `fill_nth` fields. Swipe steps must be on-screen numbers. Tiny `[0,0][0,0]` nodes are not tapped.

### Fixed
- Nubo live run (2026-08-18): finished sessions on the saved Privatia Rigatoni profile. Logs showed bottle 15 mL (app default per click) and pump 30 mL. Note save returned to MainActivity. Proxy capture for that run was not started in this session.

## 4.6.5 - 2026-08-17

### Fixed
- `FINAL-REPORT.md` and `ROADMAP.md`: Pebbi live run on 2026-08-17. Appium reached Add New Baby. Complete Setup did not save. Cold start hit Pairip. Pulled 3.2.1, 3.4.0, 3.5.0. Capture had 8 flows. Scan: `no_transmission_detected`.
- Nurture Lock on this API 29 emulator opens Pairip `LicenseActivity` with CLOSE only. No inject.
- Nubo installed from `apks/nubo.apk`. Profile saved (name + DOB). No gender field. System-proxy capture 0 bytes. Scan: `no_transmission_detected`.

## 4.6.4 - 2026-08-17

### Added
- Injector `tap_text` matches `content-desc` as well as `text`, so Flutter TalkBack labels work. Unit tests: `tests/test_inject_node_match.py`.
- MimiLog inject config (`scripts/inject-config/com.mimiapp.mimilog.json`) for the live onboarded Dashboard: Feeding, Bottle, volume 482 mL, Save. Create-profile is gone once a baby exists.
- `.gitignore` entry for `results/synthetic-scan-*.json` so local scan files with machine paths are not committed.

### Changed
- `FINAL-REPORT.md`: MimiLog live save sits in the existing table and the proprietary short write-up. Extra live and Play-license detail stays in Footnotes (`[^mimilog-play]`). MimiLog is not FOSS; it is no longer under FOSS self-hosted.
- Injector `fill_nth` sends DPAD_CENTER and ESCAPE after typing unless the step sets `"dismiss": false`. MimiLog Bottle needs `dismiss: false`. Amila and Baby Daybook keep the default so Done is not under the keyboard.

### Fixed
- MimiLog live run (2026-08-17): bottle 482 mL saved. Nap 777 minutes saved. Synth note saved. System-proxy capture stayed at 0 flows.
- `FINAL-REPORT.md` grouped MimiLog under FOSS self-hosted. MimiLog is a closed Play Store app. The public GitHub page has no source license and no app source. The write-up now sits in the proprietary short report.

## 4.6.3 - 2026-08-16

### Added
- `scripts/adb_text.py` encodes spaces for `adb shell input text`. Unit tests: `tests/test-adb-text.sh`.
- Per-app injector configs under `scripts/inject-config/` (`tests/test-inject-config.sh` checks each JSON).

### Fixed
- Appium login helper honors `--wait-webview` instead of capping the wait at 15 seconds.
- Synthetic inject skips `swipe` steps that do not have four coordinates.
- Google account helper encodes `adb` text the same way as the injector, and prefers `ANDROID_SERIAL`.
- Appium native taps escape quotes in UiSelector strings.
- Live inject no longer reads an unset device serial or profile path. `run-tests.sh` pins `adb -s` to `ANDROID_SERIAL` (default emulator-5554), including proxy cleanup.
- App names that contain `+` (Baby+) pass input checks.
- Google account helper launches `ADD_ACCOUNT_SETTINGS` and checks `dumpsys account` for `type=com.google`. It does not print account lists. API 29 has no `cmd account list`.

## 4.6.2 - 2026-08-16

### Added
- Appium UiAutomator2 login helper: `scripts/appium-webview-login.py` taps native Baby+ LOGIN, then LOGIN WITH GOOGLE, then the device Google account in the GMS picker. Context picking lives in `scripts/webview_context.py` (`tests/test-webview-context.sh`). Live Appium is optional and not required for CI. In-app Google login still needs the audit proxy off, same as system account add.

## 4.6.1 - 2026-08-15

### Fixed
- `scripts/scan-synthetic-baby-data.sh` now treats name and note markers as strong transmission types in addition to string, so positive synthetic baby-data fixtures trigger transmission_observed.
- `tests/test-synthetic-baby-data.sh` writes temporary capture and output files inside the repo root so the output path guard accepts them.
- Remove stale `results/network-log-heartful_baby.json` with null package_name that failed schema validation and duplicated the correct `network-log-heartful-baby.json`.
- `scripts/scan-synthetic-baby-data.sh` output path validation now uses Path.resolve so non-existent output files are allowed by the repo-root guard.

## 4.6.0 - 2026-08-14

### Added
- Synthetic baby-data transmission test tooling: `results/synthetic-baby-profile.json` defines a fixed fictional baby ("Privatia Rigatoni", born 2026-03-14 at 6 lbs 8 oz) with sentinel feeding, sleep, and diaper values, and the marker strings used to detect them in a capture.
- `scripts/scan-synthetic-baby-data.sh`: reads a raw local capture (`.mitm` or `decode-traffic-*.json`), greps it for the profile's marker strings, and reports which fictional values appear in a request body, a response body, or a request URL, with the recipient host, path, method, and status. It emits no adjacent body content, so its report is safe to commit. The committed, sanitized network logs are not searched because their bodies are redacted.
- `tests/test-synthetic-baby-data.sh`: asserts the scan detects a transmission in a positive fixture (third-party and first-party hosts, numeric sentinel, response echo handled correctly) and reports none for a negative fixture.
- METHODOLOGY.md and ROADMAP.md: reproducible capture procedure and plan for the synthetic baby-data test. FINAL-REPORT.md: new "Synthetic baby-data transmission test" section and a Limits update; live captures across the 16 apps remain pending operator execution.

## 4.5.2 - 2026-08-14

### Added
- Full analytics and PII fanout scan: `scripts/scan-analytics-pii.sh` scans every committed network log, keeps unclassified hosts, and records every sent call with its data categories and assessment limit.
- `results/analytics-pii.schema.json` and `results/analytics-pii-20260803.json`: machine-readable fanout inventory for all 16 apps and 212 captured calls.
- Redaction slugs in newly built network logs. Each slug states what was removed and why, while method, host, path, status, count, and sizes remain.
- Synthetic baby-data transmission test: the automated injector (scripts/inject-synthetic-profile.py) enters fictional baby data while the capture proxy is live; the scan watches whether that data leaves the device. Manual entry is no longer required.

### Changed
- Static dark-pattern searching is no longer part of the current plan. Historical scan entries remain historical record only.
- FINAL-REPORT now bolds screen capture, screen-image upload, browser-log, contact-data, and authentication-token findings.
- Facebook findings now list possible data categories and state when the request body was not assessable because scrubbing removed its values.

## 4.5.1 - 2026-08-14

### Added
- Evidence retention hard rule: raw captures, decode files, and network logs are permanent evidence and must never be swept. `scripts/evidence-inventory.sh --check` fails the harness pre-flight when a committed network log is missing or a preserved capture is zero-byte, and warns on rotted decode files. AGENTS.md and METHODOLOGY.md document the rule; the old 90-day retention policy no longer applies.
- `evidence_source` field on every app row in `results/RESULTS-20260803.json`: `raw-replay` (8 apps with preserved captures replayed and mined) vs `session-summary` (8 legacy apps whose raw captures no longer exist). Tests assert the exact split; FINAL-REPORT Limits and README explain the depth difference.
- ROADMAP.md Sprint 5: legacy re-capture milestone for the eight session-summary apps (nurture-lock, nubo, pebbi, amila, baby-buddy, baby-daybook, baby-plus, mimilog), including the version-drift caveat and the success criterion of full raw-replay parity.

### Fixed
- Restored `results/network-log-nurture-lock.json` after a zero-flow replay of an empty recovered capture had overwritten the committed artifact on disk. The committed two-flow revenuecat entry is intact.

## 4.5.0 - 2026-08-14

### Added
- `scripts/build-network-logs.sh`: builds each committed `results/network-log-*.json` directly from the raw `.mitm` capture. Flow rows gain `count`, `origin` (`app` / `device` / `session`), request and response sizes, content types, JSON body keys (names only), and header-flag names (names only). The script removes query strings, replaces token-like path segments with `[REDACTED]`, and never emits body values.
- `results/network-log.schema.json`: documents the new optional flow properties (`count`, `request`, `response`) and the three-way `origin` field.

### Changed
- `results/RESULTS-20260803.json`: Nanit and Pregnancy+ reclassified from `minor` to `major` after the full launch captures exposed additional SDK families (Nanit: Microsoft Clarity, Localytics, Cordial, Coralogix; Pregnancy+: Microsoft Clarity, Facebook, Adapty with install attribution, OneSignal, first-party Philips APIs). Pixy's offline test now reflects only what the raw capture holds (three Facebook Graph bootstrap flows; the earlier Firebase Installations entry is not reproduced by the preserved `.mitm`). What to Expect and wave-1 offline counts align with the raw captures.
- `FINAL-REPORT.md` and `README.md`: wave-1 blocks and summary rows updated to the enriched capture evidence (BabyCenter 35 flows across nine SDK families; BellyBloom 53 flows including TikTok Pangle; Nanit and Pregnancy+ `🚫` at 95%).

## 4.4.0 - 2026-08-14

### Added
- `FINAL-REPORT.md`: granular test results per app. Every captured call appears in a Service | Data shared | Call/Log table with per-app capture metadata and a confidence explanation for each verdict. Claim quotes are hyperlinked to the source listing where the package is verified.
- Historical 4.4.0 roadmap entry: operator-integrated consent-flow testing. A fictional baby profile (name, birth date, weight, feeding and sleep logs) was entered by hand while the app ran through the capture proxy. The current plan keeps the fictional data transmission check and removes consent-pressure searching.

### Removed
- Historical 4.4.0 removal: `scripts/detect-dark-patterns.sh`, `tests/test-dark-patterns.sh`, `results/dark-patterns.schema.json`, and all `results/dark-patterns-*.json` artifacts were deleted. Static heuristics gave false signals (the word "timer" is also Danish for "hours") and cannot see runtime behavior. 4.5.2 removes the remaining active roadmap wording.
- `results/product-metadata.json`: `dark_patterns_*` fields removed.
- `.github/workflows/test.yml` and `AGENTS.md`: dark-pattern script, schema, and unit-test checks removed from the pipeline.

### Changed
- `FINAL-REPORT.md`: "Proprietary apps we tested" renamed to "Granular Test results"; dark-pattern scan section replaced by the roadmap.
- `README.md`, `METHODOLOGY.md`, `CONTRIBUTING.md`, `CANON-SUMMARY.md`, `TESTING-PHASES.md`: dark-pattern references updated to the paused/archived status.

## 4.3.0 - 2026-08-14

### Added
- Wave 1 burst tests: BabyCenter, BellyBloom, Nanit, Pregnancy+, and What to Expect. All five keep no traffic on the device; none make a privacy promise, so each result is "No claim" with a privacy mark from the launch capture.
- `RESULTS-20260803.json` and `FINAL-REPORT.md`: 16-app classification. Wave-1 verdicts: BabyCenter major (AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, Firebase), BellyBloom major (Adjust, DoubleClick, Facebook, Firebase), What to Expect major (AppsFlyer, Microsoft Clarity, Scorecard Research, Firebase), Nanit minor (Firebase plus the Nanit API), Pregnancy+ minor (Firebase only).
- `results/dark-patterns-{babycenter,bellybloom,nanit,pregnancyplus,whattoexpect}.json`: dark-pattern scans of the five wave-1 APKs.
- `results/network-log-{babycenter,bellybloom,nanit,pregnancyplus,whattoexpect}.json`: sanitized network logs for the five wave-1 apps.
- Regression tests: `test-results-artifacts.sh` asserts the 16-app set, exact `privacy_class` mapping, report emoji/class agreement, and network-log coverage.
- Regression tests: `test-decode-traffic.sh` Test 20 (wave-1 tracker domains: appsflyersdk.com, clarity.ms, scorecardresearch.com).

### Changed
- `README.md` and `FINAL-REPORT.md`: results tables extended to all 16 apps; "Popular Google Play apps - next wave" became the tested Wave 1 section with per-app evidence blocks.
- `.github/workflows/test.yml`: test matrix and verification loop extended from 11 to 16 apps (proxy ports 8091-8095).
- `APK_PRIVACY_TEST_HARNESS.md`: Wave 1 target table with package names and burst-test slugs.
- BellyBloom 1.0.9 requires Android 12L (API 32); the tested build is 1.0.8, which shares the same package signature. Coverage limit documented in FINAL-REPORT.md.

## 4.2.0 - 2026-08-12

### Added
- `RESULTS-20260803.json` and `FINAL-REPORT.md`: 11-app classification with `privacy_class` (pass/minor/major) covering Amila, Baby Daybook, Baby+, MimiLog, Nara, Heartful Baby, and Pixy on top of the original four.
- `FINAL-REPORT.md`: Class column with 💖/❕/🚫 result key; FOSS self-hosted section; "Popular Google Play apps - next wave" table (BabyCenter, Nanit, What to Expect, Pregnancy+, BellyBloom) with Play Store data-safety statements and verified package names.
- Regression tests: `test-results-artifacts.sh` asserts the 11-app set, exact `privacy_class` mapping, report emoji/class agreement, and that every reported destination appears in the matching sanitized network log.
- Regression tests: `test-decode-traffic.sh` Test 18 (wave-1 filter hosts reject common-word labels such as "lite" and "view") and Test 19 (Amila `com.amila.parenting` attributes `amila.example.com`).

### Changed
- `README.md`: tested-app and results tables extended to all 11 apps; result links now point to `FINAL-REPORT.md`.
- `results/network-log.schema.json`: flow `status` is now `oneOf` integer or the string `"unknown"` (was unconstrained).
- `scripts/decode-traffic.sh`: explicit filter hosts for the five wave-1 packages (babycenter, nanit, whattoexpect, pregnancyplus, bellybloom) and for corrected Amila/BabyTrack package names; the last-segment fallback can no longer misattribute common-word labels.
- `scripts/run-tests.sh`: DEFAULT_APPS aligned to the 11 classified apps with corrected names (Wachanga/BabyTrack out of scope); summary fallback fails loud (exit code 1) instead of reporting SUCCESS with empty data; `static_scan` no longer writes fabricated `trackers_found: 0` when no scan ran.
- `scripts/detect-dark-patterns.sh`: unzip is now required only for APK-file input, not directory scans.
- `.github/workflows/test.yml`: test-matrix and summary aligned to the 11 classified apps; banned-vocabulary scan now covers `localonly/candidates.md`; strict-mode schema check writes to `/tmp` instead of the repo root.
- `results/RESULTS-20260803.md`: marked superseded in favor of `FINAL-REPORT.md`.

## 4.1.0 - 2026-08-12

### Added
- Regression test: `test-decode-traffic.sh` now asserts the decoder classifies SDK hosts (googleapis.com, etc.) as trackers, locking in shared-tracker detection.
- Regression tests: `test-dark-patterns.sh` Test 14 (0dp ConstraintLayout not a hidden-consent false positive) and Test 15 (benign "timer" string not a pressure tactic).

### Changed
- `.gitignore`: `prompts/` is now ignored (local-only working material); tracked `prompts/` removed from the tree.

### Fixed
- `scripts/har_dump.py`: `startedDateTime` now emitted in UTC with an explicit timezone offset (was local time, ambiguous in HAR and across runs).
- `scripts/har_dump.py`: guarded against a missing request timestamp to avoid a crash on malformed flows.
- `scripts/decode-traffic.sh`: classify major SDK hosts (googleapis.com, firebaseio.com, crashlytics.com, fbcdn.net, gstatic.com, google.com) as trackers so `compare-apps.sh` shared-tracker detection works.
- `scripts/decode-traffic.sh`: package-name validation now rejects path separators and newlines (traversal/injection guard).
- `scripts/detect-dark-patterns.sh`: exclude `0dp` ConstraintLayout match-constraints from the hidden-consent small-width heuristic (systematic false positive).
- `scripts/detect-dark-patterns.sh`: pressure-tactic regex anchored with word boundaries and bare `timer` removed (Danish "hours" / feed-timer false positives).
- `scripts/compare-apps.sh`: defensive `max(0, …)` floor on per-app body-size sums.

## 4.0.0 - Sprint 4 - Complete

### Added
- Burst 5 re-test: objection android sslpinning disable + frida-server 16.0.11 resolved TLS handshake failures for plain-Java apps; Nara (React Native) remained INCONCLUSIVE due to SoLoader incompatibility
- FINAL-REPORT.md: standardized Burst sections to Nurture Lock template (app, package, version, claim, verdict, static analysis, dynamic capture, confidence-annotated verdict)
- FINAL-REPORT.md: updated Burst 5 verdicts to INCONCLUSIVE (70% confidence), matching executive summary
- localonly/bursts/burst-5-config.sh: added nara to BURST_APPS (was missing)
- Burst 5 NSC audit: Nara's NSC is empty `<network-security-config/>`; no `com.facebook.ads` in any app; rejections are app-level OkHttp CertificatePinner or documented Google-host mitmproxy #5260 anomaly
- Aging gap documentation: eBPF impossible on API 28 AVD (CONFIG_UPROBES not set, kernel 4.4); viable only via AVD upgrade to API 34 + ecapture, with baseline discontinuity

### Changed
- CHANGELOG.md: Sprint 4 status updated from In Progress → Complete
- README.md: What is next section updated; Sprint 4 row closed

### Fixed
- FINAL-REPORT.md: em-dash ` — ` → ` - ` per AGENTS.md step 4
- FINAL-REPORT.md: INCONCLUSIVE verdicts annotated with (70% confidence) per executive summary
- Burst 5 config: nara added back to BURST_APPS
- Objection sslpinning disable: #776 `check$okhttp` fragility documented; httptoolkit universal unpinning script as fallback
- Final report synthesizing all burst findings
- Methodology publication and tool open-sourcing

## 3.3.0 - 2026-08-05

### Added
- Owlet ecosystem testing: Owlet Sock and Owlet Cam added to candidates.md with MDR/RED regime, verified CVE data from NVD, and test plan.
- `scripts/detect-dark-patterns.sh` v1: Static dark pattern detection in APK resources.
- `results/dark-patterns.schema.json`: Schema for dark pattern detection output.
- `tests/test-dark-patterns.sh`: 7 unit tests for the dark pattern detector.
- `scripts/compare-apps.sh` v1: Cross-app data comparison for decoded traffic JSON files.
- `results/comparison.schema.json`: Schema for cross-app comparison output.
- `tests/test-compare-apps.sh`: 7 unit tests for the comparison script.
- Dark pattern detection methodology documented in METHODOLOGY.md.
- `localonly/skeletons/owlet-sock.json` and `owlet-cam.json`: Skeleton entries for wearable devices.
- `localonly/entries/owlet-test-plan.md`: Documented test plan for Owlet ecosystem.

### Changed
- `decode-traffic.sh` FILTER_HOST now includes Owlet apps (`com.owletcare.sock`, `com.owletcare.cam`).
- `results/product-metadata.json` now includes entries for Owlet Sock and Owlet Cam with retention, CVE, and regime data.
- `localonly/candidates.md` per-product config table updated with verified Owlet CVE data.

### Fixed
- Corrected CVE mapping: CVE-2023-6321 and CVE-2023-6323 both affect Owlet Cam, not Owlet Sock.

## 3.2.0 - 2026-08-05

### Added
- Schema enforcement gate in CI. `decode-traffic.sh` now supports `DECODE_TRAFFIC_STRICT=1` mode.
- Strict mode exits with code 1 when output does not conform to `results/decode-traffic.schema.json`.
- CI unit-tests job now runs strict-mode validation on every build.
- `SCHEMA_FILE` environment variable overrides the default schema path.
- Two new unit tests for strict mode (valid pass, invalid fail).
- Tier 1 apps added to harness: BabyTrack, Amila, Wachanga.

### Changed
- decode-traffic.sh schema validation now captures exit code correctly. It used to mask failures.
- decode-traffic.sh schema file path is now overridable via `SCHEMA_FILE` env var.
- `run-tests.sh` app list delimiter changed from space to semicolon. This fixes word-splitting on app names with spaces.

### Fixed
- `run-tests.sh` no longer breaks multi-word app names (e.g., "Baby Buddy", "Nurture Lock") due to bash word splitting.
- `decode-traffic.sh` now uses `printf` instead of `echo` for JSON output to avoid flag injection.
- `decode-traffic.sh` FILTER_HOST now includes Tier 1 apps (BabyTrack, Amila, Wachanga).
- `tests/test-decode-traffic.sh` cleanup trap now removes all test fixtures.
- `tests/test-decode-traffic.sh` Tests 12 and 13 now use distinct output files.
- `tests/test-decode-traffic.sh` Tests 12 and 13 now capture stderr for debugging.
- CI `unit-tests` job now has `timeout-minutes: 10`.
- CI schema validation gate now pins `jsonschema==4.26.0`.
- CI schema validation gate now writes to workspace instead of `/tmp`.
- CI now validates `localonly/skeletons/*.json` are valid JSON.
- CI `generate-summary` now reads app list dynamically from `test-matrix` output.
- CI `download-artifact` now uses `if-no-files-found: ignore`.
- CI `canary.yml` now actually runs unit tests and harness dry-run.
- `run-tests.sh` now detects and converts deprecated space-delimited `APK_HARNESS_APPS`.

## 3.1.2 - 2026-08-05

### Added
- `results/product-metadata.json` - stores product metadata outside the code.
- `results/product-metadata.schema.json` - schema for the metadata file.
- `tests/test-decode-traffic.sh` - 11 unit tests for the decoder.
- `tests/fixtures/test-capture.har` - test data for unit tests.
- CI now runs unit tests and checks product-metadata.json.
- Canary checks now validate product-metadata.json and its schema.
- decode-traffic.sh now checks that the output directory exists before writing.

### Changed
- decode-traffic.sh loads product metadata from a config file. It used to be hardcoded.
- Schema validation in decode-traffic.sh now uses an environment variable. It used to use shell string expansion.
- Python inline script in decode-traffic.sh now uses a relative path. It used to use `__file__`.
- Removed ROADMAP-PROMPT-v2.md and v3.md from git. Added them to .gitignore.
- Added a single `roadmap.md` file for the project roadmap.

### Fixed
- Python `__file__` error when running inline scripts.
- Single quote injection risk in schema file paths.
- Unit test cleanup now uses `trap EXIT` for reliability.
- Test HAR now includes matching flows so the decoder runs the full path.
- Missing config file now falls back to default values.
- Corrupted config file now falls back to default values.

## 3.1.1 - 2026-08-03

### Added
- Part 8.5: Per-product retention, security EOL/CVE, and device identity tracking.
- `scripts/decode-traffic.sh` v2: Decodes HAR captures into structured JSON with product metadata.
- `results/decode-traffic.schema.json` v2: Schema for decoded traffic with retention_schedule, security_eol, cve_list, regulatory_regime.
- `localonly/candidates.md`: 16+ discovered apps in Tier 1-3, wearable/IoT, and out-of-scope lists.
- `localonly/skeletons/`: Skeleton test entries for Tier 1-2 apps.
- `localonly/entries/TIMESTAMP_LOG.md`: Audit log entry template.
- `--live` flag in `run-tests.sh`: Enables live traffic capture mode.
- Tool version recording in `run-tests.sh`: Records mitmproxy, adb, jadx, docker, objection versions.
- Port allocation 8080-8095: Supports up to 16 apps with unique PROXY_PORT per app.
- CI matrix expanded to 11 apps: nurturelock, nubo, pebbi, babybuddy, babytrack, amila, wachanga, nighp, milli, baby-connect, snugl.
- CI regression check: Part header count >= 11.

### Changed
- Removed standalone Part 5.5; merged FOSS paths into Parts 1-3 with **[FOSS]** tags.
- CI babybuddy check: changed from "Part 5.5" grep to **[FOSS]** tag grep.
- `run-tests.sh`: App list configurable via `APK_HARNESS_APPS` env var.

### Fixed
- `validate_input` now uses strict mode for package names and app types. It uses relaxed mode for app names.
- Part 7 cleanup uses `adb root || true` with post-removal checks. Uses `set -uo pipefail` without `-e`.
- Part 7 shred comment now says "if available".
- EXODUS_IMAGE is no longer pinned. EXODUS_DIGEST is optional.
- `results/schema.json` name field is now a free-form string.
- `test_foss_app` now uses case-based repo_url matching.
- Proxy config now reads back after setting. Marks PROXY_NOT_SET if values do not match.
- mitmproxy readiness now polls the web port with curl for 15 seconds.
- ShellCheck now passes on run-tests.sh.

## 3.1.0 - 2026-08-03

### Added
- Nurture Lock dynamic test - caught RevenueCat API call on launch.
- Nurture Lock static analysis - found 8 tracking libraries.
- Nubo package name found - `com.clicksie.nuboapp`.
- Nubo dynamic test - Firebase sends session data, screen views, and onboarding tracking on first launch.
- Pebbi dynamic test - Firebase and version-policy checks every ~30 seconds.
- Pebbi static analysis - found Firebase, AdServices, Install Referrer, RevenueCat, PairIP LicenseCheck.
- APK downloads through apkeep from APKPure.
- System certificate install through `-writable-system` emulator flag.

### Changed
- Nurture Lock verdict - UNTESTED to FAIL. The "100% offline" claim is false.
- Nubo verdict - UNTESTED to FAIL. The "local-first" claim is false.
- Pebbi verdict - UNTESTED to FAIL. Expected for a positive control.
- Baby Buddy dynamic test now complete. Confidence 60% to 100%.
- All "we" changed to "I" in public docs.

### Anomaly
- Nubo Firebase Analytics batches had `com.pebbi.android` data and Pebbi's Firebase project ID. May be a shared library or test artifact.

### Corrected
- `.gitignore` now excludes apks/, decompiled/, capture files, runtime logs, and localonly/.
- Capture files and runtime logs removed from git tracking.
- CI checks now verify results JSON structure, schema match, version agreement, and script syntax.
- Secret scan (gitleaks) added to CI.
- RESULTS-20260803.md - fixed typos, redacted Firebase IDs and project identifiers.
- METHODOLOGY.md - rewritten in first person. Corrected consent claims and tooling claims.
- ARTICLE.md - added author and date. Fixed dead links and tooling claims.
- README.md - updated tool versions. Added emulator setup. Corrected exodus and covert-channel claims.
- Harness version now 3.1.0 across all files.
- `scripts/run-tests.sh` hardened - real package names, MITM_PID export, idempotent cleanup, work-dir opt-out, adb timeouts, split-APK dedup, JSON output with jq, honest observation window, flow export with retry, launch checks, `--check` dry-run mode.
- `results/RESULTS-20260803.json` added - machine-readable results.

## 3.0.0-loop3 - 2026-08-03

### Added
- Baby Buddy as fourth test target.
- Part 5.5 - FOSS testing with browser, Android client, and source audit paths.
- Part 9 - privacy engineering.
- Part 10 - SRE practices.
- `scripts/run-tests.sh` - automated test runs.
- `results/schema.json` - machine-readable results schema.
- `results/TEMPLATE.md` - results template.
- GitHub Actions workflows for CI and weekly canary tests.
- Article template for publication.

### Changed
- Hardened agent plan with formal DAG, JSON schema, and 15 enforced rules.
- Added consensus for critical verdicts.
- Added Byzantine fault tolerance for subagent failures.
- Added prompt injection scan.
- Pinned all tool versions.
- Added trap handlers for SIGINT and SIGTERM cleanup.
- Added input validation to stop injection.

### Fixed
- 226 findings from 4 adversarial review loops.
- Added missing tool checks for jq and git.
- Fixed race conditions in process cleanup.
- Fixed false positives in grep patterns.
- Added repository cleanup after audit.

## 2.0.0-loop1 - 2026-08-03

### Added
- Environment variable configuration.
- Error handling with `set -euo pipefail`.
- Smoke tests for all tools.
- Working directory structure with artifacts.
- Part 7 - cleanup and teardown.
- Part 8 - audit log with hash chain.
- Static scan with pinned Docker image.
- Dynamic capture with mitmproxy.
- Covert channel analysis for BLE, NFC, and ultrasound.

## 1.0.0 - Original

### Added
- Initial test harness document.
- Three test targets - Nurture Lock, Nubo, Pebbi.
- Manual test procedure for macOS.
- Agent plan for subagent execution.
