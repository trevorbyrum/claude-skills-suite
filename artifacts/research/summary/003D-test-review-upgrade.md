# Deep Research Summary — 003D: Test Review Skill Upgrade

> Date: 2026-03-11
> Sources: 60+ queries | 80+ scanned | 45+ cited
> Agents: 5 Sonnet research agents (parallel)
> Scope: Exhaustive — validate existing + discover missing

---

## Executive Summary

The current test-review skill is **substantially aligned with industry best practices** across all 8 existing categories. Google SWE Book, Meta ACH research, ISO 29119, ISTQB, and testsmells.org validate every current check. However, **6 significant gaps** exist that prevent the skill from being best-in-class, and **3 existing checks need refinement**.

The single most important finding: **mutation testing is the ground truth for test adequacy**, not coverage. AI-generated tests routinely achieve 100% line coverage while scoring 4% on mutation testing. This is the #1 addition needed.

---

## Confidence Map

| Finding | Confidence | Sources |
|---------|-----------|---------|
| Mutation testing is essential for AI-assisted codebases | HIGH | Meta ACH, Google Testing Blog, Sentry engineering, academic consensus |
| Property-based testing fills gaps example tests structurally cannot | HIGH | Trail of Bits, Hypothesis docs, arXiv 2510.09907, empirical studies |
| Contract testing is required for microservices | HIGH | Pact docs, Spotify honeycomb, Martin Fowler |
| Test pyramid is not universal — shape depends on architecture | HIGH | Fowler 2021, Dodds trophy, Spotify honeycomb, Google hourglass |
| 80% coverage is not a meaningful quality target | HIGH | Meta ACH ("coverage doesn't find faults"), Google best practices |
| CRAP score is the best single metric for review prioritization | MEDIUM | Academic studies, SonarQube adoption, limited industry validation |
| Feature flag coverage is a major blind spot | MEDIUM | vfunction, LaunchDarkly, limited empirical data |
| LLM Magic Number Test smell at 85-99% prevalence | MEDIUM | Single study (20,505 suites), needs replication |

---

## Validation of Current Skill (8 Categories)

### Solid — Keep As-Is
1. **Test landscape mapping** — Correct per Google SWE Book. Enhancement: also detect testing strategy shape.
2. **Feature-to-test mapping** — Correct per ISO 29119-3 (requirements traceability).
3. **Stub detection** — Validated by testsmells.org taxonomy. Note: deprioritize vs mutation testing.
4. **Missing error paths** — Correct per ISTQB equivalence partitioning. Expand scope (see below).
5. **Coverage gaps** — Correct heuristic. Needs quantitative threshold (CC >10).
6. **Test infrastructure** — Correct per Google engineering practices.

### Need Refinement
7. **Mock overuse detection** — Partially misguided. Mocking external I/O is correct, not overuse. Refine to: "mocks of types the SUT *owns*" not "mocks of external dependencies."
8. **Fragile test detection** — Incomplete. Add: date/time dependencies (datetime.now() without injection), network dependencies (real HTTP calls without VCR), filesystem state.
9. **Error path detection** — Incomplete. Add: exception hierarchy testing, timeout/retry paths, partial failure in batch operations, resource exhaustion.

---

## New Sections to Add (Priority Order)

### P0: Mutation Testing Adequacy
**The most critical gap.** Meta and Google validate this is the ground truth.

- **Tools**: Stryker (JS/TS), PIT (Java), mutmut (Python), cargo-mutants (Rust), Gremlins (Go)
- **Score thresholds**: 90%+ auth/payments/safety, 75-90% business logic, 50-75% utilities, <50% inadequate
- **Reviewer checks**: Is mutation tool configured? If score data exists, parse it. Flag modules <80%.
- **Key insight**: VoidMethodCalls mutations have lowest kill rate (~69%) — strongest signal for missing side-effect assertions
- **When overkill**: prototype code, UI rendering, coverage <50% (fix coverage first)

### P0: Cyclomatic Complexity-Based Gap Detection
Quantify "complex functions" — currently subjective.

- **Threshold**: CC >10 = high complexity (ISO 29119, industry standard)
- **CRAP score**: `CC² × (1 - coverage)³ + CC`. Score >30 = needs action, >60 = high risk
- **Tools**: radon (Python), complexity-report (JS), gocyclo (Go), cognitive-complexity (SonarQube)
- **Actionable**: Any function CC >10 with no test = concrete finding, not subjective judgment

### P1: Property-Based Testing Detection
Each PBT property finds ~50x as many mutations as average unit test.

- **7 PBT patterns**: roundtrip, oracle/differential, metamorphic, invariant, model-based, commutativity, easy-to-verify
- **Trail of Bits trigger list**: serialization pairs, parsers, normalization, validators, custom data structures, math/algorithmic functions — any of these without PBT = finding
- **Signs of absence**: 5+ parametrized tests with similar inputs, encode/decode with single-value tests, no edge cases on parsers, stateful objects with ≥3 mutating methods
- **Tools**: Hypothesis (Python), fast-check (JS/TS), proptest (Rust), jqwik (Java, maintenance-only)
- **When overkill**: simple CRUD, UI rendering, external API wrappers, one-off scripts

### P1: Contract Testing for Service Boundaries
Missing link in microservices testing.

- **When required**: any service boundary crossing team ownership with independent deployments
- **Not needed**: monorepos with coordinated deploys, stable versioned SDKs
- **Tools**: Pact (language-agnostic, most mature), Spring Cloud Contract (JVM), Specmatic (OpenAPI-first), Microcks (AsyncAPI/Kafka)
- **Reviewer red flags**: HTTP mocks (nock, WireMock) with no .pact file, integration tests hitting real services, no `can-i-deploy` CI gate
- **GraphQL/gRPC**: Pact supports both via plugins

### P1: Test Strategy Shape Assessment
The test pyramid is not universal.

- **Pyramid**: still valid for algorithmic/TDD code, breaks in microservices
- **Trophy** (Dodds): correct for JS/TS SPAs, integration-heavy
- **Honeycomb** (Spotify): microservices standard, integration-heavy with contract tests replacing E2E
- **Hourglass**: the #1 antipattern (Google documented) — unit + E2E heavy, no middle layer
- **Reviewer action**: detect architecture type, compare unit/integration/E2E ratios, flag mismatched strategy
- **Heavy E2E wrong when**: CI >30 min, >20% E2E flaky, or duplicates integration coverage

### P2: LLM-Generated Test Anti-Patterns (Enhanced)
Beyond current stub/mock detection.

- **Magic Number Test**: 85-99% prevalence in LLM tests vs near-zero in human tests — reliable AI-written signal
- **Test Oracle Problem**: LLMs assert by "mentally executing" implementation, not reasoning from spec
- **Coverage Theater**: 100% line coverage, 4% mutation score (documented pattern)
- **Hallucinated APIs**: assertions on methods/properties that don't exist
- **Data Model Mismatch**: fixtures with wrong field names or types
- **Copilot-specific**: 92.45% failure rate without existing test context, 54.72% with context
- **Detection**: mutation testing catches all of these — it's the universal detector

### P2: Feature Flag Coverage
Largest dead-code blind spot (2025 research).

- **Check**: both flag branches (on/off) must have tests
- **Flag staleness**: flags constant >90 days should be flagged for removal
- **Tools**: LaunchDarkly audit API, Flagsmith, vfunction
- **Pattern**: search for `if (featureFlags.get('x'))` → verify test covers both branches

### P2: Test Infrastructure Enhancements
- **Test isolation**: tests sharing mutable global state = root cause of order-dependency
- **Parallel safety**: suites that can't run in parallel block fast CI
- **Testcontainers**: recommend for DB-dependent tests (86x speedup documented with transaction rollback)
- **CI targets**: full suite <10 min, parallelize at >5 min
- **Flakiness**: async timing (45%), concurrency (20%), order dependency (12%) — fix timing with explicit awaits, not longer timeouts
- **Quarantine pattern**: Slack achieved 19.82% → 96% stability by quarantining not disabling

### P3: Additional Checks
- **Test naming quality**: behavioral names (given/when/then) vs method names — ISO 29119, Google SWE Book
- **Boundary value analysis**: tests at exact partition boundaries, not just typical values
- **State transition testing**: stateful APIs, auth flows, workflow engines
- **Date/time injection**: datetime.now() without time injection = timezone/midnight flakiness

---

## Test Quality Metrics Hierarchy (for reviewer)

```
Mutation Score > Branch Coverage > CRAP Score > Assertion Density > Line Coverage
```

- **Mutation score**: ground truth. <60% = block, 60-80% = warning, >80% = good
- **Branch coverage**: strictly stronger than line coverage. `coverage.py --branch`, `go cover -covermode=atomic`
- **CRAP score**: best for prioritizing review effort. >30 = needs action, >60 = refactor first
- **Assertion density**: Microsoft Research + 54-company study confirms strongest correlate with reduced defects. 0 assertions = P0 finding.
- **Line coverage**: useful as CI floor (60% min), not quality signal. 80% target has no research basis.

---

## Coverage Gap Detection Stack (Practical)

1. **Import graph analysis** (static, zero-overhead) — files with no test coverage at all
2. **Coverage diff tooling** (lcov/Codecov on CI) — specific uncovered lines/branches
3. **Mutation testing** (Stryker/PIT/mutmut/cargo-mutants) — covered but not meaningfully tested
4. **Coverage-guided fuzzing** (per-module) — deep edge cases for parsers/input handlers
5. **Symbolic execution** (targeted, offline) — security-critical C/C++/Rust only

---

## Progressive Disclosure Structure (Recommended)

```
skills/test-review/
  SKILL.md                          (~250 lines, scannable)
  references/
    mutation-testing-guide.md       (tools, thresholds, interpretation)
    pbt-patterns.md                 (7 patterns, trigger list, framework guide)
    contract-testing-guide.md       (when required, tools, red flags)
    test-strategy-shapes.md         (pyramid/trophy/honeycomb decision tree)
    llm-test-antipatterns.md        (smell taxonomy, detection signals)
    metrics-reference.md            (full metrics hierarchy, tools, thresholds)
```

---

## Sources (45+ cited)

### Mutation Testing
- Meta ACH: engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/
- Meta LLM Mutation: engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/
- Stryker Mutator: stryker-mutator.io
- PIT: pitest.org
- MutGen (89.5% mutation score): arxiv.org/html/2506.02954v2

### Property-Based Testing
- Trail of Bits PBT guide: blog.trailofbits.com
- Hypothesis: hypothesis.works
- Agentic PBT ($9.93/bug): arxiv.org/html/2510.09907v1
- fast-check: fast-check.dev

### Contract Testing
- Pact: docs.pact.io
- Specmatic: specmatic.io
- Schemathesis: schemathesis.readthedocs.io

### Test Strategy
- Martin Fowler testing shapes: martinfowler.com/articles/2021-test-shapes.html
- Kent C. Dodds trophy: kentcdodds.com/blog/the-testing-trophy-and-testing-classifications
- Spotify honeycomb: engineering.atspotify.com

### Standards & Industry
- Google SWE Book Ch 12-14: abseil.io/resources/swe-book
- Google Testing Blog: testing.googleblog.com
- ISO 29119: softwaretestingstandard.org
- testsmells.org taxonomy: testsmells.org/pages/testsmells.html

### LLM Test Quality
- 20,505-suite study (Magic Number Test 85-99%): PMC research
- Copilot failure rates: AST 2024 empirical study
- CANDOR (97.1% oracle correctness): arxiv.org

### Coverage & Fuzzing
- AFL++/libFuzzer/ClusterFuzz: google.github.io/clusterfuzz
- KLEE: klee-se.org
- WingFuzz data coverage: USENIX Security 2024
- Atheris Python fuzzer: Google Open Source Blog

### Infrastructure
- Testcontainers: testcontainers.com
- Slack flakiness quarantine: slack.engineering
- Launchable test selection: launchable.com
- DeFlaker: cs.cornell.edu
