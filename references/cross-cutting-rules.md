# Cross-Cutting Rules

These rules apply to every skill in the suite. Every atomic SKILL.md must follow them before completing.

## Rules

1. **Note todo/feature changes** — If you discover new action items or feature changes, mention them in your response so the user can run `/todo-features` if needed. Do NOT auto-invoke todo-features or update those files directly.

2. **CLI/MCP concurrency limits (MANDATORY)** — Never exceed these simultaneous process counts:
   - **Codex**: max **5** concurrent Codex MCP jobs / brokered `codex exec` processes
   - **Copilot**: max **2** concurrent `copilot -p` processes
   - **Sonnet subagents**: no hard limit (managed by Claude runtime)
   - If a skill needs more, queue excess and launch as slots free up. Do NOT launch all at once.
   - These limits come from `general.md` and override any per-skill instructions.

3. **Driver boundary (MANDATORY)** — Any skill that dispatches an external agent must use the documented driver interface. The driver is the abstraction layer.
   - **Codex**: Call the `codex-mcp` MCP tools directly (`mcp__codex-mcp__codex_health`, `mcp__codex-mcp__codex_run`, `mcp__codex-mcp__codex_start`, `mcp__codex-mcp__codex_status`, `mcp__codex-mcp__codex_result`, `mcp__codex-mcp__codex_cancel`). Do not construct raw `codex exec` commands or use any legacy shell wrapper.
   - **Copilot**: Load the `/copilot` driver skill for invocation syntax and path resolution.
   - **Sonnet subagents**: Spawn via the Agent tool. Use `isolation: "worktree"` when parallel subagents may touch the same files.
   - Gemini, Cursor, and Vibe drivers have been removed. Anywhere a skill previously dispatched them, replace with Codex MCP (code-centric work) or a Sonnet subagent (research, devil's advocate, web grounding via WebSearch).
   - Consuming skills must NOT bypass these driver interfaces with raw CLI commands, duplicate path-resolution logic, or embed gotcha lists.
   - If Codex broker details change, update `codex-mcp` and shared references only.

4. **Homelab Tools memory sync (MANDATORY)** — Keep Qdrant memory current so home Claude stays informed across projects and sessions. Use `mcp__claude_ai_Homelab_Tools__memory_call` with `tool: 'store_memory'`.
   - **After `/meta-execute` completion**: Store execution summary (units completed/failed/blocked, retry counts, confidence scores, wave count). Tags: `meta-execute`, `execution-summary`, `{project-name}`.
   - **After `/github-sync` push**: Diff what was pushed against what memory already knows (search first, then store the delta). Include: commit hash, branch, files changed summary, commit message. Tags: `github-sync`, `commit-log`, `{project-name}`.
   - **After `/research-execute` or `/meta-deep-research-execute` synthesis**: Store the executive summary + source tally + key findings. Tags: `research`, `{NNN}` or `{NNN}D`, `{project-name}`.
   - **Format**: `{ "tool": "store_memory", "args": { "content": "<summary>", "metadata": { "tags": [...], "skill": "<skill-name>", "project": "<project-name>" } } }`
   - **Dedup rule**: Before storing, search memory with the skill name + project name. If a recent entry (same skill, same project, <24h) exists, update it instead of creating a duplicate.
