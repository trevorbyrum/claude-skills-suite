# Deep Research Prompt — 012D

## Research Question
What is the optimal database architecture and data model for a centralized, cross-project research accumulation system that stores both **distilled knowledge** (synthesized findings, conclusions) and **individual source metadata** (papers, URLs, citations, abstracts) — and how can a local LLM maximize the value of accumulated research for future retrieval, cross-referencing, and on-demand knowledge graph generation?

## Sub-Questions

1. **Database selection**: PostgreSQL (with pgvector + Apache AGE/Cypher), MongoDB, CassandraDB, or another engine — which best fits a system that must handle hundreds-to-thousands of research reports with both structured metadata and semantic search? What are the tradeoffs at this scale for each? Is a single-engine approach viable or does best-tool-per-job win?

2. **Two-layer data model**: What's the best schema/document design for separating (a) distilled research outputs (synthesis, findings, confidence scores, topic) from (b) individual sources (URL, title, authors, publication date, abstract, type, relevance score)? Should sources be normalized into their own table/collection with many-to-many links to reports, or embedded?

3. **Source extraction and storage**: Is it worth parsing each cited source out of research reports into its own record? What metadata should be captured per source? How do you deduplicate sources cited across multiple reports?

4. **PostgreSQL ecosystem**: How mature are pgvector (vector similarity), Apache AGE (Cypher/graph queries), and FTS for this use case? Can PG realistically serve as the single engine for structured + vector + graph + full-text, or do the extensions degrade at scale?

5. **Alternative DB architectures**: How do MongoDB (document flexibility, Atlas Vector Search), CassandraDB (write-heavy, distributed), SurrealDB (multi-model), or other engines compare for this workload? What about purpose-built options like Weaviate, Milvus, or ChromaDB for the vector layer?

6. **Graph generation on-demand**: If sources accumulate over time with rich metadata and relationship tags, what's needed to generate ad-hoc knowledge graphs from subsets of the data? Is this better done with a dedicated graph DB (Neo4j), a PG extension (AGE), or computed at query time from relational data?

7. **Local model enhancement**: Once a GPU is available, how can a local model (e.g., Llama 3, Mistral, Phi-3) maximize accumulated research value? Specific use cases to evaluate:
   - Auto-generating structured summaries/descriptions per source
   - Extracting entities, relationships, and key claims from sources
   - Computing embeddings for semantic search (vs. using an API)
   - Identifying cross-report patterns and contradictions
   - Enriching source metadata (categorization, quality scoring, claim extraction)
   - Any novel approaches the research uncovers

8. **Ingestion pipeline design**: What does the pipeline look like from "research report completed" to "data stored and queryable"? Steps for parsing, chunking, embedding, source extraction, deduplication, and indexing.

9. **Query patterns to optimize for**:
   - Semantic: "What do I know about topic X?" across all research
   - Structured: "All sources from domain Y published after date Z"
   - Relational: "What findings connect topic A to topic B?"
   - Aggregation: "Most-cited sources", "topics with contested findings"
   - Graph: "Show me the citation network around paper X"

10. **Future-proofing**: At hundreds-to-thousands of reports with potentially tens of thousands of individual sources, what scaling considerations matter? Migration paths if the initial choice hits limits?

## Scope
- Breadth: exhaustive
- Time horizon: include historical context but weight recent (2024-2026) heavily
- Domain constraints: database architecture, knowledge management systems, research accumulation, local LLM pipelines, vector search, graph databases

## Project Context
- Homelab: Unraid tower, Docker, Traefik, Vault — all DBs run as containers
- Already running: PostgreSQL, MongoDB, Neo4j, Qdrant, Redis (all via MCP)
- Current research output: markdown files in `artifacts/research/` per project (SQLite+FTS5 for per-project artifact DB)
- GPU: temporarily unavailable, but will return (for local model inference)
- Scale: currently 12 deep research runs, growing to hundreds+
- User is a data scientist with deep technical background — no need to simplify

## Known Prior Research
- 11 prior deep research folders exist (001D-011D) — these are the kind of outputs that would flow into this system
- Per-project SQLite+FTS5 artifact DB exists but doesn't cross project boundaries

## Output Configuration
- Research folder: artifacts/research/012D/
- Summary destination: artifacts/research/summary/012D-research-accumulation-db.md
- Topic slug: research-accumulation-db

## Special Instructions
- The user already has PG, MongoDB, Neo4j, Qdrant, and Redis running. Factor in operational complexity of adding vs. reusing existing infrastructure.
- Do NOT assume RAG is the goal — the user explicitly said this isn't about building RAGs or KGs per se, but about accumulating a rich, queryable personal knowledge base that COULD support those use cases on-demand.
- Evaluate PG+pgvector+AGE as a consolidated option seriously — the user raised it. Be honest about whether it's production-ready or still immature.
- For local model suggestions, be specific about model sizes, VRAM requirements, and what tasks they're actually good at vs. where API models are still better.
- Compare "extract every source into its own record" vs "keep sources embedded in reports" with concrete tradeoffs.
- The user values long-term compounding — sources reusable across reports, not locked to one research run.
