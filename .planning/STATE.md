# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-19)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** All v4.0 phases complete

## Current Position

Phase: 28 of 28 (Literature Review Table) -- COMPLETE
Plan: 1 of 1 -- Complete
Status: All v4.0 phases complete (25-28); Overview, Research Questions, and Lit Review features operational
Last activity: 2026-02-19 -- Merge conflict resolution: combined Phase 26 (Overview) with Phases 27-28 (Research Questions + Lit Review)

Progress: [##########] 100% (v4.0)

## Performance Metrics

**Velocity:**
- Total plans completed: 46 (across v1.0-v4.0)
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
| v4.0 | 25-28 | 5/5 | Complete | 2026-02-19 |

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
- 26-01: generate_overview_preset() uses full-corpus SQL (no LIMIT); Quick mode logs "overview", Thorough mode logs "overview_summary"/"overview_keypoints" for granular cost tracking; BATCH_SIZE 10 (doc) / 20 (search) with 300k char threshold
- 26-02: Overview replaces Summarize + Key Points in document notebook; added alongside Conclusions in search notebook; is_synthesis check expanded to c("overview", "conclusions", "research_questions", "lit_review") in both modules
- 27-01: generate_research_questions() as standalone function (not added to generate_preset()); disclaimer check widened using %in% set membership for extensibility; RAG query uses gap-focused terms with limit=15; paper metadata queried separately from abstracts table
- 28-01: GFM pipe table over DT widget (stays in message pipeline); server-side DOI injection after LLM call (not by LLM); no sticky column headers (chat panel is scroll ancestor); lapply inside repeat loop critical for dynamic token budget re-querying; plain text error message for malformed table output

### Pending Todos

- Explore partial BFS graph as intentional visualization mode
- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R L2061 — store opened for indexing but never explicitly closed (deferred from 25-02)

### Blockers/Concerns

- Phase 28: LLM table compliance is model-dependent and cannot be pre-validated; test with real notebooks at 3, 10, and 20 paper scales during implementation

## Session Continuity

Last session: 2026-02-19
Stopped at: Merge conflict resolution -- all v4.0 phases integrated
Resume file: none

**Next action:** All v4.0 phases complete. Project at 100%.
