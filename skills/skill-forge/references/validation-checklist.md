# Skill Validation Checklist

Reference for skill-forge. Validate every skill against this checklist before finishing.

## Frontmatter Checks

| # | Check | Severity | How to Detect |
|---|---|---|---|
| F1 | `name` matches directory name | FAIL | Compare `name:` field to parent directory |
| F2 | `description` ≤ 250 characters | FAIL | `wc -c` on description value |
| F3 | Description uses third person | WARN | Starts with "Evaluates", "Commits", not "Evaluate", "Commit" |
| F4 | Description includes trigger phrases | WARN | Contains "Use when", "Invoke with /name", or natural trigger words |
| F5 | No always-on language | FAIL | Flag: "Runs after", "Triggers whenever", "Applies when", "Automatically" — these cause loops |
| F6 | `disable-model-invocation: true` on lifecycle skills | FAIL | Required on `/init`, `/build-plan`, `/execute`, `/iterate`, `/review`, `/save` |
| F7 | No unrecognized frontmatter fields | WARN | Valid: `name`, `description`, `argument-hint`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context`, `agent`, `hooks`, `paths`, `shell` |

## Structure Checks

| # | Check | Severity | How to Detect |
|---|---|---|---|
| S1 | Has title (`# Name`) | FAIL | First `#` heading after frontmatter |
| S2 | Has "Why this exists" or opening paragraph | WARN | Text between title and first `##` |
| S3 | Has Inputs section | WARN | `## Inputs` present (omit for trivial action skills) |
| S4 | Has Outputs section | FAIL | `## Outputs` present |
| S5 | Has Instructions section | FAIL | `## Instructions` with numbered steps |
| S6 | Has Examples section | WARN | `## Examples` with 2-4 scenario blocks |
| S7 | Has cross-cutting footer | FAIL | Ends with `Before completing, read and follow ../../references/cross-cutting-rules.md.` |
| S8 | Body ≤ 280 lines | WARN | `wc -l` on SKILL.md. Over → extract to references/ |
| S9 | Body ≤ 1,500 words | WARN | `wc -w` on SKILL.md |

## Content Quality Checks

| # | Check | Severity | How to Detect |
|---|---|---|---|
| C1 | Instructions use imperative form | WARN | Steps say "Read", "Check", "Scan" — not "You should read" |
| C2 | Each step has a clear action | WARN | No purely-descriptive steps |
| C3 | Exit conditions defined | WARN | For multi-phase skills, each phase says when it's done |
| C4 | Finding format defined (review lenses) | FAIL | Review skills must define the exact finding structure |
| C5 | Summary section defined (review lenses) | WARN | Review skills should end with a summary table format |
| C6 | Severity levels documented (review lenses) | WARN | CRITICAL/HIGH/MEDIUM/LOW with definitions |
| C7 | No `--flag` branching | FAIL | Skill branches via auto-detection or `AskUserQuestion`, never CLI flags |

## Anti-Pattern Checks

| # | Anti-Pattern | Severity | What Went Wrong |
|---|---|---|---|
| A1 | **Stale file references** | FAIL | Outputs says `db_upsert` but instructions say "Write to the output file" — causes wrong write target |
| A2 | **Subagent DB writes** | FAIL | Instructions tell Sonnet subagents to call `db_upsert` — subagents don't have access to `references/db.sh`. Main thread does all DB writes |
| A3 | **External AI driver calls** | FAIL | No Codex anywhere in vclaude. Skills must NOT call Codex, Copilot, Gemini, or any external review service. Use Sonnet subagents (`Agent` tool, `subagent_type: "general-purpose"`) for all out-of-thread work |
| A4 | **References to removed skills** | FAIL | Mentions `/meta-execute`, `/meta-review`, `/meta-init`, `/evolve`, `/skill-doctor`, `/sync-skills`, `/copilot`, `/quick-plan`, `/claude-md-update`, `/research`, `/drift-review`, `/completeness-review`, `/clean-project`, `/compliance-review`, `/meta-context-save`, `/meta-pivot`, etc. — those have been dropped |
| A5 | **Non-portable timeout** | WARN | Resolve `gtimeout` (macOS/coreutils) OR `timeout` (Linux/GNU), whichever exists; fall back to running without a wrapper. Never hardcode an absolute path like `/opt/homebrew/bin/gtimeout` — it breaks every Linux user |
| A6 | **External MCP dependencies** | FAIL | Skills must NOT require homelab-specific MCP servers (arbytr Obsidian, Qdrant memory, SonarQube, Semgrep MCP). The suite runs on what ships with Claude Code plus standard CLI tools |
| A7 | **Always-on description** | FAIL | Description reads as standing instruction — causes loops. Use explicit invocation language |
| A8 | **Missing fresh-findings check** | WARN | Review lenses should check `db_age_hours` before re-running a scan |
| A9 | **Cross-cutting footer missing** | FAIL | Every skill must end with the cross-cutting rules reference |
| A10 | **Context stuffing in Sonnet subagent prompts** | WARN | Workers should receive 10-50k tokens of curated context, not the full codebase |
| A11 | **External storage assumed** | FAIL | All persistent state stays under `artifacts/` in the project repo. No external vault, no remote KB, no cloud sync. |

## Artifact DB Checks

| # | Check | Severity | When Applies |
|---|---|---|---|
| D1 | Outputs section uses `db_upsert` pattern | FAIL | Any skill storing intermediate findings |
| D2 | Correct artifact key format | WARN | `db_upsert '<skill-name>' '<phase>' '<label>' "$CONTENT"` |
| D3 | Fresh-findings check present | WARN | Review lenses that run scans |
| D4 | Standalone + lens labels documented | WARN | Review lenses participating in `/review` |
| D5 | No `db_upsert` in subagent prompts | FAIL | DB writes happen in main thread only |

## Driver Boundary Checks

| # | Check | Severity | When Applies |
|---|---|---|---|
| B1 | Sonnet subagents spawned via `Agent` tool | WARN | Use `subagent_type: "general-purpose"`. No Codex MCP anywhere in vclaude — no Copilot, no Gemini |
| B2 | `isolation: "worktree"` for parallel subagents | WARN | When parallel subagents may touch the same files |
| B3 | Subagent prompts include curated context | WARN | Aim for 10-50k tokens of focused inputs, not the full codebase |
| B4 | Fallback behavior specified | WARN | What happens if the subagent dispatch fails or returns empty |
| B5 | No CLI driver flags inline | FAIL | If a skill references `--model`, `--reasoning`, `codex exec`, `gh copilot`, etc., it's calling an external driver — remove |

## Progressive Disclosure Checks

| # | Check | Severity | How to Detect |
|---|---|---|---|
| P1 | Reference files exist for all `references/` links | FAIL | Every `Read references/X.md` in SKILL.md has a corresponding file |
| P2 | Agent prompts exist for all `agents/` links | FAIL | Every `Read agents/X.md` has a corresponding file |
| P3 | No orphan reference files | WARN | Files in `references/` not mentioned in SKILL.md |
| P4 | Reference files are focused | WARN | One topic per file, not a grab-bag |
| P5 | SKILL.md body doesn't duplicate references | WARN | If SKILL.md repeats reference content, extract it |

## Infrastructure Checks

| # | Check | Severity | When Applies |
|---|---|---|---|
| I1 | Sonnet subagents batched in single tool-use block | WARN | When parallelizing several `Agent` calls, send them in one message so the runtime parallelizes; no hard concurrency cap |
| I2 | Uses `run_in_background: true` for long Bash work | WARN | Skills running long-running bash commands |
| I3 | No sleep+poll loops | FAIL | Use `run_in_background` + the runtime's completion notification, not sleep+check |
| I4 | Timeout values specified | WARN | 180s Sonnet subagent, 240s research worker — see cross-cutting rule 7 |

## Naming Conventions

- Skill directories: `lowercase-hyphenated` (e.g., `test-review`, `github-sync`)
- Review lenses: `<area>-review` suffix (e.g., `security-review`, `test-review`)
- Action skills: verb or verb-noun (e.g., `github-sync`, `skill-forge`)
- Lifecycle skills: bare verb (e.g., `init`, `execute`, `review`, `save`)

## Validation Summary Format

After checking, report:

```
## Skill Validation: <skill-name>

| Category | Pass | Warn | Fail |
|---|---|---|---|
| Frontmatter | X | Y | Z |
| Structure | X | Y | Z |
| Content | X | Y | Z |
| Anti-Patterns | X | Y | Z |
| DB Integration | X | Y | Z |
| Driver Boundary | X | Y | Z |
| Progressive Disclosure | X | Y | Z |
| Infrastructure | X | Y | Z |

**Verdict**: PASS (0 FAIL) | WARN (0 FAIL, N warnings) | FAIL (N failures)

### Failures (must fix)
- [F5] Description uses always-on language: "Runs after..."

### Warnings (should fix)
- [S8] Body is 320 lines — extract catalogs to references/
```
