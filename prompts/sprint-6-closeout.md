# Sprint 6 Closeout

**Status:** Complete

## Closure Summary

Sprint 6 closeout marks the completion of the baby-app-audit project's sprint cycle. This sprint finalized all findings across bursts 1-5 and produced the definitive final report.

## Completed Items

- **FINAL-REPORT.md**: Standardized Burst sections to Nurture Lock template (app, package, version, claim, verdict, static analysis, dynamic capture, confidence-annotated verdict). Updated Burst 5 verdicts to INCONCLUSIVE (70% confidence) matching executive summary. Added Nara to BURST_APPS config.
- **CHANGELOG.md**: Sprint 4 status updated from In Progress → Complete. Added Burst 5 re-test entries, SSL pinning resolution, and NSC audit findings.
- **README.md**: "What is next" section updated with Sprint 4 completion status, operator actions for Burst 2 blocked apps, and next steps welcome note.
- **Git branch**: fix/burst-2-har-dump-fix merged into main with all sprint 4 changes including FINAL-REPORT, CHANGELOG, and README updates.
- **Test artifacts**: Cleaned git tree of comparison-burst-5.log and other transient results.

## Sprint 4-5 Results Overview

- **Burst 1**: Nurture Lock (FAIL - 95%), Nubo (FAIL - 95%), Pebbi (FAIL - 100%), Baby Buddy (PASS - 100%)
- **Burst 2**: Amila, Baby Daybook, Baby+ all phone home on launch. Firebase shared mechanism. Baby Daybook hits Facebook Graph + RevenueCat.
- **Burst 3-4**: Owlet ecosystem testing, dark pattern detection v1, MimiLog PASS (1 network call on launch despite "fully offline" claim)
- **Burst 5**: Nara (INCONCLUSIVE - Facebook/Firebase, TLS failures), Heartful Baby (INCONCLUSIVE - no network during 10s observation), Pixy (INCONCLUSIVE - Facebook SDK, pressure tactic heuristic)

## Key Findings Across All Bursts

- 8 of 9 apps with privacy claims sent data off-device despite marketing claims
- Only Baby Buddy (FOSS) and MimiLog (privacy-focused) behaved consistently with descriptions
- All "complete privacy," "HIPAA-compliant," and "bank-level encryption" claims contradicted by Firebase/Facebook SDK presence
- Dark pattern static analysis produced mostly false positives; dynamic UI pass needed

## Open Items / Backlog

- Burst 2: BabyTrack, Cradle blocked on Play Store access (need Google account on emulator-5554)
- Burst 4 backburner: Dymn Baby APK pending GitHub release
- Certificate pinning bypass for apps with TLS handshake failures (Nara, Heartful Baby, Pixy)
- Dynamic UI-automator pass for dark pattern verdicts
- Open-source harness publication (Sprint 5 planned)

## Next Sprint

Sprint 5 will focus on:
- Open-sourcing the test harness and methodology
- Dynamic UI-automator dark pattern detection
- Certificate pinning bypass implementation
- Cross-app analytics anomaly investigation (Nubo/Pebbi data sharing)
- Additional privacy claim verification