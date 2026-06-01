# Interview Prompt Structure

Reference for `/init`'s interview phase. Inline (not subagented) — Claude asks via `AskUserQuestion` directly. This file is the question-shape template.

## Question categories (order)

Adapt depth per pathway:
- Greenfield → all categories, full depth
- Join-existing → categories 1, 3, 4 scoped to "your contribution," skip 2 (already in codebase)
- Sub-project → categories 1, 3 scoped to "the sub-project's slice," skip 2 (inherited)
- Pivot → only what's NEW about the direction; don't re-interview on inherited parts

---

### 1. Problem & users

**Goal**: surface what's being built and for whom. Without this, every later answer is guesswork.

Sample questions (adapt phrasing):
- "What's the one-sentence pitch for this project?"
- "Who uses it? Be specific — 'people' isn't useful, 'solo backend devs on small teams' is."
- "What does success look like for those users? What changes in their workflow if this works?"

Anti-pattern: don't accept "everyone" or "anyone who could benefit." Push for concrete.

---

### 2. Tech stack & deployment

**Goal**: nail down the runtime so later choices flow from it.

Sample questions:
- "What languages / frameworks do you want? Or is that open?"
- "Where does this run? Local CLI / self-hosted / cloud / shipped to end-users?"
- "Database (or no)? Auth (or no)? External services (which)?"

If user says "open" to all: probe with "what are you most comfortable with?" Default to user's stack.

---

### 3. Constraints

**Goal**: surface hard limits early so the plan doesn't propose impossible work.

Sample questions:
- "Anything regulatory? GDPR, HIPAA, SOC2, PCI?"
- "Scale ceiling? 1 user / 100 / 10k / millions?"
- "Hard deadline? Or open-ended?"
- "Budget concerns — managed services OK, or self-host everything?"

Skip questions that are obvious from context (a personal CLI doesn't need a GDPR conversation).

---

### 4. Out-of-scope

**Goal**: explicit non-goals. Often more clarifying than the in-scope list.

Sample questions:
- "What does this project EXPLICITLY NOT do? (Even if a user asks — you'd say no.)"
- "What features have you considered and ruled out? Why?"

If the user can't answer, ask "What is the simplest version of this that still solves the core problem?" Out-of-scope is often implicit.

---

### 5. Key decisions already made

**Goal**: capture things the user has decided that the plan must respect.

Sample questions:
- "Decisions you've already made that I shouldn't second-guess?"
- "Hard 'no's on approaches? (e.g. 'no Kubernetes,' 'no SaaS dependencies')"
- "Names / brand / interface conventions already fixed?"

---

### 6. Risks

**Goal**: surface known unknowns before they become surprises.

Sample questions:
- "What worries you most about this project?"
- "Anything you suspect will be hard but haven't validated?"
- "Anything in this domain you've been burned by before?"

The answers feed `project-context.md`'s "Risks" section AND `project-plan.md`'s "Risks" table.

---

## Pace and discipline

- **Aim for 8-15 questions total** across all categories for greenfield. Fewer for the other modes.
- **One question at a time** via `AskUserQuestion`. Don't batch multi-question prompts unless they're genuinely independent (use multi-select for those).
- **Follow up only when the answer is non-actionable**. "I don't know" is a valid answer — capture it as a Risk and move on.
- **Don't lecture**. The interview is for collecting; the context doc is where synthesis happens.

## Output

The interview produces a structured notes file. Don't write it to disk — keep it in-context for the context-write phase (Phase 2d in greenfield, equivalent in other modes).

Notes structure:
```markdown
## Interview notes — <date>

### Problem & users
- <answer>
- <answer>

### Tech stack
- <answer>

(...etc per category)

### Open items
- <anything the user couldn't answer; carries into Risks>
```
