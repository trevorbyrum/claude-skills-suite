# SAST Pre-Scan

Deterministic, machine-verified findings injected into every lens prompt at `/review` Phase 1.5. SAST tools are dumb but reliable — they catch the unambiguous stuff before LLM reviewers see the diff. Lens reviewers then cross-reference SAST findings (confirm, dispute, or expand).

This skill suite is designed to run with **only locally-available tooling** — no external SAST services, no MCP-based scanners. Everything below uses standard CLI tools the user can install with their package manager.

## Tools run in parallel

All four steps run simultaneously — no inter-dependencies. Each tool is independently skippable if not installed.

### Step 1: Secret scan (always run if available)

```bash
gitleaks detect --source <project-root> --no-git --report-format json 2>/dev/null > /tmp/sast-gitleaks.json
```

Gitleaks is the highest-priority scanner — secrets in code are CRITICAL regardless of language. If `gitleaks` isn't on PATH, suggest `brew install gitleaks` (or `apt install gitleaks` / `cargo install gitleaks`) in the synthesis but continue without it.

### Step 2: JavaScript / TypeScript linters

Detect via `package.json` or `tsconfig.json` at the project root:

```bash
npx --no-install biome lint --reporter=json <project-root> 2>/dev/null > /tmp/sast-biome.json
npx --no-install oxlint <project-root> 2>/dev/null > /tmp/sast-oxlint.txt
```

Use `--no-install` so the scan fails fast if the tool isn't already in `node_modules` — don't pull npm packages just to scan.

### Step 3: Python linter

Detect via `pyproject.toml`, `setup.py`, or `requirements.txt`:

```bash
ruff check --output-format=json <project-root> 2>/dev/null > /tmp/sast-ruff.json
```

### Step 4: Rust linter

Detect via `Cargo.toml`:

```bash
cargo clippy --message-format=json --quiet 2>/dev/null > /tmp/sast-clippy.json
```

### Step 5: Semantic SAST (Semgrep)

The heavier cross-language pass — runs on any project, no language detection needed. Semgrep's engine is
in-process (no server), so it's safe to run locally:

```bash
semgrep --config auto --json --quiet <project-root> 2>/dev/null > /tmp/sast-semgrep.json
```

`--config auto` pulls the registry's default ruleset for the languages present. Keep ERROR/WARNING
severities; drop INFO. If `semgrep` isn't on PATH, note it and continue (install via `installer/bootstrap.sh`).

### Step 6: Vulnerability / IaC / secret scan (Trivy)

Catches dependency CVEs, IaC misconfigurations, and a second secret pass:

```bash
trivy fs --scanners vuln,misconfig,secret --format json --quiet <project-root> 2>/dev/null > /tmp/sast-trivy.json
```

Keep CRITICAL/HIGH. Trivy's secret findings reinforce gitleaks (treat as CRITICAL). If `trivy` isn't on
PATH, note it and continue.

### Step 7: Assemble `$SAST_SUMMARY`

Collect all results into a single string formatted like:

```markdown
## SAST Pre-Scan Results

### Gitleaks (N secrets detected)
- [CRITICAL] secret-type: file:line (rule-id) — block deploy
...

### Linters (N findings)
- [HIGH] biome lint/correctness/X: file:line — message
- [HIGH] oxlint correctness/X: file:line — message
- [HIGH] ruff E501: file:line — line too long
- [HIGH] clippy::needless_collect: file:line — message
...

### Semgrep (N findings)
- [ERROR] rule-id: file:line — message
...

### Trivy (N findings)
- [CRITICAL] CVE-XXXX-YYYY: package@version — fixed in Z
- [HIGH] misconfig AVD-XXX: file:line — message
...
```

Truncate to ~5000 chars max. Keep HIGH/CRITICAL (Semgrep ERROR, Trivy CRITICAL/HIGH). Drop INFO/LOW. Gitleaks + Trivy secret findings are always top priority — never truncate them.

If ALL SAST tools were unavailable, note "SAST pre-scan: no tools available — install gitleaks at minimum" and proceed. Lens reviews still run regardless.

## Injection into lens prompts

The `$SAST_SUMMARY` string is included verbatim in every Sonnet lens subagent prompt (per `agents/review-lens.md` template). Lens reviewers cross-reference:

- **Confirm** — lens also caught it: include in findings with `also-flagged-by: gitleaks/biome/oxlint/ruff/clippy/semgrep/trivy`
- **Dispute** — lens disagrees (false positive): note explicitly with rationale
- **Expand** — lens found related patterns: broader finding

## Synthesis priority

In the final synthesis (`/review` Phase 5):

- Gitleaks secrets findings: **always top priority**, ahead of LLM findings
- Linter HIGH: peer to LLM HIGH
- Lens findings confirming SAST: HIGH confidence regardless of lens count

This is what gives `/review` its "machine-verified backbone" — LLM reviews are anchored by deterministic SAST agreement.
