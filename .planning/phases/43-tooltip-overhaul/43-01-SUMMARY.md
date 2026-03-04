---
phase: 43-tooltip-overhaul
plan: 01
subsystem: ui
tags: [vis.js, tooltip, dark-mode, catppuccin, html-rendering, htmlwidgets]

# Dependency graph
requires:
  - phase: 42-year-filters-network-trimming
    provides: Citation network graph with year filters and trimming
provides:
  - Custom HTML tooltip implementation using htmlwidgets::onRender
  - Dark mode tooltip styling with Catppuccin Mocha palette
  - Tooltip containment within graph bounds with correct coordinate math
  - paper_title preservation in nodes data for saved network compatibility
affects: [future-graph-features, tooltip-enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Custom vis.js tooltip using htmlwidgets::onRender + onstationary event"
    - "JS dark mode detection via data-bs-theme attribute"
    - "HTML sanitization regex for legacy saved network data"

key-files:
  created: []
  modified:
    - R/citation_network.R
    - R/mod_citation_network.R
    - www/custom.css

key-decisions:
  - "Use custom tooltip via htmlwidgets::onRender instead of vis.js default title property — vis.js renders title as textContent not innerHTML, breaking HTML formatting"
  - "Store tooltip HTML in custom tooltip_html column and set title=NA to disable vis.js default tooltip"
  - "Detect dark mode in JS using data-bs-theme attribute and apply inline styles to custom tooltip"
  - "Sanitize old saved networks by extracting paper_title from <b>...</b> tags in legacy tooltip HTML"
  - "Position tooltip using onstationary event instead of MutationObserver — more reliable for initial placement"

patterns-established:
  - "Custom tooltip pattern: tooltip_html column + title=NA + htmlwidgets::onRender"
  - "Dark mode detection pattern: read data-bs-theme from document root"
  - "Legacy data migration: regex-based HTML sanitization for saved graphs"

requirements-completed: [TOOL-01, TOOL-02]

# Metrics
duration: N/A (user-completed)
completed: 2026-03-04
---

# Phase 43 Plan 01: Tooltip Overhaul Summary

**Custom HTML tooltips with dark mode support and proper containment — switched from vis.js default to htmlwidgets::onRender implementation**

## Performance

- **Duration:** N/A (user-completed)
- **Started:** 2026-03-03
- **Completed:** 2026-03-04
- **Tasks:** 3 (user verified)
- **Files modified:** 3

## Accomplishments

- Fixed tooltip HTML rendering by replacing vis.js default tooltip with custom implementation using htmlwidgets::onRender
- Enhanced dark mode tooltip styling with Catppuccin Mocha palette (rounded corners, border, shadow)
- Fixed tooltip containment within graph bounds (all edges: left, right, top, bottom)
- Preserved paper_title field for saved network compatibility with HTML sanitization for legacy data

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix tooltip HTML rendering and reposition logic** - `890b25d` (fix)
   - Additional fixes during verification:
     - `45f0e17` (fix): Replaced MutationObserver with custom tooltip via htmlwidgets::onRender
     - `e4128cc` (fix): Moved tooltip HTML to tooltip_html column, set title=NA
     - `97421d2` (fix): Fixed paper_title clobbering for saved networks

2. **Task 2: Enhance dark mode tooltip CSS** - `9b24305` (feat)

3. **Task 3: Verify tooltip containment and dark mode** - (checkpoint - user approved)

**Plan metadata:** (to be created in final commit)

## Files Created/Modified

- `R/citation_network.R` - Custom tooltip HTML generation with first author + et al., tooltip_html column, paper_title preservation
- `R/mod_citation_network.R` - Custom tooltip implementation using htmlwidgets::onRender + onstationary event, dark mode detection, legacy data sanitization
- `www/custom.css` - Enhanced dark mode tooltip styling (Catppuccin border, shadow, rounded corners)

## Decisions Made

**Custom tooltip approach over vis.js default:**
- vis.js default tooltip renders strings as textContent not innerHTML, so HTML tags appear as literal text
- Solution: Use htmlwidgets::onRender to create custom div on hover, styled with inline CSS based on dark mode detection
- Store tooltip HTML in custom `tooltip_html` column, set `title=NA` to disable vis.js default

**Dark mode detection in JavaScript:**
- Read `data-bs-theme` attribute from document root instead of relying on CSS classes
- Apply inline styles to custom tooltip div based on theme value
- Catppuccin Mocha palette: Surface0 background (#313244), Text color (#cdd6f4), Overlay0 border (#6c7086)

**Legacy saved network handling:**
- Old saved networks have tooltip HTML in title field, clobbering paper_title
- Solution: Sanitize on load using regex to extract title from `<b>...</b>` tags
- Preserve paper_title to database for future loads

**Tooltip positioning:**
- Switched from MutationObserver to onstationary event for initial placement
- More reliable than watching DOM mutations

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] vis.js default tooltip renders HTML as text**
- **Found during:** Task 1 verification
- **Issue:** Plan assumed vis.js title property would render HTML, but vis.js uses textContent, showing raw `<b>` tags
- **Fix:** Replaced entire tooltip approach with custom div created in htmlwidgets::onRender using onstationary event
- **Files modified:** R/mod_citation_network.R
- **Verification:** Tooltips show formatted bold title, line breaks work correctly
- **Committed in:** 45f0e17

**2. [Rule 3 - Blocking] tooltip_html custom column needed**
- **Found during:** Task 1 verification
- **Issue:** Cannot use title property for both vis.js default tooltip and custom data — they conflict
- **Fix:** Created tooltip_html column for HTML data, set title=NA to disable vis.js tooltip
- **Files modified:** R/citation_network.R, R/mod_citation_network.R
- **Verification:** Custom tooltip shows correct HTML, no vis.js default tooltip appears
- **Committed in:** e4128cc

**3. [Rule 1 - Bug] paper_title clobbered by tooltip HTML in saved networks**
- **Found during:** Task 1 verification
- **Issue:** Old saved networks have tooltip HTML in title column, overwriting paper_title on load
- **Fix:** Sanitize legacy HTML using regex extracting title from `<b>...</b>` tags, save paper_title to database
- **Files modified:** R/citation_network.R, R/mod_citation_network.R
- **Verification:** Loaded saved network shows correct paper titles, new saves preserve paper_title
- **Committed in:** 97421d2

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking)
**Impact on plan:** All deviations necessary for correctness — discovered that vis.js default tooltip implementation was fundamentally incompatible with HTML rendering. Custom tooltip approach required additional data structure changes (tooltip_html column) and legacy data handling.

## Issues Encountered

**vis.js tooltip API limitations:**
- Original MutationObserver approach in plan assumed vis.js would render HTML properly
- Discovered vis.js uses textContent not innerHTML for title strings
- Required architectural shift to custom tooltip implementation
- Resolution: htmlwidgets::onRender with onstationary event for reliable positioning

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for next plan in Phase 43 (tooltip overhaul) if more work needed, or transition to Phase 44.

All tooltip issues (#79, #127) resolved:
- Tooltips stay within graph bounds (no overlap with side panel)
- Dark mode tooltips readable with proper contrast
- HTML rendering works correctly (bold, line breaks)
- Saved networks load correctly with preserved paper_title

## Self-Check: PASSED

**Files verified:**
- FOUND: .planning/phases/43-tooltip-overhaul/43-01-SUMMARY.md

**Commits verified:**
- FOUND: 1c3b1ea (docs: complete plan)
- FOUND: 97421d2 (fix: sanitize old tooltip HTML)
- FOUND: e4128cc (fix: use tooltip_html column)
- FOUND: 45f0e17 (fix: replace vis.js tooltip)
- FOUND: 9b24305 (feat: enhance dark mode CSS)
- FOUND: 890b25d (fix: tooltip HTML rendering)

All task commits and documentation exist on disk and in git history.

---
*Phase: 43-tooltip-overhaul*
*Completed: 2026-03-04*
