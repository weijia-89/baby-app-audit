# Candidate App Registry

> **Purpose:** A living list of apps I might test. I update this as I find new candidates.
> **Source:** Piranesi S4 research, Play Store search, and operator suggestions.

---

## Tier 1  -  Immediate test (next sprint)

These apps have high user bases or high privacy risk. I test them first.

| Name | Slug | Platform | Package name | Source | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| BabyTrack | babytrack | Android | com.babytrack.app | Play Store search | Claims offline | network_capture, policy_text |
| Amila | amila | Android | com.amila.babytracker | Play Store search | Unknown | exodus_static, network_capture |
| Wachanga | wachanga | Android | com.wachanga.babymilestones | Play Store search | Milestone tracker | network_capture, policy_text |

---

## Tier 2  -  Full audit (this quarter)

These apps are interesting but lower priority than Tier 1.

| Name | Slug | Platform | Package name | Source | Privacy posture | Evidence type |
| --- | --- | --- | --- | --- | --- | --- |
| NighP | nighp | Android | com.nightp.baby | Play Store search | Sleep tracker | network_capture, exodus_static |
| Milli | milli | Android | com.milli.baby | Play Store search | Growth tracker | network_capture, policy_text |
| Baby Connect | baby-connect | Android | com.babyconnect.app | Play Store search | Syncs across devices | network_capture, manual_audit |
| SNUGL | snugl | Android | com.snugl.app | Play Store search | Baby monitor | network_capture, exodus_static |

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
| Owlet Sock | Indefinite | 2025-12-31 (Sock 2) | MDR | CVE-2023-6321 (high) |
| Owlet Cam | 30 days (Sight) | 2027-12-31 (Cam 2) | RED | CVE-2023-6323 (medium) |
| Nanit | Unknown | Unknown | RED | None known |
| Miku | Unknown | Unknown | MDR | None known |
| Snuza | Unknown | Unknown | MDR | None known |

**Note:** Retention and EOL come from privacy policies, vendor announcements, and NVD lookups. I verify each one before testing.

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
