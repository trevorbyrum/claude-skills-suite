---
name: release-prep
description: Automates release preparation — changelog generation, version bump, release notes, and git tag. Use when preparing a release, cutting a version, or shipping a milestone.
disable-model-invocation: true
---

# Release Prep

Generate a changelog from git history, bump the version, draft release notes,
and prepare a git tag. The user approves before the tag is actually created —
this skill does not push or publish without confirmation.

## Inputs

- **Current version** — read from `package.json`, `pyproject.toml`,
  `VERSION` file, or whatever the project uses for versioning. If no version
  file exists, ask the user for the current version.
- **Git log since last tag** — `git log $(git describe --tags --abbrev=0 2>/dev/null || echo "")..HEAD --oneline`

## Outputs

- `CHANGELOG.md` updated with new release section
- Version bumped in the project's version file
- Release notes drafted (printed to stdout for review)
- Git tag prepared (not pushed until user approves)

## Exit Condition

Changelog is updated, version is bumped in the source file, and the release
tag is staged. The skill ends by presenting the release notes and asking the
user to confirm before running `git tag` and `git push --tags`.

## Instructions

### 1. Determine Current Version

Search for the version in this priority order:
1. `package.json` — `"version": "x.y.z"`
2. `pyproject.toml` — `version = "x.y.z"`
3. `VERSION` file — raw semver string
4. `Cargo.toml` — `version = "x.y.z"`
5. Most recent git tag matching `v*`

If none found, ask the user. Do not guess.

### 2. Determine Version Bump

Analyze the changes since the last tag to recommend a bump level:

- **Major** (x.0.0) — breaking API changes, removed features, incompatible
  config changes
- **Minor** (0.x.0) — new features, new endpoints, new config options that
  are backward-compatible
- **Patch** (0.0.x) — bug fixes, performance improvements, documentation
  updates, dependency bumps

Present the recommendation to the user with reasoning. Wait for confirmation
or override before proceeding. The user may choose a different bump level.

### 3. Collect Changes

Gather change information from two sources:

**Git log**: Group commits by type using conventional commit prefixes where
present. For commits without prefixes, infer the category from the diff:

- **Added** — new features, new files, new endpoints
- **Changed** — modifications to existing behavior
- **Fixed** — bug fixes
- **Removed** — deleted features or deprecated code
- **Infrastructure** — CI/CD, Docker, deployment, dependency updates
- **Documentation** — docs-only changes

Use the full git log to understand the context and intent behind changes.
For commits with terse messages, inspect the diff to infer the user-facing
impact and write a meaningful changelog entry.

### 4. Update CHANGELOG.md

If `CHANGELOG.md` does not exist, create it with a header. Prepend (not
append) the new release section at the top of the file, below the header.
Format:

```markdown
## [x.y.z] - YYYY-MM-DD

### Added
- Description of feature (commit abc1234)

### Changed
- Description of change (commit def5678)

### Fixed
- Description of fix (commit 789abcd)

### Removed
- Description of removal

### Infrastructure
- Description of infra change

### Notes
- Key decision context from git log (commit context, PR descriptions, commit body)
```

Omit empty sections. Keep descriptions human-readable — rewrite terse commit
messages into complete sentences. One line per change; group related commits
into a single entry where appropriate.

### 5. Bump Version

Update the version string in the project's version file (same file
identified in step 1). For `package.json`, also update `package-lock.json`
if it exists (or note that `npm install` should be run).

### 6. Draft Release Notes

Produce a concise release summary suitable for a GitHub/GitLab release page
or a notification message. Structure:

```
# Release vX.Y.Z

**One-sentence summary of the release.**

## Highlights
- 2-4 bullet points covering the most important changes

## Breaking Changes
- (only if major bump; omit section otherwise)

## Full Changelog
See CHANGELOG.md for the complete list of changes.
```

Print the release notes to stdout. Do not write them to a file unless the
user asks.

### 7. Stage the Tag

Tell the user the exact commands that will be run:

```
git add CHANGELOG.md <version-file>
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

Ask for explicit confirmation before executing. If the user approves, run
the commands but do NOT push. Tell the user to push when ready:
`git push && git push --tags`.

### Automated Changelog (Codex)

Use Codex to generate a detailed changelog from git history:

1. Dispatch a Codex worker with `mcp__codex-mcp__codex_run`:
   ```json
   {
     "mode": "review",
     "cwd": "<project-root>",
     "prompt": "Analyze the git log since the last release tag. For each commit, categorize as: feat/fix/refactor/docs/chore. Group by category. Write a user-facing changelog in Keep a Changelog format. Include PR numbers if available. Summarize breaking changes separately.",
     "timeout_sec": 300
   }
   ```
2. If the MCP call succeeds, refine the final message based on git log context and human input.
3. If the MCP call fails, generate the changelog manually from git log.

### User-Facing Release Notes (Sonnet subagent)

After the changelog is drafted, generate user-friendly release notes:

1. Spawn a Sonnet subagent (`subagent_type: "general-purpose"`) with this
   prompt: `"Convert this technical changelog into user-friendly release
   notes. Focus on what users care about: new features, fixed bugs, breaking
   changes that require action. Skip internal refactors. Write in a friendly,
   professional tone. Changelog: [CHANGELOG_CONTENT]"`.
2. Present both the technical changelog and the user-facing notes for review.
3. If the Sonnet subagent fails, retry with Copilot — load `/copilot` for
   invocation syntax. Same prompt, 60s timeout.
4. If both fail, skip user-facing notes — the technical changelog is sufficient.

## Why Context Matters

Git history tells you *what* changed. Commit bodies, PR descriptions, and
broader diffs tell you *why*. A changelog that only lists one-line commit
summaries is a glorified `git log`. A changelog that includes intent and
decision context helps future maintainers understand the release.

## Examples

```
User: We just finished the auth overhaul. Prepare a release.
--> Read current version and git log since last tag. Recommend a minor bump
    (new feature, backward-compatible). Present changelog draft and release
    notes. Wait for approval before tagging.
```

```
User: Bump the patch version and update the changelog.
--> User has specified patch. Skip the recommendation step. Collect changes,
    update CHANGELOG.md, bump version, draft release notes, stage tag.
```

```
User: /release-prep major
--> User wants a major release. Collect changes, look specifically for
    breaking changes to highlight. Update CHANGELOG.md with a Breaking
    Changes section. Bump major version. Draft release notes with breaking
    changes prominently listed.
```

---

Before completing, read and follow `references/cross-cutting-rules.md`.
