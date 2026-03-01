# Phase 01: Multi-Seeded Citation Network - Research

**Researched:** 2026-03-01
**Domain:** Multi-seed citation network architecture, graph merging, discovery workflows
**Confidence:** HIGH

## Summary

Phase 01 extends the existing single-seed citation network to support multiple seed papers, enabling users to build combined citation networks from all papers in a document notebook or BibTeX import. The core technical challenge is refactoring `current_seed_id()` (single reactive value) to `current_seed_ids()` (reactive list), running independent BFS traversals from each seed, and merging/deduplicating the results into a single unified graph.

The existing infrastructure provides strong foundations: `fetch_citation_network()` already implements BFS with interrupt support and progress tracking, visNetwork handles ~2,000 nodes smoothly, and the ExtendedTask + mirai pattern supports async execution. The new "discovery + import" workflow requires a lightweight DuckDB set-difference query (network nodes NOT in originating notebook) paired with import buttons—explicitly NOT a full citation audit integration.

Visualization enhancements include star shapes for all seed papers (existing pattern), diamond shapes for papers reachable from 2+ seeds (new overlap indicator), and a tabbed right-side panel (Paper Details vs Missing Papers). The existing year-based viridis color gradient is preserved; no color-by-seed-origin encoding.

**Primary recommendation:** Refactor to multi-seed architecture with independent per-seed BFS, node deduplication by paper_id, shape-based overlap visualization (star/diamond/dot), and a simple tabbed discovery panel. Reuse existing progress infrastructure with per-seed progress messages ("Processing seed 3/10... Depth 2/2").

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Seed Selection:**
- Two entry points for seeding the network:
  1. **BibTeX import** — finish the existing stub button in `mod_bulk_import.R:810-815` that currently only shows a notification
  2. **Document notebook toolbar** — new button alongside Import/Export/Edit/Refresh that sends papers to the citation network tab
- All papers in the notebook become seeds (no per-paper selection)
- Clicking either button auto-switches to the Citation Network tab
- Network does NOT auto-build — user adjusts controls (depth, direction, node cap) then clicks "Build Network", same workflow as single seed

**Network Merging:**
- BFS runs from each seed paper independently
- Per-seed node cap using the existing slider (max 200 per seed)
- No overall hard ceiling — vis.js handles ~2,000 nodes smoothly; typical notebooks (5-20 papers) won't exceed this
- Deduplicate papers reachable from multiple seeds
- Year-based color gradient (viridis palette) is preserved — no color-by-seed-origin

**Seed & Overlap Visualization:**
- All seed papers get star shape (same as current single-seed behavior)
- Papers reachable from 2+ seeds get diamond shape (indicates shared/important papers)
- Regular papers remain dots
- Small legend in graph corner: star = seed, diamond = multi-seed overlap, dot = regular — build on existing collapsible legend structure
- Tooltips remain unchanged (title, authors, year, citations) — no seed-connection info in tooltips

**Discovery + Import Workflow:**
- After building a network, the right side panel becomes tabbed:
  - **"Paper Details" tab** — current behavior (shows details when clicking a node)
  - **"Missing Papers" tab** — lists network nodes NOT in the originating notebook, with import buttons
- "Missing Papers" determined by a DuckDB set-difference query (network node paper_ids vs notebook abstracts), not by running the full citation audit module
- Imported papers go into the originating notebook (the one that provided the seeds)
- This is explicitly NOT a full audit integration — it's a lightweight discovery + import workflow

**Build Workflow:**
- Fresh build each time — no incremental seed addition to existing graphs
- Existing progress modal reused, with per-seed progress messages: "Processing seed 3/10... Depth 2/2"
- Same ExtendedTask + mirai async pattern as current single-seed builds

### Claude's Discretion

- Exact tab styling for Paper Details vs Missing Papers (use bslib navset_card_tab or custom tabs)
- Missing Papers list layout (simple list, cards, or table)
- Per-paper import button placement (inline or bulk "Import All" button)
- Diamond node sizing (same as regular nodes or slightly larger for visibility)
- Progress message formatting for multi-seed builds

### Deferred Ideas (OUT OF SCOPE)

- **AUDIT-09**: Export citation gaps as BibTeX — remains a separate future feature for the citation audit module
- **AUDIT-10**: Multi-level backward citation mining (depth=2+ references of references) — future audit enhancement
- **Full unified view**: Merging network and audit into one interface was debated and deferred — too high cost/complexity for Phase 1
- **Color-by-seed-origin**: Coloring nodes by which seed they came from was considered but deferred — year-based coloring is more useful
- **Incremental seed addition**: Adding seeds to an existing graph without rebuilding was considered but deferred — adds complex state management

</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| visNetwork | 2.1.2+ (existing) | Interactive network visualization | Already integrated, handles ~2k nodes, supports shape property for star/diamond/dot |
| igraph | Latest (existing) | Graph layout computation | Already used for Fruchterman-Reingold layout; no changes needed |
| DuckDB | (existing) | Database queries, set-difference for missing papers | Fast IN clause filtering, already has abstracts and citation_networks tables |
| mirai + ExtendedTask | (existing) | Async BFS execution with interrupt support | Already integrated in Phase 18 for network building with cancellation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bslib | Latest (existing) | Tabbed panel UI (navset_card_tab) | For Paper Details vs Missing Papers tabs |
| httr2 | (existing) | OpenAlex API calls | Already used in get_citing_papers() / get_cited_papers() |
| viridisLite | (existing) | Year-based color palette | Preserved from single-seed implementation |

### No New Dependencies
All required libraries are already in the codebase. This is a refactor + enhancement, not a new technology integration.

## Architecture Patterns

### Recommended Code Structure
```
R/
├── mod_citation_network.R     # (exists) Refactor: current_seed_id → current_seed_ids
├── citation_network.R         # (exists) Refactor: fetch_citation_network → multi-seed BFS
├── mod_bulk_import.R          # (exists) Wire stub button L810-815
├── mod_document_notebook.R    # (exists) Add "Seed Network" toolbar button
└── db.R                       # (exists) Add helper: get_notebook_papers(notebook_id)
```

### Pattern 1: Multi-Seed BFS with Independent Traversals

**What:** Run BFS from each seed paper independently, then merge and deduplicate results.

**When to use:** Always — this is the core architectural change.

**Example:**
```r
# New signature in citation_network.R
fetch_multi_seed_citation_network <- function(
  seed_paper_ids,  # character vector of OpenAlex Work IDs
  email, api_key = NULL,
  direction = "both", depth = 2,
  node_limit_per_seed = 100,  # NEW: per-seed cap, not global
  progress_callback = NULL,
  interrupt_flag = NULL,
  progress_file = NULL
) {
  all_nodes <- list()
  all_edges <- list()

  total_seeds <- length(seed_paper_ids)

  for (i in seq_along(seed_paper_ids)) {
    seed_id <- seed_paper_ids[i]

    # Write per-seed progress
    write_progress(progress_file, i, total_seeds, 0, 1,
                   sprintf("Processing seed %d of %d...", i, total_seeds))

    # Run single-seed BFS (reuse existing function)
    result <- fetch_citation_network(
      seed_id, email, api_key,
      direction = direction, depth = depth,
      node_limit = node_limit_per_seed,
      progress_callback = NULL,  # Use file-based progress instead
      interrupt_flag = interrupt_flag,
      progress_file = progress_file
    )

    # Accumulate results
    all_nodes <- c(all_nodes, list(result$nodes))
    all_edges <- c(all_edges, list(result$edges))
  }

  # Merge and deduplicate
  merged_nodes <- do.call(rbind, all_nodes)
  merged_edges <- do.call(rbind, all_edges)

  # Deduplicate nodes by paper_id (keep first occurrence)
  merged_nodes <- merged_nodes[!duplicated(merged_nodes$paper_id), ]

  # Deduplicate edges by from->to pair
  edge_keys <- paste(merged_edges$from_paper_id, merged_edges$to_paper_id, sep = "->")
  merged_edges <- merged_edges[!duplicated(edge_keys), ]

  # Mark all seed papers
  merged_nodes$is_seed <- merged_nodes$paper_id %in% seed_paper_ids

  # Mark overlap papers (reachable from 2+ seeds)
  # Strategy: count how many seed BFS results contained each paper_id
  node_counts <- table(unlist(lapply(all_nodes, function(df) df$paper_id)))
  merged_nodes$is_overlap <- node_counts[merged_nodes$paper_id] >= 2

  list(nodes = merged_nodes, edges = merged_edges, partial = FALSE)
}
```

**Source:** Adapted from existing `fetch_citation_network()` in `citation_network.R` — same BFS logic, now applied per-seed.

### Pattern 2: Shape-Based Overlap Visualization

**What:** Use visNetwork `shape` property to encode seed/overlap/regular distinction.

**When to use:** Always — this is the primary visual encoding for multi-seed importance.

**Example:**
```r
# In build_network_data() (citation_network.R)
# After computing colors and sizes:

nodes_df$shape <- ifelse(
  nodes_df$is_seed,
  "star",
  ifelse(
    nodes_df$is_overlap,
    "diamond",  # NEW: papers reachable from 2+ seeds
    "dot"
  )
)

# Update legend to include diamond shape
# In mod_citation_network.R UI:
div(
  class = "mt-2",
  icon("star", class = "text-warning"), " = Seed Paper", br(),
  icon("diamond", class = "text-info"), " = Multi-Seed Overlap", br(),  # NEW
  icon("circle", class = "text-muted"), " = Regular Paper"
)
```

**Source:** visNetwork documentation — `shape` accepts "dot", "star", "diamond", "triangle", "square".

### Pattern 3: Tabbed Side Panel (Paper Details vs Missing Papers)

**What:** Replace single side panel with bslib navset_card_tab for two views.

**When to use:** Always — required for discovery + import workflow.

**Example:**
```r
# In mod_citation_network.R server, output$side_panel <- renderUI():

req(current_network_data())
ns <- session$ns

navset_card_tab(
  id = ns("side_panel_tabs"),

  # Tab 1: Paper Details (existing behavior)
  nav_panel(
    title = "Paper Details",
    value = "details",
    # Existing side panel content (title, authors, abstract, "Explore from here")
    uiOutput(ns("paper_details_content"))
  ),

  # Tab 2: Missing Papers (NEW)
  nav_panel(
    title = "Missing Papers",
    value = "missing",
    # List of network nodes NOT in originating notebook
    uiOutput(ns("missing_papers_content"))
  )
)
```

**Source:** bslib 0.6.0+ — `navset_card_tab()` creates tabbed card layouts.

### Pattern 4: DuckDB Set-Difference for Missing Papers

**What:** Query network nodes that are NOT in the originating notebook.

**When to use:** Always — this is the discovery mechanism.

**Example:**
```r
# In mod_citation_network.R server:

output$missing_papers_content <- renderUI({
  net_data <- current_network_data()
  req(net_data)

  # Get originating notebook ID (stored in network metadata)
  notebook_id <- net_data$metadata$source_notebook_id
  if (is.null(notebook_id)) {
    return(div(class = "text-muted", "No source notebook — network built from sidebar seed search"))
  }

  # Get all paper_ids in the network
  network_paper_ids <- net_data$nodes$paper_id

  # Query which ones are NOT in the notebook
  missing_papers <- dbGetQuery(con_r(), "
    SELECT paper_id, title, authors, year, cited_by_count, doi
    FROM (SELECT unnest(?::VARCHAR[]) as paper_id)
    WHERE paper_id NOT IN (SELECT paper_id FROM abstracts WHERE notebook_id = ?)
  ", list(network_paper_ids, notebook_id))

  if (nrow(missing_papers) == 0) {
    return(div(class = "text-muted", "All network papers are already in your notebook."))
  }

  # Render list of missing papers with import buttons
  lapply(seq_len(nrow(missing_papers)), function(i) {
    paper <- missing_papers[i, ]
    div(
      class = "border-bottom pb-2 mb-2",
      strong(paper$title),
      div(class = "small text-muted", paper$authors),
      div(class = "small text-muted", paste0("Year: ", paper$year, " | Citations: ", paper$cited_by_count)),
      actionButton(
        ns(paste0("import_", i)),
        "Import",
        class = "btn-sm btn-primary mt-1",
        onclick = sprintf(
          "Shiny.setInputValue('%s', '%s', {priority: 'event'});",
          ns("import_paper"), paper$paper_id
        )
      )
    )
  })
})

# Import handler
observeEvent(input$import_paper, {
  paper_id <- input$import_paper
  notebook_id <- current_network_data()$metadata$source_notebook_id
  req(paper_id, notebook_id)

  # Fetch paper details from OpenAlex
  paper <- get_paper(paper_id, config_r()$openalex$email, NULL)
  req(paper)

  # Add to notebook (reuse existing add_abstract function)
  add_abstract(con_r(), notebook_id, paper)

  showNotification("Paper imported to notebook", type = "message")

  # Refresh missing papers list (re-render will exclude newly imported paper)
  # Trigger happens automatically via reactive dependency
})
```

**Source:** DuckDB IN clause filtering + existing `add_abstract()` function from `db.R`.

### Anti-Patterns to Avoid

- **Don't merge BFS traversals depth-by-depth** — run each seed's full BFS independently, then merge. Depth-by-depth merging complicates interrupt handling and progress tracking.
- **Don't encode seed-origin in node color** — user constraint explicitly defers this; keep year-based viridis gradient.
- **Don't run citation audit for missing papers** — it's a separate module with different analysis goals (frequent citations across collection). Just do simple set-difference.
- **Don't auto-build network after seeding** — user constraint: clicking seed button switches to tab but doesn't build. Let user adjust controls first.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-seed graph merging algorithm | Custom graph union logic | Simple rbind + deduplication by paper_id | Node and edge identity is already unique (paper_id, from->to pairs); no complex graph algebra needed |
| Tabbed panel UI | Custom Bootstrap tabs + JavaScript | bslib::navset_card_tab | Shiny-reactive, accessible, consistent with existing bslib patterns |
| Missing papers query | Manual filtering in R | DuckDB IN clause | Orders of magnitude faster for large networks; DuckDB optimizes set operations |
| Shape-based legend | CSS pseudo-elements | visNetwork native shapes + Font Awesome icons | visNetwork already renders star/diamond/dot; just document in legend text |

**Key insight:** The existing single-seed infrastructure is remarkably complete. Multi-seed support is mostly architectural refactoring (reactive value → reactive list, single BFS → loop of BFS), not new algorithms or libraries.

## Common Pitfalls

### Pitfall 1: Global Node Cap vs Per-Seed Node Cap

**What goes wrong:** Applying a 200-node cap to the merged graph prunes important papers from underrepresented seeds.

**Why it happens:** Single-seed implementation has one `node_limit` parameter. Naively applying it to merged results favors seeds with high-citation neighbors.

**How to avoid:** Apply `node_limit` per-seed during individual BFS traversals, not to the merged result. Each seed gets fair representation.

**Warning signs:** In a 5-seed network with 200 global cap, one highly-cited seed dominates the entire graph; others contribute <10 nodes each.

### Pitfall 2: Edge Duplication from Bidirectional BFS

**What goes wrong:** When running "both" direction, edges appear twice (A→B from forward BFS, B→A from backward BFS).

**Why it happens:** OpenAlex returns cited papers AND citing papers; cross-links exist in both directions.

**How to avoid:** Deduplicate edges by from->to pair after merging. Existing `fetch_citation_network()` already handles this; just apply again after multi-seed merge.

**Warning signs:** Edge count is ~2x expected; graph render is slow due to redundant edges.

### Pitfall 3: Lost Seed Markers After Deduplication

**What goes wrong:** After deduplicating nodes, `is_seed` flag is FALSE for some seed papers.

**Why it happens:** `rbind(all_nodes)` might not preserve seed markers if a seed appears in another seed's BFS result as a non-seed.

**How to avoid:** Re-mark all seeds after deduplication: `merged_nodes$is_seed <- merged_nodes$paper_id %in% seed_paper_ids`.

**Warning signs:** Not all seed papers have star shapes in the rendered graph.

### Pitfall 4: Progress File Overwrite in Multi-Seed Builds

**What goes wrong:** Per-seed progress messages overwrite each other; user sees "Processing seed 10 of 10" even when seed 3 is still running.

**Why it happens:** Each BFS call writes to the same `progress_file` independently.

**How to avoid:** Wrap per-seed BFS in a higher-level progress context. Write seed-level progress before each BFS call; let BFS write depth-level progress with a prefix.

**Warning signs:** Progress modal jumps around non-sequentially; final message appears before all seeds finish.

## Code Examples

Verified patterns from existing codebase and documentation:

### Multi-Seed Reactive State (mod_citation_network.R)

```r
# BEFORE (single-seed):
current_seed_id <- reactiveVal(NULL)

# AFTER (multi-seed):
current_seed_ids <- reactiveVal(character())  # character vector of paper IDs
source_notebook_id <- reactiveVal(NULL)  # NEW: track which notebook provided seeds

# Build button handler:
observeEvent(input$build_network, {
  req(length(current_seed_ids()) > 0)

  # Create interrupt and progress files (same as before)
  flag_file <- create_interrupt_flag(session$token)
  current_interrupt_flag(flag_file)
  prog_file <- create_progress_file(session$token)
  current_progress_file(prog_file)

  # Show progress modal (same as before)
  showModal(modalDialog(
    title = tagList(icon("spinner", class = "fa-spin"), "Building Citation Network"),
    # ... progress bar UI ...
  ))

  # Invoke async task with MULTIPLE seeds
  network_task$invoke(
    seed_ids = current_seed_ids(),  # NEW: vector instead of scalar
    email = config_r()$openalex$email,
    direction = input$direction,
    depth = input$depth,
    node_limit_per_seed = input$node_limit,  # NEW: per-seed cap
    interrupt_flag = flag_file,
    progress_file = prog_file,
    app_dir = getwd()
  )

  # ... poller setup (same as before) ...
})
```

**Source:** Existing `mod_citation_network.R:360-421` — build button handler.

### Document Notebook Seed Button (mod_document_notebook.R)

```r
# In mod_document_notebook_ui():
# Add new button to toolbar (near Import/Export/Edit/Refresh)

actionButton(
  ns("seed_citation_network"),
  "Seed Network",
  class = "btn-outline-primary",
  icon = icon("share-nodes")
)

# In mod_document_notebook_server():
# Handler to collect all papers and navigate to network tab

observeEvent(input$seed_citation_network, {
  nb_id <- notebook_id()
  req(nb_id)

  # Get all paper_ids from notebook
  papers <- dbGetQuery(con(), "
    SELECT paper_id FROM abstracts WHERE notebook_id = ?
  ", list(nb_id))

  if (nrow(papers) == 0) {
    showNotification("No papers in notebook to seed network", type = "warning")
    return()
  }

  # Pass seed IDs and notebook context to main app
  # (Requires exposing a callback from main app to network module)
  seed_network_callback(
    seed_ids = papers$paper_id,
    source_notebook_id = nb_id
  )

  showNotification(
    paste("Seeding network with", nrow(papers), "papers from notebook"),
    type = "message"
  )
})
```

**Source:** Adapted from existing toolbar buttons in `mod_document_notebook.R` + `mod_bulk_import.R:810-815` stub pattern.

### BibTeX Import Seed Button (mod_bulk_import.R)

```r
# BEFORE (stub at L810-815):
observeEvent(input$seed_network, {
  showNotification(
    "Citation network seeding will be available after importing. Papers are ready for citation audit.",
    type = "message", duration = 5
  )
  removeModal()
})

# AFTER (wire to network):
observeEvent(input$seed_network, {
  # Get import run metadata to find notebook and paper_ids
  run_id <- current_run_id()
  req(run_id)

  run_metadata <- dbGetQuery(con(), "
    SELECT notebook_id FROM import_runs WHERE id = ?
  ", list(run_id))

  imported_papers <- dbGetQuery(con(), "
    SELECT work_id FROM import_items
    WHERE import_run_id = ? AND status = 'imported'
  ", list(run_id))

  if (nrow(imported_papers) == 0) {
    showNotification("No papers imported yet", type = "warning")
    return()
  }

  # Pass to network module (via callback)
  seed_network_callback(
    seed_ids = imported_papers$work_id,
    source_notebook_id = run_metadata$notebook_id[1]
  )

  removeModal()

  showNotification(
    paste("Seeding network with", nrow(imported_papers), "imported papers"),
    type = "message"
  )
})
```

**Source:** Existing stub at `mod_bulk_import.R:810-815` + import_runs/import_items schema from `db.R`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-seed only | Multi-seed architecture | Phase 01 (this phase) | Enables bulk discovery workflows; BibTeX imports become network entry points |
| No overlap indicators | Diamond shape for multi-seed overlap | Phase 01 | Surfaces shared/important papers across multiple research threads |
| Side panel single-purpose | Tabbed panel (Details + Missing Papers) | Phase 01 | Discovery + import workflow without leaving network view |

**No deprecated patterns:** This phase extends, not replaces. Single-seed networks remain supported (backward compatible — `current_seed_ids()` with length 1 behaves identically to old `current_seed_id()`).

## Open Questions

1. **Should "Import All" bulk action exist for missing papers?**
   - What we know: Per-paper import buttons are straightforward; bulk import is one line of code (`lapply(missing_paper_ids, add_abstract)`)
   - What's unclear: User might want selective import (not all missing papers are relevant)
   - Recommendation: Start with per-paper buttons. Add "Import All" if user feedback indicates it's needed. Low-cost addition later.

2. **How should network metadata track multiple seeds?**
   - What we know: `citation_networks` table has `seed_paper_id` (singular) and `seed_paper_title`
   - What's unclear: Store all seed IDs as JSON array? Comma-separated string? Create junction table?
   - Recommendation: Add `seed_paper_ids` VARCHAR column with JSON array. Keeps schema simple; DuckDB has JSON functions for querying.

3. **Should saved multi-seed networks be reloadable?**
   - What we know: Current `save_network()` / `load_network()` functions store nodes/edges and metadata
   - What's unclear: Does saving a multi-seed network require storing all seed IDs for display purposes?
   - Recommendation: Yes — store `seed_paper_ids` array in metadata. When loading, mark all seeds with stars. Already have `is_seed` column in nodes table.

## Sources

### Primary (HIGH confidence)
- `R/mod_citation_network.R` — existing single-seed implementation (reviewed 2026-03-01)
- `R/citation_network.R` — BFS traversal, node/edge building, deduplication patterns (reviewed 2026-03-01)
- `R/mod_bulk_import.R` — seed network stub at L810-815 (reviewed 2026-03-01)
- `R/db.R` — abstracts schema, citation_networks schema, import_runs/import_items (reviewed 2026-03-01)
- `.planning/phases/12-citation-network-visualization/12-RESEARCH.md` — original network architecture research (reviewed 2026-03-01)
- `.planning/phases/01-multi-seeded-citation-network/01-CONTEXT.md` — user decisions from /gsd:discuss-phase (reviewed 2026-03-01)
- `MULTI-PAPER-SEEDING-GAP.md` — architectural gap analysis (reviewed 2026-03-01)

### Secondary (MEDIUM confidence)
- visNetwork documentation — shape property accepts "star", "diamond", "dot" (verified via existing code usage)
- bslib documentation — navset_card_tab for tabbed panels (existing pattern in codebase for other modules)

### Tertiary (LOW confidence)
- None — all findings verified against codebase or official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already integrated, zero new dependencies
- Architecture: HIGH — refactoring well-understood code; patterns match existing conventions
- Pitfalls: HIGH — identified from reading existing BFS implementation and common graph-merging issues

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable domain — citation networks, DuckDB, visNetwork are mature technologies)
