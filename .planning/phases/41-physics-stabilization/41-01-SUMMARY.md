---
phase: 41-physics-stabilization
plan: 01
subsystem: ui
tags: [vis.js, visNetwork, R, Shiny, network-visualization, physics-simulation]

# Dependency graph
requires:
  - phase: 40-multi-seeded-citation-network
    provides: Citation network visualization with multi-seed support
provides:
  - Debounced physics toggle with position validation preventing singularity collapse
  - Size-conditional ambient orbital drift for small networks (≤20 nodes)
  - Interaction-aware drift pausing (drag to pause, auto-resume after 1s)
  - Stabilization event handling with forceAtlas2Based solver configuration
affects: [42-year-filters-network-trimming, 43-tooltip-overhaul, network-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "vis.js stabilizationIterationsDone event wiring for post-stabilization logic"
    - "Debounced reactives for UI control rate-limiting (prevents rapid toggle glitches)"
    - "Position validation before physics re-enable (prevents vis.js collapse to (0,0))"
    - "Size-conditional physics parameters (different behavior for small vs large networks)"

key-files:
  created: []
  modified:
    - R/mod_citation_network.R

key-decisions:
  - "Debounce delay: 300ms for physics toggle (prevents rapid toggle glitches)"
  - "Ambient drift threshold: ≤20 nodes (small networks drift, large networks freeze)"
  - "Drift resume delay: 1000ms after user interaction ends"
  - "Drift physics parameters: gravitationalConstant = -50, centralGravity = 0.005, damping = 0.25 (gentle orbital motion)"
  - "All tuneable constants marked with #NOTE comments for future adjustment"

patterns-established:
  - "Always pass full solver config when re-enabling physics via visPhysics(enabled=TRUE) — vis.js reverts to default barnesHut solver otherwise"
  - "Validate positions on data directly (check for x/y columns with non-NA values) — render flags are unreliable"
  - "Use debounced reactives for user-triggered state changes that could be spammed"

requirements-completed: [PHYS-01, PHYS-02]

# Metrics
duration: 67min
completed: 2026-03-03
---

# Phase 41 Plan 01: Physics Stabilization Summary

**Debounced physics toggle with position validation preventing singularity collapse, plus size-conditional ambient drift for small networks**

## Performance

- **Duration:** 67 minutes
- **Started:** 2026-03-03T11:06:29-05:00
- **Completed:** 2026-03-03T12:13:50-05:00
- **Tasks:** 2 (1 auto, 1 human-verify checkpoint)
- **Files modified:** 1

## Accomplishments
- Fixed singularity collapse bug on physics toggle (PHYS-01) — positions validated before re-enable, toggle debounced at 300ms
- Added ambient orbital drift for small networks (≤20 nodes) after stabilization (PHYS-02) — gentle floating motion, pauses during interaction
- Established pattern for vis.js physics configuration: always pass full solver config when re-enabling physics to prevent vis.js defaulting to barnesHut

## Task Commits

Each task was committed atomically:

1. **Task 1: Add stabilization event, interaction events, and debounced physics toggle** - `d2106cd` (feat)
   - Additional bugfixes discovered during checkpoint verification:
     - `1f6ce49`: fix(41-01): prevent singularity collapse when loading saved graphs
     - `a009fe7`: fix(41-01): check positions on data directly, not render flag
     - `807d2f5`: fix(41-01): pass solver config when re-enabling physics via toggle
2. **Task 2: Visual verification of physics behavior** - approved (checkpoint)

**Plan metadata:** (pending final commit after STATE/ROADMAP updates)

## Files Created/Modified
- `R/mod_citation_network.R` - Added:
  - `physics_toggle_debounced` reactive (300ms debounce)
  - `ambient_drift_active` reactiveVal tracking drift state
  - `stabilization_done` event handler with size-conditional freeze/drift logic
  - `user_interacting` event handlers for drag-to-pause behavior
  - `interaction_ended_debounced` reactive (1000ms debounce) for drift resume
  - Position validation in physics toggle handler (prevents collapse)
  - Full solver config on physics re-enable (prevents vis.js reverting to barnesHut)

## Decisions Made

**Physics parameters (all marked with #NOTE comments as tuneable):**
- Debounce delay: 300ms for physics toggle (prevents rapid clicking glitches)
- Ambient drift threshold: ≤20 nodes qualify for drift, >20 nodes freeze
- Drift resume delay: 1000ms after user stops interacting (drag/click)
- Drift physics settings: `gravitationalConstant = -50, centralGravity = 0.005, damping = 0.25` (creates gentle 30-60s orbital period)

**Implementation approach:**
- Use vis.js native `stabilizationIterationsDone` event instead of custom timers
- Validate positions on data directly (`x`/`y` columns present + non-NA) — render flags unreliable
- Pass full `forceAtlas2Based` solver config when calling `visPhysics(enabled=TRUE)` — vis.js reverts to default `barnesHut` solver otherwise (causes collapse)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevent singularity collapse when loading saved graphs**
- **Found during:** Task 2 (Visual verification)
- **Issue:** Loaded graphs have positions pre-computed, but the data-change observer was forcing physics toggle ON before the first render completed, triggering position validation that passed (positions exist on data), but vis.js network wasn't rendered yet → collapse to (0,0)
- **Fix:** Check positions on data directly (non-NA x/y columns) instead of relying on render flag. Simplified position validation logic to focus on data state only.
- **Files modified:** R/mod_citation_network.R
- **Verification:** Load saved network → no collapse. Toggle physics off/on → no collapse.
- **Committed in:** `a009fe7`

**2. [Rule 1 - Bug] Pass solver config when re-enabling physics via toggle**
- **Found during:** Task 2 (Visual verification)
- **Issue:** After auto-fix #1, the physics toggle handler called `visPhysics(enabled=TRUE)` without passing the `forceAtlas2Based` solver config. vis.js interprets this as "use default barnesHut solver", causing singularity collapse despite valid positions.
- **Fix:** Pass full solver config (`solver = "forceAtlas2Based"`, `forceAtlas2Based = list(gravitationalConstant = -50, centralGravity = 0.005, damping = 0.25)`) when calling `visPhysics(enabled=TRUE)` in both the toggle handler and the drift resume handler.
- **Files modified:** R/mod_citation_network.R
- **Verification:** Toggle physics off → on → nodes resume gentle motion, no collapse.
- **Committed in:** `807d2f5`

**3. [Rule 3 - Blocking] Fix position validation for saved graph loading**
- **Found during:** Task 2 (Visual verification — initial collapse fix attempt)
- **Issue:** First attempt at collapse fix checked render flag (`!is.null(output$network_graph)`) to determine if network was ready for physics. This flag is unreliable — it's set on first render but doesn't guarantee positions are synced to vis.js.
- **Fix:** Remove render flag check entirely. Position validation now only checks data state: do nodes have `x` or `x_position` columns with non-NA values? If yes, safe to re-enable physics. If no, compute layout first.
- **Files modified:** R/mod_citation_network.R
- **Verification:** Load saved network → positions validated on data directly → physics re-enables safely.
- **Committed in:** `1f6ce49` (initial fix), refined in `a009fe7`

---

**Total deviations:** 3 auto-fixed (3 bugs discovered during checkpoint verification)
**Impact on plan:** All auto-fixes were necessary correctness fixes for edge cases not covered in initial implementation. The core position validation strategy was sound, but implementation details around saved graph loading and vis.js solver configuration required iterative refinement. No scope creep — all fixes directly serve PHYS-01 (collapse prevention).

## Issues Encountered

**vis.js solver behavior:** Calling `visPhysics(enabled=TRUE)` without passing solver config causes vis.js to revert to its default `barnesHut` solver instead of maintaining the previously configured `forceAtlas2Based` solver. This was not documented in the vis.js API reference and required verification through runtime testing. Solution: always pass full solver config when toggling physics on.

**Saved graph loading edge case:** Networks loaded from saved state have positions pre-computed in the data, but the data-change observer fires before the first `renderVisNetwork` completes. This triggered physics toggle logic that passed position validation (positions exist on data) but caused collapse because vis.js network wasn't fully initialized. Solution: check positions on data directly and let vis.js handle initialization timing — don't try to guard on render state.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 42 (Year Filters + Network Trimming):**
- Physics behavior is now stable and deterministic
- Network data reactivity is well-understood (data-change observer pattern established)
- Year filter initialization can follow the same observer pattern

**Known patterns for next phase:**
- Use debounced reactives for UI controls that might be rapidly adjusted (year range slider)
- Validate data state directly instead of relying on render flags
- Use vis.js native events (`stabilizationIterationsDone`) instead of custom timers

**No blockers for tooltip work (Phase 43):**
- Physics changes don't affect tooltip rendering pipeline

---
*Phase: 41-physics-stabilization*
*Completed: 2026-03-03*
