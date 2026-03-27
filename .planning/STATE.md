---
gsd_state_version: 1.0
milestone: v20.0
milestone_name: Shiny Reactivity Cleanup
status: roadmap_ready
last_updated: "2026-03-27"
last_activity: 2026-03-27 — Roadmap created, phases 64-67 defined
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-26)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** v20.0 Shiny Reactivity Cleanup — ready to begin Phase 64

## Current Position

Phase: 64 (not started)
Plan: —
Status: Roadmap ready, awaiting phase planning
Last activity: 2026-03-27 — Roadmap created, phases 64-67 defined

```
[Phase 64] [ Phase 65 ] [ Phase 66 ] [ Phase 67 ]
[  0/1   ] [   0/1   ] [   0/1   ] [   0/1   ]
```

Progress: 0/4 phases complete

## Performance Metrics

**Velocity:**

- Total plans completed: 105 (v1.0–v16.0)
- Total phases completed: 63 (v1.0–v16.0)
- Milestones shipped: 15 (v1.0–v16.0)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

### Pending Todos

- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R (out of scope for v20.0 — defer to v21+)
- 13 pre-existing test fixture failures (missing schema columns)

### Blockers/Concerns

None — all v20.0 phases are structurally independent, ordered by regression risk only.

### Phase Ordering Rationale

- Phase 64 first: additive-only changes (req(), isolate() guards) catch NULL crashes before lifecycle testing
- Phase 65 second: observer destroy-before-create fixes across mod_slides.R, mod_document_notebook.R, mod_search_notebook.R
- Phase 66 third: cross-cutting error handling standardization after structural fixes are stable
- Phase 67 last (or parallel): fully isolated DB migration audit, no reactive dependencies

### Key Research Flags

- Phase 64 patterns: standard, no open questions (req() and isolate() placement rules documented in CLAUDE.md)
- Phase 65 templates: mod_document_notebook.R and mod_research_refiner.R are authoritative destroy-before-create examples
- Phase 66 pattern: modal-then-notify documented in FEATURES.md Pattern D
- Phase 67 needs hands-on read of all 9 migration SQL files before planning — confirm CREATE TABLE IF NOT EXISTS usage

---
*Updated: 2026-03-27 — roadmap created for v20.0*
