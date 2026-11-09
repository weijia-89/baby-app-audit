# Final Report - Which Baby Apps Keep Their Privacy Promises

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-10-10
**Harness version:** 3.2.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

This test covers 16 baby and parenting apps.
Each printed claim has one axis: pass, fail, untested, not-assessable, or inconclusive.
No stored record has gate flags G1 through G10.
A session row is not an app finding.
The package header is not origin proof.

Host, path, status, count, and sizes live in the sanitized network logs. This report keeps the claim axis and what the call is for.

| App | Privacy claim | Axis | Gate | Key findings |
| --- | --- | --- | --- | --- |
| Baby Buddy | Open source | untested | G1-G10 not stored | Android app untested. The tested session was the localhost Django site. |
| MimiLog | "Fully offline" | untested | G1-G10 not stored | Offline claim untested. The package declares no INTERNET. One measurement call in the window has no package header. |
| Amila | No claim | inconclusive | G1-G10 not stored | Firebase calls are in the 2026-08-25 window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Baby+ | "AdID not auto-enabled" | untested | G1-G10 not stored | Advertising-id setting untested. Facebook and Google ad calls are in the finished-profile window. |
| Heartful Baby | "HIPAA-compliant" | not-assessable | G1-G10 not stored | HIPAA status is not assessable. One logging batch is in the launch window. RTDB hosts only; flags not stored. |
| Baby Daybook | "AdID not auto-enabled" | untested | G1-G10 not stored | Advertising-id setting untested. Firebase calls carry the package header only. RTDB hosts only; flags not stored. RevenueCat and Sentry in that window are session. |
| Nara | "Complete privacy" | inconclusive | G1-G10 not stored | Insufficient attribution. Facebook and Crashlytics calls in the launch window are session. |
| Nubo | "Local-first" | inconclusive | G1-G10 not stored | A Firebase Installations POST is in the window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Nurture Lock | "100% offline" | untested | G1-G10 not stored | Offline claim untested. RevenueCat in the 2026-10-04 log is session. Unattributed Clarity traffic in window; source unresolved. |
| Pebbi | No claim (control) | untested | G1-G10 not stored | The 2026-10-04 mitm-only window is untested. 2026-10-10 records: pebbi-4.4.1-full.mitm and pebbi-tcpdump-coldstart.pcap. tcpdump saw DNS and TLS to app.pebbi.co; contents not read. |
| Pixy | "Bank-level encryption" | untested | G1-G10 not stored | Encryption sub-claims untested. Facebook calls in the launch window are session. |
| BabyCenter | No claim | inconclusive | G1-G10 not stored | Insufficient attribution. The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). |
| BellyBloom | No claim | inconclusive | G1-G10 not stored | Ad and attribution calls are in the window. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Nanit | No claim | inconclusive | G1-G10 not stored | Unattributed Clarity traffic in window; source unresolved. Coralogix and Cordial calls are in the window. |
| Pregnancy+ | No claim | inconclusive | G1-G10 not stored | Unattributed Clarity traffic in window; source unresolved. |
| What to Expect | No claim | inconclusive | G1-G10 not stored | The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). One Clarity asset-upload call observed; 2,753 bytes, a 71 by 71 PNG. |

Axis key:

- **pass** means the tested sentence was met.
- **fail** means a UID, a decoded body field that names the package, or an R4 line contradicts the sentence.
- **untested** means the capture did not meet the gate for that sentence.
- **not-assessable** means the sentence is not something this capture can decide.
- **inconclusive** means the window holds traffic the records cannot attribute to the app.

Gate:

- **G1-G10 not stored** means the verdict file does not store the negative-gate flags.
- No negative in this table uses a gate the file does not store.

A negative marker scan is not proof that the value never leaves the phone.

## How to read an app block

Each app has Claim, Axis, Gate, Capture, a short service table, and a link to the network log.

- **Service** - who the call names.
- **In the window** - what kind of data the capture showed. A session row is not an app finding.

Three names used below:

- **Advertising ID** - the phone number that ad companies use to say "same phone". You can reset it in Android settings.
- **Install ID** - a random number the app makes once at install.
- **Usage log** - screens you open and buttons you press.

To check a host, path, or status code, open the network log for that app.

## Analytics and PII fanout

The fanout scan covers all 16 committed network logs. [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json) field `calls_scanned` is 507 request shapes. That count is not 507 transmissions. The scan names 19 vendor or host groups.

**High-risk findings:**

- **Microsoft Clarity:** The Clarity config endpoint was fetched for BabyCenter and What to Expect. The project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). One Clarity asset-upload call observed; 2,753 bytes, a 71 by 71 PNG. That call is the What to Expect body. Pregnancy+, Nanit, and Nurture Lock: Unattributed Clarity traffic in window; source unresolved.
- **Sentry in Heartful Baby:** decompiled classes include Sentry `rrweb`. No Sentry host appeared in the preserved capture. That is static capability, not proof of a live send.

### Facebook

The BellyBloom, Pregnancy+, Nara, and Pixy windows include Facebook calls. Scrubbing removed request bodies. The table states what those SDK calls can carry, not that every field was in every request.

| Data category | In this capture |
| --- | --- |
| App activity and events | Call sent. Body not assessable |
| Device, app, and ad identifiers | Call sent. Exact fields not assessable |
| Health, contacts, photos, precise location | Not seen in scrubbed values. That is not proof of absence |

## Synthetic baby data

The same fictional profile is used for every app that has an on-device form. Marker strings and the rules for adding a field are in [results/synthetic-baby-profile.json](results/synthetic-baby-profile.json). A marker hit is not a claim axis.

| App | Inject window | Marker result | Notes |
| --- | --- | --- | --- |
| Baby+ | 2026-08-16 and 2026-08-21 About You | `transmission_observed` | Parent name in a request PUT to `appserver.health-and-parenting.com` |
| Baby+ | 2026-08-25 finished-profile recapture | `no_transmission_detected` | Install register POST to the Philips server plus Facebook and Google ad hosts. The name did not appear in this capture |
| Baby+ | 2026-08-19 Girl + DONE, then upgrade | `no_transmission_detected` | Name only in a maker response. Home still blocked by force-upgrade |
| Amila | 2026-08-17 name save | `no_transmission_detected` | Name stayed on the home screen |
| Amila | 2026-08-25 live recapture | `no_transmission_detected` | Name **Privatia Rigatoni** on home. No name in the raw capture. Not a Firebase negative. RTDB hosts only; flags not stored. |
| MimiLog | 2026-08-17 local save | `no_transmission_detected` | No `INTERNET` permission. Detail in footnotes |
| Nubo | 2026-08-18 finished timers + note | `no_transmission_detected` | Formula stayed **15**. Whole-emulator proxy. Not a Firebase negative. RTDB hosts only; flags not stored. |
| Nubo | 2026-08-24 Backup Now | not a marker scan | Last backup `08/24/2026 18:49:05` after Google Drive Continue. Claim axis stays inconclusive |
| Baby Daybook | 2026-08-17 | no inject | Pairip native crash. Environment blocker, not a privacy axis |
| Pebbi | 2026-08-17 | `no_transmission_detected` on a short walk | Profile not saved. Pairip CLOSE on cold start is an environment blocker |
| Nurture Lock | 2026-08-17 | no inject | Pairip CLOSE only. Environment blocker |
| Baby Daybook | 2026-10-04 full profile inject | `no_transmission_detected` | Name saved on-device (local SQLite row); home shows **Privatia Rigatoni**. Numeric marker hits were low-confidence coincidences in Google auth replies |
| Nurture Lock | 2026-10-04 onboarding name | `no_transmission_detected` | Home shows **Privatia Rigatoni**. RevenueCat is in the window. Log label is session. No name marker in the capture |
| Pebbi | 2026-10-04 profile form, two windows | `no_transmission_detected` | Name typed. The date field took no input. Complete Setup never fired. Profile not saved. This mitm-only window is untested |
| Pebbi | 2026-10-10 saved profile | body not in the capture | Profile saved. Records: `pebbi-4.4.1-full.mitm` and `pebbi-tcpdump-coldstart.pcap`. tcpdump saw `app.pebbi.co`. The TLS was not read |
| MimiLog | 2026-10-04 Play-gated window | `no_transmission_detected` | App has no `INTERNET` permission; capture holds Play Store and Google hosts only |

## Proprietary apps - long report

These five Play Store apps make no privacy promise. The axis is inconclusive where the log does not attribute the calls. The 2026-08-14 Clarity captures show API 29 by User-Agent. Other windows have a per-capture manifest. A missing field is the string unknown. Most fields are unknown.

The APKs came from a mirror. BellyBloom 1.0.9 needs Android 12L, so the tested build is 1.0.8 (same package signature).

| App | Package | Play Store signal | Data-safety statement |
| --- | --- | --- | --- |
| [BabyCenter](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) | `com.babycenter.pregnancytracker` | 4.9 stars, 1.54M reviews, 10M+ downloads, #3 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Nanit](https://play.google.com/store/apps/details?id=com.nanit.baby) | `com.nanit.baby` | 3.9 stars, 10.6K reviews, 500K+ downloads, #5 top grossing parenting | Shares Personal info, App activity, and App info and performance. No privacy promise found. |
| [What to Expect](https://play.google.com/store/apps/details?id=com.wte.view) | `com.wte.view` | 4.9 stars, 121K reviews, 5M+ downloads, #7 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Pregnancy+](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) | `com.hp.pregnancy.lite` | 4.8 stars, 3.64M reviews, 50M+ downloads, #10 top free parenting | Shares Location and Device or other IDs. No privacy promise found. |
| [BellyBloom](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) | `com.bellyBloom.pregnancy.tracker` | 4.6 stars, 988 reviews, 1M+ downloads | Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted. |

### BabyCenter

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-14 launch window. Insufficient attribution.

| Service | In the window |
| --- | --- |
| AppsFlyer | Which advert brought you, and an AppsFlyer ID for this phone |
| Amazon (ads) | Response keys include adId and opt-out. Values were scrubbed |
| Localytics | Usage log, likely tied to a phone ID |
| Vungle (ads) | Likely ad-measurement numbers |
| Microsoft (Clarity) | The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). |
| Scorecard Research | Repeat "this phone is here" pings |
| Google (ads) | Ad rules and permission settings |
| Google (Play services) | Location analytics from system software, not the app UI |
| OneTrust | Consent banner download. No answer was seen going back |
| BabyCenter (Snowplow and own) | In-family usage log, country, and app settings |

- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-14 launch window. Version 1.0.8.
- **Later launch:** Pairip CLOSE on this emulator. Environment blocker. That screen is not a privacy axis.

| Service | In the window |
| --- | --- |
| TikTok (Pangle ads) | Likely advertising ID, phone details, ad rules, and playable ads |
| Adjust | Session and which advert brought you |
| Facebook | App-activity and ad-network sync. Bodies scrubbed |
| InMobi (ads) | Ad rules |
| Mixpanel | Usage log |
| Google (ads and Funding Choices) | Ad files, ad rules, and consent answers |
| Google (Firebase) | Install ID and tokens. Settings and crash rules. RTDB hosts only; flags not stored. |

- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.nanit.baby)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-14 launch window. Sign-in was not completed.

| Service | In the window |
| --- | --- |
| Google (Firebase) | Install ID and tokens. Settings and crash rules. RTDB hosts only; flags not stored. |
| Microsoft (Clarity) | Unattributed Clarity traffic in window; source unresolved. |
| Localytics | Usage log, likely tied to a phone ID |
| Cordial | Contact data for email. Auth reply carried a token |
| Coralogix | App speed and errors, plus one browser log |
| Nanit (own) | Plans and cards. Cards were not signed in |

- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-14 launch window. Machine consent with sensitivity off.

| Service | In the window |
| --- | --- |
| Microsoft (Clarity) | Unattributed Clarity traffic in window; source unresolved. |
| Facebook | App-activity event. Body scrubbed |
| Adapty | Subscription state, attribution, and usage, stored on Amazon |
| OneSignal | Push rules. A token if you allow push |
| Philips (own) | Maker account server |
| Google (Firebase) | Install ID, settings, usage logs. RTDB hosts only; flags not stored. |

- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.wte.view)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-14 launch window. Advertising-ID permission is in the package.

| Service | In the window |
| --- | --- |
| AppsFlyer | Start, attribution, install date and status |
| Microsoft (Clarity) | The Clarity config endpoint was fetched; the project config enables capture features. Clarity collect call(s) observed; contents not assessable (body not JSON-parseable). One Clarity asset-upload call observed; 2,753 bytes, a 71 by 71 PNG. |
| Mixpanel | Usage log |
| Cordial | Usage events for email |
| Scorecard Research | "This phone is here" ping |
| What to Expect (Snowplow) | In-family usage log |
| Google (Firebase) | Install ID and settings. RTDB hosts only; flags not stored. |
| OneTrust | Consent banner download. No answer was seen going back |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

### Heartful Baby

- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Axis:** not-assessable
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-12 launch window. One logging batch is in the window. The HIPAA program was not reviewed.

| Service | In the window |
| --- | --- |
| Google (Firebase) | One logging batch. RTDB hosts only; flags not stored. |

- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Nara

- **Claim:** "Complete privacy" (Google Play listing)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-12 launch window. Insufficient attribution.

| Service | In the window |
| --- | --- |
| Facebook | SDK settings and model files. Request bodies in this capture were empty |
| Google (Crashlytics) | Crash report batch in the window. The row is session |

- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Pixy

- **Claim:** "Bank-level encryption" (Google Play listing)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-12 launch window. Encryption sub-claims were not measured.

| Service | In the window |
| --- | --- |
| Facebook | SDK settings and setup files. The calls are session |

- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

Baby Buddy is the only open-source app in this test. The Android app was not the session under test.

### Baby Buddy

- **Claim:** Open source - [github.com/babybuddy/babybuddy](https://github.com/babybuddy/babybuddy)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-03 localhost Django web session. The Android companion was not tested.
- **Android companion (2026-08-23):** first-launch photos of `eu.pkgsoftware.babybuddywidgets` v2.6.4. Login form only. A server was not connected. That screen is not an open-source pass for the Android app.

| Service | In the window |
| --- | --- |
| httpbin.org (curl probe) | Environment check. No app data |

## Proprietary apps - short report

### Amila

- **Claim:** No claim - [Play listing](https://play.google.com/store/apps/details?id=com.amila.parenting)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-25 live inject. Evidence source is `raw-replay`. The package header is not origin proof. A second record, `results/amila-test-20260825-silence/artifacts/captures/silence-verdict-rederived.json`, has verdict untested because `uid_available` is false. The control host in that file is 8.8.8.8. The table axis stays inconclusive. The result table does not store the gate flags.

| Service | In the window |
| --- | --- |
| Google (Firebase) | Install register, settings, logging, Crashlytics settings. RTDB hosts only; flags not stored. |
| Google (Measurement) | App Measurement config and batch posts |
| Google (Funding Choices) | Consent messages |

- **Network log:** [network-log-amila.json](results/network-log-amila.json)

### Baby+

- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-25 finished-profile window. Evidence source is `raw-replay`. The advertising-id setting was not measured.
- **About Baby gender:** required. TalkBack has no Boy/Girl names. Girl was selected via the popup row, then DONE reached home. Session dumps: `ROADMAP.md`.

| Service | In the window |
| --- | --- |
| Philips (own) | Install register: app ID, installation ID, locale, time zone |
| Facebook | Graph API calls |
| Google ads | DoubleClick, page ads, Ads services |
| Google (Firebase) | Remote config fetch. RTDB hosts only; flags not stored. |

- **Network log:** [network-log-baby-plus.json](results/network-log-baby-plus.json)

### Baby Daybook

- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-10-04, full onboarding to home with the profile. Evidence source is `raw-replay`. The advertising-id setting was not measured.

| Service | In the window |
| --- | --- |
| RevenueCat | Subscriber reads. The log label is session |
| Google (Firebase) | Install register, remote config, and the realtime stream carry the package header only. RTDB hosts only; flags not stored. Other Firebase calls in the window are session. RTDB hosts only; flags not stored. |
| Google (messages) | Push register |
| Sentry | One crash report envelope |
| Facebook | Graph call in the same window, with no package header |

- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### MimiLog

- **Claim:** "Fully offline" - [Play listing](https://play.google.com/store/apps/details?id=com.mimiapp.mimilog)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-16 launch window. Evidence stays `session-summary`. The package declares no `INTERNET` permission (permission dump kept in `results/mimilog-test-20261004/artifacts/logs/`). The kept launch capture holds one measurement call with no package header. The 2026-10-04 re-run met the Pairip probe. With the audit proxy on, Play Store license auth failed (no signed-in Google account). That capture held Play and Google hosts only.

| Service | In the window |
| --- | --- |
| Google (Measurement) | One measurement call with no package header |

- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nubo

- **Claim:** "Local-first" (Google Play listing)
- **Axis:** inconclusive
- **Gate:** G1-G10 not stored
- **Capture:** 2026-08-03 first launch. Replayed through the pipeline on 2026-08-25. Evidence source is `raw-replay`. A second record, `results/nubo-test-20260825/artifacts/captures/silence-verdict-rederived.json`, has verdict untested because `uid_available` is false. `control_hosts` in that file is empty. The table axis stays inconclusive. The result table does not store the gate flags.
- **Later use:** the kept 2026-08-18 finished-use soak shows Google device traffic only. 2026-08-24 Backup Now finished after Google Drive Continue. That backup is not a claim axis.

| Service | In the window |
| --- | --- |
| Google (Firebase) | Installations POST. The package header is not origin proof. RTDB hosts only; flags not stored. |
| Google (Crashlytics) | Crash-configuration rules. The row is session |
| Google (messages) | Push and message registers. The rows are session |

- **Network log:** [network-log-nubo.json](results/network-log-nubo.json)

### Nurture Lock

- **Claim:** "100% offline" (Google Play listing)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** 2026-10-04, full onboarding to home with the profile. Evidence source is `raw-replay`.

| Service | In the window |
| --- | --- |
| RevenueCat | Subscriber reads. The log label is session |
| Adapty | Subscription state in the window |
| OneSignal | Push rules in the window |
| AppsFlyer | Attribution settings in the window |
| Comscore (Scorecard) | "This phone is here" pings in the window |
| Microsoft (Clarity) | Unattributed Clarity traffic in window; source unresolved. |
| Facebook | Graph destination in the window |
| Philips (own) | First-party usage endpoints in the window |
| Google (Firebase) | Install and crash settings in the window. RTDB hosts only; flags not stored. |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Pebbi

- **Claim:** No claim (control app)
- **Axis:** untested
- **Gate:** G1-G10 not stored
- **Capture:** The committed log is the 2026-10-04 mitm file. That mitm-only window is untested. On 2026-10-10 the profile saved. Cite `results/pebbi-test-20261010/artifacts/captures/pebbi-4.4.1-full.mitm` and `results/pebbi-test-20261010/artifacts/captures/pebbi-tcpdump-coldstart.pcap`. tcpdump saw DNS and TLS to `app.pebbi.co`. The TLS was not read.

| Service | In the window |
| --- | --- |
| Pebbi (own) | Version-policy call. The 2026-10-04 log label is session |
| Google (Firebase) | Installations POST in the 2026-10-04 log. The package header is not origin proof. RTDB hosts only; flags not stored. |
| RevenueCat | Subscription state in the 2026-10-04 window |
| Google (Play) | Store traffic in the same window |

- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

## Cross-app view

Nara is inconclusive: insufficient attribution.
Nubo is inconclusive: the Installations POST is header-labeled only. RTDB hosts only; flags not stored.
Heartful Baby is not-assessable. Pixy is untested.
The HIPAA program and the encryption claim were not what the capture tested.

BabyCenter is inconclusive: insufficient attribution.
Nanit and Pregnancy+ have unattributed Clarity traffic in the window. The source is unresolved.
Play data-safety pages for the five long-report apps say they share data. That page is not a capture axis.

## Limits

- Launch captures predate the injector. Re-captures enter the fictional profile. The synthetic table states whether those strings were observed. A marker miss is not a claim axis.
- Captures are launch and early use. Later sessions can differ.
- Response bodies and header values were removed because they can carry tokens. Logs keep method, host, path, status, count, and sizes. A scrubbed body is not proof that PII was absent.
- Evidence depth is not equal. Fourteen apps are `raw-replay`. Two are still `session-summary` in `results/RESULTS-20260803.json`: Baby Buddy and MimiLog.
- Baby Buddy is still `session-summary`. The tested session was the localhost Django site. The Android companion pictures are a login screen only. MimiLog is still `session-summary`. The store reinstall waits on "Complete account setup / Review your account". The package declares no `INTERNET`. The license dialog is an environment fact.
- Pairip blocked four apps until 2026-09-20, when a real Play Store made the license checks pass. Baby Daybook, Nurture Lock, and Pebbi were recaptured on 2026-10-04. Pebbi's 2026-10-04 mitm window is untested. The 2026-10-10 tcpdump saw TLS to `app.pebbi.co` and the TLS was not read. MimiLog's window did not open.
- The run-level result file does not store one API level. The 2026-08-14 Clarity captures show API 29 by User-Agent. Other windows have a per-capture manifest. A missing field is the string unknown. Most fields are unknown.
- baby-track, cradle, and dymn-baby had no usable APK. No captures.

## Advice

**For parents:** An offline or local-first sentence stays untested until a stored gate passes. Baby Buddy's Android app was not the tested session. MimiLog's offline sentence is untested.

**For developers:** If you say "offline", an app-attributed call to a non-local host can fail that sentence. A session row cannot.

**For regulators:** "100% offline" and "local-first" are testable only with an attributed flow or with stored gate flags. This file has neither for those sentences.

## Footnotes

[^mimilog-play]: MimiLog 2026-08-17. Settings has units, theme, language, and notifications. No sign-in. Package asks Play license check and does not declare `INTERNET`. Entered: Privatia Rigatoni, 14 Mar 2026, Prefer not to say, bottle 482 mL, nap 777 minutes, note `PRIVATIA-RIGATONI-SYNTH`. Diaper has no weight field. Marker scan: `no_transmission_detected` for traffic that used the system HTTP proxy. Play license talks to Google from the Play Store, not from in-app baby fields. A 0-flow proxy file is not a negative.

## Artifacts

Per-app logs: links in each block. Fanout: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json). Cross-app: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw captures stay off git. They hold login tokens.
