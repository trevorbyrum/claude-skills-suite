# Init — Sub-Project Mode

Partition a parent project into a focused sub-workspace. Use when the parent's scope is too broad and the user wants to work on one slice without the noise.

**Context-window strategy**: Non-interactive phases delegate to subagents. The discovery interview (Phase 2) stays inline. Each subagent reads its own instructions from `agents/` — never load reference files into main context unless explicitly needed.

## Phase chain

```
Detect Parent → Analyze Parent [Sonnet] → Discovery Interview → Scaffold [Sonnet] → Distill Architecture [Opus] → Generate Docs [Sonnet] → Transfer Research → Worktree Setup (opt-in) → Validate & Present
```

## Phase 0: Detect Parent Pattern

Before anything else, detect how the parent project configures Claude:

1. Check for `CLAUDE.md` in parent root
2. Check for `.claude/rules/*.md` or `rules/*.md` in parent root
3. Check for both

Store the result — the sub-project mirrors whichever pattern(s) the parent uses.

Also detect whether existing sub-projects exist (directories with their own `architecture.md` or `CLAUDE.md` inside the parent). If siblings exist, list them and warn about potential conflicts with shared parent dependencies.

Pre-calculate relative symlink paths from the sub-project directory back to the parent root. Pass these as explicit values to the scaffolder — do not delegate path math to the subagent.

Also detect:
- Does `AGENTS.md` exist? (copy target)
- Does `CLAUDE.md` exist? (copy target)
- Does `project-context.md` exist? (distillation source)
- Does `project-plan.md` exist? (scope reference)
- Does `features.md` exist? (feature reference)
- Does `architecture.md` exist? (architecture reference)
- What's in `.gitignore`? (inherit relevant patterns)

Find the parent's `project-context.md`. Check:

1. `../project-context.md` — the most common case (cwd is one level under the parent)
2. `git rev-parse --show-toplevel` — if cwd is inside a parent git repo
3. User-specified path — if the user says "this is a sub-project of /path/to/foo"

If the parent's context can't be located, ask the user. Don't proceed without it — a sub-project without a parent reference is just a normal greenfield/join.

Read the parent's `project-context.md` and `project-plan.md` (if any). Note key parent decisions and the parts that DON'T apply to this sub-project.

## Phase 1: Analyze Parent Project [Subagent]

Dispatch a Sonnet subagent to analyze the parent project. Read `agents/analyzer.md` for the prompt template — fill in placeholders before spawning.

The analyzer extracts:
- Dependency graph (imports, exports, module boundaries)
- Tech stack and framework versions
- API surface of modules relevant to the sub-project task
- Type definitions and shared interfaces
- Build/test/lint commands
- Coding conventions (from linting config, existing code patterns)
- Cross-cutting concerns (auth, logging, DB, design tokens)

The analyzer writes its findings to a temp file. Read the output when complete.

**Exit condition**: Analyzer output exists with dependency graph, API surface, and conventions extracted.

## Phase 2: Discovery Interview [Inline]

Show the analyzer's findings to the user, then ask up to 3 targeted questions to fill gaps automation cannot:

1. **What is the primary deliverable and merge-back timeline?**
   (Intent and constraints not inferrable from code)

2. **What must NOT be modified in the parent project?**
   (Tribal knowledge — frozen APIs, shared state, protected paths)

3. **What conventions apply locally but aren't enforced in code?**
   (Naming patterns, architectural decisions, team norms)

Skip questions the analyzer already answered. If the analyzer covered everything, skip the interview entirely and confirm with the user:
> "Automated analysis looks complete. Anything to add before I scaffold?"

**Exit condition**: User confirms the scope is clear.

## Phase 3: Scaffold Sub-Project [Subagent]

Dispatch a Sonnet subagent to create the sub-project directory structure. Read `agents/scaffolder.md` for the prompt template.

The scaffolder creates:

```
<sub-project>/
  artifacts/
    research/
      summary/
    reviews/
    compact/
  references/
  CLAUDE.md (or rules/, or both — mirrors parent)
  AGENTS.md (generated fresh for sub-project)
  .gitignore (inherited + sub-project additions)
  todo.md (fresh from template)
```

**Symlinked files** (always current, single source of truth):
- Linting configs (`.eslintrc`, `.prettierrc`, etc.) if they exist
- `.editorconfig` if it exists
- Design token files if they exist

**Generated fresh** (tailored to sub-project scope):
- `architecture.md` — Phase 4 handles this
- `build-plan.md` — Phase 5 handles this
- `features.md` — Phase 5 handles this
- `project-context.md` — lightweight, sub-project scoped
- `CLAUDE.md` / `rules/` — references sub-project docs, not parent
- `AGENTS.md` — agent-facing rules scoped to this sub-project
- `todo.md` — empty template

**Exit condition**: Directory structure exists. Symlinks verified. Fresh files created with template content.

## Phase 4: Distill Architecture [Subagent]

This is the critical phase. Dispatch an Opus subagent to generate `architecture.md`. Read `agents/distiller.md` for the prompt template.

The distiller receives:
- Analyzer output from Phase 1
- User answers from Phase 2
- Parent's `project-context.md`, `architecture.md`, and `project-plan.md`

It produces `architecture.md` with these 11 sections:

1. **Project Overview** — 1 paragraph: what this sub-project builds and why
2. **Tech Stack** — languages, frameworks, versions (from parent)
3. **Architecture** — relevant components and their relationships
4. **Directory Structure** — annotated tree of the sub-project
5. **API Surface** — interfaces, types, exported contracts from parent that this sub-project consumes or produces
6. **Cross-Cutting Concerns** — auth, logging, DB schema, design tokens — only what's relevant to this sub-project's scope
7. **Coding Conventions** — style rules with code examples (from parent). Includes a **Testing** subsection: test file structure, runner, mocking patterns, coverage expectations
8. **Commands** — build, test, lint with full flags (adapted for sub-project)
9. **Known Constraints** — performance, security, compatibility requirements
10. **Parent Dependencies** — explicit list of what this sub-project imports from the parent, with file paths and version constraints
11. **Parent Modifications** — explicit list of parent files this sub-project will modify (migrations, shared types, API endpoints), with the nature of each change. Empty if sub-project is purely additive

**Design principle**: This file must contain almost everything Claude needs to complete the sub-project build. Minimize trips back to the parent project. Think of it as a "context distillation" — 70-98% compression of the parent while preserving all information relevant to this scope.

**Exit condition**: `architecture.md` exists with all 11 sections populated. No placeholders, no "TBD", no "see parent project."

## Phase 5: Generate Project Docs [Subagent]

Dispatch a Sonnet subagent to generate the remaining project docs. Read `agents/doc-generator.md` for the prompt template.

Generate:
- **`build-plan.md`** — Sub-project specific. Phases, milestones, work units sized for the sub-project scope. Follow the same format as the parent's `project-plan.md` but scoped to this deliverable only.
- **`features.md`** — Sub-project feature set. What this sub-project delivers, acceptance criteria, status tracking.
- **`project-context.md`** — Lightweight context doc. Scope, constraints, decisions specific to this sub-project. References `architecture.md` for technical details rather than duplicating.
- **CLAUDE.md** (or rules/) — References sub-project docs. Points to `architecture.md`, `build-plan.md`, `features.md`, `AGENTS.md`.

**Exit condition**: All docs exist, internally consistent, no references to missing files.

## Phase 6: Transfer Research [Inline]

Check the parent's `artifacts/research/` for relevant prior research.

1. List all research summaries in `artifacts/research/summary/`
2. For each, read the title and executive summary
3. Present relevant ones to the user:
   > "Found {N} research summaries. These look relevant to the sub-project:
   > - 003D: Authentication patterns for microservices
   > - 005: WebSocket scaling strategies
   > Copy these to the sub-project? (y/n/pick)"
4. Copy selected summaries to `<sub-project>/artifacts/research/summary/`

**Exit condition**: Relevant research transferred (or none if not applicable).

## Phase 7: Worktree Setup [Inline, Opt-In]

If the user requests git isolation:

1. Create a git branch: `sub/<sub-project-name>`
2. Create a worktree: `git worktree add <sub-project-path> sub/<sub-project-name>`
3. Verify the worktree is functional

If not requested, the sub-project lives as a subdirectory in the main worktree. Present the option:
> "Sub-project is ready as a subdirectory. Want git isolation via worktree?
> (Recommended for parallel development or risky refactors)"

**Exit condition**: Worktree created if requested, or user confirmed subdirectory mode.

## Phase 8: Validation & Presentation [Inline]

Final checks:
1. All symlinks resolve correctly
2. All generated docs exist and have content
3. `architecture.md` has all 11 sections
4. `build-plan.md` has work units with acceptance criteria
5. No broken file references in CLAUDE.md / rules/
6. Sub-project can be `cd`'d into and Claude would have full context

Present the summary:
> "Sub-project `{name}` is ready at `{path}`.
>
> **Symlinked** (stays current): [linting configs]
> **Generated** (sub-project specific): architecture.md, build-plan.md,
>   features.md, project-context.md, CLAUDE.md, AGENTS.md
> **Research transferred**: [list or "none"]
> **Git isolation**: worktree on `sub/{name}` / subdirectory mode
>
> Next steps:
> 1. `cd {path}` and start building
> 2. Run `/execute` to implement the build plan
> 3. Run `/review` to review the sub-project docs first"

## Error Handling

- If parent has no `project-context.md`, warn and proceed — the analyzer and interview must compensate.
- If parent has no `architecture.md`, the distiller works from analyzer output and `project-context.md` alone.
- If symlink creation fails (Windows, permissions), fall back to copy with a warning: "Symlink failed — copied instead. This copy will NOT auto-update."
- If the analyzer subagent fails, fall back to the interview for all context gathering. Skip Phase 1 findings presentation.

## Eventual merge back

When the sub-project's work is done and ready to fold back into the parent: invoke `/init` again with a merge cue ("merge the sub-project back," "/init merge"). That routes to **`references/sub-project-merge.md`** — a full automated merge flow (scanner subagent → merge-plan generation → user approval gate → research renumbering with sub-project number remapping → DB merge with `sub:<name>/` namespace prefix → batch-tiered cleanup → archival).

The merge flow handles:

1. Reconciling completed WUs back into the parent's plan changelog
2. Renumbering research folders (preserving D suffix) so the sub-project's lineage joins the parent's
3. Moving sub-project's research synthesis into the parent's `artifacts/research/` folder
4. Archiving the sub-project's `artifacts/` directory (don't delete — audit trail)
5. Reconciling parent docs (features.md, project-plan.md, project-context.md)
6. Merging artifact DB records with namespace isolation

See `references/sub-project-merge.md` for the full protocol.

## Failure modes

- **Parent doesn't have `project-context.md`**: ask the user to run `/init join-existing` on the parent first. Sub-project mode requires the parent to be initialized.
- **Scope drift mid-init**: if the user's answers to Phase 2 boundary questions suggest this isn't really a sub-project (it's a sibling or a fork), surface the mismatch and offer to switch to greenfield or join-existing instead.
- **Parent + sub-project name collision**: warn explicitly. The sub-project's slug must be distinct from the parent's.
