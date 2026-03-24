# Research Synthesis: Project Pivot & Scope Reduction Skill Design

> Research run: 010
> Sources: 44 queries | 410 scanned | 126 cited
> Date: 2026-03-24

## Executive Summary

1. **Dead code detection is a solved problem for JS/TS and compiled languages** but remains imprecise for dynamic languages. Knip (JS/TS) and dependency-cruiser provide the strongest foundation. Meta's SCARF system (104M+ lines deleted) proves the multi-signal approach (static + runtime + business context) works at extreme scale.

2. **The expand-contract pattern is the universal safe removal strategy** for data and schemas. Feature flag lifecycle management (develop → ramp → stabilize → teardown) provides the operational framework. Monthly reviews of flags at 100% rollout surface removal candidates automatically.

3. **Dependency graph analysis enables blast radius estimation** before any removal. Reachability analysis from entry points identifies unreachable code. Orphan detection finds isolated modules. Bottom-up removal order (leaves first) minimizes cascading failures.

4. **Documentation-driven deletion is the novel contribution** of meta-pivot. No existing tool treats project docs (context, plan, features) as the authoritative source for what code SHOULD exist. The gap between docs and code = removal candidates. This integrates naturally with the existing drift-review skill.

5. **AI-assisted removal works best as a hybrid**: deterministic tools first (knip, OpenRewrite, compiler warnings) for high-confidence removals, then LLM agents for intent analysis and rewrite suggestions. Kiro (AWS) demonstrates that IDE language servers provide safer refactoring than LLM guessing alone.

6. **Incremental removal decisively beats big-bang** across all research sources. Progressive rollouts with feature flags, characterization tests before removal, automated rollback, and real-time monitoring form the standard risk mitigation stack.

7. **Organizational pivot requires structured triage**: RICE scoring for objective ranking, MoSCoW for scope boundaries, Kano for user value validation. Decision logging via ADRs creates an audit trail. The Lean Startup "Zoom-In Pivot" pattern (one feature becomes entire offering) maps directly to scope reduction.

8. **Project restructuring has a 21% success rate** (McKinsey). The Strangler Fig pattern (incremental replacement behind a facade) dramatically improves outcomes. Keep refactoring separate from feature changes. Rule of three for deciding when to restructure.

## Per-Topic Synthesis

### Topic 1: Dead Code Elimination at Scale (P0) — Confidence: HIGH

**Tools by language:**
- JS/TS: Knip (primary), dependency-cruiser (validation), madge (visualization)
- Python: Vulture, Skylos (hybrid static+LLM), Scrounger (Rust-based, faster)
- Java: OpenRewrite recipes, Jarviz (bytecode analysis)
- Multi-language: Tree-sitter (AST across 40+ languages), Depends (syntactical relations)
- Polyglot: Deadcode-Detective (JS/TS/Python combo)

**Key patterns for skill encoding:**
- Phase 1 (automated): Run language-specific detectors, aggregate candidates
- Phase 2 (scoring): Cross-reference with runtime data, test coverage, last-modified dates
- Phase 3 (human review): Present ranked candidates with confidence scores
- Phase 4 (execution): Knip --fix for JS/TS, OpenRewrite recipes for Java, custom scripts for others

**False positive mitigation:**
- Whitelist files for intentionally dormant code
- Cross-validate static analysis with runtime telemetry (SCARF approach)
- Confidence scoring: high (static + runtime agree), medium (static only), low (heuristic only)

### Topic 2: Feature Removal & Scope Reduction Patterns (P0) — Confidence: HIGH

**Feature flag teardown lifecycle:**
1. Flag at 100% rollout for 1+ month with no issues → candidate for removal
2. Grace period (2-4 weeks) for developers to remove references
3. Remove flag code, keeping only the "on" path
4. Clean up associated configuration/dashboard entries

**Database/schema removal (expand-contract):**
1. Expand: Add new columns/tables alongside old ones
2. Migrate: Dual-write, backfill new structures
3. Contract: Drop old structures after verification

**Backward compatibility decision framework:**
- Security fixes → prioritize removal with mitigation path
- Cost of maintaining compat > long-term benefit → plan deprecation
- 6-12 month deprecation notice, migration guides, consumer coordination

### Topic 3: Project Restructuring After Direction Change (P0) — Confidence: MEDIUM

**When to restructure:**
- Orphan detection shows isolated module clusters
- Reachability analysis reveals unreachable code from new entry points
- Directory structure contradicts new project scope
- Rule of three: third time you encounter friction, restructure

**Strangler Fig for code restructuring:**
- Create facade/proxy layer routing to old or new module locations
- Migrate module by module behind the facade
- Remove old locations after verification
- Maintains business continuity throughout

**Monorepo patterns:**
- Group by scope/domain, not by language or technology
- @project/domain namespacing for workspace modules
- Nx generators for automated project moves

### Topic 4: Documentation-Driven Refactoring (P1) — Confidence: MEDIUM

**Novel contribution — "Plan as Deletion Signal":**
- Load project-context.md + features.md + project-plan.md
- Diff against actual codebase (files, exports, routes, schemas)
- Items in code but NOT in docs → removal candidates
- Items in docs but NOT in code → implementation gaps
- This is the core differentiator of meta-pivot vs generic cleanup tools

**Integration with existing skills:**
- drift-review already compares code against docs
- meta-pivot extends this with a deletion-oriented lens
- ADRs document why removals were made (immutable records)

**Gap:** No mature tooling exists for this pattern. This is greenfield for meta-pivot.

### Topic 5: AI-Assisted Code Removal & Rewriting (P1) — Confidence: HIGH

**Layered approach (deterministic → LLM → human):**
1. Deterministic tools: Knip, OpenRewrite, compiler warnings — zero false positives
2. LLM analysis: Understand intent of flagged code, suggest rewrites for remaining code
3. Human review: Final approval, especially for ambiguous cases

**Tool integration for meta-pivot:**
- Knip (JS/TS) + OpenRewrite (Java) + Vulture (Python) for detection
- Claude Code / Codex / Copilot for analysis and rewrite suggestions
- Kiro-style IDE integration for safe rename/move operations

**Key insight from research:**
Refactoring is a constraint satisfaction problem, not a pattern matching problem. LLMs alone are insufficient — they need deterministic tooling for the mechanical parts and human oversight for the judgment calls.

### Topic 6: Risk Mitigation During Large-Scale Removal (P1) — Confidence: HIGH

**Testing strategy:**
1. Characterization tests: Capture current behavior before removal
2. Run full test suite after each removal wave
3. Monitor for regressions in staging before production
4. Keep removed code in a revert branch for 30 days

**Rollback strategy:**
- Git branch per removal wave for instant rollback
- Feature flags as kill switches for removed features
- Automated rollback on metric degradation
- Roll-forward > rollback when possible (add back specific pieces vs full revert)

**Incremental wave pattern:**
- Wave 1: Dead code (zero dependencies, zero runtime references) — safest
- Wave 2: Orphaned modules (no incoming deps but may have outgoing) — low risk
- Wave 3: Deprecated features (has deps but flagged for removal) — medium risk
- Wave 4: Restructuring moves (live code changing location) — highest risk

### Topic 7: Dependency Graph Analysis for Removal Impact (P0) — Confidence: HIGH

**Graph construction tools:**
- JS/TS: dependency-cruiser (rules-based), madge (visualization)
- Java: Jarviz (bytecode-level)
- Multi-language: Depends, tree-sitter-based custom analyzers
- Visualization: CodeLayers (VS Code), Graphviz (custom)

**Analysis patterns for meta-pivot:**
1. Reachability analysis: Trace from entry points → unreachable = safe to remove
2. Orphan detection: Files with zero incoming + outgoing deps
3. Blast radius calculation: For each removal candidate, count transitive dependents
4. Dependency density mapping: Identify high-density clusters (redesign before removal)
5. Bottom-up removal order: Remove leaves first, then branches, then trunks

**Dependency-cruiser rules for meta-pivot:**
- `no-orphans`: Warn on isolated files
- `no-unreachable-from-root`: Error on unreachable from entry
- `numberOfDependentsLessThan`: Scoped orphan detection within directories

### Topic 8: Organizational Pivot Process (P0) — Confidence: HIGH

**Feature triage sequence:**
1. RICE score each feature/module (Reach, Impact, Confidence, Effort)
2. MoSCoW categorize (Must Have, Should, Could, Won't for new direction)
3. Kano stress-test (ensure basics covered, identify delighters)
4. Stakeholder alignment (map interests, convene, negotiate, decide)
5. Decision log (ADR format: ID, Date, Context, Decision, Consequences)

**Communication framework:**
- Explain WHY pivot is happening (business context)
- Show WHAT is being removed (specific list with rationale per item)
- Describe HOW remaining work benefits from the reduction
- Document decisions immutably (never edit, supersede with new record)

**Lean Startup integration:**
- Zoom-In Pivot: One feature becomes the entire offering
- Move quickly, commit fully, communicate clearly
- Document learnings from removed code (they're still valuable)

## Confidence Map

| Topic | Confidence | Source Agreement | Tool Maturity |
|-------|-----------|-----------------|---------------|
| 1. Dead code elimination | HIGH | Strong | Mature (knip, vulture, SCARF) |
| 2. Feature removal patterns | HIGH | Strong | Mature (expand-contract, flags) |
| 3. Project restructuring | MEDIUM | Moderate | Partial (strangler fig, but low success rates) |
| 4. Doc-driven refactoring | MEDIUM | Novel area | Immature (opportunity) |
| 5. AI-assisted removal | HIGH | Strong | Maturing (Kiro, OpenRewrite, Claude) |
| 6. Risk mitigation | HIGH | Strong | Mature (DevOps patterns) |
| 7. Dependency graph analysis | HIGH | Strong | Mature (dep-cruiser, madge) |
| 8. Organizational pivot | HIGH | Strong | Mature (MoSCoW, RICE, ADRs) |

## Gaps and Low-Confidence Areas

1. **Documentation-as-deletion-signal tooling does not exist** — meta-pivot would be first-of-kind. No prior art to validate against. Risk: may produce too many false positives if docs are stale.

2. **Multi-language dead code detection lacks a unified orchestrator** — each language has its own tool. No single tool covers JS/TS + Python + Go + Java. Tree-sitter provides a foundation but requires custom rule development.

3. **Confidence scoring for removal candidates has no standard** — Meta's SCARF uses multi-signal but is internal. No open-source equivalent of their confidence model.

4. **Project restructuring success rate is low (21%)** — even with good tools, the organizational and communication aspects frequently fail. Meta-pivot must prioritize human gates and stakeholder alignment.

5. **Feature flag cleanup tooling is mostly SaaS-internal** — LaunchDarkly, Statsig, ConfigCat handle this in their platforms. No good open-source standalone tool for flag lifecycle management.

## Implications for meta-pivot Skill Design

### Proposed Phase Sequence

1. **Scope Analysis** (automated): Load project docs, build dependency graph, run dead code detectors, map code-to-doc alignment
2. **Triage** (human-gated): Present RICE-scored removal candidates with blast radius. User applies MoSCoW categorization.
3. **Decision Logging** (human): Stakeholders approve cuts. Each decision logged as ADR with rationale.
4. **Removal Planning** (automated): Generate removal waves ordered by risk (dead code → orphans → deprecated → restructuring). Create characterization tests.
5. **Execution** (automated with gates): Execute wave-by-wave. Run tests after each wave. Human approves progression.
6. **Verification** (automated): Run drift-review to confirm code matches updated docs. Run full test suite. Monitor metrics.
7. **Documentation Update** (automated): Update project-context.md, features.md, project-plan.md to reflect new reality.

### Key Integration Points with Existing Skills

| Existing Skill | Integration |
|---|---|
| drift-review | Phase 1 (scope analysis) — extend with deletion lens |
| clean-project | Phase 1 — structural bloat detection feeds removal candidates |
| refactor-review | Phase 5 — code quality check after removals |
| breaking-change-review | Phase 4 — detect breaking changes in removal plan |
| counter-review | Phase 3 — adversarial challenge of removal decisions |
| evolve | Phase 7 — doc updates after removal |

### What Can Be Automated vs. What Requires Human Judgment

| Automated | Human Required |
|---|---|
| Dead code detection | Dormant-vs-dead distinction |
| Dependency graph construction | Scope boundary decisions |
| Blast radius calculation | Stakeholder alignment |
| Characterization test generation | Feature triage (MoSCoW) |
| Wave execution | Wave progression approval |
| Doc-code diff | Removal rationale documentation |
| Metric monitoring | Rollback decisions |

## Challenges and Caveats (from Triple-Counter Review)

The following concerns were raised by adversarial reviewers (Sonnet subagent + Gemini CLI) and are integrated here as required corrections and caveats.

### Corrections to Original Claims

1. **"Dead code detection is solved" is overclaimed.** More accurately: *unused file/export/dependency detection* is mature for JS/TS. Within-function dead code (unreachable branches, dead conditions) and dynamically-loaded code remain hard. For Python/Ruby, tools are heuristic, not definitive. The skill should present detection results as *candidates* with confidence levels, never as certainties.

2. **The McKinsey 21% statistic is about organizational restructuring, not code restructuring.** Code file moves with proper tooling (Nx generators, IDE refactoring) have much higher success rates. The stat applies to the *communication and alignment* dimensions of Phase 3, not to the technical execution in Phases 4-5.

3. **"Universal" expand-contract is narrower than claimed.** It applies to data/schema changes specifically. Removing entire features, services, UI components, or API endpoints requires different strategies (feature flags for runtime, branch-based for source). The skill must match the removal strategy to the artifact type.

4. **RICE scoring cannot be directly mapped to code modules.** RICE was designed for product features. "Reach" and "Impact" don't have obvious code-metric equivalents. The skill should use a modified scoring system: *Usage frequency* (replaces Reach), *Blast radius* (replaces Impact), *Test coverage* (replaces Confidence), *Lines of code* (replaces Effort).

### Missing Dimensions to Address in Skill Design

1. **Configuration-as-code removal.** The synthesis focuses on source code but ignores Terraform, Docker, CI/CD configs, k8s manifests, and build artifacts that accumulate dead config after pivots. Phase 1 should scan these as well.

2. **Git itself is the ultimate rollback.** The wave pattern with feature flags may be over-engineering for pre-production codebases. The skill should detect whether the project is in production and adjust risk mitigation accordingly: production = full wave protocol; pre-production = simpler branch-and-verify approach.

3. **Stale documentation bootstrapping.** The "plan as deletion signal" pattern assumes docs are accurate. At pivot time, docs are often the most stale. The skill MUST include a "doc freshness check" phase before relying on docs for deletion signals. If docs are stale, flag it and require doc update (via /evolve) before proceeding.

4. **Minimum viable skill scope.** The 7-phase design may be too heavy for v1. Consider shipping Phases 1-2 (analysis + triage) first, with execution phases added in v2. If the skill takes longer to run than manual deletion, teams will not adopt it.

5. **Performance at scale.** Running knip + dependency-cruiser + tree-sitter + doc-code diff on 100K+ file codebases could be very slow. The skill should support incremental analysis (only changed files since last run) and timeout guards.

6. **Missing language-specific tool coverage.** The synthesis should have named: `go vet` (Go), `rustc` warnings + `cargo udeps` (Rust), `-Wunreachable-code` (C/C++), `deadcode` (Go). These fill the multi-language gap.

### Counter Status

- **Sonnet counter**: Complete. 4 unsupported claims, 4 missing perspectives, 2 contradictions, 4 unasked questions.
- **Gemini counter**: Complete. Raised 8 categories of challenges, especially around documentation staleness vulnerability and tool integration complexity.
- **Codex counter**: Pending (concurrency slots occupied). Findings will be integrated if available before session ends.
