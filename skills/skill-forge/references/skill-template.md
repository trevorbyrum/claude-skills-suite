# Canonical SKILL.md Template

Ground-truth structure for skills in this suite. Skill-forge uses this when generating new SKILL.md files.

## Frontmatter (Required)

```yaml
---
name: <skill-name>
description: <trigger-focused description, ≤250 chars>
argument-hint: "[optional-arg]"
disable-model-invocation: true
---
```

### Frontmatter Rules

- **`name`**: lowercase, hyphenated, matches directory name exactly. Max 64 chars.
- **`description`**: The primary trigger mechanism — how Claude Code decides to load this skill.
  - **Third person** ("Evaluates...", "Commits and pushes...")
  - **Specific trigger phrases** ("Use when...", "Invoke with /name or when user says...")
  - **≤ 250 characters** — over this is truncated
  - **No always-on language** — "Runs after X" or "Triggers whenever Y" reads as a standing instruction and causes loops. Use explicit invocation.
- **`disable-model-invocation: true`** on every lifecycle skill (`/init`, `/research`, `/build-plan`, `/execute`, `/iterate`, `/review`, `/save`). These are user-triggered only. Action skills (`/github-sync`, `/skill-forge`) stay auto-invocable.
- **`argument-hint`**: shown during autocomplete. Omit if the skill takes no arguments.

### Optional Advanced Fields

```yaml
# user-invocable: false              # Hides from / menu. Default: true.
# model: claude-opus-4-7             # Model override.
# effort: low | medium | high | max  # Effort level override.
# context: fork                      # Run in a forked subagent context.
# agent: <subagent-type>             # Subagent type; requires context: fork.
# shell: bash | powershell           # Shell for !command blocks. Default: bash.
# allowed-tools: [Bash, Read, Edit]  # Tools that can run without permission prompts.
# paths: ["src/**/*.ts"]             # Glob patterns limiting auto-activation.
```

## Body Structure

Section order. Omit optional sections if not applicable.

### 1. Title

```markdown
# Skill Name
```

Title case. Matches the `name` field conceptually.

### 2. Why This Exists (1-3 sentences)

What this skill does and **why it exists**. Not just "reviews tests" but "reviews tests because LLM-generated tests have specific failure patterns that manual review misses."

If you can't answer "Why can't I just do this myself?" — the skill may not be worth building.

### 3. Inputs

Table or bulleted list:

```markdown
## Inputs

- `project-context.md` — to understand scope and constraints
- `features.md` — to map features to coverage
- The full codebase
```

Or table format:

```markdown
| Input | Source | Required |
|---|---|---|
| project-plan.md | Project root | Yes |
| project-context.md | Project root | Yes |
```

### 4. Outputs

Two patterns:

**Pattern A — Artifact DB (review lenses, intermediate findings):**

```markdown
## Outputs

- **Standalone mode**: `db_upsert '<skill-name>' 'findings' 'standalone' "$CONTENT"`
- **As part of /review**: `db_upsert '<skill-name>' 'findings' 'lens' "$CONTENT"`
```

**Pattern B — File output (final deliverables, project docs):**

```markdown
## Outputs

- `project-plan.md` in project root
- Updated `features.md` with status tracking
```

**Pattern C — No persistent output (action skills like /github-sync):**

```markdown
## Outputs

- Clean working tree with changes committed and pushed
- Commit hash reported to user
```

Review lenses always use Pattern A. Lifecycle skills may use both A and B.

### 5. Instructions

Numbered phases. Each step has:
- An imperative action ("Read", "Check", "Scan")
- Brief context (1 sentence — not a paragraph)
- Bash examples for DB or CLI calls
- An exit condition where applicable

```markdown
## Instructions

### Phase 1: Load Context

Read `project-context.md` to understand the threat model.
This shapes which checks matter.

### Phase 2: Scan for X

...

### Phase N: Produce Findings

Format each finding (store via `db_upsert` as shown in Outputs above):
```

**Key patterns:**

#### Fresh Findings Check (review lenses only)

```markdown
### Fresh Findings Check

Before running a new scan, check for existing fresh findings:
\`\`\`bash
source references/db.sh
AGE=$(db_age_hours '<skill-name>' 'findings' 'standalone')
\`\`\`
If `$AGE` is non-empty and < 24, ask: "Found fresh findings from $AGE hours ago. Reuse? (y/n)"
```

#### Finding Format (review lenses only)

Define the exact structure. Each lens customizes categories but must include: severity, category, location, problem, evidence, recommendation.

#### Summarize (review lenses only)

End with a summary table: count by severity/category, overall verdict.

#### Branching (MANDATORY)

Skills must not use `--flag` arguments. Branch by:

1. **Auto-detection** — filesystem, git state, prior DB records.
2. **`AskUserQuestion`** at entry if (1) is ambiguous.

Example pattern at the top of Instructions:

```markdown
### Phase 0: Detect Mode

Check whether `project-plan.md` exists:
- Exists → continue in update mode (see references/update.md)
- Missing → continue in from-scratch mode (see references/from-scratch.md)

If neither path applies, ask the user via `AskUserQuestion`.
```

### 6. Execution Mode (review lenses only)

How the skill runs standalone vs as part of `/review`:

```markdown
## Execution Mode

- **Standalone**: Spawn the `review-lens` Sonnet subagent with this skill's instructions.
  Stores findings as `db_upsert '<skill-name>' 'findings' 'standalone'`.
- **Via /review**: `/review` dispatches all default-tier lenses in parallel via the
  `review-lens` agent. Findings stored under label `lens`.
```

### 7. References (on-demand)

Pointer to progressive-disclosure files:

```markdown
## References (on-demand)

Read only when the relevant section calls for them:
- `references/foo.md` — what it contains
- `references/bar.md` — what it contains
```

### 8. Examples (2-4)

Show different trigger scenarios:

```markdown
## Examples

\`\`\`
User: Run a security audit before we deploy.
→ Full audit across all categories. Produce prioritized findings.
\`\`\`
```

### 9. Cross-Cutting Footer (Required)

Every skill ends with:

```markdown
---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
```

## Progressive Disclosure

| Level | What | When Loaded | Budget |
|---|---|---|---|
| 1 | Frontmatter | Always (skill index) | ≤ 250 chars description |
| 2 | SKILL.md body | On trigger | ≤ 280 lines / ~ 1,500 words |
| 3 | `references/`, `agents/`, `templates/` | On demand | No hard limit; one focused topic per file |

### Subdirectory Purposes

- **`references/`** — Deep reference docs, checklists, catalogs, schemas.
- **`agents/`** — Sonnet subagent prompt templates with XML tags and placeholders.
- **`templates/`** — Project scaffold templates.
- **`scripts/`** — Bash utilities specific to the skill (rare — most shared logic lives in `references/db.sh` at the project level).

### When to Extract to References

Extract when:
- A section exceeds ~ 100 lines of reference material
- Content is only needed for one specific instruction step
- Multiple skills could potentially share the reference

Keep inline when:
- Essential context for understanding the flow
- Under 30 lines
- Removing it would make the instructions unclear

## Sizing Guidelines

| Skill Type | Typical SKILL.md | References | Example |
|---|---|---|---|
| Action (github-sync, skill-forge) | 80-160 lines | 0-2 files | `/github-sync` |
| Lifecycle (init, execute, review) | 150-280 lines | 2-6 files + agents/ | `/init`, `/review` |
| Review lens (security-review) | 100-180 lines | 0-2 files | `security-review` |

## Severity Levels (Review Lenses)

All review lenses share one severity scale:

- **CRITICAL** — blocks deployment, causes data loss, security exposure, correctness failure
- **HIGH** — significant gap needing immediate attention
- **MEDIUM** — quality issue to fix before next milestone
- **LOW** — nitpick or improvement suggestion
