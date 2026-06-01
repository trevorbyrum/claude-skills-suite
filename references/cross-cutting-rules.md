# Cross-Cutting Rules

These rules apply to every skill in the suite. Every SKILL.md must follow them before completing.

## Rules

1. **Note todo/feature changes** — If you discover new action items or feature changes, mention them in your response so the user can run `/build-plan` (update mode) if needed. Do NOT auto-invoke `/build-plan` or modify `project-plan.md`, `features.md`, or `todo.md` directly.

2. **Concurrency** — Sonnet subagents (`Agent` tool, `subagent_type: "general-purpose"`) have no hard concurrency limit; the Claude runtime manages parallelism. When fanning out reviewers, research workers, or rubric checks, prefer batching multiple `Agent` calls in a single tool-use block over launching one-by-one — the runtime parallelizes them automatically.

3. **Execution model (MANDATORY)** — Claude (main thread) writes code, edits files, and orchestrates. Sonnet subagents handle parallel/heavy work — research workers, devil's advocate, rubric review, lens reviewers in `/review`, web grounding via WebSearch. Use `isolation: "worktree"` when parallel subagents may touch the same files. There is no Codex/Copilot/Gemini integration in this suite — every model call is either main-thread Claude or a Sonnet subagent. Reviews are user-triggered via `/review`; there is no automatic background review hook.

4. **Storage layout** — All persisted artifacts stay local under the project's `artifacts/` directory.
   - SQLite + FTS5 artifact DB at `artifacts/project.db` (wrapper: `references/db.sh`)
   - Research synthesis at `artifacts/research/NNN-<topic-slug>/synthesis.md`
   - Review findings at `artifacts/reviews/<timestamp>/` (one folder per review run)
   - Init partial state at `artifacts/init-<phase>-partial.md`
   - Memory entries at `skill='memory', phase='<source-skill>'` rows in the artifact DB (see rule 5)
   - No external vault, no remote KB, no cloud sync required — everything works from the repo alone.

5. **Memory sync (local always, MCP optional)** — Skills that produce durable cross-session summaries write a memory entry to the local artifact DB. This is always safe and works with zero external dependencies.

   ```bash
   source references/db.sh
   db_write 'memory' '<source-skill>' '<comma-separated-tags>' "$SUMMARY"
   ```

   **Optional MCP mirror.** If the user has a memory MCP server installed (e.g., the `qdrant-memory` MCP exposing `mcp__qdrant-memory__store_memory`, or any custom gateway exposing `mcp__<name>__memory_call`), the main thread may *also* mirror the entry there for cross-project access. Detection is opportunistic: if the tool is visible in the session's tool list, call it; if it errors or isn't present, skip silently. **The local DB row is the source of truth.** The MCP mirror is a convenience for users who want a queryable cross-project memory layer; everything still works without it.

   **Triggers** (skill → what to write):
   - **After `/execute` wave**: wave summary (units done / failed / blocked, retry counts, confidence). Tags: `execute`, `wave-<N>`, `<project-name>`.
   - **After `/github-sync` push**: commit hash, branch, files-changed summary, commit message. Tags: `github-sync`, `commit-log`, `<project-name>`.
   - **After `/research`**: synthesis executive summary + source tally + key findings. Tags: `research`, `<NNN>`, `<project-name>`.

   **Dedup**: before writing, check `db_age_hours 'memory' '<source-skill>' '<label>'`. If a fresh entry (<24h) exists with the same skill+label, prefer `db_upsert` over `db_write` to update in place.

6. **Subagents cannot write the DB (MANDATORY)** — Sonnet subagents spawned via the `Agent` tool do NOT have access to `references/db.sh` or the project DB path. If a subagent calls `db_upsert` / `db_write` / `db_read` it will silently fail.
   - **Subagents return findings as response text only.** Never instruct them to persist.
   - **Main thread persists.** After a subagent returns, the main thread reads its response and writes to the DB.
   - For very large outputs, use the temp-file convention in rule 8.

7. **Stall and timeout standard** — Use these defaults unless a skill documents a deliberate override.

   | Operation | Timeout |
   |---|---|
   | Sonnet subagent (scaffold, context-write, rubric, lens reviewer, devil's-advocate) | 180s |
   | Sonnet research worker | 240s |
   | Interactive interview (inline `AskUserQuestion`) | no timeout; user-paced |
   | User-quiet interactive (wait phase) | 5 min wait; 30 min → save state and exit |

   Sub-second / fast bash calls (db.sh wrappers, git porcelain) have no timeout requirement.

8. **Temp-file handoff convention** — When a subagent's output is too large to embed in its response and must persist for the main thread to read, use `/tmp/<skill>-<phase>-<purpose>.<ext>`.
   - Examples: `/tmp/competitive-landscape.md`, `/tmp/lightweight-plan.<date>.md`, `/tmp/review-lens-<lens>.md`.
   - **Main thread cleans up** after persisting (`rm -f` the temp file once the content is in the DB or in a project file).
   - Never use `/tmp` files as a long-lived store — they are session-scoped scratch only.

9. **Worker budget per task (MANDATORY)** — Cap the number of attempts for any single work unit or fix:
   - `/execute` linear or single-WU: **5** attempts per WU before pausing and surfacing to the user
   - `/execute` review-fix: **3** attempts per finding
   - `/research` worker: 1 attempt; failure → note in synthesis (no automatic retry)
   - `/research` deep mode debate: 3 rounds TOTAL (position / challenge / response) across the WHOLE synthesis — see rule 11. NOT per-claim. If a single finding genuinely needs adversarial deep-dive beyond the whole-synthesis debate, that targeted check gets 2 rounds.

   When a budget is hit, **never silently retry beyond it.** Stop, log a verdict (PARTIAL or FAIL), surface to the user.

10. **PROJECT_DB fallback for non-git projects** — `references/db.sh` derives the DB path from `git rev-parse --show-toplevel`. For projects without a git repo, export `PROJECT_DB=<absolute-path>/artifacts/project.db` before sourcing `db.sh`. The `/init` `init-db` phase or shared bash will surface this if git isn't initialized yet.

11. **Subagent dispatch — parallel-by-default, max-impact-per-agent**

    Whenever a skill processes multiple units of work — work units in `/execute`, lens workers in `/review`, research tracks in `/research`, audit targets, fixes from a review synthesis — dispatch them in parallel by default. Build the dependency DAG, find the frontier (units whose deps are done), fan out one subagent per frontier unit in a single message. Serialize only when forced: an unmet dependency, or a shared `mutable`-file collision.

    But before deciding *how many* to dispatch, decide *how thick each slice should be*. The default mistake is over-fragmentation — slicing the work into so many trivial pieces that synthesis overhead and lost cross-cutting context cost more than the parallelism saves. This is the diffusion-of-labor problem: each agent ends up doing too little to add value.

    ### Sizing heuristics

    - **One agent owns one cohesive deliverable**, not a single line or single check. An audit subagent reads multiple related files and produces one report. A restoration subagent ports a related cluster of files end-to-end, not one file at a time.
    - **If you can't name what makes agent A's slice meaningfully different from agent B's, merge them.** Adjacent slices on the same file, same module, or same conceptual area belong to one agent.
    - **Prefer fewer thicker agents over many thin ones.** A single agent reading 10 files and producing a synthesis usually beats 10 agents each reading 1. The exception is when each unit is truly independent AND each requires deep per-unit attention (e.g. each is its own subsystem with no overlap).
    - **Cluster same-file colliders** into one subagent that handles them in dependency order. Don't make the whole wave sequential just because two units share a file.

    ### When to fan out wide vs cluster tight

    - **Wide** (one agent per unit): the units are genuinely orthogonal — different skills, different subsystems, different files, no cross-cutting context the synthesis would need.
    - **Tight** (cluster into thicker agents): the units share files, share rationale, share the same architectural concern, OR would all be reading roughly the same context anyway. Bundle them — one agent doing the whole concern beats many agents repeating the load.

    ### Debate the whole in pieces, not pieces of the whole

    An adversarial debate is allowed — and encouraged — to have multiple pieces: perspectives, rounds, lenses, attack angles. Each piece is a meaningful slice of the *debate*, not of the *subject under review*.

    Legacy `/research` deep Phase 3: 3 models × 3 rounds = **9 TOTAL dispatches**. The 9 are pieces of the debate (Round 1 = position paper, Round 2 = challenge, Round 3 = response — each model takes each role). But every one of the 9 engages with the ENTIRE synthesis. The structure has many pieces; every piece reads the whole.

    The failure mode is the reverse: shredding the SUBJECT into pieces and debating each piece in isolation. That multiplies dispatches by N findings, each reviewer loses cross-finding pattern recognition, and the synthesis-level signal collapses. This is what caused the 93-agent explosion in this project — debate was applied per-claim instead of per-synthesis.

    Rule: structure the debate however richly you want (multi-round, multi-model, multi-lens, adversarial vs friendly), but **each debater must engage with the WHOLE thing under review, not a sliver of it.**

    If a specific finding needs deeper scrutiny than the whole-synthesis debate provides, surface it explicitly with its own targeted check — but make that a deliberate per-finding decision, not the default shape of the debate.

    ### Concurrency caps and wave gates still apply

    - Sonnet subagents have no hard numeric ceiling; the sizing heuristics above are the practical ceiling.
    - The wave-gate user-approval pattern (between waves, in `/execute` Phase 4) is for cross-WU drift detection. It fires at wave boundaries, not before each unit within a wave. Don't insert `AskUserQuestion` gates between independent units in the same wave.
