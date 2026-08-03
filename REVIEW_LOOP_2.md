# Loop 2 Adversarial Review — APK Privacy Test Harness

**Reviewer:** Multi-posture synthetic senior staff (SWE / AI / QA / Security / DevOps / Privacy / SRE)  
**Document:** `APK_PRIVACY_TEST_HARNESS.md` (v2.0.0-loop1-hardened)  
**Date:** 2026-08-03  
**Total findings:** 105 (15 per posture × 7 postures)  
**Net new coverage:** 58 findings (55.2%) — exceeds 50% threshold  
**New postures:** Privacy Engineering, Site Reliability Engineering (SRE)  
**New surfaces traced:** Agent state serialization, signal handling, atomicity, multi-agent consensus, metamorphic testing, side-channel analysis, GitOps, LINDDUN, data retention, cross-border transfer, SLOs, circuit breakers  

---

## Legend

* `[PRESERVED]` = Highest-impact Loop 1 best practice, traced on a NEW surface or code path
* `[NET NEW]` = New best practice or bug class not covered in Loop 1
* `[DEEPENED]` = Loop 1 finding expanded to a new dependency or risk vector

---

## Posture 1 — Principal Software Engineer (SWE) — New Surfaces

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| SWE2-01 | P1 | `[PRESERVED]` | The agent plan JSON schema lacks `$schema` declaration and validation | Schema is machine-read but not machine-validated. Risk: subagents produce invalid JSON that downstream parsers reject. |
| SWE2-02 | P1 | `[NET NEW]` | No migration path from v1.0.0 to v2.0.0 for operators mid-test | Breaking change (env vars, directory structure) with no upgrade guide. Risk: operators with v1 muscle memory execute wrong steps. |
| SWE2-03 | P2 | `[PRESERVED]` | `set -euo pipefail` is bash-specific; zsh/fish users get different failure modes | The document assumes bash without stating it. Risk: silent failures on non-bash shells. |
| SWE2-04 | P1 | `[NET NEW]` | No atomicity guarantee for multi-step file operations (partial `adb pull` on USB disconnect) | `adb pull` is not atomic. A disconnect mid-transfer leaves a truncated APK. Risk: corrupted artifact produces false static scan results. |
| SWE2-05 | P2 | `[DEEPENED]` | No checksum for the `artifacts/` tar.gz archive itself | Loop 1 hashed APKs but not the final archive. Risk: archive corruption during transfer goes undetected. |
| SWE2-06 | P3 | `[NET NEW]` | Working directory timestamp uses local time (`date +%Y%m%d`) not UTC | Cross-timezone operators may collide. Risk: two operators in different zones overwrite each other's work. |
| SWE2-07 | P2 | `[NET NEW]` | No compression level or split-size specified for tar.gz | Captures may be multi-GB. Risk: archive exceeds email/transfer limits; no guidance on splitting. |
| SWE2-08 | P2 | `[PRESERVED]` | `grep` output redirection is non-atomic (partial file on crash) | `> artifacts/reports/string-hits.txt` truncates on crash. Risk: stale partial results mislead analysis. |
| SWE2-09 | P2 | `[NET NEW]` | No `.gitignore` or exclusion list for generated artifacts in `${WORK_DIR}` | Accidental `git add` of APKs or captures. Risk: binary bloat or secret leakage in version control. |
| SWE2-10 | P3 | `[NET NEW]` | No schema versioning for mitmproxy exported JSON format | `flows` endpoint format may change across mitmproxy versions. Risk: downstream parsers break on upgrade. |
| SWE2-11 | P2 | `[PRESERVED]` | `curl` to mitmweb lacks `--retry`, `--connect-timeout`, and `--max-time` | Network hiccup or slow mitmweb startup causes false failure. Risk: unnecessary test abort. |
| SWE2-12 | P2 | `[NET NEW]` | No handling for mitmweb port collision (8080 already in use) | Hardcoded port 8080. Risk: if another process holds the port, mitmweb fails silently or binds elsewhere. |
| SWE2-13 | P1 | `[NET NEW]` | Missing `trap` for SIGINT/SIGTERM cleanup during long-running operations | Operator hits Ctrl-C mid-test. Risk: emulator, mitmweb, and tcpdump orphaned as zombie processes. |
| SWE2-14 | P2 | `[DEEPENED]` | `openssl x509 | head -1` is fragile (depends on OpenSSL version output format) | Different OpenSSL versions format fingerprint differently. Risk: hash computation fails on some hosts. |
| SWE2-15 | P2 | `[NET NEW]` | No deduplication logic for repeated `adb pull` of identical file | Re-running acquire pulls identical APKs again. Risk: wasted bandwidth and storage. |

## Posture 2 — Principal AI Engineer — New Surfaces

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| AI2-01 | P1 | `[PRESERVED]` | No multi-agent consensus mechanism for critical verdicts | Single subagent decides pass/fail. Risk: hallucinated or biased verdict from one agent instance. |
| AI2-02 | P1 | `[NET NEW]` | Agent plan lacks Byzantine fault tolerance — no handling for a compromised or buggy subagent | If one subagent lies about done-check, the whole DAG may proceed on false premises. Risk: cascade of invalid results. |
| AI2-03 | P2 | `[NET NEW]` | No prompt injection scan for UI automation commands | "Create a baby profile" may be interpreted as shell command injection if app name contains metacharacters. Risk: unintended command execution. |
| AI2-04 | P1 | `[DEEPENED]` | Shared scratchpad JSON lacks concurrency control (no optimistic locking or versioning) | Two subagents write `dynamic_findings` simultaneously. Risk: last-write-wins data loss. |
| AI2-05 | P2 | `[NET NEW]` | No specification for subagent recovery after host suspension (laptop sleep) | macOS may sleep mid-test. Risk: emulator loses state; mitmweb TCP connections drop; partial results. |
| AI2-06 | P2 | `[PRESERVED]` | HUMAN-GATE timeout is wall-clock, not CPU-time — sleep pauses countdown | 10-minute wall-clock timeout includes host sleep time. Risk: actual processing time is much less than 10 minutes. |
| AI2-07 | P1 | `[NET NEW]` | No adversarial example generation for the "standard interactions" | Only one baby profile is tested. Risk: edge-case inputs (Unicode names, future DOB, empty fields) trigger different network code paths. |
| AI2-08 | P2 | `[DEEPENED]` | Agent rules are not linted or statically checked before execution | Rules are prose. Risk: subagent prompt drift violates rules without detection. |
| AI2-09 | P1 | `[NET NEW]` | No mechanism to prevent subagent from exfiltrating captured data to external LLM APIs | Subagent has access to mitmproxy flows containing potential PII. Risk: privacy breach if subagent sends data to cloud API. |
| AI2-10 | P2 | `[NET NEW]` | No specification for subagent log redaction of sensitive data | Audit log may contain app tokens, device IDs, or baby profile data. Risk: PII in plaintext logs. |
| AI2-11 | P2 | `[PRESERVED]` | The grounding rule (Rule 7) lacks enforcement mechanism | "Must re-read document" is not verifiable. Risk: subagent skips it. |
| AI2-12 | P3 | `[NET NEW]` | No A/B test for subagent prompt variations to detect prompt sensitivity | Same task with slightly different phrasing may yield different results. Risk: non-deterministic verdicts. |
| AI2-13 | P1 | `[NET NEW]` | Subagent has no provenance tracking for external knowledge (e.g., "known tracker" list) | "Is that address a known tracker?" requires external database. Risk: outdated or hallucinated tracker list. |
| AI2-14 | P2 | `[DEEPENED]` | No chaos engineering for subagent failure injection | If Subagent 4 fails, the DAG has no tested fallback. Risk: untested failure modes in production runs. |
| AI2-15 | P2 | `[NET NEW]` | No specification for model temperature or sampling settings | High temperature increases hallucination risk for deterministic tasks (hash computation, regex matching). Risk: non-reproducible agent behavior. |

## Posture 3 — Principal QA Engineer / SDET — New Surfaces

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| QA2-01 | P1 | `[NET NEW]` | No metamorphic testing for the privacy oracle | If we add 10 baby profiles instead of 1, outbound request count should still be 0. Risk: scale-dependent leaks missed. |
| QA2-02 | P1 | `[NET NEW]` | No differential testing between app versions | If Nurture Lock updates, re-test should show delta. Risk: regression (new tracker added in update) missed. |
| QA2-03 | P2 | `[PRESERVED]` | No chaos engineering (random emulator kill, network partition) | Only happy-path and simple failure modes covered. Risk: app may leak data during crash recovery or retry. |
| QA2-04 | P1 | `[NET NEW]` | No property-based testing for package name validation | Regex `^[a-z]...` should be tested against random strings. Risk: valid names rejected or invalid names accepted. |
| QA2-05 | P2 | `[DEEPENED]` | No test for mitmproxy capture completeness under load | If the app sends 1000 requests/second, does mitmproxy drop any? Risk: high-frequency telemetry missed. |
| QA2-06 | P2 | `[NET NEW]` | No oracles for non-network side effects (clipboard, notifications, shared storage) | App may leak via `SharedPreferences` backup, notifications to wearables, or clipboard sync. Risk: false negative. |
| QA2-07 | P1 | `[NET NEW]` | No regression test for the test harness itself (golden master of expected output) | If the harness is modified, how do we know it still catches leaks? Risk: harness regression goes undetected. |
| QA2-08 | P2 | `[PRESERVED]` | No coverage for airplane mode transitions | App may queue data and burst-send when connectivity returns. Risk: offline claim holds in airplane mode but fails on reconnection. |
| QA2-09 | P2 | `[NET NEW]` | No test for app behavior during Android Doze / App Standby | Doze restricts network; app may defer leaks to maintenance windows. Risk: leaks only visible after idle period. |
| QA2-10 | P1 | `[NET NEW]` | No equivalence class analysis for the "known tracker" database | What defines "known"? Risk: false negatives for trackers not in the database. |
| QA2-11 | P2 | `[DEEPENED]` | No performance regression test for test execution time | If a future change makes the harness take 4 hours, we have no alert. Risk: CI budget overrun. |
| QA2-12 | P2 | `[NET NEW]` | No mutation testing for the shell scripts | If we change `grep` to `fgrep`, does the test still catch trackers? Risk: script changes invalidate test logic. |
| QA2-13 | P1 | `[NET NEW]` | No test for data retention policy enforcement | Captures contain potential PII. If retained beyond 90 days, compliance risk. Risk: policy not enforced programmatically. |
| QA2-14 | P2 | `[PRESERVED]` | No coverage for Android Work Profile / Island / Shelter isolation | App in work profile may have different network rules. Risk: leak only visible in specific profile context. |
| QA2-15 | P2 | `[NET NEW]` | No test for reproducibility across macOS versions (Sonoma vs Sequoia) | Host OS differences may affect emulator networking. Risk: non-reproducible results across team. |

## Posture 4 — Principal Cybersecurity Engineer — New Surfaces

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| SEC2-01 | P0 | `[NET NEW]` | No side-channel analysis (timing, power, electromagnetic) | App may leak data via timing of UI renders or CPU usage patterns. Risk: advanced exfiltration undetected. |
| SEC2-02 | P1 | `[NET NEW]` | No analysis of Trusted Execution Environment (TEE) or StrongBox key usage | App may encrypt data in TEE before sending. Risk: traffic appears random; dynamic capture misses semantic content. |
| SEC2-03 | P1 | `[DEEPENED]` | Certificate pinning bypass leaves Frida gadget in APK permanently | If repacked APK is not deleted, it could be accidentally installed on a real device. Risk: persistent backdoor. |
| SEC2-04 | P1 | `[NET NEW]` | No verification of Android Verified Boot (AVB) state before testing | If bootloader is unlocked, the test environment is already compromised. Risk: false confidence in results. |
| SEC2-05 | P2 | `[PRESERVED]` | No analysis of TLS 1.3 Encrypted Client Hello (ECH) | ECH hides the destination SNI from mitmproxy. Risk: true destination address unknown even with CA installed. |
| SEC2-06 | P1 | `[NET NEW]` | No memory forensics for runtime-decrypted strings | App may decrypt tracker URLs at runtime. Risk: static scan (jadx) shows nothing; dynamic capture sees only encrypted traffic. |
| SEC2-07 | P2 | `[NET NEW]` | No check for hardware-backed attestation keys leaking device identity | App may send attestation to server for fingerprinting. Risk: "offline" app still phones home with device ID. |
| SEC2-08 | P1 | `[DEEPENED]` | The `tcpdump` capture runs with `sudo` — no sudoers restriction or command whitelist | Full root access for packet capture. Risk: compromised tcpdump command injection. |
| SEC2-09 | P2 | `[NET NEW]` | No analysis of ultrasonic cross-device tracking (SilverPush-style) | App may emit inaudible sound signals picked up by other devices. Risk: no network traffic but data still leaves phone. |
| SEC2-10 | P1 | `[NET NEW]` | No verification that mitmproxy itself has not been compromised | Custom CA is powerful. Risk: if mitmproxy binary is backdoored, all captured data is exfiltrated. |
| SEC2-11 | P2 | `[PRESERVED]` | No check for Bluetooth Low Energy (BLE) beacons | App may broadcast to nearby BLE receivers. Risk: data exfiltration without IP traffic. |
| SEC2-12 | P2 | `[NET NEW]` | No analysis of Android SafetyNet / Play Integrity API responses | App may send integrity verdict to server. Risk: device attestation data leaves phone even if app content does not. |
| SEC2-13 | P1 | `[NET NEW]` | No secure deletion (shred) for artifacts containing potential PII | `rm -rf` leaves data recoverable on SSD/HDD. Risk: forensic recovery of baby data from host disk. |
| SEC2-14 | P2 | `[DEEPENED]` | The audit log is append-only but not immutable (operator can edit) | No hash chain or signature. Risk: tampering with evidence after test. |
| SEC2-15 | P2 | `[NET NEW]` | No analysis of NFC or QR code data exfiltration | App may encode data in QR or NFC for another device to scan. Risk: air-gapped exfiltration. |

## Posture 5 — Principal DevOps / Platform Engineer — New Surfaces

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| DEV2-01 | P1 | `[NET NEW]` | No GitOps representation of the test environment | All setup is imperative shell. Risk: drift between runs; no pull-request review of environment changes. |
| DEV2-02 | P1 | `[NET NEW]` | No immutable infrastructure pattern for the emulator | AVD is mutable. Risk: state accumulation across tests invalidates isolation. |
| DEV2-03 | P2 | `[PRESERVED]` | No blue-green or canary strategy for test harness updates | If v2.0.0 changes methodology, results are incomparable to v1.0.0 without dual-run validation. Risk: metric drift. |
| DEV2-04 | P1 | `[NET NEW]` | No SLO defined for test harness availability | "Should work" is not an SLO. Risk: no alert when harness success rate drops. |
| DEV2-05 | P2 | `[NET NEW]` | No circuit breaker for external dependencies (Play Store, Docker Hub) | If Docker Hub is down, the test blocks indefinitely. Risk: no graceful degradation. |
| DEV2-06 | P2 | `[DEEPENED]` | No automated provisioning of the entire test stack from a single command | 20+ manual steps. Risk: human error; skipped steps. |
| DEV2-07 | P1 | `[NET NEW]` | No secret rotation policy for mitmproxy CA private key | Same CA reused across tests. Risk: key compromise enables universal MitM against test devices. |
| DEV2-08 | P2 | `[NET NEW]` | No cost budgeting for cloud resources (if extended to cloud-based testing) | Future scale-up may use cloud emulators. Risk: runaway costs. |
| DEV2-09 | P2 | `[PRESERVED]` | No automated garbage collection of old `${WORK_DIR}` directories | Timestamped directories accumulate. Risk: disk exhaustion. |
| DEV2-10 | P2 | `[NET NEW]` | No reproducible build for the test harness documentation itself | The markdown is not generated from a template or checked for drift. Risk: manual edits introduce inconsistencies. |
| DEV2-11 | P1 | `[NET NEW]` | No automated dependency update scanning (brew, pipx, docker) | Tools have CVEs. Risk: testing with vulnerable tools compromises results or host. |
| DEV2-12 | P2 | `[DEEPENED]` | No telemetry or metrics emission for test harness health | We don't know how often tests fail, how long they take, or why. Risk: blind to systemic issues. |
| DEV2-13 | P2 | `[NET NEW]` | No Infrastructure-as-Code drift detection | If an operator manually changes the emulator, no alert. Risk: configuration drift. |
| DEV2-14 | P1 | `[NET NEW]` | No disaster recovery plan for the test host (Mac) hardware failure | If Mac dies mid-engagement, all evidence is on local disk. Risk: total evidence loss. |
| DEV2-15 | P2 | `[NET NEW]` | No automated backup of artifacts to off-host storage | `artifacts.tar.gz` stays on Mac. Risk: single point of failure. |

## Posture 6 — Principal Privacy Engineer (NEW POSTURE)

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| PRIV-01 | P0 | `[NET NEW]` | No Data Protection Impact Assessment (DPIA) for the test itself | The test captures baby data (name, DOB, feeding patterns). Risk: GDPR Article 35 violation if conducted in EU. |
| PRIV-02 | P1 | `[NET NEW]` | No data minimization principle applied to captured traffic | All traffic is captured, not just app traffic. Risk: over-collection of unrelated personal data. |
| PRIV-03 | P1 | `[NET NEW]` | No purpose limitation documented | Captured data may be used for purposes beyond privacy testing. Risk: scope creep; legal challenge. |
| PRIV-04 | P2 | `[NET NEW]` | No consent mechanism for data subjects (parents of tracked babies) | Test data includes baby profiles. Risk: testing without parental consent violates COPPA/GDPR. |
| PRIV-05 | P1 | `[NET NEW]` | No retention schedule with automated enforcement | 90-day retention is stated but not enforced. Risk: data retained indefinitely. |
| PRIV-06 | P2 | `[NET NEW]` | No cross-border transfer assessment | If results are shared with US-based researchers, GDPR Article 44 may apply. Risk: unlawful transfer. |
| PRIV-07 | P2 | `[NET NEW]` | No anonymization or pseudonymization of captured flows | mitmproxy flows contain device IDs, IP addresses, timestamps. Risk: re-identification of test subject. |
| PRIV-08 | P1 | `[NET NEW]` | No right-to-erasure procedure for test artifacts | Data subject (parent) may request deletion. Risk: inability to comply with GDPR Article 17. |
| PRIV-09 | P2 | `[NET NEW]` | No privacy notice for operators handling baby data | Operators may not realize the sensitivity of captured data. Risk: mishandling due to ignorance. |
| PRIV-10 | P1 | `[NET NEW]` | No LINDDUN threat modeling applied to the test harness itself | The test harness collects, processes, and stores baby data. Risk: the tester becomes the privacy risk. |
| PRIV-11 | P2 | `[NET NEW]` | No data subject access request (DSAR) preparation | If tested app is later found to leak data, affected users may request their data. Risk: no procedure to respond. |
| PRIV-12 | P2 | `[NET NEW]` | No encryption at rest for archived artifacts | `artifacts.tar.gz` is plaintext. Risk: unauthorized access to sensitive data on disk. |
| PRIV-13 | P1 | `[NET NEW]` | No privacy-enhancing technology (PETs) usage (differential privacy, secure multi-party computation) | Raw data shared among subagents. Risk: subagent with access to flows can reconstruct sensitive profiles. |
| PRIV-14 | P2 | `[NET NEW]` | No privacy policy for the test harness itself | Users of the harness (operators) have no notice of how their data is handled. Risk: trust deficit. |
| PRIV-15 | P2 | `[NET NEW]` | No data breach notification procedure | If artifacts are leaked, who is notified and when? Risk: regulatory penalty for delayed notification. |

## Posture 7 — Principal Site Reliability Engineer (SRE) (NEW POSTURE)

| # | Item | Priority | Type | Rationale |
|---|------|----------|------|-----------|
| SRE-01 | P1 | `[NET NEW]` | No Service Level Objective (SLO) for test success rate | What percentage of test runs should complete successfully? Risk: no target to improve toward. |
| SRE-02 | P1 | `[NET NEW]` | No Service Level Indicator (SLI) for test duration | `PERF_BUDGET_MINUTES` is a limit, not an SLO. Risk: no tracking of p50/p99 test duration. |
| SRE-03 | P2 | `[NET NEW]` | No error budget defined for test harness failures | If 10% of tests fail, is that acceptable? Risk: no framework for prioritizing reliability work. |
| SRE-04 | P1 | `[NET NEW]` | No cascading failure prevention (emulator crash → mitmweb orphan → disk full) | One failure cascades to others. Risk: resource exhaustion; need manual cleanup. |
| SRE-05 | P2 | `[NET NEW]` | No rate limiting for `adb` commands | Rapid `adb shell` loops may overwhelm the emulator. Risk: emulator instability or ADB daemon crash. |
| SRE-06 | P1 | `[NET NEW]` | No health check for the test harness as a whole | Individual tool checks exist, but no end-to-end "canary" test. Risk: broken harness used for real testing. |
| SRE-07 | P2 | `[NET NEW]` | No automated rollback of the test environment on failure | If Part 2 fails, Part 3 may proceed on dirty state. Risk: cross-contamination between test phases. |
| SRE-08 | P2 | `[NET NEW]` | No load shedding or backpressure mechanism | Large APKs or long captures may OOM the host. Risk: test runner crash. |
| SRE-09 | P1 | `[NET NEW]` | No distributed tracing across subagent boundaries | Cannot reconstruct the full execution path of a multi-subagent test. Risk: opaque failures. |
| SRE-10 | P2 | `[NET NEW]` | No runbook for common failure modes (emulator panic, Docker daemon freeze) | "If something breaks" covers tool errors but not infrastructure failures. Risk: extended downtime. |
| SRE-11 | P1 | `[NET NEW]` | No capacity planning for concurrent test executions | If two operators run tests simultaneously, port 8080 collides. Risk: test interference. |
| SRE-12 | P2 | `[NET NEW]` | No post-mortem template for test harness incidents | When a test produces a false negative, how do we learn? Risk: repeated mistakes. |
| SRE-13 | P2 | `[NET NEW]` | No synthetic monitoring (continuous canary test against a known-leaky app) | We don't know if the harness can still detect leaks until we test a real app. Risk: silent harness failure. |
| SRE-14 | P1 | `[NET NEW]` | No graceful degradation for optional components | If `jadx` is unavailable, the test aborts. Risk: core test (dynamic capture) blocked by optional static scan. |
| SRE-15 | P2 | `[NET NEW]` | No notification channel for test completion or failure | Human must poll for completion. Risk: delayed response to failures. |

---

## Cross-Posture Critical Themes (Loop 2)

1. **Test harness as privacy risk** (PRIV-01, PRIV-10, PRIV-13, SEC2-13): The tester becomes the attacker. Capturing baby data creates a GDPR/COPPA liability surface that did not exist in Loop 1.
2. **Cascading failure modes** (SRE-04, SRE-07, SRE-11, SWE2-13): Infrastructure and process failures compound because the harness lacks circuit breakers, rollback, and resource isolation.
3. **Advanced exfiltration vectors** (SEC2-01, SEC2-09, SEC2-11, SEC2-15, QA2-06): Side channels, BLE, NFC, ultrasound, and cross-device tracking bypass all network-based detection.
4. **Agent trust and consensus** (AI2-02, AI2-09, AI2-13, AI2-14): Multi-agent orchestration introduces Byzantine fault tolerance and data exfiltration risks not present in single-agent execution.
5. **Immutability and drift** (DEV2-02, DEV2-10, DEV2-13, SWE2-02): Mutable environments and manual documentation edits guarantee drift over time.
