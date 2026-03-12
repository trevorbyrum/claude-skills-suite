---
name: meta-review
description: Comprehensive multi-model project review across 8 lenses and 3 model families in parallel. Use for full project review, pre-deploy audit, or milestone quality gate. Not for single-lens reviews.
---

# meta-review

Meta-skill that runs SAST pre-scan (Semgrep, SonarQube, local CLIs), then
fans out 8 review lenses across 3 model families in parallel with SAST
context injected, then synthesizes into a unified report with confidence scoring.

## Architecture

Sonnet-primary with targeted Codex/Gemini spot-checks on key lenses.

```
                   +-- Semgrep MCP scan
                   +-- SonarQube MCP query (if project exists)
meta-review --> SAST pre-scan --+-- ruff / biome / oxlint / gitleaks (local CLIs)
                   |
                   v  $SAST_SUMMARY injected into all lens prompts
                   |
                   +-- counter-review ----[Sonnet | Gemini]
                   +-- security-review ---[Sonnet | Codex]
                   +-- test-review ------[Sonnet]
                   +-- refactor-review ---[Sonnet | Codex]       --> synthesis
                   +-- drift-review -----[Sonnet | Gemini]
                   +-- completeness-review -[Sonnet | Codex]
                   +-- compliance-review -[Sonnet]
```

Total: SAST pre-scan + **12 LLM reviews** (7 Sonnet + 3 Codex + 2 Gemini), then 1 synthesis pass.

**Model assignment rationale:**
- **Sonnet** (all 8): primary reviewer, full codebase access, no concurrency limit
- **Codex** (security, refactor, completeness): code-centric lenses where static analysis shines
- **Gemini** (counter, drift): architecture/strategy lenses that benefit from web grounding

## Inputs

| Input | Source | Required |
|---|---|---|
| Project root path | cwd or user prompt | Yes |
| project-context.md | Project root | Yes |
| features.md | Project root | Yes |
| project-plan.md | Project root | Recommended |
| Full codebase | Project root | Yes |

## Outputs

- 7 x 3 = 21 individual lens findings in the artifact DB (skill=`{lens}`, phase=`findings`, label=`sonnet`/`codex`/`gemini`)
- 1 unified synthesis on disk: `artifacts/reviews/review-synthesis.md`

## Instructions

### Phase 1: Preparation

1. Verify the project has the required inputs. If `project-context.md` or
   `features.md` is missing, stop and tell the user to create them first
   (run `/meta-init` or the individual atomic skills).

2. Create the `artifacts/reviews/` directory if it does not exist.

3. Check CLI availability for multi-model execution:
   ```bash
   CODEX=$(ls ~/.nvm/versions/node/*/bin/codex 2>/dev/null | sort -V | tail -1)
   test -x "$CODEX" || CODEX="/opt/homebrew/bin/codex"
   GTIMEOUT="/opt/homebrew/bin/gtimeout"; test -x "$GTIMEOUT" || GTIMEOUT="/opt/homebrew/bin/timeout"
   COPILOT="/opt/homebrew/bin/copilot"
   GEMINI="/Users/trevorbyrum/.npm-global/bin/gemini"
   test -x "$GEMINI" || GEMINI="/opt/homebrew/bin/gemini"
   test -x "$CODEX" && echo "codex: available" || echo "codex: unavailable"
   test -x "$GEMINI" && echo "gemini: available" || echo "gemini: unavailable"
   test -x "$COPILOT" && echo "copilot: available" || echo "copilot: unavailable"
   ```
   Note which models are available. Copilot is Gemini's fallback — if Gemini
   is unavailable or fails, retry with Copilot before skipping. Unavailable
   models are skipped — synthesis adjusts confidence scoring accordingly.

4. Identify the ~10 most important source files for Gemini context. These
   are typically: entry point, main config, core business logic files, auth
   module, database layer, and any file >200 lines. Write this file list —
   Gemini invocations will reference them via `@path/to/file`.

### Phase 1.5: SAST Pre-Scan

Run static analysis tools **before** LLM reviews. Results are injected as
context into every lens prompt so reviewers see real findings, not just vibes.

All 3 steps run in parallel (no dependencies between them):

#### Step 1: Semgrep MCP scan

Call the Semgrep MCP tool directly (Claude has access as a global MCP tool):
```
mcp__semgrep__scan_directory(path: "<project-root>")
```
Store the result. If the tool is unavailable, skip and note in synthesis.

#### Step 2: SonarQube MCP query

Check if the project has a SonarQube project key:
```
mcp__sonarqube__search_my_sonarqube_projects(q: "<project-name>")
```

If a project exists, pull HIGH/BLOCKER issues and security hotspots:
```
mcp__sonarqube__search_sonar_issues_in_projects(
  projects: ["<projectKey>"],
  severities: ["HIGH", "BLOCKER"],
  issueStatuses: ["OPEN"]
)
mcp__sonarqube__search_security_hotspots(projectKey: "<projectKey>")
```

If no SonarQube project exists, skip. Do NOT create one or run sonar-scanner
here — that's a separate setup step the user does ahead of time.

#### Step 3: Local SAST CLIs

Detect project language from file extensions, then run the applicable tools:

**TypeScript/JavaScript projects** (has `package.json` or `tsconfig.json`):
```bash
npx biome lint --reporter=json <project-root> 2>/dev/null > /tmp/sast-biome.json
npx oxlint <project-root> 2>/dev/null > /tmp/sast-oxlint.txt
```

**Python projects** (has `pyproject.toml`, `setup.py`, or `requirements.txt`):
```bash
ruff check --output-format=json <project-root> 2>/dev/null > /tmp/sast-ruff.json
```

**All projects** (secrets scan):
```bash
gitleaks detect --source <project-root> --no-git --report-format json 2>/dev/null > /tmp/sast-gitleaks.json
```

If a tool is not installed or fails, skip it and note in synthesis.

#### Step 4: Assemble SAST summary

Collect all results into a single `$SAST_SUMMARY` string. Format:

```markdown
## SAST Pre-Scan Results

### Semgrep (N findings)
- [severity] rule-id: message (file:line)
...

### SonarQube (N HIGH/BLOCKER issues, M security hotspots)
- [BLOCKER] S2189: 'stopped' is not modified in this loop (file:line)
- [CRITICAL] S3776: Cognitive Complexity 120 exceeds 15 (file:line)
...

### Local Tools
- biome: N issues
- oxlint: N issues
- ruff: N issues
- gitleaks: N secrets detected (CRITICAL — block deploy)
```

Truncate to ~5000 chars max — keep HIGH/BLOCKER/CRITICAL findings, drop
INFO/LOW. This summary is injected into every lens prompt in Phase 2.

If ALL SAST tools were unavailable or returned zero findings, note
"SAST pre-scan: no tools available or zero findings" and proceed — LLM
reviews still run regardless.

### Phase 2: Fan-Out (12 reviews total)

The 7 review lenses with their model assignments:

| Lens | Atomic Skill | Sonnet | Codex | Gemini |
|---|---|---|---|---|
| counter-review | `/counter-review` | YES | — | YES |
| security-review | `/security-review` | YES | YES | — |
| test-review | `/test-review` | YES | — | — |
| refactor-review | `/refactor-review` | YES | YES | — |
| drift-review | `/drift-review` | YES | — | YES |
| completeness-review | `/completeness-review` | YES | YES | — |
| compliance-review | `/compliance-review` | YES | — | — |

**Do NOT add lenses to Codex or Gemini beyond what is listed above.**
Sonnet covers all 7. Codex covers 3. Gemini covers 2. Total = 12 reviews.

---

#### Step 2a: Launch Sonnet subagents (all 7 at once — OK)

Spawn the `review-lens` agent (`subagent_type: "review-lens"`) for each lens.
All 7 can run simultaneously — Sonnet subagents have no concurrency limit.

Each agent:
1. Receives the lens name, the atomic skill's review instructions, AND the
   `$SAST_SUMMARY` from Phase 1.5 in the prompt
2. Has full codebase access via Claude tools
3. Uses standardized severity classification and output format
4. Cross-references SAST findings — confirms, disputes, or expands on them
5. Returns findings as text in its response — does NOT write to DB

**DB writes are the main thread's job.** When each subagent returns, the
main thread extracts the findings from the agent's response and writes
them to the artifact DB:
```bash
source artifacts/db.sh
db_upsert '{lens}' 'findings' 'sonnet' "$AGENT_RESPONSE"
```
Subagents do NOT have access to `artifacts/db.sh` or the project DB path.
Never rely on subagents to write to the DB — they will silently fail.

#### Step 2b: Launch Codex (3 lenses — all 3 at once)

Use the `/codex` skill for invocation syntax.

Launch exactly **3** Codex processes for: `security-review`, `refactor-review`,
`completeness-review`. All 3 fit within the 5-slot limit — no queuing needed.

Each Codex exec:
1. Receives a review prompt assembled from the atomic skill's instructions
   AND the `$SAST_SUMMARY` from Phase 1.5
2. Runs with `--sandbox read-only --ephemeral` and relevant source directories
   via `--add-dir`
3. Pipes output to a temp file, then stores in DB:
   ```bash
   $GTIMEOUT 120 "$CODEX" exec --ephemeral --sandbox read-only --skip-git-repo-check \
     -C <project-root> --add-dir <relevant-dir-1> --add-dir <relevant-dir-2> \
     -o /tmp/lens-codex-{lens}.md "LENS_PROMPT" 2>/dev/null
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'codex' "$(cat /tmp/lens-codex-{lens}.md)" && rm /tmp/lens-codex-{lens}.md
   ```

If Codex is unavailable, skip all Codex reviews and note it in synthesis.

#### Step 2c: Launch Gemini (2 lenses — both at once)

Use the `/gemini` skill for invocation syntax and environment safety.

Launch exactly **2** Gemini processes for: `counter-review`, `drift-review`.
Both fit within the 2-slot limit — no queuing needed.

Each Gemini invocation:
1. Receives a prompt file containing: the atomic skill's review instructions,
   the `$SAST_SUMMARY` from Phase 1.5, plus relevant code context via
   `@path/to/file` references (use the file list from Phase 1, max ~10 files)
2. Uses `codebase_investigator` sub-agent
3. Runs with `--agent codebase_investigator`, `$GTIMEOUT 60`, and `2>/dev/null`
4. Pipes output to a temp file, then stores in DB as label `gemini`:
   ```bash
   $GTIMEOUT 60 "$GEMINI" ... 2>/dev/null > /tmp/lens-gemini-{lens}.md
   source artifacts/db.sh && db_upsert '{lens}' 'findings' 'gemini' "$(cat /tmp/lens-gemini-{lens}.md)" && rm /tmp/lens-gemini-{lens}.md
   ```

If Gemini is unavailable or fails (timeout, empty output), **retry each
failed lens with Copilot** using the `/copilot` skill. Use the same prompt
and context, but adapt invocation syntax:
```bash
$GTIMEOUT 60 "$COPILOT" --allow-all-tools --no-ask-user --no-color --disable-builtin-mcps --add-dir <project-root> -s \
  -p "LENS_PROMPT" 2>/dev/null > /tmp/lens-copilot-{lens}.md
source artifacts/db.sh && db_upsert '{lens}' 'findings' 'copilot' "$(cat /tmp/lens-copilot-{lens}.md)" && rm /tmp/lens-copilot-{lens}.md
```
Store as label `copilot` — it counts the same as `gemini` for confidence
scoring. If both Gemini and Copilot fail, skip and note it in synthesis.

**Steps 2a, 2b, and 2c can all launch simultaneously** — there is no
queuing needed since counts are within limits (7 Sonnet, 3 Codex, 2 Gemini/Copilot).

---

### Phase 3: Wait for Completion

All 12 reviews must complete before synthesis begins:

- Sonnet: confirm all 7 subagents returned
- Codex: confirm 3/3 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'codex'` for security, refactor, completeness
- Gemini: confirm 2/2 via DB: `source artifacts/db.sh && db_exists '{lens}' 'findings' 'gemini'` for counter, drift

If any individual review fails (timeout, crash, empty output), note the
failure in synthesis but do not block on it. Partial data is better than no
data.

### Phase 4: Synthesis

After all reviews complete, read lens findings from the artifact DB. Each
lens has a different number of models — read only what was assigned:

```bash
source artifacts/db.sh
# All 7 lenses have Sonnet
SONNET=$(db_read '{lens}' 'findings' 'sonnet')
# security, refactor, completeness also have Codex
CODEX=$(db_read '{lens}' 'findings' 'codex')    # only for 3 lenses
# counter, drift also have Gemini
GEMINI=$(db_read '{lens}' 'findings' 'gemini')   # only for 2 lenses
```

Synthesize into `artifacts/reviews/review-synthesis.md` (this file STAYS on disk — it is the final output).

The synthesis document structure:

#### Confidence Scoring

Confidence depends on how many models reviewed that lens:

| Lens Coverage | Agreement | Confidence |
|---|---|---|
| 2-model lens (Sonnet + Codex/Gemini) | 2/2 agree | **HIGH** |
| 2-model lens | 1/2 flags it | **MEDIUM** |
| 1-model lens (Sonnet only) | Sonnet flags it | **MEDIUM** (no cross-validation) |

For findings that appear across multiple lenses (cross-lens patterns),
confidence is automatically HIGH regardless of per-lens model count.

#### Deduplication

Different models will find the same issue with different wording. Merge
duplicates into a single finding, noting which models flagged it.

#### Cross-Lens Patterns

Look for patterns that span multiple lenses:
- A security finding + a test finding about the same code = high-priority gap
- A drift finding + a completeness finding = likely a feature that was
  partially implemented and then abandoned
- A refactor finding + a counter-review finding = structural issue
  masquerading as multiple smaller problems

Flag cross-lens patterns explicitly — they are higher priority than any
single-lens finding.

#### Synthesis Document Structure

```markdown
# Review Synthesis

## Summary
- Total findings: N (after dedup)
- By confidence: HIGH: X, MEDIUM: Y
- SAST pre-scan: Semgrep (N), SonarQube (N), local tools (N) — or "skipped"
- Reviews completed: 12 (7 Sonnet + 3 Codex + 2 Gemini), note any failures
- Multi-model lenses: security, refactor, completeness (Codex), counter, drift (Gemini)

## SAST Findings (Pre-Scan)
[BLOCKER/CRITICAL findings from static analysis tools — these are machine-
verified, not LLM opinion. Gitleaks secrets findings are always top priority.]

## Cross-Lens Patterns
[Patterns that span multiple review lenses — highest priority items]

## HIGH Confidence Findings
[Findings flagged by all available models — sorted by severity]

## MEDIUM Confidence Findings
[Findings flagged by 2 of 3 models — sorted by severity]

## Notable LOW Confidence Findings
[Only CRITICAL/HIGH severity findings from a single model — may be
false positives but too important to ignore]

## Per-Lens Summary
[One-paragraph summary per lens with finding counts]

## Recommendations
[Prioritized action list: what to fix first, what can wait, what to ignore]
```

### Phase 5: Report

Present the synthesis to the user. Highlight:
- Total finding count and confidence distribution
- Top 3 highest-priority items (cross-lens patterns first)
- Whether any lenses found zero issues (suspicious — may indicate the
  review prompt was too narrow or the model hallucinated "all clear")

After presenting, suggest: **"Run `/review-fix` to implement approved fixes."**

## Error Handling

- If a model is unavailable, run with remaining models. Adjust confidence
  scoring denominators accordingly.
- If an entire lens fails across all models, flag it as "REVIEW FAILED" in
  synthesis and recommend the user run that lens manually.
- If the project is small (< 5 source files), warn the user that some lenses
  (refactor, compliance) may produce thin results — this is expected, not a
  failure.

## Examples

```
User: "Run a full review before we deploy."
Action: Verify inputs exist. Fan out all 7 lenses x 3 models in parallel.
        Wait for completion. Synthesize. Present prioritized findings.
```

```
User: "Project review — we just finished the MVP."
Action: Same full fan-out. Emphasize completeness-review and drift-review
        since MVP milestones are where planned vs. actual diverge most.
```

```
User: "Audit everything. I don't trust this codebase."
Action: Full review. Call out any lens where all 3 models agree there are
        CRITICAL issues — those are the trust-breakers to address first.
```

```
User: [After meta-init] "Run the review before I start building."
Action: Full review focused on the plan and context docs rather than code
        (since code doesn't exist yet). Counter-review, completeness-review,
        and drift-review are most relevant at this stage.
```

---

Before completing, read and follow `../references/cross-cutting-rules.md`.
