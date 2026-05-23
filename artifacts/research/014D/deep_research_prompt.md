# Deep Research Prompt — 014D

## Research Question
How should the Claude Skills Suite (54 skills, 10 agents, 8 hooks) be restructured — through consolidation, architectural rethink, and storage migration — to close compliance gaps (cnotes/coterie not followed), support iterative development phases, eliminate redundancy, and move artifact storage to server-side PostgreSQL/Qdrant?

## Sub-Questions

1. **Why are cnotes/coterie rules not followed?** The CLAUDE.md template references them, cross-cutting-rules.md mandates them (rules 1-2), but Claude doesn't write cnotes in practice. Is the 13-field schema too heavy? Is the "read before completing" pattern too late? Should cnotes be enforced via hooks instead of instructions? Should they move to SQLite/PostgreSQL?

2. **What skill covers iterative development?** The lifecycle has init → plan → execute → review but no skill for the "tweaking phase" — ad-hoc changes, debugging, small features where meta-execute is overkill but you still want structure (plan tracking, context updates, cnotes). What would a lightweight execution skill look like?

3. **How should review/gen skill pairs work?** test-review + test-gen, log-review + log-gen exist as separate skills. Should review skills auto-offer generation? Should gen skills be absorbed into their review counterparts?

4. **Should review lenses be config-driven?** 14 review skills share review-lens-framework.md. Could they be a single parameterized skill with lens configs instead of 14 separate SKILL.md files? What's the trade-off?

5. **How to eliminate reference duplication?** cross-cutting-rules.md is copied into ~47 skill references/ dirs. Symlinks? Single-source reads? What pattern works best with Claude Code's progressive disclosure?

6. **Should meta-context-save become periodic + immutable?** User wants: (a) periodic auto-save that doesn't require manual invocation, (b) immutable snapshots that never get overwritten (current db_upsert overwrites). How to implement both?

7. **Where should artifacts live?** Current: local SQLite+FTS5. Proposed: research → PostgreSQL on Unraid server, vector embeddings → Qdrant on server. Questions: per-project Qdrant collections or shared? What goes in PG vs Qdrant vs local? How to handle the GPU being down (no local embeddings)?

8. **Hook architecture**: 4 identical session-start hooks. Should unify. Also: should cnotes enforcement be a hook (post-edit or stop) rather than an instruction? What other hooks are missing?

9. **Skill taxonomy**: Current categories (meta/atomic/review/driver/lifecycle/infra) — are these optimal? Some skills are miscategorized (browser-review is "research" but acts as review lens, sub-project is listed as both meta and lifecycle).

10. **What's missing?** What capabilities do modern AI-assisted dev workflows need that this suite lacks? Consider: monitoring/observability integration, CI/CD pipeline skills, automated regression detection, context-aware code completion hints.

## Scope
- Breadth: exhaustive — this is an architectural rethink, not incremental cleanup
- Time horizon: include historical (how other AI dev tool suites and plugin systems evolved) + cutting edge (2025-2026 patterns)
- Domain constraints: Claude Code skill system, AI-assisted development tooling, plugin/extension architectures, artifact storage patterns

## Project Context
**Claude Skills Suite** — 54 skills for Claude Code orchestrating multi-model workflows (Claude, Codex, Gemini, Cursor, Vibe, Copilot). Solo developer (Trevor Byrum). Homelab infrastructure: Unraid tower, Docker, Traefik, Vault, PostgreSQL, Qdrant, MongoDB, Redis, Neo4j. GPU currently down. Key patterns: progressive disclosure, subagent delegation, artifact DB (SQLite+FTS5), cross-cutting rules, driver skill boundary.

**Sacred skills** (user confirmed, do not recommend removing): skill-forge, meta-init, meta-execute, meta-review, github-sync, github-pull, meta-context-save.

**Key pain points from user:**
- coterie/cnotes rules not followed by Claude despite being in cross-cutting-rules
- Skills sometimes not read when invoked (e.g., /codex)
- In-between tweaking phases have no structure — changes happen but docs/plans don't update
- meta-execute is overkill for small work but user wants its structure
- CLAUDE.md generation may be missing critical rules
- Review outputs should be stored in DB with only summaries visible
- Research should move to PostgreSQL, vectors to Qdrant

## Known Prior Research
- 001D-008D: various skill-specific deep research
- 009-010: regular research runs
- 011D-013D: recent deep research on accumulation DB and ingestion pipeline
- `deep-research-skill-audit.md`: earlier audit from 2026-03-07

## Output Configuration
- Research folder: artifacts/research/014D/
- Summary destination: artifacts/research/summary/014D-skill-suite-architecture-rethink.md
- Topic slug: skill-suite-architecture-rethink

## Special Instructions
- Challenge the assumption that more skills = better. Evaluate whether 54 skills creates cognitive overload vs. a smaller set of composable primitives.
- Research how other AI dev tool ecosystems (Cursor rules, Windsurf, Aider conventions, OpenHands) handle the "iterative tweaking phase" problem.
- Investigate whether cnotes compliance failure is a systemic issue with instruction-based enforcement vs. hook-based enforcement in LLM workflows.
- Look at prior research 012D (accumulation DB) and 013D (ingestion pipeline) for storage architecture decisions already made — build on those, don't contradict without evidence.
- The user's GPU is down — any Qdrant/embedding solution must work without local GPU (API-based embeddings or server-side).
- **Actively research coding agent workflow best practices and skill/plugin design patterns.** Look at: Claude Code's own skill system docs, Anthropic's agent SDK patterns, Devin/SWE-agent/OpenHands task decomposition, Cursor's rules/notepads system, Aider's conventions files, Windsurf's cascade rules, GitHub Copilot workspace flows. Find concrete examples of how these systems handle: skill composition, context management, iterative development loops, artifact storage, compliance enforcement, and progressive disclosure. This is a first-class research thread, not a side note.
