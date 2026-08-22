# AGENTS.md - APK Privacy Test Harness

Source for how to run agent work: `/Users/dubs/.config/opencode/AGENTS.md`.
Local verbatim copy (gitignored): `.agent/opencode-AGENTS.md`.
Em-dashes in that source are written here as " - " to match this repo's prose rules.

MASTER CONTRACT - read fully. Re-read this block at the start of every task. Never summarize it back.

## SKILLS (installed: superpowers + trainer, both wired)
- Load superpowers `using-superpowers` for methodology (spec -> plan -> TDD -> review -> finish).
- trainer.skill IS installed (registered via `skills.paths` in the global opencode config). It is
  available for adversarial review, hardening, recovery, and routing. Invoke trainer explicitly
  when the task is dangerous or you want its full routing - that is allowed and does not require
  ALLOW-FANOUT.
- superpowers subagent/parallel-agent skills are OFF by default (they multiply requests).
  Forbidden unless you type the exact phrase `ALLOW-FANOUT`.
- Skill trees: `/Users/dubs/.config/opencode/opencode.jsonc` (`skills.paths`), plus
  `/Users/dubs/Projects/superpowers-main/skills` and `/Users/dubs/Projects/trainer.skill`.

## DETERMINISTIC SKILL TRIGGERS (machine-enforced by tests/skill_trigger_gate_test.py)
# Whole-word, case-insensitive. On any user turn matching a trigger, the agent MUST
# invoke the mapped skill in the SAME turn before emitting any answer. No exceptions.
# "invoke" is deliberately EXCLUDED (overloaded generic prose).
- triggers: [ingest, jobspy, jobspy triage, csv triage, job board ingest, apply-row extraction]
  skill: ingest-search-results
  (This trigger is from the global OpenCode contract. It applies to toren job-board ingest, not to this harness.)

## THE LOOP - follow these phases IN ORDER. Print the phase name + one-line checklist, then do it.

**PHASE 0 ROUTE** [checklist: task classified? scratchpad path confirmed?]
Classify the task. Confirm `.agent/scratchpad.md`. If the change is dangerous/irreversible,
tell me BEFORE touching anything.

**PHASE 1 PLAN** [checklist: spec in <=5 bullets? exact file list? no files read yet?]
Restate the task in <=5 bullets and list the EXACT files you will need. Show me. WAIT for "go".
Do NOT read files yet.

**PHASE 2 CONTEXT** [checklist: all listed files read in one batch? written to scratchpad? announced?]
Read every file from Phase 1 together in as few calls as possible. Write their relevant content
+ plan + open questions into `.agent/scratchpad.md`. Say "context captured to scratchpad". This
is the ONLY time you read source files this task.

**PHASE 3 BUILD** [checklist: working from scratchpad only? test-first? one batched response?]
Produce a bite-sized task list from the scratchpad (no new reads). For each item, in ONE response:
write the failing test, then the minimal code, then state the expected RED->GREEN result. Run the
suite ONCE for the batch, not per step.

**PHASE 4 REVIEW** [checklist: adversarial checklist run? findings by severity? anti-theater?]
Invoke superpowers `requesting-code-review`. Review ONLY the diff and scratchpad/context - open no
new files (missing file = list as BLOCKING GAP and stop). One response, findings ordered
CRITICAL/MAJOR/MINOR/NIT. **Anti-theater:** do NOT approve on "tests exist" or a grep/`test -f`
check; a placeholder/empty implementation is CRITICAL. Run the SENIOR-ENGINEER CHECKLIST below.
If any CRITICAL/MAJOR is open: apply fixes as ONE batched edit and re-run REVIEW at most ONCE
more, then escalate to me.

**PHASE 5 FINISH** [checklist: real test evidence? procedural audit clean? scratchpad current? docs? branch choice?]
Invoke superpowers `verification-before-completion` + `finishing-a-development-branch`. In ONE
response report: (1) actual RED->GREEN evidence per task (never "should pass"); (2) procedural
audit - confirm no re-reads, no web tools, no subagent, no unrequested files, plus local step
count; (3) scratchpad Decisions/Open Questions updated so the next session needs zero
re-discovery; (4) docs updated if behavior changed (missing = BLOCKING); (5) present
merge/PR/keep/discard and WAIT for my choice. Declare success only when every item has evidence.

## SENIOR-ENGINEER ADVERSARIAL CHECKLIST (run in PHASE 4; this is trainer's posture)
1. Dead references - does any symbol/path/config point at something that doesn't exist?
2. Config/env drift - duplicate or contradictory settings?
3. Silent no-ops - instructions/branches that never fire?
4. Platform assumptions - verified against THIS machine, not inferred?
5. Enforcement backstop - is the rule actually enforced, or just hoped for?
6. Unbounded loops - retries/turns/recursion capped?
7. Off-by-one / boundary - first/last/empty/duplicate inputs handled?
8. Error paths - failures caught, not swallowed; no fail-open where fail-safe is required?
9. Idempotency - safe to run twice?
10. Cache/state invalidation - stale reads after a write?
11. Injection surface - file/tool content treated as untrusted (OWASP LLM01)?
12. Secrets hygiene - never read/log `.env`, `auth.json`, `config.yaml`, `secrets/`, keys.
13. Least privilege / fail-safe defaults.
14. Human-in-the-loop for irreversible actions.
15. Evidence over claims - every "done" backed by a real run, not "should pass".

## STOP-AND-ASK CONDITIONS
Missing file or context; a rule/task conflict; more than 2 review loops; any irreversible or
destructive action; `ALLOW-FANOUT` not given but parallelism seems needed.

## CHECKOUT / BRANCH-REVIEW REMINDER (offer-only, lightweight)
When a session starts on a git branch that is NOT `main`/`master`, and
`git diff origin/main...HEAD --stat` is non-empty, the agent MUST:
1. Print a one-line diff-vs-base summary: branch, base `origin/main`, # files,
   # insertions/deletions, top-3 changed paths.
2. If the diff is empty: print "clean tree, nothing to review" and stop.
3. If non-empty: remind the operator that the **trainer PR-review loop** is
   available, and print the exact command to launch it - but NEVER auto-run the
   loop, NEVER call `gh`, NEVER post. Offer only.
4. **Opt-out detection:** if the branch name matches a non-feature pattern
   (e.g. `chore/`, `docs/`, `wip/`, `exp/`, `scratch/`, `tmp/`, or no
   `feat/`/`fix/` prefix on a clearly non-code branch), the agent should note
   it can skip the reminder and ask whether to suppress future nudges on this
   branch shape. Detection is heuristic - when unsure, still remind.

This is a REMINDER only. The full loop (`trainer-autonomous-code-review.md`)
is multi-pass, runs the `reviewer_surface_tracker.py` novelty gate, and must be
triggered by explicit operator request. Running it on every checkout would blow
the context budget. A silent git `post-checkout` nudge may also exist at
`scripts/hooks/post-checkout` (non-networked; prints to stderr only).

## AGENT PROMPT GENERATION RULE (operator preference, 2026-07-16)
When the user asks for a "new agent prompt", "handoff prompt", "session continuation prompt",
or any request to produce a prompt for a future agent/session to continue work:

1. **NEVER write a file to disk.** Do not create `.md`, `.txt`, or any other file.
2. **Output ONLY in the chat session** inside a fenced codeblock (use a text fence).
3. **NEVER show preamble, thinking, work, or explanation.** Do not say "Here is the prompt",
   "I will generate", "Outputting now", or any variant. Do not summarize what you are about to do.
4. **Output the prompt directly** as the sole content of your response - nothing before or after.
5. **Delete any existing `.agent/next-session-prompt.md`** or similar file if one exists,
   but do not mention the deletion.

This rule is absolute and takes precedence over any default behavior or skill guidance that
might suggest writing handoff files to disk. The operator's explicit instruction is: chat-only,
zero preamble, codeblock-escaped output.

## PLAIN-LANGUAGE QUESTIONS (global, all sessions)

When asking the operator anything - clarifying question, decision, or multiple-choice - apply before sending:

1. No jargon or initials (e.g. PR, gate, diff, branch, HEAD, invariant, rubric, posture, ref, CI, lint, eval, harness, nonce, idempotent, provenance, snapshot). If a technical term is unavoidable, define it in one plain sentence.
2. Give context in 1-2 sentences: what you were doing, what you found, why it matters. Do not assume recall of earlier turns.
3. Name the ask plainly. Each option's description must be plain and state its consequence.
4. If a rule blocks you, state that in plain words and its effect, not its name.
5. Keep to one screen; use a list only for distinct choices.

---

## Skills Pipeline for .md Changes

Any change to a `.md` file must run through this pipeline before commit.

```bash
# 1. Write content (simple-english pragmatic mode)
# 2. Check style manually with the simple-english rules. No TIC script is present in this checkout.
# 3. Scan for AI tells
python3 /Users/dubs/Projects/deai.skill/deai-scan.py <file>
# 4. Fix AI slop manually:
#    - em-dash -> " - "
#    - passive -> active
#    - latinate -> plain
```

Steps 1, 2, and 4 are manual. Step 3 is automated. Run all four before committing any `.md` file.

## Review Depth

Reviews come in two depths. Pick based on risk.

### Lightweight (P1 Only)

Use for small fixes, doc updates, config changes.

```bash
# Run the banned-vocabulary check from .github/workflows/test.yml
# ("Check for banned vocabulary" step - single source of truth)
bash -n scripts/run-tests.sh && bash scripts/run-tests.sh --check
bash -n scripts/compare-apps.sh && bash scripts/compare-apps.sh --check
```

### Deep (P1 + P2 + P3)

Use for new features, security changes, schema changes.

```bash
# P1: all lightweight checks above, plus:
# P2: shellcheck on all scripts
shellcheck scripts/*.sh
# P2: JSON schema validation
python3 -m json.tool results/schema.json > /dev/null
python3 -m json.tool results/decode-traffic.schema.json > /dev/null
python3 -m json.tool results/comparison.schema.json > /dev/null
python3 -m json.tool results/network-log.schema.json > /dev/null
python3 -m json.tool results/analytics-pii.schema.json > /dev/null
python3 -m json.tool results/analytics-pii-20260803.json > /dev/null
# P2: run all unit tests
bash tests/test-decode-traffic.sh
bash tests/test-compare-apps.sh
bash tests/test-analytics-pii.sh
bash tests/test-network-log-redaction.sh
# P3: full harness dry run
bash scripts/run-tests.sh --check

Set `REVIEW_DEPTH=light` or `REVIEW_DEPTH=deep` in your environment to signal intent.

## CI Gates

These must pass on every push:

- Part headers 0-10 + 8.5 in APK_PRIVACY_TEST_HARNESS.md
- `"$schema"` declaration in harness doc
- `HARNESS_VERSION` agreement across run-tests.sh and test.yml
- `## 3.3.0` in CHANGELOG.md
- Banned vocab 0 hits on all public .md files
- JSON validation on results/*.json
- `bash -n` + shellcheck on all scripts
- All unit tests pass

## Evidence retention (HARD RULE)

Raw captures, decode files, and network logs are permanent evidence. Never delete, sweep, or "clean" them.

- The evidence tree is: `results/*-test-*/` (captures, HARs, logs, reports), `results/decode-traffic-*.json`, `results/network-log-*.json`, `results/*.mitm`, `results/mitm-capture/`.
- NEVER run `rm`, `rm -rf`, `find -delete`, or a cleanup pass over `results/`. There is no retention window: METHODOLOGY's old 90-day deletion policy no longer applies; evidence stays on disk indefinitely (gitignored for secrets, never committed).
- The only legitimate deletion is the harness's own `WORK_DIR` under `${HOME}/apk-privacy-test-*` (it deletes only what it created). `KEEP_WORK_DIR=1` preserves even that.
- Never sweep or run a "git tree clean of test artifacts" pass unless a verified backup restores the files.
- Mechanical backstop: `scripts/evidence-inventory.sh --check` fails the harness pre-flight when a committed network log is missing. Zero-byte `.mitm` files only warn (they are kept when a first mitmdump start dies). It warns on rotted decode files. Run it directly before any deletion: `bash scripts/evidence-inventory.sh --check`.
- Lost-capture knowledge: the pre-2026-08-14 legacy sessions (nurture-lock, nubo, pebbi, amila, baby-buddy, baby-daybook, baby-plus, mimilog) have NO raw captures left on disk. Their results are decode-level (`evidence_source: session-summary`); do not re-derive full-depth claims from them, and never describe them as raw-replay evidence. See ROADMAP.md for the recapture milestone.

## Secret hygiene - result artifacts

Captured traffic artifacts contain live secrets. `.gitignore` excludes them on purpose.

- `results/decode-traffic-*.json` and `*.mitm` captures contain captured Firebase JWTs, refresh tokens, and installation IDs.
- NEVER `git add -f` or commit these files. Force-adding them leaks secrets AND fails CI (gitleaks detects the JWTs).
- If a report needs to link per-app artifacts, link the committed, sanitized `results/network-log-*.json` logs instead.
- Raw network captures are generated locally and stay local only. See `METHODOLOGY.md` (Redaction) for the full policy.
- Never read `.secrets/` (including `.secrets/google.json`). Load that file only inside a script that types into the emulator.

## Sprint 6 Closeout

Sprint 6 closeout finalizes the baby-app-audit project's sprint cycle. All prerequisites verified:

- FINAL-REPORT.md complete with standardized Burst verdicts
- CHANGELOG 4.0.0 status marked Complete
- README "What is next" section updated
- Git tree clean of test artifacts (comparison-burst-5.log removed)
- Merge commit to main: fix/burst-2-har-dump-fix integrated
- Pipeline checks: run-tests.sh --check passes, schema validation, unit tests

Outputs delivered:
- Sprint-6 closeout documented in this AGENTS.md section and the merge commit
- Branch merged to main with all sprint 4 changes
- AGENTS.md updated with sprint-6 section

## Learned User Preferences
- Keep Cursor skills synced to origin. OpenCode holds the latest skills; treat laptop-migration skill notes as stale and delete them.
- Invoke superpowers and trainer throughout this harness work.
- Source of how to run agent work is OpenCode `AGENTS.md` at `/Users/dubs/.config/opencode/AGENTS.md` (local gitignored copy: `.agent/opencode-AGENTS.md`).
- Do not ask the operator to tap labeled buttons (OK, I agree, NEXT) that uiautomator can find by text. Drive adb, uiautomator, or Appium yourself.
- Keep the emulator window visible so the operator can see it. Use emulator-5554 only; ignore emulator-5556. Do not restart a live windowed session into headless.
- Prefer Appium / WebView context over screenshot coordinate taps for login-gated apps.
- Prefer skip or no-gender on synthetic baby forms when the app offers it. If gender is required and skip is not offered, select female (including unlabeled icon gender) rather than stopping.
- When offering a choice, explain it in very simple language (ELI12) and say which option is more thorough.
- Keep FINAL-REPORT as the existing table plus per-app block. Put deep-dive license or provenance material in footnotes. Do not add special per-app dive sections.
- When Play license, a missing package, or Pairip blocks inject, pull or sideload an APK or emulate the needed calls. Do not treat a CLOSE-only dump as a completed profile.
- Keep screenshots of each inject step (home, form, saved log, charts). We will later turn this project into a public site and article that explains, piece by piece, how we collected the data, including for readers who are not engineers. Store those PNGs under `results/<app>-test-<date>/artifacts/uiux/` (binary `adb exec-out screencap`; gitignored evidence tree; never commit secrets). Backfill the same pictures for every earlier test, not only Nubo. See ROADMAP.md "Screenshots for every prior test".

## Learned Workspace Facts
- Google account sign-in fails while the mitm proxy is on (cert pinning). Turn the proxy off for Google auth; restore `10.0.2.2:8080` before capture. After capture set proxy `:0`. SIGINT mitmdump; confirm `lsof` shows port 8080 free before a new dump (the child may outlive the wrapper).
- Do not launch `UiMinfaActivity` to add a Google account; it opens Gmail IMAP setup. Use `android.settings.ADD_ACCOUNT_SETTINGS`, then tap Google.
- API 29 has no `adb shell cmd account list`. An empty result is a false empty; check `dumpsys account` instead.
- Native inject configs exist for Amila, Baby Daybook, and onboarded MimiLog. Pebbi after Pairip is native (Welcome / Add New Baby), not WebView. Baby+ remains login-gated. MimiLog is not FOSS. After a profile exists, Feeding / Bottle uses `content-desc`. ESCAPE closes the Bottle sheet; the recipe sets `dismiss: false` on `fill_nth`.
- Baby+ About Baby requires gender (Boy/Girl only). The gender control has empty content-desc and no Boy/Girl nodes in the dump; log that as an accessibility finding. Still complete the form when a female control is tappable.
- Baby+ About You CONTINUE sends a first-party PUT to `appserver.health-and-parenting.com`; a plaintext marker scan can miss an encoded name in that body.
- A 0-flow mitm capture through the system HTTP proxy is not proof data stayed on-device. Flutter apps often ignore that proxy. Proof that Firebase was silent needs a reachable-host control, a packet capture the app cannot skip, a finished-profile time window, and two records that agree. See METHODOLOGY.md "What proves Firebase is silent".
- Nubo article screenshots (2026-08-18): `/Users/dubs/Projects/baby-app-audit-sprint4/results/nubo-test-20260818/artifacts/uiux/article-01-logs.png`, `article-02-chart.png`, `article-03-device.png`, `article-04-logs-again.png`. Also `after-inject.png` (note typed), `after-inject3.png` (logs after save). Other apps still need the same kind of pictures.
- Most captures are a short first-launch window. That is not a 20-minute idle, and it is not Backup/Sign-in/device-pair. Nubo 2026-08-18 finished home activities on device; Settings extras, Backup, and BLE pair were not tapped. See ROADMAP.md "App surface and sync-condition coverage".
- `adb exec-out screencap` must stay binary. Do not decode it as text or the PNG is corrupted.
- Use screenshots to drive WebView coordinates when uiautomator dumps expose no nodes.
- On this API 29 Google APIs AVD, a stub Play Store (`com.android.vending` 1.8) makes Pairip `LicenseActivity` CLOSE-only (Pebbi, Nurture Lock). Baby Daybook crashes `UnsatisfiedLinkError` Pairip `VMRunner`. That is not a privacy verdict.
