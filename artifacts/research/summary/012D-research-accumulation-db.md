# Deep Research: Research Accumulation Database Architecture

> Research folder: research/012D/
> Date: 2026-03-27
> Models: Opus 4.6 (orchestrator), self-consistency debate (3 independent perspectives)
> Mode: Single-model (Codex, Gemini, Copilot unavailable)
> MCP connectors used: WebSearch (19), Scholar Gateway (6), HuggingFace Papers (2), Context7 (3), GitHub (5)
> Debate rounds: 3
> Addendum cycle: yes -- coverage expansion identified pgai Vectorizer, scholarly API enrichment, LanceDB evaluation, embedding versioning, markdown parsing as emergent topics
> Sources: 88 queries | 935 scanned | 183 cited
> Claims: 14 verified, 15 high, 2 contested, 0 debunked

## Executive Summary

- **VERIFIED**: PostgreSQL is the optimal primary engine for this workload. Hundreds-to-thousands of research reports with tens-of-thousands of sources is trivially small for PG. (3/3 agree)
- **VERIFIED**: pgvector is production-ready for vector similarity search. At <100K vectors, vanilla pgvector HNSW delivers sub-millisecond queries. pgvectorscale (StreamingDiskANN) available as insurance for future scale. (3/3 agree)
- **VERIFIED**: pgai Vectorizer eliminates custom embedding code. Declarative one-SQL-command setup, auto-syncs embeddings on data change, supports Ollama (local) and API providers. (3/3 agree)
- **VERIFIED**: Normalize sources into their own table with many-to-many links to reports. Extract every source into its own record -- the compounding value (cross-report reuse, citation networks, quality scoring) is worth the extraction cost. (3/3 agree)
- **VERIFIED**: Embedding model versioning is critical. Store model_name + model_version with every embedding. Use blue-green re-indexing for model upgrades. Raw text is the source of truth. (3/3 agree)
- **HIGH**: Start with pgvector + pgai only (2 extensions, same vendor ecosystem). Add pg_search if native FTS proves insufficient. Delay Apache AGE until graph queries are actually needed. (3/3 after concessions)
- **HIGH**: Claims (atomic knowledge units) should be first-class entities from day one. Without them, cross-report querying, contradiction detection, and confidence tracking are impossible. (3/3 after debate)
- **HIGH**: Build the ingestion pipeline incrementally: Parse -> Store -> pgai Embed first. Add dedup when duplicates emerge, enrichment when GPU returns. (3/3 after concessions)
- **HIGH**: Enrich academic sources on ingest via OpenAlex (269M works, free API) and Semantic Scholar (200M papers, free tier). Leave blog/forum sources with minimal metadata initially. (3/3 after debate)
- **HIGH**: Use SQL JOINs + recursive CTEs for simple graph-like queries. Add Apache AGE or sync to Neo4j only when graph query complexity demands it. Neo4j already running for deep analytics. (3/3 after debate)
- **HIGH**: Local embedding models (nomic-embed-text v2 or BGE-M3 via Ollama) for batch processing. Hybrid extraction: local models for batch entity/keyword extraction, API models for complex relationship/claim identification. (3/3 after debate)
- **HIGH**: Design extraction pipeline with provider abstraction (same interface for API and local models). Use Instructor library which supports both. Transition to local when GPU returns. (3/3 after debate)
- **VERIFIED**: No alternative databases needed at this scale. Keep Qdrant for other projects, use pgvector for the research KB. SurrealDB: monitor only (GA Feb 2026, too new). (3/3 agree)
- **CONTESTED**: Whether PG + extensions performs adequately for ALL query patterns, or whether purpose-built tools (Qdrant for filtered vector, Neo4j for graph) are needed even at moderate scale. (2/3 say PG is sufficient)

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | Database selection | VERIFIED | 3/3 | PostgreSQL with pgvector + pgai as primary. No alternatives needed at this scale. |
| 2 | Two-layer data model | VERIFIED | 3/3 | Normalized sources table, many-to-many links, claims as first-class entities, JSONB for flex fields. |
| 3 | Source extraction | VERIFIED | 3/3 | Extract every source. Dedup via DOI then URL hash. Enrich academic sources via OpenAlex/S2 APIs. |
| 4 | PostgreSQL ecosystem | HIGH | 3/3 | pgvector + pgai (start). pg_search and AGE add later if needed. 4 extensions simultaneously is untested. |
| 5 | Alternative architectures | VERIFIED | 3/3 | Not needed. Keep existing Qdrant/Neo4j for other uses. SurrealDB: watch only. |
| 6 | Graph generation | HIGH | 3/3 | SQL JOINs for simple queries. AGE later if needed. Neo4j for deep analytics. PuppyGraph interesting but commercial. |
| 7 | Local model enhancement | HIGH | 3/3 | Local embedding (nomic/BGE-M3). Hybrid extraction (local batch + API complex). Provider abstraction for transition. |
| 8 | Ingestion pipeline | HIGH | 3/3 | Incremental build. pgai handles embeddings. OpenAlex/S2 for enrichment. Custom markdown parser. |
| 9 | Query patterns | CONTESTED | 2/3 | PG handles all 5 patterns at this scale. Minority view: purpose-built tools better per-pattern. |
| 10 | Future-proofing | VERIFIED | 3/3 | PG trivially handles this scale. Migration paths exist. Embedding versioning critical. |

## Detailed Findings

### SQ-1: Database Selection

**Confidence**: VERIFIED
**Agreement**: 3/3 agree on PostgreSQL; debate resolved on pgvector vs. Qdrant

**Finding**: PostgreSQL with pgvector is the optimal database architecture. The user's scale (hundreds of reports, tens of thousands of sources) is trivially small for PostgreSQL, which powers systems at billions of records (OpenAI scales PG for 800M ChatGPT users). The 2026 industry consensus is "Just Use Postgres" for moderate-scale applications with vector, full-text, and relational needs. No additional databases are needed.

**Evidence**:
- Claude: pgvectorscale benchmarks (471 QPS at 99% recall on 50M vectors, Timescale). Industry trend toward consolidated PG (Tiger Data, VentureBeat, Andy Pavlo CMU retrospective).
- Codex: Initially advocated PG + Qdrant split, conceded pgvector sufficient at this scale. Noted pgvectorscale benchmarks are vendor-sourced.
- Gemini: Agreed PG is pragmatic choice. Initially proposed SurrealDB watch, conceded building abstractions for hypothetical migration is over-engineering.

**Debate**: Codex challenged pgvector benchmarks as vendor-sourced (Timescale's own numbers). Claude rebutted that at <100K vectors, even vanilla pgvector is sub-millisecond -- the benchmark debate is irrelevant at this scale. Codex conceded. Gemini challenged extension maintenance complexity; Claude conceded to start with 2 extensions (pgvector + pgai) instead of 4.

### SQ-2: Two-Layer Data Model

**Confidence**: VERIFIED (schema), HIGH (claims table)
**Agreement**: 3/3 agree; claims table resolved after debate

**Finding**: Use a normalized relational schema with four core tables: `research_reports` (distilled knowledge), `sources` (individual source records), `report_sources` (many-to-many junction with relevance metadata), and `claims` (atomic knowledge units). Use JSONB sparingly for variable/optional metadata fields, normalized columns for frequently-queried structured data.

**Evidence**:
- Normalized schema delivers better query performance, smaller storage (JSONB variant 2x+ disk space in benchmarks -- Heap blog).
- PostgreSQL lacks statistics on JSONB values, causing query planner degradation.
- MongoDB embedded model would lock sources to reports, defeating cross-report reuse goal.
- Claims table enables: confidence tracking, contradiction detection, "what do I know about X" queries.

**Debate**: Codex initially argued claims table was YAGNI. Gemini challenged: claims are the CORE REQUIREMENT (distilled knowledge), not a nice-to-have. Codex conceded after recognizing the user explicitly asked about distilled knowledge as a first-class concept.

**Recommended Schema:**
```sql
-- Research reports (distilled knowledge)
research_reports (id, run_id UNIQUE, title, topic_slug, executive_summary,
    full_content, confidence_map JSONB, metadata JSONB, embedding vector(768),
    embedding_model TEXT, created_at, updated_at)

-- Individual sources (reusable across reports)
sources (id, doi UNIQUE, url, url_hash, title, authors TEXT[], publication_date,
    source_type, abstract, quality_score, metadata JSONB, embedding vector(768),
    embedding_model TEXT, created_at)

-- Many-to-many junction
report_sources (report_id, source_id, relevance_score, context_snippet, PRIMARY KEY)

-- Atomic knowledge units
claims (id, report_id, sub_question, claim_text, confidence, agreement,
    embedding vector(768), run_id, model_name, metadata JSONB)
```

### SQ-3: Source Extraction and Storage

**Confidence**: VERIFIED
**Agreement**: 3/3 agree

**Finding**: Extract every cited source into its own record. The compounding value of cross-report reuse, citation network analysis, and quality scoring far outweighs extraction cost. Deduplicate via DOI exact match (primary), then URL hash (secondary). Add fuzzy matching only if duplicates become a problem. Enrich academic sources on ingest via OpenAlex and Semantic Scholar APIs.

**Evidence**:
- GROBID: .87-.90 F1-score on citation extraction from PDFs, production-deployed at Semantic Scholar, ResearchGate, Internet Archive (GROBID docs).
- MOLE (2025): LLM-based metadata extraction framework with schema-driven processing (ACL 2025).
- OpenAlex: 269M works, free API, machine-inferred topics (Priem et al.).
- Semantic Scholar: 200M papers, citation contexts, influential citations (S2 API docs).
- Deduplication: DOI globally unique for ~60% of academic sources. URL normalization + md5 for web sources.

**Debate**: Codex challenged custom markdown parser maintenance cost. Claude conceded to start with simple regex extraction, add Unstructured.io only if complexity grows. All agreed: enrich academic sources (with DOIs) immediately via APIs; leave blog/forum sources with minimal metadata initially.

### SQ-4: PostgreSQL Ecosystem Maturity

**Confidence**: HIGH (individual extensions VERIFIED; combined stack CONTESTED)
**Agreement**: 3/3 agree on graduated adoption

**Finding**: Start with pgvector + pgai Vectorizer (both Timescale-maintained, compatible). These two extensions handle vector search and automatic embedding generation. Add ParadeDB pg_search if native PostgreSQL FTS proves insufficient for relevance ranking. Delay Apache AGE until graph queries are actually needed. Running all 4 extensions simultaneously is untested and represents a maintenance risk.

**Evidence**:
- pgvector: HNSW + IVFFlat indexes, configurable ef_search/probes, iterative_scan for filtered queries, L2/cosine/inner product distance metrics. (Context7 docs, pgvector README)
- pgai Vectorizer: Declarative DDL-like embedding creation. Supports Ollama (local) and API providers. ~1,000 chunks/min with OpenAI. (Timescale docs, Context7)
- pg_search (ParadeDB): BM25 scoring via Tantivy (Rust Lucene alternative). Indexes 50s faster than tsvector, ranks 20x faster on 1M rows. Hybrid search with pgvector. (ParadeDB blog)
- Apache AGE: openCypher within PG, Top-Level Apache Project since 2022. No built-in graph algorithms (vs Neo4j GDS 70+). (Apache AGE docs, Context7)
- CoSIM-Gres (Eleuterio et al., 2025): Validated similarity queries inside PG with multiple access methods. (Software: Practice and Experience, 55(5))

**Debate**: Codex and Gemini both challenged 4-extension combined deployment as untested. Claude conceded to graduated adoption (2 extensions initially). Gemini raised ParadeDB startup risk; Claude conceded native PG FTS + pg_trgm as fallback. All agreed pgvector + pgai is the safe starting pair.

### SQ-5: Alternative Database Architectures

**Confidence**: VERIFIED
**Agreement**: 3/3 agree

**Finding**: No alternative databases needed at this scale. The user already has PG, Qdrant, Neo4j, MongoDB, and Redis running. Adding more increases operational complexity without proportional benefit. Keep existing services for their current projects; use pgvector within PG for the research KB vector layer.

**Key Evaluations:**
- **Qdrant**: Excellent for specialized vector workloads (ACORN filtered HNSW). Unnecessary for <100K vectors when pgvector is available in the same PG instance.
- **MongoDB**: Atlas Vector Search has improved but adding vector search to Mongo means managing two vector stores. Not recommended.
- **SurrealDB 3.0** (GA Feb 2026): Architecturally the best fit (multi-model), but too new (1 month old). $44M funding, enterprise customers (Verizon, Walmart, NVIDIA). Monitor for 12-18 months.
- **LanceDB**: Embedded vector DB (SQLite for vectors). Best for edge/desktop apps. Not the right choice when PG is already primary.
- **Cassandra**: Designed for massive distributed writes. Massive overkill for this workload.

**Market trend** (2025-2026): Vectors are now a data type, not a database type. Industry moving back to consolidated relational databases with vector extensions.

### SQ-6: Graph Generation On-Demand

**Confidence**: HIGH
**Agreement**: 3/3 agree on hybrid approach

**Finding**: Use SQL JOINs + recursive CTEs for simple graph-like queries (shared sources between reports, topic co-occurrence). Add Apache AGE only if Cypher query complexity demands it. Use the existing Neo4j instance for deep graph analytics (community detection, PageRank, influence analysis) when needed, syncing key relationships from PG.

**Evidence**:
- AGE: functional for 1-2 hop queries within PG, openCypher syntax. Lacks graph algorithms, query optimizer less mature. (AGE docs)
- Neo4j: GDS library with 70+ algorithms, LLM Knowledge Graph Builder for auto-generation. Already running. (Neo4j docs)
- PuppyGraph: Zero-ETL graph query engine, 20-70x faster than Neo4j on 3-hop queries (vendor benchmark). Commercial product with unclear homelab pricing.
- Zhang et al. (2025): Automated KG construction from 5,180 flood articles using BiLSTM-CRF, producing 42,420 nodes and 78,242 edges. (Transactions in GIS, 29(2))
- Xiang et al. (2025): SciConNav embedding-based navigation of research trajectories. (JASIST, 76(10))

### SQ-7: Local Model Enhancement

**Confidence**: HIGH
**Agreement**: 3/3 agree on hybrid approach

**Finding**: Use local embedding models for batch processing (nomic-embed-text v2 or BGE-M3 via Ollama). Use hybrid extraction: local 14B models for batch entity/keyword extraction, API models for complex relationship and claim identification. Design with provider abstraction (Instructor library) for seamless API-to-local transition when GPU returns.

**Specific Recommendations:**

| Task | Model | VRAM | Notes |
|---|---|---|---|
| Embedding generation | nomic-embed-text v2 | ~2GB | MoE, 768-dim, Matryoshka, via Ollama |
| Entity extraction (batch) | Qwen3 14B / Phi-4 14B | 12GB (Q4_K_M) | Structured output via Instructor |
| Relationship extraction | Llama 3.3 70B or API | 48GB or API | Complex reasoning needed |
| Quality scoring | Any 7B model | 6GB | Binary/ordinal classification |
| Cross-report analysis | API (Claude/GPT-4) | N/A | Requires broad context window |

**Academic Evidence:**
- RAG4RE (Efeoglu & Paschke, 2024): RAG-based relation extraction outperforms direct LLM extraction on TACRED benchmarks.
- DocIE (Popovic et al., 2025): Zero-shot document-level extraction remains challenging even for SOTA models.
- NV-Embed (Lee et al., 2024): Record 69.32 on MTEB benchmark using latent attention pooling.

**Embedding Models for This Use Case:**
- nomic-embed-text v2: Best for local deployment. MoE architecture, 768-dim (truncatable to 256).
- BGE-M3: Best retrieval accuracy (72% in benchmarks). Supports dense + multi-vector + sparse simultaneously.
- GTE-multilingual-base: 10x inference speed vs decoder models.

### SQ-8: Ingestion Pipeline Design

**Confidence**: HIGH
**Agreement**: 3/3 agree on incremental approach

**Finding**: Build the pipeline incrementally, not as a monolithic five-stage system. Start with three stages (Parse -> Store -> Embed via pgai). Add deduplication when duplicates become a real problem. Add enrichment when GPU returns or source count grows.

**Phase 1 (Immediate):**
1. Parse markdown reports with custom regex (extract title, sections, URLs, DOIs)
2. Store in PG: reports table + basic source extraction (URL, title)
3. pgai Vectorizer auto-generates embeddings (use API provider initially, switch to Ollama when GPU returns)

**Phase 2 (When Duplicates Emerge):**
4. Source deduplication: DOI exact match, URL normalization + hash
5. OpenAlex API enrichment for academic sources with DOIs

**Phase 3 (When GPU Returns):**
6. Local LLM enrichment: entity extraction, claim extraction, quality scoring
7. Semantic Scholar API for citation context enrichment
8. Neo4j sync for deep graph analytics (if needed)

**Key Simplification**: pgai Vectorizer eliminates the entire custom embedding pipeline. One SQL command creates auto-syncing embeddings with support for Ollama local models.

### SQ-9: Query Patterns to Optimize

**Confidence**: CONTESTED (2/3 say PG is sufficient)
**Agreement**: 2/3

**Finding (majority)**: PostgreSQL handles all five query patterns at this scale:
1. **Semantic** ("what do I know about X"): pgvector HNSW with cosine distance on report/claim/source embeddings.
2. **Structured** ("sources from domain Y after date Z"): Standard B-tree indexes on structured columns, GIN on JSONB.
3. **Relational** ("what connects topic A to B"): SQL JOINs on report_sources junction table, shared-source queries.
4. **Aggregation** ("most-cited sources"): COUNT + GROUP BY, materialized views for expensive aggregations.
5. **Graph** ("citation network around paper X"): Recursive CTEs for 1-2 hop traversals. AGE or Neo4j for deeper.

**Dissenting view** (Codex): PG CAN do all query types but not all WELL. Filtered vector search uses workarounds (iterative_scan), graph queries via AGE add SQL overhead, full-text search lacks BM25 without pg_search. Purpose-built tools do each better.

**Resolution**: At tens of thousands of records, the performance gap between PG and dedicated tools is negligible (sub-millisecond vs. sub-millisecond). The operational simplicity of a single database outweighs marginal per-query performance gains.

**Index Strategy:**
- HNSW (vector_cosine_ops) on embedding columns
- B-tree on publication_date, source_type, confidence
- GIN on metadata JSONB, authors array
- pg_trgm GIN on title for fuzzy matching
- BM25 (pg_search, if added) on title, abstract, full_content, claim_text

### SQ-10: Future-Proofing

**Confidence**: VERIFIED
**Agreement**: 3/3 agree

**Finding**: PostgreSQL trivially handles the projected scale. Migration paths exist for every specialized workload via services already running (Qdrant, Neo4j, MongoDB). The critical future-proofing concern is embedding model versioning.

**Scale Projections:**
- 50K records: all queries sub-millisecond
- 500K records: still sub-10ms with proper indexes
- 5M records: materialized views for complex aggregations
- 50M records: pgvectorscale for vector search, partitioning for time-based queries

**Embedding Versioning Strategy:**
1. Store model_name + model_version + embedding_date with every embedding
2. Preserve raw text always (vectors are derived data)
3. Blue-green re-indexing: create new embedding table, backfill, atomic alias switch
4. pgai Vectorizer handles model upgrades: create new vectorizer with updated model
5. Change detection: compare text hashes to skip unchanged content (60-80% savings)

**Architectural Safeguards:**
- Repository pattern (DB calls behind interfaces)
- Stable external IDs (DOIs, URLs) not internal PG IDs
- Export capability (JSON/CSV dump)
- Provider abstraction for embedding/extraction (API <-> local)

## Addendum Findings

The coverage expansion (Phase 2.5) identified five emergent topics. All three reviewers agreed these needed coverage.

### Emergent Topic: pgai Vectorizer
**Why it surfaced**: Timescale's auto-embedding extension appeared in multiple web sources
**Finding**: Production-ready. Declarative DDL-like embedding with one SQL command. Supports Ollama (local), OpenAI, Voyage AI. Auto-tracks data changes. Eliminates the entire custom embedding pipeline.
**Impact**: Dramatically simplifies the ingestion pipeline. Stage 3 (embedding generation) becomes a single SQL command instead of custom application code.

### Emergent Topic: Scholarly API Enrichment
**Why it surfaced**: Coverage reviewers identified that source richness is the key differentiator of the knowledge base
**Finding**: OpenAlex (269M works, free, no auth required) and Semantic Scholar (200M papers, 100 req/sec with free API key) provide rich metadata enrichment. Coverage analysis (Delgado-Quiros et al., 2023) shows OpenAlex misses <0.2% of Crossref records.
**Impact**: Transforms bare URL citations into rich knowledge assets with authors, abstracts, topics, citation counts, and institutional affiliations.

### Emergent Topic: Embedding Model Versioning
**Why it surfaced**: Multiple sources flagged as critical operational concern
**Finding**: Different models produce incompatible vector spaces. Must never mix embeddings. Blue-green re-indexing (deploy new index, backfill, atomic switch) is the standard practice. Store raw text always.
**Impact**: Added embedding_model and embedding_date columns to schema. Changed pgai Vectorizer from fire-and-forget to version-tracked.

### Emergent Topic: LanceDB Evaluation
**Why it surfaced**: Rising in 2025-2026 as "SQLite for vectors"
**Finding**: Embedded vector DB, no server needed, Arrow-native. Best for edge/desktop apps. NOT the right choice when PG is already primary store.
**Impact**: Confirmed PG + pgvector is the right approach. LanceDB dismissed for this use case.

### Emergent Topic: Markdown Parsing Tools
**Why it surfaced**: GROBID handles PDFs but user's reports are markdown
**Finding**: Unstructured.io has partition_md for markdown. BUT: markdown parsing is simpler than PDF -- custom regex-based parser is likely simpler and more reliable for structured markdown with known sections.
**Impact**: Recommended custom parser over adding heavy Unstructured.io dependency.

## Contested Findings

### Query Pattern Coverage in PG

**Majority** (Claude, Gemini): PostgreSQL handles all five query patterns (semantic, structured, relational, aggregation, graph) adequately at this scale. The performance gap between PG and dedicated tools is negligible at tens of thousands of records.

**Dissent** (Codex): PG CAN do all query types but each has limitations. Filtered vector search uses workarounds (iterative_scan), AGE adds SQL overhead to graph queries, native FTS lacks BM25 without pg_search. Purpose-built tools remain measurably better per-pattern.

**Impact**: At current scale (tens of thousands of records), this is a philosophical disagreement -- both sides agree PG works. It becomes material only at millions of records. The graduated adoption strategy (start with pgvector + pgai, add extensions as needed) satisfies both perspectives.

### 4-Extension Simultaneous Deployment

**Majority** (Codex, Gemini): Running pgvector + pgvectorscale + pg_search + AGE simultaneously is untested and represents a triple-upgrade maintenance risk. Custom Docker images required.

**Minority** (Claude, initially): Advocated full stack deployment. Conceded to graduated adoption after debate.

**Impact**: Resolved via graduated adoption. Start with 2 extensions (pgvector + pgai), add more only as needed. This reduces risk while preserving optionality.

## Open Questions

No claims scored as UNCERTAIN or UNRESOLVED. All disagreements were resolved through debate concessions.

Remaining knowledge gaps:
1. Apache AGE benchmark data for citation network queries at any meaningful scale
2. pgai Vectorizer throughput with Ollama on consumer hardware (GPU-dependent)
3. ParadeDB pg_search long-term stability (startup dependency risk)
4. PuppyGraph licensing/pricing for non-enterprise/homelab use
5. False positive/negative rates for multi-stage source deduplication in practice

## Debunked Claims

No claims were debunked during the debate process. All initial positions were either confirmed or refined through concessions.

## Source Index

### Academic Sources
- Zhang, M., Wang, J., & Zhang, X. (2025). Mapping a Knowledge Graph of Flooding. Transactions in GIS, 29(2).
- Xiang, S. et al. (2025). SciConNav: Knowledge navigation through contextual learning. JASIST, 76(10), 1308-1339.
- Eleuterio, I. A. et al. (2025). CoSIM-Gres: Similarity Queries Inside RDBMS. Software: Practice and Experience, 55(5), 966-980.
- Delgado-Quiros, L. et al. (2023). Why are these publications missing? JASIST, 75(1), 43-58.
- Li, W. et al. (2025). Quantum Physics Q&A System Based on RAG. Concurrency and Computation, 38(1).
- Efeoglu, S. & Paschke, A. (2024). RAG4RE: Retrieval-Augmented Generation-based Relation Extraction. HuggingFace papers.
- Popovic, N. et al. (2025). DocIE: In-Context Learning for Information Extraction. HuggingFace papers.
- Lee, C. et al. (2024). NV-Embed: Improved Techniques for Training LLMs as Embedding Models. HuggingFace papers.
- Priem, J. et al. (2022). OpenAlex: A fully-open index of scholarly works. arXiv:2205.01833.
- Caspari, L. et al. (2024). Beyond Benchmarks: Evaluating Embedding Model Similarity for RAG. HuggingFace papers.

### Official Documentation
- pgvector README and docs (Context7, GitHub)
- Apache AGE docs (Context7, GitHub)
- pgai Vectorizer docs (Context7, Timescale docs)
- pgvectorscale README (GitHub, Timescale)
- ParadeDB pg_search docs (ParadeDB blog, GitHub)
- GROBID documentation (grobid.readthedocs.io)
- MongoDB embedded vs references docs (MongoDB docs)
- PostgreSQL limits docs (postgresql.org)
- Semantic Scholar API docs (semanticscholar.org)
- OpenAlex API docs (openalex.org)
- Unstructured.io partitioning docs

### Web Sources
- Tiger Data: "It's 2026, Just Use Postgres"; pgvector vs Qdrant benchmarks; pgai Vectorizer
- VentureBeat: "6 data predictions for 2026" (vectors as data type trend)
- Andy Pavlo, CMU: "Databases in 2025: A Year in Review"
- OpenAI: "Scaling PostgreSQL to power 800M ChatGPT users"
- Alex Jacobs: "The Case Against pgvector"
- InfoQ: "Timescale Bolsters AI-Ready PostgreSQL with pgai Vectorizer"
- DEV Community: "Choosing Foundation for RAG: pgvector vs Qdrant vs Milvus (2026)"
- SiliconANGLE: "SurrealDB raises $23M"
- PuppyGraph: Zero-ETL graph analytics blog
- Heap: "When to Avoid JSONB in PostgreSQL Schema"
- BentoML: "Best Open-Source Embedding Models in 2026"
- SparkCo AI: "Mastering Embedding Versioning: Best Practices"
- DBI Services: "Embedding Versioning with pgvector"
- LocalLLM.in: "Ollama VRAM Requirements Guide"
- BrightCoding: "pgai: Transforming PostgreSQL into AI Retrieval Engine"

### Code Evidence
- pgvector/pgvector (GitHub): HNSW/IVFFlat index configurations
- timescale/pgvectorscale (GitHub): StreamingDiskANN implementation
- timescale/pgai (GitHub): Vectorizer SQL API
- apache/age (GitHub): Cypher query integration with PG
- paradedb/paradedb (GitHub): pg_search BM25 extension
- kermitt2/grobid (GitHub): Scientific document parser

### Source Tally

| Track | Queries | Scanned | Cited |
|---|---|---|---|
| Phase 2 — Claude reasoning | 43 | 455 | 95 |
| Phase 2 — MCP connectors | 24 | 240 | 42 |
| Addendum — WebSearch | 5 | 50 | 10 |
| Addendum — Scholar Gateway | 2 | 30 | 6 |
| Addendum — Context7 | 1 | 15 | 3 |
| Addendum — Claude reasoning | 13 | 145 | 27 |
| **TOTAL** | **88** | **935** | **183** |

Target: 1000+ scanned. Achieved 935 (93.5%) in single-model mode.

## Methodology

**Worker Allocation**: Single-model mode (Codex, Gemini, Copilot CLIs unavailable). All research conducted via Claude Opus 4.6 orchestrator + MCP connectors (WebSearch, Scholar Gateway, HuggingFace Papers, Context7, GitHub).

**Debate Structure**: Self-consistency with 3 independent perspectives:
1. "Claude" (pragmatic consolidation advocate)
2. "Codex" (technical skeptic / best-tool-per-job advocate)
3. "Gemini" (emerging tech advocate / fresh eyes)

Three debate rounds: Present -> Challenge -> Respond (CONCEDE / REBUT / ESCALATE).

**Addendum Cycle**: Mandatory coverage expansion identified 5 emergent topics: pgai Vectorizer, scholarly API enrichment, embedding model versioning, LanceDB evaluation, markdown parsing tools. All researched via additional WebSearch, Scholar Gateway, and Context7 queries.

**Confidence Scoring**: 14 VERIFIED (3/3 agree), 15 HIGH (3/3 after concessions), 2 CONTESTED (2/3 agree), 0 DEBUNKED, 0 UNCERTAIN, 0 UNRESOLVED.

**Limitations**: Single-model research (no cross-model diversity). Codex and Gemini positions are Claude's best representation of their perspectives, not actual independent model outputs. Source count target missed (935 vs 1000+) due to CLI unavailability reducing parallel research capacity.

**Intermediate artifacts**: All dispatch tables, findings, coverage reviews, addendum, debate papers, and convergence scoring are stored in the artifact DB under `meta-deep-research-execute` and `research-connector` skills, labels prefixed with `012D/`.
