# Research Plan — 010: Project Pivot & Scope Reduction Skill Design

## Topics

| # | Topic | Priority | Lane | Connectors |
|---|-------|----------|------|------------|
| 1 | Dead code elimination at scale — static analysis, dependency graphs, tree-shaking across languages | P0 | Code | GitHub, Context7, Web Search |
| 2 | Feature removal & scope reduction patterns — safe feature cuts, flag teardown, migration paths, DB cleanup | P0 | Both | Web Search, GitHub |
| 3 | Project restructuring after direction change — file reorg, module consolidation, namespace cleanup | P0 | Both | Web Search, GitHub, Context7 |
| 4 | Documentation-driven refactoring — docs as source of truth for what code should exist, drift as deletion signal | P1 | Both | Web Search, GitHub |
| 5 | AI-assisted code removal & rewriting — LLM orchestration for large-scale removal, safety checks, human gates | P1 | Code | Web Search, GitHub, Context7 |
| 6 | Risk mitigation during large-scale removal — testing, rollback, incremental vs big-bang, confidence scoring | P1 | Both | Web Search, GitHub |
| 7 | Dependency graph analysis for removal impact — call graphs, import graphs, cascading effect mapping | P0 | Code | GitHub, Context7, Web Search |
| 8 | Organizational pivot process — stakeholder alignment, scope negotiation, feature triage frameworks (MoSCoW, RICE), communicating what's cut and why, decision logging | P0 | Both | Web Search, GitHub |

## Connector Allocation

| Connector | Topics | Subagents |
|-----------|--------|-----------|
| Web Search | 1,2,3,4,5,6,7,8 | 3 |
| GitHub | 1,2,3,4,5,6,7,8 | 2 |
| Context7 | 1,3,5,7 | 1 |

Total: 6 subagents. All Code/Both lane.
