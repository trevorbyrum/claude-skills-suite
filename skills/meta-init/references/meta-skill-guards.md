# Meta-Skill Guards

> Shared timeout and error handling patterns for meta-skills (meta-init,
> meta-join, meta-execute, meta-review, meta-production). Reference this
> file instead of duplicating these guards.

## Timeout Guards

- Set a mental time limit of 5 minutes per phase. If a phase has not produced
  output in 5 minutes, check if the subprocess is still running.
- For Codex calls: use `codex-mcp` MCP tools. Use `codex_health` for
  availability, `codex_run` for normal jobs, and `codex_start` plus
  `codex_status`/`codex_result` for long or parallel jobs. Set `timeout_sec`
  explicitly for work that may exceed the default. Prefer `skip_smoke: true`
  for fast availability checks; do not treat one health smoke timeout as a
  complete outage unless a real Codex task also fails/times out.
- For Copilot CLI calls: always use `$GTIMEOUT` with skill-appropriate values
  (120s for read-only analysis, 180s for larger prompts). If it times out,
  skip and note "Copilot timed out — skipping."
- For Sonnet subagents: no external timeout — managed by the Claude runtime.
  If a subagent has been running for more than 10 minutes with no output,
  consider it stalled and move on.
- If a subagent has been running for more than 10 minutes with no output,
  consider it stalled and move on.
- Report any timeouts in the completion summary so the user knows what was
  skipped.

## Context-Window Strategy

Non-interactive phases are delegated to subagents to keep the main thread
lean. Interactive phases (interviews, user approvals) stay inline. Each
subagent reads its own SKILL.md — never load atomic skill files into the
main context.

## Shared Phase Patterns

### Scaffold Check + Dispatch

Check for standard directories (`artifacts/`, `docs/`, `src/`) and template
files (`todo.md`, `features.md`, `CLAUDE.md`, `AGENTS.md`, `.gitignore`).
If all present, skip. If gaps, dispatch a subagent to fill them via
`project-scaffold`.

### Repo Check + Setup

Check if git is initialized and remote origin is set. If fully set up, skip.
If partially set up, ask user. If missing, run `repo-create` inline.

### Build Plan Dispatch

Dispatch a subagent with the `build-plan` skill. Pass project-context.md
and optionally research findings. Review output and present to user for
approval.
