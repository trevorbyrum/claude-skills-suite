# Deep Research: Contract Testing & Test Quality Metrics
## Research for test-review skill upgrade
**Date:** 2026-03-11
**Sources:** 35+ web sources, academic papers, tool documentation

---

## TOPIC 1: Contract Testing

### What Contract Testing Is and Is Not

Contract testing validates that two services—a consumer and a provider—agree on the shape and semantics of their interaction. It sits between unit tests (too narrow) and full integration/E2E tests (too slow, too fragile):

| Test Type | Complexity | Speed | Coverage |
|-----------|-----------|-------|----------|
| Unit | Low | Fast | Low |
| Contract | Low | Fast | Medium |
| Integration | High | Slow | High |
| E2E | Very High | Very Slow | High |

Contract testing does NOT replace:
- Unit tests for internal business logic
- Database integrity, authorization, or concurrency tests
- UI testing, performance under load
- Multi-hop workflow testing (still needs integration/E2E)

---

### When Contract Testing Is Required

**Mandatory triggers — flag as a gap if absent when any of these apply:**
1. Multiple teams own interdependent services (team code ownership boundaries = service boundaries)
2. Services deploy independently without a coordinated release train
3. Any external or third-party API integration
4. Rapid iteration where silent API regression risk is high
5. Any service-to-service HTTP/gRPC/event boundary crossing a team boundary

**Not required when:**
- All consumers are in the same repo with the same deploy cycle (monorepo monolith)
- The "provider" is a stable, versioned external SDK (e.g., AWS SDK)
- The interaction is one-way fire-and-forget with no schema expectations

---

### Consumer-Driven vs Provider-Driven Contracts

#### Consumer-Driven (Pact model)
- The consumer writes tests that define exactly what it needs from the provider
- Only the parts of the provider actually consumed are tested — unused fields can change freely
- Consumer generates a `.pact` JSON file; provider verifies against it
- Preferred when: multiple consumers with different needs, consumer teams are autonomous, you want to detect when provider changes break real consumers
- Key property: the contract is derived from consumer code, reducing drift

#### Provider-Driven / Spec-Driven (Specmatic, Dredd model)
- The OpenAPI/Swagger spec is the contract; provider must implement it faithfully
- Consumers generate stubs/mocks from the same spec
- Preferred when: spec-first development, compliance requirements, existing OpenAPI documentation, one provider serves many consumers
- Key limitation: a provider can satisfy its own spec while still breaking a consumer who calls it in an unexpected way

#### Bi-Directional (PactFlow BDCT)
- Consumer publishes a consumer contract (from existing mocks, Cypress, MSW, Playwright)
- Provider publishes its OpenAPI spec
- PactFlow performs static cross-contract comparison
- No provider verification build required
- Best for: retrofitting onto existing systems, third-party APIs, teams with existing API mocking infrastructure
- Reduces developer effort vs CDCT by >50% per field reports
- `can-i-deploy` command in CI/CD gates deployments on compatibility verification

---

### Tool Reference

#### Pact (pact.io / PactFlow)
- **Model:** Consumer-driven, code-first, contract-by-example
- **Languages:** Java, JS/TS, Python, Ruby, .NET, Go, PHP, Swift, C++
- **Transports:** HTTP REST, GraphQL (via HTTP), gRPC/Protobuf (via Plugin Framework), Kafka/Avro (via Plugin Framework)
- **Broker:** Pact Broker (OSS) or PactFlow (SaaS) for storing/sharing contracts
- **CI gate:** `can-i-deploy` — queries broker to confirm both consumer and provider versions are compatible before deploy
- **Strengths:** Language-neutral JSON pacts, consumer code generates contracts (no drift), provider states for test data setup, mature ecosystem
- **Limitations:** Consumer must write Pact tests explicitly; steep learning curve; Python library significantly less mature than Java

**gRPC/Protobuf support:**
- Requires installing `pact-protobuf-plugin` via Pact CLI
- Tests specify proto file path, service method, request/response structures using Protobuf types
- Catches: protocol-level mismatches, type safety violations, field-level semantic changes
- v0.5.0 (2024): added provider state value injection into message fields and gRPC metadata

**GraphQL support:**
- GraphQL is HTTP under the hood — standard Pact HTTP interactions work
- Define the query body as the request; match response fields the consumer uses

#### Spring Cloud Contract
- **Model:** Both consumer-driven AND provider-driven (provider can write contracts)
- **Languages:** JVM only (Java, Kotlin, Groovy); contracts written in Groovy DSL or YAML
- **Contract storage:** Must be in a single shared Git repository per provider (all consumers' contracts together)
- **Stubs:** Generates WireMock stubs for consumers automatically
- **Strengths:** Deep Spring/JVM integration, provider-driven option, familiar to Spring teams
- **Limitations:** JVM-only, central repository creates coordination overhead, harder for polyglot environments
- **Choose when:** Full Spring ecosystem, JVM monoglot shop, want provider-driven workflow option

#### Specmatic
- **Model:** Provider-driven / spec-driven (OpenAPI as executable contract)
- **Languages:** JVM (Kotlin/Java core), CLI available
- **Features:** Contract tests from OpenAPI specs, service virtualization (smart mocks), backward compatibility checking, schema resiliency tests (auto-generates invalid inputs), Kafka contract testing
- **Workflow:** `specmatic test` runs the spec against a running provider; provider gets spec-valid response validation
- **Choose when:** Existing OpenAPI specs, spec-first development, multi-consumer single-spec scenarios, compliance needs

#### Dredd
- **Model:** Provider-driven, tests API descriptions against backend implementation
- **Languages:** Go, Node.js, Python, Ruby, Rust, PHP, Perl (language-agnostic CLI)
- **Formats:** OpenAPI 2.0 (full), OpenAPI 3.x (experimental support)
- **Strengths:** Simple, no broker needed, validates spec against implementation
- **Limitations:** One-directional (only tests that provider matches spec, not that consumers are using it correctly); experimental OAS3 support
- **Choose when:** Simple APIs, quick spec-to-reality validation, no multi-consumer complexity

#### Schemathesis
- **Model:** Property-based testing / schema fuzzing (NOT contract testing per se)
- **Languages:** Python (but tests any HTTP API via CLI)
- **Source:** OpenAPI, GraphQL schemas
- **Key distinction:** Does NOT validate bilateral agreements. Instead, auto-generates hundreds of test cases from the schema, including edge cases, boundary violations, invalid inputs
- **What it finds that contract tests miss:** Boundary violations, constraint violations, type mismatches, server crashes from edge-case inputs, validation bypasses, stateful bugs in multi-step workflows
- **Field results:** 4.5x more unique defects than second-best fuzzer; surfaces 5-15 issues on first run against production schemas
- **CI integration:** GitHub Actions, GitLab CI, pytest
- **Choose when:** Supplementary to contract testing, especially for public-facing APIs; fuzz testing; OpenAPI spec/implementation drift detection

#### Karate
- **Model:** Multi-purpose (contract, performance, UI, Kafka testing) via low-code DSL
- **Languages:** DSL-driven, multi-language
- **Kafka support:** Built-in `topic` and `produce` keywords for async API testing with Kafka; supports Avro and JSON serialization
- **Choose when:** Cross-functional teams, low-code preference, need Kafka + REST contract testing in one tool

#### Microcks
- **Model:** Mock-and-test via open standards (OpenAPI, AsyncAPI, gRPC, SOAP)
- **Kubernetes:** Deployable on Kubernetes
- **Async support:** Native AsyncAPI support; connects to real Kafka broker, publishes mock messages, validates incoming messages against schema
- **Limitation (2025):** Cannot simulate causal link between synchronous HTTP action and async event — hybrid workflow contract testing is not yet supported (open issue as of July 2025)
- **Choose when:** Kubernetes-native teams, AsyncAPI/Kafka contracts, end-to-end mock coverage

#### WireMock
- **Model:** Mock server for edge-case and unstable dependency simulation
- **Note:** WireMock alone is NOT contract testing — it can be used as the consumer-side test double in bi-directional contracts but provides no provider verification
- **Choose when:** Supplementary mock infrastructure alongside Pact or BDCT

---

### How a Reviewer Detects Missing Contract Coverage

#### Direct Code Signals (file/code patterns to flag)

1. **Integration tests that start a real external service or call live URLs**
   - Test imports that spin up Docker Compose with external dependencies
   - `@SpringBootTest` with `webEnvironment=DEFINED_PORT` calling real downstream services
   - Hardcoded staging/prod URLs in test setup
   - No mock/stub for the outgoing HTTP calls in unit-level tests

2. **Mocked APIs without contract validation**
   - `jest.mock()`, `WireMock`, `nock`, `responses`, `httpretty`, `requests_mock` — any HTTP mock without a corresponding `.pact` file, Specmatic test, or Dredd hook
   - Mocks that return static JSON blobs hardcoded in test files (no schema enforcement)
   - Mock responses that look like they were written once and never updated

3. **No `.pact` files or pact broker configuration in the repo**
   - Missing `pact` dependency in package.json / pom.xml / build.gradle / requirements.txt
   - No `PACT_BROKER_URL` or `pactflow` config anywhere in CI/CD files
   - No `specmatic.yml`, `dredd.yml`, or equivalent

4. **Tests that verify too much (brittle contracts)**
   - Contract tests using exact-match on entire response bodies instead of type/regex matchers
   - Hardcoded timestamps, UUIDs, or tokens in contract assertions

5. **Provider has no `/setup` or provider state endpoint**
   - In Pact: provider state setup (`@State` in Spring, `stateHandlers` in JS) is absent
   - Means consumer contract tests will fail on provider side from missing data

6. **Service-to-service clients with no contract**
   - A `RestTemplate`, `axios`, `requests`, `http.Client`, `grpc.Dial` call crossing a team boundary with no corresponding contract test in either service

7. **E2E tests doing contract-level work**
   - End-to-end tests that exist solely to verify field names and types in API responses (contract tests in disguise, but slow and fragile)

#### Anti-Patterns to Call Out

| Anti-Pattern | Impact | Recommendation |
|---|---|---|
| One-sided testing (consumer only, no provider verification) | False confidence | Require provider verification in CI |
| Hard-coded values in contracts | Brittle tests that break on dynamic data | Use type matchers, regex matchers |
| No contract versioning strategy | Silent breaking changes | Require semantic versioning tags on Pact Broker |
| No `can-i-deploy` gate | Services deploy incompatible versions | Add as pre-deploy CI step |
| Contract tests in E2E layer | Slow, fragile, wrong layer | Move to unit-level consumer tests |
| Mock not derived from contract | Mock drifts from reality | Use Specmatic service virtualization or WireMock stubs generated from contracts |

---

### GraphQL Contract Testing Patterns

- GraphQL is HTTP — Pact HTTP interactions work as-is
- Consumer test: define the query in request body, specify only fields the consumer uses in response
- Key insight: two consumers using the same GraphQL endpoint may use different subsets — consumer-driven contracts handle this better than provider-driven
- Schemathesis supports GraphQL schema-based fuzzing as a complement

---

### gRPC/Protobuf Contract Testing Patterns

- **Pact Plugin Framework** is the primary mechanism (pact-protobuf-plugin)
- Install: `pact-plugin-cli install https://github.com/pactflow/pact-protobuf-plugin`
- Test specifies: proto file path, service method name, request message fields, response message matchers
- Catches: field type mismatches, missing required fields, added breaking fields, package name changes
- Alternative: generate REST/HTTP gateway alongside gRPC and test the HTTP layer with standard tools

---

### Kafka / Async / Event-Driven Contract Testing

- **Pact:** Message Pact for async interactions (message shape only, not transport)
- **Microcks:** Native AsyncAPI spec → Kafka mock; validates message schemas against spec
- **Karate:** `topic`/`produce` DSL keywords, Avro/JSON support
- **Specmatic:** Kafka contract testing support built-in

---

### CI/CD Integration Checklist

```
Consumer CI:
  [ ] Consumer tests generate .pact files
  [ ] .pact files published to Pact Broker / PactFlow
  [ ] can-i-deploy check before deploy

Provider CI:
  [ ] Provider verification job fetches latest consumer contracts
  [ ] Provider verification passes all consumer pacts
  [ ] can-i-deploy check before deploy
  [ ] Webhook triggers provider verification when new pact published
```

---

## TOPIC 2: Test Quality Metrics Beyond Line Coverage

### The Coverage Trap

Line coverage is a **negative indicator only**: low coverage definitively signals a gap; high coverage proves nothing about test quality.

The pathological case: 100% line coverage with 0 assertions. The tests execute every line but verify nothing. Mutation testing would expose this instantly.

Research finding: "Coverage and mutation score are weakly positively correlated — mutation score is NOT a 'refined' coverage score; reporting one without the other paints a partial picture." (AST 2024 research)

---

### Metric Hierarchy (Most to Least Actionable for AI Reviewer)

| Rank | Metric | What It Measures | Actionability | Tooling |
|------|--------|-----------------|--------------|---------|
| 1 | **Mutation Score** | Whether tests catch real bugs (execution + assertions) | High — flags assertion gaps | PIT, Stryker, mutmut, Cosmic Ray |
| 2 | **Branch Coverage** | All control paths tested | High — finds missing edge cases | Istanbul/nyc, JaCoCo, coverage.py |
| 3 | **CRAP Score** | Risk-weighted: complexity × untested coverage | High — prioritizes review effort | NDepend, OpenClover |
| 4 | **Assertion Density** | Assertions per test method | Medium — proxies for test thoroughness | Static analysis, custom lint |
| 5 | **Line/Statement Coverage** | Lines executed | Medium (negative indicator only) | Istanbul, coverage.py, go cover, tarpaulin, JaCoCo |
| 6 | **Test-to-Code Ratio** | Volume of test code vs production code | Low — inflated by low-value tests | LOC counters |
| 7 | **MC/DC** | Each condition independently affects outcome | Very High (safety-critical only) | LDRA, VectorCAST, specialized tools |
| 8 | **Cyclomatic Complexity** | Code path count | Indirect — drives CRAP, not directly actionable alone | SonarQube, complexity tools |

---

### Mutation Testing: The Gold Standard

#### How It Works
1. Tool introduces small, single-change faults ("mutants") into production code
2. Full test suite runs against each mutant
3. If tests FAIL → mutant "killed" (good — tests caught the bug)
4. If tests PASS → mutant "survived" (bad — tests missed a detectable bug)
5. Mutation Score = Killed / (Killed + Survived) × 100

#### What Mutation Catches That Coverage Misses
- Tests that execute code but assert nothing (assertion-free tests)
- Off-by-one errors (changing `>` to `>=`)
- Logical operator flips (`&&` to `||`)
- Missing null checks
- Incorrect conditional logic
- Return value errors

#### Thresholds by Context

| Score | Interpretation | Action |
|-------|---------------|--------|
| 90%+ | Excellent | Required for payments, auth, safety-critical code |
| 75–90% | Good | Production quality; address remaining gaps |
| 50–75% | Moderate | Needs improvement; flag for review |
| < 50% | Poor | Tests are ineffective; treat as a bug |

Stryker.NET default thresholds: `high: 80, low: 60, break: 0` (break=0 means build does NOT fail by default — teams must set break explicitly, e.g., `break: 60`).

PIT (Java) example: `mutationThreshold: 85, coverageThreshold: 85` — breaks build if either falls below.

#### Practical Limitations

1. **Equivalent mutants:** Code changes that don't affect observable behavior (~3% of mutants in practice per 2024 ISSTA research). These are semantically equivalent but syntactically different — tests can never kill them. Modern tools (EMS technique, 2024) detect ~4× more equivalent mutants than prior techniques, dramatically reducing false-failure noise.

2. **Execution cost:** Full mutation testing runs can be 10–100× longer than the test suite. Mitigation strategies:
   - Run nightly or on PR merge, not on every commit
   - **Incremental mode** (Stryker `since`/`with-baseline`, arcmutate for PIT): only mutate changed code since last run
   - Scope to critical modules first

3. **Not all mutants are equal:** Trivial mutations (string constant changes) inflate scores without meaningful signal. Use tool-specific mutation operator selection to exclude noise.

---

### Tool Reference: Mutation Testing

#### PIT / Pitest (Java/JVM)
- **Languages:** Java, Kotlin, Scala (JVM)
- **Build:** Maven plugin (`org.pitest:pitest-maven`), Gradle (`info.solidsoft.pitest`)
- **Speed:** Bytecode-level mutation — fast vs AST-based tools
- **Incremental:** arcmutate (commercial) for PR-level analysis
- **Reports:** HTML + XML; color-coded line vs mutation coverage side-by-side
- **CI break:** `mutationThreshold` and `coverageThreshold` in plugin config
- **Key guidance:** "Tempting to run in main CI pipeline — rarely a good idea. Use dedicated CI jobs or scheduled builds."

#### Stryker (JS/TS, C#, Scala)
- **StrykerJS:** JavaScript, TypeScript — 30+ mutation operators
- **Stryker.NET:** C# — Maven/Gradle equivalent for .NET
- **Stryker4s:** Scala
- **Thresholds:** `high: 80, low: 60, break: 0` (defaults) — set `break` to enforce CI gate
- **Incremental:** `--since` flag compares against git ref; `--with-baseline` caches between runs
- **Dashboard:** `dashboard.stryker-mutator.io` — visual reports showing surviving mutants
- **FOSDEM 2024:** Active development track

#### mutmut (Python)
- **Most actively maintained** Python mutation tool as of 2024
- 6 mutation operators
- Simple CLI; works with pytest, unittest
- Less feature-rich than Cosmic Ray but more reliable

#### Cosmic Ray (Python)
- 9 mutation operators; more customization
- Build-tool integration (only Python tool with this capability)
- Community active but mutmut has more frequent commits
- Choose for: advanced mutation operator customization

#### MutPy (Python)
- AST-based; historically popular but less actively maintained than mutmut/Cosmic Ray
- Still valid for projects that depend on it

---

### Branch Coverage vs Line Coverage vs Statement Coverage

**Hierarchy of strictness:** MC/DC > Condition Coverage > Branch Coverage > Statement/Line Coverage > Function Coverage

**Practical recommendation:**
- **Branch coverage is the minimum bar** for meaningful coverage metrics. Line coverage is a good starting point but misses untaken else-branches
- Example: `if condition { return x }` — line coverage passes if this line executes regardless of whether the false branch is ever tested
- "Two most useful metrics: branch coverage and function coverage. Line coverage is the least useful." (Codecov research)
- **Use both line and branch** together — line to ensure no dead code paths, branch to catch missed edge cases

**Coverage type support by tool:**

| Tool | Language | Line | Branch | Statement | Condition |
|------|----------|------|--------|-----------|-----------|
| Istanbul/nyc | JS/TS | ✓ | ✓ | ✓ | - |
| V8 coverage | JS/TS | ✓ | ✓ | - | - |
| coverage.py | Python | ✓ | ✓ | - | - |
| go cover | Go | ✓ | ✓ | - | - |
| tarpaulin | Rust | ✓ (line only, noted as early-stage) | - | - | - |
| grcov | Rust | ✓ | ✓ | - | - |
| JaCoCo | Java | ✓ | ✓ | ✓ | - |
| OpenClover | Java | ✓ | ✓ | ✓ | CRAP |
| Cobertura | Java | ✓ | ✓ | - | - |

---

### CRAP Score (Change Risk Anti-Patterns)

**Formula:** `CRAP(m) = CC(m)² × U(m)³ + CC(m)`

Where:
- `CC(m)` = cyclomatic complexity of method m
- `U(m)` = fraction of method NOT covered by tests (0.0 to 1.0)

**Key property:** The formula exponentially penalizes complex, untested code. A method with CC=6 and 0% coverage = CRAP score of 37 (above the risky threshold of 30).

**Thresholds:**
| CRAP Score | Risk Level | Action |
|---|---|---|
| 0–30 | Acceptable | No action |
| 30–60 | Attention needed | Add tests or refactor |
| 60+ | High risk | Prioritize for redesign |

**Ceiling:** If cyclomatic complexity exceeds 30, no amount of test coverage can bring CRAP below 30. The method needs refactoring, not more tests.

**For AI reviewer:** CRAP score is the best single metric for prioritizing where to direct test improvement effort. A high-CC, low-coverage method is a ticking time bomb. Flag any method with CRAP > 30.

---

### Cyclomatic Complexity as a Testing Signal

**Thresholds:**
| CC | Complexity | Testing Implication |
|----|-----------|-------------------|
| 1–6 | Low | Straightforward; basic coverage sufficient |
| 7–9 | Moderate | Should have branch coverage |
| 10–20 | High | Needs extensive testing; consider refactoring |
| 20+ | Very high | Near-untestable; refactor first |

**Key insight:** Cyclomatic complexity tells you HOW MANY test cases are needed to achieve branch coverage. A CC=10 method needs at minimum 10 test cases for full branch coverage.

---

### MC/DC (Modified Condition/Decision Coverage)

**Context:** Required by DO-178C Level A (aviation software where failure = loss of aircraft). Also required/recommended in ISO 26262 (automotive), IEC 61508 (functional safety), IEC 62304 (medical devices).

**What it requires:** Each boolean condition in a decision must independently affect the decision outcome — demonstrated by test cases.

**Efficiency advantage:** For N conditions, MC/DC requires only N+1 test cases vs 2^N for full condition coverage. For 16 conditions: 17 tests vs 65,536.

**For general software:** MC/DC is overkill for most applications. It is relevant only for:
- Safety-critical software with regulatory requirements
- Authentication / authorization logic where partial condition coverage is a security risk
- Financial calculation logic with complex conditionals

**Tools:** LDRA, VectorCAST, Testwell CTC++ — NOT mainstream developer tooling.

---

### Assertion Density

**Definition:** Number of assert/expect/verify statements per test method (or per line of test code).

**Research backing:** Microsoft Research (ISSTA-cited study) found statistically significant negative relationship between assertion density and post-release fault density. Higher assertion density → fewer production defects.

**STREW-J metric suite** (54-company study): assertion density is the single test quantification metric most correlated with reduction in post-release defects.

**Practical thresholds:** No universal standard, but:
- 0 assertions per test = useless test (smoke test at best)
- 1 assertion per test = minimal but acceptable
- 3–5 targeted assertions = good
- 15+ assertions in a single test = test is doing too much (brittle)

**For AI reviewer:** Flag test methods with 0 assertions. Flag test methods that call a function/method but assert nothing about its return value or side effects.

---

### Test-to-Code Ratio

**Definition:** Lines of test code ÷ Lines of production code

**Research finding:** Test-to-code ratio (volume metric) is a weaker predictor of quality than assertion density (depth metric). A codebase can have 3:1 test-to-code ratio with 0% mutation score if tests don't assert.

**Common ranges:** Production codebases vary from 0.5:1 to 3:1. No universal "right" ratio.

**For AI reviewer:** Useful only as a red flag at the low end (< 0.3:1 suggests undertesting). Not a positive quality signal at the high end.

---

### Is 80% Coverage a Useful Target?

**Research consensus:**
- 80% line coverage is the most cited threshold, but has no rigorous basis — it was popularized informally
- 80% coverage can give false confidence: the 80% covered could be trivially covered; the missing 20% might be the most critical code
- "Reaching from 80% to 100% is costly and usually produces complex, difficult-to-maintain tests"
- NIST guidance: management-mandated coverage quotas often backfire by incentivizing hollow tests

**What research actually recommends:**
1. Do not use a single universal threshold — context matters
2. Critical code (auth, payments): target 90%+ branch coverage + mutation testing
3. Application logic: 80% branch coverage is a reasonable floor
4. Generated/boilerplate code: exempt from coverage requirements
5. The interesting question is not "did we hit 80%?" but "what is in the untested 20%, and does it matter?"

**SonarQube "Sonar way for AI Code" standard:** Requires ≥80% coverage for new code, ≤3% duplication — reasonable industry floor for new code.

**Better approach:** Use coverage as a CI gate floor (fail < 80%) + CRAP score to identify high-risk gaps + mutation score to validate coverage quality.

---

### Modern Coverage Tools: Deeper Notes

#### Istanbul / nyc (JavaScript/TypeScript)
- Istanbul = instrumentation engine; nyc = CLI wrapper
- Gold standard since 2012; de facto for all JS/TS projects
- Supports Jest, Mocha, Ava, Jasmine, Karma, and more
- Outputs: lcov, html, json, text-summary, cobertura
- Reports: line, statement, branch, function coverage
- V8 provider (native Node.js coverage) is an alternative — faster but less accurate branch detection
- **AI reviewer signal:** If a JS/TS project doesn't use Istanbul/nyc or Jest's built-in coverage (which wraps Istanbul), that is a gap.

#### coverage.py (Python)
- De facto standard for Python
- Works with pytest (`pytest-cov` plugin), unittest, Django test runner
- `--branch` flag enables branch coverage (not on by default — flag absence is a reviewer signal)
- `--fail-under=80` for CI gates
- `omit` configuration to exclude generated code, migrations, settings
- **AI reviewer signal:** `coverage run` without `--branch` = missing branch coverage

#### go cover (Go)
- Built-in tooling: `go test -coverprofile=coverage.out ./...`
- `go tool cover -html=coverage.out` for HTML report
- No external dependency needed
- Reports statement coverage; branch coverage via `-covermode=atomic`
- **AI reviewer signal:** Missing `-coverprofile` in CI scripts; no coverage threshold check

#### tarpaulin (Rust)
- `cargo tarpaulin` — line coverage, noted as "may contain minor inaccuracies"
- Alternative: `grcov` (from Mozilla) — more accurate, supports branch coverage, integrates with LCOV
- Alternative: `cargo-llvm-cov` — LLVM-based, most accurate, supports branch coverage
- **AI reviewer signal:** Missing any coverage step in Rust CI = gap; prefer `cargo-llvm-cov` over tarpaulin for accuracy

#### JaCoCo (Java)
- Free, OSS; built into Maven/Gradle via `jacoco` plugin
- Reports line, branch, instruction, method, class coverage
- Generates HTML, XML, CSV reports
- `failOnMinimumInstructionCoverage` for CI breaks
- Compatible with SonarQube for trending

---

### Actionable Rules for an AI Test Reviewer

#### Must-Flag (P0 — Block)
1. Test method with 0 assertions (executes code but asserts nothing)
2. CRAP score > 60 on any method
3. Mutation score < 50% on critical modules (auth, payment, data processing)
4. Coverage.py used without `--branch` flag
5. Coverage threshold not enforced in CI (no `-fail-under` or equivalent)

#### Should-Flag (P1 — Conditional)
6. Line coverage < 80% on new code
7. Branch coverage < 70% on new code
8. CRAP score 30–60 on any method (needs tests or refactor)
9. Mutation score 50–75% (needs improvement)
10. Test file with test-to-code ratio < 0.3 for core business logic
11. Stryker/PIT configured but `break` threshold = 0 (not enforcing gate)
12. Cyclomatic complexity > 15 with < 50% branch coverage

#### Informational (P2 — Suggest)
13. No mutation testing configured at all (suggest adding to nightly CI)
14. Test methods with > 10 assertions (consider splitting)
15. test-to-code ratio > 5:1 (may indicate test bloat)
16. Only line coverage tracked, not branch coverage
17. No CRAP metric tracking (suggest SonarQube or OpenClover)

---

## Sources

### Contract Testing
- [Introduction | Pact Docs](https://docs.pact.io/)
- [FAQ | Pact Docs](https://docs.pact.io/faq)
- [Comparisons with other tools | Pact Docs](https://docs.pact.io/getting_started/comparisons)
- [Contract Testing: The Missing Link in Your Microservices Strategy? | Gravitee](https://www.gravitee.io/blog/contract-testing-microservices-strategy)
- [PACT Contract Testing — Microsoft ISE Developer Blog](https://devblogs.microsoft.com/ise/pact-contract-testing-because-not-everything-needs-full-integration-tests/)
- [Bi-Directional Contract Testing | PactFlow](https://pactflow.io/bi-directional-contract-testing/)
- [gRPC contract testing: how to test gRPC/Protobuf with Pact + PactFlow](https://pactflow.io/blog/contract-testing-for-grpc-and-protobufs/)
- [Contract testing Protobufs, gRPC & Avro with Pact | Pactflow](https://pactflow.io/blog/the-case-for-contract-testing-protobufs-grpc-avro/)
- [pact-protobuf-plugin GitHub](https://github.com/pactflow/pact-protobuf-plugin)
- [Beyond Rest — Contract Testing in the Age of gRPC, Kafka and GraphQL](https://gitnation.com/contents/beyond-rest-contract-testing-in-the-age-of-grpc-kafka-and-graphql)
- [Contract Testing | Specmatic Docs](https://docs.specmatic.io/contract_driven_development/contract_testing.html)
- [Specmatic (homepage)](https://specmatic.io/)
- [Dredd — HTTP API Testing Framework](https://dredd.org/)
- [Schemathesis (homepage)](https://schemathesis.io/)
- [Automate API testing Using Schemathesis | Capital One](https://www.capitalone.com/tech/software-engineering/api-testing-schemathesis/)
- [10 Tools For API Contract Testing | Nordic APIs](https://nordicapis.com/10-tools-for-api-contract-testing/)
- [PACT vs Spring Cloud Contract — Saturn Cloud Blog](https://saturncloud.io/blog/pact-vs-spring-cloud-contract-tests-which-one-should-you-use/)
- [Consumer Driven Contract Testing Spring Cloud Contract Vs PactFlow | InnovationForge](https://innovationforge.in/2024/07/04/Consumer-Driven-Contract-Testing-Spring-Cloud-Contract-vs-PactFlow.html)
- [A Comprehensive Guide to Contract Testing APIs — Liran Tal](https://lirantal.com/blog/a-comprehensive-guide-to-contract-testing-apis-in-a-service-oriented-architecture-5695ccf9ac5a)
- [Common pitfalls and anti-patterns in contract testing | LinkedIn](https://www.linkedin.com/advice/0/what-some-common-pitfalls-anti-patterns-avoid-contract)
- [Resilient Builds With Can-I-Deploy — PactFlow](https://pactflow.io/blog/resilient-builds-with-can-i-deploy-2/)
- [Kafka Testing with Karate](https://www.karatelabs.io/Kafka)
- [How Microcks Can Speed-Up Your AsyncAPI Adoption | AsyncAPI](https://www.asyncapi.com/blog/microcks-asyncapi-part2)
- [Pact Open Source Update — August 2024](https://docs.pact.io/blog/2024/08/29/pact-open-source-update-aug-2024)

### Test Quality Metrics
- [Mutation Testing: The Ultimate Guide to Test Quality Assessment in 2025 | MasterSoftwareTesting](https://mastersoftwaretesting.com/testing-fundamentals/types-of-testing/mutation-testing)
- [Code Coverage vs Mutation Testing | Optivem Journal](https://journal.optivem.com/p/code-coverage-vs-mutation-testing)
- [The Pitfalls of Test Coverage: Introducing Mutation Testing with Stryker and Cosmic Ray](https://dev.to/wintrover/the-pitfalls-of-test-coverage-introducing-mutation-testing-with-stryker-and-cosmic-ray-1kcg)
- [Comparing Code Coverage Techniques: Line, Property-Based, and Mutation Testing | Sven Ruppert](https://svenruppert.com/2024/05/31/comparing-code-coverage-techniques-line-property-based-and-mutation-testing/)
- [Mutation Coverage is not Strongly Correlated with Line Coverage (AST 2024)](https://dl.acm.org/doi/10.1145/3644032.3644442)
- [Stryker Mutator (homepage)](https://stryker-mutator.io/)
- [Configuration | Stryker Mutator](https://stryker-mutator.io/docs/stryker-net/configuration/)
- [Announcing StrykerJS incremental mode](https://stryker-mutator.io/blog/announcing-incremental-mode/)
- [PIT Mutation Testing](https://pitest.org/)
- [PIT Mutation Testing on CI/CD Pipeline | Trendyol Tech](https://medium.com/trendyol-tech/pit-mutation-testing-on-ci-cd-pipeline-1298f355bae5)
- [Equivalent Mutants in the Wild (ISSTA 2024)](https://dl.acm.org/doi/10.1145/3650212.3680310)
- [Equivalent mutants | Stryker Mutator Docs](https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/)
- [Static and Dynamic Comparison of Mutation Testing Tools for Python (SBQS 2024)](https://sol.sbc.org.br/index.php/sbqs/article/view/32948)
- [CRAP Metric Is a Thing And It Tells You About Risk in Your Code | NDepend](https://blog.ndepend.com/crap-metric-thing-tells-risk-code/)
- [Understanding CRAP and Cyclomatic Complexity Metrics | OtterWise](https://getotterwise.com/blog/understanding-crap-and-cyclomatic-complexity-metrics)
- [Cyclomatic complexity — Wikipedia](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
- [The Relation of Test-Related Factors to Software Quality (Apache Systems) | Empirical Software Engineering](https://link.springer.com/article/10.1007/s10664-020-09891-y)
- [Assessing the Relationship between Software Assertions and Post-Release Defects | Microsoft Research](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-2006-54.pdf)
- [MC/DC Coverage | Rapita Systems](https://www.rapitasystems.com/mcdc-coverage)
- [Modified condition/decision coverage — Wikipedia](https://en.wikipedia.org/wiki/Modified_condition/decision_coverage)
- [Modified Condition/Decision Coverage (MC/DC) | LDRA](https://ldra.com/capabilities/mc-dc/)
- [The Best Code Coverage Tools By Programming Language | Codecov](https://about.codecov.io/blog/the-best-code-coverage-tools-by-programming-language/)
- [Line or Branch Coverage: Which Type is Right for You? | Codecov](https://about.codecov.io/blog/line-or-branch-coverage-which-type-is-right-for-you/)
- [Is 70%, 80%, 90%, or 100% Code Coverage Good Enough? | Qt Blog](https://www.qt.io/quality-assurance/blog/is-70-80-90-or-100-code-coverage-good-enough)
- [Do you aim for 80% code coverage? | DEV Community](https://dev.to/d_ir/do-you-aim-for-80-code-coverage-let-me-guess-which-80-it-is-1fj9)
- [Minimum Acceptable Code Coverage | Bullseye](https://www.bullseye.com/minimum.html)
- [Comparison with other coverage tools — tarpaulin Wiki](https://github.com/xd009642/tarpaulin/wiki/Comparison-with-other-coverage-tools)
- [10 Code Quality Metrics for Large Engineering Orgs | Qodo](https://www.qodo.ai/blog/code-quality-metrics-2026/)
- [How to Test AI-Generated Code the Right Way in 2026 | TwoCents](https://www.twocents.software/blog/how-to-test-ai-generated-code-the-right-way/)
