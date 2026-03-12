---
name: skill-forge
description: Creates or edits skills. Scaffolds directory, writes SKILL.md from template, validates against checklist. Use when building or modifying a skill.
---

# Skill Forge

Create new skills or edit existing ones following the suite's established patterns.
Auto-detects mode based on whether the skill directory already exists — no separate
create/edit workflow needed.

## Why This Exists

Every skill in the suite was built by Claude, and every hard-won lesson (always-on
description loops, subagent DB write failures, stale file references, bare `timeout`
breakage) is documented in the validation checklist. Without this skill, each new
skill risks repeating those mistakes. Skill-forge encodes the patterns so they're
followed by default.

## Inputs

- **Skill name** — the user provides a name or describes what they want
- **Skill purpose** — what problem does it solve, when should it trigger
- **Existing SKILL.md** (edit mode) — the current file to modify
- `references/skill-template.md` — canonical SKILL.md structure
- `references/validation-checklist.md` — anti-patterns and validation rules

## Outputs

- `skills/<name>/SKILL.md` — the skill file (created or updated)
- `skills/<name>/references/` — reference files if progressive disclosure is needed
- `skills/<name>/agents/` — subagent prompts if the skill dispatches workers
- Validation report showing pass/warn/fail against the checklist

## Instructions

### Phase 1: Detect Mode

Check if `skills/<name>/SKILL.md` exists.

- **Exists** → edit mode. Read the current SKILL.md. Identify what the user wants changed.
- **Does not exist** → create mode. Gather intent from the user.

If the user hasn't provided a name, ask for one. Suggest a name following conventions:
- Review lenses: `*-review` (e.g., `performance-review`)
- Meta-skills: `meta-*` (e.g., `meta-deploy`)
- Driver skills: bare CLI name (e.g., `kubectl`)
- Action skills: verb-noun (e.g., `cache-warm`, `db-migrate`)

### Phase 2: Gather Intent

Ask the user (skip questions they've already answered):

1. **What does this skill do?** One sentence.
2. **What triggers it?** User says "X", after event Y, part of meta-skill Z.
3. **What does it need?** Inputs — files, project docs, external data.
4. **What does it produce?** DB records, files, side effects.
5. **Does it dispatch CLIs?** If yes, which ones — determines driver skill references.
6. **Is it a review lens?** If yes, it needs: fresh-findings check, finding format, severity levels, summary, execution mode (standalone + multi-model), and meta-review wiring.
7. **Does it need reference files?** Large catalogs, checklists, or prompt templates that would push SKILL.md over 500 lines.

For edit mode, also ask:
- **What's wrong with the current version?** Or what should change.

Present a brief plan before writing:
```
Mode: create | edit
Name: <name>
Type: review lens | meta-skill | driver | action | utility
Sections: [list of sections that will be included]
References: [list of reference files to create, if any]
Agent prompts: [list of agent prompt files, if any]
```

Wait for user approval before proceeding.

### Phase 3: Scaffold (Create Mode Only)

Create the directory structure:

```bash
mkdir -p skills/<name>/references   # always
mkdir -p skills/<name>/agents       # only if dispatching workers
mkdir -p skills/<name>/templates    # only if generating project files
```

### Phase 4: Write SKILL.md

Read `references/skill-template.md` for the canonical structure.

Write the SKILL.md following the template exactly. Key rules:

**Frontmatter:**
- `name:` must match directory name
- `description:` ≤150 characters, third person, trigger-focused, no always-on language
- Only add `argument-hint:` if the skill accepts arguments

**Body — follow section order from template:**
1. Title (# Name)
2. Purpose (1-3 sentences with "why")
3. Inputs (table or list)
4. Outputs (Pattern A for DB, Pattern B for files, Pattern C for actions)
5. Instructions (numbered phases, imperative form, exit conditions)
6. Execution Mode (if applicable — review lenses and meta-skills)
7. References (if reference files exist)
8. Examples (2-4 scenarios)
9. Cross-cutting footer

**Review lens specifics** (if this is a review lens):
- Add Fresh Findings Check as first instruction step
- Define finding format with: severity, category, location, problem, evidence, recommendation
- Define severity levels (CRITICAL/HIGH/MEDIUM/LOW)
- Add Summarize step as final instruction
- Add Execution Mode section with standalone + multi-model patterns
- Use artifact DB output pattern (Pattern A)

**Skills that dispatch CLIs:**
- Reference the driver skill (`/codex`, `/gemini`, `/vibe`, `/cursor`, `/copilot`)
- Do NOT inline CLI commands, flags, paths, or timeout syntax
- Specify only: task type, prompt template, output path, concurrency, fallback

### Phase 5: Write Reference Files (If Needed)

For each reference file identified in Phase 2:
- Create in `skills/<name>/references/`
- Each file should be focused on one topic
- Add a `## References (on-demand)` section to SKILL.md pointing to each file
- Use the pattern: "Read `references/X.md` for [description of when/why to read it]"

For agent prompt templates:
- Create in `skills/<name>/agents/`
- Use XML tags and `[PLACEHOLDER]` markers for values the skill fills in at runtime
- Reference from SKILL.md: "Read `agents/X.md` for the prompt template — fill in placeholders before spawning"

### Phase 6: Validate

Read `references/validation-checklist.md` and check the skill against every applicable rule.

Run the checks:

1. **Frontmatter checks** (F1-F6)
2. **Structure checks** (S1-S9)
3. **Content quality checks** (C1-C6)
4. **Anti-pattern checks** (A1-A10)
5. **Artifact DB checks** (D1-D5) — if the skill uses the DB
6. **Driver boundary checks** (B1-B5) — if the skill dispatches CLIs
7. **Progressive disclosure checks** (P1-P5) — if reference files exist
8. **Infrastructure checks** (I1-I4) — if the skill uses CLI workers

Report results using the validation summary format from the checklist.

**Any FAIL = fix before finishing.** Warnings are advisory — fix if easy, note if not.

### Phase 7: Report

Tell the user:
- Files created/modified (with paths)
- Validation result (PASS/WARN/FAIL)
- Any warnings that weren't fixed and why
- Whether the skill needs wiring into a meta-skill (meta-review for lenses, meta-init for lifecycle skills)
- Remind to run `/skill-doctor` if they want suite-wide validation

## Examples

```
User: I need a skill that reviews database query performance.
→ Create mode. Gather intent: review lens type, inputs = codebase + schema,
  outputs = DB findings. Scaffold, write SKILL.md with fresh-findings check,
  query analysis steps, finding format. Validate. Suggest wiring into meta-review.
```

```
User: The security-review description is too long, fix it.
→ Edit mode. Read current SKILL.md. Check description length. Trim to ≤150 chars
  while preserving trigger phrases. Validate the change.
```

```
User: /skill-forge dependency-audit
→ Create mode with name provided. Ask remaining questions (purpose, triggers,
  inputs/outputs). Scaffold and build.
```

```
User: Add a "What If" scenarios section to the test-review skill.
→ Edit mode. Read test-review/SKILL.md. Add the section following existing
  pattern. Check if content should be in references/ instead. Validate.
```

```
User: Make a driver skill for kubectl.
→ Create mode. Driver type — no references/ needed. Write SKILL.md with
  path discovery, flag reference, gotchas section. Validate against B1-B5.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
