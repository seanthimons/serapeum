# Phase 01: Seed Paper Discovery - Research

**Researched:** 2026-02-10
**Domain:** Academic paper citation discovery, OpenAlex API integration, R/Shiny reactive patterns
**Confidence:** HIGH

## Summary

Phase 1 implements seed paper discovery (users start from a known paper and discover related work through citation relationships) and fixes the critical abstract embedding bug. The phase has two distinct technical challenges: (1) fixing the ragnar/legacy embedding fallback chain to process abstracts correctly, and (2) building a DOI/title lookup UI that populates search notebooks with citation network results.

The embedding fix is well-understood (filtering logic excludes abstracts) and straightforward to implement. The discovery feature requires OpenAlex API integration for citation traversal and a producer-consumer Shiny module pattern to pass query parameters to the existing search notebook module.

**Primary recommendation:** Fix #55 first in its own plan (critical path, blocks testing). Then implement discovery as a separate module (mod_seed_discovery.R) that outputs to mod_search_notebook.R using reactive expressions for query parameters.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Latest | HTTP client for OpenAlex API | Already used in api_openalex.R, modern successor to httr |
| jsonlite | Latest | JSON parsing for API responses | Already used throughout codebase |
| ragnar | Latest | Semantic chunking and VSS+BM25 retrieval | Already integrated for document embedding, needs abstract support |
| DBI + duckdb | Latest | Database operations | Already used for all persistence |
| shiny + bslib | Latest | UI framework | Project standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shinyWidgets | Latest (optional) | Autocomplete input widgets | Only if building custom autocomplete; dqshiny may be simpler |
| dqshiny | Latest (optional) | Pre-built autocomplete_input() | Faster implementation than custom; consider for title search |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 | httr (old) | httr2 has better error handling and request composition, already in use |
| OpenAlex citation filters | Manual graph traversal | OpenAlex provides cites/cited_by filters - no need to build graph logic |
| Custom autocomplete | Shiny selectizeInput | selectizeInput doesn't handle async API calls well; autocomplete better for large datasets |

**Installation:**
```r
# Already installed:
# httr2, jsonlite, DBI, duckdb, shiny, bslib

# Optional (only if building autocomplete):
install.packages("dqshiny")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_seed_discovery.R    # NEW: Seed paper lookup + citation fetching
├── mod_search_notebook.R   # EXISTING: Consumer of discovery results
├── api_openalex.R          # EXTEND: Add get_paper_by_doi(), get_citations()
├── _ragnar.R               # MODIFY: Ensure abstracts are chunked correctly
└── db.R                    # NO CHANGES: Schema already supports abstracts
```

### Pattern 1: Producer-Consumer Module Communication

**What:** Discovery module returns reactive query parameters that search notebook consumes.

**When to use:** Anytime one module generates search criteria that another module executes.

**Example:**
```r
# Producer module (mod_seed_discovery.R)
mod_seed_discovery_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    # Returns reactive with discovery query params
    discovery_output <- reactive({
      req(input$fetch_citations)

      list(
        query = NULL,  # No text query for citation discovery
        filters = list(
          cites = input$seed_paper_id,  # OpenAlex filter
          from_year = 2000,
          to_year = 2026
        ),
        notebook_name = paste("Citations to:", input$seed_paper_title)
      )
    })

    discovery_output
  })
}

# Consumer usage (in app.R)
discovery <- mod_seed_discovery_server("seed", con, config)

# Pass to search notebook creation logic
observeEvent(discovery(), {
  params <- discovery()
  # Create search notebook with params$filters
})
```

**Source:** [Shiny module design patterns: Pass module inputs to other modules](https://itsalocke.com/blog/shiny-module-design-patterns-pass-module-inputs-to-other-modules/)

### Pattern 2: OpenAlex Citation Traversal

**What:** Use OpenAlex filter API to fetch citation relationships without building graph.

**When to use:** Discovering related papers from a seed paper.

**Example:**
```r
# Source: OpenAlex official docs
# Get papers that cite W2741809807
get_citations_to <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Filter: cites:{paper_id}
  # Returns: papers that cite the given work
  build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("cites:", paper_id),
      per_page = per_page
    ) |>
    req_perform() |>
    resp_body_json() |>
    (\(body) lapply(body$results, parse_openalex_work))()
}

# Get papers cited by W2741809807
get_citations_from <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Filter: cited_by:{paper_id}
  # Returns: papers cited by the given work (outgoing citations)
  build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("cited_by:", paper_id),
      per_page = per_page
    ) |>
    req_perform() |>
    resp_body_json() |>
    (\(body) lapply(body$results, parse_openalex_work))()
}

# Get algorithmically related papers
get_related_works <- function(paper_id, email, api_key = NULL, per_page = 25) {
  # Filter: related_to:{paper_id}
  # Returns: papers with most concepts in common
  build_openalex_request("works", email, api_key) |>
    req_url_query(
      filter = paste0("related_to:", paper_id),
      per_page = per_page
    ) |>
    req_perform() |>
    resp_body_json() |>
    (\(body) lapply(body$results, parse_openalex_work))()
}
```

**Sources:**
- [OpenAlex Filter works documentation](https://docs.openalex.org/api-entities/works/filter-works)
- [OpenAlex Get a single work](https://docs.openalex.org/api-entities/works/get-a-single-work)

### Pattern 3: DOI Lookup

**What:** Retrieve single paper by DOI before fetching citations.

**When to use:** User enters DOI or DOI-based URL as seed paper.

**Example:**
```r
# Source: OpenAlex official docs
# Already exists in api_openalex.R as get_paper()
# Supports DOI format: https://doi.org/10.7717/peerj.4375

lookup_seed_paper <- function(doi_or_url, email, api_key = NULL) {
  # Normalize input
  if (grepl("^10\\.", doi_or_url)) {
    # Plain DOI like "10.7717/peerj.4375"
    doi_or_url <- paste0("https://doi.org/", doi_or_url)
  }

  # get_paper() already handles full URL format
  get_paper(doi_or_url, email, api_key)
}
```

**Source:** [OpenAlex Get a single work](https://docs.openalex.org/api-entities/works/get-a-single-work)

### Anti-Patterns to Avoid

- **Don't expand mod_search_notebook.R:** Already 1,760 lines. Discovery UI must be separate module.
- **Don't build custom graph traversal:** OpenAlex provides citation filters - use them directly.
- **Don't assume polite pool still works:** As of Feb 13, 2026, API key is required (100k credits/day free).
- **Don't embed inline during citation fetch:** Follow existing pattern - import first, embed on button click.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Citation network graph | Manual BFS/DFS traversal, adjacency lists | OpenAlex `cites`, `cited_by`, `related_to` filters | OpenAlex pre-computes citation relationships; your traversal would miss papers not in your local DB and require complex sync logic |
| Autocomplete search | Custom debounce + API throttling + dropdown rendering | `dqshiny::autocomplete_input()` or Shiny's `selectizeInput` with server-side options | Autocomplete has tricky UX (keyboard nav, debouncing, race conditions); dqshiny handles this correctly |
| Text chunking for abstracts | String splitting by sentence or character count | Ragnar's semantic chunking (already integrated) | Ragnar preserves semantic boundaries and generates better embeddings; abstracts are short (1 chunk usually) but keeping consistency with documents avoids dual code paths |
| Embedding model switching | Custom embedding API wrappers for each provider | OpenRouter unified API (already in use) | OpenRouter provides single interface to multiple embedding models; switching models is config change, not code change |

**Key insight:** OpenAlex is a citation index, not just a search engine. Its graph traversal is the product - don't replicate it locally.

## Common Pitfalls

### Pitfall 1: Abstract Embedding Ignored by Ragnar Path

**What goes wrong:** Abstracts imported but never embedded; search returns no results for papers.

**Why it happens:** Embedding logic in mod_search_notebook.R (lines 1505-1547) queries abstracts and inserts to ragnar store correctly, but legacy fallback path (lines 1550-1576) filters `WHERE c.source_id IN (...)` from chunks table without checking source_type. Abstracts are created with source_type='abstract' but chunks may not be created if abstract is short.

**How to avoid:**
1. Always create chunk for abstract (line 1460 already does this)
2. Ensure ragnar path uses consistent origin format: `"abstract:{id}"` (line 1532 already correct)
3. Legacy fallback should query chunks by source_id AND verify chunk was created
4. Test both ragnar and legacy paths with same abstract data

**Warning signs:**
- "Embed Papers" button shows count but embedding completes instantly
- RAG chat says "no relevant context found" for papers known to be embedded
- Ragnar store exists but `search_chunks_hybrid()` returns empty results

**Source:** CONCERNS.md (lines 33-39), R/mod_search_notebook.R analysis

### Pitfall 2: Rate Limit Exhaustion on Citation Fetching

**What goes wrong:** Fetching 100 papers that cite a seed paper consumes 100 API credits; user hits daily limit quickly.

**Why it happens:** OpenAlex changed from polite pool (email-based, unlimited for non-commercial) to API key with 100k credits/day free tier (Feb 13, 2026). Each list request costs 1 credit. Citation queries with per_page=200 still only cost 1 credit, but multiple pages cost multiple credits.

**How to avoid:**
1. Default to per_page=25 (not 200) for citation fetching
2. Show estimated credit usage in UI: "This will fetch ~100 papers (1 credit)"
3. Add "Load More" pagination instead of auto-fetching all citations
4. Cache citation results in search notebook (already done via abstracts table)
5. Provide user setting for max citations to fetch (prevent runaway queries)

**Warning signs:**
- 429 HTTP errors from OpenAlex API
- "Daily credit limit exceeded" errors
- Slow citation fetching despite fast network

**Source:** [OpenAlex Rate limits and authentication](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)

### Pitfall 3: Title Autocomplete Performance Degradation

**What goes wrong:** Title autocomplete becomes unusable as user types (laggy, races, incorrect results).

**Why it happens:** Each keystroke triggers OpenAlex search query. Without debouncing, typing "machine learning" fires 17 queries. OpenAlex API latency is 200-500ms; queries arrive out of order; UI shows old results.

**How to avoid:**
1. Debounce text input (wait 300ms after last keystroke before querying)
2. Cancel in-flight requests when new query starts (httr2 supports this)
3. Show loading indicator during query
4. Limit results to 10 suggestions (per_page=10)
5. Only trigger autocomplete after 3+ characters typed
6. Consider using dqshiny::autocomplete_input which handles debouncing

**Warning signs:**
- Autocomplete shows results for "mach" after user has typed "machine learning"
- UI freezes while typing
- Multiple network requests visible in browser dev tools per keystroke

**Source:** [Shiny reactivity components](https://mastering-shiny.org/reactivity-components.html), httr2 documentation

### Pitfall 4: DOI Format Variations Breaking Lookup

**What goes wrong:** User enters "doi:10.1234/abcd" or "www.doi.org/10.1234/abcd" and lookup fails.

**Why it happens:** OpenAlex expects `https://doi.org/10.1234/abcd` format. Users paste from various sources with different formats:
- Plain DOI: `10.1234/abcd`
- DOI with prefix: `doi:10.1234/abcd`
- HTTP (not HTTPS): `http://doi.org/10.1234/abcd`
- dx.doi.org variant: `https://dx.doi.org/10.1234/abcd`

**How to avoid:**
1. Normalize input before API call:
   - Strip `doi:` prefix
   - Replace `http://` with `https://`
   - Replace `dx.doi.org` with `doi.org`
   - Prepend `https://doi.org/` if missing
2. Validate DOI format with regex: `^10\.\d{4,}/\S+$`
3. Show user-friendly error: "Invalid DOI format. Example: 10.1234/abcd"
4. Provide paste-from-clipboard button (many DOIs are copied from browser)

**Warning signs:**
- "Paper not found" for valid DOIs
- Different error messages for same DOI formatted differently
- Users complaining lookup doesn't work with DOIs from specific sources

**Source:** OpenAlex API documentation, DOI.org format spec

### Pitfall 5: Mixing Citation Types Confusing Users

**What goes wrong:** Users fetch "citations" and get unexpected papers - some newer than seed paper, some older.

**Why it happens:** Three citation relationships have different meanings:
- `cites:W123` = papers that cite W123 (incoming, usually newer)
- `cited_by:W123` = papers cited by W123 (outgoing, references, usually older)
- `related_to:W123` = algorithmically similar papers (not citations)

Users expect "citations" to mean "papers that cite this one" but may want references instead. UI must be clear about direction.

**How to avoid:**
1. Use clear labels:
   - "Papers citing this work" (incoming, cites filter)
   - "Papers cited by this work" (outgoing, cited_by filter)
   - "Related papers" (related_to filter)
2. Show counts from seed paper metadata before fetching
3. Provide radio buttons or tabs to choose citation direction
4. Default to incoming citations (most common discovery use case)
5. Show publication year distribution in results to verify direction

**Warning signs:**
- User expects recent papers, gets old papers (or vice versa)
- Citation counts don't match OpenAlex metadata for seed paper
- Users asking "why are these papers not citing my seed paper?"

**Source:** [OpenAlex Filter works documentation](https://docs.openalex.org/api-entities/works/filter-works), OpenAlex Work object schema

## Code Examples

Verified patterns from official sources and existing codebase:

### Fetching Citations with OpenAlex Filters

```r
# Source: OpenAlex official docs + existing api_openalex.R pattern

#' Get papers that cite a given work (incoming citations)
#' @param paper_id OpenAlex ID (e.g., "W2741809807")
#' @param email User email for API
#' @param api_key OpenAlex API key (required as of Feb 2026)
#' @param per_page Results per page (default 25, max 200)
#' @return List of parsed works
get_citing_papers <- function(paper_id, email, api_key, per_page = 25) {
  # Ensure paper_id has W prefix
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key)
  req <- req |> req_url_query(
    filter = paste0("cites:", paper_id),
    per_page = per_page
  )

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenAlex API error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

  lapply(body$results, parse_openalex_work)
}

#' Get papers cited by a given work (outgoing citations/references)
#' @param paper_id OpenAlex ID
#' @param email User email
#' @param api_key OpenAlex API key
#' @param per_page Results per page
#' @return List of parsed works
get_cited_papers <- function(paper_id, email, api_key, per_page = 25) {
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key)
  req <- req |> req_url_query(
    filter = paste0("cited_by:", paper_id),
    per_page = per_page
  )

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenAlex API error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

  lapply(body$results, parse_openalex_work)
}

#' Get algorithmically related papers
#' @param paper_id OpenAlex ID
#' @param email User email
#' @param api_key OpenAlex API key
#' @param per_page Results per page
#' @return List of parsed works
get_related_papers <- function(paper_id, email, api_key, per_page = 25) {
  if (!grepl("^W", paper_id)) {
    paper_id <- paste0("W", paper_id)
  }

  req <- build_openalex_request("works", email, api_key)
  req <- req |> req_url_query(
    filter = paste0("related_to:", paper_id),
    per_page = per_page
  )

  resp <- tryCatch({
    req_perform(req)
  }, error = function(e) {
    stop("OpenAlex API error: ", e$message)
  })

  body <- resp_body_json(resp)

  if (is.null(body$results)) {
    return(list())
  }

  lapply(body$results, parse_openalex_work)
}
```

### DOI Normalization for Lookup

```r
# Source: OpenAlex docs + DOI.org format specification

#' Normalize DOI input to OpenAlex format
#' @param input User input (DOI, URL, or DOI with prefix)
#' @return Normalized DOI URL or NULL if invalid
normalize_doi <- function(input) {
  if (is.null(input) || nchar(trimws(input)) == 0) {
    return(NULL)
  }

  input <- trimws(input)

  # Remove doi: prefix
  input <- sub("^doi:", "", input, ignore.case = TRUE)

  # Extract DOI from URL if present
  if (grepl("doi\\.org/", input)) {
    input <- sub("^.*/doi\\.org/", "", input)
  }
  if (grepl("dx\\.doi\\.org/", input)) {
    input <- sub("^.*/dx\\.doi\\.org/", "", input)
  }

  # Validate DOI format (starts with 10.xxxx)
  if (!grepl("^10\\.\\d{4,}/\\S+$", input)) {
    return(NULL)
  }

  # Return OpenAlex-compatible URL
  paste0("https://doi.org/", input)
}

# Usage:
# normalize_doi("10.7717/peerj.4375")
#   -> "https://doi.org/10.7717/peerj.4375"
# normalize_doi("doi:10.7717/peerj.4375")
#   -> "https://doi.org/10.7717/peerj.4375"
# normalize_doi("http://dx.doi.org/10.7717/peerj.4375")
#   -> "https://doi.org/10.7717/peerj.4375"
```

### Producer Module Pattern

```r
# Source: Shiny module communication patterns + existing mod_search_notebook.R

# mod_seed_discovery.R
mod_seed_discovery_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Start from a Paper"),
    card_body(
      textInput(ns("doi_input"), "Enter DOI or paste DOI URL",
                placeholder = "10.1234/abcd or https://doi.org/10.1234/abcd"),
      actionButton(ns("lookup_doi"), "Look Up Paper", class = "btn-primary"),
      hr(),
      uiOutput(ns("paper_preview")),
      uiOutput(ns("citation_controls"))
    )
  )
}

mod_seed_discovery_server <- function(id, con, config) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store seed paper
    seed_paper <- reactiveVal(NULL)

    # Store discovery request
    discovery_request <- reactiveVal(NULL)

    # Look up paper by DOI
    observeEvent(input$lookup_doi, {
      req(input$doi_input)

      doi <- normalize_doi(input$doi_input)
      if (is.null(doi)) {
        showNotification("Invalid DOI format", type = "error")
        return()
      }

      cfg <- config()
      email <- get_setting(cfg, "openalex", "email")
      api_key <- get_setting(cfg, "openalex", "api_key")

      paper <- tryCatch({
        get_paper(doi, email, api_key)
      }, error = function(e) {
        showNotification(paste("Paper not found:", e$message), type = "error")
        NULL
      })

      if (!is.null(paper)) {
        seed_paper(paper)
      }
    })

    # Show paper preview
    output$paper_preview <- renderUI({
      paper <- seed_paper()
      req(paper)

      tagList(
        h5(paper$title),
        p(class = "text-muted", paste(paper$authors[[1]][1:3], collapse = ", "),
          if (length(paper$authors[[1]]) > 3) " et al." else "",
          " (", paper$year, ")"),
        p(class = "small", substr(paper$abstract, 1, 200), "...")
      )
    })

    # Show citation controls
    output$citation_controls <- renderUI({
      paper <- seed_paper()
      req(paper)

      tagList(
        h6("Fetch Related Papers:"),
        p(class = "small text-muted",
          "Cited by: ", paper$cited_by_count, " papers | ",
          "References: ", paper$referenced_works_count, " papers"),
        radioButtons(ns("citation_type"), NULL,
                     choices = c(
                       "Papers citing this work" = "cites",
                       "Papers cited by this work" = "cited_by",
                       "Related papers" = "related_to"
                     ),
                     selected = "cites"),
        actionButton(ns("fetch_citations"), "Fetch Papers",
                     class = "btn-success")
      )
    })

    # Create discovery request when user clicks fetch
    observeEvent(input$fetch_citations, {
      paper <- seed_paper()
      req(paper, input$citation_type)

      discovery_request(list(
        seed_paper = paper,
        citation_type = input$citation_type,
        notebook_name = paste(
          switch(input$citation_type,
                 cites = "Citing:",
                 cited_by = "Cited by:",
                 related_to = "Related to:"),
          paper$title
        )
      ))
    })

    # Return discovery request as reactive for consumer
    return(discovery_request)
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Polite pool with email parameter | API key required (free, 100k credits/day) | Feb 13, 2026 | Must update api_openalex.R to require API key; email parameter deprecated |
| Manual embedding for each chunk | Ragnar VSS+BM25 hybrid retrieval | Jan 2026 (already integrated) | Abstracts must use ragnar path for consistency; legacy path is fallback only |
| selectizeInput for autocomplete | dqshiny::autocomplete_input with debouncing | 2024-2025 (best practice) | Better UX for API-backed autocomplete; handles race conditions |
| Fixed chunk size (e.g., 500 chars) | Semantic chunking with 10-20% overlap | 2025 (RAG best practice) | Abstracts are short (usually 1 chunk) but semantic boundaries improve retrieval quality |

**Deprecated/outdated:**
- `mailto` parameter in OpenAlex API: Replaced by required `api_key` header (Feb 2026)
- Polite pool tier: No longer exists; all users on API key tier with rate limits
- httr package: Superseded by httr2 (better error handling, request composition)

## Open Questions

1. **Should title autocomplete query OpenAlex or local cache?**
   - What we know: OpenAlex supports title.search filter, but each query costs 1 API credit
   - What's unclear: How to balance responsiveness vs API usage; whether local cache of titles makes sense
   - Recommendation: Start with OpenAlex API (simpler); monitor usage; if heavy use, add local title cache table populated from previous searches

2. **How many citations to fetch by default?**
   - What we know: Some papers have 10k+ citing papers; fetching all would exhaust API credits and create massive notebooks
   - What's unclear: What default limit balances discovery value vs performance
   - Recommendation: Default to per_page=25 (1 API credit); show "Load More" button; cap at 200 total; let user configure max in settings

3. **Should related_to filter use different UI than citation filters?**
   - What we know: related_to is algorithmic (not citation-based); may confuse users expecting citation network
   - What's unclear: Whether to separate related_to into different discovery mode or combine with citations
   - Recommendation: Combine in same UI with clear labels; most users won't distinguish; separate later if user feedback indicates confusion

## Sources

### Primary (HIGH confidence)
- [OpenAlex Rate limits and authentication](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) - API key requirement, credit limits
- [OpenAlex Filter works](https://docs.openalex.org/api-entities/works/filter-works) - Citation filters (cites, cited_by, related_to)
- [OpenAlex Get a single work](https://docs.openalex.org/api-entities/works/get-a-single-work) - DOI lookup format
- Existing codebase: R/api_openalex.R, R/mod_search_notebook.R, R/_ragnar.R, R/db.R - Current patterns

### Secondary (MEDIUM confidence)
- [Shiny module design patterns: Pass module inputs to other modules](https://itsalocke.com/blog/shiny-module-design-patterns-pass-module-inputs-to-other-modules/) - Producer-consumer pattern
- [dqshiny autocomplete_input](https://rdrr.io/cran/dqshiny/man/autocomplete_input.html) - Autocomplete widget
- [Chunking for RAG best practices | Unstructured](https://unstructured.io/blog/chunking-for-rag-best-practices) - 10-20% overlap recommendation
- [Best Chunking Strategies for RAG in 2025](https://www.firecrawl.dev/blog/best-chunking-strategies-rag-2025) - Semantic chunking > fixed size

### Tertiary (LOW confidence)
- WebSearch findings about autocomplete and reactive patterns - Verified against official Shiny docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use except optional dqshiny
- Architecture: HIGH - Producer-consumer pattern is standard Shiny practice; OpenAlex API documented
- Pitfalls: HIGH - Embedding bug well-documented in CONCERNS.md; rate limits verified in official docs
- Code examples: HIGH - Based on existing codebase patterns and official OpenAlex docs

**Research date:** 2026-02-10
**Valid until:** 2026-03-15 (30 days - OpenAlex API stable, Shiny patterns mature)
