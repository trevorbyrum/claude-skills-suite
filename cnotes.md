# Collaboration Notes

> Newest first. Each note is locked once a newer note exists above it.
> Format: `CN-YYYYMMDD-HHMMSS-AUTHOR`

## Notes (Newest First)

---CLAUDE--------------------
note_id: CN-20260312-203000-CLAUDE
timestamp_utc: 2026-03-12T20:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: New skill-forge skill — unified create/edit for skill suite
files_touched: skills/skill-forge/SKILL.md, skills/skill-forge/references/skill-template.md, skills/skill-forge/references/validation-checklist.md
summary: |
  Built /skill-forge — single skill that handles both creating new skills and editing existing ones.
  Auto-detects mode based on whether skills/<name>/SKILL.md exists.
  Two reference files encode all suite patterns and lessons learned:
  - skill-template.md: canonical SKILL.md structure (frontmatter rules, section order, progressive disclosure architecture, output patterns A/B/C, sizing guidelines)
  - validation-checklist.md: 40+ checks across 8 categories (frontmatter, structure, content, anti-patterns, DB integration, driver boundary, progressive disclosure, infrastructure)
  Anti-pattern checks encode every production bug we've hit: always-on descriptions, subagent DB writes, stale file refs, bare timeout, line-count validation, context stuffing.
  Self-validated: PASS (0 failures, 0 warnings). Description at 146 chars.
decisions:
  - Single skill (skill-forge) instead of separate skill-create + skill-edit — mode detection is trivial
  - Validation checklist uses FAIL/WARN severity — FAILs must be fixed before finishing
  - User confirms plan before writing (Phase 2 gate) — follows general.md approach-selection rule
handoff_to: CLAUDE
next_actions: Consider adding skill-forge to meta-init scaffold chain; update todo/features if needed
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-193000-CLAUDE
timestamp_utc: 2026-03-12T19:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Counter-review upgrade — adversarial red-team capabilities
files_touched: skills/counter-review/SKILL.md, skills/counter-review/references/abuse-cases.md, skills/counter-review/references/attack-chains.md, skills/counter-review/references/what-if-scenarios.md
summary: |
  Upgraded counter-review from 4 attack vectors to 7. Added 3 adversarial sections + 3 progressive-disclosure reference files.
  New sections: §6 Adversarial Abuse Cases (business logic, input boundaries, state manipulation, agentic abuse), §7 Attack Chain Construction (trust boundary mapping, escalation paths, chain severity scoring), §8 "What If" Scenarios (infrastructure failure, security breach, scale, operational).
  Added boundary table vs security-review — counter-review owns creative adversarial thinking, security-review owns checklist/pattern compliance.
  Finding template extended with Attack Chain format (entry point, path, prerequisites, likelihood) and Scenario format (assumption challenged, current behavior, verdict).
  3 reference files follow security-review's progressive disclosure pattern.
decisions:
  - Counter-review absorbs red-team functionality (no separate red-team skill)
  - Clear boundary: security-review = known patterns/checklists, counter-review = creative adversarial thinking
  - Attack chains are counter-review's unique capability — chaining findings across lenses
handoff_to: CLAUDE
next_actions: Update description (currently >150 chars — needs trim per todo #1)
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-190000-CLAUDE
timestamp_utc: 2026-03-12T19:00:00Z
author: CLAUDE
activity_type: BUG_FIX
work_scope: Fix stale "output file" references in 5 review lens skills + meta-review description
files_touched: skills/counter-review/SKILL.md, skills/completeness-review/SKILL.md, skills/refactor-review/SKILL.md, skills/compliance-review/SKILL.md, skills/drift-review/SKILL.md, skills/meta-review/SKILL.md
summary: |
  1. Fixed 5 lens skills that still said "Write findings to the output file" despite Outputs section correctly using db_upsert. Changed to "Format each finding using this structure (store via db_upsert as shown in Outputs above)". security-review and test-review were already clean.
  2. Fixed meta-review description: "8 lenses" → "7 lenses". The 8th was never wired in.
  3. Discovered skills/ui-design/ — directory scaffolded (Mar 11 23:16) but SKILL.md never written. Empty references/ dir only. Not wired into meta-review or meta-research.
decisions:
  - Only review-synthesis.md stays on disk as a file. All lens findings go to artifact DB only.
risks_or_gaps: ui-design skill needs to be written and wired into meta-review as 8th lens (user confirmed this was intended)
handoff_to: CLAUDE
next_actions: Write ui-design SKILL.md, wire as 8th lens in meta-review
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-150000-CLAUDE
timestamp_utc: 2026-03-12T15:00:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Vibe skill overhaul, context estimation removal, github-pull skill, CLI dedup rule
files_touched: skills/vibe/SKILL.md, skills/meta-execute/SKILL.md, rules/general.md, hooks/stop-check.sh, skills/meta-context-save/SKILL.md, skills/project-scaffold/templates/claude-md-template.md, skills/github-pull/SKILL.md
summary: |
  1. Removed context window estimation from stop hook, meta-context-save, and claude-md-template. Context save is now manual-only via /meta-context-save.
  2. Created /github-pull skill (git fetch --prune + git pull --ff-only, --rebase/--stash options).
  3. Full rewrite of /vibe skill — old syntax was 100% wrong (--headless, --no-prompt, generate/review subcommands don't exist). Correct: `-p "PROMPT" --output text --max-turns N`. Verified against --help, live testing, official Mistral docs.
  4. Removed duplicated CLI syntax from meta-execute and general.md — driver skills are now single source of truth. Saved feedback memory for this rule.
decisions:
  - Driver skills (/vibe, /codex, /gemini, /copilot, /cursor) are the ONLY place CLI syntax lives. Consuming skills say "load /vibe for syntax" instead of inlining commands.
  - 9 other consuming skills still have duplicated CLI syntax — needs future sweep.

---CLAUDE--------------------
note_id: CN-20260313-120000-CLAUDE
timestamp_utc: 2026-03-13T12:00:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: SAST pre-scan integration into meta-review (todo #4b)
files_touched: skills/meta-review/SKILL.md, todo.md
files_reviewed: skills/meta-review/SKILL.md
summary: Added Phase 1.5 "SAST Pre-Scan" to meta-review. Claude main thread calls Semgrep MCP, SonarQube MCP, and local CLIs (ruff/biome/oxlint/gitleaks) before LLM reviews. Results injected into all lens prompts.
details:
  - Phase 1.5 has 4 parallel steps: Semgrep MCP scan_directory, SonarQube search_sonar_issues (if project exists), local CLIs (language-detected), gitleaks secrets scan
  - $SAST_SUMMARY assembled and truncated to ~5000 chars (HIGH/BLOCKER/CRITICAL only)
  - All 3 dispatch sections (Sonnet, Codex, Gemini) updated to include SAST context
  - Sonnet subagents now cross-reference SAST findings (confirm/dispute/expand)
  - Synthesis template updated with SAST Findings section (machine-verified, not LLM opinion)
  - Architecture diagram updated to show pre-scan flow
  - Graceful degradation: if ALL tools unavailable, LLM reviews still run
  - SonarQube query only runs if project already exists — does NOT create projects or run sonar-scanner
  - Updated Step 2: SonarQube now auto-creates project + runs sonar-scanner if no project exists (derives key from folder name)
  - Requires JDK 21 (already installed via Homebrew), token from Vault services/sonarqube or $SONARQUBE_TOKEN env var
  - Graceful skip if JDK missing or SonarQube unreachable
validation: structural review of SKILL.md edits — needs real /meta-review run to validate end-to-end
risks_or_gaps: Not tested on a real project yet; SAST summary truncation at 5000 chars may lose findings on large codebases; sonar-scanner adds ~60s to Phase 1.5
handoff_to: CLAUDE
next_actions: Run /meta-review on Arbytr to validate Phase 1.5 end-to-end
------------------------------

---CLAUDE--------------------
note_id: CN-20260313-110000-CLAUDE
timestamp_utc: 2026-03-13T11:00:00Z
author: CLAUDE
activity_type: SETUP
work_scope: SonarQube MCP verification + first full project scan
files_touched: ~/.mcp.json, todo.md
files_reviewed: Arbytr project (369 files indexed, 156 TS/JS analyzed)
summary: Confirmed SonarQube MCP Docker swap working. Ran first full scan on Arbytr project — 36.9k LOC, quality gate PASSED, 27 bugs, 517 code smells, 32 security hotspots, 0 vulnerabilities.
details:
  - MCP connection verified: `search_my_sonarqube_projects` returned empty (fresh install) — confirmed live
  - `analyze_code_snippet` tested on extension.ts — returned 5 issues (works without projectKey for local analysis)
  - Created `arbytr` project via SonarQube API (`/api/projects/create`)
  - JDK 21 already installed via Homebrew but not on PATH — used `JAVA_HOME` export to enable sonar-scanner
  - Full scan via `npx sonar-scanner` — 369 files, 8 languages detected, 62s total
  - 1 BLOCKER: infinite loop in `poll-history.mjs:214` (`stopped` not modified)
  - 35 CRITICAL cognitive complexity violations (worst: `config.ts:165` at 120, limit is 15)
  - `ChatPanelProvider.ts:83` complexity 70, `StatusPage.tsx:119` complexity 44
  - `agora-core/src/types.ts` has 11 functions over complexity limit
  - GUI accessible at http://tower:9000/dashboard?id=arbytr via Tailscale
  - Todo #4a updated to reflect Docker swap + verification
validation: Quality gate PASSED, all MCP tools functional, scan results visible in GUI
risks_or_gaps: 0% test coverage reported (no lcov configured); security hotspots need manual triage
handoff_to: CLAUDE
next_actions: Triage 32 security hotspots; configure test coverage reporting; wire SonarQube into meta-review Phase 1 (todo #4b)
------------------------------

---CLAUDE--------------------
note_id: CN-20260313-100000-CLAUDE
timestamp_utc: 2026-03-13T10:00:00Z
author: CLAUDE
activity_type: SETUP
work_scope: SonarQube MCP wiring (in progress)
files_touched: none yet
files_reviewed: ~/.mcp.json, cnotes.md
summary: Verified all 5 local SAST tools installed. Researched SonarQube MCP server (official Docker image mcp/sonarqube). Waiting on user's SonarQube token to complete wiring.
details:
  - Tower Tailscale address: http://tower:9000 (SonarQube)
  - User plans to expose SonarQube GUI through Cloudflare
  - MCP server will connect via Tailscale directly (not Cloudflare)
  - Official Docker image: mcp/sonarqube (Java/Gradle, JDK 21+)
  - Env vars needed: SONARQUBE_TOKEN (user token), SONARQUBE_URL, STORAGE_PATH
  - Default SonarQube creds: admin/admin (forces change on first login)
  - Flagged: ~/.mcp.json has GitHub PAT + GitLab token in plaintext (todo #15)
  - SonarQube container confirmed running on tower (since 2026-03-11, sonarqube:community v26.3.0, traefik_proxy network, no Traefik labels = no web exposure)
  - Tower Tailscale IP: 100.127.173.50 (tower.elk-bangus.ts.net), 68ms from Mac
  - SonarQube does NOT need public web exposure for MCP — Tailscale IP sufficient
  - Docker Desktop NOT running on this Mac — can't run mcp/sonarqube Docker image until started
  - No Vault recipe exists yet at services/sonarqube (404)
  - Options presented: A) Docker Desktop, B) JDK build, C) tower-side (rejected). No JDK or Docker — used npm package instead
  - npm package `sonarqube-mcp-server` (deprecated but functional) works as stdio MCP server
  - Added to ~/.mcp.json with SONARQUBE_BASE_URL=http://100.127.173.50:9000
  - Token stored in Vault at services/sonarqube (v1)
  - Needs Claude Code restart to pick up new MCP server
validation: All 5 tools confirmed installed; npm MCP server tested (starts without errors); Vault store confirmed (v1)
  - User started Docker Desktop — swapped npm package for official mcp/sonarqube Docker image
  - Docker 29.1.3 confirmed running, image pulled successfully
risks_or_gaps: Need to test actual SonarQube queries after Claude Code restart
handoff_to: CLAUDE
next_actions: Restart Claude Code → verify sonarqube tools appear → test a query → wire into meta-review Phase 1
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-162434-CLAUDE
timestamp_utc: 2026-03-12T16:24:34Z
author: CLAUDE
activity_type: CODE_REVIEW
work_scope: Design meta-execute multi-model pipeline (Vibe + Cursor + Codex)
files_touched: none (design phase)
files_reviewed: meta-execute/SKILL.md, vibe/SKILL.md, cursor/SKILL.md, copilot/SKILL.md
summary: Agreed on cross-model Best-of-N generation + 5-reviewer panel for meta-execute
details:
  - Generation: 1 Vibe + 1 Cursor per WU (cross-model Best-of-2), 2 WUs at a time (conservative start)
  - Review panel (5 per WU, 2 WUs concurrent): Codex (fixes), Sonnet (rubric), Cursor --mode ask, Copilot, Gemini
  - Codex role shifts from coder to editor+reviewer — reads Vibe/Cursor output, reviews against rubric, applies fixes
  - Staggered pipeline (option B) to keep Cursor at ≤3 concurrent
  - Synthesis: 3/5 ACCEPT → merge; any REJECT → Codex fixes informed by all 5; disagreement → Claude synthesizes
  - Pending: implementation into meta-execute SKILL.md, worker.md, reviewer.md
validation: not run (design only)
risks_or_gaps: Vibe/Cursor output quality unknown until first real run; conservative 2+2 limits may need adjustment
handoff_to: CLAUDE
next_actions: Implement pipeline into meta-execute upon user approval
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-154500-CLAUDE
timestamp_utc: 2026-03-12T15:45:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Add Copilot as Gemini fallback + fix concurrency limits
files_touched: general.md, cross-cutting-rules.md, copilot/SKILL.md, gemini/SKILL.md, meta-review/SKILL.md, research-execute/SKILL.md, meta-production/SKILL.md, release-prep/SKILL.md, project-questions/SKILL.md, build-plan/SKILL.md, meta-deep-research-execute/SKILL.md
files_reviewed: All 13 skills referencing Gemini
summary: Copilot is now Gemini's primary fallback across all skills. Concurrency fixed 3→2.
details:
  - Fallback chain everywhere: Gemini → Copilot → WebSearch/skip (8 skill files updated)
  - Copilot concurrency 3→2 in general.md, cross-cutting-rules.md, copilot/SKILL.md
  - New CLI landscape: Gemini (free), Codex ($20/mo), Copilot (premium requests), Cursor (Pro+ student free)
validation: grep scan confirmed all Gemini call sites now have Copilot fallback
risks_or_gaps: Copilot/Cursor not yet tested in subagent/background shells — may need path fixes like Codex/Gemini needed
handoff_to: none
next_actions: Test Copilot fallback in real meta-review run; verify Cursor Agent CLI path
------------------------------

---CLAUDE--------------------
note_id: CN-20260312-153000-CLAUDE
timestamp_utc: 2026-03-12T15:30:00Z
author: CLAUDE
activity_type: CODE_WRITE
work_scope: Fix infinite skill loop in Cursor IDE
files_touched: skills/todo-features/SKILL.md, skills/github-sync/SKILL.md, skills/evolve/SKILL.md, references/cross-cutting-rules.md
files_reviewed: All 39 skill SKILL.md frontmatter blocks
summary: Diagnosed and fixed infinite loop caused by 3 skill descriptions acting as always-on rules + cross-cutting-rules amplifying them
details:
  - Root cause: todo-features ("Runs after completing work"), github-sync ("Applies whenever uncommitted changes"), evolve ("project changed") — these descriptions read as standing instructions, not slash-command triggers
  - cross-cutting-rules forced every skill to update todo.md/features.md on completion, re-triggering the chain
  - Fix: rewrote all 3 descriptions to require explicit /slash-command invocation
  - Fix: cross-cutting-rules now says "mention changes in response" instead of "update files directly"
validation: Grep scan of all SKILL.md descriptions confirmed no other always-on trigger language remains
risks_or_gaps: Skills that explicitly call /github-sync or /todo-features as steps (meta-execute, review-fix, meta-context-save) still work — those are intentional inline calls, not description-driven auto-triggers
handoff_to: none
next_actions: Test in Cursor to confirm loop is broken; related to todo #1 (trim descriptions ≤150 chars)
------------------------------

### CN-20260312-093000-CLAUDE
- Moved repo from iCloud (`~/Library/Mobile Documents/.../Shared/claude`) → `/Users/byrum_work/Projects/claude`
- Reason: iCloud kept corrupting `.git/index` (all files showed as D + ?? on session start)
- Fixed git index corruption via `git reset` before the move
- Repointed 4 symlinks in `~/.claude/`: agents, hooks, rules, skills → new location
- Migrated project config + memory to `~/.claude/projects/-Users-byrum-work-Projects-claude/`
- GitHub remote unchanged: `trevorbyrum/claude-skills-suite`
- Old iCloud copy still exists — user should delete after confirming new location works

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
