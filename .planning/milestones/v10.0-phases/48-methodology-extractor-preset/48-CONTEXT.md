# Phase 48: Methodology Extractor Preset - Context

**Gathered:** 2026-03-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add an AI preset that extracts structured research methods from papers using section-targeted RAG, presented as a per-paper comparison table. Also reorganize the document notebook preset bar into two rows (quick vs deep presets) to accommodate the growing number of presets.

</domain>

<decisions>
## Implementation Decisions

### Output structure
- Per-paper table format: one row per paper, columns for the 5 core fields
- Columns: Paper (Author et al., Year), Study Design, Data Sources, Sample Characteristics, Statistical Methods, Tools/Instruments
- Author (Year) citation format in the first column — matches Lit Review Table convention
- No synthesis/summary row — pure extraction only, user draws conclusions
- Papers without clear methods sections included with 'N/A' fields — transparent about gaps

### Section targeting
- RAG prioritizes Methods and Materials sections only (`section_filter = c("methods", "methodology")`)
- Methodology-specific retrieval query: "study design methodology data sources sample size statistical methods instruments"
- 15 chunks per retrieval (slightly more generous than conclusions preset's 10, given methods sections can be detailed)
- 3-level fallback: section-filtered → unfiltered hybrid search → direct DB query (same pattern as conclusions preset)

### Button placement & preset bar reorganization
- Two-row preset bar layout replacing current single row
- Row 1 (Quick presets): Overview, Study Guide, Outline
- Row 2 (Deep presets): Conclusions, Lit Review, Methods, Slides, Export dropdown
- Button label: "Methods" (short, matches bar brevity style)
- Reorganization happens in Phase 48 — Phase 49 just adds Gap Analysis to Row 2
- Uses existing `btn-sm btn-outline-primary` styling per design system (Phase 45)

### Edge cases
- No minimum paper count — works on 1+ papers (consistent with Lit Review Table)
- RAG guard required: "Synthesis unavailable — re-index this notebook first." (same as Lit Review)
- Warning toast at 20+ papers: "Analyzing N papers — output quality may degrade with large collections." (same threshold as Lit Review)

### Disclaimer
- AI disclaimer banner shown on output (METH-05) — add "methodology_extractor" to `is_synthesis` check in chat renderer

### Claude's Discretion
- Exact LLM prompt wording for methodology extraction
- Markdown table formatting details
- Icon choice for the Methods button (from existing icon wrappers in theme_catppuccin.R)
- Handling of search notebook context (if applicable — may be document-only)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing preset patterns (generate_lit_review_table as primary template).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `generate_lit_review_table()` in R/rag.R — closest template for new per-paper table preset
- `search_chunks_hybrid()` with `section_filter` parameter — exact mechanism for section-targeted RAG
- `detect_section_hint()` in R/pdf.R — already classifies "methods" and "methodology" sections
- `handle_preset()` in mod_document_notebook.R — generic preset handler for simple presets
- Lit Review Table handler (lines 919-967) — template for complex preset with RAG guard + warning toast
- `is_synthesis` check (line 703) — controls disclaimer display, needs new preset_type added
- Icon wrappers in R/theme_catppuccin.R — use existing wrappers for button icon

### Established Patterns
- Preset functions in R/rag.R: accept (con, config, notebook_id, session_id) parameters
- 3-level retrieval fallback: section-filtered → unfiltered → direct DB
- Chat message format: list with role, content, timestamp, preset_type fields
- RAG guard pattern: `if (!isTRUE(rag_available()))` check before synthesis

### Integration Points
- R/rag.R: new `generate_methodology_extractor()` function
- R/mod_document_notebook.R: new button in UI, new observeEvent handler, updated is_synthesis check
- Preset bar UI (lines 63-104): restructure into two-row layout

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 48-methodology-extractor-preset*
*Context gathered: 2026-03-05*
