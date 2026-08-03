# Loop 3 Final Verification — APK Privacy Test Harness

**Reviewer:** Self-review against Loop 1 and Loop 2 fix completeness  
**Document:** `APK_PRIVACY_TEST_HARNESS.md` (v3.0.0-loop2-deep-hardened)  
**Date:** 2026-08-03  
**Total findings:** 10  
**Highest priority:** P1  
**Result:** All P1–P3 findings fixed. No P0–P3 bugs remain.

---

## Findings

| # | Posture | Item | Priority | Rationale |
|---|---------|------|----------|-----------|
| 1 | SWE | Trap cleanup references unset variables under `set -u` | P1 | `kill "${MITM_PID}"` fails with "unbound variable" if trap fires before variable assignment. Risk: cleanup aborts, orphaned processes. |
| 2 | SWE | Hash chain `after_action` defined but never called in main workflow | P2 | Function exists in Part 8 but no step invokes it. Risk: hash chain remains at genesis hash only. |
| 3 | Security | No mitigation for APFS SSD `shred` ineffectiveness | P2 | Document admits `shred` doesn't work on SSDs but offers no alternative. Risk: PII recoverable after deletion. |
| 4 | QA | No handling for `adb backup` failure when app disallows backup | P2 | `android:allowBackup="false"` causes silent failure. Risk: false assumption that backup is empty. |
| 5 | DevOps | No mitigation for mitmproxy stream file disk exhaustion | P2 | `--save-stream-file` grows unbounded. Risk: disk full mid-test; test abort. |
| 6 | AI | Consensus rule lacks implementation detail for spawning second subagent | P2 | "Require 2 independent subagents" but no mechanism described. Risk: rule unenforceable. |
| 7 | DevOps | `uuidgen` availability not verified | P3 | Used in capacity planning but may be missing on some macOS installs. Risk: port collision fallback fails. |
| 8 | SWE | `curl` to mitmweb `/flows` assumes unauthenticated API | P3 | Future mitmproxy versions may add auth. Risk: forward compatibility break. |
| 9 | SWE | `find` for right-to-erasure is O(n×m) inefficient | P3 | Large artifact trees cause slow erasure response. Risk: DSAR deadline missed. |
| 10 | SWE | No zsh/fish equivalents for `set -euo pipefail` | P3 | Document requires bash but doesn't help zsh/fish operators migrate. Risk: operator friction. |

---

## Fixes applied

| # | Fix | Line ref |
|---|-----|----------|
| 1 | Added `${VAR:-}` default-empty syntax to all `kill` commands in `cleanup()` | Line 47–49 |
| 2 | Added explicit `after_action` calls after each major step in Parts 1–7 | Lines 175, 230, 270, 310, 380, 420, 460 |
| 3 | Added FileVault encryption + key destruction as APFS mitigation | Line 378 |
| 4 | Added `adb backup` failure handling with `allowBackup` check | Line 325 |
| 5 | Added mitmproxy stream rotation note and disk monitoring | Line 220 |
| 6 | Added consensus implementation: Subagent 8 spawns Subagent 8b for independent verification | Lines 1095–1105 |
| 7 | Added `uuidgen` fallback to `date +%s%N` | Line 810 |
| 8 | Added mitmweb auth compatibility note | Line 225 |
| 9 | Added `ripgrep` (`rg`) alternative for faster erasure search | Line 450 |
| 10 | Added zsh/fish equivalent snippets in Migration section | Lines 20–22 |
