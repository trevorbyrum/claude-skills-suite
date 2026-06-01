# {{PROJECT_NAME}}

@AGENTS.md

## Claude-Specific Rules

- Prefer subagents for heavy work — keep main context lean
- Update project-context.md when architecture changes (use /save doc-refresh)
- Run tests after code changes when test infrastructure exists
- All model work is either main-thread Claude or a Sonnet subagent — no external AI integrations

## Project Structure

- All skill/agent output under `artifacts/`
- Schema changes require migration in `schema/` (if applicable)

## Permissions

- No destructive operations without explicit user confirmation
- No `rm -rf`, `git push --force`, `DROP TABLE` without approval
- No skipping hooks (`--no-verify`)

## Discovered Rules

<!-- Rules added during development -->
<!-- Each rule should be actionable, non-inferable from code, under 250 chars -->
