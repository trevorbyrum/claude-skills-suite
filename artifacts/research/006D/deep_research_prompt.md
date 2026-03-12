# Deep Research Prompt — 006D

## Research Question
What are the best practices, principles, and optimal structure for building a dedicated UI/UX generation and design system skill for Claude Code — one that produces sleek, minimal, modern interfaces that look intentionally designed (not generic AI output)?

## Sub-Questions

1. **Ecosystem scan:** Do any Claude Code plugins, Cursor rules, Copilot extensions, v0 configs, Bolt templates, or other AI coding tools ship dedicated UI/UX skills/rules? What do they cover, and are they any good?

2. **Optimal tech stack for Claude:** Which frontend frameworks, CSS approaches, component libraries, and tooling does Claude Code generate the best UI code with? (React vs Svelte vs Vue, Tailwind vs CSS Modules vs styled-components, shadcn/ui vs Radix vs headless, etc.) — empirical evidence preferred over opinion.

3. **AI-generated UI anti-patterns:** What are the telltale signs of "AI-generated UI"? Generic layouts, inconsistent spacing, accessibility gaps, over-reliance on rounded corners, etc. How do you avoid them?

4. **Design system enforcement:** How should a skill encode and enforce a design system — tokens (colors, spacing, typography), component patterns, layout rules? What level of prescription works vs. what becomes too rigid?

5. **Modern aesthetic principles:** Best practices for glassmorphism, liquidmorphism, neomorphism, and minimal/sleek design. When to use each. Common mistakes. How to encode these as actionable rules rather than vague vibes.

6. **Accessibility + aesthetics tension:** How to maintain WCAG compliance while pursuing aggressive modern aesthetics. Specific patterns that achieve both. What the "Apple-level design that's also accessible" playbook looks like.

7. **Skill architecture:** Should this be one monolithic UI/UX skill or decomposed (e.g., ui-generate, design-system, ui-review, accessibility-check)? Tradeoffs of each approach. How do existing skill suites (like this one with 37 skills) handle scope creep?

8. **Reference file strategy:** What reference materials should the skill ship with? (Token files, component catalogs, example screenshots, anti-pattern galleries, checklists?) What format works best for LLM consumption?

9. **Generation vs. review:** Should the skill focus on generating UI code from descriptions, reviewing existing UI code for quality, or both? How do other tools split this?

10. **Prompt engineering for UI:** What prompt patterns, system instructions, and few-shot examples produce the best UI output from Claude specifically? Any research or community findings on this?

## Scope
- Breadth: exhaustive
- Time horizon: include historical context but weight toward 2024-2026 (post-Claude 3 era)
- Domain constraints: frontend web UI. Mobile and native are secondary. Focus on what Claude Code can actually generate/review in a terminal workflow.

## Project Context
This is for a Claude Code skill suite (37 skills, 10 agents, 7 hooks) that orchestrates Claude + Gemini + Codex. The user's design philosophy:
- "Sleek, minimal, holy shit this is nice — Steve Jobs taste"
- Glassmorphism, liquidmorphism, neomorphism (mix per project)
- Documents at Fortune 500 consulting quality
- The skill must produce output that does NOT look like generic Claude UI/UX

The skill suite already has review lenses (security, compliance, completeness, refactor, test, drift, counter) and meta-skills that orchestrate multiple sub-skills. A UI/UX skill could follow similar patterns.

## Known Prior Research
- 003D: test-review upgrade research
- 004D: meta-production upgrade research
- 005D: free tools augmentation research
- None specifically on UI/UX

## Output Configuration
- Research folder: artifacts/research/006D/
- Summary destination: artifacts/research/summary/006D-uiux-skill-design.md
- Topic slug: uiux-skill-design

## Special Instructions
- **Challenge the assumption** that a UI/UX skill is a good idea. Present honest counterarguments.
- **Find real examples** of AI coding tools with UI/UX guidance. Don't fabricate — if nothing exists, say so.
- **Tech stack investigation must be empirical** — find benchmarks, community reports, or practical evidence of which stacks Claude generates best UI code with. Not just "React is popular."
- **Anti-generic mandate:** The #1 requirement is that output doesn't look like every other AI-generated UI. Research what makes AI UI look generic and how to escape it.
- **Practical structure:** End with a concrete proposed skill structure (files, references, architecture) that could be implemented.
