---
name: research
description: Researches a project topic via a single-Sonnet orchestrator with parallel worker subagents. Synthesis written to artifacts/research/. Invoke with /research or when the user says "research X" / "look into Y" / "validate this approach".
disable-model-invocation: true
argument-hint: "[<research question>]"
---

# Research

End-to-end research pipeline. The main thread plans topics; Sonnet subagents fan out per topic (no concurrency limit — the runtime parallelizes); the main thread synthesizes findings into a single document at `artifacts/research/<NNN>-<topic-slug>/synthesis.md`.

**Scope**: standard mode targets ~10-50 sources scanned across all topics — fast, focused, sufficient for most architectural decisions and library comparisons. For broader coverage (300+ sources, adversarial depth), use deep mode if available.

Designed to stay lean. The main chat context only sees the topic plan and the final synthesis — worker output flows through temp files, never inline.

## Inputs

| Input | Source | Required |
|---|---|---|
| `project-context.md` | Project root | Recommended (used to derive topics if no specific question is asked) |
| User's research question | Prompt | Yes |
| Prior research under `artifacts/research/` | Local | Optional (used to dedup or build on) |

## Outputs

- **Synthesis**: `artifacts/research/<NNN>-<topic-slug>/synthesis.md`
- **Optional sources file**: `artifacts/research/<NNN>-<topic-slug>/sources.md` (when there are 20+ cited URLs)
- **Local index**: `db_upsert 'research' 'index' '<NNN>-<topic-slug>' "<local-path>|<one-line-summary>|<timestamp>"`
- **Transient worker outputs**: `artifacts/research/<NNN>/workers/` — cleaned up by `/save` clear-mode

## Instructions

### Phase 1: Folder number

```bash
HIGHEST=$(ls artifacts/research/ 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1)
NNN=$(printf '%03d' $(( ${HIGHEST:-0} + 1 )))
```

You MUST use this command. Don't eyeball the folder list — collisions silently overwrite.

### Phase 2: Read context (if available)

If `project-context.md` exists, read it and extract sections relevant to the research question. Compress to essentials — don't pass the whole document to workers.

If the user's question is broad ("research this project"), clarify with 2-3 questions max:

- What decision will this inform?
- Known constraints or biases to challenge?
- Prior research to build on?

Don't over-interview. If the question is narrow ("compare X vs Y"), skip clarification.

### Phase 3: Plan topics (main thread)

Decompose the research question into 3-8 discrete topics. For each:

1. **Title** — one short phrase
2. **Lane** — `academic` (theory, comparison, design patterns), `code` (APIs, idioms, examples), or `both`
3. **Priority** — P0 (blocks the decision) / P1 (important) / P2 (nice-to-know)
4. **Self-counter** — "What would make this topic unnecessary?" If the answer is "we already know," demote or drop.

Write the topic plan to `artifacts/research/<NNN>/research_plan.md`.

### Phase 4: Approval gate

Present the plan to the user:

> "Research plan ready with {N} topics (P0: X | P1: Y | P2: Z).
>
> 1. Execute all
> 2. P0 only
> 3. Cherry-pick — tell me which topic numbers
> 4. Stop here, save the plan, execute later"

Wait for the user's answer. Don't assume.

### Phase 5: Worker fan-out (Sonnet subagents)

For each topic in the approved scope, spawn a Sonnet subagent via the `Agent` tool (`subagent_type: "general-purpose"`). Batch all `Agent` calls in a single tool-use block so the runtime parallelizes them.

Each worker prompt is assembled from:
- `agents/standard-worker.md` template
- Topic title + lane + priority
- The compressed context excerpt from Phase 2
- Available connectors (WebSearch + whatever MCP tools are present in this session — e.g., GitHub MCP, Context7 docs)
- Source-tally requirements (3-5 queries per topic minimum)
- Expected output path (the worker writes to a temp file, main thread persists)

Workers return findings as response text. The main thread reads the responses and writes them to `/tmp/research-<NNN>-worker-<topic>.md` so the synthesis step has a stable file to read.

Wait for all workers to return. If one fails, proceed with the others and note the failure in synthesis.

### Phase 6: Synthesis (main thread)

Read all worker outputs. Build the synthesis document:

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
| <other MCP> | N | N | N |
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

Write to `artifacts/research/<NNN>-<topic-slug>/synthesis.md`. If there are >20 cited URLs, also write a `sources.md` alongside.

Clean up temp files:

```bash
rm -f /tmp/research-<NNN>-worker-*.md
```

### Phase 7: Index

```bash
source references/db.sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SUMMARY=<one-line summary from the synthesis exec summary>
db_upsert 'research' 'index' "${NNN}-${TOPIC_SLUG}" "artifacts/research/${NNN}-${TOPIC_SLUG}/synthesis.md|${SUMMARY}|${TIMESTAMP}"
```

Skills like `/build-plan` and `/iterate` check this index via `db_age_hours 'research' 'index' '<topic>'` to decide whether to rerun.

### Phase 8: Memory sync (cross-cutting rule 5)

Always write the synthesis summary to the local memory log:

```bash
source references/db.sh
PROJECT=$(basename "$(git rev-parse --show-toplevel)")
SUMMARY="Research ${NNN}-${TOPIC_SLUG}: <exec-summary, 3-5 lines>. Sources: <N> scanned / <N> cited. Confidence: <map>."
LABEL="${NNN},${TOPIC_SLUG},${PROJECT}"

# Dedup: if a fresh entry exists for the same topic, upsert
AGE=$(db_age_hours 'memory' 'research' "$LABEL")
if [[ -n "$AGE" && "$AGE" -lt 24 ]]; then
  db_upsert 'memory' 'research' "$LABEL" "$SUMMARY"
else
  db_write 'memory' 'research' "$LABEL" "$SUMMARY"
fi
```

**Optional MCP mirror**: if a memory MCP is configured in this session (e.g., `mcp__qdrant-memory__store_memory` or any `mcp__<name>__memory_call`), the main thread may also mirror the entry — best-effort, silent on failure. The local DB row stands as the source of truth.

### Phase 9: Present results

Read the synthesis exec summary and source tally. Present:
- Executive summary (3-5 lines)
- Source counts: `{N} scanned | {N} cited` across `{N}` connectors
- Confidence map: high / medium / low areas
- Gap areas — questions still open

### Phase 10: Terminal handoff

Offer:

> "Research complete. {N} sources scanned | {N} cited.
>
> 1. **Build the plan** — `/build-plan` informed by these findings
> 2. **Dive deeper** — re-run specific topics or sub-questions
> 3. **Done for now** — apply findings when ready"

Wait for the user's answer.

## References (on-demand)

- `references/standard.md` — full single-orchestrator pipeline (topic plan → worker fan-out → synthesis)

## Agent prompts (on-demand)

- `agents/standard-worker.md` — per-topic Sonnet worker prompt template

## Examples

```
User: /research
→ Phase 2 reads context. Phase 3 plans 5 topics from context. Phase 4 asks
  for approval. Phase 5 dispatches 5 Sonnet workers in parallel. Phase 6
  synthesizes to artifacts/research/001-<slug>/synthesis.md. Phase 8 writes
  the memory entry. Phase 10 offers /build-plan handoff.
```

```
User: /research — Postgres or SQLite for this scale
→ Narrow scope. Phase 2 skips clarification (question is concrete). Phase 3
  plans 3 topics (scaling characteristics, operational overhead, migration
  path). Phase 5 dispatches 3 workers. Synthesis surfaces a recommendation
  with confidence + caveats.
```

```
User: /research — quick check on what react-query v5 changed
→ Single-topic mode. Phase 3 plans 1 topic. Phase 5 dispatches 1 worker
  scoped to docs/changelog. Synthesis is short (~50 lines). Phase 10 suggests
  /iterate (the migration is small).
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
