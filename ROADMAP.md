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

### Burst 2  -  Partial (3 of 5 apps tested, 2 blocked)
- Tier 1 apps: BabyTrack (blocked), Amila (done), Wachanga (dropped: wrong category)
- Privacy-first batch 1: Baby Daybook (done), Baby+ (done), Cradle (blocked)
- Dark pattern scans: amila (3), baby-daybook (2), baby-plus (3)
- Cross-app comparison: comparison-burst-2.json (3 apps, 0 shared trackers, shared mechanism: Firebase)
- Blockers: BabyTrack and Cradle not on APKPure/F-Droid, require Play Store install
- Baby+ tested with older v2.0.10 (current v3.2 ships armeabi_v7a-only, incompatible with arm64 emulator)

### Burst 3  -  Planned
- Tier 2 apps: NighP, Milli, Baby Connect, SNUGL, Talli Baby

### Burst 4  -  Planned
- FOSS candidates: LunaTracker, MimiLog, Sara Baby Tracker, Dymn Baby

### Burst 5  -  Planned
- Privacy-first batch 2: BabyLog, Nara, Heartful Baby, Nestling, Pixy, Nurture Lock (variant)

### Burst 6  -  Planned
- Wearable / IoT: Owlet Sock, Owlet Cam, Nanit, Miku, Snuza

### Final Report and Publication  -  Planned
- Synthesize all burst findings into final report
- Publish methodology and open-source the tool
