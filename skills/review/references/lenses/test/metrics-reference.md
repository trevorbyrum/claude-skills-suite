# Test Quality Metrics Reference

## Metrics Hierarchy (most to least predictive)

```
Mutation Score > Branch Coverage > CRAP Score > Assertion Density > Line Coverage
```

---

## 1. Mutation Score

- Ground truth for test effectiveness
- Measures: % of injected faults caught by tests
- Thresholds:
  - <50% = CRITICAL
  - 50-60% = block
  - 60-80% = warning
  - >80% = good
  - >90% = excellent
- Tools: Stryker (JS/TS), PIT (Java), mutmut (Python), cargo-mutants (Rust), Gremlins (Go)
- Only weakly correlated with line coverage — high coverage does not guarantee high mutation score

---

## 2. Branch Coverage

- Strictly stronger than line coverage
- Measures: % of conditional branches executed
- Tool flags:
  - `coverage.py` requires `--branch` flag (NOT default) — absence is a reviewer signal
  - `go cover` requires `-covermode=atomic` for branch data
  - Istanbul/nyc reports branch coverage alongside line by default
  - JaCoCo reports branch coverage in HTML/XML output

---

## 3. CRAP Score (Change Risk Anti-Patterns)

- Best single metric for prioritizing review effort
- Formula: `CC² × (1 - coverage)³ + CC`
  - CC = cyclomatic complexity of the function
  - coverage = test coverage of that function (0-1)
- Thresholds:
  - <30: acceptable
  - 30-60: needs attention (tests or simplification)
  - >60: high risk — refactor before adding tests
  - If CC >30: no amount of testing helps — refactor first
- Tools: SonarQube (calculates automatically), phpunit (PHP), custom scripts using radon + coverage

---

## 4. Assertion Density

- Assertions per test method
- Microsoft Research + 54-company study: strongest correlate with reduced post-release defects
- Thresholds:
  - 0 assertions = P0 finding (test does nothing)
  - 1 assertion = acceptable for focused unit tests
  - 3-5 assertions = typical for integration tests
  - >10 assertions per test = may indicate test doing too much (Lazy Test smell)
- Detection: count `assert`, `expect`, `should` statements per test function

---

## 5. Line Coverage

- Weakest metric — measures execution, not correctness
- 80% target has no rigorous research basis
- Useful as a CI floor (60% min per Google), not a quality signal
- High line coverage with low assertion density = pathological (coverage theater)
- Tool-specific:
  - Istanbul/nyc (JS/TS): default in Jest
  - coverage.py (Python): use `--branch` for meaningful data
  - go cover (Go): use `-covermode=atomic`
  - tarpaulin (Rust): nightly Rust required for some features
  - JaCoCo (Java): Gradle/Maven plugin

---

## 6. Cyclomatic Complexity (CC)

- McCabe metric: number of linearly independent paths through a function
- CC >10 = high complexity (ISO 29119, industry standard)
- Any function CC >10 with no test = concrete finding
- Tools: radon (Python), complexity-report/escomplex (JS), gocyclo (Go), cognitive-complexity (SonarQube)

---

## 7. Test-to-Code Ratio

- Least actionable as a standalone metric
- Typical healthy ranges: 1:1 to 2:1 (test LOC : source LOC)
- <0.5:1 = likely undertested
- >3:1 = possibly overtested or test code needs refactoring
- Use only as a sanity check, never as a target

---

## MC/DC (Modified Condition/Decision Coverage)

- Only relevant for: aviation (DO-178C Level A), automotive (ISO 26262), medical (IEC 62304)
- Not an actionable general-purpose metric
- If the project is in one of these domains, MC/DC is mandatory

---

## Coverage Visualization Tools

| Tool | Languages | Integration |
|------|-----------|-------------|
| Codecov | All (via lcov/cobertura) | GitHub/GitLab PR comments, coverage diff |
| lcov + genhtml | C/C++, any lcov-compatible | CI artifacts, HTML reports |
| grcov (Mozilla) | Rust, LLVM-instrumented C | lcov/HTML/cobertura output |
| SonarCloud/Codacy | All | PR gates, blended quality metrics |
| JaCoCo | Java | Gradle/Maven, HTML/XML |
| Istanbul/nyc | JS/TS | Jest/Mocha built-in |

---

## Reviewer Actions

1. Check which metrics are collected (coverage config, CI artifacts)
2. If only line coverage: recommend branch coverage and mutation testing
3. If coverage.py without `--branch`: flag as incomplete coverage data
4. Calculate CRAP score for high-complexity functions (CC >10)
5. Check assertion density: flag test methods with 0 assertions as P0
6. If mutation score exists: compare to line coverage — gap >40pp = coverage theater
7. Don't fixate on coverage %. Focus on mutation score and CRAP hotspots.
