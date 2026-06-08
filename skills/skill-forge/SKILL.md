---
name: skill-forge
description: Creates or edits skills. Scaffolds directory, writes SKILL.md from template, validates against checklist. Invoke with /skill-forge when building or modifying a skill.
argument-hint: "[<skill-name>]"
---

# Skill Forge

Create new skills or edit existing ones following the suite's established patterns.
Auto-detects mode based on whether the skill directory already exists — no separate
create/edit workflow needed.

## Why this exists

Every skill in this suite was built by Claude, and every hard-won lesson (always-on
descriptions causing loops, subagent DB write failures, stale file references)
lives in the validation checklist. Without this skill, each new skill risks
repeating those mistakes.

## Inputs

- **Skill name** — user provides or describes what they want
- **Skill purpose** — what problem it solves, when it triggers
- **Existing SKILL.md** (edit mode) — the file to modify
- `references/skill-template.md` — canonical SKILL.md structure
- `references/validation-checklist.md` — anti-patterns and validation rules

## Outputs

- `skills/<name>/SKILL.md` — created or updated
- `skills/<name>/references/` — only if progressive disclosure is needed
- `skills/<name>/agents/` — only if the skill dispatches Sonnet subagents
- Validation report (PASS/WARN/FAIL against the checklist)

## Instructions

### Phase 1: Detect mode

Check whether `skills/<name>/SKILL.md` exists.

- **Exists** → edit mode. Read the current file. Identify what to change.
- **Does not exist** → create mode. Gather intent.

If the user hasn't provided a name, ask for one. Naming conventions:
- Review lenses: `<area>-review` (e.g., `performance-review`)
- Action skills: verb or verb-noun (e.g., `cache-warm`, `db-migrate`)

### Phase 2: Gather intent

Ask the user (skip questions they've already answered):

1. **What does this skill do?** One sentence.
2. **What triggers it?** User says "X", or part of which lifecycle skill.
3. **What does it need?** Inputs — files, project docs, external data.
4. **What does it produce?** DB records, files, side effects.
5. **Does it dispatch Sonnet subagents?** Determines if `agents/` is needed.
6. **Is it a review lens?** If yes: fresh-findings check, finding format, severity levels, summary, execution mode required.
7. **Does it need reference files?** Large catalogs, checklists, prompt templates that would push SKILL.md over 280 lines.

For edit mode also ask: **What's wrong with the current version?**

Present a brief plan before writing:

```
Mode: create | edit
Name: <name>
Type: review lens | action | utility
Sections: [list]
References: [list]
Agent prompts: [list]
```

Wait for user approval before proceeding.

### Phase 3: Scaffold (create mode only)

```bash
mkdir -p skills/<name>
mkdir -p skills/<name>/references   # only if reference files are needed
mkdir -p skills/<name>/agents       # only if dispatching Sonnet subagents
mkdir -p skills/<name>/templates    # only if generating project files
```

### Phase 4: Write SKILL.md

Read `references/skill-template.md` for the canonical structure.

Follow the template exactly. Key rules:

**Frontmatter:**
- `name:` matches directory name
- `description:` ≤ 250 characters, third person, trigger-focused, no always-on language
- `disable-model-invocation: true` on lifecycle skills (user-triggered only)
- `argument-hint:` only if the skill accepts arguments

**Body — section order per template:**
1. Title
2. Why this exists (1-3 sentences)
3. Inputs
4. Outputs (Pattern A: DB; Pattern B: files; Pattern C: side-effect)
5. Instructions (numbered phases, imperative form, exit conditions)
6. Execution Mode — only for review lenses
7. References — only if reference files exist
8. Examples (2-4)
9. Cross-cutting footer

**Review lens specifics** (if this is a review lens):
- Fresh Findings Check as first instruction step (`db_age_hours` < 24h)
- Define finding format: severity, category, location, problem, evidence, recommendation
- Severity levels: CRITICAL / HIGH / MEDIUM / LOW
- Summarize step as final instruction
- Execution Mode section (standalone + as part of `/review`)
- Pattern A output (DB)

**If the new skill dispatches external agents** (Sonnet subagents):
- Sonnet subagents (the only out-of-thread option): use `Agent` tool with `subagent_type: "general-purpose"` per cross-cutting rule 3 + rule 11.
- No skill in vclaude calls Codex MCP. All model calls go through Claude main thread or Sonnet subagents.
- All multi-unit dispatch must follow rule 11 (parallel-by-default, max-impact-per-agent, debate-the-whole-in-pieces).
- Read cross-cutting-rules.md sections 2, 3, 6, 11 before authoring dispatch logic.

**Branching pattern (MANDATORY):**
Skills must not use `--flag` arguments. Branch by:
1. Auto-detection (filesystem, git, prior DB state).
2. `AskUserQuestion` at entry if (1) is ambiguous.

### Phase 5: Write reference files (if needed)

Each reference file:
- One focused topic
- Lives in `skills/<name>/references/`
- Linked from SKILL.md as `Read references/X.md for [purpose]`

Agent prompt templates:
- Live in `skills/<name>/agents/`
- Use XML tags and `[PLACEHOLDER]` markers for runtime values
- Referenced as `Read agents/X.md for the prompt template`

### Phase 6: Validate

Read `references/validation-checklist.md` and check every applicable rule:

1. Frontmatter (F1-F6)
2. Structure (S1-S9)
3. Content quality (C1-C6)
4. Anti-patterns (A1-A10)
5. Artifact DB integration (D1-D5) — if the skill uses the DB
6. Driver boundary (B1-B5) — if the skill dispatches Sonnet subagents
7. Progressive disclosure (P1-P5) — if reference files exist
8. Infrastructure (I1-I4) — if the skill spawns external workers

Report using the validation summary format from the checklist.

**Any FAIL = fix before finishing.** Warnings are advisory.

### Phase 7: Report

Tell the user:
- Files created/modified (with paths)
- Validation result (PASS / WARN / FAIL)
- Any warnings that weren't fixed and why
- Whether the skill needs wiring into `/review` (for lenses) or referenced from another lifecycle skill

## Examples

```
User: I need a skill that reviews database query performance.
→ Create mode. Review lens type. Inputs = codebase + schema. Outputs = DB findings.
  Scaffold, write SKILL.md with fresh-findings check, query analysis steps,
  finding format. Validate. Suggest wiring into /review's default-tier.
```

```
User: The security-review description is too long, fix it.
→ Edit mode. Read current SKILL.md. Trim description to ≤ 250 chars while
  preserving trigger phrases. Re-validate.
```

```
User: /skill-forge dependency-audit
→ Create mode with name provided. Ask remaining questions. Scaffold and build.
```

```
User: Add a "What If" scenarios section to the test-review skill.
→ Edit mode. Read test-review/SKILL.md. Add section following existing pattern.
  Check if content should live in references/ instead. Validate.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
