# Phase 25: Stabilize - Research

**Researched:** 2026-02-18
**Domain:** R/Shiny bug fixes, Ragnar/DuckDB connection management, visNetwork tooltip/CSS, OpenRouter pricing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **BUGF-01 (seed paper visibility):** Pin seed paper as the first result in abstract search, always at top regardless of sort order
- **BUGF-02 (duplicate modals):** Check the existing open PR first — if its solution works, land it as-is rather than reimplementing
- **BUGF-03 (cost tracking):** The table refresh works fine — the real issue is that non-default models (those not on the built-in pricing list) may not show accurate costs. Fix model pricing coverage, not the refresh mechanism
- **BUGF-04 (paper count after removal):** Fix the count to update correctly after refresh following removals
- **PR landing strategy:** Land all pending PRs (UIPX-01 duplicate toasts, UIPX-02 collapsible keywords, and BUGF-02 modal PR if it exists) FIRST in a single merge pass, then fix remaining bugs on the clean base

- **DEBT-01:** Fresh approach — fix the leak however is cleanest, don't constrain to reusing with_ragnar_store()
- **DEBT-01 scope:** Fix search_chunks_hybrid leak as primary target; audit all other ragnar callers; log new issues for any found, don't fix in this phase
- **DEBT-01 verification:** Code review sufficient — no special Windows file-lock testing required

- **DEBT-02:** Add section_hint to the PDF indexing pipeline for new PDFs only — existing PDFs keep current origins
- **DEBT-03:** Remove with_ragnar_store() and register_ragnar_cleanup() immediately — don't evaluate, just delete
- **Dead code sweep:** Light sweep — remove obviously dead code encountered along the way
- **Reporting:** List all removed dead code in PR description for user review

- **UIPX-03 (tooltip containment):** Smart repositioning — tooltip flips direction dynamically to stay within graph container bounds
- **UIPX-04 (network background):** Light neutral background that works with ALL themes. Must not interfere with colorblind-safe node color palettes
- **UIPX-05 (settings layout):** Already fixed — skip

### Claude's Discretion

- Exact implementation pattern for connection leak fix (fresh approach)
- Technical approach for pinning seed paper to top of results
- Tooltip repositioning implementation details
- Which dead code qualifies as "obviously dead" during light sweep

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 25 is a housekeeping phase touching six distinct technical areas: PR landing, four bug fixes, three debt items, and four UI polishes. The codebase is well-structured R/Shiny with DuckDB via DBI and ragnar for vector search. The main technical risks are (1) the Ragnar connection leak in `search_chunks_hybrid`, which opens a DuckDB connection on every RAG query with no cleanup, and (2) the DEBT-02 pipeline gap where PDF chunks enter ragnar stores without `section_hint` encoded in their origin strings. Both are clearly scoped and low-risk to fix.

The two open PRs (112, 115) are Copilot-generated DRAFT PRs ready to evaluate: PR 112 solves BUGF-02 (duplicate toasts via observer tracking pattern), PR 115 solves UIPX-02 (collapsible keywords panel). Both look correct based on code review. The PR landing-first strategy is sound because PR 112 and the remaining BUGF-01 both touch `mod_search_notebook.R`, and landing first avoids merge conflicts.

BUGF-01 has a critical finding: the seed paper is NOT added to the notebook's abstracts table when a seed-discovery notebook is created. Only the cited-by/citing papers are added. The seed paper's OpenAlex ID is stored in `search_filters.seed_paper_id` (as JSON). The fix must either (a) insert the seed paper into the abstracts table at notebook creation time, or (b) look it up and prepend it dynamically in `papers_data()`. Option (a) is cleaner and ensures the paper persists through refreshes.

BUGF-03 is not a refresh timing bug: the cost tracker polling already provides live updates. The root issue is `pricing_env$MODEL_PRICING` in `cost_tracking.R` only has 7 hardcoded models; any other model used falls back to `DEFAULT_PRICING` ($1/$3 estimate). The fix is populating `pricing_env` from the live `/models` API response at startup.

**Primary recommendation:** Land PRs 112 and 115 first; delete DEBT-03 dead code second (zero risk); then execute the remaining work items on the clean base.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R/Shiny | `shiny` >=1.7 | UI framework | Project uses throughout |
| bslib | current | Bootstrap 5 components | All UI in bslib cards/layouts |
| DBI + duckdb | current | DB connections | Main app store |
| ragnar | current | Vector search (DuckDB-backed) | Per-notebook stores |
| visNetwork | current | Citation network graph | Already in use |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httr2 | current | HTTP requests | OpenRouter/OpenAlex API calls |
| viridisLite | current | Color palettes | Network node coloring |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| on.exit for ragnar cleanup | with_ragnar_store() wrapper | on.exit is simpler and direct; wrapper is being deleted (DEBT-03) |
| CSS for tooltip containment | visNetwork JS event | CSS alone cannot reposition; JS is needed to detect boundary |

---

## Architecture Patterns

### Pattern 1: Observer Deduplication (BUGF-02 solution — PR 112)
**What:** Track which item IDs already have observers using `reactiveValues`. Before creating an `observeEvent`, check if the ID key is already set. Clean up after firing.
**When to use:** Any `observe({lapply(ids, function(id) { observeEvent(...) })})` pattern that re-runs when its dependency list changes.
**Example (from PR 112):**
```r
delete_observers <- reactiveValues()

observe({
  papers <- filtered_papers()
  lapply(papers$id, function(paper_id) {
    id_str <- as.character(paper_id)
    if (is.null(delete_observers[[id_str]])) {
      delete_observers[[id_str]] <- observeEvent(input[[paste0("delete_paper_", paper_id)]], {
        # ... action ...
        delete_observers[[id_str]] <- NULL  # cleanup
      }, ignoreInit = TRUE)
    }
  })
})
```
**Note:** PR 112 already applies this to `mod_search_notebook.R` (paper delete, block journal, unblock journal) and `app.R` (network deletion). Verify its solution covers ALL observer leak sites before landing.

### Pattern 2: on.exit Resource Cleanup (DEBT-01)
**What:** Use `on.exit()` immediately after opening a connection so it closes on any exit path (normal return, error, early return).
**When to use:** Any function that opens a DuckDB/ragnar connection as a local variable for a single operation.
**Example:**
```r
# In search_chunks_hybrid, after opening the store:
own_store <- is.null(ragnar_store)
store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)
if (!is.null(store) && own_store) {
  on.exit(
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
    add = TRUE
  )
}
```
**Key constraint:** Only close stores that `search_chunks_hybrid` opened itself — if caller passes a `ragnar_store` argument, caller owns the lifecycle.

### Pattern 3: encode_origin_metadata in PDF Chunking (DEBT-02)
**What:** The `chunk_with_ragnar()` function in `_ragnar.R` produces plain `"filename#page=N"` origin strings. The `process_pdf()` function in `pdf.R` already computes `section_hint` per chunk. The gap: `insert_chunks_to_ragnar()` receives the raw chunk data frame and uses `origin` as-is, without encoding section_hint.
**Fix approach:** In `insert_chunks_to_ragnar()`, when the chunk data frame has a `section_hint` column, re-encode the origin using `encode_origin_metadata()`:
```r
# Before building ragnar_chunks in insert_chunks_to_ragnar():
if ("section_hint" %in% names(chunks)) {
  chunks$origin <- vapply(seq_len(nrow(chunks)), function(i) {
    encode_origin_metadata(
      chunks$origin[i],
      section_hint = chunks$section_hint[i],
      doi = NULL,
      source_type = "pdf"
    )
  }, character(1))
}
```
**Scope:** This only affects new PDFs indexed after the fix. Existing ragnar stores keep their unencoded origins until re-indexed.

### Pattern 4: Seed Paper Insertion (BUGF-01) — CRITICAL FINDING
**Root cause (confirmed):** When a seed-discovery notebook is created in `app.R` (lines 948-1026), only the citing/cited papers are inserted into `abstracts`. The seed paper itself is never inserted. The `notebooks` table has NO seed DOI column — the seed's OpenAlex paper ID is stored as JSON in `search_filters` under the key `seed_paper_id`.

**Why the seed paper doesn't appear:** `list_abstracts(con, nb_id)` queries `abstracts WHERE notebook_id = ?`. Since the seed paper was never inserted into `abstracts`, it cannot appear in the list at all.

**Fix approach:** At notebook creation time in `app.R`, after populating citing/cited papers, also insert the seed paper itself into `abstracts` if it has an abstract. Then in `papers_data()`, read the `seed_paper_id` from `search_filters` and move that paper to row 1.

**Two-part fix:**
```r
# Part 1 — In app.R, observeEvent(discovery_request(), ...) after papers loop:
# Insert the seed paper itself
seed <- req$seed_paper
existing_seed <- dbGetQuery(con, "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
                            list(nb_id, seed$paper_id))
if (nrow(existing_seed) == 0) {
  create_abstract(con, nb_id, seed$paper_id, seed$title, seed$authors,
                  seed$abstract, seed$year, seed$venue, seed$pdf_url,
                  cited_by_count = seed$cited_by_count,
                  referenced_works_count = seed$referenced_works_count,
                  fwci = seed$fwci, doi = seed$doi)
}
```
```r
# Part 2 — In mod_search_notebook.R, papers_data reactive: pin seed to position 1
papers_data <- reactive({
  paper_refresh()
  nb_id <- notebook_id()
  req(nb_id)
  sort_by <- input$sort_by %||% "year"
  papers <- list_abstracts(con(), nb_id, sort_by = sort_by)

  # Pin seed paper to top if this is a seed-discovery notebook
  nb <- get_notebook(con(), nb_id)
  filters <- tryCatch(
    if (!is.na(nb$search_filters)) jsonlite::fromJSON(nb$search_filters) else list(),
    error = function(e) list()
  )
  seed_paper_id <- filters$seed_paper_id
  if (!is.null(seed_paper_id) && !is.na(seed_paper_id) && nrow(papers) > 0) {
    seed_idx <- which(papers$paper_id == seed_paper_id)
    if (length(seed_idx) > 0 && seed_idx[1] != 1L) {
      papers <- rbind(papers[seed_idx[1], ], papers[-seed_idx[1], ])
    }
  }
  papers
})
```

**Note:** `seed$paper_id` in `discovery_request` is the OpenAlex work ID (e.g., `W1234567890`). The `abstracts.paper_id` column stores the same format. Match on `paper_id`, not DOI.

### Pattern 5: OpenRouter Pricing Coverage (BUGF-03)
**What:** `estimate_cost()` in `cost_tracking.R` falls back to `DEFAULT_PRICING` for any model not in `pricing_env$MODEL_PRICING`. This is inaccurate for non-standard models.
**Fix:** At app startup (after API key is available), call `list_chat_models()` and use the returned pricing data to populate `pricing_env$MODEL_PRICING`. The `update_model_pricing()` function already exists for this purpose.
**Where to call:** In `app.R` server, after effective_config is initialized:
```r
observe({
  cfg <- effective_config()
  api_key <- get_setting(cfg, "openrouter", "api_key")
  req(api_key, nchar(api_key) > 0)

  tryCatch({
    models <- list_chat_models(api_key)
    # list_chat_models returns: id, name, tier, context, prompt_price, completion_price
    if (nrow(models) > 0 && "prompt_price" %in% names(models)) {
      update_model_pricing(models[, c("id", "prompt_price", "completion_price")])
    }
  }, error = function(e) message("[pricing] Failed to fetch live pricing: ", e$message))
}) |> bindEvent(effective_config(), once = TRUE)
```
**Note:** Embedding model pricing should also be fetched. `list_embedding_models()` returns `id`, `name`, `price_per_million`. May need to adapt format for `update_model_pricing()` which expects `prompt_price`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connection cleanup | Custom wrapper function | `on.exit()` with `DBI::dbDisconnect(store@con, shutdown=TRUE)` | R's `on.exit()` guarantees cleanup on any exit path including errors |
| Tooltip boundary detection | CSS `overflow: hidden` | Inline JS in visNetwork + CSS | CSS overflow alone cannot detect tooltip position relative to container boundary |
| Model pricing data | Manual JSON maintenance | `/models` API endpoint via existing `list_chat_models()` | API already returns `pricing$prompt` and `pricing$completion` per model |
| Seed paper display | Complex reactive graph | Insert seed paper into abstracts at creation time | Simplest source of truth; no special rendering logic needed |

---

## Common Pitfalls

### Pitfall 1: Closing Caller-Provided Ragnar Stores
**What goes wrong:** `search_chunks_hybrid` accepts an optional `ragnar_store` parameter. If a caller passes a live store, and the function's `on.exit` cleanup closes it, the caller's store is invalidated.
**Why it happens:** `on.exit()` fires regardless of how the connection was acquired.
**How to avoid:** Check `own_store <- is.null(ragnar_store)` before opening and only register `on.exit` when `own_store` is TRUE. Never close a store that was passed in by the caller.
**Warning signs:** Tests or callers that pass a pre-opened store start failing with "connection already closed" errors.

### Pitfall 2: PR 112 Observer Coverage
**What goes wrong:** PR 112 fixes observer deduplication in some locations but may miss others. If BUGF-02 is declared "fixed" by landing PR 112 but other duplicate-observer sites remain, users still see duplicate notifications in those flows.
**Why it happens:** The Copilot PR was generated against the issue description, which may not enumerate all affected code paths.
**How to avoid:** Before merging, audit the full `mod_search_notebook.R` for all `observe({lapply(...)})` patterns. Compare PR 112's changed lines against every `observeEvent` inside a `lapply` in that file.
**Warning signs:** Duplicate notifications still appear for unblock journal or paper view actions after landing.

### Pitfall 3: encode_origin_metadata in insert_chunks_to_ragnar Side Effects
**What goes wrong:** Changing `insert_chunks_to_ragnar` to encode section_hint may affect callers that pass chunks WITHOUT a `section_hint` column.
**Why it happens:** The function is shared between PDF indexing (has section_hint) and abstract indexing (no section_hint — already encoded at call site).
**How to avoid:** The fix must be conditional on `"section_hint" %in% names(chunks)` — only encode when column is present. Abstract indexing paths in `mod_search_notebook.R` already call `encode_origin_metadata` at the call site (line 2010), so they're not affected.

### Pitfall 4: Dark Mode vs Network Background (UIPX-04)
**What goes wrong:** The current background `#1a1a2e` (dark navy) is jarring in dark mode (double-dark). Choosing a white background washes out lighter viridis yellows.
**Why it happens:** CSS sets `background-color: #1a1a2e` statically in `custom.css`.
**How to avoid:** Use a medium-light neutral grey (e.g., `#e8e8ee`) for light mode and a dark complement for dark mode, controlled by `[data-bs-theme="dark"]` CSS selector. Viridis family palettes are designed for both dark and light backgrounds; mid-tone backgrounds are safest.
**Colorblind constraint:** All viridis-family palettes (viridis, magma, plasma, inferno, cividis) are colorblind-safe by design. Mid-tone grey provides adequate contrast with ALL of them.

### Pitfall 5: DuckDB single-writer constraint on Windows
**What goes wrong:** On Windows, DuckDB has strict single-writer behavior. If a ragnar store connection is left open (the current leak), subsequent open attempts fail with "database is locked" errors.
**Why it happens:** Each call to `search_chunks_hybrid` via `rag_query` opens a new connection without closing the previous one.
**How to avoid:** The `on.exit` fix directly resolves this. No special Windows testing required per user decision, but the fix is especially important on Windows.

### Pitfall 6: Seed Paper Absent in discovery_request
**What goes wrong:** `discovery_request$seed_paper` is the paper object returned by `get_paper(doi, ...)`. It includes `paper_id`, `title`, `authors`, `abstract`, etc. The `paper_id` is the OpenAlex work ID, NOT the DOI.
**How to avoid:** Match seed detection in `papers_data()` using `paper_id` field (which is stored in `abstracts.paper_id`), not DOI. If the seed paper has no abstract, it still should be inserted — just without abstract content.

---

## Code Examples

### Seed Paper Pinning — Full Implementation (BUGF-01)
```r
# In app.R, observeEvent(discovery_request(), ...) — after the papers loop
# (around line 1012), before navigate/notify:

# Insert seed paper into abstracts if not already present
seed <- req$seed_paper
existing_seed <- dbGetQuery(con,
  "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
  list(nb_id, seed$paper_id))
if (nrow(existing_seed) == 0) {
  create_abstract(
    con, nb_id, seed$paper_id, seed$title,
    seed$authors, seed$abstract,
    seed$year, seed$venue, seed$pdf_url,
    keywords = seed$keywords,
    work_type = seed$work_type,
    cited_by_count = seed$cited_by_count,
    referenced_works_count = seed$referenced_works_count,
    fwci = seed$fwci,
    doi = seed$doi
  )
}
```
```r
# In mod_search_notebook.R, papers_data reactive — pin seed to row 1:
papers_data <- reactive({
  paper_refresh()
  nb_id <- notebook_id()
  req(nb_id)
  sort_by <- input$sort_by %||% "year"
  papers <- list_abstracts(con(), nb_id, sort_by = sort_by)

  nb <- tryCatch(get_notebook(con(), nb_id), error = function(e) NULL)
  if (!is.null(nb) && !is.na(nb$search_filters) && nchar(nb$search_filters) > 0) {
    filters <- tryCatch(jsonlite::fromJSON(nb$search_filters), error = function(e) list())
    seed_paper_id <- filters$seed_paper_id
    if (!is.null(seed_paper_id) && nrow(papers) > 0) {
      seed_idx <- which(as.character(papers$paper_id) == as.character(seed_paper_id))
      if (length(seed_idx) > 0 && seed_idx[1] != 1L) {
        papers <- rbind(papers[seed_idx[1], ], papers[-seed_idx[1], ])
      }
    }
  }
  papers
})
```

### Connection Leak Fix (DEBT-01)
```r
# In R/db.R, search_chunks_hybrid() — after line ~710
# Change from:
store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)

# To:
own_store <- is.null(ragnar_store)
store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)
if (!is.null(store) && own_store) {
  on.exit(
    tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL),
    add = TRUE
  )
}
```

### Dead Code Removal (DEBT-03)
```r
# In R/_ragnar.R — delete these two complete functions (including their roxygen docstrings):
# 1. with_ragnar_store()        (lines ~282-336)
# 2. register_ragnar_cleanup()  (lines ~349-361)
# Verified: zero callers exist anywhere in the codebase
```

### BUGF-04: Paper Count Notification Fix
```r
# In mod_search_notebook.R, do_search_refresh() — end of the function
# Current (WRONG - uses pre-exclusion count):
showNotification(paste("Loaded", length(papers), "papers"), type = "message")

# The `papers` variable at line 1938 is already the post-exclusion list
# because the exclusion filtering happens in-place earlier (around line 1890).
# Verify by checking what `papers` contains at the notification line.
# If correct, the notification IS counting post-exclusion — and the bug
# is that it says "Loaded N papers" when N are newly ADDED (not total visible).
# Consider changing to: "Search complete: N papers in notebook"
# and separately count how many were newly added vs already existed.
```

### UIPX-04: Network Background (CSS change)
```css
/* In www/custom.css — replace the static dark background: */

/* Before: */
.citation-network-container {
  background-color: #1a1a2e;
}

/* After — light neutral that works with all viridis palettes: */
.citation-network-container {
  background-color: #e8e8ee;
}

/* Dark mode variant: */
[data-bs-theme="dark"] .citation-network-container {
  background-color: #1e1e2e;
}
```

---

## PR Status

### PR 112 — Fix duplicate toast notifications (BUGF-02)
- **Status:** DRAFT — ready to review and merge
- **Changes:** `mod_search_notebook.R` (+64/-37), `app.R` (+23/-12)
- **Pattern:** `reactiveValues` observer tracking for paper delete, block journal, unblock journal, network deletion
- **Verdict:** Solution is architecturally correct. Verify coverage before landing.

### PR 115 — Collapsible keywords panel (UIPX-02)
- **Status:** DRAFT — ready to merge
- **Changes:** `mod_search_notebook.R` (+10/-1)
- **Pattern:** Bootstrap collapse with `data-bs-toggle="collapse"`, matching existing journal quality filter pattern
- **Note:** PR modifies `card_header("Keywords")` at UI line 141 to add collapse toggle. No conflict with PR 112 (server-only changes).
- **Verdict:** Clean, minimal change. Merge as-is.

---

## Technical Domain Analysis

### DEBT-01: Ragnar Connection Leak — Exact Location
- **File:** `R/db.R`, function `search_chunks_hybrid`, line ~710
- **Leaked code:** `store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)` — `connect_ragnar_store` opens a DuckDB connection via `ragnar::ragnar_store_connect(path)`. No `on.exit`, no disconnect anywhere on the return paths.
- **All callers that leak:** `rag_query()` in `rag.R` (1 call), `generate_conclusions_preset()` in `rag.R` (3 calls). None pass a pre-opened `ragnar_store`.
- **Other ragnar callers audit results:**
  - `ensure_ragnar_store()` in `_ragnar.R` — opens store and RETURNS it; caller owns lifecycle. In `mod_search_notebook.R` line 1993, returned store is used in a block but never explicitly closed — secondary leak, log as new issue per decision.
  - `check_store_integrity()` in `_ragnar.R` — opens and disconnects immediately. CORRECT.
  - `rebuild_notebook_store()` in `_ragnar.R` — disconnects explicitly on success and interrupt. CORRECT.
  - `delete_abstract_chunks_from_ragnar()` in `_ragnar.R` — uses `on.exit`. CORRECT.

### DEBT-02: section_hint Pipeline Gap — Exact Location
- **Current flow:** `process_pdf()` → `chunk_with_ragnar()` (plain `"filename#page=N"` origins) → `detect_section_hint()` adds `section_hint` column → returns `list(chunks, ...)`.
- **Then:** `mod_document_notebook.R` line 533 calls `insert_chunks_to_ragnar(store, result$chunks, doc_id, "document")`.
- **Gap:** In `insert_chunks_to_ragnar` (`_ragnar.R` line ~829), `ragnar_chunks$origin <- chunks$origin` copies the raw `"filename#page=N"` string. The `section_hint` column is ignored entirely.
- **Fix location:** `insert_chunks_to_ragnar()` in `_ragnar.R`, with `"section_hint" %in% names(chunks)` guard.

### DEBT-03: Dead Code — Exact Locations
- `with_ragnar_store()`: `R/_ragnar.R` function + roxygen docstring, lines ~282-336. Zero callers (grep confirmed).
- `register_ragnar_cleanup()`: `R/_ragnar.R` function + roxygen docstring, lines ~349-361. Zero callers (grep confirmed).

### BUGF-01: Seed Paper — Root Cause (Confirmed)
- **notebooks table schema:** `id, name, type, search_query, search_filters, created_at, updated_at` — NO seed_paper_doi column.
- **seed_paper_id storage:** Stored in `search_filters` JSON as `seed_paper_id` key (OpenAlex work ID format, e.g., `W1234567890`). Set in `app.R` line 959: `filters <- list(citation_filter = ..., citation_type = ..., seed_paper_id = req$seed_paper$paper_id)`.
- **Why seed paper is missing:** `observeEvent(discovery_request(), ...)` only inserts the citing/cited papers into `abstracts`, never the seed paper itself. `list_abstracts()` can only show papers in the `abstracts` table.
- **Fix:** Two-part — insert seed paper at creation time AND pin it to row 1 in `papers_data()`.

### BUGF-03: Pricing Coverage — Exact Gap
- `pricing_env$MODEL_PRICING` has 7 hardcoded models only.
- Any non-listed model falls back to `DEFAULT_PRICING = list(prompt=1.00, completion=3.00)`.
- `update_model_pricing()` already exists; `list_chat_models()` returns `prompt_price`/`completion_price` columns.
- Fix: call `update_model_pricing()` at startup using `list_chat_models()` output.

### BUGF-04: Paper Count — Exact Issue
- `do_search_refresh()` in `mod_search_notebook.R` line 1938: `showNotification(paste("Loaded", length(papers), "papers"), ...)`.
- At this point `papers` is the post-exclusion list (exclusion filtering happened earlier). But the count shown includes papers already in the notebook (deduplication happens by checking `existing` rows and skipping, but `length(papers)` still counts all fetched papers including skipped duplicates).
- **Real issue:** The notification says "Loaded N papers" where N is the raw API response count, not the count of newly-inserted papers. The net new papers added could be 0 if all were already present.
- **Fix:** Track a separate `newly_added` counter in the loop and show that in the notification.

---

## Open Questions

1. **ensure_ragnar_store() secondary leak in embed flow**
   - What we know: `ensure_ragnar_store()` returns an open store; `mod_search_notebook.R` line 1993 uses it in a block without explicit disconnect.
   - What's unclear: Whether garbage collection closes the DuckDB connection when the store object goes out of scope.
   - Recommendation: During DEBT-01 audit, determine if this is a real leak; log as new issue if so (per user decision: don't fix additional leaks in this phase).

2. **UIPX-03 tooltip flip — CSS vs JS**
   - What we know: visNetwork renders `.vis-tooltip` as a positioned div inside the container. Current CSS uses `max-width` and `pointer-events: none` but no repositioning.
   - What's unclear: Whether CSS alone can handle edge detection, or whether a JS snippet is needed.
   - Recommendation: A small JS mutation observer on the tooltip or a visNetwork `afterDrawing` event handler is the most reliable approach. CSS container clipping is simpler but doesn't flip direction.

3. **list_chat_models() column names for pricing update**
   - What we know: `list_chat_models()` in `api_openrouter.R` returns a data frame; code shows it extracts `prompt_price` and `completion_price`.
   - What's unclear: Whether these are the exact column names used vs intermediate names.
   - Recommendation: Read `list_chat_models()` in full before writing the startup pricing call to confirm exact column names.

---

## Sources

### Primary (HIGH confidence)
- Direct code review: `R/db.R` `search_chunks_hybrid` (lines 698-848) — confirmed connection leak
- Direct code review: `R/_ragnar.R` `with_ragnar_store`, `register_ragnar_cleanup` — zero callers confirmed
- Direct code review: `R/_ragnar.R` `insert_chunks_to_ragnar` (lines 823-848) — DEBT-02 gap confirmed
- Direct code review: `R/cost_tracking.R` `pricing_env$MODEL_PRICING` — 7-model static list confirmed
- Direct code review: `R/pdf.R` `process_pdf` — section_hint computed but not forwarded confirmed
- Direct code review: `R/mod_search_notebook.R` `do_search_refresh` (line 1938) — notification count issue confirmed
- Direct code review: `R/mod_citation_network.R` + `www/custom.css` — tooltip CSS and `#1a1a2e` background confirmed
- Direct code review: `app.R` `observeEvent(discovery_request(), ...)` (lines 948-1026) — seed paper NOT inserted confirmed
- Direct code review: `R/db.R` `init_schema` — notebooks table has no seed_paper_doi column confirmed
- Direct code review: `app.R` line 959 — `seed_paper_id` stored in `search_filters` JSON confirmed
- GitHub PR 112 review — observer tracking solution confirmed correct
- GitHub PR 115 review — collapsible keywords solution confirmed correct
- GitHub issues #86, #110, #116, #117, #118, #119 — issue descriptions reviewed

### Secondary (MEDIUM confidence)
- Code review of `R/api_openrouter.R` `list_chat_models()` — column names inferred from code, not runtime-tested

---

## Metadata

**Confidence breakdown:**
- PR landing: HIGH — both PRs reviewed and solutions confirmed
- DEBT-01 (connection leak): HIGH — exact location identified, fix pattern is standard R `on.exit`
- DEBT-02 (section_hint pipeline): HIGH — gap confirmed, fix approach clear
- DEBT-03 (dead code removal): HIGH — zero callers confirmed
- BUGF-01 (seed paper pinning): HIGH — root cause confirmed (paper not inserted), two-part fix identified
- BUGF-02 (duplicate modals): HIGH — PR 112 solution correct, coverage verification needed
- BUGF-03 (pricing coverage): HIGH — root cause confirmed, fix path clear
- BUGF-04 (paper count): HIGH — issue is notification count showing API response count not newly-added count
- UIPX-03 (tooltip): MEDIUM — approach identified, CSS vs JS tradeoff needs experimentation
- UIPX-04 (network background): HIGH — current value identified, neutral grey recommendation is colorblind-safe

**Research date:** 2026-02-18
**Valid until:** 2026-03-18 (30 days — stable codebase)
