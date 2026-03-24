# Tool Matrix — Impact Analysis

Reference for SKILL.md §2, §3, §7, §8.

## Language → Tool Mapping

| Language | Graph Tool (primary) | Graph Tool (fallback) | Dead-Code Tool | Notes |
|---|---|---|---|---|
| JS/TS | dependency-cruiser (`npx depcruise`) | madge (`npx madge`) | knip (`npx knip`) | depcruiser preferred; madge is faster but less accurate for dynamic imports |
| Python | ast stdlib (built-in) | — | vulture (`python -m vulture`) | ast parse is zero-install; vulture --min-confidence 60 reduces noise |
| Go | `go list -json ./...` | `go vet ./...` | `go vet` compiler warnings | go list produces full import graph natively |
| Rust | `cargo tree` | `cargo udeps` | `cargo udeps` | udeps requires nightly; fall back to cargo tree + manual scan |
| Java/Kotlin | `mvn dependency:tree` / `gradle dependencies` | grep imports | compiler `-Xlint:unused` | maven/gradle produce structured output; pass `--quiet` to suppress noise |
| Universal fallback | `grep -rn "^import\|^from\|require("` | — | — | Use when no tools available; confidence = low |

## Confidence Scoring Rubric

| Score | Criteria | Examples |
|---|---|---|
| **high** | Two or more independent tools agree on the same file/symbol as unused OR static analysis agrees with a runtime signal (e.g., coverage data) | knip flags unused export AND dependency-cruiser shows no inbound edges AND vulture confirms |
| **high** | Single tool with zero-inbound-edges from entry point traversal (orphan) combined with dead-code tool confirmation | dependency-cruiser orphan + knip unused export |
| **medium** | Single static tool flags the candidate with no corroboration | knip alone, or vulture alone |
| **medium** | Orphan analysis (no inbound edges) without dead-code tool confirmation | reachability gap, no tool signal |
| **medium** | Doc-code diff agrees with one static tool | doc says "removed in v2" + knip flags export |
| **low** | Grep/heuristic only — import pattern scan without tool confirmation | fallback grep, no structured tool ran |
| **low** | Doc-code diff alone — code not mentioned in docs but tools found importers | documentation gap, may be intentional |
| **low** | Compiler warning without static graph confirmation | single -Xlint warning |

Confidence downgrades:
- If the graph was built from grep fallback only, cap all candidates at **medium**.
- If only one tool ran for a language, cap at **medium** regardless of signal count.
- If the project has <20 source files, apply a "small project" multiplier: treat medium as high
  (small projects rarely have orphans by accident).

## Doc-Code Diff Algorithm

Used in SKILL.md §8.

### Step 1: Extract Doc Mentions

For each document (`project-context.md`, `features.md`, `project-plan.md`):

1. Extract capitalized nouns, CamelCase identifiers, hyphenated-names, and `code-formatted` tokens
2. Normalize: lowercase, strip punctuation, de-duplicate
3. Mark items from `project-plan.md` that appear adjacent to "done", "complete", "removed",
   "deprecated", "deleted" — these are **deletion signals**

### Step 2: Locate in Codebase

For each doc-mentioned item `X`:
- Glob: `**/X.*`, `**/*X*.*`, `**/X/index.*`
- Grep: symbol definition patterns (`def X`, `class X`, `function X`, `export.*X`, `const X =`)
- Match is found if glob OR grep returns ≥1 result

### Step 3: Classify Gaps

| Classification | Condition | Action |
|---|---|---|
| `code-not-in-docs` | File/symbol exists in codebase, not found in any doc extract | Add as candidate, source=`doc-diff`, confidence=low (may be intentional) |
| `docs-not-in-code` | Doc mentions X, no file/symbol found | Flag as stale doc; if deletion signal, candidate confidence = medium |
| `plan-deletion-signal` | project-plan.md marks X as done/removed AND code still has X | Candidate confidence = high (plan intent overrides code presence) |

Config-as-code: run same algorithm against `.tf` files (resource names), `Dockerfile` (COPY targets,
RUN commands), `docker-compose.yml` (service names, volume mounts), CI YAML (job names, artifact
paths). Gaps where CI references a missing file = high confidence external dependency warning.

## Entry Point Detection Heuristics

| Language | Primary Heuristics | Secondary Heuristics |
|---|---|---|
| JS/TS | `package.json` `"main"`, `"exports"`, `"bin"` fields; files named `index.ts`, `app.ts`, `server.ts`, `cli.ts` | Next.js: `pages/_app.tsx`, `app/layout.tsx`; Vite: `src/main.ts` |
| Python | `pyproject.toml` `[project.scripts]`; files with `if __name__ == "__main__"`; `__init__.py` in top-level package | Django: `manage.py`, `wsgi.py`, `asgi.py`; FastAPI: `main.py` with `app = FastAPI()` |
| Go | `package main` files (all are entry points); `cmd/*/main.go` pattern | Lambda handlers, test files with `TestMain` |
| Rust | `[[bin]]` entries in `Cargo.toml`; `src/main.rs`; `src/lib.rs` (library root) | `examples/*.rs` treated as secondary entry points |
| Java/Kotlin | Classes with `public static void main(String[])` or `@SpringBootApplication` | `@RestController` files (treat as entry points for web projects) |
| Universal | Any file referenced by CI/CD as a build target or run command | Any file in `"scripts"` of a Makefile or Taskfile |

When multiple entry point detection methods disagree, take the union. Log all detected entry
points — over-inclusion is safer than under-inclusion for reachability analysis.
