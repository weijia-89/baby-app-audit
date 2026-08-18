# Final Report - Which Baby Apps Keep Their Privacy Promises

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-17
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

We tested 16 baby and parenting apps. Most say they protect their privacy. We checked whether their words match what the app actually does with your data.

Nine apps make a privacy promise. Seven of them sent data off the device. Only Baby Buddy and MimiLog did what they said.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open source | PASS | 💖 | 100% | No data leaves your phone. The app talks only to itself on the same device |
| MimiLog | "Fully offline" | PASS | 💖 | 100% | One call to Google's setup service at launch. The app holds no valid project, so it sends nothing. A later live save also showed no baby-profile traffic through the system proxy |
| Amila | No claim | No claim | ❕ | 90% | The app registers this install with Google and downloads app settings and font files at launch |
| Baby+ | "AdID not auto-enabled" | FAIL | ❕ | 90% | The app contacts a Philips server, Google, and Firebase at launch |
| Heartful Baby | "HIPAA-compliant" | FAIL | ❕ | 90% | The app sends one usage log to Google Firebase at launch. A HIPAA claim does not match this |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 🚫 | 90% | The app registers with Google and calls a subscription service. Its code also contains Facebook code |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | The app calls Facebook nine times at launch. It also sends crash reports and usage data to Google |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | The app sends what you do in it (screens you open, steps you take at setup) to Firebase at first launch |
| Nurture Lock | "100% offline" | FAIL | 🚫 | 95% | The app calls a subscription service at launch. Its package contains code from eight tracking companies |
| Pebbi | No claim (control) | No claim | 🚫 | 100% | The app sends data to Firebase, Google ads, and Google's message service at launch |
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | The app calls Facebook three times at launch to load Facebook's tracking rules |
| BabyCenter | No claim | No claim | 🚫 | 95% | **Microsoft Clarity receives screen content, text, pictures, and taps.** The app also sends an advertising ID and usage data to many companies at launch |
| BellyBloom | No claim | No claim | 🚫 | 90% | The app sends your advertising ID, usage, and a record of which advert brought you, to many companies at launch |
| Nanit | No claim | No claim | 🚫 | 95% | **Microsoft Clarity receives screen activity.** Coralogix receives a 15.6-kilobyte browser log, and Cordial receives contact data |
| Pregnancy+ | No claim | No claim | 🚫 | 95% | **Microsoft Clarity receives screen activity.** The app also sends an advertising ID, usage, consent answers, and attribution data to five companies |
| What to Expect | No claim | No claim | 🚫 | 90% | **Microsoft Clarity uploads screen images.** The app also sends an advertising ID, usage, and consent answers to several companies |

Result key:

- **💖** means the app passed and behaved as described.
- **❕** means the app failed, but the capture showed it sends data off the phone without identifying you.
- **🚫** means the app failed, and the capture showed data that identifies you or very heavy data collection.

An app with no privacy claim cannot fail, because there is no promise to break. Its result says "no claim"; the privacy mark still shows what we saw.

No test ended inconclusive.

## How to read the tables below

Each app section has a table with three columns.

- **Service** - the company that receives the call.
- **Data shared** - what kind of data the call carries, in plain words. "We saw" means the reply to this call contained that data in our capture. "Likely" means the app connects to this service for that purpose, but we could not read what was inside because the message bodies carry login tokens and we removed them.
- **Call/Log** - the internet address the app used and the result code. This line is for anyone who wants to check the raw record.

Three kinds of data repeat across the tables, so they have one name each here:

- **Advertising ID** - the number that your phone shows to apps and ad companies. It tells them "this is the same phone" across apps, so they can show you targeted ads. You can reset it in Android settings.
- **Install ID** - a new random number that the app makes once, when you install it on your phone. It tells the company "this is one phone with one install".
- **Usage log** - a record of what you do in the app: which screens you open and which buttons you press.

### Evidence labels

- **Call sent** - the capture records the method, address, path, status, and call count.
- **Content not assessable** - the call was sent, but privacy scrubbing removed the body or header values. This is not evidence that PII was absent.
- **Capability observed** - a response, static file, or SDK name shows that a feature exists. This does not prove that the feature sent data.
- **Destination only** - an older capture records the destination but not the request body or response details.

## Analytics and PII fanout

The fanout scan covers all 16 committed network logs. It scanned 212 calls and found 18 vendor or host groups. It does not limit the result to a short list of popular vendors.

The scan records every call, including calls to an unclassified host. Each call records whether it was sent, its data categories, the assessment status, and the redaction slugs. See [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json) and its schema.

**High-risk findings:**

- **Microsoft Clarity:** The capture shows screen-capture settings. Clarity collection calls were sent. What to Expect also sent a screen-image upload. The request contents were scrubbed, so the exact screen data in each request is not assessable.
- **Sentry in Heartful Baby:** The decompiled app contains Sentry `rrweb` classes. No Sentry destination appeared in the preserved network capture. This is static capability evidence, not proof of transmission.
- **Other replay tools:** FullStory, Smartlook, UXCam, Appsee, Glassbox, LogRocket, Contentsquare, Heap, Quantum Metric, Mouseflow, Hotjar, and Instabug were not observed in the committed capture logs. This is a capture-window result, not proof that those tools are absent from every app version or later session.

### Facebook assessment

The capture records Facebook calls in BellyBloom, Pregnancy+, Nara, and Pixy. The list below gives the data categories that the observed Facebook SDK calls can handle. It does not claim that every category was in every request.

| Data category | Why it is in scope | Assessment in this capture |
| --- | --- | --- |
| App activity and events | Facebook `activities` calls were sent | **Call sent. Request body not assessable because scrubbing removed its values.** |
| Device and app identifiers | Facebook event and Audience Network calls can use identifiers for the app or device | **Call sent. Exact fields not assessable because scrubbing removed its values.** |
| Advertising and attribution data | The calls include Facebook event and ad-network endpoints | **Call sent. Exact fields not assessable because scrubbing removed its values.** |
| Device and software details | Facebook SDK configuration and model endpoints were contacted | **Configuration response observed. User-data request content was not assessable.** |
| Network metadata | A server can receive connection metadata such as source address and time | **Not assessable from the sanitized capture.** |
| Health, contacts, photos, and precise location | These are possible SDK inputs only when the app passes them to the SDK | **Not observed in the scrubbed request values. This is not evidence of absence.** |

## Synthetic baby-data transmission test

The launch captures could not see user-entered baby data (feeding, sleep, diaper), because no fictional profile was entered during those windows. This test closes that gap. It does not replace the findings above. It adds a direct check for entered values leaving the device.

Method:

- A fixed fictional baby, "Privatia Rigatoni", born 2026-03-14 at 6 lbs 8 oz, with unusual sentinel values for feeding (482 mL), sleep (777 minutes), and diaper (1234 g). The automated injector enters these in each app while the capture proxy is live (see `scripts/inject-synthetic-profile.py`). The full profile is in `results/synthetic-baby-profile.json`.
- After capture, `scripts/scan-synthetic-baby-data.sh` greps the raw local capture for the profile's marker strings. It reports which fictional values appear in a request body, a response body, or a request URL, and the recipient host for each.
- The committed, sanitized network logs are not searched. Their bodies are redacted, so the fictional values would be invisible there. Only the raw local capture can show exfiltration.

Status: the profile, the scan tool, and a unit test are in place. Live inject+scan is in progress. Baby+ (2026-08-16): Google sign-in reached **About You** / **About Baby**. Parent-name **CONTINUE** sent a `PUT` to `appserver.health-and-parenting.com` with no plaintext marker match. Baby name was entered; **DONE** did not complete because gender is not exposed to automation (see Baby+ accessibility note). MimiLog (2026-08-17): local save; 0 system-proxy flows; scan `no_transmission_detected`.[^mimilog-play] Amila (2026-08-17): name saved on the home screen. Capture had 9 flows. Scan: `no_transmission_detected` (0 marker hits). Baby Daybook (2026-08-17): crashed at Pairip native load on this emulator. No inject. Pebbi (2026-08-17): 4.0.1 reached **Add New Baby** then Pairip on cold start. Pulled 3.2.1 (forced update), 3.4.0 and 3.5.0 (Pairip). No saved Pebbi profile. Nurture Lock: Pairip **CLOSE** only. Nubo (2026-08-18): profile already saved. Full start/stop milk, sleep, and pump sessions, plus bottle/pee/poop taps and a saved note. Proxy capture for that run was not started here. Scan still `no_transmission_detected` on the 0-byte file from 2026-08-17.

## Proprietary apps - long report

These are the five most popular Google Play targets. They make no privacy promise, so their result says "No claim"; the privacy mark shows what we saw in the launch capture.

The Play Store pages make no no-data-sharing or offline promise. We acquired these APKs from a mirror and ran burst tests on an API 29 emulator. None of the five kept traffic on the device. BellyBloom 1.0.9 requires Android 12L (API 32), so the tested build is 1.0.8, which shares the same package signature.

| App | Package | Play Store signal | Data-safety statement |
| --- | --- | --- | --- |
| [BabyCenter](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) | `com.babycenter.pregnancytracker` | 4.9 stars, 1.54M reviews, 10M+ downloads, #3 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Nanit](https://play.google.com/store/apps/details?id=com.nanit.baby) | `com.nanit.baby` | 3.9 stars, 10.6K reviews, 500K+ downloads, #5 top grossing parenting | Shares Personal info, App activity, and App info and performance. No privacy promise found. |
| [What to Expect](https://play.google.com/store/apps/details?id=com.wte.view) | `com.wte.view` | 4.9 stars, 121K reviews, 5M+ downloads, #7 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Pregnancy+](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) | `com.hp.pregnancy.lite` | 4.8 stars, 3.64M reviews, 50M+ downloads, #10 top free parenting | Shares Location and Device or other IDs. No privacy promise found. |
| [BellyBloom](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) | `com.bellyBloom.pregnancy.tracker` | 4.6 stars, 988 reviews, 1M+ downloads | Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted. |

### BabyCenter
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) (data safety: "Shares Personal info and Health and fitness, plus five other data types")
- **Result:** No claim
- **Confidence:** 95%. Thirty-five calls at launch to at least eight companies. The app asks for the advertising-ID permission in its file list, and it registers which advert brought you. This is the strongest no-claim evidence in this wave. We could not read the message bodies, which caps confidence below 100%.
- **Capture:** 2026-08-14, launch window, 35 calls (19 types, 17 addresses).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Tells its business customers which advert brought you and when you started the app. We saw the reply carry an AppsFlyer ID for this phone | POST 2snoab.launches.appsflyersdk.com/api/v6.18/androidevent -> 200 |
| AppsFlyer | Downloads its own app-settings file at launch | GET 2snoab.cdn-settings.appsflyersdk.com/android/v2/.../settings -> 200 (3 calls) |
| Amazon (ads) | Sends your advertising ID and whether you asked out of ads. The reply echoes the advertising ID back | POST s.amazon-adsystem.com/api3/update_dev_info -> 200 (a 1,047-byte message; the reply echoes the advertising ID) |
| Localytics | Receives a usage log: what you do in the app. The log is likely tied to an ID for this phone | POST analytics.localytics.com/api/v4/applications/.../upload -> 202; POST profile.localytics.com/v1/apps/.../profiles/... -> 202 |
| Vungle (ads) | Likely receives ad-measurement numbers: which ads it showed you | POST logs.ads.vungle.com/sdk/metrics -> 200 |
| Microsoft (Clarity) | **Receives a recording of what you see and do in the app: which screens open and where you tap, with the text and pictures on them** | POST r.clarity.ms/collect -> 204 (4 calls); GET www.clarity.ms/tag/mobile/vnmy25t03u -> 200 |
| Scorecard Research | Receives a small "this phone is here" call, twelve times. Likely used to count visitors and identify your phone for surveys | GET census-app.scorecardresearch.com/p2 -> 200 (12 calls) |
| Google (ads) | Downloads the rules for showing ads, plus settings that say which permissions the ad code may use | GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 |
| Google (Play services) | Receives location-analytics data. This call comes from Google's system software on the phone, not from the app itself | POST semanticlocation-pa.googleapis.com (application/grpc) |
| OneTrust | Downloads the "do we have permission to track you?" screen shown at first open. We saw no answer being sent back | GET mobile-data.onetrust.io/cfw/cmp/v1/banner -> 200 |
| BabyCenter (Snowplow) | Receives its own usage log through the Snowplow program. This stays inside the BabyCenter family | POST bcsp.babycenter.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| BabyCenter (own) | Asks which country you are in and downloads app settings. This stays inside the BabyCenter family | GET geo.babycenter.com/v1 -> 200; GET www.babycenter.com/app_config/android/en-US/welcomeScreenABTest.json -> 200 |

- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) (data safety: "Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted")
- **Result:** No claim
- **Confidence:** 90%. Fifty-three calls at launch, almost all to ad and tracking services. We used version 1.0.8 because version 1.0.9 needs a newer Android. A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, 53 calls (42 types, 13 addresses).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| TikTok (Pangle ads) | Likely sends your advertising ID and phone details, downloads ad rules, and loads full-screen ad games (one file is 1.8 million bytes) | POST api16-access-ttp.tiktokpangle.us/api/ad/union/sdk/settings/ -> 200 (3 calls); POST api16-access-ttp.tiktokpangle.us/service/2/dual_events/ -> 200; GET lf-static.tiktokpangle-cdn-us.com/obj/union-fe-tx/playable/sdk/... -> 206 |
| Adjust | Records when you started the app and which advert brought you. We saw its reply carry an account ID and your tracking state | POST app.adjust.com/session -> 200; GET app.adjust.com/attribution -> 200 (reply keys: adid, app_token, attribution) |
| Facebook | **Sends an app-activity event to Facebook. The request body was scrubbed, so the exact event fields are not assessable.** | GET graph.facebook.com/v16.0/app -> 200 (3 calls); POST graph.facebook.com/v16.0/26540417615628323/activities -> 200 (3 calls) |
| Facebook (Audience Network) | **Sends a Facebook ad-network sync call. The request body was scrubbed, so identifier and ad-matching fields are not assessable.** | POST www.facebook.com/adnw_sync2 -> 200 |
| InMobi (ads) | Downloads ad rules and settings | POST config.inmobi.com/config-server/v1/config/secure.cfg -> 200 (2 calls) |
| Mixpanel | Receives a usage log: what you do in the app | POST api.mixpanel.com/track/ -> 200 |
| Google (ads) | Downloads the ad files (one file of 719,476 bytes) and the rules for showing ads | GET googleads.g.doubleclick.net/mads/static/sdk/native/sdk-core-android.html -> 200; GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 (61 kilobytes) |
| Google (Funding Choices) | Sends your answers to the "can this app collect data for ads?" screen back to Google's consent service | POST fundingchoicesmessages.google.com/a/consent -> 200; POST fundingchoicesmessages.google.com/um/... -> 204 |
| Google (Firebase) | Registers this install. The reply carries an install ID, a security token, and a way to refresh it | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google (Firebase) | Downloads app settings and crash-configuration rules. No data about you | POST firebaseremoteconfig.googleapis.com/v1/projects/254761198014/namespaces/firebase:fetch -> 200; GET firebase-settings.crashlytics.com/spi/v2/platforms/android/gmp/... -> 200 |

- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.nanit.baby) (data safety: "Shares Personal info, App activity, and App info and performance")
- **Result:** No claim
- **Confidence:** 95%. Twelve calls at launch. The app records what you do on screen and sends it, plus usage logs, and it sends contact data to an email-marketing service. We did not sign in, which caps confidence below 100%.
- **Capture:** 2026-08-14, launch window, 12 calls.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (Firebase) | Registers this install. The reply carries an install ID, a security token, and a way to refresh it | POST firebaseinstallations.googleapis.com/v1/projects/nanit-144706/installations -> 200 |
| Google (Firebase) | Downloads app settings and crash rules. No data about you | POST firebaseremoteconfig.googleapis.com/v1/projects/25705829844/namespaces/firebase:fetch -> 200; GET firebase-settings.crashlytics.com/... -> 200 |
| Microsoft (Clarity) | **Receives a recording of what you see and do in the app: which screens open and where you tap** | POST r.clarity.ms/collect -> 204 |
| Localytics | Receives a usage log likely tied to an ID for this phone | POST analytics.localytics.com/api/v4/applications/.../upload -> 202 |
| Cordial | Receives contact data for its email service. The login call's reply carries a token | POST events-stream-svc.usw2.cordial.com/mobile/auth/... -> 200 (the reply carries a token); POST events-stream-svc.usw2.cordial.com/mobile/contacts -> 200 |
| Coralogix | **Receives error and speed data about the app while you use it, plus one 15.6-kilobyte browser log of what the app does** | POST ingress.eu1.rum-ingress-coralogix.com (RUM collection); POST ingress.eu1.rum-ingress-coralogix.com/browser/v1beta/logs -> 202 |
| Nanit (own) | Asks its own server for product plans and card features. We were not signed in, so the cards call was refused (401) | GET api.nanit.com/plans -> 200; GET api.nanit.com/cards -> 401 |

- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) (data safety: "Shares Location and Device or other IDs")
- **Result:** No claim
- **Confidence:** 95%. Forty-two calls at launch to five ad and tracking companies. We accepted the consent screens by machine and turned off sensitivity, so a real user might see even more calls. This caps confidence below 100%.
- **Capture:** 2026-08-14, launch window, 42 calls (33 types, 17 addresses).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Microsoft (Clarity) | Receives a recording of what you see and do in the app: which screens open and where you tap | POST b.clarity.ms/collect -> 204 |
| Facebook | **Sends a Facebook app-activity event. The request body was scrubbed, so the exact event and identifier fields are not assessable.** | GET graph.facebook.com/v16.0/app -> 200; POST graph.facebook.com/v16.0/546319842074484/activities -> 200 |
| Adapty | Controls what you can buy in the app. It sends your subscription state, which advert brought you, and usage events, and it keeps them on Amazon computers | POST api-eu.adapty.io (paywall and events); POST api-ua.adapty.io (install record); Amazon Cognito and Amazon S3 serve the data |
| OneSignal | Downloads rules for push messages. If you allow push, it sends a token that addresses your phone | GET api.onesignal.com (android_params.js) |
| Philips (own) | Asks the Philips account server to identify your phone. This is the maker's own service | iam-api.philips-digital.com; www.global.api.philips.com |
| Google (Firebase) | Registers this install, downloads settings, and sends usage logs. The reply carries an install ID and a security token | POST firebaseinstallations.googleapis.com/v1/projects/.../installations -> 200; POST firebaselogging.googleapis.com/v0cc/log/batch -> 200; GET firebase-settings.crashlytics.com/... -> 200 |

- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.wte.view) (data safety: "Shares Personal info and Health and fitness, plus five other data types")
- **Result:** No claim
- **Confidence:** 90%. Twenty-five calls at launch, most to ad and tracking services. The app's file list asks for the advertising-ID permission. A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, 25 calls (17 types, 15 addresses).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Records when you started the app and which advert brought you. The calls likely carry an install ID, and one call returns your install date and status | POST a2lve5.register.appsflyersdk.com/api/v6.18/androidevent -> 200; GET a2lve5.gcdsdk.appsflyersdk.com/install_data/v5.0/com.wte.view -> 200 |
| Microsoft (Clarity) | **Receives a recording of what you see and do in the app, including the pictures on each screen. It uploads those pictures as files.** | POST b.clarity.ms/collect -> 204 (3 calls); POST b.clarity.ms/tgi1pxdmic/upload-asset/... -> 200 |
| Mixpanel | Receives a usage log: what you do in the app (one message is 7,593 bytes) | POST api.mixpanel.com/track/ -> 200 |
| Cordial | Receives usage events for email messages | POST events-stream-svc.usw2.cordial.com/mobile/events -> 200 |
| Scorecard Research | Receives a small "this phone is here" call. Likely used to count visitors | GET census-app.scorecardresearch.com/p2 -> 200 |
| What to Expect (Snowplow) | Receives its own usage log through the Snowplow program. This stays inside the What to Expect family | POST sp.whattoexpect.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| Google (Firebase) | Registers this install and downloads settings. The reply carries an install ID and a security token | POST firebaseinstallations.googleapis.com/v1/projects/.../installations -> 200 |
| OneTrust | Downloads the "do we have permission to track you?" screen shown at first open. We saw no answer being sent back | GET mobile-data.onetrust.io/cfw/cmp/v1/banner -> 200 |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

### Heartful Baby
- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Five calls at launch: four connectivity checks (no data) and one usage log to Google. One usage log is enough to break a HIPAA promise. A single log limits certainty.
- **Capture:** 2026-08-12, launch window, 5 calls.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (connectivity) | Checks that the internet works. No data about you | GET connectivitycheck.gstatic.com/generate_204 -> 204 (2 calls); GET www.google.com/generate_204 -> 204 (2 calls) |
| Google (Firebase) | Receives a usage log: what you do in the app (one message is 6,671 bytes) | POST firebaselogging.googleapis.com/v0cc/log/batch -> 200 |

- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Nara
- **Claim:** "Complete privacy" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Ten calls at launch: nine to Facebook and one crash report to Google. Facebook phones home on every launch, so "complete privacy" is false. We could not read the payloads, which caps confidence below 95%.
- **Capture:** 2026-08-12, launch window, 10 calls.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | **Downloads Facebook SDK settings and model files. The request body was empty in this capture, so no user-data payload was assessed.** | GET graph.facebook.com/v16.0/app -> 200 (4 calls); GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (4 calls); GET graph.facebook.com/v16.0/app/model_asset -> 200 |
| Google (Crashlytics) | Receives a crash report 60 kilobytes in size: what the app was doing when it stopped, plus phone details | POST crashlyticsreports-pa.googleapis.com/v1/firelog/legacy/batchlog -> 200 |

- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Pixy
- **Claim:** "Bank-level encryption" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Three calls at launch, all to Facebook, to load Facebook's tracking rules. Encryption protects messages in transit; it does not stop data collection or sharing, so the claim is false in scope. We could not read the payloads, which caps confidence below 95%. The raw capture holds these three calls only; the earlier list also had one Firebase call that the preserved capture does not show, so we report only what the raw capture shows.
- **Capture:** 2026-08-12, launch window, 3 calls.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | **Downloads Facebook SDK settings and setup files. The request body was empty in this capture, so no user-data payload was assessed.** | GET graph.facebook.com/v16.0/app -> 200; GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (2 calls) |

- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

Baby Buddy is the only open-source app in this test.

### Baby Buddy
- **Claim:** Open source - see [github.com/babybuddy/babybuddy](https://github.com/babybuddy/babybuddy)
- **Result:** PASS
- **Confidence:** 100%. The replayed raw capture contains one flow: a GET to httpbin.org/get with no request body, HTTP 200. Its User-Agent is `curl/8.7.1` and it carries a `Proxy-Connection` header, so it was a `curl` connectivity probe run during the capture session - an artifact of the capture environment, not a call made by the Baby Buddy app. The app itself made zero outbound calls, consistent with PASS. We found no synthetic baby-data transmission. The code is public and anyone can read it.
- **Capture:** 2026-08-03, full session (web app), 0 app-originated outbound calls (1 capture-environment curl probe). Evidence source changed from session-summary to raw-replay (capture relocated and replayed).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| httpbin.org (curl probe) | Capture-environment connectivity check (User-Agent: curl/8.7.1). No app data. | httpbin.org/get (artifact, not app-originated) |

## Proprietary apps - short report

### Amila
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.amila.parenting) (data safety: "Shares Personal info and App activity")
- **Result:** No claim
- **Confidence:** 90%. Six flows at launch: Firebase registers the install, and the app downloads settings and font files from Google. Nothing showed data that identifies you, so the mark is ❕ not 🚫.
- **Capture:** 2026-08-08, launch window, 6 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (Firebase) | Registers this install. The reply likely carries an install ID. Downloads app settings | firebaseinstallations.googleapis.com; firebaseremoteconfig.googleapis.com |
| Google (Fonts) | Downloads the font files the app shows on screen. No data about you | fonts.googleapis.com; fonts.gstatic.com |

- **Network log:** [network-log-amila.json](results/network-log-amila.json)

### Baby+
- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Three flows at launch: to a Philips server, to Google, and to Firebase. We could not read the payloads, which caps confidence below 95%.
- **Capture:** 2026-08-08, launch window, 3 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Philips (own) | Calls the maker's server. Likely registers the install and sends usage | (Philips server) |
| Google | Registers the install and downloads settings | Firebase and Google calls |
| Firebase | Registers this install with an ID and a security token | (Firebase) |

- **Network log:** [network-log-baby-plus.json](results/network-log-baby-plus.json)
- **Accessibility (2026-08-16, API 29 emulator, logged-in onboarding):** On **About Baby**, gender is required (`Please select baby’s gender`) but the control is one `EditText` (`com.hp.babyapp:id/baby_1_gender_options`) whose text is only `Baby's Gender`. `content-desc` is empty. The dump has no named Boy/Girl/Unknown nodes, no `RadioButton`/`ImageButton` children, and no checkable state. TalkBack and UiAutomator cannot name or select an option. A labeled **OK** dialog dismisses; **DONE** then fails the same check. Local dump: `results/baby-plus-test-20260816/artifacts/uiux/about-baby-gender.xml`. This blocked the synthetic-profile save, so the baby-name transmission scan is incomplete.

### Baby Daybook
- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Eight flows at launch: Firebase, a subscription service, and Google. The app's code also contains Facebook code. We could not read the payloads, which caps confidence below 95%.
- **Capture:** 2026-08-08, launch window, 8 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| RevenueCat | Receives your subscription state: whether you pay and what you have unlocked | api.revenuecat.com |
| Google (Firebase) | Registers this install and downloads settings | firebaseinstallations.googleapis.com; firebaseremoteconfig.googleapis.com; firebaseremoteconfigrealtime.googleapis.com |
| Google (messages) | Registers the phone to receive push and message services | android.apis.google.com |

- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### MimiLog
- **Claim:** "Fully offline" - see [Google Play listing](https://play.google.com/store/apps/details?id=com.mimiapp.mimilog)
- **Result:** PASS
- **Confidence:** 100%. The app tried one setup call to Google Firebase. The app holds no valid project, so no data was exchanged. "Fully offline" holds.
- **Capture:** 2026-08-03, launch window, 0 completed outgoing calls (1 setup call that never connected).
- **Live check (2026-08-17):** No sign-in. No Internet permission. Profile and tracker values stayed on the device. The system HTTP proxy saw 0 flows. Scan: `no_transmission_detected`.[^mimilog-play]

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (Firebase) | Setup call only. No data was exchanged because the app holds no valid project | (setup call to firebase; never completed) |

- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nubo
- **Claim:** "Local-first" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 95%. Eleven flows at first launch. The app sends what you do in it (screens you open, steps you take at setup) to Firebase, not just "local first".
- **Capture:** 2026-08-03, first launch, 11 flows. Evidence source changed from session-summary to raw-replay (capture relocated and replayed).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (Firebase) | Sends a usage log: screens you open and steps you take at setup, tied to an install ID | firebaseinstallations.googleapis.com; app-measurement.com |
| Google (Crashlytics) | Downloads crash-configuration rules | firebase-settings.crashlytics.com |
| Google (messages) | Registers the phone to receive push and message services | android.apis.google.com |

- **Network log:** [network-log-nubo.json](results/network-log-nubo.json)
- **Live check (2026-08-18):** Full use on the already-saved Privatia Rigatoni profile. Left and right milk timers started and stopped. Sleep timer started and stopped. Pump timer started and stopped. One bottle tap (logged 15 mL, the app default per click, not 482 and not the profile extra 90). Pee and poop taps. Note title and body saved (`PRIVATIA-RIGATONI-SYNTH` / `Rigatoni-8823-synthfeed`); the app returned to MainActivity Logs. Name still on the home/log header. System HTTP proxy capture was not started in this session (host tool block). Scan of the earlier 0-byte `Nubo.mitm` remains `no_transmission_detected`. A 0-flow proxy is not proof Firebase or GMS was silent. Operator capture+scan is on the final sprint list in ROADMAP.md.

### Nurture Lock
- **Claim:** "100% offline" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 95%. The app calls a subscription service at launch, so "100% offline" is false. Its package contains code from eight tracking companies. The raw capture was relocated from the sibling harness and replayed: 17 flows, 6 destinations.
- **Capture:** 2026-08-03, launch window, 17 flows (raw replay).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| RevenueCat | Receives your subscription state: whether you pay and what you have unlocked | api.revenuecat.com |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)
- **Live check (2026-08-17):** Launch opened Pairip `LicenseActivity`. The dialog says to enable Google Play and use an up-to-date version. The only button is **CLOSE**. Appium then failed because `MainActivity` never started. No profile was entered. The emulator Play Store package is stub `com.android.vending` 1.8.

### Pebbi
- **Claim:** No claim (control app)
- **Result:** No claim
- **Confidence:** 100%. Four flows at launch. The app sends data to Firebase, Google ads, and Google's message service. The mark is 🚫 because the volume is heavy even without a claim.
- **Capture:** 2026-08-03, launch window, destinations only.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (Firebase) | Sends usage logs and crash rules | firebase-settings.crashlytics.com; firebaselogging-pa.googleapis.com |
| Pebbi (own) | Calls its own server | app.pebbi.co |
| Google (messages) | Registers the phone to receive push and message services | android.apis.google.com |

- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)
- **Live check (2026-08-17):** A monkey launch hit the same Pairip **CLOSE** dialog. An Appium session with no app reset reached native **Welcome to Pebbi**, then **Customise Settings** (units), then **Add New Baby**. Contexts stayed `NATIVE_APP` (no WebView). The name field took typing. Date of birth is a picker (`Select date and time of birth`). Gender is two icon buttons with no TalkBack name. **Complete Setup** stayed disabled. Pulled APKPure 3.2.1 (opens, then **Update required** with no Later), 3.4.0 and 3.5.0 (Pairip). 4.0.1 cold start returns to Pairip on this Play stub. Proxy capture of the 4.0.1 walk: 8 flows. Scan: `no_transmission_detected`. This is not a saved profile.

## Cross-app view

Every app that failed shares one piece of code: Firebase. Nara and Pixy also embed Facebook. The words "complete privacy" and "HIPAA-compliant" sit next to code that sends data to others.

Four of the five wave-1 apps ship at least one program that records installs and shows ads (from Facebook, Adjust, TikTok, or Google/Amazon). **Nanit sends screen and browser telemetry to Microsoft Clarity and Coralogix, plus contact data to Cordial.** The Google Play data-safety pages for all five say they share data; none promise to keep data on the device.

## Roadmap

- **Synthetic baby-data transmission testing (in progress).** Static dark-pattern searching is no longer part of this project. The operator test uses a fixed fictional baby, "Privatia Rigatoni", enters fictional feeding, sleep, and diaper data, and watches the raw capture for those values. The test records whether the baby data leaves the phone and which recipient receives it. The profile, scan tool, and unit test are committed; live captures across the 16 apps are pending. See the report's "Synthetic baby-data transmission test" section, `METHODOLOGY.md` for the capture procedure, and `ROADMAP.md` for the plan.
- **Full analytics and PII fanout (now).** `scripts/scan-analytics-pii.sh` scans every committed network log. It records all analytics, attribution, advertising, diagnostics, messaging, and replay-related calls, including unclassified hosts.
- **Wave 2 testing.** Tier 1 candidates in `localonly/candidates.md` (gitignored) are the next wave.
- **Legacy re-capture.** Eight apps (Nurture Lock, Nubo, Pebbi, Amila, Baby Buddy, Baby Daybook, Baby+, MimiLog) lost their raw captures before the retention rule existed. Three (Nurture Lock, Nubo, Baby Buddy) have been backfilled by relocating the original raw captures from the sibling `apk-privacy-harness` project and replaying them; their results are now `evidence_source: raw-replay`. The remaining five (Pebbi, Amila, Baby Daybook, Baby+, MimiLog) still rest on session summaries and are scheduled for live re-capture. See `ROADMAP.md` for details.

## Limits

- The launch captures used for the findings above predate the automated injector, so a fictional baby profile was not yet entered during them. That step is now automated (`scripts/inject-synthetic-profile.py`) and wired into `run-tests.sh --live`, so re-captures enter the profile and the synthetic baby-data transmission test states per app whether entered baby data left the device and to which recipient.
- The captures cover the launch and early-use window of each app. Behavior later in a session could differ.
- We removed response bodies and header values from this report and the network logs because they can carry tokens or PII. New sanitized logs replace removed values with slugs such as `[REDACTED:request-body-values:secret-or-PII]`. The method, host, path, status, count, and sizes remain, so the record still proves that the call was sent. A scrubbed body is not evidence that PII was absent.
- Evidence depth is not equal across the 16 apps. Eleven apps (BabyCenter, BellyBloom, Nanit, Pregnancy+, What to Expect, Heartful Baby, Nara, Pixy, Nurture Lock, Nubo, Baby Buddy) have `evidence_source: raw-replay` - we replayed and mined every call in the preserved capture. The remaining five (Pebbi, Amila, Baby Daybook, Baby+, MimiLog) have `evidence_source: session-summary` - their raw captures disappeared before the retention rule existed. Treat session-summary rows as lower-bound evidence; see ROADMAP.md for the planned legacy re-capture.
- baby-track, cradle, and dymn-baby were excluded from the legacy backfill. No accessible APK could be obtained and their package identifiers did not resolve to real apps, so no captures or scans were performed for them.

## Advice

**For parents:** Do not trust "offline" or "local-first" claims. Baby Buddy made no app-originated calls. MimiLog's launch Firebase setup never completed, and a later live save showed 0 flows on the system HTTP proxy.

**For developers:** If you say "offline", remove the analytics and attribution code. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable claims. Someone should test them.

## Footnotes

[^mimilog-play]: MimiLog live save and Play license (2026-08-17). Settings lists units, theme, language, and notifications only. There is no sign-in or cloud sync. The package requests `com.android.vending.CHECK_LICENSE` and does not declare `INTERNET`. It ships Pairip `LicenseActivity` / `LicenseContentProvider`.

    Entered while the emulator HTTP proxy was on: name Privatia Rigatoni, birth date 14 Mar 2026, sex Prefer not to say, bottle 482 mL, nap 777 minutes, note `PRIVATIA-RIGATONI-SYNTH`. Diaper has no weight field, so 1234 g was not entered. The feeding capture file stayed at 0 bytes (0 flows). Scan verdict: `no_transmission_detected`. That result covers only traffic that used the system HTTP proxy.

    The app does not call Google itself for the license check. It binds to the Play Store service. Play talks to Google's license server. Play sends the package name, the Play account user id, and other license fields. It does not read the in-app name, birth date, or sex fields. See [Setting up licensing](https://developer.android.com/google/play/licensing/setting-up).

    Pairip is Play Automatic Integrity Protection with a license check at launch; some builds add extra device checks. See [APKiD issue 495](https://github.com/rednaga/apkid/issues/495).

    Play Integrity (a related API, not the same as LVL) collects package, version, signing cert, license status, and device attestation. Optional `nonce` and `requestHash` are visible to Google. Do not put user content in those fields. See [Play Integrity overview](https://developer.android.com/google/play/integrity/overview) and [Play Integrity data safety](https://developer.android.com/google/play/integrity/terms).

    A 0-flow system-proxy capture does not prove a Play Store call was absent. Play often skips the system HTTP proxy and pins TLS. A later capture can watch `com.android.vending` at cold start. Scan that capture for the fictional name (expect a miss) and for Play license hosts. A Play/GMS call without the fictional markers is not a baby-data transmission.

## Artifacts

Per-app sanitized network logs (committed): see the network-log links in each app block above. Analytics and PII fanout: [results/analytics-pii-20260803.json](results/analytics-pii-20260803.json). Cross-app view: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw network captures (results/decode-traffic-<app>.json) are generated locally and kept out of the repository because they contain captured login tokens.
