# Skill Validation Checklist

Reference for skill-forge. Validate every skill against this checklist before finishing.

## Frontmatter Checks

| # | Check | Severity | How to Detect |
|---|-------|----------|---------------|
| F1 | `name` matches directory name | FAIL | Compare `name:` field to parent directory |
| F2 | `description` ≤ 150 characters | FAIL | `wc -c` on the description value |
| F3 | Description uses third person | WARN | Starts with verb ("Evaluates", "Commits"), not imperative ("Evaluate", "Commit") |
| F4 | Description includes trigger phrases | WARN | Contains "Use when", "Invoke with", or natural trigger words |
| F5 | No always-on language in description | FAIL | Flag: "Runs after", "Triggers whenever", "Applies when", "Automatically" — these cause infinite loops |
| F6 | No extra frontmatter fields | WARN | Only `name`, `description`, `argument-hint` are valid |

## Structure Checks

| # | Check | Severity | How to Detect |
|---|-------|----------|---------------|
| S1 | Has title (# Name) | FAIL | First `#` heading after frontmatter |
| S2 | Has Purpose section or opening paragraph | WARN | Text between title and first `##` |
| S3 | Has Inputs section | WARN | `## Inputs` present (can omit for trivial action skills) |
| S4 | Has Outputs section | FAIL | `## Outputs` present |
| S5 | Has Instructions section | FAIL | `## Instructions` with numbered steps |
| S6 | Has Examples section | WARN | `## Examples` with 2-4 scenario blocks |
| S7 | Has cross-cutting footer | FAIL | Ends with `Before completing, read and follow ../references/cross-cutting-rules.md` |
| S8 | Body ≤ 500 lines | WARN | `wc -l` on SKILL.md. Flag if over — extract to references/ |
| S9 | Body ≤ 2,000 words | WARN | `wc -w` on SKILL.md |

## Content Quality Checks

| # | Check | Severity | How to Detect |
|---|-------|----------|---------------|
| C1 | Instructions use imperative form | WARN | Steps say "Read", "Check", "Scan" not "You should read", "Consider checking" |
| C2 | Each step has a clear action | WARN | No steps that are purely descriptive without an action verb |
| C3 | Exit conditions defined | WARN | For multi-phase skills, each phase should say when it's done |
| C4 | Finding format defined (review lenses) | FAIL | Review skills must define the exact finding structure |
| C5 | Summary section defined (review lenses) | WARN | Review skills should end with a summary table format |
| C6 | Severity levels documented (review lenses) | WARN | CRITICAL/HIGH/MEDIUM/LOW with definitions |

## Anti-Pattern Checks (learned from production issues)

| # | Anti-Pattern | Severity | What Went Wrong |
|---|-------------|----------|-----------------|
| A1 | **Stale file references** | FAIL | Outputs says `db_upsert` but instructions say "Write to the output file" — causes .md file writes instead of DB writes |
| A2 | **Subagent DB writes** | FAIL | Instructions tell subagents to call `db_upsert` — subagents don't have access to `artifacts/db.sh`. Main thread must handle all DB writes |
| A3 | **Inlined CLI commands** | FAIL | Skill embeds Codex/Gemini/Vibe/Cursor/Copilot CLI flags, paths, or syntax instead of referencing the driver skill. Violates driver skill boundary |
| A4 | **Hardcoded CLI paths** | FAIL | Uses `/opt/homebrew/bin/codex` instead of dynamic discovery from driver skill |
| A5 | **Bare `timeout` command** | FAIL | Must use `$GTIMEOUT` (absolute path `/opt/homebrew/bin/gtimeout`). Bare `timeout` resolves to perl alarm wrapper in subagent shells, breaks Gemini |
| A6 | **Line-count output validation** | WARN | Validating CLI output by `wc -l` instead of `wc -c`. Gemini produces few very long lines (5-10 lines, 500-2000+ chars each) |
| A7 | **Always-on skill description** | FAIL | Description reads as standing instruction ("Runs after X", "Triggers when Y") — causes other agents to loop. Must use explicit invocation language |
| A8 | **Missing fresh-findings check** | WARN | Review lenses should check `db_age_hours` before re-running a scan to avoid duplicate work within 24h |
| A9 | **Cross-cutting footer missing** | FAIL | Every skill must end with the cross-cutting rules reference |
| A10 | **Context stuffing in worker prompts** | WARN | Workers should receive 10-50k tokens of curated context, not the full codebase. Irrelevant context degrades output |

## Artifact DB Integration Checks

| # | Check | Severity | When Applies |
|---|-------|----------|--------------|
| D1 | Outputs section uses `db_upsert` pattern | FAIL | Any skill that stores intermediate findings |
| D2 | Correct artifact key format | WARN | `db_upsert '<skill-name>' '<phase>' '<label>' "$CONTENT"` |
| D3 | Fresh-findings check present | WARN | Review lenses that run scans |
| D4 | Standalone + multi-model labels documented | WARN | Review lenses that participate in meta-review |
| D5 | No `db_upsert` in subagent prompts | FAIL | DB writes must happen in main thread |

## Driver Skill Boundary Checks

| # | Check | Severity | When Applies |
|---|-------|----------|--------------|
| B1 | CLI invocation references driver skill | FAIL | Any skill dispatching Codex/Gemini/Vibe/Cursor/Copilot |
| B2 | No embedded CLI flags or syntax | FAIL | Consuming skills specify task type + prompt + output path only |
| B3 | No auth/path setup inline | FAIL | Driver skill handles path discovery |
| B4 | No timeout syntax inline | FAIL | Driver skill handles `$GTIMEOUT` wrapping |
| B5 | Fallback behavior specified | WARN | What happens if the CLI is unavailable |

## Progressive Disclosure Checks

| # | Check | Severity | How to Detect |
|---|-------|----------|---------------|
| P1 | Reference files exist for all `references/` links | FAIL | Every `Read references/X.md` in SKILL.md has a corresponding file |
| P2 | Agent prompts exist for all `agents/` links | FAIL | Every `Read agents/X.md` in SKILL.md has a corresponding file |
| P3 | No orphan reference files | WARN | Files in `references/` not mentioned in SKILL.md |
| P4 | Reference files are focused (one topic each) | WARN | Each file covers one concept, not a grab-bag |
| P5 | SKILL.md body doesn't duplicate reference content | WARN | If SKILL.md repeats what's in a reference file, extract it |

## Concurrency and Infrastructure Checks

| # | Check | Severity | When Applies |
|---|-------|----------|--------------|
| I1 | Respects CLI concurrency limits | FAIL | Codex: 5, Vibe: 3, Cursor: 3, Gemini: 2, Copilot: 2 |
| I2 | Uses `run_in_background: true` for parallel CLI calls | WARN | Skills that dispatch multiple CLI workers |
| I3 | No sleep+poll loops | FAIL | Must use `run_in_background` + notification, not sleep+check |
| I4 | Timeout values specified for all CLI calls | WARN | 120s research/review, 180s generation, 300s complex |

## Naming Conventions

- Skill directories: `lowercase-hyphenated` (e.g., `test-review`, `meta-execute`)
- Review lenses: `*-review` suffix (e.g., `security-review`, `completeness-review`)
- Meta-skills: `meta-*` prefix (e.g., `meta-init`, `meta-review`)
- Driver skills: bare CLI name (e.g., `codex`, `gemini`, `vibe`)
- Action skills: verb or verb-noun (e.g., `github-sync`, `init-db`, `release-prep`)

## Validation Summary Format

After checking, report:

```
## Skill Validation: <skill-name>

| Category | Pass | Warn | Fail |
|----------|------|------|------|
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
- ...

### Warnings (should fix)
- [S8] Body is 520 lines — extract catalogs to references/
- ...
```
