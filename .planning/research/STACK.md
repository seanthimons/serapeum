# Technology Stack for Discovery Features

**Project:** Serapeum Discovery Milestone
**Researched:** 2026-02-10
**Confidence:** HIGH

## Recommended Stack

### OpenAlex API Endpoints

| Endpoint | Version | Purpose | Why Recommended |
|----------|---------|---------|-----------------|
| `/works` with `cites` filter | Current | Seed paper → cited by (incoming citations) | Official filter returning works that cite a given paper. Use `filter=cites:W2741809807` for discovery workflows. |
| `/works` with `cited_by` filter | Current | Seed paper → references (outgoing citations) | Official filter returning works referenced by a given paper. Enables backward citation traversal. |
| `/works` with `related_to` filter | Current | Seed paper → semantically similar works | Uses OpenAlex's algorithmic relatedness (recent papers with most concepts in common). Best for topic exploration. |
| `/topics` entity endpoint | Current | Browse 4,500 topics hierarchically | Provides 4-level hierarchy (domain → field → subfield → topic) with IDs and display names for navigation. |
| `/topics/{id}` with works filter | Current | Topic → papers in that topic | Filter works by `primary_topic.id` or `topics.id` to explore topic content. |
| `/works` autocomplete | Current | Type-ahead search interface | Returns titles, author hints, citation counts, DOI links. Perfect for seed paper search UI. |

**Confidence:** HIGH - All endpoints verified from [OpenAlex official documentation](https://docs.openalex.org/api-entities/works).

### Key OpenAlex Filters for Discovery

| Filter | Purpose | Syntax Example | When to Use |
|--------|---------|----------------|-------------|
| `cites:` | Find papers citing a work | `filter=cites:W2741809807` | Forward citation discovery (who cites this?) |
| `cited_by:` | Find papers cited by a work | `filter=cited_by:W2766808518` | Backward citation discovery (what does this cite?) |
| `related_to:` | Find semantically related papers | `filter=related_to:W2486144666` | Topic exploration without citations |
| `primary_topic.id:` | Filter by primary topic | `filter=primary_topic.id:T10100` | Browsing a specific topic |
| `topics.id:` | Filter by any assigned topic | `filter=topics.id:T10100` | Broader topic coverage |
| `primary_topic.domain.id:` | Filter by research domain | `filter=primary_topic.domain.id:D1` | High-level topic browsing |
| `primary_topic.field.id:` | Filter by research field | `filter=primary_topic.field.id:F100` | Mid-level topic browsing |
| `primary_topic.subfield.id:` | Filter by subfield | `filter=primary_topic.subfield.id:S1000` | Fine-grained topic browsing |
| `title.search:` | Title-only search | `filter=title.search:quantum` | Precise title matching |
| `abstract.search:` | Abstract-only search | `filter=abstract.search:machine learning` | Abstract-focused discovery |
| `title_and_abstract.search:` | Combined search | `filter=title_and_abstract.search:covid` | Broader text search |

**Confidence:** HIGH - All filters verified from [OpenAlex Filter Works documentation](https://docs.openalex.org/api-entities/works/filter-works).

### Work Object Fields for Discovery

| Field | Type | Purpose | Notes |
|-------|------|---------|-------|
| `referenced_works` | List[String] | IDs of works this paper cites | Outgoing citations for backward traversal |
| `referenced_works_count` | Integer | Count of references | Quick check for well-connected papers |
| `cited_by_count` | Integer | Incoming citation count | Already used; critical for ranking |
| `related_works` | List[String] | IDs of algorithmically similar works | OpenAlex computes based on shared concepts |
| `topics` | List[Object] | Up to 3 ranked topics | Each has display_name, score, subfield, field, domain |
| `primary_topic` | Object | Highest-ranked topic | Identical to first item in topics list |
| `concepts` | List[Object] | Legacy concept tags (deprecated) | Still available but Topics recommended |
| `keywords` | List[Object] | AI-generated keywords | Short phrases with similarity scores |
| `fwci` | Float | Field-weighted citation impact | Percentile-based quality metric |

**Confidence:** HIGH - Verified from [OpenAlex Work Object documentation](https://docs.openalex.org/api-entities/works/work-object).

### R Package Dependencies

| Package | Version | Purpose | Why Recommended |
|---------|---------|---------|-----------------|
| httr2 | ≥ 1.0.0 | HTTP client for OpenAlex API | Already in use. Modern pipeable API, built-in rate limiting/retry, explicit request objects. Recommended over httr for API wrappers per [official docs](https://httr2.r-lib.org/articles/wrapping-apis.html). |
| jsonlite | ≥ 1.8.0 | JSON parsing for API responses | Already in use. Use `flatten = TRUE` for nested structures, `fromJSON()` with simplifyVector for arrays. |
| DuckDB R | ≥ 0.9.0 | Store topics, citations, relationships | Already in use. Native JSON/LIST support for storing arrays (referenced_works, topics). Use `to_json()` for export. |
| shiny | ≥ 1.8.0 | UI framework | Already in use. Modal dialogs for wizards via `modalDialog()`. |
| bslib | ≥ 0.6.0 | Bootstrap 5 components | Already in use. Cards, layouts, offcanvas for UI. |

**Confidence:** HIGH - All packages verified as current and suitable for requirements.

### Optional: openalexR Package

| Package | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| openalexR | ≥ 2.0.2 | ROpenSci OpenAlex client | **NOT RECOMMENDED** for this project. Serapeum already has custom `api_openalex.R` with httr2. Adding openalexR introduces dependency overhead and architectural inconsistency. Use existing httr2 client. |

**Confidence:** MEDIUM - openalexR is [feature-complete and CRAN-approved](https://cran.r-project.org/web/packages/openalexR/), but redundant given existing architecture.

## Recommended Patterns

### Pattern 1: Seed Paper Discovery

**What:** User enters partial title/DOI, system shows autocomplete, user selects seed paper, system fetches related works.

**Implementation:**
```r
# 1. Autocomplete for seed selection
GET /works/autocomplete?q={user_input}

# 2. Fetch seed paper with relationships
GET /works/{seed_id}
# Returns: referenced_works, related_works, topics

# 3. Fetch related papers (pick ONE strategy)
# Option A: Citations (forward)
GET /works?filter=cites:{seed_id}

# Option B: References (backward)
GET /works?filter=cited_by:{seed_id}

# Option C: Semantic similarity
GET /works?filter=related_to:{seed_id}
```

**Why:** OpenAlex provides three orthogonal discovery paths. Start with `related_to` for broadest coverage, then let user filter by citation relationships.

**Confidence:** HIGH - Pattern documented in [OpenAlex API Guide](https://docs.openalex.org/api-entities/works).

### Pattern 2: Topic Browsing

**What:** User browses domain → field → subfield → topic hierarchy, system shows papers in selected topic.

**Implementation:**
```r
# 1. List domains (top-level topics with domain.id filter)
GET /topics?group_by=domain.id

# 2. List fields within domain
GET /topics?filter=domain.id:{selected_domain}
           &group_by=field.id

# 3. List subfields within field
GET /topics?filter=field.id:{selected_field}
           &group_by=subfield.id

# 4. List topics within subfield
GET /topics?filter=subfield.id:{selected_subfield}

# 5. Fetch works for selected topic
GET /works?filter=primary_topic.id:{topic_id}
          &sort=cited_by_count:desc
```

**Why:** OpenAlex Topics provide explicit 4-level hierarchy. Use `group_by` for aggregation at each level. Filter works by `primary_topic.id` for highest-confidence matches.

**Confidence:** HIGH - Verified from [OpenAlex Topics documentation](https://docs.openalex.org/api-entities/topics).

### Pattern 3: LLM-Assisted Query Construction

**What:** User describes research interest in natural language, LLM generates structured OpenAlex query.

**Implementation:**
```r
# System prompt for LLM
system_prompt <- "You are a query builder for the OpenAlex API.
User will describe research interest. Generate valid OpenAlex filter syntax.

Available filters:
- title.search: (text)
- abstract.search: (text)
- publication_year: (year or range)
- is_oa: (true/false)
- cited_by_count: (>N)
- type: (article|review|preprint|book|dataset)
- primary_topic.field.id: (field ID)

Output ONLY the filter string, no explanation.
Example: 'title_and_abstract.search:machine learning,publication_year:>2020,is_oa:true'"

# User input
user_input <- "Recent open access papers about climate change impacts on agriculture with at least 10 citations"

# LLM generates
llm_output <- chat_completion(api_key, model,
  format_chat_messages(system_prompt, user_input))

# Parse and execute
filter_string <- llm_output
GET /works?filter={filter_string}
```

**Why:** Chain-of-Thought prompts excel at query expansion ([research](https://arxiv.org/pdf/2305.03653)). LLMs can map natural language to structured filters. Constrain output format to prevent hallucination.

**Confidence:** MEDIUM - Pattern validated by [LLM query expansion research](https://haystack.deepset.ai/blog/query-expansion), but requires prompt engineering tuning.

### Pattern 4: Startup Wizard

**What:** First-time users see modal dialog guiding them through creating their first search notebook.

**Implementation:**
```r
# Module: mod_startup_wizard.R
mod_startup_wizard_ui <- function(id) {
  ns <- NS(id)
  # Empty - wizard triggered programmatically
}

mod_startup_wizard_server <- function(id, notebook_count) {
  moduleServer(id, function(input, output, session) {
    # Show wizard on first visit
    observe({
      if (notebook_count() == 0 && !wizard_dismissed()) {
        showModal(modalDialog(
          title = "Welcome to Serapeum Discovery",
          wizard_page_1_ui(session$ns),
          footer = tagList(
            actionButton(session$ns("next_1"), "Next"),
            modalButton("Skip")
          )
        ))
      }
    })

    # Multi-step wizard with observeEvent for each step
    # Use removeModal() and showModal() to transition
  })
}
```

**Why:** [Shiny modal dialogs](https://shiny.posit.co/r/articles/build/modal-dialogs/) support wizard patterns. Break onboarding into steps (introduce features → create first notebook → run search). Use localStorage or DB flag to track dismissal.

**Confidence:** HIGH - Standard Shiny pattern documented in [Mastering Shiny](https://mastering-shiny.org/action-dynamic.html).

## Database Schema Extensions

### New Tables for Discovery

```sql
-- Store topic hierarchy for offline browsing
CREATE TABLE topics (
  topic_id VARCHAR PRIMARY KEY,
  display_name VARCHAR,
  description TEXT,
  domain_id VARCHAR,
  domain_name VARCHAR,
  field_id VARCHAR,
  field_name VARCHAR,
  subfield_id VARCHAR,
  subfield_name VARCHAR,
  works_count INTEGER,
  updated_date TIMESTAMP
);

-- Store citation relationships for graph visualization (future)
CREATE TABLE citations (
  source_paper_id VARCHAR,  -- paper doing the citing
  target_paper_id VARCHAR,  -- paper being cited
  notebook_id INTEGER,
  PRIMARY KEY (source_paper_id, target_paper_id, notebook_id)
);

-- Wizard dismissal tracking
CREATE TABLE user_preferences (
  key VARCHAR PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Why:** Topics table enables offline hierarchical browsing. Citations table supports future graph features. DuckDB handles JSON arrays natively via LIST type - no need for junction tables for `referenced_works`.

**Confidence:** HIGH - DuckDB [JSON/LIST support](https://duckdb.org/docs/stable/data/json/overview) verified.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| OpenAlex Client | Custom httr2 | openalexR package | Already have working httr2 client in `api_openalex.R`. Adding openalexR = dependency bloat + architectural inconsistency. |
| Topic System | OpenAlex Topics | OpenAlex Concepts | Concepts deprecated, ~65K items vs 4.5K Topics. Topics have cleaner hierarchy and active maintenance. |
| Query Builder Approach | LLM prompt engineering | Keyword extraction + templates | LLMs handle natural language variation better. Chain-of-Thought prompts proven for query expansion. |
| Wizard UI | Shiny modalDialog | Dedicated onboarding page | Modals less disruptive, dismissible, don't block navigation. Standard Shiny pattern. |
| Related Works Discovery | OpenAlex `related_to` filter | Compute similarity via embeddings | OpenAlex precomputes relationships across 240M works. Reinventing = expensive + slower. Use their API. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| OpenAlex Concepts API | Deprecated in favor of Topics | Topics API (`/topics`) |
| Web scraping for citations | OpenAlex provides structured data | OpenAlex filters (`cites`, `cited_by`) |
| Manual JSON flattening | jsonlite handles it | `fromJSON(..., flatten = TRUE)` |
| `httr` package | Superseded by httr2 | `httr2` (already in use) |
| Semantic Scholar API | Not currently integrated, scope creep | Focus on OpenAlex for milestone |

## Installation

**No new R packages required.** All dependencies already in Serapeum:

```r
# Verify existing packages (already in renv if present)
library(httr2)      # HTTP client
library(jsonlite)   # JSON parsing
library(DuckDB)     # Database
library(shiny)      # UI framework
library(bslib)      # Bootstrap components
```

**New OpenAlex API requirements (as of Feb 2025):**
- Free API key required (100,000 credits/day)
- Add to `config.yml`: `openalex.api_key`
- Pass via `req_headers("Authorization" = paste("Bearer", api_key))`

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| httr2 | ≥ 1.0.0 | jsonlite ≥ 1.8.0 | Use `resp_body_json()` for auto-parsing |
| DuckDB | ≥ 0.9.0 | R ≥ 4.0 | Native JSON support introduced 0.9.x |
| shiny | ≥ 1.8.0 | bslib ≥ 0.6.0 | Modal dialogs stable across versions |
| bslib | ≥ 0.6.0 | Bootstrap 5.x | Offcanvas, cards require Bootstrap 5 |

**Note:** OpenAlex API does not version endpoints. Breaking changes announced via [mailing list](https://groups.google.com/g/openalex-community).

## Sources

**Official Documentation (HIGH confidence):**
- [OpenAlex Works API](https://docs.openalex.org/api-entities/works) - Endpoints, filters, search
- [OpenAlex Filter Works](https://docs.openalex.org/api-entities/works/filter-works) - Complete filter reference
- [OpenAlex Work Object](https://docs.openalex.org/api-entities/works/work-object) - Field structure
- [OpenAlex Topics](https://docs.openalex.org/api-entities/topics) - Topic hierarchy
- [OpenAlex Topic Object](https://docs.openalex.org/api-entities/topics/topic-object) - Topic structure
- [httr2 Documentation](https://httr2.r-lib.org/) - R HTTP client
- [httr2 Wrapping APIs Guide](https://httr2.r-lib.org/articles/wrapping-apis.html) - Best practices
- [DuckDB JSON Overview](https://duckdb.org/docs/stable/data/json/overview) - JSON handling
- [Shiny Modal Dialogs](https://shiny.posit.co/r/articles/build/modal-dialogs/) - Wizard patterns

**R Package Documentation (HIGH confidence):**
- [openalexR on CRAN](https://cran.r-project.org/web/packages/openalexR/) - Version 2.0.2
- [jsonlite Reference Manual](http://jeroen.r-universe.dev/jsonlite/doc/manual.html) - Parsing nested JSON

**Research Papers (MEDIUM confidence):**
- [Query Expansion with LLMs (arXiv)](https://arxiv.org/pdf/2305.03653) - Chain-of-Thought for search
- [Haystack Query Expansion](https://haystack.deepset.ai/blog/query-expansion) - RAG techniques

**Community Resources (MEDIUM confidence):**
- [Engineering Production-Grade Shiny Apps](https://engineering-shiny.org/structuring-project.html) - Module patterns
- [Mastering Shiny - Modules](https://mastering-shiny.org/scaling-modules.html) - Best practices
- [Mastering Shiny - Dynamic UI](https://mastering-shiny.org/action-dynamic.html) - Wizards

---
*Stack research for: Serapeum Discovery Features*
*Researched: 2026-02-10*
