# Deep Research Prompt — 011D

## Research Question

What is the "inventor's notebook" (also: engineer's notebook, laboratory notebook, invention disclosure) — the formal documentation practice used in patent law, engineering, and R&D to record inventions, design decisions, experimental results, and development provenance? How does it work legally, what are modern digital implementations, and how can this concept be adapted for AI-assisted software development workflows where multiple AI agents collaborate on code?

## Sub-Questions

1. **Legal foundation**: What is the formal legal basis for inventor's notebooks? Trace from US patent law (pre-AIA "first to invent" interference proceedings through post-AIA first-to-file), trade secret law, and international IP frameworks (EPO, WIPO, PCT). What statutory and case law establishes their evidentiary value?

2. **Required elements**: What must a legally defensible inventor's notebook contain? Cover: conception records, reduction to practice, prior art awareness, design decisions with alternatives considered, experimental protocols and results, dates/timestamps, witness signatures, chain of custody, and non-obviousness documentation.

3. **Modern digital tools (ELNs)**: What electronic lab notebook (ELN) solutions exist? Survey commercial (LabArchives, Benchling, Dotmatics, PatSnap) and open-source options. What standards govern ELNs (FDA 21 CFR Part 11, EU Annex 11, ALCOA+)? How do they handle authentication, immutability, audit trails, and digital signatures?

4. **Patent prosecution value**: What specific documentation patterns strengthen patent claims during prosecution? How do examiners and courts evaluate notebook evidence? What distinguishes adequate from excellent documentation for patent support? Include inter partes review (IPR) and litigation contexts.

5. **First-to-file implications**: Under AIA's first-to-file system, notebooks no longer establish priority dates — but what residual legal value do they retain? Cover: trade secret documentation, prior user rights (35 USC 273), derivation proceedings, inventor oath support, and defensive publications.

6. **AI inventorship and patent law**: Deep-dive the legal landscape of AI-assisted invention. Cover: Thaler v. Vidal (DABUS), USPTO Feb 2024 guidance on AI-assisted inventions, EPO/UK positions, the "significant contribution" test, Pannu v. Iolab factors. How must human inventive contribution be documented when AI tools assist?

7. **AI contribution attribution**: What frameworks exist (or are emerging) for documenting the boundary between human inventive contribution and AI-assisted implementation? How should organizations document that a human conceived the invention while AI helped reduce it to practice?

8. **Software development adaptation**: How can the inventor's notebook concept be adapted for modern software development? Cover: git as an immutable log, commit messages as experiment records, design decision records (ADRs), RFC processes, and how these map to traditional notebook elements.

9. **AI-assisted development provenance**: What would a "development provenance notebook" look like for AI-assisted workflows where Claude, Codex, Gemini, Copilot, Cursor, and Vibe all contribute code? What needs to be captured: which agent wrote what, human direction/oversight at each step, inventive decisions vs. routine implementation, alternative approaches explored?

10. **Integration patterns for skill suites**: How could this be implemented as either (a) a dedicated skill, (b) a cross-cutting rule applied to all skills, (c) an enhancement to existing artifact/logging systems, or (d) a combination? Consider: cnotes.md collaboration logs, artifact DB entries, git hooks, and automated capture vs. manual annotation.

## Scope

- Breadth: exhaustive
- Time horizon: include historical (pre-AIA notebook requirements provide important context) through current (2024-2026 AI inventorship developments)
- Domain constraints: patent law, trade secret law, software engineering, AI-assisted development, electronic records management
- Special connector: Use Midpage Legal Research for case law (Thaler v. Vidal, Pannu v. Iolab, interference proceedings, IPR decisions, trade secret cases involving notebook evidence)

## Project Context

Claude Skills Suite — 42+ skills orchestrating multi-model AI development workflows. Key relevant patterns:
- **cnotes.md**: Existing collaboration log where all agents (Claude, Codex, Gemini, Copilot) write structured notes with 13 required fields (note_id, timestamp, author, activity_type, work_scope, files_touched, summary, details, validation, risks, handoff, next_actions)
- **Artifact DB**: SQLite+FTS5 store (`artifacts/project.db`) with helper functions for structured storage
- **Cross-cutting rules**: Applied by all skills automatically
- **Git history**: Full commit history with agent attribution
- **meta-review**: 10-11 lens review system that could feed decision documentation
- **meta-execute**: Multi-model implementation with Best-of-2 generation and 5-reviewer panels

The owner (Trevor Byrum) is a solo developer building AI-assisted development tooling. Interest is both in (a) using notebooks for his own IP protection and (b) building notebook capability into the skill suite as a feature for users.

## Known Prior Research

None — this is the first investigation on this topic.

## Output Configuration

- Research folder: artifacts/research/011D/
- Summary destination: artifacts/research/summary/011D-inventors-notebook-ip-provenance.md
- Topic slug: inventors-notebook-ip-provenance

## Special Instructions

- **Midpage Legal Research connector is available** — use it heavily for case law on inventor's notebooks, AI inventorship (Thaler/DABUS), trade secret notebook evidence, and patent prosecution. This is the first research using this connector — exercise it thoroughly.
- **AI inventorship is a priority area** — the USPTO Feb 2024 guidance and international positions are rapidly evolving. Get the latest.
- **Practical integration is the end goal** — don't just survey the law; synthesize actionable patterns for how an AI skill suite should capture provenance.
- Challenge the assumption that traditional notebooks map cleanly to software — find where the analogy breaks down.
- Look for any existing tools or frameworks that already solve "AI development provenance" even partially.
