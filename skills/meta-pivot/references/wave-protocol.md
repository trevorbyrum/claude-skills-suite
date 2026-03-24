# Wave Protocol Reference

Supporting detail for `surgical-remove`. Read on demand when the SKILL.md instruction
references a specific section.

---

## Wave Ordering Rationale

Waves are ordered by the blast radius of a mistake, smallest first.

| Wave | Risk driver | Why this position |
|------|-------------|-------------------|
| 1 — Dead code | Zero dependencies, zero refs | Nothing can break. A false positive is the only risk — a file the analysis thought was unused but isn't. Discoverable immediately from test failures. |
| 2 — Orphaned modules | No inbound deps; has outbound | Removing the file is safe. Cleaning up its outbound import statements is mechanical — grep-confirmed, low error surface. |
| 3 — Deprecated features | Has inbound deps | Callers must be updated. Scope is bounded by the import graph. Characterization tests capture the contract before it disappears. |
| 4 — Restructuring | Live code, path/name changes | References scattered across the codebase. Old path strings can hide in config files, dynamic imports, string literals. Highest grep burden, highest re-test burden. Always last. |

Roll-forward order matters: if Wave 2 causes a problem, Wave 1 is already clean —
you rollback only Wave 2's branch, not the whole operation.

---

## Characterization Test Strategy

### When to generate

Generate characterization tests before removal when ALL of the following are true:
- Production mode is active (deploy indicators detected)
- The wave is 3 or 4 (code has dependencies or is live code)
- The file has at least one callable public function or exported class

Skip when:
- Pre-production shortcut is active
- Wave 1 or Wave 2 (no inbound callers, so nothing calls this code)
- File is pure config (no functions), pure type declarations, or pure re-exports
  with no logic

### What to capture

One test per public entry point is sufficient. Characterization tests are NOT
meant to be comprehensive — they record the current observable output so a
regression surfaces immediately after removal.

Pattern:
```
input: minimum valid arguments
assert: exact return value OR snapshot of output shape
```

For side-effectful functions (DB writes, HTTP calls), use the existing test
infrastructure's mock/stub layer — do not make real network or DB calls.

### Where to write them

`tests/characterization/wave-{N}/` — keep them isolated so they can be deleted
after the pivot is complete. Add a `# TODO: delete after pivot` comment in the
test file header.

---

## Pre-Production Detection Checklist

Check for deploy indicators by scanning the project root and common config locations.
**Any one match** = treat as production.

| Indicator | Check |
|-----------|-------|
| Docker with exposed port | `Dockerfile` exists AND contains `EXPOSE` |
| Docker Compose with deploy | `docker-compose.yml` contains `deploy:` or `replicas:` |
| CI/CD deploy stage | `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/config.yml` containing `deploy`, `publish`, `release`, or `push` in a job/stage name |
| Published package | `package.json` contains `"publishConfig"` or `"private": false`; `pyproject.toml` with `[tool.poetry] name` and no `private`; `Cargo.toml` without `publish = false` |
| Kubernetes manifests | Any `*.yaml` containing `kind: Deployment` or `kind: Service` |
| Heroku | `Procfile` exists |
| Terraform | Any `*.tf` file with a `resource` block referencing a cloud provider |
| Deploy scripts | `scripts/deploy.sh`, `deploy/`, `infra/`, or `Makefile` with a `deploy` target |

If none of these are present, pre-production shortcut applies.

---

## Rollback Decision Tree

When something goes wrong mid-wave, use this tree:

```
Tests failing?
├── YES: Are the failures in code touched by this wave?
│   ├── YES — Roll forward: the removal caused a real breakage.
│   │         Fix the breakage (patch call sites or revert specific file).
│   │         Re-run tests. If fixed, continue.
│   │         If unfixable in <30 min, rollback the wave.
│   └── NO  — Coincidental failure (pre-existing flaky test or unrelated regression).
│             Document the failure in the wave log.
│             Ask the user whether to continue or pause for investigation.
│             Do NOT auto-continue past a red test suite in production mode.
│
Tests passing but unexpected file references remain?
├── Wave 3: Grep found an importer you missed.
│   Add the cleanup to this wave, commit, re-verify.
└── Wave 4: Old path string still present in a config or test file.
    Find and update it. Do NOT commit with dangling references.

User requests rollback:
  Production:    git checkout {base} && git branch -D pivot/wave-{N}
  Pre-prod:      git checkout {base} && git branch -D pivot/removal
  Roll-forward preferred: only full rollback if >3 failures or structural
  breakage that cannot be patched atomically.
```

---

## Git Branch Naming and Merge Strategy

### Branch names

| Mode | Branch pattern |
|------|---------------|
| Production, per wave | `pivot/wave-1`, `pivot/wave-2`, `pivot/wave-3`, `pivot/wave-4` |
| Pre-production shortcut | `pivot/removal` |

Base branch: whatever branch was active when surgical-remove started. Do not
assume `main` — check with `git branch --show-current` before creating branches.

### Merge strategy

Always merge with `--no-ff` to preserve wave history in the base branch:

```bash
git checkout {base-branch}
git merge --no-ff pivot/wave-{N} -m "pivot: merge wave-{N} ({short description})"
```

Delete merged branches after merging to keep branch list clean:

```bash
git branch -d pivot/wave-{N}
```

Never squash-merge — wave commit history is the rollback audit trail.

---

## Mid-Wave Test Failure Protocol

1. Immediately capture the failure output: `npm test 2>&1 > /tmp/wave-{N}-failures.txt`
2. Identify failing test files. Check if they import or reference any file removed
   in this wave.
3. If YES (expected breakage): fix the call site in the test, re-run, continue.
4. If NO (unexpected breakage):
   - Do NOT auto-proceed in production mode.
   - Report to main thread: test name, failure message, file path.
   - Present two options: investigate + fix before continuing, or rollback the wave.
5. In pre-prod shortcut mode: unexpected failures follow the same protocol —
   still report and gate, even though there's no per-wave branch to rollback
   (rollback = `git reset --hard` to the commit before wave started).
