# Deep Research Prompt — 013D

## Research Question
How should a high-volume AI research accumulation system be designed to ingest, enrich, deduplicate, and index both distilled research outputs AND individual worker/sub-agent reports — with specific focus on source extraction pipelines, pgai Vectorizer practical deployment, local model enrichment strategies, and schema design that maximizes long-term compounding value from hundreds-to-thousands of research runs?

This is a follow-up to 012D (research-accumulation-db) which established PostgreSQL + pgvector + pgai as the foundation. 013D focuses on **implementation specifics**.

## Sub-Questions

1. **Ingestion pipeline for structured markdown**: What is the best approach for parsing the specific output format of deep research runs? Each run produces: 1 dispatch table, 10-15 worker findings (research-connector), 3 coverage reviews, 1 addendum, 3-5 addendum findings, 9 debate papers (position/challenge/response × 3 perspectives), 1 convergence scoring, 1 source tally, and 1 final summary — totaling ~20-32 artifacts per run. These are stored in a SQLite artifact DB with (skill, phase, label, content) schema. What's the optimal extraction pipeline from SQLite→PostgreSQL?

2. **Source extraction from markdown**: Worker findings contain inline citations in various formats (URLs, DOIs, paper titles, "Author et al. (YYYY)" references). What are the best tools and techniques for extracting individual source records from semi-structured markdown? How accurate are regex vs LLM-based extraction approaches? What metadata should be captured per source, and how should partially-identified sources (e.g., "Author et al." with no URL) be handled?

3. **Claim extraction and atomization**: Research outputs contain claims at multiple granularities — executive summary bullets, per-sub-question findings, convergence scores, debate positions. How should atomic claims be extracted and stored? What constitutes a "claim" vs. a "finding" vs. a "recommendation"? How to handle confidence inheritance (a claim in the summary inherits from the debate that produced it)?

4. **pgai Vectorizer practical deployment**: Specific setup for a Docker-based homelab PostgreSQL instance. How does pgai Vectorizer work with Ollama for local embeddings? What's the SQL DDL for creating vectorizers on multiple tables? Performance characteristics at 100-1000 records? How to handle embedding model upgrades? What about embedding multiple fields per record (title vs full content vs claims)?

5. **Deduplication across research runs**: Sources frequently appear in multiple research runs. What deduplication strategies work best? DOI matching, URL normalization, fuzzy title matching, embedding similarity? How to merge metadata from multiple citations of the same source (one run has the URL, another has the DOI, a third has the abstract)?

6. **Local model enrichment pipeline**: When a GPU is available, what specific pipeline should run over accumulated research to maximize value? Options include: per-source summary generation, entity/relationship extraction, quality scoring, topic classification, claim-source linking, contradiction detection across runs. What's the priority ordering? What models at what sizes for each task? How to make this idempotent (re-runnable without duplication)?

7. **Schema design for worker reports**: The 012D schema has research_reports, sources, report_sources, and claims. How should worker_reports (individual sub-agent outputs) fit in? Should debate papers be stored differently than findings? Should coverage reviews and addendums be first-class entities? What relationships between worker reports, claims, and sources enable the most useful queries?

8. **Cross-run knowledge queries**: What specific query patterns become possible with this architecture? Examples: "What's the consensus across all runs about PostgreSQL vs MongoDB?", "Which sources appear most frequently?", "Show me all contested findings", "What topics have I researched that relate to X?". How should indexes and materialized views be designed to support these?

9. **Backfill strategy**: There are 118 existing artifacts across 8 research runs (~415KB of content) plus 10 summary files in the filesystem. What's the most efficient approach to backfill these into the new PG schema? Should backfill be manual, scripted, or LLM-assisted? How to handle the older runs that may have different formatting conventions?

10. **Integration with meta-deep-research-execute**: How should the existing skill be modified to write to PG after each run? Should it write incrementally (each worker writes as it completes) or batch (after all phases complete)? How to handle the current SQLite artifact DB — keep it as the hot working store and sync to PG, or replace it entirely?

## Scope
- Breadth: focused (implementation-specific, not broad architecture)
- Time horizon: recent only (2024-2026), with emphasis on current tooling
- Domain constraints: PostgreSQL extensions, pgai, embedding pipelines, local LLM inference, document parsing, knowledge management systems

## Project Context
- Homelab: Unraid tower, Docker containers, Traefik proxy
- PostgreSQL already running (Docker container, MCP tools available)
- Qdrant, Neo4j, MongoDB, Redis also running
- Current artifact DB: SQLite+FTS5 at `artifacts/project.db` with (id, skill, phase, label, content, created_at) schema
- Research output volume: ~20-32 artifacts per deep research run, 5+ runs per week trending upward
- GPU: temporarily unavailable but will return (for local model inference via Ollama)
- Ollama: already installed and configured
- User is a data scientist — can write Python, SQL, shell scripts. Deep Go expertise.

## Known Prior Research
- 012D (research-accumulation-db): Established PG+pgvector+pgai as foundation, 4-table schema, incremental build approach, local model recommendations. This research builds directly on 012D findings.

## Output Configuration
- Research folder: artifacts/research/013D/
- Summary destination: artifacts/research/summary/013D-research-ingestion-pipeline.md
- Topic slug: research-ingestion-pipeline

## Special Instructions
- This is implementation-focused research. Favor concrete code examples, SQL DDL, Python snippets, and specific tool configurations over architectural theory.
- The existing SQLite artifact DB structure is a GIVEN — the pipeline must extract from it. Don't redesign it.
- pgai Vectorizer is the embedding solution (per 012D). Research its practical usage, not alternatives.
- For local model tasks, specify exact model names, quantization levels, and VRAM requirements.
- The user runs 5+ deep research runs per week and each produces ~20-32 artifacts. Design for this throughput.
- Consider whether the ingestion should happen inside the Claude Code skill (at end of meta-deep-research-execute) or as a separate async pipeline (cron job, script, etc.).
- Evaluate whether the per-project SQLite should be kept as a hot working store with periodic PG sync, or whether PG should replace it entirely.
