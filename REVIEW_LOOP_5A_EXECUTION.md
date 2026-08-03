# Loop 5A Review — Test Execution Code (5 Postures)

**Reviewer:** Multi-posture synthetic senior staff (SWE / AI / QA / Security / DevOps)  
**Scope:** `scripts/run-tests.sh` and test execution results  
**Date:** 2026-08-03  
**Total findings:** 85 (17 per posture)  
**Highest priority:** P0  

---

## Posture 1 — Principal Software Engineer (SWE)

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| SWE-E1 | Hardcoded `https://github.com/babybuddy/babybuddy.git` URL | P1 | No verification of URL integrity. Risk: repo moved, renamed, or compromised. |
| SWE-E2 | `local` variable declarations inside loops are not POSIX-compliant | P2 | Using `local` in `while` loops is bash-specific. Risk: script fails on strict POSIX shells. |
| SWE-E3 | No cleanup of cloned repository after audit | P1 | Baby Buddy source stays in `$WORK_DIR`. Risk: disk exhaustion across multiple runs. |
| SWE-E4 | `wc -l` counts include empty lines and comments | P2 | Network reference count (2530) is inflated by minified JS. Risk: misleading metrics. |
| SWE-E5 | `kill -0` to check mitmweb PID is race-prone | P2 | PID may be reused between check and kill. Risk: false positive or false negative. |
| SWE-E6 | No trap handler for cleanup in test execution script | P1 | Ctrl-C leaves mitmweb running. Risk: orphaned processes, port conflicts. |
| SWE-E7 | `jq` is required but not checked in preflight | P1 | Script fails silently if `jq` is missing. Risk: incomplete results. |
| SWE-E8 | Working directory uses `date` with local timezone | P2 | `date +%Y%m%d` uses local time. Risk: collision across timezones. |
| SWE-E9 | No file locking for concurrent executions | P2 | Two simultaneous runs write to same `$WORK_DIR`. Risk: data corruption. |
| SWE-E10 | `grep -rEi` on large repos is O(n) and slow | P2 | Baby Buddy audit took noticeable time. Risk: performance budget exceeded. |
| SWE-E11 | No validation that pulled APK is actually an APK | P2 | `adb pull` could retrieve a non-APK file. Risk: false static scan. |
| SWE-E12 | `sleep` durations are magic numbers without justification | P3 | `sleep 3`, `sleep 5`, `sleep 10` are arbitrary. Risk: race conditions. |
| SWE-E13 | No version check for script compatibility | P2 | Script assumes harness v3.0.0 but doesn't verify. Risk: version mismatch. |
| SWE-E14 | `mkdir -p` creates directories but doesn't verify permissions | P3 | If `$WORK_DIR` is read-only, script fails late. Risk: confusing errors. |
| SWE-E15 | No rollback mechanism for partial test failures | P2 | If test 2 of 4 fails, previous results are left in inconsistent state. Risk: false summary. |
| SWE-E16 | `adb shell monkey` is deprecated for app launching | P2 | `monkey` is for stress testing, not reliable launching. Risk: app doesn't start. |
| SWE-E17 | `curl` to mitmweb uses HTTP not HTTPS | P1 | Localhost HTTP is acceptable but should be noted. Risk: man-in-the-middle on shared hosts. |

## Posture 2 — Principal AI Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| AI-E1 | No hallucination guard for grep pattern interpretation | P1 | "2530 network references" includes minified JS comments. Risk: AI misinterprets as actual network calls. |
| AI-E2 | Results JSON lacks confidence scores for each test phase | P2 | No way to express "static scan incomplete due to missing tools." Risk: binary pass/fall misleading. |
| AI-E3 | No structured logging for subagent consumption | P2 | Output is free-form text. Risk: downstream AI parsers fail. |
| AI-E4 | `test_app` function signature doesn't include test configuration | P2 | Cannot parameterize timeout, retry count, or proxy port per app. Risk: rigid execution. |
| AI-E5 | No state machine for test progression | P1 | Script jumps between functions without tracking phase. Risk: skipped steps undetected. |
| AI-E6 | Error handling conflates "tool missing" with "app missing" | P2 | Both show as warnings. Risk: different root causes treated identically. |
| AI-E7 | No formal specification of expected vs. actual results | P2 | Cannot automatically detect deviations. Risk: manual review required. |
| AI-E8 | `BEST_EFFORT` mode is not formally defined | P2 | What runs and what skips is implicit. Risk: inconsistent execution. |
| AI-E9 | No input validation for app names or package names | P1 | Metacharacters in package names could inject shell commands. Risk: command injection. |
| AI-E10 | Results directory structure is not self-describing | P2 | `Baby Buddy.json` has space in filename. Risk: shell parsing issues. |
| AI-E11 | No checksum for the script itself | P2 | Tampered script produces invalid results. Risk: supply chain attack on test harness. |
| AI-E12 | `main()` function doesn't return structured exit codes | P2 | Always exits 0 even on partial failure. Risk: CI cannot detect problems. |
| AI-E13 | No specification for parallel vs. serial execution | P2 | Apps tested sequentially. Risk: slow execution, no optimization. |
| AI-E14 | No context window budget for log output | P3 | Long grep outputs overflow terminals. Risk: unreadable logs. |
| AI-E15 | Agent rules from harness document are not enforced in code | P1 | Rule 12 (prompt injection scan) not implemented. Risk: security vulnerability. |
| AI-E16 | No provenance tracking for test environment changes | P2 | If tools are upgraded mid-test, results are incomparable. Risk: metric drift. |
| AI-E17 | `jq` manipulation is fragile (tmp file + mv pattern) | P2 | If mv fails, results are corrupted. Risk: data loss. |

## Posture 3 — Principal QA Engineer / SDET

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| QA-E1 | No unit tests for the test script itself | P1 | Meta-testing gap. Risk: script bugs produce false results. |
| QA-E2 | No test for preflight failure handling | P1 | Best-effort mode not verified. Risk: unknown behavior when tools missing. |
| QA-E3 | No test for concurrent execution | P2 | Two runs may collide. Risk: untested race condition. |
| QA-E4 | No regression test for Baby Buddy source audit | P2 | If repo changes, expected hit counts change. Risk: false positives. |
| QA-E5 | No oracle for "expected network references" | P2 | 2530 hits may be correct or may indicate over-matching. Risk: unknown baseline. |
| QA-E6 | No test for mitmproxy startup failure | P2 | If port 8080 is in use, test continues blindly. Risk: false negative. |
| QA-E7 | No validation of JSON schema compliance | P2 | Results may not match `results/schema.json`. Risk: downstream parser failure. |
| QA-E8 | No test for APK hash computation | P2 | If hashing fails, results lack integrity. Risk: unverifiable claims. |
| QA-E9 | No coverage for `adb` failure modes | P2 | Device offline, unauthorized, or not found. Risk: unhandled errors. |
| QA-E10 | No performance benchmark for test duration | P3 | No acceptance criteria for how long tests should take. Risk: timeout surprises. |
| QA-E11 | No test for disk full condition | P2 | If disk fills during clone, behavior undefined. Risk: silent corruption. |
| QA-E12 | No test for network timeout during clone | P2 | GitHub unreachable produces `CLONE_FAILED` but not verified. Risk: false assumption. |
| QA-E13 | No golden master for expected output format | P2 | Cannot detect format drift across runs. Risk: parser breakage. |
| QA-E14 | No test for cleanup completeness | P2 | If `rm -rf` fails, artifacts persist. Risk: privacy violation. |
| QA-E15 | No test for signal handling (SIGINT mid-test) | P1 | Orphaned processes not verified. Risk: resource leaks. |
| QA-E16 | No equivalence partitioning for app types | P2 | Only "native" and "foss" tested. "web" and "hybrid" paths unverified. Risk: untested branches. |
| QA-E17 | No mutation testing for grep patterns | P2 | If pattern is wrong, results are wrong. Risk: silent false negatives. |

## Posture 4 — Principal Cybersecurity Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| SEC-E1 | `git clone` over HTTPS without certificate pinning | P1 | Risk: MITM on GitHub delivers malicious source. |
| SEC-E2 | Script downloads and executes code from internet | P1 | `git clone` + `grep` on untrusted repo. Risk: malicious source triggers parser vulnerabilities. |
| SEC-E3 | `eval` in grep pattern is a literal string search, but pattern contains regex metacharacters | P2 | Pattern `eval\(` searches for literal `eval(`. Risk: missed if code uses `eval` without parens. |
| SEC-E4 | No sandboxing for cloned repository | P1 | Full repo access with same privileges as test. Risk: post-clone hooks, malicious `.git/config`. |
| SEC-E5 | `wc -l < file` is vulnerable to filename injection | P2 | If filename contains shell metacharacters. Risk: command injection. |
| SEC-E6 | Results written to predictable path (`~/apk-privacy-test-*`) | P2 | Other users/processes can predict and access. Risk: information disclosure. |
| SEC-E7 | No audit of who ran the test and when | P2 | Results lack operator identity. Risk: repudiation. |
| SEC-E8 | `adb` connection over USB is unencrypted | P1 | If physical device used. Risk: traffic interception. |
| SEC-E9 | Script has `set -euo pipefail` but error paths call `true` | P2 | `|| true` suppresses failures. Risk: silent security issues. |
| SEC-E10 | No verification of mitmproxy binary integrity | P2 | `mitmweb` is trusted implicitly. Risk: compromised binary. |
| SEC-E11 | Results JSON not signed or encrypted | P2 | Tampering undetected. Risk: false evidence. |
| SEC-E12 | `git clone` depth not limited | P2 | Full history cloned including potentially malicious commits. Risk: exposure to old vulnerabilities. |
| SEC-E13 | No check for repository fork vs. original | P2 | Could clone a malicious fork. Risk: testing wrong code. |
| SEC-E14 | Network hits file contains full file paths | P2 | Absolute paths leak directory structure. Risk: information disclosure. |
| SEC-E15 | `chmod +x` on script not verified before execution | P3 | If script is not executable, error is confusing. Risk: social engineering vector. |
| SEC-E16 | No memory protection for sensitive results | P2 | Results in memory during execution. Risk: swap/pagefile exposure. |
| SEC-E17 | `curl` to localhost:8081 trusts any service on that port | P1 | If another process binds 8081 first. Risk: capturing wrong data. |

## Posture 5 — Principal DevOps / Platform Engineer

| # | Item | Priority | Rationale |
|---|------|----------|-----------|
| DEV-E1 | No containerization for test environment | P1 | Tools installed directly on host. Risk: host pollution, version conflicts. |
| DEV-E2 | No infrastructure-as-code for tool installation | P2 | Manual `brew install` steps. Risk: environment drift. |
| DEV-E3 | No resource limits (CPU, memory, disk I/O) | P2 | Large repos can exhaust resources. Risk: host instability. |
| DEV-E4 | No log aggregation or centralized logging | P2 | Logs scattered in `$WORK_DIR`. Risk: incident investigation pain. |
| DEV-E5 | No monitoring of test execution health | P2 | If test hangs, no alert. Risk: indefinite blocking. |
| DEV-E6 | No artifact retention policy enforcement | P2 | 90-day policy stated but not enforced. Risk: disk exhaustion. |
| DEV-E7 | No environment parity between CI and local | P2 | CI uses ubuntu-latest, local uses macOS. Risk: different behavior. |
| DEV-E8 | No dependency pinning for script runtime | P2 | bash version, coreutils version vary. Risk: compatibility issues. |
| DEV-E9 | No rollback for failed test runs | P2 | Partial results remain. Risk: false conclusions from incomplete data. |
| DEV-E10 | No blue-green deployment for test environment | P3 | Single emulator instance. Risk: cross-test contamination. |
| DEV-E11 | No cost tracking for external resources | P3 | GitHub API calls, Docker pulls not metered. Risk: unexpected bills. |
| DEV-E12 | No auto-scaling for parallel test execution | P3 | Sequential execution only. Risk: slow feedback. |
| DEV-E13 | No secret management for GitHub tokens | P2 | If GitHub API rate limit hit, no token configured. Risk: test blocked. |
| DEV-E14 | No network isolation for test environment | P1 | Test shares host network. Risk: interference, data leakage. |
| DEV-E15 | No automated garbage collection of old workspaces | P2 | `~/apk-privacy-test-*` accumulate. Risk: disk exhaustion. |
| DEV-E16 | No health check for external dependencies before test | P2 | GitHub.com may be down. Risk: unnecessary failures. |
| DEV-E17 | No SLO for test execution time | P2 | 120-minute budget not monitored. Risk: missed deadlines. |
