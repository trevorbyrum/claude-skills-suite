# Test Strategy Shapes

Reference for AI reviewer. Load this when assessing whether a project's test distribution matches its architecture.

## Decision Tree

```
What architecture?
├── Monolith / Library / Algorithm-heavy
│   → Pyramid (unit-heavy) ✓
│   Unit: 70%  Integration: 20%  E2E: 10%
│
├── SPA / Frontend (React, Vue, etc.)
│   → Trophy (integration-heavy) ✓
│   Static: lint/types  Unit: 20%  Integration: 50%  E2E: 20%
│   2024 update: E2E deserves larger slice in SSR apps (Next.js, Remix)
│   because Playwright has made E2E nearly as cheap as integration
│
├── Microservices
│   → Honeycomb (integration + contract heavy) ✓
│   Unit: 20%  Integration: 50%  Contract: 20%  E2E: 10%
│   Key: "integration test" = service + real local deps
│   "integrated test" = cross-service (avoid — use contracts instead)
│
└── API / Backend Service
    → Trophy variant ✓
    Unit: 30%  Integration: 50%  E2E: 20%
```

## The Shapes Explained

**Pyramid (Cohn, 2009)**: Many unit, fewer integration, fewest E2E. Still valid for TDD/algorithmic code. Breaks in microservices because mocking service boundaries gives false confidence.

**Trophy (Dodds, 2019)**: Static analysis + integration-heavy. "Write tests. Not too many. Mostly integration." Correct for frontend apps where unit testing components in isolation misses real bugs.

**Honeycomb (Spotify, 2018)**: Integration-heavy with contract tests replacing cross-service E2E. The microservices standard. Key distinction: test your service with real local dependencies, use contracts for everything external.

**Hourglass (Google-documented antipattern)**: Unit + E2E heavy with no middle layer. Most common dysfunction. Fix: build in-memory fakes that enable integration tests.

## When Heavy Unit Testing is Wrong

- Mocks outnumber assertions
- Tests break on non-behavioral refactors (testing implementation, not behavior)
- The code's real risk is at service boundaries, not in isolated units

## When Heavy E2E Testing is Wrong

- CI takes >30 minutes
- >20% of E2E tests are known-flaky
- E2E duplicates integration test coverage
- E2E tests fail for environmental reasons more than code reasons

## Reviewer Actions

1. Count test files by type (unit vs integration vs e2e vs contract)
2. Detect architecture type from project structure (`src/services/` = microservices, `src/components/` = SPA, etc.)
3. Compare ratio to expected shape
4. Flag mismatches as MEDIUM finding with specific recommendation
5. Flag hourglass pattern (lots of unit + lots of E2E, no integration) as HIGH finding
