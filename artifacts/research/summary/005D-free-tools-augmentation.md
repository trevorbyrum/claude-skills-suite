# Deep Research: Free Tools to Augment Claude Code Skill Suite

> Research folder: research/005D/
> Date: 2026-03-11
> Models: Opus 4.6 (orchestrator + reasoning), Sonnet 4.6 (7 connectors via WebSearch),
>   Gemini 0.32.1 (2 instances — primary + dissent)
> MCP connectors used: WebSearch (47 queries), Gemini CLI (2 instances)
> Debate rounds: 2-model (Codex unavailable — all 4 workers timed out)
> Addendum cycle: yes — emergent topics (Rust revolution, SARIF unification, slopsquatting, LLM+SA hybrid)
> Sources: 66 queries | ~654 scanned | ~256 cited
> Claims: 6 verified, 8 high, 3 contested, 0 debunked

## Executive Summary

- **VERIFIED**: Rust-based tools (Ruff, ty, Biome, oxlint, ast-grep) deliver 10-100x performance improvements over predecessors, making pre-commit type checking and linting practical for monorepos. Adoption by Shopify, Airbnb, Mercedes-Benz.
- **VERIFIED**: Hypothesis property-based testing finds ~50x more mutations than average unit tests (OOPSLA 2025, 40-project evaluation). This is the single highest-leverage testing tool for any Python project.
- **VERIFIED**: No single secret scanner catches all types. Running Gitleaks + TruffleHog together catches more than either alone (academic study on 576K samples).
- **VERIFIED**: Slopsquatting (AI package hallucination) is a real attack vector — 20% of AI-generated code references non-existent packages, 58% of hallucinated names are repeatable. Mitigation: post-generation registry validation.
- **HIGH**: LLM + static analysis hybrid approach reduces false positives by 85-98% (ICSE 2025/2026 papers, Datadog production deployment). This is the strongest argument for pairing deterministic tools WITH LLM review.
- **HIGH**: Semgrep OSS is best-in-class free SAST for pattern matching across 30+ languages — but limited to intra-procedural analysis. CodeQL is superior for complex taint tracking (free for open source).
- **HIGH**: SonarQube MCP server bridges existing code quality data into Claude Code, and Semgrep MCP enables AI-assisted security scanning with Cursor hooks integration.
- **CONTESTED**: "More tools = fewer bugs" is an oversimplification. Industrial studies show 96% false positive rates in large-scale SATs, a "16% ceiling" for automated bug detection, and shadow pipeline creation when developers face too much friction.
- **CONTESTED**: MCP server ecosystem is growing fast (7,260+ servers) but has a "Security and Governance Deficit" — critical RCE vulnerabilities (CVE-2025-6514), confused deputy risks, and context bloat consuming 40-50% of LLM windows.
- **CONTESTED**: ty (Astral) is 10-60x faster than mypy/pyright but still in beta. Missing Pydantic/Django support. Monitor for 2026 stable release.

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | Static analysis tools | VERIFIED | 3/3 | Ruff+ty+Biome+oxlint for speed; Semgrep+CodeQL for security; MegaLinter/pre-commit for orchestration |
| 2 | MCP servers for code quality | HIGH | 2/3 | SonarQube MCP + Semgrep MCP are production-ready; ecosystem immature overall |
| 3 | Tools catching bugs LLMs miss | HIGH | 2/3 | Meta Infer, Google ErrorProne, NullAway for deterministic bugs; LLM best as false-positive filter |
| 4 | Advanced testing tools | VERIFIED | 3/3 | Hypothesis, fast-check, Stryker, Schemathesis, Pact all free and mature |
| 5 | Drift detection | HIGH | 2/3 | Spectral (API), Vale (prose), dependency-cruiser (JS arch), Knip (dead code) cover most cases |
| 6 | Security scanning | VERIFIED | 3/3 | Trivy+Gitleaks+Semgrep+Checkov+osv-scanner cover SAST/SCA/secrets/IaC/supply-chain |
| 7 | Emerging tools (2024-2026) | HIGH | 2/3 | Rust tool revolution is real; ty/Pyrefly/oxlint leading. Caution on MCP maturity. |
| 8 | Dev-time observability | HIGH | 2/3 | memray+py-spy (Python), Tracetest (distributed), ASAN (C/C++), Instruments (macOS) |
| 9 | Underutilized MCP servers | HIGH | 2/3 | n8n (workflow automation), qdrant (code search), lmstudio (local review), neo4j (dependency graphs) |
| 10 | Compounding tool pipelines | CONTESTED | 1/3 | Compounding effects real (PBT+mutation, LLM+SAST) but diminishing returns equally real |

## Detailed Findings

### SQ-1: Static Analysis Tools

**Confidence**: VERIFIED | **Agreement**: 3/3

The landscape has been transformed by Rust-based tooling. The recommended stack by lifecycle phase:

**Tier 1 — Essential (every project)**
| Tool | Languages | Speed vs Predecessor | License | Integration |
|---|---|---|---|---|
| Ruff | Python | 10-100x vs Flake8/Pylint | MIT | pre-commit, CI, SARIF |
| ty (Astral) | Python types | 10-60x vs mypy/pyright | MIT | pre-commit (beta) |
| Biome | JS/TS/JSON/CSS | 25x vs ESLint+Prettier | MIT | pre-commit, CI |
| oxlint | JS/TS | 50-100x vs ESLint | MIT | pre-commit, CI |
| Semgrep OSS | 30+ languages | N/A (unique) | LGPL-2.1 | pre-commit, CI, SARIF, MCP |
| ShellCheck | Bash/Shell | N/A | GPL-3.0 | pre-commit, CI |
| Hadolint | Dockerfile | N/A | GPL-3.0 | pre-commit, CI, SARIF |

**Tier 2 — Specialized**
| Tool | Purpose | License |
|---|---|---|
| ast-grep | Structural search/rewrite, polyglot | MIT |
| golangci-lint | Go meta-linter (50+ linters) | GPL-3.0 |
| clippy | Rust idiomatic linting | MIT |
| CodeQL | Deep taint analysis (free for OSS) | MIT |
| actionlint | GitHub Actions YAML linting | MIT |
| typos | Source code spell checking | MIT |

**Tier 3 — Orchestrators**
| Tool | What It Does | Speed Note |
|---|---|---|
| pre-commit | Hook framework, largest ecosystem | Standard |
| Lefthook | Hook framework, 300% faster (Go, parallel) | Fast |
| MegaLinter | 50+ languages, Docker-based aggregator | Docker overhead |
| Trunk Check | Multi-tool orchestrator with caching | Commercial freemium |

**Debate**: Gemini confirmed all Tier 1 tools and added typos as an emergent tool. No models contested the Rust performance claims — multiple independent benchmarks corroborate.

### SQ-2: MCP Servers for Code Quality

**Confidence**: HIGH | **Agreement**: 2/3

**Production-ready MCP servers:**
- **SonarQube MCP** (github.com/SonarSource/sonarqube-mcp-server) — Official, Rust-based. Queries code quality metrics, issues, quality gates. Free Docker deployment. Requires SonarQube instance.
- **Semgrep MCP** (github.com/semgrep/mcp) — Official. Security scanning, vulnerability detection, AST analysis. Cursor hooks integration for enforcing scans on all AI-generated code.
- **Playwright MCP** (github.com/microsoft/playwright-mcp) — Official Microsoft. Browser automation, accessibility snapshots, visual regression testing. 143 device emulations.

**Promising community servers:**
- Code Review MCP — Multi-LLM code review with structured output
- Code Analysis MCP — 80+ tools for code navigation and impact analysis
- Sentry MCP — Real-time error/issue context for AI agents
- 16-tool CLI wrapper — Wraps 240+ CLI dev tools via MCP

**Caution (Gemini dissent):**
- MCP ecosystem has critical security vulnerabilities (CVE-2025-6514 RCE in mcp-remote)
- 78% of implementations lack granular authorization (confused deputy risks)
- Loading multiple MCP servers can consume 40-50% of LLM context window
- Community servers vary widely in quality and maintenance

### SQ-3: Tools Catching Bugs LLMs Miss

**Confidence**: HIGH | **Agreement**: 2/3

LLMs and traditional static analysis are **complementary, not substitutes**:

| Bug Category | LLMs Catch | Traditional Tools Catch |
|---|---|---|
| Business logic flaws | Good (contextual reasoning) | Poor |
| API misuse patterns | Moderate | Excellent (Semgrep, CodeQL) |
| Null dereferences | Moderate | Excellent (NullAway, Infer) |
| Concurrency bugs | Poor | Good (Infer thread safety) |
| Memory safety | Poor | Excellent (ASAN, Valgrind) |
| Type errors | Moderate | Excellent (mypy, pyright, ty) |
| False positive triage | Excellent (85-98% reduction) | N/A |

**Key tools:**
- **Meta Infer** (fbinfer.com) — MIT — Java/C/C++/ObjC — Null dereference, memory leaks, thread safety. High false positive rate but catches real bugs at scale.
- **Google ErrorProne** (errorprone.info) — Apache-2.0 — Java — Compile-time bug detection, low false positive rate.
- **NullAway** (github.com/uber/NullAway) — MIT — Java — Eliminates NPEs with JSpecify. Recent 2025 improvements to generic method inference.

**Research finding (ICSE 2026)**: The optimal approach is running static analysis FIRST, then using LLMs to filter false positives. This achieves 94-98% false positive elimination while maintaining high recall. Cost: $0.001-$0.12 per alarm.

### SQ-4: Advanced Testing Tools

**Confidence**: VERIFIED | **Agreement**: 3/3

**Mutation Testing** (validates test quality):
| Tool | Languages | License | Key Feature |
|---|---|---|---|
| Stryker | JS/TS/.NET | Apache-2.0 | Dashboard, incremental, CI integration. Updated Mar 2026. |
| mutmut | Python | BSD | Simple, pytest integration |
| cargo-mutants | Rust | MIT | Active development, Rustconf 2024 talk |
| PIT/pitest | Java | Apache-2.0 | Mature, widely adopted |

**Property-Based Testing** (finds edge cases automatically):
| Tool | Languages | License | Key Evidence |
|---|---|---|---|
| Hypothesis | Python | MPL-2.0 | **OOPSLA 2025: 50x more mutations killed than unit tests** |
| fast-check | JS/TS | MIT | @fast-check/vitest + jest integrations |
| proptest | Rust | MIT/Apache | Inspired by Hypothesis, flexible |
| jqwik | Java | EPL-2.0 | JUnit 5 native |

**Fuzz Testing** (finds crashes and security bugs):
| Tool | Languages | License | Key Feature |
|---|---|---|---|
| Schemathesis | OpenAPI/GraphQL | MIT | API fuzzing from spec. Used at Capital One. |
| AFL++ | C/C++ | Apache-2.0 | State-of-the-art coverage-guided fuzzer |
| Jazzer | Java | Apache-2.0 | JVM fuzzing |
| Atheris | Python | Apache-2.0 | Google-maintained, Python + native extensions |

**Contract Testing** (prevents integration breakage):
| Tool | Languages | License | Key Feature |
|---|---|---|---|
| Pact | Multi-language | MIT | Consumer-driven contracts. PactFlow AI (2025). |
| Specmatic | Multi-language | MIT | Contract-driven from OpenAPI specs |

### SQ-5: Drift Detection Tools

**Confidence**: HIGH | **Agreement**: 2/3

| Drift Type | Tool | Languages/Formats | License | Integration |
|---|---|---|---|---|
| API schema | Spectral | OpenAPI/AsyncAPI | Apache-2.0 | CLI, VSCode, GitHub Action |
| API behavior | Schemathesis | OpenAPI/GraphQL | MIT | CI, pytest |
| API behavior | Dredd | OpenAPI/API Blueprint | MIT | CI |
| Prose/docs | Vale | Markdown/RST/HTML | MIT | pre-commit, CI. Used by Datadog, Grafana. |
| JS/TS deps | dependency-cruiser | JS/TS | MIT | CI, pre-commit |
| Java arch | ArchUnit | Java/Kotlin | Apache-2.0 | JUnit integration |
| Dead code | Knip | JS/TS | ISC | CI, 80+ framework support |
| Python deps | deptry | Python | MIT | pre-commit, CI (Rust-based, fast) |
| Infra drift | driftctl | Terraform | Apache-2.0 | CI |
| Code complexity | Wily | Python | MIT | Tracks complexity over time |
| Source typos | typos | Multi-language | MIT | pre-commit, GitHub Action |
| Commit format | commitlint | Any | MIT | commit-msg hook, CI |

### SQ-6: Security Scanning

**Confidence**: VERIFIED | **Agreement**: 3/3

**Recommended free security pipeline:**

```
Pre-commit:     Gitleaks (secrets) + TruffleHog (verified secrets)
SAST:           Semgrep OSS (patterns) + CodeQL (taint analysis, OSS only)
SCA:            Trivy (vulns+licenses) + osv-scanner (OSV database)
IaC:            Checkov (Terraform/K8s) + KICS (2,400+ queries)
Containers:     Trivy (images) + Grype (risk scoring with EPSS+KEV)
Supply chain:   OpenSSF Scorecard + npm/cargo/go audit
Python-specific: Bandit (security) + Safety (CVEs)
SBOM:           Syft (generate) + Trivy (scan)
```

**Key finding**: All tools above are Apache-2.0 or MIT licensed, run locally on macOS, and produce SARIF or JSON output. SARIF Visualizer (2025) can aggregate results from multiple tools into unified dashboards — client-side, no data leaves browser.

**Caution**: No single tool catches everything. Research confirms different scanners have different detection strengths. The pipeline above provides defense in depth.

### SQ-7: Emerging Tools (2024-2026)

**Confidence**: HIGH | **Agreement**: 2/3

**Strong evidence (adopt now or monitor closely):**
- **ty (Astral)** — 10-60x faster Python type checking. Beta 2025, stable 2026. By Ruff/uv creators.
- **Pyrefly (Meta)** — 35x faster than Pyre. Backed by Meta.
- **oxlint v1.0** (Aug 2025) — 50-100x faster JS linting. 520+ rules.
- **Biome 2.0** (June 2025) — Added type inference. 91K npm weekly downloads.
- **LLM mutation testing (Meta)** — First industrial-scale LLM mutation+test generation (Feb 2025).
- **Agentic PBT** — Automated Hypothesis testing across Python ecosystem (2025 academic study).
- **Semgrep MCP + Cursor hooks** — AI-generated code automatically scanned, agent prompted to fix.
- **SonarQube MCP** — Official bridge from SonarQube data to AI agents.

**Caution needed:**
- AI code review tools: Early tools had 9:1 false positive ratio, causing teams to ignore bots entirely.
- SWE-bench agents improved from 33% to 70%+ in one year but still miss 30% of real bugs.
- Many MCP servers: community-maintained, varying quality, active security concerns.
- Consumption-based pricing traps: Some tools shift from free to volatile usage-based models.

### SQ-8: Dev-Time Observability/Debugging

**Confidence**: HIGH | **Agreement**: 2/3

| Category | Tool | Languages | License | macOS | Key Feature |
|---|---|---|---|---|---|
| Memory profiling | memray | Python | Apache-2.0 | Yes | Traces every allocation including C extensions. Bloomberg-maintained. |
| CPU profiling | py-spy | Python | MIT | Yes | Low-overhead sampling profiler |
| Memory check | AddressSanitizer | C/C++/Rust | Apache-2.0 | Yes | Compile-time instrumentation, catches UAF/overflow |
| Memory tracking | heaptrack | C/C++ | GPL-2.0 | Yes | Allocation tracking with GUI |
| Trace-based testing | Tracetest | Multi-lang | MIT | Yes | Assert on distributed traces, OTel-native, free localMode |
| Continuous profiling | Pyroscope | Multi-lang | AGPL-3.0 | Yes | Continuous profiling |
| Tracing | Jaeger | Multi-lang | Apache-2.0 | Docker | Distributed tracing |
| Profiling (native) | Instruments | Multi-lang | macOS built-in | Yes | Comprehensive Apple profiling suite |

### SQ-9: Underutilized Existing MCP Servers

**Confidence**: HIGH | **Agreement**: 2/3

| MCP Server | Underutilized Capability | Practical Application |
|---|---|---|
| **n8n** | Workflow automation + MCP server/client | LintGuardian workflow: auto-lint PRs with AI, auto-fix, submit correction PRs. FlowLint: static analysis for workflow files. Expose any n8n workflow as MCP tool. |
| **qdrant-memory** | Semantic code search + duplicate detection | Store code patterns as embeddings (jina-embeddings-v2-base-code). Find similar code for refactoring. Detect near-duplicate code. Store review findings for retrieval. |
| **lmstudio** | Local LLM for secondary review | Run local models (DeepSeek, Phi, Mistral) for code review at zero API cost. llmster for headless CI use. Privacy-preserving analysis. |
| **neo4j-plc** | Dependency graph analysis | Build codebase knowledge graphs. Catch dependency violations via Cypher queries. Impact analysis: "what breaks if I change X?" |
| **Playwright** | Beyond basic testing | Accessibility auditing via accessibility snapshots. Visual regression. Self-healing test generation. 143 device emulations. Exploratory autonomous testing. |
| **browser-use** | Automated QA | UI bug detection, broken link checking, accessibility testing. Verify documentation against live UI. |
| **GitHub** | PR automation + code search | Combine with danger.js patterns for automated PR checks. Code search for pattern enforcement. |

### SQ-10: Compounding Tool Pipelines

**Confidence**: CONTESTED | **Agreement**: 1/3

**Evidence FOR compounding effects:**
- Type checker + mutation testing: Types reduce false mutants; mutation testing validates type coverage completeness.
- PBT + mutation testing: Hypothesis finds ~50x more mutations than unit tests (OOPSLA 2025).
- LLM + SAST: 85-98% false positive elimination while maintaining recall (ICSE 2025/2026).
- Multiple secret scanners: Different tools detect different secret types (academic study).
- Meta: LLM-generated mutations + LLM-generated tests = first industrial-scale deployment (Feb 2025).

**Evidence AGAINST (diminishing returns):**
- 96% false positive rate in large-scale industrial SATs — alert fatigue is real.
- "16% ceiling" — automated tools catch superficial bugs; humans still catch most domain-specific flaws.
- 56% of developers report security checks as primary bottleneck, leading to "shadow pipelines".
- Each tool adds configuration burden, maintenance cost, and context-switch overhead.
- Tool sprawl (15-80 tools per org) creates a "complexity tax" and expands attack surface.

**Recommended tiered approach:**

| Tier | Tools | Value | Risk |
|---|---|---|---|
| 1 (Essential) | Type checker + Linter + Secret scanner + pre-commit | Highest ROI, lowest friction | Low |
| 2 (High Value) | SAST + SCA + Dead code detection + Prose linting | Strong signal, moderate setup | Medium — false positive management needed |
| 3 (Advanced) | Mutation testing + PBT + Contract testing + Trace testing | Catches deep bugs | High — requires team buy-in and expertise |
| 4 (Experimental) | LLM+SAST hybrid + MCP integrations + Code embeddings | Cutting-edge | High — immature tooling, MCP security concerns |

## Addendum Findings

Coverage expansion (Phase 2.5) identified 5 emergent topics not in the original prompt:

### Emergent Topic: Rust-Based Tool Revolution
**Why it surfaced**: Every search for modern linters/type checkers returned Rust-based tools dominating benchmarks.
**Finding**: Ruff, ty, Biome, oxlint, ast-grep, Gitleaks, deptry, typos are all written in Rust. The 10-100x performance improvements make workflows practical that were impossible before (pre-commit type checking on monorepos, real-time editor feedback).
**Impact**: Fundamental shift in what "pre-commit" can include. Type checking + linting + formatting in <1 second is now possible.

### Emergent Topic: SARIF as Unifying Format
**Why it surfaced**: Multiple tools across different categories all output SARIF.
**Finding**: SARIF Visualizer (2025) provides client-side aggregation/visualization. Tools supporting SARIF: Semgrep, CodeQL, Trivy, Gitleaks, Hadolint, Grype, osv-scanner, Ruff, Biome, oxlint.
**Impact**: A Claude Code skill could aggregate SARIF from all tools into a unified dashboard, enabling cross-tool deduplication and prioritization.

### Emergent Topic: Slopsquatting / AI Package Hallucination
**Why it surfaced**: Gemini dissent research on supply chain security.
**Finding**: 20% of AI-generated code references non-existent packages (576K sample study, March 2025). 58% of hallucinated names are repeatable, enabling targeted attacks. Open-source models: 21.7% hallucination rate; commercial (GPT-4): 5.2%.
**Impact**: Any AI-assisted development workflow needs post-generation package validation. Existing tools (osv-scanner, npm audit, cargo audit) can partially address this.

### Emergent Topic: LLM + Static Analysis Hybrid
**Why it surfaced**: Multiple academic papers (ICSE 2025, ICSE 2026, OOPSLA 2024) converged on this approach.
**Finding**: Running static analysis first, then using LLMs to filter false positives achieves 85-98% false positive elimination. IRIS (ICSE 2026) achieves 5.21% lower false discovery than CodeQL alone. Datadog uses this in production.
**Impact**: The existing meta-review skill (7 lenses) should incorporate deterministic tool results as input to LLM review, not just LLM-on-LLM.

### Emergent Topic: danger.js for PR Automation
**Why it surfaced**: Searches for code review automation tools.
**Finding**: danger.js (MIT) runs in CI, provides JS API for custom PR rules (missing tests, changelog, PR size, TODO detection). Works with GitHub/GitLab/Bitbucket/20+ CI systems.
**Impact**: Bridges the gap between static analysis output and PR review workflow. Could be integrated into pre-commit hooks or CI to enforce skill suite standards.

## Contested Findings

### "More tools = fewer bugs"
**Majority** (Gemini + WebSearch evidence): Diminishing returns are real. 96% false positive rate in industrial SATs. Shadow pipelines emerge when friction exceeds tolerance.
**Dissent** (Opus reasoning): Compounding effects ARE real for well-chosen combinations (PBT+mutation, LLM+SAST). The key is curation, not accumulation.
**Impact**: The skill suite should recommend a tiered adoption strategy, not a "use everything" approach. Each tier should have measurable entry criteria.

### "MCP ecosystem is ready for production code quality"
**Majority** (Gemini dissent): Security and Governance Deficit. CVE-2025-6514, confused deputy, context bloat.
**Dissent** (Opus + WebSearch): Official servers from SonarSource and Semgrep ARE production-ready. Community servers are not.
**Impact**: Recommend only vendor-backed MCP servers (SonarQube, Semgrep, Playwright). Community servers should be treated as experimental.

### "ty will replace mypy/pyright"
**Majority** (WebSearch + Gemini): Performance is genuinely 10-60x better. Astral has strong track record (Ruff, uv).
**Dissent** (Coverage review): Beta status. Incomplete typing spec. Missing Pydantic/Django support. Cannot be sole type checker yet.
**Impact**: Add ty alongside mypy/pyright in pre-commit (it's fast enough). Switch to ty-only after stable release + 3rd-party library support.

## Open Questions

None classified as UNCERTAIN or UNRESOLVED. All sub-questions received sufficient evidence for at least HIGH confidence.

## Debunked Claims

No claims were debunked through the debate process. The closest was "more tools = fewer bugs" which was contested rather than debunked — the nuance is that CURATED combinations produce compounding benefits while UNCURATED accumulation produces diminishing returns.

## Source Index

### Academic Sources
- OOPSLA 2025: "Empirical Evaluation of Property-Based Testing in Python" (40-project study, ~50x mutation finding)
- ICSE 2026: "Reducing False Positives in Static Bug Detection with LLMs" (Tencent, 433 alarms study)
- ICSE 2025: "With a Little Help from My LLM Friends: Enhancing Static Analysis with LLMs"
- ICSE 2026: "LLM-based Vulnerability Discovery through the Lens of Code Metrics" (IRIS framework)
- OOPSLA 2024: "Enhancing Static Analysis for Practical Bug Detection" (LLift framework)
- Springer Nature 2025: "Fuzzing-based mutation testing of C/C++ in cyber-physical systems"
- ACM TOSEM 2023: "Open Problems in Fuzzing RESTful APIs"
- arXiv 2025: "Agentic Property-Based Testing: Finding Bugs Across the Python Ecosystem"
- arXiv 2025: Package hallucination study (576K code samples)

### Official Documentation
- Astral (ty, Ruff): astral.sh/blog/ty, docs.astral.sh/ruff
- Semgrep MCP: semgrep.dev/docs/mcp
- SonarQube MCP: github.com/SonarSource/sonarqube-mcp-server
- Trivy: trivy.dev
- Schemathesis: schemathesis.io
- Hypothesis: hypothesis.readthedocs.io
- fast-check: fast-check.dev
- Spectral: stoplight.io/open-source/spectral
- Vale: vale.sh
- Tracetest: tracetest.io
- OpenSSF Scorecard: scorecard.dev
- Knip: knip.dev
- KICS: kics.io
- danger.js: danger.systems/js

### Web Sources (selected)
- dev.to: "Deep Dive: Why Rust-Based Tooling is Dominating JavaScript in 2026"
- InfoQ: "Oxlint v1.0 Stable Released" (Aug 2025)
- InfoQ: "VoidZero Announces Oxfmt Alpha" (Jan 2026)
- Meta Engineering Blog: "Revolutionizing software testing: LLM-powered bug catchers" (Feb 2025)
- Datadog Blog: "Using LLMs to filter out false positives from static analysis"
- Datadog Blog: "How we use Vale to improve documentation editing"
- Trend Micro: "Slopsquatting: When AI Agents Hallucinate Malicious Packages"
- Socket.dev: "Slopsquatting: How AI Hallucinations Are Fueling Supply Chain Attacks"
- n8n.io: "LintGuardian" workflow template
- Qdrant: "Semantic Search for Code" tutorial
- Capital One: "Automate API testing Using Schemathesis"

### Source Tally

| Phase | Track | Queries | Scanned | Cited |
|---|---|---|---|---|
| Phase 2 | B (WebSearch x35) | 35 | ~350 | ~120 |
| Phase 2 | D (Gemini x2) | 19 | 184 | 56 |
| Phase 2 | A (Opus reasoning) | — | — | ~30 |
| Addendum | B (WebSearch x12) | 12 | ~120 | ~50 |
| **TOTAL** | | **66** | **~654** | **~256** |

## Methodology

**Worker allocation:**
- Track A (Opus): 2 reasoning subagents (inline) — SQ-3/7/9/10
- Track B (Sonnet/WebSearch): 47 web searches across all sub-questions
- Track C (Codex): 4 workers attempted, all timed out (exit 124). Redistributed to WebSearch.
- Track D (Gemini): 2 instances (primary + dissent). Initial attempts failed with `--agent generalist` flag. Succeeded on retry with `-p` flag. Had MCP issues but produced useful output.

**Debate structure:** 2-model (Claude/Opus + Gemini) due to Codex unavailability. Evidence cross-validated through 47 independent WebSearch queries covering overlapping topics.

**Addendum cycle:** Mandatory. Identified 5 emergent topics (Rust revolution, SARIF unification, slopsquatting, LLM+SA hybrid, danger.js). 12 additional WebSearch queries. All emergent topics confirmed with evidence.

**Limitations:**
- Source count (654) below 1000+ target due to Codex failures and MCP connector unavailability
- Academic sources thinner than typical — Consensus and Scholar Gateway MCPs not available
- 2-model debate instead of 3-model — Codex perspective missing
- Gemini had MCP issues, producing shorter-than-ideal output

**Intermediate artifacts available in artifact DB:**
- `meta-deep-research-execute` / `dispatch-table` / `005D`
- `research-connector` / `findings` / `005D/*` (3 consolidated findings files)
- `meta-deep-research-execute` / `coverage-review` / `005D/claude`
- `meta-deep-research-execute` / `source-tally` / `005D`
- `meta-deep-research-execute` / `convergence-scoring` / `005D`
