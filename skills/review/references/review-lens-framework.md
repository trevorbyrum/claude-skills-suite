# Review Lens Framework

Single canonical reference. Every review lens — default-tier and optional-tier — follows the patterns here. Lens-specific checks live in `default-tier.md` and `optional-tier.md`.

## Severity tiers

All lenses share four tiers:

- **CRITICAL** — blocks deployment: data loss, security exposure, correctness failure, regulatory violation
- **HIGH** — significant gap needing immediate attention before next milestone
- **MEDIUM** — quality issue to fix in the next iteration
- **LOW** — nitpick, polish, improvement suggestion

## Finding format

Every finding includes (at minimum):

| Field | Value |
|---|---|
| Severity | CRITICAL / HIGH / MEDIUM / LOW |
| Location | `file:line` or `file:line-line` for ranges |
| Problem | What's wrong (1-3 sentences) |
| Evidence | What in the code or context supports the finding |
| Recommendation | How to fix it (specific, not "consider refactoring") |

Lens-specific fields:
- Security: add **CWE** id when applicable
- Dep-audit: add **package** + **affected version range**
- Browser: add **screenshot or text excerpt** of the visible defect
- UI: add **viewport / breakpoint** the issue manifests at
- Breaking-change: add **public API surface** affected + **caller count** if known

## Fresh-findings check (lens entry)

Before scanning, each Sonnet lens subagent should be told:

> A previous lens run for {LENS} on this project exists from N hours ago. The user opted to {reuse | rescan}. If reusing, you don't need to scan again — just return the cached findings from the DB.

The main thread handles the cache check (`db_age_hours <lens> findings lens`) before dispatch and bakes the decision into the prompt. Subagents don't query the DB.

If the user opted to reuse, the main thread skips dispatch for that lens entirely and reads `db_read <lens> findings lens` directly into synthesis.

## Output (subagent → main thread → DB)

Subagents return findings as **response text**, never call `db_*` functions (per cross-cutting anti-pattern A2).

Main thread persists:

```bash
source references/db.sh
db_upsert '<lens>' 'findings' 'lens' "$AGENT_RESPONSE"
```

The `lens` label means "produced as part of /review's multi-lens fan-out." A user invoking a single lens directly still uses `lens` — there is no separate `standalone` label in the new suite (the legacy split was an artifact of the meta-review/atomic-skill design).

## Execution model context (per cross-cutting rule 3)

- **Sonnet subagents** run all lenses. Spawn via the `Agent` tool with `subagent_type: "general-purpose"`.
- **Main thread** handles SAST pre-scan (Phase 1.5), subagent dispatch, finding deduplication, and synthesis assembly.
- **No external review services.** This suite is local-only — no Codex, Copilot, Gemini, or cloud review APIs are invoked. The SAST pre-scan supplies deterministic anchor findings; everything else is Sonnet reasoning.

## Counter-review specifics

Counter-review is the one lens that doesn't scan code — it reviews the plan / context / architecture decisions. Its inputs are:
- `project-plan.md`
- `project-context.md`
- The most recent prior `review-synthesis-*.md` (if any) — counter-review checks that prior findings have been addressed

Its findings often refer to documents, not code. Location format: `project-plan.md:WU-N-M` or `project-context.md:§Section`.

## Confidence scoring (synthesis-time)

Confidence depends on how many sources agree:

| Sources agreeing | Confidence |
|---|---|
| 2+ lenses + SAST findings | HIGH |
| 2+ lenses | HIGH |
| 1 lens + SAST findings | MEDIUM |
| 1 lens, severity CRITICAL/HIGH | MEDIUM (preserved despite single source) |
| 1 lens, severity MEDIUM/LOW | LOW |

The synthesis (SKILL.md Phase 5) sorts findings by confidence × severity.

## Anti-patterns

- **Hallucinated all-clear**: a lens reports zero findings on a non-trivial codebase. Usually means the prompt was too narrow or the model hedged. Synthesis flags this for review.
- **Same finding restated by every lens**: dedup at synthesis time. The lens that flagged it FIRST keeps the citation; others get noted in passing.
- **Findings without recommendations**: surface as "INCOMPLETE" — every finding must have an actionable next step.
