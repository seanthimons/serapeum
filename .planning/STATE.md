# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-18)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 27 — Research Question Generator (v4.0)

## Current Position

Phase: 27 of 28 (Research Question Generator) — IN PROGRESS
Plan: 1 of 1 — COMPLETE
Status: Phase 27 plan 01 complete; phase complete
Last activity: 2026-02-19 — 27-01 complete: generate_research_questions() + UI wiring

Progress: [███░░░░░░░] 50% (v4.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 44 (across v1.0-v4.0)
- Total execution time: ~8 days across 6+ milestones

**By Milestone:**

| Milestone | Phases | Plans | Status | Shipped |
|-----------|--------|-------|--------|---------|
| v1.0 | 0-4 | 9 | Complete | 2026-02-11 |
| v1.1 | 5-8 | 6 | Complete | 2026-02-11 |
| v1.2 | 9-10 | 2 | Complete | 2026-02-12 |
| v2.0 | 11-15 | 8 | Complete | 2026-02-13 |
| v2.1 | 16-19 | 7 | Complete | 2026-02-13 |
| v3.0 | 20-24 | 9 | Complete | 2026-02-17 |
| v4.0 | 25-28 | 3/5 | In Progress | — |

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

Recent decisions affecting v4.0:
- DEBT-03: with_ragnar_store() confirmed dead code and deleted (evaluated: zero callers, not needed for DEBT-01 fix)
- DEBT-01: Fixed via own_store ownership tracking + on.exit in search_chunks_hybrid; caller-owned stores never closed
- DEBT-02: section_hint encoding guarded by column presence check; abstract paths unaffected
- SYNTH-02: Use GFM markdown tables (not JSON-parsed HTML) for Literature Review Table to stay within existing message pipeline; DT widget is an optional fallback path if GFM quality is poor
- Phase 28: Literature Review Table uses direct SQL (all abstracts) not RAG top-k — comparison matrix requires complete coverage
- 25-01: Observer dedup pattern applied to all lapply+observeEvent sites; seed paper inserted at notebook creation using paper_id (not DOI) as duplicate check key; pricing fetch once=TRUE so API failure non-blocking
- 27-01: generate_research_questions() as standalone function (not added to generate_preset()); disclaimer check widened using %in% set membership for extensibility; RAG query uses gap-focused terms with limit=15; paper metadata queried separately from abstracts table

### Pending Todos

- Explore partial BFS graph as intentional visualization mode
- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061 — store opened for indexing but never explicitly closed (deferred from 25-02)

### Blockers/Concerns

- Phase 28: LLM table compliance is model-dependent and cannot be pre-validated; test with real notebooks at 3, 10, and 20 paper scales during implementation

## Session Continuity

Last session: 2026-02-19
Stopped at: Completed 27-01-PLAN.md
Resume file: none

**Next action:** Phase 27 complete — ready for Phase 28
