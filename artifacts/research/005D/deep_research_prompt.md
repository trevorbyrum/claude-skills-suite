# Deep Research Prompt — 005D

## Research Question
What free or freemium tools, MCP servers, applications, and code libraries exist that could augment a Claude Code skill suite to produce fewer bugs, fewer code errors, less drift between docs and code, fewer missed issues in reviews, and less guessing during development — across the full dev lifecycle (writing, reviewing, testing, deploying)?

## Sub-Questions
1. What static analysis tools (linters, type checkers, bug finders) are free for individual use on macOS/Linux, cover multiple languages, and can be integrated into pre-commit hooks or CI?
2. What MCP servers exist (official, community, emerging) that add code quality, testing, or review capabilities not already covered by GitHub, Playwright, Homelab Tools, or Figma MCP servers?
3. What free code review tools or libraries can catch bugs that LLM-based reviews miss — especially logic errors, concurrency bugs, null safety, type narrowing gaps?
4. What free testing tools go beyond basic unit tests — mutation testing, property-based testing, fuzz testing, contract testing — that work on macOS and integrate into automated workflows?
5. What drift detection tools exist that compare documentation/specs against actual code and flag divergence automatically?
6. What free security scanning tools (SAST, SCA, secret detection, container scanning) have generous free tiers and can run locally on macOS or in Docker?
7. What emerging or lesser-known tools (2024-2026) show strong evidence of reducing real bugs in practice, even if not yet mainstream? Require authoritative backing or strong empirical evidence.
8. What free observability/debugging tools help catch errors earlier in development (not just production) — runtime analysis, memory profiling, trace-based testing?
9. Which of the existing MCP servers the user already has connected (Homelab Tools, GitHub, Playwright, neo4j-plc, qdrant-memory, lmstudio, n8n) are underutilized for code quality purposes?
10. What tool combinations or pipelines produce compounding bug-reduction effects (e.g., type checker + mutation testing + property-based testing together catch more than the sum of parts)?

## Scope
- Breadth: exhaustive
- Time horizon: primarily 2024-2026, include established tools with historical track record
- Domain constraints: macOS-first, Linux also. Any language stack. No paid API costs — free/OSS/freemium with generous individual limits only.

## Project Context
This is a Claude Code skill suite (38 skills, 10 agents, 7 hooks) that orchestrates code reviews, testing, security scanning, production readiness, and multi-model research using Claude as orchestrator with Codex and Gemini as workers. The skill suite already includes:
- 7 review lenses (security, test, refactor, drift, completeness, compliance, counter)
- Pre-commit hooks (Codex lint)
- Meta-review (12 parallel reviews across 3 model families)
- Meta-production (12-dimension production readiness scoring)
- Test-review (mutation testing, PBT, contract testing assessment)
- Security-review (OWASP Agentic, supply chain, P0/P1/P2 tiers)
- Connected MCP servers: GitHub, Playwright, Homelab Tools, neo4j-plc, qdrant-memory, lmstudio, n8n, browser-use

The gap: these skills assess and review but rely heavily on LLM judgment. The user wants concrete tools that provide deterministic, evidence-based signals to complement LLM reasoning — reducing false negatives and guesswork.

## Known Prior Research
- 001D: agent-security-gaps (security review upgrade)
- 002D: meta-execute upgrade (worker design, agentic rubrics)
- 003D: test-review upgrade (mutation testing, PBT, contract testing)
- 004D: meta-production upgrade (SLO/SLI, chaos, DORA)

## Output Configuration
- Research folder: artifacts/research/005D/
- Summary destination: artifacts/research/summary/005D-free-tools-augmentation.md
- Topic slug: free-tools-augmentation

## Special Instructions
- Every tool recommendation MUST include: name, URL, license, free tier limits, macOS/Linux support, how it integrates (hook/CLI/MCP/library)
- For non-mainstream or emerging tools, require either: (a) backing by authoritative source (CNCF, Google, Meta, academic paper), OR (b) clear empirical evidence (benchmarks, case studies, adoption metrics)
- Flag any tool that LOOKS free but has hidden costs (usage caps, telemetry concerns, bait-and-switch pricing history)
- Prioritize tools that can feed deterministic signals into Claude Code skills/hooks (exit codes, structured output, JSON reports)
- Group findings by lifecycle phase: Write → Review → Test → Secure → Deploy → Monitor
- Call out which existing MCP servers could be better leveraged before recommending new ones
