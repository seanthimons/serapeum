---
phase: 25-stabilize
plan: 01
subsystem: ui
tags: [shiny, reactiveValues, observer-deduplication, cost-tracking, openalex, seed-paper]

# Dependency graph
requires:
  - phase: 22-module-migration
    provides: per-notebook ragnar store, Phase 22 observers in mod_search_notebook.R
  - phase: 24
    provides: clean codebase base for stabilize phase
provides:
  - Observer deduplication for paper delete, block journal, unblock journal, network delete
  - Seed paper inserted into abstracts at notebook creation (BUGF-01 Part A)
  - Seed paper pinned to row 1 in papers_data reactive (BUGF-01 Part B)
  - Live model pricing fetched at startup for all OpenRouter models (BUGF-03)
  - Search refresh notification shows newly-added count only (BUGF-04)
  - Collapsible keywords panel in search notebook UI (PR 115)
affects: [26-debt-resolution, 27-ui-polish, 28-literature-review-table]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Observer deduplication: reactiveValues() as ID registry; skip if observer already tracked; NULL-out after fire"
    - "Live pricing refresh: observeEvent(effective_config(), once=TRUE) calls list_chat_models() at startup"
    - "Newly-added counter: increment only on actual INSERT, skip duplicates silently"
    - "Seed paper pinning: read seed_paper_id from search_filters JSON, rbind seed row to front"

key-files:
  created: []
  modified:
    - app.R
    - R/mod_search_notebook.R

key-decisions:
  - "PR 112 applied manually to feature branch (not merged via GitHub) due to merge conflict with PR 115 squash; all observer deduplication patterns included"
  - "Seed paper inserted before citation loop so it always exists in notebook regardless of API results"
  - "Pricing fetch wrapped in tryCatch so API failure does not block app startup"
  - "newly_added counter declared outside the for loop and used in the notification after withProgress closes"

patterns-established:
  - "Observer dedup pattern: if (is.null(observers[[id]])) { observers[[id]] <- observeEvent(..., { ...; observers[[id]] <- NULL }) }"
  - "Seed paper pinning: check seed_paper_id from filters JSON, move matching row to position 1 via rbind"

# Metrics
duration: 45min
completed: 2026-02-18
---

# Phase 25 Plan 01: Land PRs + Fix BUGF-01/03/04 Summary

**Observer deduplication (PR 112 pattern) applied to all delete/block/unblock handlers; BUGF-01 seed paper inserted and pinned to row 1; BUGF-03 live pricing fetched at startup; BUGF-04 refresh shows newly-added count**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-02-18
- **Completed:** 2026-02-18
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- PR 115 (collapsible keywords panel) merged to main
- PR 112 duplicate toast fix applied to feature branch (manual port due to merge conflict)
- BUGF-01: Seed paper inserted into abstracts at notebook creation AND pinned to row 1 in papers_data
- BUGF-03: Live model pricing fetched via list_chat_models() and list_embedding_models() on startup
- BUGF-04: Search refresh notification shows "Added N new papers (M total)" instead of raw API count

## Task Commits

Each task was committed atomically:

1. **Task 1: Land pending PRs 112 and 115** - `bfa7dff` (feat)
2. **Task 2: Fix BUGF-01, BUGF-03, BUGF-04** - `322e531` (fix)

## Files Created/Modified

- `app.R` - Seed paper insertion in discovery_request handler (BUGF-01 Part A); live pricing observer at startup (BUGF-03); delete_network_observers deduplication (PR 112)
- `R/mod_search_notebook.R` - papers_data reactive pins seed to row 1 (BUGF-01 Part B); delete_observers / block_journal_observers / unblock_journal_observers deduplication (PR 112); newly_added counter in do_search_refresh (BUGF-04)

## Decisions Made

- PR 112 could not be merged via GitHub (copilot branch was stale vs main after PR 115 squash). Changes ported manually to feature/25-stabilize. PR 112 closed with explanation comment.
- Seed paper insertion uses `paper_id` (OpenAlex work ID) as the duplicate check key, not DOI, per plan specification.
- Pricing fetch uses `once = TRUE` on the observeEvent to run only at startup (not on every config change).
- embedding models from list_embedding_models() have `price_per_million` column; manually mapped to `prompt_price`/`completion_price` (0 for completion) before calling update_model_pricing().

## Deviations from Plan

None - plan executed exactly as written. PR 112 merge conflict was handled per the plan's contingency: "If coverage is missing sites: merge what it has, then add the missing observer deduplication in Task 2" — in this case, the entire PR was applied in Task 1 as a manual port rather than a merge.

## Issues Encountered

- PR 112 had a merge conflict with PR 115 (both modified mod_search_notebook.R). Resolved by checking out the PR 112 branch, attempting rebase (failed), aborting, and manually applying all diffs from the PR diff review to the feature branch. All changes confirmed applied via grep verification.
- Test suite has pre-existing failures (missing schema columns for `section_hint` in chunks and `doi` in abstracts, missing `serapeum` namespace, missing `delete_notebook_store` function). These are schema migration issues not caused by this plan's changes. 100 tests pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All BUGF-01..04 requirements addressed in plan 01 (BUGF-02 via PR 112 applied, BUGF-01/03/04 fixed directly)
- Both UIPX PRs landed (PR 112 applied, PR 115 merged to main)
- Feature branch `feature/25-stabilize` is pushed and ready for Phase 25 plan 02 (DEBT-01..03 and remaining UI polish)
- Pre-existing test failures should be addressed in a future phase (schema migration tests need `section_hint` and `doi` columns added to test fixtures)

---
*Phase: 25-stabilize*
*Completed: 2026-02-18*
