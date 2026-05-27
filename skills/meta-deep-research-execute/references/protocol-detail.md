# Deep Research Protocol — Detailed Phase Instructions

This file contains the full step-by-step instructions for each phase of the
deep research protocol. The orchestrating subagent reads this file when
executing the research.

## Phase 1: Decomposition

Read `deep_research_prompt.md`. The dispatcher already identified sub-questions
during the clarifying interview. Your job:

1. **Validate and refine the sub-questions.** Add any the dispatcher missed.
   Remove duplicates. Ensure each is:
   - Specific enough for a single worker
   - Independent enough for parallel research
   - Answerable with evidence (not opinion)

2. **Classify each by evidence type:**

   | Type | Primary Workers |
   |---|---|
   | Academic | Sonnet (MCP connectors) |
   | Technical | Codex MCP + Sonnet (Context7, GitHub) |
   | Market | Sonnet (WebSearch + web grounding subagent) |
   | Reasoning | Opus subagent (extended thinking) |

3. **Build the dispatch table.** Assign each sub-question to 2-3 models.
   Every sub-question MUST be covered by at least 2 models.

4. **Write the dispatch table** to the artifact DB:
   ```bash
   source artifacts/db.sh
   db_upsert 'meta-deep-research-execute' 'dispatch-table' '{NNN}D' "$DISPATCH_TABLE_CONTENT"
   ```

## Phase 2: Parallel Research Fan-Out

Launch all 4 tracks simultaneously.

### Track A: Opus Deep Reasoning (2-3 subagents)

Spawn Opus subagents for "Reasoning" sub-questions. Each receives:
- Its assigned sub-questions
- Project context from the prompt file
- Full MCP connector access
- Instruction: "Use extended thinking. Cite every claim. Flag uncertainty."
- Instruction: "Track sources — include a Source Tally at the end of your output."

Output: `research-connector` / `findings` / `{NNN}D/{descriptive-name}` in the
artifact DB. Track A Opus subagents write their output there directly.

### Track B: Sonnet Connector Sweep (7-10 subagents)

One Sonnet subagent per MCP connector with mapped topics. Use the
`research-connector` agent — it has the multi-query protocol (3-5 queries per
topic) and source counting built in.

| Connector | Tool |
|---|---|
| Consensus | `mcp__claude_ai_Consensus__search` |
| Scholar Gateway | `mcp__claude_ai_Scholar_Gateway__semanticSearch` |
| PubMed | `mcp__claude_ai_PubMed__search_articles` |
| Synapse.org | `mcp__claude_ai_Synapse_org__search_synapse` |
| Clinical Trials | `mcp__claude_ai_Clinical_Trials__search_trials` |
| Context7 | `mcp__claude_ai_Context7__resolve-library-id` + `query-docs` |
| GitHub | `mcp__github__search_code` / `search_repositories` |
| Microsoft Learn | `mcp__claude_ai_Microsoft_Learn__microsoft_docs_search` |
| Hugging Face | `mcp__claude_ai_Hugging_Face__paper_search` |
| Web Search | `WebSearch` |

Skip connectors with zero mapped sub-questions.

**Each subagent MUST follow the multi-query protocol** and include the Source
Tally table in its output.

Output: `research-connector` / `findings` / `{NNN}D/{descriptive-name}` in the
artifact DB per connector (written by the research-connector agent).

### Track C: Codex Technical Validation (up to 4 workers)

**Hard limit: 4 concurrent Codex MCP jobs.** Reserve 1 slot for Phase 2.5/3.
Check availability with `mcp__codex-mcp__codex_health` using `skip_smoke: true`;
if that reports a hard broker/config error, reassign Codex work to Sonnet. Do
not reassign solely because a health smoke times out; launch one real Codex
worker with the normal task timeout and decide from that result.

**Workers 1-3: Primary research** — each gets 1-2 technical sub-questions.

Call `mcp__codex-mcp__codex_start` for each worker:
```json
{
  "mode": "review",
  "cwd": "/path/to/project",
  "prompt": "[assembled primary research prompt]",
  "timeout_sec": 300
}
```
The assembled primary research prompt asks Codex to check library docs, API
signatures, known issues, source tally, findings, confidence, and unverified
gaps for `[SUB-QUESTION]` using `[relevant excerpt]`.
Poll with `codex_status`, fetch with `codex_result`, then store the final
message:
```bash
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}' "$CODEX_FINAL_MESSAGE"
```

**Worker 4: Devil's advocate** — find problems with the likely answers.
Covers all sub-questions assigned to Codex devil's advocate in the dispatch
table. Broader scope than primary workers to compensate for single worker.

Call `mcp__codex-mcp__codex_start`:
```json
{
  "mode": "debate",
  "cwd": "/path/to/project",
  "prompt": "[assembled devil's advocate prompt]",
  "timeout_sec": 300
}
```
The assembled devil's advocate prompt asks for evidence against conventional
answers, known bugs, failure cases, better alternatives, outdated claims,
per-question counter-evidence, risks, and source tally.
Store the final message:
```bash
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}-counter' "$CODEX_FINAL_MESSAGE"
```

### Track D: Sonnet Web Grounding (2 subagents)

Two Sonnet subagents with WebSearch tool access. No external CLI required —
runs entirely within the Claude runtime, so no concurrency limit applies.

**Subagent 1: Primary research + case studies** — broad web grounding via
WebSearch. Combines primary research and case study collection.

Spawn an Agent (e.g., `subagent_type: "general-purpose"`) with this prompt:
```
You have WebSearch tool access. Research thoroughly using web search.
Prioritize recent (2025-2026) sources, practitioner posts, conference
talks, case studies. First-hand experience > theory.

Sub-questions: [LIST FROM DISPATCH TABLE]

Per question provide:
- Answer with citations (URLs)
- Source quality (authoritative vs blog vs forum)
- Recency
- Consensus level (agreed vs contested)

ALSO find real-world case studies and production deployments for each
question where applicable. Per case: company, scale, outcome, timeline,
would-they-do-it-again. Prioritize engineering blogs over generic how-tos.

At the END, include:
## Source Tally
- Web searches executed: [N]
- Results scanned: [N]
- Sources cited: [N]

Return the entire research output as text. The orchestrator will store it.
```
After the subagent returns, store its output in the DB:
```bash
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}-primary-web' "$AGENT_RESPONSE"
```

**Subagent 2: Contradiction hunter** — explicitly adversarial.

Spawn a second Sonnet subagent with this prompt:
```
You have WebSearch tool access. Find CONTRADICTING evidence and dissenting
opinions on:

[LIST WITH EXPECTED MAINSTREAM ANSWERS]

Find: posts arguing AGAINST the popular answer, failure stories, unexpected
benchmarks, migration-away stories.

Include Source Tally at end (searches executed, results scanned, cited).
Return the entire research output as text.
```
Store output in the DB:
```bash
source artifacts/db.sh && db_upsert 'research-connector' 'findings' '{NNN}D/{descriptive-name}-dissent' "$AGENT_RESPONSE"
```

Wait for all Phase 2 workers to complete.

### Phase 2 Source Aggregation

After all workers complete, parse Source Tally sections from all findings in the
artifact DB (query `research-connector` / `findings` / `{NNN}D/*`). Aggregate and
store:

```markdown
# Source Tally — Phase 2

| Worker | Track | Queries | Scanned | Cited |
|---|---|---|---|---|
| [descriptive-name] | B (Consensus) | 12 | 87 | 14 |
| [descriptive-name] | C (Codex) | 5 | 34 | 8 |
| [descriptive-name] | D (Sonnet WebSearch) | 8 | 156 | 22 |
| ... | ... | ... | ... | ... |
| **TOTAL** | | **N** | **N** | **N** |

Target: 1000+ scanned
Status: [ON TRACK / SHORTFALL — need N more]
```

Store this tally in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'source-tally' '{NNN}D' "$TALLY_CONTENT"
```

## Phase 2.5: Coverage Expansion (MANDATORY)

This phase ALWAYS runs. It is not optional or conditional. The initial research
inevitably surfaces topics, options, and alternatives that weren't in the
original prompt. The debate here is NOT about WHETHER to expand — it's about
WHAT needs expanded research, WHERE the research is thin, and WHICH emergent
tangential topics should be folded in.

### Step 1: Coverage Debate

Launch three reviewers in parallel: an Opus subagent, a Sonnet subagent
with WebSearch, and a Codex MCP worker.

Each reads:
- The original `deep_research_prompt.md`
- The dispatch table
- ALL Phase 2 findings files
- The source tally

Their job: identify what's missing, what's thin, and what new threads emerged.

**Reviewer A — Opus subagent** (parallel with Reviewer B and C):

Spawn an Opus subagent with this prompt:
```
You are a research coverage auditor. This is a MANDATORY expansion phase —
your job is to find what needs MORE research, not to decide if research is
"sufficient." There is ALWAYS more to find.

Read:
1. {research_folder}/deep_research_prompt.md (original scope)
2. The dispatch table from the artifact DB (what was planned)
3. All Phase 2 findings in the artifact DB (what was found)
4. The source tally (coverage breadth)

Identify:
- Which original sub-questions have THIN evidence (low source count,
  single-source, low confidence)? These need reinforcement.
- What NEW topics, options, or alternatives surfaced during the research
  that weren't in the original prompt but are clearly relevant?
- Are there well-known approaches, tools, or patterns that practitioners
  would expect to see but the research missed entirely?
- Which connectors underperformed (low result counts)? What different
  queries might yield better results?
- How far is the source count from the 1000+ target? Which tracks should
  contribute more?

Return your assessment as text. The orchestrator will store it.

Format:
## Thin Areas Needing Reinforcement
## Emergent Topics to Research
## Missed Options/Approaches
## Underperforming Connectors
## Source Count Gap
```
After the subagent returns, store via:
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'coverage-review' '{NNN}D/opus' "$AGENT_RESPONSE"
```

**Reviewer B — Sonnet subagent with WebSearch** (parallel with A and C):

Spawn a Sonnet subagent with WebSearch tool access:
```
You are a research coverage auditor with web access. This is a MANDATORY
expansion phase — your job is to find what's missing, not to confirm
things are fine.

Read the original research prompt and all findings below. Then use WebSearch
to actively hunt for what the research missed:
- Search for 'best [topic] alternatives 2026' — what options weren't covered?
- Search for recent developments (2025-2026) the findings don't mention
- Search for practitioner criticism of the approaches the research favors
- Search for adjacent topics that practitioners commonly consider alongside
  the main question

Original prompt: $(cat {research_folder}/deep_research_prompt.md)
Findings summary: [compressed key findings from each file]
Source count: [current total from tally]

Return your assessment as text in this format:
## Missing Options/Approaches (with URLs)
## Recent Developments Not Covered (with URLs)
## Adjacent Topics Worth Researching
## Thin Areas in Current Findings
## Source Gaps and Suggested Queries
```
After the subagent returns:
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'coverage-review' '{NNN}D/sonnet' "$AGENT_RESPONSE"
```

**Reviewer C — Codex** (parallel with A and B — uses reserved slot 5):
```json
{
  "mode": "review",
  "cwd": "<project-root>",
  "add_dirs": ["{research_folder}"],
  "prompt": "[assembled technical coverage audit prompt]",
  "timeout_sec": 300
}
```
The assembled coverage prompt asks Codex to identify missing libraries,
unverified technical claims, additional repos/docs/benchmarks, missing
comparison dimensions, emergent topics, and suggested connector queries.
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'coverage-review' '{NNN}D/codex' "$CODEX_FINAL_MESSAGE"
```

### Step 2: Addendum Creation

Spawn a DIFFERENT Opus subagent (not one that participated in Phase 2 or the
coverage review). This Opus is the impartial judge who synthesizes the three
reviews into a concrete research addendum.

```
You are the research addendum author. You have NOT participated in any prior
research or review — you are fresh eyes.

Read from the artifact DB:
1. {research_folder}/deep_research_prompt.md (original scope)
2. coverage-review/{NNN}D/opus
3. coverage-review/{NNN}D/sonnet
4. coverage-review/{NNN}D/codex
5. source-tally/{NNN}D

This is a MANDATORY expansion. Your job is to write the addendum, not to
decide if one is needed. There is ALWAYS an addendum in deep research.

Synthesize the three coverage reviews and create a prioritized expansion plan:

1. **Thin areas**: Which original sub-questions need more evidence? Assign
   reinforcement queries to specific connectors.

2. **Emergent topics**: Which new topics surfaced across multiple reviewers?
   These are the highest-signal additions — if 2/3 reviewers noticed the
   same gap, it's real.

3. **Missed options**: Well-known alternatives that weren't covered. These
   get full sub-question treatment.

4. **Source count**: If below 1000+, allocate additional query variations
   to the thinnest connectors.

Prioritize ruthlessly — the addendum should be focused, not a kitchen sink.
Rank by impact on the original research question.

Return the addendum as text. The orchestrator will store it via:
db_upsert 'meta-deep-research-execute' 'addendum' '{NNN}D' "$CONTENT"

Format:
# Deep Research Addendum — {NNN}D

## Synthesis of Coverage Reviews
[What all three reviewers agreed on vs. where they diverged]

## Reinforcement Targets
[Original sub-questions needing more evidence, with specific new queries]

## New Sub-Questions (from emergent topics)
[Numbered list — each with: question, why it matters to the original
research question, which connectors to use]

## Missed Alternatives to Evaluate
[Options/approaches/tools that should have been in the original research]

## Source Count Plan
Current: [N] scanned | Target: 1000+
[Which tracks and connectors will close the gap]

## Worker Allocation
[Specific track (A/B/C/D) assignments and worker counts]
```

### Step 3: Addendum Research Cycle

The addendum ALWAYS produces additional research. Execute it:

1. **Update the dispatch table.** Read the existing dispatch table from the DB
   (`db_read 'meta-deep-research-execute' 'dispatch-table' '{NNN}D'`), append
   addendum topics with `[ADDENDUM]` tags, then upsert back.

2. **Dispatch additional workers.** Follow the same Phase 2 pattern but ONLY
   for the addendum topics. Use the worker allocation from the addendum.
   Store outputs in the artifact DB with `-addendum` suffix in the label:
   `research-connector` / `findings` / `{NNN}D/{descriptive-name}-addendum`

   All addendum connector subagents MUST follow the multi-query protocol and
   include Source Tally tables.

3. **Update source tally.** Re-aggregate all source tallies (original +
   addendum) from the DB (query all `research-connector` / `findings` /
   `{NNN}D/*`). Add an `## Addendum Sources` section showing the additional
   coverage. Upsert back to `meta-deep-research-execute` / `source-tally` /
   `{NNN}D`.

4. **Max 1 addendum cycle.** To prevent infinite loops, exactly ONE addendum
   cycle runs per deep research invocation. If coverage gaps remain after
   the addendum, note them in the final summary — but do not loop again.

## Phase 3: Cross-Model Debate (3 Rounds)

All debate files go in the artifact DB under
`meta-deep-research-execute` / `debate` / `{NNN}D/{stem}`.

**IMPORTANT**: The debate covers ALL findings — both original Phase 2 AND any
addendum findings. Position papers must reference addendum findings where
relevant.

Three "models" participate: **Opus** (Anthropic high reasoning), **Sonnet**
(Anthropic balanced + WebSearch), **Codex** (OpenAI technical).

### Round 1: Present (parallel)

Each model compiles its Phase 2 (+ addendum) findings into a position paper.

**Opus Position** (Opus subagent): Read all Track A output and reasoning-
type sub-questions (including addendum files). For each sub-question: state
claim, list evidence with citations, rate confidence (HIGH/MEDIUM/LOW),
flag gaps.

Output stored in artifact DB: `meta-deep-research-execute` / `debate` /
`{NNN}D/position-opus` (written by the orchestrator after the subagent returns).

**Sonnet Position** (Sonnet subagent with WebSearch): Read all Track B + D
output (connector sweep + web grounding). Same per sub-question format.
Where contradiction research disagrees with primary, present BOTH.

Stored: `meta-deep-research-execute` / `debate` / `{NNN}D/position-sonnet`.

**Codex Position** (Codex MCP `review` mode):
```json
{
  "mode": "review",
  "cwd": "<project-root>",
  "prompt": "Read the Codex research findings (from artifact DB labels {NNN}D/* under research-connector/findings, specifically the codex-authored ones). Compile a position paper. Per sub-question: claim, evidence, confidence, gaps. If primary and devil's advocate conflict, present BOTH.",
  "timeout_sec": 300
}
```
Store the final message:
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/position-codex' "$CODEX_FINAL_MESSAGE"
```

### Round 2: Challenge (parallel, adversarial)

Each model reads the OTHER two models' positions and attacks them.

**Opus challenges Sonnet + Codex** (Opus subagent):
Read `position-sonnet` and `position-codex` from DB. Challenge: insufficient
evidence, wrong/outdated technical details, contradictions between them,
missing perspectives, hallucinated claims.
Stored: `meta-deep-research-execute` / `debate` / `{NNN}D/challenge-opus`.

**Sonnet challenges Opus + Codex** (Sonnet subagent with WebSearch):
Same task with web-grounded fact-checking — Sonnet can run fresh WebSearch
queries to verify or dispute claims with current sources.
Stored: `meta-deep-research-execute` / `debate` / `{NNN}D/challenge-sonnet`.

**Codex challenges Opus + Sonnet** (Codex MCP `debate` mode):
```bash
source artifacts/db.sh
OPUS_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-opus')
SONNET_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-sonnet')
```
Then call `mcp__codex-mcp__codex_run`:
```json
{
  "mode": "debate",
  "cwd": "<project-root>",
  "prompt": "You are a technical fact-checker. Challenge these position papers:\nOpus: <OPUS_POS>\nSonnet: <SONNET_POS>\n\nFocus on: wrong library claims, unsourced performance claims, incorrect API behavior, architecture that won't scale.",
  "timeout_sec": 300
}
```
Store:
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-codex' "$CODEX_FINAL_MESSAGE"
```

### Round 3: Respond + Converge (parallel)

Each model reads challenges against its position and responds with one of:
- **Concede**: "Valid. Updating position to [new position]."
- **Rebut**: "Original claim stands because [additional evidence]."
- **Escalate**: "Insufficient evidence either way. Flagging as unresolved."

**Opus responds** (Opus subagent): reads challenges from DB (`{NNN}D/challenge-sonnet`
and `{NNN}D/challenge-codex`). Stores output in artifact DB:
`meta-deep-research-execute` / `debate` / `{NNN}D/response-opus`.

**Sonnet responds** (Sonnet subagent with WebSearch): same task, with the
ability to run fresh WebSearch queries to back rebuttals with new evidence.
Stored: `meta-deep-research-execute` / `debate` / `{NNN}D/response-sonnet`.

**Codex responds** (Codex MCP `debate` mode):
```bash
source artifacts/db.sh
CODEX_POS=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/position-codex')
OPUS_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-opus')
SONNET_CHAL=$(db_read 'meta-deep-research-execute' 'debate' '{NNN}D/challenge-sonnet')
```
Then call `mcp__codex-mcp__codex_run`:
```json
{
  "mode": "debate",
  "cwd": "<project-root>",
  "prompt": "Read challenges against your position and respond per claim: CONCEDE / REBUT / ESCALATE with evidence.\n\nYour position: <CODEX_POS>\nOpus's challenges: [extract Codex-targeted from <OPUS_CHAL>]\nSonnet's challenges: [extract Codex-targeted from <SONNET_CHAL>]",
  "timeout_sec": 300
}
```
Store:
```bash
source artifacts/db.sh && db_upsert 'meta-deep-research-execute' 'debate' '{NNN}D/response-codex' "$CODEX_FINAL_MESSAGE"
```

## Phase 4: Convergence Scoring

Read ALL 9 debate files. Score every major claim using extended thinking.

**Confidence levels by debate outcome:**

| Outcome | Confidence | Meaning |
|---|---|---|
| 3/3 agree after debate | **VERIFIED** | Highest trust |
| 2/3 agree, 1 conceded | **HIGH** | Debate resolved |
| 2/3 agree, 1 rebutted with evidence | **CONTESTED** | Majority + documented dissent |
| All 3 hold different positions | **UNCERTAIN** | Present all, flag for human |
| Claim challenged, no model could rebut | **DEBUNKED** | Hallucination caught |
| All 3 escalated | **UNRESOLVED** | Honest evidence gap |

**Rules:**
- VERIFIED -> report as facts
- HIGH -> report with concession note
- CONTESTED -> report BOTH sides, let user decide
- UNCERTAIN -> "Open Questions" section
- DEBUNKED -> debate trail only
- UNRESOLVED -> "Gaps" section with follow-up suggestions

**Source quality weighting:**
Academic papers > official docs > engineering blogs > forums > LLM inference.
2025-2026 sources weighted higher for fast-moving fields. First-hand experience
(case studies, postmortems) weighted higher than theory.

Store scoring results in the artifact DB:
```bash
source artifacts/db.sh
db_upsert 'meta-deep-research-execute' 'convergence-scoring' '{NNN}D' "$SCORING_CONTENT"
```

## Phase 5: Write Summary

Write the final summary to `artifacts/research/summary/{NNN}D-{topic-slug}.md`.
Create `artifacts/research/summary/` if it doesn't exist. This is the only
file output — all intermediate artifacts are in the artifact DB.

**Summary structure (300-500 lines):**

```markdown
# Deep Research: {Topic}

> Research folder: research/{NNN}D/
> Date: {DATE}
> Models: Opus 4.7 (orchestrator + reasoning), Sonnet 4.6 ({N} subagents),
>   Codex gpt-5.3 ({N} workers)
> MCP connectors used: {LIST}
> Debate rounds: 3
> Addendum cycle: [yes — {reason} | no]
> Sources: {N} queries | {N} scanned | {N} cited
> Claims: {N} verified, {N} high, {N} contested, {N} debunked

## Executive Summary

[10-15 bullets — highest-confidence findings only. Each states the claim,
its confidence level, and model agreement.]

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | [question] | VERIFIED | 3/3 | [one-line answer] |
| 2 | [question] | CONTESTED | 2/3 | [majority position] |

## Detailed Findings

### SQ-1: [Sub-Question]

**Confidence**: VERIFIED / HIGH / CONTESTED / UNCERTAIN / UNRESOLVED
**Agreement**: Which models agree, which dissent

**Finding**: [synthesized answer]

**Evidence**:
- Opus: [evidence with citations]
- Sonnet: [evidence with citations + URLs]
- Codex: [evidence with citations]

**Debate**: [how the claim evolved through 3 rounds]

[Repeat per sub-question]

## Addendum Findings

[If an addendum cycle ran, summarize what it added. Reference the coverage
review that triggered it and the new evidence gathered.]

### Emergent Topic: [Name]
**Why it surfaced**: [which connector/worker found it]
**Finding**: [what we learned]
**Impact on original question**: [how this changes the answer]

## Contested Findings

[Claims where models disagreed after debate. Present BOTH sides.]

### [Contested Claim]
**Majority** ({models}): [claim + evidence]
**Dissent** ({model}): [counter-claim + evidence]
**Impact**: [why this matters for the user's decision]

## Open Questions

[UNCERTAIN or UNRESOLVED claims. Include suggested follow-up.]

## Debunked Claims

[Claims confidently stated in Round 1 that didn't survive challenge.
These are the hallucinations caught by debate.]

## Source Index

### Academic Sources
[Papers from Consensus, Scholar Gateway, PubMed]

### Official Documentation
[From Context7, MS Learn, GitHub]

### Web Sources
[From Sonnet WebSearch subagents — with URLs]

### Code Evidence
[From Codex, GitHub search]

### Source Tally
[Final aggregate from artifact DB (meta-deep-research-execute / source-tally / {NNN}D) — queries, scanned, cited by track]

## Methodology

[Brief: worker allocation, debate structure, confidence scoring,
whether addendum cycle ran and why.
Intermediate artifacts available in artifact DB under
`meta-deep-research-execute` and `research-connector` skills, all labels
prefixed with `{NNN}D/`.]
```

## Phase 6: Report Completion

After writing the summary, report back to the dispatching Claude with ONLY:
- The summary file path
- Source tally: {N} queries | {N} scanned | {N} cited
- Claim counts: verified / high / contested / debunked
- Whether an addendum cycle ran (and what it added)
- Any CONTESTED findings needing human judgment (one line each)

Keep the report-back minimal — the dispatcher reads the full summary itself.

## Error Handling

- **Codex unavailable**: Redistribute to Sonnet subagents only after a hard
  broker/config error or a real Codex task failure/timeout. Debate becomes
  2-model (Opus + Sonnet). Note "Codex unavailable" in methodology.
- **WebSearch unavailable**: Track D Sonnet subagents do inference-only
  synthesis from training data. Flag findings as "inference-only, no fresh
  sources."
- **Subagent failure**: Note the gap. Mark affected claims as UNCERTAIN.
- **Debate timeout**: Proceed with available responses. 2-model debate is
  still better than none.
- **Coverage review failure**: If any reviewer fails in Phase 2.5, proceed
  with available reviews. The addendum author works with whatever reviews
  completed. If ALL reviewers fail, write a minimal addendum targeting only
  source count gaps and proceed to debate.
- **Addendum cycle**: Exactly 1 cycle, mandatory. If coverage gaps remain
  after the addendum, note them in the summary but do not loop again.

## Concurrency Limits (HARD CONSTRAINTS)

These limits reflect the user's actual subscription/platform caps:

| Worker Type | Max Concurrent | Allocation |
|---|---|---|
| **Codex MCP** | **5 jobs** | 4 Phase 2 workers + 1 reserved for Phase 2.5/3 |
| **Sonnet subagents** | no hard limit | Tracks B + D + Phase 2.5 review + debate rounds |
| **Opus subagents** | no hard limit | Track A + coverage review + addendum author + debate rounds |

**Rules:**
- NEVER exceed the Codex 5-slot limit. If a phase needs more, run sequentially.
- Track C (Codex) workers 1-4 must fully complete before Phase 2.5 Codex reviewer starts.
- Debate rounds (1 Codex job per round across 3 rounds) reuse the same Codex slot sequentially.

## Cost Awareness

This skill is expensive. ~17 workers + mandatory coverage expansion + addendum
workers + 3 debate rounds.

- Opus subagents: 2-3 x ~100K tokens each (Phase 2) + 1 coverage reviewer
  + 1 addendum author + 2 debate roles = up to 7 Opus subagents
- Sonnet subagents: 10-12 x ~50K tokens each (Tracks B + D + coverage + debate)
- Codex workers: up to 4 concurrent in Phase 2 (of 5 max) + 1 reserved for
  coverage and each debate round

Reserve for decisions where being wrong costs more than the research.
