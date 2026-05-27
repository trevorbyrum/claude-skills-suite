# Schema

> Canonical schema for `{{PROJECT_NAME}}`. Any change here is a contract change —
> downstream consumers, migrations, and tests depend on these definitions.

## Files

- `tables.sql` — Current authoritative table definitions (CREATE TABLE …).
- `migrations/` — Ordered, immutable migration scripts. Format: `NNN_short_name.sql` (e.g., `001_initial.sql`, `002_add_user_email_index.sql`).
- `schema.md` — Human-readable ERD + table descriptions. Updated when `tables.sql` changes.
- `seeds/` (optional) — Idempotent seed data for dev/test environments. Never run in production.

## Why This Exists

Schema is high-blast-radius. Three things make schema changes safe:

1. **Single source of truth.** `tables.sql` reflects the current state. Anything else (ORM models, type definitions, query builders) derives from it.
2. **Forward-only history.** New changes are new migrations. Never edit a shipped migration — write a follow-up.
3. **Drift detection.** `breaking-change-review` reads this directory and flags when ORM models, type definitions, or query code reference columns / tables / constraints that don't match `tables.sql`.

## Workflow

When making a schema change:

1. Write a new migration in `migrations/NNN_descriptive_name.sql`.
2. Apply it to your dev DB and confirm it runs cleanly.
3. Update `tables.sql` to reflect the new authoritative state.
4. Update `schema.md` with the new shape, relationships, and any rationale.
5. Run `/breaking-change-review` to catch downstream code that needs updating.
6. Update ORM models / type definitions / query code in the same commit as the migration — never let them drift across commits.

## Pre-Commit Guard

The `pre-commit-codex-lint.sh` hook runs `/breaking-change-review` in
schema-drift mode when files under `schema/` change. The commit is blocked
if drift is detected without a corresponding code update.

## What NOT to Put Here

- Production data dumps (use a separate backup process).
- Per-environment configuration (use `.env` / Vault).
- Generated artifacts (ORM-derived types live in the codebase, not here).
