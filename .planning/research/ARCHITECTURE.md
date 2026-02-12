# Architecture Patterns: Citation Network Graph, DOI Storage, Export Workflows

**Domain:** Research Assistant - Discovery Workflow Enhancement
**Researched:** 2026-02-12
**Confidence:** HIGH

## Integration with Existing Architecture

### Current Architecture Pattern: Producer-Consumer

**Existing workflow:**
1. Discovery modules (mod_seed_discovery, mod_query_builder, mod_topic_explorer) produce reactive requests
2. app.R consumes these requests via observeEvent()
3. Consumer fetches papers from OpenAlex API
4. Consumer creates notebook and populates abstracts table

**New features follow same pattern:**
- DOI storage: Data layer enhancement (no new modules)
- Citation network graph: New consumer in abstract detail view
- Export-to-seed: New producer button in abstract detail view
- Export data: New consumer in search notebook module

## Component Architecture

### 1. DOI Storage (Data Layer Only)

**Integration Point:** Database schema migration

**New Component:** Migration file `migrations/002_add_doi_column.sql`

```sql
-- Add DOI column to abstracts table
ALTER TABLE abstracts ADD COLUMN doi VARCHAR;
```

**Modified Component:** `R/db.R`
- `create_abstract()` function signature already has all parameters from parse_openalex_work()
- parse_openalex_work() extracts DOI (line 181-186 in api_openalex.R)
- create_abstract() must be updated to accept and store `doi` parameter

**Data Flow:**
```
OpenAlex API → parse_openalex_work() → doi field (already extracted)
                                     ↓
                         create_abstract() (needs doi parameter)
                                     ↓
                              abstracts.doi column
```

**No module changes required** - all API callers in app.R already pass through parsed work objects to create_abstract().

### 2. Citation Network Graph

**Integration Point:** Abstract detail view in mod_search_notebook.R (lines 691-833)

**New Component:** `R/mod_citation_network.R` (Shiny module)

**UI Structure:**
```r
mod_citation_network_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header("Citation Network"),
    card_body(
      visNetworkOutput(ns("network_graph")),
      # Controls
      radioButtons(ns("direction"),
        choices = c("Incoming citations" = "incoming",
                    "Outgoing references" = "outgoing",
                    "Both" = "both"),
        selected = "both"
      ),
      numericInput(ns("depth"), "Network depth", value = 1, min = 1, max = 2)
    )
  )
}
```

**Server Structure:**
```r
mod_citation_network_server <- function(id, con, paper_id, config) {
  moduleServer(id, function(input, output, session) {
    # Reactive: Fetch citation network data
    network_data <- reactive({
      req(paper_id())
      fetch_citation_network(
        con(),
        paper_id(),
        direction = input$direction,
        depth = input$depth,
        config()
      )
    })

    # Render visNetwork graph
    output$network_graph <- renderVisNetwork({
      data <- network_data()
      visNetwork(data$nodes, data$edges) %>%
        visOptions(highlightNearest = TRUE) %>%
        visInteraction(navigationButtons = TRUE)
    })
  })
}
```

**New Utility Function:** `R/citation_network.R`
```r
fetch_citation_network <- function(con, paper_id, direction, depth, config) {
  # 1. Get seed paper from abstracts table
  # 2. Call OpenAlex API for citing/cited papers
  # 3. Build nodes data frame (id, label, group)
  # 4. Build edges data frame (from, to)
  # 5. Return list(nodes = nodes_df, edges = edges_df)
}
```

**Modified Component:** `R/mod_search_notebook.R`
- Abstract detail view adds citation network card below metadata section
- New reactive: `viewed_paper_data()` to share paper info with citation network module
- Call: `mod_citation_network_server("citation_network", con_r, viewed_paper, effective_config)`

**Data Flow:**
```
User clicks paper → viewed_paper() reactive updates
                           ↓
            mod_citation_network_server() receives paper_id
                           ↓
            fetch_citation_network() calls OpenAlex API
                           ↓
            visNetwork renders interactive graph
```

**Technology Stack:**
- `visNetwork` R package (CRAN, version 2.1.4+)
- Uses vis.js JavaScript library for rendering
- Interactive features: zoom, drag nodes, highlight neighbors, physics simulation

### 3. Export-to-Seed Workflow

**Integration Point:** Abstract detail view actions (mod_search_notebook.R lines 836-844)

**Modified Component:** `R/mod_search_notebook.R`

**UI Change:** Add export button to detail_actions output
```r
output$detail_actions <- renderUI({
  paper <- current_paper_data()
  if (is.null(paper)) return(NULL)

  div(
    class = "d-flex gap-2",
    actionButton(ns("export_to_seed"),
                 "Use as Seed",
                 icon = icon("seedling"),
                 class = "btn-sm btn-success"),
    actionButton(ns("close_detail"),
                 "Close",
                 class = "btn-sm btn-secondary")
  )
})
```

**Server Logic:** New observeEvent handler
```r
observeEvent(input$export_to_seed, {
  paper <- current_paper_data()
  req(paper, paper$doi)

  # Pre-fill DOI input in seed discovery module
  updateTextInput(session, "seed_doi_input", value = paper$doi)

  # Navigate to discover view
  # (Requires communication back to app.R via reactive)
  seed_request(list(
    doi = paper$doi,
    source = "notebook_export"
  ))
})
```

**Modified Component:** `app.R`
- Search notebook module returns seed_request reactive
- Observer consumes seed_request and navigates to discover view with pre-filled DOI

**Data Flow:**
```
User clicks "Use as Seed" button in abstract detail
                ↓
     observeEvent captures paper DOI
                ↓
     seed_request() reactive emits {doi, source}
                ↓
     app.R observer consumes request
                ↓
     current_view("discover") + pre-fill DOI input
```

**Alternative Pattern (Simpler):** Instead of reactive communication, use modal dialog:
```r
observeEvent(input$export_to_seed, {
  paper <- current_paper_data()
  showModal(modalDialog(
    title = "Start Seed Discovery",
    p("Use this paper to discover related works?"),
    p(strong(paper$title)),
    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("confirm_seed"), "Discover", class = "btn-success")
    )
  ))
})

observeEvent(input$confirm_seed, {
  # Create seed discovery notebook directly
  # (Same pattern as current seed_discovery → app.R flow)
  removeModal()
})
```

### 4. Citation/Synthesis Export

**Integration Point:** Search notebook chat interface (mod_search_notebook.R)

**New Component:** Export button in chat output section

**UI Addition:** Add download button next to chat response
```r
# In render_chat_message() helper or chat output
div(
  class = "d-flex justify-content-between align-items-start",
  div(class = "flex-grow-1", chat_content),
  downloadButton(ns(paste0("export_", message_id)),
                 label = NULL,
                 icon = icon("download"),
                 class = "btn-sm btn-outline-secondary")
)
```

**Server Logic:** New downloadHandler
```r
output$export_synthesis <- downloadHandler(
  filename = function() {
    paste0("synthesis_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".md")
  },
  content = function(file) {
    # Get current chat messages
    messages <- chat_history()

    # Format as markdown
    md_content <- format_chat_as_markdown(messages)

    # Write to file
    writeLines(md_content, file)
  }
)
```

**Utility Function:** `R/export_utils.R`
```r
format_chat_as_markdown <- function(messages) {
  # Convert chat history to markdown format
  # Include metadata: date, notebook name, query
  # Format: # Synthesis\n\n## Query\n...\n## Response\n...
}
```

**Data Flow:**
```
User clicks download button
         ↓
downloadHandler triggered
         ↓
format_chat_as_markdown() formats messages
         ↓
Browser downloads .md file
```

**Export Formats:**
- Markdown (.md): Primary format, preserves structure
- CSV (.csv): For citations list only (paper_id, title, authors, year, doi)
- Plain text (.txt): For simple copy-paste

**Additional Export Location:** Abstract list bulk export
```r
# In mod_search_notebook.R, add button to abstract list header
actionButton(ns("export_abstracts"),
             "Export List",
             icon = icon("file-export"),
             class = "btn-sm btn-outline-primary")

output$export_abstracts <- downloadHandler(
  filename = function() {
    paste0("abstracts_", notebook_name(), "_", Sys.Date(), ".csv")
  },
  content = function(file) {
    papers <- papers_data()
    write.csv(papers, file, row.names = FALSE)
  }
)
```

## New vs Modified Components Summary

### New Components
| File | Type | Purpose |
|------|------|---------|
| `migrations/002_add_doi_column.sql` | Migration | Add doi column to abstracts table |
| `R/mod_citation_network.R` | Module | Citation network graph visualization |
| `R/citation_network.R` | Utility | Fetch and build citation network data |
| `R/export_utils.R` | Utility | Format chat/abstracts for export |

### Modified Components
| File | Changes | Reason |
|------|---------|--------|
| `R/db.R` | Add `doi` parameter to create_abstract() | Store DOI from parse_openalex_work() |
| `R/mod_search_notebook.R` | Add citation network card, export buttons, download handlers | Integrate all 4 new features |
| `app.R` | Consume seed_request reactive from search notebook | Support export-to-seed workflow |

### No Changes Required
| Component | Why No Changes |
|-----------|----------------|
| `R/api_openalex.R` | Already extracts DOI (line 181-186) |
| `R/mod_seed_discovery.R` | Already accepts DOI input, no API changes |
| All API callers in app.R | Already pass parsed work objects through |

## Suggested Build Order

### Phase 1: Data Foundation (1 task)
**Task 1: DOI Storage**
- Create migration file
- Update create_abstract() function signature
- Test: Verify new abstracts have DOI stored

**Dependencies:** None
**Validation:** Query abstracts table, check doi column populated

### Phase 2: Visualization (2 tasks)
**Task 2: Citation Network Module**
- Create mod_citation_network.R
- Create citation_network.R utility
- Install visNetwork package dependency
- Test: Render network graph for sample paper

**Dependencies:** Task 1 (needs DOI for API calls)
**Validation:** Graph displays, interactive controls work

**Task 3: Integrate Network into Detail View**
- Modify mod_search_notebook.R to add network card
- Wire module into abstract detail view
- Test: Click paper, see network graph below metadata

**Dependencies:** Task 2
**Validation:** Network appears in UI, updates on paper selection

### Phase 3: Export Workflows (3 tasks)
**Task 4: Export-to-Seed Button**
- Add button to detail_actions in mod_search_notebook.R
- Add observeEvent handler
- Wire seed_request reactive to app.R
- Test: Click button, navigate to discover view with pre-filled DOI

**Dependencies:** Task 1 (needs DOI)
**Validation:** DOI pre-fills, discover workflow works

**Task 5: Chat Export**
- Create export_utils.R
- Add download button to chat output
- Add downloadHandler for markdown export
- Test: Download synthesis markdown file

**Dependencies:** None
**Validation:** Downloaded file contains formatted chat

**Task 6: Abstract List Export**
- Add export button to abstract list header
- Add downloadHandler for CSV export
- Test: Download abstract list as CSV

**Dependencies:** Task 1 (include DOI in export)
**Validation:** CSV contains all abstract fields including DOI

## Data Flow Diagrams

### DOI Flow
```
OpenAlex API Response
        ↓
parse_openalex_work() [api_openalex.R:181-186]
        ↓
parsed_work.doi field
        ↓
create_abstract(doi = ...) [db.R]
        ↓
abstracts.doi column [database]
        ↓
Abstract detail view displays DOI link
Export-to-seed uses DOI
Citation network uses DOI for API calls
```

### Citation Network Flow
```
User clicks paper in list
        ↓
viewed_paper() reactive updates [mod_search_notebook.R]
        ↓
mod_citation_network_server receives paper_id
        ↓
fetch_citation_network() [citation_network.R]
        ↓
get_citing_papers() / get_cited_papers() [api_openalex.R]
        ↓
Build nodes/edges data frames
        ↓
visNetwork() renders graph [mod_citation_network.R]
```

### Export-to-Seed Flow
```
User clicks "Use as Seed" in detail view
        ↓
observeEvent(input$export_to_seed) [mod_search_notebook.R]
        ↓
seed_request() reactive emits {doi, source}
        ↓
app.R observer consumes seed_request
        ↓
current_view("discover")
updateTextInput for DOI field in mod_seed_discovery
```

### Export Data Flow
```
User clicks "Export" button
        ↓
downloadHandler triggered
        ↓
format_chat_as_markdown() / write.csv() [export_utils.R]
        ↓
Browser downloads file
```

## Architecture Patterns to Follow

### Pattern 1: Database Migrations
**What:** Use db_migrations.R pattern for schema changes
**When:** Adding/modifying database columns
**Example:**
```r
# migrations/002_add_doi_column.sql
ALTER TABLE abstracts ADD COLUMN doi VARCHAR;
```
**Why:** Existing databases need migration path, not just init_schema() changes

### Pattern 2: Producer-Consumer with Reactives
**What:** Modules emit reactive requests, app.R consumes and executes
**When:** Cross-module navigation or data passing
**Example:**
```r
# In module
seed_request <- reactiveVal(NULL)
observeEvent(input$export_to_seed, {
  seed_request(list(doi = paper$doi))
})
return(seed_request)

# In app.R
seed_req <- mod_search_notebook_server(...)
observeEvent(seed_req(), {
  # Handle request
})
```
**Why:** Decouples modules, maintains single responsibility

### Pattern 3: Download Handlers for Export
**What:** Use downloadButton + downloadHandler pattern
**When:** Exporting data as files
**Example:**
```r
# UI
downloadButton(ns("export"), "Export", icon = icon("download"))

# Server
output$export <- downloadHandler(
  filename = function() { paste0("data_", Sys.Date(), ".csv") },
  content = function(file) { write.csv(data, file) }
)
```
**Why:** Standard Shiny pattern, handles file generation and download

### Pattern 4: Shiny Modules for Reusable Components
**What:** Encapsulate UI + server logic in modules
**When:** Component used in multiple places or logically distinct
**Example:**
```r
mod_citation_network_ui <- function(id) { ... }
mod_citation_network_server <- function(id, ...) { ... }
```
**Why:** Namespace isolation, reusability, testability

## Anti-Patterns to Avoid

### Anti-Pattern 1: Direct Schema Changes in init_schema()
**What:** Adding new columns via ALTER TABLE in init_schema() tryCatch blocks
**Why bad:** Doesn't track migration history, hard to debug version conflicts
**Instead:** Use migrations/ directory with versioned SQL files
**Detection:** If seeing "column already exists" errors in logs

### Anti-Pattern 2: Tight Module Coupling
**What:** Module A directly calls Module B's inputs/outputs
**Why bad:** Breaks namespace isolation, hard to test, brittle
**Instead:** Use reactive values to communicate through parent scope (app.R)
**Detection:** If seeing ns() calls across module boundaries

### Anti-Pattern 3: Blocking API Calls in Render Functions
**What:** Calling OpenAlex API directly in renderUI() or renderPlot()
**Why bad:** Blocks UI thread, no loading indicators, poor UX
**Instead:** Use reactive() for data fetching + withProgress() for long operations
**Detection:** UI freezes during API calls

### Anti-Pattern 4: Duplicating parse_openalex_work() Logic
**What:** Re-parsing OpenAlex responses in new code
**Why bad:** Inconsistent field extraction, breaks if API changes
**Instead:** Always use parse_openalex_work() from api_openalex.R
**Detection:** Direct access to work$doi instead of parsed_work$doi

## Technology Dependencies

### New Package: visNetwork
**Purpose:** Interactive network graph visualization
**Installation:** `install.packages("visNetwork")`
**Version:** 2.1.4+ (CRAN stable)
**License:** MIT
**Bundle size:** ~500KB (vis.js included)
**Browser requirements:** Modern browsers (ES6)

**Integration:**
```r
# In DESCRIPTION
Imports:
  visNetwork (>= 2.1.4)

# In R/mod_citation_network.R
library(visNetwork)
```

**Performance considerations:**
- Handles up to ~1000 nodes smoothly
- Physics simulation can be disabled for larger graphs
- Client-side rendering (no server round-trips)

### Existing Packages (No Changes)
- shiny: Modal dialogs, download handlers
- bslib: Card layouts for network graph
- DBI/duckdb: Database migrations
- httr2: OpenAlex API calls (already used)

## Scalability Considerations

| Concern | At 10 papers | At 100 papers | At 1000 papers |
|---------|--------------|---------------|----------------|
| DOI storage | Instant | Instant | Instant (indexed column) |
| Citation network rendering | Instant | 1-2 seconds | 5+ seconds (disable physics) |
| Network API calls | 1 request | 1 request | 1 request (pagination handled) |
| Export file size | <1KB | ~50KB | ~500KB (CSV), ~1MB (markdown) |
| Download handler memory | Negligible | <10MB | ~50MB (stream large exports) |

**Optimization strategies:**
- Citation network: Limit depth to 2, add "Load more" button for depth 3+
- Export: Stream large CSV files instead of loading all into memory
- DOI lookup: Add index on abstracts.doi column for fast searches

## Error Handling

### DOI Missing
**Scenario:** OpenAlex paper has no DOI
**Handling:** Store as NA, hide "Use as Seed" button if NA
**UI:** Show "DOI not available" message in abstract detail

### Network Fetch Failure
**Scenario:** OpenAlex API timeout or rate limit
**Handling:** Display error message in network card, retry button
**UI:** "Failed to load network. [Retry]"

### Export Failure
**Scenario:** File write error (permissions, disk full)
**Handling:** showNotification with error message
**UI:** "Export failed: [error message]"

## Testing Strategy

### Unit Tests
- `test-db-migrations.R`: Test DOI column migration
- `test-citation-network.R`: Test network data building
- `test-export-utils.R`: Test markdown formatting

### Integration Tests
- Test DOI flow: API → parse → store → display
- Test network: Paper selection → API call → graph render
- Test export: Button click → download → file contents

### Manual Testing Checklist
- [ ] New abstracts have DOI populated
- [ ] Abstract detail shows DOI link (if available)
- [ ] Citation network graph renders and is interactive
- [ ] "Use as Seed" button pre-fills DOI in discover view
- [ ] Chat export downloads markdown with correct format
- [ ] Abstract list export downloads CSV with all fields
- [ ] All existing functionality still works

## Sources

**R Shiny Network Visualization:**
- [Interactive Network Visualization with R](https://www.statworx.com/en/content-hub/blog/interactive-network-visualization-with-r)
- [visNetwork: Network Visualization using 'vis.js' Library](https://datastorm-open.github.io/visNetwork/)
- [Introduction to visNetwork](https://cran.r-project.org/web/packages/visNetwork/vignettes/Introduction-to-visNetwork.html)
- [visNetwork GitHub Repository](https://github.com/datastorm-open/visNetwork)
- [cyjShiny: A cytoscape.js R Shiny Widget for network visualization](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0285339)
- [Interactive network chart with R](https://r-graph-gallery.com/network-interactive.html)

**Shiny Export Patterns:**
- [Create a download button or link — downloadButton](https://rstudio.github.io/shiny/reference/downloadButton.html)
- [Help users download data from your app - Posit](https://shiny.posit.co/r/articles/build/download/)
- [Chapter 9 Uploads and downloads | Mastering Shiny](https://mastering-shiny.org/action-transfer.html)

**Shiny Modal Patterns:**
- [Create a modal dialog UI — modalDialog - Shiny](https://shiny.posit.co/r/reference/shiny/1.6.0/modaldialog.html)
- [Modal — Shiny](https://shiny.posit.co/r/components/display-messages/modal/)
