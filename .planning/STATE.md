# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-10)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration
**Current focus:** Phase 4 - Startup Wizard + Polish (in progress)

## Current Position

Phase: 4 of 4 (Startup Wizard + Polish)
Plan: 2 of 2 in current phase
Status: Complete - 2 of 2 plans complete
Last activity: 2026-02-11 -- Completed 04-01 Startup Wizard

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 6 minutes
- Total execution time: 1.09 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0-foundation | 1 | 25 min | 25 min |
| 1-seed-paper-discovery | 2 | 5 min | 2.5 min |
| 2-query-builder-sorting | 2 | 6 min | 3 min |
| 3-topic-explorer | 2 | 17 min | 8.5 min |
| 4-startup-wizard-polish | 2 | 17 min | 8.5 min |

**Recent Trend:**
- Last 5 plans: 03-01 (2m), 03-02 (15m), 04-02 (1m), 04-01 (16m)
- Trend: 04-01 moderate execution (UI modal with localStorage integration)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- shiny:connected event used for localStorage checks to avoid race conditions with Shiny.setInputValue (04-01)
- onFlushed callback delays modal display until modules initialized (04-01)
- removeModal() called before current_view() in routing handlers to avoid state conflicts (04-01)
- modalButton("Close") allows wizard to reappear, actionLink("skip_wizard") persists preference (04-01)
- h-100 class on wizard buttons equalizes heights in three-column flex layout (04-01)
- CSS injection uses high specificity with !important to override RevealJS theme defaults (04-02)
- Citation CSS is inline in YAML frontmatter rather than separate file for self-contained slides (04-02)
- max-height: 15vh with overflow-y: auto prevents citations from pushing content off-slide (04-02)
- Dropped connections package — connConnection breaks dbWithTransaction, standard dbConnect sufficient (03-02)
- OpenAlex API key optional for topic fetching — polite pool with email works (03-02)
- Topic search includes keywords column — display_name too narrow for useful search (03-02)
- Topic consumer fetches papers outside withProgress to avoid <<- scoping issues (03-02)
- Full refresh strategy for topics cache (DELETE + bulk insert) - topics data is static enough that incremental updates not needed (03-01)
- 30-day cache TTL for topics - topics change infrequently, longer TTL reduces API load (03-01)
- Named character vectors for selectInput compatibility - IDs as values, display names as names (03-01)
- Separate hierarchy levels with explicit parent filtering - cleaner than self-join queries (03-01)
- LLM generates OpenAlex filter syntax but filter attributes are validated against allowlist before API call (02-02)
- Filter validation checks attribute names only, not values (hyphenated values like journal-article are valid) (02-02)
- Query preview shown to user with explanation, search terms, and filter string before execution (02-02)
- Sort preference is session-only (not persisted to database) (02-01)
- All metric sorts use NULLS LAST to sink papers with missing data (02-01)
- Producer-consumer pattern: discovery modules return reactive requests consumed by app.R to create notebooks (01-02)
- Discovery results populate search notebook without modifying mod_search_notebook.R (01-02)
- Phase 0 adds migration versioning before any schema changes
- Bootstrap existing databases at version 001 without re-executing init_schema (00-01)

### Pending Todos

- Bug: Seed discovery ("Discover from Paper") prompts for email even when already configured

### Blockers/Concerns

- mod_search_notebook.R is 1,760 lines -- new features must be separate modules, not additions to this file

## Session Continuity

Last session: 2026-02-11
Stopped at: Completed 04-01-PLAN.md
Resume file: .planning/phases/04-startup-wizard-polish/04-01-SUMMARY.md
Next: Phase 4 complete - all plans executed
