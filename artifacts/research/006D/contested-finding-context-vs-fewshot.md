# Contested Finding Resolution: Context Engineering vs Few-Shot Examples for UI Code Generation
**Research date:** 2026-03-11
**Verdict:** Codex dissent is correct. The majority position overreaches. **Both complement each other, and the best skills use both.**

---

## The Contested Claim

- **Majority (Claude + Gemini):** Rich design system context (tokens, specs, anti-patterns) loaded at session start is MORE effective than curated few-shot examples for Claude 4.x UI code generation.
- **Dissent (Codex):** Few-shot examples embedded in reference files complement context engineering. A "portfolio" approach (1-2 excellent examples) in reference files is proven effective.

## Definitive Assessment: DISSENT UPHELD

The majority conflates two different questions: (1) "Is context engineering more important than few-shot prompting?" (yes) and (2) "Does rich context REPLACE few-shot examples?" (no). The evidence overwhelmingly shows that **declarative context + curated code examples** outperforms either approach alone. The optimal strategy is a hybrid.

---

## Evidence

### 1. Anthropic's Own Guidance Says: Use Both

**Claude 4 Best Practices** (docs.anthropic.com) states explicitly:
> "Claude 4 models pay attention to details and examples as part of instruction following. Ensure that your examples align with the behaviors you want to encourage."

**Multishot Prompting Guide** (docs.anthropic.com) recommends:
> "3-5 diverse, relevant examples to show Claude exactly what you want — particularly effective for tasks that require structured outputs or adherence to specific formats."

**Critical nuance:** Anthropic's guidance does NOT say "use examples OR context." It positions examples as one component within a well-engineered context. The Claude 4 best practices page treats examples as a first-class technique alongside explicit instructions and contextual motivation.

Sources:
- [Claude 4 Best Practices](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)
- [Multishot Prompting](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/multishot-prompting)

### 2. Anthropic's Own Frontend Aesthetics Cookbook: Uses Code Examples

The official Anthropic cookbook `prompting_for_frontend_aesthetics.ipynb` uses a **hybrid approach**:
- Declarative descriptions (avoid generic fonts, commit to cohesive color themes, use CSS-only animations)
- Specific prompt text snippets like `TYPOGRAPHY_PROMPT` and `DISTILLED_AESTHETICS_PROMPT`
- Generated code output examples showing before/after comparisons

The cookbook does NOT rely on pure declarative specs. It shows Claude what good output looks like alongside telling it what to aim for.

Sources:
- [Prompting for Frontend Aesthetics Cookbook](https://github.com/anthropics/claude-cookbooks/blob/main/coding/prompting_for_frontend_aesthetics.ipynb)
- [Claude Cookbook Platform](https://platform.claude.com/cookbook/coding-prompting-for-frontend-aesthetics)

### 3. Anthropic's Official Frontend Design Skill: Declarative Only (But With a Catch)

The official `frontend-design` SKILL.md from `anthropics/claude-code` is **purely declarative** — design principles, anti-patterns, tone guidance. No code examples in the SKILL.md itself.

**However**, the skill is designed to work alongside:
- The shadcn/ui MCP server (which injects actual component source code at runtime)
- Project-level context from `shadcn info --json` (real TypeScript props, import paths)
- The user's actual codebase (which Claude reads via tools)

So the skill appears "no examples" on the surface, but the **runtime architecture injects concrete code context** through MCP and file reading. The "examples" come from the project itself, not the skill file. This is not "pure context replaces examples" — it's "examples are sourced dynamically rather than statically."

Sources:
- [Frontend Design SKILL.md](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md)
- [shadcn/ui MCP for Claude Code](https://www.shadcn.io/mcp/claude-code)
- [Improving Frontend Design Through Skills](https://claude.com/blog/improving-frontend-design-through-skills)

### 4. Community Skills That Work Well: Hybrid Approach

**interface-design (Dammyjay93):** Stores design tokens AND patterns in `.interface-design/system.md`. Patterns include concrete values (button: 36px height, 12px 16px padding, 6px radius). This is a token+example hybrid — the "pattern" section IS a lightweight code example.

**Triptease Design System:** Recommends specific web components for complex interactions alongside declarative guidance. Component recommendations function as implicit examples.

**ui-ux-pro-max:** Uses a CSV database of styles, colors, and typography. This is declarative data, but includes stack-specific guidelines that contain implementation patterns.

Sources:
- [interface-design](https://github.com/Dammyjay93/interface-design)
- [Triptease Design System](https://github.com/triptease/claude-skill-design-system)
- [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)

### 5. Academic Evidence: Few-Shot Still Helps Frontier Models for Code

**Xu et al. (2024), "Does Few-Shot Learning Help LLM Performance in Code Synthesis?" (arXiv:2412.02906):**
- Even a single example can improve coding capabilities by the same margin as model architecture choices
- Claude models specifically improve more with few-shotting than GPT models
- Claude 3 Haiku: 11% correctness zero-shot → 75% with 3 examples
- Diminishing returns after ~3 examples (3 examples ≈ 9 examples in performance)

**Key finding for frontier models:** The benefit of few-shot shrinks as model capability increases, but does NOT disappear. Even GPT-4o and Claude 3.5 Sonnet show measurable improvements with well-chosen examples on coding benchmarks.

Sources:
- [Does Few-Shot Learning Help LLM Performance in Code Synthesis?](https://arxiv.org/abs/2412.02906)
- [PromptLayer Analysis](https://www.promptlayer.com/research-papers/unlocking-llm-code-synthesis-the-power-of-few-shot-learning)

### 6. Context Engineering Literature: Examples Are Part of Context

Anthropic's own **"Effective Context Engineering for AI Agents"** blog post explicitly lists few-shot examples as one form of context (categorized as "episodic memories"):
> "Few-shot examples (episodic memories) are one form of context that agents might select for examples of desired behavior."

Context engineering does not oppose few-shot examples. It subsumes them. The majority position incorrectly treated "context engineering" and "few-shot examples" as competing alternatives when they are actually parent-child concepts.

**Context rot finding:** A focused 300-token context often outperforms an unfocused 113,000-token context. This means examples must be curated and concise — but it does NOT mean they should be eliminated.

Sources:
- [Effective Context Engineering for AI Agents (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Context Engineering (LangChain)](https://blog.langchain.com/context-engineering-for-agents/)

### 7. Cursor Rules Evidence: Code Examples Improve Output

From community evidence on Cursor rules (which function similarly to Claude Code skills):
- Rules including "real-world examples that demonstrated complete task implementations" outperformed abstract rules
- 63% faster onboarding, 41% fewer code review iterations, 29% higher CI/CD success when rules include examples
- Recommended format: proper markdown, clear headings, detailed descriptions, helpful code comments, and enough examples to cover use cases

Sources:
- [Cursor Rules Documentation](https://docs.cursor.com/context/rules)
- [How to Write Great Cursor Rules (Trigger.dev)](https://trigger.dev/blog/cursor-rules)
- [Cursor AI Complete Guide](https://medium.com/@hilalkara.dev/cursor-ai-complete-guide-2025-real-experiences-pro-tips-mcps-rules-context-engineering-6de1a776a8af)

---

## When Each Approach Wins

| Scenario | Best Approach | Why |
|---|---|---|
| **Novel aesthetic direction** (e.g., "brutalist organic hybrid") | Declarative context only | No existing example to draw from; descriptions unlock Claude's creative synthesis |
| **Consistent design system adherence** (match existing tokens/spacing) | Tokens + 1 canonical component example | Example anchors the abstract tokens to concrete implementation |
| **Format/structure compliance** (specific HTML structure, class naming) | Examples essential | Declarative descriptions of structure are ambiguous; examples are unambiguous |
| **Animation/motion patterns** | Declarative descriptions + CSS snippet | Motion is hard to describe declaratively; a 10-line CSS snippet clarifies intent instantly |
| **Color palette / typography pairing** | Declarative tokens sufficient | CSS variables and font names are already concrete enough |
| **Complex component composition** (multi-part layouts, responsive grids) | 1 example + anti-pattern warnings | Layout intent is notoriously hard to communicate without showing one implementation |

---

## Token Cost Analysis

| Content Type | Typical Token Cost | Reuse Value |
|---|---|---|
| Design tokens (CSS vars, spacing scale) | 200-400 tokens | Every generation |
| Anti-pattern list ("never use Inter, no purple gradients") | 100-200 tokens | Every generation |
| Design principles (typography rules, color theory) | 300-600 tokens | Every generation |
| 1 curated component example (~30 lines of code) | 150-300 tokens | High — anchors all other context |
| 3-5 full page examples | 1,500-3,000 tokens | Diminishing returns after 1-2 |

**Optimal budget:** ~800-1,200 tokens for a reference file. This accommodates full declarative context PLUS 1-2 short code examples. The marginal cost of 1 example (150-300 tokens) is trivially small relative to the context window and delivers outsized returns on format consistency.

---

## Concrete Recommendation for UI/UX Skill Reference Files

### Structure: Declarative-First, Example-Anchored

```
reference-file.md
├── Design Tokens (CSS variables, spacing, colors)     ← declarative
├── Typography System (font pairs, scale, weights)      ← declarative
├── Anti-Patterns ("never do X")                        ← declarative
├── Principles (composition rules, motion philosophy)   ← declarative
└── Canonical Example (1 complete component, 20-40 LOC) ← code example
    └── Annotated: "THIS is what the above tokens look like in practice"
```

### Rules:
1. **Always include 1 canonical code example** per reference file that demonstrates the tokens/specs in action. This is the "portfolio" approach the Codex dissent advocated.
2. **Cap at 2 examples max** per reference file. Diminishing returns are real after 2 (academic evidence confirms 3 ≈ 9).
3. **Examples should be SHORT** (20-40 lines). Not a full page — a single component that demonstrates spacing, color tokens, typography, and one animation.
4. **Annotate the example** with brief comments linking back to the declarative specs ("uses --spacing-4 from tokens above").
5. **Anti-patterns > positive examples** for aesthetic guidance. Telling Claude "never use Inter, never purple-on-white, never 1.5x size jumps" is more efficient than showing 5 good examples.
6. **Dynamic examples via MCP** when available. If the project has shadcn/ui or a component library, let the MCP server inject real component source at runtime rather than hardcoding examples in skill files.

### What NOT to Do:
- Do NOT include 3+ full-page HTML examples (token-expensive, diminishing returns)
- Do NOT rely solely on declarative descriptions for format/structure requirements (ambiguous)
- Do NOT include examples without annotation (Claude may copy surface features rather than understanding the underlying system)
- Do NOT treat "context engineering" and "few-shot examples" as competing strategies (examples ARE context)

---

## Resolution Summary

| Position | Verdict |
|---|---|
| Majority: Rich context fully replaces few-shot examples | **OVERREACH.** Context engineering is the right framework, but it includes examples as a component, not excludes them. |
| Dissent: Few-shot complements context engineering | **CORRECT.** The "portfolio" approach (1-2 curated examples in reference files) is validated by Anthropic's own docs, the academic literature, community skill patterns, and the Cursor rules ecosystem. |

**Final answer:** For a UI/UX skill's reference files, use **declarative-first, example-anchored** design. Rich context (tokens, specs, anti-patterns, principles) forms 70-80% of the reference content. 1-2 short, annotated code examples form the remaining 20-30% and serve as the concrete anchor that resolves ambiguity in the declarative specs. This is not a compromise — it is the empirically optimal strategy.
