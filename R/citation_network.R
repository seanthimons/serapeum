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
#' @param interrupt_flag Optional path to interrupt flag file for cancellation
#' @return List with nodes (data.frame) and edges (data.frame), or partial results on error
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                     direction = "both", depth = 2,
                                     node_limit = 100, progress_callback = NULL,
                                     interrupt_flag = NULL,
                                     progress_file = NULL) {

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

    # Check for interrupt at start of each BFS hop
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      if (!is.null(progress_callback)) {
        progress_callback("Cancelled by user", 1.0)
      }

      # Convert accumulated data to data frames
      nodes_df <- if (length(nodes_list) > 0) {
        do.call(rbind, lapply(nodes_list, as.data.frame, stringsAsFactors = FALSE))
      } else {
        data.frame(
          paper_id = character(),
          title = character(),
          authors = character(),
          year = integer(),
          venue = character(),
          doi = character(),
          cited_by_count = integer(),
          is_seed = logical(),
          stringsAsFactors = FALSE
        )
      }

      edges_df <- if (length(edges_list) > 0) {
        do.call(rbind, lapply(edges_list, as.data.frame, stringsAsFactors = FALSE))
      } else {
        data.frame(
          from_paper_id = character(),
          to_paper_id = character(),
          stringsAsFactors = FALSE
        )
      }

      return(list(nodes = nodes_df, edges = edges_df, partial = TRUE))
    }

    next_frontier <- character()
    total_fetched <- 0
    frontier_size <- length(current_frontier)

    # Write hop-start progress
    write_progress(progress_file, hop, depth, 0, frontier_size,
                   sprintf("Hop %d of %d: fetching %d papers...", hop, depth, frontier_size))

    # For each paper in current frontier, fetch its citations
    for (fi in seq_along(current_frontier)) {
      frontier_paper <- current_frontier[fi]

      # Write per-paper progress
      write_progress(progress_file, hop, depth, fi, frontier_size,
                     sprintf("Hop %d of %d \u2014 paper %d of %d", hop, depth, fi, frontier_size))

      # Check for interrupt at each frontier paper
      if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
        if (!is.null(progress_callback)) {
          progress_callback("Cancelled by user", 1.0)
        }

        # Convert accumulated data to data frames
        nodes_df <- if (length(nodes_list) > 0) {
          do.call(rbind, lapply(nodes_list, as.data.frame, stringsAsFactors = FALSE))
        } else {
          data.frame(
            paper_id = character(),
            title = character(),
            authors = character(),
            year = integer(),
            venue = character(),
            doi = character(),
            cited_by_count = integer(),
            is_seed = logical(),
            stringsAsFactors = FALSE
          )
        }

        edges_df <- if (length(edges_list) > 0) {
          do.call(rbind, lapply(edges_list, as.data.frame, stringsAsFactors = FALSE))
        } else {
          data.frame(
            from_paper_id = character(),
            to_paper_id = character(),
            stringsAsFactors = FALSE
          )
        }

        return(list(nodes = nodes_df, edges = edges_df, partial = TRUE))
      }
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

  # Write final-phase progress
  write_progress(progress_file, depth, depth, 1, 1, "Discovering cross-links between papers...")

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

  list(nodes = nodes_df, edges = edges_df, partial = FALSE)
}

#' Fetch multi-seed citation network using BFS traversal
#'
#' Builds citation graphs from multiple seed papers, running BFS independently
#' per seed then merging and deduplicating the results. Detects overlap papers
#' (reachable from 2+ seeds) for visual encoding.
#'
#' @param seed_paper_ids Character vector of OpenAlex Work IDs
#' @param email User email for OpenAlex API
#' @param api_key Optional OpenAlex API key
#' @param direction "forward", "backward", or "both"
#' @param depth Number of hops from each seed (1-3)
#' @param node_limit_per_seed Maximum nodes per seed (25-200)
#' @param interrupt_flag Optional path to interrupt flag file
#' @param progress_file Optional path to progress file
#' @return List with nodes (data.frame with is_overlap column) and edges (data.frame)
fetch_multi_seed_citation_network <- function(seed_paper_ids, email, api_key = NULL,
                                               direction = "both", depth = 2,
                                               node_limit_per_seed = 100,
                                               interrupt_flag = NULL,
                                               progress_file = NULL) {
  # Handle single-seed case: delegate to existing function for backward compatibility
  if (length(seed_paper_ids) == 1) {
    result <- fetch_citation_network(
      seed_paper_id = seed_paper_ids[1],
      email = email,
      api_key = api_key,
      direction = direction,
      depth = depth,
      node_limit = node_limit_per_seed,
      progress_callback = NULL,
      interrupt_flag = interrupt_flag,
      progress_file = progress_file
    )

    # Add is_overlap column (all FALSE for single seed)
    result$nodes$is_overlap <- FALSE
    # Community will be detected by compute_layout_positions (walktrap)
    return(result)
  }

  # Multi-seed case: run BFS per seed and merge
  total_seeds <- length(seed_paper_ids)
  per_seed_results <- list()
  any_partial <- FALSE

  for (seed_idx in seq_along(seed_paper_ids)) {
    seed_id <- seed_paper_ids[seed_idx]

    # Write seed-level progress
    write_progress(
      progress_file,
      seed_idx,
      total_seeds,
      0,
      1,
      sprintf("Processing seed %d of %d...", seed_idx, total_seeds)
    )

    # Check for interrupt between seeds
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      any_partial <- TRUE
      break
    }

    # Fetch citation network for this seed
    result <- fetch_citation_network(
      seed_paper_id = seed_id,
      email = email,
      api_key = api_key,
      direction = direction,
      depth = depth,
      node_limit = node_limit_per_seed,
      progress_callback = NULL,
      interrupt_flag = interrupt_flag,
      progress_file = progress_file
    )

    per_seed_results[[seed_id]] <- result

    if (result$partial) {
      any_partial <- TRUE
    }
  }

  # If interrupted before completing any seeds
  if (length(per_seed_results) == 0) {
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
        is_overlap = logical(),
        stringsAsFactors = FALSE
      ),
      edges = data.frame(
        from_paper_id = character(),
        to_paper_id = character(),
        stringsAsFactors = FALSE
      ),
      partial = TRUE
    ))
  }

  # Merge all node dataframes
  all_nodes <- do.call(rbind, lapply(per_seed_results, function(r) r$nodes))

  # Merge all edge dataframes
  all_edges <- do.call(rbind, lapply(per_seed_results, function(r) r$edges))

  # Track which papers appear in which seed's result set (for overlap detection)
  paper_seed_map <- list()
  for (seed_id in names(per_seed_results)) {
    paper_ids <- per_seed_results[[seed_id]]$nodes$paper_id
    for (pid in paper_ids) {
      if (is.null(paper_seed_map[[pid]])) {
        paper_seed_map[[pid]] <- character()
      }
      paper_seed_map[[pid]] <- c(paper_seed_map[[pid]], seed_id)
    }
  }

  # Deduplicate nodes by paper_id (keep first occurrence)
  merged_nodes <- all_nodes[!duplicated(all_nodes$paper_id), ]

  # Deduplicate edges by from->to pair
  merged_edges <- all_edges[!duplicated(paste(all_edges$from_paper_id, all_edges$to_paper_id, sep = "->")), ]

  # Re-mark seeds (prevents lost seed markers as noted in Pitfall 3)
  merged_nodes$is_seed <- merged_nodes$paper_id %in% seed_paper_ids

  # Compute overlap: papers from 2+ seeds (excluding seeds themselves)
  overlap_counts <- sapply(merged_nodes$paper_id, function(pid) {
    length(unique(paper_seed_map[[pid]]))
  })

  merged_nodes$is_overlap <- (overlap_counts >= 2) & !merged_nodes$is_seed

  # Community labels: use primary seed origin for each paper
  merged_nodes$community <- sapply(merged_nodes$paper_id, function(pid) {
    seeds <- paper_seed_map[[pid]]
    if (length(seeds) == 0) return(NA_character_)
    seeds[1]  # Primary seed (first seed that discovered this paper)
  })

  list(
    nodes = merged_nodes,
    edges = merged_edges,
    partial = any_partial
  )
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
    palette_colors <- viridisLite::viridis(100, option = palette)
    middle_color <- palette_colors[50]
    colors <- rep(middle_color, length(years))
    colors[is.na(years)] <- "#999999"
    return(colors)
  }

  # Use 10th percentile as floor so ancient outliers (e.g. Linnaeus 1735)
  # don't compress the modern range. Papers below the floor get pinned
  # to the darkest color; the full gradient spreads across the bulk.
  year_floor <- as.numeric(stats::quantile(valid_years, 0.10, na.rm = TRUE))
  year_ceil <- max(valid_years, na.rm = TRUE)

  if (year_ceil == year_floor) {
    palette_colors <- viridisLite::viridis(100, option = palette)
    middle_color <- palette_colors[50]
    colors <- rep(middle_color, length(years))
    colors[is.na(years)] <- "#999999"
    return(colors)
  }

  # Clamp to floor, then normalize to 0-1
  clamped <- pmax(years, year_floor)
  normalized <- (clamped - year_floor) / (year_ceil - year_floor)

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

  # Update is_seed markers if seed_paper_id is provided
  # (handles both single ID and vector)
  if (!is.null(seed_paper_id)) {
    nodes_df$is_seed <- nodes_df$paper_id %in% seed_paper_id
  }

  # Add visNetwork columns
  nodes_df$id <- nodes_df$paper_id
  nodes_df$label <- NA  # No labels by default (show on hover)
  nodes_df$value <- compute_node_sizes(nodes_df$cited_by_count)

  # Handle missing is_overlap column (old saved networks)
  if (is.null(nodes_df$is_overlap)) {
    nodes_df$is_overlap <- FALSE
  }

  # Shape: star for seeds, diamond for overlap papers, dot for regular
  nodes_df$shape <- ifelse(
    nodes_df$is_seed,
    "star",
    ifelse(
      isTRUE(nodes_df$is_overlap) | (!is.null(nodes_df$is_overlap) & nodes_df$is_overlap),
      "diamond",
      "dot"
    )
  )

  # Node colors: use color.background so visNetwork builds a nested color object.
  # Setting flat `color` + `color.border` crashes vis.js dataframeToD3 because
  # it overwrites the string with a nested path lookup (GH debug 2026-02-25).
  nodes_df$color.background <- map_year_to_color(nodes_df$year, palette)
  nodes_df$color.border <- ifelse(nodes_df$is_seed, "#FFD700", "rgba(205, 214, 244, 0.5)")
  nodes_df$color.highlight.border <- ifelse(nodes_df$is_seed, "#FFD700", "#b4befe")
  nodes_df$color.highlight.background <- nodes_df$color.background
  nodes_df$borderWidth <- ifelse(nodes_df$is_seed, 5, 2)

  # Preserve original paper title.
  # For loaded networks, paper_title may not exist — fall back to title.
  if (is.null(nodes_df$paper_title)) {
    nodes_df$paper_title <- nodes_df$title
  }

  # Sanitize: old saved networks stored tooltip HTML in title column.
  # Extract plain title from between <b>...</b> tags if present.
  has_html <- grepl("<b>", nodes_df$paper_title, fixed = TRUE)
  if (any(has_html)) {
    nodes_df$paper_title[has_html] <- sub(
      ".*?<b>(.*?)</b>.*", "\\1", nodes_df$paper_title[has_html]
    )
  }

  # Extract first author for display
  first_author <- sub(",.*", "", nodes_df$authors)
  author_display <- ifelse(
    grepl(",", nodes_df$authors),
    paste0(first_author, " et al."),
    first_author
  )

  # Tooltip HTML stored in custom column — our onRender JS reads this via innerHTML.
  # NOT stored in 'title' because vis.js renders title as plain text, not HTML.
  nodes_df$tooltip_html <- sprintf(
    "<div style='max-width:300px;word-wrap:break-word'><b>%s</b><br>%s<br>Year: %s<br>Citations: %s</div>",
    htmltools::htmlEscape(nodes_df$paper_title),
    htmltools::htmlEscape(author_display),
    ifelse(is.na(nodes_df$year), "N/A", nodes_df$year),
    nodes_df$cited_by_count
  )

  # Clear title so vis.js does NOT show its default (text-only) tooltip
  nodes_df$title <- NA

  # Edges: visNetwork expects 'from' and 'to' columns
  if (nrow(edges_df) > 0) {
    # Drop self-loops (OpenAlex sometimes lists a paper in its own referenced_works)
    edges_df <- edges_df[edges_df$from_paper_id != edges_df$to_paper_id, ]
    edges_df$from <- edges_df$from_paper_id
    edges_df$to <- edges_df$to_paper_id
    edges_df$arrows <- "to"  # Directional arrows

    # Community-aware edge classification for cluster separation
    # Skip if community column is missing or entirely NA (e.g., old saved networks)
    has_community <- !is.null(nodes_df$community) && any(!is.na(nodes_df$community))
    if (has_community && nrow(edges_df) > 0) {
      node_community <- setNames(nodes_df$community, nodes_df$id)
      from_comm <- node_community[edges_df$from]
      to_comm <- node_community[edges_df$to]

      is_inter <- from_comm != to_comm
      is_inter[is.na(is_inter)] <- TRUE  # Unknown community = treat as inter-cluster

      # Flag for inter-cluster (actual spring length set in module where density scaling is known)
      edges_df$is_inter_cluster <- is_inter

      # Visual encoding: inter-cluster edges are more transparent and dashed
      edges_df$color <- ifelse(
        is_inter,
        "rgba(140, 143, 161, 0.15)",
        "rgba(140, 143, 161, 0.35)"
      )
      edges_df$dashes <- is_inter
    }
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

  # Community detection for single-seed networks (multi-seed already has community from seed_origin)
  if (is.null(nodes_df$community)) {
    g_undirected <- igraph::as.undirected(g, mode = "collapse")
    wt <- igraph::cluster_walktrap(g_undirected)
    membership <- igraph::membership(wt)
    nodes_df$community <- as.character(membership[match(nodes_df$paper_id, names(membership))])
  }

  nodes_df
}
