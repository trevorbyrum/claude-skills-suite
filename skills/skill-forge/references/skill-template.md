# Canonical SKILL.md Template

Reference for skill-forge. This is the ground truth for skill structure.

## Frontmatter (Required)

```yaml
---
name: <skill-name>
description: <trigger-focused description, ≤150 chars>
---
```

### Frontmatter Rules

- **`name`**: lowercase, hyphenated, matches directory name exactly
- **`description`**: The primary trigger mechanism. How Claude Code decides to load this skill.
  - Write in **third person** ("Evaluates...", "Commits and pushes...", "Scans for...")
  - Include **specific trigger phrases** ("Use when...", "Invoke with /name or when user says...")
  - **≤150 characters** — descriptions over this limit may be silently truncated
  - **Never use always-on language** — "Runs after completing work" or "Triggers whenever X changes" reads as a standing instruction and causes infinite loops. Use explicit invocation: "Invoke explicitly with /name"

### Optional Frontmatter Fields

```yaml
argument-hint: [description of accepted arguments]
```

Do NOT add fields that don't exist in the spec. No `disable-model-invocation`, no custom fields.

## Body Structure

Every SKILL.md follows this section order. Omit optional sections if not applicable — don't include empty sections.

### 1. Title

```markdown
# Skill Name
```

Human-readable name. Title case. Matches the `name` field conceptually.

### 2. Purpose (1-3 sentences)

What this skill does and **why it exists**. Not just "reviews tests" but "reviews tests because LLM-generated tests have specific failure patterns that manual review misses."

The purpose should answer: "Why can't I just do this myself?" If it doesn't have a compelling answer, the skill may not be worth building.

### 3. Inputs

Table or list of what the skill needs to run:

```markdown
## Inputs

- `project-context.md` — to understand scope and constraints
- `features.md` — to map features to coverage
- The full codebase
```

Or table format for complex inputs:

```markdown
| Input | Source | Required |
|---|---|---|
| project-plan.md | Project root | Yes |
| project-context.md | Project root | Yes |
```

### 4. Outputs

What the skill produces. Two patterns exist:

**Pattern A — Artifact DB (for review lenses and intermediate findings):**
```markdown
## Outputs

- **Standalone mode**: Store findings in the artifact DB:
  `db_upsert '<skill-name>' 'findings' 'standalone' "$CONTENT"`
- **Multi-model mode** (called by meta-review): Store per-model findings:
  - Sonnet: `db_upsert '<skill-name>' 'findings' 'sonnet' "$CONTENT"`
  - Codex: `db_upsert '<skill-name>' 'findings' 'codex' "$CONTENT"`
  - Gemini: `db_upsert '<skill-name>' 'findings' 'gemini' "$CONTENT"`
```

**Pattern B — File output (for final deliverables or project docs):**
```markdown
## Outputs

- `project-plan.md` in project root
- Updated `features.md` with status tracking
```

**Pattern C — No persistent output (action skills like github-sync):**
```markdown
## Outputs

- Clean working tree with changes committed and pushed
- Commit hash reported to user
```

Choose the pattern that fits. Review lenses always use Pattern A. Meta-skills may use both A and B.

### 5. Instructions

Numbered phases/steps. Each step has:
- A clear action (imperative: "Read", "Check", "Scan", "Produce")
- Context for why this step matters (1 sentence, not a paragraph)
- Bash examples where the action involves DB or CLI calls
- An explicit exit condition where applicable

```markdown
## Instructions

### Phase 1: Load Context

Read `project-context.md` to understand the threat model.
This shapes which checks matter — a CLI tool needs different analysis than a public API.

### Phase 2: Scan for X

...

### Phase N: Produce Findings

Format each finding using this structure (store via `db_upsert` as shown in Outputs above):
```

**Key instruction patterns:**

#### Fresh Findings Check (review lenses only)
```markdown
### Fresh Findings Check

Before running a new scan, check if fresh findings already exist:
\`\`\`bash
source artifacts/db.sh
AGE=$(db_age_hours '<skill-name>' 'findings' 'standalone')
\`\`\`
If `$AGE` is non-empty and less than 24, report: "Found fresh findings from $AGE hours ago. Reuse them? (y/n)"
```

#### Finding Format (review lenses only)
Define the exact structure for findings. Each lens can customize categories but must include: severity, category, location, problem, evidence, recommendation.

#### Summarize (review lenses only)
End with a summary table: count by severity/category, overall verdict.

### 6. Execution Mode (if applicable)

How the skill runs standalone vs as part of a meta-skill:

```markdown
## Execution Mode

- **Standalone**: Spawn the `review-lens` agent with this skill's lens instructions.
  Stores findings as `db_upsert '<skill-name>' 'findings' 'standalone'`.
- **Via meta-review**: The `review-lens` agent runs Sonnet review, while Codex and Gemini
  run in parallel. Each stores findings under label `sonnet`/`codex`/`gemini`.
```

### 7. References (on-demand) (if applicable)

Pointer to progressive-disclosure reference files:

```markdown
## References (on-demand)

Read these files only when needed for the relevant section:
- `references/foo.md` — description of what it contains
- `references/bar.md` — description of what it contains
```

### 8. Examples (2-4)

Show different trigger scenarios. Use fenced code blocks:

```markdown
## Examples

\`\`\`
User: Run a security audit before we deploy.
→ Full audit across all categories. Produce prioritized findings.
\`\`\`

\`\`\`
User: Just check the auth implementation.
→ Emphasis on Auth section. Still scan other areas but prioritize auth.
\`\`\`
```

### 9. Cross-Cutting Footer (Required)

Every skill ends with:

```markdown
---

Before completing, read and follow `../references/cross-cutting-rules.md`.
```

## Progressive Disclosure Architecture

Skills use a 3-level loading strategy:

| Level | What | When Loaded | Budget |
|---|---|---|---|
| 1 | Frontmatter only | Always (part of skill index) | ≤150 chars description |
| 2 | SKILL.md body | On trigger (user invokes skill) | ≤500 lines / ~2,000 words |
| 3 | `references/`, `agents/`, `templates/` | On demand (specific section needs it) | No hard limit, but keep files focused |

### Subdirectory Purposes

- **`references/`** — Deep reference docs, checklists, catalogs, schemas. Read on demand by specific instruction sections.
- **`agents/`** — Subagent prompt templates with XML tags and placeholders. Used by skills that spawn workers.
- **`templates/`** — Project scaffold templates (for skills that generate files in target projects).
- **`scripts/`** — Reusable bash utilities (rare — most shared logic lives in `references/db.sh`).

### When to Extract to References

Extract content to `references/` when:
- A section exceeds ~100 lines of reference material (catalogs, checklists, pattern lists)
- The content is only needed for one specific instruction step
- Multiple skills could potentially share the reference

Keep in SKILL.md when:
- The content is essential context for understanding the skill's flow
- It's under 30 lines
- Removing it would make the instructions unclear

## Sizing Guidelines

| Skill Type | Typical SKILL.md | References | Example |
|---|---|---|---|
| Simple action (github-sync, init-db) | 50-80 lines | 0 files | github-sync |
| Review lens (test-review, security-review) | 200-280 lines | 2-6 files | test-review |
| Meta-orchestrator (meta-execute, meta-review) | 300-500 lines | 2-3 agent prompts | meta-execute |
| Driver skill (codex, vibe, gemini) | 100-200 lines | 0-1 files | codex |

## Severity Levels (Review Lenses)

All review lenses use the same 4-tier severity:

- **CRITICAL** — Blocks deployment, causes data loss, security exposure, or correctness failure
- **HIGH** — Significant gap that needs immediate attention
- **MEDIUM** — Quality issue to fix before next milestone
- **LOW** — Nitpick or improvement suggestion
