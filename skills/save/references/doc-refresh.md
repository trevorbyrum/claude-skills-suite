# Heavy Doc Refresh

Use only when the user explicitly asks to update docs ("update docs", "sync docs", "evolve") — typically after a real architectural change, scope shift, or research finding. Not for routine status updates (those are the light path in `SKILL.md` Phase 1).

## Three sub-modes

| Trigger | Sub-mode |
|---|---|
| "update context" / "context changed" | Context-only |
| "update plan" / "plan changed" / completed work units | Plan-only |
| Anything else | Full (both) |

If ambiguous → `AskUserQuestion` with the three options.

---

## Context-only

1. **Read `project-context.md`.** If missing, stop — tell the user to run `/init` first.
2. **Identify what changed.** Compare new information against the current document. List every field that needs updating.
3. **Edit sections in place.** Update affected fields directly so the body reflects current truth. Keep structure and formatting — change values, not layout.
4. **Add a changelog entry** at the top (newest first, append-only). Format:

   ```markdown
   ### YYYY-MM-DD — [PLATFORM]

   - **[Section]: [Field]**: "[old]" → "[new]"
   - **Key Decision added/changed/removed**: row number + content
   - **Reason**: one line
   ```

   `[PLATFORM]` must be one of: `[CLAUDE]`
5. **Verify completeness.** Every body change has a matching changelog line.

---

## Plan-only

1. **Read `project-plan.md`.** If missing, stop — tell the user to run `/init` first.
2. **Identify what changed.** Completed, added, removed, re-scoped, dependency changes.
3. **Edit work units in place.**
   - Mark completed work as done
   - Add new work units in the appropriate phase
   - Update dependency chains
   - Adjust scope descriptions
   - Move work between phases if sequencing changed
4. **Add a changelog entry** at the top (newest first, append-only). Format:

   ```markdown
   ### YYYY-MM-DD — [PLATFORM]

   - **Completed**: [WU] — [brief outcome]
   - **Added**: [WU] — [why needed]
   - **Changed**: [WU] — "[old]" → "[new]"
   - **Removed**: [WU] — [why no longer needed]
   - **Blocker added/resolved**: [WU] depends on / unblocked by [what]
   - **Reason**: [overall rationale]
   ```

   `[PLATFORM]` must be one of: `[CLAUDE]`
5. **Verify completeness.** Every status change has a matching changelog line.

---

## Full mode

### Phase A: Research gate (optional)

Run `/research` (standard mode, scoped tight) if **any** of:
- Change introduces tech/pattern not in the project's stack
- User describes a problem but doesn't have a clear solution
- You lack confidence in the best approach
- Change affects multiple architectural concerns with unclear tradeoffs

Skip research if **all**:
- Change is straightforward (completed work, scope cut, simple swap)
- Technologies are already understood in this project
- User has already made the decision

### Phase B: Informed discussion

After research (or if multiple valid approaches exist):

1. Summarize what you learned relevant to the change.
2. Present options if tradeoffs exist:
   - Option A: [approach] — pros — cons
   - Option B: [approach] — pros — cons
   - Recommendation + why
3. Surface risks: implications the user may not have considered, conflicts with existing Key Decisions.
4. Get explicit approval before updating docs.

Skip this phase if the user made a clear, unambiguous decision and just wants docs updated.

### Phase C: Evolve context

Run the Context-only flow above.

If the change only affected context (glossary update, constraint clarification) with zero plan impact: tell the user and exit.

### Phase D: Evolve plan

Run the Plan-only flow above. Pass any new context from Phase C (e.g., Key Decision changes affecting dependencies).

### Phase E: Cross-check consistency

After both phases complete:

1. **Verify no contradictions** between `project-context.md` and `project-plan.md`:
   - Context says tech stack X, plan has work units for Y?
   - Context says feature out of scope, plan has work units for it?
   - Context says constraint exists, plan ignores it?
2. If inconsistencies found, flag to the user and ask which document is correct. Fix before exiting.
3. **Present summary**: files modified, fields updated, work units affected, research incorporated, inconsistencies resolved.

---

## Why edit-in-place + append-only changelog

Both docs serve two audiences each:
- Someone who wants **current state** reads the body.
- Someone who wants the **decision trail** reads the changelog.

Edit-in-place keeps the body authoritative. Changelog-as-diff preserves history without cluttering the body.

After heavy refresh completes, both updated docs are the source of truth in the repo. No vault mirror — vclaude is local-only.
