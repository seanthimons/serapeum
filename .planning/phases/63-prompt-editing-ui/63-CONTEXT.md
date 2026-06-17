# Phase 63: Prompt Editing UI - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can view, edit, version, and reset the system prompts for all AI presets without seeing RAG plumbing. The prompt editing UI lives in the Settings page. This phase creates the UI module, DB read/write functions, and wires prompts into the generation pipeline. The `prompt_versions` table already exists from Phase 62.

</domain>

<decisions>
## Implementation Decisions

### UI placement
- Prompt editor lives as a new section in the Settings page (right column or below existing sections)
- Presets listed in a grouped format: Quick (Summarize, Key Points, Study Guide, Outline) and Deep (Overview, Conclusions, Research Questions, Literature Review, Methodology Extractor, Gap Analysis, Slides)
- Clicking a preset name opens a modal dialog with the prompt editor
- No preview/test button — users test by running the preset in their notebook after saving

### Prompt separation (RAG vs instruction)
- Only the task instruction portion of each prompt is exposed for editing
- Hidden machinery includes: role preamble ("You are a..."), CITATION RULES block, OWASP separator markers, source context formatting
- A read-only note above the editor explains: "This prompt is combined with citation rules and source context when generating output. You're editing the task instructions only."
- For `generate_preset()`: the values in the `presets` list are the editable portions (e.g., "Provide a comprehensive summary...")
- For dedicated generators (conclusions, overview, research_questions, lit_review, methodology, gap_analysis): the task-specific instruction paragraphs within `system_prompt` are editable
- Citation rules are NOT editable — they are system-level machinery
- The `rag_query()` chat prompt is excluded from the editor — only preset prompts are editable

### Version history UX
- Dropdown/selectInput of dates (most recent first) above the editor textarea
- Selecting a date loads that version's prompt text into the editor for review
- Loading an old version is non-destructive — user must click Save to make it active (creates new version with today's date)
- "Reset to Default" button loads the hardcoded default text into the textarea; user confirms by saving; on save, all custom versions for that preset are deleted
- No diff view between versions — simple text replacement

### Editor interaction
- Plain textAreaInput (rows=15) in a modal dialog — no syntax highlighting needed
- Explicit save button in modal footer with confirmation toast
- Validation: non-empty check only — prompts are freeform instruction text
- No character/word count display

### Claude's Discretion
- Exact layout within Settings page (new section heading, position relative to existing sections)
- Modal sizing and styling details
- How to extract the "editable portion" from each preset's system_prompt (string splitting strategy)
- Whether to create a separate helper file (e.g., R/prompt_helpers.R) or add functions to R/db.R

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prompt storage schema
- `R/db_migrations.R` — Migration runner, `apply_migration()` pattern
- `migrations/011_create_prompt_versions.sql` — Table schema: composite PK (preset_slug, version_date), prompt_text, created_at

### Prompt structure (source of editable text)
- `R/rag.R` — All AI preset prompts: `generate_preset()` lines 156-162 (presets list), `generate_conclusions_preset()` line 270+, `generate_overview_preset()` line 454+, `generate_research_questions()` line 700+, `generate_methodology_extractor()` line 1119+, `generate_gap_analysis()` line 1332+
- `R/slides.R` — Slide generation prompt (if slides preset is included)

### UI patterns
- `R/mod_settings.R` — Existing Settings page layout (two-column, card-based)
- `R/mod_document_notebook.R` — How presets are invoked (lines 934+, handle_preset function)

### Phase 62 context
- `.planning/phases/62-prompt-storage-schema/62-CONTEXT.md` — Schema decisions: UPSERT behavior, no seeded defaults, reset = delete rows

### Requirements
- `.planning/REQUIREMENTS.md` — PRMT-01 through PRMT-06 (view, edit, hide RAG, store, recall versions, reset)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/db.R`: DBI-based query helpers (dbGetQuery, dbExecute) — use for prompt_versions CRUD
- `R/mod_settings.R`: Settings module with two-column layout, card_header/card_body pattern
- `R/theme_catppuccin.R`: Semantic icon wrappers (icon_settings, icon_edit, etc.) for consistent UI
- `migrations/011_create_prompt_versions.sql`: Table already created by Phase 62

### Established Patterns
- Settings page uses `layout_columns(col_widths = c(6, 6))` for two-column layout
- Modal dialogs used elsewhere (slide generation, bulk import) via `showModal(modalDialog(...))`
- Toast notifications via `showNotification()` for save confirmations
- Namespace-prefixed inputs via `ns()` in Shiny modules

### Integration Points
- `generate_preset()` and dedicated generators in R/rag.R need to check prompt_versions table before using hardcoded defaults
- Settings module server needs DB connection (already passed as `con` reactive)
- Preset slug list must match Phase 62 convention: summarize, keypoints, studyguide, outline, conclusions, overview, research_questions, literature_review (lit_review in code), methodology, gap_analysis, slides

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The UI should follow the existing Settings page patterns (cards, modals, consistent icon usage).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 63-prompt-editing-ui*
*Context gathered: 2026-03-21*
