# Weekend sprint orchestrator (baby-app-audit)

Committed contract for the scheduled Saturday/Sunday 07:00 sprint run. The automation prompt is a
thin pointer to this file so the orchestration is versioned and cheap to send.

Model-agnostic: nothing here names a model, provider, or vendor-specific primitive. Any harness
that can spawn subagents, hold files, and run shell commands can execute it.

---

## 0. Roles

| Role | Count | Owns | Never does |
|---|---|---|---|
| Orchestrator | 1 (this session) | dispatch, gates, PR bodies, EOD report | reads app source or raw captures, merges, force-pushes |
| PM | 1 subagent | one burst spec from the roadmap and testing phases | runs tests, edits evidence |
| Evidence SWE | 1 to 3 subagents | one worktree + branch each: harness code, schema, scripts, tests | touches another worker's paths, invents findings |
| QA | 1 subagent | adversarial test audit + rerun of every script the burst claims | approves its own work, claims a run it did not execute |

## 1. Token discipline (hard rules)

1. **The orchestrator never reads raw evidence.** Not APKs, not `decompiled/`, not `results/`, not HAR files, not `localonly/`. It reads `ROADMAP.md`, `TESTING-PHASES.md`, `AGENTS.md`, and worker one-line outputs only.
2. **Workers write, orchestrator summarizes.** Each worker returns at most 12 lines plus a file path under `/tmp/babyaudit-sprint-<date>/`.
3. **One context brief per run** at `/tmp/babyaudit-sprint-<date>/brief.md`: repo SHA, current burst number, the apps in scope, the criteria version (Sprint 3 criteria), and the harness commands. Later workers read the brief, never re-derive.
4. **Fixed fan-out**: maximum 3 concurrent workers. This repo's `AGENTS.md` forbids parallel subagents without an explicit `ALLOW-FANOUT` token; the scheduled run carries that token **only** for the sprint orchestrator, never for ad-hoc work.
5. **Barrier between waves.** No overlapping writes to the same file.
6. **Two-round stop rule** on every review or audit loop.
7. **Structured returns**, identical shape to the toebeans run:

```
RESULT: <PASS|FAIL|BLOCKED>
PR: <url or none>
FILES: <n> changed
TEST: <command> -> <x passed / y failed>
RISK: <one line or none>
DETAIL: /tmp/babyaudit-sprint-<date>/<worker>.md
```

8. **No evidence re-collection.** A burst consumes evidence already captured in `results/`. If evidence is missing for an app, the worker reports `BLOCKED: missing evidence <path>` and the run does not fabricate it by driving the emulator unattended.
9. **Cap the burst.** 3 apps or 4 PRs per run, whichever comes first.

## 2. Skill posture (invoke once, by name, in every worker prompt)

- **trainer**: routes and gates, including the adversarial posture this repo already codifies in its SENIOR-ENGINEER ADVERSARIAL CHECKLIST.
- **superpowers**: `writing-plans`, `test-driven-development`, `verification-before-completion`, `systematic-debugging`, `requesting-code-review`.
- **ponytail** (level `full`): smallest complete change; no new dependency for a few lines; deletion beats addition. Audit scripts accrete, so this skill matters more here than in toebeans.
- **form-check**: adversarial review; the anti-theater rule (a placeholder implementation is CRITICAL).
- **safe-terminal**: any multi-line shell.
- **writing**: report and PR prose.

Precedence: trainer > the repo's own AGENTS.md loop > form-check/verification > safe-terminal > ponytail > writing.

## 3. Repo contract (from this repo's `AGENTS.md`, non-negotiable)

- The LOOP phases apply to every task: ROUTE, PLAN, CONTEXT, BUILD, REVIEW, FINISH. The sprint run uses the same phases at the orchestration level; workers run the LOOP inside their own scope.
- Anti-theater: "tests exist" is not approval. A placeholder or empty implementation is CRITICAL.
- Never read or log secrets: `.env`, `auth.json`, `config.yaml`, `secrets/`, keys.
- Human-in-the-loop for any irreversible or destructive action.
- Evidence over claims: every "done" is backed by a real run, never "should pass".
- Agent-prompt-generation rule: when the operator asks for a prompt, chat-only, no files, no preamble.

## 4. Phases

### Phase 0: preflight (orchestrator)

1. `git fetch origin && git log --oneline -n 5 origin/main`.
2. Read `ROADMAP.md` for the current sprint and burst, `TESTING-PHASES.md` for the burst plan, and `FINAL-REPORT.md`'s open items.
3. Confirm harness prerequisites: `python3 --version`, `bash scripts/evidence-inventory.sh --help` (or the current inventory entry point), and whether an APK/emulator path exists. Do not boot an emulator unattended.
4. Write `/tmp/babyaudit-sprint-<date>/brief.md`: SHA, current burst, apps in scope, criteria version, exact commands, and the evidence paths that already exist.
5. If the current burst is complete and no next burst is declared in the roadmap, **do not invent a burst**: report "no burst declared, operator decision needed" and stop.

### Phase 1: PM wave (1 subagent, `product-reviewer`)

Produce `/tmp/babyaudit-sprint-<date>/spec.md`: the burst scope (3 apps maximum), the per-app acceptance criteria tied to the Sprint 3 criteria, what evidence already satisfies each criterion, what is missing, and explicit out-of-scope. Returns a 10-line summary only.

### Phase 2: SWE wave (up to 3 subagents, parallel)

One worker per app or per harness concern. Owned paths are disjoint by construction: each app gets its own directory under `results/`, and harness changes are a separate worker. Each worker prompt contains: role, worktree, brief path, spec path, acceptance criteria verbatim, exact commands, the anti-theater rule, and the output shape.

Hard rule for this repo: a worker may **update metadata and write findings from existing evidence**, and may **write or fix harness code with tests**, but may not invent an observation that the evidence does not support. Unsupported claim is CRITICAL.

### Phase 3: QA wave (1 subagent)

- Read each PR diff, not the repo.
- Judge the tests for empty asserts, mock theater, and whether they can fail on a real regression.
- Re-run every script the PR claims to have run, and compare the actual output to the claim.
- Check each acceptance criterion has covering evidence, not just a claim.
- Returns one `RESULT` per PR plus ranked gaps. Cap: 2 rounds.

### Phase 4: close-out (orchestrator)

1. Write `/tmp/babyaudit-sprint-<date>/EOD.md`: PRs, CI state, apps covered, criteria satisfied vs missing, evidence gaps, next burst recommendation.
2. Update `ROADMAP.md` only if a burst actually completed (that is a docs PR, not a direct push to main).
3. Leave every PR open. Remove worktrees.

## 5. Failure handling

| Situation | Action |
|---|---|
| Missing evidence for an app | `BLOCKED: missing evidence <path>`; do not drive the emulator unattended; list it for the operator |
| A worker's finding has no evidence path | CRITICAL; the finding is rejected, not softened |
| Two workers write the same file | The later dispatcher yields; re-scope or cancel |
| Burst complete, no next burst declared | Stop and ask; never invent |
| Nothing legitimate to do | Report "sprint not warranted" |

## 6. What a good run looks like

1 to 3 small PRs, each covering one app or one harness concern, with evidence paths cited for every finding, tests that can actually fail, CI green, and an EOD naming exactly which criteria are satisfied and which are still missing.
