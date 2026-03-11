---
phase: 54-tooltip-layer
plan: 01
subsystem: UI/UX
tags: [accessibility, wcag-2.2, tooltips, keyboard-nav]
dependencies:
  requires: [bslib, Bootstrap 5]
  provides: [tooltip-layer, wcag-compliance]
  affects: [R/mod_search_notebook.R, app.R, R/mod_keyword_filter.R]
tech_stack:
  added: []
  patterns: [bslib::tooltip, native-title-attributes, keyboard-accessible-tooltips]
key_files:
  created: []
  modified:
    - R/mod_search_notebook.R
    - app.R
    - R/mod_keyword_filter.R
decisions:
  - 300ms hover delay prevents flicker in dense button grids
  - Bottom placement for consistency across all tooltips
  - Export dropdown uses container body option to prevent clipping
  - Dynamic keyword badges use native title attributes (not bslib::tooltip)
  - Excluded New Search/Document Notebook buttons (labels are self-explanatory)
metrics:
  duration: 96s
  tasks: 3
  files_modified: 3
  commits: 2
  completed: "2026-03-11"
requirements_completed:
  - TOOL-05
---

# Phase 54 Plan 01: Tooltip Layer Summary

**One-liner:** Accessible, keyboard-navigable tooltips on 12 static buttons using bslib::tooltip() with 300ms delay and bottom placement, plus contextual title attributes on dynamic keyword filter badges.

## Tasks Completed

| Task | Name                                                      | Status   | Commit  |
| ---- | --------------------------------------------------------- | -------- | ------- |
| 1    | Wrap all 12 static buttons with bslib::tooltip()         | Complete | d5d9d9b |
| 2    | Add title attributes to dynamic keyword filter badges    | Complete | 098a351 |
| 3    | Human verification checkpoint                             | Approved | -       |

## What Was Built

### Static Button Tooltips (bslib::tooltip)

**Toolbar buttons (6):**
- Import: "Add papers by pasting DOIs or uploading a BibTeX file"
- Edit Search: "Change your search query, filters, or discovery method"
- Cit Network: "Build a citation network from a seed paper in your results"
- Export: "Download your current papers as BibTeX or CSV" (with container: body)
- Refresh: "Re-run your current search to check for new results"
- Load More: "Fetch the next batch of results from OpenAlex"

**Sidebar discovery buttons (6):**
- Import Papers: "Add papers by pasting DOIs or uploading a BibTeX file"
- Discover from Paper: "Find related work by using a known paper as a seed"
- Explore Topics: "Browse OpenAlex topic hierarchies to find research areas"
- Build a Query: "Use AI to help construct an effective search query"
- Citation Network: "Visualize citation relationships between papers"
- Citation Audit: "Check your collection for missing references and gaps"

All tooltips use:
- 300ms show delay (prevents flicker during cursor movement)
- 100ms hide delay (responsive dismissal)
- Bottom placement (consistent positioning)
- Bootstrap 5 native behavior (keyboard-accessible, Escape dismissible)

### Dynamic Badge Tooltips (title attributes)

Keyword filter badges now show contextual native browser tooltips:
- Neutral state: "Click to include '[keyword]' in filter"
- Include state: "Click to exclude '[keyword]'"
- Exclude state: "Click to clear '[keyword]' filter"

State-based titles provide clear affordance for the three-state cycle.

## Deviations from Plan

None. Plan executed exactly as written.

## Technical Implementation

### bslib::tooltip Pattern

```r
bslib::tooltip(
  actionButton(...),
  "Descriptive tooltip text here",
  placement = "bottom",
  options = list(delay = list(show = 300, hide = 100))
)
```

Special case for Export dropdown (btn-group container):
```r
bslib::tooltip(
  div(class = "btn-group btn-group-sm w-100", ...),
  "Download your current papers as BibTeX or CSV",
  placement = "bottom",
  options = list(delay = list(show = 300, hide = 100), container = "body")
)
```

The `container: "body"` option prevents tooltip clipping when the dropdown menu is opened.

### Title Attribute Pattern

```r
badge_title <- switch(state,
  "neutral" = paste0("Click to include '", kw$keyword, "' in filter"),
  "include" = paste0("Click to exclude '", kw$keyword, "'"),
  "exclude" = paste0("Click to clear '", kw$keyword, "' filter"),
  ""
)

actionLink(
  ns(input_id),
  span(...),
  title = badge_title
)
```

## Verification

### Automated
- Shiny smoke test passed (app starts without errors)
- All modified files validated

### Manual (User Checkpoint)
User verified:
- All 12 tooltips appear on hover with correct text
- 300ms delay prevents flicker during cursor movement
- Tooltips appear on keyboard focus (Tab navigation)
- Tooltips dismiss on Escape key
- Dark mode maintains readable contrast
- Export dropdown still functions correctly with tooltip wrapper
- Keyword badges show contextual native tooltips
- New Search/Document Notebook buttons correctly excluded from tooltip coverage

## Requirements Satisfied

**TOOL-05:** Every toolbar button has a descriptive tooltip
- ✅ All 12 static buttons (6 toolbar + 6 sidebar) have bslib::tooltip()
- ✅ Tooltips are keyboard-accessible (Tab focus triggers display)
- ✅ WCAG 2.2 compliance via Bootstrap 5 native behavior
- ✅ Tooltips are dismissible (Escape key, click outside)
- ✅ Readable in light and dark modes
- ✅ Max 15 words per tooltip (all under limit)

## Files Modified

### R/mod_search_notebook.R
- Wrapped 6 toolbar buttons with bslib::tooltip()
- Added approved descriptive copy for each button
- Special handling for Export dropdown with container: body option

### app.R
- Wrapped 6 sidebar discovery buttons with bslib::tooltip()
- Added approved descriptive copy for each button
- Excluded New Search/Document Notebook buttons (per user decision)

### R/mod_keyword_filter.R
- Added switch() logic to generate contextual title text based on filter state
- Added title parameter to actionLink() for native browser tooltips

## Impact

### User Experience
- First-time users can now discover button functions without trial-and-error
- Keyboard navigation users have equal access to tooltips (WCAG 2.2 compliance)
- 300ms delay prevents tooltip spam during rapid cursor movement
- Consistent bottom placement provides predictable visual hierarchy

### Accessibility
- WCAG 2.2 Level AA compliance for keyboard accessibility
- Tooltips are programmatically exposed to screen readers via Bootstrap 5 ARIA attributes
- Escape key provides standard dismissal behavior
- Focus management follows W3C best practices

### Developer Experience
- bslib::tooltip() is now the established pattern for static button tooltips
- Title attributes remain the pattern for dynamic elements (state-based or frequently updated)
- Clear precedent for future tooltip additions

## Next Steps

No follow-up work required. Tooltip layer is complete and verified.

---

**Execution time:** 96 seconds (1m 36s)
**Commits:** 2 feature commits
**Requirements completed:** TOOL-05

## Self-Check: PASSED

All files exist:
- ✅ R/mod_search_notebook.R
- ✅ app.R
- ✅ R/mod_keyword_filter.R

All commits exist:
- ✅ d5d9d9b (Task 1: Wrap 12 static buttons)
- ✅ 098a351 (Task 2: Add keyword badge title attributes)
