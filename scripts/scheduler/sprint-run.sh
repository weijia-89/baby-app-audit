#!/bin/bash
# Weekend sprint driver: runs one scheduled sprint phase headlessly through Cursor Agent.
#
# Billing: `agent` bills to the same Cursor plan as the editor. No separate API spend.
# Usage: sprint-run.sh <project-slug> <sat|sun>
# Env overrides: SPRINT_DRY_RUN=1, SPRINT_MODEL, SPRINT_WORKER_MODEL
set -uo pipefail

PROJECT="${1:?usage: sprint-run.sh <project-slug> <sat|sun>}"
PHASE="${2:?usage: sprint-run.sh <project-slug> <sat|sun>}"

ROOT="/Users/dubs/Projects"
SCHED="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/Library/Logs/weekend-sprint"
STATE_DIR="$HOME/Library/Application Support/weekend-sprint"
AGENT_BIN="$HOME/.local/bin/agent"
STAMP="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/$PROJECT-$PHASE-$STAMP.log"

# Orchestrator model: Grok 4.7 Medium, the non-fast variant.
# Slug confirmed from `agent models` on this account (2026-11-06): effort and the fast flag are
# encoded in the slug itself (grok-4.7-medium, grok-4.7-medium-fast), so no bracket override is used.
MODEL="${SPRINT_MODEL:-grok-4.7-medium}"

mkdir -p "$LOG_DIR" "$STATE_DIR"
# Logs can contain repo content and paths; keep them private to this user.
umask 077
touch "$LOG" 2>/dev/null || true

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"$LOG"; }

case "$PROJECT" in
  toebeans)
    REPO="$ROOT/toebeans"
    CONTRACT="$REPO/docs/orchestration/sprint-orchestrator.md"
    PROMPT="$SCHED/prompts/toebeans-$PHASE.txt"
    ;;
  baby-app-audit)
    REPO="$ROOT/baby-app-audit-sprint4"
    CONTRACT="$REPO/docs/orchestration/sprint-orchestrator.md"
    PROMPT="$SCHED/prompts/baby-app-audit-$PHASE.txt"
    ;;
  *)
    echo "unknown project: $PROJECT" >&2
    exit 2
    ;;
esac

fail() {
  log "FAIL $*"
  /usr/bin/osascript -e "display notification \"$*\" with title \"Weekend sprint blocked\"" 2>/dev/null || true
  exit 1
}

# Model list can be large and slow; fetch it once, cached per day. If the fetch fails we
# record that and let the run proceed rather than failing closed on a transient error.
# The temp file is process-unique: two projects can run concurrently and must not collide.
model_available() {
  local needle="$1" cache="$STATE_DIR/models.txt" tmp="$STATE_DIR/models.$$.tmp"
  if [[ ! -s "$cache" ]] || [[ -n "$(find "$cache" -mtime +1 2>/dev/null)" ]]; then
    if ! "$AGENT_BIN" models >"$tmp" 2>/dev/null; then
      rm -f "$tmp"
      log "WARN model list unavailable (transient?); skipping the model check"
      return 0
    fi
    mv "$tmp" "$cache"
  fi
  grep -qi -- "$needle" "$cache"
}

# --- preflight -------------------------------------------------------------
[[ -x "$AGENT_BIN" ]] || fail "agent CLI missing at $AGENT_BIN (install: curl https://cursor.com/install -fsS | bash)"
[[ -d "$REPO" ]] || fail "repo missing: $REPO"
[[ -f "$CONTRACT" ]] || fail "contract missing: $CONTRACT (merge the sprint-orchestrator PR first)"
[[ -f "$PROMPT" ]] || fail "prompt missing: $PROMPT"

# Auth: probe, but never block on the probe. It has produced false negatives (a sandboxed or
# worker-owned process reports "not logged in" while the account is fine), and a false negative
# cancels a legitimate run. The real `agent --print` call below fails loudly with a nonzero exit
# and an "Authentication required" line, which is the authoritative signal and is checked after.
if "$AGENT_BIN" status 2>&1 | grep -qi "not logged in\|no user\|unauthenticated"; then
  log "WARN auth probe says not logged in; continuing, the run itself will fail loudly if true"
fi

# Model must exist on this account before we spend a request on it.
if ! model_available "$MODEL"; then
  fail "model not available on this account: $MODEL (run: agent models)"
fi

# One run per project at a time. The lock must not survive a reboot or a hard kill, so compare
# the recorded pid AND its start time; a recycled pid from an unrelated process is not a lock.
# Acquisition uses an atomic directory create, not check-then-write, so two jobs that fire in
# the same second cannot both win.
LOCK_DIR="$STATE_DIR/$PROJECT.lock.d"
LOCK="$LOCK_DIR/owner"
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s %s\n' "$$" "$(ps -o lstart= -p $$ 2>/dev/null | tr -s ' ' '_')" >"$LOCK"
    return 0
  fi
  # Directory exists: either a live run, or debris from a crash.
  local pid start live
  read -r pid start <"$LOCK" 2>/dev/null || true
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    live="$(ps -o lstart= -p "$pid" 2>/dev/null | tr -s ' ' '_')"
    if [[ -z "${start:-}" ]] || [[ "$live" == "$start" ]]; then
      return 1
    fi
    log "WARN stale lock: pid $pid is a different process; reclaiming"
  else
    log "WARN stale lock: pid ${pid:-unknown} is gone; reclaiming"
  fi
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" 2>/dev/null || return 1
  printf '%s %s\n' "$$" "$(ps -o lstart= -p $$ 2>/dev/null | tr -s ' ' '_')" >"$LOCK"
  return 0
}
acquire_lock || fail "another $PROJECT sprint is still running"
release_lock() { rm -rf "$LOCK_DIR"; }
trap release_lock EXIT
trap 'release_lock; exit 130' INT TERM

# Keep the log dir from growing without bound.
find "$LOG_DIR" -name '*.log' -mtime +45 -delete 2>/dev/null || true

# --- environment -----------------------------------------------------------
# launchd gives a minimal environment; do not assume HOME or a login shell profile is set.
# Falling back to the passwd entry keeps log and state paths stable even under a bare launchd.
if [[ -z "${HOME:-}" ]] || [[ ! -d "${HOME:-}" ]]; then
  HOME="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -n "$HOME" ]] || HOME="/Users/$(id -un)"
  export HOME
fi
LOG_DIR="$HOME/Library/Logs/weekend-sprint"
STATE_DIR="$HOME/Library/Application Support/weekend-sprint"
LOG="$LOG_DIR/$PROJECT-$PHASE-$STAMP.log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

PROMPT_TEXT="$(cat "$PROMPT")"

log "START project=$PROJECT phase=$PHASE model=$MODEL head=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "CONTRACT=$CONTRACT"
log "PROMPT=$PROMPT"

if [[ "${SPRINT_DRY_RUN:-0}" == "1" ]]; then
  log "DRY RUN: would invoke agent --print --output-format stream-json"
  echo "dry run ok: $PROJECT $PHASE"
  exit 0
fi

# --- run -------------------------------------------------------------------
# No `cd`: --workspace names the tree, and staying put keeps this script safe to invoke
# from any working directory (launchd starts jobs in /). If the CLI ever ignores
# --workspace, the explicit guard below is what catches it.
if [[ ! -d "$REPO/.git" ]]; then
  fail "repo is not a git checkout: $REPO"
fi

"$AGENT_BIN" --print \
  --output-format stream-json \
  --model "$MODEL" \
  --force \
  --trust \
  --workspace "$REPO" \
  "$PROMPT_TEXT" >>"$LOG" 2>&1

RC=$?

# stream-json can report a clean exit while the run itself failed (auth failure, tool error,
# contract contradiction). Treat an explicit failure record in the log as a failure too, so a
# broken run is never announced as clean.
if [[ $RC -eq 0 ]] && tail -c 400000 "$LOG" 2>/dev/null | grep -qiE '"type":"error"|Authentication required'; then
  RC=1
  log "WARN rc was 0 but the stream contains an error record; treating as failure"
fi

if [[ $RC -eq 0 ]]; then
  log "OK rc=0 head=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  /usr/bin/osascript -e "display notification \"$PROJECT $PHASE finished clean\" with title \"Weekend sprint\"" 2>/dev/null || true
else
  log "FAIL rc=$RC"
  /usr/bin/osascript -e "display notification \"$PROJECT $PHASE exited rc=$RC - see $LOG\" with title \"Weekend sprint failed\"" 2>/dev/null || true
fi

exit $RC
