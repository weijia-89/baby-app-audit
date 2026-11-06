#!/bin/bash
# Install (or remove) the four weekend sprint launchd jobs.
#
# Usage:
#   bash install-weekend-sprints.sh            # install all four
#   bash install-weekend-sprints.sh --dry-run  # print what would be installed
#   bash install-weekend-sprints.sh --remove   # unload and delete
#
# Schedule: Saturday 07:00 and Sunday 07:00 local time, per project.
set -uo pipefail

SCHED="$(cd "$(dirname "$0")" && pwd)"
AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/weekend-sprint"
MODE="${1:-install}"

mkdir -p "$AGENTS" "$LOG_DIR"

# label | project | phase | weekday (6=Sat, 0=Sun)
JOBS=(
  "com.dubs.weekend-sprint.toebeans-sat|toebeans|sat|6"
  "com.dubs.weekend-sprint.toebeans-sun|toebeans|sun|0"
  "com.dubs.weekend-sprint.babyaudit-sat|baby-app-audit|sat|6"
  "com.dubs.weekend-sprint.babyaudit-sun|baby-app-audit|sun|0"
)

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
