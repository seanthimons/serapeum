# Feature Research

**Domain:** Academic Research Assistant — Synthesis Presets (v4.0 Stability + Synthesis)
**Researched:** 2026-02-18
**Confidence:** MEDIUM-HIGH

---

## Scope

This research covers three new features planned for the v4.0 milestone, evaluated against
what comparable tools (Elicit, SciSpace, Consensus, ResearchRabbit, AnswerThis) actually
do in production:

1. **Unified Overview preset** (#98) — merge Summarize + Key Points into one output
2. **Literature Review Table** (#99) — structured per-paper comparison matrix
3. **Research Question Generator** (#102) — suggest new research directions from corpus

Existing features that these depend on are already shipped:
- Summarize preset (generate_preset "summarize")
- Key Points preset (generate_preset "keypoints")
- Conclusion synthesis (generate_conclusions_preset)
- Research gap synthesis
- RAG retrieval (search_chunks_hybrid via ragnar)
- Markdown rendering in chat window
- Chat export (Markdown/HTML)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Unified Overview output (Summary + Key Points in one call)** | Running two separate presets to get a complete picture is awkward; every major tool (Elicit, SciSpace) defaults to a combined overview | LOW | Merge Summarize + Key Points prompts into one system prompt; single LLM call; output two named sections in markdown; replaces two buttons with one |
| **Literature Review Table with standard academic columns** | Researchers doing lit reviews expect a paper-by-paper comparison table as the primary structured output; Elicit built its entire product around this feature | MEDIUM | Columns: Paper/Author/Year, Methodology, Sample Size, Key Findings, Limitations; markdown table output rendered in chat; must handle 5–30 papers without exceeding context window |
| **Per-paper citation attribution in table** | Each row in a comparison table must map to a specific source paper; researchers need to verify claims | LOW | Already have source attribution pattern from build_context(); extend to include source metadata per row |
| **Research questions grounded in corpus gaps** | Researchers expect gap-to-question flow: "what gaps exist?" naturally leads to "what should I study next?"; AnswerThis and Elicit both do this | MEDIUM | Build on existing gap analysis output (generate_conclusions_preset already has "Research Gaps" section); research question generator reads the gap output as input context |
| **Consistent markdown output formatting** | All synthesis outputs already render markdown in chat window; new presets must match this contract | LOW | Use same system prompt structure as existing presets; headings + bullet points + citation format |
| **AI-generated content disclaimer on new outputs** | Already required by existing presets; omitting it on new features would be inconsistent | LOW | Copy existing disclaimer injection pattern from mod_document_notebook.R / mod_search_notebook.R |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Custom dimension columns in Literature Review Table** | Elicit allows user-defined extraction columns ("Relevance to biotic interactions", "Model organisms"); SciSpace lets users define column prompts; local-first version would let user specify 1-2 custom columns before running | HIGH | Requires UI input (text field for custom column prompt) + dynamic prompt construction; deferred — ship fixed standard columns first, validate demand before adding custom |
| **PICO-structured research questions for health/bio fields** | PICO (Population, Intervention, Comparison, Outcome) is the gold standard framework in biomedical research; tools like INRA.AI and PICOT generators show demand; optional PICO framing of suggested questions differentiates for medical/nursing researchers | MEDIUM | Add "PICO format" toggle in Research Question Generator; restructure output template when enabled; only valuable for health/biomedical subfields — gate behind option |
| **Methodology Extractor preset** (#100) | Isolated methodology focus (study design, instruments, statistical methods) is a distinct need from general overview; useful for researchers designing their own study | MEDIUM | Separate preset from Overview; uses section-targeted RAG (methods section); complements Literature Review Table |
| **Gap Analysis Report preset** (#101) | Explicit gap analysis as a named preset (vs buried in Conclusions) validates research directions more formally; AnswerThis built their product around this feature | MEDIUM | Upgrade current "Research Gaps" section in generate_conclusions_preset into its own standalone preset; use same section-targeted RAG pattern |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Interactive table with editable cells** | Researchers want to annotate and correct AI extraction errors inline | Requires full table state management in Shiny (reactiveValues per cell); significant UI complexity for v4.0; export workflow already handles this | Export table to CSV; user edits in Excel/Sheets; re-import not needed since table is synthesis output |
| **Auto-refresh table on new papers added** | "I added a paper, now update the table" | Table generation is an expensive LLM call; auto-triggering on reactive changes would cause accidental API spend; ragnar store updates are already async | Keep table generation manual (button-triggered); show "papers changed since last run" badge as a hint to re-run |
| **CSV export specifically for Literature Review Table** | Researchers want to move the comparison matrix to other tools | Adds export infrastructure complexity when chat export (Markdown) already handles this adequately for v4.0; markdown tables are copy-pasteable | Markdown table export via existing chat download handles this; add CSV-specific export only if user demand validated post-v4.0 |
| **Fully autonomous table column selection** | "Let the AI decide what columns to extract" | Without user-specified columns, the LLM picks inconsistent dimensions across runs; re-runs produce different structures making longitudinal comparison impossible | Fixed standard column set for v4.0; optional user-defined columns as v4.x feature after column stability is validated |
| **Research question scoring/ranking** | "Which question is most promising?" | Requires LLM to judge LLM outputs; adds another API call; ranking is subjective and domain-specific; researchers are better judges of their own field priorities | Present 5-7 unranked research questions; researcher selects; keeps LLM in supportive role |
| **Real-time streaming for table generation** | Show cells populating as the LLM generates | Parsing structured markdown tables from a streaming response is fragile; partial tables render as broken markdown | Generate full response then render; show spinner with status message during generation |

---

## Feature Dependencies

```
[Unified Overview preset]
    └──depends on──> [generate_preset() infrastructure] (already exists)
    └──replaces──> [Summarize preset] + [Key Points preset] (merge, don't delete)
    └──enhances──> [Chat export] (output available for download immediately)

[Literature Review Table]
    └──depends on──> [Per-paper metadata in DB] (title, author, year — already exists in abstracts table)
    └──depends on──> [build_context() pattern] (already exists in rag.R)
    └──requires──> [Structured prompt producing markdown table] (new)
    └──optionally enhances──> [Chat export to Markdown/CSV] (table in markdown is already exportable)

[Research Question Generator]
    └──depends on──> [Gap analysis capability] (partially exists in generate_conclusions_preset)
    └──enhances──> [Gap Analysis Report preset] (#101, separate feature)
    └──works best with──> [Conclusion synthesis output as input context] (can chain)

[Gap Analysis Report preset] (#101)
    └──depends on──> [generate_conclusions_preset infrastructure] (refactor, not rebuild)
    └──enhances──> [Research Question Generator] (gap list feeds question generation)

[Methodology Extractor preset] (#100)
    └──depends on──> [section_filter in search_chunks_hybrid] (already exists — "methods" section hint)
    └──depends on──> [generate_preset() infrastructure] (already exists)
```

### Dependency Notes

- **Overview replaces but does not delete Summarize/Key Points:** The existing buttons may remain as secondary options; Overview becomes the primary recommended preset
- **Literature Review Table depends on paper metadata:** The abstracts table already has title/author/year; document notebook needs doc name — both are available via build_context()
- **Research Question Generator chains well after Gap Analysis:** A two-step flow (run Gaps first, then Questions) produces better output than running Questions cold; consider a "Generate Questions from this analysis" follow-up button
- **Methodology Extractor depends on section hints:** The ragnar section_filter feature (already built in Phase 18/19) enables methods-section-targeted retrieval; without it, methodology extraction from full-text PDFs is noisier

---

## MVP Definition

### v4.0 Launch With

Minimum feature set for the milestone.

- [ ] **Unified Overview preset** (#98) — single LLM call, two-section output (Summary + Key Points); replaces the two-button pattern; LOW complexity
- [ ] **Literature Review Table** (#99) — fixed standard columns (Title, Year, Methodology, Sample Size, Key Findings, Limitations); markdown table in chat; works for search notebooks (abstracts) and document notebooks (PDFs); MEDIUM complexity
- [ ] **Research Question Generator** (#102) — 5-7 suggested questions grounded in identified gaps; output as numbered markdown list with rationale; MEDIUM complexity

### Add After Validation (v4.x)

- [ ] **Gap Analysis Report preset** (#101) — extract gap analysis out of Conclusions into its own named preset; value depends on user demand signal
- [ ] **Methodology Extractor preset** (#100) — methods-section-targeted extraction; valuable but dependent on having PDFs with clear section hints
- [ ] **PICO-structured output option for Research Questions** — add toggle for health/biomedical field researchers; defer until field usage validated

### Future Consideration (v5+)

- [ ] **Custom column prompts in Literature Review Table** — user-defined extraction dimensions; requires UI design investment
- [ ] **CSV export for Literature Review Table** — dedicated CSV export (vs markdown); defer until post-v4.0 demand confirmed
- [ ] **Argument Map / Claims Network** (#104) — high complexity, niche use case

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Unified Overview preset (#98) | HIGH | LOW | P1 |
| Literature Review Table (#99) | VERY HIGH | MEDIUM | P1 |
| Research Question Generator (#102) | HIGH | MEDIUM | P1 |
| Gap Analysis Report preset (#101) | HIGH | MEDIUM | P2 |
| Methodology Extractor preset (#100) | HIGH | MEDIUM | P2 |
| PICO output option | MEDIUM | MEDIUM | P3 |
| Custom table columns | MEDIUM | HIGH | P3 |
| CSV export for table | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for v4.0 launch
- P2: Should have, add in v4.x if capacity allows
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | Elicit | SciSpace | AnswerThis | Serapeum v4.0 Approach |
|---------|--------|----------|------------|------------------------|
| **Overview/Summary** | Multi-paper summary with citations | Paper-level summaries; combine manually | Combined summaries with citations | Single-call Overview preset merging Summary + Key Points |
| **Literature Review Table** | Core product feature; 35 pre-defined columns + custom; 99.4% accuracy claim | Custom column prompts on uploaded PDFs; methodology/findings/limitations default | Not primary feature | Fixed 5-column table (Title, Year, Methodology, Sample Size, Findings, Limitations); markdown output |
| **Research Question Generator** | Not a named feature; gap identification available | Not explicitly offered | "Instant Gap Analysis" → implies next questions | 5-7 numbered questions with gap rationale; optionally chains from gap analysis output |
| **Gap Analysis** | Implicit in research report | Available as column | Primary differentiator | Standalone preset (#101) built from existing Conclusions synthesis |
| **Export** | CSV, BibTeX, Zotero | CSV, BibTeX, Zotero, Mendeley | PDF report | Markdown/HTML (existing); table markdown is copy-pasteable |
| **Local/private** | Cloud-only | Cloud-only | Cloud-only | **Key differentiator** — all data stays local; no API calls to extract data (only to LLM) |

---

## Implementation Notes for Each Feature

### Feature 1: Unified Overview Preset (#98)

**What it is:** Replace separate Summarize and Key Points presets with one "Overview" button that produces both in a single LLM call.

**Prompt structure:**
```
System: You are a research synthesis assistant. Generate an Overview of the provided sources.

OUTPUT FORMAT:
## Summary
[3-5 paragraph narrative synthesis of main themes, arguments, and findings]

## Key Points
- [Bullet 1 — most important finding or concept]
- [Bullet 2]
...
[7-10 bullets total]

Cite sources using [Document Name] or [Paper Title] format throughout.
```

**Complexity:** LOW. Modify `generate_preset()` to add `overview` type. Replace two buttons in `mod_document_notebook_ui()` and `mod_search_notebook_ui()` with one.

**Existing buttons:** Keep Summarize + Key Points as secondary options (don't delete); make Overview the primary/recommended button.

---

### Feature 2: Literature Review Table (#99)

**What it is:** A structured per-paper comparison matrix. For each paper in the notebook, extract: Title/Author/Year, Methodology, Sample Size, Key Findings, Limitations.

**Standard column set (v4.0):**
1. Paper (Title, First Author, Year)
2. Study Design / Methodology
3. Sample / Dataset
4. Key Findings
5. Limitations

**Prompt structure:**
```
System: You are a research extraction assistant. For each source provided, extract structured data.

OUTPUT FORMAT:
Produce a markdown table with these exact columns:
| Paper | Study Design | Sample | Key Findings | Limitations |
|-------|-------------|--------|--------------|-------------|
| [Title (Author, Year)] | [methodology] | [N=X or dataset description] | [main findings, 1-2 sentences] | [stated limitations] |

Rules:
- One row per source paper
- Use "Not reported" when the source does not mention a field
- Do not invent data; only extract what is explicitly stated
- Keep each cell concise (max 40 words per cell)
```

**Complexity:** MEDIUM. New function `generate_literature_table()` in `rag.R`. Needs context-building that passes per-paper metadata (not just chunks). May need to restructure context so LLM can attribute each row to the correct source.

**Context challenge:** The current `build_context()` pools all chunks. For a per-row table, the LLM needs to see one paper's content per row. For search notebooks (abstracts), this is straightforward — one abstract per paper. For document notebooks (PDFs), context needs to be grouped by document. Consider a `build_context_per_paper()` variant.

**Hallucination risk:** HIGH for numerical data (sample sizes, effect sizes). Mitigate with:
- Explicit "Not reported" instruction (prevents LLM from inventing numbers)
- Disclaimer in output reminding user to verify numerical claims

---

### Feature 3: Research Question Generator (#102)

**What it is:** Analyze the corpus to suggest 5-7 specific, researchable questions that address identified gaps or unexplored dimensions.

**Input strategy:** Two modes:
1. **Cold start:** Retrieves gap-relevant chunks directly (uses same query as Conclusions preset)
2. **Chained:** User first runs Conclusions/Gap Analysis, then clicks "Generate Research Questions from this analysis" — passes previous output as additional context (higher quality)

**Prompt structure:**
```
System: You are a research design consultant. Based on the provided sources and their identified gaps, suggest specific, feasible research questions that could advance the field.

OUTPUT FORMAT:
## Suggested Research Questions

For each question, provide:
**RQ[N]: [Question text]**
*Rationale:* [1-2 sentences explaining what gap this addresses and why it is answerable]

Rules:
- Generate 5-7 questions
- Questions must be specific enough to be researchable (not "more research is needed on X")
- Ground each question in an explicit gap or limitation from the sources
- Include methodological hints where appropriate ("using longitudinal design", "in population X")
```

**Complexity:** MEDIUM. New function `generate_research_questions()` in `rag.R`. The cold-start path reuses `search_chunks_hybrid()` with gap-focused query. The chained path requires passing prior synthesis output as context.

---

## Complexity vs. Value Summary

| Feature | Complexity | v4.0 Value | Key Risk |
|---------|------------|------------|----------|
| Unified Overview (#98) | LOW | HIGH — immediate UX improvement for all users | None significant |
| Literature Review Table (#99) | MEDIUM | VERY HIGH — core research workflow, highly requested | Per-paper context grouping; hallucination in numerical fields |
| Research Question Generator (#102) | MEDIUM | HIGH — completes gap→question workflow | Quality depends on corpus size; weak corpus = generic questions |

---

## Sources

**Competitor Features:**
- [Elicit: AI for Scientific Research](https://elicit.com/) — table extraction, systematic review mode
- [Elicit Systematic Review announcement](https://elicit.com/blog/systematic-review/) — Feb 2025 feature additions
- [SciSpace Literature Review: 2025 Review](https://effortlessacademic.com/scispace-an-all-in-one-ai-tool-for-literature-reviews/) — MEDIUM confidence (WebSearch + WebFetch)
- [AnswerThis: Research Gap Finder](https://answerthis.io/ai/research-gap-finder) — gap-to-question workflow

**Extraction Accuracy Research:**
- [Data Extractions Using Elicit and Human Reviewers (Bianchi, 2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12462964/) — systematic comparison, PMC
- [Evaluating Elicit as Semi-Automated Second Reviewer (Hilkenmeier et al., 2025)](https://journals.sagepub.com/doi/10.1177/08944393251404052) — extraction accuracy nuances

**Research Question Frameworks:**
- [PICO Question Builder — INRA.AI](https://www.inra.ai/question-builder) — PICO framework for systematic review questions
- [How to Conduct Research Gap Analysis — Anara](https://anara.com/blog/ai-for-finding-research-gaps) — gap analysis to question generation workflow

**Literature Review AI Tool Landscape:**
- [8 Best AI Tools for Literature Review (Dupple, 2026)](https://dupple.com/learn/best-ai-for-literature-review)
- [AI Tools for Literature Review — Anara blog](https://anara.com/blog/ai-for-literature-review)

---
*Feature research for: Serapeum v4.0 Stability + Synthesis — Overview Preset, Literature Review Table, Research Question Generator*
*Researched: 2026-02-18*
