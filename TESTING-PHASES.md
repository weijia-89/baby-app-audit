# Baby App Audit - Testing Phases (Bursts)

**Strategy:** Test apps in bursts of 3-5 apps. Re-audit previously tested apps with Sprint 3 criteria before testing new apps.

**Sprint 3 New Criteria:**
1. Dark pattern detection (static APK resource scan)
2. Cross-app comparison (shared trackers, endpoints, data volume)
3. Product metadata (retention, EOL, CVE, regulatory regime)
4. Per-product governance (Part 8.5)

---

## Burst 1: Re-audit Original 4 Apps with New Criteria

**Goal:** Validate Sprint 3 criteria on known targets before applying to new apps.

**Apps:**
1. Nurture Lock - re-test dark patterns, update metadata
2. Nubo - complete static analysis (jadx), dark patterns, metadata
3. Pebbi - re-test dark patterns, update metadata
4. Baby Buddy - source re-audit, metadata

**Tests to run:**
- [ ] Static analysis (jadx decompile + string search)
- [ ] Dark pattern scan (`scripts/detect-dark-patterns.sh`)
- [ ] Dynamic capture (mitmproxy - if available)
- [ ] Product metadata update (`results/product-metadata.json`)
- [ ] Cross-app comparison prep (decode traffic)

**Expected outputs:**
- Updated `results/dark-patterns-*.json` for each app
- Updated `results/product-metadata.json`
- New or updated decoded traffic JSONs
- `results/comparison-*.json` with all 4 apps

---

## Burst 2: Tier 1 Apps + Privacy-First Batch 1

**Goal:** Test high-priority apps and privacy-first marketed apps.

**Apps (6 total):**
- BabyTrack (com.babytrack.app) - claims offline
- Amila (com.amila.babytracker) - unknown
- Wachanga (com.wachanga.babymilestones) - milestone tracker
- Baby Daybook (com.babydaybook.app) - Piranesi-verified, no AdID
- Baby+ (com.babyplus.app) - Piranesi-verified, no AdID
- Cradly (com.cradly.app) - claims privacy-first, local-first

**Tests to run:**
- [ ] APK acquisition (apkeep or adb)
- [ ] Static analysis (jadx + string search)
- [ ] Dark pattern scan
- [ ] Dynamic capture
- [ ] Product metadata entry
- [ ] Decode traffic

**Expected outputs:**
- 6 new app entries in results
- 6 dark-patterns JSONs
- 6 decoded traffic JSONs
- Updated comparison JSON

---

## Burst 3: Tier 2 Apps

**Goal:** Test medium-priority apps.

**Apps (5 total):**
- NighP (com.nightp.baby)
- Milli (com.milli.baby)
- Baby Connect (com.babyconnect.app) - syncs across devices
- SNUGL (com.snugl.app) - baby monitor
- Talli Baby (com.mybabylogger.babylogger) - cloud sync via Wi-Fi

**Tests:** Same as Burst 2.

---

## Burst 4: FOSS Candidates

**Goal:** Test open-source apps for comparison baseline.

**Apps (4 total):**
- LunaTracker (it.danieleverducci.lunatracker) - GPL-3.0, WebDAV sync
- MimiLog (com.mimiapp.mimilog) - no ads, no signup, fully offline
- Sara Baby Tracker (com.suleymansurucu.sarababy) - GPL-3.0, Firebase sync
- Dymn Baby (com.dymnstudio.dymn-baby) - MIT, fully offline

**Tests:**
- [ ] Source code audit (clone + search)
- [ ] If APK exists: static + dynamic
- [ ] Dark pattern scan (if Android APK)
- [ ] Product metadata

---

## Burst 5: Privacy-First Marketed Batch 2

**Goal:** Test remaining privacy-marketed apps.

**Apps (6 total):**
- BabyLog (com.babylog.app) - claims 100% offline
- Nara (com.naraorganics.nara) - claims complete privacy
- Heartful Baby (com.heartfulsprout.baby) - claims HIPAA-compliant
- Nestling (com.nestling.app) - claims privacy-first
- Pixy (com.pixykid.app) - claims bank-level encryption
- Nurture Lock (com.nurturelock.app) - different package from original

**Note:** Some of these may be iOS-only. Test Android versions where available.

---

## Burst 6: Wearable / IoT

**Goal:** Test hardware devices with companion apps.

**Apps (5 total):**
- Owlet Sock (com.owletcare.sock) - MDR, SpO2 monitor
- Owlet Cam (com.owletcare.cam) - RED, Wi-Fi camera
- Nanit (com.nanit.app) - baby monitor camera
- Miku (com.miku.app) - breathing monitor
- Snuza (com.snuza.app) - movement monitor

**Special tests:**
- [ ] BLE beacon analysis
- [ ] Companion app network traffic
- [ ] Device firmware checks
- [ ] Regulatory regime validation (MDR vs RED)
- [ ] CVE lookup

---

## Burst Execution Rules

1. **Canary test:** Run Pebbi (positive control) before each burst.
2. **One app at a time:** Serial execution per app to avoid port collisions.
3. **Port rotation:** Use 8080-8095 for concurrent apps in same burst.
4. **Artifact isolation:** Each app gets `results/<app>-test-<date>/` directory.
5. **Batch config:** Use `APK_HARNESS_APPS` env var with semicolon delimiter.
6. **Partial failure OK:** If one app fails, continue with others.
7. **Evidence chain:** Record SHA-256, timestamps, and commit hashes for every test.

## Burst Scheduling

| Burst | Apps | Estimated time | Dependencies |
|-------|------|----------------|--------------|
| 1 | 4 (re-audit) | 1 day | Emulator ready |
| 2 | 6 (Tier 1 + privacy) | 2 days | Burst 1 complete |
| 3 | 5 (Tier 2) | 2 days | Burst 2 complete |
| 4 | 4 (FOSS) | 1 day | Burst 3 complete |
| 5 | 6 (Privacy batch 2) | 2 days | Burst 4 complete |
| 6 | 5 (Wearables) | 2 days | Burst 5 complete |

**Total: 10 days over 6 bursts.**
