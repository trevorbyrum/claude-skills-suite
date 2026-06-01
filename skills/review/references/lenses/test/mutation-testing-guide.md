# Mutation Testing Guide

> On-demand reference for test-review skill. Load this when evaluating mutation testing coverage or recommending tooling.

## What It Is

- Inject single-operator mutations into source → run tests → classify: killed / survived / equivalent / timeout
- Measures whether tests actually validate behavior — not just execute code
- A test suite with 100% line coverage can still score 4% on mutation testing (AI-generated tests routinely do this)

## Tools by Language

| Language | Tool | Key Features |
|----------|------|--------------|
| JS/TS | Stryker | `--incremental` mode, git-diff aware; Sentry runs weekly (20-25 min/package) |
| Java | PIT | `withHistory` for incremental, `scmMutationCoverage` for PR-level, bytecode-fast |
| Python | mutmut | AST-based, ~1200 mutants/min, `--jobs` flag gives 4x speedup, defines Adequacy Ratio |
| Rust | cargo-mutants | Replaces entire function bodies, reflinks for fast copies, `--git-diff-lines` for sharding |
| Go | Gremlins (v0.6.0, Dec 2025) | Maintained successor to go-mutesting; scope to individual microservices |

## Score Thresholds

- **90%+** — auth, payments, safety-critical logic
- **75-90%** — core business logic
- **50-75%** — utilities, non-critical paths
- **<50%** — inadequate; tests don't validate behavior (flag immediately)

## Key Mutation Operators to Check For

- **VoidMethodCalls** — lowest kill rate (~69%); strongest signal for missing side-effect assertions (verify calls happened)
- **ConditionalsBoundary** — catches off-by-one errors (`<` vs `<=`)
- **NegateConditionals** — catches inverted logic bugs that coverage misses
- **ReturnValues** — catches missing return value assertions

If surviving mutants cluster around one operator, that operator type is systematically untested.

## Equivalent Mutants

- 4-39% of real-world mutants are semantically identical to the original (equivalent)
- Do NOT count equivalent mutants against the score
- LLM-based detection: F1=86.58% at 43ms/mutant pair (UniXCoder)
- Meta ACH (2025): precision=0.95, recall=0.96 with simple preprocessing
- Most tools exclude obvious equivalents automatically; flag if a project has manual exclusion lists

## CI Integration Patterns

- **Incremental/diff-based (PRs)**: only mutate changed lines
  - Stryker: `--incremental`
  - PIT: `scmMutationCoverage`
  - cargo-mutants: `--git-diff-lines`
- **Full run**: weekly or pre-release only (can take 20-60 min)
- **Gate**: fail CI if score drops below threshold per module
- **PR comment**: surviving mutants surfaced inline — highest-signal code review signal

## When NOT to Recommend

- Prototype / throwaway code
- UI rendering tests (visual assertions, snapshot tests)
- Coverage <50% — fix coverage first; mutation testing on low-coverage code just confirms it's bad
- Massive legacy codebase with no tests — start with basic coverage, not mutation
- Time-critical CI path without incremental mode configured

## AI-Generated Code: The Critical Insight

- AI-generated tests routinely achieve 100% line coverage while scoring **4%** on mutation testing
- Root cause: AI tests execute every line but assert nothing meaningful (variable assigned, no assertion on value)
- Feeding surviving mutants back to AI tools improved scores from 70% to 78% in controlled studies
- **Mutation testing is THE essential quality gate for AI-assisted development — treat it as mandatory, not optional**

## Reviewer Checklist

1. Is a mutation tool in `devDependencies` / test dependencies?
2. Is there a mutation config file? (`stryker.config.js`, PIT gradle plugin block, `mutmut` in `setup.cfg`, `.cargo-mutants.toml`)
3. If score data exists: parse and flag any module below 80%
4. If no mutation testing present: recommend it for auth, payments, and core business logic modules — call these out by name
5. Check for **VoidMethodCalls survivors** specifically — strongest signal for untested side effects
6. If tests are AI-generated (or likely AI-generated): mutation testing is mandatory, not optional — say so explicitly
7. Check if CI runs mutation tests incrementally on PRs — if not, recommend adding it even if full run exists
