# {{PROJECT_NAME}}

## Stack

{{STACK_DESCRIPTION}}

## Commands

{{BUILD_COMMAND}}        # build
{{TEST_COMMAND}}         # run tests
{{LINT_COMMAND}}         # lint/format check

## Code Style

- {{LANGUAGE_CONVENTIONS}}
- No hardcoded secrets — use environment variables with empty-string fallbacks
- Follow existing patterns in the codebase — consistency over personal preference

## Boundaries

ALWAYS:

- Run tests before committing
- Validate inputs at system boundaries
- Use parameterized queries for database access
- Clean up after yourself: no debug logs, no commented-out code, no stubs

ASK FIRST:

- Adding new dependencies
- Changing database schema
- Modifying CI/CD pipeline configuration

NEVER:

- Hardcode secrets or credentials
- Commit .env files or credentials
- Skip pre-commit hooks (--no-verify)
- Force push to main/master

## Project Context

See `project-context.md` for architecture decisions and constraints.
See `project-plan.md` for implementation roadmap.
See `features.md` for product capabilities.
See `schema/` for the authoritative data model (tables, migrations,
ERD). Code that references DB columns/tables must stay in sync with
`schema/tables.sql` — `/breaking-change-review` flags drift.

## Commit Convention

- Format: `type: concise description` (feat, fix, refactor, test, docs, chore)
- Keep subject line under 72 characters
