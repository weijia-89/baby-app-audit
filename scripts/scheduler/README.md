# Weekend sprint scheduler (launchd + Cursor CLI)

Installed in both toebeans and baby-app-audit. This copy drives baby-app-audit; the toebeans copy lives in that repo.

Runs the sprint contracts at 07:00 Saturday and Sunday, **on this Mac**, headless, billed to your
existing Cursor plan.

Everything here runs locally. No cloud agent, no remote scheduler, no cloud Terraform.

## Why local execution is the requirement

The toebeans sprint builds an Android app: `./gradlew`, `adb`, an Android SDK, and a device or
emulator. A cloud VM does not have your toolchain, your signing setup, or your emulator state. A
sprint that cannot run the build cannot verify its own work, so it must run where the build runs.

## What was removed

A Terraform configuration that created four **cloud-executed** Cursor Automations was archived to
`archive/cloud-terraform-2026-11-06/`. It was never applied: no state file was written, no cloud
resource was ever created, so there was nothing to destroy. The archive is kept only as a record of
the model settings and prompt text; it is not part of the live path.

## Files

| Path | Role |
|---|---|
| `/Users/dubs/Projects/scripts/scheduler/sprint-run.sh` | driver: preflight, lock, model check, run, notify |
| `/Users/dubs/Projects/scripts/scheduler/install-weekend-sprints.sh` | writes and bootstraps the four launchd plists |
| `/Users/dubs/Projects/scripts/scheduler/prompts/*.txt` | the four run prompts |
| `~/Library/LaunchAgents/com.dubs.weekend-sprint.*.plist` | the jobs |
| `~/Library/Logs/weekend-sprint/` | stream-json logs, launchd stdout/stderr |

## Setup (once)

1. Install the Cursor CLI (already done on this machine):

```
curl https://cursor.com/install -fsS | bash
```

2. Log in. This opens a browser; it cannot be automated:

```
~/.local/bin/agent login
```

3. Confirm auth and that your model string resolves on this account:

```
~/.local/bin/agent status
~/.local/bin/agent models | grep -i grok
```

If the exact string differs, set `SPRINT_MODEL` in the plist to what `agent models` prints.

4. Confirm both contracts exist on `main` in each repo (they are merged):

```
git -C /Users/dubs/Projects/toebeans ls-tree origin/main --name-only docs/orchestration/
git -C /Users/dubs/Projects/baby-app-audit-sprint4 ls-tree origin/main --name-only docs/orchestration/
```

5. Install the jobs:

```
bash /Users/dubs/Projects/scripts/scheduler/install-weekend-sprints.sh
```

6. Verify one job is registered:

```
launchctl print gui/$(id -u)/com.dubs.weekend-sprint.toebeans-sat | head -20
```

## Testing without waiting for Saturday

Dry run (preflight only, no request spent):

```
SPRINT_DRY_RUN=1 bash /Users/dubs/Projects/scripts/scheduler/sprint-run.sh toebeans sat
```

Force one real run now:

```
launchctl kickstart -k gui/$(id -u)/com.dubs.weekend-sprint.toebeans-sat
```

Watch it:

```
tail -f ~/Library/Logs/weekend-sprint/toebeans-sat-$(date +%F).log
```

## Models

| Layer | Setting |
|---|---|
| Orchestrator | `grok-4.7-medium` (default in the driver) |
| Workers | `deepseek-v41-flash-1017-high`, named inside each prompt |

The worker model is a prompt instruction because the CLI exposes no per-subagent model flag. If a
run cannot set it, the prompt requires the orchestrator to say so rather than silently running
everything on one model.

Override the orchestrator model without editing the script:

```
SPRINT_MODEL='grok-4.7-high' bash sprint-run.sh toebeans sat
```

## Cost control

- One run per project at a time, enforced by a lock file.
- `RunAtLoad` is false, so installing or rebooting never fires a sprint.
- Logs older than 45 days are deleted on each run.
- `SPRINT_DRY_RUN=1` spends nothing.
- Each run is a normal Cursor request stream against your plan.

## Removing

```
bash /Users/dubs/Projects/scripts/scheduler/install-weekend-sprints.sh --remove
```

## Known limits

- macOS only. A Linux equivalent would be a systemd timer with the same driver.
- No run dashboard. History is the log files.
- The machine must be awake. launchd runs a missed `StartCalendarInterval` job after wake, but a
  laptop asleep all weekend defers the run rather than skipping it.
- CLI sessions do not appear in the Cursor app; the PRs are the visible output.
- `--force` is required for unattended tool use, so the agent can write files and run shell
  commands without prompting. The contracts cap what it may do, but the guardrail is policy. Add
  `--sandbox enabled` in `sprint-run.sh` for a harder boundary.
