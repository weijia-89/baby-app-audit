# Candidate App Registry

> **Purpose:** A living list of apps I might test. I update this as I find new candidates.
> **Source:** Piranesi S4 research, Play Store search, and operator suggestions.

---

## Tier 1  -  Immediate test (next sprint)

These apps have high user bases or high privacy risk. I test them first.

| Name | Slug | Platform | Package name | Source | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| BabyTrack | babytrack | Android | com.sociodigitals.babytrack | Play Store search | Claims offline | network_capture, policy_text |
| Amila | amila | Android | com.amila.parenting | Play Store search | Unknown | exodus_static, network_capture |
| ~~Wachanga~~ | ~~wachanga~~ | ~~Android~~ | ~~com.wachanga.babymilestones~~ | Play Store search | Wrong category (pregnancy tracker, not milestones) | DROPPED 2026-08-07 |

**Note (2026-08-07):** Original package names for BabyTrack (`com.babytrack.app`) and Amila (`com.amila.babytracker`) were incorrect and returned Play Store 404. Correct names verified by fetching Play Store listing pages: BabyTrack is `com.sociodigitals.babytrack` (SocioDigitals, 0+ downloads, offline-first), Amila is `com.amila.parenting` (Amila Tech, 1M+ downloads, "Baby tracker - feeding, sleep"). Wachanga was dropped: the only Wachanga app on Play Store (`com.wachanga.pregnancy`) is a pregnancy tracker, not a baby-milestones app. The candidate description "Milestone tracker" did not match the real app.

---

## Tier 2  -  Full audit (this quarter)

These apps are interesting but lower priority than Tier 1.

| Name | Slug | Platform | Package name | Source | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| NighP | nighp | Android | com.nightp.baby | Play Store search | Sleep tracker | network_capture, exodus_static |
| Milli | milli | Android | com.milli.baby | Play Store search | Growth tracker | network_capture, policy_text |
| Baby Connect | baby-connect | Android | com.babyconnect.app | Play Store search | Syncs across devices | network_capture, manual_audit |
| SNUGL | snugl | Android | com.snugl.app | Play Store search | Baby monitor | network_capture, exodus_static |
| Talli Baby | talli-baby | Android / iOS | com.mybabylogger.babylogger | Operator suggestion | Cloud sync via Wi-Fi device | network_capture, exodus_static, policy_text |

---

## FOSS candidates

Open-source apps. I test these to compare against proprietary baselines. Baby Buddy is already in scope as the FOSS baseline (see "Out of scope" note in dedup log).

| Name | Slug | Platform | Package name | Source | License | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LunaTracker | lunatracker | Android | it.danieleverducci.lunatracker | F-Droid | GPL-3.0 | WebDAV sync, optional cloud | network_capture, exodus_static |
| MimiLog | mimilog | Android / iOS | com.mimiapp.mimilog | Play Store search | Proprietary (no ads, no signup) | Fully offline, no account | exodus_static, policy_text |
| Sara Baby Tracker | sara-baby | Android / iOS | com.suleymansurucu.sarababy | Play Store search | GPL-3.0 | Firebase sync, caregiver sharing | network_capture, exodus_static |
| Dymn Baby | dymn-baby | Android | com.dymnstudio.dymn-baby | GitHub | MIT | Fully offline | exodus_static, policy_text |

**Note:** MimiLog is not open source but is privacy-focused (no ads, no signup, fully offline). I include it here for comparison with FOSS offline-first apps.

---

## Privacy-first marketed

These apps explicitly market themselves as privacy-first, local-only, or offline. I test them to verify whether the marketing matches the code and the wire. Piranesi research surfaced almost no apps in this category — a gap this section fills.

| Name | Slug | Platform | Package name | Source | Marketing claim | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| Baby Daybook | baby-daybook | iOS / Android | com.drillyapps.babydaybook | Piranesi S1 (Pybus) | AdID not auto-enabled; no US processing | network_capture, exodus_static |
| Baby+ | baby-plus | iOS / Android | com.hp.babyapp | Piranesi S1 (Pybus) | AdID not auto-enabled; no US processing | network_capture, exodus_static |
| Nurture Lock | nurture-lock | Android | com.angry.shark.studio.nurturelock | Web search | 100% offline, no account, AES-256, local storage only | network_capture, exodus_static |
| Cradle | cradle | iOS / Android | com.creatorlane.cradle | Web search | Privacy-first, encrypted at rest, no data sold | network_capture, exodus_static |
| BabyLog | babylog | iOS | com.babylog.app | Web search | 100% offline, no account, no cloud | network_capture, exodus_static |
| Nara | nara | iOS / Android | com.naraorganics.nara | Web search | Complete privacy, real-time sharing, no data sold | network_capture, exodus_static |
| Heartful Baby | heartful-baby | iOS / Android | com.heartfulsprout.baby | Web search | HIPAA-compliant, never sell data | network_capture, exodus_static |
| Nestling | nestling | iOS | com.nestling.app | Web search | Privacy-first, no ads, no data selling | network_capture, exodus_static |
| Pixy | pixy | iOS / Android | com.pixykid.app | Web search | Bank-level encryption, HIPAA compliant, privacy first | network_capture, exodus_static |

**Note:** Baby Daybook and Baby+ are Piranesi-verified (Pybus C-010: among only 4 of 14 apps that did NOT auto-enable AdIDs). Nurture Lock, Cradle, BabyLog, Nara, Heartful Baby, Nestling, and Pixy come from web search — marketing claims only, not yet code-verified.

**Note (2026-08-07):** Original package names for Baby Daybook (`com.babydaybook.app`), Baby+ (`com.babyplus.app`), Nurture Lock (`com.nurturelock.app`), and Cradle (`com.cradly.app`, was "Cradly") were incorrect and returned Play Store 404. Correct names verified by fetching Play Store listing pages: Baby Daybook is `com.drillyapps.babydaybook` (Baltapis, 1M+ downloads), Baby+ is `com.hp.babyapp` (Philips Electronics UK, 5M+ downloads), Nurture Lock is `com.angry.shark.studio.nurturelock` (from installed emulator package), Cradle is `com.creatorlane.cradle` (Creator Lane Studios, 100+ downloads). The original "Cradly" spelling was wrong; the real app is "Cradle". Cradle's marketing says "Privacy first, encrypted at rest, no data sold" but it is a brand-new app (100+ downloads, launched Aug 2026) — low reach.

---

## Tier 3  -  Backlog (future)

These apps are on my list but not scheduled yet.

| Name | Slug | Platform | Package name | Source | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| Sprout Baby | sprout-baby | iOS / Android | com.sproutbaby.app | Play Store search | Baby tracker | policy_text, external_citation |
| Glow Baby | glow-baby | iOS / Android | com.glowbaby.app | Play Store search | Baby tracker | policy_text, external_citation |
| Huckleberry | huckleberry | iOS / Android | com.huckleberry.app | Play Store search | Sleep tracker | policy_text, external_citation |
| Tinyhood | tinyhood | iOS / Android | com.tinyhood.app | Play Store search | Parenting app | policy_text, external_citation |
| Kinedu | kinedu | iOS / Android | com.kinedu.app | Play Store search | Baby development | policy_text, external_citation |
| Pregnancy+ | pregnancy-plus | iOS / Android | com.pregnancyplus.app | Play Store search | Pregnancy tracker | policy_text |
| What to Expect | what-to-expect | iOS / Android | com.wte.app | Play Store search | Pregnancy tracker | policy_text |
| BabyCenter | babycenter | iOS / Android | com.babycenter.app | Play Store search | Pregnancy tracker | policy_text |

**Note:** What to Expect, BabyCenter, and Pregnancy+ are pregnancy apps, not baby-milestone apps. I track them separately because the data type differs.

---

## Wearable / IoT  -  Phase 2

These are hardware devices with companion apps. I test them after I finish the mobile app backlog.

| Name | Slug | Platform | Package name | Device type | Regime | Source |
| --- | --- | --- | --- | --- | --- | --- |
| Owlet Sock | owlet-sock | Android / iOS | com.owletcare.sock | SpO2 monitor | MDR | Piranesi S4 |
| Owlet Cam | owlet-cam | Android / iOS | com.owletcare.cam | Wi-Fi camera | RED | Piranesi S4 |
| Nanit | nanit | Android / iOS | com.nanit.app | Baby monitor camera | RED | Play Store search |
| Miku | miku | Android / iOS | com.miku.app | Breathing monitor | MDR | Play Store search |
| Snuza | snuza | Android / iOS | com.snuza.app | Movement monitor | MDR | Play Store search |

**Regime note:** MDR devices claim health monitoring (SpO2, breathing). RED devices are radio transmitters (Wi-Fi, Bluetooth). I test MDR and RED paths separately.

---

## Out of scope

| Name | Reason | Date decided |
| --- | --- | --- |
| riafy | Removed from Play Store. Only 170 downloads when active. Not worth the effort. | 2026-08-03 |

---

## Per-product config

I record retention, EOL, and regime for each candidate before testing.

| App | Retention | EOL | Regime | CVE list |
| --- | --- | --- | --- | --- |
| BabyTrack | Unknown | N/A | Unknown | None known |
| Amila | Unknown | N/A | Unknown | None known |
| Wachanga | Unknown | N/A | Unknown | None known |
| NighP | Unknown | N/A | Unknown | None known |
| Milli | Unknown | N/A | Unknown | None known |
| Baby Connect | Unknown | N/A | Unknown | None known |
| SNUGL | Unknown | N/A | Unknown | None known |
| Owlet Sock | Indefinite | Unknown (Dream Sock active) | MDR | None known |
| Owlet Cam | 30 days (Sight) | Unknown (Cam 2 active) | RED | CVE-2023-6321 (high), CVE-2023-6323 (medium) |
| Nanit | Unknown | Unknown | RED | None known |
| Miku | Unknown | Unknown | MDR | None known |
| Snuza | Unknown | Unknown | MDR | None known |
| Talli Baby | Unknown | N/A | Unknown | None known |
| LunaTracker | Unknown | N/A | Unknown | None known |
| MimiLog | Unknown | N/A | Unknown | None known |
| Sara Baby Tracker | Unknown | N/A | Unknown | None known |
| Dymn Baby | Unknown | N/A | Unknown | None known |
| Baby Daybook | Unknown | N/A | Unknown | None known |
| Baby+ | Unknown | N/A | Unknown | None known |
| Nurture Lock | Unknown | N/A | Unknown | None known |
| Cradly | Unknown | N/A | Unknown | None known |
| BabyLog | Unknown | N/A | Unknown | None known |
| Nara | Unknown | N/A | Unknown | None known |
| Heartful Baby | Unknown | N/A | Unknown | None known |
| Nestling | Unknown | N/A | Unknown | None known |
| Pixy | Unknown | N/A | Unknown | None known |

**Note:** Retention and EOL come from privacy policies, vendor announcements, and NVD lookups. I verify each one before testing.

---

## Owlet ecosystem research

I looked up the Owlet Sock and Owlet Cam in the National Vulnerability Database (NVD) to verify security claims.

### Regime classification

| Device | Regime | Reason |
| --- | --- | --- |
| Owlet Sock | MDR | Pulse oximeter and sleep monitor. FDA cleared the Dream Sock in 2023 as a medical device (510(k) K223279). |
| Owlet Cam | RED | Wi-Fi camera and radio transmitter. Falls under the Radio Equipment Directive in the EU. |

### Basic UDI-DI

| Device | Basic UDI-DI | Status |
| --- | --- | --- |
| Owlet Sock | Unknown | Not publicly disclosed in NVD or FDA 510(k) summary. |
| Owlet Cam | N/A | RED devices do not require UDI-DI. |

### Verified CVEs

| CVE ID | Device | Severity | Description | Source |
| --- | --- | --- | --- | --- |
| CVE-2023-6321 | Owlet Cam | High (CVSS 8.8) | Command injection in the IOCTL that manages OTA updates. A crafted command can lead to root execution. | NVD, Bitdefender |
| CVE-2023-6323 | Owlet Cam | Medium (CVSS 6.5) | ThroughTek Kalay SDK does not verify message authenticity. An attacker can impersonate an authoritative server. | NVD, Bitdefender |

**Note:** Both verified CVEs affect the Owlet Cam, not the Owlet Sock. The Sock may have security issues, but none are listed in NVD as of 2026-08-05. The Bitdefender research that discovered these flaws is at https://bitdefender.com/blog/labs/notes-on-throughtek-kalay-vulnerabilities-and-their-impact/.

### EOL status

| Device | EOL date | Confidence |
| --- | --- | --- |
| Owlet Sock (Dream Sock) | Not announced | Active product as of 2026-08-05 |
| Owlet Cam (Cam 2) | Not announced | Active product as of 2026-08-05 |

The original Owlet Smart Sock was discontinued in 2021 after an FDA warning letter. The Dream Sock replaced it and received 510(k) clearance in 2023.

---

## Deduplication log

I check each candidate against this list before adding it. If it is already here, I do not add it again.

| App | First seen | Deduplication check |
| --- | --- | --- |
| Nurture Lock | 2026-08-03 | Original target |
| Nubo | 2026-08-03 | Original target |
| Pebbi | 2026-08-03 | Original target |
| Baby Buddy | 2026-08-03 | Original target (FOSS baseline) |
| BabyTrack | 2026-08-04 | New - not in original list |
| Amila | 2026-08-04 | New - not in original list |
| Wachanga | 2026-08-04 | New - not in original list |
| Talli Baby | 2026-08-05 | New - not in original list |
| LunaTracker | 2026-08-05 | New - not in original list |
| MimiLog | 2026-08-05 | New - not in original list |
| Sara Baby Tracker | 2026-08-05 | New - not in original list |
| Dymn Baby | 2026-08-05 | New - not in original list |
| Baby Daybook | 2026-08-05 | New - Piranesi S1 C-010 |
| Baby+ | 2026-08-05 | New - Piranesi S1 C-010 |
| Nurture Lock | 2026-08-05 | New - web search |
| Cradly | 2026-08-05 | New - web search |
| BabyLog | 2026-08-05 | New - web search |
| Nara | 2026-08-05 | New - web search |
| Heartful Baby | 2026-08-05 | New - web search |
| Nestling | 2026-08-05 | New - web search |
| Pixy | 2026-08-05 | New - web search |

---

## How I add a new candidate

1. Search the Play Store or App Store for the app name.
2. Record the package name from the URL.
3. Check the privacy policy for retention and data sharing claims.
4. Assign a tier based on user-base size and privacy risk.
5. Mark evidence types I plan to collect.
6. Run a deduplication check against this file.
7. Add the app to the table.

**Source attribution:** Each app links back to the Piranesi S4 reconcile ingest where applicable.
