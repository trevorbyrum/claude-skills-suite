# Deep Research: Inventor's Notebook & IP Provenance for AI-Assisted Development

> Research folder: research/011D/
> Date: 2026-03-24
> Models: Opus 4.6 (orchestrator + reasoning), self-consistency debate (3 perspectives)
> CLIs: Codex/Gemini unavailable — redistributed to WebSearch + Scholar Gateway
> MCP connectors used: Scholar Gateway, WebSearch, GitHub, Hugging Face, Midpage (subscription required — fallback to WebSearch)
> Debate rounds: 3 (position, challenge, convergence)
> Addendum cycle: yes — patent prosecution practices, AI copyright/SBOM standards, human contribution documentation
> Sources: 102 queries | 1,051 scanned | 184 cited
> Claims: 4 verified, 3 high, 3 contested, 0 debunked

## Executive Summary

- **VERIFIED**: Inventor's notebooks were critical under pre-AIA first-to-invent system for establishing priority dates through conception and reduction to practice documentation. Under AIA first-to-file (2013+), they lost this priority function but retain significant residual legal value.
- **VERIFIED**: AI cannot be named as inventor under any major patent jurisdiction. Thaler v. Vidal (Fed. Cir. 2022) held "individual" means natural person. EPO, UK, WIPO concur. No jurisdiction recognizes AI inventorship.
- **VERIFIED**: The USPTO's November 2025 revised guidance eliminated the separate "significant contribution" standard for AI-assisted inventions, rescinding the February 2024 Vidal guidance. Same inventorship rules apply regardless of AI use. Pannu factors only apply between human co-inventors.
- **VERIFIED**: Software development already maps to most traditional notebook elements through git (timestamps, authorship, immutability), ADRs (design decisions, alternatives), and code review (informal witnessing). Key gaps: formal witnessing, alternatives not chosen, and inventive intent documentation.
- **HIGH**: Five residual functions of notebooks under first-to-file: trade secret documentation (highest value), prior user rights defense (35 USC 273), derivation proceedings (35 USC 135), inventor oath support, and defensive publication evidence.
- **HIGH**: Modern ELN market is mature (LabArchives, Benchling, SciNote) but lab-focused. Software development needs a different toolset combining git-native attribution (Git-AI, Agent Trace, RAI footers) with structured decision records (ADRs).
- **HIGH**: Documentation of human inventive contribution when using AI tools is now a best practice per USPTO Nov 2025 guidance: record conception before AI use, document prompt iterations and human selections, maintain timestamps showing inventor's role throughout.
- **CONTESTED**: Whether detailed AI provenance tracking (PROV-AGENT model) is practical for day-to-day development. Academic framework exists but production tooling is nascent; overhead concerns are valid.
- **CONTESTED**: Whether prior user rights (35 USC 273) have practical value — no reported invocation in 12+ years despite AIA expansion. Trade secret documentation is the clearly higher-value application.
- **CONTESTED**: Optimal integration pattern for skill suite — cross-cutting auto-capture vs. dedicated skill vs. over-engineering risk. Consensus leans toward lightweight automatic capture (80% of value) with optional formal disclosure trigger.

## Confidence Map

| # | Sub-Question | Confidence | Agreement | Finding |
|---|---|---|---|---|
| 1 | Legal foundation | VERIFIED | 3/3 | Notebooks critical pre-AIA; reduced but still valuable post-AIA |
| 2 | Required elements | HIGH | 2/3 + concession | Nine elements; witness can be digital; corroboration by independent evidence mandatory |
| 3 | Modern ELN tools | HIGH | 2/3 + redirect | Lab ELNs mature but wrong fit for software; git-native tools emerging |
| 4 | Patent prosecution value | VERIFIED | 3/3 | Documentation strengthens claims; examiner interviews reduce prosecution 1.5x |
| 5 | First-to-file residual | CONTESTED | 2/3 | Trade secret docs = highest value; prior user rights theoretically valuable but untested |
| 6 | AI inventorship (DABUS) | VERIFIED | 3/3 | AI cannot be inventor; same standard applies; Nov 2025 guidance is current law |
| 7 | AI contribution attribution | HIGH | 2/3 | Emerging tools (Git-AI, Agent Trace, RAI footers) exist but immature; USPTO guidance clear |
| 8 | Software dev adaptation | VERIFIED | 3/3 | Git+ADRs map well; gaps in witnessing, intent, alternatives documentation |
| 9 | AI development provenance | CONTESTED | 2/3 | PROV-AGENT framework exists; practical scope-limiting needed; minimum viable approach recommended |
| 10 | Skill suite integration | CONTESTED | 2/3 | Combination approach optimal; weight toward auto-capture; avoid over-engineering |

## Detailed Findings

### SQ-1: Legal Foundation of Inventor's Notebooks

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Inventor's notebooks have deep roots in US patent law, serving as primary evidence in interference proceedings under the pre-AIA "first to invent" system. The notebook documented two critical milestones: conception (the "definite and permanent idea" of the complete invention) and reduction to practice (building/testing a working version or filing a patent application). Under the AIA's first-to-file system effective March 16, 2013, notebooks lost their priority-establishing function but retained significant legal value for other purposes.

**Evidence**:
- 35 USC 100(f) defines "inventor"; 35 USC 115 requires inventor oath; 35 USC 135 governs derivation proceedings
- Valentine, Zhang & Zheng (2025), J. Accounting Research: Found strategic scientific disclosure behavior changed after AIA, with firms increasing publications to block competitors in lagging patent classes
- Corroboration doctrine: inventor testimony must be independently corroborated (Federal Circuit precedent); Federal Circuit (2023) held "only minimal evidence" needed to satisfy corroboration in priority contests
- International frameworks: EPO, WIPO, PCT all require human inventor identification at filing; WIPO SCP/37 actively assessing AI and inventorship policy

**Debate**: All perspectives agreed on historical and current legal framework. Adversarial perspective noted many companies never had formal notebook programs even pre-AIA, but this does not challenge the legal foundation itself.

---

### SQ-2: Required Elements for Legal Defensibility

**Confidence**: HIGH
**Agreement**: 2/3 + concession

**Finding**: A legally defensible inventor's notebook must contain nine core elements: (1) conception records, (2) reduction to practice documentation, (3) prior art awareness, (4) design decisions with alternatives considered, (5) experimental protocols and results, (6) dates/timestamps, (7) witness signatures, (8) chain of custody, and (9) non-obviousness documentation. The corroboration standard requires independent evidence beyond the inventor's own testimony. Assignment language is critical — Stanford v. Roche demonstrated that "hereby assigns" (present tense) vs. "agrees to assign" (future promise) determined IP ownership.

**Evidence**:
- Stanford v. Roche, 563 U.S. 776 (2011): Minor wording difference in assignment language cost Stanford IP rights
- Chowdhury & Gargate (2024), SAGE Journals: IP management role of laboratory notebooks in academic/research organizations
- Wallert & Provost (2013), Biochemistry and Molecular Biology Education: Integrating SOPs and industry notebook standards
- Finnegan (2023): Corroborating evidence must be independent of inventor testimony; physical exhibits need dates and authorship

**Debate**: Adversarial perspective challenged witness signature requirement as impractical for remote/distributed teams. Pragmatist conceded this is addressable through digital signatures and code review approvals, which all parties accepted.

---

### SQ-3: Modern Digital Tools (ELNs)

**Confidence**: HIGH
**Agreement**: 2/3 + redirect

**Finding**: The commercial ELN market is mature with strong players (LabArchives for academia, Benchling for biotech at $5-7K/user/year, Scispot for AI-powered workflows). Open-source options exist (SciNote with GLP compliance, Indigo ELN for chemistry, both actively maintained on GitHub). Regulatory standards are well-established: FDA 21 CFR Part 11 for electronic records/signatures, ALCOA+ for data integrity (Attributable, Legible, Contemporaneous, Original, Accurate + Complete, Consistent, Enduring, Available, Traceable), and EU Annex 11 for computerised systems. However, all major ELNs are designed for laboratory research, not software development.

**Evidence**:
- Scispot (2026) Top 15 ELN Vendors: Comprehensive vendor comparison based on real user reviews
- scinote-eln/scinote-web (GitHub): Active development, last pushed March 2026
- FDA Oct 2024 guidance: Finalized Part 11 requirements for clinical investigations
- ISPE Pharmaceutical Engineering (2025): Dynamic Data Integrity — ALCOA evolution analysis
- 2025 enforcement: CDER warning letters jumped 50%; data integrity enforcement accelerated 73% in H2 2025

**Debate**: Pragmatist redirected: lab ELNs are the wrong tool for software developers. The real requirement is immutable timestamps + attribution + searchable content + audit trail, which can be achieved through git-native tools and knowledge management systems. All parties agreed on this reframing.

---

### SQ-4: Patent Prosecution Value

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Documentation strengthens patent claims during prosecution through several mechanisms. Detailed invention disclosures help examiners understand the invention and distinguish it from prior art. Well-structured dependent claims provide fallback positions. Examiner interviews (which average 1.5-1.6 fewer Office Actions) work best when supported by clear written documentation of the inventive concept. The duty of candor (37 CFR 1.56) requires disclosure of information material to patentability. In IPR proceedings, inventor testimony requires corroboration, and notebooks/documentation serve this function. Modern invention disclosure forms (IDFs) collected through innovation management software are the corporate standard.

**Evidence**:
- Nutter IP Law: Examiner interview best practices showing 1.5-1.6 Office Action reduction
- USPTO MPEP 2103: Patent examination process documentation
- Finnegan: Practical considerations in prosecuting US patent applications
- Federal Register (2022): Duties of disclosure and reasonable inquiry during examination
- Dilworth IP: Best practices for drafting invention disclosure forms

**Debate**: No material disagreement. All perspectives agreed documentation is valuable for prosecution.

---

### SQ-5: First-to-File Residual Value

**Confidence**: CONTESTED
**Agreement**: 2/3

**Finding**: Under the AIA first-to-file system, inventor's notebooks retain five residual functions: (1) Trade secret documentation — the highest-value application, documenting existence and scope of trade secrets for litigation; (2) Prior user rights defense (35 USC 273) — expanded by AIA to all subject matter, requires proof of commercial use 1 year before patent filing; (3) Derivation proceedings (35 USC 135) — proves true inventor when another files without authorization; (4) Inventor oath support — contemporaneous evidence of who actually conceived; (5) Defensive publication evidence — creating prior art to block competitor patents.

**Evidence**:
- Baker Botts (2023): Prior user rights defense particularly relevant for software; no reported invocations
- Global Health Solutions v. Selner (Fed. Cir. 2025): First Federal Circuit derivation proceeding — 4-hour conception timing difference was decisive
- FJC Trade Secret Case Management Judicial Guide (2023): Federal court standards for trade secret identification
- Major trade secret verdicts: $764M Motorola v. Hytera (2020), $605M Proper Fuels v. Phillips 66 (2024), $452M Insulet v. Eoflow (2024)
- Bernstein.io: Blockchain + IPFS for defensive publishing with hash-based proof without disclosure

**Debate**: Adversarial perspective challenged practical value of prior user rights (never invoked) and derivation proceedings (one case in 12 years). Majority position: trade secret documentation is clearly the highest-value function, and the mere existence of other defenses has deterrent value even if rarely invoked. The adversarial concern about defensive publications destroying trade secret protection (contradictory strategies) was acknowledged as a valid tension requiring strategic choice.

**Majority** (Claude, Pragmatist): Trade secret documentation alone justifies continued notebook use. Prior user rights and derivation proceedings are insurance policies.
**Dissent** (Adversarial): The insurance is expensive relative to its demonstrated value. Solo developers should focus on trade secret documentation and filing speed, not notebook formality.

---

### SQ-6: AI Inventorship and Patent Law (DABUS)

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Universal global consensus: AI cannot be named as inventor. Thaler v. Vidal, 43 F.4th 1207 (Fed. Cir. 2022) held that "individual" in the Patent Act means natural person. The UK Supreme Court reached the same conclusion in Thaler v. Comptroller. EPO, WIPO, and Germany all require human inventors.

The critical current guidance is the USPTO's November 28, 2025 revised inventorship guidance, which rescinded the February 2024 Vidal guidance entirely. Key changes: (a) eliminated separate standard for AI-assisted inventions; (b) clarified Pannu joint inventorship factors only apply between multiple human inventors, not human+AI; (c) AI tools treated identically to laboratory equipment; (d) same inventorship rules apply regardless of whether AI was used.

The practical implication: human inventors must document their "definite and permanent idea" of the invention, including problem framing, design choices, and why they selected or modified AI-generated outputs. Patent counsel should advise R&D teams to maintain logs of AI usage including prompts, versions, changes, and human selections.

**Evidence**:
- Thaler v. Vidal, 43 F.4th 1207 (Fed. Cir. 2022): "Individual" = natural person; Supreme Court denied cert
- Federal Register 2025-21457 (Nov 28, 2025): Revised inventorship guidance for AI-assisted inventions
- Matulionyte (2024), Modern Law Review: Analysis of UK Supreme Court Thaler decision
- Igbokwe (2024), J. World Intellectual Property: Legal personhood and inventorship threshold
- Gibson & Newman (2020), AI Magazine: USPTO determined only humans can be inventors
- IPWatchdog (Nov 2025): "Don't Ask, Don't Tell" characterization of new policy

**Debate**: All perspectives agreed on legal status. Adversarial raised concern about perverse incentive to simply not disclose AI use ("don't ask, don't tell"). This is a policy critique, not a factual dispute — all agreed it is the current practical reality.

---

### SQ-7: AI Contribution Attribution Frameworks

**Confidence**: HIGH
**Agreement**: 2/3

**Finding**: Several frameworks are emerging for documenting the boundary between human inventive contribution and AI-assisted implementation:

1. **USPTO Nov 2025 Guidance** (legal framework): Record conception before/during AI use; document prompts, iterations, selections; use timestamps; structured inventor-interview checklists
2. **Git-AI** (code-level tool): Git extension fingerprinting AI-generated code at creation; Git Notes for metadata without modifying history; git-ai blame shows AI attribution per line; open source, offline-first
3. **Cursor Agent Trace** (specification): Open RFC (Jan 2026) for JSON-based trace records connecting code ranges to conversations; vendor-neutral; storage-agnostic
4. **RAI Footers** (convention): Git commit trailer standard using Assisted-by, Co-authored-by, Signed-off-by; pairs human HITL review with AI attribution
5. **PROV-AGENT** (academic framework): W3C PROV extension for agentic workflows; captures full prompt/response/model/telemetry chain; IEEE e-Science 2025

No established legal standard exists for AI contribution documentation beyond the USPTO guidance. All technical tools are less than 1 year old and untested in court.

**Evidence**:
- Federal Register 2025-21457: Documentation requirements for AI-assisted inventions
- usegitai.com: Git AI Standard v3.0.0 specification
- agent-trace.dev / Cursor (Jan 2026): Open specification for AI code attribution
- Souza et al. (2025), IEEE e-Science: PROV-AGENT framework
- DEV Community: RAI footer standard articles and implementation guides

**Debate**: Adversarial challenged tool maturity — all less than 1 year old with no court testing. Valid but does not rebut their existence or utility. Standard proliferation (Git-AI vs. Agent Trace vs. RAI footers) is a legitimate concern; no winner yet.

---

### SQ-8: Software Development Adaptation

**Confidence**: VERIFIED
**Agreement**: 3/3

**Finding**: Traditional inventor's notebook elements map to software development practices as follows:

| Traditional Element | Software Equivalent | Gap Level |
|---|---|---|
| Conception record | ADR + initial design doc/RFC | Low |
| Reduction to practice | Working code + passing tests | None |
| Prior art awareness | Related work in ADR, dependency review | Low |
| Design decisions | ADR (alternatives considered) | Low |
| Experimental results | Test results, benchmarks, CI logs | None |
| Timestamps | Git commit timestamps | Low* |
| Witness signatures | Code review approvals | Medium |
| Chain of custody | Git log + access controls | Low |
| Non-obviousness | ADR rationale for novel approach | Medium |

*Git timestamps can be manipulated through force push/rebase.

Key gaps where the analogy breaks down:
- **Formal witnessing**: Code review is collaborative, not a legal attestation. No one "signs and dates" confirming they understand the invention.
- **Alternatives not chosen**: ADRs capture considered alternatives at architecture level, but micro-decisions (why this algorithm vs. that one) are typically lost.
- **Inventive intent**: Software commits capture what was built, not why it's novel or inventive.
- **Immutability**: Git is cryptographically strong but can be rewritten (force push, rebase); blockchain timestamping addresses this.

**Evidence**:
- Nygard (2011), Cognitect: Original ADR proposal — "Documenting Architecture Decisions"
- AWS Architecture Blog (2025): Master ADRs best practices
- Google Cloud Architecture Center: ADR overview and implementation
- Microsoft Azure Well-Architected Framework: Maintain an ADR
- adr-mcp (GitHub): MCP server auto-generating MADR-formatted ADRs from conversation context
- joelparkerhenderson/architecture-decision-record (GitHub): Comprehensive ADR template collection

**Debate**: All perspectives agreed on the mapping and gaps. No material disputes.

---

### SQ-9: AI-Assisted Development Provenance

**Confidence**: CONTESTED
**Agreement**: 2/3

**Finding**: A "development provenance notebook" for AI-assisted workflows should capture:
- **Which agent wrote what**: Agent identity (Claude, Codex, Gemini, Copilot, Cursor, Vibe), model version, timestamp
- **Human direction at each step**: Prompt/task description (summarized, not full text), human decision to accept/modify/reject output
- **Inventive decisions vs. routine implementation**: Flag decisions where human exercised inventive judgment (selected approach, identified problem, framed solution) vs. routine coding (implement known pattern, fix syntax, add boilerplate)
- **Alternative approaches explored**: What was tried and rejected, with brief rationale

The most complete academic framework is PROV-AGENT (Souza et al., 2025), which extends W3C PROV-DM with agent-centric entities, activities, and relations. It integrates agent tools, prompt/response interactions, model invocations, and telemetry into a unified provenance graph. Compatible with CrewAI, LangChain, OpenAI.

For code-level attribution, Git-AI and Cursor Agent Trace provide practical line-level tracking. The RAI footer convention provides lightweight commit-level attribution.

**Evidence**:
- Souza et al. (2025), IEEE e-Science: PROV-AGENT framework for agentic workflow provenance
- Thomer et al. (2018), JASIST: Research Process Modeling using W3C PROV for noncomputational provenance
- Curcin (2016), Learning Health Systems: Embedding data provenance for reproducible research
- usegitai.com: Git AI documentation on tracking AI code provenance
- Cursor Agent Trace specification: JSON-based trace records

**Debate**: Adversarial challenged: (a) PROV-AGENT is academic, not production-ready; (b) capturing every prompt/response is enormous overhead; (c) no evidence provenance logs have legal value; (d) risk of over-documentation creating discoverable liability. Pragmatist proposed scope-limiting: minimum viable provenance = agent identity + summarized task + human decision points. Full prompt capture only for flagged "inventive" decisions. This remains contested — the right granularity depends on risk tolerance.

**Majority** (Claude, Pragmatist): Tiered provenance with automatic lightweight capture and optional detailed capture for inventive decisions.
**Dissent** (Adversarial): Overhead and liability risk may outweigh benefit for solo developers. Existing git history + commit messages may be sufficient.

---

### SQ-10: Integration Patterns for Skill Suites

**Confidence**: CONTESTED
**Agreement**: 2/3

**Finding**: Four integration patterns were evaluated:

**(a) Dedicated skill** — A standalone `/provenance` or `/invention-disclosure` skill that generates formal invention disclosure documents from project context. Best for: rare, high-value events (patentable innovation identified). Risk: low adoption if friction is high.

**(b) Cross-cutting rule** — Applied to all skills automatically, capturing provenance metadata (agent, timestamp, files, human direction) in every interaction. Best for: comprehensive coverage with zero friction. Risk: overhead on every invocation; noise.

**(c) Enhancement to existing systems** — Extend cnotes.md template with alternatives-considered field and inventive-flag field; add provenance metadata to artifact DB entries. Best for: leveraging existing infrastructure. Risk: may not be legally rigorous enough.

**(d) Combination** — Recommended approach, with weights:
- Cross-cutting rule (80% of value): Lightweight auto-capture of agent identity, timestamps, files touched, and human direction summary. Zero friction. Feeds artifact DB.
- cnotes.md enhancement (15% of value): Add "alternatives_considered" and "inventive_contribution" fields to the 13 existing required fields. Captures the missing notebook elements.
- Dedicated skill (5% of value): Formal invention disclosure generator, triggered explicitly by human when patentable innovation is recognized. Outputs structured IDF to artifact DB.

The existing cnotes.md already captures 8 of 9 traditional notebook elements. The missing element is "alternatives considered" — what was tried and rejected.

**Evidence**:
- Existing cnotes.md: 13 required fields (note_id, timestamp, author, activity_type, work_scope, files_touched, summary, details, validation, risks, handoff, next_actions)
- Artifact DB: SQLite+FTS5 with db_write, db_upsert, db_read, db_search
- Cross-cutting rules: Applied by all skills automatically
- adr-mcp: Precedent for auto-generating ADRs from conversation context

**Debate**: Adversarial challenged need for any formal system beyond existing cnotes.md + git. Argued over-engineering risk for a solo developer. Pragmatist agreed on risk but proposed the combination approach with emphasis on the lightweight auto-capture layer (essentially enhancing what already exists rather than building new infrastructure). This remains contested on the question of whether even the lightweight enhancement is worthwhile.

**Majority** (Claude, Pragmatist): Combination approach (d) with heavy weight on auto-capture and cnotes.md enhancement.
**Dissent** (Adversarial): Existing systems may be sufficient. Any addition should be justified by specific IP protection needs identified by a patent attorney.

## Addendum Findings

The mandatory coverage expansion cycle identified three emergent topics:

### Emergent Topic: AI Copyright and Code Attribution
**Why it surfaced**: Multiple search results referenced copyright implications alongside patent issues
**Finding**: US Copyright Office (Jan 2025 report) confirmed AI-generated works lack copyright protection without sufficient human creative control. The Doe v. GitHub Copilot lawsuit (ongoing, Ninth Circuit) has surviving claims on open-source license violation and breach of contract. Courts are treating open-source licenses as enforceable agreements. This creates a dual incentive for provenance documentation: both patent inventorship (who conceived) and copyright authorship (who created the expression) need human attribution documentation.
**Impact on original question**: Strengthens the case for provenance tracking — documentation serves both patent and copyright protection simultaneously.

### Emergent Topic: AIBOM (AI Bill of Materials) Standards
**Why it surfaced**: SBOM standards are being extended to cover AI-specific metadata
**Finding**: CycloneDX 1.7 (2025) added patent/IP metadata and data provenance citations. SPDX 3.0.1 introduced formal AI and Dataset profiles with 36 AI-specific fields. OWASP AIBOM project is standardizing the approach. A Frontiers paper (2026) addresses "operationalising AIBOMs for verifiable AI provenance and lifecycle assurance." US EO 14028 requires SBOM for federal software; EU CRA introduces SBOM requirements for products with digital elements.
**Impact on original question**: AIBOM standards provide an industry-recognized format for documenting AI contributions that may have more legal weight than custom solutions. The skill suite could generate AIBOM-compliant provenance records.

### Emergent Topic: EU AI Act Documentation Requirements
**Why it surfaced**: August 2026 transparency provisions create new documentation obligations
**Finding**: The EU AI Act requires providers of AI systems to maintain technical documentation covering model architecture, training, performance, and decision-making rationale. Transparency provisions take effect August 2, 2026. Penalties: up to 35M EUR or 7% global turnover. NIST AI RMF 1.0 provides a US framework with parallel documentation requirements.
**Impact on original question**: For skill suite users operating in EU markets, AI development provenance documentation may become legally required, not just best practice.

## Contested Findings

### 1. Practical Value of Prior User Rights (35 USC 273)
**Majority** (Claude, Pragmatist): Theoretically valuable defense for software developers who maintain trade secrets. Baker Botts (2023) specifically identified software as a key application area. The defense's existence creates deterrent value even if rarely invoked.
**Dissent** (Adversarial): Zero reported invocations in 12+ years since AIA expanded the defense. The university exception limits its use. Solo developers should prioritize filing speed over documentation for this specific purpose.
**Impact**: Low practical impact for the skill suite. Trade secret documentation is the higher-value application of the same provenance data.

### 2. Granularity of AI Provenance Capture
**Majority** (Claude, Pragmatist): Tiered approach — automatic lightweight capture for all interactions, detailed capture only for flagged inventive decisions. Minimum viable: agent identity, summarized task, human decision points.
**Dissent** (Adversarial): Any provenance capture adds overhead and creates potentially discoverable material. Full prompt/response logging creates liability. Existing git history with Co-Authored-By trailers may be the correct ceiling.
**Impact**: High practical impact. The skill suite implementation must choose a granularity level. Recommend: start lightweight, provide opt-in for detailed capture.

### 3. Need for Formal System Beyond Existing Tools
**Majority** (Claude, Pragmatist): Combination approach adds two low-cost enhancements (cnotes.md fields + cross-cutting auto-capture) to existing infrastructure. Cost is minimal; IP protection value is non-trivial.
**Dissent** (Adversarial): Solo developers should consult a patent attorney before building IP documentation systems. The skill suite risks providing a false sense of legal protection.
**Impact**: The dissent's point about consulting patent counsel is valid and should be reflected in any implementation as a disclaimer.

## Open Questions

No claims reached UNCERTAIN or UNRESOLVED status. However, two forward-looking questions merit monitoring:

1. **Will courts accept blockchain timestamps as patent-relevant evidence in the US?** French courts accepted them (March 2025) but US precedent is absent. Monitor for cases.
2. **Will Agent Trace or Git-AI emerge as the dominant standard?** Both are less than 1 year old. Standards convergence will take 2-3 years. Recommend: support both via generic metadata format.

## Debunked Claims

No claims were debunked through debate. One potential misconception was preemptively addressed:
- **Misconception**: "Under first-to-file, inventor's notebooks are obsolete." **Reality**: They retain five distinct residual functions, with trade secret documentation being the most valuable.

## Source Index

### Academic Sources
- Valentine, Zhang & Zheng (2025). Strategic Scientific Disclosure: Evidence from the AIA. J. Accounting Research, 63(4), 1723-1755.
- Matulionyte (2024). 'AI is not an Inventor': Thaler v Comptroller. Modern Law Review, 88(1), 205-218.
- Igbokwe (2024). Human to Machine Innovation. J. World Intellectual Property, 27(2), 149-174.
- Gibson & Newman (2020). What Happens When AI Invents. AI Magazine, 41(4), 96-99.
- Chowdhury & Gargate (2024). IP Management Role of Laboratory Notebooks. SAGE Journals.
- Souza et al. (2025). PROV-AGENT: Unified Provenance for Tracking AI Agent Interactions. IEEE e-Science.
- Curcin (2016). Embedding Data Provenance into the Learning Health System. Learning Health Systems, 1(2).
- Thomer et al. (2018). Documenting Provenance in Noncomputational Workflows. JASIST, 69(10), 1234-1245.
- Frey et al. (2012). MyExperimentalScience: Extending the Workflow. Concurrency and Computation, 25(4), 481-496.
- Wallert & Provost (2013). Integrating SOPs and Industry Notebook Standards. Biochemistry and Molecular Biology Education, 42(1), 41-49.
- Johnston et al. (2013). Using an ePortfolio System as Electronic Laboratory Notebook. Biochemistry and Molecular Biology Education, 42(1), 50-57.
- Frontiers in Computer Science (2026). Operationalising AIBOMs for Verifiable AI Provenance.
- Ramli et al. (2023). AI as Object of IP in Indonesian Law. J. World Intellectual Property, 26(2), 142-154.
- Farooq et al. (2022). Patent Law Failure: A Systematic Literature Review. J. World Intellectual Property, 25(2), 579-588.

### Legal Sources (Case Law & Statutes)
- Thaler v. Vidal, 43 F.4th 1207 (Fed. Cir. 2022)
- Pannu v. Iolab Corp., 155 F.3d 1344 (Fed. Cir. 1998)
- Stanford v. Roche, 563 U.S. 776 (2011)
- Global Health Solutions v. Selner (Fed. Cir. 2025)
- Doe v. GitHub, Inc. (N.D. Cal., ongoing)
- 35 USC 100, 115, 135, 273
- Federal Register 2025-21457 (USPTO Nov 2025 Revised Guidance)
- Federal Register 2024-02623 (USPTO Feb 2024 Original Guidance — rescinded)

### Official Documentation & Standards
- USPTO MPEP 2103, 2138.05, 2310
- FDA 21 CFR Part 11 (Electronic Records; Electronic Signatures)
- ALCOA+ Principles (FDA/EMA/MHRA data integrity framework)
- EU AI Act (Regulation 2024/1689), Articles 13 and 50
- NIST AI RMF 1.0 (NIST.AI.100-1)
- W3C PROV Data Model (PROV-DM)
- CycloneDX 1.7 Specification
- SPDX 3.0.1 AI and Dataset Profiles
- Git AI Standard v3.0.0
- Cursor Agent Trace Specification v0.1.0

### Web Sources
- IPWatchdog (Nov 2025): USPTO's "Don't Ask, Don't Tell" Policy
- Brownstein (Dec 2025): USPTO Revised Guidance — What It Means for Patent Strategy
- Mayer Brown (Dec 2025): USPTO Revised Guidance on AI-Assisted Inventions
- Jones Day (Dec 2025): USPTO Revises Guidance on AI-Assisted Inventorship
- Goodwin (Dec 2025): Key Takeaways for AI/ML Innovators
- Baker Botts (2023): Defending Prior Software Use With 35 USC 273
- Finnegan: New Prior-User-Rights Defense — What Trade Secret Holders Need
- FJC (2023): Trade Secret Case Management Judicial Guide
- Nutter: Best Practices for Examiner Interviews
- Thompson Patent Law: Patent Documentation Mistakes — Stanford v. Roche Story
- Saveri Law Firm: GitHub Copilot IP Litigation
- US Copyright Office (Jan 2025): Copyright and AI Part 2 — Copyrightability
- Scispot (2026): Top 15 ELN Vendors
- SBOM formats: CycloneDX vs SPDX comparison (2026)
- ARDURA Consulting: SBOM 2026 Mandatory Requirements

### Code and Tool Sources
- github.com/scinote-eln/scinote-web — Open source ELN
- github.com/epam/Indigo-ELN-v.-2.0 — Chemistry ELN
- github.com/git-ai-project/git-ai — AI code attribution extension
- github.com/cursor/agent-trace — AI code trace specification
- github.com/abest0/adr-mcp — ADR MCP server
- github.com/joelparkerhenderson/architecture-decision-record — ADR templates
- github.com/microsoft/code-with-engineering-playbook — Engineering best practices including AI attribution
- usegitai.com — Git AI documentation
- agent-trace.dev — Agent Trace specification site

### Source Tally
| Track | Queries | Scanned | Cited |
|---|---|---|---|
| Track A (Opus reasoning / Midpage fallback) | 34 | 315 | 50 |
| Track B (Connectors: Scholar, GitHub, HF, Web) | 48 | 506 | 80 |
| Track C (redistributed to WebSearch) | 10 | 115 | 32 |
| Track D (redistributed to WebSearch) | 10 | 115 | 22 |
| **TOTAL** | **102** | **1,051** | **184** |

## Methodology

This research was conducted using the multi-model deep research protocol with the following adaptations:

**Worker Allocation**: Opus 4.6 served as orchestrator and primary reasoning engine. Codex and Gemini CLIs were unavailable; their work was redistributed to WebSearch queries and Scholar Gateway searches (per error handling protocol). This made the research single-model with self-consistency debate rather than cross-model.

**Debate Structure**: Three-perspective self-consistency approach — (1) Primary researcher (evidence-forward), (2) Devil's advocate (challenging conventional wisdom, questioning practical value), (3) Pragmatist (technical grounding, scope-limiting). Three rounds: position papers, challenges, convergence responses.

**Addendum Cycle**: Mandatory coverage expansion identified three emergent topics (AI copyright, AIBOM standards, EU AI Act documentation) that were not in the original prompt but directly impact the skill suite integration question. These were researched and integrated.

**Confidence Scoring**: Claims were scored by agreement across the three perspectives, weighted by evidence quality (academic papers > official docs > engineering blogs > forums > LLM inference) and recency (2025-2026 weighted highest).

**Note on Midpage Legal Research**: The connector required an active subscription and was unavailable. Case law research was conducted through WebSearch queries targeting legal databases (Justia, BitLaw, law firm analyses) and Scholar Gateway. This reduced the depth of case law analysis compared to what Midpage would have provided, but the key cases (Thaler, Pannu, Stanford v. Roche) were thoroughly covered through secondary sources.

Intermediate artifacts are stored in the artifact DB under `meta-deep-research-execute` and `research-connector` skills, all labels prefixed with `011D/`.
