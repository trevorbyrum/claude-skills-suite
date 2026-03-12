---
name: meta-production
description: Scored production readiness assessment (READY / CONDITIONAL / NOT READY) across 12 dimensions. Use when asking "can we ship this?" Outputs artifacts/reviews/production-readiness.md.
---

# meta-production

Production Readiness Review (PRR) — a scored, evidence-backed assessment of
whether a project is safe to deploy to production. Based on cross-analysis of
6 PRR frameworks: Google SRE PRR, Cortex scorecards, OpsLevel rubrics,
Backstage Soundcheck, Port.dev, and GitLab PRR.

## Chain

```
[Phase 1: Stack Research]     Gemini — production patterns for this stack
[Phase 2: Parallel Scan]      7 review lenses (Sonnet) + production scan (5 Codex)
[Phase 3: Scoring]            Claude — score 12 dimensions from Phase 1-2 findings
[Phase 4: Report]             Write artifacts/reviews/production-readiness.md with verdict
```

## Inputs

| Input | Source | Required |
|---|---|---|
| project-context.md | Project root | Yes |
| features.md | Project root | Yes |
| project-plan.md | Project root | No |
| Source code | `src/` or equivalent | Yes |
| Existing review findings | Artifact DB (lens findings) | No (reused if fresh) |

## Service Criticality Tier

Before scoring, determine the service's criticality tier from project-context.md:

| Tier | Description | Dims 11-12 Weight | Example |
|---|---|---|---|
| **Critical** | User-facing, revenue-impacting, or safety-critical | Full weight | Payment API, auth service |
| **Standard** | Internal service with dependencies downstream | 70% weight | Data pipeline, admin API |
| **Low** | Internal tool, batch job, or early-stage prototype | 40% weight | CLI tool, cron job, dev utility |

Criticality affects scoring for Dims 11 (Reliability) and 12 (Capacity) only.
A batch job doesn't need SLOs or load tests — don't penalize it for that.
Dims 1-10 apply equally regardless of tier.

## Scoring System

### 12 Dimensions (0-10 each, 120 total)

| # | Dimension | What It Measures | Primary Source |
|---|---|---|---|
| 1 | **Code Completeness** | No stubs, TODOs, placeholders, incomplete implementations | completeness-review |
| 2 | **Code Quality** | No duplication, consistent patterns, no over-engineering, no truncation | refactor-review |
| 3 | **Security** | No secrets, deps audited, auth solid, input validated, OWASP + supply chain | security-review |
| 4 | **Testing** | Coverage adequate, no stub tests, error paths tested, mutation-aware | test-review |
| 5 | **Documentation Sync** | Docs match code, no drift in either direction | drift-review |
| 6 | **Compliance** | Follows documented rules + applicable regulatory controls | compliance-review |
| 7 | **Architecture** | Stack justified, no circular deps, scaling considered, resilient | counter-review |
| 8 | **Observability** | Logging, metrics, tracing, SLI-based alerting, cost-aware, correlation IDs | Production scan |
| 9 | **Deployment** | Progressive delivery, rollback, env config, graceful shutdown, supply chain | Production scan |
| 10 | **Operations** | Incident maturity, on-call health, rate limiting, circuit breakers, DORA infra | Production scan |
| 11 | **Reliability** | SLO/SLI defined, error budgets, chaos readiness, resilience tested | Production scan (NEW) |
| 12 | **Capacity** | Load test evidence, auto-scaling, capacity model, resource sizing | Production scan (NEW) |

### Scoring Rubric Per Dimension

| Score | Meaning |
|---|---|
| 9-10 | Excellent — production-grade, no issues |
| 7-8 | Good — minor issues, none blocking |
| 5-6 | Acceptable — notable gaps but workable with known risks |
| 3-4 | Concerning — significant gaps that need addressing |
| 1-2 | Poor — critical issues, not safe for production |
| 0 | Missing — dimension not addressed at all |

### Verdict Thresholds

| Total Score | Verdict | Meaning |
|---|---|---|
| 102-120 (85%+) | **PRODUCTION READY** | Ship it. Minor items can be addressed post-launch. |
| 84-101 (70-84%) | **CONDITIONALLY READY** | Can ship if listed conditions are met first. |
| 60-83 (50-69%) | **NOT READY** | Significant work required. Remediation plan provided. |
| 0-59 (<50%) | **BLOCKED** | Critical failures. Do not deploy under any circumstances. |

**Override rule**: Any single dimension scoring 0-2 forces a maximum verdict
of CONDITIONALLY READY regardless of total score. A single critical gap can
sink a deployment.

## Instructions

### Phase 1: Stack Research (Gemini)

Before scanning code, research production best practices specific to this
project's tech stack. Read `project-context.md` to identify the stack and
determine the service criticality tier.

Load `/gemini` for invocation syntax. Key params: 120s timeout, prompt:
`"Research production readiness best practices for a [STACK] application.
Cover: deployment patterns (blue/green, canary, progressive delivery),
observability (SLI-based alerting, OpenTelemetry, cost-aware),
security hardening (supply chain, runtime security, network policies),
SLO/SLI definition, chaos engineering readiness, capacity planning,
incident response maturity, and common production antipatterns.
Be specific to this stack — not generic advice.
Project context: [first 3 sections of project-context.md]"`.
Replace `[STACK]` with the actual tech stack from project-context.md.
Output to `/tmp/prr-stack-research.md`.

If Gemini is unavailable or fails, retry with Copilot — load `/copilot`
for invocation syntax. Same prompt, same output file.
If both Gemini and Copilot fail, use Claude WebSearch. Stack research is NOT
optional — the production-specific checks in Phase 2 use these findings.

### Phase 2: Parallel Scan

Fan out all scans simultaneously. Three tracks run in parallel:

#### Track A: Review Lenses (7 Sonnet Subagents)

Check the artifact DB for fresh lens findings:

```bash
source artifacts/db.sh
AGE=$(db_age_hours 'security-review' 'findings' 'sonnet')
# Repeat for other lenses
```

If `$AGE` is non-empty and < 24, reuse those findings instead of re-running that lens.

For each lens that needs running, spawn a Sonnet subagent using the
`review-lens` agent (`subagent_type: "review-lens"`). Pass each lens its
specific instructions from the corresponding skill:

1. `completeness-review` → Dimension 1
2. `refactor-review` → Dimension 2
3. `security-review` → Dimension 3
4. `test-review` → Dimension 4
5. `drift-review` → Dimension 5
6. `compliance-review` → Dimension 6
7. `counter-review` → Dimension 7

Each review-lens subagent stores its output in DB as `db_upsert '{lens}' 'findings' 'sonnet' "$CONTENT"`.

#### Track B: Production Antipattern Scan (5 Codex Workers)

Fan out 5 Codex instances — one per production dimension (Dims 8-12).
Uses all 5 available Codex slots.

Load `/codex` for invocation syntax. Key params for all 5 workers:
`--sandbox read-only`, `--ephemeral`, `--cd /path/to/project`, 120s timeout.

Read `references/production-scan-prompts.md` for prompts for Dims 8-10.
Read `references/reliability-capacity-prompts.md` for prompts for Dims 11-12.

Launch all 5 in parallel. Output each to `/tmp/prr-{dimension}.md`.

**Workers 1-3** — Observability (8), Deployment (9), Operations (10):
prompt from `references/production-scan-prompts.md`.

**Workers 4-5** — Reliability (11), Capacity (12):
prompt from `references/reliability-capacity-prompts.md`.

Wait for all 5 and store in DB:

```bash
source artifacts/db.sh
for dim in observability deployment operations reliability capacity; do
  wait $CODEX_PID
  db_upsert 'meta-production' 'scan' "$dim" "$(cat /tmp/prr-$dim.md)"
  rm /tmp/prr-$dim.md
done
```

If Codex is unavailable, run these 5 checks as Sonnet subagents instead.
Less depth but still covers the patterns via grep and file analysis.

#### Track C: Production Research Cross-Reference (Gemini)

While Track A and B run, have Gemini cross-reference the stack research
(Phase 1) against the project's actual implementation:

Load `/gemini` for invocation syntax. Key params: 120s timeout, prompt:
`"Compare these production best practices against the actual codebase.
For each practice, mark it as: IMPLEMENTED, PARTIALLY IMPLEMENTED, or MISSING.
Cite specific files and lines.
Best practices: $(cat /tmp/prr-stack-research.md)
Focus on the top 20 most critical practices for this stack."`.
Output to `/tmp/prr-practices.md`. Then store in DB:
```bash
source artifacts/db.sh
db_upsert 'meta-production' 'scan' 'practices-audit' "$(cat /tmp/prr-practices.md)"
rm /tmp/prr-practices.md
```

If Gemini is unavailable or fails, retry Track C with Copilot — load `/copilot`
for invocation syntax. Same prompt, same output file and DB storage step.
If both Gemini and Copilot fail, skip this track. It enriches the report but
isn't required for scoring.

### Phase 3: Scoring

After all Phase 2 scans complete, score each dimension.

**For Dimensions 1-7** (review lenses):

Read lens findings from the artifact DB:

```bash
source artifacts/db.sh
COMPLETENESS=$(db_read 'completeness-review' 'findings' 'sonnet')
REFACTOR=$(db_read 'refactor-review' 'findings' 'sonnet')
SECURITY=$(db_read 'security-review' 'findings' 'sonnet')
TEST=$(db_read 'test-review' 'findings' 'sonnet')
DRIFT=$(db_read 'drift-review' 'findings' 'sonnet')
COMPLIANCE=$(db_read 'compliance-review' 'findings' 'sonnet')
COUNTER=$(db_read 'counter-review' 'findings' 'sonnet')
```

Score based on:

| Findings | Score |
|---|---|
| 0 CRITICAL, 0 HIGH | 9-10 |
| 0 CRITICAL, 1-2 HIGH | 7-8 |
| 0 CRITICAL, 3+ HIGH or 1 CRITICAL | 5-6 |
| 2+ CRITICAL or 5+ HIGH | 3-4 |
| 3+ CRITICAL | 1-2 |
| Lens not run / no data | 0 |

Adjust within the range based on MEDIUM/LOW count and finding severity.

**For Dimensions 8-10** (production scans):

```bash
source artifacts/db.sh
OBSERVABILITY=$(db_read 'meta-production' 'scan' 'observability')
DEPLOYMENT=$(db_read 'meta-production' 'scan' 'deployment')
OPERATIONS=$(db_read 'meta-production' 'scan' 'operations')
PRACTICES=$(db_read 'meta-production' 'scan' 'practices-audit')
```

| Findings | Score |
|---|---|
| Category fully addressed, patterns implemented | 9-10 |
| Most items addressed, 1-2 minor gaps | 7-8 |
| Some items addressed, notable gaps | 5-6 |
| Few items addressed, significant gaps | 3-4 |
| Category barely addressed | 1-2 |
| No evidence of any production consideration | 0 |

**For Dimensions 11-12** (reliability + capacity, criticality-weighted):

```bash
RELIABILITY=$(db_read 'meta-production' 'scan' 'reliability')
CAPACITY=$(db_read 'meta-production' 'scan' 'capacity')
```

Apply service criticality tier weighting. Read `references/slo-chaos-dora-checks.md`
for detailed scoring criteria per tier. Chaos readiness scores as a maturity
indicator — higher is better, but absence doesn't block.

**Cross-validation**: Compare each Codex worker's findings against the
Gemini practices audit (Track C). If they contradict, investigate. The more
conservative score wins unless you can verify the optimistic assessment.
When both agree, boost confidence to HIGH.

### Phase 4: Report

Read `references/report-template.md` for the full report structure, then
write `artifacts/reviews/production-readiness.md` following that template.

### Post-Report

After writing the report, present the user with:

1. The verdict and total score
2. The scorecard table
3. The critical blockers (if any)
4. Top 3 remediation items

Then offer next steps:

> "Production readiness assessment complete.
>
> 1. **Fix blockers** — address the P0 items and re-run `/meta-production`
> 2. **Detailed dive** — review a specific dimension in depth
> 3. **Accept risk** — proceed to deployment with documented gaps
> 4. **Full review** — run `/meta-review` for the complete review sweep"

## Reuse of Existing Reviews

Check the artifact DB for fresh lens findings using `db_age_hours`. For each lens:

```bash
source artifacts/db.sh
AGE=$(db_age_hours '{lens}' 'findings' 'sonnet')
```

If `$AGE` is non-empty and < 24, reuse that lens's findings instead of re-running it.
This allows the user to run `/meta-review` first for the full review treatment,
then run `/meta-production` which picks up those findings from the DB and adds the
production-specific dimensions (8-12) and scoring.

If existing findings are older than 24 hours (or absent), re-run those lenses — the
codebase may have changed.

## Error Handling

- If Gemini is unavailable: try Copilot as fallback for stack research (Phase 1)
  and Track C (practices audit). If both fail, use Claude WebSearch for Phase 1
  and skip Track C. Note in methodology section.
- If Codex is unavailable: run production antipattern checks as Sonnet
  subagents instead. Note reduced scan depth in methodology.
- If both are unavailable: all scans run via Sonnet subagents. The report
  is still valid but note "single-model assessment" in methodology and
  reduce confidence in Dimensions 8-12 scoring.
- If a review lens fails: score that dimension 0 and note "assessment
  incomplete" in the scorecard.

## Examples

```
User: "Is this ready for production?"
Action: Read project-context.md for stack + criticality tier. Phase 1 — Gemini
        researches production patterns. Phase 2 — 7 review lenses + 5 Codex
        production scans + Gemini practices audit. Phase 3 — score all 12
        dimensions (weight Dims 11-12 by tier). Phase 4 — write report.
```

```
User: "/meta-production"
Action: Full PRR flow. All 4 phases, 12 dimensions.
```

```
User: "We already ran a full review, just check production readiness"
Action: Check artifact DB for fresh lens findings (db_age_hours < 24). Reuse
        for Dims 1-7. Run only production scans (5 Codex + Gemini) for Dims
        8-12. Score and report.
```

```
User: "Re-check production readiness after fixing the blockers"
Action: Re-run only dimensions that scored below 7. Reuse passing dimensions.
        Update report with new scores and revised verdict.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
