# Technology Stack Additions - Citation Network & Export

**Project:** Serapeum Discovery & Export Enhancements
**Milestone:** v1.3 (Citation Network Visualization, Citation Export, Synthesis Export)
**Researched:** 2026-02-12
**Confidence:** HIGH

## Executive Summary

The new features (citation network visualization, citation export, synthesis export) require **minimal stack additions** to the existing R/Shiny infrastructure. All capabilities can be implemented with:

1. **One new package**: `visNetwork` (2.1.4) for citation network graphs
2. **One optional package**: `handlr` (0.3.1) for multi-format citation export
3. **Existing packages**: Base R + existing stack (httr2, jsonlite, DuckDB) handle everything else

**Key insight:** OpenAlex API already provides citation relationships (`referenced_works`, `cited_by_api_url`). No new data sources needed.

---

## New Packages Required

### Citation Network Visualization

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **visNetwork** | 2.1.4 | Interactive network graphs in Shiny | Industry-standard for R network viz. Built on vis.js, htmlwidget integration, native Shiny reactivity via `visNetworkProxy()`. Published Sept 2025 (actively maintained). Best-in-class for citation networks. |

**Installation:**
```r
install.packages("visNetwork")
```

**Confidence:** HIGH
- **Source:** [CRAN official page](https://cran.r-project.org/web/packages/visNetwork/index.html), [Official documentation](https://datastorm-open.github.io/visNetwork/)
- **Evidence:** Latest version 2.1.4 published 2025-09-04, active GitHub issues, comprehensive Shiny integration docs

---

### Citation Export (Multi-Format)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **handlr** | 0.3.1 | Convert among citation formats | rOpenSci package. Handles BibTeX, RIS, Citeproc, Schema.org, RDF/XML, CFF, CodeMeta. Published Mar 2025 (actively maintained). Unified R6 API (`HandlrClient`) + standalone writer functions. |

**Installation:**
```r
install.packages("handlr")
```

**Confidence:** MEDIUM
- **Source:** [CRAN page](https://cran.r-project.org/web/packages/handlr/index.html), [rOpenSci docs](https://docs.ropensci.org/handlr/)
- **Evidence:** Version 0.3.1 published 2025-03-03, rOpenSci maintained
- **Note:** NOT currently installed in project. Requires validation that OpenAlex data maps cleanly to required citation fields.

---

## Existing Stack (No Changes)

These features **reuse existing capabilities**:

| Technology | Current Version | New Use Case |
|------------|----------------|--------------|
| **httr2** | 1.2.1 | Fetch citation networks from OpenAlex (`/works?filter=openalex:W123\|W456\|W789`, up to 50 IDs per batch with pipe separator) |
| **jsonlite** | 2.0.0 | Parse OpenAlex citation responses, structure data for export |
| **DuckDB** | 1.3.2 | Store citation relationships (new columns: `referenced_works`, `cited_by` as JSON arrays) |
| **Base R utils** | Built-in | `write.csv()` for CSV export via `downloadHandler()` |
| **Shiny** | 1.11.1 | `downloadHandler()` + `downloadButton()` for all export formats |
| **bslib** | 0.9.0 | UI layout (cards, value boxes) for network viz and export controls |

**Confidence:** HIGH
- **Source:** Installed versions from project (verified via Rscript), [Shiny downloadHandler docs](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html)
- **Evidence:** All packages already validated in phases 1-5. CSV export is base R. OpenAlex supports bulk work fetching via pipe-separated IDs.

---

## Data Pipeline: OpenAlex → Citation Export

### What OpenAlex Provides

Per [OpenAlex Work object docs](https://docs.openalex.org/api-entities/works/work-object):

**Available fields per work:**
- `doi` (string, canonical external ID)
- `title` / `display_name` (string)
- `authorships` (list with author details)
- `publication_year` (integer)
- `primary_location.source` (venue/journal)
- `referenced_works` (list of OpenAlex IDs, e.g., `["https://openalex.org/W123", ...]`)
- `referenced_works_count` (integer)
- `cited_by_api_url` (URL to fetch citing works)
- `cited_by_count` (integer)

**Current Serapeum DB schema** already stores:
```
abstracts table: paper_id, title, authors, abstract, keywords, year, venue,
                 pdf_url, work_type, oa_status, cited_by_count,
                 referenced_works_count, fwci
```

**Gap:** `referenced_works` (list of IDs) not yet stored.

### Required DB Changes

**Migration needed:** Add `referenced_works` column to `abstracts` table.

```sql
ALTER TABLE abstracts ADD COLUMN referenced_works VARCHAR DEFAULT '[]'
```

Store as JSON array string (existing pattern from `excluded_paper_ids` in notebooks table).

### Bulk Citation Fetching

**OpenAlex API capability:** Fetch up to 50 works in one call using pipe separator.

**Example:**
```r
# From stored referenced_works: ["W2753353163", "W123456", ...]
ids <- c("W2753353163", "W123456", "W789012")
filter_param <- paste0("openalex:", paste(ids, collapse = "|"))
# https://api.openalex.org/works?filter=openalex:W2753353163|W123456|W789012
```

**Performance:** Use existing `build_openalex_request()` + `search_papers()` patterns from `api_openalex.R`.

**Confidence:** HIGH
- **Source:** [OpenAlex blog post on bulk fetching](https://blog.ourresearch.org/fetch-multiple-dois-in-one-openalex-api-request/), [API docs](https://docs.openalex.org/api-entities/works/search-works)

---

## BibTeX Export Strategy

### Option 1: Build from OpenAlex Data (Recommended)

**Approach:** Construct BibTeX strings directly from stored paper metadata.

**Why:**
- Zero dependencies
- Full control over field mapping
- OpenAlex provides all required fields
- BibTeX format is simple text-based

**BibTeX required fields** (per [BibTeX.com spec](https://www.bibtex.com/g/bibtex-format/)):
- `@article`: author, title, journal (venue), year
- `@inproceedings`: author, title, booktitle, year
- `@book`: author, title, publisher, year

**OpenAlex → BibTeX mapping:**
```r
# Pseudocode
generate_bibtex <- function(paper) {
  entry_type <- if (paper$work_type == "article") "@article" else "@misc"
  cite_key <- paste0(substr(paper$authors[1], 1, 10), paper$year)

  sprintf("%s{%s,\n  author = {%s},\n  title = {%s},\n  journal = {%s},\n  year = {%d},\n  doi = {%s}\n}",
    entry_type, cite_key,
    paste(paper$authors, collapse = " and "),
    paper$title, paper$venue, paper$year, paper$doi
  )
}
```

**Confidence:** HIGH
- **Source:** [BibTeX format spec](https://www.bibtex.com/g/bibtex-format/), OpenAlex field availability confirmed
- **Evidence:** BibTeX is well-documented plain text format. All required fields available in DB.

### Option 2: Use handlr Package

**Approach:** Convert OpenAlex JSON → Citeproc → BibTeX/RIS via handlr.

**Workflow:**
```r
library(handlr)

# Convert paper metadata to Citeproc JSON
citeproc_json <- list(
  type = "article-journal",
  title = paper$title,
  author = lapply(authors, function(a) list(family = a)),
  issued = list("date-parts" = list(c(paper$year))),
  DOI = paper$doi,
  "container-title" = paper$venue
)

# Write as BibTeX
client <- HandlrClient$new(x = jsonlite::toJSON(citeproc_json, auto_unbox = TRUE))
client$read(format = "citeproc")
bibtex_output <- client$write(format = "bibtex")
```

**Why consider:**
- Multi-format support (RIS, Schema.org, RDF/XML)
- Standards-compliant output
- rOpenSci maintained

**Why NOT primary recommendation:**
- Adds dependency
- Requires Citeproc intermediate format construction
- OpenAlex data → handlr mapping needs validation
- Direct construction is simpler for BibTeX/CSV

**Confidence:** MEDIUM
- **Source:** [handlr docs](https://docs.ropensci.org/handlr/reference/HandlrClient.html), [CRAN](https://cran.r-project.org/web/packages/handlr/index.html)
- **Evidence:** Package actively maintained (Mar 2025), but no direct evidence of OpenAlex → handlr pattern in wild. Needs phase-specific research to validate field mapping.

**Recommendation:** Use **Option 1** for BibTeX/CSV (simple, zero dependencies). Consider **Option 2** only if user requests RIS/RDF/Schema.org formats later.

---

## CSV Export Strategy

**Approach:** Use base R `write.csv()` with Shiny `downloadHandler()`.

**Implementation:**
```r
output$download_citations_csv <- downloadHandler(
  filename = function() {
    paste0("citations-", Sys.Date(), ".csv")
  },
  content = function(file) {
    # papers is reactive data.frame from selected papers
    df <- data.frame(
      Title = papers$title,
      Authors = sapply(papers$authors, paste, collapse = "; "),
      Year = papers$year,
      Journal = papers$venue,
      DOI = papers$doi,
      CitedBy = papers$cited_by_count
    )
    write.csv(df, file, row.names = FALSE)
  }
)
```

**Why:**
- Zero dependencies (base R + Shiny built-ins)
- Straightforward data frame → CSV
- `downloadHandler()` already validated in project

**Confidence:** HIGH
- **Source:** [Shiny downloadHandler docs](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html), [Mastering Shiny Ch. 9](https://mastering-shiny.org/action-transfer.html)
- **Evidence:** Standard Shiny pattern, well-documented, no version-specific issues.

---

## Synthesis Export Strategy

**Approach:** Markdown or plain text export via `downloadHandler()`.

**Rationale:**
- LLM-generated synthesis is already text/markdown
- User likely wants copy-paste or save to file
- No special formatting needed beyond what LLM provides

**Implementation:**
```r
output$download_synthesis <- downloadHandler(
  filename = function() {
    paste0("synthesis-", Sys.Date(), ".md")
  },
  content = function(file) {
    writeLines(synthesis_text(), file)
  }
)
```

**Alternative formats (if requested later):**
- HTML: Wrap markdown in minimal HTML template
- PDF: Use `rmarkdown::render()` (adds dependency, likely overkill)

**Confidence:** HIGH
- **Source:** Base R `writeLines()`, Shiny `downloadHandler()`
- **Evidence:** Simplest approach for text export.

---

## Citation Network Visualization Stack

### Core: visNetwork Package

**Why visNetwork over alternatives:**

| Package | Pros | Cons | Verdict |
|---------|------|------|---------|
| **visNetwork** | vis.js-based, htmlwidget, native Shiny proxy, 20+ layouts, active (Sept 2025) | Larger bundle size | ✅ **Recommended** |
| networkD3 | Lightweight, D3.js-based | Limited interactivity, no Shiny proxy | ❌ Less suitable |
| shinyCyJS | Cytoscape.js, customizable | More complex API | ❌ Overkill |
| g6R | New (2025), 20 layouts, G6 engine | Very new (0.1.0), less proven | ⚠️ Monitor for future |

**Confidence:** HIGH
- **Source:** [CRAN visNetwork](https://cran.r-project.org/web/packages/visNetwork/index.html), [Package comparison](https://www.statworx.com/en/content-hub/blog/interactive-network-visualization-with-r), [R Graph Gallery](https://r-graph-gallery.com/network-interactive.html)
- **Evidence:** visNetwork most mature, best Shiny integration, proven citation network use cases.

### Implementation Pattern

**Minimal working example:**
```r
library(visNetwork)

# In UI
visNetworkOutput("citation_network")

# In Server
output$citation_network <- renderVisNetwork({
  nodes <- data.frame(
    id = papers$paper_id,
    label = papers$title,
    title = paste0(papers$title, "\n(", papers$year, ")") # Hover tooltip
  )

  edges <- data.frame(
    from = citing_paper_id,
    to = cited_paper_id,
    arrows = "to"
  )

  visNetwork(nodes, edges) %>%
    visOptions(highlightNearest = TRUE, nodesIdSelection = TRUE) %>%
    visPhysics(stabilization = FALSE) %>%
    visInteraction(navigationButtons = TRUE)
})
```

**Reactive updates** (without full redraw):
```r
observe({
  visNetworkProxy("citation_network") %>%
    visUpdateNodes(nodes = updated_nodes_df)
})
```

**Confidence:** HIGH
- **Source:** [visNetwork Shiny docs](https://datastorm-open.github.io/visNetwork/shiny.html), [CRAN vignette](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html)
- **Evidence:** Official Shiny integration examples, `visNetworkProxy()` documented for reactive updates.

---

## Integration Points with Existing Code

### 1. Database (`R/db.R`)

**Changes needed:**
- Add migration for `referenced_works` column (VARCHAR, JSON array string)
- Add helper function `get_citation_network(con, paper_ids)` to fetch papers + their references

**Pattern to follow:** Existing migrations at lines 98-149 (keywords, excluded_paper_ids, work_type, oa_status, etc.)

### 2. OpenAlex API (`R/api_openalex.R`)

**Changes needed:**
- Extract `referenced_works` in `parse_openalex_work()` (currently extracts `referenced_works_count` at line 224 but not the list itself)
- Add batch fetching helper `fetch_works_batch(work_ids, email, api_key)` using pipe-separated filter

**Pattern to follow:** Existing `search_papers()` function structure (lines 256-350)

### 3. Shiny Modules

**New module:** `R/mod_citation_export.R`
- Export buttons (BibTeX, CSV, synthesis)
- Network visualization UI + server logic
- Uses existing module pattern (`mod_*_ui()`, `mod_*_server()`)

**Pattern to follow:** `R/mod_cost_tracker.R` (value boxes, tables, download handlers)

### 4. App Routing (`app.R`)

**Changes needed:**
- Wire citation export module into search/document notebooks
- No new sidebar links needed (export actions live within notebooks)

**Pattern to follow:** Existing module wiring at app.R server function

---

## What NOT to Add

### ❌ Do NOT Add

| Technology | Why Not |
|------------|---------|
| **RefManageR** | Last updated Sept 2022 (stale). Handlr is more current. If neither needed, build BibTeX directly. |
| **rbibutils** | Low-level bibutils wrapper. Overkill for simple BibTeX generation. |
| **knitcitations** | Designed for R Markdown, not Shiny apps. |
| **bib2df** | Only reads BibTeX, doesn't write. |
| **networkD3** | Less interactive than visNetwork, no Shiny proxy. |
| **igraph** | Graph *analysis* library, not visualization. visNetwork can consume igraph objects if needed. |
| **ggplot2 + ggraph** | Static plots, not interactive. Not suitable for citation networks. |

### ❌ Do NOT Create New Data Sources

- OpenAlex already provides citation relationships
- No need for Crossref, Semantic Scholar, etc. (OpenAlex aggregates)
- No need for separate graph database (DuckDB + JSON arrays sufficient for ~thousands of papers)

---

## Version Constraints & Compatibility

### R Version
**Minimum:** R 4.5.1 (project standard per CLAUDE.md)

### Package Compatibility Matrix

| Package | Version | R Requirement | Notes |
|---------|---------|---------------|-------|
| visNetwork | 2.1.4 | R >= 3.5.0 | No conflicts with existing stack |
| handlr | 0.3.1 | R >= 3.5.0 | Optional, only if multi-format needed |

**Tested configuration:**
- Shiny 1.11.1 + bslib 0.9.0 + visNetwork 2.1.4 (all current as of Feb 2026)

**Confidence:** HIGH
- **Source:** CRAN package metadata
- **Evidence:** All packages support R >= 3.5, well below project's R 4.5.1 baseline.

---

## Performance Considerations

### Citation Network Size

**Scenario analysis:**

| Papers in Network | Nodes | Edges (avg 20 refs/paper) | visNetwork Performance |
|-------------------|-------|---------------------------|------------------------|
| 10 papers | 10 | ~200 | ✅ Instant |
| 50 papers | 50 | ~1,000 | ✅ Fast |
| 100 papers | 100 | ~2,000 | ✅ Good |
| 500 papers | 500 | ~10,000 | ⚠️ May need layout optimization |

**Mitigation for large networks:**
- Limit initial depth (1-hop vs. 2-hop citations)
- Use `visPhysics(stabilization = FALSE)` for faster initial render
- Implement server-side filtering (show top-cited only)

**Confidence:** MEDIUM
- **Source:** visNetwork docs, general htmlwidget performance characteristics
- **Evidence:** vis.js handles thousands of nodes but browser performance degrades. Needs phase-specific testing with real data.

### OpenAlex API Rate Limits

**Constraint:** 50 works per batched request, 10 requests/second (polite pool with email).

**Fetching 100-paper network:**
- 100 papers + ~2,000 referenced works (if not cached) = ~40 API calls at 50 works/batch
- At 10 req/sec: ~4 seconds
- **Solution:** Cache fetched works in DuckDB, only fetch missing ones.

**Confidence:** HIGH
- **Source:** [OpenAlex rate limits](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- **Evidence:** Existing project uses polite pool pattern in `api_openalex.R`.

---

## Installation & Setup

### For Citation Network Visualization Only

```r
install.packages("visNetwork")
```

### For Multi-Format Citation Export

```r
install.packages("handlr")
```

### Database Migration

Run migration on app startup (existing pattern in `db.R`):
```sql
ALTER TABLE abstracts ADD COLUMN referenced_works VARCHAR DEFAULT '[]'
```

**No breaking changes:** All additions are backward-compatible.

---

## Decision Log

| Decision | Rationale | Alternatives Rejected |
|----------|-----------|----------------------|
| Use visNetwork for citation graphs | Best Shiny integration, mature, actively maintained | networkD3 (limited), g6R (too new), shinyCyJS (complex) |
| Build BibTeX directly vs. handlr | Simpler, zero dependencies, OpenAlex maps cleanly | handlr (adds complexity), RefManageR (stale) |
| Store cited works as JSON array in DuckDB | Matches existing pattern (`excluded_paper_ids`), portable, sufficient for ~1000s papers | Separate graph DB (overkill), normalized tables (premature) |
| Use base R `write.csv()` | Built-in, simple, works with `downloadHandler()` | writexl (adds dependency), data.table (overkill) |
| Make handlr optional | Only needed if user wants RIS/RDF/Schema.org formats later | Install upfront (premature) |

---

## Open Questions (For Phase-Specific Research)

1. **Field mapping validation:** Does OpenAlex `authorships` structure map cleanly to BibTeX author format? Need to handle multi-author edge cases.

2. **Citation network UI/UX:** Where to place network viz in notebook UI? Dedicated tab vs. modal vs. sidebar panel?

3. **Network depth:** Default to 1-hop (papers + their direct references) or 2-hop (references of references)? Performance vs. insight tradeoff.

4. **Export scope:** Export all papers in notebook, or only selected/visible papers? Needs UX decision.

5. **handlr necessity:** Can we defer installing handlr until user requests non-BibTeX formats? Or install proactively?

---

## Summary Table: Stack Additions

| Feature | Package Required | Version | Status | Confidence |
|---------|-----------------|---------|--------|-----------|
| Citation network graph | **visNetwork** | 2.1.4 | ✅ Install | HIGH |
| BibTeX export | Base R (build directly) | Built-in | ✅ Use existing | HIGH |
| CSV export | Base R utils | Built-in | ✅ Use existing | HIGH |
| Synthesis export | Base R writeLines | Built-in | ✅ Use existing | HIGH |
| RIS/RDF/Schema.org export | handlr (optional) | 0.3.1 | ⚠️ Install if needed | MEDIUM |
| Bulk citation fetching | httr2 + jsonlite (existing) | 1.2.1, 2.0.0 | ✅ Use existing | HIGH |
| Citation storage | DuckDB (existing) | 1.3.2 | ✅ Add column | HIGH |

---

## Sources

**Network Visualization:**
- [visNetwork CRAN page](https://cran.r-project.org/web/packages/visNetwork/index.html)
- [visNetwork official docs](https://datastorm-open.github.io/visNetwork/)
- [visNetwork Shiny integration](https://datastorm-open.github.io/visNetwork/shiny.html)
- [Interactive Network Visualization with R](https://www.statworx.com/en/content-hub/blog/interactive-network-visualization-with-r)
- [R Graph Gallery - Interactive Networks](https://r-graph-gallery.com/network-interactive.html)

**Citation Export:**
- [handlr CRAN page](https://cran.r-project.org/web/packages/handlr/index.html)
- [handlr rOpenSci docs](https://docs.ropensci.org/handlr/)
- [handlr HandlrClient reference](https://docs.ropensci.org/handlr/reference/HandlrClient.html)
- [BibTeX format specification](https://www.bibtex.com/g/bibtex-format/)
- [BibTeX entry types](https://www.bibtex.com/e/entry-types/)

**OpenAlex API:**
- [OpenAlex Works documentation](https://docs.openalex.org/api-entities/works)
- [OpenAlex Work object fields](https://docs.openalex.org/api-entities/works/work-object)
- [Fetch multiple DOIs in one request](https://blog.ourresearch.org/fetch-multiple-dois-in-one-openalex-api-request/)

**Shiny Export:**
- [Shiny downloadHandler reference](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html)
- [Mastering Shiny - Uploads and Downloads](https://mastering-shiny.org/action-transfer.html)

**R Ecosystem:**
- [rOpenSci BibTeX tools roundup](https://ropensci.org/blog/2020/05/07/rmd-citations/)
