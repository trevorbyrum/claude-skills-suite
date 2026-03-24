# Project Plan — meta-pivot Skill Suite

> Last updated: 2026-03-24
> Status: active
> Based on: project-context.md, research 010 (410 sources, 126 cited)

## Executive Summary

Building `meta-pivot` — an 8-phase meta-skill that helps users pare down projects
after direction changes. Orchestrates deep analysis, triage, and safe incremental
removal with human gates at every decision point. Requires 3 new atomic skills
(`scope-triage`, `impact-analysis`, `surgical-remove`), the meta-skill orchestrator,
4 agent prompt templates, 2 artifact templates, 2 reference docs, and 1 helper
script. 3 phases, 15 work units, 9 parallelizable. ~2,800 LOC across ~20 new
files + 1 edit.

**Key risk**: "Plan as deletion signal" is novel (no prior art). Doc freshness
must be verified before using docs to drive removal decisions. Mitigated by
mandatory context rewrite in Phase 2 of the skill.

## Skill Descriptions (≤150 chars, validated)

| Skill | Description | Chars |
|---|---|---|
| meta-pivot | Orchestrates project pivot: direction interview, context rewrite, deep analysis, triage, wave removal, verification. Invoke with /meta-pivot. | 148 |
| scope-triage | Scores features/modules for keep/cut/simplify using modified RICE + MoSCoW against a stated direction. Invoke with /scope-triage. | 131 |
| impact-analysis | Builds dependency graph, runs dead code detection, calculates blast radius for removal candidates. Invoke with /impact-analysis. | 128 |
| surgical-remove | Wave-ordered code removal (dead→orphan→deprecated→restructure) with characterization tests and human gates. Invoke with /surgical-remove. | 144 |

## Data Flow (skill-forge compliance)

```text
Subagent → temp file → main thread → db_upsert + pivot-summary.md append

Key rule (A2): Subagents CANNOT call db_upsert. They write results to temp files
(/tmp/pivot-*). Main thread reads temp files, calls db_upsert, and appends to
artifacts/general/pivot-summary.md. This applies to all subagent phases (3,6,7,8).
```

**Artifact DB keys:**

| Skill | Phase | Label | Content |
|---|---|---|---|
| impact-analysis | candidates | latest | Ranked removal candidates with blast radius + confidence |
| impact-analysis | dep-graph | latest | Dependency graph summary (entry points, orphans, clusters) |
| scope-triage | triage | latest | RICE-scored + MoSCoW-categorized feature/module table |
| surgical-remove | wave-log | wave-{N} | Per-wave execution log (removed files, test results) |
| meta-pivot | summary | {timestamp} | Full pivot-summary.md snapshot |

## Phases and Milestones

| Phase | Name | Milestone | Dependencies |
|---|---|---|---|
| 1 | Atomic Skills | All 3 SKILL.md files + references + scripts written and independently testable | None |
| 2 | Meta-Pivot Orchestrator | meta-pivot SKILL.md + all agent templates + artifact schemas complete. Skill can be invoked end-to-end. | Phase 1 |
| 3 | Integration & Validation | Wired into skill suite. Passes cross-cutting compliance. Dry-run on a real project validates all 8 phases. | Phase 2 |

## Technical Approach

### meta-pivot (Meta-Skill — Orchestrator)

Context-minimal orchestrator following established meta-skill patterns
(meta-research, meta-execute). Main thread handles orchestration + human gates.
Heavy analysis dispatched to Opus subagent. Adversarial debate via Codex + Gemini
at the two highest-impact decision points.

**Delegation map:**

```text
Phase 1: Direction Interview        [I] Inline — user interaction
Phase 2: Context Rewrite            [I] Inline — user approval per doc change
Phase 3: Deep Analysis              [S] Opus subagent (impact-analysis + clean-project)
Phase 3.5: Adversarial Challenge    [W] Codex + Gemini challenge removal candidates
Phase 4: Triage & Scoring           [I] Inline — user keep/cut/simplify decisions
Phase 4.5: Adversarial Challenge    [W] Codex + Gemini challenge cut decisions
Phase 5: Decision Logging           [I] Inline — user confirms ADRs
Phase 6: Wave Execution             [S] Opus subagent per wave, main thread gates
Phase 7: Verification               [S] Sonnet subagent (drift + completeness)
Phase 8: Final Doc Update           [S] Sonnet subagent (evolve)
```

**Phase details:**

1. **Direction Interview** [I] — Guided questions to capture new direction.
   Claude summarizes old→new for user confirmation.
2. **Context Rewrite** [I, human-gated] — Rewrites project-context.md and
   project-plan.md with short per-change explanations. User approves. Then
   cascades to features.md, todo.md, other context docs. This "depoisons" the
   well for all downstream agents.
3. **Deep Analysis** [S, Opus] — Dispatches Opus subagent using
   `agents/deep-analysis.md` prompt template. Runs impact-analysis (dependency
   graph + dead code + doc-code diff + external dependency scan) + clean-project
   (structural scan). Agents read *updated* docs from Phase 2. Opus writes
   results to `/tmp/pivot-analysis-*`. Main thread reads, calls `db_upsert`,
   appends to pivot-summary.md.
4. **Adversarial Challenge I** [W, Codex+Gemini] — Before presenting candidates
   to user. Codex and Gemini independently review the removal candidates + blast
   radius. Each flags false positives, missed dependencies, and items they
   disagree on. Annotations merged into the candidate list. Fallback: Codex →
   Sonnet, Gemini → Copilot → Sonnet. At minimum 2 adversarial reviewers run.
5. **Triage & Scoring** [I, human-gated] — Runs scope-triage (modified RICE +
   MoSCoW) with adversarial annotations visible. User makes final
   keep/cut/simplify decisions per candidate.
6. **Adversarial Challenge II** [W, Codex+Gemini] — After triage, before
   logging. Codex and Gemini attack the cut decisions: "You're cutting X but Y
   depends on it", "You're keeping Z but it contradicts the new direction",
   "Wave ordering is wrong because...". User can revise triage or confirm.
   Same fallback chain.
7. **Decision Logging** [I] — ADR-format records per cut decision. Immutable
   — never edited, only superseded.
8. **Wave Execution** [S, Opus per wave] — Dispatches surgical-remove via
   `agents/wave-executor.md`. Dead code → orphans → deprecated → restructuring.
   Main thread gates between waves. User approves progression or rollback.
9. **Verification** [S, Sonnet] — drift-review + completeness-review +
   build/test/lint pass.
10. **Final Doc Update** [S, Sonnet] — Evolve captures everything that changed
    during execution.

**Artifact outputs** (written throughout, stored in `artifacts/general/`):

- `pivot-plan.md` — Created Phase 3, finalized Phase 5. What's being removed/rewritten/restructured, in what order, with blast radius (internal + external).
- `pivot-summary.md` — Append-only log. Each phase appends a timestamped section. Includes adversarial challenge results. Full audit trail.
- `decisions/` — ADR files from Phase 7.

**Adversarial debate protocol:**

```text
For each debate point (Phase 3.5, Phase 4.5):
  1. Write debate prompt to /tmp/pivot-debate-{phase}.md
  2. Dispatch in parallel:
     - Codex via codex-exec.sh review (120s timeout)
     - Gemini via /gemini driver (120s timeout)
  3. Fallback chain: Codex fails → Sonnet subagent
                     Gemini fails → Copilot → Sonnet subagent
  4. At minimum 2 of 3 reviewers must complete
  5. Main thread merges disagreements, annotates candidate list
  6. Disagreements highlighted in red for user attention
```

### scope-triage (Atomic Skill)

Presents removal candidates with modified RICE scoring adapted for code:
- **Usage frequency** (replaces Reach) — runtime call count, import count, test coverage
- **Blast radius** (replaces Impact) — transitive dependent count from impact-analysis
- **Test coverage** (replaces Confidence) — % of code paths covered by tests
- **Lines of code** (replaces Effort) — LOC to remove/rewrite

Then MoSCoW categorization against the *new* direction (Must keep / Should keep /
Could remove / Won't keep). Output stored in artifact DB via
`db_upsert 'scope-triage' 'triage' 'latest'` — ranked table with scores,
categories, and one-line rationale per item. Human approves the final
categorization.

Reusable outside meta-pivot for any scope reduction decision.

### impact-analysis (Atomic Skill)

Constructs dependency graph and calculates removal blast radius. Four modes:

1. **Graph build** — Language-aware: dependency-cruiser (JS/TS), madge (JS
   visualization), custom tree-sitter for others. Falls back to import-pattern
   grep if no tool available.
2. **Reachability analysis** — Trace from entry points. Unreachable = safe removal.
3. **Internal blast radius** — For each candidate, count transitive dependents.
   Classify: leaf (0 deps), branch (1-5), trunk (6+).
4. **External blast radius** — Scan for dependencies OUTSIDE the repo that
   reference project files. Checks:
   - Systemd/launchd services referencing project paths
   - Cron jobs / scheduled tasks calling project scripts
   - Docker containers / docker-compose mounting project directories
   - Other projects importing from this one (workspace deps, symlinks, go.mod replaces)
   - CI/CD pipeline configs (.github/workflows, .gitlab-ci.yml) referencing specific files
   - Git hooks (.git/hooks/, .husky/) referencing files being removed
   - Environment variables in shell profiles pointing to project paths
   - Reverse proxy configs (nginx, traefik) routing to this project
   - Package registries (npm link, pip -e, go workspace) with local references

   External scan uses: `grep -r` on common config locations, `docker inspect`,
   `crontab -l`, shell profile parsing. Results tagged as EXTERNAL in the
   candidate list with a separate blast radius column.

Also runs dead code detection: knip (JS/TS), vulture (Python), `go vet` (Go),
`cargo udeps` (Rust), compiler warnings. Aggregates candidates with confidence
scores (high = static + runtime agree, medium = static only, low = heuristic).

Includes doc-code diff: loads project-context.md + features.md + project-plan.md,
diffs against actual codebase. Items in code but NOT in docs = removal candidates
(the "plan as deletion signal" pattern). Config-as-code included (Terraform,
Docker, CI/CD configs).

Output stored in artifact DB via `db_upsert 'impact-analysis' 'candidates' 'latest'`
and `db_upsert 'impact-analysis' 'dep-graph' 'latest'` — ranked candidate list with
internal + external blast radius, confidence, and source (dead code tool / orphan
detection / doc-code diff / external scan).

### surgical-remove (Atomic Skill)

Wave-ordered removal execution with human gates:
- **Wave 1**: Dead code (zero deps, zero runtime refs) — safest
- **Wave 2**: Orphaned modules (no incoming deps) — low risk
- **Wave 3**: Deprecated features (has deps, flagged for removal) — medium risk
- **Wave 4**: Restructuring moves (live code changing location) — highest risk

Per wave:
1. Create git branch for the wave (`pivot/wave-N`)
2. Generate characterization tests for code being removed (captures current behavior)
3. Execute removals (file deletions, import cleanup, reference updates)
4. Run full test suite + lint + type-check
5. Report results to main thread
6. Human approves wave progression or requests rollback

Pre-production shortcut: If no production deployment detected, simplifies to
single branch with full test suite (no wave splitting, no characterization tests).

Rollback: Each wave is a separate branch. `git revert` or branch delete for
instant rollback per wave.

## Work Units

| ID | Title | Phase | Par? | LOC | Key Files | Deps | Acceptance Criteria |
|----|-------|-------|------|-----|-----------|------|---------------------|
| WU-1-01 | scope-triage SKILL.md | 1 | yes | 200 | skills/scope-triage/SKILL.md | — | Frontmatter ≤150 chars. Instructions for modified RICE scoring + MoSCoW. DB output pattern. Input/output tables. Examples. Cross-cutting footer. |
| WU-1-02 | scope-triage references | 1 | yes | 150 | skills/scope-triage/references/triage-framework.md | — | Modified RICE formula (Usage/Blast/Coverage/LOC). MoSCoW definitions for code. Scoring examples. Output table schema. |
| WU-1-03 | impact-analysis SKILL.md | 1 | yes | 300 | skills/impact-analysis/SKILL.md | — | 4 modes: graph build, reachability, internal blast radius, external blast radius. Dead code detection. Doc-code diff. Language-aware tool selection. DB output. |
| WU-1-04 | impact-analysis scripts | 1 | yes | 200 | skills/impact-analysis/scripts/analyze-deps.sh | — | Wraps dep-cruiser + knip + vulture + external scan with `$GTIMEOUT`. JSON candidate output. Graceful fallback if tools missing. Non-zero exit + message if nothing available. |
| WU-1-05 | impact-analysis references | 1 | yes | 150 | skills/impact-analysis/references/tool-matrix.md, skills/impact-analysis/references/external-scan.md | — | tool-matrix.md: language→tool map + confidence rubric. external-scan.md: checklist of external dependency locations to scan (services, cron, docker, CI, hooks, envvars, proxies). |
| WU-1-06 | surgical-remove SKILL.md | 1 | yes | 250 | skills/surgical-remove/SKILL.md | — | 4-wave protocol. Per-wave steps. Pre-production shortcut. Rollback strategy. Human gates. Git branch naming (`pivot/wave-N`). |
| WU-1-07 | surgical-remove references | 1 | yes | 100 | skills/surgical-remove/references/wave-protocol.md | — | Wave ordering rationale. Characterization test strategy. Rollback decision tree. Pre-prod vs prod detection logic. |
| WU-2-01 | meta-pivot SKILL.md | 2 | no | 450 | skills/meta-pivot/SKILL.md | WU-1-* | 10-phase orchestrator (8 phases + 2 adversarial debates). Delegation keys. Opus subagent dispatch for Phases 3,8,9,10. Adversarial debate protocol for Phases 3.5,4.5. Artifact output schema. Error handling. Examples. Cross-cutting footer. |
| WU-2-02 | Agent: deep-analysis (Opus) | 2 | yes | 80 | skills/meta-pivot/agents/deep-analysis.md | WU-2-01 | Opus subagent prompt. Reads impact-analysis + clean-project SKILL.md. Runs all 4 analysis modes incl external scan. Writes results to temp files. Placeholders: [PROJECT_PATH], [UPDATED_DOCS_HASH]. |
| WU-2-03 | Agent: adversarial-debate | 2 | yes | 80 | skills/meta-pivot/agents/adversarial-debate.md | WU-2-01 | Prompt template for Codex + Gemini debate. Two modes: candidate-challenge (Phase 3.5) and triage-challenge (Phase 4.5). Fallback chain documented. Placeholders: [CANDIDATES], [TRIAGE_DECISIONS], [DIRECTION_SUMMARY]. Output: annotated disagreements. |
| WU-2-04 | Agent: wave-executor (Opus) | 2 | yes | 60 | skills/meta-pivot/agents/wave-executor.md | WU-2-01 | Opus subagent prompt. Reads surgical-remove SKILL.md. Placeholders: [WAVE_NUMBER], [CANDIDATE_LIST], [PROJECT_PATH]. Writes execution log to temp file. |
| WU-2-05 | Agent: verification | 2 | yes | 50 | skills/meta-pivot/agents/verification.md | WU-2-01 | Sonnet subagent prompt. Reads drift-review + completeness-review SKILL.md. Placeholders: [PROJECT_PATH], [PIVOT_SUMMARY_PATH]. |
| WU-2-06 | Agent: doc-update | 2 | yes | 40 | skills/meta-pivot/agents/doc-update.md | WU-2-01 | Sonnet subagent prompt. Reads evolve SKILL.md. Placeholders: [PROJECT_PATH], [PIVOT_SUMMARY_PATH]. |
| WU-2-07 | Artifact schemas | 2 | yes | 100 | skills/meta-pivot/templates/pivot-plan-template.md, skills/meta-pivot/templates/pivot-summary-template.md | WU-2-01 | pivot-plan: removal wave table, internal + external blast radius, rollback strategy. pivot-summary: section headers for all 10 phases incl adversarial results. Both in artifacts/general/. |
| WU-3-01 | Wire into skill suite | 3 | no | 20 | — | WU-2-01 | Frontmatter description ≤150 chars. Trigger phrases documented. No always-on language. |
| WU-3-02 | Validation & dry-run | 3 | no | 0 | — | WU-3-01 | /skill-doctor passes. Run meta-pivot Phases 1-2 on this project as dry-run. Verify interview + context rewrite flow works end-to-end. |

**Totals**: 17 work units, 12 parallelizable, ~3,230 LOC, ~22 new files

## Dependency Graph

```text
Phase 1 (all parallel):
WU-1-01 (scope-triage SKILL) ──────┐
WU-1-02 (scope-triage refs) ───────┤
WU-1-03 (impact-analysis SKILL) ───┤
WU-1-04 (impact-analysis scripts) ─┼──→ WU-2-01 (meta-pivot SKILL)
WU-1-05 (impact-analysis refs) ────┤         │
WU-1-06 (surgical-remove SKILL) ───┤         ▼
WU-1-07 (surgical-remove refs) ────┘    Phase 2 (agents parallel after 2-01):
                                        WU-2-02 (agent: deep-analysis) ────┐
                                        WU-2-03 (agent: adversarial) ──────┤
                                        WU-2-04 (agent: wave-executor) ────┤
                                        WU-2-05 (agent: verification) ─────┼→ WU-3-01 → WU-3-02
                                        WU-2-06 (agent: doc-update) ───────┤
                                        WU-2-07 (artifact schemas) ────────┘
```

**Critical path**: WU-1-03 → WU-2-01 → WU-2-02 → WU-3-01 → WU-3-02

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Doc-code diff false positives | High | Medium | Confidence scoring. Human review in Phase 5. Doc freshness gate in Phase 2 catches stale docs first. |
| No unified multi-lang dead code tool | High | Low | Language-specific tool selection with grep fallback. Most projects are 1-2 languages. |
| External scan misses dependencies | Medium | High | Checklist-driven (external-scan.md). Warn user that scan is best-effort. Manual review for production systems. Adversarial debate in Phase 3.5 may catch gaps. |
| Wave execution too slow for small projects | Medium | Medium | Pre-production shortcut: single branch, no wave splitting. Auto-detect in Phase 3. |
| Skill too heavyweight | Medium | High | Natural exit points at each phase. Phases 1-2 valuable standalone. Can stop after Phase 5 (triage) if user just wants analysis. |
| Adversarial debate adds latency | Medium | Low | Codex + Gemini run in parallel (120s each). Total added time ~2-3 min. Value: catches false positives before user makes irreversible decisions. |
| Codex + Gemini both unavailable | Low | Medium | Triple fallback: Codex → Sonnet, Gemini → Copilot → Sonnet. At minimum 2 Sonnet subagents always run. |
| Context rewrite misunderstands direction | Low | High | Two human gates: confirm old→new summary, then approve each doc change with explanation. |
| External removal breaks running services | Low | Critical | External blast radius scan surfaces these BEFORE triage. Candidates with external deps flagged as CRITICAL in triage. User must explicitly acknowledge. |

## Competitive Insights

No existing tool provides a full project pivot workflow. The closest:
- **Knip / dependency-cruiser** — Dead code + dependency analysis only. No triage, no execution, no doc integration.
- **OpenRewrite** — Automated refactoring recipes. Java-focused. No pivot awareness.
- **Gemini Code Assist / Copilot** — Codebase-aware refactoring but no structured pivot process.
- **Moderne (Moddy)** — Enterprise refactoring at scale. Closest competitor but recipe-based, not direction-change-aware.

**Differentiation**: meta-pivot is the only tool that:
1. Starts with organizational triage (direction interview + stakeholder alignment)
2. Uses project documentation as deletion signals
3. Rewrites context docs BEFORE analysis to prevent poisoned reviews
4. Provides wave-ordered execution with human gates
5. Verifies against updated docs post-removal

## Open Items

1. ~~Artifact location~~ — Resolved: `artifacts/general/` for pivot-plan.md, pivot-summary.md, decisions/
2. Should scope-triage support importing external usage data (analytics, APM)? — Deferred to v2.
3. Should impact-analysis support monorepo cross-package analysis? — Deferred to v2 (single-package for v1).
4. Should meta-pivot integrate with meta-execute for the execution phase, or use its own surgical-remove? — Using surgical-remove (different execution model: removal waves vs build waves).

## Changelog
<!-- Append-only -->
- 2026-03-24: Initial plan. Based on research 010 (410 sources, 126 cited, triple-countered). User-directed design: 8 phases with context rewrite early + doc update late, artifacts in artifacts/general/.
