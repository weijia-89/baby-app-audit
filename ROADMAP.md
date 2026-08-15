# Roadmap

## Sprint 1  -  Done

- Live data collection pipeline with schema-valid output
- Harness restructure with FOSS tags
- App expansion to 16+ candidates with skeleton entries
- Research prompts and shared output schema

## Sprint 2  -  Done

- Tier 1 app full test runs with live captures
- Automated schema enforcement in CI
- FOSS path validation for BabyBuddy

## Sprint 3  -  Done

- Wearable ecosystem deep-dive (Owlet)
- Dark pattern detection automation
- Cross-app data comparison

## Sprint 4  -  Current  -  Testing Phase

**Goal:** Systematically test all candidate apps in bursts, applying Sprint 3 criteria to both new and previously tested apps.

### Burst 1  -  Done
- Re-audit original 4 apps (Nurture Lock, Nubo, Pebbi, Baby Buddy) with new Sprint 3 criteria
- Validate harness on known targets before expanding
- Dark pattern scans: nurture-lock (2), nubo (3), pebbi (2)
- Decode traffic reports generated for all native apps
- Cross-app comparison: comparison-burst-1.json

### Burst 2  -  Partial (3 of 5 apps tested, 2 backburner)
- Tier 1 apps: BabyTrack (backburner), Amila (done), Wachanga (dropped: wrong category)
- Privacy-first batch 1: Baby Daybook (done), Baby+ (done), Cradle (backburner)
- Dark pattern scans: amila (3), baby-daybook (2), baby-plus (3)
- Cross-app comparison: comparison-burst-2.json (3 apps, 0 shared trackers, shared mechanism: Firebase)
- Baby+ tested with older v2.0.10 (current v3.2 ships armeabi_v7a-only, incompatible with arm64 emulator)

### Burst 3  -  Dropped (no privacy/offline claims)
- All 5 Tier 2 apps (NighP, Milli, Baby Connect, SNUGL, Talli Baby) dropped: none make privacy or offline promises

### Burst 4  -  Partial (1 of 2 apps tested, 1 backburner)
- MimiLog (done): fully offline, no ads, no signup; no outbound flows in capture; 1 Firebase Remote Config attempt never completed
- Dymn Baby (backburner): APK not on APKPure or F-Droid; pending GitHub release
- Dropped: LunaTracker (WebDAV/cloud), Sara Baby Tracker (Firebase sync)

### Burst 5  -  Planned (3 apps, Android-only)
- Nara (complete privacy, no data sold)
- Heartful Baby (HIPAA-compliant, never sell data)
- Pixy (bank-level encryption, HIPAA compliant)
- Dropped: BabyLog (iOS only), Nestling (iOS only), Nurture Lock variant (already tested in Burst 1)

### Burst 6  -  Dropped (no privacy/offline claims)
- All 5 wearable/IoT apps (Owlet Sock, Owlet Cam, Nanit, Miku, Snuza) dropped: none make privacy or offline promises

### Backburner  -  Play Store-only or unavailable apps
Apps that make privacy/offline claims but cannot be acquired via APKPure or F-Droid. Require Google account on emulator or manual APK download to test.
- **BabyTrack** (com.sociodigitals.babytrack): claims offline, encrypted, no ads. 0+ downloads. Solo dev (Indonesia). Not indexed by AppBrain or AppStoreSpy.
- **Cradle** (com.creatorlane.cradle): claims privacy-first, encrypted at rest, no data sold. 130 total downloads (8/month). Brand-new app (Aug 2026).
- **Dymn Baby** (com.dymnstudio.dymn-baby): MIT license, fully offline. APK not on APKPure or F-Droid. Pending GitHub release download.

**General rule:** Any future app that can only be acquired from the Play Store (not on APKPure, F-Droid, or other mirrors) goes to backburner. The operator must either (a) add a Google account to the emulator, or (b) manually download the APK from a browser and place it in `apks/`. Neither option blocks the rest of the testing pipeline — only APK acquisition.

### Final Report and Publication  -  Planned
- Synthesize all burst findings into final report
- Publish methodology and open-source the tool

## Sprint 5  -  Planned  -  Legacy re-capture and evidence parity

**Goal:** Bring the 8 legacy apps (nurture-lock, nubo, pebbi, amila, baby-buddy, baby-daybook, baby-plus, mimilog) up to the same evidence depth as the wave-1/wave-2 apps. Their raw `.mitm` captures disappeared before the retention rule existed (AGENTS.md "Evidence retention"); their results are decode-level only, and two of them (Amila, Baby+) are the same shape of thin evidence that flipped Nanit and Pregnancy+ to major.

### Legacy re-capture  -  Planned
- Re-run the harness on all 8 legacy apps with the new retention rule in force; preserve `results/<app>-test-<date>/artifacts/captures/*.mitm` permanently (evidence-inventory guard now enforces this).
- Expected caveat: current APK versions differ from the tested builds (e.g. we tested Baby+ at v2.0.10 and BellyBloom at v1.0.8). Record the tested APK hash in RESULTS and note version drift in the report; if archived APKs exist locally, prefer them for continuity.
- After each capture: run `scripts/build-network-logs.sh` to produce enriched network logs, then re-audit `privacy_class` and evidence at full depth (expect: Amila and Baby+ may flip minor -> major like Nanit/Pregnancy+ did).
- Update `RESULTS-20260803.json` `evidence_source` for the 8 apps from `session-summary` to `raw-replay`, refresh the FINAL-REPORT blocks, and re-run all gates (unit tests, evidence inventory, schema validation).
- Success criterion: all 16 apps have `evidence_source: raw-replay` and a preserved, non-zero-byte capture tree; zero apps classified on decode-level evidence alone.
