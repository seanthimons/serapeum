# Phase 23: Legacy Code Removal - Research

**Researched:** 2026-02-17
**Domain:** R codebase surgery — removing dual-codepath legacy embedding/retrieval, cleaning up `ragnar_available()` conditionals, and dead helper functions
**Confidence:** HIGH (all findings from direct source code inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Removal Order & Safety**
  - Single sweep — remove all legacy code across all files at once, one commit
  - Delete everything — no preservation of legacy code as comments or backup files; git history is the backup
  - Remove all traces including tests, comments, and docs — with one exception: keep `digest::digest()` in `_ragnar.R` where it's used for ragnar chunk hashing
  - Rewrite test guards: `skip_if_not(ragnar_available(), ...)` becomes unconditional (ragnar is required)
  - Delete tests that exercise removed code paths (e.g., `use_ragnar = FALSE` fallback tests)
  - Verification: grep check for zero results + app launch to confirm no errors

- **ragnar_available() Handling**
  - Delete all if/else branches — keep only the ragnar code path, unconditional
  - No startup check for ragnar installation — app assumes ragnar is always present
  - Remove `use_ragnar` parameters from function signatures entirely (e.g., `process_pdf`)
  - `ragnar_available()` function definition: Claude's discretion on whether to delete entirely or stub, based on caller analysis

- **search_chunks() vs search_chunks_hybrid()**
  - Claude's discretion on whether to delete `search_chunks()` entirely or alias it to `search_chunks_hybrid()`, based on caller analysis

- **Dependency Cleanup Scope**
  - Keep digest package — it's used in ragnar pipeline for chunk hashing, not just legacy code
  - Amend ROADMAP success criteria: remove LEGC-04 (digest removal) or reword to reflect digest stays
  - Light audit beyond the 3 targets — remove obviously dead helper functions left behind by the migration
  - Clean up library() calls in app.R for packages only used by legacy code paths

### Claude's Discretion

- Whether to delete `ragnar_available()` definition entirely or keep as TRUE stub
- Whether to delete `search_chunks()` or alias to `search_chunks_hybrid()`
- Which helper functions qualify as "obviously dead" during light audit
- Exact ordering of removals within the single sweep

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 23 is a codebase surgery phase: no new features, no new tests, only deletions and simplifications. The goal is to remove the dual-codepath structure introduced before ragnar was made a hard dependency, leaving only the ragnar path unconditionally.

The scope is well-bounded. There are exactly 6 production R files with `ragnar_available()` references: `db.R`, `mod_document_notebook.R`, `mod_search_notebook.R`, `pdf.R`, `rag.R`, and `_ragnar.R`. Legacy embedding code (`get_embeddings` in production paths, cosine similarity) lives in `db.R`, `rag.R`, `mod_document_notebook.R`, and `mod_search_notebook.R`. Test coverage of legacy paths exists in two test files: `test-ragnar.R` and `test-embedding.R`.

The most important pre-planning discovery: `ragnar_available()` is called inside `_ragnar.R` itself (in `insert_chunks_to_ragnar`, `retrieve_with_ragnar`, `build_ragnar_index`, `connect_ragnar_store`, `get_ragnar_store`, `chunk_with_ragnar`). Because these functions are only called when ragnar is known to be present, the guards are purely defensive boilerplate that becomes dead code once ragnar is a hard dependency. The definition itself can be deleted cleanly — no caller outside `_ragnar.R` guards behavior on it at the module level (the module-level callers in `db.R`, `pdf.R`, etc. contain the `if/else` blocks that will be removed).

**Primary recommendation:** Delete `ragnar_available()` entirely — its callers are all `if/else` blocks being removed, and the internal `_ragnar.R` guards are just defensive no-ops once ragnar is required. Delete `search_chunks()` (the legacy cosine-similarity version) entirely — its only production caller is inside the legacy fallback block in `rag.R` that will be removed; alias it to nothing.

---

## Architecture Patterns

### Current Dual-Codepath Structure (to be removed)

The pattern repeated across multiple files:

```r
# Pattern A — conditional execution (most common)
if (ragnar_available()) {
  # ragnar path
} else {
  # legacy path: get_embeddings() + cosine_similarity()
}

# Pattern B — parameter-gated
if (use_ragnar && ragnar_available()) {
  # ragnar chunking/search
}
# fallback below
```

### Target Structure (after removal)

```r
# All legacy conditionals collapse to unconditional ragnar calls:
chunk_with_ragnar(pages, origin, ...)  # always used
search_chunks_hybrid(con, query, ...)  # always used
```

---

## File-by-File Removal Inventory

This is the complete, verified inventory of what needs to change. Each item was confirmed by source code inspection.

### `R/_ragnar.R`

**What to do:** Remove the `ragnar_available()` function definition (lines 139–142). Remove the `requireNamespace("digest", quietly = TRUE)` check — it is only in `ragnar_available()` which is deleted. Remove `ragnar_available()` guards from internal functions: `insert_chunks_to_ragnar` (line 912), `retrieve_with_ragnar` (line 948), `build_ragnar_index` (line 997), `connect_ragnar_store` (line 194), `get_ragnar_store` (line 156), `chunk_with_ragnar` (line 221). These guards collapse to unconditional execution. Keep `digest::digest()` at line 920 intact.

**Also dead:** `check_ragnar_version()` (lines 300–368) — defined but never called from any production or test code. Qualifies as "obviously dead" left by prior migration work. Delete it.

**Keep intact:** `digest::digest()` call at line 920 inside `insert_chunks_to_ragnar`. `get_embeddings()` call inside `get_ragnar_store` (line 173) — this is the ragnar-path embed function, not legacy.

```r
# KEEP (line 173 in _ragnar.R) — this is ragnar's embed function, NOT legacy:
embed_via_openrouter <- function(texts) {
  result <- get_embeddings(openrouter_api_key, embed_model, texts)
  do.call(rbind, result$embeddings)
}
```

Note: `get_embeddings()` in `api_openrouter.R` is still required for ragnar store creation. Do not delete it.

### `R/db.R`

**What to delete:**
- `cosine_similarity()` function (lines 400–414) — legacy math helper, only used by `search_chunks()`
- `parse_embedding()` function (lines 419–454) — only used by `search_chunks()`
- `update_chunk_embedding()` function (lines 390–394) — only called from legacy embedding blocks in `mod_document_notebook.R` (which are also being deleted)
- `search_chunks()` function (lines 462–521) — the legacy cosine-similarity search. Its only production caller is in `rag.R`'s legacy fallback block (being removed). The decision is to delete it entirely (no alias needed — there are no callers remaining after rag.R cleanup).

**What to change in `search_chunks_hybrid()`:**
- Remove the `ragnar_available()` guard at line 847. The function currently reads `if (ragnar_available() && file.exists(ragnar_store_path)) { ... }`. This becomes just `if (file.exists(ragnar_store_path)) { ... }` (or just the unconditional ragnar path, since ragnar is now guaranteed).
- Remove the "fallback to legacy search" block (lines 974–990) — this returns an empty frame with a log message. After removal, the function simply returns early with an empty data frame if no store exists.
- Update docstring: remove mention of "Falls back to legacy cosine similarity."

### `R/rag.R`

**What to delete:**
- Remove `use_ragnar` parameter from `rag_query()` signature and its body (lines 60–121).
- Delete the legacy fallback block inside `rag_query()`: the `if (is.null(chunks) || nrow(chunks) == 0)` block that calls `get_embeddings()` then `search_chunks()` (lines 93–121).
- The function collapses to: call `search_chunks_hybrid()` unconditionally, check result, build context, generate response.
- Update docstring: remove `use_ragnar` param doc, remove "Falls back to legacy cosine similarity search" text.

**What to fix in callers:** `mod_document_notebook.R` and `mod_search_notebook.R` call `rag_query(... use_ragnar = TRUE ...)`. Remove the `use_ragnar = TRUE` argument from both call sites after the parameter is removed.

### `R/pdf.R`

**What to delete:**
- `chunk_text()` function (lines 30–58) — the legacy word-based chunker. After removal, `process_pdf()` will always use `chunk_with_ragnar()`.
- Remove `use_ragnar` parameter from `process_pdf()` signature (line 125–126).
- Remove the `if (use_ragnar && ragnar_available()) { ... }` conditional block (lines 135–170).
- Remove the legacy word-based fallback block (lines 172–210): the `for (page_num in ...)` loop that calls `chunk_text()`.
- The function body becomes: call `chunk_with_ragnar()` directly, add `section_hint` column, return result.
- Remove the `chunking_method = "word_based"` return path entirely.
- Update docstring: remove `use_ragnar` param, remove fallback mentions.

**What to keep:** `extract_pdf_text()`, `detect_section_hint()` — both still used in the ragnar path.

### `R/mod_document_notebook.R`

**What to delete:**
- Line 1 comment: `# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)` — stale after `ragnar_available()` is deleted.
- The `ragnar_available()` conditional guard at line 524 — collapses. The `if (ragnar_available() && nrow(result$chunks) > 0 && !is.null(api_key) && nchar(api_key) > 0)` becomes `if (nrow(result$chunks) > 0 && !is.null(api_key) && nchar(api_key) > 0)`.
- The `ragnar_indexed <- FALSE` tracking variable and the `if (!ragnar_indexed ...) { ... }` legacy embedding block (lines 557–594). This whole block — batch loop calling `get_embeddings()` and `update_chunk_embedding()` — is deleted.
- The `use_ragnar = TRUE` argument at the `rag_query()` call site (line 738).

**What to keep:** `rag_ready`, `store_healthy`, `ensure_ragnar_store`, `insert_chunks_to_ragnar`, `build_ragnar_index` — all ragnar path, all stay.

### `R/mod_search_notebook.R`

**What to delete:**
- Line 1 comment: `# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)` — stale.
- The `ragnar_available()` conditional at line 1984 — collapses to unconditional ragnar path. The `if (ragnar_available()) { ... }` wrapping the ragnar indexing block is removed, making ragnar indexing unconditional.
- The `ragnar_indexed <- FALSE` tracking variable and `if (!ragnar_indexed) { ... }` legacy embedding fallback block (lines 2047–2074) — entire fallback with `get_embeddings()` loop deleted.
- The `use_ragnar = TRUE` argument at the `rag_query()` call site (line 2264).

**What to keep:** `rag_ready`, `store_healthy`, `ensure_ragnar_store`, `insert_chunks_to_ragnar`, `build_ragnar_index` — all ragnar path.

---

## Test File Changes

### `tests/testthat/test-ragnar.R`

**Delete entirely:**
- Test: `"process_pdf falls back to word-based chunking without ragnar"` (lines 42–53) — exercises `use_ragnar = FALSE`, which is being removed. This test will error after the parameter is deleted.

**Rewrite (remove `skip_if_not` guards):**
- `"ragnar_available returns boolean"` (lines 18–22) — the `ragnar_available()` function no longer exists after deletion. Either delete this test or replace it with a smoke test that ragnar is loadable.
- `"chunk_with_ragnar returns expected structure when ragnar available"` (lines 24–40) — remove the `skip_if_not(ragnar_available(), ...)` guard. Make unconditional.
- `"process_pdf uses ragnar when available"` (lines 55–66) — remove `skip_if_not(ragnar_available(), ...)` guard. Remove `use_ragnar = TRUE` argument. Make unconditional.
- `"search_chunks_hybrid returns expected structure"` (lines 68–86) — remove `skip_if_not(ragnar_available(), ...)` guard. Make unconditional.
- `"get_ragnar_store requires API key for new stores"` (lines 88–98) — remove `skip_if_not(ragnar_available(), ...)` guard. Make unconditional.
- `"connect_ragnar_store returns NULL for non-existent store"` (lines 101–109) — remove `skip_if_not(ragnar_available(), ...)` guard. Make unconditional.

### `tests/testthat/test-embedding.R`

**Delete tests that exercise legacy `search_chunks()`:**
- `"search_chunks finds abstract chunks by notebook"` (lines 54–103) — exercises the deleted `search_chunks()` function with cosine similarity. Delete this test.
- `"search_chunks filters abstracts by notebook"` (lines 106–153) — same reason. Delete this test.

**Keep:**
- `"abstract chunks are created with correct source_type"` (lines 15–52) — pure DB test, no legacy code.
- `"build_context formats abstract citations correctly"` (lines 155–173) — pure formatting test, no legacy code.
- `"build_context handles mixed document and abstract sources"` (lines 175–191) — pure formatting test, no legacy code.

---

## Discretionary Recommendations

### `ragnar_available()`: Delete entirely (HIGH confidence)

**Evidence:** Every call site is an if/else block being removed. There are no callers that would remain after cleanup — the internal `_ragnar.R` guards are all defensive boilerplate being simplified. No test file exercises a `ragnar_available() == FALSE` branch that we're keeping. Deleting it is cleaner than a TRUE stub because a stub pretends the function still has meaning.

### `search_chunks()`: Delete entirely (HIGH confidence)

**Evidence:** Its only production caller is in `rag.R`'s legacy fallback block (lines 116–120), which is being deleted. The test callers (`test-embedding.R` lines 96, 141, 148) are also being deleted. After cleanup, `search_chunks()` has zero callers. There is no justification for an alias — `search_chunks_hybrid()` has a different signature (takes a text query string, not a pre-computed embedding vector), so a transparent alias would be wrong.

### `check_ragnar_version()`: Delete as obviously dead (HIGH confidence)

**Evidence:** Defined in `_ragnar.R` (lines 300–368), never called from any production file or test file. Was presumably written as a utility but never wired up. No caller exists anywhere in `R/` or `tests/`. Removing it eliminates ~70 lines of dead code.

### Other potentially dead helper: `update_chunk_embedding()` in `db.R`

**Evidence:** Its only caller is in `mod_document_notebook.R`'s legacy embedding block (line 588), which is being deleted. Delete `update_chunk_embedding()` in `db.R`.

---

## Common Pitfalls

### Pitfall 1: Stranded `get_embeddings()` References
**What goes wrong:** After removing legacy embedding blocks, `get_embeddings()` in `api_openrouter.R` (line 70) still has a legitimate caller: `get_ragnar_store()` in `_ragnar.R` at line 173 uses it inside the `embed_via_openrouter` closure for creating new ragnar stores. Do NOT delete `get_embeddings()` from `api_openrouter.R`.
**How to avoid:** Verify each deleted call site individually. The function definition stays; only the legacy call sites are removed.

### Pitfall 2: `ragnar_indexed` Variable Left Orphaned
**What goes wrong:** In `mod_document_notebook.R`, the `ragnar_indexed <- FALSE` variable declaration (line 520) exists only to gate the legacy fallback block. If the legacy block is removed but the variable declaration is left, R will show an unused variable. More critically, if `ragnar_indexed <- TRUE` (line 543) is left but the `if (ragnar_indexed)` check is gone, there's no hard error but it's dead code clutter.
**How to avoid:** Remove all three pieces together: the declaration (`ragnar_indexed <- FALSE`), the assignment (`ragnar_indexed <- TRUE`), and the gate (`if (!ragnar_indexed && ...)`).

### Pitfall 3: `process_pdf()` Return Value Shape Change
**What goes wrong:** After removing the word-based fallback, `process_pdf()` no longer returns `chunking_method = "word_based"`. The test `"process_pdf uses ragnar when available"` in `test-ragnar.R` checks `expect_equal(result$chunking_method, "ragnar")`. This test is safe to keep; just remove the `skip_if_not` guard. But callers that branched on `chunking_method` value need checking.
**Evidence:** `grep -rn "chunking_method" R/` shows `chunking_method` is set in `pdf.R` returns but never read from outside `pdf.R`. Only tests inspect it. Safe.

### Pitfall 4: `search_chunks_hybrid()` Behavior When Store Missing
**What goes wrong:** After removing the `ragnar_available()` guard from `search_chunks_hybrid()`, the function must still handle the case where no ragnar store exists (user hasn't embedded yet). Currently this falls through to the "fallback to legacy search" return (lines 974–990). After removing that block, the function needs an explicit early-return empty frame.
**How to avoid:** Replace the fallback block with a direct empty-frame return using the same column schema. The `if (file.exists(ragnar_store_path))` check already handles this — if the store doesn't exist, the ragnar branch is skipped, and the function will hit the fallback. After removing the fallback, simply end the function with `return(data.frame(...))` using the expected empty schema.

### Pitfall 5: Comment Artifacts
**What goes wrong:** Lines 1 in both `mod_document_notebook.R` and `mod_search_notebook.R`, and line 1 in `pdf.R` and `rag.R`, all say `# Note: ragnar_available() is defined in R/_ragnar.R (sourced first alphabetically)`. After `ragnar_available()` is deleted, these comments are false. They should be removed.
**How to avoid:** Include these 4 comment lines in the single sweep.

---

## Code Examples

### Before/After: `ragnar_available()` guard removal in `_ragnar.R`

```r
# BEFORE (insert_chunks_to_ragnar, line 912):
insert_chunks_to_ragnar <- function(store, chunks, source_id, source_type) {
  if (!ragnar_available() || nrow(chunks) == 0) {
    return(invisible(store))
  }
  # ...
}

# AFTER:
insert_chunks_to_ragnar <- function(store, chunks, source_id, source_type) {
  if (nrow(chunks) == 0) {
    return(invisible(store))
  }
  # ...
}
```

### Before/After: `process_pdf()` in `pdf.R`

```r
# BEFORE signature:
process_pdf <- function(path, chunk_size = 500, overlap = 50,
                        use_ragnar = TRUE, origin = NULL) {

# AFTER signature:
process_pdf <- function(path, chunk_size = 500, overlap = 50, origin = NULL) {
```

The entire body shrinks from ~85 lines to ~20 lines: extract text, call `chunk_with_ragnar()`, add `section_hint` column, return.

### Before/After: `rag_query()` in `rag.R`

```r
# BEFORE signature:
rag_query <- function(con, config, question, notebook_id, use_ragnar = TRUE, session_id = NULL) {

# AFTER signature:
rag_query <- function(con, config, question, notebook_id, session_id = NULL) {
```

The `chunks <- NULL` + the whole `if (use_ragnar && ragnar_available()) { ... }` + `if (is.null(chunks) || nrow(chunks) == 0) { ... }` block (lines 81–121) collapses to a single unconditional call:

```r
chunks <- tryCatch({
  search_chunks_hybrid(con, question, notebook_id, limit = 5)
}, error = function(e) {
  message("Search failed: ", e$message)
  data.frame()
})
```

### Before/After: Legacy fallback in `mod_document_notebook.R`

```r
# BEFORE (~75 lines):
ragnar_indexed <- FALSE
if (ragnar_available() && nrow(result$chunks) > 0 && ...) {
  # ragnar indexing block...
  ragnar_indexed <- TRUE
}
if (!ragnar_indexed && ...) {
  # legacy get_embeddings() + update_chunk_embedding() batch loop...
}

# AFTER (~15 lines):
if (nrow(result$chunks) > 0 && !is.null(api_key) && nchar(api_key) > 0) {
  # ragnar indexing block — unconditional
  store <- ensure_ragnar_store(nb_id, session, api_key, embed_model)
  if (!is.null(store)) {
    insert_chunks_to_ragnar(store, result$chunks, doc_id, "document")
    build_ragnar_index(store)
    rag_ready(TRUE)
    store_healthy(TRUE)
  }
}
```

---

## ROADMAP Amendment Required

The ROADMAP (`.planning/ROADMAP.md`) currently states:

> **Phase 23: Legacy Code Removal** - Remove ragnar_available conditionals, cosine similarity fallback, digest dependency

And success criteria include:
> 3. Digest package is removed from dependencies and no code references digest::digest()
> 4. Codebase search for "ragnar_available", "cosine", "get_embeddings" returns zero results in R files

**Amendments needed before or during execution:**
1. Reword criterion #3: "digest::digest() is retained only for chunk hashing in the ragnar pipeline (`_ragnar.R`). Legacy digest usage (in `ragnar_available()` check) is removed." Or simply remove LEGC-04 from Phase 23 scope.
2. Reword criterion #4: exclude `get_embeddings` from the zero-result grep (it's still used in `_ragnar.R` for the ragnar embed function). The grep check should be: `"ragnar_available"`, `"cosine_similarity"`, `"use_ragnar"` → zero results. `"get_embeddings"` → exactly 2 results (definition in `api_openrouter.R`, usage in `_ragnar.R` embed closure).

---

## Verification Protocol

After the single-sweep commit, run:

```bash
# These should return zero results:
grep -rn "ragnar_available" R/ --include="*.R"
grep -rn "cosine_similarity\|parse_embedding\b" R/ --include="*.R"
grep -rn "use_ragnar" R/ --include="*.R"
grep -rn "chunk_text\b" R/ --include="*.R"
grep -rn "search_chunks\b[^_]" R/ --include="*.R"   # not search_chunks_hybrid
grep -rn "check_ragnar_version" R/ --include="*.R"
grep -rn "update_chunk_embedding" R/ --include="*.R"

# These should return exactly 2 results (definition + ragnar embed closure):
grep -rn "get_embeddings" R/ --include="*.R"

# These should return exactly 1 result (chunk hashing in _ragnar.R):
grep -rn "digest::digest" R/ --include="*.R"
```

Then launch the app and verify no startup errors.

---

## Open Questions

1. **`search_chunks_hybrid()` empty-frame schema after legacy fallback removal**
   - What we know: The legacy fallback (lines 974–990) returns a data frame with columns: `id, source_id, source_type, chunk_index, content, page_number, doc_name, abstract_title, similarity`.
   - What's unclear: The ragnar-path return at line 968 doesn't include a `similarity` column — it returns ragnar's native columns plus computed `source_type`, `page_number`, `doc_name`, `abstract_title`. The empty-frame returned when no store exists should match the ragnar-path schema, not the legacy schema.
   - Recommendation: After removing the fallback, replace it with an empty frame matching the ragnar return schema (without `similarity`). Verify `build_context()` works with ragnar-path columns — it reads `doc_name`, `abstract_title`, `page_number`, `content`, which ragnar results do have.

2. **`embedding` column in `chunks` table**
   - What we know: The DB schema has an `embedding` column on the `chunks` table (used by legacy `search_chunks()`). After this phase, no code writes to or reads from this column in production.
   - What's unclear: Whether the DB migration to drop the `embedding` column is in scope for Phase 23 or a later phase.
   - Recommendation: Out of scope for Phase 23 per the phase description (code removal only, not schema migration). Note it as a future cleanup in a TODO/ROADMAP item but do not add migration here.

---

## Sources

### Primary (HIGH confidence)

- Direct inspection of `R/_ragnar.R` (lines 139–142, 156, 194, 221, 300–368, 912, 920, 948, 997)
- Direct inspection of `R/db.R` (lines 390–521, 822–991)
- Direct inspection of `R/rag.R` (lines 1–167)
- Direct inspection of `R/pdf.R` (lines 1–212)
- Direct inspection of `R/mod_document_notebook.R` (lines 1, 520–594, 738)
- Direct inspection of `R/mod_search_notebook.R` (lines 1, 1981–2074, 2264)
- Direct inspection of `tests/testthat/test-ragnar.R` (lines 1–110)
- Direct inspection of `tests/testthat/test-embedding.R` (lines 1–192)
- `renv.lock` — digest is a transitive dependency of many packages, removing it from direct use does not affect renv.lock

---

## Metadata

**Confidence breakdown:**
- Removal inventory: HIGH — verified by grep and source reading of every file
- Discretionary recommendations: HIGH — based on caller analysis, no ambiguity found
- Pitfalls: HIGH — identified from actual code structure, not speculation
- Verification protocol: HIGH — grep patterns derived from confirmed identifier names

**Research date:** 2026-02-17
**Valid until:** Until any code changes in `R/` — this is a point-in-time snapshot of the codebase
