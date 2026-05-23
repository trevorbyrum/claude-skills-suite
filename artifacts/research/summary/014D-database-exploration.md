# Research 014D: Database Exploration for AI Agent Workspace

**Date**: 2026-03-31
**Objective**: Find databases beyond the usual suspects for a solo dev + homelab + AI agent workflow

---

## Tier 1: Strong Candidates (Best fit for the use case)

### 1. SurrealDB 3.0
- **What**: Multi-model database (document + graph + relational + time-series + vector + key-value) in a single Rust binary
- **Why it fits**: ONE database, ONE query language (SurrealQL), handles all data types. SurrealMCP gives AI agents native structured memory via MCP protocol. Docker-ready, self-hostable. Each project gets its own namespace/database natively.
- **Key feature**: Context graphs -- connects decisions, exploration logs, reviews as a graph while storing the actual content as documents. Vector search built in for semantic retrieval.
- **Agent story**: SurrealMCP launched Aug 2025. Claude, Codex, Cursor can read/write structured data via MCP with role-based access. Real-time subscriptions for live dashboards.
- **Maturity**: v3.0 GA (2026). Production-ready. Active development. 30k+ GitHub stars.
- **Docker**: `docker run --rm --pull always -p 8000:8000 surrealdb/surrealdb:latest start`
- **Namespace isolation**: Native. `USE NS project_a DB decisions;` per project.
- **License**: BSL 1.1 (converts to Apache 2.0 after 4 years)
- **Links**: [surrealdb.com](https://surrealdb.com), [SurrealMCP](https://surrealdb.com/mcp), [GitHub](https://github.com/surrealdb/surrealdb)

### 2. ArcadeDB
- **What**: Multi-model database (graph + document + key-value + time-series + vector + full-text) supporting 5 query languages
- **Why it fits**: True multi-model with native graph. Understands SQL, Cypher, Gremlin, GraphQL, and MongoDB query language. Time-series support added recently. Apache 2.0 license (genuinely open source). Lightweight Docker image.
- **Key feature**: Model decisions as graph nodes, exploration logs as time-series, reviews as documents -- all in one DB with one transaction.
- **Agent story**: Has an MCP server. Agents can write via any of the 5 query languages. SQL for simple inserts, Cypher for graph traversals of decision chains.
- **Maturity**: v25.3.1 (March 2026). Stable, production-ready. Conceptual fork of OrientDB.
- **Docker**: `docker run -d -p 2480:2480 -p 2424:2424 arcadedata/arcadedb:latest`
- **License**: Apache 2.0 (fully open source, no restrictions)
- **Links**: [arcadedb.com](https://arcadedb.com/), [GitHub](https://github.com/ArcadeData/arcadedb)

### 3. Gel (formerly EdgeDB)
- **What**: Graph-relational database built on PostgreSQL with a next-gen query language (EdgeQL)
- **Why it fits**: Thinks in objects and links, not tables and joins. Built-in migration system. Schema-first design perfect for structured agent output. Runs on top of Postgres but abstracts away the complexity.
- **Key feature**: EdgeQL produces rich structured objects, not flat rows. Deep fetching of related objects (decision -> rationale -> affected_files -> reviews) without JOINs.
- **Agent story**: Type-safe query builder in TypeScript. Agents can write structured data with schema validation built in.
- **Maturity**: Renamed from EdgeDB to Gel in Feb 2025. Stable, production-ready. Active development.
- **Docker**: Available via official Docker images
- **License**: Apache 2.0
- **Links**: [geldata.com](https://www.geldata.com), [GitHub](https://github.com/edgedb/edgedb)

### 4. Dolt / Doltgres
- **What**: SQL database with Git-like version control (branch, merge, diff, clone)
- **Why it fits**: Every change is versioned. You can branch a project's database, let an agent experiment, then merge or discard. Perfect for "exploration logs" -- you literally get a commit history of every data change. Diff any two points in time.
- **Key feature**: `DOLT_DIFF('decisions', 'HEAD~5', 'HEAD')` shows what changed. Branch per experiment. Merge findings back. MySQL-compatible wire protocol.
- **Agent story**: Agents write data normally via SQL. Every write is automatically versioned. You can review what any agent wrote, when, and roll back. Doltgres gives you PostgreSQL compatibility.
- **Maturity**: Dolt is stable/production. Doltgres is Beta (2025). Very active development.
- **Docker**: Available. Single binary.
- **License**: Apache 2.0
- **Links**: [dolthub.com](https://www.dolthub.com/), [GitHub](https://github.com/dolthub/dolt)

---

## Tier 2: Compelling Alternatives (Interesting for specific aspects)

### 5. HelixDB
- **What**: Graph-vector database built from scratch in Rust
- **Why it fits**: Combines graph traversal + vector similarity search in a single query. Sub-millisecond graph traversals. Purpose-built for AI retrieval patterns.
- **Key feature**: HelixQL (typed, compiled query language). Single query to "find decisions similar to X that are connected to project Y."
- **Maturity**: Early (YC 2025, London startup). Promising but young.
- **License**: Open source
- **Links**: [helix-db.com](https://www.helix-db.com/), [GitHub](https://github.com/HelixDB/helix-db)

### 6. TypeDB 3.0
- **What**: Hypergraph database with native reasoning engine
- **Why it fits**: N-ary relationships (a decision can connect to multiple entities through a single relation). Built-in deductive reasoning derives new conclusions from existing data. Strong semantics.
- **Key feature**: Define rules like "if a decision was made in context X and review Y flagged it, then it's a disputed_decision" and the DB infers this automatically at query time.
- **Agent story**: Knowledge base for LLMs. When agents query context, TypeDB can reason about connections they didn't explicitly create.
- **Maturity**: v3.0.0 released Dec 2024. Major rewrite. Established company (Vaticle).
- **License**: Mozilla Public License 2.0
- **Links**: [typedb.com](https://typedb.com/), [GitHub](https://github.com/vaticle/typedb)

### 7. KuzuDB
- **What**: Embedded property graph database (like "SQLite for graphs")
- **Why it fits**: Embedded (no server process), Cypher query language, vector search + full-text search built in. Written in C++, bindings for Python/Node/Rust/Go. Handles billions of edges on a single machine.
- **Key feature**: Import from Parquet/Arrow/DuckDB. Query graphs locally without running a server.
- **Maturity**: Active development, growing community. MIT license.
- **Limitation**: Embedded only -- no server mode. Would need a wrapper for multi-project access.
- **Links**: [kuzudb.com](https://docs.kuzudb.com/), [GitHub](https://github.com/kuzudb/kuzu)

### 8. XTDB
- **What**: Immutable bitemporal SQL database (every record tracked across two time dimensions)
- **Why it fits**: Perfect for "what did we know, and when did we know it?" queries. All data is immutable -- append-only. Built-in time-travel queries. SQL:2011 temporal standard.
- **Key feature**: Query "show me all decisions as they existed on March 15" or "when was this decision first recorded vs when did it actually happen."
- **Agent story**: Agents append events; nothing is ever deleted. Full audit trail of every AI decision and exploration.
- **Maturity**: v2.0 beta (2025). Written in Clojure/Java. Apache Arrow columnar engine.
- **Docker**: Available
- **License**: MPL 2.0
- **Links**: [xtdb.com](https://xtdb.com/), [GitHub](https://github.com/xtdb/xtdb)

### 9. TrailBase
- **What**: Sub-millisecond, single-binary backend (auth + API + DB + admin UI) built on Rust + SQLite + WASM
- **Why it fits**: PocketBase alternative but faster (11x). Single binary, Docker-ready. Built-in admin UI for exploring data. RESTful APIs + real-time subscriptions auto-generated from schema.
- **Key feature**: Type-safe APIs generated from SQLite schema. WebAssembly runtime for custom server logic. Vector search via sqlite-vec.
- **Agent story**: Agents hit REST APIs to write structured data. Admin UI for human review. Real-time subscriptions for live dashboards.
- **Maturity**: Newer project, actively developed. Based on proven components (SQLite, Axum).
- **License**: Open source
- **Links**: [trailbase.io](https://trailbase.io/), [GitHub](https://github.com/trailbaseio/trailbase)

### 10. Convex
- **What**: Open-source reactive database where queries are TypeScript functions running inside the DB
- **Why it fits**: Self-hostable (Docker). Queries are TypeScript -- agents already write TypeScript. Real-time reactivity built in. File storage, scheduling, search all included.
- **Key feature**: Define a `getDecisions` query in TypeScript. When data changes, all subscribed clients get updates instantly.
- **Agent story**: Agents call TypeScript functions that have direct DB access. Type-safe, serverless functions with ACID transactions.
- **Maturity**: Open-sourced recently. Production-ready (used by many apps). Self-hosting docs available.
- **License**: Open source
- **Links**: [convex.dev](https://www.convex.dev/), [GitHub](https://github.com/get-convex/convex-backend)

---

## Tier 3: Niche / Specialized (Worth knowing about)

### 11. EventSourcingDB
- **What**: Purpose-built event sourcing database (append-only event log)
- **Why it fits**: Every agent action becomes an event. Replay events to reconstruct state. CloudEvents standard format. HTTP API.
- **Limitation**: Free up to 25,000 events, then commercial license required.
- **Docker**: `docker run -it -p 3000:3000 thenativeweb/eventsourcingdb`
- **Links**: [eventsourcingdb.io](https://docs.eventsourcingdb.io/)

### 12. KurrentDB (formerly EventStoreDB)
- **What**: Mature event-native database. Globally ordered immutable event log.
- **Why it fits**: Best-in-class event sourcing. Lock-free appends, lightning-fast retrieval per stream. One stream per project, events per agent action.
- **Maturity**: Very mature (years of production use). Written in C#/.NET.
- **Docker**: Available
- **Links**: [kurrent.io](https://www.kurrent.io/), [GitHub](https://github.com/kurrent-io/KurrentDB)

### 13. LiveStore
- **What**: Event-sourced, reactive SQLite framework (local-first)
- **Why it fits**: All writes are mutation events in an eventlog. SQLite as the read model. Git-inspired push/pull sync. Created by Prisma's founder.
- **Limitation**: Primarily for web/app state management. Young project (just open-sourced 2025).
- **Links**: [livestore.dev](https://livestore.dev/), [GitHub](https://github.com/livestorejs/livestore)

### 14. FrankenSQLite
- **What**: Ground-up Rust reimplementation of SQLite with concurrent writers, page-level MVCC, and built-in encryption
- **Why it fits**: Solves SQLite's single-writer bottleneck. Multiple agents can write simultaneously to different pages. Built-in encryption. Fountain code repair for bit rot.
- **Limitation**: Very new (2025-2026). Pure safe Rust, zero unsafe blocks.
- **Links**: [frankensqlite.com](https://frankensqlite.com/), [GitHub](https://github.com/Dicklesworthstone/frankensqlite)

### 15. Limbo
- **What**: Turso's complete rewrite of SQLite in Rust with async I/O
- **Why it fits**: Async from the ground up (io_uring on Linux). WASM support. Deterministic simulation testing.
- **Limitation**: Work in progress. Not yet production-ready.
- **Links**: [turso.tech/blog](https://turso.tech/blog/introducing-limbo-a-complete-rewrite-of-sqlite-in-rust), [GitHub](https://github.com/tursodatabase/limbo)

### 16. SpacetimeDB
- **What**: Relational database that is also a server. Application logic runs inside the DB.
- **Why it fits**: Write schema + business logic as a module (Rust/TypeScript/C#). DB compiles it, runs it, auto-syncs to clients. 150k+ TPS benchmarked.
- **Limitation**: Designed for games/real-time apps. Unconventional architecture.
- **Links**: [spacetimedb.com](https://spacetimedb.com/), [GitHub](https://github.com/clockworklabs/SpacetimeDB)

### 17. Memori (by MemoriLabs)
- **What**: SQL-native memory layer for AI agents. Open source.
- **Why it fits**: Purpose-built for AI agent memory. Structured entity extraction, relationship mapping, SQL-based retrieval. Uses SQLite, PostgreSQL, MySQL, or MongoDB as backend.
- **Key feature**: Transparent, queryable AI memory with schema and constraints. Not just embeddings.
- **Links**: [memorilabs.ai](https://memorilabs.ai/), [GitHub](https://github.com/MemoriLabs/Memori)

### 18. GlueSQL
- **What**: SQL database engine in pure Rust with pluggable storage backends
- **Why it fits**: Write SQL queries against JSON files, localStorage, IndexedDB, Sled, or Redb. Same SQL, different backends.
- **Limitation**: More of an engine than a full database. Good for embedding SQL into tools.
- **Links**: [GitHub](https://github.com/gluesql/gluesql)

### 19. ParadeDB (pg_search)
- **What**: PostgreSQL extension for Elastic-quality full-text + hybrid (BM25 + vector) search
- **Why it fits**: If you do end up on Postgres, this eliminates the need for Elasticsearch. BM25 scoring + pgvector semantic search in one query. Built on Tantivy (Rust).
- **Links**: [paradedb.com](https://www.paradedb.com/), [GitHub](https://github.com/paradedb/paradedb)

### 20. Neon (Serverless Postgres with branching)
- **What**: Serverless Postgres with instant Copy-on-Write branching
- **Why it fits**: Every PR/experiment gets its own isolated database branch in <1 second. Scale to zero when idle. Acquired by Databricks for $1B.
- **Limitation**: Cloud-managed (not self-hosted, though open source). Postgres-based.
- **Links**: [neon.com](https://neon.com/), [GitHub](https://github.com/neondatabase/neon)

---

## Comparison Matrix: Top 5 for Your Use Case

| Feature | SurrealDB | ArcadeDB | Dolt | Gel | TypeDB |
|---|---|---|---|---|---|
| Multi-model | Doc+Graph+TS+Vec+KV | Doc+Graph+KV+TS+Vec+FTS | Relational only | Graph-relational | Hypergraph |
| Query language | SurrealQL | SQL/Cypher/Gremlin/GraphQL/Mongo | SQL (MySQL) | EdgeQL + SQL | TypeQL |
| MCP support | Yes (SurrealMCP) | Yes | No (SQL only) | No | No |
| Docker single binary | Yes (Rust) | Yes (Java) | Yes (Go) | Yes (Rust+PG) | Yes (Rust+Java) |
| Namespace per project | Native | Native (databases) | Database per project | Database per project | Database per project |
| Version control | No | No | Yes (Git for data) | Migrations | No |
| Time-travel queries | No | Time-series model | Yes (dolt_diff) | No | No |
| Graph traversals | Yes (native) | Yes (native) | No | Yes (links) | Yes (native) |
| Vector search | Yes | Yes | No | No (pgvector via PG) | No |
| Reasoning/inference | No | No | No | No | Yes (native) |
| License | BSL 1.1 | Apache 2.0 | Apache 2.0 | Apache 2.0 | MPL 2.0 |
| Maturity | v3.0 GA | v25.3 Stable | v1.x Stable | Stable (renamed) | v3.0.0 |
| Resource footprint | Light (Rust) | Medium (JVM) | Light (Go) | Medium (PG) | Medium (Rust+JVM) |

---

## Recommendation Summary

**If I had to pick ONE for this exact use case:**

**SurrealDB 3.0** -- It is the only database that natively handles documents, graphs, vectors, time-series, AND key-value in a single binary with a single query language, has native MCP support for AI agents, runs as a lightweight Docker container, and supports namespace isolation per project out of the box. The AI agent story is the strongest of any database in this list.

**Runner-up:** **ArcadeDB** -- If you want genuinely open source (Apache 2.0) with no licensing surprises, and you value being able to query the same data with SQL, Cypher, Gremlin, or GraphQL depending on what's convenient.

**Wildcard:** **Dolt** -- If versioning every change matters more than multi-model. Git-for-data is a genuinely unique capability that no other database offers. Perfect for "what did the agent write and when."

---

## Sources

- [SurrealDB](https://surrealdb.com) | [SurrealMCP](https://surrealdb.com/mcp)
- [ArcadeDB](https://arcadedb.com/) | [GitHub](https://github.com/ArcadeData/arcadedb)
- [Gel (EdgeDB)](https://www.geldata.com) | [GitHub](https://github.com/edgedb/edgedb)
- [Dolt](https://www.dolthub.com/) | [GitHub](https://github.com/dolthub/dolt)
- [HelixDB](https://www.helix-db.com/) | [GitHub](https://github.com/HelixDB/helix-db)
- [TypeDB](https://typedb.com/)
- [KuzuDB](https://docs.kuzudb.com/) | [GitHub](https://github.com/kuzudb/kuzu)
- [XTDB](https://xtdb.com/) | [GitHub](https://github.com/xtdb/xtdb)
- [TrailBase](https://trailbase.io/) | [GitHub](https://github.com/trailbaseio/trailbase)
- [Convex](https://www.convex.dev/) | [GitHub](https://github.com/get-convex/convex-backend)
- [EventSourcingDB](https://docs.eventsourcingdb.io/)
- [KurrentDB](https://www.kurrent.io/) | [GitHub](https://github.com/kurrent-io/KurrentDB)
- [LiveStore](https://livestore.dev/) | [GitHub](https://github.com/livestorejs/livestore)
- [FrankenSQLite](https://frankensqlite.com/) | [GitHub](https://github.com/Dicklesworthstone/frankensqlite)
- [Limbo](https://turso.tech/blog/introducing-limbo-a-complete-rewrite-of-sqlite-in-rust)
- [SpacetimeDB](https://spacetimedb.com/) | [GitHub](https://github.com/clockworklabs/SpacetimeDB)
- [Memori](https://memorilabs.ai/) | [GitHub](https://github.com/MemoriLabs/Memori)
- [GlueSQL](https://github.com/gluesql/gluesql)
- [ParadeDB](https://www.paradedb.com/) | [GitHub](https://github.com/paradedb/paradedb)
- [Neon](https://neon.com/) | [GitHub](https://github.com/neondatabase/neon)
- [Andy Pavlo: Databases in 2025 Review](https://www.cs.cmu.edu/~pavlo/blog/2026/01/2025-databases-retrospective.html)
- [PingCAP: Best Database for AI Agents](https://www.pingcap.com/compare/best-database-for-ai-agents/)
- [Medium: Databases built for AI and agentic applications](https://medium.com/@alipouw/databases-built-for-ai-and-agentic-applications-cca8d873be8a)
- [ML Mastery: Best AI Agent Memory Frameworks 2026](https://machinelearningmastery.com/the-6-best-ai-agent-memory-frameworks-you-should-try-in-2026/)
- [Local-First News](https://www.localfirstnews.com/2026-03-26/)
