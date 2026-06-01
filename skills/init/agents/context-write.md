# Sonnet Subagent Prompt — Context Write

Used by `/init` (any pathway) Phase 2d when the interview notes are large enough to warrant subagent synthesis. Fill in `[PLACEHOLDERS]` before spawning.

```
You are drafting project-context.md for [PROJECT_NAME] at [PROJECT_ROOT].

## Inputs

### Interview notes
[PASTE THE FULL INTERVIEW NOTES STRUCTURE FROM agents/questions.md OUTPUT]

### Discovery summary (join-existing / pivot modes only)
[PASTE THE DISCOVERY SUMMARY IF PRESENT — codebase observations, tech stack from manifests, existing docs found]

### Parent context (sub-project mode only)
[PASTE THE PARENT PROJECT'S project-context.md OR THE RELEVANT EXCERPTS]

### Pivot description (pivot mode only)
[USER'S PIVOT DESCRIPTION + THE ADVERSARIAL REVIEW VERDICT]

## What to write

A complete `project-context.md` following this exact structure:

```markdown
# Project Context — [PROJECT_NAME]

## Problem
[1-2 paragraphs synthesized from the "Problem & users" interview category]

## Users / Stakeholders
[Bullets — who uses this, in what scenarios. Specific, not generic.]

## Scope
- **In scope**: 
  - [bullet]
  - [bullet]
- **Out of scope**:
  - [bullet — from the user's explicit non-goals]
  - [bullet]

## Tech Stack
[Per-language/framework/key library: one line with rationale.
For sub-project mode: refer to parent's stack via "inherited from parent" — don't redefine.]

## Constraints
[Deployment, scale, regulatory, budget, time. Only include what was discussed.]

## Key Decisions
| Decision | Rationale | Alternatives considered |
|---|---|---|
| ... | ... | ... |

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ... | low/med/high | low/med/high | ... |

## Glossary
[Only if the domain has terms the future agent will need. Skip otherwise.]

## Changelog
- [TODAY] — Initial context, drafted from interview on [DATE]
  [For join-existing add:] Joined existing project at commit [SHA].
  [For sub-project add:] Sub-project of [parent-name].
  [For pivot add:] Pivot rewrite from [archived-filename].
```

## Discipline

- **No hallucination**: every claim in the doc traces back to interview notes, discovery, parent context, or pivot description. If you don't have the info, leave the section minimal — don't invent.
- **Keep "In scope" tight**: 5-10 bullets max. Anything not bulleted is implicitly out of scope.
- **"Out of scope" is just as important as "in scope"**: 3-7 bullets capturing the explicit non-goals the user surfaced.
- **Key Decisions only the BIG ones**: technology choices, architectural patterns, deliberate "we will / will not do X" commitments. Not minor style preferences.
- **Risks: don't reach**: if the user surfaced 2 risks, write 2 — don't add 5 generic risks ("complexity", "scope creep") to look thorough.

## Return format

Reply with the FULL markdown content of `project-context.md`. The main thread will:
1. Present it to the user for review.
2. Edit if the user requests changes.
3. Write the approved version to `[PROJECT_ROOT]/project-context.md`.

Do NOT write to disk yourself. Do NOT call any tool other than reading the inputs given above.

If you find genuine ambiguity in the interview notes that you cannot resolve, surface it at the top of your reply as "## Questions for user before this is final" with specific items — then provide your best-guess draft below for the user to correct.
```
