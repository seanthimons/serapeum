#' Citation Network Module UI
#' @param id Module ID
mod_citation_network_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Include custom CSS
    tags$head(tags$link(rel = "stylesheet", href = "custom.css")),

    # JavaScript handler for progress updates
    tags$script(HTML("
      Shiny.addCustomMessageHandler('updateBuildProgress', function(data) {
        var bar = document.getElementById(data.bar_id);
        if (bar) {
          bar.style.width = data.percent + '%';
          bar.textContent = data.percent + '%';
          bar.setAttribute('aria-valuenow', data.percent);
        }
        var msg = document.getElementById(data.msg_id);
        if (msg) {
          msg.textContent = data.message;
        }
      });
    ")),

    # Top controls bar
    div(
      class = "citation-network-controls mb-3 p-3 bg-body-secondary rounded",
      layout_columns(
        col_widths = c(2, 2, 2, 3, 3),

        # Direction toggle
        div(
          radioButtons(
            ns("direction"),
            tags$span("Direction", title = "Forward: papers that cite the seed. Backward: papers the seed cites. Both: all citation links."),
            choices = c("Forward" = "forward", "Backward" = "backward", "Both" = "both"),
            selected = "both",
            inline = FALSE
          )
        ),

        # Depth slider
        div(
          sliderInput(
            ns("depth"),
            tags$span("Depth", title = "Number of hops from the seed paper. Depth 1 = direct citations only. Higher depths discover more distant connections but take longer."),
            min = 1, max = 3, value = 1, step = 1
          )
        ),

        # Node cap slider
        div(
          sliderInput(
            ns("node_limit"),
            tags$span("Node Cap", title = "Maximum number of papers in the network. When exceeded, only the most-cited papers are kept."),
            min = 5, max = 200, value = 100, step = 5
          )
        ),

        # Build button
        div(
          class = "d-flex align-items-center h-100",
          actionButton(
            ns("build_network"),
            "Build Network",
            class = "btn-primary",
            icon = icon_diagram()
          )
        ),

        # Save button
        div(
          class = "d-flex align-items-center h-100",
          actionButton(
            ns("save_network"),
            "Save Network",
            class = "btn-outline-success",
            icon = icon_save()
          )
        )
      ),

      # Year filter row (hidden until network is built)
      uiOutput(ns("year_filter_panel"))
    ),

    # Main content area with side panel
    layout_columns(
      col_widths = c(8, 4),

      # Left: Graph container
      div(
        class = "citation-network-container position-relative",
        visNetwork::visNetworkOutput(ns("network_graph"), height = "700px"),

        # Collapsible legend overlay with palette selector
        div(
          class = "citation-network-legend",
          id = ns("legend_panel"),
          # Header with toggle
          div(
            class = "legend-header",
            onclick = sprintf(
              "var el = document.getElementById('%s'); el.classList.toggle('collapsed');
               var btn = this.querySelector('.legend-toggle');
               btn.innerHTML = el.classList.contains('collapsed') ? '&#x25C0;' : '&#x25BC;';",
              ns("legend_panel")
            ),
            h6("Legend"),
            tags$button(
              class = "legend-toggle",
              type = "button",
              title = "Toggle legend",
              HTML("&#x25BC;")
            )
          ),
          # Collapsible body
          div(
            class = "legend-body",
            div(
              class = "mb-2",
              selectInput(
                ns("palette"),
                NULL,
                choices = c(
                  "Viridis" = "viridis",
                  "Magma" = "magma",
                  "Plasma" = "plasma",
                  "Inferno" = "inferno",
                  "Cividis" = "cividis"
                ),
                selected = "viridis",
                width = "100%"
              )
            ),
            div(
              class = "mb-2",
              strong("Color:"), " Publication Year",
              # Dynamic gradient rendered server-side
              uiOutput(ns("legend_gradient")),
              div(
                class = "d-flex justify-content-between small text-muted",
                span("Older"), span("Newer")
              )
            ),
            div(
              strong("Size:"), " Citation Count",
              div(class = "small text-muted", "Larger = More Citations")
            ),
            div(
              class = "mt-2",
              icon_star(class = "text-warning"), " = Seed Paper", br(),
              icon_diamond(class = "text-info"), " = Multi-Seed Overlap", br(),
              icon_circle(class = "text-muted"), " = Regular Paper"
            ),
            tags$hr(),
            bslib::input_switch(
              ns("physics_enabled"),
              "Physics Simulation",
              value = TRUE
            ),
          )
        )
      ),

      # Right: Side panel (conditional)
      uiOutput(ns("side_panel"))
    )
  )
}

#' Citation Network Module Server
#' @param id Module ID
#' @param con_r Database connection (reactive)
#' @param config_r Effective config (reactive)
#' @param network_id_r Network ID to load (reactive)
#' @param network_trigger Reactive trigger for network list refresh
mod_citation_network_server <- function(id, con_r, config_r, network_id_r, network_trigger) {
  moduleServer(id, function(input, output, session) {

    # Helper function: Compute influential paper IDs with bridge detection
    compute_trim_ids <- function(nodes, edges) {
      n_nodes <- nrow(nodes)

      # For very small networks, don't trim
      if (n_nodes < 20) {
        return(list(keep_ids = nodes$id, remove_count = 0))
      }

      # Seeds always kept
      seed_ids <- nodes$id[nodes$is_seed]

      # Compute adaptive citation threshold from unfiltered data
      # NOTE: Adaptive percentile threshold — tuneable parameter
      if (n_nodes >= 50) {
        threshold <- quantile(nodes$cited_by_count, 0.75, na.rm = TRUE)
      } else {
        threshold <- quantile(nodes$cited_by_count, 0.50, na.rm = TRUE)
      }

      # Influential papers = seeds + high citation count
      influential_ids <- nodes$id[nodes$cited_by_count >= threshold | nodes$is_seed]

      # Bridge detection (skip for large networks > 500 nodes)
      bridge_ids <- character(0)
      if (n_nodes <= 500) {
        # NOTE: Bridge detection — simplified edge-based approach for citation networks (mostly DAGs).
        # For dense graphs, consider igraph::articulation_points() instead.
        non_influential <- nodes$id[!(nodes$id %in% influential_ids)]

        for (node_id in non_influential) {
          # Check if this node has edges connecting TO influential papers
          has_edge_to_influential <- any(edges$from == node_id & edges$to %in% influential_ids)
          # AND edges connecting FROM influential papers
          has_edge_from_influential <- any(edges$to == node_id & edges$from %in% influential_ids)

          if (has_edge_to_influential && has_edge_from_influential) {
            bridge_ids <- c(bridge_ids, node_id)
          }
        }
      }

      keep_ids <- unique(c(seed_ids, influential_ids, bridge_ids))
      remove_count <- n_nodes - length(keep_ids)

      list(keep_ids = keep_ids, remove_count = remove_count)
    }

    # Helper function: Apply combined year + trim filters
    apply_combined_filters <- function() {
      net_data <- unfiltered_network_data()
      req(net_data)

      nodes <- net_data$nodes
      edges <- net_data$edges

      # Start with all nodes
      year_keep <- rep(TRUE, nrow(nodes))
      trim_keep <- rep(TRUE, nrow(nodes))

      # Apply year filter
      range <- input$year_filter
      include_null <- input$include_unknown_year_network
      if (!is.null(range) && !is.null(include_null)) {
        # Seeds always kept
        year_keep <- nodes$is_seed
        if (include_null) {
          year_keep <- year_keep | is.na(nodes$year) | (nodes$year >= range[1] & nodes$year <= range[2])
        } else {
          year_keep <- year_keep | (!is.na(nodes$year) & nodes$year >= range[1] & nodes$year <= range[2])
        }
      }

      # Apply trim filter
      if (isTRUE(input$trim_enabled)) {
        result <- compute_trim_ids(nodes, edges)
        trim_keep <- nodes$id %in% result$keep_ids
      }

      # Combine with AND logic
      final_keep <- year_keep & trim_keep
      filtered_nodes <- nodes[final_keep, ]

      # Keep edges where both endpoints survive
      filtered_node_ids <- filtered_nodes$id
      filtered_edges <- edges[edges$from %in% filtered_node_ids & edges$to %in% filtered_node_ids, ]

      # Update display data
      current_network_data(list(
        nodes = filtered_nodes,
        edges = filtered_edges,
        metadata = net_data$metadata
      ))

      filtered_nodes
    }

    # Helper: compute density-scaled physics parameters
    compute_physics_params <- function(n_nodes, n_edges) {
      gravity <- if (n_nodes <= 30) -120
                 else if (n_nodes <= 100) -200
                 else if (n_nodes <= 200) -350
                 else -500
      spring <- if (n_nodes <= 30) 350
                else if (n_nodes <= 100) 450
                else if (n_nodes <= 200) 600
                else 800
      edge_ratio <- n_edges / max(n_nodes, 1)
      if (edge_ratio > 3) {
        gravity <- gravity * 1.5
        spring <- spring * 1.3
      }
      stab_iters <- if (n_nodes <= 50) 300
                    else if (n_nodes <= 150) 600
                    else 1000
      list(gravity = gravity, spring = spring, stab_iters = stab_iters)
    }

    # Current network data (may be filtered)
    current_network_data <- reactiveVal(NULL)
    # Unfiltered snapshot — set when network is built/loaded, never mutated by filters
    unfiltered_network_data <- reactiveVal(NULL)
    current_seed_ids <- reactiveVal(character())
    source_notebook_id <- reactiveVal(NULL)
    selected_node_id <- reactiveVal(NULL)
    # Physics state tracking
    ambient_drift_active <- reactiveVal(FALSE)
    # TRUE when the current render used saved positions (physics disabled at render).
    # Prevents the data-change observer from forcing physics ON and causing a
    # singularity collapse — loaded graphs should stay frozen until the user
    # explicitly toggles physics.
    rendered_with_positions <- reactiveVal(FALSE)

    # Progressive loading state
    progressive_nodes <- reactiveVal(NULL)
    progressive_edges <- reactiveVal(NULL)

    # Async task state
    current_interrupt_flag <- reactiveVal(NULL)
    current_progress_file <- reactiveVal(NULL)
    progress_poller <- reactiveVal(NULL)

    # Create ExtendedTask for async network building
    network_task <- ExtendedTask$new(function(seed_ids, email, direction, depth, node_limit_per_seed, interrupt_flag, progress_file, app_dir) {
      mirai::mirai({
        # Source required files in isolated process
        source(file.path(app_dir, "R", "interrupt.R"))
        source(file.path(app_dir, "R", "api_openalex.R"))
        source(file.path(app_dir, "R", "citation_network.R"))

        # Build network with interrupt and progress support
        result <- fetch_multi_seed_citation_network(
          seed_ids, email, api_key = NULL,
          direction = direction, depth = depth,
          node_limit_per_seed = node_limit_per_seed,
          interrupt_flag = interrupt_flag,
          progress_file = progress_file
        )

        # Compute layout for full results only
        if (!isTRUE(result$partial) && nrow(result$nodes) > 0) {
          result$nodes <- compute_layout_positions(result$nodes, result$edges)
        }

        result
      }, seed_ids = seed_ids, email = email, direction = direction,
         depth = depth, node_limit_per_seed = node_limit_per_seed,
         interrupt_flag = interrupt_flag, progress_file = progress_file, app_dir = app_dir)
    })

    # Initialize palette from DB setting
    observe({
      palette <- get_db_setting(con_r(), "network_palette") %||% "viridis"
      updateSelectInput(session, "palette", selected = palette)
    }) |> bindEvent(con_r(), once = TRUE)

    # Year filter panel — only shown when a network exists
    output$year_filter_panel <- renderUI({
      net_data <- unfiltered_network_data()
      req(net_data)
      ns <- session$ns

      # FILT-01: Compute dynamic year bounds from actual network data
      valid_years <- net_data$nodes$year[!is.na(net_data$nodes$year)]
      if (length(valid_years) > 0) {
        min_year <- min(valid_years)
        max_year <- max(valid_years)
      } else {
        min_year <- 1900
        max_year <- as.integer(format(Sys.Date(), "%Y"))
      }

      div(
        class = "mt-2 pt-2 border-top",
        layout_columns(
          col_widths = c(5, 3, 4),
          div(
            sliderInput(
              ns("year_filter"),
              tags$span("Year Range",
                        title = "Filter network nodes by publication year. Adjust range then click Apply to update."),
              min = min_year, max = max_year, value = c(min_year, max_year),
              step = 1, sep = "", ticks = FALSE
            )
          ),
          div(
            class = "pt-4",
            bslib::input_switch(ns("include_unknown_year_network"), "Include unknown year", value = TRUE),
            bslib::input_switch(ns("trim_enabled"), "Trim to Influential", value = FALSE),
            uiOutput(ns("trim_label"))
          ),
          div(
            class = "pt-3",
            actionButton(ns("apply_year_filter"), "Apply Year Filter",
                         class = "btn-outline-primary btn-sm", icon = icon_filter()),
            uiOutput(ns("year_filter_preview"))
          )
        )
      )
    })

    # Dynamic slider bounds from unfiltered data (stable — not affected by filtering)
    observe({
      net_data <- unfiltered_network_data()
      req(net_data)

      nodes <- net_data$nodes
      valid_years <- nodes$year[!is.na(nodes$year)]

      if (length(valid_years) == 0) {
        min_year <- 1900
        max_year <- 2026
      } else {
        min_year <- min(valid_years)
        max_year <- max(valid_years)
      }

      updateSliderInput(session, "year_filter",
                        min = min_year, max = max_year,
                        value = c(min_year, max_year))
    })

    # Filter preview — counts against unfiltered data so preview is always accurate
    output$year_filter_preview <- renderUI({
      net_data <- unfiltered_network_data()
      if (is.null(net_data)) return(NULL)

      range <- input$year_filter
      include_null <- input$include_unknown_year_network
      if (is.null(range) || is.null(include_null)) return(NULL)

      nodes <- net_data$nodes
      # Seed paper is always kept
      is_kept <- nodes$is_seed
      if (include_null) {
        is_kept <- is_kept | is.na(nodes$year) | (nodes$year >= range[1] & nodes$year <= range[2])
      } else {
        is_kept <- is_kept | (!is.na(nodes$year) & nodes$year >= range[1] & nodes$year <= range[2])
      }

      div(
        class = "mt-1 small text-muted",
        paste(sum(is_kept), "of", nrow(nodes), "nodes")
      )
    })

    # Trim label — shows removal count when enabled
    output$trim_label <- renderUI({
      net_data <- unfiltered_network_data()
      if (is.null(net_data)) return(NULL)
      if (!isTRUE(input$trim_enabled)) return(NULL)

      result <- compute_trim_ids(net_data$nodes, net_data$edges)

      div(class = "small text-muted mt-1",
          paste("Removes", result$remove_count, "papers"))
    })

    # Auto-enable trim for 500+ node networks
    observe({
      net_data <- unfiltered_network_data()
      req(net_data)
      if (nrow(net_data$nodes) >= 500) {
        bslib::update_switch("trim_enabled", value = TRUE, session = session)
      }
    }, priority = -1)

    # Apply year filter — filters from unfiltered snapshot, never destructive
    observeEvent(input$apply_year_filter, {
      net_data <- unfiltered_network_data()
      req(net_data)

      filtered_nodes <- apply_combined_filters()

      showNotification(
        paste("Filters applied:", nrow(filtered_nodes), "of", nrow(net_data$nodes), "nodes shown"),
        type = "message"
      )
    })

    # Dynamic legend gradient that updates with palette
    output$legend_gradient <- renderUI({
      palette <- input$palette %||% "viridis"
      gradient_colors <- tryCatch({
        cols <- viridisLite::viridis(5, option = palette)
        paste(cols, collapse = ", ")
      }, error = function(e) {
        "#440154FF, #3B528BFF, #21908CFF, #5DC863FF, #FDE725FF"
      })
      div(
        class = "color-gradient mt-1",
        style = paste0(
          "height: 20px; background: linear-gradient(to right, ",
          gradient_colors,
          "); border-radius: 3px;"
        )
      )
    })

    # Build network button handler
    observeEvent(input$build_network, {
      req(length(current_seed_ids()) > 0)

      # Create interrupt and progress files
      flag_file <- create_interrupt_flag(session$token)
      current_interrupt_flag(flag_file)
      prog_file <- create_progress_file(session$token)
      current_progress_file(prog_file)

      # Determine modal title based on number of seeds
      modal_title <- if (length(current_seed_ids()) > 1) {
        "Building Multi-Seed Citation Network"
      } else {
        "Building Citation Network"
      }

      # Show progress modal
      showModal(modalDialog(
        title = tagList(icon_spinner(class = "fa-spin"), modal_title),
        tags$div(
          class = "progress",
          style = "height: 25px;",
          tags$div(
            id = session$ns("build_progress_bar"),
            class = "progress-bar progress-bar-striped progress-bar-animated",
            role = "progressbar",
            style = "width: 5%;",
            `aria-valuenow` = "5",
            `aria-valuemin` = "0",
            `aria-valuemax` = "100",
            "5%"
          )
        ),
        tags$div(
          id = session$ns("build_progress_message"),
          class = "text-muted mt-2",
          "Initializing..."
        ),
        footer = actionButton(session$ns("cancel_build"), "Stop", class = "btn-warning", icon = icon_stop()),
        easyClose = FALSE,
        size = "m"
      ))

      # Invoke async task
      network_task$invoke(
        seed_ids = current_seed_ids(),
        email = config_r()$openalex$email,
        direction = input$direction,
        depth = input$depth,
        node_limit_per_seed = input$node_limit,
        interrupt_flag = flag_file,
        progress_file = prog_file,
        app_dir = getwd()
      )

      # Start polling observer — reads real progress from file
      poller <- observe({
        invalidateLater(1000)  # every 1 second
        pf <- isolate(current_progress_file())
        prog <- read_progress(pf)
        session$sendCustomMessage("updateBuildProgress", list(
          bar_id = session$ns("build_progress_bar"),
          msg_id = session$ns("build_progress_message"),
          percent = max(prog$pct, 5),
          message = prog$message
        ))
      })
      progress_poller(poller)  # Store so cancel/result handlers can destroy it
    })

    # Cancel button handler
    observeEvent(input$cancel_build, {
      # Signal interrupt to the running mirai process via file flag
      flag_file <- current_interrupt_flag()
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }

      # Stop progress poller
      poller <- progress_poller()
      if (!is.null(poller)) {
        poller$destroy()
        progress_poller(NULL)
      }

      # Update modal to show cancelling state
      session$sendCustomMessage("updateBuildProgress", list(
        bar_id = session$ns("build_progress_bar"),
        msg_id = session$ns("build_progress_message"),
        percent = 100,
        message = "Stopping... waiting for partial results"
      ))
    })

    # Task result handler
    observe({
      result <- network_task$result()
      req(result)

      # Destroy progress poller
      poller <- progress_poller()
      if (!is.null(poller)) {
        poller$destroy()
        progress_poller(NULL)
      }

      # Close modal
      removeModal()

      # Clean up interrupt flag and progress file
      flag_file <- current_interrupt_flag()
      clear_interrupt_flag(flag_file)
      current_interrupt_flag(NULL)
      clear_progress_file(current_progress_file())
      current_progress_file(NULL)

      # Handle empty results
      if (is.null(result$nodes) || nrow(result$nodes) == 0) {
        showNotification("No papers found in citation network", type = "warning")
        return()
      }

      # Compute layout for partial results (skipped in mirai for partials)
      if (isTRUE(result$partial)) {
        # Filter edges to only include nodes that were collected before cancellation
        valid_ids <- result$nodes$paper_id
        result$edges <- result$edges[
          result$edges$from_paper_id %in% valid_ids & result$edges$to_paper_id %in% valid_ids, , drop = FALSE
        ]
        result$nodes <- compute_layout_positions(result$nodes, result$edges)
      }

      # Build visualization data — reuse exact same pattern as current code
      palette <- input$palette %||% "viridis"
      seed_ids <- current_seed_ids()
      viz_data <- build_network_data(result$nodes, result$edges, palette, seed_ids)

      # Store network — same pattern as current code
      net_list <- list(
        nodes = viz_data$nodes,
        edges = viz_data$edges,
        metadata = list(
          seed_paper_id = seed_ids[1],  # backward compat
          seed_paper_ids = seed_ids,
          seed_paper_title = viz_data$nodes$paper_title[viz_data$nodes$is_seed][1],
          source_notebook_id = source_notebook_id(),
          direction = input$direction,
          depth = input$depth,
          node_limit = input$node_limit,
          palette = palette,
          partial = isTRUE(result$partial)
        )
      )
      current_network_data(net_list)
      unfiltered_network_data(net_list)

      # Show different notifications for partial vs full results
      if (isTRUE(result$partial)) {
        showNotification(
          sprintf("Partial network: %d nodes, %d edges (stopped by user)",
                  nrow(viz_data$nodes), nrow(viz_data$edges)),
          type = "message", duration = 8
        )
      } else {
        showNotification(
          sprintf("Network built: %d papers from %d seed%s",
                  nrow(viz_data$nodes), length(seed_ids),
                  if (length(seed_ids) == 1) "" else "s"),
          type = "message"
        )
      }
    })

    # Render network graph
    output$network_graph <- visNetwork::renderVisNetwork({
      net_data <- current_network_data()
      req(net_data)

      nodes <- net_data$nodes
      edges <- net_data$edges

      # Check if this is a loaded network (has pre-computed positions)
      has_positions <- !is.null(nodes$x_position) && !is.null(nodes$y_position)
      # Track render mode so the data-change observer knows not to force physics ON
      # for loaded graphs (which would cause singularity collapse — see PHYS-01)
      rendered_with_positions(has_positions)

      if (has_positions) {
        # Use saved positions
        nodes$x <- nodes$x_position
        nodes$y <- nodes$y_position
      }

      # Compute physics params for edge length assignment (needed before visNetwork call)
      params <- compute_physics_params(nrow(nodes), nrow(edges))

      # Set per-edge spring lengths for community-aware cluster separation
      # NOTE: Inter-cluster multiplier (2.5x) — tuneable. Higher values (3-4x) push
      # clusters further apart. Single-seed networks may need a higher multiplier
      # since citation graphs are densely interconnected. Multi-seed networks see
      # clear separation at 2.5x. If separation is too weak, increase; if clusters
      # feel disconnected, decrease.
      if ("is_inter_cluster" %in% colnames(edges) && nrow(edges) > 0) {
        edges$length <- ifelse(edges$is_inter_cluster, params$spring * 2.5, params$spring)
      }

      # Create visNetwork (edges must have length column set before this call)
      vn <- visNetwork::visNetwork(nodes, edges, width = "100%", height = "700px")

      # Configure physics based on whether we have positions
      if (has_positions) {
        # Disable physics for instant render of saved networks
        vn <- vn |>
          visNetwork::visPhysics(
            enabled = FALSE,
            stabilization = FALSE
          )
      } else {
        # Enable physics for initial build, auto-freeze after stabilization
        vn <- vn |>
          visNetwork::visPhysics(
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = params$gravity,
              springLength = params$spring,
              damping = 0.4
            ),
            stabilization = list(iterations = params$stab_iters)
          ) |>
          visNetwork::visLayout(randomSeed = 42)
      }

      # Configure appearance
      vn <- vn |>
        visNetwork::visEdges(
          arrows = "to",
          color = list(
            color = "rgba(140, 143, 161, 0.35)",
            highlight = "rgba(140, 143, 161, 0.7)"
          ),
          smooth = list(type = "continuous")
        ) |>
        visNetwork::visNodes(
          font = list(size = 0),  # No labels by default
          scaling = list(
            min = 10,
            max = 100,
            label = list(enabled = FALSE),
            customScalingFunction = htmlwidgets::JS(
              "function(min, max, total, value) {
                if (max === min) { return 0.5; }
                return (value - min) / (max - min);
              }"
            )
          )
        ) |>
        visNetwork::visInteraction(
          hover = TRUE,
          tooltipDelay = 200,
          navigationButtons = TRUE
        ) |>
        visNetwork::visEvents(
          click = sprintf("function(params) {
            if (params.nodes.length > 0) {
              Shiny.setInputValue('%s', params.nodes[0], {priority: 'event'});
            }
          }", session$ns("node_clicked")),
          stabilizationIterationsDone = sprintf("function() {
            Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
          }", session$ns("stabilization_done")),
          dragStart = sprintf("function(params) {
            Shiny.setInputValue('%s', true, {priority: 'event'});
          }", session$ns("user_interacting")),
          dragEnd = sprintf("function(params) {
            Shiny.setInputValue('%s', false, {priority: 'event'});
          }", session$ns("user_interacting"))
        ) |>
        visNetwork::visOptions(
          highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)
        ) |>
        # Custom tooltip — renders HTML, handles containment & dark mode
        htmlwidgets::onRender("
          function(el, x) {
            var container = el.closest('.citation-network-container') || el;
            var network = HTMLWidgets.getInstance(el).network;
            if (!network) return;

            // Create custom tooltip element inside the position:relative container
            var tip = document.createElement('div');
            tip.style.cssText = 'position:absolute;display:none;z-index:1000;max-width:300px;' +
              'word-wrap:break-word;padding:8px 12px;border-radius:0.5rem;' +
              'pointer-events:none;font-size:14px;line-height:1.4;';
            container.appendChild(tip);

            var mx = 0, my = 0;

            function styleTip() {
              var dark = document.documentElement.getAttribute('data-bs-theme') === 'dark';
              if (dark) {
                tip.style.backgroundColor = '#313244';
                tip.style.color = '#cdd6f4';
                tip.style.border = '1px solid #6c7086';
                tip.style.boxShadow = '0 4px 12px rgba(0,0,0,0.4)';
              } else {
                tip.style.backgroundColor = '#f5f4ed';
                tip.style.color = '#000';
                tip.style.border = '1px solid #808074';
                tip.style.boxShadow = '3px 3px 10px rgba(0,0,0,0.2)';
              }
            }

            function positionTip() {
              var cW = container.clientWidth;
              var cH = container.clientHeight;
              var tW = tip.offsetWidth;
              var tH = tip.offsetHeight;

              var left = mx + 15;
              var top = my + 15;

              // Clamp right — flip to left of cursor
              if (left + tW > cW - 8) left = mx - tW - 10;
              if (left < 8) left = 8;

              // Clamp bottom — flip above cursor
              if (top + tH > cH - 8) top = my - tH - 10;
              if (top < 8) top = 8;

              tip.style.left = left + 'px';
              tip.style.top = top + 'px';
            }

            // Track mouse position relative to container
            el.addEventListener('mousemove', function(e) {
              var r = container.getBoundingClientRect();
              mx = e.clientX - r.left;
              my = e.clientY - r.top;
              if (tip.style.display !== 'none') positionTip();
            });

            network.on('hoverNode', function(params) {
              var node = network.body.data.nodes.get(params.node);
              if (!node || !node.tooltip_html) return;
              tip.innerHTML = node.tooltip_html;
              styleTip();
              tip.style.display = 'block';
              positionTip();
            });

            network.on('blurNode', function() { tip.style.display = 'none'; });
            network.on('dragStart', function() { tip.style.display = 'none'; });
            network.on('zoom', function() { tip.style.display = 'none'; });
          }
        ")

      vn
    })

    # Live-recolor nodes when palette changes
    observeEvent(input$palette, {
      net_data <- current_network_data()
      req(net_data)

      palette <- input$palette
      nodes <- net_data$nodes

      # Recompute colors with new palette
      new_colors <- map_year_to_color(nodes$year, palette)
      nodes$color.background <- new_colors
      nodes$color.highlight.background <- new_colors

      # Update stored data
      net_data$nodes <- nodes
      net_data$metadata$palette <- palette
      current_network_data(net_data)

      # Also update unfiltered snapshot so next Apply uses new colors
      uf_data <- unfiltered_network_data()
      if (!is.null(uf_data)) {
        uf_colors <- map_year_to_color(uf_data$nodes$year, palette)
        uf_data$nodes$color.background <- uf_colors
        uf_data$nodes$color.highlight.background <- uf_colors
        uf_data$metadata$palette <- palette
        unfiltered_network_data(uf_data)
      }

      # Also save palette to DB so settings stays in sync
      tryCatch(
        save_db_setting(con_r(), "network_palette", palette),
        error = function(e) NULL
      )

      # Update via proxy (no full re-render)
      visNetwork::visNetworkProxy(session$ns("network_graph")) |>
        visNetwork::visUpdateNodes(nodes[, c("id", "color.background",
                                              "color.highlight.background",
                                              "value", "shape", "borderWidth",
                                              "color.border",
                                              "color.highlight.border")])
    }, ignoreInit = TRUE)

    # Debounced trim toggle observer
    trim_debounced <- reactive({ input$trim_enabled }) |> debounce(300)
    observeEvent(trim_debounced(), {
      net_data <- unfiltered_network_data()
      req(net_data)
      apply_combined_filters()
    }, ignoreInit = TRUE)

    # Debounced physics toggle to prevent rapid-click glitches
    physics_toggle_debounced <- reactive({
      input$physics_enabled
    }) |> debounce(300)  # NOTE: Debounce delay — tuneable. Prevents rapid toggle glitches

    # PHYS-01: Debounced physics toggle with position validation (prevents singularity collapse)
    observeEvent(physics_toggle_debounced(), {
      enabled <- physics_toggle_debounced()
      req(!is.null(enabled))
      net_data <- current_network_data()
      req(net_data)

      if (enabled) {
        # PHYS-01: Re-enable physics with the same forceAtlas2Based solver used
        # for fresh builds. Calling visPhysics(enabled = TRUE) alone uses vis.js
        # defaults (barnesHut), whose gravity pulls all nodes to (0,0) — the
        # singularity collapse bug. Passing explicit solver params ensures nodes
        # maintain their spread and simulate naturally from current positions.
        params <- compute_physics_params(nrow(net_data$nodes), nrow(net_data$edges))

        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(
            enabled = TRUE,
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = params$gravity,
              springLength = params$spring,
              damping = 0.4
            ),
            stabilization = FALSE  # Don't re-stabilize — resume from current positions
          )
      } else {
        # Instant freeze — nodes stop immediately where they are
        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(enabled = FALSE)
        ambient_drift_active(FALSE)
      }
    }, ignoreInit = TRUE)

    # PHYS-02: Stabilization handler — conditional freeze/drift based on network size
    observeEvent(input$stabilization_done, {
      net_data <- current_network_data()
      req(net_data)

      n_nodes <- nrow(net_data$nodes)

      if (n_nodes <= 20) {  # NOTE: Ambient drift threshold — tuneable
        # Enable gentle ambient drift for small networks
        ambient_drift_active(TRUE)
        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(
            enabled = TRUE,
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = -50,
              centralGravity = 0.005,
              damping = 0.25  # NOTE: Drift speed — tuneable. Lower damping = longer orbit (~30-60s). centralGravity keeps nodes loosely centered.
            )
          )
      } else {
        # Freeze large networks after stabilization
        ambient_drift_active(FALSE)
        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(enabled = FALSE)
      }
    }, ignoreInit = TRUE)

    # Interaction-aware drift pausing
    observeEvent(input$user_interacting, {
      if (isTRUE(input$user_interacting) && ambient_drift_active()) {
        # Temporarily disable physics during interaction
        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(enabled = FALSE)
      }
    }, ignoreInit = TRUE)

    # Debounced interaction end — resume drift after user stops interacting
    interaction_ended_debounced <- reactive({
      input$user_interacting
    }) |> debounce(1000)  # NOTE: Resume delay after interaction — tuneable

    observeEvent(interaction_ended_debounced(), {
      if (isFALSE(interaction_ended_debounced()) &&
          ambient_drift_active() &&
          isTRUE(physics_toggle_debounced())) {
        # Resume ambient drift after user interaction ends
        visNetwork::visNetworkProxy(session$ns("network_graph")) |>
          visNetwork::visPhysics(
            enabled = TRUE,
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = -50,
              centralGravity = 0.005,
              damping = 0.25
            )
          )
      }
    }, ignoreInit = TRUE)

    # Reset physics state when network data changes.
    # PHYS-01: Only force physics ON for fresh builds (no saved positions).
    # Loaded graphs render with physics disabled; forcing the toggle ON here
    # would re-enable physics via the debounced toggle observer, causing vis.js
    # to run a new simulation with default solver params → singularity collapse.
    # Instead, loaded graphs set the toggle to OFF to match their rendered state.
    #
    # NOTE: We check for positions directly on the data rather than using
    # rendered_with_positions(), because this observer fires BEFORE
    # renderVisNetwork re-executes (Shiny flush cycle: observers before outputs).
    observeEvent(current_network_data(), {
      ambient_drift_active(FALSE)
      net_data <- current_network_data()
      has_saved_positions <- !is.null(net_data$nodes$x_position) &&
        !is.null(net_data$nodes$y_position)
      if (has_saved_positions) {
        # Loaded graph — physics will be disabled at render, toggle must match
        bslib::update_switch("physics_enabled", value = FALSE, session = session)
      } else {
        # Fresh build — physics is running for initial layout, toggle should be ON
        bslib::update_switch("physics_enabled", value = TRUE, session = session)
      }
    }, ignoreInit = TRUE, ignoreNULL = TRUE)

    # Handle node click
    observeEvent(input$node_clicked, {
      selected_node_id(input$node_clicked)
    })

    # Render side panel with tabs
    output$side_panel <- renderUI({
      net_data <- current_network_data()
      if (is.null(net_data)) return(NULL)

      ns <- session$ns
      notebook_id <- source_notebook_id()

      div(
        class = "citation-network-side-panel",
        navset_card_tab(
          id = ns("side_panel_tabs"),

          nav_panel(
            title = "Paper Details",
            value = "details",
            uiOutput(ns("paper_details_content"))
          ),

          # Only show Missing Papers tab when there's a source notebook
          if (!is.null(notebook_id)) {
            nav_panel(
              title = tagList("Missing Papers ", uiOutput(ns("missing_count_badge"), inline = TRUE)),
              value = "missing",
              uiOutput(ns("missing_papers_content"))
            )
          }
        )
      )
    })

    # Render paper details content
    output$paper_details_content <- renderUI({
      node_id <- selected_node_id()
      ns <- session$ns

      if (is.null(node_id)) {
        return(div(
          class = "text-muted p-3 text-center",
          icon_mouse_pointer(),
          br(), br(),
          "Click a node to see paper details"
        ))
      }

      net_data <- current_network_data()
      req(net_data)

      # Find node data
      node <- net_data$nodes[net_data$nodes$id == node_id, ]
      if (nrow(node) == 0) return(NULL)

      tagList(
        div(
          class = "d-flex justify-content-between align-items-center mb-3",
          h5(class = "mb-0", icon_file_alt(), " Paper Details"),
          actionLink(ns("close_panel"), icon_times())
        ),

        h5(node$paper_title),

        # Authors
        div(
          class = "mb-2",
          strong("Authors: "),
          node$authors
        ),

        # Year
        div(
          class = "mb-2",
          strong("Year: "),
          if (is.na(node$year)) "N/A" else node$year
        ),

        # Venue
        if (!is.na(node$venue)) {
          div(
            class = "mb-2",
            strong("Venue: "),
            node$venue
          )
        },

        # Citation count
        div(
          class = "mb-2",
          strong("Citations: "),
          node$cited_by_count
        ),

        # DOI link
        if (!is.na(node$doi)) {
          div(
            class = "mb-3",
            strong("DOI: "),
            tags$a(
              href = paste0("https://doi.org/", node$doi),
              target = "_blank",
              node$doi,
              icon_external_link_alt(class = "ms-1 small")
            )
          )
        },

        hr(),

        # Abstract (fetch on demand)
        div(
          class = "mb-3",
          strong("Abstract:"),
          div(
            class = "mt-2 small",
            uiOutput(ns("node_abstract"))
          )
        ),

        hr(),

        # Actions
        div(
          class = "d-grid gap-2",
          actionButton(
            ns("explore_from_node"),
            "Explore from here",
            class = "btn-primary",
            icon = icon_diagram()
          )
        )
      )
    })

    # Compute missing papers reactively
    missing_papers_data <- reactive({
      net_data <- current_network_data()
      req(net_data)
      notebook_id <- source_notebook_id()
      if (is.null(notebook_id)) return(NULL)

      # Get all paper_ids in the network (exclude seed papers — they're already in notebook)
      network_paper_ids <- net_data$nodes$paper_id[!net_data$nodes$is_seed]

      if (length(network_paper_ids) == 0) return(data.frame())

      # Set-difference query: network papers NOT in notebook
      con <- con_r()
      notebook_paper_ids <- dbGetQuery(con,
        "SELECT paper_id FROM abstracts WHERE notebook_id = ?",
        list(notebook_id)
      )$paper_id

      missing_ids <- setdiff(network_paper_ids, notebook_paper_ids)
      if (length(missing_ids) == 0) return(data.frame())

      # Get details from network nodes data (already have title, authors, year, citations)
      missing_nodes <- net_data$nodes[net_data$nodes$paper_id %in% missing_ids,
                   c("paper_id", "paper_title", "authors", "year", "cited_by_count", "doi", "is_overlap"),
                   drop = FALSE]

      # Sort: overlap papers first (more interesting), then by citation count
      missing_nodes <- missing_nodes[order(-as.integer(missing_nodes$is_overlap), -missing_nodes$cited_by_count), ]

      missing_nodes
    })

    # Badge showing missing paper count
    output$missing_count_badge <- renderUI({
      mp <- missing_papers_data()
      if (is.null(mp) || nrow(mp) == 0) return(NULL)
      span(class = "badge bg-info", nrow(mp))
    })

    # Render missing papers content
    output$missing_papers_content <- renderUI({
      ns <- session$ns
      notebook_id <- source_notebook_id()

      if (is.null(notebook_id)) {
        return(div(class = "text-muted p-3",
          "No source notebook — network was built from sidebar seed search.",
          br(), br(),
          "To see missing papers, seed the network from a search notebook or BibTeX import."
        ))
      }

      mp <- missing_papers_data()
      if (is.null(mp) || nrow(mp) == 0) {
        return(div(class = "text-muted p-3",
          icon_check_circle(class = "text-success"),
          " All network papers are already in your notebook."
        ))
      }

      tagList(
        div(class = "p-2 small text-muted",
          paste(nrow(mp), "papers found in the network but not in your notebook.")
        ),
        div(
          style = "max-height: 550px; overflow-y: auto;",
          lapply(seq_len(nrow(mp)), function(i) {
            paper <- mp[i, ]
            div(
              class = "border-bottom p-2",
              div(
                class = "d-flex justify-content-between align-items-start",
                div(
                  strong(class = "small", paper$paper_title),
                  if (isTRUE(paper$is_overlap)) {
                    span(class = "badge bg-info ms-1", "overlap")
                  }
                ),
                tags$button(
                  class = "btn btn-sm btn-outline-primary ms-2 flex-shrink-0",
                  onclick = sprintf(
                    "Shiny.setInputValue('%s', '%s', {priority: 'event'});",
                    ns("import_missing_paper"), paper$paper_id
                  ),
                  icon_add(), " Import"
                )
              ),
              div(class = "small text-muted", paper$authors),
              div(class = "small text-muted",
                paste0(
                  if (!is.na(paper$year)) paste("Year:", paper$year) else "",
                  if (!is.na(paper$cited_by_count)) paste(" | Citations:", paper$cited_by_count) else ""
                )
              )
            )
          })
        )
      )
    })

    # Import missing paper handler
    observeEvent(input$import_missing_paper, {
      paper_id <- input$import_missing_paper
      notebook_id <- source_notebook_id()
      req(paper_id, notebook_id)

      config <- config_r()
      email <- config$openalex$email

      tryCatch({
        # Fetch full paper details from OpenAlex
        paper <- get_paper(paper_id, email, api_key = NULL)
        if (is.null(paper)) {
          showNotification("Could not fetch paper details", type = "error")
          return()
        }

        # Add to notebook
        create_abstract(
          con_r(), notebook_id, paper$paper_id, paper$title,
          paper$authors, paper$abstract,
          paper$year, paper$venue, paper$pdf_url,
          keywords = paper$keywords,
          work_type = paper$work_type,
          work_type_crossref = paper$work_type_crossref,
          oa_status = paper$oa_status,
          is_oa = paper$is_oa,
          cited_by_count = paper$cited_by_count,
          referenced_works_count = paper$referenced_works_count,
          fwci = paper$fwci,
          doi = paper$doi
        )

        showNotification(
          paste("Imported:", substr(paper$title, 1, 60), "..."),
          type = "message"
        )

        # Refresh missing papers list by invalidating reactive
        # The missing_papers_data reactive will re-query and the imported paper will be excluded
      }, error = function(e) {
        showNotification(paste("Import failed:", e$message), type = "error")
      })
    })

    # Fetch abstract for selected node
    output$node_abstract <- renderUI({
      node_id <- selected_node_id()
      req(node_id)

      config <- config_r()
      email <- config$openalex$email

      # Fetch paper details from OpenAlex
      paper <- tryCatch({
        get_paper(node_id, email, api_key = NULL)
      }, error = function(e) NULL)

      if (is.null(paper) || is.null(paper$abstract) || is.na(paper$abstract)) {
        return(div(class = "text-muted fst-italic", "No abstract available"))
      }

      div(paper$abstract)
    })

    # Close side panel
    observeEvent(input$close_panel, {
      selected_node_id(NULL)
    })

    # Explore from selected node
    observeEvent(input$explore_from_node, {
      node_id <- selected_node_id()
      req(node_id)

      # Update seed and rebuild (single-seed mode, no notebook association)
      current_seed_ids(c(node_id))
      source_notebook_id(NULL)
      selected_node_id(NULL)  # Close panel

      # Trigger build
      shiny::updateActionButton(session, "build_network", label = "Build Network")
      showNotification("New seed paper set. Click 'Build Network' to rebuild.", type = "message")
    })

    # Save network
    observeEvent(input$save_network, {
      net_data <- current_network_data()
      req(net_data)

      showModal(modalDialog(
        title = "Save Citation Network",
        textInput(
          session$ns("network_name"),
          "Network Name",
          placeholder = "e.g., Deep Learning Citations"
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("confirm_save"), "Save", class = "btn-primary")
        )
      ))
    })

    # Confirm save
    observeEvent(input$confirm_save, {
      req(input$network_name)
      name <- trimws(input$network_name)
      if (nchar(name) == 0) return()

      net_data <- current_network_data()
      req(net_data)

      tryCatch({
        # Ensure positions are computed
        if (is.null(net_data$nodes$x) || is.null(net_data$nodes$y)) {
          net_data$nodes <- compute_layout_positions(net_data$nodes, net_data$edges)
        }

        # Save to database
        network_id <- save_network(
          con_r(),
          id = NULL,
          name = name,
          seed_paper_id = net_data$metadata$seed_paper_id,
          seed_paper_title = net_data$metadata$seed_paper_title,
          direction = net_data$metadata$direction,
          depth = net_data$metadata$depth,
          node_limit = net_data$metadata$node_limit,
          palette = net_data$metadata$palette,
          nodes_df = net_data$nodes,
          edges_df = net_data$edges,
          seed_paper_ids = net_data$metadata$seed_paper_ids,
          source_notebook_id = net_data$metadata$source_notebook_id
        )

        removeModal()
        showNotification(paste("Network saved:", name), type = "message")

        # Trigger sidebar refresh
        if (!is.null(network_trigger)) {
          network_trigger(network_trigger() + 1)
        }

      }, error = function(e) {
        showNotification(paste("Error saving network:", e$message), type = "error")
      })
    })

    # Load network when network_id_r changes
    observe({
      network_id <- network_id_r()
      req(network_id)

      # Check if this is a paper_id (starts with W) or network UUID
      if (grepl("^W\\d+", network_id)) {
        # This is a paper_id for a new network - just set as seed
        current_seed_ids(c(network_id))
        source_notebook_id(NULL)
        # Don't auto-build - let user click "Build Network"
      } else {
        # This is a saved network UUID - load from database
        loaded <- load_network(con_r(), network_id)
        if (is.null(loaded)) {
          showNotification("Network not found", type = "error")
          return()
        }

        # Use saved palette, falling back to current UI selection
        palette <- loaded$metadata$palette %||%
                   input$palette %||%
                   "viridis"

        # Sync palette selector to loaded network's palette
        updateSelectInput(session, "palette", selected = palette)

        # Get seed IDs (use new field if available, fall back to old single-seed field)
        loaded_seed_ids <- if (!is.null(loaded$metadata$seed_paper_ids)) {
          unlist(loaded$metadata$seed_paper_ids)
        } else {
          c(loaded$metadata$seed_paper_id)
        }

        # Build visualization data
        viz_data <- build_network_data(
          loaded$nodes,
          loaded$edges,
          palette,
          loaded_seed_ids
        )

        # Set current network and unfiltered snapshot
        net_list <- list(
          nodes = viz_data$nodes,
          edges = viz_data$edges,
          metadata = loaded$metadata
        )
        current_network_data(net_list)
        unfiltered_network_data(net_list)

        # Update controls
        updateRadioButtons(session, "direction", selected = loaded$metadata$direction)
        updateSliderInput(session, "depth", value = loaded$metadata$depth)
        updateSliderInput(session, "node_limit", value = loaded$metadata$node_limit)

        # Set seed IDs and notebook ID
        current_seed_ids(loaded_seed_ids)
        source_notebook_id(loaded$metadata$source_notebook_id)
      }
    })

    # Session cleanup
    session$onSessionEnded(function() {
      cleanup_session_flags(session$token)
    })

    # Return network state for external use
    list(
      set_seeds = function(seed_ids, notebook_id = NULL) {
        current_seed_ids(seed_ids)
        source_notebook_id(notebook_id)
      },
      set_seed = function(paper_id) {
        current_seed_ids(c(paper_id))
        source_notebook_id(NULL)
      }
    )
  })
}
