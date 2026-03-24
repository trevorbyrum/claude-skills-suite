# Scope Triage Framework

Reference for the scope-triage skill. Contains the exact RICE formula, per-dimension
scoring rubrics, MoSCoW definitions adapted for code modules, output table schema,
and edge-case handling.

---

## Modified RICE Formula

```
RICE = (Usage × 0.30) + (Blast × 0.30) + (Coverage × 0.20) + (LOC × 0.20)
```

Range: 0.0 – 10.0. **Low score = safe removal candidate. High score = keep.**

The weights reflect the two dominant removal risks: disrupting active users
(Usage) and cascading breakage (Blast) outweigh test safety (Coverage) and
effort (LOC).

---

## Dimension Scoring Rubrics (0–10 each)

### Usage — Import count, call sites, test references

How much of the codebase actively calls this module?

| Score | Signal |
|---|---|
| 0–1 | Zero call sites. Dead code or conditionally imported but never reached. |
| 2–3 | 1–2 call sites, all within the same feature module. Low spread. |
| 4–5 | 3–10 call sites across 2–3 distinct modules. Moderate coupling. |
| 6–7 | 11–30 call sites or referenced across 4+ modules. Widely used. |
| 8–9 | 31–100 call sites or core utility imported in most files. |
| 10 | >100 call sites or re-exported by a public package index. Platform-level usage. |

Count: import statements + direct call sites + test `describe`/`it` blocks that
directly instantiate or import the module. Use static grep; do not count
transitive imports here (those belong to Blast).

---

### Blast — Transitive dependent count (from impact-analysis)

How many modules/files break if this one is removed?

| Score | Signal |
|---|---|
| 0–1 | 0–1 transitive dependents. Isolated leaf node. |
| 2–3 | 2–5 dependents. Small, bounded blast. |
| 4–5 | 6–15 dependents. Medium blast — test coverage matters. |
| 6–7 | 16–40 dependents. Large blast — removal requires careful migration. |
| 8–9 | 41–100 dependents. Very large blast — essentially a platform module. |
| 10 | >100 dependents or the module is in a shared library consumed by other projects. |

Use the `transitive_count` field from impact-analysis output. If absent, derive
via: `grep -r "import.*module-name" --include="*.ts" -l | wc -l`.

---

### Coverage — Existing test coverage of this module

How safe is removal from a regression standpoint?

High coverage means the module is well-tested, so regressions from removal
would surface quickly. This makes removal *safer*, hence higher score = easier cut.

| Score | Signal |
|---|---|
| 0–1 | No test files reference this module. No safety net. |
| 2–3 | Integration tests touch it incidentally but no unit tests. |
| 4–5 | Unit tests exist but cover <40% of branches. |
| 6–7 | Unit tests cover 40–70% of branches. Decent safety net. |
| 8–9 | Unit tests cover >70% of branches. High confidence in test signal. |
| 10 | >90% branch coverage + contract/property-based tests. Gold standard. |

If a coverage report is available (Istanbul, pytest-cov, etc.), use the branch
coverage percentage. If not available, estimate from: (number of test assertions
targeting this module) / (number of exported functions × 3).

---

### LOC — Lines of code to remove or rewrite

How much work does removal require?

High LOC = expensive removal. Low LOC = cheap cut. Score inversely with LOC.

| Score | LOC Range | Notes |
|---|---|---|
| 10 | < 50 LOC | Trivial removal — a few files. |
| 8–9 | 50–150 LOC | Small module. Afternoon's work. |
| 6–7 | 151–400 LOC | Medium module. One sprint item. |
| 4–5 | 401–800 LOC | Substantial. Needs planning. |
| 2–3 | 801–1500 LOC | Large. Multi-sprint effort. |
| 0–1 | > 1500 LOC | Major subsystem. Removal is a project, not a task. |

Count only the LOC within the candidate module itself, not its dependents.
Use `wc -l` on source files, excluding blank lines and comments if feasible.

---

## MoSCoW Definitions (Code Module Adaptation)

Standard MoSCoW is a product prioritization tool. Here it is redefined for code
modules evaluated against a **new project direction** established in Phase 2.

### Must Keep

The module is on the critical path of the new direction. Removing it would
block the pivot or require an immediate, equivalent replacement before any
other work can proceed.

Examples: auth layer if the new direction still has users; database client if
the new stack still persists data; core domain model if it maps directly to the
new problem space.

**Action**: Mark as untouchable. Do not propose for removal regardless of RICE score.

### Should Keep

The module supports the new direction but is not on the critical path. Removing
it would require workarounds but would not block the pivot. Worth keeping if
the refactoring cost is low; consider simplifying rather than fully removing.

Examples: a utility library that the new direction uses 20% as often; a logging
abstraction that could be replaced with a simpler one eventually.

**Action**: Preserve for now. Flag for simplification in a future cleanup pass.

### Could Remove

The module is not relevant to the new direction AND has a manageable blast
radius. Removal is safe to schedule but not urgent.

Examples: a legacy export format the new direction does not support; a feature
flag system built for the old A/B testing strategy.

**Action**: Schedule for a cleanup sprint. Acceptable to defer.

### Won't Keep

The module actively contradicts the new direction, is confirmed dead code, or
was purpose-built for the old direction with no residual value. Prioritize for
removal.

Examples: old-direction business logic the new direction explicitly replaces;
code behind a permanently-disabled feature flag; modules that import only other
"Won't Keep" candidates.

**Action**: Include in surgical-remove candidates. Highest removal priority.

---

## Example Scoring: Three Module Archetypes

### Archetype A — Dead Code (easy removal target)

**Module**: `src/legacy/csv-exporter.ts` (180 LOC)
**Context**: New direction drops CSV export entirely in favor of API streaming.

| Dimension | Raw Signal | Score |
|---|---|---|
| Usage | 0 import statements, 0 call sites | 0 |
| Blast | 0 transitive dependents | 0 |
| Coverage | 1 test file, 2 assertions — traces happy path only | 2 |
| LOC | 180 LOC | 8 |

```
RICE = (0 × 0.30) + (0 × 0.30) + (2 × 0.20) + (8 × 0.20)
     = 0 + 0 + 0.4 + 1.6 = 2.0
```

**MoSCoW**: Won't Keep — no call sites, directly contradicts new direction.
**Rationale**: Dead code confirmed. Zero blast. Safe to delete immediately.

---

### Archetype B — Actively Used, Still Relevant

**Module**: `src/auth/session-manager.ts` (320 LOC)
**Context**: New direction still requires user authentication.

| Dimension | Raw Signal | Score |
|---|---|---|
| Usage | 42 call sites across 8 modules | 9 |
| Blast | 28 transitive dependents | 6 |
| Coverage | 68% branch coverage | 7 |
| LOC | 320 LOC | 7 |

```
RICE = (9 × 0.30) + (6 × 0.30) + (7 × 0.20) + (7 × 0.20)
     = 2.7 + 1.8 + 1.4 + 1.4 = 7.3
```

**MoSCoW**: Must Keep — auth is core to the new direction.
**Rationale**: High usage, broad blast radius, central to pivot. Do not touch.

---

### Archetype C — Partially Relevant (simplify, don't delete)

**Module**: `src/reporting/pdf-renderer.ts` (550 LOC)
**Context**: New direction keeps basic PDF export but drops advanced templating.

| Dimension | Raw Signal | Score |
|---|---|---|
| Usage | 8 call sites in 3 modules | 4 |
| Blast | 9 transitive dependents | 4 |
| Coverage | 35% branch coverage | 3 |
| LOC | 550 LOC | 4 |

```
RICE = (4 × 0.30) + (4 × 0.30) + (3 × 0.20) + (4 × 0.20)
     = 1.2 + 1.2 + 0.6 + 0.8 = 3.8
```

**MoSCoW**: Should Keep — basic PDF still needed; advanced templating is not.
**Rationale**: Medium RICE, partially aligned. Recommend simplifying to ~150 LOC
by removing the unused template engine integration rather than full removal.

---

## Output Table Schema

```markdown
| Module/File | Usage | Blast | Coverage | LOC | RICE Score | MoSCoW | Rationale |
|---|---|---|---|---|---|---|---|
```

**Column definitions:**

| Column | Type | Notes |
|---|---|---|
| Module/File | string | Relative path from project root |
| Usage | integer 0–10 | Raw dimension score |
| Blast | integer 0–10 | Raw dimension score |
| Coverage | integer 0–10 | Raw dimension score |
| LOC | integer 0–10 | Raw dimension score (inverse of line count) |
| RICE Score | decimal (1 place) | Weighted sum per formula above |
| MoSCoW | enum | Must Keep / Should Keep / Could Remove / Won't Keep |
| Rationale | string | 1–2 sentences. Flag conflicts here. |

Sort: ascending RICE Score (lowest first). Ties: Won't Keep before Could Remove
before Should Keep before Must Keep.

---

## Edge Cases

### Shared Utilities (`src/utils/`, `lib/helpers/`)

Shared utilities almost always have high Blast scores. Treat them with extra
caution:
- If >20 consumers: score Blast as 10 regardless of directory structure.
- Never mark a shared utility "Won't Keep" unless you have confirmed zero
  consumers via exhaustive static analysis.
- When in doubt: "Should Keep" with a note to audit consumers first.

### Test Files (`*.test.ts`, `*.spec.py`, `__tests__/`)

Do not score test files independently. They are scored as part of the module
they test. Exception: test helper files (fixtures, factories, shared mocks)
that are referenced by 10+ test files should be scored and marked Must Keep
or Should Keep if their module remains.

### Config Files (`*.config.js`, `*.yaml`, `*.toml`, env schemas)

Config files are deployment artifacts, not code modules. Score them only if
impact-analysis explicitly flagged them as removal candidates. When scored:
- Usage = 0 (configs are read at runtime, not imported)
- Blast = 10 if the config drives a still-needed system; 0 if the system is
  being removed
- Coverage = 0 (configs are rarely unit-tested)
- LOC = 10 (configs are almost always <50 lines)

### RICE / MoSCoW Conflicts

A conflict occurs when RICE Score > 6.0 AND MoSCoW = Could Remove or Won't Keep,
OR when RICE Score < 3.0 AND MoSCoW = Must Keep.

When a conflict is detected, add a `[CONFLICT]` prefix to the Rationale cell and
describe the tension explicitly. The user resolves all conflicts before approval.
Do not auto-resolve conflicts by overriding either the score or the category.
