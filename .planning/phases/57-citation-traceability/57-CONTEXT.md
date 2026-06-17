# Phase 57: Citation Traceability - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

All AI-generated outputs instruct the LLM to include page-level citations so users can trace claims back to source documents. This is a prompt-engineering-only change across `R/rag.R` and `R/slides.R`. No new dependencies, infrastructure, or UI changes.

</domain>

<decisions>
## Implementation Decisions

### Citation format
- All non-slide prose outputs use APA-like parenthetical format: `(Author, Year, p.X)`
- When multiple sources support a claim, cite all: `(Smith, 2023, p.5; Jones, 2022, p.12)`
- Slides keep their current working `^[Author et al., 2023, p.5]` Quarto inline footnote syntax unchanged — do NOT modify slide citation format (past experience: deviating from Quarto spec caused breakage)
- RAG chat prompt updated from `[Document Name, p.X]` to `(Author, Year, p.X)` for consistency with presets

### Page number fallback
- When page metadata is available (document notebooks with PDFs): `(Author, Year, p.X)`
- When source is an abstract (OpenAlex, no pages): `(Author, Year, abstract)` — explicitly marks the source as abstract-only
- When page_number is NA in document notebooks (extraction failed): `(Author, Year, filename-slug, chunk N)` — enough info for user to locate content manually

### Preset-specific behavior
- **Prose presets** (Overview quick/thorough, Conclusions, Study Guide, Summarize, Key Points, Outline, Research Questions, Gap Analysis): add `(Author, Year, p.X)` citation instruction to system prompts
- **Structured table presets** (Lit Review Table, Methodology Extractor): keep table cells clean, add numbered footnote section below the table linking claims to page numbers
- **Research Questions**: update from `Author et al. (Year)` to include page numbers in rationales: `Smith et al. (2023, p.14) found that...`
- **Gap Analysis**: same treatment as Research Questions — page numbers in gap rationales
- **4 basic presets** (summarize, keypoints, studyguide, outline): all get the same citation instruction — no lighter treatment for any preset

### Citation density
- Every substantive claim gets a citation — maximum traceability
- When multiple sources support the same claim, cite all relevant sources to show evidence convergence
- Same density instruction across all prose presets — no quick vs deep distinction for citation behavior

### Claude's Discretion
- Exact wording of citation instructions per prompt (as long as the format and density decisions above are respected)
- Whether to add correct/wrong citation examples in prompts (recommended based on v7.0 slide prompt success)
- How to word the footnote instruction for table presets

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prompt files
- `R/rag.R` — Contains all AI preset prompts: `rag_query()` (line ~108), `generate_preset()` (line ~208), `generate_conclusions_preset()` (line ~362), `call_overview_quick()` (line ~517), `call_overview_summary()` (line ~558), `call_overview_keypoints()` (line ~587), `generate_research_questions()` (line ~771), `generate_lit_review_table()` (line ~996), `generate_methodology_extractor()` (line ~1073)
- `R/slides.R` — Slide generation prompts: `build_slides_prompt()` (line ~38), `build_healing_prompt()` (line ~371)

### Context builder
- `R/rag.R` `build_context()` (line ~1) — Formats source labels as `[DocName, p.X]` or `[Paper Title]`; this is what the LLM sees as source identifiers
- `R/rag.R` `build_context_by_paper()` (line ~831) — Formats chunks with `[p.X, section_hint]` headers per paper

### Requirements
- `.planning/REQUIREMENTS.md` — CITE-01 (preset page citations), CITE-02 (slide page citations)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build_context()` already formats source labels with page numbers (`[DocName, p.X]`) — the LLM context already contains page data
- `build_context_by_paper()` includes `[p.X, section_hint]` per chunk — page metadata flows through the pipeline
- `format_chat_messages()` handles system/user prompt assembly for all presets

### Established Patterns
- OWASP instruction-data separation: `===== BEGIN SOURCES =====` / `===== END SOURCES =====` delimiters (used in conclusions, research questions)
- Concrete correct/wrong syntax examples in prompts (established in v7.0 slide prompts — proven effective across Claude Sonnet 4 and Gemini Flash)
- System prompts define role + format rules, user prompts provide sources + task

### Integration Points
- Each preset function has its own `system_prompt` string — changes are localized per function
- `build_context()` source labels may need updating to include Year if not already present (currently shows `[DocName, p.X]` for documents, `[Paper Title]` for abstracts)
- No changes needed to retrieval, chunking, or database layers

</code_context>

<specifics>
## Specific Ideas

- User explicitly warned against changing Quarto footnote syntax in slides — "This fucked us over before" — leave `^[text]` format exactly as-is
- Fallback format `(Author, Year, abstract)` chosen to set clear expectations about source depth when citing OpenAlex abstracts without full text

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 57-citation-traceability*
*Context gathered: 2026-03-18*
