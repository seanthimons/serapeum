# Project Research Summary

**Project:** Serapeum v11.0 Search Notebook UX Milestone
**Domain:** Academic search interface with toolbar improvements, pagination, filtering enhancements
**Researched:** 2026-03-06
**Confidence:** HIGH

## Executive Summary

This milestone refines the search notebook interface with seven targeted UX improvements: toolbar button reorganization with semantic colors, Load More pagination to replace single-page results, expanded document type filters (16 OpenAlex types vs current 3), year slider/histogram alignment fixes, comprehensive tooltip coverage for accessibility, and visual harmonization with Catppuccin theme. Research confirms all features can be implemented with the existing stack (bslib, Bootstrap 5, Shiny, OpenAlex API) — no new dependencies required.

The recommended approach is sequential implementation following dependency order: (1) establish OpenAlex cursor pagination in API layer, (2) implement pagination state management in server, (3) add Load More UI, (4) restructure toolbar with semantic colors, (5) add tooltips for accessibility, (6) enhance document type filter UX, (7) fix year slider alignment. This order ensures stable foundation before cosmetic refinements. Icon+text buttons outperform icon-only for comprehension in academic tools where users are infrequent (not daily power users), and Load More buttons provide better control than infinite scroll for goal-oriented search workflows.

Key risks center on reactive programming pitfalls: cursor state invalidation loops if Load More observer isn't properly isolated, cursor becoming stale when filters change if reset logic is incomplete, and bslib tooltips disappearing on dynamic UI re-renders. Mitigations include strict reactive hygiene (isolate() for cursor reads, cursor reset on ALL filter changes), tooltip strategy (title attributes for dynamic content, bslib for static buttons), and composable filter chain integrity (document type filtering before keyword/journal modules). Color harmonization must remain CSS-only to avoid scope creep into known tech debt (secondary ragnar leak).

## Key Findings

### Recommended Stack

**No new dependencies required.** All v11.0 features use existing capabilities: bslib 0.10.0 provides `tooltip()` with Bootstrap 5 dark mode integration, OpenAlex API v1 supports cursor pagination via `cursor` parameter and `meta.next_cursor` response field, Bootstrap 5 `btn-toolbar` and `btn-group` classes handle button layout, and bsicons 0.1.2 provides 2000+ icons (76 wrappers already in `R/theme_catppuccin.R`).

**Core technologies:**
- **bslib 0.10.0**: Native Bootstrap 5 tooltips via `tooltip()`, flexbox cards for slider/histogram alignment — already installed, no upgrade needed
- **OpenAlex API v1**: Cursor pagination (`cursor` param, returns `meta.next_cursor`), 16 work type taxonomy — existing endpoint, new parameter usage
- **Bootstrap 5.3**: `btn-toolbar`, `btn-group`, flexbox utilities, tooltip JavaScript — available via bslib, no custom framework
- **bsicons 0.1.2**: Icon library for button icons (arrow-clockwise, plus-circle, download) — already integrated with 76 semantic wrappers

**What NOT to add:**
- histoslider package (overkill for simple alignment)
- shinyWidgets (bslib tooltips sufficient)
- Custom tooltip JavaScript (Bootstrap 5 native support)
- New icon library (bsicons established, mixing libraries fragments design)

### Expected Features

**Must have (table stakes):**
- Icon+text for toolbar buttons — text labels reduce ambiguity, icon-only increases cognitive load and fails on touch devices (no hover)
- Load More button at result set end — academic search is goal-oriented, users need control over loading vs infinite scroll
- Tooltips for icon-only buttons — WCAG 2.2 requirement (1.4.13), keyboard-accessible
- Distinct Refresh vs Load More — different actions require different affordances (Refresh = retry/replace, Load More = expand/append)
- Disable Load More when exhausted — prevents confusion, shows "all results loaded" state
- Checkboxes for multi-select document types — standard faceted search pattern

**Should have (competitive):**
- Icon+text with brand colors — Topics button pattern (icon + label + semantic color) already established in v10.0
- Result count in Load More tooltip — "Load More (50 available)" sets expectation for batch size
- Active filter chips for document types — modern faceted search UI, helps users track active filters
- Button grouping with visual separators — groups related actions (Import|Edit vs Export|Network)
- Consistent icon position (left-of-text) — dominant 2026 pattern, visual rhythm

**Defer (v2+):**
- Adaptive labels (mobile collapse to icon-only) — responsive design complexity, not needed for desktop app
- Batch size control for Load More — adds UI complexity, unclear user demand
- Sticky Load More — mobile pattern, less useful for desktop scroll
- Keyboard shortcut hints in tooltips — power user feature
- Expanded document types beyond current 6 — low priority until user requests

### Architecture Approach

The composable filter chain pattern (papers_data → keyword_filter → journal_filter → display) must be preserved when adding document type filtering. Pagination state lives in `reactiveValues()` (cursor, has_more, total_fetched) rather than database — cursors are ephemeral, session-scoped, and expire. OpenAlex cursor pagination requires new `search_papers_with_pagination()` function returning `list(papers, next_cursor, count)`. Tooltip strategy splits: static buttons use `bslib::tooltip()`, dynamic renderUI elements use `title` attributes (JavaScript reinitialization complexity avoided).

**Major components:**
1. **API pagination layer** (api_openalex.R) — `search_papers_with_pagination()` adds cursor parameter, extracts `meta.next_cursor` from response, treats cursor as opaque string (never parse/decode)
2. **Pagination state management** (mod_search_notebook_server) — `pagination_state` reactiveValues tracks cursor/has_more, reset on ALL filter changes (year, type, Edit Search save), `do_load_more()` mirrors Refresh but with cursor continuation
3. **Toolbar restructuring** (mod_search_notebook_ui) — reorder to Import → Refresh → Load More → Export → Network → Edit, apply semantic colors (primary=lavender for Refresh, info=sapphire for Load More/Network), add tooltips via `bslib::tooltip()` for static buttons
4. **Document type filter** (Edit Search modal) — move type distribution panel above checkboxes for better UX, keep existing checkboxInput pattern (scalable to 16 types with collapsible sections)
5. **Year slider alignment** (card layout) — wrap slider + histogram in single container div, `theme(plot.margin = margin(0,0,0,0))` eliminates ggplot2 padding, Bootstrap gap utilities control spacing
6. **Tooltip layer** — `bslib::tooltip()` for toolbar buttons (static), `title` attributes for dynamic UI (keyword/journal filter buttons), test dark mode inheritance from `bs_theme()`

### Critical Pitfalls

1. **Reactive invalidation loop from Load More state** — Cursor state reactive triggers UI re-render which fires observer that modifies cursor, creating infinite loop. **Avoid:** Use `isolate(cursor_state())` when reading cursor inside load-more observer, keep pagination state separate from display state (cursor is data, paper_refresh is UI trigger). **Warning signs:** App hangs on Load More click, repeated "Listening for messages" in console, memory climbs steadily.

2. **OpenAlex cursor invalidation on filter changes** — Storing cursor from previous API call, user changes year filter or document type, then clicks Load More — app sends cursor with NEW filters, OpenAlex returns inconsistent results or error. **Avoid:** Reset `cursor_state(NULL)` in ALL filter change observers (year_range, document type checkboxes, Edit Search save, keyword filter module). Hide/disable Load More button when cursor is NULL. **Warning signs:** Load More returns papers outside year range, duplicate papers after filter change, OpenAlex 400 error.

3. **Document type filtering breaking composable filter chain** — Adding document type filtering AFTER keyword filtering breaks chain because keywords process full set, then types remove papers keywords already filtered. **Avoid:** Document type filtering must happen in `papers_data()` reactive BEFORE passing to keyword filter module. Maintain filter order: API filters (OpenAlex query) → year range → document type → keyword → journal quality → display. **Warning signs:** Keyword badges show counts but paper list empty, unchecking all types shows "no papers" but keyword panel shows keywords, journal quality filter has no effect.

4. **bslib tooltips disappearing on dynamic renderUI** — Wrapping buttons with `bslib::tooltip()` in `renderUI()` output — tooltip doesn't appear after re-render because Bootstrap 5 JavaScript bindings lost. **Avoid:** Use static UI with `conditionalPanel()` instead of `renderUI()` where possible, use `title` attributes for truly dynamic content, add JavaScript reinitialization handler if bslib tooltip required. **Warning signs:** Tooltip works once then disappears after UI update, "Tooltip is not defined" JavaScript error, icon-only button with no hover feedback.

5. **Button reordering breaking observer bindings** — Reordering toolbar buttons changes DOM order, developer confusion about which `ns("action")` corresponds to which visual button leads to copy-paste errors. **Avoid:** Keep input IDs and observer names in sync, use unique descriptive IDs (edit_search, refresh_search, NOT btn1, btn2), search codebase for all references after reordering, test every button click. **Warning signs:** Button click has no effect, wrong modal appears, "input$X is undefined" in console.

## Implications for Roadmap

Based on research, suggested phase structure follows dependency order with critical path through pagination foundation (Phases 1-3):

### Phase 1: API Pagination Foundation
**Rationale:** Cursor pagination is blocking for both Refresh and Load More logic. Must establish API contract before UI/server changes.
**Delivers:** `search_papers_with_pagination()` function in `api_openalex.R` returning `list(papers, next_cursor, count)`
**Uses:** OpenAlex API cursor parameter, `meta.next_cursor` response field (STACK.md §5)
**Avoids:** Pitfall #8 (cursor format assumptions) — treat cursor as opaque string, never parse/decode/validate

### Phase 2: Pagination State Management
**Rationale:** Server-side state layer required before UI implementation, enables both Refresh and Load More patterns.
**Delivers:** `pagination_state` reactiveValues (cursor, has_more, total_fetched), modified `do_search_refresh()` to track cursor, new `do_load_more()` function
**Depends on:** Phase 1 (uses search_papers_with_pagination)
**Avoids:** Pitfall #1 (reactive loops) via `isolate()` pattern, Pitfall #2 (cursor invalidation) via reset logic in ALL filter observers

### Phase 3: Load More Button
**Rationale:** Implements append-mode pagination UI with conditional rendering based on cursor state.
**Delivers:** Load More button in toolbar, `observeEvent(input$load_more)` wired to `do_load_more()`, conditional rendering when `pagination_state$has_more`
**Addresses:** Table stakes Load More feature (FEATURES.md Pattern 2), distinct from Refresh mental model (FEATURES.md Pattern 6)
**Depends on:** Phase 2 (uses pagination_state)
**Avoids:** UX pitfall (Load More visible when cursor NULL) via conditional rendering

### Phase 4: Button Bar Restructuring
**Rationale:** Toolbar layout finalized with all buttons present before applying colors/tooltips.
**Delivers:** Reordered buttons (Import → Refresh → Load More → Export → Network → Edit), semantic color classes (btn-outline-primary, btn-outline-info, btn-outline-success)
**Uses:** Bootstrap 5 btn-toolbar, btn-group classes (STACK.md §1), Catppuccin semantic colors (ARCHITECTURE.md color table)
**Addresses:** Button grouping table stakes (FEATURES.md Pattern 5), color harmonization differentiator
**Depends on:** Phase 3 (Load More button exists)
**Avoids:** Pitfall #6 (observer binding breaks) via verification after reorder

### Phase 5: Tooltip Layer
**Rationale:** Visual polish after structure stable, accessibility requirement for icon-only buttons.
**Delivers:** `bslib::tooltip()` wrappers on static toolbar buttons, `title` attributes on dynamic buttons (keyword/journal filter), dark mode testing
**Uses:** bslib tooltip() function (STACK.md §2)
**Addresses:** WCAG 2.2 tooltips table stakes (FEATURES.md Pattern 1 & 4), under-15-word content guideline
**Depends on:** Phase 4 (toolbar buttons finalized)
**Avoids:** Pitfall #4 (dynamic UI tooltips) via title attribute strategy, Pitfall #10 (namespace collision) via `ns()` for tooltip IDs

### Phase 6: Document Type Filter UX
**Rationale:** Independent of pagination, can proceed in parallel with Phases 4-5, enhances discoverability.
**Delivers:** Type distribution panel moved above checkboxes in Edit Search modal, optional badge styling for labels
**Addresses:** Expanded document types differentiator (FEATURES.md Pattern 3), 16 OpenAlex work types (STACK.md §3)
**Avoids:** Pitfall #3 (composable chain break) by verifying type filtering happens in `papers_data()` before keyword module
**Independent:** Can start after Phase 1 (no pagination dependency)

### Phase 7: Year Slider Alignment Fix
**Rationale:** Independent cosmetic fix, no functional dependencies, pure CSS/layout.
**Delivers:** Adjusted CSS margin/padding between slider and histogram, shared container div with explicit width
**Uses:** bslib flexbox cards, Bootstrap gap utilities (STACK.md §4)
**Avoids:** Pitfall #5 (grid misalignment) via `theme(plot.margin = margin(0,0,0,0))` and container strategy, Pitfall #7 (color harmonization scope creep) by keeping changes CSS-only
**Independent:** Can start anytime

### Phase Ordering Rationale

- **Sequential critical path (1 → 2 → 3 → 4 → 5):** API changes must precede state management, state must exist before UI, UI structure must finalize before polish. Breaking this order causes rework (e.g., adding Load More before pagination state requires UI rewrite when state added).
- **Parallel opportunities:** Phase 6 (document types) and Phase 7 (year slider) are independent, can proceed alongside Phases 4-5 to compress schedule.
- **Pitfall avoidance:** Order explicitly prevents Pitfall #1 (reactive loops established before UI triggers them), Pitfall #2 (cursor reset logic co-located with filter state in Phase 2), Pitfall #3 (composable chain verified in Phase 6 before expanding filters), Pitfall #7 (color harmonization deferred to Phase 4 after structure stable, CSS-only rule enforced).
- **Architecture patterns:** Follows ARCHITECTURE.md build order (§ "Build Order") — foundation before features, features before polish.

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** OpenAlex cursor pagination well-documented with official tutorials, straightforward API parameter addition
- **Phase 4:** Bootstrap 5 button groups are standard pattern, bslib integration proven in existing codebase (76 icon wrappers)
- **Phase 5:** bslib tooltips documented with examples, title attribute fallback is standard HTML
- **Phase 7:** CSS flexbox alignment is standard technique, ggplot2 margin removal already implemented in codebase

**Phases needing extra validation (not research, but testing focus):**
- **Phase 2:** Reactive invalidation loops are subtle — allocate time for thorough testing with multiple filter changes + Load More clicks
- **Phase 3:** Cursor state conditional rendering needs cross-browser testing (especially dark mode tooltip rendering)
- **Phase 6:** Composable filter chain integrity requires end-to-end testing with all filter combinations (keyword + type + journal quality)

**No phases require deeper research** — all patterns have HIGH confidence from official documentation (OpenAlex API docs, Bootstrap 5 reference, bslib package docs, Shiny reactive programming guides).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified with official docs (bslib CRAN, OpenAlex API, Bootstrap 5.3), no version upgrades needed |
| Features | HIGH | UX patterns sourced from NN/G research, WCAG 2.2 spec, design system documentation (PatternFly, Cloudscape) |
| Architecture | HIGH | Composable filter chain exists in codebase (lines 794-798), pagination state pattern proven in Shiny apps, cursor lifecycle documented by OpenAlex |
| Pitfalls | HIGH | Reactive loops documented in Mastering Shiny Ch16, cursor invalidation confirmed in OpenAlex tutorials, tooltip dynamic UI issue verified in bslib docs |

**Overall confidence:** HIGH

Research is verified with authoritative sources (OpenAlex official docs, Bootstrap 5 reference, bslib package documentation, Shiny reactive programming guides). Architecture leverages existing codebase patterns (composable filters, semantic colors, icon wrappers). Only LOW confidence area addressed in research was Load More batch size (50 vs 25 vs 100) — defaulted to existing config value of 25 per PROJECT.md line 2214.

### Gaps to Address

**Load More batch size preference:** Research found community consensus on 50 items per load for general web apps, but no scholarly-specific guidance. **Resolution:** Use existing config value (`abstracts_per_search = 25` from PROJECT.md) for consistency, defer optimization to user feedback in v11.0.

**Button ordering frequency analysis:** Proposed order (Import → Refresh → Load More → Export → Network → Edit) follows workflow sequence, but lacks usage analytics to confirm Import is more frequent than Edit. **Resolution:** Implement workflow order per FEATURES.md Pattern 5, collect analytics in v11.0 for potential reorder in v12.0.

**Document type usage distribution:** Expanding from 3 to 16 types assumes users need books/datasets/editorials, but no Serapeum-specific data on which types are requested. **Resolution:** Phase 6 moves distribution panel above checkboxes to show live counts, helping users discover which types are available in their query results. Defer further UI changes (e.g., type grouping) until usage patterns emerge.

**Year slider debounce value:** 400ms debounce prevents reactive storm but may lose final value on rapid drag (Pitfall #9). **Resolution:** Accept UX trade-off per ARCHITECTURE.md — debounce necessary for performance, alternative is Apply Filter button (deferred to future milestone).

## Sources

### Primary (HIGH confidence)
- [OpenAlex Cursor Pagination Documentation](https://developers.openalex.org/how-to-use-the-api/get-lists-of-entities/paging) — cursor parameter mechanics, per_page limits, opaque cursor warning
- [OpenAlex API Tutorials (GitHub)](https://github.com/ourresearch/openalex-api-tutorials/blob/main/notebooks/getting-started/paging.ipynb) — cursor usage examples with Python code
- [Bootstrap 5.3 Button Group Documentation](https://getbootstrap.com/docs/5.3/components/button-group/) — btn-toolbar, btn-group classes, accessibility (role, aria-label)
- [bslib::tooltip() Reference](https://rstudio.github.io/bslib/reference/tooltip.html) — function signature, placement, dynamic updates, dark mode compatibility
- [bslib Tooltips & Popovers Article](https://rstudio.github.io/bslib/articles/tooltips-popovers/index.html) — dynamic UI pattern with renderUI, reinitialization requirements
- [Mastering Shiny Ch16: Escaping the graph](https://mastering-shiny.org/reactivity-components.html) — isolate(), observeEvent() patterns, reactive invalidation loops
- [NN/G Icon Usability](https://www.nngroup.com/articles/icon-usability/) — "labels always win" guidance, cognitive load of icon-only
- [WCAG 2.2 1.4.13 Content on Hover or Focus](https://www.wcag.com/authors/1-4-13-content-on-hover-or-focus/) — tooltip accessibility requirements, keyboard navigation

### Secondary (MEDIUM confidence)
- [Analysis of Publication and Document Types in OpenAlex (arXiv)](https://arxiv.org/html/2406.15154v1) — 16 work type taxonomy, article consolidation (July 2023)
- [PatternFly Filter Guidelines](https://www.patternfly.org/patterns/filters/design-guidelines/) — checkbox multi-select for facets, active filter chips with remove buttons
- [NN/G Tooltip Guidelines](https://www.nngroup.com/articles/tooltip-guidelines/) — under-15-word guideline, describe action not UI
- [Pagination vs Infinite Scroll vs Load More (Medium)](https://ashishmisal.medium.com/pagination-vs-infinite-scroll-vs-load-more-data-loading-ux-patterns-in-react-53534e23244d) — Load More works well for goal-oriented search
- [UI Cheat Sheet: Pagination, infinite scroll, and the load more button (UX Collective)](https://uxdesign.cc/ui-cheat-sheet-pagination-infinite-scroll-and-the-load-more-button-e5c452e279a8) — position awareness, user control

### Project-Specific Context
- `.planning/PROJECT.md` lines 249 (secondary ragnar leak), 2214 (abstracts_per_search config)
- `R/mod_search_notebook.R` lines 68-102 (button bar), 129-153 (year slider), 794-798 (composable filter chain), 974 (year debounce), 1892-1912 (document type filters), 1997-2006 (work_type column check)
- `R/theme_catppuccin.R` — 76 icon wrappers (icon_rotate, icon_plus_circle, icon_file_import, etc.)
- `R/api_openalex.R` lines 293-376 — search_papers() implementation, per_page parameter

---
*Research completed: 2026-03-06*
*Ready for roadmap: yes*
