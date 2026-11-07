#!/bin/bash
# Weekend sprint driver: runs one scheduled sprint phase headlessly through Cursor Agent.
#
# Billing: `agent` bills to the same Cursor plan as the editor. No separate API spend.
# Usage: sprint-run.sh <project-slug> <sat|sun>
# Env overrides: SPRINT_DRY_RUN=1, SPRINT_MODEL, SPRINT_WORKER_MODEL
set -uo pipefail

PROJECT="${1:?usage: sprint-run.sh <project-slug> <sat|sun>}"
PHASE="${2:?usage: sprint-run.sh <project-slug> <sat|sun>}"

# --- environment (resolved BEFORE any path is used) ------------------------
# launchd gives a minimal environment; do not assume HOME or a login shell profile is set.
# This block must run first: every log and state path below derives from HOME, so a later
# fallback would leave the early writes pointing at /Library and silently discarding them.
if [[ -z "${HOME:-}" ]] || [[ ! -d "${HOME:-}" ]]; then
  HOME="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -n "${HOME:-}" ]] || HOME="/Users/$(id -un)"
  export HOME
fi

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

mkdir -p "$LOG_DIR" "$STATE_DIR" || {
  # With no writable log directory there is nowhere to report a failure; say it on stderr so
  # launchd's StandardErrorPath captures it rather than losing the reason entirely.
  printf 'sprint-run: cannot create log or state directory under %s\n' "$HOME" >&2
  exit 1
}
# Logs can contain repo content and paths; keep them private to this user.
umask 077
touch "$LOG" 2>/dev/null || true

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"$LOG"; }

case "$PROJECT" in
  toebeans)
    REPO="$ROOT/toebeans"
    CONTRACT="$REPO/docs/orchestration/sprint-orchestrator.md"
    # Prompt resolves beside this script, so the driver always reads its own repo's copy
    # even if an older plist still points at a different checkout.
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

# A prompt must come from this kit's own directory. If a stale plist points the driver at
# another repo's kit, it would run the wrong instructions for the wrong project.
case "$SCHED" in
  */toebeans/scripts/scheduler) EXPECTED_KIT="toebeans" ;;
  */baby-app-audit-sprint4/scripts/scheduler) EXPECTED_KIT="baby-app-audit" ;;
  *) EXPECTED_KIT="" ;;
esac
if [[ -n "$EXPECTED_KIT" ]] && [[ "$EXPECTED_KIT" != "$PROJECT" ]]; then
  fail "driver kit is for '$EXPECTED_KIT' but was asked to run '$PROJECT' (stale plist? reinstall from the matching repo)"
fi

# --- preflight -------------------------------------------------------------
[[ -x "$AGENT_BIN" ]] || fail "agent CLI missing at $AGENT_BIN (install: curl https://cursor.com/install -fsS | bash)"
[[ -d "$REPO" ]] || fail "repo missing: $REPO"
[[ -f "$CONTRACT" ]] || fail "contract missing: $CONTRACT (merge the sprint-orchestrator PR first)"
[[ -f "$PROMPT" ]] || fail "prompt missing: $PROMPT"

# Auth: probe, but never block on the probe. Note the probe reads environment-dependent state:
# a sandboxed or worker-owned process reports "not logged in" while the account is fine, and the
# real run then succeeds. The authoritative signal is the `agent --print` call itself, whose
# failure text is caught after the run.
if "$AGENT_BIN" status 2>&1 | grep -qi "not logged in\|no user\|unauthenticated"; then
  log "NOTE auth probe says not logged in here; proceeding (the probe reflects this process's view, not the launchd job's)"
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

# --- toolchain -------------------------------------------------------------
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# Toolchain paths differ per project: toebeans is Gradle + Android, baby-app-audit is a Python
# harness. Exporting a JDK for a repo with no Gradle build is harmless but misleading, so the
# dependency is declared per project instead of globally.
case "$PROJECT" in
  toebeans)
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
    ;;
  baby-app-audit)
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
    ;;
esac

PROMPT_TEXT="$(cat "$PROMPT")"

log "START project=$PROJECT phase=$PHASE model=$MODEL head=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "CONTRACT=$CONTRACT"
log "PROMPT=$PROMPT"

# Byte offset of this run's start, so post-run log scanning cannot be polluted by earlier runs.
RUN_START_BYTES="$(wc -c <"$LOG" 2>/dev/null | tr -d ' ')"
[[ -n "$RUN_START_BYTES" ]] || RUN_START_BYTES=0
log "RUN_START_BYTES=$RUN_START_BYTES"

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

# Bound the run. Without a ceiling, a stalled agent holds the lock indefinitely and silently
# blocks the next scheduled slot, which is worse than a failed run because nothing reports it.
# SPRINT_TIMEOUT_SECONDS defaults to 2 hours: long enough for a multi-wave sprint, short enough
# that a hang is reported the same day.
TIMEOUT_SECONDS="${SPRINT_TIMEOUT_SECONDS:-7200}"

# Extract the session id from this run's slice of the log, so a stalled run can be resumed
# rather than restarted from scratch (which would duplicate any PRs it already opened).
run_session_id() {
  tail -c +$((RUN_START_BYTES + 1)) "$LOG" 2>/dev/null \
    | grep -o '"session_id":"[^"]*"' \
    | head -1 \
    | sed 's/.*:"//; s/"$//'
}

# Did this run's slice end in a transient transport failure? The CLI prints these as plain
# text, not as a stream-json error record, so the stream-error check alone misses them.
run_had_transient_failure() {
  tail -c +$((RUN_START_BYTES + 1)) "$LOG" 2>/dev/null \
    | grep -qiE 'RetriableError|Connection stalled|ECONNRESET|socket hang up|network error'
}

run_once() {
  # $1 empty = fresh run; otherwise the chat id to resume.
  local resume_id="${1:-}"
  local -a args=(--print --output-format stream-json --model "$MODEL" --force --trust
                 --workspace "$REPO")
  if [[ -n "$resume_id" ]]; then
    args+=(--resume "$resume_id")
    log "RESUME session=$resume_id"
  else
    args+=("$PROMPT_TEXT")
  fi

  "$AGENT_BIN" "${args[@]}" >>"$LOG" 2>&1 &
  local agent_pid=$!
  local waited=0
  while kill -0 "$agent_pid" 2>/dev/null; do
    if (( waited >= TIMEOUT_SECONDS )); then
      log "FAIL timed out after ${TIMEOUT_SECONDS}s; terminating agent pid $agent_pid"
      kill -TERM "$agent_pid" 2>/dev/null
      sleep 10
      kill -KILL "$agent_pid" 2>/dev/null
      wait "$agent_pid" 2>/dev/null
      return 124
    fi
    sleep 5
    waited=$((waited + 5))
  done
  wait "$agent_pid"
}

# One retry, and only for a transient transport failure: those resume cleanly. A logic or tool
# failure is not retried, because repeating it produces the same result and doubles the cost.
run_with_deadline() {
  run_once ""
  local rc=$?
  if [[ $rc -ne 0 ]] && run_had_transient_failure; then
    local sid
    sid="$(run_session_id)"
    if [[ -n "$sid" ]] && (( TRANSIENT_RETRIES > 0 )); then
      log "WARN transient transport failure detected; resuming session once after 30s"
      sleep 30
      run_once "$sid"
      return $?
    fi
    log "WARN transient failure but no session id recoverable; not retrying"
  fi
  return $rc
}
TRANSIENT_RETRIES="${SPRINT_TRANSIENT_RETRIES:-1}"

run_with_deadline
RC=$?

if [[ $RC -eq 124 ]] || [[ $RC -eq 137 ]]; then
  log "FAIL timed out after ${TIMEOUT_SECONDS}s (rc=$RC); the lock will be released"
fi

# stream-json can report a clean exit while the run itself failed (auth failure, tool error,
# contract contradiction). Treat an explicit failure record in the log as a failure too, so a
# broken run is never announced as clean. Scope the scan to this run: the log is append-only and
# shared across runs of the same day, so an old error record must not condemn a good run.
RUN_START_BYTES="${RUN_START_BYTES:-0}"
if [[ $RC -eq 0 ]] && tail -c +$((RUN_START_BYTES + 1)) "$LOG" 2>/dev/null | grep -qiE '"type":"error"|Authentication required'; then
  RC=1
  log "WARN rc was 0 but this run's stream contains an error record; treating as failure"
fi

if [[ $RC -eq 0 ]]; then
  log "OK rc=0 head=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  /usr/bin/osascript -e "display notification \"$PROJECT $PHASE finished clean\" with title \"Weekend sprint\"" 2>/dev/null || true
else
  # A failed run may still have done real work: this exact case produced a merged-quality PR
  # before the connection dropped. Say so instead of implying nothing happened.
  POSSIBLE_WORK=""
  if git -C "$REPO" for-each-ref --count=1 --sort=-committerdate \
       --format='%(refname:short) %(committerdate:relative)' 'refs/heads/sprint-*' 2>/dev/null | grep -q .; then
    POSSIBLE_WORK=" (a branch may hold partial work; check PRs before re-running)"
  fi
  log "FAIL rc=$RC$POSSIBLE_WORK"
  /usr/bin/osascript -e "display notification \"$PROJECT $PHASE failed rc=$RC$POSSIBLE_WORK - see $LOG\" with title \"Weekend sprint failed\"" 2>/dev/null || true
fi

exit $RC
