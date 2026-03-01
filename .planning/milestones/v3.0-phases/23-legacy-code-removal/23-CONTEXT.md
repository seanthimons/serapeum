# Phase 23: Legacy Code Removal - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove all legacy embedding and retrieval code paths, making ragnar the sole RAG backend. This is a code deletion and simplification phase — no new features. The digest package stays (used in ragnar pipeline). Success criteria LEGC-04 (digest removal) must be amended.

</domain>

<decisions>
## Implementation Decisions

### Removal Order & Safety
- Single sweep — remove all legacy code across all files at once, one commit
- Delete everything — no preservation of legacy code as comments or backup files; git history is the backup
- Remove all traces including tests, comments, and docs — with one exception: keep `digest::digest()` in `_ragnar.R` where it's used for ragnar chunk hashing
- Rewrite test guards: `skip_if_not(ragnar_available(), ...)` becomes unconditional (ragnar is required)
- Delete tests that exercise removed code paths (e.g., `use_ragnar = FALSE` fallback tests)
- Verification: grep check for zero results + app launch to confirm no errors

### ragnar_available() Handling
- Delete all if/else branches — keep only the ragnar code path, unconditional
- No startup check for ragnar installation — app assumes ragnar is always present
- Remove `use_ragnar` parameters from function signatures entirely (e.g., `process_pdf`)
- `ragnar_available()` function definition: Claude's discretion on whether to delete entirely or stub, based on caller analysis

### search_chunks() vs search_chunks_hybrid()
- Claude's discretion on whether to delete `search_chunks()` entirely or alias it to `search_chunks_hybrid()`, based on caller analysis

### Dependency Cleanup Scope
- Keep digest package — it's used in ragnar pipeline for chunk hashing, not just legacy code
- Amend ROADMAP success criteria: remove LEGC-04 (digest removal) or reword to reflect digest stays
- Light audit beyond the 3 targets — remove obviously dead helper functions left behind by the migration
- Clean up library() calls in app.R for packages only used by legacy code paths

### Claude's Discretion
- Whether to delete `ragnar_available()` definition entirely or keep as TRUE stub
- Whether to delete `search_chunks()` or alias to `search_chunks_hybrid()`
- Which helper functions qualify as "obviously dead" during light audit
- Exact ordering of removals within the single sweep

</decisions>

<specifics>
## Specific Ideas

- Success criterion #3 (digest removal) needs amendment before execution — digest stays because `_ragnar.R:920` uses `digest::digest()` for chunk hashing in the active ragnar pipeline
- Success criterion #4 grep check should exclude `digest` from the search terms, or scope it to "legacy uses of digest" only
- The debate analysis found ~30 stray references across <10 files — scope is small enough for single sweep

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 23-legacy-code-removal*
*Context gathered: 2026-02-17*
