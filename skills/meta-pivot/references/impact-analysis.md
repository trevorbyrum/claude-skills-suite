
# Impact Analysis

## Purpose

Determine what can be safely removed from a project by building a dependency graph, tracing
reachability from all entry points, and computing the blast radius for every removal candidate
across both internal and external consumers. Merge dead-code detection, orphan analysis, and
doc-code divergence into a ranked candidate list.

## Inputs

- Updated `project-context.md`, `project-plan.md`, `features.md` (post context rewrite)
- Full codebase
- Artifact DB (`artifacts/project.db`) for output

## Outputs

- `db_upsert 'impact-analysis' 'candidates' 'latest' "$CONTENT"` — ranked removal candidate list
- `db_upsert 'impact-analysis' 'dep-graph' 'latest' "$CONTENT"` — dependency graph summary

See candidate schema in §9.

## Instructions

### 1. Detect Language(s)

Scan the project root for language indicators:

- **JS/TS**: `package.json`, `tsconfig.json`, `.js`/`.ts`/`.jsx`/`.tsx` files
- **Python**: `pyproject.toml`, `setup.py`, `requirements.txt`, `.py` files
- **Go**: `go.mod`, `.go` files
- **Rust**: `Cargo.toml`, `.rs` files
- **Java/Kotlin**: `pom.xml`, `build.gradle`, `.java`/`.kt` files

Multiple languages may coexist — process each independently. If no manifest exists, fall back to
extension census:

```bash
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.rs" \) \
  | sed 's|.*\.||' | sort | uniq -c | sort -rn > /tmp/ia-lang-census.txt
```

Exit condition: if no source files found, abort and report "no analyzable source files."

### 2. Build Dependency Graph

Read `references/tool-matrix.md` for per-language tool selection and confidence scoring.

Run language-specific tools first; fall back to grep-based import scanning if tools are
unavailable.

**JS/TS primary:**
```bash
GTIMEOUT="/opt/homebrew/bin/gtimeout"
$GTIMEOUT 120 npx dependency-cruiser --output-type json --no-config . \
  > /tmp/ia-depcruiser.json 2>/tmp/ia-depcruiser.err \
  || $GTIMEOUT 90 npx madge --json . > /tmp/ia-madge.json 2>/tmp/ia-madge.err
```

**Python primary:**
```bash
$GTIMEOUT 90 python -m vulture . --min-confidence 60 > /tmp/ia-vulture.txt 2>&1 || true
# Import graph via stdlib ast — no external tool required
python3 -c "
import ast, os, json, sys
graph = {}
for root, _, files in os.walk('.'):
    for f in files:
        if f.endswith('.py'):
            path = os.path.join(root, f)
            try:
                tree = ast.parse(open(path).read())
                imps = [n.names[0].name if isinstance(n, ast.Import)
                        else n.module or '' for n in ast.walk(tree)
                        if isinstance(n, (ast.Import, ast.ImportFrom))]
                graph[path] = imps
            except: pass
print(json.dumps(graph))
" > /tmp/ia-py-graph.json 2>/tmp/ia-py-graph.err
```

**Go primary:**
```bash
$GTIMEOUT 60 go list -json ./... > /tmp/ia-go-list.json 2>/tmp/ia-go-list.err
$GTIMEOUT 60 go vet ./... > /tmp/ia-go-vet.txt 2>&1 || true
```

**Rust primary:**
```bash
$GTIMEOUT 120 cargo udeps --output json > /tmp/ia-cargo-udeps.json 2>&1 || true
$GTIMEOUT 60 cargo tree --format "{p} {d}" > /tmp/ia-cargo-tree.txt 2>&1 || true
```

**Universal fallback** (run for any language or when primary tools fail):
```bash
grep -rn "^import\|^from\|require(" --include="*.{js,ts,py,go,rs}" . \
  > /tmp/ia-grep-imports.txt 2>/dev/null || true
```

Parse all tool outputs into a unified edge list: `{ source: "path/to/file", imports: ["path/to/dep"] }`.
Write merged graph to `/tmp/ia-graph.json`.

Exit condition: if all tools fail AND grep fallback returns 0 lines, report "dependency graph
unavailable — no import patterns found."

### 3. Detect Entry Points

Read `references/tool-matrix.md` §Entry-Point-Heuristics for per-language rules.

General heuristics (apply to all languages):
- Files named `main.*`, `index.*`, `app.*`, `server.*`, `cli.*`
- Executables listed in `package.json` `"bin"`, `pyproject.toml` `[scripts]`, `Cargo.toml` `[[bin]]`
- API route files (`routes/`, `handlers/`, `controllers/`, `views/`)
- Test runners (`*.test.*`, `*.spec.*`, `*_test.go`, `test_*.py`) — treat as separate entry set
- Exported symbols from library entrypoints (`index.ts`, `__init__.py`, `lib.rs`)

Collect entry points into `/tmp/ia-entries.json`.

### 4. Reachability Analysis

Starting from each detected entry point, perform a forward traversal of the import graph to
mark every transitively reachable module.

```
reachable = BFS/DFS from each entry point through import edges
unreachable = all_modules - reachable
```

Modules in `unreachable` are orphan candidates. Log reachable count, orphan count, and entry
point list.

If the graph is a single connected component (no orphans), log that finding and continue to §5
for dead-code tool signals.

### 5. Internal Blast Radius

For every module (reachable and orphaned), calculate the number of modules that directly or
transitively import it (reverse reachability = blast radius).

Classify:
- **leaf**: 0 dependents — lowest risk to remove
- **branch**: 1–5 dependents
- **trunk**: 6+ dependents — highest risk; flag for manual review

Produce `/tmp/ia-blast-internal.json`: `{ "module": "...", "class": "leaf|branch|trunk", "dependent_count": N, "dependents": [...] }`.

### 6. External Blast Radius

Read `references/external-scan.md` for exact commands, platform differences, and
access-denied handling.

Run the external scan checklist against the current project directory. Collect all positive
matches. Each match becomes an external reference entry: `{ location: "...", type: "...", snippet: "..." }`.

Write results to `/tmp/ia-blast-external.json`.

If a scan command is access-denied or times out, log a warning and continue — do NOT abort.

### 7. Dead Code Detection

Run available dead-code tools in parallel (respect driver skill invocation rules if delegating):

| Language | Tool | Command |
|---|---|---|
| JS/TS | knip | `$GTIMEOUT 120 npx knip --reporter json > /tmp/ia-knip.json 2>&1` |
| Python | vulture | already run in §2; parse `/tmp/ia-vulture.txt` |
| Go | go vet | already run in §2; parse `/tmp/ia-go-vet.txt` |
| Rust | cargo udeps | already run in §2; parse `/tmp/ia-cargo-udeps.json` |
| Compiler warnings | any | capture stderr from build runs if available |

Parse each tool's output into a list of flagged symbols/files with confidence per
`references/tool-matrix.md` §Confidence-Scoring.

### 8. Doc-Code Diff

Load project documentation:
```
project-context.md  →  extract: listed modules, services, components, features
features.md         →  extract: feature names, described capabilities
project-plan.md     →  extract: planned modules, phases, deliverables
```

For each doc-mentioned item, attempt to locate a corresponding file or symbol in the codebase
via glob (`**/item.*`, `**/*item*`) and symbol grep.

Read `references/tool-matrix.md` §Doc-Code-Diff-Algorithm for the full extraction and
classification logic.

Classify gaps:
- **code-not-in-docs**: Exists in codebase, not mentioned in any doc → potential dead feature
- **docs-not-in-code**: Mentioned in docs, absent from codebase → stale doc or planned-but-removed

Items in **docs-not-in-code** where `project-plan.md` marks the feature as "done" or "complete"
are especially strong removal candidates ("plan as deletion signal").

Config-as-code is included: scan Terraform (`.tf`), Docker (`Dockerfile`, `docker-compose.yml`),
and CI/CD (`.github/workflows/`, `.gitlab-ci.yml`) for references to missing files or removed
modules.

### 9. Merge, Deduplicate, and Rank

Combine all candidate signals:

| Source | Candidates from |
|---|---|
| `orphan` | unreachable modules from §4 |
| `dead-code` | tool-flagged unused symbols/files from §7 |
| `doc-diff` | code-not-in-docs items from §8 |
| `external` | modules with external-only refs (no internal users) |

Deduplicate by canonical file path. For each unique candidate, merge all signals. Assign
confidence per `references/tool-matrix.md` §Confidence-Scoring:
- **high**: 2+ independent tools agree, or static + runtime agreement
- **medium**: single static tool, or orphan + doc-diff agree
- **low**: grep/heuristic only, or doc-diff alone

Rank: leaf > branch > trunk within each confidence band. List trunk items last (highest blast
radius = highest risk).

Build two output records:

**candidates record:**
```
FILE/MODULE | SOURCE(S) | BLAST-CLASS | DEP-COUNT | EXTERNAL-REFS | CONFIDENCE
src/utils/legacy.ts | orphan,dead-code | leaf | 0 | none | high
src/api/v1/old-auth.ts | orphan | branch | 3 | .github/workflows/deploy.yml | medium
src/jobs/report-gen.py | doc-diff | trunk | 8 | crontab | low
```

**dep-graph record:**
```
Entry points: [list]
Total modules: N
Reachable: N
Orphaned: N
Cluster summary: [top 3 clusters by size]
Leaf/branch/trunk counts: N / N / N
```

Store both:
```bash
db_upsert 'impact-analysis' 'candidates' 'latest' "$CANDIDATES_CONTENT"
db_upsert 'impact-analysis' 'dep-graph' 'latest' "$GRAPH_CONTENT"
```

### 10. Report Summary

Output to the user:

- Language(s) detected and tools that ran successfully vs fell back
- Entry point count and reachability coverage percentage
- Candidate count by confidence band and blast class
- Top 5 highest-confidence leaf candidates (safe quick wins)
- Any trunk candidates (require manual review before removal)
- External dependency warnings (services, cron, CI that will break)
- Any doc-code gaps found (code-not-in-docs count, docs-not-in-code count)

## Examples

```
meta-pivot Opus subagent invokes this after context rewrite.
→ Detects JS/TS project, runs dependency-cruiser, traces from index.ts + route files,
  finds 12 orphaned modules (8 leaf, 3 branch, 1 trunk), runs knip, cross-refs
  project-context.md. Stores ranked candidates and dep-graph to DB.
```

```
Large Python monorepo, no manifest tools installed.
→ Falls back to AST-based import graph + vulture + grep. Marks all candidates as
  medium/low confidence. Reports tool gaps. Stores partial results with confidence
  downgrade noted.
```

```
Go service with systemd unit referencing project path.
→ External scan finds /etc/systemd/system/myapp.service referencing $(pwd)/bin/server.
  Candidate src/cmd/server/main.go gets external-ref = "systemd:myapp.service", blast
  class upgraded to trunk regardless of internal dependent count.
```

---

Before completing, read and follow `../../references/cross-cutting-rules.md`.
