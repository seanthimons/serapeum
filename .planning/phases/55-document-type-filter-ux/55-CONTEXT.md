# Phase 55: Document Type Filter UX - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Expand document type filtering from 6 hardcoded checkboxes to the full OpenAlex 16-type taxonomy using compact chip toggles, add a distribution preview panel above the chips, apply distinctive per-category badge styling across the app, and wire client-side type filtering into the existing filter chain. Increase API page size from 25 to 100 to compensate for client-side filtering.

</domain>

<decisions>
## Implementation Decisions

### Chip toggle layout
- Replace 6 checkboxes with compact clickable chip toggles (badge-style, similar to keyword badges)
- Two-state: ON (included) / OFF (excluded) — no three-state rotation
- Default state: common types ON (article, review, preprint, book), rare types OFF (erratum, paratext, grant, supplementary-materials, etc.)
- Add "Select All / Deselect All" text links above the chip grid
- Chip colors match the badge colors used in search results (visual consistency)

### Distribution panel
- Move distribution panel ABOVE the chip toggles (currently below)
- Data source: current loaded papers (not a separate API call)
- Display-only — no interactive bar clicking
- Collapsible via `<details>` element, expanded by default
- Show ALL 16 types including zero-count types (user sees what's missing)
- Pre-filter counts: reflects all loaded papers regardless of type filter state

### Badge styling
- Color-coded by category (3-4 color families within Catppuccin palette):
  - Primary research (e.g., article, book, book-chapter, dissertation): one color family
  - Reviews/editorials (e.g., review, editorial, letter, peer-review): another family
  - Preprints/reports (e.g., preprint, report, standard): another family
  - Metadata/other (e.g., erratum, paratext, grant, supplementary-materials, dataset): gray/neutral family
- Similar types share hues with subtle variation
- Labels: Title case, human-friendly (e.g., "Book Chapter", "Peer Review", not "book-chapter")
- Same badge colors used in both Edit Search chip toggles and search result cards

### Filter chain position
- Both API-level AND client-side filtering (belt-and-suspenders)
- API filter: pass `work_types` to `search_openalex_works()` on fresh search/refresh
- Client-side filter: applied in `papers_data()` reactive AFTER keyword filter, BEFORE journal filter
- Save & Refresh: re-filters loaded papers locally (no fresh API search triggered by type change alone)
- Next actual search/refresh uses the saved type filters at API level

### Page size increase
- Increase API page size from 25 to 100 papers per request
- Compensates for client-side type filtering reducing visible results
- 100 is OpenAlex's max per_page

### Claude's Discretion
- Exact Catppuccin color assignments for each of the 16 types
- Chip toggle CSS implementation (reuse keyword badge pattern or new)
- Distribution bar chart styling (bar heights, colors, spacing)
- How to group the 16 types for default on/off split (which types are "common" vs "rare")
- Responsive layout of chip grid (flow-wrap vs fixed columns)

</decisions>

<specifics>
## Specific Ideas

- Chip toggles should feel like the keyword badge system — familiar interaction pattern within the app
- "Select All / Deselect All" is essential with 16 toggles to avoid tedious clicking
- Distribution panel showing all 16 types (even zeros) gives researchers confidence about what OpenAlex returned vs what was filtered
- Pre-filter counts in distribution panel means it's a stable reference — doesn't jump around as user toggles chips
- Page size bump to 100 is the pragmatic response to client-side filtering narrowing results

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `get_type_badge()` in mod_search_notebook.R:874 — already maps 9 types to Bootstrap classes; needs expansion to 16
- Keyword badge toggle pattern in mod_keyword_filter.R — three-state rotation logic to reference for two-state chip design
- 76 icon wrappers in R/theme_catppuccin.R — Catppuccin color palette available via Bootstrap variables
- `format_large_number()` helper from Phase 53 — for compact count display

### Established Patterns
- Edit Search modal in mod_search_notebook.R:1930-2036 — document type section at line 1974-2001
- `get_selected_work_types()` reactive at line 2040 — collects checkbox state, needs refactoring for chip state
- Filter chain: papers_data() → keyword_filtered_papers → journal_filtered_papers — type filter inserts between keyword and journal
- OpenAlex API already supports `type:` pipe-delimited filter in search_openalex_works() at api_openalex.R:354

### Integration Points
- Edit Search modal document type section (line 1974-2001): replace checkboxes with chip grid + distribution panel
- `type_distribution` renderUI (line 2078): move above chips, show all 16 types, pre-filter counts
- `get_selected_work_types()` reactive (line 2040): refactor from 6 checkbox reads to 16 chip state reads
- Save handler (line 2232-2244): collect 16 chip states instead of 6 checkboxes
- `papers_data()` reactive: add client-side type filter step
- API page_size parameter: change from 25 to 100

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 55-document-type-filter-ux*
*Context gathered: 2026-03-11*
