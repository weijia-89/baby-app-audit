# Remaining steps, exact commands

Four steps. Run them in order. Everything here is copy-paste ready.

Verified on this machine: 10 of 11 preflight checks pass. The one failure is auth, which is step 1.

---

## Step 1: log in to the Cursor CLI

This opens a browser window. It is the step I cannot do for you.

```bash
~/.local/bin/agent login
```

Complete the browser flow, then come back to the terminal.

**Verify it worked:**

```bash
~/.local/bin/agent status
```

Expected: a line naming your account, not `Not logged in`.

---

## Step 2: confirm your model string

The driver defaults to `grok-4.7-medium`, confirmed against `agent models` on 2026-11-06.
your account confirms it.

```bash
~/.local/bin/agent models | grep -i grok
```

**If a grok line appears**, note its exact spelling. If it matches `grok-4.7`, you are done with this
step. If it differs, for example `grok-4.7-high`, you need to set `SPRINT_MODEL` in step 4.

**If no grok line appears**, list everything and pick the strongest model you have:

```bash
~/.local/bin/agent models | head -40
```

---

## Step 3: point both repos at `main`

Both are currently on feature branches, so a sprint would start from the wrong base.

### 3a. toebeans

The untracked `docs/orchestration/` copy is identical to the version already merged on `main`, so it
is safe to remove. Removing it prevents the branch switch from aborting.

```bash
cd /Users/dubs/Projects/toebeans
rm -rf docs/orchestration
git checkout main
git pull --ff-only origin main
```

**If `git checkout main` still refuses**, something else is modified. Check:

```bash
git status --short
```

Resolve whatever it lists, then retry the checkout. Do not use `--force`.

### 3b. baby-app-audit

This branch has unmerged local commits (2 ahead, 2 behind). Do not delete it; just switch away.

```bash
cd /Users/dubs/Projects/baby-app-audit-sprint4
git checkout main
git pull --ff-only origin main
```

The `docs/sprint-orchestrator` branch stays on disk if you want it later.

**Verify both landed:**

```bash
git -C /Users/dubs/Projects/toebeans rev-parse --abbrev-ref HEAD
git -C /Users/dubs/Projects/baby-app-audit-sprint4 rev-parse --abbrev-ref HEAD
git -C /Users/dubs/Projects/toebeans ls docs/orchestration/
```

Expected: `main`, `main`, then `sprint-orchestrator.md`.

---

## Step 4: run preflight, then take one real test run

### 4a. Preflight

```bash
bash /Users/dubs/Projects/scripts/scheduler/preflight.sh toebeans
```

Expected: `result: 11 passed, 0 failed` and `Ready.`

If a grok model was missing or spelled differently in step 2, this is where it shows. Fix it before
continuing.

### 4b. Dry run (costs nothing)

```bash
SPRINT_DRY_RUN=1 bash /Users/dubs/Projects/scripts/scheduler/sprint-run.sh toebeans sat
```

Expected: `dry run ok: toebeans sat`

### 4c. One real run, to see actual output before trusting a Saturday

This spends Cursor plan usage. It is the only way to know the whole chain works.

```bash
launchctl kickstart -k gui/$(id -u)/com.dubs.weekend-sprint.toebeans-sat
```

Watch it:

```bash
tail -f ~/Library/Logs/weekend-sprint/toebeans-sat-$(date +%Y-%m-%d).log
```

Press Ctrl+C to stop watching; that does not stop the run.

**What success looks like:** the log grows past the `START` line, and either a PR appears on GitHub or
the log ends with `OK rc=0`.

**What failure looks like:** a line starting with `FAIL`, plus a macOS notification. The message names
the cause. Nothing is left half-done, because the driver stops before spending a request.

---

## If step 2 gave you a different model string

Set it explicitly in both the Saturday and Sunday jobs. Edit these two files:

```
~/Library/LaunchAgents/com.dubs.weekend-sprint.toebeans-sat.plist
~/Library/LaunchAgents/com.dubs.weekend-sprint.toebeans-sun.plist
```

Add `SPRINT_MODEL` under `EnvironmentVariables`, next to `PATH`:

```xml
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/Users/dubs/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>SPRINT_MODEL</key>
    <string>grok-4.7-high</string>
  </dict>
```

Replace `grok-4.7-high` with what step 2 actually printed. Then reload:

```bash
launchctl bootout gui/$(id -u)/com.dubs.weekend-sprint.toebeans-sat
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dubs.weekend-sprint.toebeans-sat.plist
```

---

## What happens after this

Nothing until Saturday 07:00. Then:

- launchd fires the job if the Mac is awake, or runs it on wake if it was asleep.
- The driver checks auth, model, contract and lock, then runs `agent --print` locally.
- Work happens in `/Users/dubs/Projects/toebeans`; PRs land on GitHub; the log goes to
  `~/Library/Logs/weekend-sprint/`.
- You get a macOS notification on success and on failure.

## Checking on it later

```bash
# are the jobs loaded
launchctl list | grep weekend-sprint

# how many times each has run
for j in toebeans-sat toebeans-sun babyaudit-sat babyaudit-sun; do
  printf '%-14s ' "$j"
  launchctl print gui/$(id -u)/com.dubs.weekend-sprint.$j 2>/dev/null | grep -E '^\s+(runs|state) =' | tr -d '\n'
  echo
done

# today's logs
ls -la ~/Library/Logs/weekend-sprint/
```

## Turning it off

```bash
bash /Users/dubs/Projects/scripts/scheduler/install-weekend-sprints.sh --remove
```

Removes all four jobs and their plists. Logs are left in place.
