# Research Knowledge Base — Project Plan

> Last updated: 2026-03-28
> Status: planning
> Based on: project-context.md, 012D (research-accumulation-db, 183 cited), 013D (research-ingestion-pipeline, 153 cited)

## Executive Summary

Building a centralized PostgreSQL-based research knowledge base that accumulates
distilled findings AND individual source metadata across all projects and research
runs. Uses pgai Vectorizer for automatic embedding via Ollama, a Python ingestion
pipeline that syncs from the existing per-project SQLite artifact DB, and a 5-layer
dedup cascade for source normalization.

4 phases, 16 work units, 8 parallelizable. ~1,400 LOC across ~18 files. The system
ingests ~20-32 artifacts per deep research run at 5+ runs/week, producing a
compounding personal knowledge base with semantic search, cross-run queries, and
future local-model enrichment.

**Key risks**: pgai Vectorizer + Ollama performance untested at scale on this
homelab hardware. Apache AGE and pg_search deferred — if native PG FTS or SQL
JOINs prove insufficient, those extensions add complexity.

**CLI checks**: Codex and Gemini unavailable (timeout). Competitive landscape and
feasibility checks skipped. No competing products identified — this is a personal
knowledge accumulation system, not a market product.

## Directory Structure

```
research-kb/
  docker-compose.yml          # timescaledb-ha + pgai-vectorizer-worker + ollama
  sql/
    001-schema.sql             # 6 tables + indexes + constraints
    002-vectorizers.sql        # pgai vectorizer DDL for 3 tables
    003-queries.sql            # reusable cross-run query library
  src/
    __init__.py
    config.py                  # PG_URL, SQLITE_PATH, env var loading
    sqlite_reader.py           # read artifacts from project.db by run_id
    pg_writer.py               # insert into PG tables, transaction management
    source_extractor.py        # regex + structured section parsing for sources
    claim_parser.py            # parse confidence map + per-SQ findings
    dedup.py                   # 5-layer cascade: hash/DOI/URL/title/embedding
    enrichment.py              # OpenAlex + Semantic Scholar API enrichment
    queue.py                   # local file queue for PG failure retry
    sync.py                    # CLI entry point: orchestrates read/extract/write
    backfill.py                # one-time: parse 10 summary files into PG
  tests/
    test_source_extractor.py
    test_claim_parser.py
    test_dedup.py
    test_sync.py
  pyproject.toml               # dependencies: psycopg[binary], pyalex, etc.
```

## Phases and Milestones

### Phase 1: Database Foundation
- **Goal**: PG running with schema, pgai auto-embedding operational, Python project scaffolded
- **Milestone**: `SELECT count(*) FROM research_reports` returns 0, pgai vectorizer status shows "active", `python -m research_kb.sync --help` prints usage
- **Dependencies**: Docker running on Unraid, Ollama installed

### Phase 2: Core Ingestion Pipeline
- **Goal**: `sync_to_pg.py --run 012D` reads from SQLite, writes research_report + worker_reports to PG
- **Milestone**: Run `sync.py --run 012D`, verify `research_reports` has 1 row, `worker_reports` has 32 rows, pgai auto-generates embeddings within 30s
- **Dependencies**: Phase 1 complete

### Phase 3: Source & Claim Extraction
- **Goal**: Sources extracted from markdown, deduplicated, claims parsed from structured sections, full pipeline wired
- **Milestone**: Run `sync.py --run 012D` end-to-end, verify `sources` has >50 rows (deduplicated), `claims` has >20 rows, `report_sources` junction populated
- **Dependencies**: Phase 2 complete (for wiring), Phase 1 complete (for schema)

### Phase 4: Enrichment, Backfill & Integration
- **Goal**: Academic sources enriched via OpenAlex, all 10 existing summaries backfilled, meta-deep-research-execute calls sync automatically
- **Milestone**: `sources` table has enriched metadata (authors, abstract, citation_count) for academic entries. All 10 summary files ingested. Next deep research run auto-syncs to PG without manual intervention.
- **Dependencies**: Phase 3 complete

## Technical Approach

### Database
PostgreSQL via `timescale/timescaledb-ha:pg17` Docker image (includes pgvector).
pgai Vectorizer worker runs as a sidecar container, polling for new/changed rows
every 5s and auto-generating embeddings via Ollama (nomic-embed-text, 768-dim).
HNSW indexes on embedding columns for sub-millisecond similarity search. Native
PG FTS via generated tsvector columns for keyword search. pg_trgm for fuzzy title
matching in dedup.

### Ingestion Pipeline
Python 3.11+ with psycopg3 (binary). Reads from SQLite artifact DB using standard
sqlite3 module. Single transaction per run — all-or-nothing consistency. On PG
connection failure, serializes the sync request to `~/.research-sync-queue.json`
and retries on next successful run.

### Source Extraction
Two-layer: regex for URLs (`https?://...`) and DOIs (`10.\d{4,9}/...`), then
structured section parsing for the Source Index section of summaries. No LLM
needed for the structured format — regex handles 90%+ of cases. LLM fallback
(Instructor + Ollama) deferred to Phase 5 (future) for ambiguous author-year refs.

### Claim Extraction
Parse existing structured sections directly: Confidence Map table rows become
claims with inherited confidence/agreement. Per-SQ finding headers become claims
with their debate provenance. No Claimify-style LLM extraction needed — the deep
research output format is already structured for this.

### Deduplication
5-layer cascade ordered by speed: (1) SHA-256 content hash with UNIQUE constraint,
(2) DOI exact match, (3) URL normalization via url-normalize library + hash,
(4) pg_trgm fuzzy title match >= 0.7, (5) pgvector cosine similarity < 0.1.
Metadata merge via COALESCE on conflict — first-seen run preserved, fields
enriched from later citations.

### Enrichment
OpenAlex API (pyalex, 250M+ works, free, no auth) for DOI-based academic source
enrichment: authors, institutions, citation count, topics, FWCI. Semantic Scholar
as secondary (200M papers, free tier). Runs as post-insert step, idempotent via
`enrichment_status` JSONB column.

## Work Unit Decomposition

| ID | Unit | Phase | Parallel? | LOC Est | Key Files | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|---------|-----------|--------------|---------------------|
| WU-1-01 | Docker Compose setup | 1 | yes | ~60 | `research-kb/docker-compose.yml` | none | `docker compose up -d` starts 3 containers (db, vectorizer-worker, ollama). `psql` connects to PG on port 5433. Ollama responds on 11434. |
| WU-1-02 | Python project scaffold | 1 | yes | ~80 | `research-kb/pyproject.toml`, `research-kb/src/__init__.py`, `research-kb/src/config.py` | none | `pip install -e research-kb/` succeeds. `from research_kb.config import settings` returns PG_URL, SQLITE_PATH, OLLAMA_HOST with env var overrides and empty-string fallbacks. |
| WU-1-03 | SQL schema DDL | 1 | no | ~120 | `research-kb/sql/001-schema.sql` | WU-1-01 | `psql -f 001-schema.sql` creates 6 tables (research_reports, worker_reports, sources, claims, report_sources, worker_report_sources) + all indexes + constraints. `\dt` shows all 6. Generated tsvector columns on worker_reports and sources. pg_trgm extension enabled. |
| WU-1-04 | pgai Vectorizer setup | 1 | no | ~50 | `research-kb/sql/002-vectorizers.sql` | WU-1-03 | `psql -f 002-vectorizers.sql` creates 3 vectorizers (research_reports, claims, sources). `SELECT * FROM ai.vectorizer_status` shows all 3 active. Ollama pulls nomic-embed-text on first run. |
| WU-2-01 | SQLite reader module | 2 | yes | ~80 | `research-kb/src/sqlite_reader.py` | WU-1-02 | `read_run("012D")` returns a dict with keys: summary (str), workers (list[dict]), source_tally (str). Each worker dict has: skill, phase, label, content, created_at. Returns empty dict for nonexistent run_id. |
| WU-2-02 | PG writer module | 2 | yes | ~120 | `research-kb/src/pg_writer.py` | WU-1-02, WU-1-03 | `write_research_report(conn, report_dict)` inserts into research_reports, returns id. `write_worker_reports(conn, run_id, workers_list)` inserts all workers, returns list of ids. Both use parameterized queries. Duplicate run_id raises IntegrityError (UNIQUE constraint on run_id). |
| WU-2-03 | Sync CLI entry point | 2 | no | ~100 | `research-kb/src/sync.py` | WU-2-01, WU-2-02 | `python -m research_kb.sync --run 012D` reads from SQLite, writes research_report + worker_reports to PG in single transaction, prints summary (rows inserted). `--run 012D` again is idempotent (skips with message). `--dry-run` flag prints what would be inserted without writing. |
| WU-2-04 | Failure queue | 2 | no | ~60 | `research-kb/src/queue.py` | WU-2-03 | On PG connection failure in sync.py, writes `{"run_id": "012D", "timestamp": "...", "sqlite_path": "..."}` to `~/.research-sync-queue.json`. `python -m research_kb.sync --retry-queue` processes all queued items. Queue file deleted when empty. sync.py always checks queue first before processing new run. |
| WU-3-01 | Source extractor | 3 | yes | ~120 | `research-kb/src/source_extractor.py`, `research-kb/tests/test_source_extractor.py` | WU-1-02 | `extract_sources(markdown_content)` returns list of dicts with: url, doi, title, source_type, content_hash. Regex extracts URLs (http/https), DOIs (10.NNNN/...), and parses Source Index sections. Test covers: URL extraction, DOI extraction, Source Index table parsing, dedup within single document. |
| WU-3-02 | Claim parser | 3 | yes | ~100 | `research-kb/src/claim_parser.py`, `research-kb/tests/test_claim_parser.py` | WU-1-02 | `extract_claims(summary_content)` returns list of dicts with: claim_text, confidence, agreement, sub_question. Parses Confidence Map table rows and Executive Summary bullets. Test covers: confidence map parsing, executive summary bullet extraction, confidence inheritance from VERIFIED/HIGH/CONTESTED tags. |
| WU-3-03 | Dedup cascade | 3 | no | ~100 | `research-kb/src/dedup.py`, `research-kb/tests/test_dedup.py` | WU-1-03, WU-3-01 | `find_existing_source(conn, source_dict)` returns source_id if duplicate found, None otherwise. Checks 4 layers in order: content_hash, DOI, normalized URL, fuzzy title (pg_trgm >= 0.7). `upsert_source(conn, source_dict)` inserts or merges via COALESCE. Test covers: exact hash match, DOI match, URL normalization (strips utm params), fuzzy title match. Embedding similarity (layer 5) deferred until pgai generates embeddings. |
| WU-3-04 | Wire extractors into sync | 3 | no | ~80 | `research-kb/src/sync.py` (edit) | WU-2-03, WU-3-01, WU-3-02, WU-3-03 | `python -m research_kb.sync --run 012D` now also: extracts sources from summary + worker reports via source_extractor, deduplicates via dedup module, extracts claims from summary via claim_parser, populates report_sources and worker_report_sources junctions. End-to-end: sources table has >50 rows, claims >20 rows for 012D. |
| WU-4-01 | OpenAlex enrichment | 4 | yes | ~120 | `research-kb/src/enrichment.py` | WU-3-04 | `enrich_academic_sources(conn)` queries sources where doi IS NOT NULL AND enrichment_status->>'openalex' IS NULL. For each, calls OpenAlex API via pyalex, updates: authors, abstract, citation_count, publication_date, topics, enrichment_status JSONB. Idempotent — skips already-enriched. Rate-limited to 10 req/sec (OpenAlex polite pool). |
| WU-4-02 | Backfill script | 4 | yes | ~200 | `research-kb/src/backfill.py` | WU-3-04 | `python -m research_kb.backfill` reads all 10 files from `artifacts/research/summary/`. Parses each into research_report + sources + claims using same extractors as sync.py. Inserts with dedup. Prints per-file summary (rows inserted/skipped). Idempotent — skips already-backfilled run_ids. |
| WU-4-03 | Skill integration | 4 | yes | ~30 | `skills/meta-deep-research-execute/SKILL.md` (edit), `research-kb/src/sync.py` (no edit, already exists) | WU-2-03 | Add sync call at end of Phase 5 in SKILL.md: `python research-kb/src/sync.py --run "$NNN" || echo "PG sync failed, queued for retry"`. Next deep research run auto-syncs. Verify by running a test sync from the skill's Phase 5 location. |
| WU-4-04 | Cross-run query library | 4 | no | ~80 | `research-kb/sql/003-queries.sql` | WU-4-02 | SQL file with 8 named queries: most-cited sources, all contested findings, topic search (semantic), source by domain, cross-run consensus, citation count aggregation, worker model comparison, enrichment coverage. Each query tested against backfilled data — returns non-empty results. |

## Dependency Graph

```
Phase 1 (Foundation):
  WU-1-01 (Docker) ──┬──> WU-1-03 (Schema) ──> WU-1-04 (Vectorizers)
  WU-1-02 (Scaffold) ┘

Phase 2 (Ingestion):
  WU-2-01 (SQLite reader) ──┬──> WU-2-03 (Sync CLI) ──> WU-2-04 (Queue)
  WU-2-02 (PG writer) ──────┘

Phase 3 (Extraction):
  WU-3-01 (Source extractor) ──┬──> WU-3-03 (Dedup) ──┬──> WU-3-04 (Wire)
  WU-3-02 (Claim parser) ──────┘                       │
  WU-2-03 (Sync CLI) ─────────────────────────────────┘

Phase 4 (Enrichment & Integration):
  WU-3-04 (Wire) ──┬──> WU-4-01 (OpenAlex)
                    ├──> WU-4-02 (Backfill) ──> WU-4-04 (Query library)
                    └──> WU-4-03 (Skill integration)
```

**Critical path**: WU-1-01 → WU-1-03 → WU-1-04 → WU-2-02 → WU-2-03 → WU-3-04 → WU-4-02 → WU-4-04

**Parallelizable waves**:
- Wave 1: WU-1-01 + WU-1-02 (2 units)
- Wave 2: WU-1-03 (needs Docker up)
- Wave 3: WU-1-04 + WU-2-01 + WU-2-02 + WU-3-01 + WU-3-02 (5 units)
- Wave 4: WU-2-03 + WU-3-03 (2 units)
- Wave 5: WU-2-04 + WU-3-04 (2 units)
- Wave 6: WU-4-01 + WU-4-02 + WU-4-03 (3 units)
- Wave 7: WU-4-04 (1 unit)

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| pgai Vectorizer + Ollama performance on homelab hardware | Medium | Low | At <1K records, any performance is acceptable. Monitor embedding latency after backfill. pgvectorscale available as scale insurance. |
| Codex/Gemini CLIs unavailable for meta-execute workers | Medium | High | All work units are Python/SQL — Claude + Sonnet subagents can implement without external CLIs. Vibe/Cursor as fallback generators. |
| Source extraction regex misses edge cases | Low | Medium | Start with high-precision patterns. Log unmatched references. Add LLM fallback in future phase when GPU returns. |
| Docker Compose port conflicts with existing PG | Medium | Low | Use port 5433 (not 5432) to avoid conflict with any existing PG instance. Config via env var. |
| OpenAlex API rate limiting or downtime | Low | Low | Polite pool (10 req/sec). Retry with exponential backoff. Enrichment is async — doesn't block ingestion. |
| Embedding model upgrade breaks similarity search | High | Medium | Blue-green strategy: store model_name + model_version with every embedding. Re-index with new model before switching. Raw text is source of truth. |
| SQLite artifact DB schema changes | Medium | Low | Reader module uses explicit column names, not SELECT *. Schema changes require reader update. |

## Open Items

1. **Port allocation**: Which port for the research-kb PG instance? Suggested 5433 to avoid conflicts. Confirm.
2. **PG credentials**: Store in Vault (`services/research-kb`) or use local Docker defaults for now?
3. **Ollama model pull**: Should Docker Compose auto-pull nomic-embed-text on startup, or assume it's already available from existing Ollama install?
4. **Existing Ollama vs. new container**: You already have Ollama installed. Should the Docker Compose reference your existing Ollama instance (via host network) instead of spinning up a new container?
5. **Future phases** (not in this plan): LLM-based source extraction (Instructor + Ollama), local model enrichment pipeline (NER, quality scoring, contradiction detection), Apache AGE for graph queries, pg_search for BM25. These are deferred until GPU returns and the base system is validated.

## Changelog
<!-- Append-only -->
- 2026-03-28: Initial plan created from 012D + 013D research findings
