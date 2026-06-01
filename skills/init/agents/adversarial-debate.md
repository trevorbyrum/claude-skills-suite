# Adversarial Debate — Two Sonnet Subagent Protocol

Two modes: `candidate-challenge` (Phase 3.5) and `triage-challenge` (Phase 4.5).
Both run as a debate between two Sonnet subagents (`subagent_type: "general-purpose"`),
one steelmanning "keep" and one steelmanning "cut," judged by the main thread.

Main thread fills in placeholders and dispatches workers.

---

## Mode: candidate-challenge

Used after Phase 3 (Deep Analysis). Challenges the removal candidate list.

### Prompt (write to /tmp/pivot-debate-candidates.md)

```text
You are an adversarial reviewer for a project pivot. The project is changing
direction and the following files/modules have been flagged as removal candidates.

DIRECTION CHANGE:
[DIRECTION_SUMMARY]

REMOVAL CANDIDATES:
[CANDIDATES]

Your job is to CHALLENGE these candidates. For each one, evaluate:

1. Is this truly removable? Could it be dormant but needed?
2. Are there hidden dependencies not captured in the blast radius?
3. Would removing this break anything outside the test suite?
4. Is the confidence score appropriate?
5. Are there candidates MISSING from this list that should be here?

Output format:
## Disputed Items (should NOT be removed)
- [file/module]: [reason it should stay]

## Flagged Items (needs closer look)
- [file/module]: [concern]

## Missing Items (should be on the list)
- [file/module]: [why it should be removed]

## Agreed Items (removal is correct)
- [count] items confirmed as safe removals

Be adversarial. Assume the analysis missed something.
```

### Dispatch

**Reviewer 1 — Sonnet subagent (steelman "cut")**:

Spawn an `Agent` with `subagent_type: "general-purpose"`, prompt = the contents of `/tmp/pivot-debate-candidates.md` plus a leading instruction:

> "You are steelmanning the removal decision. Argue for cutting every candidate that has even a plausible case for removal. Push back hard against keeping anything dormant. Cite hidden coupling that justifies the cut."

The subagent returns its assessment as text; main thread writes it to `/tmp/pivot-debate-cut.md`.

**Reviewer 2 — Sonnet subagent (steelman "keep")**:

Spawn a second `Agent` with `subagent_type: "general-purpose"`, prompt = the contents of `/tmp/pivot-debate-candidates.md` plus a leading instruction:

> "You are steelmanning preservation. Argue for keeping every candidate that has even a plausible case for preservation. Surface external dependencies, dormant usage, and reversibility costs. Push back hard against premature cuts."

The subagent returns its assessment as text; main thread writes it to `/tmp/pivot-debate-keep.md`.

Spawn both subagents in the same tool-use block — the Claude runtime parallelizes them.

### Synthesis (main thread)

Main thread reads both files and synthesizes a verdict per candidate:

- Both reviewers agreed CUT → confirmed removal
- Both reviewers agreed KEEP → confirmed retention
- Disagreement → flagged for explicit human gate in Phase 4 Triage

### Fallback

- One subagent fails or times out → spawn a single judge subagent with both partial outputs and ask for the strongest case + caveats
- Both subagents fail → surface to user; pivot pauses

---

## Mode: triage-challenge

Used after Phase 4 (Triage). Challenges the keep/cut/simplify decisions.

### Prompt (write to /tmp/pivot-debate-triage.md)

```text
You are an adversarial reviewer for a project pivot. The team has triaged
modules into keep/cut/simplify categories. Challenge their decisions.

DIRECTION CHANGE:
[DIRECTION_SUMMARY]

TRIAGE DECISIONS:
[TRIAGE_DECISIONS]

For each decision, evaluate:

1. CUT items: Will removing this actually break something not covered by tests?
   Are there external systems (services, cron, CI) that depend on it?
2. KEEP items: Does keeping this contradict the new direction? Is it technical
   debt being preserved out of caution?
3. SIMPLIFY items: Is simplification realistic, or should this be a full cut?
4. WAVE ORDERING: Is the proposed removal order safe? Would removing Wave 1
   items break Wave 3 items before they're addressed?

Output format:
## Dangerous Cuts (high risk of breakage)
- [item]: [what could break and why]

## Questionable Keeps (contradicts new direction)
- [item]: [why it should be reconsidered]

## Wave Ordering Issues
- [description of ordering problem]

## Confirmed Safe (no objections)
- [count] decisions confirmed
```

### Dispatch

Same pattern as candidate-challenge (two Sonnet subagents in parallel — one steelmanning "the triage is too aggressive," one steelmanning "the triage is too cautious"). Same synthesis flow. Same fallback chain.
