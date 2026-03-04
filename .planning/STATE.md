---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Network Graph Polish
status: unknown
last_updated: "2026-03-03T21:28:12.022Z"
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 8
  completed_plans: 8
---

---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Network Graph Polish
status: unknown
last_updated: "2026-03-03T18:21:56.393Z"
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 7
  completed_plans: 7
---

---
gsd_state_version: 1.0
milestone: v9.0
milestone_name: Network Graph Polish
status: planning
last_updated: "2026-03-04T15:09:32Z"
progress:
  total_phases: 44
  completed_phases: 43
  total_plans: 76
  completed_plans: 76
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-02)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** v9.0 Network Graph Polish

## Current Position

Phase: 43 (tooltip-overhaul)
Plan: 01 (complete)
Status: Plan 43-01 complete — awaiting next plan
Last activity: 2026-03-04 — Completed 43-01 tooltip HTML rendering and dark mode styling

Progress: [████████████████████] 76/76 plans (100%)

## Performance Metrics

**Velocity:**
- Total plans completed: 76 (across v1.0–v9.0 in-progress)
- Total phases completed: 43 (across all milestones)

**Recent Milestones:**
- v9.0 (Phases 41-43 in-progress): 3 plans so far (2026-03-04)
- v8.0 (Phases 40, 40.1): 6 plans, 2 days (2026-03-01 → 2026-03-02)
- v7.0 (Phases 33-39): 14 plans, 3 days (2026-02-25 → 2026-02-27)

## Accumulated Context

### Recent Decisions

**Phase 43-01 (Tooltip Overhaul):**
- Use custom tooltip via htmlwidgets::onRender instead of vis.js default title property — vis.js renders title as textContent not innerHTML, breaking HTML formatting
- Store tooltip HTML in custom tooltip_html column and set title=NA to disable vis.js default tooltip
- Detect dark mode in JS using data-bs-theme attribute and apply inline styles to custom tooltip
- Sanitize old saved networks by extracting paper_title from <b>...</b> tags in legacy tooltip HTML
- Position tooltip using onstationary event instead of MutationObserver — more reliable for initial placement

**Phase 42-01 (Year Filters + Network Trimming):**
- Move trim toggle from legend panel to year filter area for better UX grouping
- Convert 'unknown year' checkbox to switch for consistency with other toggles
- Stack trim toggle and unknown year toggle vertically for cleaner layout
- Use adaptive citation percentile threshold (50th for 20-49 nodes, 75th for 50+ nodes)
- Skip bridge detection for networks > 500 nodes (performance optimization)

**Phase 41-01 (Physics Stabilization):**
- Always pass full solver config when re-enabling vis.js physics — calling `visPhysics(enabled=TRUE)` without config reverts to barnesHut solver
- Validate positions on data directly (x/y columns present + non-NA) — render flags are unreliable for saved graph loading
- Use debounced reactives for user-triggered state changes that could be spammed (300ms for physics toggle, 1000ms for interaction-end)
- Size threshold for ambient drift: ≤20 nodes (small networks drift, large networks freeze)

### Pending Todos

- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061
- 13 pre-existing test fixture failures (missing schema columns: section_hint, doi)

### Blockers/Concerns

**Known tech debt:**
- Connection leak in search_chunks_hybrid (#117)
- Section_hint not encoded in PDF ragnar origins (#118)
- Dead code: with_ragnar_store, register_ragnar_cleanup (#119)

## Session Continuity

Last session: 2026-03-04
Stopped at: Completed 43-01-PLAN.md (tooltip HTML rendering and dark mode styling)
Resume file: None

**Next steps:**
1. Phase 43 complete (1/1 plans done) — determine if more phases needed or milestone complete
2. Feature branch per phase, test before merge

---
*Updated: 2026-03-04 — Phase 43-01 complete (tooltip overhaul)*
