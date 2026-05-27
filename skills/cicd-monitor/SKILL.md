---
name: cicd-monitor
description: Monitor GitHub Actions runs, surface failures, propose fixes, remember past incidents. Invoke with /cicd-monitor or use when the user asks "did CI pass" or "what broke the deploy".
---

# cicd-monitor

Read-only CI/CD awareness skill. Watches GitHub Actions runs for the
current repo, surfaces failures with log excerpts and likely root causes,
and remembers past incidents so the same fix isn't rediscovered every
deploy.

**Research basis**: 014D §10 (Missing Capabilities). CI/CD awareness was
flagged as a missing capability alongside session memory. This skill is
session-scoped — for true cross-session incident memory, see the planned
Qdrant integration (Phase 5b in `artifacts/014D-deferred-discussion.md`).

## When to use

- "Did CI pass on my last push?"
- "What broke the deploy?"
- "Why is the build red on `main`?"
- After `/github-sync` if the user wants confirmation that CI cleared.
- Before opening a PR to surface failing checks proactively.

## When NOT to use

- For local lint / type-check / test runs — use the project's commands directly.
- For deploying — this skill is read-only. Use the project's deploy tooling.
- For an exhaustive review of historical runs — use `gh run list` and filter.

## Inputs

| Input | Source | Required |
|---|---|---|
| GitHub repo (owner/name) | `git remote get-url origin` or user prompt | Yes |
| Run identifier (optional) | User prompt ("last run", PR #, SHA) | No — defaults to latest |
| `gh` CLI authenticated | `gh auth status` | Yes (skill errors out if missing) |

## Outputs

- **Run summary** in artifact DB (skill=`cicd-monitor`, phase=`runs`, label=`{run-id}`)
- **Failure incident** entry per failed run (skill=`cicd-monitor`, phase=`incidents`, label=`{ISO-8601}`)
  containing: job name, step that failed, log excerpt (~50 lines), likely
  root cause, suggested fix
- **Inline summary** to the user (verdict, top failures, suggested action)

Append-only — use `db_write` for incidents so the history is preserved.

## Instructions

### Phase 1: Preflight [Inline]

1. Confirm `gh` is installed and authenticated:
   ```bash
   gh auth status >/dev/null 2>&1 || { echo "gh CLI not authenticated — run 'gh auth login'"; exit 1; }
   ```
2. Resolve the repo:
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
   ```
   If empty, ask the user for `owner/name`.

3. Resolve the target run:
   - User said "last run" or no qualifier → most recent run on current branch.
   - User gave PR number → most recent run for that PR's head.
   - User gave SHA → most recent run for that SHA.
   - User gave `main` or another branch → most recent run on that branch.

### Phase 2: Fetch Run Status [Inline]

```bash
# Get the run id + status + conclusion
gh run list --limit 1 --branch "$BRANCH" --json databaseId,status,conclusion,workflowName,headSha,createdAt
```

Three possible states:

- **status=`in_progress`** → report progress (which jobs running, ETA from
  workflow defaults), then stop. Optionally offer to wait via
  `gh run watch <id> --exit-status` (foreground; warn the user about block).
- **conclusion=`success`** → one-line confirmation; store the run in DB; exit.
- **conclusion=`failure`** or `cancelled` or `timed_out` → proceed to Phase 3.

### Phase 3: Failure Triage [Inline]

For a failed run:

1. List failing jobs:
   ```bash
   gh run view "$RUN_ID" --json jobs -q '.jobs[] | select(.conclusion=="failure") | {name, databaseId, steps: [.steps[] | select(.conclusion=="failure") | .name]}'
   ```
2. For each failing job, fetch the log of the failing step (clip to ~50
   lines around the error):
   ```bash
   gh run view --job "$JOB_ID" --log-failed 2>/dev/null | tail -100
   ```
3. Classify the failure type. Use this triage table (regex-first, then heuristic):

   | Pattern | Class | Suggested Fix |
   |---|---|---|
   | `npm ERR!` / `yarn error` / `pnpm ERR` | Dependency install | Check lockfile, node version, registry auth |
   | `Cannot find module` / `ModuleNotFoundError` | Missing dep | Add to `package.json` / `requirements.txt` |
   | `error TS\d+` / `error: type` | Type error | Run typecheck locally; fix the surfaced types |
   | `expect(...).toBe` / `AssertionError` / `FAIL` | Failing test | Run the test locally; fix the assertion or code |
   | `lint`/`eslint`/`ruff`/`biome` followed by `error` | Lint | Run the linter with `--fix`; commit |
   | `403`/`401`/`Bad credentials` | Auth/secrets | Check `secrets.*` references in workflow; rotate token |
   | `timeout` / `exceeded the maximum execution time` | Timeout | Raise job timeout or parallelize step |
   | `out of memory` / `Killed` / `137` | OOM | Larger runner, or split the job |
   | (none of the above) | Unknown | Surface log excerpt for human |

4. Cross-check for **repeat incidents**. Read the last 20 failure
   incidents from DB and look for matching patterns (same workflow + same
   failing step + similar log signature):
   ```bash
   source artifacts/db.sh
   db_read_all 'cicd-monitor' 'incidents' | tail -20
   ```
   If a match exists, surface the prior fix.

### Phase 4: Persist + Report [Inline]

1. Write the run summary:
   ```bash
   db_write 'cicd-monitor' 'runs' "$RUN_ID" "$(jq -n --arg s "$STATUS" --arg c "$CONCLUSION" --arg w "$WORKFLOW" --arg sha "$HEAD_SHA" '{status:$s, conclusion:$c, workflow:$w, head_sha:$sha}')"
   ```
2. For each failure, write an incident:
   ```bash
   TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   db_write 'cicd-monitor' 'incidents' "$TIMESTAMP" "$INCIDENT_CONTENT"
   ```
   `INCIDENT_CONTENT` includes: workflow, job, step, classification, log
   excerpt, suggested fix, and a `repeat_of: <prior_timestamp>` field if
   a match was found in Phase 3.

3. Report to the user:
   ```
   CI status for <repo> on <branch>: FAILURE (run #<RUN_ID>)

   Failed jobs:
   - <job-name> → step "<step>" failed
     Class: <classification>
     Log excerpt:
       <~10 line excerpt>
     Suggested fix: <fix>
     [Repeat of <prior timestamp> — same fix applied before]

   Workflow: <workflow-name>
   SHA: <short-sha>
   ```

### Phase 5: Optional Auto-Fix Offer [Inline]

For TRANSIENT classifications (lint, type error, missing dep) only, offer
to dispatch a fix:

> "Want me to attempt a fix? I can spawn Codex MCP to address the [lint /
> type / missing-dep] failure on a new branch and open a PR. Yes / No."

If yes:
- Spawn `mcp__codex-mcp__codex_run` with `mode: "generate"`, prompt
  containing the failure summary + the log excerpt + project-context
  conventions, `timeout_sec: 300`.
- After Codex completes, run the relevant local check (lint / typecheck
  / test) to verify the fix.
- On success, branch + commit + open PR via `gh pr create`.

For PERMANENT classifications (logic failures, auth issues, OOM) — do NOT
auto-fix. Surface and stop.

## Constraints

- **Read-only by default.** No `git push`, no `gh workflow run`, no
  `gh run rerun` unless explicitly requested. Phase 5 auto-fix is opt-in
  per invocation, never default.
- **Append-only DB writes.** Each run gets its own DB record. Each
  incident gets its own timestamped record. Never overwrite history.
- **gh auth is a hard requirement.** Skill aborts with a clear error if
  `gh auth status` fails. Do not silently fall back.
- **No polling loops in this skill.** If the user wants to wait for a
  run, surface `gh run watch <id> --exit-status` and let them run it
  (which blocks their terminal, not Claude's). For periodic checking,
  use `/loop /cicd-monitor` from the user side.
- **Log excerpts capped at ~50 lines.** Full logs stay on GitHub. The DB
  carries just enough to recognize repeats.
- **No secrets in stored content.** Before writing to DB, scan the log
  excerpt with `gitleaks --no-banner -p` and redact matches.

## Examples

```
User: /cicd-monitor
Action: Resolve current branch's latest run. If in-progress, report
        progress. If passed, confirm. If failed, triage, classify,
        check for repeats, store incident, report.
```

```
User: Did CI pass on the auth PR?
Action: Find the PR ("auth"), grab its head SHA, fetch the most recent
        run for that SHA. Report status. If failed, full triage.
```

```
User: Why does main keep failing?
Action: Pull last 5 runs on main, count failure types, surface the
        dominant class (e.g., "4 of 5 failed on the integration test
        suite — same step every time"). Read prior incidents from DB
        for the repeating signature; suggest the recurring fix.
```

```
User: CI is red — fix it
Action: Triage the failure. If transient (lint/type/missing-dep), offer
        Phase 5 auto-fix and proceed on confirmation. If permanent,
        surface the failure and recommend running the relevant skill
        (e.g., `/test-review` or `/security-review`).
```

---

Before completing, read and follow `references/cross-cutting-rules.md`.
