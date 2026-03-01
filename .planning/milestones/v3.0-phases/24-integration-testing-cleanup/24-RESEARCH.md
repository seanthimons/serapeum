# Phase 24: Integration Testing & Cleanup - Research

**Researched:** 2026-02-17
**Domain:** R/testthat integration testing, ragnar RAG pipeline, Shiny app startup lifecycle
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Auto-delete on app startup — no user confirmation required
- Delete unconditionally — don't check whether per-notebook stores exist first (shared store is obsolete regardless)
- Show a brief toast notification: "Legacy search index removed" (non-blocking)
- Clean up ALL legacy RAG files in data/, not just `data/serapeum.ragnar.duckdb` — includes .wal files and any other legacy embedding artifacts

### Claude's Discretion
- Integration test scope and depth (happy path vs edge cases)
- Test infrastructure choices (where tests live, mocking strategy)
- Exact list of legacy files to clean up (investigate what exists in data/)
- Order of operations (test first or cleanup first)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

## Summary

Phase 24 closes out v3.0 with two deliverables: integration tests validating the per-notebook RAG workflow end-to-end, and a toast notification for the legacy shared store deletion that already runs at startup. Most of the hard work was done in prior phases; this phase is primarily additive.

The legacy deletion code is already implemented in `app.R` (lines 29-39, added in Phase 22). It logs via `message()` and silently removes files. What's missing is the `showNotification()` toast. The challenge is architectural: the deletion runs in global scope before the `server` function is defined, so `showNotification()` cannot be called there directly. The toast must be deferred to a one-time `observe()` block inside the server.

For integration tests, the workflow (chunk -> insert -> build_index -> retrieve) is fully exercisable without hitting the OpenRouter API by using a mock embed function. The `ragnar_store_create()` API accepts any function as `embed`, making it straightforward to inject deterministic embeddings. Importantly, `ragnar_retrieve()` requires the index to be built first via `ragnar_store_build_index()` before VSS search works.

**Primary recommendation:** Write integration tests in a new `test-ragnar-integration.R` file using a mock embed function for offline testing, and add a deferred `showNotification()` observer in the server to fire the toast after the legacy deletion runs at startup.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.x | Test framework | Already in use across all test files |
| ragnar | installed | Store operations | Hard dependency per v3.0 decision |
| DBI + duckdb | installed | Database ops | Already in use throughout |
| withr | installed | Temporary directories, cleanup | Already used in test-ragnar-helpers.R |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rlang | installed | `rlang::hash()` for chunk deduplication | Used in `insert_chunks_to_ragnar()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Mock embed in tests | Real OpenRouter calls | Mock is offline, deterministic, no API cost |
| Single integration test file | Extending existing test-ragnar.R | New file keeps unit vs integration tests separate |

## Architecture Patterns

### Recommended Project Structure
```
tests/testthat/
├── test-ragnar-helpers.R    # Unit tests (pure functions) — existing
├── test-ragnar.R            # Ragnar component tests — existing
└── test-ragnar-integration.R  # NEW: end-to-end workflow tests
```

### Pattern 1: Mock Embed Function for Integration Tests
**What:** Use a deterministic mock embed function that returns random-but-consistent embeddings so ragnar store creation and retrieval work offline.
**When to use:** All integration tests that need a working ragnar store without an API key.
**Example:**
```r
# Source: ragnar docs (ragnar_store_create accepts any embed function)
# Deterministic mock: same text produces same embedding vector
mock_embed <- function(texts) {
  # Return small-dimensional embeddings for test speed
  # Each embedding is a row in the returned matrix
  matrix(
    vapply(texts, function(t) {
      set.seed(rlang::hash(t))  # Deterministic per text content
      runif(16)
    }, numeric(16)),
    nrow = length(texts),
    byrow = TRUE
  )
}

store <- ragnar::ragnar_store_create(
  tmp_path,
  embed = mock_embed,
  embedding_size = 16
)
```

### Pattern 2: Deferred Toast Notification for Pre-Server Deletion
**What:** The legacy store deletion runs in global scope at app startup (before `server`). A toast requires a session. Solve by tracking whether deletion happened in a global flag, then showing the toast in a one-time `observe()` inside the server.
**When to use:** Anytime you need to show a Shiny notification for work that happened before the server started.
**Example:**
```r
# In global scope (app.R, before ui/server):
legacy_store_deleted <- FALSE
legacy_store <- file.path("data", "serapeum.ragnar.duckdb")
if (file.exists(legacy_store)) {
  message("[ragnar] Removing legacy shared store: ", legacy_store)
  file.remove(legacy_store)
  for (ext in c(".wal", ".tmp")) {
    f <- paste0(legacy_store, ext)
    if (file.exists(f)) file.remove(f)
  }
  legacy_store_deleted <- TRUE
}

# In server function:
observe({
  if (legacy_store_deleted) {
    showNotification(
      "Legacy search index removed",
      type = "message",
      duration = 5  # Non-blocking, auto-dismisses
    )
  }
}) |> bindEvent(TRUE, once = TRUE)
```

### Pattern 3: Integration Test Structure (Create → Embed → Query)
**What:** Full workflow test using temp directories and mock embed.
**When to use:** TEST-01 requirement validation.
**Example:**
```r
test_that("ragnar workflow: chunk -> embed -> retrieve works end-to-end", {
  skip_if_not(requireNamespace("ragnar", quietly = TRUE))

  # Setup: temp DB and temp ragnar dir
  tmp_db <- tempfile(fileext = ".duckdb")
  tmp_dir <- withr::local_tempdir()

  con <- get_db_connection(tmp_db)
  on.exit({ close_db_connection(con); unlink(tmp_db) }, add = TRUE)
  init_schema(con)

  # Create notebook
  nb_id <- create_notebook(con, "Test Notebook", "document")

  # Create ragnar store with mock embed
  store_path <- file.path(tmp_dir, paste0(nb_id, ".duckdb"))
  mock_embed <- function(texts) matrix(runif(length(texts) * 16), nrow = length(texts))
  store <- ragnar::ragnar_store_create(store_path, embed = mock_embed, embedding_size = 16)

  # Chunk synthetic text
  pages <- c(
    "Introduction: This paper studies neural network methods.",
    "Methods: We applied gradient descent to optimize weights.",
    "Conclusion: The approach achieved 95% accuracy on benchmarks."
  )
  chunks <- chunk_with_ragnar(pages, origin = "test_paper.pdf")

  # Insert and build index
  insert_chunks_to_ragnar(store, chunks, source_id = "doc-001", source_type = "document")
  build_ragnar_index(store)

  # Retrieve
  results <- retrieve_with_ragnar(store, "neural network methods", top_k = 3)

  # Assertions
  expect_s3_class(results, "data.frame")
  expect_true(nrow(results) > 0)
  expect_true("text" %in% names(results) || "content" %in% names(results))

  DBI::dbDisconnect(store, shutdown = TRUE)
})
```

### Pattern 4: section_hint Round-Trip Test
**What:** Verify section_hint encoding survives from chunk creation through ragnar insertion and retrieval.
**Example:**
```r
test_that("section_hint encoding survives round-trip through ragnar store", {
  skip_if_not(requireNamespace("ragnar", quietly = TRUE))

  # Encode origin with section hint
  encoded_origin <- encode_origin_metadata(
    "paper.pdf#page=5",
    section_hint = "conclusion",
    doi = "10.1234/test",
    source_type = "pdf"
  )

  # Insert as chunk
  chunks <- data.frame(
    content   = "The main conclusions are...",
    page_number = 5L,
    chunk_index = 0L,
    context   = "",
    origin    = encoded_origin,
    stringsAsFactors = FALSE
  )

  # [store setup code here]
  insert_chunks_to_ragnar(store, chunks, "doc-001", "document")
  build_ragnar_index(store)

  # Retrieve and decode
  results <- retrieve_with_ragnar(store, "conclusions", top_k = 1)
  expect_true(nrow(results) > 0)

  decoded <- decode_origin_metadata(results$origin[1])
  expect_equal(decoded$section_hint, "conclusion")
})
```

### Anti-Patterns to Avoid
- **Calling `ragnar_retrieve()` before `ragnar_store_build_index()`:** Returns 0 results because the VSS index is not built. Always call `build_ragnar_index()` after inserting chunks.
- **Using `requireNamespace('ragnar', quietly=TRUE)` as a skip guard:** On this machine, renv DESCRIPTION files are broken so `requireNamespace()` returns FALSE even though ragnar IS loadable. Use `tryCatch(library(ragnar); TRUE, error=function(e) FALSE)` or simply gate on whether `ragnar::ragnar_store_create` exists.
- **Calling `showNotification()` in global scope:** Shiny notifications require an active session. Global code runs before any session exists. Defer to an observer.
- **Testing legacy deletion by checking `file.exists(legacy_store)`:** That file doesn't exist in dev (was never created in the per-notebook era). Tests must CREATE the file first, then verify deletion.
- **Using `assignInNamespace` to mock `get_notebook_ragnar_path`:** This fails in the test suite because the project isn't loaded as a package (namespace "serapeum" doesn't exist). Use `withr::local_dir()` or pass paths directly instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mock embeddings | Custom embedding server | Simple `matrix(runif(...), nrow=...)` | ragnar accepts any `function(texts) -> matrix`; no server needed |
| Temp directory cleanup | Manual `unlink()` calls | `withr::local_tempdir()` | Automatic cleanup on test exit, even on failure |
| Store lifecycle | Custom open/close wrappers | `on.exit(DBI::dbDisconnect(store, shutdown=TRUE), add=TRUE)` | ragnar stores are DuckDB connections; existing pattern works |

**Key insight:** ragnar's embed parameter is just a function `texts -> matrix`, so deterministic offline testing requires nothing more than `function(texts) matrix(runif(length(texts)*N), nrow=length(texts))`.

## Common Pitfalls

### Pitfall 1: ragnar_retrieve Returns Empty Before Index Build
**What goes wrong:** Inserting chunks and immediately calling `ragnar_retrieve()` returns 0 results.
**Why it happens:** VSS (vector similarity search) requires the HNSW index to be built. BM25 may also need indexing. `ragnar_store_build_index()` must be called after all inserts.
**How to avoid:** Always call `build_ragnar_index(store)` after inserting. In `insert_chunks_to_ragnar()` this is done explicitly by callers (document notebook module calls it after insert).
**Warning signs:** `nrow(results) == 0` even with relevant content inserted.

### Pitfall 2: Toast Cannot Fire from Global Scope
**What goes wrong:** `showNotification("Legacy search index removed")` called before `server` runs throws "cannot call shiny functions outside of a Shiny session".
**Why it happens:** `showNotification()` requires an active Shiny session.
**How to avoid:** Set a global boolean flag (`legacy_store_deleted <- TRUE`) in global scope, check it in a one-time server observer (`bindEvent(TRUE, once=TRUE)`).
**Warning signs:** Error on app startup: "Operation not allowed without an active reactive context".

### Pitfall 3: Legacy File Patterns Beyond the Main .duckdb
**What goes wrong:** Deleting `serapeum.ragnar.duckdb` but leaving `serapeum.ragnar.duckdb.wal` causes DuckDB to attempt recovery on next open (or errors if a process tries to use the WAL without the main file).
**Why it happens:** DuckDB creates WAL (write-ahead log) and `.tmp` files alongside the main database file.
**How to avoid:** Current code already handles `.wal` and `.tmp`. No other legacy files were found in `data/` — `data/ragnar/` is empty (per-notebook era), no other `.ragnar.duckdb` files exist.
**Warning signs:** Files matching `data/*.wal` or `data/*.tmp` after deletion.

### Pitfall 4: requireNamespace('ragnar') Returns FALSE Despite ragnar Being Installed
**What goes wrong:** `skip_if_not(requireNamespace('ragnar', quietly=TRUE))` skips tests that could actually run.
**Why it happens:** The renv library has packages with missing DESCRIPTION files (`One or more packages recorded in the lockfile are not installed`). `requireNamespace()` uses DESCRIPTION to validate the package; when missing, it returns FALSE even if the package DLL and R code are present.
**How to avoid:** Use `tryCatch({ library(ragnar); TRUE }, error = function(e) FALSE)` as the skip guard, or run tests via normal `Rscript` invocation (which uses `.Rprofile` to activate renv properly).
**Warning signs:** Tests in `test-ragnar.R` pass (they use `skip_if_not(requireNamespace(...))` and are skipped), but `chunk_with_ragnar()` works fine in app code.

### Pitfall 5: section_hint Not in ragnar Results
**What goes wrong:** Retrieving from ragnar store doesn't return `section_hint` as a column — it's encoded inside the `origin` string.
**Why it happens:** ragnar doesn't natively support arbitrary metadata columns. Serapeum encodes section_hint using pipe-delimited format in the `origin` field (e.g., `paper.pdf#page=5|section=conclusion|doi=...|type=pdf`).
**How to avoid:** The round-trip test must call `decode_origin_metadata(results$origin[1])` to extract `section_hint` from the returned origin string.
**Warning signs:** Looking for `results$section_hint` — that column won't exist.

## Code Examples

Verified patterns from actual codebase:

### Legacy Store Deletion (current state in app.R lines 29-39)
```r
# Source: app.R:29-39 (already implemented in Phase 22)
legacy_store <- file.path("data", "serapeum.ragnar.duckdb")
if (file.exists(legacy_store)) {
  message("[ragnar] Removing legacy shared store: ", legacy_store)
  file.remove(legacy_store)
  for (ext in c(".wal", ".tmp")) {
    f <- paste0(legacy_store, ext)
    if (file.exists(f)) file.remove(f)
  }
}
# MISSING: toast notification — must be added as server observer
```

### Insert + Index + Retrieve Pipeline (from _ragnar.R)
```r
# Source: R/_ragnar.R - insert_chunks_to_ragnar() + build_ragnar_index() + retrieve_with_ragnar()
store <- ragnar::ragnar_store_create(path, embed = embed_fn, embedding_size = N)

# Chunks must have: content, page_number, chunk_index, context, origin
insert_chunks_to_ragnar(store, chunks, source_id, "document")
build_ragnar_index(store)  # REQUIRED before retrieval

results <- retrieve_with_ragnar(store, query, top_k = 5)
# Results have: text, origin, source_type, page_number, doc_name, abstract_title
```

### Skip Guard for ragnar Tests (safe pattern)
```r
# Don't use: skip_if_not(requireNamespace('ragnar', quietly=TRUE))
# Due to renv DESCRIPTION file issues on this machine.
# Use instead:
ragnar_available <- tryCatch({
  library(ragnar)
  TRUE
}, error = function(e) FALSE)
skip_if_not(ragnar_available, "ragnar not loadable")
```

### What retrieve_with_ragnar Returns
```r
# Source: R/_ragnar.R:retrieve_with_ragnar()
# Columns: text, origin, source_type, page_number, doc_name, abstract_title
# Note: column may be "text" not "content" — check both in assertions
results <- retrieve_with_ragnar(store, query, top_k = 5)
# Access text as: results$text (ragnar native column name)
# Access origin: results$origin  <- pipe-delimited, use decode_origin_metadata()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `digest::digest` for chunk hashes | `rlang::hash()` | Phase 23 | Removes digest dependency |
| Shared `serapeum.ragnar.duckdb` | Per-notebook `data/ragnar/{nb_id}.duckdb` | Phase 22 | File isolation, multi-notebook support |
| Legacy deletion without toast | Deletion + deferred toast (this phase) | Phase 24 | User awareness of migration |

**Deprecated/outdated:**
- `data/serapeum.ragnar.duckdb`: Deleted on startup. No migration — legacy embeddings are deleted (per v3.0 decision).
- Shared ragnar store pattern: Replaced by `get_notebook_ragnar_path(notebook_id)`.

## Open Questions

1. **Can `ragnar_retrieve()` work with BM25-only (no embed)?**
   - What we know: `ragnar_retrieve()` uses hybrid VSS + BM25. With a mock embed, VSS results will be meaningless (random embeddings), but BM25 text search should work.
   - What's unclear: Whether the hybrid retrieval still returns correct BM25 matches when VSS results are noise.
   - Recommendation: Test with mock embed and verify at least ONE result is returned for a query containing exact text from the inserted chunks. If retrieval is unreliable with random embeds, test only that `nrow(results) >= 0` (store is queryable) rather than asserting specific content.

2. **Which other legacy files exist in `data/` beyond `serapeum.ragnar.duckdb`?**
   - What we know: Current `data/` contains: `notebooks.duckdb`, `ragnar/` (empty), `support/` (RDS files), `test_006.duckdb`, `test_migration.duckdb`. No `serapeum.ragnar.duckdb` file exists in dev.
   - What's unclear: Whether any `.wal` or `.tmp` companion files could exist alongside other DB files.
   - Recommendation: The locked decision says "clean up ALL legacy RAG files" — the only legacy RAG file was `serapeum.ragnar.duckdb` and its WAL/tmp companions. The current code handles exactly this. No additional patterns found.

3. **What is the correct `embedding_size` for the mock embed in tests?**
   - What we know: The OpenRouter embed model `openai/text-embedding-3-small` produces 1536-dimensional embeddings. The mock can use any size.
   - What's unclear: Whether ragnar enforces size consistency across inserts.
   - Recommendation: Use a small size (16 or 32) for test speed. The size only needs to be consistent within a single test store.

## Sources

### Primary (HIGH confidence)
- Codebase: `R/_ragnar.R` — full implementation of all ragnar wrapper functions
- Codebase: `app.R` lines 19-39 — existing legacy deletion code
- Codebase: `tests/testthat/test-ragnar-helpers.R` — existing test patterns
- Codebase: `tests/testthat/test-ragnar.R` — existing ragnar tests
- Context7: `/tidyverse/ragnar` — `ragnar_store_create`, `ragnar_store_insert`, `ragnar_store_build_index`, `ragnar_retrieve` API

### Secondary (MEDIUM confidence)
- Observed behavior: Running `testthat::test_dir()` with renv reports 100 passing tests, confirming test infrastructure works
- Observed behavior: `requireNamespace('ragnar', quietly=TRUE)` returns FALSE due to broken DESCRIPTION files — safe skip guard requires `tryCatch(library(ragnar)...)` pattern

### Tertiary (LOW confidence)
- Whether BM25 alone (with random VSS) returns meaningful results in hybrid search — not verified experimentally.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from existing test files and renv.lock
- Architecture (deferred toast pattern): HIGH — standard Shiny pattern for deferred server actions
- Architecture (integration test with mock embed): HIGH — ragnar API docs confirm embed is a plain function
- Pitfalls (requireNamespace issue): HIGH — directly observed during research
- Pitfalls (retrieve before index): MEDIUM — inferred from ragnar docs; not tested in this session

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable domain, 30 days)
