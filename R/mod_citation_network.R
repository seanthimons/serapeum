#' Citation Network Module UI
#' @param id Module ID
mod_citation_network_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Include custom CSS
    tags$head(tags$link(rel = "stylesheet", href = "custom.css")),

    # Top controls bar
    div(
      class = "citation-network-controls mb-3 p-3 bg-light rounded",
      layout_columns(
        col_widths = c(2, 2, 2, 2, 2, 2),

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
          ),
          # Progress indicator
          uiOutput(ns("build_progress"))
        ),

        # Color palette selector
        div(
          selectInput(
            ns("palette"),
            "Color Palette",
            choices = c(
              "Viridis" = "viridis",
              "Magma" = "magma",
              "Plasma" = "plasma",
              "Inferno" = "inferno",
              "Cividis" = "cividis"
            ),
            selected = "viridis"
          )
        ),

        # Save button
        actionButton(
          ns("save_network"),
          "Save Network",
          class = "btn-outline-success",
          icon = icon("save")
        )
      )
    ),

    # Main content area with side panel
    layout_columns(
      col_widths = c(8, 4),

      # Left: Graph container
      div(
        class = "citation-network-container position-relative",
        visNetwork::visNetworkOutput(ns("network_graph"), height = "700px"),

        # Always-visible legend overlay
        div(
          class = "citation-network-legend",
          h6("Legend"),
          div(
            class = "mb-2",
            strong("Color:"), " Publication Year",
            div(
              class = "color-gradient mt-1",
              style = "height: 20px; background: linear-gradient(to right, #440154, #31688e, #35b779, #fde724); border-radius: 3px;"
            ),
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

    # Current network data
    current_network_data <- reactiveVal(NULL)
    current_seed_id <- reactiveVal(NULL)
    selected_node_id <- reactiveVal(NULL)
    build_in_progress <- reactiveVal(FALSE)

    # Progressive loading state
    progressive_nodes <- reactiveVal(NULL)
    progressive_edges <- reactiveVal(NULL)

    # Initialize palette from DB setting
    observe({
      palette <- get_db_setting(con_r(), "network_palette") %||% "viridis"
      updateSelectInput(session, "palette", selected = palette)
    }) |> bindEvent(con_r(), once = TRUE)

    # Build progress
    output$build_progress <- renderUI({
      if (build_in_progress()) {
        div(
          class = "mt-2 small text-muted",
          icon("spinner", class = "fa-spin"), " Building network..."
        )
      }
    })

    # Build network button handler
    observeEvent(input$build_network, {
      req(current_seed_id())

      build_in_progress(TRUE)
      on.exit(build_in_progress(FALSE))

      config <- config_r()
      email <- config$openalex$email
      api_key <- NULL  # Optional

      seed_id <- current_seed_id()
      direction <- input$direction
      depth <- input$depth
      node_limit <- input$node_limit

      # Get palette from UI control
      palette <- input$palette %||% "viridis"

      # Progress callback for progressive rendering
      progress_cb <- function(message, fraction) {
        # This would update progressive state
        # For now, we'll do full render after completion
      }

      withProgress(message = "Fetching citation network...", {
        tryCatch({
          # Fetch network
          result <- fetch_citation_network(
            seed_id, email, api_key,
            direction = direction,
            depth = depth,
            node_limit = node_limit,
            progress_callback = progress_cb
          )

          if (nrow(result$nodes) == 0) {
            showNotification("No papers found in citation network", type = "warning")
            return()
          }

          # Compute layout positions
          result$nodes <- compute_layout_positions(result$nodes, result$edges)

          # Build visualization data
          viz_data <- build_network_data(result$nodes, result$edges, palette, seed_id)

          # Store current network
          current_network_data(list(
            nodes = viz_data$nodes,
            edges = viz_data$edges,
            metadata = list(
              seed_paper_id = seed_id,
              seed_paper_title = viz_data$nodes$paper_title[viz_data$nodes$is_seed][1],
              direction = direction,
              depth = depth,
              node_limit = node_limit,
              palette = palette
            )
          ))

          showNotification(
            paste("Network built:", nrow(viz_data$nodes), "nodes,", nrow(viz_data$edges), "edges"),
            type = "message"
          )

        }, error = function(e) {
          showNotification(paste("Error building network:", e$message), type = "error")
        })
      })
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
        # Enable physics for initial build
        vn <- vn |>
          visNetwork::visPhysics(
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
              gravitationalConstant = -50,
              springLength = 200
            ),
            stabilization = list(iterations = 200)
          ) |>
          visNetwork::visLayout(randomSeed = 42)
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
          scaling = list(min = 10, max = 50, label = list(enabled = FALSE))
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

      # Update via proxy (no full re-render)
      visNetwork::visNetworkProxy("network_graph") |>
        visNetwork::visUpdateNodes(nodes[, c("id", "color", "size", "shape",
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

        # Set current network
        current_network_data(list(
          nodes = viz_data$nodes,
          edges = viz_data$edges,
          metadata = loaded$metadata
        ))

        # Update controls
        updateRadioButtons(session, "direction", selected = loaded$metadata$direction)
        updateSliderInput(session, "depth", value = loaded$metadata$depth)
        updateSliderInput(session, "node_limit", value = loaded$metadata$node_limit)

        # Set seed ID
        current_seed_id(loaded$metadata$seed_paper_id)
      }
    })

    # Return network state for external use
    list(
      set_seed = function(paper_id) {
        current_seed_id(paper_id)
      }
    )
  })
}
