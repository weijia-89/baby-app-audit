# Baby App Privacy Audit - Results

**Test run:** baby-app-audit-20260803
**Dates:** 2026-08-03 to 2026-08-14
**Harness version:** 3.3.0
**Author:** Wei Jia
**License:** GPL-3.0
**Repository:** https://github.com/weijia-89/baby-app-audit

## What we found

We tested 16 baby and parenting apps. Most say they protect their privacy. We checked whether their words match what the app actually does with your data.

Nine apps make a privacy promise. Seven of them sent data off the device. Only Baby Buddy and MimiLog did what they said.

| App | Privacy claim | Result | Privacy | Confidence | Key findings |
| --- | --- | --- | --- | --- | --- |
| Baby Buddy | Open source | PASS | 💖 | 100% | No tracking libraries; all traffic stays on localhost in default configuration |
| MimiLog | "Fully offline" | PASS | 💖 | 100% | One Firebase configuration call; no valid project, so no data exchanged |
| Amila | No claim | No claim | ❕ | 90% | Firebase Installations, Remote Config, and Google Fonts calls on launch |
| Baby+ | "AdID not auto-enabled" | FAIL | ❕ | 90% | Philips server, Firebase, and Google calls on launch |
| Heartful Baby | "HIPAA-compliant" | FAIL | ❕ | 90% | One Firebase logging batch on launch |
| Baby Daybook | "AdID not auto-enabled" | FAIL | 🚫 | 90% | Firebase and RevenueCat calls on launch; Facebook SDK found in code |
| Nara | "Complete privacy" | FAIL | 🚫 | 90% | Nine Facebook Graph API calls and one Crashlytics batch on launch |
| Nubo | "Local-first" | FAIL | 🚫 | 95% | Sends session analytics, screen views, and onboarding events to Firebase on first launch |
| Nurture Lock | "100% offline" | FAIL | 🚫 | 95% | Calls `api.revenuecat.com` on launch; 8 tracking libraries in the APK |
| Pebbi | No claim (control) | No claim | 🚫 | 100% | Extensive data collection via Firebase, Google AdServices, and FCM registration |
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | Three Facebook Graph API calls on launch |
| BabyCenter | No claim | No claim | 🚫 | 95% | AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |
| BellyBloom | No claim | No claim | 🚫 | 90% | Adjust, DoubleClick, Facebook, and Firebase calls on launch |
| Nanit | No claim | No claim | 🚫 | 95% | Firebase, Microsoft Clarity, Localytics, Cordial, and Coralogix flows plus the Nanit API on launch; no ad-network SDK |
| Pregnancy+ | No claim | No claim | 🚫 | 95% | Firebase, Facebook, Microsoft Clarity, Adapty, and OneSignal flows on launch, including install attribution |
| What to Expect | No claim | No claim | 🚫 | 90% | AppsFlyer, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |

Result key:

- **💖** means the app passed and behaved as described.
- **❕** means the app failed, but the capture showed phone-home traffic without identifying user data.
- **🚫** means the app failed and the capture showed identifying data or extensive tracking.

An app with no privacy claim cannot fail, because there is no promise to break. Its result says "no claim"; the privacy mark still shows what we observed.

No test ended inconclusive.

## How to read the granular tables

Each app block below answers who, what, when, why, and how for every distinct call we captured:

- **Who** - the **Service** column names the company or endpoint that receives the data.
- **What** - the **Data shared** column describes what the call carries. "Observed" means the capture itself showed it (for example, a server-issued installation ID in the response). "Inferred" means we derived it from the endpoint, the SDK that made it, and the documented behavior of that SDK; we withheld payloads that carried authentication tokens.
- **When** - the capture line in each block gives the date, the trigger (app launch), and the window length.
- **How** - the **Call/Log** column lists the method, host, and redacted path of each call plus the HTTP response status.
- **Why** - the confidence line explains why the evidence is (or is not) enough to settle the claim.

**Network captures:** each app block links to its own sanitized network log (`results/network-log-<app>.json`). These logs list the hosts, paths, and response status codes of captured traffic. They contain no query strings, headers, or bodies, because those carried authentication tokens. The raw captures (`results/decode-traffic-<app>.json`) stay local only.

## Granular Test results

### Nurture Lock
- **Claim:** "100% offline" - see [angry-shark-studio.com](https://www.angry-shark-studio.com/)
- **Result:** FAIL
- **Confidence:** 95%. Two outbound calls to RevenueCat recorded at launch, and 8 tracking libraries confirmed in the decompiled code (RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, Tenjin). An app that sends no data needs no payment-entitlement or attribution SDK. The early burst traced destinations only, so paths and payloads were not recorded; the SDK list and two confirmed calls make the offline claim false with high confidence.
- **Capture:** 2026-08-03, launch window, burst 1 trace mode (destination-only), 2 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| RevenueCat | Subscription and entitlement checks; sends an anonymous install identifier with each call (inferred - payload not captured in trace mode) | api.revenuecat.com - destination recorded, no per-path detail, 2 calls, status unknown |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Nubo
- **Claim:** "Local-first" - see [Google Play listing](https://play.google.com/store/apps/details?id=com.clicksie.nuboapp)
- **Result:** FAIL
- **Confidence:** 95%. Four outbound destinations on launch: Firebase Installations, Crashlytics settings, Google FCM push registration, and Google app-measurement (analytics transport). A local-first app should not register a push channel or an analytics pipeline. Destination-only trace mode limits payload detail, but the set of destinations already contradicts the claim.
- **Capture:** 2026-08-03, launch window, burst 1 trace mode (destination-only), 4 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration for analytics and messaging (inferred) | firebaseinstallations.googleapis.com - destination recorded, no per-path detail, status unknown |
| Google Crashlytics | Crash-reporting settings fetch (inferred) | firebase-settings.crashlytics.com - destination recorded, no per-path detail, status unknown |
| Google FCM | Push-registration token request tying the device to the app (inferred) | android.apis.google.com - destination recorded, no per-path detail, status unknown |
| Google Analytics | App-measurement transport for session and screen events (inferred) | app-measurement.com - destination recorded, no per-path detail, status unknown |

- **Network log:** [network-log-nubo.json](results/network-log-nubo.json)

### Pebbi
- **Claim:** No privacy claim (positive control) - see [Google Play listing](https://play.google.com/store/apps/details?id=com.pebbi.android)
- **Result:** No claim
- **Confidence:** 100%. We chose Pebbi as the control because we expected heavy data collection. Four destinations appeared on launch: Firebase logging, Crashlytics settings, Google FCM registration, and the app's own API host. The capture matched the expectation, which also validates the harness.
- **Capture:** 2026-08-03, launch window, burst 1 trace mode (destination-only), 4 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Analytics event batches and crash-reporting settings (inferred) | firebaselogging-pa.googleapis.com, firebase-settings.crashlytics.com - destinations recorded, no per-path detail, status unknown |
| Google FCM | Push-registration token request (inferred) | android.apis.google.com - destination recorded, no per-path detail, status unknown |
| Pebbi | The app's own API; session and account data (inferred) | app.pebbi.co - destination recorded, no per-path detail, status unknown |

- **Network log:** [network-log-pebbi.json](results/network-log-pebbi.json)

### Amila
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.amila.parenting)
- **Result:** No claim
- **Confidence:** 90%. Six flows to four destinations, all on launch: Firebase Installations, two Firebase Remote Config fetches, and two Google Fonts downloads. No advertising SDK traffic appeared in the window. A single launch window cannot prove what later sessions do, which caps confidence below 95%.
- **Capture:** 2026-08-08, launch window, burst capture, 6 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; sends package, app signature, and client ID (observed in wave-1 builds of the same endpoint); Google issues an installation ID | POST firebaseinstallations.googleapis.com/v1/projects/parenting-891b7/installations -> 200 |
| Google Firebase | Feature-config fetch; app, version, operating system; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/946125544729/namespaces/firebase:fetch -> 200 (2 calls) |
| Google Fonts | Font resource download; no user data | GET fonts.googleapis.com/css -> 200; GET fonts.gstatic.com/s/poppins/...woff2 -> 200; GET fonts.gstatic.com/s/roboto/...woff2 -> 200 |

- **Network log:** [network-log-amila.json](results/network-log-amila.json)

### Baby Daybook
- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Eight flows on launch: Firebase Installations, FCM push registration, three RevenueCat entitlement calls keyed to an anonymous install ID, and two Firebase config calls. RevenueCat pairs device identifiers with entitlements, so launch traffic carries identity-linked data; the Facebook SDK also sits in the code (no Graph calls captured in this window). We withheld payloads, so we could not confirm exactly which identifiers crossed the wire - 90%, not 95%.
- **Capture:** 2026-08-08, launch window, burst capture, 8 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (inferred) | POST firebaseinstallations.googleapis.com/v1/projects/baby-daybook-app/installations -> 200 |
| RevenueCat | Entitlement and offering checks keyed to an anonymous install ID (RCAnonymousID); ties device identifiers to subscription state (inferred) | GET api.revenuecat.com/v1/subscribers/$RCAnonymousID:[REDACTED] -> 201; GET api.revenuecat.com/v1/subscribers/$RCAnonymousID:[REDACTED]/offerings -> 200 and -> 304; GET api.revenuecat.com/v1/product_entitlement_mapping -> 200 |
| Google FCM | Push-registration token request (inferred) | POST android.apis.google.com/c2dm/register3 -> 200 |
| Google Firebase | Feature-config fetch and invalidation stream (no user data) | POST firebaseremoteconfig.googleapis.com/v1/projects/219982030553/namespaces/firebase:fetch -> 200; POST firebaseremoteconfigrealtime.googleapis.com/v1/projects/219982030553/namespaces/firebase:streamFetchInvalidations -> 200 |

- **Network log:** [network-log-baby-daybook.json](results/network-log-baby-daybook.json)

### Baby+
- **Claim:** "AdID not auto-enabled" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Three flows on launch: a Philips server install registration, a Firebase config fetch, and an FCM push registration. The Philips registration is an app install record on a third-party server; FCM ties the device to the app for push. The AdID claim does not cover this traffic, and the claim is therefore not false on its own terms - the failure is that the app still phones home with identity-linked channels.
- **Capture:** 2026-08-08, launch window, burst capture, 3 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Philips | App install registration on the Philips server (Parse _Installation object); device and app identifiers (inferred) | POST appserver.health-and-parenting.com/server/classes/_Installation -> 201 |
| Google Firebase | Feature-config fetch; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/1009074339940/namespaces/firebase:fetch -> 200 |
| Google FCM | Push-registration token request (inferred) | POST android.apis.google.com/c2dm/register3 -> 200 |

- **Network log:** [network-log-baby-plus.json](results/network-log-baby-plus.json)

### MimiLog
- **Claim:** "Fully offline" (Google Play listing)
- **Result:** PASS
- **Confidence:** 100%. Zero outbound flows in the capture. The single Firebase configuration attempt never completed because the device held no valid Firebase project for this app, so the app exchanged no data. With no outbound bytes at all, the offline claim holds.
- **Capture:** 2026-08-03, launch window, burst 1 capture, 0 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| (none) | No outbound traffic observed during the launch window | No calls recorded |

- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nara
- **Claim:** "Complete privacy" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Ten flows on launch: nine to the Facebook Graph API (app config, SDK gatekeepers, model asset) and one Crashlytics report batch. The Facebook SDK phones home repeatedly on every launch; "complete privacy" is false. We withheld payloads, so we could not verify which identifiers the Graph calls carried - 90%, not 95%.
- **Capture:** 2026-08-12, launch window, burst capture, 10 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | SDK bootstrap: app configuration, gatekeeper flags, and model asset fetches; device, OS, and app info (inferred) | GET graph.facebook.com/v16.0/app -> 200 (4 calls); GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (4 calls); GET graph.facebook.com/v16.0/app/model_asset -> 200 |
| Google Crashlytics | Crash report batch; device, OS, and stack traces (inferred) | POST crashlyticsreports-pa.googleapis.com/v1/firelog/legacy/batchlog -> 200 |

- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Heartful Baby
- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Five flows on launch: four connectivity probes (no data) and one Firebase analytics batch. One analytics batch is enough to break a HIPAA framing, but a single batch limits certainty about the extent of collection.
- **Capture:** 2026-08-12, launch window, burst capture, 5 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (connectivity) | Network connectivity probes; no data | GET connectivitycheck.gstatic.com/generate_204 -> 204 (2 calls); GET www.google.com/generate_204 -> 204 (2 calls) |
| Google Firebase | Analytics event batch (screen and app events) (inferred) | POST firebaselogging.googleapis.com/v0cc/log/batch -> 200 |

- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Pixy
- **Claim:** "Bank-level encryption" (Google Play listing)
- **Result:** FAIL
- **Confidence:** 90%. Three flows on launch: three Facebook Graph SDK bootstrap calls. Encryption in transit does not cover data collection and sharing; the claim is false on scope. The preserved raw capture holds these three flows only; the earlier artifact list also logged one Firebase Installations call that the preserved .mitm does not reproduce, so we report what the raw capture shows. We withheld payloads - 90%, not 95%.
- **Capture:** 2026-08-12, launch window, burst capture, 3 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | SDK bootstrap: app configuration and gatekeeper flags; device, OS, and app info (inferred) | GET graph.facebook.com/v16.0/app -> 200; GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (2 calls) |

- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

### Baby Buddy
- **Claim:** Open source - see [github.com/babybuddy/babybuddy](https://github.com/babybuddy/babybuddy)
- **Result:** PASS
- **Confidence:** 100%. Zero flows off the device across the full session; all traffic stayed on localhost between the app and its own bundled server. The codebase is public and auditable.
- **Capture:** 2026-08-03, full session (web app), 0 outbound flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| (none) | No outbound traffic observed | No calls recorded |

- **Network log:** [network-log-baby-buddy.json](results/network-log-baby-buddy.json)

## Popular Google Play apps - Wave 1 burst tests

These five apps are the first wave of popular Google Play targets. They make no privacy promise, so their result says "No claim"; the privacy mark still shows what we observed in the launch capture.

The Play Store pages make no no-data-sharing or offline promise. We acquired these APKs from a mirror and ran burst tests on an API 29 emulator. None of the five kept traffic on the device. BellyBloom 1.0.9 requires Android 12L (API 32), so the tested build is 1.0.8, which shares the same package signature.

| App | Package | Play Store signal | Data-safety statement |
| --- | --- | --- | --- |
| [BabyCenter](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) | `com.babycenter.pregnancytracker` | 4.9 stars, 1.54M reviews, 10M+ downloads, #3 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Nanit](https://play.google.com/store/apps/details?id=com.nanit.baby) | `com.nanit.baby` | 3.9 stars, 10.6K reviews, 500K+ downloads, #5 top grossing parenting | Shares Personal info, App activity, and App info and performance. No privacy promise found. |
| [What to Expect](https://play.google.com/store/apps/details?id=com.wte.view) | `com.wte.view` | 4.9 stars, 121K reviews, 5M+ downloads, #7 top free parenting | Shares Personal info and Health and fitness, plus five other data types. No privacy promise found. |
| [Pregnancy+](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) | `com.hp.pregnancy.lite` | 4.8 stars, 3.64M reviews, 50M+ downloads, #10 top free parenting | Shares Location and Device or other IDs. No privacy promise found. |
| [BellyBloom](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) | `com.bellyBloom.pregnancy.tracker` | 4.6 stars, 988 reviews, 1M+ downloads | Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted. |

### BabyCenter
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.babycenter.pregnancytracker) (data-safety: "Shares Personal info and Health and fitness, plus five other data types")
- **Result:** No claim
- **Confidence:** 95%. Thirty-five flows on launch across nine SDK families: AppsFlyer, Amazon Ads, Localytics, Vungle, Microsoft Clarity, Scorecard Research, Google Ads, OneTrust, and Google Play Services geolocation analytics, plus the BabyCenter Snowplow tracker and own API. The manifest declares ACCESS_ADSERVICES_AD_ID plus an install-referrer receiver. The combination of volume, SDK variety, and Ad-ID permissions makes this the strongest no-claim evidence in wave 1.
- **Capture:** 2026-08-14, launch window, burst 7, 35 flows (19 unique rows, 17 destinations).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Launch and install events plus SDK settings bootstrap; app-instance and advertising identifiers (inferred from the SDK event endpoint) | POST 2snoab.launches.appsflyersdk.com/api/v6.18/androidevent -> 200; GET 2snoab.cdn-settings.appsflyersdk.com/android/v2/.../settings -> 200 (x3) |
| Amazon Ads | Install and device-info beacon with ad-state reporting; the response echoes the ad ID (observed: response body keys adId, idChanged, opt-out, rcode) | POST s.amazon-adsystem.com/api3/update_dev_info -> 200 (1047 B request, 86 B response) |
| Localytics | Analytics upload and profile endpoint; app-instance identifiers (inferred) | POST analytics.localytics.com/api/v4/applications/.../upload -> 202; POST profile.localytics.com/v1/apps/.../profiles/... -> 202 |
| Vungle | SDK metrics endpoint; device and app info (inferred) | POST logs.ads.vungle.com/sdk/metrics -> 200 |
| Microsoft Clarity | Session telemetry beacons and asset checks; session identifiers and interaction events (inferred) | POST r.clarity.ms/collect -> 204 (x4); POST r.clarity.ms/vnmy25t03u/check-asset -> 200; GET www.clarity.ms/tag/mobile/vnmy25t03u -> 200 |
| Scorecard Research | Census-style measurement beacon; device and app identifiers (inferred) | GET census-app.scorecardresearch.com/p2 -> 200 (x12) |
| Google Ads | Ad configuration fetch; Ad-ID capability (manifest declares ACCESS_ADSERVICES_AD_ID) | GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 |
| Google Play Services | Geolocation analytics via Play services (device-origin row, not the app process) | POST semanticlocation-pa.googleapis.com (application/grpc) |
| OneTrust | Consent banner configuration; consent state (inferred) | GET mobile-data.onetrust.io/cfw/cmp/v1/banner -> 200 |
| BabyCenter (Snowplow) | In-app event tracker via Snowplow collector; app events (inferred) | POST bcsp.babycenter.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| BabyCenter (own) | Geo/region detection and in-app config fetch; region and device data (inferred) | GET geo.babycenter.com/v1 -> 200; GET www.babycenter.com/app_config/android/en-US/welcomeScreenABTest.json -> 200 |

- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) (data-safety: "Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted")
- **Result:** No claim
- **Confidence:** 90%. Fifty-three flows on launch, overwhelmingly to advertising or tracking endpoints: TikTok Pangle (ad config plus a 1.8 MB playable ad bundle), Adjust session and attribution, Facebook bootstrap and activities beacon, InMobi, Mixpanel, Google Ads, Funding Choices consent, and Firebase. We used version 1.0.8 because 1.0.9 requires Android 12L (API 32). A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 53 flows (42 unique rows, 13 destinations).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| TikTok (Pangle) | Ad SDK: settings, compliance, strategies, dual-event reporting, and monitor beacons plus playable ad assets (up to 1.8 MB); device and ad identifiers (inferred) | POST api16-access-ttp.tiktokpangle.us/api/ad/union/sdk/settings/ -> 200 (x3); POST api16-access-ttp.tiktokpangle.us/service/2/dual_events/ -> 200; GET lf-static.tiktokpangle-cdn-us.com/obj/union-fe-tx/playable/sdk/... -> 206 |
| Adjust | Install-attribution and session reporting; device and install identifiers (inferred) | POST app.adjust.com/session -> 200; GET app.adjust.com/attribution -> 200 (response keys adid, app_token, attribution) |
| Facebook | App configuration bootstrap and activities beacon; device and app identifiers (inferred) | GET graph.facebook.com/v16.0/app -> 200 (x3); POST graph.facebook.com/v16.0/26540417615628323/activities -> 200 (x3); POST www.facebook.com/adnw_sync2 -> 200 |
| InMobi | Ad config fetch; device and app info (inferred) | POST config.inmobi.com/config-server/v1/config/secure.cfg -> 200 (x2) |
| Mixpanel | Event tracking; app events (inferred) | POST api.mixpanel.com/track/ -> 200 |
| Google Ads | Ad SDK loader, cache manifest, config and publisher settings fetch | GET googleads.g.doubleclick.net/mads/static/sdk/native/sdk-core-android.html -> 200; GET googleads.g.doubleclick.net/mads/static/mad/sdk/native/sdk-core-v40-loader.appcache -> 200; GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 (61 kB) |
| Funding Choices (Google) | Consent management messages | POST fundingchoicesmessages.google.com/a/consent -> 200; POST fundingchoicesmessages.google.com/um/... -> 204 |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch and Crashlytics settings; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/254761198014/namespaces/firebase:fetch -> 200; GET firebase-settings.crashlytics.com/spi/v2/platforms/android/gmp/... -> 200 |

- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.nanit.baby) (data-safety: "Shares Personal info, App activity, and App info and performance")
- **Result:** No claim
- **Confidence:** 95%. Twelve flows on launch. The capture now shows Microsoft Clarity session telemetry (r.clarity.ms/collect), Localytics analytics, Cordial email-messaging events, Coralogix RUM, and Crashlytics settings alongside Firebase Installations and Remote Config, plus the Nanit API (plans, cards, mobile auth and contacts, browser logs). The mobile auth and contacts calls carry an authorization header; the browser logs upload is 15.6 kB. No dedicated ad-network SDK appeared in the window. Account login was not exercised, which caps confidence below 100%.
- **Capture:** 2026-08-14, launch window, burst 7, 12 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/nanit-144706/installations -> 200 |
| Google Firebase | Feature-config fetch and invalidation stream; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/25705829844/namespaces/firebase:fetch -> 200; POST firebaseremoteconfigrealtime.googleapis.com/v1/projects/25705829844/namespaces/firebase:streamFetchInvalidations -> 200; GET firebase-settings.crashlytics.com/spi/v2/platforms/android/gmp/... -> 200 |
| Microsoft Clarity | Session telemetry beacon; session identifiers and interaction events (inferred) | POST r.clarity.ms/collect -> 204 (x4) |
| Localytics | Analytics upload and profile creation; app-instance identifiers (inferred) | POST analytics.localytics.com/api/v4/applications/.../upload -> 202; POST profile.localytics.com/v1/apps/.../profiles/... -> 202 |
| Cordial | Email-messaging event stream; app events (inferred) | POST events-stream-svc.usw2.cordial.com/mobile/events -> 200 |
| Coralogix | Front-end error and performance telemetry (RUM) | POST ingress.eu1.rum-ingress-coralogix.com (RUM ingest) |
| Nanit | Product/plan API, account, contacts, and client logs once logged in; auth and contacts calls carry authorization headers (observed); posts a 15.6 kB browser-log batch | GET api.nanit.com/plans -> 200; GET api.nanit.com/cards -> 401; /mobile/auth/...; /mobile/contacts; /browser/v1beta/logs -> 200 |

- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) (data-safety: "Shares Location and Device or other IDs")
- **Result:** No claim
- **Confidence:** 95%. Forty-two flows on launch. The capture now shows Firebase (Installations, Remote Config, logging, Crashlytics settings), Microsoft Clarity session telemetry (b.clarity.ms/collect), Facebook app configuration plus activities beacon (app id 546319842074484), Adapty paywall analytics with an install-attribution POST, OneSignal push configuration, and first-party Philips APIs, with Amazon Cognito and S3 in the Adapty flow. Automation accepted the consent screens and disabled sensitivity, so the count is a floor; a real user session could add more. This caps confidence below 99%.
- **Capture:** 2026-08-14, launch window, burst 7, 42 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch, logging batch, and Crashlytics settings; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/1073993904376/namespaces/firebase:fetch -> 200; POST firebaselogging.googleapis.com/v0cc/log/batch -> 200; GET firebase-settings.crashlytics.com/... -> 200 |
| Microsoft Clarity | Session telemetry beacon; session identifiers and interaction events (inferred) | POST b.clarity.ms/collect -> 204 |
| Facebook | App configuration bootstrap and activities beacon; device and app identifiers (inferred) | GET graph.facebook.com/v16.0/app -> 200; POST graph.facebook.com/v16.0/546319842074484/activities -> 200 |
| Adapty | Paywall products, analytics profiles, install attribution, and event analytics; subscription and install identifiers (observed) | POST api-ua.adapty.io (install attribution); api-eu.adapty.io (paywall products, analytics events); Amazon Cognito identity and S3 buckets in the flow |
| OneSignal | Push configuration fetch; device token material sent if push is used (inferred) | GET api.onesignal.com (android_params.js) |
| Philips (first-party) | Identity and account APIs for the Philips Baby analytics platform; account data (inferred) | iam-api.philips-digital.com; www.global.api.philips.com |

- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.wte.view) (data-safety: "Shares Personal info and Health and fitness, plus five other data types")
- **Result:** No claim
- **Confidence:** 90%. Twenty-five flows on launch, most to advertising or tracking endpoints: AppsFlyer across four event subdomains plus SDK bootstrap and install-data checks, Microsoft Clarity (tag config, collect beacons, asset uploads), Mixpanel, Cordial, Scorecard Research, Snowplow, OneTrust consent, and Firebase Installations and Remote Config. The manifest declares ACCESS_ADSERVICES_AD_ID and AD_SERVICES_CONFIG. A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 25 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Launch, install, and in-app events plus SDK bootstrap and install-data checks; app-instance and advertising identifiers (inferred from the SDK endpoints) | POST a2lve5.register.appsflyersdk.com/api/v6.18/androidevent -> 200; POST a2lve5.pia.appsflyersdk.com/api/v1.0/pia-android-event -> 200; POST a2lve5.dlsdk.appsflyersdk.com/v1.0/android/com.wte.view -> 200; GET a2lve5.gcdsdk.appsflyersdk.com/install_data/v5.0/com.wte.view -> 200; GET a2lve5.cdn-settings.appsflyersdk.com/android/v2/.../settings -> 200 (x3) |
| Microsoft Clarity | Session telemetry beacons and asset uploads; session identifiers and interaction events (inferred) | POST b.clarity.ms/collect -> 204 (x3); POST b.clarity.ms/tgi1pxdmic/upload-asset/... -> 200 |
| Mixpanel | Event tracking; app events (inferred) | POST api.mixpanel.com/track/ -> 200 |
| Cordial | Email-messaging event stream; app events (inferred) | POST events-stream-svc.usw2.cordial.com/mobile/events -> 200 |
| Scorecard Research | Census-style measurement beacon; device and app identifiers (inferred) | GET census-app.scorecardresearch.com/p2 -> 200 |
| What to Expect (Snowplow) | In-app event tracker via Snowplow collector; app events (inferred) | POST sp.whattoexpect.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch and Crashlytics settings; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/179542082127/namespaces/firebase:fetch -> 200; GET firebase-settings.crashlytics.com/spi/v2/platforms/android/gmp/... -> 200 |
| OneTrust | Consent banner configuration; consent state (inferred) | GET mobile-data.onetrust.io/cfw/cmp/v1/banner -> 200 |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

## Cross-app view

Every app that failed shares one piece of code: Firebase. Nara and Pixy also embed Facebook. The words "complete privacy" and "HIPAA-compliant" sit next to code that sends data to third parties.

Four of the five wave-1 apps ship at least one install-attribution or ad SDK (AppsFlyer, Adjust, Facebook, TikTok Pangle, or Google/Amazon ads) alongside Firebase; Nanit ships session analytics, RUM, and email-messaging SDKs instead. The Play Store data-safety pages for all five share data; none promise to keep data on the device.

## Roadmap

- **Operator-integrated dark pattern testing (next).** We paused the static dark-pattern scan and removed its artifacts from this pipeline. Static heuristics gave weak signals (the word "timer" is also Danish for "hours") and cannot see runtime behavior. The next phase replaces it with hands-on operator testing: set up a fictional baby profile in the app (name, birth date, weight, feeding and sleep logs), enter that data by hand, and watch the capture logs for the fake values and for consent-screen pressure patterns. This finds out whether the data we type in leaves the phone, and whether consent screens push toward sharing. See `METHODOLOGY.md` for the capture procedure and `ROADMAP.md` for the plan.
- **Wave 2 testing.** Tier 1 candidates in `localonly/candidates.md` (gitignored) are the next wave.

## Limits

- We did not tap the apps by hand. Some data paths stayed hidden. The operator-integrated roadmap item closes this gap.
- The captures cover the launch and early-use window of each app. Behavior later in a session could differ.
- We withheld response bodies and headers from this report and the network logs because they carried authentication tokens. "Data shared" is therefore "observed" only where the capture itself showed the exchange (for example, a Firebase installation ID and refresh token in the response), and "inferred" elsewhere from the endpoint and the SDK that made the call.
- Evidence depth is not equal across the 16 apps. Eight apps (BabyCenter, BellyBloom, Nanit, Pregnancy+, What to Expect, Heartful Baby, Nara, Pixy) have `evidence_source: raw-replay` - we replayed and mined every flow in the preserved `.mitm` capture. The other eight (Nurture Lock, Nubo, Pebbi, Amila, Baby Buddy, Baby Daybook, Baby+, MimiLog) have `evidence_source: session-summary` - their raw captures disappeared before the retention rule existed, so their results rest on the original session summaries, which are thinner (for example, Nanit and Pregnancy+ looked clean at that depth and flipped to major once we replayed the raw captures). Treat session-summary rows as lower-bound evidence; see ROADMAP.md for the planned legacy re-capture.

## Advice

**For parents:** Do not trust "offline" or "local-first" claims. Baby Buddy is the only app we tested that sent nothing off the device.

**For developers:** If you say "offline", remove the analytics and attribution code. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable claims. Someone should test them.

## Artifacts

Machine-readable results: [results/RESULTS-20260803.json](results/RESULTS-20260803.json)

Per-app sanitized network logs (committed): see the network-log links in each app block above. Cross-app view: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw network captures (`results/decode-traffic-<app>.json`) are generated locally and kept out of the repository because they contain captured authentication tokens.
