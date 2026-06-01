# Research — Standard Mode

Single-orchestrator pipeline. Main thread orchestrates; Sonnet subagents handle per-topic deep dives.

**Deliberate scope**: standard mode targets ~10-50 sources scanned across all topics. It is the lightweight option — fast, focused, sufficient for most architectural decisions and library comparisons. When broad coverage matters (300+ sources, adversarial debate, exhaustive gap-closing), use deep mode instead. This is an intentional design reduction from the legacy `research-execute` 300+ source target, which now belongs exclusively to deep mode.

## Pipeline shape

```
Phase A: Topic plan (main thread)
  → Approval gate
Phase B: Worker fan-out (Sonnet subagents in parallel, no concurrency limit)
Phase C: Synthesis (main thread)
```

## Phase A: Topic plan

1. **Extract topics from project-context.md** (or the user's question if no context).
2. **Categorize each topic** by lane:
   - **Academic** — concepts, theory, comparison papers, design patterns
   - **Code** — library APIs, framework idioms, working examples
   - **Both** — most architecture decisions
3. **Prioritize** P0 / P1 / P2:
   - P0 — blocks the build plan; if wrong, the project doesn't work
   - P1 — important but not blocking
   - P2 — nice to know, can defer
4. **Self-counter the plan** — for each topic, write one sentence:
   "What would make this research unnecessary?"
   If the answer is "we already know," demote or drop.
5. Write the plan to `artifacts/research/<NNN>/research_plan.md`.

## Approval gate

Present to the user:

> "Research plan ready with {N} topics (P0: X | P1: Y | P2: Z).
>
> 1. Execute all
> 2. P0 only
> 3. Cherry-pick — tell me which topic numbers
> 4. Stop here, save the plan, execute later"

Wait for the user's answer. Don't assume.

## Phase B: Worker fan-out

For each topic in the approved scope, spawn a Sonnet subagent in parallel (`subagent_type: "general-purpose"`, `isolation: "worktree"` if any worker may edit files — research workers typically don't).

Each worker:
- Reads `agents/standard-worker.md` for the prompt template
- Filled in with: topic name, priority, lane, mapped connectors (WebSearch + relevant MCP tools available in this environment), expected output path, source-tally requirements (3-5 queries per topic minimum)
- Returns its findings as text in the response — does NOT write to vault or DB directly (the main thread handles that)

Wait for all workers to return. If one fails, proceed with the others and note the failure in synthesis.

## Phase C: Synthesis

Main thread:
1. Collect all worker outputs.
2. Build the synthesis document:

```markdown
# Research Synthesis — <NNN> <topic title>

Generated: <date>
Project: <project-name>
Scope: <"All topics" | "P0 only" | "Cherry-picked: 1, 3, 5">

## Executive Summary
[3-5 lines: what was learned, top 3 decisions informed, biggest risk surfaced]

## Source Tally
| Connector | Queries | Scanned | Cited |
|---|---|---|---|
| WebSearch | N | N | N |
| <MCP tool> | N | N | N |
| ... | ... | ... | ... |
| **Total** | **N** | **N** | **N** |

## Findings by Topic

### Topic 1: <name> [P0 | P1 | P2]
**Question:** [as planned]
**Answer:** [3-5 line answer]
**Evidence:** [bullets with citations]
**Confidence:** high | medium | low
**Open:** [anything still uncertain]

### Topic 2: ...

## Cross-Topic Patterns
[Anything that spans multiple topics — usually high-value, surfaces hidden dependencies]

## Recommendations
[Prioritized list of decisions the user should make based on this research]

## Gaps and Low-Confidence Areas
[What this research couldn't answer with high confidence; what would close the gap]
```

3. Write a sources.md alongside if there are >20 cited URLs (otherwise inline in synthesis).
4. Proceed to Phase D (Triple-Counter) before handing back to SKILL.md Phase 7.

## Phase D: Triple-Counter Adversarial Review

The synthesis draft is one perspective. Challenge it with three parallel Sonnet subagents per cross-cutting rule 11, then integrate feedback before persisting.

### Dispatch (parallel)

Spawn all three at once (`subagent_type: "general-purpose"`). Each receives the full synthesis draft as context.

**Counter 1 — Skeptical reviewer:**
Prompt: "You are a skeptical peer reviewer. Read this research synthesis and identify: unsupported claims, missing perspectives, contradictions between sources, logical leaps, and questions the research failed to ask. Be specific — cite the claim and the weakness. Return your findings as structured text."

**Counter 2 — Adversarial reviewer with WebSearch:**
Prompt: "You have WebSearch. Read this research synthesis and challenge it adversarially. Search for recent developments the synthesis doesn't reflect, weak or overclaimed evidence, alternative viewpoints, and anything that would change the conclusions. Return your findings as structured text."
Grant this subagent WebSearch access.

**Counter 3 — Technical-rubric reviewer (Sonnet):**
Prompt: "You are a technical accuracy reviewer. Read this research synthesis and flag any claims about libraries, frameworks, APIs, protocols, or technical specifications that are outdated, incorrect, or unsupported by common knowledge or available documentation. For each flag: state the claim, explain the inaccuracy, and suggest a correction if possible. Return your findings as structured text."

Per cross-cutting rule 6: subagents return findings as response text only. Main thread persists.

### Integration

After all three return, the main thread:

1. Reads each counter's findings.
2. Identifies valid concerns (a concern is valid if it points to a real gap, overclaim, or inaccuracy — not just preference).
3. Appends a **"Challenges and Caveats"** section to the synthesis using this template:

```markdown
## Challenges and Caveats

### From skeptical review
[Address each valid point raised. If dismissed, explain why.]

### From adversarial web review
[Recent findings or alternative perspectives that qualify the synthesis conclusions.]

### From technical-rubric review
[Technical corrections or accuracy caveats.]
```

Then:

1. If a valid concern is significant enough to change a finding, update that finding's **Confidence** rating and note the revision.
2. Do NOT silently dismiss counter-arguments. Every flagged concern gets an explicit disposition.

Then hand control back to SKILL.md Phase 7 (Index + memory sync).

## Failure modes

- **Sonnet worker hits rate limit**: retry with backoff (one retry). If still fails, note in synthesis as "topic X — worker failed, recommend manual review."
- **No web access**: workers fall back to whatever MCP servers are available (e.g., GitHub MCP, Context7 docs). Note in the source tally what was reachable and what wasn't.
- **Topic too narrow for any source**: synthesis says "no evidence found" rather than fabricating.

## When to escalate to deep mode

If during Phase C you notice:
- Multiple findings flagged "low confidence" on the same topic
- Sources disagree (claims contested with no clear resolution)
- The decision the research is informing has high downside risk

Then SKILL.md Phase 8 should suggest re-running in deep mode for that specific question. Don't auto-escalate.
