# Optional Tier — 3 Lenses (User Opt-in)

These don't run in default-tier full review because most projects don't need them every pass. User opts in at `/review` entry, or invokes one directly with `/review ui` / `/review browser` / `/review breaking-change`.

For shared patterns, see `review-lens-framework.md`.

---

## ui-review

**Purpose**: Frontend UI quality from code inspection. Component composition, accessibility, design-system adherence.

**When to use**:
- Project has frontend files (`*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`)
- A UI feature was just shipped or refactored
- Accessibility audit needed

**Key checks**:
- Missing accessibility attributes (alt, aria-*, role) on interactive elements
- Color contrast violations (look for hex codes against background — flag obvious ones)
- Inconsistent spacing / sizing scales
- Components without TypeScript prop types or with `any`
- State management leaks (local state that should be lifted, or vice versa)
- Re-render hot spots (deep prop drilling, missing memoization on heavy components)

**Add field**: viewport / breakpoint the issue manifests at.

**Deep references** (Sonnet lens subagent reads on demand):
- `lenses/ui/design-a11y.md` — accessibility patterns (WCAG, ARIA, focus management)
- `lenses/ui/design-anti-patterns.md` — UI anti-patterns catalog
- `lenses/ui/design-colors.md` — color systems, contrast ratios
- `lenses/ui/design-typography.md` — type scales, font pairing
- `lenses/ui/design-tokens.css` — design-token reference (CSS variables for the suite)

**Not in default tier because**: backend-only projects (CLI tools, APIs, libraries) shouldn't pay for this lens.

---

## browser-review

**Purpose**: Live UI testing in a real browser via Playwright MCP. Catches the things ui-review can't see from code alone — actual rendering, timing, layout.

**When to use**:
- Project has a dev server that can be started
- ui-review surfaced visual concerns that need verification
- Pre-deploy smoke

**Key checks**:
- Page loads without console errors
- Critical user flows complete (login, checkout, etc.)
- Visible layout issues at multiple viewports
- Network requests succeed (no 404s, no infinite-spinner)
- Accessibility tree looks reasonable (real check via Playwright accessibility tools)

**Add field**: screenshot or text excerpt of the visible defect; `mcp__playwright__browser_take_screenshot` URL if hosted.

**Concurrency note**: Playwright MCP is single-instance — only one browser-review lens at a time across the suite.

**Not in default tier because**: requires the dev server up, takes minutes, only useful for actively-developed frontends.

---

## breaking-change-review

**Purpose**: Public API surface diff. Catches signature changes, removed exports, changed semantics on functions that users / other modules depend on.

**When to use**:
- Pre-release (cutting a new version)
- Refactor PR that touches public exports
- Library project (not internal app)

**Inputs**: `git diff` against the last release tag (or main), plus the codebase as it stands.

**Key checks**:
- Removed exports (function, class, type) — flag as BREAKING
- Changed function signatures (new required param, removed param, type narrowing of param)
- Changed return types (narrowing or replacing)
- Removed enum / const values
- Changed defaults that downstream behavior may depend on
- Renamed without deprecation alias

**Add field**: public API surface affected + caller count if known (grep `import.*<name>` across the codebase).

**Severity guide**:
- Removed public export still used downstream → CRITICAL
- Changed required signature → HIGH
- Changed default → MEDIUM (often missed)
- Removed unused export → LOW

**Not in default tier because**: only matters when the project has external consumers OR is between releases. Internal apps changing rapidly don't need this every review.

### §1. Determine Comparison Base

Identify what to diff against:

- If the user specifies a ref (tag, branch, commit), use it
- If the project has tags, use the most recent tag: `git describe --tags --abbrev=0`
- If on a feature branch, use the merge base: `git merge-base HEAD main`
- If nothing else, use `HEAD~10` as a rough window

Report the comparison base to the user before proceeding.

### §3. Dependency Breaking Changes (HIGH)

Check dependency version bumps for breaking changes:

- Any major version bumps (semver X.0.0)? These signal intentional breaking changes
- Read changelogs/release notes for major bumps to identify what broke
- Are peer dependency requirements still satisfied?
- Did a transitive dependency bump its major version?
- Were dependencies removed that downstream consumers might rely on?
- Did the minimum required runtime version change (Node.js, Python, Go)?

**Severity guide**:
- Removed public export still used downstream → CRITICAL
- Changed required signature → HIGH
- Changed default → MEDIUM (often missed)
- Removed unused export → LOW

### §4. Schema & Migration Changes (CRITICAL)

If the project has database migrations or schema files, check:

- Are there destructive migrations? (`DROP TABLE`, `DROP COLUMN`, `ALTER COLUMN` type change)
- Are migrations reversible? (Do down / rollback migrations exist?)
- Will migrations require downtime? (Large table `ALTER`s, index creation without `CONCURRENTLY`)
- Are schema changes backwards-compatible with the previous application version? (Critical for rolling deploys — the old app version must be able to run against the new schema while traffic shifts)
- Were foreign key constraints added that could fail on existing data?

**Decision rules**:

- `DROP TABLE` or `DROP COLUMN` in a migration without a corresponding down migration → CRITICAL
- `ALTER COLUMN … TYPE` without a casting expression → CRITICAL (data loss)
- `NOT NULL` constraint added without a default on a non-empty table → CRITICAL (deploy failure)
- `ADD COLUMN` with `NOT NULL` and no default → CRITICAL
- Migration with no down/rollback step → HIGH
- Migration that locks a table >1s on large tables (index without `CONCURRENTLY`, full-table `ALTER`) → HIGH
- Rolling-deploy incompatibility (old app code can't read the new schema) → CRITICAL; new app code can't read old schema rows → HIGH

**Finding format extension**: add `Category: Schema Migration` and sub-fields `Migration file: <path>` + `Operation: <DROP|ALTER|ADD CONSTRAINT|…>` + `Reversible: yes|no`.

### §5. Configuration & Environment Changes (HIGH)

Check for config changes that break existing deployments:

- New required environment variables without defaults
- Changed env var names or formats
- Changed config file schema (new required fields, removed fields)
- Changed Docker image entrypoint, CMD, or expected volumes
- Changed port numbers or bind addresses
- Changed feature flag names or defaults

### §5.5. Schema Drift Detection (CRITICAL, when `schema/` exists)

If the project has a `schema/` directory, run a focused drift check between the canonical schema and the code that references it. This catches the common failure mode where someone updates ORM models / type definitions / queries without updating the source of truth (or vice versa).

**This section runs in two cases**:

- The diff being reviewed touches anything under `schema/` (auto-trigger)
- The user explicitly requests a "schema drift" check

**Inputs for this section**:

- `schema/tables.sql` — authoritative table definitions
- `schema/migrations/` — applied migrations (read order: filename-numeric ascending)
- ORM models / type definitions / query call sites in `src/` (or equivalent)

**Procedure**:

1. **Parse `schema/tables.sql`** to extract the canonical set of:
   - Tables (name)
   - Columns (table, name, type, nullability, default)
   - Constraints (PK, FK, UNIQUE, CHECK)
   - Indexes
   Store the parsed set as the source-of-truth catalog for this run.

2. **Locate code-side schema references.** Scan for the patterns that describe a table or column from the application side:
   - **TypeScript/JS**: `interface User`, `type User`, Prisma `model User`, TypeORM `@Entity`, Drizzle `pgTable(...)`, knex `.table('users')`, raw SQL strings (`SELECT … FROM users`)
   - **Python**: SQLAlchemy `class User(Base)`, Django `class User(models.Model)`, dataclass annotations on DB DTOs, raw SQL strings
   - **Go**: GORM struct tags, sqlx struct tags, `db:"…"` tags, raw SQL
   - **Rust**: Diesel `table!`, sqlx query macros
   For each match, extract the implied table + columns the code uses.

3. **Diff code-side references against canonical catalog**:
   - **Code references column not in `tables.sql`** → CRITICAL drift. The code will fail at runtime against the real DB. List `file:line` + the bad column name.
   - **Code references table not in `tables.sql`** → CRITICAL drift. Same.
   - **Column nullability mismatch** (code declares NOT NULL but `tables.sql` says NULL, or vice versa) → HIGH drift. Will cause silent bugs.
   - **Column type mismatch** (code says `int`, `tables.sql` says `text`) → HIGH.
   - **Canonical column or table referenced by zero code** → MEDIUM (potential dead schema; may also be intentional for external consumers — flag, don't auto-recommend deletion).
   - **Migrations directory not monotonic** (gaps in numbering, duplicates) → HIGH drift (history corruption).
   - **Migration touches a table not in `tables.sql`** → CRITICAL drift (someone applied a migration but forgot to update the source of truth).

4. **Cross-reference with the current diff**. If the diff modifies `schema/tables.sql` but no code in this commit references the new shape (or vice versa), flag it. The two should change together.

**Finding format extension**: add `Category: Schema Drift` and `Drift type: Missing column | Missing table | Nullability mismatch | Type mismatch | Dead schema | Migration gap`.

### §6. Cross-Reference with Docs

If API documentation, READMEs, or migration guides exist:

- Are breaking changes documented?
- Is there a migration guide for consumers?
- Does the changelog mention the breaking changes?
- If using semver, does the version bump match the change severity? (Breaking change without major bump = violation)

### Summary Verdict

End with:

- Summary table of breaking changes by category and severity
- Semver recommendation: Is this a MAJOR, MINOR, or PATCH release?
- Migration guide draft (if CRITICAL findings exist)
- Rollback risk assessment: Can this be safely rolled back if it breaks production?
- Overall verdict: **BREAKING** (has CRITICALs — needs migration guide), **CAUTIOUS** (HIGHs — needs review), **COMPATIBLE** (no breaking changes detected)

**Draft migration guide if needed.**

---

## Picking the optional tier

At `/review` entry, the orchestrator asks via `AskUserQuestion`:

> "Run optional-tier lenses?
> - UI — frontend code quality
> - Browser — live UI test via Playwright
> - Breaking-change — public API diff
>
> Pick any that apply, or skip."

Multi-select. Each picked lens spawns one Sonnet subagent in Phase 3 alongside the default-tier 12.

Heuristics for the orchestrator to auto-suggest:
- Frontend files exist → suggest UI
- Dev server config present + browser MCP available → suggest browser only if user is pre-deploying
- `package.json` `version` is non-pre-release + recent tag → suggest breaking-change
