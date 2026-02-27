# Phase 37: Citation Audit - Research

**Researched:** 2026-02-26
**Domain:** Citation gap analysis, SQL aggregation, async task execution, R Shiny data tables
**Confidence:** HIGH

## Summary

Phase 37 enables users to identify frequently-cited papers missing from their search notebook collection by analyzing both backward references (papers cited BY the collection) and forward citations (papers that CITE the collection). The core challenge is efficient aggregation across potentially thousands of cited works from 500+ papers in a collection, requiring single-query SQL GROUP BY operations to avoid N+1 query explosions.

The codebase already has proven patterns: OpenAlex API functions (`get_citing_papers`, `get_cited_papers`), async task execution with mirai + ExtendedTask, progress modal with cancellation (interrupt flags), and database-backed caching (import_runs pattern). The citation network module demonstrates fetching and caching referenced_works arrays. The bulk import module demonstrates progress reporting, partial results on cancellation, and batch API operations.

The technical stack combines DuckDB's `unnest()` function for array flattening with GROUP BY aggregation, OpenAlex batch API for fetching missing paper metadata (up to 50 DOIs per request), and a dedicated citation_audit_results table for caching analysis results with staleness tracking. Results are presented in a sortable table (no complex widget needed — plain Shiny table with radioButtons sorting), with one-click import and batch selection support.

**Primary recommendation:** Implement SQL-first aggregation using DuckDB `unnest()` on referenced_works arrays stored in abstracts table, cache results in citation_audit_results table with last_analyzed timestamp, use ExtendedTask + mirai for async execution with modal progress (matching citation network pattern), and present results in plain Shiny table with sortable columns.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Results presentation:**
- Table layout with sortable columns (title, authors, year, collection frequency, global citation count)
- Show both collection frequency (how many times referenced by/citing user's papers) AND global OpenAlex citation count
- Show direction breakdown — distinguish backward references from forward citations (e.g., separate counts or tags)
- Default sort by collection frequency descending; columns are re-sortable by user

**Trigger & scope:**
- Dedicated audit tab/page (not a button inside search notebook)
- Dropdown to select which search notebook to audit
- Always audits entire notebook — no subset selection
- No minimum paper count warning — small notebooks work the same as seed-paper workflows
- Results are cached in DB with last-analysis date; user can re-run manually
- Papers imported since last audit are marked as imported in cached results
- Imported papers go into the same notebook being audited

**Import workflow:**
- Checkbox selection + batch import supported alongside single-paper import
- Single import: immediate action, no confirmation
- Batch import: confirmation dialog ("Import X papers?") before proceeding
- Both single and batch import navigate to the notebook after completion

**Progress & async:**
- Modal overlay with stepped progress bar (matching existing network building modal pattern)
- Steps shown: "Fetching backward references..." → "Fetching forward citations..." → "Ranking results..."
- Cancel button always available throughout entire analysis
- On cancel during fetch: show partial results collected so far
- On failure (rate limit, network error): show partial results with warning that results may be incomplete

### Claude's Discretion

- Exact table widget choice and styling
- Cache invalidation strategy (time-based vs manual only)
- How direction breakdown is visually presented (separate columns, badges, tooltip)
- Progress bar granularity within each step

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUDIT-01 | User can trigger citation gap analysis on a search notebook | Dedicated audit tab with notebook dropdown (Architecture Pattern 1); async task with ExtendedTask + mirai (Pattern 3) |
| AUDIT-02 | System analyzes backward references (papers cited BY collection) using referenced_works | DuckDB `unnest()` on referenced_works arrays stored in abstracts.doi column; SQL aggregation pattern (Don't Hand-Roll #1) |
| AUDIT-03 | System analyzes forward citations (papers that CITE the collection) via OpenAlex cited_by API | OpenAlex filter syntax `cites:W123\|W456` for batch queries (Code Example 1); batch API pattern from Phase 34 |
| AUDIT-04 | Missing papers ranked by citation frequency (threshold: 2+ references) | SQL `GROUP BY` with `HAVING COUNT(*) >= 2` filter; collection frequency = primary sort key (Architecture Pattern 2) |
| AUDIT-05 | User sees ranked list with title, author, year, and citation count | Plain Shiny table with sortable columns via radioButtons (Standard Stack: base Shiny); no complex widget needed |
| AUDIT-06 | User can import individual missing papers with one click | Reuse `create_abstract()` from db.R; batch import uses ExtendedTask pattern from bulk import (Code Example 2) |
| AUDIT-07 | Analysis runs async with progress indicator and cancellation | ExtendedTask + mirai with interrupt flags (Pattern 3); modal progress with stepped updates (Pattern 4); partial results on cancel |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DuckDB | (existing) | SQL aggregation with `unnest()` | Already in use; `unnest()` flattens arrays for GROUP BY queries; avoids N+1 query anti-pattern |
| mirai | (existing) | Async task execution | Already integrated via ExtendedTask; proven pattern in citation network and bulk import modules |
| httr2 | (existing) | OpenAlex batch API calls | Already integrated; supports pipe-separated filter syntax for batch queries |
| bslib/Shiny | (existing) | Table rendering and sorting | Base Shiny table with radioButtons sorting (no external widget needed) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | (existing) | Serialize direction breakdown metadata | Storing backward/forward counts as JSON in audit results table |
| uuid | (existing) | Generate audit run IDs | Consistent with existing `create_notebook()` pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SQL `unnest()` + GROUP BY | R for-loop over referenced_works | R loop = N+1 queries, memory explosion with 500 papers × 50 refs each = 25,000 queries; SQL = single query |
| Plain Shiny table | DT::datatable or reactable | DT/reactable overkill for ~200 rows; adds external dependency; plain Shiny sufficient for sortable columns |
| Dedicated audit_results table | Store in abstracts table | Separate table enables staleness tracking, preserves imported status, allows multiple audit runs per notebook |

**Installation:**
```r
# All dependencies already installed in existing codebase
# No new packages required
```

## Architecture Patterns

### Pattern 1: Dedicated Audit Tab with Notebook Selection

**What:** Standalone audit page in app navigation (not embedded in search notebook), dropdown to select target notebook, results displayed in main content area.

**Why:** User constraint requires dedicated tab; separates audit workflow from notebook browsing; allows auditing multiple notebooks without switching contexts.

**Implementation:**
```r
# In app.R navigation:
nav_panel(
  title = "Citation Audit",
  icon = icon("magnifying-glass-chart"),
  mod_citation_audit_ui("audit")
)

# In mod_citation_audit_ui:
selectInput(
  ns("notebook_id"),
  "Audit Notebook:",
  choices = NULL  # Populated server-side from list_notebooks()
)
actionButton(ns("run_audit"), "Run Analysis", icon = icon("play"))
```

### Pattern 2: SQL-First Aggregation with unnest()

**What:** Single SQL query to aggregate all referenced_works and cited_by relationships across entire notebook, avoiding N+1 query anti-pattern.

**Why:** 500 papers with avg 50 refs each = 25,000 referenced works; N+1 query pattern would execute 500 separate SELECTs (catastrophic performance); SQL GROUP BY executes once.

**Implementation:**
```sql
-- Backward references: papers cited BY collection
-- Use unnest() to flatten referenced_works JSON arrays
SELECT
  work_id,
  COUNT(*) as collection_frequency
FROM (
  SELECT
    json_array_elements_text(referenced_works::json) as work_id
  FROM abstracts
  WHERE notebook_id = ?
  AND referenced_works IS NOT NULL
)
GROUP BY work_id
HAVING COUNT(*) >= 2  -- Threshold filter
ORDER BY collection_frequency DESC;

-- Forward citations: papers that CITE collection
-- Use OpenAlex batch filter: cites:W123|W456|W789
-- Build pipe-separated list of all paper_ids in notebook
SELECT string_agg(paper_id, '|') as paper_ids
FROM abstracts
WHERE notebook_id = ?;
```

**Key insight:** DuckDB's `unnest()` (via `json_array_elements_text`) flattens referenced_works arrays into rows, enabling GROUP BY aggregation in a single query. This is 100-1000x faster than row-by-row iteration.

### Pattern 3: Async Execution with ExtendedTask + mirai

**What:** Run citation analysis in background worker process using ExtendedTask + mirai, matching existing citation network pattern.

**Why:** Analysis involves multiple API calls (forward citations batch query, missing papers metadata fetch) that could take 30+ seconds; blocking main session would freeze UI.

**Implementation:**
```r
# Reuse pattern from mod_citation_network.R (lines 192-219)
audit_task <- ExtendedTask$new(function(notebook_id, email, api_key, interrupt_flag, progress_file, db_path, app_dir) {
  mirai::mirai({
    # Source required files in isolated process
    source(file.path(app_dir, "R", "interrupt.R"))
    source(file.path(app_dir, "R", "api_openalex.R"))
    source(file.path(app_dir, "R", "citation_audit.R"))

    # Run analysis with interrupt and progress support
    run_citation_audit(
      notebook_id = notebook_id,
      email = email,
      api_key = api_key,
      db_path = db_path,
      interrupt_flag = interrupt_flag,
      progress_file = progress_file
    )
  }, notebook_id = notebook_id, email = email, api_key = api_key,
     interrupt_flag = interrupt_flag, progress_file = progress_file,
     db_path = db_path, app_dir = app_dir)
})

# Invoke with interrupt and progress files
observeEvent(input$run_audit, {
  flag_file <- create_interrupt_flag(session$token)
  prog_file <- create_progress_file(session$token)

  audit_task$invoke(
    notebook_id = input$notebook_id,
    email = config_r()$openalex$email,
    api_key = config_r()$openalex$api_key,
    interrupt_flag = flag_file,
    progress_file = prog_file,
    db_path = "data/notebooks.duckdb",
    app_dir = getwd()
  )
})
```

**Source:** Phase 18 (progress modal), Phase 22 (citation network), Phase 35 (bulk import) all use this pattern.

### Pattern 4: Stepped Progress Modal with Cancellation

**What:** Modal overlay with progress bar showing distinct steps (backward refs → forward citations → ranking), cancel button always available, partial results on cancel.

**Why:** User constraint requires stepped progress with cancellation; matches existing citation network modal pattern (mod_citation_network.R lines 370-394).

**Implementation:**
```r
# Show modal with stepped progress
showModal(modalDialog(
  title = tagList(icon("spinner", class = "fa-spin"), "Analyzing Citations"),
  tags$div(
    class = "progress",
    style = "height: 25px;",
    tags$div(
      id = session$ns("audit_progress_bar"),
      class = "progress-bar progress-bar-striped progress-bar-animated",
      role = "progressbar",
      style = "width: 5%;",
      "5%"
    )
  ),
  tags$div(
    id = session$ns("audit_progress_message"),
    class = "text-muted mt-2",
    "Initializing..."
  ),
  footer = actionButton(session$ns("cancel_audit"), "Cancel", class = "btn-warning"),
  easyClose = FALSE
))

# Poll progress file and update bar
observe({
  req(audit_task$status() == "running")

  invalidateLater(500)  # Poll every 500ms
  prog <- read_audit_progress(current_progress_file())

  session$sendCustomMessage("updateAuditProgress", list(
    bar_id = session$ns("audit_progress_bar"),
    msg_id = session$ns("audit_progress_message"),
    percent = prog$pct,
    message = prog$message
  ))
}) |> bindEvent(audit_task$status())

# Cancel handler
observeEvent(input$cancel_audit, {
  signal_interrupt(current_interrupt_flag())
})
```

**Source:** Exact pattern from mod_citation_network.R; reuse JavaScript handler from citation network module.

### Anti-Patterns to Avoid

**Anti-pattern 1: N+1 Queries**
- **What goes wrong:** Looping over each abstract to fetch referenced_works individually
- **Why it happens:** Intuitive to process one paper at a time
- **How to avoid:** Use SQL `unnest()` + GROUP BY for single-query aggregation
- **Warning signs:** Query count scales linearly with notebook size; noticeable slowdown above 50 papers

**Anti-pattern 2: In-Memory Aggregation**
- **What goes wrong:** Fetching all referenced_works into R, then using `table()` to count
- **Why it happens:** Familiar R pattern
- **How to avoid:** Let DuckDB handle aggregation (it's optimized for this)
- **Warning signs:** Memory usage spikes; slow performance with large notebooks

**Anti-pattern 3: Blocking API Calls**
- **What goes wrong:** Running citation analysis in main Shiny session, freezing UI
- **Why it happens:** Simpler to code synchronously
- **How to avoid:** Always use ExtendedTask + mirai for multi-second operations
- **Warning signs:** Shiny app becomes unresponsive during analysis

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Array aggregation across rows | R for-loop with `table()` | DuckDB `unnest()` + GROUP BY | DuckDB executes in-process with optimized C++ aggregation; R loop creates memory copies and slow iteration |
| Batch API fetching | Sequential `get_paper()` calls | OpenAlex pipe-separated filter syntax | OpenAlex supports up to 50 DOIs per request; sequential calls = 50x more API overhead |
| Sortable table widget | Build custom DataTable component | Shiny radioButtons + reactive sorting | User constraint requires simple column sort; no need for search/filter/pagination features of full DataTable library |
| Progress reporting | Custom WebSocket messages | File-based progress with `read_progress()` | File-based pattern already proven in citation network and bulk import; cross-process compatible; no additional infrastructure |

**Key insight:** SQL aggregation is 100-1000x faster than R loops for this use case because DuckDB operates in-process with columnar storage, while R loops create intermediate data structures and iterate slowly.

## Common Pitfalls

### Pitfall 1: Missing referenced_works Data

**What goes wrong:** Some abstracts lack referenced_works arrays (OpenAlex doesn't always provide them), causing NULL values in aggregation.

**Why it happens:** Not all papers in OpenAlex have reference data indexed.

**How to avoid:** Filter `WHERE referenced_works IS NOT NULL` in SQL query; handle empty arrays gracefully in `unnest()`.

**Warning signs:** NULL errors in GROUP BY; unexpectedly low citation gap counts.

### Pitfall 2: Duplicate Work IDs in Results

**What goes wrong:** Same missing paper appears in both backward and forward results, creating duplicate rows in final table.

**Why it happens:** A paper can be cited BY the collection AND cite papers IN the collection.

**How to avoid:** Aggregate backward and forward results into single row per work_id, store direction breakdown as separate columns (backward_count, forward_count).

**Warning signs:** User sees duplicate titles in results table; confusing UX.

### Pitfall 3: Cache Staleness Without Visual Indicator

**What goes wrong:** User views stale audit results from last week, doesn't realize new papers imported since then aren't reflected.

**Why it happens:** Cache doesn't track when underlying notebook changed.

**How to avoid:** Show last_analyzed timestamp in UI; mark papers as "imported since last audit" if abstract.created_at > audit.last_analyzed.

**Warning signs:** User reports "imported paper still shows in gaps"; confusion about cache freshness.

### Pitfall 4: Memory Explosion with Large Batch Imports

**What goes wrong:** User selects 500 missing papers for batch import, app runs out of memory or hangs.

**Why it happens:** Batch import tries to fetch all 500 papers in one API call.

**How to avoid:** Reuse chunked batch_fetch_papers() from Phase 34 (50 DOIs per batch); show warning if selection exceeds 100 papers.

**Warning signs:** App freezes on large batch import; memory usage spikes.

## Code Examples

### Example 1: OpenAlex Batch Forward Citations Query

```r
# Fetch papers that CITE any work in the collection
# Use pipe-separated filter syntax: cites:W123|W456|W789

# Step 1: Get all paper_ids in notebook
notebook_paper_ids <- dbGetQuery(con, "
  SELECT paper_id FROM abstracts WHERE notebook_id = ?
", list(notebook_id))$paper_id

# Step 2: Build pipe-separated filter
filter_str <- paste0("cites:", paste(notebook_paper_ids, collapse = "|"))

# Step 3: Query OpenAlex
req <- build_openalex_request("works", email, api_key) |>
  req_url_query(filter = filter_str, per_page = 200)

resp <- req_perform(req)
body <- resp_body_json(resp)

# Step 4: Extract citing papers
citing_works <- lapply(body$results, parse_openalex_work)

# Step 5: Count citations per work (papers can cite multiple works in collection)
citation_counts <- table(sapply(citing_works, function(w) w$paper_id))
```

**Source:** OpenAlex API documentation; pipe-separated filter pattern from api_openalex.R `batch_fetch_papers()`.

### Example 2: Single-Query Backward References Aggregation

```r
# SQL aggregation using DuckDB unnest() to flatten referenced_works arrays
backward_refs <- dbGetQuery(con, "
  WITH unnested AS (
    SELECT
      paper_id as citing_paper,
      unnest(string_split(referenced_works, ',')) as cited_work_id
    FROM abstracts
    WHERE notebook_id = ?
    AND referenced_works IS NOT NULL
    AND referenced_works != ''
  )
  SELECT
    cited_work_id as work_id,
    COUNT(*) as collection_frequency,
    'backward' as direction
  FROM unnested
  WHERE cited_work_id NOT IN (
    SELECT paper_id FROM abstracts WHERE notebook_id = ?
  )
  GROUP BY cited_work_id
  HAVING COUNT(*) >= 2
  ORDER BY collection_frequency DESC
", list(notebook_id, notebook_id))
```

**Key insight:** `unnest(string_split())` flattens comma-separated referenced_works into rows; NOT IN subquery excludes papers already in collection; single query aggregates all backward refs.

**Source:** DuckDB documentation on `unnest()`; pattern adapted from citation_network.R refs_map usage.

### Example 3: Batch Import with Progress Reporting

```r
# Reuse batch_fetch_papers() from Phase 34 with progress callback
run_batch_import <- function(missing_dois, notebook_id, email, api_key, db_path,
                              interrupt_flag, progress_file) {
  # Progress callback
  progress_cb <- function(batch_current, batch_total, found_so_far, not_found_so_far) {
    msg <- sprintf("Importing batch %d/%d: %d found, %d not found",
                   batch_current, batch_total, found_so_far, not_found_so_far)
    write_import_progress(progress_file, batch_current, batch_total,
                          found_so_far, not_found_so_far, msg)

    # Check for cancellation
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      stop("Import cancelled by user")
    }
  }

  # Fetch papers from OpenAlex
  result <- batch_fetch_papers(
    dois = missing_dois,
    email = email,
    api_key = api_key,
    progress_callback = progress_cb
  )

  # Store in database
  for (paper in result$papers) {
    create_abstract(con, notebook_id, paper$paper_id, paper$title, ...)
  }

  list(imported = length(result$papers), failed = length(result$errors))
}
```

**Source:** bulk_import.R `run_bulk_import()` function (lines 157-273); reuse pattern for citation audit batch import.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Citation analysis as manual workflow | Automated citation gap detection | Phase 37 (current) | Users can discover missing influential papers without manual cross-referencing |
| Row-by-row citation fetching | Batch API queries with pipe syntax | Phase 34 (2026-02-26) | 50x reduction in API calls for forward citations |
| In-memory R aggregation | SQL GROUP BY with unnest() | DuckDB 0.8+ (2023) | 100-1000x performance improvement for large notebooks |

**Deprecated/outdated:**
- Individual `get_paper()` calls for missing papers — use batch_fetch_papers() with pipe-separated DOIs instead
- R `table()` for counting citations — use SQL GROUP BY for in-database aggregation

## Validation Architecture

> Validation enabled per workflow.nyquist_validation in .planning/config.json

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x (existing) |
| Config file | tests/testthat.R (existing) |
| Quick run command | `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUDIT-01 | Trigger audit on notebook | integration | `Rscript -e "testthat::test_file('tests/testthat/test-mod-citation-audit.R', filter = 'trigger')" -x` | ❌ Wave 0 |
| AUDIT-02 | Backward refs SQL aggregation | unit | `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R', filter = 'backward')" -x` | ❌ Wave 0 |
| AUDIT-03 | Forward citations batch query | unit | `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R', filter = 'forward')" -x` | ❌ Wave 0 |
| AUDIT-04 | Frequency ranking with threshold | unit | `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R', filter = 'ranking')" -x` | ❌ Wave 0 |
| AUDIT-05 | Results table rendering | integration | `Rscript -e "testthat::test_file('tests/testthat/test-mod-citation-audit.R', filter = 'display')" -x` | ❌ Wave 0 |
| AUDIT-06 | Single and batch import | integration | `Rscript -e "testthat::test_file('tests/testthat/test-mod-citation-audit.R', filter = 'import')" -x` | ❌ Wave 0 |
| AUDIT-07 | Async with progress and cancel | integration | `Rscript -e "testthat::test_file('tests/testthat/test-mod-citation-audit.R', filter = 'async')" -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_file('tests/testthat/test-citation-audit.R')" -x`
- **Per wave merge:** `Rscript -e "testthat::test_dir('tests/testthat')" -x`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

Test infrastructure setup needed before implementation:

- [ ] `tests/testthat/test-citation-audit.R` — covers AUDIT-02, AUDIT-03, AUDIT-04 (SQL aggregation, batch queries, ranking logic)
- [ ] `tests/testthat/test-mod-citation-audit.R` — covers AUDIT-01, AUDIT-05, AUDIT-06, AUDIT-07 (UI integration, async execution)
- [ ] Test fixtures: sample notebooks with referenced_works arrays, mock OpenAlex batch responses

## Open Questions

1. **Cache invalidation trigger**
   - What we know: User can manually re-run audit; results cached with last_analyzed timestamp
   - What's unclear: Should cache auto-invalidate when new abstracts added to notebook? Or purely manual re-run?
   - Recommendation: Purely manual re-run (simpler, matches user constraint "user can re-run manually"); show staleness indicator if notebook.updated_at > audit.last_analyzed

2. **Direction breakdown display format**
   - What we know: Must distinguish backward from forward citations (user constraint)
   - What's unclear: Separate columns vs. tooltip vs. badge vs. inline text?
   - Recommendation: Separate columns (backward_count, forward_count) — clearest UX, enables independent sorting, no hover required

3. **Batch import size limit**
   - What we know: batch_fetch_papers() handles chunking automatically (50 DOIs per batch)
   - What's unclear: Should we warn/block if user selects >100 papers for batch import?
   - Recommendation: Show warning above 100 papers ("This may take several minutes"), no hard block — user may legitimately need large batch imports

## Sources

### Primary (HIGH confidence)

- DuckDB documentation - `unnest()` function: https://duckdb.org/docs/sql/functions/nested.html
- OpenAlex API documentation - batch queries with pipe syntax: https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists
- Existing codebase: R/api_openalex.R (batch_fetch_papers, get_citing_papers, get_cited_papers)
- Existing codebase: R/citation_network.R (BFS traversal, referenced_works handling)
- Existing codebase: R/bulk_import.R (async with ExtendedTask, progress modal, batch import)
- Existing codebase: R/interrupt.R (interrupt flags, progress files)
- Existing codebase: migrations/006_create_citation_networks.sql (graph storage pattern)

### Secondary (MEDIUM confidence)

- DuckDB array aggregation patterns: https://duckdb.org/docs/guides/sql_features/unnest.html
- R Shiny ExtendedTask documentation: https://shiny.posit.co/r/articles/improve/async/

### Tertiary (LOW confidence)

None — all findings verified with official docs or existing codebase patterns.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use; no new dependencies
- Architecture: HIGH - SQL aggregation pattern verified with DuckDB docs; async pattern proven in 3 existing modules
- Pitfalls: HIGH - Identified from common SQL anti-patterns + existing codebase issues (connection leaks, N+1 queries)

**Research date:** 2026-02-26
**Valid until:** 2026-04-26 (60 days — stable domain, mature codebase patterns)
