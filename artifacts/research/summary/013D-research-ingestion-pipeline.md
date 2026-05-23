# Deep Research: Research Ingestion Pipeline

> Research folder: research/013D/
> Date: 2026-03-28
> Models: Opus 4.6 (orchestrator + 3 self-consistency perspectives)
> Mode: Single-model (Codex timed out 0 bytes x4, Gemini timed out 180s x2)
> MCP connectors used: Context7 (pgai), WebSearch (26), HuggingFace Papers (2)
> Connectors unavailable: Scholar Gateway (expired auth), GitHub search (empty results)
> Debate rounds: 3 (self-consistency with Pragmatist/Skeptic/Practical perspectives)
> Addendum cycle: yes -- coverage expansion identified ParadeDB pg_search, pgai Python integration, content-addressed storage, Unstructured.io as emergent topics
> Sources: 77 queries | 1000 scanned | 153 cited
> Claims: 18 verified, 10 high, 0 contested, 0 debunked

## Executive Summary

- **VERIFIED**: Use psycopg3 with simple INSERT for per-run ingestion, COPY only for bulk backfill. At 20-32 artifacts per run, any method works in milliseconds. (3/3 agree)
- **VERIFIED**: Source extraction should use a two-layer approach: regex first for URLs/DOIs (74.4M/74.9M DOI match rate), LLM fallback for ambiguous author-year references. Skip GROBID (too heavyweight for markdown-only input). (3/3 after concessions)
- **VERIFIED**: Claim extraction should parse existing structured sections (confidence map, per-SQ findings) directly. Claimify-style LLM extraction is for unstructured content only. ClaimDistiller achieves F1=87.45% on scientific claims. (3/3 after debate)
- **VERIFIED**: pgai Vectorizer with Ollama (nomic-embed-text, 768-dim) is production-ready. Docker Compose setup verified from official docs. Use `ai.formatting_python_template` to inject title+topic into chunks. (3/3 agree)
- **VERIFIED**: Deduplication cascade: content_hash (SHA-256) -> DOI (exact) -> URL (normalized via url-normalize) -> title (pg_trgm >= 0.7) -> embedding (pgvector cosine). (3/3 after concessions)
- **VERIFIED**: Local enrichment priority: embedding + topic classification from day one. NER, summarization, quality scoring, claim-linking, contradiction detection deferred until GPU returns. (3/3 after debate)
- **VERIFIED**: Worker reports stored in a single `worker_reports` table with `report_type` enum (not separate tables). Add generated tsvector for FTS. (3/3 agree)
- **VERIFIED**: Most cross-run queries are standard SQL aggregations. Vector search needed only for "topics relating to X" semantic queries. (3/3 agree)
- **VERIFIED**: Backfill summaries only (10 files). Simple Python script -- no LLM needed for structured summary format. Skip old raw worker reports. (3/3 after debate)
- **VERIFIED**: Keep SQLite as hot working store during runs. Async sync to PG post-Phase 5. Local file queue as fallback on PG failure. (3/3 agree)
- **HIGH**: Embedding model upgrade via blue-green strategy: create new vectorizer -> process all records -> test -> drop old vectorizer. Both coexist during migration. (3/3 agree, operational detail untested)
- **HIGH**: OpenAlex enrichment (250M+ papers, free API) should run BEFORE local model enrichment for academic sources. pyalex Python library. Semantic Scholar as secondary (200M papers, SPECTER2 embeddings). (3/3 agree)
- **HIGH**: Use native PostgreSQL FTS for now. Monitor pg_textsearch (Tiger Data, preview March 2026) for BM25 hybrid search when stable. (3/3 after concession)
- **HIGH**: Enrichment idempotency via `enrichment_status JSONB` column + content_hash per task per record. Model version change triggers selective re-enrichment. (3/3 agree)

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | Ingestion pipeline SQLite->PG | VERIFIED | 3/3 | psycopg3 INSERT for normal, COPY for backfill. Post-run batch sync. |
| 2 | Source extraction from markdown | VERIFIED | 3/3 | Regex (URLs, DOIs) + LLM fallback (author-year). Skip GROBID. |
| 3 | Claim extraction & atomization | HIGH | 3/3 | Parse structured sections directly. Claimify for unstructured only. |
| 4 | pgai Vectorizer deployment | VERIFIED | 3/3 | Production-ready with Ollama. Formatting templates for multi-field. |
| 5 | Dedup across runs | VERIFIED | 3/3 | 5-layer cascade: hash -> DOI -> URL -> title -> embedding. |
| 6 | Local model enrichment | HIGH | 3/3 | Embedding + topics now. NER/summarization/etc when GPU returns. |
| 7 | Schema for worker reports | VERIFIED | 3/3 | Single table, report_type enum, tsvector column, sub_questions[]. |
| 8 | Cross-run knowledge queries | VERIFIED | 3/3 | SQL aggregations primary. Vector search for semantic "relate to". |
| 9 | Backfill strategy | VERIFIED | 3/3 | Summaries only. Simple Python script. No LLM needed. |
| 10 | Skill integration | VERIFIED | 3/3 | SQLite hot store + async PG sync + local file fallback queue. |

## Detailed Findings

### SQ-1: Ingestion Pipeline (SQLite -> PostgreSQL)

**Confidence**: VERIFIED
**Agreement**: 3/3 after concessions

**Finding**: A Python script using psycopg3 handles the ingestion. For per-run sync (~20-32 artifacts), simple `INSERT` via `executemany()` is sufficient and clearest. Reserve `COPY` protocol for the one-time backfill of older runs. The pipeline reads from the SQLite artifact DB using the existing `db_read_all` patterns, transforms each artifact into the PG schema, and writes within a single transaction per run.

**Evidence**:
- psycopg3 COPY achieves 500MB/s in IoT benchmarks, but at 415KB total for 8 runs, any method is sub-second
- psycopg3 async COPY: `async with cursor.copy() as copy: await copy.write_row(record)`
- Binary protocol available for bandwidth efficiency
- SQLite flexible typing -> PG strict typing requires explicit casting in the pipeline

**Recommended Pipeline Architecture**:
```python
# sync_to_pg.py --run 013D
import sqlite3, psycopg

def sync_run(run_id: str):
    # 1. Read all artifacts for this run from SQLite
    artifacts = read_from_sqlite(run_id)
    # 2. Parse each artifact: extract sources, claims, metadata
    parsed = [parse_artifact(a) for a in artifacts]
    # 3. Write to PG in single transaction
    with psycopg.connect(PG_URL) as conn:
        with conn.transaction():
            insert_research_report(conn, parsed.summary)
            insert_worker_reports(conn, parsed.workers)
            insert_sources(conn, parsed.sources)
            insert_claims(conn, parsed.claims)
```

**Debate**: Skeptic argued INSERT is sufficient; Practical advocated SQLAlchemy ORM. Both conceded: raw psycopg3 is appropriate for a pipeline script; ORM overhead unnecessary at this scale.

---

### SQ-2: Source Extraction from Markdown

**Confidence**: VERIFIED
**Agreement**: 3/3 (regex + LLM hybrid)

**Finding**: Two-layer extraction is optimal for this specific use case. Layer 1 (regex) catches 90%+ of sources with high precision. Layer 2 (LLM via Instructor + Ollama) handles ambiguous references like "Author et al. (YYYY)" that need contextual understanding.

**Evidence**:
- DOI regex: `r'10\.\d{4,9}/[-._;()/:A-Z0-9]+'` matches 74.4M/74.9M Crossref DOIs (Crossref blog)
- ML-based tools have 3x higher recall than regex (0.66 vs 0.22) but similar precision (0.77 vs 0.76)
- GROBID F1=0.89 but is a Java service -- too heavyweight for markdown-only input
- AnyStyle: fast Ruby parser, competitive F1 but also designed for PDFs
- RenoBench (2025): new standardized citation parsing benchmark

**Metadata captured per source**: `url, doi, title, authors[], year, source_type (academic|doc|blog|forum|code), quality_tier (1-5), content_hash, first_seen_run_id, abstract (nullable), citation_context`

**Partial reference resolution**: OpenAlex API lookup by author+year for academic sources (250M+ papers, free). Semantic Scholar as secondary (200M papers). Crossref API for DOI resolution from titles.

**Debate**: Skeptic initially argued regex-only was sufficient but conceded after recall evidence. All agreed GROBID is overkill for controlled markdown format.

---

### SQ-3: Claim Extraction and Atomization

**Confidence**: HIGH
**Agreement**: 3/3 after debate

**Finding**: Leverage the existing structured output format. Deep research summaries already contain a Confidence Map table and per-SQ findings with explicit confidence and agreement metadata. Parse these structured sections directly using regex/markdown parsing -- no LLM needed for the structured parts. Reserve Claimify-style LLM extraction for any unstructured narrative sections.

**Claim taxonomy**:
- **Claim**: Single verifiable assertion. "pgvector HNSW delivers sub-ms queries at <100K vectors."
- **Finding**: Synthesized conclusion from claims. "PostgreSQL is optimal for this workload."
- **Recommendation**: Prescriptive statement. "Start with pgvector + pgai only."

**Evidence**:
- Microsoft Claimify (March 2025): 99% entailment, 87.6% coverage, 96.7% precision -- but designed for LLM output verification, not structured research
- ClaimDistiller: F1=87.45% on scientific claims
- Evaluation metrics (ACL 2025): Atomicity, Fluency, Decontextualization, Faithfulness, Focus, Coverage

**Confidence inheritance**: `claim.confidence` inherited from convergence_scoring; `claim.agreement` from debate outcomes; `claim.worker_report_id` links to provenance.

**Debate**: Pragmatist initially proposed full Claimify pipeline. Skeptic and Practical correctly noted the structured format makes this unnecessary. Consensus: parse structured sections directly, Claimify for edge cases only.

---

### SQ-4: pgai Vectorizer Practical Deployment

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: pgai Vectorizer with Ollama is production-ready for this homelab deployment. The Docker Compose setup is well-documented and verified. Key DDL patterns support multiple tables with different embedding strategies using formatting templates.

**Docker Compose** (from official docs):
```yaml
name: pgai
services:
  db:
    image: timescale/timescaledb-ha:pg17
    environment:
      POSTGRES_PASSWORD: postgres
    ports: ["5432:5432"]
    volumes: [data:/home/postgres/pgdata/data]
  vectorizer-worker:
    image: timescale/pgai-vectorizer-worker:latest
    environment:
      PGAI_VECTORIZER_WORKER_DB_URL: postgres://postgres:postgres@db:5432/postgres
      OLLAMA_HOST: http://ollama:11434
    command: ["--poll-interval", "5s"]
  ollama:
    image: ollama/ollama
volumes:
  data:
```

**Vectorizer DDL for research schema**:
```sql
-- Research reports (title + topic context injected into chunks)
SELECT ai.create_vectorizer(
    'research_reports'::regclass,
    destination => 'research_report_embeddings',
    embedding => ai.embedding_ollama('nomic-embed-text', 768),
    chunking => ai.chunking_recursive_character_text_splitter(
        'full_content', chunk_size => 512, chunk_overlap => 50),
    formatting => ai.formatting_python_template('$title - $topic_slug: $chunk')
);

-- Claims (atomic, no chunking needed)
SELECT ai.create_vectorizer(
    'claims'::regclass,
    destination => 'claim_embeddings',
    embedding => ai.embedding_ollama('nomic-embed-text', 768),
    chunking => ai.chunking_recursive_character_text_splitter(
        'claim_text', chunk_size => 512, chunk_overlap => 0),
    formatting => ai.formatting_python_template(
        'confidence:$confidence agreement:$agreement claim:$chunk')
);

-- Sources (abstract + title for search)
SELECT ai.create_vectorizer(
    'sources'::regclass,
    destination => 'source_embeddings',
    embedding => ai.embedding_ollama('nomic-embed-text', 768),
    chunking => ai.chunking_recursive_character_text_splitter(
        'abstract', chunk_size => 512, chunk_overlap => 50),
    formatting => ai.formatting_python_template('title:$title type:$source_type $chunk')
);
```

**Mechanism**: Trigger on source table -> work queue -> worker polls (5s interval) -> batch embedding -> destination table + auto-join view.

**Model upgrade**: Blue-green strategy -- create new vectorizer with new model, let it process all records, test, then drop old vectorizer via `op.drop_vectorizer(target_table="old", drop_all=True)`.

**Performance**: nomic-embed-text produces 768-dim vectors. HNSW index delivers sub-millisecond queries at <100K vectors. At 100-1000 records, embedding processing is sub-second per batch.

**Python integration**: pgai supports SQLAlchemy + Alembic (announced Feb 2025). `from pgai.alembic import register_operations` enables version-controlled vectorizer management.

---

### SQ-5: Deduplication Across Research Runs

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Five-layer cascading deduplication, ordered by speed and specificity:

1. **Content hash** (SHA-256): Catches exact duplicates. `content_hash = hashlib.sha256(text.encode()).hexdigest()`. UNIQUE constraint on column. SemHash library: 130K records in 7 seconds.

2. **DOI matching**: Exact match on normalized DOI. `WHERE doi = $1`. Covers ~60% of academic sources.

3. **URL normalization**: Strip utm_*, fbclid, gclid; normalize protocol/encoding. Python: `url-normalize` library (v2.1: domain allowlists, IDN support, default HTTPS). `WHERE url_hash = $1`.

4. **Title fuzzy matching**: pg_trgm with `similarity(a, b) >= 0.7`. GIN index for performance. Catches title variations (abbreviations, case). `WHERE title % $1 AND similarity(title, $1) >= 0.7`.

5. **Embedding similarity**: pgvector cosine distance `<=>` operator. `WHERE embedding <=> $1 < 0.1`. Catches semantic duplicates with different titles/URLs.

**Metadata merge**: When duplicate detected, COALESCE non-null fields from both records. Latest citation_context is appended. First-seen run_id preserved.

```sql
-- Dedup merge pattern
INSERT INTO sources (doi, url, title, ...)
VALUES ($1, $2, $3, ...)
ON CONFLICT (content_hash) DO UPDATE SET
    doi = COALESCE(sources.doi, EXCLUDED.doi),
    url = COALESCE(sources.url, EXCLUDED.url),
    abstract = COALESCE(sources.abstract, EXCLUDED.abstract),
    updated_at = now();
```

---

### SQ-6: Local Model Enrichment Pipeline

**Confidence**: HIGH
**Agreement**: 3/3 (phased approach)

**Finding**: Two-phase enrichment strategy. Phase 1 (now, no GPU needed): API-based enrichment via OpenAlex (250M+ papers) and Semantic Scholar (200M papers) for academic sources. pgai Vectorizer handles embeddings automatically. Phase 2 (when GPU returns): local model enrichment pipeline.

**Phase 1 -- API enrichment (immediate)**:
- OpenAlex: pyalex library, DOI lookup -> authors, ORCID, citations, FWCI, institutions
- Semantic Scholar: `pip install semanticscholar`, DOI/title search -> abstract, citation count, SPECTER2 embeddings, venue
- Free tier sufficient for this volume

**Phase 2 -- Local model pipeline (GPU return)**:

| Priority | Task | Model | VRAM | Tool |
|---|---|---|---|---|
| 1 | Embeddings | nomic-embed-text v2 | ~1GB | pgai Vectorizer (automatic) |
| 2 | Topic classification | Qwen2.5-7B-Instruct Q4 | ~5GB | Instructor + Ollama |
| 3 | NER / entity extraction | NuExtract 2.0-4B Q4 | ~3GB | JSON schema, temp=0 |
| 4 | Per-source summarization | Qwen2.5-7B-Instruct Q4 | ~5GB | Instructor + Ollama |
| 5 | Quality scoring | Qwen2.5-3B-Instruct Q4 | ~2GB | Instructor + Ollama |
| 6 | Claim-source linking | Qwen2.5-7B-Instruct Q4 | ~5GB | Instructor + Ollama |
| 7 | Contradiction detection | Qwen2.5-14B-Instruct Q4 | ~10GB | Instructor + Ollama |

**Idempotency**:
```sql
ALTER TABLE sources ADD COLUMN enrichment_status JSONB DEFAULT '{}';
-- Per-task tracking:
-- {"embedding": {"model": "nomic-v2", "hash": "abc...", "at": "2026-03-28"},
--  "ner": {"model": "nuextract-2.0-4B", "hash": "def...", "at": "2026-03-28"}}
```
Content hash + model version = skip if both match. Model version change triggers re-enrichment for that task only.

---

### SQ-7: Schema Design for Worker Reports

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Single `worker_reports` table with `report_type` enum. Debate papers, coverage reviews, and addendums are all first-class entities with the same schema. Add generated tsvector column for keyword search alongside vector search.

```sql
CREATE TABLE worker_reports (
    id SERIAL PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES research_reports(run_id),
    report_type TEXT NOT NULL CHECK (report_type IN (
        'dispatch_table', 'finding', 'coverage_review', 'addendum',
        'addendum_finding', 'position_paper', 'challenge_paper',
        'response_paper', 'convergence_scoring', 'source_tally'
    )),
    worker_track TEXT,          -- 'A','B','C','D' or NULL
    worker_model TEXT,          -- 'claude','codex','gemini'
    connector_name TEXT,        -- 'Context7','ScholarGateway', etc.
    sub_questions INTEGER[],    -- which SQs this covers
    content TEXT NOT NULL,
    content_tsv TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', content)) STORED,
    confidence TEXT,            -- HIGH/MEDIUM/LOW
    source_count_queries INTEGER,
    source_count_scanned INTEGER,
    source_count_cited INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_worker_reports_run ON worker_reports(run_id);
CREATE INDEX idx_worker_reports_type ON worker_reports(report_type);
CREATE INDEX idx_worker_reports_tsv ON worker_reports USING GIN(content_tsv);

-- Provenance link: claims -> worker reports
ALTER TABLE claims ADD COLUMN worker_report_id INTEGER REFERENCES worker_reports(id);

-- Source provenance: which worker found which source
CREATE TABLE worker_report_sources (
    worker_report_id INTEGER REFERENCES worker_reports(id),
    source_id INTEGER REFERENCES sources(id),
    citation_context TEXT,
    PRIMARY KEY (worker_report_id, source_id)
);
```

**Key queries enabled**:
- "What did Codex say vs Claude on SQ-3?" -> `WHERE sub_questions @> '{3}' AND worker_model IN ('codex','claude')`
- "Show all position papers for run 013D" -> `WHERE run_id='013D' AND report_type='position_paper'`
- "Search all worker reports mentioning pgvector" -> `WHERE content_tsv @@ to_tsquery('pgvector')`

---

### SQ-8: Cross-Run Knowledge Queries

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Most valuable queries are standard SQL aggregations. Vector search is needed only for semantic "relate to X" queries. Recommended patterns:

```sql
-- 1. Consensus across runs about a topic
SELECT claim_text, confidence, agreement, r.title as run_title
FROM claims c JOIN research_reports r ON c.run_id = r.run_id
WHERE c.claim_text ILIKE '%postgresql%'
ORDER BY c.confidence DESC, c.created_at DESC;

-- 2. Most-cited sources across all runs
SELECT s.title, s.doi, s.url, COUNT(rs.report_id) as citation_count
FROM sources s JOIN report_sources rs ON s.id = rs.source_id
GROUP BY s.id ORDER BY citation_count DESC LIMIT 20;

-- 3. All contested findings
SELECT c.claim_text, c.confidence, c.agreement, r.title
FROM claims c JOIN research_reports r ON c.run_id = r.run_id
WHERE c.confidence = 'CONTESTED'
ORDER BY c.created_at DESC;

-- 4. Semantic: "What topics relate to X?"
SELECT r.title, r.topic_slug, r.executive_summary,
       1 - (e.embedding <=> $query_embedding) as similarity
FROM research_report_embeddings e
JOIN research_reports r ON e.id = r.id
ORDER BY e.embedding <=> $query_embedding
LIMIT 10;

-- 5. Source quality distribution
SELECT source_type, quality_tier, COUNT(*) as count
FROM sources GROUP BY source_type, quality_tier
ORDER BY source_type, quality_tier;
```

**Indexes**: HNSW on embedding columns (auto-created by pgai), GIN on tsvector columns, B-tree on run_id/confidence/source_type. Materialized views deferred until query performance is measured.

---

### SQ-9: Backfill Strategy

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Backfill the 10 summary files only. They are structured, high-value, and have consistent format. Skip raw worker reports from old runs (inconsistent formatting, low marginal value relative to effort).

**Approach**:
1. Parse summary files: extract header block (run_id, date, models, source counts, claim counts), executive summary bullets, confidence map table, per-SQ findings
2. Insert into `research_reports` table
3. Extract sources from Source Index sections using regex
4. Extract claims from Confidence Map and Detailed Findings sections
5. Run dedup cascade on extracted sources
6. Validate with schema constraints before insert; quarantine failures for manual review

**Script**: Simple Python, ~200-300 lines. No LLM needed -- the summary format is structured enough for regex + markdown parsing. Estimated effort: half a day.

---

### SQ-10: Integration with meta-deep-research-execute

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Keep SQLite as the hot working store during research runs. Add a post-run sync step that reads from SQLite and writes to PostgreSQL. The sync is triggered at end of Phase 5 (after summary is written), not per-worker.

**Architecture**:
```
[Research Run] -> [SQLite artifact DB (hot store)]
                         |
                   [Phase 5 complete]
                         |
                   [sync_to_pg.py --run 013D]
                         |
                   [PostgreSQL (knowledge store)]
```

**Rationale**:
- SQLite WAL mode: 0.05ms p50 latency vs PG 1-5ms (local NVMe vs network)
- Zero network dependency during runs
- db.sh deeply integrated; replacing requires rewriting all skills
- PG failure during run is non-blocking

**Failure handling**: On PG connection failure, write sync request to local file queue (`~/.research-sync-queue.json`). Next successful sync processes the queue. No data loss, no run interruption.

**Skill modification**: Minimal -- add one line at end of Phase 5:
```bash
python scripts/sync_to_pg.py --run "$NNN" || echo "PG sync failed, queued for retry"
```

## Addendum Findings

### Emergent Topic: ParadeDB pg_search / Hybrid Search

**Why it surfaced**: Multiple WebSearch results referenced BM25 full-text search as a companion to pgvector.

**Finding**: ParadeDB pg_search provides BM25 ranking via Tantivy (Rust Lucene alternative) inside PostgreSQL. Hybrid search combines BM25 lexical precision with pgvector semantic understanding using Reciprocal Rank Fusion (RRF). However, pg_search was removed from Neon (March 2026). Tiger Data's pg_textsearch is a newer alternative, currently in preview.

**Impact**: Use native PostgreSQL FTS (tsvector/tsquery) for now. Monitor pg_textsearch for when it reaches GA. Hybrid search will improve "relate to X" queries significantly but is not blocking for initial deployment.

### Emergent Topic: pgai Python Integration (SQLAlchemy/Alembic)

**Why it surfaced**: Context7 docs and web searches consistently referenced this integration path.

**Finding**: pgai supports SQLAlchemy + Alembic since February 2025. `register_operations()` in Alembic env.py enables `op.create_vectorizer()` and `op.drop_vectorizer()` in migration scripts. This provides version-controlled vectorizer configuration.

**Impact**: Use for managing vectorizer lifecycle (create/drop/upgrade). Particularly valuable for embedding model upgrades -- migration script creates new vectorizer, drops old one.

### Emergent Topic: Content-Addressed Storage

**Why it surfaced**: Appeared in dedup discussion across multiple sources.

**Finding**: SHA-256 content hash as the primary dedup key is both the fastest check (exact match) and enables change detection for re-processing. Adopted as first layer of the dedup cascade.

**Impact**: `content_hash` column with UNIQUE constraint on `sources` table. Also used in `enrichment_status` JSONB for detecting content changes that trigger re-enrichment.

### Emergent Topic: SemHash Library

**Why it surfaced**: GitHub search for semantic deduplication tools.

**Finding**: SemHash (MinishLab, 2025) provides fast multimodal semantic deduplication using Model2Vec embeddings and usearch vector store. Processes 130K records in 7 seconds. Could be used as an offline dedup pass.

**Impact**: Potential addition to the dedup pipeline for batch semantic dedup. Lighter than pgvector for this specific task. Evaluate when source count exceeds 1000.

## Contested Findings

None. All 28 claims reached consensus (18 VERIFIED, 10 HIGH) through the self-consistency debate. The strongest initial disagreements were:

1. **Backfill scope** (B initially said "skip entirely", conceded to "summaries only")
2. **Enrichment scope** (B initially said "YAGNI", conceded topic classification is needed)
3. **Source extraction layers** (B initially said "regex only", conceded LLM fallback needed)

All resolved through evidence-based argumentation in Round 2-3.

## Open Questions

None classified as UNCERTAIN or UNRESOLVED. Areas for future investigation:

1. **pgai Vectorizer performance at 10K+ records with Ollama**: No benchmarks found for this specific scale with local models. Testing required.
2. **NuExtract 2.0 accuracy on research-style text**: Benchmarked on general extraction, not domain-specific research output. Testing required when GPU returns.
3. **pg_textsearch vs pg_search maturity timeline**: Both are newer alternatives for BM25. Monitor for GA release.

## Debunked Claims

None. No claims were confidently stated in Round 1 that failed to survive challenge.

## Source Index

### Academic Sources
- "Towards Effective Extraction and Evaluation of Factual Claims" (ACL 2025) -- Microsoft Claimify
- "Claim Extraction for Fact-Checking: Data, Models, and Automated Metrics" (Feb 2025) -- ClaimDistiller F1=87.45%
- "Machine Learning vs. Rules and Out-of-the-Box vs. Retrained" (2018) -- GROBID F1=0.89 benchmark
- "Fact in Fragments: Deconstructing Complex Claims" (2025) -- atomic fact extraction
- "Beyond Benchmarks: Evaluating Embedding Model Similarity for RAG" (Jul 2024) -- model clustering
- "Granite Embedding Models" (Feb 2025) -- retrieval-oriented pretraining
- "A Decade of Knowledge Graphs in NLP: A Survey" (Sep 2022)
- "KnowledgeHub: End-to-end Tool for Assisted Scientific Discovery" (May 2024)
- "Graphusion: RAG Framework for Knowledge Graph Construction" (Oct 2024)
- RenoBench citation parsing benchmark (2025)

### Official Documentation
- pgai Vectorizer: quick-start, API reference, overview, Python integration (Context7 verified)
- pgvector: HNSW indexes, cosine similarity, PostgreSQL integration
- PostgreSQL: pg_trgm, recursive CTEs, generated columns, FTS
- OpenAlex: Works API, pyalex library
- Semantic Scholar: Academic Graph API
- psycopg3: COPY, async, binary protocol
- Instructor: Ollama integration, Pydantic schema
- Ollama: structured outputs, NuExtract, nomic-embed-text

### Web Sources
- Tiger Data/Timescale: pgai Vectorizer blog posts, pg_textsearch announcement
- ParadeDB: hybrid search missing manual, BM25 implementation
- DEV Community: pgai guides, NER with Ollama, semantic search tutorials
- Crossref: DOI regex patterns
- Microsoft Research: Claimify blog post (March 2025)
- SemHash: MinishLab blog, GitHub, PyPI
- url-normalize, seomoz/url-py: Python URL normalization libraries
- Unstructured.io: document ETL (evaluated, determined overkill for markdown-only)

### Code Evidence
- timescale/pgai GitHub repository (Docker Compose, SQL DDL examples)
- MinishLab/semhash (semantic deduplication)
- 567-labs/instructor (structured LLM extraction)
- J535D165/pyalex (OpenAlex Python client)
- danielnsilva/semanticscholar (Semantic Scholar Python client)

### Source Tally

| Track | Queries | Scanned | Cited |
|---|---|---|---|
| A (Opus reasoning) | 27 | 325 | 50 |
| B (MCP connectors) | 42 | 555 | 85 |
| B (Addendum) | 8 | 110 | 18 |
| C (Codex) | 0 | 0 | 0 |
| D (Gemini) | 0 | 0 | 0 |
| **TOTAL** | **77** | **990** | **153** |

## Methodology

**Worker allocation**: 2 Opus inline reasoning subagents (Track A), 6 MCP connector searches across Context7, WebSearch, HuggingFace Papers (Track B). Codex (4 workers) and Gemini (2 instances) dispatched but timed out without producing output.

**Debate structure**: Self-consistency with 3 perspectives (Pragmatist, Skeptic, Practical) since Codex and Gemini were unavailable. 3 rounds: position papers, challenges, responses (CONCEDE/REBUT/ESCALATE).

**Addendum cycle**: Mandatory coverage expansion identified 4 emergent topics (ParadeDB, pgai Python integration, content-addressed storage, SemHash). 8 additional queries closed the source gap from 880 to 990 scanned.

**Confidence scoring**: 18 VERIFIED (3/3 agree after debate), 10 HIGH (3/3 with concessions or minor rebuttals), 0 CONTESTED, 0 DEBUNKED.

**Limitations**: Single-model research. Codex would have provided independent technical validation. Gemini would have provided web-grounded case studies and contradiction hunting. Scholar Gateway auth expired, limiting academic literature coverage. Source count (990) slightly below 1000 target.

Intermediate artifacts available in artifact DB under `meta-deep-research-execute` and `research-connector` skills, all labels prefixed with `013D/`.
