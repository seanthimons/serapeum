---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
last_updated: "2026-03-02T04:09:40.114Z"
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 5
  completed_plans: 5
---

---
gsd_state_version: 1.0
milestone: v8.0
milestone_name: Multi-Seeded Citation Network
status: in-progress
last_updated: "2026-03-02T03:43:00Z"
progress:
  total_phases: 41
  completed_phases: 40
  total_plans: 71
  completed_plans: 71
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** v8.0 in progress — Phase 40.1 (HOTFIX) active

## Current Position

Phase: 40.1 (App Crashing - HOTFIX)
Plan: 2/2 complete
Status: Phase complete
Last activity: 2026-03-02 — Phase 40.1 Plan 02 complete: UI cleanup (physics toggle, button layout, notification deduplication)

Progress: [████████████████████] 72/72 plans (100%)

## Performance Metrics

**Velocity:**
- Total plans completed: 72 (67 from v1.0-v7.0 + 5 from v8.0)
- Total phases completed: 41 (across all milestones)
- v8.0 plans completed: 5 (Phase 40: 3, Phase 40.1: 2 — COMPLETE)
- v7.0 plans completed: 14 (Phase 33: 1, Phase 34: 2, Phase 35: 2, Phase 36: 2, Phase 37: 2, Phase 38: 2, Phase 39: 3)

**Recent Milestones:**
- v8.0 (Phases 40, 40.1): 4 plans, 1 day (2026-03-01 → 2026-03-02)
- v7.0 (Phases 33-39): 14 plans, 3 days (2026-02-25 → 2026-02-27)
- v6.0 (Phases 30-32): 8 plans, 3 days (2026-02-22 → 2026-02-25)
- v5.0 (Phase 29): 1 plan, <1 day (2026-02-22)
- v4.0 (Phases 25-28): 6 plans, 3 days (2026-02-18 → 2026-02-19)

## Accumulated Context

### Roadmap Evolution

- Phase 40 added: multi-seeded citation network (renamed from Phase 01 during v8.0 milestone alignment)
- Phase 40.1 inserted after Phase 40: app crashing (URGENT)

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting future work:

- **Phase 40.1-02**: visNetworkProxy calls in Shiny modules must use session$ns() for output IDs
- **Phase 40.1-02**: Auto-triggered flows (pre_fill_doi, network_seed_request) should be silent - UI state change is sufficient feedback
- **Phase 40.1-02**: Physics toggle belongs in legend panel for logical grouping with other graph controls
- **Phase 40.1-01**: Query DB for Work ID when DOI lookup fails (silent fallback pattern)
- **Phase 40.1-01**: Fallback happens silently without user notification (better UX)
- **Phase 40-02**: Use separate network_seed_request reactive to avoid conflict with seed_request (which goes to seed discovery)
- **Phase 40-02**: Auto-switch to network view on seed button click (user then clicks Build Network)
- **Phase 40-02**: Return list from search notebook module instead of single reactive (backward compat)
- **Phase 40-01**: Per-seed BFS loop rather than unified traversal (simpler deduplication)
- **Phase 40-01**: Store seed_paper_ids as JSON array for flexibility
- **Phase 40-01**: Encode overlap via shape (diamond) rather than color (preserves year gradient)
- **v7.0**: Programmatic YAML frontmatter for slides (eliminated regex injection fragility)
- **v7.0**: LLM outputs content only, no YAML — separation of concerns
- **v7.0**: Concrete syntax examples in prompts > abstract instructions
- **v7.0**: Import run created in main session before mirai (avoids FK constraint issues)
- **v7.0**: Single-query SQL aggregation for citation audit (handles 500+ papers)
- [Phase 40]: Use navset_card_tab for side panel (Paper Details + Missing Papers tabs)
- [Phase 40]: Sort missing papers by overlap first, then citation count (overlap = more interesting)

### Pending Todos

- Explore partial BFS graph as intentional visualization mode
- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061
- 13 pre-existing test fixture failures (missing schema columns: section_hint, doi)

### Blockers/Concerns

**Known tech debt:**
- Connection leak in search_chunks_hybrid (#117)
- Section_hint not encoded in PDF ragnar origins (#118)
- Dead code: with_ragnar_store, register_ragnar_cleanup (#119)
- Tooltip overflow (#79)

## Session Continuity

Last session: 2026-03-02
Stopped at: Completed 40.1-02-PLAN.md (UI cleanup: physics toggle, button layout, notification deduplication)
Resume file: None

**Next steps:**
1. Continue v8.0 milestone or define v9.0
2. Address remaining tech debt (connection leaks, dead code)

---
*Updated: 2026-03-02 — Phase 40.1 complete: fixed crashes, UI cleanup, notification deduplication*
