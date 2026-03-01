---
phase: 26-unified-overview-preset
plan: 01
subsystem: api
tags: [rag, llm, openrouter, duckdb, batching, preset]

# Dependency graph
requires:
  - phase: 19-conclusion-synthesis
    provides: generate_conclusions_preset() pattern for full-corpus LLM synthesis
  - phase: 25-stabilize
    provides: stable R/rag.R base with chat_completion(), estimate_cost(), log_cost()
provides:
  - generate_overview_preset() function in R/rag.R
  - Full-corpus SQL retrieval for both document and search notebooks (no LIMIT)
  - Quick mode (single LLM call) producing ## Summary + ## Key Points
  - Thorough mode (two sequential LLM calls) with merged output
  - Automatic batching for notebooks exceeding 300k chars or 2x BATCH_SIZE rows
  - Three cost log categories: overview, overview_summary, overview_keypoints
affects: [26-02, mod_document_notebook, mod_search_notebook]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Full-corpus retrieval via direct SQL (no RAG top-k) for synthesis presets
    - Nested helper functions (call_overview_quick, call_overview_summary, call_overview_keypoints) scoped inside preset function
    - Batching with split(seq_len(nrow(df)), ceiling(.../ BATCH_SIZE)) pattern
    - OWASP LLM01:2025 compliant prompts (instructions before data, clear BEGIN/END SOURCES delimiters)

key-files:
  created: []
  modified:
    - R/rag.R

key-decisions:
  - "Quick mode logs cost as 'overview'; Thorough mode logs 'overview_summary' and 'overview_keypoints' separately for granular cost tracking"
  - "BATCH_SIZE: 10 for document notebooks (PDF chunks avg ~500 chars), 20 for search notebooks (abstracts avg ~1500 chars)"
  - "CHAR_LIMIT: 300k characters (~75k tokens) as single-call safe threshold for 128k context models"
  - "Batching trigger: total_chars > 300k OR nrow > BATCH_SIZE * 2 (either condition activates batching)"
  - "Thematic subheading order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps (IMRAD-aligned)"

patterns-established:
  - "Full-corpus preset pattern: dbGetQuery with no LIMIT, batching guard, helper functions for each call type"
  - "Source formatting: vapply loop with sprintf, wrapped in ===== BEGIN/END SOURCES ====="

# Metrics
duration: 2min
completed: 2026-02-19
---

# Phase 26 Plan 01: Unified Overview Preset Backend Summary

**generate_overview_preset() with full-corpus SQL retrieval, Quick/Thorough modes, depth control, and automatic batching for large notebooks**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-19T15:48:13Z
- **Completed:** 2026-02-19T15:50:48Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `generate_overview_preset()` to `R/rag.R` (241 lines) as the backend engine for the unified Overview preset
- Full-corpus SQL retrieval with no LIMIT: document notebooks query chunks+documents ordered by created_at/chunk_index; search notebooks query abstracts ordered by year DESC
- Quick mode (single LLM call) produces combined ## Summary and ## Key Points output with thematic subheadings
- Thorough mode (two sequential LLM calls) separates summary and key points into independent calls, then merges with `paste0("## Summary\n\n", ..., "\n\n## Key Points\n\n", ...)`
- Batching activates when total characters exceed 300k or row count exceeds 2x BATCH_SIZE; batches are concatenated with `\n\n---\n\n` separator

## Task Commits

Each task was committed atomically:

1. **Task 1: Add generate_overview_preset() to R/rag.R** - `5c77a63` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `R/rag.R` - Added `generate_overview_preset()` function (241 new lines after existing `generate_conclusions_preset()`)

## Decisions Made
- Quick mode logs cost category `"overview"`; Thorough mode logs `"overview_summary"` and `"overview_keypoints"` separately for granular per-call cost tracking
- BATCH_SIZE set to 10 for document (PDF chunks ~500 chars each) and 20 for search (abstracts ~1500 chars each)
- Batching condition uses OR logic: `total_chars > 300000 || nrow > BATCH_SIZE * 2` so both extremely large individual-document notebooks and wide search notebooks trigger batching
- Thematic subheadings follow IMRAD order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `generate_overview_preset()` is complete and callable from Plan 02 notebook module handlers
- Function signature matches what Plan 02 research example calls: `generate_overview_preset(con, cfg, nb_id, notebook_type, depth, mode, session_id)`
- Cost categories match plan spec exactly
- Batching TODO comments in place for future merge-pass improvement

## Self-Check: PASSED

- R/rag.R: FOUND
- commit 5c77a63: FOUND
- 26-01-SUMMARY.md: FOUND

---
*Phase: 26-unified-overview-preset*
*Completed: 2026-02-19*
