# Sprint 4 Plan - Final Report and Open-Source Release

**One sentence.** Publish a final audit report and release the baby app privacy test harness as an open-source tool.

**First user.** A privacy researcher or journalist who wants to cite the findings or replicate the test.

**MVP (v0).**
1. A single, polished final report that synthesizes all findings from Sprints 1-3.
2. Updated public documentation (README, METHODOLOGY, HARNESS) that reflects the final state.
3. A tagged release on GitHub with a clear open-source declaration.

**Acceptance criteria for MVP.**
- [ ] Final report file exists (`FINAL-REPORT.md` or expanded `RESULTS-20260803.md`) and covers: executive summary, per-app findings, dark pattern analysis, cross-app comparison, limitations, and recommendations.
- [ ] All public `.md` files pass the AGENTS.md pipeline: `tic.sh`, `deai-scan.py`, banned vocab check.
- [ ] `ROADMAP.md` accurately reflects completed work (Sprints 1-3 Done, Sprint 4 Current) with dates.
- [ ] `CHANGELOG.md` has a `## 4.0.0` header with Sprint 4 deliverables listed.
- [ ] GitHub release tag `v4.0.0` exists with release notes summarizing the audit.
- [ ] `LICENSE` is correct (GPL-3.0) and mentioned in README.
- [ ] CI passes (unit tests, schema validation, banned vocab, shellcheck).

**Kill criteria.**
1. If final report synthesis takes more than 2 days of focused work, publish the methodology only and defer the full report.
2. If open-source release prep requires more than 1 day (beyond CONTRIBUTING.md + release tag), defer to a post-publication follow-up.

**Deliberate non-goals (v0).**
- Do not add new app tests or expand the candidate list.
- Do not redesign schemas or rewrite the harness.
- Do not create a separate project website or blog post (use GitHub README as the publication surface).
- Do not submit to academic journals or conferences (out of scope for this sprint).

**First three concrete tasks.**
1. Update `ROADMAP.md` and `CHANGELOG.md` to mark Sprint 3 complete and Sprint 4 active.
2. Draft the final report structure and populate the executive summary.
3. Verify CI passes and create the `v4.0.0` release tag.

**Timebox to v0.** One weekend (2 focused days). If the timebox is exceeded, apply kill criterion #1.

---

## Task Breakdown

### P1 - Documentation updates
- [ ] Update `ROADMAP.md` status
- [ ] Add `## 4.0.0` to `CHANGELOG.md`
- [ ] Verify `README.md` "What is next" section points to Sprint 4 deliverables
- [ ] Run AGENTS.md checks on all modified `.md` files

### P2 - Final report generation
- [ ] Create report structure (executive summary, findings, dark patterns, comparison, limits, next steps)
- [ ] Synthesize `RESULTS-20260803.md` content into publishable prose
- [ ] Include dark pattern analysis with honest confidence levels
- [ ] Include cross-app comparison with shared tracker findings
- [ ] Add recommendations section (for parents, developers, regulators)

### P3 - Open-source release
- [ ] Verify `LICENSE` is GPL-3.0 and correct
- [ ] Add `CONTRIBUTING.md` with basic guidelines
- [ ] Tag release `v4.0.0` with release notes
- [ ] Verify CI passes on final commit

## Dependencies
- Sprint 3 artifacts (`RESULTS-20260803.md`, dark pattern JSONs, comparison JSONs)
- CI pipeline (`.github/workflows/`)
- AGENTS.md style pipeline for `.md` files

## Risks
- Dark pattern findings have low confidence (mostly false positives) - report must be honest about this
- Nubo static analysis was late addition - ensure consistency
- Cross-app comparison has limited scope (only 3 apps with outbound traffic)
