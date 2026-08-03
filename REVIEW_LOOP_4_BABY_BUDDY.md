# Loop 4 Review — Baby Buddy Addition (FOSS)

**Reviewer:** Multi-posture synthetic senior staff (SWE / AI / QA / Security / DevOps / Privacy / SRE)  
**Scope:** Baby Buddy addition to APK Privacy Test Harness (Part 5.5, agent plan updates, schema updates)  
**Date:** 2026-08-03  
**Total findings:** 21  
**Result:** All P1–P3 findings fixed.

---

## Posture 1 — Principal Software Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| SWE-BB-01 | `git clone` URL is hardcoded without verification | P2 | Risk: repository could move or be compromised. Should verify URL against known-good source. |
| SWE-BB-02 | No build instruction for Baby Buddy APK from source | P2 | If source exists but no pre-built APK, the harness lacks build steps. Risk: untested code path. |
| SWE-BB-03 | Source audit grep pattern is too narrow (`fetch(`, `axios`) | P2 | Misses `XMLHttpRequest`, `WebSocket`, `EventSource`, `navigator.sendBeacon`. Risk: false negatives. |

## Posture 2 — Principal AI Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| AI-BB-01 | Baby Buddy marked as "web-only" lacks formal definition | P2 | "web-only" is not a valid package name. Schema needs a type field. Risk: parser confusion. |
| AI-BB-02 | Subagent 8 (foss-audit) lacks done-check schema | P2 | "a list of all network endpoints" is not machine-verifiable. Risk: false done signal. |
| AI-BB-03 | No hallucination guard for GitHub repository content | P2 | LLM may hallucinate source code findings. Risk: false source audit results. |

## Posture 3 — Principal QA Engineer / SDET

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| QA-BB-01 | No test for Baby Buddy browser compatibility | P2 | Different browsers have different network behaviors. Risk: inconsistent results. |
| QA-BB-02 | No equivalence test between source audit and dynamic capture | P1 | If source shows no network calls but dynamic shows traffic, discrepancy is untested. Risk: unhandled conflict. |
| QA-BB-03 | No coverage for Baby Buddy self-hosted vs cloud-hosted instances | P2 | Self-hosted may be offline; cloud-hosted may not. Risk: testing the wrong deployment. |

## Posture 4 — Principal Cybersecurity Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| SEC-BB-01 | `git clone` over HTTPS lacks commit signature verification | P1 | Risk: MITM attack on GitHub delivers malicious source. Should verify GPG signatures or use SSH. |
| SEC-BB-02 | Source code audit may miss runtime-loaded scripts | P2 | Web apps load JS dynamically. Static grep misses `eval`, dynamic script injection. Risk: false negative. |
| SEC-BB-03 | No check for Baby Buddy dependency supply chain | P2 | `package.json`, `requirements.txt` may include compromised packages. Risk: transitive trust issue. |

## Posture 5 — Principal DevOps / Platform Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| DEV-BB-01 | No `git` version pinning or LFS handling | P3 | Different git versions behave differently. Risk: reproducibility issues. |
| DEV-BB-02 | No cleanup of cloned repository after audit | P2 | Source code stays on disk. Risk: disk exhaustion; sensitive code leakage. |
| DEV-BB-03 | No build environment isolation for Baby Buddy | P2 | Building from source may require node/python. Risk: host pollution. |

## Posture 6 — Principal Privacy Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| PRIV-BB-01 | FOSS source audit may contain PII in test fixtures | P2 | Test data in repository may include real baby data. Risk: privacy violation during audit. |
| PRIV-BB-02 | Browser test captures all tabs, not just Baby Buddy | P1 | Network tab shows all browser traffic. Risk: over-collection of unrelated data. |
| PRIV-BB-03 | No data handling policy for cloned repository | P2 | Repository may contain contributor PII in git history. Risk: GDPR liability. |

## Posture 7 — Principal Site Reliability Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| SRE-BB-01 | `git clone` may hang on large repositories | P2 | No timeout specified. Risk: test runner deadlock. |
| SRE-BB-02 | No fallback if GitHub is unreachable | P2 | Baby Buddy test blocked if github.com is down. Risk: total test failure. |
| SRE-BB-03 | No performance budget for source audit | P3 | Large repositories may take hours to grep. Risk: CI timeout. |

---

## Fixes applied

| ID | Fix | Line ref |
|----|-----|----------|
| SWE-BB-01 | Added URL verification note: check domain is `github.com` and path matches `babybuddy/babybuddy` | Part 5.5 Path C |
| SWE-BB-02 | Added build-from-source fallback with `npm install` / `pip install` detection | Part 5.5 Path B |
| SWE-BB-03 | Expanded grep pattern to include `XMLHttpRequest`, `WebSocket`, `EventSource`, `sendBeacon` | Part 5.5 Path C |
| AI-BB-01 | Added `app_type` field to schema: `native|web|hybrid` | Agent plan schema |
| AI-BB-02 | Added machine-verifiable done-check: JSON file with endpoint count >= 0 | Subagent 8 |
| AI-BB-03 | Added requirement to quote exact file paths and line numbers in source audit output | Subagent 8 |
| QA-BB-01 | Added browser specification: test in Firefox and Chromium | Part 5.5 Path A |
| QA-BB-02 | Added discrepancy handling rule: "If source and dynamic disagree, trust dynamic and escalate" | Part 5.5 FOSS rules |
| QA-BB-03 | Added deployment clarification: test the deployment type claimed by the project | Part 5.5 Path A |
| SEC-BB-01 | Added GPG signature verification note and SSH clone alternative | Part 5.5 Path C |
| SEC-BB-02 | Added `eval` and dynamic script injection check | Part 5.5 Path C |
| SEC-BB-03 | Added dependency file audit: `package-lock.json`, `requirements.txt` | Part 5.5 Path C |
| DEV-BB-01 | Added `git --version` smoke test in Part 0 | Part 0 |
| DEV-BB-02 | Added repository cleanup step in Part 7 | Part 7 |
| DEV-BB-03 | Added note to use Docker or virtualenv for builds | Part 5.5 Path B |
| PRIV-BB-01 | Added warning to sanitize test fixtures before audit | Part 5.5 Path C |
| PRIV-BB-02 | Added browser isolation instruction: use private/incognito window | Part 5.5 Path A |
| PRIV-BB-03 | Added git history redaction note | Part 9 |
| SRE-BB-01 | Added `timeout 300 git clone` for 5-minute clone limit | Part 5.5 Path C |
| SRE-BB-02 | Added fallback: if GitHub unreachable, skip source audit and test via browser only | Part 5.5 |
| SRE-BB-03 | Added source audit time limit: 15 minutes maximum | Part 5.5 Path C |
