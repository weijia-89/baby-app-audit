# Roadmap Prompt v3  -  Multi-Team Agile Implementation

## Executive Summary

This prompt directs four agile teams to implement the baby-app-audit privacy harness roadmap over 4 sprints. Each team owns one task. Teams work in parallel with daily standups, shared CI gates, and cross-team dependencies managed by a Tech Lead.

**Context:** Repo at `/Users/dubs/Projects/apk-privacy-harness`, version 3.1.1. Piranesi S4 research has discovered 16+ new apps and deep-dived the Owlet wearable ecosystem. This prompt incorporates those findings.

---

## Team Structure

### Team Alpha  -  Live Data Collection Pipeline
- **Engineering Manager:** Scope and risk management
- **2 Senior SWEs:** Script development, schema design
- **QA Lead:** Test strategy, edge cases
- **TPM:** Sprint planning, dependency tracking

### Team Beta  -  Harness Restructure
- **Engineering Manager:** Architecture decisions, backward compatibility
- **2 Senior SWEs:** Part restructuring, FOSS integration
- **QA Lead:** Regression testing, structural validation
- **TPM:** Sprint planning, CI gate updates

### Team Gamma  -  New Apps & Expansion
- **Product Manager:** Candidate prioritization, tier definitions
- **Engineering Manager:** Matrix scaling, port allocation
- **2 Senior SWEs:** candidates.md, test entries, CI updates
- **QA Lead:** Matrix validation, smoke tests

### Team Delta  -  Research Prompts
- **Product Manager:** Prompt design, output specifications
- **Engineering Manager:** Prompt automation, integration points
- **1 Senior SWE:** Prompt templates, directory structure
- **QA Lead:** Output validation, schema checks

### Cross-Team Roles
- **Tech Lead (you):** Integration, conflict resolution, final review
- **Security Advisor:** All teams consult on encryption, legal auth, data handling
- **DevOps Lead:** CI/CD updates across all teams

---

## Cross-Team Standards (30 Best Practices)

These apply to ALL teams:

### Git & Branching (5)
1. Feature branches from `origin/main`  -  never commit to main directly
2. Branch naming: `feat/<team>-<task>-<description>`
3. One commit per logical change; atomic commits
4. Commit messages follow conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`
5. Rebase before PR; no merge commits in feature branches

### Code Quality (10)
6. `bash -n` on all shell scripts before commit
7. `shellcheck` clean (zero warnings) on all shell scripts
8. `python3 -m json.tool` on all JSON files
9. Banned vocab check: six words forbidden — see CONTEXT.md section "Banned vocabulary"
10. All `.md` files pass: simple-english → tic → deai → banned vocab
11. Replace em-dashes with " - " in all prose
12. Active voice, short sentences (20 words or fewer)
13. No AI slop (passive in active contexts, latinate where plain works)
14. Code blocks in APK_PRIVACY_TEST_HARNESS.md are untouchables unless operator approves
15. Version-pin all external tools; record exact version in run log

### Testing (5)
16. Write failing test before fixing bug (TDD discipline)
17. Every script has `--help` or usage message
18. Input validation on all user-facing scripts
19. Edge case coverage: empty input, malformed JSON, missing files
20. Regression tests for any changed behavior

### Security & Privacy (5)
21. Encrypt captured reproductive-health data at rest (age or similar)
22. Minimize data retention; set hard retention-and-deletion policy
23. Document legal authorization for TLS interception before capture
24. Segmented network for capture environment
25. Use throwaway accounts only; never seed real PII

### Documentation (5)
26. Update CHANGELOG.md for every version bump
27. Update README.md if behavior changes
28. Update CONTEXT.md if repo state changes
29. Every PR uses the PR template (Summary, Changes, Test plan, Notes)
30. All findings use canonical evidence schema; every field provenance-tracked

---

## Sprint 1 (Weeks 1-2)

### Team Alpha  -  Live Data Collection Pipeline

**Backlog:**
- Update Part 8.5 in harness doc with per-product retention, security EOL/CVE, device identity
- Update decode-traffic.sh v2 with new schema fields
- Add localonly/entries/TIMESTAMP_LOG.md template
- Update run-tests.sh with --live flag and tool version recording
- Implement evidence handling (immutable, encrypted, segmented)

**Best Practices (25):**
31. Per-product retention tracking: Sock indefinite, Sight 30 days, clips 14 days
32. Security EOL/CVE tracking: Cam 2 EOL 2027, CVE-2023-6321/6323/6324
33. Device identity resolution: MDR vs RED regimes, Basic UDI-DI vs model
34. Schema v2: backward-compatible with v1; add retention_schedule, security_eol, cve_list, regulatory_regime
35. Version-pin mitmproxy, Frida, exodus-CLI; record in run log
36. Immutable evidence storage: sha256 + timestamp
37. Encrypt at rest: age or similar tool
38. Log all access to raw captures
39. Segmented network: capture environment isolated from production
40. Document legal authorization for TLS interception
41. Throwaway accounts only; no real PII in captures
42. decode-traffic.sh handles JSON, form-encoded, skips binary/chunked
43. Input validation: HAR exists, valid JSON, contains entries array
44. Output schema validation before writing
45. Usage message: `./decode-traffic.sh <capture.har> <package_name> [output.json]`
46. Filter by app package name against URL host and headers
47. Extract response headers: Set-Cookie, Cache-Control, Expires
48. Distinguish realtime_bidding vs data_broker_sale in mechanism field
49. Schema versioned: "$schema": "decode-traffic/2.0"
50. Add decode-traffic.schema.json to results/
51. --live flag in run-tests.sh: skip if mitmproxy not available
52. Record mitmproxy version in run log
53. Timestamp correlation: log each data entry with timestamp
54. Cross-reference timestamps with capture to identify phoned-home data
55. All counts reported as lower bounds (cert pinning, obfuscation cause undercounting)

**Acceptance Criteria:**
- [ ] Schema v2 validates all new fields
- [ ] decode-traffic.sh passes shellcheck
- [ ] --live flag works (skip if mitmproxy absent)
- [ ] Evidence handling encrypts and hashes correctly
- [ ] CI gates: Part 8.5 exists, schema validates, banned vocab 0 hits

**Dependencies on other teams:** None (enables Team Beta)

---

### Team Beta  -  Harness Restructure

**Backlog:**
- Audit Parts 1-8; add parallel FOSS path with **[FOSS]** tag
- Remove Part 5.5 as standalone; merge into restructured Parts
- Update agent plan JSON (remove Part 5.5 node, add per-product scoring)
- Update run-tests.sh: babybuddy uses unified flow
- Update CI: babybuddy grep, Part 8.5 grep, regression checks

**Best Practices (25):**
56. Non-FOSS path unchanged: untouchable code blocks stay byte-identical
57. **[FOSS]** tag consistent across all FOSS-specific steps
58. Agent plan JSON updated: DAG changes, rule count, rule references
59. test_foss_app adapted to unified flow (not special case)
60. CI test.yml: babybuddy grep changed from "Part 5.5" to **[FOSS]** tag
61. CI test.yml: Part 8.5 added to lint-and-validate
62. CI test.yml: regression check counts Part headers >= 11
63. CI canary.yml: remove "Part 5.5" grep, add "Part 8.5"
64. Backward compatibility: existing test flows unchanged
65. Migration path for existing results JSON (optional fields, schema versioning)
66. Per-product test paths: different devices need different flows
67. Regime-split device identity module: MDR vs RED test paths
68. Medical-device path: encryption at rest for health data checks
69. RED radio path: consumer RF/telecom checks
70. Failures in one regime do not block another
71. test_foss_app case-based repo_url resolution preserved
72. validate_input strict/relaxed modes preserved
73. Part 7 cleanup: `adb root || true` + post-rm verification preserved
74. `set -uo pipefail` (no `-e`) in cleanup preserved
75. Proxy readback after set preserved
76. mitmproxy readiness: curl poll, not kill -0 preserved
77. All loop 3 fixes preserved (see DO NOT REVERT list in CONTEXT.md)
78. Feature branch: `feat/beta-harness-restructure`
79. Version bump if harness doc changes (operator approves)
80. Run bash -n && shellcheck after every script change

**Acceptance Criteria:**
- [ ] All Part headers 0-10 + 8.5 present
- [ ] babybuddy uses unified flow
- [ ] **[FOSS]** tags exist in all restructured Parts
- [ ] Regression test: existing non-FOSS paths still work
- [ ] CI gates pass: lint, JSON, version agreement, banned vocab

**Dependencies:** Team Alpha (schema v2 for per-product fields)

---

### Team Gamma  -  New Apps & Expansion

**Backlog:**
- Expand candidates.md with 16+ discovered apps in tiers
- Create skeleton test entries for Tier 1-2 apps
- Update run-tests.sh matrix: port allocation 8080-8095
- Update test.yml matrix to match
- Update CHANGELOG with new apps

**Best Practices (20):**
81. candidates.md structured: Tier 1 (immediate), Tier 2 (full audit), Tier 3 (backlog), Out of scope
82. Each candidate: name, platform, package name, source, privacy posture, evidence type
83. Evidence type tagging: exodus_static, network_capture, policy_text, manual_audit, external_citation
84. Deduplication check against existing candidates
85. Source attribution: link to Piranesi S4 reconcile ingest
86. Priority tier based on user-base estimates and risk
87. riafy marked out of scope (removed from Play, 170 downloads)
88. Pregnancy apps (What to Expect, BabyCenter) marked as pregnancy, not baby-milestone
89. Wearable/IoT in Phase 2: Owlet ecosystem devices
90. Per-product config: retention, EOL, regime for each app
91. Port allocation: unique PROXY_PORT per app (8080 + index)
92. Matrix scaling: 16 apps max, ports 8080-8095
93. CI test.yml: matrix matches new apps and ports
94. CI timeout: ensure 120 minutes sufficient for expanded matrix
95. Smoke tests for each new app: verify harness structure contains app name
96. Version bump: update HARNESS_VERSION across all artifacts
97. Update results/schema.json if new fields needed
98. Add app-specific procedures to harness doc (Part sections)
99. Baby Buddy retained as FOSS baseline
100. All new apps go through simple-english → tic → deai → banned vocab

**Acceptance Criteria:**
- [ ] candidates.md has 16+ apps with full metadata
- [ ] Tier 1-2 apps have skeleton test entries
- [ ] Port allocation unique per app
- [ ] Matrix CI passes within timeout
- [ ] All new apps pass banned vocab and DEAI

**Dependencies:** Team Beta (unified test flow), Team Alpha (schema v2)

---

### Team Delta  -  Research Prompts

**Backlog:**
- Create prompts/ directory with 4 markdown files
- Define output schemas for all prompts
- Add results/research/ directory for outputs
- Update README.md Roadmap section

**Best Practices (20):**
101. Prompt 01 (find-tracking-apps): include 16+ discovered apps as baseline
102. Prompt 02 (data-analysis-techniques): add per-product retention scoring, security posture scoring
103. Prompt 03 (related-studies): include all prior art identified in S4 canons
104. Prompt 04 (device-identity-research): new prompt for regulatory identity mapping
105. Each prompt: objective, constraints, output format (JSON only), confidence rubric
106. Each prompt: prior art check instruction, cross-prompt dedup instruction
107. Each prompt: how results feed back into harness (specific file/section)
108. Reference to S4.2 canon as source of truth
109. Confidence rubric: primary source = up to 95, single study = up to 70, etc.
110. No hedging; use "unverified" if uncertain
111. Cite all sources with URLs
112. No "first to do X" or "no prior art" claims
113. Output save path: results/research/01-apps.json, etc.
114. prompts/ directory tracked in git (not gitignored)
115. Verify prompts with `verify_prompts_md.py` if available
116. Prompt templates exported via piranesi skill if available
117. All prompts pass DEAI scan and banned vocab check
118. README.md updated to mention research prompts
119. Cross-prompt dedup: check for overlap between 02 and 03 outputs
120. Each prompt tagged with roadmap task it feeds into

**Acceptance Criteria:**
- [ ] 4 prompt files in prompts/
- [ ] Each prompt has all required sections
- [ ] Output schemas defined and valid
- [ ] All prompts pass DEAI and banned vocab
- [ ] README.md updated

**Dependencies:** None (enables future research)

---

## Sprint 2 (Weeks 3-4)

### Cross-Team Integration
- Tech Lead reviews all Sprint 1 outputs
- Resolve conflicts between teams
- Merge feature branches into integration branch
- Run full CI suite

### Team Alpha
- Implement evidence schema migration v1 → v2
- Add retention diff alerts
- Build EU Data Act Disclosure scraper target

### Team Beta
- Implement per-product test paths
- Add regime-split device identity module
- Update CI for per-product checks

### Team Gamma
- Begin Tier 1 app testing (BabyTrack, Amila, Wachanga)
- Implement per-app privacy posture profiler
- Add evidence type taxonomy to CI

### Team Delta
- Execute Prompt 01: find additional tracking apps
- Validate output schema against harness requirements
- Begin Prompt 04: device identity research on Owlet

---

## Sprint 3 (Weeks 5-6)

### Cross-Team Integration
- Full e2e testing across all teams' work
- Performance testing: matrix scaling, port allocation
- Security review: encryption, access logs, retention

### Team Alpha
- Build security EOL/CVE monitor (NVD API integration)
- Implement retention schedule diff engine
- Add per-product retention scoring to evidence schema

### Team Beta
- Implement FOSS test path automation
- Add **[FOSS]** tag validation to CI
- Complete Part restructuring with all FOSS paths

### Team Gamma
- Complete Tier 2 app entries (NighP, Milli, Pebbi, Baby Connect, SNUGL)
- Add wearable/IoT devices to candidates (Owlet ecosystem)
- Update test matrix for wearable-specific paths

### Team Delta
- Execute Prompt 02: build scoring rubric with retention and security posture
- Execute Prompt 03: gap analysis with recommended harness additions
- Integrate all prompt outputs into harness docs

---

## Sprint 4 (Weeks 7-8)

### Cross-Team Integration
- Final QA pass: all teams' work integrated
- Regression testing: all 4 original apps + 16 new apps
- Performance validation: CI passes within timeout
- Security audit: all encryption, access logs, retention policies verified

### Team Alpha
- Finalize decode-traffic.sh v2 with all fields
- Complete evidence handling documentation
- Hand off to Team Beta for integration

### Team Beta
- Finalize harness restructure
- Complete agent plan JSON updates
- All CI gates green

### Team Gamma
- Finalize candidates.md with all tiers
- Complete CHANGELOG updates
- Version bump to 3.2.0 (operator approves)

### Team Delta
- Finalize all 4 prompt templates
- Complete results/research/ directory setup
- Update all downstream documentation

---

## Definition of Done (All Teams)

We mark a task complete only after this checklist passes:

- [ ] Code written and tested locally
- [ ] `bash -n` passes on all scripts
- [ ] `shellcheck` clean on all scripts
- [ ] `python3 -m json.tool` validates all JSON
- [ ] Banned vocab 0 hits on all docs
- [ ] DEAI scan passes on all .md files
- [ ] simple-english pragmatic mode verified
- [ ] tic style check passed
- [ ] All new .md files through full pipeline
- [ ] CI gates pass: Part headers, $schema, version agreement, banned vocab
- [ ] Regression tests pass: existing functionality unchanged
- [ ] Documentation updated: CHANGELOG, README, CONTEXT if applicable
- [ ] PR created with template (Summary, Changes, Test plan, Notes)
- [ ] Operator approval obtained before merge
- [ ] Feature branch rebased on latest main
- [ ] No merge commits in feature branch
- [ ] Commit messages follow conventional commits

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Schema v2 breaks existing results | Medium | High | Backward-compatible optional fields; migration script |
| Port exhaustion with 16+ apps | Low | Medium | Port range 8080-8095; verify no conflicts |
| CI timeout with expanded matrix | Medium | Medium | Parallel job limit; sequential fallback |
| Encryption key management | Low | High | age tool; document key rotation procedure |
| NVD API rate limits | Medium | Low | Cache CVE data; fallback to manual lookup |
| FOSS path incomplete | Medium | High | **[FOSS]** tag validation in CI; operator review |
| Prompt output drift | Medium | Medium | JSON schema validation; automated checks |

---

## Appendices

### A. Research Findings Summary
(See ROADMAP-PROMPT-v2.md for full synthesized research)

### B. Candidate App Registry
(See localonly/candidates.md after Team Gamma Sprint 1)

### C. Evidence Schema v2
(See results/decode-traffic.schema.json after Team Alpha Sprint 1)

### D. CI Gate Checklist
- Part headers 0-10 + 8.5 in APK_PRIVACY_TEST_HARNESS.md
- `"$schema"` declaration in harness doc
- `HARNESS_VERSION="3.1.1"` in run-tests.sh, test.yml (or bumped version)
- `## 3.1.1` (or bumped) in CHANGELOG.md
- Banned vocab 0 hits on 5+ docs
- JSON validation on results/schema.json and results/RESULTS-20260803.json
- `bash -n scripts/run-tests.sh` + shellcheck
- Schema version check
- Port count check (matrix apps <= allocated ports)

### E. Version Bump Procedure
1. Update HARNESS_VERSION in run-tests.sh
2. Update HARNESS_VERSION in .github/workflows/test.yml
3. Update HARNESS_VERSION in .github/workflows/canary.yml
4. Add version section to CHANGELOG.md
5. Verify version agreement across all 4 locations
6. Operator approves version number

### F. Research Prompt Output Schema
- results/research/01-apps.json
- results/research/02-rubric.json
- results/research/03-gaps.json
- results/research/04-identities.json
