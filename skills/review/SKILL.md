---
name: review
description: Multi-lens project review. Default tier runs 12 Sonnet lenses on the codebase in parallel. Optional tier adds UI / browser / breaking-change. Invoke with /review for a full pass, or "/review security" for a single lens.
disable-model-invocation: true
argument-hint: "[full | <lens-name>]"
---

# Review

> **YOUR ROLE: ORCHESTRATOR ONLY.** You dispatch Sonnet subagents; you do NOT read code and produce review findings inline. The lenses derive their value from being independent Sonnet workers running in parallel — if you do the review in the main thread, all of that collapses: lenses lose independence, context blows up, and the synthesis loses its multi-perspective signal.
>
> The ONLY work the main thread does is: Phase 1.5 SAST pre-scan (run scanners directly), Phase 3 **dispatch and wait**, Phase 5 synthesis from returned findings. If you catch yourself reading source files for the review itself in Phase 3, stop and dispatch the Agent.

Multi-lens code + plan review. Sonnet subagents run review lenses in parallel; the main thread aggregates findings into a synthesis at `artifacts/reviews/review-synthesis-N.md`.

Two paths share the orchestration:

- **Full** — 12 default-tier lenses in parallel; user can opt in to 3 optional-tier lenses
- **Single lens** — one named lens (`/review security`, `/review tests`, etc.)

## Inputs

| Input | Source | Required |
|---|---|---|
| `project-context.md` | Project root | Yes |
| `project-plan.md` | Project root | Recommended (for drift / completeness lenses) |
| `features.md` | Project root | Recommended |
| The full codebase | Project root | Yes |

## Outputs

- Per-lens findings: `db_upsert '<lens>' 'findings' 'lens' "$CONTENT"`
- Synthesis: `artifacts/reviews/review-synthesis-N.md` — never overwrites a prior synthesis; N is the next sequential integer

## Instructions

### Phase 0: Detect mode

| Trigger | Mode |
|---|---|
| `/review` (no args) | full default-tier |
| `/review full` or "full review" | full default-tier + ask about optional tier |
| `/review <lens-name>` | single lens (e.g., `/review security`, `/review tests`) |
| `/review --include browser` style | not supported (no flags) — user picks via `AskUserQuestion` |
| "review the auth code" or area-scoped | single lens that fits OR ask via `AskUserQuestion` which lens |

If ambiguous → `AskUserQuestion`: "Full pass (default 12 lenses), one lens, or full + optional tier (adds UI / browser / breaking-change)?"

Read the matching reference:
- Full or full+optional → `references/default-tier.md` (and `optional-tier.md` if applicable)
- Single lens → `references/default-tier.md` or `references/optional-tier.md` (whichever lists the named lens)

All lenses share patterns documented in `references/review-lens-framework.md`.

### Phase 1: Verify inputs

1. Confirm `project-context.md` exists. If missing, stop and tell the user to run `/init` first.
2. Create `artifacts/reviews/` if it doesn't exist.
3. Check fresh-findings cache (per framework Phase A): for each lens about to run, check `db_age_hours '<lens>' 'findings' 'lens'`. If <24h and unchanged, offer to reuse.

### Phase 1.5: SAST pre-scan

Read `references/sast-prescan.md` for the full protocol. Run local linters and scanners in parallel — `gitleaks` (secrets), the available language linters (`biome` / `oxlint` for JS/TS, `ruff` for Python, `cargo clippy` for Rust), plus the heavier cross-language scanners `semgrep` (semantic SAST) and `trivy` (dependency CVEs / IaC / secrets). Assemble `$SAST_SUMMARY` (≤5000 chars; keep CRITICAL/HIGH + all gitleaks/trivy-secret findings, drop INFO/LOW).

This summary is injected into every lens prompt at Phase 3 so Sonnet reviewers cross-reference real findings, not just impressions. Skip cleanly if any tool is unavailable — lens reviews still run regardless.

### Phase 3: Fan out lenses (Sonnet subagents)

**STOP — this is the dispatch phase. You spawn subagents; you do NOT review code yourself.**

For each lens in the chosen scope:

1. Spawn `Agent` with `subagent_type: "general-purpose"`.
2. Pass the lens prompt assembled from:
   - The lens spec (the lens's section in `references/default-tier.md` or `references/optional-tier.md`)
   - Deep references (when the spec lists them): paths under `references/lenses/<lens>/*.md` — pass these paths to the subagent and instruct it to read them on demand
   - `agents/review-lens.md` template (filled with lens name, scope, finding format)
   - **`$SAST_SUMMARY` from Phase 1.5** (machine-verified findings to cross-reference)
   - Project root + paths to inputs
3. No hard concurrency limit (Sonnet subagents are unbounded). Single-lens mode spawns one.
4. Subagents return findings as response text. The MAIN thread writes them to DB:
   ```bash
   db_upsert '<lens>' 'findings' 'lens' "$AGENT_RESPONSE"
   ```
   Subagents do NOT have access to `references/db.sh`. Per cross-cutting anti-pattern A2.

### Phase 4: Wait for completion

Confirm all subagents returned. If any failed (timeout, crash, empty), note in synthesis but don't block.

### Phase 5: Synthesis

Read findings from DB. Build a brand-new file `artifacts/reviews/review-synthesis-<N>.md` where N is the next integer (never overwrite a prior synthesis):

```bash
N=$(ls artifacts/reviews/review-synthesis-*.md 2>/dev/null | sed -E 's/.*-([0-9]+)\.md/\1/' | sort -n | tail -1)
NEXT=$(( ${N:-0} + 1 ))
```

Structure:

```markdown
# Review Synthesis <NEXT>

Generated: <date>
Project: <name>
Scope: <full default | full + optional | single lens: X>

## Summary
- Total findings: N (after dedup)
- By severity: CRITICAL: X, HIGH: Y, MEDIUM: Z, LOW: W
- SAST findings included: N (gitleaks/linters)
- Lenses run: <list>
- Lenses skipped (cached fresh): <list>
- Lenses failed: <list with reason>

## SAST Findings
[Pulled from Phase 1.5 $SAST_SUMMARY. Machine-verified secret scans + linter output.]

## Cross-Lens Patterns
[Patterns spanning >1 lens — highest priority]

## HIGH Confidence Findings
[Flagged by multiple lenses OR by SAST + a lens]

## MEDIUM Confidence Findings
[Flagged by one lens with strong evidence]

## Notable LOW Confidence Findings
[Single-lens findings at CRITICAL/HIGH severity — may be false positives but too important to drop]

## Per-Lens Summary
[One-paragraph per lens: finding count + headline issue]

## Recommendations
[Prioritized action list: fix first, fix later, ignore.]
```

### Phase 6: Present + handoff

Show the user:
- Total finding count + severity distribution
- Top 3 cross-lens patterns
- Lenses that found zero issues (suspicious — usually means prompt was too narrow or model "all-clear" hallucination)

Offer:

> "Review complete. {N} findings (CRITICAL: X, HIGH: Y). Run `/execute fix` to apply the prioritized fixes, or `/save` to snapshot and continue."

## References (on-demand)

- `references/review-lens-framework.md` — shared output pattern, fresh-findings check, severity tiers
- `references/default-tier.md` — 12 default lenses with per-lens checks + finding categories
- `references/optional-tier.md` — 3 optional lenses (UI, browser, breaking-change)

## Agent prompts (on-demand)

- `agents/review-lens.md` — Sonnet subagent prompt template (filled per lens)

## Examples

```
User: /review
→ Phase 0: full default-tier. Phase 1.5 runs gitleaks + linters.
  Phase 3 spawns 12 Sonnet subagents in parallel. Phase 4 waits. Phase 5
  writes review-synthesis-3.md. Phase 6 presents top items.
```

```
User: /review security
→ Single lens mode. Phase 3 spawns one Sonnet subagent for security-review.
  Synthesis still uses the standard template — just one lens populated.
```

```
User: full review + check the UI too
→ Full + optional UI. Phase 3 spawns 13 subagents (12 default + ui).
```

```
User: review the auth code
→ Phase 0 ambiguous, AskUserQuestion → user picks security + tests.
  Two-lens fan-out scoped to auth/ directory.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
