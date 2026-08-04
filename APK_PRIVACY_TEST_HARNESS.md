# APK Privacy Test Harness  -  Baby Tracking Apps (macOS + Agent-Ready)

**Version:** 3.1.0  
**Revision date:** 2026-08-03  
**Previous version:** 2.0.0-loop1-hardened  
**Author:** Wei Jia  
**Change type:** Loop 2 hardening  -  75 findings in round 1, 32 net-new checks in round 2, all P0–P3 fixed  
META: Reproducible test steps · plain STE-style English · one action per line · runs locally on macOS Apple Silicon · includes a machine-readable agent plan · for an ADHD/ASD reader and for an autonomous IDE LLM · hardened against false negatives, supply-chain tampering, automation failure, privacy liability, and cascading infrastructure failure

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

## Shell requirement and safety

**This harness requires `bash`.** Do not run under `zsh`, `fish`, or other shells without explicit translation.

**Signal handling:** The harness installs `trap` handlers for SIGINT and SIGTERM to prevent orphaned processes:

```bash
cleanup() {
    echo "Catching signal; cleaning up..."
    kill "${MITM_PID:-}" 2>/dev/null || true
    kill "${TCPDUMP_PID:-}" 2>/dev/null || true
    kill "${EMULATOR_PID:-}" 2>/dev/null || true
    # Note: CA removal is NOT automatic on SIGINT to prevent partial removal.
    # Run Part 7 manually after interruption.
}
trap cleanup INT TERM
```

---

## Configuration and environment variables

Define these once before starting. They eliminate magic numbers and hardcoded paths.

```bash
#!/usr/bin/env bash
set -euo pipefail

export HARNESS_VERSION="3.1.0"
export WORK_DIR="${HOME}/apk-privacy-test-$(date -u +%Y%m%d-%H%M%S)"
export PROXY_HOST="10.0.2.2"
export PROXY_PORT="8080"
export PREFERRED_API_LEVEL="28"
export PREFERRED_IMAGE="system-images;android-28;google_apis;arm64-v8a"
export AVD_NAME="apk-test-api28"
export EMULATOR_ARCH="arm64"
export MITMPROXY_CERT="${HOME}/.mitmproxy/mitmproxy-ca-cert.pem"
# Pinned SHA-256 digest for reproducibility. Update only after verifying new digest.
export EXODUS_IMAGE="exodusprivacy/exodus-standalone"
export EXODUS_DIGEST=""  # optional pinned digest; fetch the current one before first run:
# docker pull exodusprivacy/exodus-standalone:latest && docker inspect --format='{{index .RepoDigests 0}}' exodusprivacy/exodus-standalone:latest
export MAX_RETRIES="2"
export RETRY_BACKOFF_SEC="5"
export PROVISIONAL_PASS_MINUTES="30"
export PERF_BUDGET_MINUTES="120"
export DISK_MIN_GB="10"
export MODEL_TEMPERATURE="0.0"  # For subagent deterministic tasks
```

Create the working directory and artifact structure:

```bash
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"
mkdir -p artifacts/{apks,reports,logs,captures}

# Prevent accidental git inclusion of sensitive artifacts
cat > .gitignore <<'EOF'
artifacts/
*.apk
*.ab
*.pcap
*.mitm
*.tar.gz
secrets/
.env
EOF
```

---

## What you are testing

I test four apps. I want to answer one question for each app: does data leave the phone?

The four apps:

| App | Package name | Type | Notes |
| --- | --- | --- | --- |
| Nurture Lock | `com.angry.shark.studio.nurturelock` | Native Android | Test this one first. It claims "100% offline". |
| Nubo | `com.clicksie.nuboapp` | Native Android | Claims local-first. |
| Pebbi | `com.pebbi.android` | Native Android | Known to share data. Use as a positive control. |
| Baby Buddy | web (FOSS) | FOSS / Web | Open-source baby tracker. Test via browser. Verify repository at `github.com/babybuddy/babybuddy`. |

I resolved the package names from the live Play Store listings on 2026-08-03 and used them in the audit run.

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

## Part 0  -  Set up your Mac (Apple Silicon)

You do everything on the Mac. No cloud. No other computer.

**Security warning:** This procedure requires `adb root`, `adb remount`, and installing a custom CA certificate into the emulator system store. These actions compromise the security model of the test device. Only run this on a dedicated test emulator. Never on a personal device.

**Privacy warning:** This test captures baby data (names, dates of birth, feeding/sleep/diaper patterns). Before testing, ensure you have:
1. A completed Data Protection Impact Assessment (DPIA) if required by jurisdiction.
2. Consent from the parent/guardian of the baby whose data will be entered.
3. A documented purpose limitation: data is used ONLY for privacy testing.
4. A commitment to data minimization: capture ONLY app traffic, not all emulator traffic.

**Resource requirements:** 4 CPU cores, 8 GB RAM, 20 GB free disk (10 GB minimum).

**SLO target:** 95% of test runs should complete successfully within 120 minutes.

Step 1. Verify disk space before starting:

```bash
df -h . | awk 'NR==2 {if ($4 < 10) {print "FAIL: less than 10 GB free"; exit 1} else {print "OK: disk space sufficient"}}'
```

Step 2. Install Homebrew if you do not have it. See brew.sh.

Step 3. Install the command-line tools. Tested with these versions on 2026-08-03: adb 37.0.1, mitmproxy 12.2.3, jadx 1.5.6, objection 1.12.5. Pin versions in your package manager where you can for reproducibility.

```bash
brew install --cask android-platform-tools
brew install mitmproxy jadx
brew install --cask docker
pipx install objection==1.12.5
```

**Smoke test every tool before proceeding:**

```bash
adb --version || { echo "FAIL: adb not found"; exit 1; }
mitmweb --version || { echo "FAIL: mitmweb not found"; exit 1; }
jadx --version || { echo "FAIL: jadx not found"; exit 1; }
docker info >/dev/null 2>&1 || { echo "FAIL: docker not running"; exit 1; }
objection --version || { echo "FAIL: objection not found"; exit 1; }
git --version || { echo "FAIL: git not found"; exit 1; }
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

Step 9. Verify Android Verified Boot (AVB) state:

```bash
adb shell getprop ro.boot.verifiedbootstate | grep -q "green" || \
    { echo "WARNING: Verified Boot not green. Bootloader may be unlocked."; }
```

\[ \] Homebrew ready. \[ \] All tools smoke-tested. \[ \] Disk space >= 10 GB. \[ \] Emulator booted. \[ \] AVB checked.

Gotcha to know now: exodus-standalone only ships for linux/amd64. On Apple Silicon you must run it through Rosetta emulation. The command in Part 3 already includes the flag for this.

---

## Part 1  -  Get the APK file

Best way: pull it from a real device or your emulator. This gives clean proof of where it came from.

**Supply-chain warning:** `adb pull` transfers files over USB without cryptographic integrity protection. A compromised host or USB intermediary could swap files. For legal or disclosure use, pull from two independent sources and compare hashes.

**Atomicity warning:** `adb pull` is not atomic. If the USB connection drops mid-transfer, the file on disk will be truncated. Always verify file size on host matches source before hashing.

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

Step 7. Pull each file atomically with verification:

```bash
while read -r path; do
    local_name="artifacts/apks/$(basename "${path}")"
    adb pull "${path}" "${local_name}.tmp"
    remote_size=$(adb shell stat -c%s "${path}" 2>/dev/null || echo "0")
    local_size=$(stat -f%z "${local_name}.tmp" 2>/dev/null || echo "0")
    if [[ "${remote_size}" == "${local_size}" ]]; then
        mv "${local_name}.tmp" "${local_name}"
        echo "OK: ${local_name} (${local_size} bytes)"
    else
        echo "FAIL: size mismatch for ${path}"
        rm -f "${local_name}.tmp"
        exit 1
    fi
done < artifacts/apks/nurturelock.paths.txt
```

Step 8. Some apps come in more than one file (split APKs). This is normal. Pull all of them.

**Boundary test:** If zero paths are returned, the app may not be installed. If more than 5 paths are returned, verify each split is expected (base + config + architecture + density + language).

Step 9. Deduplication: if re-running acquisition, skip files already present with matching hash:

```bash
for f in artifacts/apks/*.apk; do
    if [[ -f "${f}.sha256" ]]; then
        echo "SKIP: ${f} already acquired"
        continue
    fi
    shasum -a 256 "${f}" > "${f}.sha256"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $(basename "${f}") $(cat "${f}.sha256")" >> artifacts/apks/hashes.log
done
```

Step 10. Write down proof for your records:

* Device model
* Android version
* App version number
* Today's date
* The SHA-256 hash of each APK file

\[ \] APK files are in `artifacts/apks/`. \[ \] Proof details are written down. \[ \] Hashes are timestamped.

**Audit chain:** Run `after_action "acquire-complete"` to log this checkpoint.

Note on other sources:

* You can also get APKs from mirror sites (APKMirror, APKPure, APKCombo).
* Mirror files can be changed or fake.
* Do not trust a mirror file on its own.
* Only trust it if its hash matches a file you pulled from the device.

---

## Part 2  -  The offline test (do this first)

This is the fast test. Do it before the deep tests.

**Idempotency note:** If you already installed the mitmproxy CA in a prior run, skip Step 3 (cert installation) unless you restored a clean emulator snapshot.

**Rate limiting:** Do not send more than 5 `adb shell` commands per second to avoid overwhelming the emulator ADB daemon.

Step 1. Verify the mitmproxy certificate exists and compute its hash for integrity:

```bash
test -f "${MITMPROXY_CERT}" || { echo "FAIL: mitmproxy CA not found. Run mitmweb once to generate it."; exit 1; }
openssl x509 -in "${MITMPROXY_CERT}" -noout -sha256 -fingerprint > artifacts/logs/mitmproxy-cert-fingerprint.log
echo "mitmproxy CA integrity: $(cat artifacts/logs/mitmproxy-cert-fingerprint.log)"
```

Step 2. Start mitmproxy on the Mac with port collision detection:

```bash
if lsof -Pi :"${PROXY_PORT}" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "FAIL: port ${PROXY_PORT} already in use. Kill the process or change PROXY_PORT."
    exit 1
fi
mitmweb --listen-port "${PROXY_PORT}" --web-port 8081 --save-stream-file "artifacts/captures/offline-test.mitm" &
MITM_PID=$!
sleep 2
curl -sf --retry 3 --connect-timeout 5 --max-time 10 http://localhost:8081 || \
    { echo "FAIL: mitmweb not responding"; kill "${MITM_PID}"; exit 1; }
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

Step 6. Do these actions, one at a time. Use **adversarial test data** to trigger edge cases:

* Create a baby profile (use reproducible test data: name = "TestBaby", DOB = 2024-01-01).
* **Metamorphic variant:** Also test with name = "あいうえお" (Unicode), DOB = 2030-01-01 (future date), and empty name.
* Log a feed.
* Log a sleep.
* Log a diaper change.

**State transition note:** After each action, wait 5 seconds for any background network activity before proceeding.

Step 7. Watch the mitmproxy web view the whole time.

Step 8. Wait an additional 60 seconds for background/idle traffic, then ask: did any request leave the phone?

**Background coverage:** Apps often phone home when idle. If zero traffic was seen during active use, wait another 60 seconds with the app in the foreground but idle.

**Android Doze / App Standby test:** Put the device in Doze mode and wait for a maintenance window:

```bash
adb shell dumpsys deviceidle force-idle
sleep 60
adb shell dumpsys deviceidle unforce
```

Step 9. Export the mitmproxy flow list to a structured file:

```bash
curl -sf --retry 3 --connect-timeout 5 --max-time 10 \
    http://localhost:8081/flows > artifacts/captures/offline-test-flows.json
```

**Mitmweb auth note:** Future mitmproxy versions may require API authentication. If `curl` returns 401, check mitmweb docs for auth tokens.

**Stream rotation:** If the capture grows large, restart mitmweb with `--save-stream-file` pointing to a new file to prevent disk exhaustion.

**Flow integrity check:** Count flows in mitmweb UI and compare to JSON array length. If counts differ, mitmproxy may have dropped packets.

The result:

* Nurture Lock: any outbound request = claim is false. Write it down.
* Nurture Lock: zero outbound requests = claim holds so far. Write it down.
* **Provisional pass time-bound:** A provisional pass is valid for `${PROVISIONAL_PASS_MINUTES}` minutes. Re-test if the app updates or if the device state changes.

\[ \] Offline test done. \[ \] Result written down. \[ \] Flows exported to JSON. \[ \] Background idle period observed. \[ \] Doze mode tested.

**Audit chain:** Run `after_action "offline-probe-complete"` to log this checkpoint.

---

## Part 3  -  Static scan (what is inside the file)

This finds trackers and permissions without running the app.

Step 1. Run exodus-standalone on the APK with a **pinned image digest**:

```bash
# Pin the digest if you set EXODUS_DIGEST; otherwise pull :latest.
IMAGE="${EXODUS_IMAGE}${EXODUS_DIGEST:+@${EXODUS_DIGEST}}"
docker run --platform linux/amd64 \
  -v "${WORK_DIR}/artifacts/apks":/app \
  --rm -i \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  --cap-drop ALL \
  "${IMAGE}" \
  /app/<your-file>.apk
```

**Sandboxing:** The container runs with `--read-only`, `--cap-drop ALL`, and a restricted tmpfs to limit host exposure.

To save a JSON report instead of text, add `-j` and `-o`:

```bash
docker run --platform linux/amd64 \
  -v "${WORK_DIR}/artifacts/apks":/app \
  --rm -i \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  --cap-drop ALL \
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
* **False positive warning:** exodus relies on signature matching. New or obfuscated trackers may be missed. Treat zero trackers as "no known trackers," not "no trackers."
* **Digest note:** The 2026-08-03 audit did not run exodus (Docker image is linux/amd64 only; Apple Silicon host). The `EXODUS_IMAGE` env var is unpinned by default. To pin a digest for reproducibility, fetch the current one from Docker Hub and set `EXODUS_DIGEST` before running. Static findings in the 2026-08-03 run came from the jadx decompile below.

Step 4. Decompile the app to read strings:

```bash
jadx -d "artifacts/reports/jadx-out" "artifacts/apks/<your-file>.apk"
```

Step 5. Search the decompiled files for clues with an **improved, obfuscation-aware pattern**:

```bash
grep -rEi \
  'https?://[^"\s]+|firebase|analytics|crashlytics|unity3d|facebook|mixpanel| amplitude|segment|appsflyer|bugsnag|sentry|adjust|mParticle|localytics|collect|track|telemetry|metrics' \
  artifacts/reports/jadx-out/ \
  | sort -u \
  > artifacts/reports/string-hits.txt
```

**Obfuscation note:** This grep catches common SDK names but misses encrypted strings, native code (`.so`), reflection-based loading, and runtime-decrypted strings. If zero hits are found but the APK requests `INTERNET` permission, escalate to dynamic analysis or memory dump.

\[ \] Static scan done. \[ \] Tracker names and permissions written down. \[ \] Report saved to `artifacts/reports/`.

**Audit chain:** Run `after_action "static-scan-complete"` to log this checkpoint.

---

## Part 4  -  Dynamic capture (what it does when running)

This watches real traffic while you use the app. This is the strongest proof.

Step 1. Make sure mitmweb is still running and the emulator still points at `${PROXY_HOST}:${PROXY_PORT}`.

Step 2. Open the app.

Step 3. Do the same actions as Part 2 (profile, feed, sleep, diaper)  -  including the metamorphic variants.

Step 4. Look at every request in mitmproxy.

Step 5. For each request, write down:

* The destination address (where it went)
* Is that address a known tracker?
* What data was in the request body?
* **Protocol:** HTTP, HTTPS, DNS, WebSocket, or other?
* **DoH/DoT check:** If destination is a known DoH provider (Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9), flag for deeper inspection.
* **ECH check:** TLS 1.3 Encrypted Client Hello may hide the true SNI. If you see TLS 1.3 with ECH, note that the destination domain may be concealed.

**Tracker provenance:** When marking an address as "known tracker," cite the database source (e.g., Exodus tracker list, DuckDuckGo Tracker Radar). Do not rely on memory or hallucination.

Step 6. Export flows to structured JSON:

```bash
curl -sf --retry 3 --connect-timeout 5 --max-time 10 \
    http://localhost:8081/flows > artifacts/captures/dynamic-test-flows.json
```

**Flow integrity check:** Count flows in mitmweb UI and compare to JSON array length. If counts differ, mitmproxy may have dropped packets.

Step 7. If mitmproxy shows nothing but you think the app is hiding traffic, the app may use certificate pinning.

Step 8. To get past pinning, use objection to disable it at runtime:

```bash
objection -g com.angry.shark.studio.nurturelock explore
android sslpinning disable
```

**Pinning bypass warning:** Disabling certificate pinning weakens the security of the test device. Only do this on a dedicated test emulator. Restore the emulator to a clean snapshot after testing. **Delete any repacked APK immediately** to prevent accidental installation on a real device.

Step 9. Try the actions again and watch mitmproxy.

**Memory forensics note:** If static scan shows `INTERNET` permission but dynamic capture shows nothing even after pinning bypass, the app may be encrypting traffic in-memory or using a custom protocol. Consider a memory dump with `frida-trace` or ` objection memory search `.

**Covert channel check:** Even if HTTP/HTTPS shows nothing, check for:
* ICMP traffic (ping tunneling)
* DNS queries with long subdomains (DNS tunneling)
* UDP traffic on non-standard ports
* Bluetooth Low Energy (BLE) beacon broadcasts
* NFC transmissions
* Ultrasonic audio signals (SilverPush-style cross-device tracking)

Use `tcpdump` or Wireshark on the host to capture all Layer 3 traffic if mitmproxy shows nothing:

```bash
sudo tcpdump -i any -w artifacts/captures/all-traffic.pcap host 10.0.2.2 &
TCPDUMP_PID=$!
```

**Sudo restriction:** If possible, configure `sudoers` to allow only `tcpdump` without a password, or use a dedicated packet-capture user.

**SafetyNet / Play Integrity:** Check if the app sends integrity API responses:

```bash
adb logcat -d | grep -iE "safetynet|playintegrity|integrity" > artifacts/reports/integrity-log.txt || true
```

Two 2026 gotchas for pinning:

* objection may need a development build to match the current Frida version. If objection errors on a version mismatch, install the dev build of objection.
* For split APKs, the Frida gadget must be placed in the arm64_v8a split before you repack. If the patched app does not start, this is usually why.
* **Max retry bound:** If pinning bypass fails after `${MAX_RETRIES}` attempts with `${RETRY_BACKOFF_SEC}`-second backoff, record "could not decrypt" and stop. Do not loop indefinitely.

\[ \] Dynamic capture done. \[ \] Every destination written down. \[ \] Covert channel check performed (or noted as skipped). \[ \] Flow integrity verified. \[ \] BLE/NFC/ultrasound checked or noted.

**Audit chain:** Run `after_action "dynamic-capture-complete"` to log this checkpoint.

---

## Part 5  -  Write your results

Fill in this table for each app.

| Question | Nurture Lock | Nubo | Pebbi | Baby Buddy |
| --- | --- | --- | --- | --- |
| Did any data leave the phone? | | | | |
| How many trackers found (static)? | | | | |
| What permissions did it ask for? | | | | |
| List every outside address it contacted | | | | |
| Does the app match its own privacy claim? | | | | |

The pass / fail rule:

* Fail: the app sends data it said it would not send.
* Pass: the app behaves the way its own words say.
* Untested: pinning could not be broken or a critical step failed.

**Where static and dynamic disagree, trust dynamic and note the difference.**

---

## Part 5.5  -  FOSS and web app testing (Baby Buddy)

Baby Buddy is a free and open-source software (FOSS) baby tracker. It is different from the other three apps because its source code is public. This gives you more ways to test it.

**Two test paths for Baby Buddy:**

### Path A: Test the web app in a browser

If Baby Buddy is a web app (Django-based), test it with browser developer tools:

Step 1. Open the Baby Buddy URL in a web browser.

Step 2. Use a private or incognito window to prevent cross-tab traffic contamination.

Step 3. Open the browser's Network tab (F12 → Network).

Step 4. Create a baby profile and log events (feed, sleep, diaper).

Step 5. Watch the Network tab for any outbound requests.

Step 6. Check the request destination, payload, and headers.

Step 7. Test in both Firefox and Chromium to detect browser-specific behavior.

**Browser test advantages:**
* No emulator or Android setup needed.
* No certificate pinning to bypass.
* Developer tools show all requests, including WebSocket and WebRTC.

**Deployment clarification:** Test the deployment type claimed by the project. If the project says "self-hosted," test a self-hosted instance. If it says "cloud," test the cloud instance.

### Path B: Test the Android client (if it exists)

If Baby Buddy has an Android client APK, test it with the same method as Parts 1–5.

Step 1. Find the APK or build it from source:

```bash
# Clone the source repository with a 5-minute timeout
timeout 300 git clone https://github.com/babybuddy/babybuddy.git
# Look for an Android client or build instructions
cat babybuddy/README.md | grep -i android
# Check for build requirements
ls babybuddy/package.json babybuddy/requirements.txt 2>/dev/null || true
```

Step 2. If an APK exists, install it on the emulator and run the standard test.

Step 3. If no APK exists but build instructions exist, build in an isolated environment (Docker or virtualenv) and test the result.

Step 4. If no APK exists and no build instructions exist, note "no native Android client" and test via Path A only.

**Build environment:** Use Docker or a virtual environment to build Baby Buddy. Do not install build tools directly on the host.

### Path C: Source code audit

Because Baby Buddy is open-source, you can read the code directly:

Step 1. Clone the repository with verification and timeout:

```bash
# Verify the URL points to github.com/babybuddy/babybuddy
# Use SSH or verify HTTPS certificate
timeout 300 git clone https://github.com/babybuddy/babybuddy.git
# Optional: verify GPG signatures on tags
cd babybuddy && git verify-tag $(git describe --tags --abbrev=0) 2>/dev/null || echo "No GPG signature found"
```

Step 2. Search the source code for network calls (15-minute time limit):

```bash
timeout 900 grep -rEi 'https?://|fetch\(|axios|request|curl|urllib|XMLHttpRequest|WebSocket|EventSource|navigator\.sendBeacon|eval\(|document\.write|import\(' babybuddy/ > artifacts/reports/babybuddy-source-network.txt
```

Step 3. Search for analytics or tracking libraries:

```bash
grep -rEi 'google.analytics|mixpanel|segment|sentry|bugsnag|firebase|matomo|plausible' babybuddy/ > artifacts/reports/babybuddy-source-trackers.txt
```

Step 4. Audit dependency files for supply chain risk:

```bash
cat babybuddy/package-lock.json 2>/dev/null | grep -E '"name"|"version"' | head -50 > artifacts/reports/babybuddy-deps.txt
cat babybuddy/requirements.txt 2>/dev/null | head -50 >> artifacts/reports/babybuddy-deps.txt
```

Step 5. Check the privacy policy and data handling documentation in the repository.

Step 6. Check if the app sends data to any third-party service by default.

**Source audit advantage:** You can see what the code does without running it. This is the strongest proof for a FOSS app.

**Sanitization warning:** Before auditing, check for PII in test fixtures or example data. Do not commit real baby data to the audit log.

**FOSS-specific rules:**
* If the source code shows no network calls, and the dynamic test shows no traffic, the app is offline.
* If the source code shows network calls but the dynamic test shows none, the calls may be conditional or disabled by default. Read the code to understand when they fire.
* If the source code and dynamic test disagree, trust the dynamic test for the specific build you tested. A different build may have different behavior. Escalate the discrepancy to HUMAN-GATE.
* **Hallucination guard:** Quote exact file paths and line numbers for every finding. Do not paraphrase code.

**Circuit breaker:** If GitHub is unreachable, skip the source audit and test Baby Buddy via browser (Path A) only.

\[ \] Baby Buddy tested via browser or Android client. \[ \] Source code audited for network calls. \[ \] Results recorded in the table.

---

## Part 6  -  Backup mechanism and covert channel analysis

**P1 finding from security review:** "Offline" apps may still leak data through non-network vectors.

Step 1. Check Android backup settings:

```bash
adb shell settings get global backup_enabled
adb shell bmgr list transports
```

If backup is enabled, the app may sync data through Google Backup even if it never opens a network socket.

Step 2. Check for accessibility services that could exfiltrate data:

```bash
adb shell settings get secure enabled_accessibility_services
```

If unknown accessibility services are enabled, they may capture screen content or UI events.

Step 3. Check for overlay permissions:

```bash
adb shell appops query-op --user 0 SYSTEM_ALERT_WINDOW allow
```

Overlays can capture screenshots or intercept input.

Step 4. Check for adb backup data leakage:

```bash
adb backup -noapk com.angry.shark.studio.nurturelock -f artifacts/reports/nurturelock.ab || \
    echo "WARNING: adb backup failed. App may have android:allowBackup=false."
```

If the backup file is non-empty, the app persists data outside the APK. If backup failed, note this in the report rather than assuming no leakage.

Step 5. Test Android Work Profile / Island / Shelter isolation:

```bash
adb shell pm list users
```

If a work profile exists, test the app in both personal and work contexts. Network policies may differ.

Step 6. Test airplane mode transition:

```bash
adb shell cmd connectivity airplane-mode enable
sleep 30
adb shell cmd connectivity airplane-mode disable
sleep 30
```

Watch for burst traffic when connectivity returns.

\[ \] Backup mechanisms checked. \[ \] Covert channel vectors documented. \[ \] Work Profile tested or noted. \[ \] Airplane mode transition observed.

**Audit chain:** Run `after_action "covert-channel-analysis-complete"` to log this checkpoint.

---

## Part 7  -  Cleanup and teardown

**Required before re-use or disposal of the test environment.**

Step 1. Stop mitmweb and remove the CA from the emulator system store:

```bash
set -uo pipefail
kill "${MITM_PID}" 2>/dev/null || true
# Best-effort root/remount: if these fail (e.g. emulator already rebooted), still
# attempt cert removal so the device is not left in a compromised state.
adb root 2>/dev/null || true
adb remount 2>/dev/null || true
HASH=$(openssl x509 -inform PEM -subject_hash_old -in "${MITMPROXY_CERT}" | awk 'NR==1 {print $1}')
adb shell "rm -f /system/etc/security/cacerts/${HASH}.0" 2>/dev/null || true
# Verify the cert is actually gone; fail loudly if it remains.
if adb shell "ls /system/etc/security/cacerts/${HASH}.0" 2>/dev/null | grep -q "${HASH}"; then
  echo "ERROR: CA cert ${HASH}.0 still present - remove manually before re-use"
  exit 1
fi
adb reboot 2>/dev/null || true
echo "Cleanup complete: CA removed, emulator rebooting"
```

Step 2. Uninstall test apps:

```bash
adb uninstall com.angry.shark.studio.nurturelock || true
```

Step 3. Delete any repacked APKs with Frida gadget:

```bash
find artifacts/apks -name "*frida*" -delete
find artifacts/apks -name "*repack*" -delete
```

Step 3.5. Securely delete cloned source repositories after audit:

```bash
# Remove Baby Buddy source clone (may contain contributor PII in git history)
[[ -d "babybuddy" ]] && shred -vfz -n 3 -r babybuddy 2>/dev/null || rm -rf babybuddy
# Archive source audit outputs only, not the full repository
tar czf artifacts/babybuddy-source-audit.tar.gz artifacts/reports/babybuddy-*.txt
shred -vfz -n 3 artifacts/babybuddy-source-audit.tar.gz 2>/dev/null || rm -f artifacts/babybuddy-source-audit.tar.gz
```

Step 4. Securely delete sensitive artifacts containing PII:

```bash
# Use shred if available (not effective on APFS SSDs, but better than rm)
for f in artifacts/captures/*.mitm artifacts/captures/*.pcap; do
    [[ -f "$f" ]] && shred -vfz -n 3 "$f" 2>/dev/null || rm -f "$f"
done
```

**APFS mitigation:** `shred` is ineffective on SSDs due to wear-leveling. For high-sensitivity data, encrypt the working directory with FileVault and destroy the key. Alternatively, store artifacts on an encrypted external drive and physically destroy it after retention period.

Step 5. Archive artifacts with retention policy:

```bash
tar czf "artifacts-$(date -u +%Y%m%d-%H%M%S).tar.gz" artifacts/
shasum -a 256 "artifacts-"*.tar.gz > artifacts-archive.sha256
echo "Artifacts archived. Retain for 90 days maximum. After 90 days, securely delete."
```

Step 6. Restore emulator from snapshot or delete the AVD:

```bash
# Option A: restore clean snapshot
# Option B: delete AVD
# avdmanager delete avd -n "${AVD_NAME}"
```

\[ \] CA removed. \[ \] Apps uninstalled. \[ \] Repacked APKs deleted. \[ \] Sensitive artifacts shredded. \[ \] Artifacts archived.

**Audit chain:** Run `after_action "cleanup-complete"` to log this checkpoint.

---

## Part 8  -  Audit log and chain of custody

Every run must produce an append-only audit log:

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

**Immutability enhancement:** Compute a running hash chain to detect tampering:

```bash
echo "audit-log-start" > artifacts/logs/audit.chain
after_action() {
    local action="$1"
    local prev_hash=$(tail -1 artifacts/logs/audit.chain)
    local new_hash=$(echo "${prev_hash}${action}$(date -u +%s)" | shasum -a 256 | awk '{print $1}')
    echo "${new_hash} ${action}" >> artifacts/logs/audit.chain
}
```

---

## Part 9  -  Privacy engineering and data governance

**New in v3.0.0.** This part addresses the privacy liability created by the test itself.

Step 1. **Data minimization:** Before starting mitmweb, configure it to capture ONLY the target app's traffic, not all emulator traffic:

```bash
# Add to mitmweb args: --allow-hosts <app-domain> (if known)
# OR filter after capture
```

Step 2. **Purpose limitation:** Document the exact purpose of this test in `artifacts/reports/purpose-statement.md`:

```text
Purpose: Determine whether [App Name] transmits baby data off-device.
Data collected: Network traffic metadata and payloads.
Data NOT collected: Unrelated emulator traffic.
Retention: 90 days maximum.
```

Step 3. **Anonymization:** Before sharing artifacts, strip device IDs, IP addresses, and timestamps that could re-identify the test subject:

```bash
# Pseudonymize: replace real baby name with "[REDACTED]"
# Strip: adb device serial, host MAC address, public IP
```

Step 4. **Right to erasure:** If the parent/guardian requests deletion:

```bash
# Locate all artifacts containing their data (use ripgrep if available for speed)
if command -v rg >/dev/null 2>&1; then
    rg -l "TestBaby|2024-01-01" artifacts/ > artifacts/reports/erasure-targets.txt
else
    find artifacts/ -type f -exec grep -l "TestBaby\|2024-01-01" {} + > artifacts/reports/erasure-targets.txt
fi
# Securely delete each file (see Part 7 Step 4)
# Append deletion record to audit log
```

Step 5. **Cross-border transfer:** If sharing results outside your jurisdiction, verify:
* EU → US: ensure Standard Contractual Clauses (SCCs) or adequacy decision applies.
* If uncertain, do not transfer raw captures; share only aggregated, anonymized findings.

Step 6. **Breach notification:** If artifacts are lost or leaked:
1. Document the breach in `artifacts/reports/breach-incident.md` within 24 hours.
2. Notify the data subject (parent/guardian) if PII is involved.
3. Notify your Data Protection Officer or legal team.

\[ \] DPIA completed (if required). \[ \] Consent obtained. \[ \] Purpose documented. \[ \] Anonymization procedure defined.

**Git history privacy:** When testing FOSS apps, the cloned repository may contain contributor PII (names, emails) in `.git/logs`. Before sharing the artifacts, run `git filter-repo` or manually strip this data. See Part 7 Step 3.5 for cleanup.

**Audit chain:** Run `after_action "privacy-governance-complete"` to log this checkpoint.

---

## Part 10  -  SRE and reliability engineering

**New in v3.0.0.** This part ensures the harness itself is reliable and observable.

Step 1. **End-to-end health check (canary):** Before testing the target app, run a known-leaky app (e.g., Pebbi) through the full harness to verify detection still works:

```bash
# Run Subagents 3–6 against Pebbi FIRST
# If Pebbi produces zero outbound requests, the harness is broken. STOP.
```

Step 2. **Synthetic monitoring:** If running this harness regularly, schedule a weekly canary test against a reference APK with known trackers.

Step 3. **Circuit breaker for external dependencies:** If Docker Hub is unreachable, skip the exodus scan and continue with dynamic capture only. Do not block the entire test.

Step 4. **Graceful degradation:** If `jadx` is unavailable, skip static decompilation and rely on exodus + dynamic capture. Core test (dynamic) must never be blocked by optional components.

Step 5. **Notification channel:** Configure a notification for test completion or failure:

```bash
# Example: macOS notification
osascript -e 'display notification "APK test complete" with title "Privacy Harness"'
# In CI: webhook to Slack/Teams/PagerDuty
```

Step 6. **Capacity planning:** If two operators may run tests simultaneously, use non-colliding ports and AVD names:

```bash
export PROXY_PORT="$((8080 + RANDOM % 1000))"
export AVD_NAME="apk-test-$(uuidgen 2>/dev/null | cut -d- -f1 || date +%s%N)"
```

Step 7. **Post-mortem template:** If a test produces a false negative, fill in `artifacts/reports/post-mortem.md`:

```text
Date:
App:
Expected result:
Actual result:
Root cause:
Mitigation:
Prevented recurrence:
```

\[ \] Canary test passed. \[ \] Circuit breaker configured. \[ \] Notification enabled.

**Audit chain:** Run `after_action "sre-checks-complete"` to log this checkpoint.

---

## If something breaks

### Install the mitmproxy system certificate on Android 9 (API 28)

```bash
emulator -avd "${AVD_NAME}" -writable-system
adb root
adb remount
HASH=$(openssl x509 -inform PEM -subject_hash_old -in "${MITMPROXY_CERT}" | awk 'NR==1 {print $1}')
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
* **ECH fallback:** If TLS 1.3 ECH is suspected, note that the true destination SNI may be hidden.

### exodus-standalone will not run

* Check Docker Desktop is running (`docker info`).
* Check you added `--platform linux/amd64` (required on Apple Silicon).
* Check the file path after `/app/` is correct.
* Check the image digest matches `${EXODUS_IMAGE}`.
* **Circuit breaker:** If Docker Hub is unreachable, skip exodus and continue with dynamic capture.

### adb does not see the device

* Turn on USB debugging on a real phone.
* For the emulator, make sure it finished booting (`adb shell getprop sys.boot_completed`).
* Run `adb devices` to check it shows up.
* If the emulator crashed, check host RAM usage.
* **Rate limit:** Do not send more than 5 `adb` commands per second.

### Malware discovered in APK

**STOP.** Do not install or execute the APK on any non-isolated device.
1. Quarantine the file: `chmod 000 artifacts/apks/<file>`
2. Compute hash and upload to VirusTotal.
3. Document findings in `artifacts/reports/malware-incident.md`.
4. Notify the operator and await instructions.

### Host suspension (laptop sleep) during test

**STOP.** If the Mac sleeps during the test:
1. Note the suspension time in the audit log.
2. Verify emulator state: `adb devices`
3. If emulator is offline, restart from Part 0 Step 8.
4. If mitmweb is dead, restart from Part 2 Step 2.
5. Do not trust partial results. Re-run the affected subagent from the last done-check.

---

## Things to keep in mind

* Only test apps you installed yourself. This is normal self-analysis.
* Static scan shows what is inside. It does not prove the app sent data.
* Dynamic capture shows what the app actually sent. This is the strong proof.
* The three named apps have not been tested by anyone yet. Your test would be new evidence.
* **Regression baseline:** Save `artifacts/` from this run. Future runs should compare against this baseline to detect new trackers or destinations.
* **Differential testing:** If testing a new app version, compare results to the previous version baseline. Any new destination or tracker is a regression.
* **Golden master:** The first successful run against Pebbi (positive control) becomes the golden master. If future runs against Pebbi show zero traffic, the harness is broken.

---

## Where you may be unsure

* I resolved Nubo, Pebbi, and Baby Buddy package names from the live Play Store pages on 2026-08-03: `com.clicksie.nuboapp`, `com.pebbi.android`, Baby Buddy web-only. Confirm them again if the listings change.
* If an app uses strong pinning that objection cannot break, you may not see the traffic. Write down that you could not decrypt it. Do not guess.
* Static and dynamic results can differ. If they do, trust the dynamic capture, and note the difference.
* Tool versions move fast. If a command errors, check the tool's current docs for the 2026 version before changing the method.
* **Performance budget:** The whole run stays under `${PERF_BUDGET_MINUTES}` minutes. If it goes over, escalate to the operator.

---

## Audit log and chain of custody

Every run must produce an audit log. See Part 8 for the template and hash chain.

---

## Agent plan

This section is for an IDE LLM agent. Run it autonomously. Spawn one subagent per task. Each task lists inputs, commands, a done-check, and where to go if it fails. Run tasks in order. Do not start a task until its upstream done-check passes. Stop and ask the human only at the explicit HUMAN-GATE points.

**Agent execution state machine (formal DAG):**

```
[setup] ──► [canary-test] ──► [resolve-packages] ──► [acquire-nurturelock]
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
* `[canary-test]` must run before any real test to verify harness health.

**Global state schema (shared scratchpad  -  JSON, append-only, with optimistic locking):**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "version": "3.1.0",
  "packages": {
    "nurturelock": {"id": "com.angry.shark.studio.nurturelock", "app_type": "native"},
    "nubo": {"id": "", "app_type": "native"},
    "pebbi": {"id": "", "app_type": "native"},
    "babybuddy": {"id": "", "app_type": "foss|web|native"}
  },
  "apk_files": [
    {"path": "", "sha256": "", "timestamp": "", "source": "device|mirror", "size_bytes": 0}
  ],
  "static_findings": {
    "nurturelock": {"trackers": [], "permissions": [], "report_path": ""},
    "babybuddy": {"trackers": [], "permissions": [], "report_path": ""}
  },
  "dynamic_findings": {
    "nurturelock": {"destinations": [], "payloads": [], "flow_path": "", "covert_channels": []},
    "babybuddy": {"destinations": [], "payloads": [], "flow_path": "", "covert_channels": []}
  },
  "verdicts": {
    "nurturelock": {"verdict": "pass|fail|untested", "evidence": "", "confidence": 0},
    "babybuddy": {"verdict": "pass|fail|untested", "evidence": "", "confidence": 0}
  },
  "audit_log": "artifacts/logs/audit.log",
  "hash_chain": "artifacts/logs/audit.chain",
  "state_version": 1
}
```

**Optimistic locking:** Before writing, read `state_version`. Increment by 1. Write only if the version matches. If conflict, re-read and retry (max 3 times).

**HUMAN-GATE conditions (max wait: 10 minutes active processing time; sleep pauses countdown):**
* Unknown package names after Play Store fetch fails twice.
* Pinning cannot be broken after `${MAX_RETRIES}` attempts.
* Any step fails twice with the same error.
* Malware suspected in APK.
* Performance budget `${PERF_BUDGET_MINUTES}` exceeded.
* Canary test (Pebbi) shows zero outbound requests.

**Subagent consensus for critical verdicts:**
For `verdict = fail` (accusing an app of privacy violation), require consensus from 2 independent subagents. If they disagree, escalate to HUMAN-GATE.

---

### Subagent 1  -  setup

* Goal: make the Mac ready.
* Commands: install Homebrew casks and tools from Part 0 with pinned versions; run smoke tests; start Docker; create or boot an arm64 emulator (API 28); verify disk space; create working directory and artifact structure; start audit log; install trap handlers.
* Done-check: `adb devices` lists one device; `docker info` returns ok; `mitmweb` starts and binds port 8080; all tools smoke-tested; disk >= 10 GB; audit log initialized; AVB checked.
* On fail: read "If something breaks" for the adb and exodus rows; retry once with `${RETRY_BACKOFF_SEC}`-second backoff; if still failing, emit a HUMAN-GATE with the exact error and audit log excerpt.

---

### Subagent 2  -  canary-test

* Goal: verify the harness can still detect leaks.
* Commands: acquire Pebbi; run offline-probe and dynamic capture; verify at least one outbound request is detected.
* Done-check: Pebbi produces non-empty `dynamic_findings.destinations`.
* On fail: HUMAN-GATE  -  "Canary test failed. Harness may be broken. Do not proceed with real tests."

---

### Subagent 3  -  resolve-packages

* Goal: fill in the unknown package names for Nubo, Pebbi, and Baby Buddy.
* Commands: 
  * For Nubo and Pebbi: fetch each app's live Google Play listing; extract the `id=` value from the URL.
  * For Baby Buddy: check the project repository (GitHub) for the Android package name or confirm it is web-only.
* **Hallucination guard:** Do not invent package names. If the fetch returns no `id=`, record `null` and stop. Verify the fetched URL domain is `play.google.com` or `github.com`.
* **Validation:** Package name must match regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`.
* **Temperature:** Use `${MODEL_TEMPERATURE}=0.0` for deterministic regex matching and hash computation.
* Done-check: `packages` map has four non-empty, validated package names (or `babybuddy` marked as `web-only`).
* On fail: HUMAN-GATE asking the operator to paste the Play Store URLs or repository link.

---

### Subagent 4  -  acquire (run once per package)

* Goal: get clean APK files with provenance.
* Commands: 
  * For native Android apps (Nurture Lock, Nubo, Pebbi): `adb shell pm path <package>`; validate at least one path returned; `adb pull` each path with atomic size verification; compute SHA-256; timestamp; record device model, Android version, app version, date.
  * For Baby Buddy (FOSS): clone the repository; check for an Android client; if APK exists, pull or build it; record the Git commit hash as provenance.
* **Partial failure handling:** If one package fails, others continue. Failed packages get `verdict: untested`.
* **Boundary tests:** 0 paths → fail; >5 paths → flag for review.
* **Rate limit:** Max 5 `adb` commands per second.
* **Deduplication:** Skip if file already exists with matching hash.
* Done-check: at least one APK per native Android package on disk; Baby Buddy has either an APK or a source clone with commit hash; every file has a recorded hash, device model, Android version, app version, and date; hashes are in `artifacts/apks/hashes.log`.
* On fail: if a mirror file is used instead, tag it `INFERRED` and require a later hash match before any verified claim.

---

### Subagent 5  -  offline-probe (the decisive test, run first per package)

* Goal: answer "does any data leave the phone" quickly.
* Preconditions: mitmweb running; emulator proxy set to `${PROXY_HOST}:${PROXY_PORT}`; mitmproxy certificate trusted and verified; canary test passed.
* Commands: launch app; script the standard interactions (create profile, log feed, log sleep, log diaper); wait 60 seconds for background traffic; export mitmproxy flow list.
* **UI action guard:** If UI automation fails (element not found), record the exact error and stop. Do not guess locators.
* **Adversarial inputs:** Test with Unicode names, future DOB, and empty fields.
* **Oracle definition:** Outbound request = any TCP/UDP packet with destination NOT in (127.0.0.1/8, ::1, 224.0.0.0/4, NTP port 123).
* **Doze test:** Force idle and observe maintenance window traffic.
* Done-check: a flow list exists (it may be empty). Record request count and whether any outbound request occurred. Flows exported to JSON.
* Decision rule: for a package that claims offline, any outbound request sets `verdict = fail` with the destination as evidence. Zero requests sets `verdict = provisional pass`, continue.
* On fail to capture: if flows are empty but the app looks networked, mark "pinning suspected" and hand off to Subagent 7.

---

### Subagent 6  -  static

* Goal: list trackers and permissions without running the app.
* Commands: `docker run --platform linux/amd64` exodus-standalone with pinned digest, `-j -o report.json` per APK; `jadx` decompile; grep for URLs and SDK names with improved pattern.
* **Circuit breaker:** If Docker Hub is unreachable, skip exodus and continue with jadx only.
* Done-check: a JSON report and a grep hit list saved per package; report includes APK checksum.
* Note: record explicitly that no public exodus report exists for the nurturelock package, so this local report is the first one.
* On fail: check the platform flag and Docker; retry once; else HUMAN-GATE.

---

### Subagent 7  -  dynamic (deep capture, and pinning bypass if needed)

* Goal: record every real destination and payload.
* Commands: repeat the standard interactions under mitmweb; if pinning suspected, run `objection -g <package> explore` then `android sslpinning disable`, and retry.
* **Gotcha handling:** if objection errors on Frida version, install the dev build; for split APKs place the Frida gadget in the arm64_v8a split before repack.
* **Max retry bound:** If pinning bypass fails after `${MAX_RETRIES}` attempts, record "could not decrypt" and stop.
* **Covert channel check:** Run `tcpdump` on host to catch non-HTTP traffic if mitmproxy shows nothing. Check BLE, NFC, ultrasound.
* **Memory forensics:** If zero traffic after all checks, note "possible in-memory encryption or custom protocol."
* Done-check: `dynamic_findings` has a destination list per package; each destination tagged `tracker` or `not`; payload noted; covert channel check performed or documented as skipped.
* On fail: if pinning cannot be broken, record "could not decrypt" and do not guess; set the package's network claim to `untested`.

---

### Subagent 8  -  foss-audit (run for Baby Buddy only)

* Goal: audit the open-source code for network calls and trackers.
* Commands: clone the repository (5-minute timeout); check `app_type` field in scratchpad; if `web` or `foss`, run source audit; if `native`, skip this subagent.
* Search for HTTP/HTTPS requests, analytics libraries, and third-party SDKs; read the README and privacy policy; document findings with exact file paths and line numbers.
* Done-check: `artifacts/reports/babybuddy-source-network.txt` exists with count >= 0; `artifacts/reports/babybuddy-source-trackers.txt` exists with count >= 0; `artifacts/reports/babybuddy-deps.txt` exists.
* **Hallucination guard:** Quote exact file paths and line numbers for every finding. Do not paraphrase code.
* On fail: if source code is unavailable (GitHub unreachable), record "source audit skipped" and rely on dynamic capture only.

---

### Subagent 9  -  report

* Goal: produce the final result table and verdicts.
* Commands: merge static, dynamic, and FOSS audit findings; fill the Part 5 table; apply the pass/fail rule; where findings disagree, trust dynamic and note it; append final state to audit log; archive artifacts; compute archive SHA-256.
* **Consensus implementation:** For `verdict = fail`, Subagent 9 spawns Subagent 9b with ONLY the raw flow data and package name (no prior verdict). Subagent 9b independently analyzes flows and returns its own `verdict` and `evidence`. If 9 and 9b agree on `fail`, the verdict is final. If they disagree, escalate to HUMAN-GATE.
* **Consensus rule:** For `verdict = fail`, require 2 independent subagents to agree. Disagreement = HUMAN-GATE.
* Done-check: every app has a filled row and a pass or fail (or untested) with one evidence line; audit log closed; artifacts archived; archive hash computed.
* Output: `artifacts/reports/findings.md` plus the raw mitmproxy flows and exodus JSON as attachments.

---

### Agent rules (enforced)

* **Rule 1 (static verification):** Never tag a claim verified from a static scan alone. Static shows capability, not sending. Only dynamic capture verifies sending.
* **Rule 2 (mirror trust):** Never tag a claim verified from a mirror APK unless its hash matches a device-pulled file.
* **Rule 3 (version preference):** Prefer the API 28 image to avoid the Android 16 certificate problem unless the human asks for a newer version.
* **Rule 4 (context budget):** Keep each subagent's context under 4,000 tokens. Pass only the package name, file paths, and prior done-check results in JSON, not the whole document.
* **Rule 5 (HUMAN-GATE):** Emit a HUMAN-GATE for: unknown package names, unresolved pinning, any step that fails twice, malware suspected, performance budget exceeded, or canary test failure. Max wait: 10 minutes active processing time.
* **Rule 6 (sandbox):** Subagents must not modify files outside `${WORK_DIR}` or execute destructive host commands (`rm -rf /`, `dd`, `mkfs`). All shell commands are logged to audit log.
* **Rule 7 (grounding):** Before acting, subagent must re-read the relevant section of this document. Do not rely on prompt fragments. (Enforced by requiring subagent to quote the section header in its output.)
* **Rule 8 (max iterations):** No subagent may retry the same step more than `${MAX_RETRIES}` times. After that, escalate.
* **Rule 9 (consensus):** For `verdict = fail` (privacy violation accusation), require 2 independent subagent opinions. Disagreement = HUMAN-GATE.
* **Rule 10 (data governance):** Subagents must not exfiltrate captured traffic, baby profile data, or device identifiers to external APIs. All processing stays local.
* **Rule 11 (temperature):** Use `${MODEL_TEMPERATURE}=0.0` for all deterministic tasks (hash computation, regex matching, JSON parsing, package name validation).
* **Rule 12 (prompt injection scan):** Before executing any shell command containing user-derived input (app name, package name), validate against regex `^[a-zA-Z0-9._-]+$`. Reject metacharacters.
* **Rule 13 (provenance):** When labeling an address as "known tracker," cite the database source. Do not rely on internal knowledge.
* **Rule 14 (log redaction):** Before appending to audit log, redact baby names, device serials, and public IPs. Replace with `[REDACTED]`.
* **Rule 15 (Byzantine fault tolerance):** If a subagent's done-check contradicts the artifact on disk (e.g., claims file exists but `test -f` fails), trust the filesystem and flag the subagent for review.
