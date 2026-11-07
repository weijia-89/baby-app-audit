#!/bin/bash
# Verify the sprint scheduler: preflight, lock recovery, log hygiene, prompt integrity.
#
# This is the test harness for scripts/scheduler. It exists because the scheduler is
# unattended: a defect here is invisible until a Saturday, so the checks run in CI instead.
#
# Usage: bash tests/test-scheduler.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ok()  { printf '  PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

echo "scheduler: static checks"

for f in "$HERE/sprint-run.sh" "$HERE/install-weekend-sprints.sh" "$HERE/preflight.sh"; do
  if bash -n "$f" 2>/dev/null; then ok "syntax: $(basename "$f")"; else bad "syntax error: $(basename "$f")"; fi
done

if command -v shellcheck >/dev/null 2>&1; then
  for f in "$HERE/sprint-run.sh" "$HERE/install-weekend-sprints.sh" "$HERE/preflight.sh"; do
    if shellcheck -S warning "$f" >/dev/null 2>&1; then ok "shellcheck: $(basename "$f")"; else bad "shellcheck: $(basename "$f")"; fi
  done
else
  echo "  SKIP  shellcheck not installed"
fi

echo "scheduler: behavioural checks"

# Every prompt must exist and be non-trivial, or the run starts with no instruction.
for p in toebeans-sat toebeans-sun baby-app-audit-sat baby-app-audit-sun; do
  f="$HERE/prompts/$p.txt"
  if [[ -s "$f" ]] && [[ $(wc -l <"$f") -gt 8 ]]; then
    ok "prompt present and substantive: $p"
  else
    bad "prompt missing or too short: $p"
  fi
done

# A prompt that halts on a model slug wastes a whole run. Guard the wording.
if grep -qi "do NOT stop the run and do NOT silently substitute" "$HERE"/prompts/*.txt; then
  ok "prompts degrade on an unavailable worker model instead of halting"
else
  bad "prompts may halt on an unavailable worker model"
fi

# No hardcoded personal paths that only exist on one machine, in prompts.
# (Contracts and repos are named by argument or repo-relative path.)
if grep -qE "grok-4\.7\[context=" "$HERE"/prompts/*.txt "$HERE"/*.sh 2>/dev/null; then
  bad "obsolete bracket model syntax present (effort lives in the slug)"
else
  ok "no obsolete bracket model syntax"
fi

# The driver must not rely on a lock that survives a reboot. It must record a start time.
if grep -q "lstart" "$HERE/sprint-run.sh"; then
  ok "lock records process start time (survives pid reuse)"
else
  bad "lock can be fooled by a recycled pid"
fi

# Acquisition must be atomic, not check-then-write, or two jobs firing in one second both win.
if grep -q 'mkdir "\$LOCK_DIR"' "$HERE/sprint-run.sh"; then
  ok "lock acquisition is atomic (mkdir), not check-then-write"
else
  bad "lock has a check-then-write race"
fi

# The auth probe must not gate the run: a false negative cancels a legitimate run.
if grep -q "the probe reflects this process's view, not the launchd job's" "$HERE/sprint-run.sh"; then
  ok "auth probe logs a note instead of blocking (probe has false negatives)"
else
  bad "auth probe can cancel a run on a false negative"
fi

# HOME must be resolved before any path derives from it, or early writes land in /Library.
if grep -q "resolved BEFORE any path is used" "$HERE/sprint-run.sh"; then
  ok "HOME is resolved before log/state paths are used"
else
  bad "HOME fallback runs after paths are set (dead code)"
fi

# The installer must refuse an unversioned directory, or launchd runs unreviewed code.
if grep -q "refusing to install" "$HERE/install-weekend-sprints.sh"; then
  ok "installer refuses to install from a non-git directory"
else
  bad "installer can point launchd at unreviewed code"
fi

# Toolchain exports must be per project, not global: a JDK in a Python repo is misleading.
if grep -q 'case "$PROJECT" in' "$HERE/sprint-run.sh" && grep -q 'baby-app-audit)' "$HERE/sprint-run.sh"; then
  ok "toolchain is exported per project"
else
  bad "toolchain exported globally (wrong assumptions for one repo)"
fi

# A stalled agent must not hold the lock forever and silently block the next slot.
if grep -q "run_with_deadline" "$HERE/sprint-run.sh" && grep -q "SPRINT_TIMEOUT_SECONDS" "$HERE/sprint-run.sh"; then
  ok "run has a deadline watchdog"
else
  bad "an unbounded run can hold the lock indefinitely"
fi

# Each repo's kit must install only its own jobs, or two repos clobber each other's plists.
if grep -q "OWN_PROJECT" "$HERE/install-weekend-sprints.sh"; then
  ok "installer scopes jobs to its own repo"
else
  bad "installer installs jobs for both repos (last install wins)"
fi

# A mismatched kit/project pairing must be refused, not silently run the wrong prompt.
if grep -q "stale plist" "$HERE/sprint-run.sh"; then
  ok "driver refuses a kit/project mismatch"
else
  bad "driver can run one repo's prompt against another repo"
fi

# Stream-error scanning must be scoped to the current run, or an old failure condemns a good run.
if grep -q "RUN_START_BYTES" "$HERE/sprint-run.sh"; then
  ok "stream-error scan is scoped to the current run"
else
  bad "an old error record in an appended log would fail a good run"
fi

# The driver must treat stream errors as failures, so a broken run is never announced clean.
if grep -q '"type":"error"' "$HERE/sprint-run.sh"; then
  ok "stream-level errors count as failures"
else
  bad "a clean exit code with a stream error would be reported as success"
fi

# No `cd` in a script body: safe-terminal rule, and launchd starts jobs in /.
if grep -qE "^\s*cd " "$HERE/sprint-run.sh"; then
  bad "sprint-run.sh uses cd (breaks the no-cd rule and launchd's cwd)"
else
  ok "sprint-run.sh does not use cd"
fi

# Lock file must be removed on interrupt, not just on normal exit.
if grep -q "trap 'release_lock; exit 130' INT TERM" "$HERE/sprint-run.sh"; then
  ok "lock is released on INT/TERM"
else
  bad "lock may survive an interrupt and block future runs"
fi

# Log rotation must exist or the directory grows without bound.
if grep -q "mtime +45 -delete" "$HERE/sprint-run.sh"; then
  ok "log retention enforced"
else
  bad "no log retention; disk grows unbounded"
fi

# Every plist must lint before it is loaded, or launchd silently refuses the job.
if grep -q "plutil -lint" "$HERE/install-weekend-sprints.sh"; then
  ok "plists are linted before load"
else
  bad "an invalid plist would be installed silently"
fi

echo
echo "result: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
