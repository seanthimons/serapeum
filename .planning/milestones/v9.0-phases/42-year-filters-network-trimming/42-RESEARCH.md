# Phase 42: Year Filters + Network Trimming - Research

**Researched:** 2026-03-03
**Domain:** R Shiny reactive filtering, network graph manipulation, citation threshold analysis
**Confidence:** HIGH

## Summary

Phase 42 fixes the hardcoded year filter lower-bound (currently 1950) to dynamically compute `min(year)` from the actual network data, and adds a trim control that filters the network to show only seeds, influential papers, and connectivity-preserving bridge papers. The core challenge is identifying influential papers from existing network data (citation counts are already available) and implementing bridge detection to prevent orphaning important nodes.

The codebase already has proven patterns: year filtering with sliderInput (lines 240-290 in mod_citation_network.R), reactive filtering with unfiltered/filtered data snapshots (current_network_data vs unfiltered_network_data), and citation-based node ranking (citation_network.R lines 279-307 prune nodes by cited_by_count during BFS). The citation audit module demonstrates frequency-based thresholds (collection_frequency >= 2 in citation_audit.R line 344).

The technical challenge is defining "influential" from existing data (no audit flag exists) and detecting bridge papers that connect influential clusters. Research shows networkx.algorithms.bridges provides bridge detection in Python, and igraph in R has similar graph analysis capabilities. However, a simpler approach is citation-based thresholding (e.g., top quartile by cited_by_count) combined with edge-preservation logic (keep papers that are the only connection between two influential papers).

**Primary recommendation:** Use dynamic year bounds from `min(year)` and `max(year)` of network_nodes, implement trim control as binary toggle (on/off) with citation percentile threshold (75th percentile = "influential"), detect bridge papers by checking if removing them would orphan other influential papers, and apply trim via reactive filtering pattern (matching year filter implementation).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Trim control UX:**
- Toggle control (on/off), not a slider — the audit process already identifies influential papers, so the distinction is binary
- Located in the side panel filters section (alongside year filters)
- Auto-enable for networks with 500+ nodes; off by default for smaller networks
- Seeds are always visible — never removed by trim
- Toggle label shows count of papers that will be removed (e.g., "Trim to influential (removes 47 papers)")

**Trim threshold:**
- Claude's discretion to investigate how the audit currently flags influential papers (existing field/flag in codebase)
- Bridge papers (non-influential, non-seed papers that connect influential clusters) are kept to preserve network connectivity
- Mark bridge-paper retention logic with `#NOTE` tag in code as a design choice that can be tweaked in the future

**Filter feedback:**
- Instant removal when trim activates — no fade animation
- No persistent indicator showing how many papers are hidden
- No extra tooltip/badge on surviving papers — seeds and influential papers already have distinct shapes, which is sufficient
- Bridge papers get no visual distinction from other papers

**Year filter behavior:**
- Auto-update min/max bounds when network data changes (new search, papers added)
- Keep existing slider control — just fix the lower bound to use `min(year)` from network data instead of hardcoded 1950
- Network updates on slider release, not live during drag
- Year filter and trim toggle are independent filters (AND logic) — both apply, order doesn't matter

### Claude's Discretion

- How to determine "influential" from existing audit data (investigate codebase for existing flags/fields)
- Bridge paper detection algorithm
- Exact placement and styling of toggle within side panel
- Performance optimization for filtering large networks

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FILT-01 | Year filter lower-bound reflects the actual minimum year in the network data | Dynamic slider bounds using SQL `SELECT MIN(year), MAX(year) FROM network_nodes WHERE network_id = ?` (Pattern 1); reactive observer pattern from lines 272-290 (Code Example 1) |
| FILT-02 | User can trim the network to only influential/high-citation papers | Citation percentile threshold (75th percentile by cited_by_count) + bridge detection (Pattern 2); binary toggle control (Pattern 3); reactive filtering via current_network_data snapshot (Code Example 2) |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R base | 4.5.1 | Quantile calculation for percentile thresholds | Built-in `quantile()` function; no dependencies |
| DuckDB | (existing) | Query year ranges from network_nodes table | Already in use; efficient MIN/MAX queries on indexed columns |
| Shiny | (existing) | Toggle control and reactive filtering | bslib::input_switch pattern already used for physics toggle (line 158) |
| visNetwork | (existing) | Network re-rendering after filter | visNetworkProxy for live updates without full re-render |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| igraph | 2.1.x | Bridge detection (optional) | If simple edge-based bridge detection proves insufficient; provides `articulation_points()` function |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Citation percentile threshold | Audit collection_frequency flag | Audit data is notebook-scoped, not network-scoped; citation count is already available in network_nodes.cited_by_count |
| Edge-based bridge detection | igraph articulation points | igraph adds external dependency; edge-based approach sufficient for citation networks (tree-like structure) |
| Reactive filtering | Direct DOM manipulation | Reactive filtering maintains Shiny state consistency; matches existing year filter pattern |

**Installation:**
```r
# All dependencies already installed in existing codebase
# Optional: install.packages("igraph") if advanced bridge detection needed
```

## Architecture Patterns

### Pattern 1: Dynamic Year Bounds from Network Data

**What:** Compute slider min/max from actual network_nodes year range, not hardcoded values.

**Why:** User constraint requires year bounds to match network data; hardcoded 1950 fails for networks with papers from 1800s or 2000s-only.

**Implementation:**
```r
# In mod_citation_network.R, replace lines 272-290
observe({
  net_data <- unfiltered_network_data()
  req(net_data)

  nodes <- net_data$nodes
  valid_years <- nodes$year[!is.na(nodes$year)]

  if (length(valid_years) == 0) {
    # Fallback if no year data (shouldn't happen with OpenAlex)
    min_year <- 1900
    max_year <- 2026
  } else {
    min_year <- min(valid_years)
    max_year <- max(valid_years)
  }

  # Update slider with data-driven bounds
  updateSliderInput(session, "year_filter",
                    min = min_year, max = max_year,
                    value = c(min_year, max_year))
})
```

**Key insight:** `unfiltered_network_data()` is the canonical source of truth (lines 183-185); using it ensures year bounds reflect the full network, not filtered subset.

**Source:** Existing pattern in mod_citation_network.R lines 272-290; this is a fix to use dynamic bounds instead of hardcoded 1900/2026.

### Pattern 2: Citation Percentile Threshold + Bridge Detection

**What:** Define "influential" as papers above 75th percentile of cited_by_count, plus bridge papers that connect influential clusters.

**Why:** No existing audit flag in network_nodes (confirmed via schema inspection); citation count is the canonical influence measure already used for node size (line 613).

**Implementation:**
```r
# Calculate influential threshold
identify_influential_papers <- function(nodes_df) {
  # Seeds are always kept
  seed_ids <- nodes_df$paper_id[nodes_df$is_seed]

  # Calculate 75th percentile of citations
  citation_threshold <- quantile(nodes_df$cited_by_count, 0.75, na.rm = TRUE)

  # Papers above threshold are influential
  influential_ids <- nodes_df$paper_id[nodes_df$cited_by_count >= citation_threshold]

  # Combine seeds + influential
  base_keep <- unique(c(seed_ids, influential_ids))

  base_keep
}

# Detect bridge papers
identify_bridge_papers <- function(nodes_df, edges_df, influential_ids) {
  # NOTE: Bridge detection — keeps papers that are the only path between
  # influential papers. This is a simplified edge-based approach suitable
  # for citation networks (mostly tree-like, few cycles). For dense graphs,
  # consider igraph::articulation_points() instead.

  bridge_papers <- character(0)

  # For each non-influential paper, check if it connects influential papers
  non_influential <- setdiff(nodes_df$paper_id, influential_ids)

  for (paper_id in non_influential) {
    # Find edges where this paper is a connector
    incoming <- edges_df$from_paper_id[edges_df$to_paper_id == paper_id]
    outgoing <- edges_df$to_paper_id[edges_df$from_paper_id == paper_id]

    # If paper connects influential papers, it's a bridge
    connects_influential_in <- any(incoming %in% influential_ids)
    connects_influential_out <- any(outgoing %in% influential_ids)

    if (connects_influential_in && connects_influential_out) {
      bridge_papers <- c(bridge_papers, paper_id)
    }
  }

  bridge_papers
}
```

**Why this works:** Citation networks are mostly DAGs with sparse cycles; edge-based bridge detection catches papers that form the only path between influential clusters without requiring full graph traversal.

**Source:** Citation pruning logic in citation_network.R lines 279-307; networkx.algorithms.bridges conceptual model ([NetworkX bridges documentation](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.bridges.bridges.html)).

### Pattern 3: Binary Toggle Control in Side Panel

**What:** Add bslib::input_switch to side panel (legend area), matching physics toggle pattern.

**Why:** User constraint requires toggle in side panel; physics toggle (line 158-162) is proven pattern.

**Implementation:**
```r
# In mod_citation_network.R UI (legend panel, after physics toggle)
bslib::input_switch(
  ns("trim_enabled"),
  "Trim to Influential",
  value = FALSE  # Default off, auto-enable for 500+ nodes in observer
),
# Dynamic label showing removal count
uiOutput(ns("trim_label"))

# Server-side: compute removal count
output$trim_label <- renderUI({
  net_data <- unfiltered_network_data()
  if (is.null(net_data)) return(NULL)

  trim_active <- input$trim_enabled
  if (!isTRUE(trim_active)) return(NULL)

  influential_ids <- identify_influential_papers(net_data$nodes)
  bridge_ids <- identify_bridge_papers(net_data$nodes, net_data$edges, influential_ids)
  keep_ids <- unique(c(influential_ids, bridge_ids))

  remove_count <- nrow(net_data$nodes) - length(keep_ids)

  div(class = "small text-muted mt-1",
      paste("Removes", remove_count, "papers"))
})

# Auto-enable for large networks
observe({
  net_data <- unfiltered_network_data()
  req(net_data)

  if (nrow(net_data$nodes) >= 500) {
    bslib::update_switch("trim_enabled", value = TRUE, session = session)
  }
}, priority = -1)  # Run after data loads
```

**Key insight:** Dynamic label gives feedback without persistent badges; matches user constraint for instant feedback on toggle state.

**Source:** Physics toggle pattern lines 158-162; auto-enable logic similar to ambient drift threshold (lines 839-857).

### Pattern 4: Reactive Filtering with AND Logic

**What:** Apply year filter and trim filter independently, then combine with AND logic (both must pass).

**Why:** User constraint requires independent filters; matches existing year filter pattern (lines 316-351).

**Implementation:**
```r
# Combined filter observer (replaces year-only filter at line 316)
apply_filters <- function() {
  net_data <- unfiltered_network_data()
  req(net_data)

  nodes <- net_data$nodes
  edges <- net_data$edges

  # Filter 1: Year range
  range <- input$year_filter
  include_null <- input$include_unknown_year_network
  year_keep <- nodes$is_seed  # Seeds always kept
  if (!is.null(range) && !is.null(include_null)) {
    if (include_null) {
      year_keep <- year_keep | is.na(nodes$year) | (nodes$year >= range[1] & nodes$year <= range[2])
    } else {
      year_keep <- year_keep | (!is.na(nodes$year) & nodes$year >= range[1] & nodes$year <= range[2])
    }
  }

  # Filter 2: Trim to influential
  trim_keep <- rep(TRUE, nrow(nodes))  # Default: keep all
  if (isTRUE(input$trim_enabled)) {
    influential_ids <- identify_influential_papers(nodes)
    bridge_ids <- identify_bridge_papers(nodes, edges, influential_ids)
    keep_ids <- unique(c(influential_ids, bridge_ids))
    trim_keep <- nodes$paper_id %in% keep_ids
  }

  # AND logic: both filters must pass
  final_keep <- year_keep & trim_keep
  filtered_nodes <- nodes[final_keep, ]

  # Keep edges where both endpoints survive
  filtered_node_ids <- filtered_nodes$paper_id
  filtered_edges <- edges[edges$from_paper_id %in% filtered_node_ids &
                          edges$to_paper_id %in% filtered_node_ids, ]

  # Update display data
  current_network_data(list(
    nodes = filtered_nodes,
    edges = filtered_edges,
    metadata = net_data$metadata
  ))
}

# Trigger on year filter apply (existing button)
observeEvent(input$apply_year_filter, {
  apply_filters()
})

# Trigger on trim toggle (debounced to prevent rapid clicks)
trim_debounced <- reactive({ input$trim_enabled }) |> debounce(300)
observeEvent(trim_debounced(), {
  apply_filters()
}, ignoreInit = TRUE)
```

**Key insight:** AND logic means most restrictive filter wins; year + trim together can remove more nodes than either alone.

**Source:** Year filter logic lines 316-351; debounce pattern from physics toggle lines 776-830.

### Anti-Patterns to Avoid

**Anti-pattern 1: Mutating Unfiltered Data**
- **What goes wrong:** Modifying unfiltered_network_data() when applying filters, losing original network
- **Why it happens:** Confusion between current_network_data (filtered view) and unfiltered_network_data (canonical source)
- **How to avoid:** Always read from unfiltered_network_data(), write to current_network_data()
- **Warning signs:** Filters become irreversible; toggling trim off doesn't restore removed papers

**Anti-pattern 2: Real-time Trim During Drag**
- **What goes wrong:** Updating network on every trim toggle state change, causing visual glitches
- **Why it happens:** Missing debounce on toggle reactive
- **How to avoid:** Debounce trim toggle observer (300ms, matching physics toggle)
- **Warning signs:** Network flickers during rapid toggle clicks

**Anti-pattern 3: Computing Percentile on Filtered Data**
- **What goes wrong:** Citation threshold changes when year filter is active, making trim inconsistent
- **Why it happens:** Computing quantile() on current_network_data instead of unfiltered_network_data
- **How to avoid:** Always compute influential threshold from unfiltered_network_data
- **Warning signs:** Trim removes different papers when year filter is active vs inactive

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Year min/max calculation | R loop over nodes | SQL `SELECT MIN(year), MAX(year)` or R `min()/max()` | Built-in functions handle NA values, edge cases, and are optimized |
| Percentile calculation | Manual sorting + indexing | R `quantile()` function | Handles NA values, multiple interpolation methods, edge cases |
| Toggle control UI | Custom checkbox + CSS | bslib::input_switch | Bootstrap 5 native, accessible, matches existing physics toggle |
| Reactive debouncing | setTimeout in JavaScript | Shiny `debounce()` function | Server-side, no race conditions, matches existing physics pattern |

**Key insight:** R base and Shiny provide battle-tested functions for all filtering primitives; custom implementations introduce edge case bugs.

## Common Pitfalls

### Pitfall 1: Hardcoded Percentile Threshold

**What goes wrong:** Using 75th percentile works for 100-node networks but fails for 10-node networks (keeps only 3 papers, network becomes trivial).

**Why it happens:** Fixed percentile doesn't adapt to network size or distribution.

**How to avoid:** Use adaptive threshold: 75th percentile for 50+ nodes, 50th percentile for 20-49 nodes, no trim for <20 nodes. Mark with `#NOTE` as tuneable parameter.

**Warning signs:** Small networks become empty after trim; user confusion.

### Pitfall 2: Bridge Detection Performance on Large Networks

**What goes wrong:** Naive bridge detection (checking every edge) becomes O(n²) for 500+ node networks, causing UI freeze.

**Why it happens:** Double loop over nodes and edges without optimization.

**How to avoid:** Limit bridge detection to papers within 1 hop of influential papers (prune search space), or skip bridge detection entirely for networks >500 nodes (user constraint already auto-enables trim for large networks, so aggressive pruning is expected).

**Warning signs:** Trim toggle takes >2 seconds to respond; Shiny app freezes.

### Pitfall 3: Orphaned Influential Papers After Trim

**What goes wrong:** Removing non-influential papers severs connections between influential papers, creating isolated nodes.

**Why it happens:** Bridge detection only checks bidirectional connections (incoming AND outgoing), missing papers that are endpoints.

**How to avoid:** After filtering, check for orphaned nodes (no incoming or outgoing edges) and force-include their nearest neighbors to reconnect them.

**Warning signs:** Influential papers appear as isolated nodes in trimmed network; user reports "important papers disappeared."

### Pitfall 4: Year Filter + Trim Race Condition

**What goes wrong:** User toggles trim while year filter is still processing, causing inconsistent state (some nodes filtered by old year range, others by new).

**Why it happens:** Both filters modify current_network_data() without synchronization.

**How to avoid:** Use single unified filter function (apply_filters()) that reads unfiltered data once and applies both filters atomically.

**Warning signs:** Network shows inconsistent node counts; papers appear/disappear randomly.

## Code Examples

### Example 1: Dynamic Year Bounds Observer

```r
# Source: mod_citation_network.R lines 272-290 (modified for dynamic bounds)

# Dynamic slider bounds from unfiltered data (stable — not affected by filtering)
observe({
  net_data <- unfiltered_network_data()
  req(net_data)

  nodes <- net_data$nodes
  valid_years <- nodes$year[!is.na(nodes$year)]

  if (length(valid_years) == 0) {
    # Fallback: use reasonable defaults if no year data
    min_year <- 1900
    max_year <- as.integer(format(Sys.Date(), "%Y"))
  } else {
    # FILT-01: Dynamic bounds from actual network data
    min_year <- min(valid_years)
    max_year <- max(valid_years)
  }

  # Update slider to match network data range
  updateSliderInput(session, "year_filter",
                    min = min_year, max = max_year,
                    value = c(min_year, max_year))
})
```

**Key insight:** Observer triggers when unfiltered_network_data() changes (new network loaded or built), ensuring bounds stay in sync with data.

**Source:** Existing pattern lines 272-290; fix changes hardcoded 1900/2026 to dynamic min/max.

### Example 2: Unified Filter Function (Year + Trim)

```r
# Combined filter logic with AND semantics

apply_combined_filters <- function(net_data, year_range, include_unknown_year, trim_enabled) {
  nodes <- net_data$nodes
  edges <- net_data$edges

  # === FILTER 1: Year range ===
  # Seeds are always kept (year filter exemption)
  year_keep <- nodes$is_seed
  if (!is.null(year_range)) {
    if (include_unknown_year) {
      year_keep <- year_keep | is.na(nodes$year) |
                   (nodes$year >= year_range[1] & nodes$year <= year_range[2])
    } else {
      year_keep <- year_keep |
                   (!is.na(nodes$year) & nodes$year >= year_range[1] & nodes$year <= year_range[2])
    }
  } else {
    # No year filter active: keep all
    year_keep <- rep(TRUE, nrow(nodes))
  }

  # === FILTER 2: Trim to influential ===
  if (isTRUE(trim_enabled)) {
    # Calculate citation threshold (75th percentile)
    # NOTE: Threshold tuneable parameter — 75th percentile balances coverage vs noise
    citation_threshold <- quantile(nodes$cited_by_count, 0.75, na.rm = TRUE)

    # Identify influential papers (seeds + high citations)
    influential <- nodes$is_seed | (nodes$cited_by_count >= citation_threshold)
    influential_ids <- nodes$paper_id[influential]

    # NOTE: Bridge detection — simplified edge-based approach for citation networks.
    # Keeps papers that connect influential clusters. For dense graphs or higher
    # precision, consider igraph::articulation_points() instead.
    bridge_ids <- character(0)
    non_influential <- nodes$paper_id[!influential]

    for (paper_id in non_influential) {
      # Check if paper has edges to/from influential papers
      has_influential_incoming <- any(edges$from_paper_id[edges$to_paper_id == paper_id] %in% influential_ids)
      has_influential_outgoing <- any(edges$to_paper_id[edges$from_paper_id == paper_id] %in% influential_ids)

      if (has_influential_incoming && has_influential_outgoing) {
        bridge_ids <- c(bridge_ids, paper_id)
      }
    }

    # Trim keep: influential + bridges
    keep_ids <- unique(c(influential_ids, bridge_ids))
    trim_keep <- nodes$paper_id %in% keep_ids
  } else {
    # No trim active: keep all
    trim_keep <- rep(TRUE, nrow(nodes))
  }

  # === AND logic: both filters must pass ===
  final_keep <- year_keep & trim_keep
  filtered_nodes <- nodes[final_keep, ]

  # Keep edges where both endpoints survive
  filtered_node_ids <- filtered_nodes$paper_id
  filtered_edges <- edges[edges$from_paper_id %in% filtered_node_ids &
                          edges$to_paper_id %in% filtered_node_ids, ]

  list(
    nodes = filtered_nodes,
    edges = filtered_edges,
    metadata = net_data$metadata
  )
}

# Usage in observers
observeEvent(input$apply_year_filter, {
  net_data <- unfiltered_network_data()
  req(net_data)

  filtered <- apply_combined_filters(
    net_data,
    year_range = input$year_filter,
    include_unknown_year = input$include_unknown_year_network,
    trim_enabled = input$trim_enabled
  )

  current_network_data(filtered)

  showNotification(
    paste("Filters applied:", nrow(filtered$nodes), "of", nrow(net_data$nodes), "nodes shown"),
    type = "message"
  )
})

# Debounced trim toggle observer
trim_debounced <- reactive({ input$trim_enabled }) |> debounce(300)
observeEvent(trim_debounced(), {
  net_data <- unfiltered_network_data()
  req(net_data)

  filtered <- apply_combined_filters(
    net_data,
    year_range = input$year_filter,
    include_unknown_year = input$include_unknown_year_network,
    trim_enabled = trim_debounced()
  )

  current_network_data(filtered)
}, ignoreInit = TRUE)
```

**Key insight:** Single filter function ensures year and trim filters use the same unfiltered data source, preventing race conditions and inconsistent state.

**Source:** Year filter logic lines 316-351; debounce pattern lines 776-830; citation pruning logic lines 279-307.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded year bounds (1950-2026) | Dynamic bounds from MIN/MAX(year) | Phase 42 (current) | Year filter adapts to network data, handles historical and recent-only datasets |
| No network pruning | Citation percentile + bridge detection | Phase 42 (current) | Large networks (500+ nodes) become readable by removing low-impact papers |
| Manual citation filtering | Automatic influential detection | Phase 42 (current) | User doesn't need to understand citation thresholds |

**Deprecated/outdated:**
- Hardcoded slider bounds: Use dynamic MIN/MAX from data instead
- Manual node filtering in UI: Use server-side reactive filtering for consistency

## Validation Architecture

> Validation disabled per workflow.nyquist_validation: false in .planning/config.json

Validation section skipped.

## Open Questions

1. **Adaptive percentile threshold vs fixed 75th percentile**
   - What we know: 75th percentile works for 100+ node networks; fails for small networks (<20 nodes)
   - What's unclear: Should threshold adapt to network size (e.g., 50th percentile for small networks)?
   - Recommendation: Use adaptive threshold with `#NOTE` marker as tuneable parameter; 75th for 50+ nodes, 50th for 20-49, no trim for <20

2. **Bridge detection performance cutoff**
   - What we know: Edge-based bridge detection is O(n×m) worst case; could freeze UI on 500+ node networks
   - What's unclear: Should we skip bridge detection entirely for large networks, or optimize the algorithm?
   - Recommendation: Limit bridge search to 1-hop neighbors of influential papers (prune search space); skip bridges for 500+ nodes (user expects aggressive pruning on auto-enable)

3. **Visual feedback for bridge papers**
   - What we know: User constraint says no visual distinction for bridge papers
   - What's unclear: Should we add optional tooltip showing "kept for connectivity" on hover?
   - Recommendation: Follow user constraint (no distinction); bridges are implementation detail, not user-facing concept

## Sources

### Primary (HIGH confidence)

- **Existing codebase:** C:/Users/sxthi/Documents/serapeum/R/mod_citation_network.R (year filter lines 240-351, reactive filtering pattern lines 183-185, physics toggle lines 158-162)
- **Existing codebase:** C:/Users/sxthi/Documents/serapeum/R/citation_network.R (citation-based pruning lines 279-307, node ranking by cited_by_count)
- **Existing codebase:** C:/Users/sxthi/Documents/serapeum/R/citation_audit.R (frequency threshold logic line 344, collection_frequency >= 2 pattern)
- **Schema inspection:** C:/Users/sxthi/Documents/serapeum/migrations/006_create_citation_networks.sql (network_nodes.cited_by_count column confirmed, no audit flags)
- **User constraints:** .planning/phases/42-year-filters-network-trimming/42-CONTEXT.md (all UX decisions, trim control specifications)

### Secondary (MEDIUM confidence)

- [NetworkX bridges documentation](https://networkx.org/documentation/stable/reference/algorithms/generated/networkx.algorithms.bridges.bridges.html) — Bridge detection algorithm concepts (Python, adaptable to R)
- [vis.js Network documentation](https://visjs.github.io/vis-network/docs/) — Network filtering via DataSet/DataView
- [Network Analysis with igraph (R)](https://kateto.net/netscix2016.html) — Graph analysis patterns in R

### Tertiary (LOW confidence)

- None — all findings verified with existing codebase or official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All libraries already in use; no new dependencies needed
- Architecture: HIGH — Year filter pattern already implemented (just needs bounds fix); trim pattern matches existing physics toggle and filtering logic
- Pitfalls: HIGH — Identified from existing codebase patterns (debouncing, unfiltered data snapshots) and graph theory fundamentals

**Research date:** 2026-03-03
**Valid until:** 2026-05-03 (60 days — stable domain, mature codebase patterns)
