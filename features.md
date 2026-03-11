# Features

> What this project does and will do. Updated as features are planned, built, and shipped.

| Feature | Status | Description | Added | Notes |
|---------|--------|-------------|-------|-------|
| Skill suite (38 skills) | done | Custom Claude Code skills for orchestration, review, research, deployment, lifecycle | 2026-03-06 | |
| Agent definitions (10 agents) | done | Specialized subagent prompts: api-tester, infra-debugger, db-admin, etc. | 2026-03-06 | |
| Hook system (7 hooks) | done | Session lifecycle hooks: start, stop, compact, pre-commit | 2026-03-06 | |
| Progressive disclosure architecture | done | 3-level system: metadata, SKILL.md body, bundled references/agents/scripts | 2026-03-10 | |
| SQLite+FTS5 artifact store | done | `artifacts/project.db` with `db.sh` helper for skill artifact persistence | 2026-03-10 | |
| CLI delegation (Codex/Gemini) | done | Multi-model orchestration with concurrency limits, timeout wrappers | 2026-03-11 | |
| Wave-gated execution (meta-execute) | done | Dependency-ordered wave execution with inter-wave review gates | 2026-03-11 | |
| Security review (OWASP Agentic) | done | P0/P1/P2 tiers, agent-specific patterns, supply chain checks | 2026-03-11 | |
| Review-fix pipeline | done | Post-review fix implementation with Codex/Sonnet workers | 2026-03-11 | |
| Meta-review Sonnet-primary | done | 7 Sonnet + 3 Codex + 2 Gemini = 12 reviews within concurrency limits | 2026-03-11 | |
| GitHub sync | done | Repo initialized and pushed to trevorbyrum/claude-skills-suite | 2026-03-11 | |
| test-review upgrade | done | Mutation testing, PBT, contract testing, strategy shapes, LLM anti-patterns, metrics | 2026-03-11 | 003D research applied. SKILL.md 273 lines + 6 reference files |
| meta-production upgrade | done | 12 dims (was 10), SLO/SLI, chaos, DORA, capacity, progressive delivery, supply chain, incident maturity | 2026-03-11 | 004D research applied. SKILL.md + 4 reference files |
| Review skill thin wrappers | planned | Shared logic for 7 review lenses, reduce duplication | 2026-03-07 | P0 from skill audit |
| Fresh-findings reuse | planned | Skip duplicate scans if results <24h old | 2026-03-07 | P1 — stops redundant work |
| Gemini in project-questions | planned | Domain/competitor research before user interview | 2026-03-07 | P1 |
| Codex in build-plan | planned | Generate skeleton files (interfaces, types, stubs) alongside plan | 2026-03-07 | P2 |
| meta-join quick mode | planned | Fast catch-up without full 7-step onboard | 2026-03-07 | P2 |
| Timeout guards for meta-skills | planned | Prevent infinite stalls on hung subagents | 2026-03-07 | P2 |
| Dependency audit skill | planned | Scheduled npm/cargo audit with Mattermost alerts | 2026-03-07 | Gap from skill audit |
| Performance profiling skill | planned | CPU/memory, flame graphs, bottleneck identification | 2026-03-07 | Gap from skill audit |
| Documentation audit skill | planned | Verify README/API/arch docs current vs code | 2026-03-07 | Gap from skill audit |
| Accessibility review skill | planned | WCAG, keyboard nav, screen reader for UI projects | 2026-03-07 | Gap from skill audit |
| Load/stress testing skill | planned | Benchmarks under simulated load, capacity planning | 2026-03-07 | Gap from skill audit |
| Breaking change detection skill | planned | Diff versions for API contract, DB schema, imports | 2026-03-07 | Gap from skill audit |
| Incident postmortem skill | planned | Structured capture: timeline, root cause, prevention | 2026-03-07 | Gap from skill audit |

## Status Legend

- `planned` — Scoped but not started
- `in-progress` — Actively being built
- `done` — Implemented and working
- `cut` — Removed from scope (note why)
