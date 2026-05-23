---
name: claude-md-update
description: "Add, review, and consolidate rules in CLAUDE.md. Use when a convention should be persisted for future sessions."
argument-hint: "[rule text or 'review' to audit existing rules]"
---

# Claude MD Update

Manages the "Discovered Rules" section of CLAUDE.md. Keeps rules actionable, non-redundant, and under the 150-line effectiveness threshold.

Modes: **add** (default) — validate and append a rule | **review** — audit for staleness and duplicates.

## Instructions

### Mode Detection

- Argument is `review` → Review mode
- Any other text → Add mode (the text is the candidate rule)
- No argument → Ask: "Paste the rule to add, or say 'review' to audit existing rules."

---

### Add Mode

**1. Read CLAUDE.md.** Report: total line count, rule count in "Discovered Rules", list of existing rules. If CLAUDE.md doesn't exist, stop and tell user to create it first.

**2. Validate the candidate rule** — check all four gates, report pass/fail per gate:

| Gate | Criterion |
|---|---|
| Actionable | Specific instruction, not vague guidance ("write clean code" fails) |
| Non-inferable | Requires knowing context beyond reading the codebase |
| Length | ≤250 characters |
| No duplicate | <80% overlap with any existing rule |

If any gate fails, explain why and ask user to revise or confirm intent before continuing.

**3. Reframe** into canonical format: imperative verb first, specific, testable, one line, no hedging ("try to", "generally").

**4. Confirm with user:**
```
Original: <what the user said>
Reframed: <canonical version>
```
Ask: "Add this rule? (yes / edit / skip)" — wait for response.

**5. Append** the approved rule to the "Discovered Rules" section. If the section is absent, create it at the end of the file:
```markdown
## Discovered Rules

- <rule>
```

**6. Consolidation scan.** After appending, scan all rules for pairs that say the same thing or where one subsumes another. If found, propose merges with reasoning and wait for approval before changing anything.

**7. Budget check.** If CLAUDE.md is now ≥120 lines, warn:
> CLAUDE.md is at \<N\> lines — approaching the 150-line effectiveness threshold. Consider `/claude-md-update review` to consolidate.

---

### Review Mode

**1. Read CLAUDE.md.** Report line count and rule count.

**2. Audit each rule** for: stale references, vague/non-actionable language, duplicate coverage (≥80% overlap), inferability from the codebase alone.

**3. Present findings** grouped into Keep / Revise / Remove with reasoning. No edits until user approves.

**4. Apply approved changes.** Report final line count and rule count.

---

## Examples

```
User: /claude-md-update Always use snake_case for database columns
→ Validate (passes). Reframe: "Use snake_case for all database column names — never camelCase."
  Confirm. Append. Consolidation scan. Budget check.
```

```
User: /claude-md-update review
→ Read CLAUDE.md. Audit all rules. Present Keep/Revise/Remove groupings. Apply approved changes.
```

```
User: /claude-md-update The Redis connection needs explicit port :6379
→ Reframe: "Always include explicit port :6379 in Redis connection strings."
  Confirm. Append.
```

---

Before completing, read and follow `references/cross-cutting-rules.md`.
