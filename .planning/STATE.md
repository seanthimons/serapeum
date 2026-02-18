# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-18)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 25 — Stabilize (v4.0) — COMPLETE

## Current Position

Phase: 25 of 28 (Stabilize) — COMPLETE
Plan: 2 of 2 — COMPLETE
Status: Phase 25 complete; ready for Phase 26
Last activity: 2026-02-18 — 25-02 complete: DEBT-01/02/03 + UIPX-03/04 fixed

Progress: [██░░░░░░░░] 40% (v4.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 43 (across v1.0-v4.0 stabilize)
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
| v4.0 | 25-28 | 2/5 | In Progress | — |

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

### Pending Todos

- Explore partial BFS graph as intentional visualization mode
- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061 — store opened for indexing but never explicitly closed (deferred from 25-02)

### Blockers/Concerns

- Phase 28: LLM table compliance is model-dependent and cannot be pre-validated; test with real notebooks at 3, 10, and 20 paper scales during implementation

## Session Continuity

Last session: 2026-02-18
Stopped at: Completed 25-02-PLAN.md (DEBT-01/02/03 fixed, UIPX-03/04 polished on feature/25-stabilize)
Resume file: none

**Next action:** Phase 25 complete — merge feature/25-stabilize to main, then begin Phase 26
