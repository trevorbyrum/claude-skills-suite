# Research Prompt — 010

## Scope Decision
Execute all — all 8 topics across all mapped connectors.

## Research Plan Reference
artifacts/research/010/research_plan.md (also in DB: research-plan/plan/010)

## Topics to Execute

### P0 — Blocks Skill Design

1. **Dead code elimination at scale** (Code lane)
   - Connectors: GitHub, Context7, Web Search
   - Intent: Static analysis tools (knip, ts-prune, vulture, deadcode), dependency graph walkers, tree-shaking beyond JS. How to distinguish dead code from dormant-but-needed code. Multi-language approaches.

2. **Feature removal & scope reduction patterns** (Both lane)
   - Connectors: Web Search, GitHub
   - Intent: How teams safely remove features post-pivot. Feature flag teardown lifecycle. Database table/column deprecation. Migration paths when cutting features that have persisted data. Backward-compat decision frameworks.

3. **Project restructuring after direction change** (Both lane)
   - Connectors: Web Search, GitHub, Context7
   - Intent: File reorganization strategies. Module consolidation patterns. Namespace cleanup. When to restructure (move/rename) vs leave in place. Monorepo-to-focused patterns. Directory flattening.

7. **Dependency graph analysis for removal impact** (Code lane)
   - Connectors: GitHub, Context7, Web Search
   - Intent: Tools for mapping call graphs, import graphs, data flow graphs. Understanding cascading removal effects. Blast radius estimation before cutting files/modules. Dependency visualization.

8. **Organizational pivot process** (Both lane)
   - Connectors: Web Search, GitHub
   - Intent: Feature triage frameworks (MoSCoW, RICE, Kano) applied to scope reduction. Stakeholder alignment on cuts. Decision logging for why things were removed. Communicating pivot to team. Process for negotiating what stays vs goes.

### P1 — Improves Quality

4. **Documentation-driven refactoring** (Both lane)
   - Connectors: Web Search, GitHub
   - Intent: Using project docs (plan, context, features) as source of truth for what code SHOULD exist. Drift detection as a deletion signal. "If it's not in the plan, should it be in the code?" patterns.

5. **AI-assisted code removal & rewriting** (Code lane)
   - Connectors: Web Search, GitHub, Context7
   - Intent: How LLM agents (Claude, Codex, Copilot, Cursor) can analyze codebases for removal candidates, plan removal sequences, execute deletions safely, rewrite remaining code for efficiency. Multi-agent orchestration for large refactors.

6. **Risk mitigation during large-scale removal** (Both lane)
   - Connectors: Web Search, GitHub
   - Intent: Testing strategies (characterization tests before removal, regression after). Rollback plans (git strategies, feature flags as kill switches). Incremental vs big-bang removal. Confidence scoring for removal candidates. Canary approaches.

## Project Context Summary

**Claude Skills Suite** — 42+ skills for Claude Code orchestrating multi-model dev workflows. The target skill being designed ("meta-pivot") will be a meta-skill that helps users pare down projects after direction changes. It needs to deeply analyze the project, understand the new direction, identify removable code/files, propose restructuring, execute safely with human gates, and verify with drift-review.

Existing related skills: clean-project (structural bloat), drift-review (doc-code alignment), refactor-review (code quality), evolve (doc updates), breaking-change-review (API breaks), counter-review (adversarial analysis).

## Source Counting Target
Target: 300+ sources scanned across all connectors.
Each connector subagent must follow the multi-query protocol (3-5 queries per topic) and include a Source Tally table in its output.

## Output Configuration
- Research folder: artifacts/research/010/
- Summary destination: artifacts/research/summary/010-pivot-scope-reduction.md
- Source tally: artifacts/research/010/source-tally.md (also DB: research-execute/source-tally/010)

## Special Instructions
- Focus on ACTIONABLE patterns that can be encoded as skill phases — not just theory
- For each topic, identify what could become an automated phase vs what requires human judgment
- Pay special attention to ordering/sequencing — what must happen before what in a pivot workflow
- Look for real-world case studies of large-scale code removal and project pivots
- The skill must work across languages (not just JS/TS) — prioritize language-agnostic approaches
- Include both technical (code) AND organizational (process) dimensions — the user explicitly wants both
