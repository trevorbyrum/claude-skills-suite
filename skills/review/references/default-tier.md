# Default Tier — 12 Lenses Always Run in Full Review

Every full-review pass runs all 12 of these via parallel Sonnet subagents. Single-lens mode invokes one of these by name.

For shared patterns (finding format, severity, fresh check, output to DB), see `review-lens-framework.md`.

---

## 1. counter-review

**Purpose**: Critique the plan and context, not the code. Identify assumptions, scope creep, hidden dependencies, alternatives not considered.

**Inputs**: `project-plan.md`, `project-context.md`, prior `review-synthesis-*.md`.

**Key checks** — 7-angle adversarial attack structure:

1. **Architecture Attack**: Challenge the overall architecture. Is the chosen stack justified, or cargo-culted from a template? Are there unnecessary abstraction layers (over-engineering) or missing layers (god-file under-engineering)? Does the dependency graph make sense (circular imports / god modules)? Would this architecture survive 10x scale — and does it need to?

2. **Completeness Attack**: Scan for unfinished work. Stubs, TODOs, placeholder values, empty catch blocks. Functions in the interface with no real implementation. Features in `features.md` with no corresponding code. Code paths that silently swallow errors.

3. **Drift Attack**: Compare what docs say vs. what code does. Features marked "done" in `features.md` that are actually incomplete. Architectural decisions in `project-context.md` that the code contradicts. Plan phases in `project-plan.md` that were skipped or half-implemented.

4. **Over-Engineering Attack**: Find complexity that doesn't earn its keep. Abstractions with only one implementation. Config systems more complex than the thing they configure. Premature optimization (caching, pooling, lazy loading) with no profiling evidence. Generic frameworks built for a specific use case.

5. **Adversarial Abuse Cases**: Think like a malicious user. Business logic manipulation (prices, quantities, roles). Input boundary abuse (oversized payloads, unicode tricks, encoding attacks). State manipulation (race conditions, replay attacks, TOCTOU gaps). Workflow abuse (required steps skipped by hitting the API directly). For AI agent projects: prompt injection, tool abuse, context poisoning. Focus on business logic flaws and workflow bypasses that security-review would NOT catch.

6. **Attack Chain Construction**: Chain individual findings (from this review AND other lenses) into multi-step exploit paths. Map trust boundaries. Identify escalation paths (unauthenticated → authenticated → admin → system). Trace data exfiltration routes. Build chains — combine 2-3 low/medium findings into a high/critical path. A chain of three LOW findings that leads to a CRITICAL outcome is itself a CRITICAL finding.

7. **"What If" Scenarios**: Stress test the project's assumptions. Infrastructure: DB goes down, traffic spikes 100x. Security breach: API key leaks, dependency compromised. Scale: data grows 10x, 1000 concurrent users on the same endpoint. Operational: deploy fails midway, need to restore from backup. Assess each relevant scenario as HANDLED / PARTIALLY HANDLED / UNHANDLED. Focus on scenarios realistic for this project's scale — don't flag "1M users" for an internal 5-user tool.

**Finding location format**: `project-plan.md:WU-N-M` or `project-context.md:§Section`.

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/counter/abuse-cases.md` — abuse scenarios the plan should have considered
- `lenses/counter/attack-chains.md` — multi-step attack patterns
- `lenses/counter/what-if-scenarios.md` — devil's-advocate prompts

---

## 2. security-review

**Purpose**: Security defects in code, secrets handling, auth/session, input validation, dependency-related CVEs.

**Inputs**: full codebase, dependency manifests, env-handling code.

**Key checks**:
- Hardcoded secrets, tokens, keys (cross-reference with gitleaks output from the Phase 1.5 SAST pre-scan)
- Auth boundary violations, missing authz on endpoints
- Injection vectors: SQL, command, prompt
- Insecure crypto, weak random, missing TLS
- Missing input validation at trust boundaries (user input, network input, file input)

**Add field**: CWE id when applicable.

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/security/priority-checklists.md` — P0/P1/P2 checklist with CWE IDs, supply-chain checklist, IaC security checklist
- `lenses/security/owasp-agentic.md` — OWASP ASI01-ASI10 (Goal Hijacking, Identity Abuse, Excessive Agency, etc.) + least-agency principle + prompt-injection defenses
- `lenses/security/agent-patterns.md` — AP-1..AP-7 agent anti-patterns, "universally omitted concerns," iterative-degradation warning (security degrades 37.6% after 5 rounds of AI refinement)

---

## 3. test-review

**Purpose**: Test coverage quality. Not just "is there a test" but "does the test exercise the boundary that breaks in production."

**Inputs**: test files + the code they cover.

**Key checks**:
- Missing tests for new exports (each WU should add at least one)
- Brittle tests (snapshots without rationale, time-sensitive without freeze)
- Test fixtures that hide independence problems (shared state across tests)
- Tests asserting "doesn't throw" without asserting behavior
- E2E vs unit balance — too many e2e is slow, too few unit doesn't catch logic bugs

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/test/mutation-testing-guide.md` — Stryker/PIT/mutmut/cargo-mutants thresholds (90% / 75% / 50% bands), equivalent-mutant handling
- `lenses/test/pbt-patterns.md` — 7 property-based-testing patterns + Trail of Bits trigger list
- `lenses/test/contract-testing-guide.md` — Pact / Specmatic / Microcks, consumer-driven vs provider-driven
- `lenses/test/test-strategy-shapes.md` — pyramid / trophy / honeycomb / hourglass decision tree by architecture
- `lenses/test/llm-test-antipatterns.md` — Magic Number Test prevalence, coverage theater, hallucinated APIs
- `lenses/test/metrics-reference.md` — Mutation > Branch > CRAP > Assertion Density > Line hierarchy

**Generation Phase** (opt-in — fires only when the review finds CRITICAL/HIGH coverage gaps AND the user explicitly accepts):

After the review writes findings, offer to generate the missing tests.
Trigger condition: at least one CRITICAL or HIGH finding tagged as a coverage gap, stub test, or missing error path.

> "Found N coverage gaps. Want me to generate tests for them now? (yes / pick a subset / no)"

If the user accepts:

### G1. Plan Generation

For each gap selected by the user, read the source file and identify:

- The behaviors to test (public API, not implementation details)
- Edge cases: empty input, null, boundary values, error conditions
- Fixture needs
- Whether a related test exists that should be extended rather than duplicated

Present a table:

| Target     | Source               | Test File                               | Approach            | Tests to Generate |
|------------|----------------------|-----------------------------------------|---------------------|-------------------|
| Auth login | `src/auth/login.ts`  | `src/auth/__tests__/login.test.ts`      | Unit, mock provider | 8                 |

Wait for user approval on the plan.

### G2. Generate

For each approved target, spawn a Sonnet subagent (`subagent_type: "general-purpose"`)
with the prompt template from `../agents/test-worker.md`. Fill in all placeholders
before spawning: `[SOURCE_CODE]`, `[SOURCE_PATH]`, `[EXISTING_TESTS]`,
`[FRAMEWORK]`, `[FINDING]`, `[EDGE_CASES]`, `[TEST_PATH]`.

**Quality guardrails** (enforced by the worker prompt):

- Assert behavior, not implementation
- Meaningful assertions (no `toBeDefined` / `toBeTruthy` on objects)
- At least one error/edge case per function
- Match project conventions exactly
- No anti-patterns from `lenses/test/llm-test-antipatterns.md`

The main thread writes generated code to disk after each subagent returns
(subagents don't write files in this flow — the main thread controls placement).

### G3. Run

After writing each test file, run the project's test command scoped to
the new file. If the test fails, fix once and retry. After 2 failed
retries, flag for manual review — do not keep iterating.

### G4. Persist + Report

Store the generation result in the artifact DB:

```bash
source references/db.sh
db_upsert 'test-review' 'generation' "$TARGET_PATH" "files: <list>, tests: <count>, passing: <count>, failing: <count>"
```

Report:
- Files generated (with paths and line counts)
- Tests per file: total, passing, failing
- Coverage delta (if a coverage tool is available)
- Findings addressed vs. skipped (with reason)
- Suggestion: "Re-run `/review` (test-review lens) to confirm the new tests pass scrutiny."

---

## 4. refactor-review

**Purpose**: Code structure, duplication, abstraction quality. Catches premature abstractions AND copy-paste drift.

**Key checks**:
- Duplicated logic (the "three similar functions" smell)
- Premature abstraction (a class hierarchy serving one concrete use)
- God-functions / god-classes (>100 lines, >5 responsibilities)
- Names that don't match behavior (`get_user` that also writes to a cache)
- Magic numbers, magic strings without const definitions

---

## 5. drift-review

**Purpose**: Implementation vs. plan/context drift. Catches "we said X but the code does Y."

**Inputs**: `project-plan.md`, `project-context.md`, code.

**Key checks**:
- Features in `features.md` with no corresponding code
- Code implementing features not in `features.md` (silent scope expansion)
- Tech stack in `project-context.md` not actually used (or unauthorized addition)
- Architecture decision in `project-context.md` violated by code

---

## 6. completeness-review

**Purpose**: Whether stated functionality is fully wired vs. partially implemented.

**Key checks**:
- Exports declared but never imported anywhere
- Env vars referenced but never set / documented
- Resources opened without cleanup (DB connections, file handles, listeners)
- TODO/FIXME comments in committed code
- Stub functions that throw "not implemented"
- Half-finished refactors (old code path AND new code path coexisting)

---

## 7. compliance-review

**Purpose**: Compliance with project conventions, CLAUDE.md, AGENTS.md, regulatory if mentioned in context.

**Key checks**:
- AGENTS.md rules being violated (commit conventions, no hardcoded secrets, etc.)
- CLAUDE.md rules being violated
- Regulatory hits if `project-context.md` mentions HIPAA / GDPR / SOC2 / PCI
- License compatibility (dependency licenses vs. project license)

---

## 8. integration-review

**Purpose**: How well modules connect. Wiring errors that pass unit tests but fail in the assembled system.

**Key checks**:
- Type contracts between modules (input expected by callee vs. shape produced by caller)
- Event/message-passing — published event has consumers
- Async boundaries — promises not awaited, race conditions in initialization
- Config keys / env vars introduced by one module, consumed by another (or not consumed)

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/integration/wiring-patterns.md` — common wiring failure modes
- `lenses/integration/config-completeness.md` — env var / config key audit patterns
- `lenses/integration/teardown-patterns.md` — resource lifecycle, cleanup, shutdown ordering

---

## 9. perf-review

**Purpose**: Performance issues visible from code (not benchmarking — that needs runtime).

**Key checks**:
- O(n²) on hot paths (nested loops over the same collection)
- DB query in a loop (N+1)
- Synchronous I/O on the request path
- Unbounded growth (caches without eviction, lists that only append)
- Allocations in tight loops

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/perf/perf-patterns.md` — patterns catalog (allocation hotspots, lock contention, cache locality, batching)
- `lenses/perf/frontend-perf.md` — Core Web Vitals, hydration, bundle size, runtime profiling for frontends

---

## 10. dep-audit

**Purpose**: Dependency hygiene. CVEs, unmaintained packages, version pinning.

**Inputs**: lock file (`package-lock.json`, `Cargo.lock`, `requirements.txt`, etc.), `package.json` / `Cargo.toml` / `pyproject.toml`.

**Key checks**:
- Known CVEs in pinned versions (cross-reference with public advisories via WebSearch)
- Unmaintained packages (last commit >2 years, archived repos)
- Loose pinning (`^1.0.0` for non-prod) that risks supply-chain churn
- Direct deps that exist only because of transitive needs

**Add field**: Package + affected version range.

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/dep-audit/audit-checks.md` — full audit checklist
- `lenses/dep-audit/license-matrix.md` — license compatibility matrix for downstream license selection

---

## 11. log-review

**Purpose**: Logging quality. Missing logs at boundaries, log spam, log secrets.

**Key checks**:
- Log statements with secrets (token, password, key) in any form
- Missing logs at error boundaries (caught exception with no log)
- Log spam (info-level inside tight loops)
- Log severity mismatch (error logs for routine paths, info logs for failures)
- Inconsistent format / missing correlation ids

**Generation Phase** (opt-in — fires only when the review finds CRITICAL/HIGH observability gaps AND the user explicitly accepts):

After the review writes findings, offer to generate the logging instrumentation to fix them.
Trigger condition: at least one CRITICAL or HIGH finding (silent failures, missing error context, uninstrumented API boundaries, missing correlation IDs).

> "Found N observability gaps. Want me to add the logging now? (yes / pick a subset / no)"

If the user accepts:

### G1. Detect or Create Logger

Check if the project already has a logger configured:

- **Node.js/TS**: `winston`, `pino`, `bunyan`, `morgan` in `package.json`
- **Python**: `logging`, `structlog`, `loguru` imports
- **Go**: `log/slog`, `zap`, `logrus`, `zerolog` imports
- **Java**: `slf4j`, `log4j`, `logback` in dependencies
- **Rust**: `tracing`, `log`, `env_logger` in `Cargo.toml`

If none exists, create a minimal structured logger setup using the idiomatic library for the language. Prefer the project's existing patterns — don't introduce a new library if one is already in use.

### G2. Group Findings + Approve

Group selected findings by category and present them:

1. **Silent failures** (CRITICAL) — fix first, these hide production errors
2. **Error context** (HIGH) — add context to existing error handlers
3. **API boundaries** (HIGH) — add request/response logging at system edges
4. **Correlation IDs** (MEDIUM) — add request ID generation and propagation
5. **Log hygiene** (LOW) — fix format inconsistencies, remove PII

Ask the user which categories to implement.

### G3. Implement

For each approved finding, implement the logging fix.

**Silent failures** — replace empty catches:

```typescript
// Before
catch (e) {}

// After
catch (e) {
  logger.error({ err: e, operation: 'fetchUser', userId }, 'Operation failed');
  throw e;
}
```

**Error context** — structured context:

```python
# Before
except Exception as e:
    logger.error(f"Failed: {e}")

# After
except Exception as e:
    logger.error("operation_failed", operation="fetch_user", user_id=user_id, exc_info=True)
```

**API boundaries** — add middleware or interceptors for request/response logging.

**Correlation IDs** — request ID middleware that generates and propagates IDs.

Rules:

- Match the project's existing code style exactly.
- Use the project's existing logger — never import a competing one.
- Log at appropriate levels: ERROR for failures, INFO for business events, DEBUG for internals.
- Structured context (key-value pairs), not string interpolation.
- Never log sensitive data (passwords, tokens, PII) — redact or omit.

### G4. Verify + Persist

After implementation:

- Confirm the project still compiles and passes lint.
- Scan diff with `gitleaks` to ensure no PII or secrets are being logged.
- Verify log levels are appropriate (no INFO logging in hot paths).
- Run the test suite to ensure new logging didn't break mocked tests.

Store the generation result:

```bash
source references/db.sh
db_upsert 'log-review' 'generation' "$TARGET_PATH" "files: <list>, fixes: <count>, verified: <pass|fail>"
```

Report which findings were addressed vs. skipped, and which (if any) required manual intervention.

---

## 12. doc-audit

**Purpose**: Documentation completeness and accuracy. Catches docs that drifted from code.

**Inputs**: README, docs/, inline comments, JSDoc/docstrings.

**Key checks**:
- Exported functions / classes without docstrings (severity scales with API surface)
- Docstrings describing behavior the code doesn't have
- README setup instructions that don't actually work (impossible to verify without running, but flag obvious gaps)
- `CHANGELOG.md` missing entries for recent commits
- Inline comments that lie (out of date with the code)

---

## Lenses NOT in this tier

- `ui-review`, `browser-review`, `breaking-change-review` → see `optional-tier.md`. Opt-in only.
- Legacy `meta-production` rubric → dropped from the new suite.
