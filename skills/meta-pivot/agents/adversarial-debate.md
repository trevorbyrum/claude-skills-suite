# Adversarial Debate — Codex + Gemini Protocol

Two modes: `candidate-challenge` (Phase 3.5) and `triage-challenge` (Phase 4.5).
Main thread fills in placeholders and dispatches CLIs.

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

```bash
# Codex (load /codex driver for syntax)
bash skills/codex/scripts/codex-exec.sh review \
  --output /tmp/pivot-debate-codex.md \
  --timeout 120 \
  --stdin /tmp/pivot-debate-candidates.md

# Gemini (load /gemini driver for syntax)
# Use Research / Analysis template, 120s timeout
# Output to /tmp/pivot-debate-gemini.md
```

### Fallback

- Codex fails → Sonnet subagent with same prompt, write to /tmp/pivot-debate-sonnet-1.md
- Gemini fails → Copilot (load /copilot), same prompt → /tmp/pivot-debate-copilot.md
- Copilot fails → Sonnet subagent, write to /tmp/pivot-debate-sonnet-2.md
- Minimum: 2 reviewers must complete

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

Same pattern as candidate-challenge. Same fallback chain.
