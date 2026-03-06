# Pitfalls Research: v11.0 Search Notebook UX

**Domain:** Shiny reactive programming + OpenAlex API integration + Bootstrap UI enhancements
**Researched:** 2026-03-06
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Reactive Invalidation Loop from Load-More State

**What goes wrong:**
When splitting "Refresh" into "Refresh" + "Load More," developers often create a cursor state reactive value that both triggers UI re-renders AND is modified by the same observer. This creates an infinite invalidation loop where: cursor changes → UI updates → observer fires → cursor changes → infinite loop.

**Why it happens:**
Shiny's reactive graph invalidates all downstream dependents when a reactive value changes. If `cursor_state` is used in `renderUI()` to show the Load More button AND modified by `observeEvent(input$load_more)` that reads `cursor_state`, you create a circular dependency.

**How to avoid:**
1. Use `isolate()` when reading cursor state inside the load-more observer: `observeEvent(input$load_more, { cursor <- isolate(cursor_state()); ... })`
2. Store cursor in a non-reactive variable and only update `paper_refresh()` trigger after modifying papers
3. Use `bindEvent()` pattern instead of `observe()` to ensure explicit event sources
4. Keep pagination state separate from display state — cursor is data, paper_refresh is UI trigger

**Warning signs:**
- App hangs or becomes unresponsive when clicking Load More
- Console shows repeated "Listening for messages" or reactive invalidation messages
- Observer fires multiple times for single button click
- Memory usage climbs steadily after Load More clicks

**Phase to address:**
Phase 1 (Refresh/Load-More split) — must establish cursor state isolation pattern before implementing Load More button

---

### Pitfall 2: OpenAlex Cursor State Invalidation on Filter Changes

**What goes wrong:**
Developer stores cursor from previous API call, user changes year filter or document type, then clicks "Load More" — app sends cursor with NEW filters, OpenAlex returns inconsistent results or error because cursor is bound to original query context. Results appear duplicated or out of order.

**Why it happens:**
OpenAlex cursors are opaque tokens tied to the specific query parameters (filters, sort order) that generated them. Changing filters invalidates the cursor, but the app doesn't reset cursor state when filters change.

**How to avoid:**
1. Reset `cursor_state(NULL)` in ALL filter change observers: `observeEvent(input$year_range, { cursor_state(NULL); ... })`
2. Reset cursor when Edit Search is saved: `observeEvent(input$save_search, { cursor_state(NULL); ... })`
3. Reset cursor when keyword filters change (via composable filter chain)
4. Hide/disable Load More button when cursor is NULL (i.e., after filter change before Refresh)
5. Document that Refresh = fresh query (cursor reset), Load More = append with cursor

**Warning signs:**
- Load More returns papers outside year range
- Papers appear in wrong sort order after Load More
- Duplicate papers appear after changing filters and clicking Load More
- OpenAlex returns 400 error with cursor after filter change

**Phase to address:**
Phase 2 (OpenAlex cursor pagination) — cursor reset logic must be co-located with filter state management

---

### Pitfall 3: Document Type Filter Checkboxes Breaking Composable Filter Chain

**What goes wrong:**
Adding more document type checkboxes (dataset, editorial, letter, paratext) changes the filtered papers reactive but breaks the keyword → journal quality → display composable filter chain. Papers disappear unexpectedly or keyword filtering stops working.

**Why it happens:**
The composable filter chain (`keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data)`) expects `papers_data()` to be stable across refreshes. If document type filtering happens AFTER keyword filtering, the chain breaks — keywords are filtered on the full set, but document types remove papers that keywords already processed.

**How to avoid:**
1. Document type filtering must happen in `papers_data()` reactive BEFORE passing to keyword filter module
2. Use `filtered_papers <- reactive({ papers <- papers_data(); filter_by_year(filter_by_type(papers)) })` pattern
3. DO NOT add document type filtering to `journal_filtered_papers` or between modules
4. Maintain filter order: API filters (OpenAlex query) → year range → document type → keyword → journal quality → display
5. Test with: select one keyword → uncheck all document types → verify empty list, not error

**Warning signs:**
- Keyword badges show counts but paper list is empty
- Unchecking all document types shows "no papers" but keyword panel shows keywords
- Journal quality filter toggle has no effect after document type change
- Error: "object 'work_type' not found" in reactive chain

**Phase to address:**
Phase 3 (Document type filter expansion) — must verify composable chain integrity before expanding filter UI

---

### Pitfall 4: bslib Tooltips Not Appearing on Dynamic renderUI Elements

**What goes wrong:**
Wrapping icon-only buttons with `bslib::tooltip()` in `renderUI()` output — tooltip doesn't appear on hover, or appears on first render but disappears after re-render (e.g., after filter change).

**Why it happens:**
bslib tooltips use Bootstrap 5's JavaScript tooltip plugin, which initializes on page load. When `renderUI()` replaces DOM content, the JavaScript bindings are lost and tooltips are never re-initialized. Unlike static UI elements, dynamic content needs explicit reinitialization.

**How to avoid:**
1. Use static UI elements with `conditionalPanel()` instead of `renderUI()` where possible
2. For truly dynamic content, use HTML `title` attribute (native browser tooltip) instead of bslib tooltip
3. If bslib tooltip is required, add custom JavaScript message handler to reinitialize tooltips after renderUI
4. For icon-only buttons in loops (e.g., paper list), use `title` attribute pattern already in codebase (line 76-97 in mod_search_notebook.R)
5. Test tooltip persistence: hover → trigger re-render → hover again → verify tooltip still appears

**Warning signs:**
- Tooltip appears once, then never again after UI update
- Console shows "Tooltip is not defined" JavaScript error
- Tooltip works in static UI but not in uiOutput/renderUI sections
- Icon-only button with no visual feedback on hover (accessibility issue)

**Phase to address:**
Phase 4 (Tooltip addition) — establish tooltip strategy (title vs bslib) BEFORE implementing across UI

---

### Pitfall 5: Bootstrap Grid Column Width Mismatch Between Slider and Histogram

**What goes wrong:**
Year slider and histogram render in separate grid columns — slider shows 1950-2025 range but histogram bars align to 1900-2050, creating visual misalignment where bars don't match slider thumb positions.

**Why it happens:**
`sliderInput()` and `plotOutput()` are separate UI elements with independent width calculations. Bootstrap grid columns use flexbox which can cause fractional pixel widths. ggplot2 plot margins add padding that shifts histogram bars relative to slider track.

**How to avoid:**
1. Wrap slider + histogram in single `div()` with explicit width: `div(style = "width: 100%", ...)`
2. Use ggplot2 `theme(plot.margin = margin(0,0,0,0))` to eliminate padding (already done line 995)
3. Set histogram `width = 0.8` in `geom_col()` for slight bar shrinkage (already done line 990)
4. Ensure slider and histogram use same parent column in `layout_columns()` — NOT sibling columns
5. Test with: narrow browser window → verify slider thumb aligns with histogram bar when dragging

**Warning signs:**
- Histogram bars visibly offset from slider range (bars start/end outside slider track)
- Responsive resize causes histogram to jump relative to slider
- Bar for year 2020 appears at position that corresponds to 2018 on slider
- Bootstrap column gutters create gap between slider and histogram

**Phase to address:**
Phase 5 (Year filter alignment fix) — must establish shared container pattern before adjusting layout

---

### Pitfall 6: Button Reordering Breaking Existing Input Observers

**What goes wrong:**
Reordering toolbar buttons changes DOM order but doesn't update `observeEvent()` bindings — buttons appear to stop working or trigger wrong actions. Example: moving "Edit Search" button after "Refresh" causes Edit Search click to trigger refresh behavior.

**Why it happens:**
Shiny input bindings are stable regardless of DOM order, but developer confusion about which `ns("action")` corresponds to which visual button. The real risk is copy-paste errors when restructuring UI — duplicate IDs or wrong observer names.

**How to avoid:**
1. Keep input IDs and observer names in sync: `actionButton(ns("refresh_search"), ...)` → `observeEvent(input$refresh_search, ...)`
2. Use unique, descriptive IDs: NOT `btn1`, `btn2` — USE `edit_search`, `refresh_search`, `seed_citation_network`
3. After reordering UI, search codebase for all references to moved button ID
4. Test every button after reordering: click each button and verify expected modal/action
5. Use browser dev tools to verify button `id` attribute matches expected namespace

**Warning signs:**
- Button click has no effect (observer never fires)
- Wrong modal appears when clicking button
- Console shows "input$X is undefined" after clicking button
- Button disables but action never completes

**Phase to address:**
Phase 6 (Toolbar button reordering) — verification phase AFTER reordering, before color changes

---

### Pitfall 7: Color Harmonization Touching Secondary Ragnar Store Leak

**What goes wrong:**
Changing button classes from `btn-outline-secondary` to `btn-outline-info` across modules inadvertently modifies the re-index button styling. This triggers developer to read `ensure_ragnar_store()` code, discovering the known secondary ragnar leak (PROJECT.md line 249). Developer "fixes" the leak during color refactor, introducing breaking changes in a cosmetic phase.

**Why it happens:**
Scope creep during cosmetic changes. Color harmonization SEEMS safe, but searching for `btn-outline-secondary` reveals critical code paths. The ragnar leak is known tech debt deferred to future milestone — fixing it mid-refactor creates untested changes in production code.

**How to avoid:**
1. Color changes should ONLY modify CSS classes, never touch reactive logic
2. Before changing class on buttons near reactive code, verify observer doesn't depend on that class
3. Document known tech debt in phase plan to avoid "helpful" fixes during wrong phase
4. If tech debt is discovered during refactor, add TODO comment and move on — do not fix
5. Use git grep to find all uses of class being changed, verify none are in observer conditions

**Warning signs:**
- Cosmetic phase PR includes changes to `.R` files in server logic
- Phase plan says "button color" but diff shows `observeEvent()` modifications
- Test failures after "simple CSS change"
- Developer comment "while I was here, I also fixed..."

**Phase to address:**
Phase 7 (Color harmonization) — establish "CSS-only" rule before starting work

---

### Pitfall 8: OpenAlex Cursor Format Assumptions in Pagination Logic

**What goes wrong:**
Developer assumes cursor is a simple integer offset or base64-encoded JSON. Code attempts to parse, increment, or validate cursor format. OpenAlex changes cursor encoding, app breaks with "invalid cursor" errors.

**Why it happens:**
Cursor is documented as "opaque encoded string" but developers treat it like structured data. Temptation to add "smart" pagination logic (e.g., "show page X of Y") requires parsing cursor, which breaks when API changes encoding.

**How to avoid:**
1. Treat cursor as completely opaque — never parse, decode, or validate format
2. Only three cursor operations: store cursor from response, pass cursor to next request, set to NULL on reset
3. DO NOT display "page number" or "X of Y results" — cursor pagination doesn't support this
4. DO NOT check if cursor is "valid" before sending — let OpenAlex return error if invalid
5. Store cursor as-is in reactiveVal: `cursor_state(api_response$meta$next_cursor)`

**Warning signs:**
- Code contains `base64_decode(cursor)` or `jsonlite::fromJSON(cursor)`
- UI shows "Page 3 of 12" with cursor-based pagination
- Code checks `is.character(cursor) && nchar(cursor) > 0` before API call
- Cursor is modified or transformed before passing to API

**Phase to address:**
Phase 2 (OpenAlex cursor pagination) — API client implementation, prevent future maintenance burden

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `observe()` instead of `observeEvent()` for button handlers | Saves 2 lines (no explicit event) | Reactive invalidation loop risk, hard to debug | Never — always use `observeEvent()` for user actions |
| Storing cursor in notebook database | Preserves pagination across sessions | Cursor expiry (unknown TTL) causes stale state bugs | Never — cursors are ephemeral, reset on session start |
| Tooltip via `title` attribute instead of bslib | Works in dynamic renderUI, no JS needed | Less polished UX, no customization, no dark mode support | Acceptable for icon buttons in loops (performance trade-off) |
| Hardcoding per_page=25 instead of using config | One less setting to manage | Can't adjust without code change | Never — already in config (PROJECT.md line 2214) |
| Skipping cursor reset on filter change | Simpler filter observer code | Produces invalid results, confuses users | Never — breaks core functionality |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenAlex cursor pagination | Assuming cursor survives filter changes | Reset cursor to NULL when ANY filter changes (year, type, keywords, journal quality) |
| OpenAlex per_page limit | Using per_page > 200 to "get all results faster" | OpenAlex docs say 1-100 range, codebase uses 25 default (line 2214) — verify 200 is max |
| bslib tooltip + renderUI | Wrapping dynamic UI with `tooltip()` and expecting it to persist | Use `title` attribute for dynamic content OR add JS reinit handler |
| Bootstrap grid alignment | Placing slider and histogram in sibling columns | Place in same container `div()`, use `theme(plot.margin = margin(0,0,0,0))` |
| Shiny module namespacing | Forgetting `ns()` when adding new inputs to module UI | Always wrap input IDs: `actionButton(ns("new_button"), ...)` |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-rendering entire paper list on cursor append | UI flickers, slow response on Load More | Use `insertUI()` to append new papers instead of re-rendering full list | >100 papers in list |
| Tooltip initialization on every renderUI | Lag when switching filters, memory leak | Use `title` attribute for frequently re-rendered elements | >20 tooltips in dynamic UI |
| 400ms year slider debounce too aggressive | Users drag slider, release, wait 400ms, THEN histogram updates | Use 200ms debounce for visual feedback, 400ms for API calls | Never — 400ms is good |
| Keyword filter reactive chain firing on every keystroke | Lag when typing in search box | Already debounced — DO NOT remove debounce | N/A (already prevented) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Load More button visible when cursor is NULL | User clicks, gets "no more results" — confusing because Refresh just ran | Conditionally render Load More only when cursor exists: `if (!is.null(cursor_state())) { ... }` |
| No visual distinction between Refresh and Load More | User confuses "get new papers" with "append more of same query" | Use different icons: Refresh = rotate, Load More = circle-plus; add tooltips explaining difference |
| Year histogram updates but slider stays static after Load More | User expects slider range to expand when older/newer papers load | Update slider bounds after Load More: `updateSliderInput(session, "year_range", min = new_min, max = new_max)` |
| Document type filters show 6 checkboxes, all checked by default | Visual clutter, user doesn't know they're filtering | Default to "all types" (no filter), add "Customize types" collapsible section |
| Icon-only buttons without tooltips or aria-labels | Screen reader users can't identify button purpose; visual users guess | Always pair icon buttons with tooltip: `actionButton(..., title = "Seed Citation Network")` OR `bslib::tooltip(actionButton(...), "Save notebook")` |

## "Looks Done But Isn't" Checklist

- [ ] **Load More button:** Often missing cursor reset on filter change — verify cursor_state(NULL) in ALL filter observers (year_range, document types, Edit Search save, keyword changes)
- [ ] **Cursor pagination:** Often missing NULL cursor check before rendering Load More — verify button only shows when `!is.null(cursor_state())`
- [ ] **Document type filters:** Often missing work_type column existence check — verify graceful degradation if column missing (existing pattern line 1997-2006)
- [ ] **Tooltip accessibility:** Often missing title attribute on icon-only buttons in dynamic UI — verify every icon button has title or bslib tooltip
- [ ] **Composable filter chain:** Often breaks when new filter added between modules — verify order: papers_data → keyword → journal → display, NO filters between keyword and journal
- [ ] **Year slider alignment:** Often misaligned with histogram due to plot margins — verify `theme(plot.margin = margin(0,0,0,0))` and same container div
- [ ] **Button observer bindings:** Often copy-pasted with wrong IDs after reordering — verify each button ID matches its observer name
- [ ] **Reactive invalidation loops:** Often created by reading reactive value inside observer that modifies same value — verify `isolate()` used when reading cursor_state inside load-more observer

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Reactive invalidation loop from cursor state | LOW | 1. Add `isolate(cursor_state())` in load-more observer; 2. Restart Shiny app; 3. Test Load More button |
| Cursor state not reset on filter change | LOW | 1. Add `cursor_state(NULL)` to filter observer; 2. Test: change filter → verify Load More hidden → click Refresh → verify Load More appears if results > per_page |
| Composable filter chain broken by document type filter | MEDIUM | 1. Move document type filtering into `papers_data()` reactive; 2. Test keyword → journal quality → display chain; 3. Verify "no papers" state with all filters active |
| bslib tooltip not appearing on dynamic UI | LOW | 1. Replace `bslib::tooltip()` with `title` attribute; 2. Test tooltip appears after re-render; 3. Add aria-label for screen readers |
| Year slider/histogram misalignment | LOW | 1. Wrap both in single container div; 2. Verify ggplot2 uses `theme(plot.margin = margin(0,0,0,0))`; 3. Test responsive resize |
| Button reordering breaks observer | LOW | 1. Search codebase for button ID; 2. Verify observer name matches; 3. Click button to test; 4. Check browser console for errors |
| Color change touches ragnar leak code | HIGH | 1. Revert all logic changes; 2. Keep ONLY CSS class changes; 3. Re-run full test suite; 4. Defer ragnar leak fix to future milestone |
| OpenAlex cursor parsing breaks on format change | MEDIUM | 1. Remove all cursor parsing logic; 2. Store cursor as-is; 3. Remove "page X of Y" UI; 4. Test pagination with opaque cursor |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Reactive invalidation loop from cursor state | Phase 1 (Refresh/Load-More split) | Click Load More 5 times → verify no infinite loop, paper count increases by per_page each time |
| Cursor state invalidation on filter change | Phase 2 (OpenAlex cursor pagination) | Change year filter → verify Load More hidden → click Refresh → verify Load More appears if cursor exists |
| Document type filter breaking composable chain | Phase 3 (Document type expansion) | Select keyword → uncheck all types → verify empty list; toggle journal quality → verify filter still works |
| bslib tooltip not appearing on dynamic UI | Phase 4 (Tooltip addition) | Hover button → trigger re-render → hover again → verify tooltip still appears |
| Year slider/histogram misalignment | Phase 5 (Year filter alignment) | Resize browser to 768px → verify bars align with slider; drag slider → verify bars update in sync |
| Button reordering breaking observers | Phase 6 (Toolbar reordering) | Click every button in toolbar after reorder → verify correct modal/action fires |
| Color harmonization touching ragnar leak | Phase 7 (Color harmonization) | Run git diff before commit → verify ONLY class attribute changes, no .R server logic changes |
| OpenAlex cursor format assumptions | Phase 2 (OpenAlex cursor pagination) | Code review: search for "cursor" → verify no parsing/decoding/validation logic, only store/pass/reset |

## Additional Shiny-Specific Pitfalls

### Pitfall 9: Year Slider Debounce Losing Last Value on Rapid Interaction

**What goes wrong:**
User drags year slider rapidly, releases at 2018, but 400ms debounce means the slider value that triggers reactive is 2019 (the second-to-last position during drag). Histogram and paper list show 2019, but slider thumb shows 2018.

**Why it happens:**
`debounce(year_range_raw, 400)` delays reactive invalidation by 400ms. During rapid drag, multiple values queue up, and debounce only fires for the value that was set 400ms ago, not the final value.

**How to avoid:**
1. Current implementation is CORRECT (line 974): `year_range <- debounce(year_range_raw, 400)`
2. DO NOT reduce debounce below 200ms — creates reactive storm
3. Accept minor UX quirk: debounce is necessary to prevent histogram re-render on every slider step
4. Alternative: use Apply Filter button (like citation network Phase 24) for deliberate interaction

**Warning signs:**
- User reports "slider shows 2018 but papers are from 2019"
- Histogram updates before user finishes dragging (debounce too short)
- App becomes unresponsive during slider drag (no debounce)

**Phase to address:**
Phase 5 (Year filter alignment) — verify debounce value is appropriate, document UX trade-off in plan

---

### Pitfall 10: Module Namespace Collision When Adding Tooltips to Nested Modules

**What goes wrong:**
Adding tooltips with IDs to buttons inside keyword filter module — tooltip IDs collide when multiple search notebooks are open (Shiny Server multi-session scenario). Tooltip for "Include" button in Notebook A triggers when hovering button in Notebook B.

**Why it happens:**
Shiny module namespacing (`ns()`) creates unique IDs per module instance, but if tooltip ID is hardcoded or not namespaced, it becomes global. bslib's `tooltip(..., id = "keyword_tooltip")` needs `id = ns("keyword_tooltip")` inside module.

**How to avoid:**
1. Always use `ns()` for tooltip IDs inside modules: `tooltip(..., id = ns("tooltip_id"))`
2. Test with two search notebooks open: hover button in Notebook 1, verify tooltip doesn't appear in Notebook 2
3. If tooltip doesn't need programmatic updates, omit `id` parameter (auto-generated unique ID)
4. Use browser dev tools to verify tooltip `id` has module prefix: `search_notebook_1-keyword_filter-tooltip_id`

**Warning signs:**
- Tooltip appears in wrong notebook when hovering
- JavaScript console shows "Tooltip with id X already exists"
- Tooltip update via `update_tooltip()` affects wrong module instance

**Phase to address:**
Phase 4 (Tooltip addition) — namespace verification for tooltips in keyword/journal filter modules

---

## Sources

### OpenAlex API Documentation
- [Paging | OpenAlex technical documentation](https://developers.openalex.org/how-to-use-the-api/get-lists-of-entities/paging) — cursor pagination mechanics, per_page limits (1-100)
- [OpenAlex API Tutorials](https://github.com/ourresearch/openalex-api-tutorials/blob/main/notebooks/getting-started/paging.ipynb) — cursor usage examples
- OpenAlex documentation explicitly warns cursors are opaque and should not be parsed

### Shiny Reactive Programming
- [Chapter 16 Escaping the graph | Mastering Shiny](https://mastering-shiny.org/reactivity-components.html) — `isolate()` and `observeEvent()` patterns
- [Chapter 15 Common Application Caveats | Engineering Production-Grade Shiny Apps](https://engineering-shiny.org/common-app-caveats.html) — reactive invalidation loops, observe vs observeEvent
- [Event handler — observeEvent • shiny](https://rstudio.github.io/shiny/reference/observeEvent.html) — handler expression executed within isolate() scope

### bslib Tooltips
- [Tooltips & Popovers • bslib](https://rstudio.github.io/bslib/articles/tooltips-popovers/index.html) — dynamic UI pattern with renderUI, update_tooltip() usage
- [Shiny - Shiny for R updates: tooltips, popovers, a new theme, and more](https://shiny.posit.co/blog/posts/bslib-tooltips/) — combining tooltips with dynamic UI
- Bslib docs confirm tooltips need reinitialization after renderUI, recommend `title` attribute for dynamic content

### Bootstrap 5 Grid System
- [Grid system · Bootstrap v5.3](https://getbootstrap.com/docs/5.3/layout/grid/) — flexbox column alignment, responsive gutters
- [Columns · Bootstrap v5.0](https://getbootstrap.com/docs/5.0/layout/columns/) — column width calculations, alignment utilities

### Project-Specific Context
- `.planning/PROJECT.md` lines 249, 2214 — secondary ragnar leak known tech debt, abstracts_per_search config
- `R/mod_search_notebook.R` lines 794-798, 974, 1997-2006 — composable filter chain, year debounce, work_type column check
- `R/api_openalex.R` lines 293-376 — search_papers() implementation, per_page parameter

---

*Pitfalls research for: v11.0 Search Notebook UX improvements (toolbar, filters, pagination, tooltips, alignment)*
*Researched: 2026-03-06*
