# Phase 27: Research Question Generator - Context

**Gathered:** 2026-02-19
**Status:** In progress (debate on data retrieval pending)

<domain>
## Phase Boundary

Add a PICO-framed research question synthesis preset to the document notebook. Users click a button and receive structured research questions derived from their papers' gaps, grouped by theme with per-question rationale citing specific papers.

**Key correction from discussion:** This belongs in the **document notebook only** (full-text papers), NOT the search notebook (abstracts only). Abstracts lack sufficient depth for meaningful gap analysis.

</domain>

<decisions>
## Implementation Decisions

### Output structure
- Questions grouped by theme (e.g., "Methodology gaps", "Population gaps") — not a flat numbered list
- Each question includes a per-question rationale (1-2 sentences) citing specific papers by author/title
- No intro paragraph — output jumps straight into the first theme heading
- Paper citations in rationale use author/title format (e.g., "Smith et al. (2023) found X but did not examine Y")

### Question framing
- PICO structure where natural — not forced on every question. Exploratory/qualitative gaps can use non-PICO framing
- PICO components written in natural language (no inline [P:] [I:] [C:] [O:] labels)
- No study type suggestions per question — keep to question + rationale only
- Gap-first prompting strategy: LLM identifies gaps in the corpus first, then derives questions from those gaps

### Scope & placement
- Document notebook only — search notebook abstracts are insufficient for gap analysis
- Quick/Thorough modes (like Overview)
- Button placed on the same row as Overview in the preset popover panel

### Content depth
- Quick mode: 5 questions with 1-sentence rationale
- Thorough mode: 5-7 questions with deeper 2-3 sentence rationale (same question count ballpark, richer detail)
- Works with as few as 1 paper — no minimum paper requirement

### Data retrieval (pending)
- Debate conducted between Full-corpus SQL vs RAG top-k
- Recommendation was Full-corpus SQL (follows Overview pattern, enables implicit gap detection)
- **User has not yet confirmed** — resume discussion to finalize

### Claude's Discretion
- Exact theme category labels (emerge from the corpus)
- Prompt engineering for gap identification
- Batching strategy if corpus exceeds context window (follow Overview pattern)

</decisions>

<specifics>
## Specific Ideas

- Gap-first approach: prompt should explicitly instruct LLM to scan the corpus for gaps, then generate questions per gap
- Citations should feel grounded — "Smith et al. (2023) found X but did not examine Y" style, not vague references

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-research-question-generator*
*Context gathered: 2026-02-19 (in progress — data retrieval decision pending)*
