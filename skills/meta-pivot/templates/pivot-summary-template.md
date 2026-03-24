# Pivot Summary — Audit Trail

> Project: {{PROJECT_NAME}}
> Started: {{DATE}}
> Status: in-progress | complete | paused

This is an append-only log. Each phase appends a timestamped section.
Never edit previous sections — only append new ones.

---

## Phase 1: Direction Interview
<!-- Appended after Phase 1 completes -->

**Timestamp**: {{ISO-8601}}

**Old direction**: {{summary}}
**New direction**: {{summary}}
**Reason for change**: {{why}}
**Protected items**: {{list}}
**Known removals**: {{list}}
**External concerns**: {{list}}
**User confirmed**: yes/no

---

## Phase 2: Context Rewrite
<!-- Appended after Phase 2 completes -->

**Timestamp**: {{ISO-8601}}

**Files updated**:
- project-context.md: {{change count}} changes
- project-plan.md: {{change count}} changes
- features.md: {{change count}} changes
- todo.md: {{change count}} changes

**Key changes**:
- {{change description}}

**User approved**: yes/no

---

## Phase 3: Deep Analysis
<!-- Appended after Phase 3 completes -->

**Timestamp**: {{ISO-8601}}

**Analysis results**:
- Total candidates: {{N}}
- By source: dead code ({{N}}), orphan ({{N}}), doc-diff ({{N}}), external ({{N}})
- Internal blast radius: leaf ({{N}}), branch ({{N}}), trunk ({{N}})
- External dependencies found: {{N}}
- Confidence: high ({{N}}), medium ({{N}}), low ({{N}})

---

## Phase 3.5: Adversarial Challenge I
<!-- Appended after Phase 3.5 completes -->

**Timestamp**: {{ISO-8601}}

**Reviewers**: {{Codex/Gemini/Copilot/Sonnet — which completed}}
**Disputed items**: {{N}} (items reviewers say should NOT be removed)
**Flagged items**: {{N}} (items needing closer look)
**Missing items**: {{N}} (items reviewers say should be added)
**Agreed items**: {{N}} (confirmed safe removals)

---

## Phase 4: Triage & Scoring
<!-- Appended after Phase 4 completes -->

**Timestamp**: {{ISO-8601}}

**Triage results**:
- Must keep: {{N}}
- Should keep: {{N}}
- Could remove: {{N}}
- Won't keep: {{N}}

**User decisions**: {{N}} items triaged
**Disputes resolved**: {{N}}

---

## Phase 4.5: Adversarial Challenge II
<!-- Appended after Phase 4.5 completes -->

**Timestamp**: {{ISO-8601}}

**Reviewers**: {{which completed}}
**Dangerous cuts flagged**: {{N}}
**Questionable keeps flagged**: {{N}}
**Wave ordering issues**: {{N}}
**User revised triage**: yes/no

---

## Phase 5: Decision Logging
<!-- Appended after Phase 5 completes -->

**Timestamp**: {{ISO-8601}}

**ADRs created**: {{N}}
**Decisions logged**: {{list of ADR-NNN: item — decision}}

---

## Phase 6: Wave Execution
<!-- Appended per wave -->

### Wave {{N}}
**Timestamp**: {{ISO-8601}}
**Branch**: pivot/wave-{{N}}
**Files removed**: {{N}}
**Files modified**: {{N}}
**Tests**: pass/fail
**Build**: pass/fail
**User decision**: approved/rolled-back/paused

---

## Phase 7: Verification
<!-- Appended after Phase 7 completes -->

**Timestamp**: {{ISO-8601}}

**Drift-review**: {{N}} findings ({{severity breakdown}})
**Completeness-review**: {{N}} findings
**Test suite**: pass/fail
**Lint**: pass/fail
**Build**: pass/fail
**Overall verdict**: CLEAN / NEEDS_ATTENTION / FAILED

---

## Phase 8: Full Project Review (meta-review)
<!-- Appended after Phase 8 completes -->

**Timestamp**: {{ISO-8601}}

**Lenses run**: {{count}} across {{model families}}
**Findings**: CRITICAL ({{N}}), HIGH ({{N}}), MEDIUM ({{N}}), LOW ({{N}})
**Critical/High resolved**: {{N}} of {{N}}
**review-fix invoked**: yes/no
**Deferred to follow-up**: {{list or none}}

---

## Phase 9: Final Doc Update
<!-- Appended after Phase 9 completes -->

**Timestamp**: {{ISO-8601}}

**Files updated**: {{list}}
**Key changes**: {{summary}}
**Manual fixes needed**: {{list or none}}

---

## Completion

**Total files removed**: {{N}}
**Total waves executed**: {{N}}
**Total ADRs**: {{N}}
**External dependencies addressed**: {{N}}
**Duration**: {{start to end}}
