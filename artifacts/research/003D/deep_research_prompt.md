# Deep Research Prompt — 003D

## Research Question
What are the best practices, techniques, and tools for comprehensive automated test review in 2025-2026, and how should an AI-powered test review skill evaluate test suite quality across all dimensions — including areas our current skill covers and areas it misses entirely?

## Sub-Questions
1. **Mutation testing**: How do modern mutation testing tools (Stryker, mutmut, go-mutesting, cargo-mutants) work, what metrics matter (mutation score, equivalent mutants), and how should an AI reviewer interpret mutation results?
2. **Property-based testing**: How should a reviewer identify where property-based tests (Hypothesis, fast-check, QuickCheck, jqwik) add value over example-based tests? What are the signs that a test suite lacks property-based coverage?
3. **Contract testing**: When and how should contract tests (Pact, Spring Cloud Contract) be required? How does a reviewer detect missing contract coverage in microservice/API architectures?
4. **Test quality metrics**: Beyond line/branch coverage — what metrics actually predict test suite effectiveness? (Mutation score, assertion density, test-to-code ratio, cyclomatic complexity coverage, MC/DC, condition coverage, CRAP score)
5. **Coverage gap detection**: What are the most effective automated techniques for finding untested code paths, including symbolic execution, concolic testing, and coverage-guided fuzzing?
6. **LLM-generated test anti-patterns**: What specific failure modes do LLM-generated tests exhibit? (Beyond our current stub/mock detection — are there patterns we're missing?)
7. **Test generation strategies**: How should AI assistants generate or recommend tests? What works (test amplification, search-based testing) vs. what doesn't?
8. **Integration & E2E test evaluation**: How should a reviewer assess the balance between unit, integration, and E2E tests? What's the modern take on the test pyramid vs. trophy vs. honeycomb?
9. **Test infrastructure quality**: What makes test infrastructure reliable vs. flaky? (Deterministic fixtures, test isolation, parallel safety, container-based test envs, testcontainers)
10. **Validation of our current skill**: Does our existing test-review skill (stub detection, mock overuse, fragile tests, feature-to-test mapping, error path coverage) align with industry best practices, or are any of our current checks misguided/incomplete?

## Scope
- Breadth: exhaustive
- Time horizon: include historical foundations but prioritize 2024-2026 practices
- Domain constraints: polyglot (JS/TS, Python, Go, Rust, Java) — not framework-specific but framework-aware
- Validate existing approaches AND discover missing ones

## Project Context
This is an AI-powered skill suite for Claude Code. The test-review skill is one of 7 review lenses run during meta-review (multi-model fan-out: Sonnet + Codex + Gemini). The skill evaluates test suites of projects being reviewed — it does NOT run tests itself, it reads test code and assesses quality. Current skill covers: test landscape mapping, feature-to-test mapping, stub detection, mock overuse, fragile tests, missing error paths, coverage gaps, test infrastructure quality. Current skill is 170 lines. Upgrade should follow progressive disclosure (SKILL.md stays scannable, detail in references/).

## Known Prior Research
- 001D: skill-sprint-optimization (skill architecture, not testing)
- 002D: meta-execute quality (worker patterns, not testing)
- Neither is directly relevant. This is greenfield research for testing domain.

## Output Configuration
- Research folder: artifacts/research/003D/
- Summary destination: artifacts/research/summary/003D-test-review-upgrade.md
- Topic slug: test-review-upgrade

## Special Instructions
- The current SKILL.md is included below for validation. Research should explicitly call out which current sections are solid, which need expansion, and which are missing entirely.
- Prioritize actionable recommendations that can be turned into skill instructions (not academic theory).
- For each technique (mutation testing, PBT, contract testing, etc.), specify: when to recommend it, how to detect its absence, and what the reviewer should say.
- Include real tool names and framework-specific patterns where relevant.
- Challenge assumptions: is the test pyramid still correct? Is 80% coverage a useful target? Are mocks always bad?

## Current SKILL.md Content (for validation)

The test-review skill currently covers:
1. Map the Test Landscape (location, frameworks, types, CI)
2. Feature-to-Test Mapping (features.md → test files, zero coverage, happy-path-only, skipped tests)
3. Test Quality Audit (stub detection, mock overuse, fragile tests, missing error paths)
4. Coverage Gaps (zero-import files, complex functions, error handling, edge cases, config)
5. Test Infrastructure (one-command run, fixtures, test data, test utilities, suite speed)
6. Produce Findings (severity: CRITICAL/HIGH/MEDIUM/LOW, categories)
7. Summarize (coverage map table, finding counts, overall assessment)
