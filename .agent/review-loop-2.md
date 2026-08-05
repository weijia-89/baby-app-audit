# Sprint 3 Autonomous Code Review - Loop 2
## 5-Posture Review - Net New Checks (50%+ new from Loop 1)

---

## Posture 1: Principal Software Engineer (Loop 2 - New Checks)

1. **P2 - Python XML parsing vulnerable to XXE:** `detect-dark-patterns.sh:74` uses `xml.etree.ElementTree.parse()` which is vulnerable to XML External Entity (XXE) expansion by default. A malicious `AndroidManifest.xml` could trigger entity expansion attacks. *File: `scripts/detect-dark-patterns.sh:74`*

2. **P2 - `trap` only catches EXIT, not SIGINT/SIGTERM:** `detect-dark-patterns.sh:86` sets `trap 'rm -rf "$TEMP_DIR"' EXIT` but does not trap SIGINT or SIGTERM. If a user Ctrl+C's during a long scan, the temp directory persists. *File: `scripts/detect-dark-patterns.sh:86`*

3. **P2 - `scan_pressure_tactics` doesn't scan localized strings:** Unlike `scan_deceptive_button_order` which was updated to scan all `res/values-*/strings.xml`, `scan_pressure_tactics` only checks `res/values/strings.xml`. This is an inconsistency that could miss localized pressure language. *File: `scripts/detect-dark-patterns.sh:310-320`*

4. **P2 - Color normalization for 6-digit hex is wrong:** `detect-dark-patterns.sh:287` does `norm_color="${color:1}"` for 7-char `#RRGGBB`, which produces `#RRGGBB` (8 chars), not `RRGGBB` (6 chars). Then line 294-296 tries to read `${norm_color:0:2}` which reads `#R` instead of `RR`. This is a bug. *File: `scripts/detect-dark-patterns.sh:287,294-296`*

5. **P2 - `mktemp` portability on Linux vs macOS:** `compare-apps.sh:111` uses bare `mktemp`. On Linux this creates `/tmp/tmp.XXXXXX`. On macOS the behavior is identical. But the test files use `mktemp -d "$REPO_DIR/tests/fixtures/...XXXXXX"` which is fine. However, `mktemp` without a template may fail in some restricted environments (e.g., read-only /tmp). *File: `scripts/compare-apps.sh:111`*

6. **P2 - Array iteration with spaces in filenames:** `scan_deceptive_button_order` iterates `${strings_files[@]}` which could break if filenames contain spaces. The `for strings_file in "${strings_files[@]}"` syntax is correct, but the `find -print0` + `while read -d ''` should handle it. Let me verify... Yes, it uses proper null-terminated handling. *File: `scripts/detect-dark-patterns.sh:209-241`*

7. **P2 - `unzip -t` doesn't validate path traversal:** `detect-dark-patterns.sh:89` runs `unzip -t` which tests integrity but does not check for path traversal entries (e.g., `../../etc/passwd`). A malicious APK could extract files outside the temp directory. *File: `scripts/detect-dark-patterns.sh:89`*

8. **P2 - Python temp script is not made executable:** `compare-apps.sh:114` writes to a temp file via heredoc but never `chmod +x` it. The script runs `python3 "$TEMP_SCRIPT"` so it doesn't need to be executable, but this is a code smell. *File: `scripts/compare-apps.sh:114`*

9. **P2 - Output written before validation:** `detect-dark-patterns.sh:355-358` writes output to file BEFORE validating it's valid JSON. If `jq` fails to build the output, a partial file is written. *File: `scripts/detect-dark-patterns.sh:354-358`*

10. **P2 - `date -u` portability:** `detect-dark-patterns.sh:122` and `compare-apps.sh:108` use `date -u +%Y-%m-%dT%H:%M:%SZ`. This works on macOS and Linux but not on minimal BusyBox systems. Given the project runs on macOS/Linux CI, this is acceptable but worth noting. *File: `scripts/detect-dark-patterns.sh:122`*

11. **P3 - No timeout on long-running scans:** An APK with thousands of XML files could cause the scan to run for minutes. No timeout mechanism exists. *File: `scripts/detect-dark-patterns.sh`*

12. **P3 - `add_pattern` spawns subshell for each pattern:** Each `add_pattern` call runs `echo "$PATTERNS" | jq ...`. For large APKs with many patterns, this is O(n²) in subshells. *File: `scripts/detect-dark-patterns.sh:126-136`*

13. **P3 - No progress indicator for long scans:** A user running the script on a large APK sees no progress. The `log "Scanning..."` message is the only output until completion. *File: `scripts/detect-dark-patterns.sh:323`*

14. **P3 - `OUTPUT_FILE` validation doesn't check for overwriting:** If the output file already exists, it will be silently overwritten. No `--force` flag or confirmation. *File: `scripts/detect-dark-patterns.sh:354-358`*

15. **P3 - Schema doesn't include `tool_versions` field:** `decode-traffic.schema.json` includes `tool_versions` but `dark-patterns.schema.json` does not. For consistency and reproducibility, the scanner should record tool versions. *File: `results/dark-patterns.schema.json`*

---

## Posture 2: Principal AI Engineer (Loop 2 - New Checks)

16. **P2 - No Unicode normalization for string matching:** The regex patterns in `scan_deceptive_button_order` use ASCII text. Apps with Unicode homoglyphs (e.g., "Ассерт All" using Cyrillic А) would evade detection. *File: `scripts/detect-dark-patterns.sh:225-238`*

17. **P2 - Color parsing doesn't handle alpha channel correctly:** For 8-digit `#AARRGGBB`, line 290 does `norm_color="${color:3}"` which gives `#RRGGBB` (8 chars including #), but then the hex parsing reads `${norm_color:0:2}` = `#R`. Same bug as item 4. *File: `scripts/detect-dark-patterns.sh:290,294-296`*

18. **P2 - No false positive test for benign APKs:** Tests only verify detection of dark patterns, never verify that clean APKs produce zero false positives. This is a critical gap for an AI/ML system. *File: `tests/test-dark-patterns.sh`*

19. **P2 - Heuristic thresholds not calibrated against real data:** The 8sp threshold, 5dp width, and RGB>200 contrast values are arbitrary. Without calibration against a labeled dataset, we have no idea of precision/recall. *File: `scripts/detect-dark-patterns.sh`*

20. **P2 - Pattern confidence not calibrated:** "high", "medium", "low" labels are arbitrary. A "high" confidence pre-checked consent finding might be a false positive if the checkbox is for a functional setting (e.g., "Enable notifications"). *File: `scripts/detect-dark-patterns.sh`*

21. **P3 - No handling of Android resource references:** `@string/btn_accept` in layout XML won't be detected because the actual text is in strings.xml, not the layout. The scanner doesn't resolve resource references. *File: `scripts/detect-dark-patterns.sh`*

22. **P3 - No handling of styled text:** `<b>`, `<i>`, `<u>` tags in strings.xml could affect text rendering but aren't considered by the regex. *File: `scripts/detect-dark-patterns.sh`*

23. **P3 - No CDATA handling:** strings.xml with `<![CDATA[Accept All]]>` would not be matched by the regex. *File: `scripts/detect-dark-patterns.sh`*

24. **P3 - No HTML entity decoding:** `&amp;`, `&lt;` etc. in strings.xml would not be decoded, potentially causing missed detections. *File: `scripts/detect-dark-patterns.sh`*

25. **P3 - Missing detection of consent fatigue patterns:** Repeated consent requests (e.g., "Are you sure?" dialogs) are a known dark pattern class not detected. *File: `scripts/detect-dark-patterns.sh`*

---

## Posture 3: Principal QA Engineer / SDET (Loop 2 - New Checks)

26. **P1 - Color normalization bug causes test to pass incorrectly:** Test 10 in `test-dark-patterns.sh` tests 3-digit hex color detection, but due to the normalization bug (item 4/17), the test might be passing for the wrong reason or the color parsing is broken. *File: `tests/test-dark-patterns.sh` (Test 10), `scripts/detect-dark-patterns.sh:287`*

27. **P2 - Test 8 (APK file input) doesn't verify cleanup:** The test creates a temp directory via unzip but never verifies the temp directory is cleaned up after the script exits. *File: `tests/test-dark-patterns.sh`*

28. **P2 - Test 12 (shell metacharacters) uses a dangerous string:** The test passes `/tmp/test; rm -rf /` to verify rejection. While the script rejects it, this is a risky test string. A safer alternative would be `/tmp/test;echo`. *File: `tests/test-dark-patterns.sh`*

29. **P2 - No test for malformed zip file:** Test 8 creates a valid zip. No test verifies behavior when the zip is corrupted or truncated. *File: `tests/test-dark-patterns.sh`*

30. **P2 - No test for empty APK (no res directory):** An APK with no resources directory should produce zero patterns, but this edge case isn't tested. *File: `tests/test-dark-patterns.sh`*

31. **P2 - No test for very large number of patterns:** No performance/stress test with thousands of XML files. *File: `tests/test-dark-patterns.sh`*

32. **P2 - Test 11 (--version) doesn't test --help:** No test verifies the usage/help output is correct. *File: `tests/test-dark-patterns.sh`*

33. **P2 - compare-apps Test 9 (invalid JSON structure) creates output file on failure:** When `compare-apps.sh` fails due to invalid JSON, it may have already created the output file. The test should verify no partial output was written. *File: `tests/test-compare-apps.sh`*

34. **P2 - No test for duplicate package names in compare-apps:** If two input files have the same `package_name`, the comparison may produce unexpected results. *File: `tests/test-compare-apps.sh`*

35. **P3 - No test for very large JSON files:** compare-apps.sh loads all files into memory. No test with large JSON files to verify memory handling. *File: `tests/test-compare-apps.sh`*

36. **P3 - Test cleanup may not catch all fixtures:** If a test creates additional files not listed in cleanup(), they persist. The cleanup function is manually maintained. *File: `tests/test-dark-patterns.sh`, `tests/test-compare-apps.sh`*

37. **P3 - No test for concurrent execution:** No test verifies that running multiple instances of the script simultaneously doesn't interfere. *File: `tests/`*

---

## Posture 4: Principal Cybersecurity Engineer (Loop 2 - New Checks)

38. **P1 - Python XXE vulnerability in XML parsing:** `xml.etree.ElementTree.parse()` resolves external entities by default. A malicious `AndroidManifest.xml` with `<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>` could leak file contents. *File: `scripts/detect-dark-patterns.sh:74`*

39. **P2 - `jq --arg` doesn't sanitize evidence_file:** If `evidence_file` contains special characters (newlines, quotes), `jq --arg` will handle it correctly (jq escapes properly). But the output JSON may contain paths with special characters that break downstream parsers. *File: `scripts/detect-dark-patterns.sh:131-135`*

40. **P2 - `unzip -q` may follow symlinks in zip:** Some zip implementations allow symlink entries. Extracting a zip with symlinks could write files outside the temp directory. *File: `scripts/detect-dark-patterns.sh:93`*

41. **P2 - No validation of extracted file types:** After unzip, the extracted files could be anything (executables, scripts). The script treats them as XML without checking file type. *File: `scripts/detect-dark-patterns.sh:93`*

42. **P2 - TOCTOU race condition in compare-apps temp script:** Between `mktemp` (line 111) and `cat > "$TEMP_SCRIPT"` (line 114), an attacker could replace the temp file. This is a classic Time-of-Check-to-Time-of-Use vulnerability. *File: `scripts/compare-apps.sh:111-114`*

43. **P2 - No file permission check on input APK:** A world-readable APK containing sensitive data could be scanned, and the results (also potentially sensitive) are written with default permissions. *File: `scripts/detect-dark-patterns.sh`*

44. **P2 - `mktemp` file permissions:** `mktemp` creates files with 0600 permissions by default, but `mktemp -d` creates directories with 0700. The Python temp script is written to a file created by `mktemp` (0600), which is acceptable. *File: `scripts/compare-apps.sh:111`*

45. **P3 - No audit trail for scan decisions:** When a pattern is detected, there's no way to trace back exactly which regex matched which line in which file. *File: `scripts/detect-dark-patterns.sh`*

46. **P3 - No integrity check on results:** The output JSON has no checksum or signature. An attacker could modify results after scanning. *File: `results/dark-patterns.schema.json`*

47. **P3 - Missing CWE-916 (Hashing without salt):** Not applicable here but noting that the project doesn't track CWE coverage for the tool itself. *File: project-wide*

---

## Posture 5: Principal DevOps / Platform Engineer (Loop 2 - New Checks)

48. **P2 - CI workflow step ordering issue:** In the updated `test.yml`, the "Validate new schemas" step runs AFTER "Schema validation gate". If schema validation fails, the new schemas step won't run, hiding potential schema errors. The schema validation steps should be grouped together. *File: `.github/workflows/test.yml`*

49. **P2 - CI doesn't test on macOS:** The new scripts use `stat -f%z` (macOS) and `stat -c%s` (Linux) with fallback. But CI only tests on Linux (ubuntu-latest). The macOS code path is never exercised. *File: `.github/workflows/test.yml`*

50. **P2 - `sudo apt-get install` may fail in restricted CI environments:** Some CI runners don't allow `sudo`. The `sudo apt-get update` step may fail on GitHub Actions if the runner is restricted. *File: `.github/workflows/test.yml`*

51. **P2 - No jq version pinning:** CI installs `jq` via `apt-get install -y -qq jq` without version pinning. Different jq versions may have incompatible features. *File: `.github/workflows/test.yml`*

52. **P2 - CI doesn't verify script executable permissions:** The new scripts may lose executable permissions when checked out on a fresh runner. CI doesn't `chmod +x` them before running. *File: `.github/workflows/test.yml`*

53. **P2 - No test for `detect-dark-patterns.sh` in canary:** The canary test (macos-latest) doesn't exercise the new scripts. If the `grep -P` fix breaks on macOS, it won't be caught. *File: `.github/workflows/test.yml`*

54. **P3 - No timeout on individual test steps:** The unit-tests job has `timeout-minutes: 10` for the whole job, but individual test scripts could hang indefinitely. *File: `.github/workflows/test.yml`*

55. **P3 - No artifact collection on test failure:** When tests fail, no artifacts (logs, fixtures) are uploaded for debugging. *File: `.github/workflows/test.yml`*

56. **P3 - No test coverage reporting:** No mechanism to measure what percentage of code is covered by tests. *File: `.github/workflows/test.yml`*

57. **P3 - Missing dependency check in CI:** CI doesn't verify that `python3`, `jq`, `zip`, `unzip` are available before running tests. *File: `.github/workflows/test.yml`*

---

## Severity Summary (Loop 2)

| Severity | Count | Key Issues |
|----------|-------|------------|
| P0 | 0 | - |
| P1 | 2 | XXE vulnerability (38), Color normalization bug (26) |
| P2 | 25 | Temp cleanup (2), Inconsistent localized scan (3), Color bug (4), Path traversal (7), etc. |
| P3 | 30 | Performance (11,12), No progress (13), Unicode (16), etc. |

---

## Critical Fixes Needed (Loop 2 P1)

1. **XXE vulnerability:** Replace `xml.etree.ElementTree.parse()` with a safe parser that disables external entities
2. **Color normalization bug:** Fix the 6-digit and 8-digit hex normalization (lines 287, 290)

## High Priority Fixes (Loop 2 P2 - selected)

3. **scan_pressure_tactics should scan localized strings:** Update to match scan_deceptive_button_order pattern
4. **Temp cleanup should trap SIGINT/SIGTERM:** Add signal traps
5. **CI should test on macOS:** Add a macOS test job for the new scripts
6. **sudo in CI:** Use `apt-get` without sudo or use a setup action
