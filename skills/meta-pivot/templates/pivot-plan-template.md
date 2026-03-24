# Pivot Plan

> Generated: {{DATE}}
> Direction: {{OLD_DIRECTION}} → {{NEW_DIRECTION}}
> Status: draft | approved | executing | complete

## Direction Change Summary

**Old direction**: {{summary}}
**New direction**: {{summary}}
**Reason**: {{why the pivot is happening}}
**Protected items**: {{items explicitly kept}}

## Removal Candidates

| # | File/Module | Source | Internal Blast | External Blast | Confidence | MoSCoW | Decision |
|---|-------------|--------|---------------|----------------|------------|--------|----------|
| 1 | {{path}} | {{dead-code/orphan/doc-diff/external}} | {{leaf/branch/trunk (N)}} | {{none/list}} | {{high/medium/low}} | {{must/should/could/wont}} | {{keep/cut/simplify}} |

## Wave Assignment

| Wave | Risk Level | Candidates | Est. Files | Status |
|------|-----------|------------|------------|--------|
| 1 — Dead code | Safest | {{list}} | {{N}} | pending |
| 2 — Orphans | Low | {{list}} | {{N}} | pending |
| 3 — Deprecated | Medium | {{list}} | {{N}} | pending |
| 4 — Restructure | Highest | {{list}} | {{N}} | pending |

## External Dependencies

| External System | Type | References | Impact if Removed |
|----------------|------|-----------|-------------------|
| {{system}} | {{service/cron/docker/CI/envvar}} | {{what it references}} | {{what breaks}} |

## Rollback Strategy

- **Pre-production**: Single branch `pivot/removal`. Rollback: `git branch -D pivot/removal`
- **Production**: Per-wave branches `pivot/wave-{N}`. Rollback per wave.
- **Roll-forward preferred**: Add back specific pieces rather than full revert.

## Adversarial Review Notes

### Challenge I (Candidates)
{{Summary of disputes and flags from Phase 3.5}}

### Challenge II (Triage)
{{Summary of disputes and flags from Phase 4.5}}

## Decision Log

| ADR | Item | Decision | Rationale |
|-----|------|----------|-----------|
| ADR-001 | {{item}} | {{cut/simplify}} | {{why}} |
