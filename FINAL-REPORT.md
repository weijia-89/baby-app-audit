# Final Report - Which Baby Apps Keep Their Privacy Promises

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-10-10
**Harness version:** 3.2.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

This test covers 16 baby and parenting apps.
Baby Buddy and MimiLog matched the sentence under test.
Nubo sent an install register from the app.
Four promise rows are Not measured.
The capture did not test that sentence.
Nurture Lock is Inconclusive.
The RevenueCat call has no package header.

Host, path, status, count, and sizes live in the sanitized network logs. This report keeps the verdict and what the call is for.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open source | PASS | 💖 | 100% | Django web: no app-originated traffic. Android companion login photos are not the PASS |
| MimiLog | "Fully offline" | PASS | 💖 | 90% | Package declares no `INTERNET`. One unattributed measurement call in the kept launch capture. 2026-10-04: Play license gate held the app; it cannot connect |
| Amila | No claim | No claim | ❕ | 90% | Registers the install with Google; settings, logging, and measurement calls (2026-08-25 recapture) |
| Baby+ | "AdID not auto-enabled" | Not measured | 🚫 | 95% | Facebook and Google ads on the finished-profile replay. The parent name PUT was seen once. The advertising-id setting was not measured |
| Heartful Baby | "HIPAA-compliant" | Not measured | ❕ | 90% | One Firebase usage log at launch. The HIPAA program was not reviewed |
| Baby Daybook | "AdID not auto-enabled" | Not measured | 🚫 | 90% | Three Firebase calls are origin app. RevenueCat and Sentry in that window are origin session. The advertising-id setting was not measured |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | Nine Facebook calls at launch, plus a Google crash report |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | First launch sends an install register, crash settings, and push registers to Google |
| Nurture Lock | "100% offline" | Inconclusive | 🚫 | 95% | RevenueCat in the 2026-10-04 log is origin session, not the app. Static analysis reports eight tracking libraries in the APK |
| Pebbi | No claim (control) | No claim | 🚫 | 100% | 2026-10-04: Firebase install register is origin app. The `app.pebbi.co` call is origin session. Profile not saved. 2026-10-10: profile saved; mitm had no Pebbi flows; tcpdump saw `app.pebbi.co`; TLS unread |
| Pixy | "Bank-level encryption" | Not measured | 🚫 | 90% | Three Facebook calls at launch. Request bodies were empty. Encryption was not measured |
| BabyCenter | No claim | No claim | 🚫 | 95% | Clarity tag response lists screenCapture. The collect body was scrubbed. Ads and attribution calls are in the window |
| BellyBloom | No claim | No claim | 🚫 | 90% | Advertising ID, usage, and which advert brought you, to many companies |
| Nanit | No claim | No claim | 🚫 | 95% | A Clarity collect call is in the window. The body was scrubbed. Coralogix gets a browser log. Cordial gets contacts |
| Pregnancy+ | No claim | No claim | 🚫 | 95% | A Clarity collect call is in the window. The body was scrubbed. Ads, usage, consent, and attribution calls are in the window |
| What to Expect | No claim | No claim | 🚫 | 90% | A Clarity collect call is in the window. No upload-asset path. The body was scrubbed. Ads, usage, and consent calls are in the window |

Result key:

- **PASS** means the capture matched the claim.
- **FAIL** means the log attributes a call to the app.
  That call breaks the claim.
- **No claim** means the listing states no promise.
  The privacy mark still shows the window.
- **Not measured** means the capture did not test the printed sentence.
- **Inconclusive** means the call is in the window.
  The log does not name the app (`origin` session).
  Or the body was not read.
  Or the Firebase silence checks were not met.

Privacy mark:

- **💖** means the tested session matched the claim.
- **❕** means the window showed phone-home traffic, and the capture did not show data that identifies a person.
- **🚫** means the window showed identifying data or heavy collection.

A negative marker scan is not proof that the value never leaves the phone.

## How to read an app block

Each app has Claim, Result, Confidence, Capture, a short service table, and a link to the network log.

- **Service** - who receives the call.
- **What we saw** - what kind of data, in plain words. "We saw" means it was in the capture. "Likely" means the destination fits that job, but we scrubbed login tokens from the bodies.

Three names used below:

- **Advertising ID** - the phone number that ad companies use to say "same phone". You can reset it in Android settings.
- **Install ID** - a random number the app makes once at install.
- **Usage log** - screens you open and buttons you press.

To check a host, path, or status code, open the network log for that app.

## Analytics and PII fanout

The fanout scan covers all 16 committed network logs: 503 calls, 19 vendor or host groups. Machine output: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json).

**High-risk findings:**

- **Microsoft Clarity:** tag responses list `screenCapture`.
  Collect calls were sent.
  Request bodies were scrubbed.
  No log path contains `upload-asset`.
  Pixels were not read.
- **Sentry in Heartful Baby:** decompiled classes include Sentry `rrweb`. No Sentry host appeared in the preserved capture. That is static capability, not proof of a live send.

### Facebook

BellyBloom, Pregnancy+, Nara, and Pixy contacted Facebook. Scrubbing removed request bodies. The table states what those SDK calls can carry, not that every field was in every request.

| Data category | In this capture |
| --- | --- |
| App activity and events | Call sent. Body not assessable |
| Device, app, and ad identifiers | Call sent. Exact fields not assessable |
| Health, contacts, photos, precise location | Not seen in scrubbed values. That is not proof of absence |

## Synthetic baby data

Launch captures had no entered feeding, sleep, or diaper values. This test adds them. It does not replace the launch verdicts.

We enter one fictional baby (Privatia Rigatoni). Markers are in `results/synthetic-baby-profile.json`. We type them while the proxy is live. Short lists keep the value that sticks. The scan greps the raw local capture, not the redacted network logs. A `no_transmission_detected` row means the markers were not observed in that capture window under this scan. It does not prove the app never sends the value. Method: `METHODOLOGY.md`. How much of each app was opened is the injection table in `ROADMAP.md` ("Per-app injection flows"). The 2026-08-18 coverage snapshot is older.

| App | Inject window | Marker result | Notes |
| --- | --- | --- | --- |
| Baby+ | 2026-08-16 and 2026-08-21 About You | `transmission_observed` | Parent name in a request PUT to `appserver.health-and-parenting.com` |
| Baby+ | 2026-08-25 finished-profile recapture | `no_transmission_detected` | Install register POST to the Philips server plus Facebook and Google ad hosts. The name did not appear in this capture |
| Baby+ | 2026-08-19 Girl + DONE, then upgrade | `no_transmission_detected` | Name only in a maker response. Home still blocked by force-upgrade |
| Amila | 2026-08-17 name save | `no_transmission_detected` | Name stayed on the home screen |
| Amila | 2026-08-25 live recapture | `no_transmission_detected` | Name **Privatia Rigatoni** on home. No name in the raw capture. Not Firebase-silence |
| MimiLog | 2026-08-17 local save | `no_transmission_detected` | No `INTERNET` permission. Detail in footnotes |
| Nubo | 2026-08-18 finished timers + note | `no_transmission_detected` | Formula stayed **15**. Whole-emulator proxy. Not Firebase-silence |
| Nubo | 2026-08-24 Backup Now | not a marker scan | Last backup `08/24/2026 18:49:05` after Google Drive Continue. FAIL mark unchanged |
| Baby Daybook | 2026-08-17 | no inject | Pairip native crash. Environment blocker, not a privacy verdict |
| Pebbi | 2026-08-17 | `no_transmission_detected` on an 8-flow walk | Profile not saved. Pairip CLOSE on cold start is an environment blocker |
| Nurture Lock | 2026-08-17 | no inject | Pairip CLOSE only. Environment blocker |
| Baby Daybook | 2026-10-04 full profile inject | `no_transmission_detected` | Name saved on-device (local SQLite row); home shows **Privatia Rigatoni**. Numeric marker hits were low-confidence coincidences in Google auth replies |
| Nurture Lock | 2026-10-04 onboarding name | `no_transmission_detected` | Home shows **Privatia Rigatoni**. RevenueCat is in the window. Log origin is session. No name marker in the capture |
| Pebbi | 2026-10-04 profile form, two windows | `no_transmission_detected` | Name typed. The date field took no input. Complete Setup never fired. Profile not saved |
| Pebbi | 2026-10-10 saved profile | body not in the capture | Profile saved. Mitm: 8 flows, Google and Play only. tcpdump saw `app.pebbi.co`. We did not read the TLS |
| MimiLog | 2026-10-04 Play-gated window | `no_transmission_detected` | App has no `INTERNET` permission; capture holds Play Store and Google hosts only |

## Proprietary apps - long report

These five Play Store apps make no privacy promise. Result is "No claim". The privacy mark is from the launch capture.

We acquired the APKs from a mirror and ran burst tests on an API 29 emulator. BellyBloom 1.0.9 needs Android 12L, so we tested 1.0.8 (same package signature).

| App | Package | Play Store signal | Data-safety statement |
| --- | --- | --- | --- |
| [BabyCenter](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) | `com.babycenter.pregnancytracker` | 4.9 stars, 1.54M reviews, 10M+ downloads, #3 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Nanit](https://play.google.com/store/apps/details?id=com.nanit.baby) | `com.nanit.baby` | 3.9 stars, 10.6K reviews, 500K+ downloads, #5 top grossing parenting | Shares Personal info, App activity, and App info and performance. No privacy promise found. |
| [What to Expect](https://play.google.com/store/apps/details?id=com.wte.view) | `com.wte.view` | 4.9 stars, 121K reviews, 5M+ downloads, #7 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Pregnancy+](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) | `com.hp.pregnancy.lite` | 4.8 stars, 3.64M reviews, 50M+ downloads, #10 top free parenting | Shares Location and Device or other IDs. No privacy promise found. |
| [BellyBloom](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) | `com.bellyBloom.pregnancy.tracker` | 4.6 stars, 988 reviews, 1M+ downloads | Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted. |

### BabyCenter

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker)
- **Result:** No claim
- **Confidence:** 95%. Thirty-five calls at launch to at least eight companies. Advertising-ID permission is in the package. Message bodies were not readable.
- **Capture:** 2026-08-14, launch window, 35 calls.

| Service | What we saw |
| --- | --- |
| AppsFlyer | Which advert brought you, and an AppsFlyer ID for this phone |
| Amazon (ads) | Advertising ID and opt-out state. Reply echoed the ID |
| Localytics | Usage log, likely tied to a phone ID |
| Vungle (ads) | Likely ad-measurement numbers |
| Microsoft (Clarity) | Tag response lists `screenCapture` and `webViewCapture`. Collect POST body was scrubbed. Log origin is session |
| Scorecard Research | Repeat "this phone is here" pings |
| Google (ads) | Ad rules and permission settings |
| Google (Play services) | Location analytics from system software, not the app UI |
| OneTrust | Consent banner download. We saw no answer sent back |
| BabyCenter (Snowplow and own) | In-family usage log, country, and app settings |

- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker)
- **Result:** No claim
- **Confidence:** 90%. Fifty-three calls at launch, almost all ads and tracking. Version 1.0.8. One launch window.
- **Capture:** 2026-08-14, launch window, 53 calls.
- **Later launch:** Pairip CLOSE on this emulator. Environment blocker. The 🚫 mark is from 2026-08-14.

| Service | What we saw |
| --- | --- |
| TikTok (Pangle ads) | Likely advertising ID, phone details, ad rules, and playable ads |
| Adjust | Session and which advert brought you |
| Facebook | App-activity and ad-network sync. Bodies scrubbed |
| InMobi (ads) | Ad rules |
| Mixpanel | Usage log |
| Google (ads and Funding Choices) | Ad files, ad rules, and consent answers |
| Google (Firebase) | Install ID and tokens. Settings and crash rules |

- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.nanit.baby)
- **Result:** No claim
- **Confidence:** 95%. Twelve calls at launch. We did not sign in.
- **Capture:** 2026-08-14, launch window, 12 calls.

| Service | What we saw |
| --- | --- |
| Google (Firebase) | Install ID and tokens. Settings and crash rules |
| Microsoft (Clarity) | Collect call in the window. Body was scrubbed. Pixels were not read |
| Localytics | Usage log, likely tied to a phone ID |
| Cordial | Contact data for email. Auth reply carried a token |
| Coralogix | App speed and errors, plus one 15.6 KB browser log |
| Nanit (own) | Plans (200) and cards (401, not signed in) |

- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite)
- **Result:** No claim
- **Confidence:** 95%. Forty-two calls at launch. Machine consent with sensitivity off. A person can see more.
- **Capture:** 2026-08-14, launch window, 42 calls.

| Service | What we saw |
| --- | --- |
| Microsoft (Clarity) | Collect call in the window. Body was scrubbed. Pixels were not read |
| Facebook | App-activity event. Body scrubbed |
| Adapty | Subscription state, attribution, and usage, stored on Amazon |
| OneSignal | Push rules. A token if you allow push |
| Philips (own) | Maker account server |
| Google (Firebase) | Install ID, settings, usage logs |

- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.wte.view)
- **Result:** No claim
- **Confidence:** 90%. Twenty-five calls at launch. Advertising-ID permission is in the package.
- **Capture:** 2026-08-14, launch window, 25 calls.

| Service | What we saw |
| --- | --- |
| AppsFlyer | Start, attribution, install date and status |
| Microsoft (Clarity) | Collect call in the window. No `upload-asset` path. Body was scrubbed. Pixels were not read |
| Mixpanel | Usage log |
| Cordial | Usage events for email |
| Scorecard Research | "This phone is here" ping |
| What to Expect (Snowplow) | In-family usage log |
| Google (Firebase) | Install ID and settings |
| OneTrust | Consent banner download. We saw no answer sent back |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

### Heartful Baby

- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Result:** Not measured
- **Confidence:** 90%.
  One Firebase usage log (6,671 bytes) is in the launch window.
  The HIPAA program was not reviewed.
- **Capture:** 2026-08-12, launch window, 5 calls (four were connectivity checks with no user data).

| Service | What we saw |
| --- | --- |
| Google (Firebase) | Usage log (one 6,671-byte message) |

- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Nara

- **Claim:** "Complete privacy" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Facebook phones home on every launch. Payloads not readable.
- **Capture:** 2026-08-12, launch window, 10 calls.

| Service | What we saw |
| --- | --- |
| Facebook | SDK settings and model files. Empty request bodies in this capture |
| Google (Crashlytics) | Crash report (~60 KB) plus phone details |

- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Pixy

- **Claim:** "Bank-level encryption" (Google Play listing)
- **Result:** Not measured
- **Confidence:** 90%. Three Facebook calls are in the preserved capture.
  Request bodies were empty.
  Encryption was not measured.
- **Capture:** 2026-08-12, launch window, 3 calls.

| Service | What we saw |
| --- | --- |
| Facebook | SDK settings and setup files. Empty request bodies in this capture |

- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

Baby Buddy is the only open-source app in this test.

### Baby Buddy

- **Claim:** Open source - [github.com/babybuddy/babybuddy](https://github.com/babybuddy/babybuddy)
- **Result:** PASS
- **Confidence:** 100%. The app made zero outbound calls. One `curl` to httpbin.org in the capture is a probe from the test environment, not the app. Code is public.
- **Capture:** 2026-08-03, web session, 0 app-originated calls.
- **Android companion (2026-08-23):** first-launch photos of `eu.pkgsoftware.babybuddywidgets` v2.6.4. Login form only. We did not connect a server. PASS still rests on the web session.

| Service | What we saw |
| --- | --- |
| httpbin.org (curl probe) | Environment check. No app data |

## Proprietary apps - short report

### Amila

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.amila.parenting)
- **Result:** No claim
- **Confidence:** 90%. Thirteen flows on the 2026-08-25 recapture. Nothing showed data that identifies you, so the mark is ❕. `privacy_class` stays minor.
- **Capture:** 2026-08-25 live inject + proxy, 13 flows. Evidence source promoted to `raw-replay`.

| Service | What we saw |
| --- | --- |
| Google (Firebase) | Install register, settings, logging, Crashlytics settings |
| Google (Measurement) | App Measurement config and batch posts |
| Google (Funding Choices) | Consent messages |

- **Network log:** [network-log-amila.json](results/network-log-amila.json)

### Baby+

- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** Not measured
- **Confidence:** 95%. Forty flows on the 2026-08-25 finished-profile recapture.
  Facebook Graph calls are in the capture.
  The APK carries the Facebook SDK (87 dex string hits).
  A first-party install register goes to the Philips server.
  The name did not leave the device in this capture.
  The kept 2026-08-21 capture saw that PUT once.
  The advertising-id setting was not measured.
- **Class change:** full-depth replay moved Baby+ from ❕ minor to 🚫 major, the same way Nanit and Pregnancy+ changed after their replays.
- **Capture:** 2026-08-25 live inject + proxy after a system-store CA reinstall, 40 flows. Evidence source promoted to `raw-replay`.
- **About Baby gender:** required. TalkBack has no Boy/Girl names. We selected Girl via the popup row, then DONE reached home. Session dumps: `ROADMAP.md`.

| Service | What we saw |
| --- | --- |
| Philips (own) | Install register: app ID, installation ID, locale, time zone |
| Facebook | Graph API calls |
| Google ads | DoubleClick, page ads, Ads services |
| Google / Firebase | Remote config fetch |

- **Network log:** [network-log-baby-plus.json](results/network-log-baby-plus.json)

### Baby Daybook

- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** Not measured
- **Confidence:** 90%. The 2026-10-04 log attributes three flows to the package.
  Those three are Firebase Installations, Remote Config, and the realtime stream.
  RevenueCat, Sentry, Firelog, and the push register are origin session.
  The package contains the Facebook SDK.
  The profile saved on-device (local SQLite).
  The marker scan found no name in traffic.
  The advertising-id setting was not measured.
- **Capture:** 2026-10-04, full onboarding to home with the profile, 132 flows. Evidence source promoted to `raw-replay`. Launch window: 2026-08-08, 8 flows.

| Service | What we saw |
| --- | --- |
| RevenueCat | Subscriber reads. Log origin is session |
| Google (Firebase) | Install register, remote config, and the realtime stream are origin app. Other Firebase calls in the window are origin session |
| Google (messages) | Push register |
| Sentry | One crash report envelope |
| Facebook | Graph call in the same window, not tagged to the app |

- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### MimiLog

- **Claim:** "Fully offline" - [Play listing](https://play.google.com/store/apps/details?id=com.mimiapp.mimilog)
- **Result:** PASS
- **Confidence:** 90%. The package declares no `INTERNET` permission (permission dump kept in `results/mimilog-test-20261004/artifacts/logs/`), so the app cannot open its own network connections. The kept launch capture holds one completed Google App Measurement call with no app package header, so the caller cannot be attributed from the capture alone. The synthetic scan found nothing.
- **Capture:** 2026-08-16, launch window, 1 flow. Evidence stays `session-summary`. The 2026-10-04 re-run passed the Pairip probe; with the audit proxy on, Play Store license auth failed (no signed-in Google account) and the capture held Play and Google hosts only.

| Service | What we saw |
| --- | --- |
| Google (Measurement) | One unattributed App Measurement call in the capture |

- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nubo

- **Claim:** "Local-first" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 95%. The preserved launch capture holds eleven flows. Firebase Installations was sent by the app itself, so usage data ties to an install ID. Crashlytics settings and push registers also appear.
- **Capture:** 2026-08-03, first launch. Replayed through the pipeline on 2026-08-25; evidence source promoted to `raw-replay`.
- **Later use:** the kept 2026-08-18 finished-use soak shows Google device traffic only. 2026-08-24 Backup Now finished after Google Drive Continue. That is cloud backup, not a change to the FAIL mark, and not Firebase-silence.

| Service | What we saw |
| --- | --- |
| Google (Firebase) | Install register sent by the app |
| Google (Crashlytics) | Crash-configuration rules |
| Google (messages) | Push and message registers |

- **Network log:** [network-log-nubo.json](results/network-log-nubo.json)

### Nurture Lock

- **Claim:** "100% offline" (Google Play listing)
- **Result:** Inconclusive
- **Confidence:** 95%.
  The RevenueCat subscriber calls in the 2026-10-04 log are origin session.
  The same window also lists Adapty, OneSignal, AppsFlyer, and Comscore.
  It also lists Clarity, Facebook, Google ads, Philips hosts, and Firebase.
  Those calls also have no app package header.
  Static analysis reports eight tracking libraries in the APK.
  The live calls do not name the app.
- **Capture:** 2026-10-04, full onboarding to home with the profile, 70 flows. Evidence source promoted to `raw-replay`. Launch window: 2026-08-03.

| Service | What we saw |
| --- | --- |
| RevenueCat | Subscriber reads. Log origin is session |
| Adapty | Subscription state in the window |
| OneSignal | Push rules in the window |
| AppsFlyer | Attribution settings in the window |
| Comscore (Scorecard) | "This phone is here" pings in the window |
| Microsoft (Clarity) | Collection endpoint in the window |
| Facebook | Graph destination in the window |
| Philips (own) | First-party usage endpoints in the window |
| Google (Firebase) | Install and crash settings in the window |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Pebbi

- **Claim:** No claim (control app)
- **Result:** No claim
- **Confidence:** 100%. The 2026-10-04 window holds 51 flows.
  Firebase Installations is origin app.
  The `app.pebbi.co` version-policy call is origin session.
  Crashlytics settings, RevenueCat, and Play traffic are in the same window.
  That day the date field took no input, so the profile did not save.
  Marker scan on that file: `no_transmission_detected`.
- **Capture:** 2026-10-04, 51 flows, `raw-replay`. This is the committed capture. Launch window: 2026-08-03. On 2026-10-10 the profile saved. 4.6.30 records 18:30 on the Play image. 4.6.31 records 22:25 on the later api29 inject. `pebbi-4.4.1-full.mitm` has 8 flows, all Google and Play. tcpdump saw DNS and TLS to `app.pebbi.co`. We did not read the TLS. The 51-flow file is still the one in RESULTS.

| Service | What we saw |
| --- | --- |
| Pebbi (own) | Version-policy call. Log origin is session |
| Google (Firebase) | Install register is origin app. Crash settings are in the window |
| RevenueCat | Subscription state in the window |
| Google (Play) | Store traffic in the same window |

- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

## Cross-app view

Nara and Nubo still fail the printed sentence.
Nara's window includes Facebook calls.
Nubo's install register is origin app.
Heartful Baby and Pixy are Not measured.
The HIPAA program and the encryption claim were not what the capture tested.

Four of the five long-report apps ship install and ad programs
(Facebook, Adjust, TikTok, or Google/Amazon).
Nanit's window includes a Clarity collect call and a Coralogix browser log.
Cordial contact calls are in that window too.
Play data-safety pages for all five say they share data.

## Limits

- Launch captures predate the injector. Re-captures enter the fictional profile. The synthetic table states whether those strings left the device.
- Captures are launch and early use. Later sessions can differ.
- We removed response bodies and header values because they can carry tokens. Logs keep method, host, path, status, count, and sizes. A scrubbed body is not proof that PII was absent.
- Evidence depth is not equal. Fourteen apps are `raw-replay` (Nubo and Baby+ promoted 2026-08-25; Baby Daybook, Nurture Lock, and Pebbi promoted 2026-10-04). Two are still `session-summary` in `results/RESULTS-20260803.json`: Baby Buddy and MimiLog.
- Baby Buddy is still `session-summary`. The PASS is the Django web session. The Android companion pictures are a login screen only. MimiLog is still `session-summary`. Changelog 4.6.31: the store reinstall waits on "Complete account setup / Review your account", and the package declares no `INTERNET`. The license dialog is an environment fact.
- Pairip blocked four apps until 2026-09-20, when a real Play Store made the license checks pass. We recaptured Baby Daybook, Nurture Lock, and Pebbi on 2026-10-04. Pebbi's 2026-10-10 save is a second window: the mitm file has no Pebbi flows, and we did not read the TLS to `app.pebbi.co`. MimiLog's window did not open.
- baby-track, cradle, and dymn-baby had no usable APK. No captures.

## Advice

**For parents:** Do not trust "offline" or "local-first". Baby Buddy made no app-originated calls. MimiLog's Firebase setup never completed, and a later save showed 0 system-proxy flows.

**For developers:** If you say "offline", remove analytics and attribution. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable.

## Footnotes

[^mimilog-play]: MimiLog 2026-08-17. Settings has units, theme, language, and notifications. No sign-in. Package asks Play license check and does not declare `INTERNET`. Entered: Privatia Rigatoni, 14 Mar 2026, Prefer not to say, bottle 482 mL, nap 777 minutes, note `PRIVATIA-RIGATONI-SYNTH`. Diaper has no weight field. Scan: `no_transmission_detected` for traffic that used the system HTTP proxy. Play license talks to Google from the Play Store, not from in-app baby fields. A 0-flow proxy file does not prove Play was silent.

## Artifacts

Per-app logs: links in each block. Fanout: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json). Cross-app: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw captures stay off git. They hold login tokens.
