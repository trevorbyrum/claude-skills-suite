# Build Plan — Lightweight Mode

For small in-session scope (formerly `/quick-plan`). No phases, no critical path, no risk table. Just a goal + checklist + sanity check.

## When to use this mode

| OK for | Not for |
|---|---|
| Adding a single feature (dark mode toggle, new endpoint) | A new project or major feature flow |
| Fixing a multi-step bug | Anything spanning > 1 day or > 10 file changes |
| Spike or experiment | Anything that needs `/execute` parallelism |
| In-session scoping before `/iterate` | Anything that benefits from up-front research |

Heuristic: if you can describe the goal in one sentence and the checklist fits in ≤ 7 bullets, lightweight is fine.

## Output

Lightweight plans do **not** modify `project-plan.md`. They live in one of two places depending on context:

- **If `/iterate` is active or about to start**: append the goal + checklist to the iterate changelog and put the checklist in `db_upsert 'iterate' 'checklist' 'current'`. Then exit `/build-plan` and hand off to `/iterate`.
- **Otherwise**: write to `/tmp/lightweight-plan.<date>.md` and tell the user it's transient.

## Structure

```markdown
# <one-line goal>

## Context
[1-2 sentences: what triggered this, why now]

## Checklist
- [ ] Step 1 — concrete action
- [ ] Step 2 — concrete action
- [ ] Step 3 — concrete action
- ...

## Risks
- [Anything that could derail this. Skip if none.]

## Done when
[One sentence: what does success look like? E.g. "Toggle works in light/dark, persists across reload, tests pass."]
```

## Process

1. **Capture goal in one question.** "What are we building?" — capture as the title.
2. **Generate the checklist.** 3-7 bullets, concrete actions. Use imperative verbs ("add", "wire up", "write test for"). Avoid "investigate" or "consider" — if those are needed, the scope is wrong for lightweight mode.
3. **Surface risks** if any are non-obvious. Skip the section entirely if none.
4. **Define done.** One testable sentence.
5. **Write the file**, present to user, ask if checklist looks right via `AskUserQuestion`.
6. **Handoff.** Suggest `/iterate` (bug-fix mode if bug, default if feature) to start the work. Tell the user the lightweight plan is transient — if scope grows, run `/build-plan` again in update or from-scratch mode.

## Anti-patterns

- **Re-creating from-scratch in lightweight form.** If you find yourself writing phases or milestones, the scope is too big — bail out and run from-scratch mode instead.
- **Updating `project-plan.md` from lightweight mode.** The whole point is that lightweight plans don't pollute the canonical plan file. They're scoped to one in-session loop.
- **Multiple lightweight plans in one session.** That's a signal the underlying work needs a real plan. Either consolidate into `/build-plan` update mode, or finish the current lightweight scope and reassess.
