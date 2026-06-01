# Build Plan — From-Scratch Mode

For greenfield plans where no `project-plan.md` exists, or a clean rewrite.

## Phase structure

Break the project into 3-6 phases. Each phase delivers something usable or testable — avoid phases that are purely preparatory with no visible output.

Typical pattern (adapt to the project):

- **Phase 1: Foundation** — core data model, project setup, basic API or skeleton
- **Phase 2: Core features** — the primary value proposition
- **Phase 3: Integration** — external systems, auth, real data
- **Phase 4: Polish** — UI refinement, error handling, edge cases, performance
- **Phase 5: Ship** — deployment, monitoring, documentation, launch

Some projects need a research spike as Phase 1. Others can skip integration. Match phases to the actual work.

## Milestones

Each phase gets 1-2 milestones. A milestone is a concrete, testable statement:
- Bad: "Auth is done"
- Good: "User can log in and see their dashboard"

Milestones are the checkpoints that tell the user (and future agents) whether the project is on track.

## Risks

Pull from: research synthesis, Phase 2 technical feasibility check, and your own analysis.

For each risk:
- What could go wrong
- Likelihood (high/medium/low)
- Impact (high/medium/low)
- Mitigation strategy

## Technical approach

For each major component (auth, data layer, API, UI, etc.), describe the approach in 3-5 sentences. Reference research findings where applicable.

This is not full architecture docs — it's enough for an agent to start implementing without guessing at strategy.

## Plan-file structure

```markdown
# Project Plan — <project-name>

Generated: <date>
Based on: project-context.md[, research synthesis path]

## Executive Summary
[3-5 sentences: what, how many phases, key risks, estimated total effort]

## Phases and Milestones
[Phase table with milestones and target dates if timeline is known]

## Technical Approach
[Per-component approach descriptions]

## Work Units
[Full table of all work units with all fields from SKILL.md Phase 3]

## Dependency Graph
[Text DAG or table showing unit dependencies and critical path]

## Risks
[Risk table: likelihood, impact, mitigation]

## Competitive Insights
[Key takeaways from landscape analysis, if available]

## Open Items
[Anything unresolved that needs user input before work begins]

## Changelog
[Newest-first list of plan revisions. First entry: "Initial plan — <date>"]
```

## Dependency graph

Draw the dependency DAG as text or a table. Identify the **critical path** — the longest chain of sequential work units. This sets the minimum project duration regardless of parallelism.

If the critical path is unexpectedly long (>60% of total WUs), look for false dependencies — units claimed dependent that could actually parallelize.
