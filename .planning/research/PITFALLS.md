# Domain Pitfalls: Citation Networks, Export, and Cross-Module Integration

**Domain:** Citation Graph Visualization, BibTeX Export, Cross-Module Navigation, DOI Storage
**Researched:** 2026-02-12
**Confidence:** MEDIUM-HIGH

**Scope:** This research focuses on pitfalls specific to adding citation network discovery, export features, and cross-module communication to an existing R/Shiny research assistant with DuckDB backend and OpenAlex API integration.

---

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: Citation Network Exponential Explosion

**What goes wrong:**
User clicks "Show citation network" for a paper with 50 citations. App fetches those 50 papers from OpenAlex, then fetches *their* citations (2,500 papers), then *their* citations (125,000 papers). API rate limit exhausted in minutes. UI freezes for 60+ seconds. Browser tab crashes from rendering 100k+ nodes.

**Why it happens:**
Citation networks grow exponentially: average paper cites 25 others. Recursive fetching without depth limit or breadth control. No deduplication → same paper fetched multiple times. Rendering all nodes at once (visNetwork/igraph default behavior). Developer tests with recent papers (few citations) but users explore seminal papers (thousands of citations).

**Consequences:**
- OpenAlex daily quota (100,000 credits) consumed in single session
- Browser memory overflow (Chrome kills tab at ~2GB)
- Users wait minutes then force-quit app
- Corrupted database state if API fetch interrupted mid-transaction

**Prevention:**
1. **Depth limiting:** Default to 1-hop (direct citations only), max 2-hops with warning
2. **Breadth limiting:** Cap at 100 papers per level (e.g., show "50 more citations..." button)
3. **Batch fetching:** Use OpenAlex OR syntax `filter=ids:W1|W2|W3...` (50 IDs per request) instead of individual lookups
4. **Progressive loading:** Fetch and render incrementally (10 papers at a time with loading indicator)
5. **Credit budgeting:** Calculate estimated API cost before fetch, require user confirmation if >1000 credits
6. **Deduplication:** Track fetched paper IDs in Set, skip already-loaded papers
7. **Lazy rendering:** Render only visible viewport (visNetwork `stabilization=FALSE` + viewport clipping)

**Detection:**
- Monitor API credit consumption rate (>100 credits/minute → likely explosion)
- Track citation fetch depth in logs
- Browser console shows "out of memory" errors
- Users report "app crashed after clicking citation button"
- visNetwork stabilization takes >30 seconds

**Phase to address:**
**Phase: Citation Discovery (06)** — Must implement depth/breadth limits BEFORE building UI. Non-negotiable for MVP.

**Sources:**
- [OpenAlex Rate Limits](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- [Citation Networks as DAGs](https://en.wikipedia.org/wiki/Citation_graph)
- [visNetwork Performance Tips](https://datastorm-open.github.io/visNetwork/shiny.html)

---

### Pitfall 2: Citation Graph Cycles Break DAG Assumptions

**What goes wrong:**
Citation network rendering assumes DAG (directed acyclic graph) for layout algorithms. Encounter citation cycle: Paper A (arXiv preprint) cites Paper B → Paper B (published version) cites Paper A (updated preprint). Layout algorithm loops infinitely. Hierarchical layout crashes with "cycle detected" error. Graph displays with overlapping nodes.

**Why it happens:**
Real-world citation networks have cycles (~1% of edges) due to:
- Preprints updated after citing paper published
- Same-issue papers citing each other (conference proceedings)
- Database errors (incorrect metadata)
- Self-citations recorded as edges (should be filtered)

Developers assume textbook DAG properties. Layout libraries (igraph hierarchical layout, dagre) fail on cyclic input. No cycle detection before rendering.

**Consequences:**
- `igraph::layout_as_tree()` throws error, graph doesn't render
- Infinite loops in custom layout algorithms
- Overlapping/misplaced nodes confuse users
- Users report "some papers missing from graph"

**Prevention:**
1. **Cycle detection:** Use `igraph::is_dag()` before layout, fallback to force-directed if cycles exist
2. **Edge filtering:** Remove self-loops (`from == to`) and duplicate edges before layout
3. **Transitive reduction:** Simplify graph to remove redundant edges (A→B→C makes A→C redundant)
4. **Layout fallback hierarchy:**
   - Try hierarchical layout (`layout_as_tree`) if DAG
   - Fall back to force-directed (`layout_with_fr`) if cycles
   - Final fallback: circular layout (always works)
5. **User notification:** Display "Citation cycles detected (N edges removed for clarity)" if cycles found
6. **Test data:** Include cyclic citation examples in test suite

**Detection:**
- Error logs: "not a DAG" or "cycle detected"
- Graph renders but nodes overlap
- Layout time >10 seconds (symptom of cycle-induced loop)
- Missing papers in visualization vs. database

**Phase to address:**
**Phase: Citation Discovery (06)** — Cycle handling required for reliable rendering. Add to graph construction logic.

**Sources:**
- [Citation Networks and DAGs](https://en.wikipedia.org/wiki/Citation_graph)
- [Transitive Reduction of Citation Networks](https://academic.oup.com/comnet/article-pdf/3/2/189/1071092/cnu039.pdf)
- [igraph DAG Detection](https://igraph.org/r/doc/is_dag.html)

---

### Pitfall 3: Cross-Module State Contamination via Global reactiveValues

**What goes wrong:**
Search notebook and discovery workflow share `app_state <- reactiveValues()` defined in `app_server.R`. User A selects papers in search notebook → triggers export to discovery. User B (different session on shared server) sees User A's paper selections appear in their UI. Multi-user sessions corrupt each other's state. Single-user sees stale data from previous workflow.

**Why it happens:**
Global `reactiveValues` defined outside `session` scope is shared across ALL sessions. Developer tests locally (single session) → works fine. Deployed to RStudio Connect/Shinyapps.io with multiple users → shared state. Modules read from `app_state$selected_papers` → contaminated by other sessions. No session isolation.

**Consequences:**
- Data leakage between users (security + privacy issue)
- Stale state from previous user persists
- Users report "seeing other people's papers"
- Non-deterministic bugs (depends on user order)

**Prevention:**
1. **Session-scoped reactiveValues:** Define inside `server <- function(input, output, session)` NOT outside
   ```r
   # WRONG (global)
   app_state <- reactiveValues(selected = list())
   server <- function(input, output, session) { ... }

   # CORRECT (session-scoped)
   server <- function(input, output, session) {
     app_state <- reactiveValues(selected = list())
   }
   ```

2. **Pass reactiveValues to modules:** Don't rely on global scope
   ```r
   # Module call
   discovery_server("discovery", app_state = app_state, db_con = db_con)

   # Module definition
   discovery_server <- function(id, app_state, db_con) {
     moduleServer(id, function(input, output, session) {
       # Use app_state here (session-isolated)
     })
   }
   ```

3. **Avoid session$userData for cross-module state:** Use explicit parameters instead
   - `session$userData` breaks module encapsulation
   - Hard to track data flow
   - Creates hidden dependencies

4. **R6 objects for complex state:** Alternative to reactiveValues for non-reactive shared state
   ```r
   AppState <- R6Class("AppState",
     public = list(
       selected_papers = list(),
       set_selected = function(papers) { self$selected_papers <- papers }
     )
   )
   # Create per-session instance
   server <- function(input, output, session) {
     app_state <- AppState$new()
   }
   ```

5. **Test multi-session behavior:** Use `shinytest2` with multiple sessions, verify isolation

**Detection:**
- Different users see same data
- State persists across app reloads (single-user symptom)
- `reactiveLog` shows unexpected cross-talk
- Deployed app behaves differently than local

**Phase to address:**
**Phase: Export Integration (07)** — Session isolation must work BEFORE cross-module navigation. Verify in testing, not production.

**Sources:**
- [Shiny Modules: Communication Patterns](https://mastering-shiny.org/scaling-modules.html)
- [Communication Between Modules Anti-Patterns](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/)
- [session$userData Pitfalls](https://engineering-shiny.org/common-app-caveats.html)

---

### Pitfall 4: DOI Field Migration Breaks Existing User Databases

**What goes wrong:**
Add `doi VARCHAR` column to `abstracts` table via `ALTER TABLE` in new release. New installs work fine. Existing users upgrade → database schema has new column, but ALL existing papers have `NULL` DOI. Search by DOI returns zero results. Export to BibTeX fails validation (missing DOI field). Users report "DOI feature doesn't work" → requires manual re-import of all papers.

**Why it happens:**
Migration adds column but doesn't backfill data. OpenAlex API returns DOI in response, but wasn't stored historically. No migration script to fetch DOIs for existing papers. Developer tests with fresh database → all papers have DOIs. Users with 1000+ existing papers → 99% have NULL DOI.

**Consequences:**
- Feature appears broken for existing users
- Manual re-import loses user annotations/tags
- Support burden: "Why don't my papers have DOIs?"
- Database migration fails silently (no error, just NULL)

**Prevention:**
1. **Migration versioning:** Use `PRAGMA user_version` (DuckDB supports this)
   ```sql
   -- Check current version
   SELECT * FROM pragma_user_version();

   -- Set version after migration
   PRAGMA user_version = 2;
   ```

2. **Backfill migration script:** Add column THEN populate for existing rows
   ```sql
   -- Migration 002: Add DOI column and backfill
   BEGIN TRANSACTION;

   -- Add column (NULL for existing rows)
   ALTER TABLE abstracts ADD COLUMN doi VARCHAR;

   -- Backfill: For papers with paper_id matching OpenAlex format (W12345),
   -- mark for async fetch (set doi = 'PENDING')
   UPDATE abstracts
   SET doi = 'PENDING'
   WHERE paper_id LIKE 'W%' AND doi IS NULL;

   PRAGMA user_version = 2;
   COMMIT;
   ```

3. **Async backfill:** Don't fetch 1000 DOIs during migration (slow startup)
   - Mark rows as `PENDING`
   - Background job fetches DOIs in batches (50 papers per API call using OR syntax)
   - Progress indicator: "Fetching DOI for 450/1000 papers..."
   - Cache fetched DOIs to avoid re-fetching

4. **Graceful degradation:** UI handles NULL DOI
   - Export: Generate citation key from title+year if DOI missing
   - Display: Show "DOI unavailable" instead of empty field
   - Search: Allow DOI filter but show count of DOI-enabled papers

5. **Test migration path:** Automated test with v1 database → v2 upgrade → verify DOI presence

6. **DuckDB-specific quirks:**
   - `ALTER TABLE ADD COLUMN` doesn't support `NOT NULL` constraint if rows exist ([Issue #3248](https://github.com/duckdb/duckdb/issues/3248))
   - Column defaults only apply to new rows, not existing
   - No `UPDATE ... FROM` syntax for joins (use `UPDATE WHERE EXISTS`)

**Detection:**
- Database has `doi` column but all values NULL
- DOI search returns 0 results for existing users
- BibTeX export warnings: "Missing DOI for 95% of papers"
- Different behavior for new vs. upgraded users

**Phase to address:**
**Phase: Database Enhancement (05)** — Implement migration infrastructure BEFORE adding DOI column. Test with realistic user database (1000+ papers).

**Sources:**
- [DuckDB ALTER TABLE](https://duckdb.org/docs/stable/sql/statements/alter_table)
- [DuckDB NOT NULL Limitation](https://github.com/duckdb/duckdb/issues/3248)
- [SQLite Patterns for R Shiny](https://unconj.ca/blog/advanced-sqlite-patterns-for-r-and-shiny.html)

---

### Pitfall 5: BibTeX Export Encoding Corruption

**What goes wrong:**
Export 50 papers to BibTeX file. Open in citation manager → garbled characters: "café" becomes "cafÃ©", "Müller" becomes "MÃ¼ller". LaTeX compilation errors: "Undefined control sequence \textbackslash". Accented author names break bibliography rendering. Non-Latin scripts (Greek symbols, Chinese names) completely mangled.

**Why it happens:**
BibTeX has complex encoding requirements:
- **Legacy BibTeX:** Only supports ASCII + LaTeX escape sequences (`{\"u}` for ü)
- **BibLaTeX/Biber:** Supports UTF-8 natively
- **Mixed environments:** Some users have old TeX distributions expecting ASCII

Shiny `downloadHandler` doesn't specify encoding → defaults to system locale (Windows: CP1252, Linux: UTF-8). OpenAlex returns UTF-8 → written with wrong encoding. Special characters require LaTeX escaping (`&` → `\&`, `%` → `\%`) but not applied.

**Consequences:**
- Broken citations in LaTeX documents
- Users manually fix 50+ entries
- Reputation damage: "Export feature is broken"
- Non-reproducible bugs (depends on user's OS/locale)

**Prevention:**
1. **Specify UTF-8 explicitly in downloadHandler:**
   ```r
   downloadHandler(
     filename = "citations.bib",
     content = function(file) {
       # CRITICAL: Specify UTF-8 encoding
       con <- file(file, open = "w", encoding = "UTF-8")
       writeLines(bib_content, con)
       close(con)
     }
   )
   ```

2. **Add UTF-8 BOM (optional but helpful):**
   ```r
   # Write UTF-8 byte order mark for better compatibility
   writeBin(charToRaw('\ufeff'), file)
   writeLines(bib_content, file)
   ```

3. **LaTeX special character escaping:**
   ```r
   escape_latex <- function(text) {
     text <- gsub("\\\\", "\\\\textbackslash ", text)  # Must escape backslash first
     text <- gsub("&", "\\\\&", text)
     text <- gsub("%", "\\\\%", text)
     text <- gsub("\\$", "\\\\$", text)
     text <- gsub("_", "\\\\_", text)
     text <- gsub("\\{", "\\\\{", text)
     text <- gsub("\\}", "\\\\}", text)
     text <- gsub("~", "\\\\textasciitilde ", text)
     text <- gsub("\\^", "\\\\textasciicircum ", text)
     text
   }
   ```

4. **Use rbibutils package:** Handles encoding correctly
   ```r
   library(rbibutils)
   # Convert to BibTeX with UTF-8 encoding
   writeBib(bib_entries, file = file,
            encoding = "UTF-8",
            texChars = "export")  # Convert special chars to TeX sequences
   ```

5. **Provide encoding options:** Let users choose
   - "UTF-8 (modern, BibLaTeX)" — default
   - "ASCII + LaTeX escapes (legacy BibTeX)" — convert ü → {\"u}
   - Test exports with both old and new TeX distributions

6. **Validate output:** Test BibTeX parsing with `rbibutils::readBib()`
   ```r
   # After export, verify it's valid
   tryCatch({
     readBib(file, encoding = "UTF-8")
   }, error = function(e) {
     showNotification("Export may have encoding issues", type = "warning")
   })
   ```

**Detection:**
- User reports "weird characters in exported file"
- BibTeX entries fail to parse in Zotero/Mendeley
- LaTeX compilation errors referencing bibliography
- Different results on Windows vs. Mac/Linux

**Phase to address:**
**Phase: Export Features (07)** — UTF-8 handling must work from day 1 of export feature. Add to export MVP requirements.

**Sources:**
- [rbibutils Encoding](https://geobosh.github.io/rbibutils/)
- [BibTeX UTF-8 Support Discussion](https://latex.org/forum/viewtopic.php?t=8673)
- [Zotero BibTeX Export Encoding](https://forums.zotero.org/discussion/24136/default-encoding-in-bibtex-export)

---

### Pitfall 6: Download Handler Tempdir Permission Errors in Production

**What goes wrong:**
`downloadHandler` for BibTeX export works locally. Deploy to shinyapps.io → users click Download → error "Permission denied" or "Cannot write to directory". Export fails silently (button does nothing). Logs show `EACCES` error writing to working directory.

**Why it happens:**
Shiny apps on shared hosting (shinyapps.io, RStudio Connect) run with restricted filesystem permissions. Cannot write to working directory (`getwd()`). `downloadHandler` content function tries to write intermediate files to working directory → permission denied. Local development has full permissions → masking the issue.

**Consequences:**
- Export feature completely broken in production
- No error message shown to user (silent failure)
- Developer can't reproduce locally
- Emergency hotfix requires redeployment

**Prevention:**
1. **Always use tempdir() for intermediate files:**
   ```r
   downloadHandler(
     filename = "citations.bib",
     content = function(file) {
       # CORRECT: Use tempdir() which is always writable
       temp_file <- file.path(tempdir(), "temp_citations.bib")

       # Generate BibTeX content
       write_bibtex(papers, temp_file)

       # Copy to download location (Shiny-managed path)
       file.copy(temp_file, file, overwrite = TRUE)
     }
   )
   ```

2. **Test on production-like environment:**
   - Use Docker container with restricted permissions
   - Deploy to shinyapps.io free tier for testing
   - Run with `Sys.setFilePermissions(getwd(), mode = "0500")` to simulate read-only

3. **Avoid rmarkdown::render() in working directory:**
   ```r
   # WRONG: Renders in current dir (no write permission)
   rmarkdown::render("report.Rmd", output_file = file)

   # CORRECT: Copy template to tempdir first
   temp_rmd <- file.path(tempdir(), "report.Rmd")
   file.copy("report.Rmd", temp_rmd)
   rmarkdown::render(temp_rmd, output_dir = tempdir())
   ```

4. **Handle Windows Storage Sense issue:**
   - Windows 10+ may delete tempdir() contents periodically
   - For long-running sessions, check if tempdir exists before use
   ```r
   ensure_tempdir <- function() {
     td <- tempdir()
     if (!dir.exists(td)) {
       dir.create(td, recursive = TRUE)
     }
     td
   }
   ```

5. **Clean up temp files explicitly:**
   ```r
   content = function(file) {
     temp_file <- file.path(tempdir(), "citations.bib")
     on.exit(unlink(temp_file), add = TRUE)  # Clean up on function exit

     # ... generate content ...
   }
   ```

**Detection:**
- Production logs: "Permission denied" or "EACCES"
- Download button works locally but not deployed
- Users report "nothing happens when I click download"
- Error logs show `Error in file.create(...)` or `cannot open file`

**Phase to address:**
**Phase: Export Features (07)** — Test with restricted permissions BEFORE deployment. Add to deployment checklist.

**Sources:**
- [Shiny Download Handler Best Practices](https://mastering-shiny.org/action-transfer.html)
- [Generating Reports with Shiny](https://shiny.posit.co/r/articles/build/generating-reports/)
- [Windows Storage Sense Issue](https://github.com/rstudio/shiny/issues/2542)

---

## Moderate Pitfalls

### Pitfall 7: visNetwork Reactivity Cascade Performance

**What goes wrong:**
Citation network visualization with 200 nodes. User filters by year → triggers reactive update → visNetwork re-renders entire graph → 5-second freeze. Every filter change re-stabilizes physics simulation → UI unresponsive. Users can't interact with graph during updates.

**Why it happens:**
visNetwork physics stabilization is expensive (O(n²) for n nodes). Every reactive invalidation triggers full re-render instead of incremental update. Reactive expression depends on multiple inputs (filters, selected papers) → cascading updates. No use of `visNetworkProxy` to update without redrawing.

**Consequences:**
- Sluggish UI during filtering
- Users wait 5-10 seconds for graph to update
- Browser becomes unresponsive (single-threaded JS)
- Poor user experience compared to static graph

**Prevention:**
1. **Use visNetworkProxy for updates:**
   ```r
   # Initial render (one time)
   output$network <- renderVisNetwork({
     visNetwork(nodes, edges) %>%
       visPhysics(stabilization = FALSE)  # Disable auto-stabilization
   })

   # Updates via proxy (no full redraw)
   observeEvent(input$year_filter, {
     filtered_nodes <- filter_nodes(input$year_filter)

     visNetworkProxy("network") %>%
       visUpdateNodes(filtered_nodes)  # Update without redraw
   })
   ```

2. **Disable physics for large graphs:**
   ```r
   visNetwork(nodes, edges) %>%
     visPhysics(
       stabilization = FALSE,  # No initial stabilization
       enabled = nrow(nodes) < 100  # Disable physics if >100 nodes
     )
   ```

3. **Precompute layout with igraph:**
   ```r
   library(igraph)
   g <- graph_from_data_frame(edges, vertices = nodes)
   layout <- layout_with_fr(g)  # Force-directed layout (computed once)

   nodes$x <- layout[, 1] * 100
   nodes$y <- layout[, 2] * 100

   visNetwork(nodes, edges) %>%
     visPhysics(enabled = FALSE)  # Use precomputed positions
   ```

4. **Debounce filter inputs:**
   ```r
   year_filter_debounced <- debounce(reactive(input$year_filter), 500)

   observeEvent(year_filter_debounced(), { ... })
   ```

5. **Throttle reactive updates:**
   ```r
   # Update at most once per second
   observe({
     invalidateLater(1000)
     visNetworkProxy("network") %>% visUpdateNodes(filtered_nodes())
   })
   ```

6. **Progressive rendering for huge graphs:**
   ```r
   # Render first 50 nodes immediately
   render_nodes <- nodes[1:50, ]
   visNetwork(render_nodes, edges) %>% ...

   # Add remaining nodes asynchronously
   later::later(function() {
     visNetworkProxy("network") %>%
       visUpdateNodes(nodes[51:nrow(nodes), ])
   }, delay = 1)
   ```

**Detection:**
- visNetwork re-stabilization on every input change
- `reactlog` shows frequent invalidation of network output
- UI freezes during graph updates
- Browser DevTools shows long-running JS tasks (>1 second)

**Phase to address:**
**Phase: Citation Discovery (06)** — Optimize before user testing. Proxy-based updates required for 100+ node graphs.

**Sources:**
- [visNetwork with Shiny](https://datastorm-open.github.io/visNetwork/shiny.html)
- [visNetwork Performance](https://www.kaizen-r.com/2022/06/faster-graphs-in-r-igraph-vs-visnetwork/)
- [Shiny Reactivity Performance](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/reactive-values.html)

---

### Pitfall 8: DOI Validation Fragility

**What goes wrong:**
Store DOI in database without validation. Some entries: `10.1234/abc`, `https://doi.org/10.1234/abc`, `doi:10.1234/abc`, `DOI: 10.1234/abc`. BibTeX export inconsistent: some entries have URL, some have bare DOI. Citation managers reject malformed DOIs. Users report "some citations don't import correctly".

**Why it happens:**
OpenAlex may return DOI in different formats (usually lowercase URL). User input allows free text. No normalization before storage. BibTeX `doi` field expects bare DOI (not URL). Different conventions: CrossRef uses lowercase, some journals use uppercase.

**Consequences:**
- Duplicate papers in database (same DOI, different formats)
- BibTeX export invalid
- Citation manager import fails
- DOI search misses papers

**Prevention:**
1. **Normalize DOI before storage:**
   ```r
   normalize_doi <- function(doi) {
     if (is.null(doi) || is.na(doi) || doi == "") return(NA_character_)

     # Remove common prefixes
     doi <- gsub("^https?://doi\\.org/", "", doi, ignore.case = TRUE)
     doi <- gsub("^https?://dx\\.doi\\.org/", "", doi, ignore.case = TRUE)
     doi <- gsub("^doi:\\s*", "", doi, ignore.case = TRUE)
     doi <- trimws(doi)

     # Lowercase (DOI registry is case-insensitive but lowercase is standard)
     doi <- tolower(doi)

     # Validate format: starts with "10."
     if (!grepl("^10\\.", doi)) {
       warning("Invalid DOI format: ", doi)
       return(NA_character_)
     }

     doi
   }
   ```

2. **Validate DOI format:**
   ```r
   is_valid_doi <- function(doi) {
     # DOI regex: 10.xxxx/suffix (where xxxx is 4+ digits, suffix is anything)
     grepl("^10\\.\\d{4,}/[-._;()/:a-zA-Z0-9]+$", doi)
   }
   ```

3. **Store bare DOI, generate URL on demand:**
   ```r
   # Database: "10.1234/abc"
   # Display: <a href="https://doi.org/{doi}">{doi}</a>
   doi_url <- function(doi) paste0("https://doi.org/", doi)
   ```

4. **BibTeX export: Use bare DOI:**
   ```r
   # CORRECT
   @article{key,
     doi = {10.1234/abc},
     ...
   }

   # WRONG (some tools expect URL in separate field)
   @article{key,
     doi = {https://doi.org/10.1234/abc},
     ...
   }
   ```

5. **Handle missing DOIs gracefully:**
   ```r
   # Don't include empty doi field in BibTeX
   if (!is.na(doi) && doi != "") {
     sprintf("  doi = {%s},\n", doi)
   } else {
     ""
   }
   ```

**Detection:**
- Database query: `SELECT DISTINCT doi FROM abstracts WHERE doi LIKE '%://%'` returns rows
- BibTeX export has mixed formats
- Users report duplicate papers with "same DOI"
- CrossRef API lookups fail for some DOIs

**Phase to address:**
**Phase: Database Enhancement (05)** — Normalization required when adding DOI column. Add validation to `store_paper()` function.

**Sources:**
- [DOI Field Format](https://www.bibtex.com/f/doi-field/)
- [BibTeX DOI Validation](https://bibtex.eu/fields/doi/)
- [CrossRef DOI Best Practices](https://www.crossref.org/documentation/retrieve-metadata/rest-api/)

---

### Pitfall 9: Cross-Module Navigation State Loss

**What goes wrong:**
User searches for "machine learning" in Search Notebook → selects 5 papers → clicks "Explore Citations". Discovery module opens with citation network. User clicks "Back to Search". Search results gone → returns to empty search. Must re-run query. Selected papers lost. Frustrating back-and-forth workflow.

**Why it happens:**
Modules don't preserve state across navigation. Search results stored in reactive expression (ephemeral). No persistence layer for UI state. Navigation implemented as tab switch → resets module. No "return to previous state" mechanism.

**Consequences:**
- Users lose work when switching modules
- Must re-run expensive queries
- Poor UX compared to browser back button
- Users avoid cross-module features

**Prevention:**
1. **Persist search state in reactiveValues:**
   ```r
   server <- function(input, output, session) {
     app_state <- reactiveValues(
       search_results = NULL,
       search_query = "",
       selected_papers = list(),
       current_tab = "search"
     )

     # Search module saves state
     search_server("search", app_state)

     # Discovery module reads state
     discovery_server("discovery", app_state)
   }
   ```

2. **Save search results on navigation:**
   ```r
   # In search module
   observeEvent(input$explore_citations, {
     # Save current state before switching
     app_state$search_results <- search_results()
     app_state$search_query <- input$query
     app_state$selected_papers <- input$selected_rows

     # Switch to discovery tab
     updateTabsetPanel(session, "main_tabs", selected = "discovery")
   })
   ```

3. **Restore state on return:**
   ```r
   # In search module
   observe({
     # Restore search when tab becomes active
     if (input$main_tabs == "search" && !is.null(app_state$search_results)) {
       # Restore results without re-querying
       search_results(app_state$search_results)
       updateTextInput(session, "query", value = app_state$search_query)
     }
   })
   ```

4. **Use database for expensive state:**
   ```r
   # Store search results temporarily in DB
   save_search_session <- function(db_con, session_id, results) {
     dbExecute(db_con, "
       CREATE TEMP TABLE IF NOT EXISTS search_cache (
         session_id VARCHAR,
         results TEXT,
         timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       )
     ")

     dbExecute(db_con, "
       INSERT INTO search_cache (session_id, results)
       VALUES (?, ?)
     ", params = list(session_id, jsonlite::toJSON(results)))
   }
   ```

5. **Breadcrumb navigation pattern:**
   ```r
   # Display "Search > Discovery" breadcrumb
   # Click "Search" → returns to previous state (not new search)
   output$breadcrumb <- renderUI({
     path <- app_state$navigation_path
     tagList(
       actionLink("nav_search", "Search"),
       if ("discovery" %in% path) {
         tagList(" > ", actionLink("nav_discovery", "Discovery"))
       }
     )
   })
   ```

6. **Browser back button support (advanced):**
   ```r
   # Use shiny.router or shiny.semantic.dashboard
   # Enables browser back/forward with state preservation
   library(shiny.router)
   route("/search", search_page)
   route("/discovery", discovery_page)
   ```

**Detection:**
- Users complain "lost my search results"
- Frequent re-runs of same query
- High API usage from redundant searches
- Users avoid cross-module features

**Phase to address:**
**Phase: Export Integration (07)** — State preservation required for cross-module navigation. Core UX requirement.

**Sources:**
- [Shiny Modules: Passing State](https://mastering-shiny.org/scaling-modules.html)
- [reactiveValues for State Management](https://medium.com/@netomics/modifying-reactive-values-in-shiny-apps-f5df29fb6603)
- [shiny.router for Navigation](https://appsilon.github.io/shiny.router/)

---

### Pitfall 10: BibTeX Citation Key Collisions

**What goes wrong:**
Export 100 papers to BibTeX. Citation keys generated as `author_year` → multiple papers by same author in same year → duplicate keys `smith_2020`, `smith_2020`, `smith_2020`. LaTeX compilation warning: "Citation 'smith_2020' multiply defined". Bibliography shows only first paper. Users manually rename 20+ keys.

**Why it happens:**
Naive citation key generation: `paste(first_author, year, sep = "_")`. Multiple papers by same author-year combination. No uniqueness check. No suffix generation (smith_2020a, smith_2020b). OpenAlex doesn't provide citation keys → must generate.

**Consequences:**
- Duplicate keys break LaTeX bibliography
- Only first occurrence rendered
- Users spend 30+ minutes manually fixing
- Export feature appears broken

**Prevention:**
1. **Generate unique keys with suffix:**
   ```r
   generate_citation_keys <- function(papers) {
     keys <- character(nrow(papers))
     key_counts <- list()

     for (i in seq_len(nrow(papers))) {
       # Extract first author last name
       first_author <- extract_first_author(papers$authors[i])
       year <- papers$year[i]

       # Base key
       base_key <- tolower(paste(first_author, year, sep = "_"))
       base_key <- gsub("[^a-z0-9_]", "", base_key)  # Remove special chars

       # Add suffix if duplicate
       if (base_key %in% names(key_counts)) {
         key_counts[[base_key]] <- key_counts[[base_key]] + 1
         suffix <- letters[key_counts[[base_key]]]
         keys[i] <- paste0(base_key, suffix)
       } else {
         key_counts[[base_key]] <- 1
         keys[i] <- base_key
       }
     }

     keys
   }
   ```

2. **Use DOI-based keys (most reliable):**
   ```r
   # Convert DOI to key: 10.1234/abc → doi_10_1234_abc
   doi_to_key <- function(doi) {
     paste0("doi_", gsub("[^a-zA-Z0-9]", "_", doi))
   }
   ```

3. **Validate uniqueness before export:**
   ```r
   validate_citation_keys <- function(keys) {
     dupes <- keys[duplicated(keys)]
     if (length(dupes) > 0) {
       stop("Duplicate citation keys: ", paste(dupes, collapse = ", "))
     }
     keys
   }
   ```

4. **Let users customize key format:**
   ```r
   # Settings option
   selectInput("citation_key_format", "Citation Key Format",
     choices = c(
       "author_year" = "author_year",
       "doi" = "doi",
       "custom" = "custom"
     )
   )
   ```

5. **Include OpenAlex ID as fallback:**
   ```r
   # If author extraction fails, use OpenAlex ID
   if (is.na(first_author) || first_author == "") {
     base_key <- paste0("openalex_", gsub("W", "", paper_id))
   }
   ```

**Detection:**
- BibTeX export warnings on import
- LaTeX compilation: "multiply defined" warnings
- Users report "missing citations in bibliography"
- Testing: Export same paper twice → duplicate keys

**Phase to address:**
**Phase: Export Features (07)** — Unique key generation required from day 1. Part of export MVP.

**Sources:**
- [BibTeX Key Conventions](https://www.bibtex.com/g/bibtex-format/)
- [Citation Key Best Practices](https://retorque.re/zotero-better-bibtex/index.print.html)

---

## Minor Pitfalls

### Pitfall 11: Citation Network Node Label Truncation

**What goes wrong:**
Citation graph shows 50 papers. Node labels truncated: "A Survey of Deep Learni..." (meaningless). Users can't identify papers without clicking each node. Tooltips overlap making them unreadable. Graph visualization useless for navigation.

**Why it happens:**
visNetwork default label length too short. Long paper titles overflow node boundaries. No title abbreviation strategy (use first 3 words + ...). Tooltip not configured.

**Prevention:**
1. **Smart title truncation:**
   ```r
   truncate_title <- function(title, max_words = 5) {
     words <- strsplit(title, " ")[[1]]
     if (length(words) <= max_words) return(title)
     paste(paste(words[1:max_words], collapse = " "), "...")
   }

   nodes$label <- sapply(nodes$title, truncate_title)
   ```

2. **Full title in tooltip:**
   ```r
   nodes$title <- paste0(
     "<b>", nodes$full_title, "</b><br>",
     nodes$authors, "<br>",
     nodes$year
   )

   visNetwork(nodes, edges) %>%
     visInteraction(tooltipDelay = 200)
   ```

3. **Abbreviate common phrases:**
   ```r
   abbreviate_title <- function(title) {
     title <- gsub("A Survey of", "Survey:", title)
     title <- gsub("An Overview of", "Overview:", title)
     title <- gsub("Introduction to", "Intro:", title)
     title
   }
   ```

4. **Font size adaptation:**
   ```r
   visNetwork(nodes, edges) %>%
     visNodes(font = list(size = 14, multi = "html"))
   ```

**Phase to address:**
**Phase: Citation Discovery (06)** — Basic usability requirement. Add to initial graph implementation.

---

### Pitfall 12: Missing Citation Direction Indication

**What goes wrong:**
Citation graph shows edges but users can't tell direction. "Does A cite B or does B cite A?" Arrows too small to see. Graph navigation confusing. Users misinterpret citation relationships.

**Prevention:**
1. **Prominent arrows:**
   ```r
   visNetwork(nodes, edges) %>%
     visEdges(
       arrows = list(to = list(enabled = TRUE, scaleFactor = 1.5)),
       color = list(color = "#848484", highlight = "#FF0000")
     )
   ```

2. **Edge labels for clarity:**
   ```r
   edges$label <- "cites"  # A --cites--> B
   ```

3. **Color coding:**
   ```r
   edges$color <- ifelse(edges$type == "cites", "#00AA00", "#AA0000")
   ```

**Phase to address:**
**Phase: Citation Discovery (06)** — Initial graph implementation.

---

## Phase-Specific Warnings

Pitfalls likely to occur during specific phases of the roadmap.

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| DOI Storage (05) | Migration breaks existing databases | Versioned migrations with backfill script |
| Citation Discovery (06) | Exponential API explosion | Depth/breadth limits + batch fetching |
| Citation Discovery (06) | Graph cycles break layout | Cycle detection + fallback layouts |
| Citation Discovery (06) | visNetwork performance | Use proxy updates + precomputed layouts |
| Export Features (07) | UTF-8 encoding corruption | Explicit encoding + rbibutils |
| Export Features (07) | Tempdir permission errors | Always use tempdir(), test on restricted env |
| Export Features (07) | Citation key collisions | Unique key generation with suffix |
| Export Integration (07) | Cross-module state contamination | Session-scoped reactiveValues |
| Export Integration (07) | Navigation state loss | Persist state in reactiveValues + DB cache |

---

## Integration Gotchas

Common mistakes when integrating these features.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **OpenAlex Citation Fetching** | Loop through citations individually | Batch with OR: `filter=ids:W1\|W2\|W3...` (50 per request) |
| **DOI Storage** | Add column without backfill | Migration script: add column → mark PENDING → async backfill |
| **BibTeX Export** | System encoding for writeLines | Explicit UTF-8: `file(encoding = "UTF-8")` |
| **visNetwork Updates** | Re-render on every change | Use `visNetworkProxy()` for incremental updates |
| **Citation Graph Layout** | Assume DAG properties | Detect cycles, fallback to force-directed layout |
| **Cross-Module State** | Global reactiveValues | Session-scoped, pass to modules as parameters |
| **Download Handler** | Write to working directory | Use `tempdir()` for intermediate files |
| **Citation Keys** | Simple `author_year` | Add suffix for duplicates: `smith_2020a`, `smith_2020b` |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fetch all citations recursively | Works for recent papers, times out for seminal papers | Limit depth to 1-2 hops, cap breadth at 100/level | Papers with >50 citations |
| Re-render visNetwork on filter | Fast with 20 nodes, freezes with 200 | Use `visNetworkProxy` for updates | 100+ nodes |
| Store citation network in reactiveValues | Works initially, memory grows over session | Store in database, load on-demand | 500+ papers in network |
| Generate BibTeX on-the-fly | Fast for 10 papers, slow for 100 | Cache generated BibTeX, invalidate on update | 50+ papers |
| Synchronous DOI backfill | Works for 10 papers, blocks startup for 1000 | Async background job with progress | 100+ existing papers |
| Full paper metadata in graph nodes | Works for small graphs, bloats for large | Store minimal node data, load details on click | 200+ nodes |

---

## Security & Privacy Considerations

| Risk | Impact | Prevention |
|------|--------|------------|
| **Cross-user state leakage** | User A sees User B's papers | Session-scoped reactiveValues, test multi-session |
| **DOI enumeration** | Exposed paper collection via DOI list | Require authentication before export |
| **Temp file exposure** | BibTeX files left in /tmp readable by others | Use session-specific tempdir, clean up on exit |
| **Malicious DOI injection** | Crafted DOI breaks BibTeX parser | Validate DOI format before storage/export |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Citation network:** Renders graph, but no depth limit → exponential explosion
- [ ] **DOI migration:** Column added, but no backfill → all existing papers NULL
- [ ] **BibTeX export:** Generates file, but wrong encoding → garbled characters
- [ ] **Cross-module navigation:** Switches tabs, but loses state → must re-search
- [ ] **Citation keys:** Generated, but not unique → duplicate key errors
- [ ] **Graph layout:** Works locally, but cycles crash on real data → no fallback
- [ ] **Download handler:** Works locally, but fails deployed → permission errors
- [ ] **visNetwork updates:** Functional, but re-renders → performance issues

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Citation explosion | LOW | Kill API requests, show error, add depth limit |
| Graph cycles | LOW | Fallback to force-directed layout, log cycle info |
| Encoding corruption | LOW | Re-export with UTF-8, provide fixed file |
| State contamination | MEDIUM | Clear reactiveValues, restart sessions |
| Missing DOIs | MEDIUM | Run backfill script, notify users of progress |
| Duplicate citation keys | LOW | Regenerate with suffix algorithm, re-export |
| Permission errors | LOW | Update code to use tempdir, redeploy |
| visNetwork freeze | LOW | Reload page, reduce graph size, disable physics |

---

## Testing Checklist

Specific tests required to catch these pitfalls.

### Unit Tests
- [ ] DOI normalization: URL → bare DOI, uppercase → lowercase
- [ ] Citation key generation: Duplicates get suffix
- [ ] BibTeX escaping: Special characters → LaTeX sequences
- [ ] Graph cycle detection: Identify cyclic edges
- [ ] Encoding: UTF-8 roundtrip (write → read → verify)

### Integration Tests
- [ ] DOI migration: v1 database → v2 with backfill
- [ ] Citation fetch: Batch request returns all papers
- [ ] Cross-module navigation: Search → Discovery → back preserves state
- [ ] Export download: File written to tempdir, transferred correctly
- [ ] Multi-session: Two users don't see each other's state

### Performance Tests
- [ ] Citation graph: 200-node network renders in <5 seconds
- [ ] visNetwork proxy: Update 50 nodes without full re-render
- [ ] BibTeX export: 100 papers in <2 seconds
- [ ] DOI backfill: 1000 papers in <60 seconds (batched)

### Production Simulation Tests
- [ ] Deploy to shinyapps.io free tier, test download handler
- [ ] Restricted permissions: Run with read-only working directory
- [ ] Multi-user: Concurrent sessions don't contaminate state
- [ ] Large database: Test with 10k+ papers, 5k+ citations

---

## Sources

### Official Documentation (HIGH Confidence)
- [OpenAlex Rate Limits](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- [DuckDB ALTER TABLE](https://duckdb.org/docs/stable/sql/statements/alter_table)
- [DuckDB Storage Versioning](https://duckdb.org/docs/stable/internals/storage)
- [visNetwork with Shiny](https://datastorm-open.github.io/visNetwork/shiny.html)
- [Shiny Download Handlers](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html)
- [rbibutils Package](https://geobosh.github.io/rbibutils/)

### Academic Research (MEDIUM Confidence)
- [Citation Networks as DAGs](https://en.wikipedia.org/wiki/Citation_graph)
- [Transitive Reduction of Citation Networks](https://academic.oup.com/comnet/article-pdf/3/2/189/1071092/cnu039.pdf)

### Technical Blogs & Guides (MEDIUM Confidence)
- [Shiny Modules Communication Patterns](https://mastering-shiny.org/scaling-modules.html)
- [Communication Between Modules Anti-Patterns](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/)
- [Advanced SQLite Patterns for R Shiny](https://unconj.ca/blog/advanced-sqlite-patterns-for-r-and-shiny.html)
- [Generating Reports with Shiny](https://shiny.posit.co/r/articles/build/generating-reports/)
- [visNetwork Performance Tips](https://www.kaizen-r.com/2022/06/faster-graphs-in-r-igraph-vs-visnetwork/)
- [Shiny Reactive Performance](https://www.datanovia.com/learn/tools/shiny-apps/server-logic/reactive-values.html)

### Best Practices (MEDIUM Confidence)
- [Engineering Production-Grade Shiny Apps: Common Caveats](https://engineering-shiny.org/common-app-caveats.html)
- [BibTeX DOI Field Format](https://www.bibtex.com/f/doi-field/)
- [BibTeX UTF-8 Discussion](https://latex.org/forum/viewtopic.php?t=8673)
- [Zotero Encoding Best Practices](https://forums.zotero.org/discussion/24136/default-encoding-in-bibtex-export)

### GitHub Issues (LOW-MEDIUM Confidence)
- [DuckDB NOT NULL Constraint Limitation](https://github.com/duckdb/duckdb/issues/3248)
- [Shiny tempdir Windows Issue](https://github.com/rstudio/shiny/issues/2542)

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Citation explosion | Phase 06 (Citation Discovery) | Load test: seminal paper (500+ citations), verify depth limit |
| Graph cycles | Phase 06 (Citation Discovery) | Unit test: cyclic graph input, verify fallback layout |
| State contamination | Phase 07 (Export Integration) | Multi-session test: verify isolation |
| DOI migration | Phase 05 (Database Enhancement) | Test: v1 DB → v2 with 1000 papers, verify backfill |
| BibTeX encoding | Phase 07 (Export Features) | Roundtrip test: write → parse → verify UTF-8 |
| Tempdir permissions | Phase 07 (Export Features) | Deploy test: shinyapps.io download |
| Citation key collisions | Phase 07 (Export Features) | Unit test: duplicate author-year → unique keys |
| visNetwork performance | Phase 06 (Citation Discovery) | Performance test: 200-node graph, <5s render |
| Navigation state loss | Phase 07 (Export Integration) | UX test: search → discovery → back |
| DOI validation | Phase 05 (Database Enhancement) | Unit test: various formats → normalized |

---

*Pitfalls research for: Serapeum Citation Discovery & Export Features*
*Researched: 2026-02-12*
*Confidence: MEDIUM-HIGH (official docs + academic research + verified best practices)*
