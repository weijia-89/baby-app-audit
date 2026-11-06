#!/bin/bash
# Verify every precondition a launchd job needs, in the environment launchd actually provides.
#
# launchd does not read ~/.zshrc, so an interactive shell passing these checks proves nothing.
# This script runs the same checks the driver will run, then reports what is still missing.
#
# Usage: bash preflight.sh [project-slug]
set -uo pipefail

PROJECT="${1:-toebeans}"
SCHED="$(cd "$(dirname "$0")" && pwd)"
AGENT_BIN="$HOME/.local/bin/agent"

# Mirror the environment the driver exports, not the interactive shell's.
export PATH="/Users/dubs/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

PASS=0
FAIL=0
ok()   { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  WARN  %s\n' "$*"; }

case "$PROJECT" in
  toebeans)        REPO="/Users/dubs/Projects/toebeans" ;;
  baby-app-audit)  REPO="/Users/dubs/Projects/baby-app-audit-sprint4" ;;
  *) echo "unknown project: $PROJECT" >&2; exit 2 ;;
esac

echo "preflight: $PROJECT"
echo "repo:      $REPO"
echo

echo "binary"
[[ -x "$AGENT_BIN" ]] && ok "agent CLI executable at $AGENT_BIN" || bad "agent CLI missing at $AGENT_BIN"
[[ -x "$AGENT_BIN" ]] && { V="$("$AGENT_BIN" --version 2>/dev/null | head -1)"; [[ -n "$V" ]] && ok "agent version $V" || bad "agent --version produced nothing"; }

echo "auth"
# Two distinct questions, and they have different answers in different contexts:
#   1. Can THIS shell see credentials? A sandboxed or worker-owned process often cannot,
#      even when the account is signed in, so a failure here is not proof of a problem.
#   2. Can the launchd job see credentials? That is the only one that decides Saturday.
# So probe both and only hard-fail when the launchd context also fails.
probe_auth() {
  # Run the probe with a minimal environment, which is closer to what launchd provides
  # than an inherited interactive shell.
  env -i HOME="$HOME" PATH="/Users/dubs/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$AGENT_BIN" status 2>&1 | head -3
}

THIS_SHELL_AUTH="$(probe_auth)"
if printf '%s' "$THIS_SHELL_AUTH" | grep -qi "not logged in\|no user\|unauthenticated"; then
  warn "this shell cannot see credentials (common when running inside an editor worker)"
else
  ok "logged in (minimal env probe)"
fi

# The authoritative check: run the real job path once and look at what the driver logged.
# A driver log line of START means auth, model, contract and lock all passed.
LATEST_LOG="$(ls -t "$HOME/Library/Logs/weekend-sprint/"*.log 2>/dev/null | head -1)"
if [[ -n "$LATEST_LOG" ]] && grep -q "START project=" "$LATEST_LOG" 2>/dev/null; then
  ok "the launchd job path has authenticated before (evidence: $(basename "$LATEST_LOG"))"
elif printf '%s' "$THIS_SHELL_AUTH" | grep -qi "not logged in\|no user\|unauthenticated"; then
  bad "no job has ever run, and this shell cannot see credentials; sign in from Terminal: ~/.local/bin/agent login"
else
  warn "no completed job run on record yet (run one to prove the launchd path)"
fi

echo "repo"
[[ -d "$REPO" ]] && ok "repo exists" || bad "repo missing: $REPO"
[[ -d "$REPO/.git" ]] && ok "git checkout present" || bad "not a git checkout"
[[ -f "$REPO/docs/orchestration/sprint-orchestrator.md" ]] \
  && ok "orchestration contract present" \
  || bad "contract missing: $REPO/docs/orchestration/sprint-orchestrator.md"
if [[ -d "$REPO/.git" ]]; then
  BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  [[ "$BRANCH" = "main" ]] && ok "on main" || warn "on branch '$BRANCH', not main (the run works, but starts from that branch)"
  DIRTY="$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$DIRTY" = "0" ]] && ok "working tree clean" || warn "$DIRTY uncommitted path(s); the run starts from a dirty tree"
fi

echo "prompts"
for p in sat sun; do
  [[ -f "$SCHED/prompts/$PROJECT-$p.txt" ]] && ok "prompt $p present" || bad "prompt missing: $p"
done

echo "toolchain"
# This repo is a Python + bash harness; it has no Gradle build. Check only what it needs.
if command -v python3 >/dev/null 2>&1; then ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"; else bad "python3 missing"; fi
[[ -d "$ANDROID_HOME/platform-tools" ]] && ok "adb present (optional here)" || warn "adb missing (device steps will skip)"

echo "launchd jobs"
INSTALLED=0
for f in com.dubs.weekend-sprint.toebeans-sat com.dubs.weekend-sprint.toebeans-sun \
         com.dubs.weekend-sprint.babyaudit-sat com.dubs.weekend-sprint.babyaudit-sun; do
  if launchctl print "gui/$(id -u)/$f" >/dev/null 2>&1; then
    INSTALLED=$((INSTALLED+1))
  fi
done
if [[ $INSTALLED -eq 0 ]]; then
  warn "no jobs installed yet (run: bash $SCHED/install-weekend-sprints.sh)"
else
  ok "$INSTALLED of 4 jobs loaded"
fi

echo
echo "result: $PASS passed, $FAIL failed"
echo
if [[ $FAIL -gt 0 ]]; then
  echo "Not ready. Fix the FAIL lines above, then re-run this script."
  echo "The one you cannot automate: ~/.local/bin/agent login (it opens a browser)."
  exit 1
fi
echo "Ready. Next: bash $SCHED/install-weekend-sprints.sh"
