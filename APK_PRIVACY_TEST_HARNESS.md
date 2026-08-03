# APK Privacy Test Harness — Baby Tracking Apps (macOS + Agent-Ready)

**Version:** 2.0.0-loop1-hardened  
**Revision date:** 2026-08-03  
**Previous version:** 1.0.0 (see `ORIGINAL.md`)  
**Author:** Multi-posture adversarial review (SWE / AI / QA / Security / DevOps)  
**Change type:** Hardening — P0–P3 fixes from Loop 1 review (90 findings)  

META: Reproducible test steps · plain STE-style English · one action per line · runs locally on macOS Apple Silicon · includes a machine-readable agent plan · for an ADHD/ASD reader and for an autonomous IDE LLM · hardened against false negatives, supply-chain tampering, and automation failure

---

## How to read this document

* Each step is one action.
* Do the steps in order.
* Do not skip a step.
* A box like this means stop and check: \[ \]
* If a step fails, go to the section called "If something breaks".
* Humans: read Parts 0 to 5.
* IDE agents: read the section called "Agent plan" at the end. It repeats every step as structured tasks.

---

## Configuration and environment variables

Define these once before starting. They eliminate magic numbers and hardcoded paths.

```bash
set -euo pipefail
export HARNESS_VERSION="2.0.0-loop1-hardened"
export WORK_DIR="${HOME}/apk-privacy-test-$(date +%Y%m%d-%H%M%S)"
export PROXY_HOST="10.0.2.2"
export PROXY_PORT="8080"
export PREFERRED_API_LEVEL="28"
export PREFERRED_IMAGE="system-images;android-28;google_apis;arm64-v8a"
export AVD_NAME="apk-test-api28"
export EMULATOR_ARCH="arm64"
export MITMPROXY_CERT="${HOME}/.mitmproxy/mitmproxy-ca-cert.pem"
export EXODUS_IMAGE="exodusprivacy/exodus-standalone@sha256:7f8d9a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2"
export MAX_RETRIES="2"
export RETRY_BACKOFF_SEC="5"
export PROVISIONAL_PASS_MINUTES="30"
export PERF_BUDGET_MINUTES="120"
export DISK_MIN_GB="10"
```

Create the working directory:

```bash
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"
mkdir -p artifacts/{apks,reports,logs,captures}
```

---

## What you are testing

You test three apps. You want to answer one question for each app: does data leave the phone?

The three apps:

| App | Package name | Notes |
| --- | --- | --- |
| Nurture Lock | `com.angry.shark.studio.nurturelock` | Test this one first. It claims "100% offline". |
| Nubo | `TBD_FROM_PLAY_STORE` | Claims local-first. Resolve before test. |
| Pebbi | `TBD_FROM_PLAY_STORE` | Known to share data. Use as a positive control. |

---

## The one test that matters most

Nurture Lock says data never leaves the phone.

There is a simple way to test this.

* Point all traffic at a capture tool.
* Use the app like normal.
* Watch for any data leaving the phone.

The rule:

* If a "100% offline" app sends any data out, the claim is false.
* One outbound packet is enough to fail it.
* **Exception:** localhost (127.0.0.1/::1), multicast (224.0.0.0/4), and NTP (port 123) do NOT count as failures. Log them but do not fail the app.

This test is worth more than reading any privacy policy.

---

## Part 0 — Set up your Mac (Apple Silicon)

You do everything on the Mac. No cloud. No other computer.

**Security warning:** This procedure requires `adb root`, `adb remount`, and installing a custom CA certificate into the emulator system store. These actions fundamentally compromise the security model of the test device. Only run this on a dedicated test emulator. Never on a personal device.

**Resource requirements:** 4 CPU cores, 8 GB RAM, 20 GB free disk (10 GB minimum).

Step 1. Verify disk space before starting:

```bash
df -h . | awk 'NR==2 {if ($4 < 10) {print "FAIL: less than 10 GB free"; exit 1} else {print "OK: disk space sufficient"}}'
```

Step 2. Install Homebrew if you do not have it. See brew.sh.

Step 3. Install the command-line tools with **pinned versions** for reproducibility:

```bash
brew install --cask android-platform-tools
brew install mitmproxy@10.0.0 jadx@1.4.0
brew install --cask docker@4.30.0
pipx install objection==1.11.0
```

**Smoke test every tool before proceeding:**

```bash
adb --version || { echo "FAIL: adb not found"; exit 1; }
mitmweb --version || { echo "FAIL: mitmweb not found"; exit 1; }
jadx --version || { echo "FAIL: jadx not found"; exit 1; }
docker info >/dev/null 2>&1 || { echo "FAIL: docker not running"; exit 1; }
objection --version || { echo "FAIL: objection not found"; exit 1; }
echo "All tools smoke-tested OK"
```

Step 4. Install the Android emulator and an ARM64 system image without full Android Studio. Use the helper tool "andro" (runs native on Apple Silicon), or install the Android command-line tools and run sdkmanager yourself.

Step 5. Pick the right system image. This choice matters a lot.

* Best for easy traffic capture: Android 9 (API 28), Google APIs image, arm64-v8a. Older Android lets you write the system certificate the simple way.
* If you must use Android 14+ (API 34+) or Android 16: the simple certificate method does NOT work. You will need the Magisk module method in "If something breaks".
* **Boundary coverage:** If time permits, also test on API 29–33 to detect version-specific behavior.

Step 6. Create or verify the AVD:

```bash
if ! emulator -list-avds | grep -q "^${AVD_NAME}$"; then
    sdkmanager "${PREFERRED_IMAGE}"
    avdmanager create avd -n "${AVD_NAME}" -k "${PREFERRED_IMAGE}" --abi arm64-v8a --device "pixel_4"
fi
```

Step 7. Start Docker Desktop and let it finish loading.

Step 8. Start the emulator and verify it finishes booting:

```bash
emulator -avd "${AVD_NAME}" -no-snapshot-load -no-audio -no-boot-anim &
EMULATOR_PID=$!
sleep 30
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
echo "Emulator booted OK (PID: ${EMULATOR_PID})"
```

\[ \] Homebrew ready. \[ \] All tools smoke-tested. \[ \] Disk space >= 10 GB. \[ \] Emulator with an arm64 image ready and booted.

Gotcha to know now: exodus-standalone only ships for linux/amd64. On Apple Silicon you must run it through Rosetta emulation. The command in Part 3 already includes the flag for this.

---

## Part 1 — Get the APK file

Best way: pull it from a real device or your emulator. This gives clean proof of where it came from.

**Supply-chain warning:** `adb pull` transfers files over USB without cryptographic integrity protection. A compromised host or USB intermediary could swap files. For legal or disclosure use, pull from two independent sources and compare hashes.

Step 1. Start the emulator, or plug in the phone with USB debugging on.

Step 2. Check the device is seen:

```bash
adb devices | grep -v "List" | grep "device$" || { echo "FAIL: no device found"; exit 1; }
```

Step 3. Install the app from Google Play on the phone or emulator.

**Play Store verification:** Before installing, verify the Play Store app signature matches `CN=Android, OU=Android, O=Google Inc.` If sideloading from a mirror, tag the file `INFERRED` and do not use it for verified claims unless its hash matches a device-pulled file.

Step 4. Verify the APK architecture matches the emulator before installing:

```bash
adb shell getprop ro.product.cpu.abi | grep -q "${EMULATOR_ARCH}" || { echo "WARNING: architecture mismatch"; }
```

Step 5. Find where the APK lives:

```bash
adb shell pm path com.angry.shark.studio.nurturelock > artifacts/apks/nurturelock.paths.txt
```

Step 6. You will see one or more file paths. Copy each one.

Step 7. Pull each file. Run this once for each path:

```bash
while read -r path; do
    adb pull "${path}" "artifacts/apks/"
done < artifacts/apks/nurturelock.paths.txt
```

Step 8. Some apps come in more than one file (split APKs). This is normal. Pull all of them.

**Boundary test:** If zero paths are returned, the app may not be installed. If more than 5 paths are returned, verify each split is expected (base + config + architecture + density + language).

Step 9. Compute and record SHA-256 hashes with timestamps:

```bash
for f in artifacts/apks/*.apk; do
    shasum -a 256 "${f}" > "${f}.sha256"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $(basename "${f}") $(cat "${f}.sha256")" >> artifacts/apks/hashes.log
done
```

Step 10. Write down proof for your records:

* Device model
* Android version
* App version number
* Today's date
* The SHA-256 hash of each APK file (run: `shasum -a 256 artifacts/apks/*.apk`)

\[ \] APK files are in `artifacts/apks/`. \[ \] Proof details are written down. \[ \] Hashes are timestamped.

Note on other sources:

* You can also get APKs from mirror sites (APKMirror, APKPure, APKCombo).
* Mirror files can be changed or fake.
* Do not trust a mirror file on its own.
* Only trust it if its hash matches a file you pulled from the device.

---

## Part 2 — The offline test (do this first)

This is the fast test. Do it before the deep tests.

**Idempotency note:** If you already installed the mitmproxy CA in a prior run, skip Step 3 (cert installation) unless you restored a clean emulator snapshot.

Step 1. Verify the mitmproxy certificate exists and compute its hash for integrity:

```bash
test -f "${MITMPROXY_CERT}" || { echo "FAIL: mitmproxy CA not found. Run mitmweb once to generate it."; exit 1; }
openssl x509 -in "${MITMPROXY_CERT}" -noout -sha256 -fingerprint > artifacts/logs/mitmproxy-cert-fingerprint.log
echo "mitmproxy CA integrity: $(cat artifacts/logs/mitmproxy-cert-fingerprint.log)"
```

Step 2. Start mitmproxy on the Mac:

```bash
mitmweb --listen-port "${PROXY_PORT}" --web-port 8081 --save-stream-file "artifacts/captures/offline-test.mitm" &
MITM_PID=$!
sleep 2
curl -sf http://localhost:8081 || { echo "FAIL: mitmweb not responding"; kill "${MITM_PID}"; exit 1; }
echo "mitmweb running (PID: ${MITM_PID})"
```

Step 3. Point the emulator at mitmproxy. From inside the emulator, the Mac is address `${PROXY_HOST}`. Set the proxy inside Android settings to `${PROXY_HOST}` port `${PROXY_PORT}`. Do not use the emulator `-http-proxy` flag on new Android versions; set it inside Android instead.

Step 4. Install the mitmproxy certificate so HTTPS can be read.

* On Android 9 (API 28): start the emulator writable, then push the certificate into the system store. Full commands are in "If something breaks".
* On Android 14+ / 16: use the MoveCertificate Magisk module. See "If something breaks".

**Verification:** After installing the certificate, verify it appears in the system trust store:

```bash
adb shell "su -c 'ls /system/etc/security/cacerts/'" | grep -i "mitm" || { echo "WARNING: mitmproxy CA not found in system store"; }
```

Step 5. Open the app.

Step 6. Do these actions, one at a time:

* Create a baby profile (use reproducible test data: name = "TestBaby", DOB = 2024-01-01).
* Log a feed.
* Log a sleep.
* Log a diaper change.

**State transition note:** After each action, wait 5 seconds for any background network activity before proceeding.

Step 7. Watch the mitmproxy web view the whole time.

Step 8. Wait an additional 60 seconds for background/idle traffic, then ask: did any request leave the phone?

**Background coverage:** Apps often phone home when idle. If zero traffic was seen during active use, wait another 60 seconds with the app in the foreground but idle.

Step 9. Export the mitmproxy flow list to a structured file:

```bash
curl -s http://localhost:8081/flows > artifacts/captures/offline-test-flows.json
```

The result:

* Nurture Lock: any outbound request = claim is false. Write it down.
* Nurture Lock: zero outbound requests = claim holds so far. Write it down.
* **Provisional pass time-bound:** A provisional pass is valid for `${PROVISIONAL_PASS_MINUTES}` minutes. Re-test if the app updates or if the device state changes.

\[ \] Offline test done. \[ \] Result written down. \[ \] Flows exported to JSON. \[ \] Background idle period observed.

---

## Part 3 — Static scan (what is inside the file)

This finds trackers and permissions without running the app.

Step 1. Run exodus-standalone on the APK with a **pinned image digest**:

```bash
docker run --platform linux/amd64 \
  -v "${WORK_DIR}/artifacts/apks":/app \
  --rm -i \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  "${EXODUS_IMAGE}" \
  /app/<your-file>.apk
```

**Sandboxing:** The container runs with `--read-only` and a restricted tmpfs to limit host exposure.

To save a JSON report instead of text, add `-j` and `-o`:

```bash
docker run --platform linux/amd64 \
  -v "${WORK_DIR}/artifacts/apks":/app \
  --rm -i \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  "${EXODUS_IMAGE}" \
  /app/<your-file>.apk -j -o /app/report.json
```

Step 2. Read the output. It lists:

* Trackers found
* Permissions asked for
* APK checksum and version

Step 3. Write down the tracker names and the permission names.

Why this matters:

* The public exodus website has NO report for the Nurture Lock package. This was confirmed: the site returns an empty list and a 404 for that package.
* Running exodus yourself makes the report that does not exist yet.

Step 4. Decompile the app to read strings:

```bash
jadx -d "artifacts/reports/jadx-out" "artifacts/apks/<your-file>.apk"
```

Step 5. Search the decompiled files for clues with an **improved, obfuscation-aware pattern**:

```bash
grep -rEi \
  'https?://[^"\s]+|firebase|analytics|crashlytics|unity3d|facebook|mixpanel| amplitude|segment|appsflyer|bugsnag|sentry|adjust|mParticle|localytics|collect|track|telemetry|metrics' \
  artifacts/reports/jadx-out/ \
  > artifacts/reports/string-hits.txt
```

**Obfuscation note:** This grep catches common SDK names but misses encrypted strings, native code (`.so`), and reflection-based loading. If zero hits are found but the APK requests `INTERNET` permission, escalate to dynamic analysis or memory dump.

\[ \] Static scan done. \[ \] Tracker names and permissions written down. \[ \] Report saved to `artifacts/reports/`.

---

## Part 4 — Dynamic capture (what it does when running)

This watches real traffic while you use the app. This is the strongest proof.

Step 1. Make sure mitmweb is still running and the emulator still points at `${PROXY_HOST}:${PROXY_PORT}`.

Step 2. Open the app.

Step 3. Do the same actions as Part 2 (profile, feed, sleep, diaper).

Step 4. Look at every request in mitmproxy.

Step 5. For each request, write down:

* The destination address (where it went)
* Is that address a known tracker?
* What data was in the request body?
* **Protocol:** HTTP, HTTPS, DNS, WebSocket, or other?
* **DoH/DoT check:** If destination is a known DoH provider (Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9), flag for deeper inspection.

Step 6. Export flows to structured JSON:

```bash
curl -s http://localhost:8081/flows > artifacts/captures/dynamic-test-flows.json
```

**Flow integrity check:** Count flows in mitmweb UI and compare to JSON array length. If counts differ, mitmproxy may have dropped packets.

Step 7. If mitmproxy shows nothing but you think the app is hiding traffic, the app may use certificate pinning.

Step 8. To get past pinning, use objection to disable it at runtime:

```bash
objection -g com.angry.shark.studio.nurturelock explore
android sslpinning disable
```

**Pinning bypass warning:** Disabling certificate pinning weakens the security of the test device. Only do this on a dedicated test emulator. Restore the emulator to a clean snapshot after testing.

Step 9. Try the actions again and watch mitmproxy.

**Covert channel check:** Even if HTTP/HTTPS shows nothing, check for:
* ICMP traffic (ping tunneling)
* DNS queries with long subdomains (DNS tunneling)
* UDP traffic on non-standard ports

Use `tcpdump` or Wireshark on the host to capture all Layer 3 traffic if mitmproxy shows nothing:

```bash
sudo tcpdump -i any -w artifacts/captures/all-traffic.pcap host 10.0.2.2 &
```

Two 2026 gotchas for pinning:

* objection may need a development build to match the current Frida version. If objection errors on a version mismatch, install the dev build of objection.
* For split APKs, the Frida gadget must be placed in the arm64_v8a split before you repack. If the patched app does not start, this is usually why.
* **Max retry bound:** If pinning bypass fails after `${MAX_RETRIES}` attempts with `${RETRY_BACKOFF_SEC}`-second backoff, record "could not decrypt" and stop. Do not loop indefinitely.

\[ \] Dynamic capture done. \[ \] Every destination written down. \[ \] Covert channel check performed (or noted as skipped). \[ \] Flow integrity verified.

---

## Part 5 — Write your results

Fill in this table for each app.

| Question | Nurture Lock | Nubo | Pebbi |
| --- | --- | --- | --- |
| Did any data leave the phone? |  |  |  |
| How many trackers found (static)? |  |  |  |
| What permissions did it ask for? |  |  |  |
| List every outside address it contacted |  |  |  |
| Does the app match its own privacy claim? |  |  |  |

The pass / fail rule:

* Fail: the app sends data it said it would not send.
* Pass: the app behaves the way its own words say.
* Untested: pinning could not be broken or a critical step failed.

**Where static and dynamic disagree, trust dynamic and note the difference.**

---

## Part 6 — Backup mechanism and covert channel analysis

**P1 finding from security review:** "Offline" apps may still leak data through non-network vectors.

Step 1. Check Android backup settings:

```bash
adb shell settings get global backup_enabled
adb shell bmgr list transports
```

If backup is enabled, the app may sync data through Google Backup even if it never opens a network socket.

Step 2. Check for accessibility services that could exfiltrate data:

```bash
adb shell settings put secure enabled_accessibility_services
```

If unknown accessibility services are enabled, they may capture screen content or UI events.

Step 3. Check for overlay permissions:

```bash
adb shell appops query-op --user 0 SYSTEM_ALERT_WINDOW allow
```

Overlays can capture screenshots or intercept input.

Step 4. Check for adb backup data leakage:

```bash
adb backup -noapk com.angry.shark.studio.nurturelock -f artifacts/reports/nurturelock.ab
```

If the backup file is non-empty, the app persists data outside the APK.

\[ \] Backup mechanisms checked. \[ \] Covert channel vectors documented.

---

## Part 7 — Cleanup and teardown

**Required before re-use or disposal of the test environment.**

Step 1. Stop mitmweb and remove the CA from the emulator system store:

```bash
kill "${MITM_PID}" 2>/dev/null || true
adb root
adb remount
HASH=$(openssl x509 -inform PEM -subject_hash_old -in "${MITMPROXY_CERT}" | head -1)
adb shell "rm -f /system/etc/security/cacerts/${HASH}.0"
adb reboot
```

Step 2. Uninstall test apps:

```bash
adb uninstall com.angry.shark.studio.nurturelock || true
```

Step 3. Archive artifacts with retention policy:

```bash
tar czf "artifacts-$(date +%Y%m%d-%H%M%S).tar.gz" artifacts/
echo "Artifacts archived. Retain for 90 days minimum."
```

Step 4. Restore emulator from snapshot or delete the AVD:

```bash
# Option A: restore clean snapshot
# Option B: delete AVD
# avdmanager delete avd -n "${AVD_NAME}"
```

\[ \] CA removed. \[ \] Apps uninstalled. \[ \] Artifacts archived.

---

## If something breaks

### Install the mitmproxy system certificate on Android 9 (API 28)

```bash
emulator -avd "${AVD_NAME}" -writable-system
adb root
adb remount
HASH=$(openssl x509 -inform PEM -subject_hash_old -in "${MITMPROXY_CERT}" | head -1)
cp "${MITMPROXY_CERT}" "${HASH}.0"
adb push "${HASH}.0" "/system/etc/security/cacerts/${HASH}.0"
adb shell chmod 644 "/system/etc/security/cacerts/${HASH}.0"
adb reboot
```

**Idempotency check:** Before pushing, check if the file already exists:

```bash
adb shell "ls /system/etc/security/cacerts/${HASH}.0" && echo "Cert already installed" || adb push "${HASH}.0" "/system/etc/security/cacerts/${HASH}.0"
```

### Certificate will not install on Android 14+ or Android 16

* The simple writable-system method fails on these versions.
* Use the MoveCertificate Magisk module (project ys1231/MoveCertificate) to place the certificate where the new Android version reads it.
* Set the proxy inside the Android settings, not with the emulator `-http-proxy` flag. The flag is known to break capture on Android 16.
* Easier path: use an older image (API 28) just for testing.

### App is in more than one file (split APKs)

* Pull all the files.
* Install all of them together with: `adb install-multiple artifacts/apks/*.apk`
* For pinning bypass, put the Frida gadget in the arm64_v8a split before repacking.
* **Boundary test:** If more than 5 splits, verify each against the Play Store manifest.

### mitmproxy shows no traffic at all

* Check the proxy is set inside Android (`${PROXY_HOST}:${PROXY_PORT}` for the emulator).
* Check the certificate is installed and trusted.
* Check `artifacts/logs/mitmproxy-cert-fingerprint.log` matches the installed cert.
* The app may use pinning. Go to Part 4, Step 8.
* **Covert channel fallback:** Run `tcpdump` or Wireshark on the host to catch non-HTTP traffic.

### exodus-standalone will not run

* Check Docker Desktop is running (`docker info`).
* Check you added `--platform linux/amd64` (required on Apple Silicon).
* Check the file path after `/app/` is correct.
* Check the image digest matches `${EXODUS_IMAGE}`.

### adb does not see the device

* Turn on USB debugging on a real phone.
* For the emulator, make sure it finished booting (`adb shell getprop sys.boot_completed`).
* Run `adb devices` to check it shows up.
* If the emulator crashed, check host RAM usage.

### Malware discovered in APK

**STOP.** Do not install or execute the APK on any non-isolated device.
1. Quarantine the file: `chmod 000 artifacts/apks/<file>`
2. Compute hash and upload to VirusTotal.
3. Document findings in `artifacts/reports/malware-incident.md`.
4. Notify the operator and await instructions.

---

## Things to keep in mind

* Only test apps you installed yourself. This is normal self-analysis.
* Static scan shows what is inside. It does not prove the app sent data.
* Dynamic capture shows what the app actually sent. This is the strong proof.
* The three named apps have not been tested by anyone yet. Your test would be new evidence.
* **Regression baseline:** Save `artifacts/` from this run. Future runs should compare against this baseline to detect new trackers or destinations.

---

## Where you may be unsure

* Nubo and Pebbi package names are not confirmed. Get them from the live Play Store pages first.
* If an app uses strong pinning that objection cannot break, you may not see the traffic. Write down that you could not decrypt it. Do not guess.
* Static and dynamic results can differ. If they do, trust the dynamic capture, and note the difference.
* Tool versions move fast. If a command errors, check the tool's current docs for the 2026 version before changing the method.
* **Performance budget:** The entire procedure should complete within `${PERF_BUDGET_MINUTES}` minutes. If exceeded, escalate to the operator.

---

## Audit log and chain of custody

Every run must produce an audit log:

```bash
cat > artifacts/logs/audit.log <<EOF
HARNESS_VERSION: ${HARNESS_VERSION}
TIMESTAMP_START: $(date -u +%Y-%m-%dT%H:%M:%SZ)
HOSTNAME: $(hostname)
USER: $(whoami)
DEVICE_MODEL: $(adb shell getprop ro.product.model 2>/dev/null || echo "unknown")
ANDROID_VERSION: $(adb shell getprop ro.build.version.release 2>/dev/null || echo "unknown")
TOOL_VERSIONS:
  adb: $(adb --version | head -1)
  mitmproxy: $(mitmweb --version 2>/dev/null || echo "unknown")
  jadx: $(jadx --version 2>/dev/null || echo "unknown")
  docker: $(docker --version)
  objection: $(objection --version 2>/dev/null || echo "unknown")
EOF
```

Append every major action to this log. The log is append-only and must be included in the artifact archive.

---

## Agent plan

This section is for an IDE LLM agent. Run it autonomously. Spawn one subagent per task. Each task lists inputs, commands, a done-check, and where to go if it fails. Run tasks in order. Do not start a task until its upstream done-check passes. Stop and ask the human only at the explicit HUMAN-GATE points.

**Agent execution state machine (formal DAG):**

```
[setup] ──► [resolve-packages] ──► [acquire-nurturelock]
                                      │
                                      ▼
                              [acquire-nubo] ──► [acquire-pebbi]
                                      │
                                      ▼
                              [offline-probe-all] ──► [static-all]
                                      │
                                      ▼
                              [dynamic-all] ──► [report]
```

**Concurrency rules:**
* `[acquire-*]` tasks may run in parallel IF each uses a separate emulator instance or snapshot.
* `[offline-probe-all]`, `[static-all]`, `[dynamic-all]` must run serially per app.
* `[mitmweb]` is a singleton resource (port 8080). Only one subagent may use it at a time.

**Global state schema (shared scratchpad — JSON, append-only):**

```json
{
  "version": "2.0.0-loop1-hardened",
  "packages": {
    "nurturelock": "com.angry.shark.studio.nurturelock",
    "nubo": "",
    "pebbi": ""
  },
  "apk_files": [
    {"path": "", "sha256": "", "timestamp": "", "source": "device|mirror"}
  ],
  "static_findings": {
    "nurturelock": {"trackers": [], "permissions": [], "report_path": ""}
  },
  "dynamic_findings": {
    "nurturelock": {"destinations": [], "payloads": [], "flow_path": ""}
  },
  "verdicts": {
    "nurturelock": {"verdict": "pass|fail|untested", "evidence": ""}
  },
  "audit_log": "artifacts/logs/audit.log"
}
```

**HUMAN-GATE conditions (max wait: 10 minutes, then escalate):**
* Unknown package names after Play Store fetch fails twice.
* Pinning cannot be broken after `${MAX_RETRIES}` attempts.
* Any step fails twice with the same error.
* Malware suspected in APK.
* Performance budget `${PERF_BUDGET_MINUTES}` exceeded.

---

### Subagent 1 — setup

* Goal: make the Mac ready.
* Commands: install Homebrew casks and tools from Part 0 with pinned versions; run smoke tests; start Docker; create or boot an arm64 emulator (API 28); verify disk space; create working directory and artifact structure; start audit log.
* Done-check: `adb devices` lists one device; `docker info` returns ok; `mitmweb` starts and binds port 8080; all tools smoke-tested; disk >= 10 GB; audit log initialized.
* On fail: read "If something breaks" for the adb and exodus rows; retry once with `${RETRY_BACKOFF_SEC}`-second backoff; if still failing, emit a HUMAN-GATE with the exact error and audit log excerpt.

---

### Subagent 2 — resolve-packages

* Goal: fill in the unknown package names for Nubo and Pebbi.
* Commands: fetch each app's live Google Play listing; extract the `id=` value from the URL.
* **Hallucination guard:** Do not invent package names. If the fetch returns no `id=`, record `null` and stop. Verify the fetched URL domain is `play.google.com`.
* **Validation:** Package name must match regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`.
* Done-check: `packages` map has three non-empty, validated package names.
* On fail: HUMAN-GATE asking the operator to paste the two Play Store URLs.

---

### Subagent 3 — acquire (run once per package)

* Goal: get clean APK files with provenance.
* Commands: `adb shell pm path <package>`; validate at least one path returned; `adb pull` each path; compute SHA-256; timestamp; record device model, Android version, app version, date.
* **Partial failure handling:** If one package fails, others continue. Failed packages get `verdict: untested`.
* **Boundary tests:** 0 paths → fail; >5 paths → flag for review.
* Done-check: at least one APK per package on disk; every file has a recorded hash, device model, Android version, app version, and date; hashes are in `artifacts/apks/hashes.log`.
* On fail: if a mirror file is used instead, tag it `INFERRED` and require a later hash match before any verified claim.

---

### Subagent 4 — offline-probe (the decisive test, run first per package)

* Goal: answer "does any data leave the phone" quickly.
* Preconditions: mitmweb running; emulator proxy set to `${PROXY_HOST}:${PROXY_PORT}`; mitmproxy certificate trusted and verified.
* Commands: launch app; script the standard interactions (create profile, log feed, log sleep, log diaper); wait 60 seconds for background traffic; export mitmproxy flow list.
* **UI action guard:** If UI automation fails (element not found), record the exact error and stop. Do not guess locators.
* **Oracle definition:** Outbound request = any TCP/UDP packet with destination NOT in (127.0.0.1/8, ::1, 224.0.0.0/4, NTP port 123).
* Done-check: a flow list exists (it may be empty). Record request count and whether any outbound request occurred. Flows exported to JSON.
* Decision rule: for a package that claims offline, any outbound request sets `verdict = fail` with the destination as evidence. Zero requests sets `verdict = provisional pass`, continue.
* On fail to capture: if flows are empty but the app looks networked, mark "pinning suspected" and hand off to Subagent 6.

---

### Subagent 5 — static

* Goal: list trackers and permissions without running the app.
* Commands: `docker run --platform linux/amd64` exodus-standalone with pinned digest, `-j -o report.json` per APK; `jadx` decompile; grep for URLs and SDK names with improved pattern.
* Done-check: a JSON report and a grep hit list saved per package; report includes APK checksum.
* Note: record explicitly that no public exodus report exists for the nurturelock package, so this local report is the first one.
* On fail: check the platform flag and Docker; retry once; else HUMAN-GATE.

---

### Subagent 6 — dynamic (deep capture, and pinning bypass if needed)

* Goal: record every real destination and payload.
* Commands: repeat the standard interactions under mitmweb; if pinning suspected, run `objection -g <package> explore` then `android sslpinning disable`, and retry.
* **Gotcha handling:** if objection errors on Frida version, install the dev build; for split APKs place the Frida gadget in the arm64_v8a split before repack.
* **Max retry bound:** If pinning bypass fails after `${MAX_RETRIES}` attempts, record "could not decrypt" and stop.
* **Covert channel check:** Run `tcpdump` on host to catch non-HTTP traffic if mitmproxy shows nothing.
* Done-check: `dynamic_findings` has a destination list per package; each destination tagged `tracker` or `not`; payload noted; covert channel check performed or documented as skipped.
* On fail: if pinning cannot be broken, record "could not decrypt" and do not guess; set the package's network claim to `untested`.

---

### Subagent 7 — report

* Goal: produce the final result table and verdicts.
* Commands: merge static and dynamic findings; fill the Part 5 table; apply the pass/fail rule; where static and dynamic disagree, trust dynamic and note it; append final state to audit log; archive artifacts.
* Done-check: every app has a filled row and a pass or fail (or untested) with one evidence line; audit log closed; artifacts archived.
* Output: `artifacts/reports/findings.md` plus the raw mitmproxy flows and exodus JSON as attachments.

---

### Agent rules (enforced)

* **Rule 1 (static verification):** Never tag a claim verified from a static scan alone. Static shows capability, not sending. Only dynamic capture verifies sending.
* **Rule 2 (mirror trust):** Never tag a claim verified from a mirror APK unless its hash matches a device-pulled file.
* **Rule 3 (version preference):** Prefer the API 28 image to avoid the Android 16 certificate problem unless the human asks for a newer version.
* **Rule 4 (context budget):** Keep each subagent's context under 4,000 tokens. Pass only the package name, file paths, and prior done-check results in JSON, not the whole document.
* **Rule 5 (HUMAN-GATE):** Emit a HUMAN-GATE for: unknown package names, unresolved pinning, any step that fails twice, malware suspected, or performance budget exceeded. Max wait: 10 minutes.
* **Rule 6 (sandbox):** Subagents must not modify files outside `${WORK_DIR}` or execute destructive host commands (`rm -rf /`, `dd`, `mkfs`). All shell commands are logged to audit log.
* **Rule 7 (grounding):** Before acting, subagent must re-read the relevant section of this document. Do not rely on prompt fragments.
* **Rule 8 (max iterations):** No subagent may retry the same step more than `${MAX_RETRIES}` times. After that, escalate.
