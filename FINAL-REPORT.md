# Final Report - Which Baby Apps Keep Their Privacy Promises

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-25
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

We tested 16 baby and parenting apps. Most say they protect privacy. Seven of nine that make a promise sent data off the device. Only Baby Buddy and MimiLog matched their words.

Host, path, status, count, and sizes live in the sanitized network logs. This report keeps the verdict and what the call is for.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open source | PASS | 💖 | 100% | Django web: no app-originated traffic. Android companion login photos are not the PASS |
| MimiLog | "Fully offline" | PASS | 💖 | 100% | Firebase setup never completed. Later local save: no baby-profile traffic on the system proxy |
| Amila | No claim | No claim | ❕ | 90% | Registers the install with Google; settings, logging, and measurement calls (2026-08-25 recapture) |
| Baby+ | "AdID not auto-enabled" | FAIL | ❕ | 90% | Contacts Philips, Google, and Firebase at launch. Later About You PUT sends the parent name |
| Heartful Baby | "HIPAA-compliant" | FAIL | ❕ | 90% | One Firebase usage log at launch. A HIPAA claim does not match this |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 🚫 | 90% | Google plus a subscription service. Package also contains Facebook code |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | Nine Facebook calls at launch, plus a Google crash report |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | First launch sends screen and setup steps to Firebase |
| Nurture Lock | "100% offline" | FAIL | 🚫 | 95% | Subscription call at launch. Package lists eight tracking companies |
| Pebbi | No claim (control) | No claim | 🚫 | 100% | Firebase, Google ads, and Google messages at launch |
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | Three Facebook calls at launch to load tracking rules |
| BabyCenter | No claim | No claim | 🚫 | 95% | **Microsoft Clarity receives screen content, text, pictures, and taps.** Ads and attribution too |
| BellyBloom | No claim | No claim | 🚫 | 90% | Advertising ID, usage, and which advert brought you, to many companies |
| Nanit | No claim | No claim | 🚫 | 95% | **Microsoft Clarity records the screen.** Coralogix gets a browser log. Cordial gets contacts |
| Pregnancy+ | No claim | No claim | 🚫 | 95% | **Microsoft Clarity records the screen.** Ads, usage, consent, and attribution to five companies |
| What to Expect | No claim | No claim | 🚫 | 90% | **Microsoft Clarity uploads screen images.** Ads, usage, and consent answers as well |

Result key:

- **💖** passed and behaved as described.
- **❕** failed, but the capture did not show data that identifies you.
- **🚫** failed, and the capture showed identifying data or very heavy collection.

An app with no privacy claim cannot fail. Its result says "no claim". The privacy mark still shows what we saw.

No test ended inconclusive.

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

The fanout scan covers all 16 committed network logs: 212 calls, 18 vendor or host groups. Machine output: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json).

**High-risk findings:**

- **Microsoft Clarity:** collection calls were sent. What to Expect also sent a screen-image upload. Scrubbing removed request bodies, so the exact pixels are not assessable.
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

We enter one fictional baby (Privatia Rigatoni). Markers are in `results/synthetic-baby-profile.json`. We type them while the proxy is live. Short lists keep the value that sticks. The scan greps the raw local capture, not the redacted network logs. Method: `METHODOLOGY.md`. How much of each app we opened: `ROADMAP.md`.

| App | Inject window | Marker result | Notes |
| --- | --- | --- | --- |
| Baby+ | 2026-08-16 and 2026-08-21 About You | `transmission_observed` | Parent name in a request PUT to `appserver.health-and-parenting.com` |
| Baby+ | 2026-08-19 Girl + DONE, then upgrade | `no_transmission_detected` | Name only in a maker response. Home still blocked by force-upgrade |
| Amila | 2026-08-17 name save | `no_transmission_detected` | Name stayed on the home screen |
| Amila | 2026-08-25 live recapture | `no_transmission_detected` | Name **Privatia Rigatoni** on home. No name in the raw capture. Not Firebase-silence |
| MimiLog | 2026-08-17 local save | `no_transmission_detected` | No `INTERNET` permission. Detail in footnotes |
| Nubo | 2026-08-18 finished timers + note | `no_transmission_detected` | Formula stayed **15**. Whole-emulator proxy. Not Firebase-silence |
| Nubo | 2026-08-24 Backup Now | not a marker scan | Last backup `08/24/2026 18:49:05` after Google Drive Continue. FAIL mark unchanged |
| Baby Daybook | 2026-08-17 | no inject | Pairip native crash. Environment blocker, not a privacy verdict |
| Pebbi | 2026-08-17 | `no_transmission_detected` on an 8-flow walk | Profile not saved. Pairip CLOSE on cold start is an environment blocker |
| Nurture Lock | 2026-08-17 | no inject | Pairip CLOSE only. Environment blocker |

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
| Microsoft (Clarity) | **Screen recording: screens, taps, text, and pictures** |
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
| Microsoft (Clarity) | **Screen recording** |
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
| Microsoft (Clarity) | Screen recording |
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
| Microsoft (Clarity) | **Screen recording plus image file uploads** |
| Mixpanel | Usage log |
| Cordial | Usage events for email |
| Scorecard Research | "This phone is here" ping |
| What to Expect (Snowplow) | In-family usage log |
| Google (Firebase) | Install ID and settings |
| OneTrust | Consent banner download. We saw no answer sent back |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

### Heartful Baby

- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. One usage log is enough to break a HIPAA promise. One log also limits certainty.
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
- **Result:** FAIL
- **Confidence:** 90%. Encryption in transit is not "no collection". Payloads not readable. We report only the three Facebook calls in the preserved capture.
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
- **Result:** FAIL
- **Confidence:** 90%. Forty flows on the 2026-08-25 finished-profile recapture. A first-party install register went to the Philips server, and Facebook plus Google advertising hosts appeared during onboarding and home. The name did not leave the device in this capture. The kept 2026-08-21 capture saw that name PUT once.
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
- **Result:** FAIL
- **Confidence:** 90%. Eight flows at launch. Payloads not readable. FAIL is from 2026-08-08, not from the later Pairip crash.
- **Capture:** 2026-08-08, launch window, 8 flows.

| Service | What we saw |
| --- | --- |
| RevenueCat | Subscription state |
| Google (Firebase) | Install register and settings |
| Google (messages) | Push and message register |

- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### MimiLog

- **Claim:** "Fully offline" - [Play listing](https://play.google.com/store/apps/details?id=com.mimiapp.mimilog)
- **Result:** PASS
- **Confidence:** 90%. The package declares no `INTERNET` permission, so the app cannot open its own network connections. The kept launch capture holds one completed Google App Measurement call with no app package header, so the caller cannot be attributed from the capture alone. The synthetic scan found nothing.
- **Capture:** 2026-08-16, launch window, 1 flow. Evidence stays `session-summary`: a 2026-08-25 live re-run hit a Pairip license dialog and CLOSE-loop on this AVD, for the installed build and for an archived-build sideload test.

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
- **Result:** FAIL
- **Confidence:** 95%. A subscription call at launch breaks "100% offline". Package lists eight tracking companies. FAIL is from 2026-08-03, not from later Pairip CLOSE.
- **Capture:** 2026-08-03, launch window, 17 flows (raw replay).

| Service | What we saw |
| --- | --- |
| RevenueCat | Subscription state |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Pebbi

- **Claim:** No claim (control app)
- **Result:** No claim
- **Confidence:** 100%. Four flows at launch. 🚫 because volume is heavy even with no claim. Later Pairip CLOSE is an environment blocker.
- **Capture:** 2026-08-03, launch window, destinations only.

| Service | What we saw |
| --- | --- |
| Google (Firebase) | Usage logs and crash rules |
| Pebbi (own) | Own server |
| Google (messages) | Push and message register |

- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

## Cross-app view

Every failed app shares Firebase. Nara and Pixy also embed Facebook. "Complete privacy" and "HIPAA-compliant" sit next to code that sends data out.

Four of the five long-report apps ship install and ad programs (Facebook, Adjust, TikTok, or Google/Amazon). Nanit also sends screen and browser telemetry to Clarity and Coralogix, and contacts to Cordial. Play data-safety pages for all five say they share data.

## Limits

- Launch captures predate the injector. Re-captures enter the fictional profile. The synthetic table states whether those strings left the device.
- Captures are launch and early use. Later sessions can differ.
- We removed response bodies and header values because they can carry tokens. Logs keep method, host, path, status, count, and sizes. A scrubbed body is not proof that PII was absent.
- Evidence depth is not equal. Eleven apps are `raw-replay` (Nubo and Baby+ promoted 2026-08-25). Five are still `session-summary` in `results/RESULTS-20260803.json`.
- Treat session-summary rows as a lower bound. Later local `.mitm` files can exist and still not change a mark. Recapture plan: `ROADMAP.md` Sprint 5.
- MimiLog joined the Pairip-blocked set on 2026-08-25: the license dialog CLOSE-loops on cold start. Pebbi, Nurture Lock, and Baby Daybook stay blocked too. These are environment blockers, not privacy marks.
- baby-track, cradle, and dymn-baby had no usable APK. No captures.

## Advice

**For parents:** Do not trust "offline" or "local-first". Baby Buddy made no app-originated calls. MimiLog's Firebase setup never completed, and a later save showed 0 system-proxy flows.

**For developers:** If you say "offline", remove analytics and attribution. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable.

## Footnotes

[^mimilog-play]: MimiLog 2026-08-17. Settings has units, theme, language, and notifications. No sign-in. Package asks Play license check and does not declare `INTERNET`. Entered: Privatia Rigatoni, 14 Mar 2026, Prefer not to say, bottle 482 mL, nap 777 minutes, note `PRIVATIA-RIGATONI-SYNTH`. Diaper has no weight field. Scan: `no_transmission_detected` for traffic that used the system HTTP proxy. Play license talks to Google from the Play Store, not from in-app baby fields. A 0-flow proxy file does not prove Play was silent.

## Artifacts

Per-app logs: links in each block. Fanout: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json). Cross-app: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw captures stay off git. They hold login tokens.
