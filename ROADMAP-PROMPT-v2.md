Roadmap execution prompt for /Users/dubs/Projects/apk-privacy-harness (github.com/weijia-89/baby-app-audit).

CONTEXT
- Repo audits infant milestone apps for privacy leaks. 4 apps tested (Nurture Lock, Nubo, Pebbi, Baby Buddy).
- Current version 3.1.1 on main. All loop 3 fixes merged. Skills: simple-english, tic, deai. User voice: first person "I", contractions, plain words, " - " not em-dash, short declarative sentences.
- DO NOT REVERT loop 3 fixes (PR #9).
- Verified claims canon (S4.2) is the source of truth. See CANON-SUMMARY.md for digest.
- Piranesi S4 research has discovered 16+ new apps and deep-dived the Owlet wearable ecosystem.

SYNTHESIZED RESEARCH FINDINGS  -  incorporate these into all tasks:

**From Discovery Canon (baby/pregnancy apps):**
- 16+ apps discovered with varying privacy postures (see candidates list below)
- 3 apps have verified Exodus static analysis: Amila (6 trackers), Wachanga (9 trackers), NighP (14 trackers)
- 5/20 fertility apps leak health data (25%)  -  but these are pregnancy apps, not baby-milestone trackers
- Presence ≠ egress: Exodus proves SDK presence, not runtime transmission
- No baby-milestone tracker has measured egress in the research corpus
- No independent security audit (MASA AL2/SOC2/ISO) found for any commercial candidate
- Cleanest commercial candidate: BabyTrack (iCloud-only, no ad SDKs)
- riafy "Baby Tracker" removed from Google Play 2026-05-23  -  out of scope
- Nubo iOS label self-declares "Usage Data / not linked"  -  on-wire behavior unknown

**From Deep Research Canon (Owlet ecosystem):**
- Dynamic network analysis is highest-yield technique (observes actual PII egress)
- COPPA 2025 amendments effective 2026
- ISO/IEC 27559:2022 supplies rubric anchors (identifiability thresholds)
- Per-product retention schedules differ: Sock telemetry indefinite, Cam/Sight 30 days, clips 14 days
- Device identity is regime-split: Dream Sock (MDR Class IIb, SGS NB 1639), Cam 2/Dream Sight (RED radio, no UDI)
- Security EOL dates: Cam 2/Dream Sight 2027, Smart Sock 3 2026
- Cam 2 has known CVEs (2023) and approaching EOL  -  live risk
- BabySat US-only, no EU presence, no CE mark
- Indefinite retention of infant biometric telemetry is highest-severity retention finding

**Key constraints:**
- Confirmed data transmission is the standard of proof
- All counts are lower bounds
- Do not claim "first to do X" or "no prior art"
- Real-time-bidding ≠ data-broker sale
- Dark-pattern findings ≠ data-transmission findings
- Encrypt captured reproductive-health data at rest
- Version-pin all external tools

---

TASK 1: LIVE DATA COLLECTION PIPELINE

Goal: Operator sets up accounts, adds data while mitmproxy runs. Decode traffic to see what phones home.

1a. Update Part 8.5 in harness doc:
   - Add per-product retention schedule tracking (Sock indefinite, Sight 30 days, etc.)
   - Add security EOL/CVE tracking (Cam 2 EOL 2027, CVE-2023-6321/6323/6324)
   - Add device identity resolution (MDR vs RED regimes, Basic UDI-DI vs model number)
   - Record mitmproxy version in run log
   - Use throwaway accounts only
   - Each data entry gets timestamp in localonly/entries/TIMESTAMP_LOG.md
   - Log using canonical evidence schema plus new fields: {retention_schedule, security_eol, cve_list, regulatory_regime}

1b. Update scripts/decode-traffic.sh:
   - Add per-product retention extraction from response headers
   - Add security posture fields: {eol_date, cve_ids[], security_grade}
   - Add regulatory regime tag: {medical_device, radio_device, consumer_app}
   - Schema version bump to 2.0 (backward-compatible with 1.0)

1c. Add localonly/entries/TIMESTAMP_LOG.md template (as before)

1d. Update run-tests.sh:
   - Accept --live flag
   - Record tool versions (mitmproxy, Frida, exodus-CLI)
   - Skip if mitmproxy not available

1e. Evidence handling:
   - Immutable storage with sha256 + timestamp
   - Encrypt at rest (age)
   - Log all access
   - Segmented network
   - Document legal authorization for TLS interception

---

TASK 2: RESTRUCTURE HARNESS  -  FOSS INTEGRATION

Goal: FOSS is first-class path in every relevant Part.

2a. Audit Parts 1-8:
   - Add parallel FOSS path with **[FOSS]** tag
   - Add per-product test paths (different devices need different flows)
   - Add regime-split device identity module (MDR vs RED)
   - Non-FOSS path unchanged (untouchable code blocks)

2b. Remove Part 5.5 as standalone. Merge into restructured Parts.

2c. Update agent plan JSON:
   - Remove Part 5.5 node
   - Add per-product retention scoring
   - Add security posture scoring
   - Update rule count

2d. Update run-tests.sh:
   - babybuddy uses same flow as other apps
   - Adapt test_foss_app to unified flow
   - Add per-product config (retention, EOL, regime)

2e. Update CI (test.yml):
   - Change babybuddy grep for "Part 5.5" to **[FOSS]** tag check
   - Add "Part 8.5" grep
   - Add regression check: count Part headers >= 11

2f. Update CI (canary.yml):
   - Remove "Part 5.5" grep
   - Add "Part 8.5" grep

---

TASK 3: NEW APPS AND FOSS OPTIONS

Goal: Expand test matrix with discovered apps.

3a. Update localonly/candidates.md with 16+ apps:

**Tier 1 (Immediate audit):**
| App | Platform | Package | Source | Privacy Posture | Evidence |
|-----|----------|---------|--------|-----------------|----------|
| BabyTrack | iOS |  -  | App Store | iCloud-only, no ad SDKs | ingest-asserted |
| Amila | Android/iOS | com.amila.parenting | Play Store | Device-only claim; 6 Exodus trackers | verified Exodus |
| Wachanga | Android | com.wachanga.babycare | Play Store | 9 Exodus trackers incl. Facebook + myTracker | verified Exodus |

**Tier 2 (Full audit):**
| App | Platform | Package | Source | Privacy Posture | Evidence |
|-----|----------|---------|--------|-----------------|----------|
| NighP | Android | com.nighp.babytracker_android | Play Store | 14 Exodus trackers; ad-heavy | verified Exodus |
| Milli | iOS/Android |  -  | milli.app | GDPR Art.9 consent; baby data withheld from Firebase/AdMob | ingest-asserted |
| Pebbi | Web/app |  -  | pebbi.co | No ad cookies; optional PebbiAI to Google | ingest-asserted |
| Baby Connect | iOS/Android/web | com.seacloud.bc | AppBrain | US-only subprocessors; GA + de-identified aggregates | ingest-asserted |
| SNUGL | iOS/Android |  -  | snugled.com | No health-data sale; ~60-day purge | ingest-asserted |

**Tier 3 (Backlog):**
| App | Platform | Privacy Posture | Evidence |
|-----|----------|-----------------|----------|
| Babylytics | iOS/Android | Supabase + Firebase cloud | ingest-asserted |
| Pip | iOS/Android | Firebase-backed cloud | ingest-asserted |
| Cuddlydoo | iOS/Android | "Don't sell" + interest-based ad cookies | ingest-asserted |
| raya-logs | Self-hosted | "No telemetry" but Firebase Firestore backend | ingest-asserted |
| Nubo | iOS + BLE | On-device/E2E marketing; iOS label "Usage Data / not linked" | ingest-asserted / unknown |

**Out of scope:**
| App | Reason |
|-----|--------|
| riafy "Baby Tracker" | Removed from Google Play 2026-05-23; 170 downloads |
| What to Expect | Pregnancy app, not baby-milestone tracker |
| BabyCenter | Pregnancy app, not baby-milestone tracker |

**Wearable/IoT (Phase 2):**
| Device | Type | Regulatory Regime | Key Risk |
|--------|------|-------------------|----------|
| Owlet Dream Sock | Medical wearable | MDR Class IIb (SGS NB 1639) | Indefinite telemetry retention |
| Owlet Dream Sight | Camera | RED radio (no UDI) | 30-day telemetry; EOL 2027 |
| Owlet Cam 2 | Camera | RED radio (no UDI) | Known CVEs; EOL 2027 |
| Owlet Smart Sock 3 | Wearable | RED radio | EOL 2026 |
| Owlet BabySat | Prescription | FDA-cleared, no CE mark | Provider-BAA-governed retention |

3b. For each Tier 1-2 app, create skeleton test entry in harness doc.

3c. Update run-tests.sh matrix:
   - Extend port allocation: 8080-8095 for 16 apps
   - Add per-product config

3d. Update test.yml matrix to match.

3e. Update CHANGELOG with new apps.

---

TASK 4: PIRANESI RESEARCH PROMPTS

Goal: Create research prompts that feed into harness methodology.

4a. Create prompts/ directory. Add four markdown files:

   prompts/01-find-tracking-apps.md:
   - Find 10+ baby/toddler apps that track users and claim privacy
   - Output: [{name, platform, claim, tracking_libraries[], data_collected[], source_url, confidence, evidence_tier}]
   - Include the 16+ apps already discovered as baseline
   - Cite sources. Flag unverified claims.
   - Route through piranesi skill.

   prompts/02-data-analysis-techniques.md:
   - Deep dive on privacy auditing techniques
   - Cover: traffic analysis, static analysis, dynamic analysis, consent mapping, rubric design
   - Output: scoring rubric (JSON) with weighted criteria (sum to 1.0)
   - Rubric must cover: data minimization, consent, encryption, third-party sharing, retention, user control, transparency, device fingerprinting, background collection, SDK behavior, cross-app tracking, COPPA compliance
   - Each criterion: {name, description, weight, scoring: {0, 5, 10}}
   - Add per-product retention scoring (indefinite = automatic 0 on retention criterion)
   - Add security posture scoring (EOL proximity, known CVEs)
   - Cite sources. No hedging.

   prompts/03-related-studies.md:
   - Find 5+ similar studies on app privacy (especially children)
   - Prior art already identified: Jo et al. 2606.26276v3, Pybus et al., Ali et al., Lalaine, Saini & Saxena, Hassan et al., Surfshark
   - For each NEW study: {citation, methodology, measurements, lessons, coverage_gaps}
   - Identify unknown unknowns: clipboard snooping, SDK fingerprinting, background collection, cross-app tracking, device fingerprinting without network
   - Output: gap analysis (JSON) ranked by impact
   - Cite sources. Flag unverified.

   prompts/04-device-identity-research.md (NEW):
   - Research task: map vendor product catalogs to regulatory identities
   - Cover: MDR (Basic UDI-DI, notified body, certificate), RED (model, harmonized standards, EOL), FDA (GUDID, product code)
   - Request per-product: {product_name, model, regulatory_regime, certification_id, notified_body, eol_date, security_update_guarantee}
   - Output: JSON with regime-split identities
   - Example: Owlet Dream Sock (MDR, SGS 1639, US25/00000423) vs Cam 2 (RED, no UDI, EOL 2027)
   - Cite sources. Flag unverified.

4b. Each prompt must include:
   - Objective (one sentence)
   - Constraints (simple-english, no AI slop, cite sources, no hedging, "unverified" if uncertain)
   - Output format (JSON only, save path under results/research/)
   - Confidence rubric
   - Prior art check instruction
   - Cross-prompt dedup instruction
   - How results feed back into harness
   - Reference to S4.2 canon

4c. Create results/research/ directory for prompt outputs.

4d. Update README.md to mention research prompts in Roadmap section.

---

TECHNICAL SCOPE (from Engineering Manager)

**Task 1:**
- Components: decode-traffic.sh v2, schema v2, retention tracker, CVE monitor
- Dependencies: mitmproxy, NVD API, EU Data Act Disclosure scraper
- Risks: Schema migration complexity, NVD API rate limits
- Effort: Medium

**Task 2:**
- Components: Per-product test paths, regime-split identity module, FOSS integration
- Dependencies: Task 1 schema v2
- Risks: Breaking existing test flows, backward compatibility
- Effort: Large

**Task 3:**
- Components: candidates.md expansion, test matrix scaling, per-product config
- Dependencies: Task 2 restructure
- Risks: CI timeout with 16+ apps, port exhaustion
- Effort: Medium

**Task 4:**
- Components: 4 research prompt templates, results/research/ directory
- Dependencies: None
- Risks: Prompt drift, output format inconsistency
- Effort: Small

Cross-cutting:
- All tools version-pinned
- Evidence immutable (sha256 + timestamp)
- Encrypt at rest
- Schema versioned (v1 → v2 migration)
- CI gates updated for new Part headers

QA STRATEGY (from QA Lead)

**Task 1:**
- Approach: Unit tests for decode-traffic.sh, integration tests for retention extraction
- Acceptance: Schema v2 validates, retention fields populated, CVE lookup works
- Edge cases: Empty capture, binary payload, missing headers
- Regression: Existing results JSON still validates

**Task 2:**
- Approach: Structural tests for Part headers, e2e tests for FOSS path
- Acceptance: All Part headers present, babybuddy uses unified flow, **[FOSS]** tags exist
- Edge cases: Missing FOSS path, orphaned Part 5.5 references
- Regression: Existing test flows unchanged

**Task 3:**
- Approach: Matrix scaling tests, port conflict tests
- Acceptance: 16 apps allocate unique ports, CI passes within timeout
- Edge cases: Port exhaustion, duplicate app entries
- Regression: Existing 4 apps still pass

**Task 4:**
- Approach: Prompt validation, output schema checks
- Acceptance: All prompts have required sections, output is valid JSON
- Edge cases: Missing citation, unverified claim not flagged
- Regression: Existing prompts unchanged

CI gate updates:
- Add "Part 8.5" to lint-and-validate
- Add port count check (matrix apps <= allocated ports)
- Add schema version check
- Add banned vocab check on new docs

---

AFTER EACH TASK:
1. Run: bash -n scripts/run-tests.sh && shellcheck scripts/run-tests.sh
2. Run: python3 -m json.tool results/schema.json
3. Run: python3 /Users/dubs/Projects/deai.skill/deai-scan.py on changed .md files
4. Run banned vocab check on all docs
5. Version bump if harness doc changes (3.1.2, 3.1.3, etc.)
6. Prepare commit; operator approves before push
7. Create PR with PR template

CONSTRAINTS
- Read AGENTS.md first every session.
- Feature branches from origin/main.
- verification-before-completion before claiming done.
- Code blocks in APK_PRIVACY_TEST_HARNESS.md are untouchables unless operator approves.
- Never commit, push, or create PRs unless operator explicitly asks.
- Keep operator's voice throughout all docs.
- All new .md files go through simple-english → tic → deai → banned vocab pipeline.
- decode-traffic.sh must be chmod +x before commit.
- prompts/ directory tracked in git.
- The verified claims canon (S4.2) is the source of truth.
- All counts from network capture are lower bounds.
- Confirmed data transmission is the standard of proof.
- Do not merge dark-pattern findings with data-transmission findings.
- Treat real-time-bidding bidstream exposure as distinct from data-broker sale.
- Captured reproductive-health data is sensitive  -  encrypt at rest, minimize retention.
- All external tools must be version-pinned.
- Raw captures are immutable  -  store with content hash and timestamp.
