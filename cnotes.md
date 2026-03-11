# Collaboration Notes

> Newest first. Each note is locked once a newer note exists above it.
> Format: `CN-YYYYMMDD-HHMMSS-AUTHOR`

## Notes (Newest First)

### CN-20260311-221000-CLAUDE
- Pushed to GitHub: 435099f (27 files, +5513 lines)
- Semgrep MCP added to ~/.mcp.json (local, no API cost)
- Handoff stored in qdrant memory for home Claude pickup
- Remaining for next session: SonarQube MCP connection (needs tower IP + token), meta-review SAST integration, pre-commit hook test

### CN-20260311-220000-CLAUDE
- Installed 5 local tools: ruff 0.15.5, semgrep 1.154.0, gitleaks 8.30.0, biome 2.4.6, oxlint 1.53.0
- Deployed SonarQube Community Edition on Unraid (container: sonarqube, port 9000, no web exposure)
- Recipe stored in Vault for redeployment
- Rewrote pre-commit hook: 3-phase (Gitleaks → Ruff/Biome/oxlint → Codex)

### CN-20260311-213500-CLAUDE
- Deep research 005D (free tools augmentation) completed — 66 queries, ~654 scanned, ~256 cited
- 10 sub-questions: static analysis, MCP servers, bug detection, testing, drift, security, emerging tools, observability, underutilized MCPs, tool pipelines
- 6 verified: Rust tools 10-100x faster, Hypothesis PBT 50x mutations, dual secret scanners, slopsquatting real, LLM+SAST hybrid 85-98% FP reduction
- 3 contested: "more tools = fewer bugs" (curated yes, uncurated no), MCP ecosystem maturity (vendor OK, community risky), ty replacing mypy (too early)
- 5 emergent topics: Rust tool revolution, SARIF unification, slopsquatting, LLM+SA hybrid, danger.js
- Underutilized existing MCPs: n8n, qdrant-memory, lmstudio, neo4j-plc, Playwright
- New MCP servers: SonarQube MCP (official), Semgrep MCP (official)
- Summary at: artifacts/research/summary/005D-free-tools-augmentation.md
- Next: user decides which tools/integrations to pursue

### CN-20260311-190000-CLAUDE
- Configured global permissions in ~/.claude/settings.json: Bash(*), Read(*), Write(*), Edit(*), Glob(*), Grep(*), WebFetch(*), WebSearch, mcp__* all auto-approved
- Deny list empty — no silent blocks. Claude's own guardrails + general.md rules handle safety
- Added availableModels: ["opus", "sonnet", "haiku"]
- Wiped project settings.local.json (160 lines of one-off approvals → empty)
- Wiped project settings.json allow list (3 MCP tools → empty, global handles it)
- User was frustrated with click-yes-all-day permission model. This fixes it permanently.

### CN-20260311-180000-CLAUDE
- Applied 004D research to meta-production skill: 10→12 dimensions, 4 reference files
- New dims: 11 Reliability (SLO/SLI, error budgets, chaos readiness), 12 Capacity (load tests, auto-scaling, capacity model)
- Service criticality tiers (Critical/Standard/Low) weight Dims 11-12 — batch jobs aren't penalized for missing SLOs
- Expanded Dim 8: +SLI-based alerting, trace sampling, cardinality control, correlation IDs, cost-aware observability
- Expanded Dim 9: +progressive delivery, supply chain security (SLSA, SBOM, cosign), network policies, secrets rotation
- Expanded Dim 10: +incident maturity model, on-call health metrics, DORA measurement infrastructure (validate infra not scores)
- Scoring: /120 total, thresholds at 85%/70%/50%. Chaos = maturity indicator, not hard gate. DORA = infrastructure check, not fixed tiers
- New files: references/reliability-capacity-prompts.md, references/slo-chaos-dora-checks.md
- Updated files: SKILL.md, references/production-scan-prompts.md, references/report-template.md
- 6 contested findings resolved per user approval (12 dims, validate infra, maturity indicator, tier weighting, tool-agnostic, automation+human)

### CN-20260311-170000-CLAUDE
- Deep research 004D (meta-production upgrade) completed — 35 queries, 580+ scanned, 127 cited
- 11 sub-questions researched: SLO/SLI, chaos engineering, DORA metrics, deployment patterns, on-call readiness, observability gaps, security hardening, capacity planning, compliance, PRR framework comparison, dimension restructuring
- 2 debunked: DORA Elite thresholds as gates (methodology changed), 10 dims cover everything (3 gaps found)
- 6 contested findings awaiting user decision (12 vs 10 dims, chaos as hard gate, SLO universality, etc.)
- 3 emergent topics: continuous PRR, modern incident platforms (incident.io/Rootly), Tetragon as Falco alt
- Codex + Gemini unavailable during run (Bash permission denials) — 580 vs 1000 target scanned
- Summary at: artifacts/research/summary/004D-meta-production-upgrade.md
- Next: apply findings to upgrade meta-production SKILL.md + references

### CN-20260311-160000-CLAUDE
- Applied 003D research to test-review skill: SKILL.md 170→273 lines, 6 new reference files
- Matched security-review progressive disclosure structure (SKILL.md scannable, detail in references/)
- 3 existing checks refined: mock overuse (scope to SUT-owned types), fragile tests (+datetime/network/filesystem), error paths (+exception hierarchy/timeout/batch)
- 6 new sections: mutation testing adequacy, PBT assessment, contract testing, coverage gaps (CC/CRAP), strategy shapes, LLM anti-patterns
- Raw research agent dumps moved from references/ to artifacts/research/003D/
- features.md updated: test-review upgrade → done

### CN-20260311-150000-CLAUDE
- Deep research 003D (test-review upgrade) completed — 60+ queries, 45+ cited sources
- All 8 current skill categories validated against Google SWE Book, Meta ACH, ISO 29119
- 3 existing checks need refinement: mock overuse, fragile tests, error paths
- 6 new sections identified: mutation testing (P0), CC thresholds (P0), PBT (P1), contract testing (P1), strategy shapes (P1), LLM anti-patterns (P2)
- Key insight: mutation testing is ground truth — AI tests hit 100% coverage / 4% mutation score
- Summary at: artifacts/research/summary/003D-test-review-upgrade.md
- Next: apply findings to upgrade SKILL.md + create reference files

### CN-20260311-140000-CLAUDE
- Pushed skill suite to GitHub: https://github.com/trevorbyrum/claude-skills-suite
- Initialized git repo from iCloud shared directory (was not previously a git repo)
- Force-pushed over stale remote commit (`e404487`) with current local state
- Git identity set to `Trevor Byrum <tbyrum@8-bit-byrum.com>` (repo-local, not global)
- `.gitignore` excludes: `.claude/`, `artifacts/project.db`, `compact/`, `.DS_Store`
- No GitHub credentials in Vault — using `gh` CLI auth (keyring-based, `trevorbyrum` account)
