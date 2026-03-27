---
gsd_state_version: 1.0
milestone: v20.0
milestone_name: Shiny Reactivity Cleanup
status: executing
last_updated: "2026-03-27T20:13:26.806Z"
last_activity: 2026-03-27
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 18
  completed_plans: 17
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-26)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 67 — infrastructure

## Current Position

Phase: 67 (infrastructure) — EXECUTING
Plan: 2 of 2
Status: Ready to execute
Last activity: 2026-03-27

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

- [Phase 64-additive-guards]: Added explicit is.na() check in match_aa_model guard — nzchar(NA_character_) returns TRUE in R, not NA, so plan's shorthand was incorrect
- [Phase 64-additive-guards]: GARD-02 audit confirmed no code changes needed — all fig_refresh reads are safe in observeEvent/isolate contexts
- [Phase 65-01]: LIFE-01 chip handlers confirmed at module init level — no restructuring needed
- [Phase 65-01]: docs_reactive() caches list_documents() — renderUI blocks consume reactive instead of calling DB directly
- [Phase 65]: delete_doc_observers added to cleanup loop — equally needs teardown alongside fig_action_observers and extract_observers
- [Phase 65]: mod_slides.R onSessionEnded hook body is empty by design — chip handlers are pre-allocated at init per LIFE-01, no observer store to destroy
- [Phase 66-error-handling]: show_error_toast() extracted to utils_notifications.R — sourced automatically by app.R glob loop
- [Phase 66-error-handling]: modal-then-notify pattern: removeModal() -> show_error_toast() -> is_processing(FALSE) -> NULL applied to all 9 preset error handlers

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
