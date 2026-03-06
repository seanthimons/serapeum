# Phase 49: Gap Analysis Report Preset - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Add an AI preset that identifies methodological and topical gaps through cross-paper synthesis of Discussion/Limitations/Future Work sections. Requires minimum 3 papers. Report highlights contradictory findings with inline citations. Button added to Deep presets row in document notebook.

</domain>

<decisions>
## Implementation Decisions

### Output structure
- Narrative prose organized by gap category, not tabular
- Opening summary (2-3 sentences) highlighting the most critical gaps identified
- All 5 gap categories always shown as headings: Methodological Gaps, Geographic Gaps, Population Gaps, Measurement Gaps, Theoretical Gaps
- If no gaps found for a category: "No significant [type] gaps identified across the reviewed papers."
- Inline Author (Year) citations woven into narrative — matches Lit Review Table convention

### Contradictions display
- Contradictions integrated within their relevant gap category (not a separate section)
- Visually distinguished with bold prefix: "**Contradictory finding:** Smith (2023) reports X while Jones (2024) found Y."
- LLM prompt explicitly instructs to actively identify and highlight contradictory findings between papers (GAPS-03)

### Button & threshold UX
- Button label: "Research Gaps"
- Placement: Deep presets row, after Methods, before Slides
- Order: Conclusions, Lit Review, Methods, Research Gaps, Slides
- Minimum 3 papers enforced — error toast on click: "Gap analysis requires at least 3 papers. Add more papers to this notebook."
- Large-collection warning at 15+ papers (lower than Methods/Lit Review's 20 threshold): "Analyzing N papers — output quality may degrade with large collections."
- Uses existing `btn-sm btn-outline-primary` styling per design system (Phase 45)

### Section targeting & RAG
- Section filter targets: `c("discussion", "limitations", "future_work")` — all three section types from detect_section_hint()
- 20 chunks per retrieval (more generous than Methods' 15 — cross-paper synthesis needs broader context)
- 3-level fallback: section-filtered → unfiltered hybrid search → direct DB query (same as Methods preset)
- Gap-specific retrieval query emphasizing limitations, future work, contradictions, and research gaps

### Edge cases & coverage
- Transparent coverage note when fallback was needed: "Note: Some papers lacked structured Discussion/Limitations sections; analysis drew from available content."
- RAG guard required: "Synthesis unavailable — re-index this notebook first." (same as other presets)

### Disclaimer
- AI disclaimer banner shown on output (GAPS-05) — add "gap_analysis" to `is_synthesis` check in chat renderer

### Claude's Discretion
- Exact LLM prompt wording for gap identification and contradiction detection
- How to word the coverage transparency note
- Icon choice for the Research Gaps button (from existing icon wrappers in theme_catppuccin.R)
- Markdown formatting details within narrative sections

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing preset patterns (generate_methodology_extractor and generate_conclusions as primary templates for cross-paper synthesis).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `generate_methodology_extractor()` in R/rag.R — template for section-targeted preset with per-paper extraction
- `generate_conclusions()` in R/rag.R — template for cross-paper synthesis narrative output
- `search_chunks_hybrid()` with `section_filter` parameter — section-targeted RAG mechanism
- `detect_section_hint()` in R/pdf.R — already classifies "discussion", "limitations", "future_work" sections
- `handle_preset()` in mod_document_notebook.R — generic preset handler for simple presets
- Lit Review Table handler (lines 919-967) — template for complex preset with RAG guard + warning toast
- Methods handler (lines ~1005-1027) — latest implementation of section-targeted preset
- `is_synthesis` check (line 717) — controls disclaimer display, add "gap_analysis" to the %in% vector
- Icon wrappers in R/theme_catppuccin.R — use existing wrapper for button icon

### Established Patterns
- Preset functions in R/rag.R: accept (con, config, notebook_id, session_id) parameters
- 3-level retrieval fallback: section-filtered → unfiltered → direct DB
- Chat message format: list with role, content, timestamp, preset_type fields
- RAG guard pattern: `if (!isTRUE(rag_available()))` check before synthesis
- Warning toast at threshold: `showNotification()` for large collections
- Two-row preset bar: Quick (Overview, Study Guide, Outline) + Deep (Conclusions, Lit Review, Methods, [new], Slides)

### Integration Points
- R/rag.R: new `generate_gap_analysis()` function
- R/mod_document_notebook.R: new button in Deep row UI, new observeEvent handler, updated is_synthesis check
- Deep presets row (line 103-118): add Research Gaps button between Methods and Slides

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 49-gap-analysis-report-preset*
*Context gathered: 2026-03-06*
