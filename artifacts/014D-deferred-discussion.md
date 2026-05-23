# 014D Deferred Items — Circle Back

## 1. Stop Hook (from Phase 1a)
- Proposed: Stop hook that offers checkpoint commits (git diff → conventional commit message → approve/skip) + context snapshot to DB
- Questions to resolve: Should it auto-generate a simplified activity note (replacing cnotes)? Or just rely on git history? How heavy can a Stop hook be before it's annoying?
- Related: The daily push reminder (SessionEnd hook) also deferred

## 2. /iterate Skill (Phase 4a)
- Proposed: Lightweight execution skill for ad-hoc tweaking phases
- Design: Session-aware, 3-5 bullet checklist, auto-cnotes via hook, review offer after N changes
- Questions: How does it detect activation vs meta-execute? What triggers review offers? Does it update project-plan.md or maintain its own lightweight plan? How does it interact with /evolve?
- Key research: Every major AI dev tool has this mode (Cursor Composer, Windsurf Cascade, Aider conventions, OpenHands event log)

## 3. Phase 5 — Storage + Memory (all items)
- 5a: meta-context-save → append-only (db_write instead of db_upsert, timestamped labels)
- 5b: Session memory → Qdrant (SessionEnd hook extracts key facts, stores to shared collection, per-project tenant)
- 5c: Research → PostgreSQL (follow 012D/013D architecture, SQLite hot store, async sync to PG, pgai Vectorizer with API embeddings)
- 5d: Schema tracking (schema/ dir in scaffold, tables.sql, migrations/, schema.md ERD, breaking-change-review drift check)
- Dependency: GPU is down, but pgai Vectorizer supports API embeddings so PG migration can proceed. Qdrant server-side is operational.

## 4. CI/CD Awareness
- Session memory auto-population is prerequisite (Phase 5b)
- CI/CD skill would monitor GitHub Actions, react to failures, remember past deployment issues
- Lower priority than memory foundation

## 5. Schema Drift Detection
- schema/ directory in project scaffold
- breaking-change-review adds schema drift check
- AGENTS.md references schema/ so all agents know expected structure
