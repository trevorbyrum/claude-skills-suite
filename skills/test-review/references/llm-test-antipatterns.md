# LLM-Generated Test Anti-Patterns

## The Core Problem: Test Oracle Failure

LLMs generate assertions by "mentally executing" the implementation, not by reasoning from specification. When code is mutated (made buggy), LLM classification accuracy drops up to 16 percentage points — confirming the oracle follows the implementation, not correctness.

Result: tests pass on buggy code because the assertion was derived from the buggy output in the first place.

---

## Smell Prevalence

From a 20,505-suite study across GPT-3.5, GPT-4, Mistral, and Mixtral:

| Smell | LLM Prevalence | Human Prevalence | Signal |
|-------|----------------|------------------|--------|
| Magic Number Test | 85–99% | Near zero | Strongest AI-vs-human signal |
| Unknown/Empty Test | 47–51% | Low | Missing names or bodies |
| Lazy Test | 32–39% | Moderate | Multiple unrelated assertions per test |
| Assertion Roulette | 31–55% | Moderate | Multiple assertions without messages |

The smell inversion — LLMs show near-universal Magic Number Test, humans show near-universal Assertion Roulette — is a reliable signal to distinguish AI-generated tests from human-written ones.

---

## Anti-Pattern Catalog

### 1. Coverage Theater

- 100% line coverage, 4% mutation score
- Every line executes but nothing meaningful is asserted
- Detection: compare line coverage % to mutation score. Gap >40pp = coverage theater
- Example: `test("runs without error", () => { doThing(); })` — no assertions

### 2. Magic Number Test

- Hardcoded expected values with no explanation of why that value is correct
- `expect(result).toBe(42)` with no context
- Detection: assertions with literal values not derived from named constants or documented specs
- Fix: extract constants, add comments linking the value to the spec

### 3. Hallucinated APIs

- Assertions on methods, properties, or return types that don't exist in the codebase
- Using deprecated or non-existent framework APIs
- Detection: grep asserted method names against source files; flag any not found
- Common in: Copilot-generated tests when context window doesn't include the implementation

### 4. Data Model Mismatch

- Test fixtures with wrong field names, types, or structure
- Mock data that doesn't match the actual schema
- Detection: compare fixture field names against actual type definitions (TypeScript interfaces, Zod schemas, Pydantic models)
- Symptom: tests pass in isolation but fail when run against real data

### 5. Mock-Mirrors-Implementation

- Mock setup replicates the exact logic of the function under test
- The test exercises the mock, not the real code
- Detection: high structural similarity between mock setup and the source function body
- Example: mock that re-implements the same conditional logic as the function it replaces

### 6. Happy-Path-Only

- All test inputs are "typical" valid values
- No null, undefined, empty string, zero, negative number, or boundary value inputs
- No error case tests despite the function having explicit error paths
- Detection: scan test inputs — if every value is a clean positive case, flag the suite

### 7. Test Oracle Problem (root cause of 1–6)

- Assertions derived by mentally running the implementation, not from specification
- When the implementation is wrong, the assertion asserts the wrong output as correct
- Detection: mutation testing catches this universally — if mutants survive, oracles are weak
- This cannot be detected by static analysis alone; mutation testing is required

### 8. Non-Deterministic / Flaky

- Shared mutable state between tests (static variables, module-level singletons)
- Using real time (`Date.now()`, `new Date()`) without clock injection
- Network calls without mocking; file system without tempdir isolation
- Detection: run the suite 3x; any test that fails non-deterministically is flaky
- See also: fragile test checks in the main SKILL.md

---

## Copilot-Specific Data

- 92.45% failure rate when generating tests with no existing test suite as context
- 54.72% failure rate when generating tests WITH existing test context
- Practical implication: always provide a representative existing test file as context when prompting for AI-generated tests

---

## CANDOR Approach (97.1% Oracle Correctness)

State-of-the-art technique for LLM-generated tests:

1. Generate multiple independent test suites for the same function (different prompts, different models)
2. Run all suites against mutation testing
3. Keep only assertions that appear (or agree) across multiple generations
4. Discard assertions unique to a single generation (likely oracle-following artifacts)

Achieves 0.980 mutation score. Not required for reviewer to implement, but informs severity scoring: a suite with no cross-validation should be flagged as HIGH risk for oracle failure.

---

## Reviewer Checklist

Use this when the test suite may be partially or fully AI-generated, or when mutation scores are not yet available:

1. **Magic Number Test** — are expected values hardcoded literals? Do they have any explanation?
2. **Coverage vs. mutation gap** — if mutation score is available, flag gap >40pp as coverage theater
3. **API existence** — do all asserted methods and properties actually exist in the source?
4. **Fixture accuracy** — do fixture field names match actual type definitions?
5. **Mock fidelity** — do mock setups structurally mirror the implementation they replace?
6. **Error path coverage** — are null, empty, boundary, and error inputs tested?
7. **Mutation testing mandate** — if tests are AI-generated, mutation testing is mandatory, not optional. Flag its absence as a gap regardless of line coverage percentage.
