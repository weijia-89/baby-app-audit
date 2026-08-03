# APK Privacy Test Harness — Baby Tracking Apps (macOS + Agent-Ready)

META: Reproducible test steps · plain STE-style English · one action per line · runs locally on macOS Apple Silicon · includes a machine-readable agent plan · for an ADHD/ASD reader and for an autonomous IDE LLM

## How to read this document

* Each step is one action.
* Do the steps in order.
* Do not skip a step.
* A box like this means stop and check: \[ \]
* If a step fails, go to the section called "If something breaks".
* Humans: read Parts 0 to 5.
* IDE agents: read the section called "Agent plan" at the end. It repeats every step as structured tasks.

## What you are testing

You test three apps. You want to answer one question for each app: does data leave the phone?

The three apps:

| App | Package name | Notes |
| --- | --- | --- |
| Nurture Lock | com.angry.shark.studio.nurturelock | Test this one first. It claims "100% offline". |
| Nubo | Get the name from the Play Store page | Claims local-first. |
| Pebbi | Get the name from the Play Store page | Known to share data. Use as a check. |

## The one test that matters most

Nurture Lock says data never leaves the phone.

There is a simple way to test this.

* Point all traffic at a capture tool.
* Use the app like normal.
* Watch for any data leaving the phone.

The rule:

* If a "100% offline" app sends any data out, the claim is false.
* One outbound packet is enough to fail it.

This test is worth more than reading any privacy policy.

## Part 0 — Set up your Mac (Apple Silicon)

You do everything on the Mac. No cloud. No other computer.

Step 1. Install Homebrew if you do not have it. See brew.sh.

Step 2. Install the command-line tools:

```
brew install --cask android-platform-tools
brew install mitmproxy jadx
brew install --cask docker
pipx install objection

```

Step 3. Install the Android emulator and an ARM64 system image without full Android Studio. Use the helper tool "andro" (runs native on Apple Silicon), or install the Android command-line tools and run sdkmanager yourself.

Step 4. Pick the right system image. This choice matters a lot.

* Best for easy traffic capture: Android 9 (API 28), Google APIs image, arm64-v8a. Older Android lets you write the system certificate the simple way.
* If you must use Android 14+ (API 34+) or Android 16: the simple certificate method does NOT work. You will need the Magisk module method in "If something breaks".

Step 5. Start Docker Desktop and let it finish loading.

\[ \] Homebrew ready. \[ \] adb, mitmproxy, jadx, docker, objection installed. \[ \] Emulator with an arm64 image ready.

Gotcha to know now: exodus-standalone only ships for linux/amd64. On Apple Silicon you must run it through Rosetta emulation. The command in Part 3 already includes the flag for this.

## Part 1 — Get the APK file

Best way: pull it from a real device or your emulator. This gives clean proof of where it came from.

Step 1. Start the emulator, or plug in the phone with USB debugging on.

Step 2. Check the device is seen:

```
adb devices

```

Step 3. Install the app from Google Play on the phone or emulator.

Step 4. Find where the APK lives:

```
adb shell pm path com.angry.shark.studio.nurturelock

```

Step 5. You will see one or more file paths. Copy each one.

Step 6. Pull each file. Run this once for each path:

```
adb pull <paste-the-path-here>

```

Step 7. Some apps come in more than one file (split APKs). This is normal. Pull all of them.

Step 8. Write down proof for your records:

* Device model
* Android version
* App version number
* Today's date
* The SHA-256 hash of each APK file (run: shasum -a 256 .apk)

\[ \] APK files are on the Mac. \[ \] Proof details are written down.

Note on other sources:

* You can also get APKs from mirror sites (APKMirror, APKPure, APKCombo).
* Mirror files can be changed or fake.
* Do not trust a mirror file on its own.
* Only trust it if its hash matches a file you pulled from the device.

## Part 2 — The offline test (do this first)

This is the fast test. Do it before the deep tests.

Step 1. Start mitmproxy on the Mac:

```
mitmweb --listen-port 8080

```

The web view opens at [http://localhost:8081](http://localhost:8081).

Step 2. Point the emulator at mitmproxy. From inside the emulator, the Mac is address 10.0.2.2. Set the proxy inside Android settings to 10.0.2.2 port 8080. Do not use the emulator -http-proxy flag on new Android versions; set it inside Android instead.

Step 3. Install the mitmproxy certificate so HTTPS can be read.

* On Android 9 (API 28): start the emulator writable, then push the certificate into the system store. Full commands are in "If something breaks".
* On Android 14+ / 16: use the MoveCertificate Magisk module. See "If something breaks".

Step 4. Open the app.

Step 5. Do these actions, one at a time:

* Create a baby profile.
* Log a feed.
* Log a sleep.
* Log a diaper change.

Step 6. Watch the mitmproxy web view the whole time.

Step 7. Ask: did any request leave the phone?

The result:

* Nurture Lock: any outbound request = claim is false. Write it down.
* Nurture Lock: zero outbound requests = claim holds so far. Write it down.

\[ \] Offline test done. \[ \] Result written down.

## Part 3 — Static scan (what is inside the file)

This finds trackers and permissions without running the app.

Step 1. Run exodus-standalone on the APK. On Apple Silicon you must add the platform flag so it runs under Rosetta:

```
docker run --platform linux/amd64 -v "$PWD":/app --rm -i exodusprivacy/exodus-standalone /app/<your-file>.apk

```

To save a JSON report instead of text, add -j and -o:

```
docker run --platform linux/amd64 -v "$PWD":/app --rm -i exodusprivacy/exodus-standalone /app/<your-file>.apk -j -o /app/report.json

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

```
jadx <your-file>.apk -d jadx-out

```

Step 5. Search the decompiled files for clues:

```
grep -rEi "https?://|\\.com|firebase|analytics|crashlytics|unity|facebook|collect|track" jadx-out

```

\[ \] Static scan done. \[ \] Tracker names and permissions written down.

## Part 4 — Dynamic capture (what it does when running)

This watches real traffic while you use the app. This is the strongest proof.

Step 1. Make sure mitmweb is still running and the emulator still points at 10.0.2.2:8080.

Step 2. Open the app.

Step 3. Do the same actions as Part 2 (profile, feed, sleep, diaper).

Step 4. Look at every request in mitmproxy.

Step 5. For each request, write down:

* The destination address (where it went)
* Is that address a known tracker?
* What data was in the request body?

Step 6. If mitmproxy shows nothing but you think the app is hiding traffic, the app may use certificate pinning.

Step 7. To get past pinning, use objection to disable it at runtime:

```
objection -g com.angry.shark.studio.nurturelock explore
android sslpinning disable

```

Step 8. Try the actions again and watch mitmproxy.

Two 2026 gotchas for pinning:

* objection may need a development build to match the current Frida version. If objection errors on a version mismatch, install the dev build of objection.
* For split APKs, the Frida gadget must be placed in the arm64_v8a split before you repack. If the patched app does not start, this is usually why.

\[ \] Dynamic capture done. \[ \] Every destination written down.

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

## If something breaks

Install the mitmproxy system certificate on Android 9 (API 28):

```
emulator -avd <name> -writable-system
adb root
adb remount
HASH=$(openssl x509 -inform PEM -subject_hash_old -in \~/.mitmproxy/mitmproxy-ca-cert.pem | head -1)
cp \~/.mitmproxy/mitmproxy-ca-cert.pem $HASH.0
adb push $HASH.0 /system/etc/security/cacerts/$HASH.0
adb shell chmod 644 /system/etc/security/cacerts/$HASH.0
adb reboot

```

Certificate will not install on Android 14+ or Android 16:

* The simple writable-system method fails on these versions.
* Use the MoveCertificate Magisk module (project ys1231/MoveCertificate) to place the certificate where the new Android version reads it.
* Set the proxy inside the Android settings, not with the emulator -http-proxy flag. The flag is known to break capture on Android 16.
* Easier path: use an older image (API 28) just for testing.

App is in more than one file (split APKs):

* Pull all the files.
* Install all of them together with: adb install-multiple \*.apk
* For pinning bypass, put the Frida gadget in the arm64_v8a split before repacking.

mitmproxy shows no traffic at all:

* Check the proxy is set inside Android (10.0.2.2:8080 for the emulator).
* Check the certificate is installed and trusted.
* The app may use pinning. Go to Part 4, Step 7.

exodus-standalone will not run:

* Check Docker Desktop is running.
* Check you added --platform linux/amd64 (required on Apple Silicon).
* Check the file path after /app/ is correct.

adb does not see the device:

* Turn on USB debugging on a real phone.
* For the emulator, make sure it finished booting.
* Run adb devices to check it shows up.

## Things to keep in mind

* Only test apps you installed yourself. This is normal self-analysis.
* Static scan shows what is inside. It does not prove the app sent data.
* Dynamic capture shows what the app actually sent. This is the strong proof.
* The three named apps have not been tested by anyone yet. Your test would be new evidence.

## Where you may be unsure

* Nubo and Pebbi package names are not confirmed. Get them from the live Play Store pages first.
* If an app uses strong pinning that objection cannot break, you may not see the traffic. Write down that you could not decrypt it. Do not guess.
* Static and dynamic results can differ. If they do, trust the dynamic capture, and note the difference.
* Tool versions move fast. If a command errors, check the tool's current docs for the 2026 version before changing the method.

## Agent plan

This section is for an IDE LLM agent. Run it autonomously. Spawn one subagent per task. Each task lists inputs, commands, a done-check, and where to go if it fails. Run tasks in order. Do not start a task until its upstream done-check passes. Stop and ask the human only at the explicit HUMAN-GATE points.

Global state to keep in a shared scratchpad:

* packages: map of app name to package name (nurturelock is known; nubo and pebbi are unknown at start)
* apk_files: list of pulled APK paths with SHA-256 hashes
* static_findings: trackers and permissions per app
* dynamic_findings: destinations and payloads per app
* verdicts: pass or fail per app with the evidence line

Subagent 1 — setup

* Goal: make the Mac ready.
* Commands: install Homebrew casks and tools from Part 0; start Docker; create or boot an arm64 emulator, prefer API 28 Google APIs image.
* Done-check: adb devices lists one device; docker info returns ok; mitmweb starts and binds port 8080.
* On fail: read "If something breaks" for the adb and exodus rows; retry once; if still failing, emit a HUMAN-GATE with the exact error.

Subagent 2 — resolve-packages

* Goal: fill in the unknown package names for Nubo and Pebbi.
* Commands: fetch each app's live Google Play listing; extract the id= value from the URL.
* Done-check: packages map has three non-empty package names.
* On fail: HUMAN-GATE asking the operator to paste the two Play Store URLs.

Subagent 3 — acquire (run once per package)

* Goal: get clean APK files with provenance.
* Commands: adb shell pm path ; adb pull each path; shasum -a 256 each file.
* Done-check: at least one APK per package on disk; every file has a recorded hash, device model, Android version, app version, and date.
* On fail: if a mirror file is used instead, tag it inferred and require a later hash match before any verified claim.

Subagent 4 — offline-probe (the decisive test, run first per package)

* Goal: answer "does any data leave the phone" quickly.
* Preconditions: mitmweb running; emulator proxy set to 10.0.2.2:8080; mitmproxy certificate trusted.
* Commands: launch app; script the standard interactions (create profile, log feed, log sleep, log diaper); capture the mitmproxy flow list.
* Done-check: a flow list exists (it may be empty). Record request count and whether any outbound request occurred.
* Decision rule: for a package that claims offline, any outbound request sets verdict = fail with the destination as evidence. Zero requests sets verdict = provisional pass, continue.
* On fail to capture: if flows are empty but the app looks networked, mark "pinning suspected" and hand off to Subagent 6.

Subagent 5 — static

* Goal: list trackers and permissions without running the app.
* Commands: docker run --platform linux/amd64 exodus-standalone with -j -o report.json per APK; jadx decompile; grep for URLs and SDK names.
* Done-check: a JSON report and a grep hit list saved per package.
* Note: record explicitly that no public exodus report exists for the nurturelock package, so this local report is the first one.
* On fail: check the platform flag and Docker; retry once; else HUMAN-GATE.

Subagent 6 — dynamic (deep capture, and pinning bypass if needed)

* Goal: record every real destination and payload.
* Commands: repeat the standard interactions under mitmweb; if pinning suspected, run objection -g explore then android sslpinning disable, and retry.
* Gotcha handling: if objection errors on Frida version, install the objection dev build; for split APKs place the Frida gadget in the arm64_v8a split before repack.
* Done-check: dynamic_findings has a destination list per package; each destination tagged tracker or not; payload noted.
* On fail: if pinning cannot be broken, record "could not decrypt" and do not guess; set the package's network claim to untested.

Subagent 7 — report

* Goal: produce the final result table and verdicts.
* Commands: merge static and dynamic findings; fill the Part 5 table; apply the pass/fail rule; where static and dynamic disagree, trust dynamic and note it.
* Done-check: every app has a filled row and a pass or fail (or untested) with one evidence line.
* Output: a short findings file plus the raw mitmproxy flows and exodus JSON as attachments.

Agent rules:

* Never tag a claim verified from a static scan alone. Static shows capability, not sending. Only dynamic capture verifies sending.
* Never tag a claim verified from a mirror APK unless its hash matches a device-pulled file.
* Prefer the API 28 image to avoid the Android 16 certificate problem unless the human asks for a newer version.
* Keep each subagent's context small: pass only the package name, file paths, and prior done-check results, not the whole document.
* Emit a HUMAN-GATE for: unknown package names, unresolved pinning, or any step that fails twice.