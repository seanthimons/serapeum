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
      class = "citation-network-controls mb-3 p-3 bg-light rounded",
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
          actionButton(
            ns("build_network"),
            "Build Network",
            class = "btn-primary",
            icon = icon("diagram-project")
          )
        ),

        # Save button
        actionButton(
          ns("save_network"),
          "Save Network",
          class = "btn-outline-success",
          icon = icon("save")
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
              icon("star", class = "text-warning"), " = Seed Paper"
            )
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

    # Current network data (may be filtered)
    current_network_data <- reactiveVal(NULL)
    # Unfiltered snapshot — set when network is built/loaded, never mutated by filters
    unfiltered_network_data <- reactiveVal(NULL)
    current_seed_id <- reactiveVal(NULL)
    selected_node_id <- reactiveVal(NULL)

    # Progressive loading state
    progressive_nodes <- reactiveVal(NULL)
    progressive_edges <- reactiveVal(NULL)

    # Async task state
    current_interrupt_flag <- reactiveVal(NULL)
    progress_poller <- reactiveVal(NULL)

    # Create ExtendedTask for async network building
    network_task <- ExtendedTask$new(function(seed_id, email, direction, depth, node_limit, interrupt_flag, app_dir) {
      mirai::mirai({
        # Source required files in isolated process
        source(file.path(app_dir, "R", "interrupt.R"), local = TRUE)
        source(file.path(app_dir, "R", "api_openalex.R"), local = TRUE)
        source(file.path(app_dir, "R", "citation_network.R"), local = TRUE)

        # Build network with interrupt support
        result <- fetch_citation_network(
          seed_id, email, api_key = NULL,
          direction = direction, depth = depth,
          node_limit = node_limit,
          progress_callback = NULL,
          interrupt_flag = interrupt_flag
        )

        # Compute layout for full results only
        if (!isTRUE(result$partial) && nrow(result$nodes) > 0) {
          result$nodes <- compute_layout_positions(result$nodes, result$edges)
        }

        result
      }, seed_id = seed_id, email = email, direction = direction,
         depth = depth, node_limit = node_limit,
         interrupt_flag = interrupt_flag, app_dir = app_dir)
    })

    # Initialize palette from DB setting
    observe({
      palette <- get_db_setting(con_r(), "network_palette") %||% "viridis"
      updateSelectInput(session, "palette", selected = palette)
    }) |> bindEvent(con_r(), once = TRUE)

    # Year filter panel — only shown when a network exists
    output$year_filter_panel <- renderUI({
      req(unfiltered_network_data())
      ns <- session$ns
      div(
        class = "mt-2 pt-2 border-top",
        layout_columns(
          col_widths = c(5, 3, 4),
          div(
            sliderInput(
              ns("year_filter"),
              tags$span("Year Range",
                        title = "Filter network nodes by publication year. Adjust range then click Apply to update."),
              min = 1900, max = 2026, value = c(1900, 2026),
              step = 1, sep = "", ticks = FALSE
            )
          ),
          div(
            class = "pt-4",
            checkboxInput(ns("include_unknown_year_network"), "Include unknown year", value = TRUE)
          ),
          div(
            class = "pt-3",
            actionButton(ns("apply_year_filter"), "Apply Year Filter",
                         class = "btn-outline-primary btn-sm", icon = icon("filter")),
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

    # Apply year filter — filters from unfiltered snapshot, never destructive
    observeEvent(input$apply_year_filter, {
      net_data <- unfiltered_network_data()
      req(net_data)

      range <- input$year_filter
      include_null <- input$include_unknown_year_network

      nodes <- net_data$nodes
      edges <- net_data$edges

      # Always keep seed paper regardless of year filter
      is_kept <- nodes$is_seed
      if (include_null) {
        is_kept <- is_kept | is.na(nodes$year) | (nodes$year >= range[1] & nodes$year <= range[2])
      } else {
        is_kept <- is_kept | (!is.na(nodes$year) & nodes$year >= range[1] & nodes$year <= range[2])
      }
      filtered_nodes <- nodes[is_kept, ]

      # Keep edges where both endpoints survive
      filtered_node_ids <- filtered_nodes$id
      filtered_edges <- edges[edges$from %in% filtered_node_ids & edges$to %in% filtered_node_ids, ]

      # Update display data (unfiltered snapshot stays intact)
      current_network_data(list(
        nodes = filtered_nodes,
        edges = filtered_edges,
        metadata = net_data$metadata
      ))

      showNotification(
        paste("Year filter applied:", nrow(filtered_nodes), "of", nrow(nodes), "nodes shown"),
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
      req(current_seed_id())

      # Create interrupt flag
      flag_file <- create_interrupt_flag(session$token)
      current_interrupt_flag(flag_file)

      # Show progress modal
      showModal(modalDialog(
        title = tagList(icon("spinner", class = "fa-spin"), "Building Citation Network"),
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
        footer = actionButton(session$ns("cancel_build"), "Stop", class = "btn-warning", icon = icon("stop")),
        easyClose = FALSE,
        size = "m"
      ))

      # Invoke async task
      network_task$invoke(
        seed_id = current_seed_id(),
        email = config_r()$openalex$email,
        direction = input$direction,
        depth = input$depth,
        node_limit = input$node_limit,
        interrupt_flag = flag_file,
        app_dir = getwd()
      )

      # Start polling observer for progress updates
      poll_count <- reactiveVal(0L)
      poller <- observe({
        invalidateLater(2000)  # every 2 seconds
        n <- isolate(poll_count()) + 1L
        poll_count(n)
        # Increment progress bar smoothly: 5% -> ~85% over time
        pct <- min(5 + n * 8, 85)
        session$sendCustomMessage("updateBuildProgress", list(
          bar_id = session$ns("build_progress_bar"),
          msg_id = session$ns("build_progress_message"),
          percent = pct,
          message = paste0("Fetching citations (step ", n, ")...")
        ))
      })
      progress_poller(poller)  # Store in reactiveVal so cancel/result handlers can destroy it
    })

    # Cancel button handler
    observeEvent(input$cancel_build, {
      # Signal interrupt to the running mirai process via file flag
      flag_file <- current_interrupt_flag()
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }

      # Cancel the ExtendedTask
      network_task$cancel()

      # Stop progress poller
      poller <- progress_poller()
      if (!is.null(poller)) {
        poller$destroy()
        progress_poller(NULL)
      }

      # Close modal immediately (don't wait for task return)
      removeModal()

      # Clean up flag
      clear_interrupt_flag(flag_file)
      current_interrupt_flag(NULL)

      showNotification(
        "Network build stopped. Partial results will display if available.",
        type = "warning", duration = 5
      )
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

      # Clean up interrupt flag
      flag_file <- current_interrupt_flag()
      clear_interrupt_flag(flag_file)
      current_interrupt_flag(NULL)

      # Handle empty results
      if (is.null(result$nodes) || nrow(result$nodes) == 0) {
        showNotification("No papers found in citation network", type = "warning")
        return()
      }

      # Compute layout for partial results (skipped in mirai for partials)
      if (isTRUE(result$partial)) {
        result$nodes <- compute_layout_positions(result$nodes, result$edges)
      }

      # Build visualization data — reuse exact same pattern as current code
      palette <- input$palette %||% "viridis"
      seed_id <- current_seed_id()
      viz_data <- build_network_data(result$nodes, result$edges, palette, seed_id)

      # Store network — same pattern as current code
      net_list <- list(
        nodes = viz_data$nodes,
        edges = viz_data$edges,
        metadata = list(
          seed_paper_id = seed_id,
          seed_paper_title = viz_data$nodes$paper_title[viz_data$nodes$is_seed][1],
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
          sprintf("Network built: %d nodes, %d edges",
                  nrow(viz_data$nodes), nrow(viz_data$edges)),
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

      if (has_positions) {
        # Use saved positions
        nodes$x <- nodes$x_position
        nodes$y <- nodes$y_position
      }

      # Create visNetwork
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
        # Scale physics parameters based on graph density
        n_nodes <- nrow(nodes)
        n_edges <- nrow(edges)

        # More nodes need stronger repulsion and longer springs to spread out
        # Base values tuned for ~30 nodes; scale up for larger graphs
        gravity <- if (n_nodes <= 30) -120
                   else if (n_nodes <= 100) -200
                   else if (n_nodes <= 200) -350
                   else -500
        spring <- if (n_nodes <= 30) 350
                  else if (n_nodes <= 100) 450
                  else if (n_nodes <= 200) 600
                  else 800
        # Dense graphs (high edge:node ratio) need even more repulsion
        edge_ratio <- n_edges / max(n_nodes, 1)
        if (edge_ratio > 3) {
          gravity <- gravity * 1.5
          spring <- spring * 1.3
        }
        # More iterations for larger graphs so layout can fully resolve
        stab_iters <- if (n_nodes <= 50) 300
                      else if (n_nodes <= 150) 600
                      else 1000

        # Enable physics for initial build, auto-freeze after stabilization
        vn <- vn |>
          visNetwork::visPhysics(
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = gravity,
              springLength = spring,
              damping = 0.4
            ),
            stabilization = list(iterations = stab_iters)
          ) |>
          visNetwork::visLayout(randomSeed = 42) |>
          visNetwork::visEvents(
            stabilizationIterationsDone = "function() {
              this.setOptions({ physics: false });
            }"
          )
      }

      # Configure appearance
      vn <- vn |>
        visNetwork::visEdges(
          arrows = "to",
          color = list(color = "#cccccc", highlight = "#666666"),
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
          }", session$ns("node_clicked"))
        ) |>
        visNetwork::visOptions(
          highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)
        )

      vn
    })

    # Live-recolor nodes when palette changes
    observeEvent(input$palette, {
      net_data <- current_network_data()
      req(net_data)

      palette <- input$palette
      nodes <- net_data$nodes

      # Recompute colors with new palette
      nodes$color <- map_year_to_color(nodes$year, palette)

      # Update stored data
      net_data$nodes <- nodes
      net_data$metadata$palette <- palette
      current_network_data(net_data)

      # Also update unfiltered snapshot so next Apply uses new colors
      uf_data <- unfiltered_network_data()
      if (!is.null(uf_data)) {
        uf_data$nodes$color <- map_year_to_color(uf_data$nodes$year, palette)
        uf_data$metadata$palette <- palette
        unfiltered_network_data(uf_data)
      }

      # Also save palette to DB so settings stays in sync
      tryCatch(
        save_db_setting(con_r(), "network_palette", palette),
        error = function(e) NULL
      )

      # Update via proxy (no full re-render)
      visNetwork::visNetworkProxy("network_graph") |>
        visNetwork::visUpdateNodes(nodes[, c("id", "color", "value", "shape",
                                              "borderWidth", "color.border")])
    }, ignoreInit = TRUE)

    # Handle node click
    observeEvent(input$node_clicked, {
      selected_node_id(input$node_clicked)
    })

    # Render side panel
    output$side_panel <- renderUI({
      node_id <- selected_node_id()
      if (is.null(node_id)) return(NULL)

      net_data <- current_network_data()
      req(net_data)

      # Find node data
      node <- net_data$nodes[net_data$nodes$id == node_id, ]
      if (nrow(node) == 0) return(NULL)

      ns <- session$ns

      div(
        class = "citation-network-side-panel",
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            span(icon("file-alt"), " Paper Details"),
            actionLink(ns("close_panel"), icon("times"))
          ),
          card_body(
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
                  icon("external-link-alt", class = "ms-1 small")
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
                icon = icon("diagram-project")
              )
            )
          )
        )
      )
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

      # Update seed and rebuild
      current_seed_id(node_id)
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
          edges_df = net_data$edges
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
        current_seed_id(network_id)
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

        # Build visualization data
        viz_data <- build_network_data(
          loaded$nodes,
          loaded$edges,
          palette,
          loaded$metadata$seed_paper_id
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

        # Set seed ID
        current_seed_id(loaded$metadata$seed_paper_id)
      }
    })

    # Session cleanup
    session$onSessionEnded(function() {
      cleanup_session_flags(session$token)
    })

    # Return network state for external use
    list(
      set_seed = function(paper_id) {
        current_seed_id(paper_id)
      }
    )
  })
}
