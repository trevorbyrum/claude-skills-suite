# Init — Join-Existing Mode

Code exists, no `project-context.md`. You're onboarding into something that's already running.

## Quick catch-up sub-mode

When the project already has a recent context doc (<2 weeks old) AND the user wants a fast catch-up (e.g., "just catch me up", "quick sync", "what changed"), skip the full phase chain and run the abbreviated flow:

1. **Drift-review only** — Dispatch a Sonnet subagent (`subagent_type: "general-purpose"`) to compare the existing `project-context.md` against the current codebase. The subagent reads both, identifies drift (docs describe X, code does Y), and returns a diff-style summary.
2. **Present findings** — Main thread reads the subagent response and presents a concise "What changed since the context doc was written" summary to the user.
3. **Done** — No context doc rewrite, no plan update. The user decides whether to run `/save` doc-refresh if the drift is significant enough to warrant a full update.

Trigger condition: `project-context.md` exists AND its "Changelog" section shows an entry within the last 14 days AND the user request signals quick mode.

If the trigger condition is not met (context doc is missing, stale, or the user wants full onboarding), fall through to the standard phase chain below.

## Phase chain

```
Discover → Interview (scoped) → Context → [Phase 2c.5 Review] → Plan-or-Validate → Final Gate
```

## Phase 2a: Discover

Read the codebase to learn what's here. Aim for high-signal, low-effort reads:

1. **Repo metadata**:
   - `git log -10 --oneline` — recent activity
   - `git ls-files | wc -l` — rough size
   - Branch list, recent contributors
   - `README.md`, `CONTRIBUTING.md`, `docs/` index if any

2. **Stack detection**:
   - Manifest files (`package.json`, `pyproject.toml`, etc.) for language + key deps
   - `Dockerfile` / `docker-compose.yml` for runtime
   - CI config for build/test commands
   - `Makefile` / `justfile` for entry-point scripts

3. **Architecture sniff**:
   - Top-level directory structure
   - Look for `src/`, `app/`, `lib/`, `services/`, `packages/` patterns
   - Identify whether it's monorepo / multi-package / single-package

4. **Existing docs**:
   - Any `architecture.md`, `decisions.md`, `ADR-*.md`
   - Markdown files in `docs/` that look load-bearing

Compile a one-page "What I see" summary. This is the basis for the scoped interview.

## Phase 2b: Interview (scoped)

Different from greenfield's interview — you already know a lot from discovery. Use the discovery summary to compress the interview.

Ask only what discovery didn't answer:

1. **Intent** — "Reading the code, this looks like X. Is that right? Anything I'm misreading?"
2. **Purpose** — "What's the goal for you joining this project? Just understanding, or implementing something specific?"
3. **Pain points** — "Anything you already know is broken / janky / not-as-intended?"
4. **Constraints** — "Anything you can't change (compatibility, deployment, regulatory)?"
5. **Authority** — "Are you the owner of this codebase or contributing? Affects whether `project-plan.md` should reflect 'what's planned' (broad) vs 'what you're personally doing next' (narrow)."

Aim for 4-8 questions. The interview takes ~10 minutes, not the 30-45 of greenfield.

## Phase 2c: Context

Same `project-context.md` structure as greenfield. Sources:
- Discovery summary (Phase 2a) for tech stack, architecture, scope
- Interview (Phase 2b) for goal, constraints, decisions

Important difference: **changelog starts with two entries**:
1. "Initial context — joined existing project at commit <sha> on <date>"
2. (Anything notable inferred from discovery, e.g. "Tech stack: detected Next.js 14 + Postgres from package.json")

Present the draft for approval.

## Phase 2c.5: Project Review [/review, before context write]

Before writing or updating `project-context.md`, run `/review` (default tier) against the current codebase state. This catches projects with significant drift or quality issues so the context doc isn't written against a broken state.

Tell the user:

> "Reading the codebase and running /review before writing the context doc — this ensures the context reflects the actual state, not a broken one."

Invoke `/review`. This dispatches the full default-tier review suite (Sonnet-only lenses) against the codebase. Wait for results.

After review completes:

- **CRITICAL/HIGH findings**: Present to user before proceeding. These signal the codebase may be significantly broken or drifted. Ask: "The review found [N] critical/high issues. Proceed with context doc as-is, or address these first?"
  - If user wants to address them: pause join-existing flow; let user run `/execute` or fix manually; resume from Phase 2a (re-discover) when ready.
  - If user wants to proceed anyway: note findings in the context doc's "Current state" section under a "Known issues" subsection. Don't block the flow.
- **MEDIUM/LOW findings**: Note in the context doc's "Risks" section as "pre-existing technical debt." Don't block the flow.
- **No significant findings**: Continue to Phase 2c without comment.

Append a one-line `/review` summary to the bottom of the discovery summary from Phase 2a before using it to draft the context doc.

**Exit condition**: /review has run and findings have been triaged (presented to user if CRITICAL/HIGH, or noted silently if MEDIUM/LOW).

## Phase 2d: Plan-or-Validate

If `project-plan.md` already exists:
- Read it.
- Hand off to `/build-plan` — it auto-detects update mode when a plan exists and reconciles against the new context.
- Mark anything obviously done in the codebase as `[done]`.

If `project-plan.md` doesn't exist:
- Hand off to `/build-plan` from-scratch mode.
- The context document + the codebase state are inputs.

## Phase order rationale

Discover first because the codebase IS the most reliable source — read it before believing the user's mental model. Scoped interview to confirm hypotheses + fill gaps. Context as the synthesis. Plan-or-validate handles whichever case applies.

## Special cases

### "Contributing, not owning"

If the user is contributing to a project they don't own, `project-context.md` should be scoped narrowly:
- "Out of scope" includes everything outside the contribution area
- "Key decisions" only the ones relevant to the contribution
- The plan tracks only the contribution work, not the whole project

### "Project has its own docs already"

If `architecture.md` / `ADR-*.md` / equivalent exists, reference them from `project-context.md`'s "Sources" section rather than duplicating. The context doc is a tactical guide for our work; the project's own docs remain canonical for project-wide truth.

### "Project is heavily WIP"

Discovery often surfaces "code that exists but isn't wired up." Note these explicitly in the context's "Current state" section — the plan will need to decide whether to finish, remove, or ignore them.

## Error handling

- Discovery is overwhelming (project too large): scope to the directory the user names; flag that the rest is treated as "out of scope" until otherwise.
- Interview surfaces deep disagreement between user mental model and code reality: pause, surface the gap, ask which to trust before continuing.
- Manifest files contradict each other (two `package.json` in different subdirs claiming different versions): flag and ask the user which is canonical.
