#!/bin/bash
# Install (or remove) the four weekend sprint launchd jobs.
#
# Usage:
#   bash install-weekend-sprints.sh            # install all four
#   bash install-weekend-sprints.sh --dry-run  # print what would be installed
#   bash install-weekend-sprints.sh --remove   # unload and delete
#
# Schedule: Saturday 07:00 and Sunday 07:00 local time, per project.
#
# IMPORTANT: the plists point at the scheduler directory this script lives in, not at a copy.
# Running this from the repo checkout makes launchd execute the committed, reviewed code. Running
# it from a stale copy elsewhere makes launchd execute that copy. The script prints the resolved
# path and refuses to install from a directory that is not inside a git checkout unless --force.
set -uo pipefail

SCHED="$(cd "$(dirname "$0")" && pwd)"
AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/weekend-sprint"
MODE=""
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|--remove) MODE="$arg" ;;
    --force) FORCE=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$AGENTS" "$LOG_DIR"

# Guard against installing from an unversioned copy: it drifts from the reviewed code silently.
if [[ "$FORCE" -ne 1 ]] && ! git -C "$SCHED" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cat >&2 <<MSG
refusing to install: $SCHED is not inside a git checkout.

The reviewed scheduler lives in each repo at scripts/scheduler/. Installing from an
unversioned copy means launchd runs code that no one reviews, and drifts without a diff.

Install from a checkout instead:
  bash /Users/dubs/Projects/toebeans/scripts/scheduler/install-weekend-sprints.sh
  bash /Users/dubs/Projects/baby-app-audit-sprint4/scripts/scheduler/install-weekend-sprints.sh

Or pass --force if you genuinely want this directory.
MSG
  exit 1
fi

echo "installing from: $SCHED"
if git -C "$SCHED" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git HEAD:        $(git -C "$SCHED" rev-parse --short HEAD 2>/dev/null) ($(git -C "$SCHED" rev-parse --abbrev-ref HEAD 2>/dev/null))"
fi

# label | project | phase | weekday (6=Sat, 0=Sun)
#
# Each repo's copy of this kit installs ONLY its own project's jobs. The kit exists in both
# repos, so a shared job table would make the last install win for every job: running the
# toebeans installer would repoint baby-app-audit's plists at the toebeans copy, and the two
# repos would load each other's prompts. The project is derived from the directory the script
# lives in, which is the only fact that distinguishes the two copies.
case "$SCHED" in
  */toebeans/scripts/scheduler) OWN_PROJECT="toebeans" ;;
  */baby-app-audit-sprint4/scripts/scheduler) OWN_PROJECT="baby-app-audit" ;;
  *)
    echo "cannot tell which project this kit belongs to (path: $SCHED)" >&2
    echo "expected .../toebeans/scripts/scheduler or .../baby-app-audit-sprint4/scripts/scheduler" >&2
    exit 2
    ;;
esac

JOBS=()
case "$OWN_PROJECT" in
  toebeans)
    JOBS=(
      "com.dubs.weekend-sprint.toebeans-sat|toebeans|sat|6"
      "com.dubs.weekend-sprint.toebeans-sun|toebeans|sun|0"
    )
    ;;
  baby-app-audit)
    JOBS=(
      "com.dubs.weekend-sprint.babyaudit-sat|baby-app-audit|sat|6"
      "com.dubs.weekend-sprint.babyaudit-sun|baby-app-audit|sun|0"
    )
    ;;
esac

echo "own project:     $OWN_PROJECT (installing ${#JOBS[@]} jobs)"

install_one() {
  local label="$1" project="$2" phase="$3" dow="$4"
  local plist="$AGENTS/$label.plist"

  cat >"$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCHED/sprint-run.sh</string>
    <string>$project</string>
    <string>$phase</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>$dow</integer>
    <key>Hour</key>
    <integer>7</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>AbandonProcessGroup</key>
  <false/>
  <key>LowPriorityIO</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/launchd-$project-$phase.out.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/launchd-$project-$phase.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/Users/dubs/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
PLIST

  # launchd will not run a job whose plist fails to parse.
  if ! plutil -lint "$plist" >/dev/null 2>&1; then
    echo "INVALID plist: $plist" >&2
    return 1
  fi

  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null; then
    echo "installed $label ($project $phase, weekday $dow 07:00)"
  else
    echo "bootstrap failed for $label (plist written to $plist)" >&2
    return 1
  fi
}

remove_one() {
  local label="$1"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm -f "$AGENTS/$label.plist"
  echo "removed $label"
}

case "$MODE" in
  --dry-run)
    for j in "${JOBS[@]}"; do
      IFS='|' read -r label project phase dow <<<"$j"
      echo "would install $label -> sprint-run.sh $project $phase (weekday $dow 07:00)"
    done
    ;;
  --remove)
    for j in "${JOBS[@]}"; do
      IFS='|' read -r label _ _ _ <<<"$j"
      remove_one "$label"
    done
    ;;
  install|"")
    RC=0
    for j in "${JOBS[@]}"; do
      IFS='|' read -r label project phase dow <<<"$j"
      install_one "$label" "$project" "$phase" "$dow" || RC=1
    done
    echo
    echo "Logs: $LOG_DIR"
    echo "Verify: launchctl print gui/$(id -u)/com.dubs.weekend-sprint.toebeans-sat | head -20"
    exit $RC
    ;;
  *)
    echo "usage: $0 [--dry-run|--remove]" >&2
    exit 2
    ;;
esac
