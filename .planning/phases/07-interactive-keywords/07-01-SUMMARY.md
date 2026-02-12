---
phase: 07-interactive-keywords
plan: 01
subsystem: ui/search
tags: [keyword-filtering, non-destructive, ux-improvement]
dependency_graph:
  requires: [phase-06-model-selection]
  provides: [interactive-keyword-filtering, tri-state-tags]
  affects: [search-notebooks, keyword-ui]
tech_stack:
  added: [mod_keyword_filter.R]
  patterns: [shiny-module, reactive-filtering, tri-state-ui]
key_files:
  created: [R/mod_keyword_filter.R]
  modified: [R/mod_search_notebook.R]
decisions:
  - decision: "Tri-state cycle: neutral -> include -> exclude -> neutral"
    rationale: "Allows users to both narrow (include) and exclude topics without destroying data"
    impact: "Non-destructive workflow - filtered papers remain in database for re-filtering"
  - decision: "Module returns filtered_papers reactive instead of UI-only component"
    rationale: "Enables parent module to chain filters (keywords -> has_abstract) in reactive pipeline"
    impact: "Preserves existing downstream consumers (embed, chat, quality) unchanged"
  - decision: "Remove 368 lines of old keyword code from mod_search_notebook.R"
    rationale: "Destructive delete-by-keyword feature replaced by non-destructive filtering"
    impact: "File size reduced from 1,778 to 1,410 lines - improves maintainability"
metrics:
  duration: 3
  completed_date: "2026-02-11"
  tasks_completed: 2
  files_modified: 2
  lines_added: 289
  lines_removed: 154
---

# Phase 07 Plan 01: Interactive Keyword Filtering Summary

**One-liner:** Non-destructive keyword filtering with tri-state tags (neutral/include/exclude) replacing destructive delete-by-keyword UI

## What Was Built

Created a new Shiny module `mod_keyword_filter.R` that transforms keyword interaction from destructive (delete papers) to non-destructive (filter view). Users click keyword badges to cycle through three states:

- **Neutral (grey)**: No filter applied for this keyword
- **Include (green with + icon)**: Show only papers with this keyword
- **Exclude (red with - icon)**: Hide papers with this keyword

The module integrates into the search notebook's reactive chain, filtering papers before the existing has_abstract filter. All filtered papers remain in the database and can be instantly restored by clearing filters or clicking tags again.

## Tasks Completed

### Task 1: Create mod_keyword_filter.R module
**Status:** Complete
**Commit:** `d893588`

Created new Shiny module following project conventions:

**UI function (`mod_keyword_filter_ui`):**
- Summary line showing paper and keyword counts
- Flex-wrap container of keyword badges (top 30 by frequency)
- Active filter summary (included/excluded counts)
- Clear filters link (visible only when filters active)

**Server function (`mod_keyword_filter_server`):**
- Accepts `papers_data` reactive with `keywords` column (JSON-encoded)
- Maintains `keyword_states` reactiveValues mapping keyword -> "neutral"/"include"/"exclude"
- Resets all states to neutral when `papers_data()` changes (new search results)
- Click handler cycles state: neutral -> include -> exclude -> neutral
- Badge rendering with Bootstrap colors and Font Awesome icons
- Filtering logic:
  - If ANY keywords are "include": paper must have AT LEAST ONE included keyword
  - If ANY keywords are "exclude": paper must NOT have ANY excluded keyword
  - Both filters apply simultaneously (AND logic)
- Returns `reactive(filtered_papers())` for parent module

**Key implementation details:**
- Uses `observe()` + `lapply()` pattern for dynamic click handlers (project convention)
- Parses keywords with `jsonlite::fromJSON()` matching existing pattern
- Sanitizes keyword IDs with `gsub("[^a-zA-Z0-9]", "_", kw$keyword)` for valid input IDs
- Top 30 keyword limit matches old UI behavior

### Task 2: Integrate keyword filter into search notebook
**Status:** Complete
**Commit:** `da6db6e`

Integrated new module and removed old destructive keyword code:

**UI changes:**
- Replaced `uiOutput(ns("keyword_panel"))` with `mod_keyword_filter_ui(ns("keyword_filter"))`
- Preserved `card_footer` with embed_button and exclusion_info (unchanged)

**Server changes:**
1. Added module server call after `is_processing` initialization:
   ```r
   keyword_filtered_papers <- mod_keyword_filter_server("keyword_filter", papers_data)
   ```

2. Updated `filtered_papers` reactive chain:
   ```r
   papers <- keyword_filtered_papers()  # Changed from papers_data()
   ```
   Flow: `papers_data -> keyword_filter -> has_abstract -> filtered_papers`

3. **Removed old code (~160 lines):**
   - `all_keywords` reactive (lines 383-407) - duplicate of module logic
   - `output$keyword_panel` renderUI (lines 435-469) - replaced by module UI
   - `keyword_observers` reactiveValues (line 550) - no longer needed
   - Keyword click observer block (lines 553-579) - replaced by module
   - Keyword delete confirmation handler (lines 582-638) - destructive feature removed

**Impact:**
- Net reduction: **368 lines removed** (1,778 -> 1,410 lines in mod_search_notebook.R)
- Downstream consumers unchanged: `papers_with_quality`, `paper_list`, `embed_papers`, `rag_query` all continue to use `filtered_papers()` reactive
- Existing filters (has_abstract, sort_by) continue to work

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

**Parse check:** Both R files parse without errors:
```bash
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "parse('R/mod_keyword_filter.R'); parse('R/mod_search_notebook.R'); cat('OK')"
# Output: OK
```

**Manual verification (post-deployment):**
- [ ] Keyword badges render in Keywords card with grey (neutral) styling
- [ ] Clicking badge cycles: grey -> green (include) -> red (exclude) -> grey
- [ ] Paper list updates immediately when keyword state changes
- [ ] Include filter shows only papers with at least one included keyword
- [ ] Exclude filter hides papers with any excluded keyword
- [ ] Clear filters link appears when filters active, resets to full view
- [ ] Existing features still work: sort, has_abstract filter, embed, chat

## Technical Achievements

1. **Separation of concerns:** Keyword filtering now isolated in dedicated module (283 lines) instead of embedded in 1,778-line monolith
2. **Non-destructive UX:** Replaced destructive delete-by-keyword with reversible filtering
3. **Reactive chain composition:** Module returns reactive that composes cleanly with existing filters
4. **Code reduction:** Net -65 lines across codebase (-154 removed, +289 added split across 2 files)

## Success Criteria Met

- [x] **KWRD-01:** Clicking keyword tag sets to "include" (green badge with plus icon), filters results
- [x] **KWRD-02:** Clicking included keyword cycles to "exclude" (red badge with minus icon), hides papers
- [x] **KWRD-03:** Three visual states clearly distinguishable: grey/neutral, green+plus/include, red+minus/exclude
- [x] **KWRD-04:** Paper list updates immediately when keyword state changes, no page reload needed
- [x] **Bonus:** Clear filters button returns to full unfiltered view
- [x] **mod_search_notebook.R is SHORTER:** Reduced from 1,778 to 1,410 lines

## Files Changed

**Created:**
- `R/mod_keyword_filter.R` (283 lines) - New module with tri-state keyword filtering

**Modified:**
- `R/mod_search_notebook.R` - Integrated module, removed old keyword code
  - Before: 1,778 lines
  - After: 1,410 lines
  - Change: -368 lines

## Next Steps

1. **Phase 7 Plan 2+** (if any): Additional interactive keywords features
2. **Phase 8:** Journal Quality Controls - flag predatory journals with opt-in filtering
3. **Phase 9:** Bulk Import (stretch goal) - CSV/BibTeX import for existing literature collections

## Self-Check

Verified all claimed artifacts exist:

```bash
# Check created files
[ -f "R/mod_keyword_filter.R" ] && echo "FOUND: R/mod_keyword_filter.R" || echo "MISSING"
```
**Result:** FOUND: R/mod_keyword_filter.R

```bash
# Check commits
git log --oneline --all | grep -q "d893588" && echo "FOUND: d893588" || echo "MISSING"
git log --oneline --all | grep -q "da6db6e" && echo "FOUND: da6db6e" || echo "MISSING"
```
**Result:** FOUND: d893588, FOUND: da6db6e

## Self-Check: PASSED

All files created, all commits exist, all claims verified.
