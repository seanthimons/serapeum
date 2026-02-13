#' Format authors list into display string
#' @param authors_list List or character vector of author names
#' @return Single character string
format_authors_display <- function(authors_list) {
  authors <- as.character(unlist(authors_list))
  authors <- authors[nzchar(authors)]
  if (length(authors) == 0) return("Unknown")
  if (length(authors) > 3) {
    paste(paste(authors[1:3], collapse = ", "), "et al.")
  } else {
    paste(authors, collapse = ", ")
  }
}

#' Fetch citation network using BFS traversal
#'
#' Builds a citation graph starting from a seed paper, traversing
#' citations up to a specified depth. Uses breadth-first search with
#' citation-count pruning to keep the most influential papers.
#'
#' @param seed_paper_id OpenAlex Work ID (e.g., "W2741809807")
#' @param email User email for OpenAlex API
#' @param api_key Optional OpenAlex API key
#' @param direction "forward" (citing papers), "backward" (cited papers), or "both"
#' @param depth Number of hops from seed (1-3)
#' @param node_limit Maximum nodes to include (25-200)
#' @param progress_callback Optional function(message, fraction) for progress updates
#' @return List with nodes (data.frame) and edges (data.frame), or partial results on error
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                     direction = "both", depth = 2,
                                     node_limit = 100, progress_callback = NULL) {

  # Ensure W prefix
  if (!grepl("^W", seed_paper_id)) {
    seed_paper_id <- paste0("W", seed_paper_id)
  }

  # Initialize data structures
  visited <- character()  # Cycle detection
  nodes_list <- list()    # Will accumulate node data
  edges_list <- list()    # Will accumulate edge data

  # Fetch seed paper metadata
  seed_paper <- tryCatch({
    get_paper(seed_paper_id, email, api_key)
  }, error = function(e) NULL)

  if (is.null(seed_paper)) {
    return(list(
      nodes = data.frame(
        paper_id = character(),
        title = character(),
        authors = character(),
        year = integer(),
        venue = character(),
        doi = character(),
        cited_by_count = integer(),
        is_seed = logical(),
        stringsAsFactors = FALSE
      ),
      edges = data.frame(
        from_paper_id = character(),
        to_paper_id = character(),
        stringsAsFactors = FALSE
      )
    ))
  }

  # Track referenced_works for cross-link discovery
  refs_map <- list()  # paper_id -> character vector of referenced work IDs

  # Add seed node
  refs_map[[seed_paper_id]] <- seed_paper$referenced_works %||% character()
  nodes_list[[seed_paper_id]] <- list(
    paper_id = seed_paper_id,
    title = seed_paper$title,
    authors = format_authors_display(seed_paper$authors),
    year = seed_paper$year %||% NA_integer_,
    venue = seed_paper$venue %||% NA_character_,
    doi = seed_paper$doi %||% NA_character_,
    cited_by_count = seed_paper$cited_by_count %||% 0L,
    is_seed = TRUE
  )
  visited <- c(visited, seed_paper_id)

  # BFS frontier: start with seed
  current_frontier <- seed_paper_id

  # Progress tracking
  if (!is.null(progress_callback)) {
    progress_callback("Fetching seed paper", 0.1)
  }

  # BFS traversal
  for (hop in seq_len(depth)) {
    if (length(current_frontier) == 0) break

    next_frontier <- character()
    total_fetched <- 0

    # For each paper in current frontier, fetch its citations
    for (frontier_paper in current_frontier) {
      # Fetch citations based on direction
      citing_papers <- list()
      cited_papers <- list()

      if (direction %in% c("forward", "both")) {
        citing_papers <- tryCatch({
          get_citing_papers(frontier_paper, email, api_key, per_page = 200)
        }, error = function(e) {
          message("Warning: Failed to fetch citing papers for ", frontier_paper, ": ", e$message)
          list()
        })
      }

      if (direction %in% c("backward", "both")) {
        cited_papers <- tryCatch({
          get_cited_papers(frontier_paper, email, api_key, per_page = 200)
        }, error = function(e) {
          message("Warning: Failed to fetch cited papers for ", frontier_paper, ": ", e$message)
          list()
        })
      }

      # Combine results
      all_papers <- c(citing_papers, cited_papers)

      # Build lookup sets for edge direction (once per frontier paper)
      citing_ids <- if (length(citing_papers) > 0) {
        sapply(citing_papers, function(p) p$paper_id)
      } else {
        character()
      }
      cited_ids <- if (length(cited_papers) > 0) {
        sapply(cited_papers, function(p) p$paper_id)
      } else {
        character()
      }

      # Process fetched papers
      for (paper in all_papers) {
        paper_id <- paper$paper_id

        # Always add edges, even if node already visited (captures cross-links)
        if (paper_id %in% citing_ids) {
          edges_list[[paste(paper_id, frontier_paper, sep = "->")]] <- list(
            from_paper_id = paper_id,
            to_paper_id = frontier_paper
          )
        }
        if (paper_id %in% cited_ids) {
          edges_list[[paste(frontier_paper, paper_id, sep = "->")]] <- list(
            from_paper_id = frontier_paper,
            to_paper_id = paper_id
          )
        }

        # Skip node creation and frontier expansion if already visited
        if (paper_id %in% visited) next

        # Add to visited set
        visited <- c(visited, paper_id)

        # Track referenced works for cross-link discovery
        refs_map[[paper_id]] <- paper$referenced_works %||% character()

        # Add node data
        nodes_list[[paper_id]] <- list(
          paper_id = paper_id,
          title = paper$title,
          authors = format_authors_display(paper$authors),
          year = paper$year %||% NA_integer_,
          venue = paper$venue %||% NA_character_,
          doi = paper$doi %||% NA_character_,
          cited_by_count = paper$cited_by_count %||% 0L,
          is_seed = FALSE
        )

        # Add to next frontier
        next_frontier <- c(next_frontier, paper_id)
      }

      total_fetched <- total_fetched + length(all_papers)
    }

    # Progress update
    if (!is.null(progress_callback)) {
      progress_callback(paste("Hop", hop, "complete:", length(next_frontier), "papers found"),
                         0.1 + (hop / depth) * 0.7)
    }

    # Prune frontier if we exceed node limit
    if (length(nodes_list) > node_limit) {
      # Sort all non-seed nodes by citation count
      node_citations <- sapply(nodes_list, function(n) {
        if (isTRUE(n$is_seed)) return(Inf)  # Keep seed
        n$cited_by_count
      })

      # Get top N paper IDs
      top_indices <- order(node_citations, decreasing = TRUE)[seq_len(node_limit)]
      top_paper_ids <- names(nodes_list)[top_indices]

      # Filter nodes
      nodes_list <- nodes_list[top_paper_ids]

      # Filter edges (keep only edges where both nodes are in top set)
      edges_list <- Filter(function(e) {
        e$from_paper_id %in% top_paper_ids && e$to_paper_id %in% top_paper_ids
      }, edges_list)

      # Update next frontier to only include kept nodes
      next_frontier <- intersect(next_frontier, top_paper_ids)
    }

    # Also prune frontier itself if it's too large (for next iteration)
    if (length(next_frontier) > 100) {
      frontier_citations <- sapply(next_frontier, function(pid) {
        nodes_list[[pid]]$cited_by_count
      })
      top_frontier_indices <- order(frontier_citations, decreasing = TRUE)[1:100]
      next_frontier <- next_frontier[top_frontier_indices]
    }

    current_frontier <- next_frontier
  }

  # Cross-link discovery: check referenced_works for edges between papers already in graph
  all_paper_ids <- names(nodes_list)
  for (pid in all_paper_ids) {
    refs <- refs_map[[pid]]
    if (length(refs) == 0) next
    # Find which referenced works are in our graph
    # OpenAlex referenced_works are full URLs like "https://openalex.org/W123"
    # Normalize to just the W-id
    ref_ids <- sub("^https://openalex\\.org/", "", refs)
    cross_links <- intersect(ref_ids, all_paper_ids)
    for (target_id in cross_links) {
      edge_key <- paste(pid, target_id, sep = "->")
      if (is.null(edges_list[[edge_key]])) {
        edges_list[[edge_key]] <- list(
          from_paper_id = pid,
          to_paper_id = target_id
        )
      }
    }
  }

  if (!is.null(progress_callback)) {
    progress_callback("Discovering cross-links between papers", 0.95)
  }

  # Convert lists to data frames
  nodes_df <- do.call(rbind, lapply(nodes_list, as.data.frame, stringsAsFactors = FALSE))
  edges_df <- if (length(edges_list) > 0) {
    do.call(rbind, lapply(edges_list, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame(
      from_paper_id = character(),
      to_paper_id = character(),
      stringsAsFactors = FALSE
    )
  }

  if (!is.null(progress_callback)) {
    progress_callback(paste("Network built:", nrow(nodes_df), "nodes,", nrow(edges_df), "edges"), 1.0)
  }

  list(nodes = nodes_df, edges = edges_df)
}

#' Map publication years to color palette
#'
#' @param years Numeric vector of publication years
#' @param palette Viridis palette name: "viridis", "magma", "plasma", "inferno", "cividis"
#' @return Character vector of hex colors
map_year_to_color <- function(years, palette = "viridis") {
  # Handle NA years - assign neutral gray
  if (all(is.na(years))) {
    return(rep("#999999", length(years)))
  }

  # Get valid years
  valid_years <- years[!is.na(years)]

  # Handle single-year edge case (division by zero)
  if (length(unique(valid_years)) == 1) {
    # Return middle palette color for all nodes
    palette_colors <- viridisLite::viridis(100, option = palette)
    middle_color <- palette_colors[50]
    colors <- rep(middle_color, length(years))
    colors[is.na(years)] <- "#999999"
    return(colors)
  }

  # Normalize years to 0-1 range
  year_range <- range(valid_years, na.rm = TRUE)
  normalized <- (years - year_range[1]) / (year_range[2] - year_range[1])

  # Map to palette
  palette_colors <- viridisLite::viridis(100, option = palette)
  color_indices <- pmin(pmax(round(normalized * 99) + 1, 1), 100)
  colors <- palette_colors[color_indices]

  # Assign gray to NAs
  colors[is.na(years)] <- "#999999"

  colors
}

#' Compute node sizes from citation counts
#'
#' Applies cube-root transform to handle power-law distribution,
#' then scales to visNetwork size range.
#'
#' @param cited_by_counts Numeric vector of citation counts
#' @return Numeric vector of node sizes (10-100)
compute_node_sizes <- function(cited_by_counts) {
  n <- length(cited_by_counts)

  if (n == 0) return(numeric(0))
  if (n == 1) return(30)

  # Cube-root transform: better spread than log1p for power-law data.
  # cbrt(100)=4.6, cbrt(1000)=10, cbrt(15000)=24.7
  # Gives 5x visual difference between 1k and 15k citations
  # (log1p only gives 1.4x — high-citation nodes look the same)
  transformed <- pmax(cited_by_counts, 0)^(1/3)

  count_range <- range(transformed, na.rm = TRUE)
  if (count_range[2] - count_range[1] == 0) {
    return(rep(30, n))
  }

  normalized <- (transformed - count_range[1]) / (count_range[2] - count_range[1])

  # Scale to range 10-100 (landmark papers should visually dominate)
  10 + normalized * 90
}

#' Build visNetwork-ready graph data
#'
#' Adds visNetwork-specific columns to nodes: color, size, shape, tooltip, etc.
#'
#' @param nodes_df Data frame from fetch_citation_network
#' @param edges_df Data frame from fetch_citation_network
#' @param palette Viridis palette name
#' @param seed_paper_id OpenAlex Work ID of seed paper
#' @return List with nodes and edges data frames ready for visNetwork
build_network_data <- function(nodes_df, edges_df, palette = "viridis", seed_paper_id = NULL) {
  if (nrow(nodes_df) == 0) {
    return(list(nodes = nodes_df, edges = edges_df))
  }

  # Add visNetwork columns
  nodes_df$id <- nodes_df$paper_id
  nodes_df$label <- NA  # No labels by default (show on hover)
  nodes_df$color <- map_year_to_color(nodes_df$year, palette)
  nodes_df$value <- compute_node_sizes(nodes_df$cited_by_count)

  # Shape: star for seed, dot for others
  nodes_df$shape <- ifelse(nodes_df$is_seed, "star", "dot")

  # Border: gold ring for seed
  nodes_df$borderWidth <- ifelse(nodes_df$is_seed, 5, 1)
  nodes_df$color.border <- ifelse(nodes_df$is_seed, "#FFD700", "#2B7CE9")

  # Preserve original paper title before overwriting with tooltip
  nodes_df$paper_title <- nodes_df$title

  # Tooltip with paper details (visNetwork uses 'title' for hover tooltip)
  nodes_df$title <- sprintf(
    "<b>%s</b><br>Authors: %s<br>Year: %s<br>Citations: %s",
    htmltools::htmlEscape(nodes_df$paper_title),
    htmltools::htmlEscape(nodes_df$authors),
    ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
    nodes_df$cited_by_count
  )

  # Edges: visNetwork expects 'from' and 'to' columns
  if (nrow(edges_df) > 0) {
    # Drop self-loops (OpenAlex sometimes lists a paper in its own referenced_works)
    edges_df <- edges_df[edges_df$from_paper_id != edges_df$to_paper_id, ]
    edges_df$from <- edges_df$from_paper_id
    edges_df$to <- edges_df$to_paper_id
    edges_df$arrows <- "to"  # Directional arrows
  }

  list(nodes = nodes_df, edges = edges_df)
}

#' Compute layout positions using igraph
#'
#' Uses Fruchterman-Reingold force-directed layout.
#' Scales coordinates for vis.js coordinate system.
#'
#' @param nodes_df Data frame with paper_id column
#' @param edges_df Data frame with from_paper_id and to_paper_id columns
#' @return nodes_df with x and y columns added
compute_layout_positions <- function(nodes_df, edges_df) {
  if (nrow(nodes_df) == 0) {
    nodes_df$x <- numeric(0)
    nodes_df$y <- numeric(0)
    return(nodes_df)
  }

  # Handle single-node edge case
  if (nrow(nodes_df) == 1) {
    nodes_df$x <- 0
    nodes_df$y <- 0
    return(nodes_df)
  }

  # Build igraph object
  if (nrow(edges_df) == 0) {
    # No edges - create star layout around seed
    n <- nrow(nodes_df)
    angles <- seq(0, 2 * pi, length.out = n + 1)[1:n]
    nodes_df$x <- cos(angles) * 800
    nodes_df$y <- sin(angles) * 800
    return(nodes_df)
  }

  # Create graph from edge list
  g <- igraph::graph_from_data_frame(
    d = edges_df[, c("from_paper_id", "to_paper_id")],
    directed = TRUE,
    vertices = nodes_df$paper_id
  )

  # Compute Fruchterman-Reingold layout
  layout_coords <- igraph::layout_with_fr(g)

  # Center on origin and scale for vis.js coordinate system
  layout_coords[, 1] <- layout_coords[, 1] - mean(layout_coords[, 1])
  layout_coords[, 2] <- layout_coords[, 2] - mean(layout_coords[, 2])
  nodes_df$x <- layout_coords[, 1] * 800
  nodes_df$y <- layout_coords[, 2] * 800

  nodes_df
}
