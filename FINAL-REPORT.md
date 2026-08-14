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
| Pixy | "Bank-level encryption" | FAIL | 🚫 | 90% | Three Facebook Graph API calls and one Firebase Installations registration |
| BabyCenter | No claim | No claim | 🚫 | 95% | AppsFlyer, DoubleClick, Microsoft Clarity, Scorecard Research, and Firebase calls on launch |
| BellyBloom | No claim | No claim | 🚫 | 90% | Adjust, DoubleClick, Facebook, and Firebase calls on launch |
| Nanit | No claim | No claim | ❕ | 90% | Firebase Installations and Remote Config plus the Nanit API on launch; no ad SDK traffic |
| Pregnancy+ | No claim | No claim | ❕ | 90% | Firebase Installations and Remote Config on launch; no ad SDK traffic |
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
- **Result:** FAIL (95% confidence)
- **Confidence:** 95%. Two outbound calls to RevenueCat recorded at launch, and 8 tracking libraries confirmed in the decompiled code (RevenueCat, Mixpanel, Firebase, AppsFlyer, Adjust, OneSignal, CleverTap, Tenjin). An app that sends no data needs no payment-entitlement or attribution SDK. The early burst traced destinations only, so paths and payloads were not recorded; the SDK list and two confirmed calls make the offline claim false with high confidence.
- **Capture:** 2026-08-03, launch window, burst 1 trace mode (destination-only), 2 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| RevenueCat | Subscription and entitlement checks; sends an anonymous install identifier with each call (inferred - payload not captured in trace mode) | api.revenuecat.com - destination recorded, no per-path detail, 2 calls, status unknown |

- **Network log:** [network-log-nurture-lock.json](results/network-log-nurture-lock.json)

### Nubo
- **Claim:** "Local-first" - see [Google Play listing](https://play.google.com/store/apps/details?id=com.clicksie.nuboapp)
- **Result:** FAIL (95% confidence)
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
- **Result:** No claim (100% confidence)
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
- **Result:** No claim (90% confidence)
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
- **Result:** FAIL (90% confidence)
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
- **Result:** FAIL (90% confidence)
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
- **Result:** PASS (100% confidence)
- **Confidence:** 100%. Zero outbound flows in the capture. The single Firebase configuration attempt never completed because the device held no valid Firebase project for this app, so the app exchanged no data. With no outbound bytes at all, the offline claim holds.
- **Capture:** 2026-08-03, launch window, burst 1 capture, 0 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| (none) | No outbound traffic observed during the launch window | No calls recorded |

- **Network log:** [network-log-mimilog.json](results/network-log-mimilog.json)

### Nara
- **Claim:** "Complete privacy" (Google Play listing)
- **Result:** FAIL (90% confidence)
- **Confidence:** 90%. Ten flows on launch: nine to the Facebook Graph API (app config, SDK gatekeepers, model asset) and one Crashlytics report batch. The Facebook SDK phones home repeatedly on every launch; "complete privacy" is false. We withheld payloads, so we could not verify which identifiers the Graph calls carried - 90%, not 95%.
- **Capture:** 2026-08-12, launch window, burst capture, 10 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | SDK bootstrap: app configuration, gatekeeper flags, and model asset fetches; device, OS, and app info (inferred) | GET graph.facebook.com/v16.0/app -> 200 (4 calls); GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (4 calls); GET graph.facebook.com/v16.0/app/model_asset -> 200 |
| Google Crashlytics | Crash report batch; device, OS, and stack traces (inferred) | POST crashlyticsreports-pa.googleapis.com/v1/firelog/legacy/batchlog -> 200 |

- **Network log:** [network-log-nara.json](results/network-log-nara.json)

### Heartful Baby
- **Claim:** "HIPAA-compliant" (Google Play listing)
- **Result:** FAIL (90% confidence)
- **Confidence:** 90%. Five flows on launch: four connectivity probes (no data) and one Firebase analytics batch. One analytics batch is enough to break a HIPAA framing, but a single batch limits certainty about the extent of collection.
- **Capture:** 2026-08-12, launch window, burst capture, 5 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google (connectivity) | Network connectivity probes; no data | GET connectivitycheck.gstatic.com/generate_204 -> 204 (2 calls); GET www.google.com/generate_204 -> 204 (2 calls) |
| Google Firebase | Analytics event batch (screen and app events) (inferred) | POST firebaselogging.googleapis.com/v0cc/log/batch -> 200 |

- **Network log:** [network-log-heartful-baby.json](results/network-log-heartful-baby.json)

### Pixy
- **Claim:** "Bank-level encryption" (Google Play listing)
- **Result:** FAIL (90% confidence)
- **Confidence:** 90%. Four flows on launch: three Facebook Graph SDK bootstrap calls and one Firebase Installations registration. Encryption in transit does not cover data collection and sharing; the claim is false on scope. We withheld payloads - 90%, not 95%.
- **Capture:** 2026-08-12, launch window, burst capture, 4 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Facebook | SDK bootstrap: app configuration and gatekeeper flags; device, OS, and app info (inferred) | GET graph.facebook.com/v16.0/app -> 200; GET graph.facebook.com/v16.0/app/mobile_sdk_gk -> 200 (2 calls) |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (inferred) | POST firebaseinstallations.googleapis.com/v1/projects/pixybaby/installations -> 200 |

- **Network log:** [network-log-pixy.json](results/network-log-pixy.json)

## FOSS self-hosted

### Baby Buddy
- **Claim:** Open source - see [github.com/babybuddy/babybuddy](https://github.com/babybuddy/babybuddy)
- **Result:** PASS (100% confidence)
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
- **Result:** No claim (95% confidence)
- **Confidence:** 95%. Twenty-one flows on launch, 18 to advertising or tracking endpoints across five SDK families (AppsFlyer, Microsoft Clarity, Scorecard Research, Google Ads, Snowplow). The manifest declares ACCESS_ADSERVICES_AD_ID plus an install-referrer receiver. The combination of volume, SDK variety, and Ad-ID permissions makes this the strongest no-claim evidence in wave 1.
- **Capture:** 2026-08-14, launch window, burst 7, 21 flows (7 unique endpoints).

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Launch and install events; app-instance and advertising identifiers (inferred from the SDK event endpoint) | POST 2snoab.launches.appsflyersdk.com/api/v6.18/androidevent -> 200 |
| Microsoft Clarity | Session telemetry beacon; session identifiers and interaction events (inferred) | POST r.clarity.ms/collect -> 204 |
| Scorecard Research | Census-style measurement beacon; device and app identifiers (inferred) | GET census-app.scorecardresearch.com/p2 -> 200 |
| Google Ads | Ad configuration fetch; Ad-ID capability (manifest declares ACCESS_ADSERVICES_AD_ID) | GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 |
| BabyCenter (Snowplow) | In-app event tracker via Snowplow collector; app events (inferred) | POST bcsp.babycenter.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| BabyCenter (own) | Geo/region detection and in-app config fetch; region and device data (inferred) | GET geo.babycenter.com/v1 -> 200; GET www.babycenter.com/app_config/android/en-US/welcomeScreenABTest.json -> 200 |

- **Network log:** [network-log-babycenter.json](results/network-log-babycenter.json)

### BellyBloom
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.bellyBloom.pregnancy.tracker) (data-safety: "Shares Health and fitness, Photos and videos, and Calendar. Data is not encrypted and cannot be deleted")
- **Result:** No claim (90% confidence)
- **Confidence:** 90%. Eight flows on launch, every one to an advertising or tracking endpoint: Adjust attribution, Facebook Audience Network sync, Google Ads SDK loader and config, and Firebase Installations and Remote Config. We used version 1.0.8 because 1.0.9 requires Android 12L (API 32). A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 8 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/254761198014/namespaces/firebase:fetch -> 200 |
| Google Ads | Ad SDK loader, cache manifest, and config fetch; Ad-ID capability | GET googleads.g.doubleclick.net/mads/static/sdk/native/sdk-core-android.html -> 200; GET googleads.g.doubleclick.net/mads/static/mad/sdk/native/sdk-core-v40-loader.appcache -> 200; GET googleads.g.doubleclick.net/favicon.ico -> 200; GET googleads.g.doubleclick.net/getconfig/pubsetting -> 200 |
| Facebook | Audience Network sync beacon; advertising identifiers (inferred) | POST www.facebook.com/adnw_sync2 -> 200 |
| Adjust | Install-attribution check; device and install identifiers (inferred) | GET app.adjust.com/attribution -> 200 |

- **Network log:** [network-log-bellybloom.json](results/network-log-bellybloom.json)

### Nanit
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.nanit.baby) (data-safety: "Shares Personal info, App activity, and App info and performance")
- **Result:** No claim (90% confidence)
- **Confidence:** 90%. Five flows on launch: three to Google Firebase (Installations, Remote Config, invalidation stream) and two to the Nanit API (a 200 plans fetch, a 401 cards fetch showing the endpoint requires auth). No advertising SDK traffic appeared in the window. Full features need the camera and an account; the capture covers onboarding only, which caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 5 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/nanit-144706/installations -> 200 |
| Google Firebase | Feature-config fetch and invalidation stream; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/25705829844/namespaces/firebase:fetch -> 200; POST firebaseremoteconfigrealtime.googleapis.com/v1/projects/25705829844/namespaces/firebase:streamFetchInvalidations -> 200 |
| Nanit | Product/plan API; account and session data once logged in (cards fetch requires auth) | GET api.nanit.com/plans -> 200; GET api.nanit.com/cards -> 401 |

- **Network log:** [network-log-nanit.json](results/network-log-nanit.json)

### Pregnancy+
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.hp.pregnancy.lite) (data-safety: "Shares Location and Device or other IDs")
- **Result:** No claim (90% confidence)
- **Confidence:** 90%. Three flows on launch, all to Google Firebase: Installations and Remote Config. No advertising SDK traffic appeared in the window. Automation accepted the consent screens; the capture disabled sensitivity. A real user session could differ, which caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 3 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/1073993904376/namespaces/firebase:fetch -> 200 |

- **Network log:** [network-log-pregnancyplus.json](results/network-log-pregnancyplus.json)

### What to Expect
- **Claim:** No claim - see [Google Play listing](https://play.google.com/store/apps/details?id=com.wte.view) (data-safety: "Shares Personal info and Health and fitness, plus five other data types")
- **Result:** No claim (90% confidence)
- **Confidence:** 90%. Fourteen flows on launch, 13 to advertising or tracking endpoints: AppsFlyer across six subdomains (register, conversions, DLSdk, GCDSdk, PIA, in-apps), Microsoft Clarity, Scorecard Research, Snowplow, and Firebase Installations and Remote Config. The manifest declares ACCESS_ADSERVICES_AD_ID and AD_SERVICES_CONFIG. A single launch window caps confidence below 95%.
- **Capture:** 2026-08-14, launch window, burst 7, 14 flows.

| Service | Data shared | Call/Log |
| --- | --- | --- |
| AppsFlyer | Launch, install, conversion, and in-app events plus SDK deployment checks; app-instance and advertising identifiers (inferred from the SDK endpoints) | POST a2lve5.register.appsflyersdk.com/api/v6.18/androidevent -> 200; POST a2lve5.conversions.appsflyersdk.com/api/v6.18/androidevent -> 200; POST a2lve5.inapps.appsflyersdk.com/api/v6.18/androidevent -> 200; POST a2lve5.pia.appsflyersdk.com/api/v1.0/pia-android-event -> 200; POST a2lve5.dlsdk.appsflyersdk.com/v1.0/android/com.wte.view -> 200; GET a2lve5.gcdsdk.appsflyersdk.com/install_data/v5.0/com.wte.view -> 200 |
| Microsoft Clarity | Session telemetry beacon; session identifiers and interaction events (inferred) | POST b.clarity.ms/collect -> 204 |
| Scorecard Research | Census-style measurement beacon; device and app identifiers (inferred) | GET census-app.scorecardresearch.com/p2 -> 200 |
| What to Expect (Snowplow) | In-app event tracker via Snowplow collector; app events (inferred) | POST sp.whattoexpect.com/com.snowplowanalytics.snowplow/tp2 -> 200 |
| Google Firebase | Device installation registration; installation ID and refresh token issued by Google (observed in response body) | POST firebaseinstallations.googleapis.com/v1/projects/[REDACTED]/installations -> 200 |
| Google Firebase | Feature-config fetch; no user data | POST firebaseremoteconfig.googleapis.com/v1/projects/179542082127/namespaces/firebase:fetch -> 200 |

- **Network log:** [network-log-whattoexpect.json](results/network-log-whattoexpect.json)

## Cross-app view

Every app that failed shares one piece of code: Firebase. Nara and Pixy also embed Facebook. The words "complete privacy" and "HIPAA-compliant" sit next to code that sends data to third parties.

All five wave-1 apps ship at least one install-attribution or ad SDK (AppsFlyer, Adjust, Facebook Audience Network, or Google Ads) alongside Firebase. The Play Store data-safety pages for all five share data; none promise to keep data on the device.

## Roadmap

- **Operator-integrated dark pattern testing (next).** We paused the static dark-pattern scan and removed its artifacts from this pipeline. Static heuristics gave weak signals (the word "timer" is also Danish for "hours") and cannot see runtime behavior. The next phase replaces it with hands-on operator testing: set up a fictional baby profile in the app (name, birth date, weight, feeding and sleep logs), enter that data by hand, and watch the capture logs for the fake values and for consent-screen pressure patterns. This finds out whether the data we type in leaves the phone, and whether consent screens push toward sharing. See `METHODOLOGY.md` for the capture procedure and `ROADMAP.md` for the plan.
- **Wave 2 testing.** Tier 1 candidates in `localonly/candidates.md` (gitignored) are the next wave.

## Limits

- We did not tap the apps by hand. Some data paths stayed hidden. The operator-integrated roadmap item closes this gap.
- The captures cover the launch and early-use window of each app. Behavior later in a session could differ.
- We withheld response bodies and headers from this report and the network logs because they carried authentication tokens. "Data shared" is therefore "observed" only where the capture itself showed the exchange (for example, a Firebase installation ID and refresh token in the response), and "inferred" elsewhere from the endpoint and the SDK that made the call.

## Advice

**For parents:** Do not trust "offline" or "local-first" claims. Baby Buddy is the only app we tested that sent nothing off the device.

**For developers:** If you say "offline", remove the analytics and attribution code. One outbound call breaks the claim.

**For regulators:** "100% offline" and "local-first" are testable claims. Someone should test them.

## Artifacts

Machine-readable results: [results/RESULTS-20260803.json](results/RESULTS-20260803.json)

Per-app sanitized network logs (committed): see the network-log links in each app block above. Cross-app view: [results/comparison-burst-7.json](results/comparison-burst-7.json). Raw network captures (`results/decode-traffic-<app>.json`) are generated locally and kept out of the repository because they contain captured authentication tokens.
