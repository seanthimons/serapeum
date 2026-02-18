---
phase: 25-stabilize
plan: 02
subsystem: db, ragnar, citation-network
tags: [duckdb, ragnar, connection-leak, section_hint, dead-code, tooltip, css, visnetwork]

# Dependency graph
requires:
  - phase: 25-01
    provides: base stabilize branch with BUGF-01/03/04 fixed
provides:
  - Connection-safe search_chunks_hybrid (no Windows file-lock risk)
  - section_hint encoded in new PDF ragnar origins
  - Dead code removed (with_ragnar_store, register_ragnar_cleanup)
  - Citation network tooltip stays within graph container bounds
  - Citation network uses theme-aware neutral grey background
affects: [26-debt-resolution, 27-ui-polish, 28-literature-review-table]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Connection ownership: own_store = is.null(ragnar_store); on.exit cleanup only for self-opened stores"
    - "Section hint encoding: guard with 'section_hint' %in% names(chunks) so abstract paths unaffected"
    - "Tooltip containment: MutationObserver via htmlwidgets::onRender watches .vis-tooltip and clamps to .citation-network-container bounds"
    - "Theme-aware graph background: #e8e8ee light / #1e1e2e dark via [data-bs-theme='dark'] selector"

key-files:
  created: []
  modified:
    - R/db.R
    - R/_ragnar.R
    - R/mod_citation_network.R
    - www/custom.css

key-decisions:
  - "DEBT-01: Fixed with fresh on.exit approach (own_store tracking) per user decision; caller-owned stores never closed by search_chunks_hybrid"
  - "DEBT-02: section_hint encoding guarded by column presence check so abstract indexing paths are unaffected"
  - "DEBT-03: with_ragnar_store() and register_ragnar_cleanup() deleted immediately per user decision (no evaluation needed)"
  - "UIPX-03: MutationObserver approach chosen over CSS-only approach for reliable boundary detection"
  - "UIPX-04: #e8e8ee light / #1e1e2e dark - neutral grey works with all viridis-family colorblind-safe palettes"

# Metrics
duration: ~3min
completed: 2026-02-18
---

# Phase 25 Plan 02: Tech Debt + Citation Network Polish Summary

**Connection leak fixed via own_store ownership tracking; section_hint encoded in new PDF origins; dead code deleted; citation network tooltip contained in-bounds and background is neutral grey for all themes**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-18T21:08:26Z
- **Completed:** 2026-02-18
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- DEBT-01: `search_chunks_hybrid` now tracks `own_store` flag and closes self-opened ragnar connections via `on.exit`; callers that pass a `ragnar_store` argument retain full lifecycle control
- DEBT-02: `insert_chunks_to_ragnar` encodes `section_hint` into pipe-delimited origin metadata when chunks have a `section_hint` column; existing abstract indexing paths unaffected
- DEBT-03: `with_ragnar_store()` and `register_ragnar_cleanup()` deleted (83 lines removed); zero callers confirmed
- UIPX-04: Network background changed from `#1a1a2e` (dark blue, all themes) to `#e8e8ee` (light) / `#1e1e2e` (dark mode) via `[data-bs-theme="dark"]` selector
- UIPX-03: MutationObserver added via `htmlwidgets::onRender` to watch `.vis-tooltip` insertions/moves and clamp them within `.citation-network-container` bounds using `requestAnimationFrame`

## Task Commits

Each task was committed atomically:

1. **Task 1: DEBT-01/02/03 - connection leak, section_hint encoding, dead code** - `9c16371` (fix)
2. **Task 2: UIPX-03/04 - tooltip containment and network background color** - `0dd9e4c` (fix)

## Files Created/Modified

- `R/db.R` - Added `own_store` flag and `on.exit` cleanup in `search_chunks_hybrid` (DEBT-01)
- `R/_ragnar.R` - Added section_hint encoding guard in `insert_chunks_to_ragnar` (DEBT-02); deleted `with_ragnar_store()` and `register_ragnar_cleanup()` (DEBT-03)
- `R/mod_citation_network.R` - Added MutationObserver JS via `htmlwidgets::onRender` for tooltip repositioning (UIPX-03)
- `www/custom.css` - Updated `.citation-network-container` background to `#e8e8ee`; added dark mode variant `#1e1e2e` (UIPX-04)

## Decisions Made

- DEBT-01 `own_store` approach is the cleanest and matches the pattern used in `rebuild_notebook_store` (which uses its own `own_con` flag for the same purpose)
- DEBT-02 guard (`"section_hint" %in% names(chunks)`) ensures the `rebuild_notebook_store` abstract path — which constructs chunks manually without `section_hint` — is unaffected
- DEBT-03: Both functions were dead code with zero callers; deleted without evaluation per plan specification
- UIPX-03: MutationObserver is more reliable than CSS-only `right: 0` approach because vis.js sets inline styles directly; observer fires on every tooltip appearance and repositions using `requestAnimationFrame`
- UIPX-04: `#e8e8ee` provides good contrast with viridis, magma, plasma, inferno, cividis node colors (all have mid-range saturation); `#1e1e2e` matches the existing legend dark theme color for consistency

## DEBT-01 Audit Findings

Per plan requirement, audited all ragnar callers for secondary leaks:

- **`rag.R: rag_query()`** — calls `search_chunks_hybrid(con, question, notebook_id, limit = 5)` with no `ragnar_store` arg; DEBT-01 fix covers this path (search_chunks_hybrid opens and closes its own store)
- **`R/mod_search_notebook.R:2061`** — `ensure_ragnar_store(nb_id, session, api_key_or, embed_model)` returns a store for indexing; store is used through line ~2100 but never explicitly disconnected after `build_ragnar_index(store)`. This is a secondary connection leak. **Not fixed in this plan** (per plan spec: log, don't fix). Logged as deferred item.

## Deviations from Plan

None — plan executed exactly as written.

## Deferred Items

- **Secondary leak in `mod_search_notebook.R:2061`:** `ensure_ragnar_store()` opens a store for search indexing that is never explicitly closed. Should add `on.exit(DBI::dbDisconnect(store@con, shutdown = TRUE), add = TRUE)` immediately after the store is assigned. Deferred to a future fix or Phase 26.

## Issues Encountered

- renv packages needed DESCRIPTION file restoration (renv::restore()) before tests could run; this is a pre-existing environment issue, not caused by plan changes
- Test suite has same 13 pre-existing failures as documented in 25-01 (missing schema columns for `section_hint`/`doi` in test fixtures, missing `serapeum` namespace, missing `delete_notebook_store` in test helpers); 103 tests pass

## Next Phase Readiness

- All DEBT-01..03 items resolved; connection leak risk eliminated before synthesis features added in Phases 26-28
- Citation network UI polished with correct background and tooltip containment
- Feature branch `feature/25-stabilize` ready for Phase 25 completion / PR to main

---
*Phase: 25-stabilize*
*Completed: 2026-02-18*

## Self-Check: PASSED

All files found:
- R/db.R: FOUND
- R/_ragnar.R: FOUND
- R/mod_citation_network.R: FOUND
- www/custom.css: FOUND
- .planning/phases/25-stabilize/25-02-SUMMARY.md: FOUND

All commits found:
- 9c16371 fix(25-02): DEBT-01/02/03 - connection leak, section_hint encoding, dead code
- 0dd9e4c fix(25-02): UIPX-03/04 - tooltip containment and network background color
