#' Cost Tracker Module UI
#' @param id Module ID
mod_cost_tracker_ui <- function(id) {
  ns <- NS(id)

  card(
    card_header("Cost Tracker"),
    card_body(
      # Session summary value box
      value_box(
        title = "Session Cost",
        value = textOutput(ns("session_total"), inline = TRUE),
        showcase = icon("dollar-sign"),
        showcase_layout = "left center",
        theme = "primary"
      ),
      hr(),
      # Recent requests table
      h6("Recent Requests"),
      div(
        style = "max-height: 300px; overflow-y: auto;",
        tableOutput(ns("recent_requests"))
      ),
      hr(),
      # Cost history section (collapsible)
      tags$details(
        tags$summary(
          class = "fw-semibold mb-2",
          style = "cursor: pointer;",
          "Cost History (Last 30 Days)"
        ),
        div(
          plotOutput(ns("cost_history_plot"), height = "200px"),
          hr(),
          h6("Cost by Operation"),
          tableOutput(ns("cost_by_operation"))
        )
      )
    )
  )
}

#' Cost Tracker Module Server
#' @param id Module ID
#' @param con_r Reactive database connection
#' @param session_id_r Reactive session ID
mod_cost_tracker_server <- function(id, con_r, session_id_r) {
  moduleServer(id, function(input, output, session) {

    # Reactive timer for session data (poll every 10 seconds)
    session_timer <- reactiveTimer(10000)

    # Reactive timer for history data (poll every 60 seconds)
    history_timer <- reactiveTimer(60000)

    # Session total reactive
    session_total <- reactive({
      session_timer()
      req(con_r(), session_id_r())

      costs <- get_session_costs(con_r(), session_id_r())
      attr(costs, "total_cost") %||% 0
    })

    # Recent requests reactive
    recent_requests <- reactive({
      session_timer()
      req(con_r(), session_id_r())

      costs <- get_session_costs(con_r(), session_id_r())

      # Return top 20
      if (nrow(costs) > 20) {
        costs <- costs[1:20, ]
      }

      costs
    })

    # Cost history reactive
    cost_history <- reactive({
      history_timer()
      req(con_r())

      get_cost_history(con_r(), 30)
    })

    # Cost by operation reactive
    cost_by_operation <- reactive({
      history_timer()
      req(con_r())

      get_cost_by_operation(con_r(), 30)
    })

    # Render session total
    output$session_total <- renderText({
      total <- session_total()
      sprintf("$%.4f", total)
    })

    # Render recent requests table
    output$recent_requests <- renderTable({
      df <- recent_requests()

      if (nrow(df) == 0) {
        return(data.frame(Message = "No requests yet"))
      }

      # Format for display
      data.frame(
        Time = vapply(df$created_at, function(t) {
          diff <- as.numeric(difftime(Sys.time(), t, units = "mins"))
          if (diff < 1) "Just now"
          else if (diff < 60) sprintf("%dm ago", round(diff))
          else if (diff < 1440) sprintf("%dh ago", round(diff / 60))
          else sprintf("%dd ago", round(diff / 1440))
        }, character(1)),
        Operation = vapply(df$operation, function(op) {
          switch(op,
                 "chat" = "\U1F4AC Chat",
                 "embedding" = "\U1F9E0 Embed",
                 "query_build" = "\U2728 Query",
                 "slide_generation" = "\U1F4CA Slides",
                 op)
        }, character(1)),
        Model = vapply(df$model, function(m) {
          # Shorten model names
          gsub("^(openai|anthropic|google)/", "", m)
        }, character(1)),
        Tokens = df$total_tokens,
        Cost = sprintf("$%.4f", df$estimated_cost),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = FALSE, spacing = "xs", width = "100%")

    # Render cost history plot
    output$cost_history_plot <- renderPlot({
      history <- cost_history()

      if (nrow(history) == 0) {
        plot.new()
        text(0.5, 0.5, "No cost data yet", cex = 1.2, col = "gray")
        return()
      }

      # Create bar plot
      par(mar = c(3, 4, 2, 1))
      barplot(
        height = history$total_cost,
        names.arg = format(as.Date(history$date), "%m/%d"),
        col = "#6366f1",
        border = NA,
        las = 2,
        ylab = "Cost (USD)",
        main = "Daily Costs"
      )
    })

    # Render cost by operation table
    output$cost_by_operation <- renderTable({
      df <- cost_by_operation()

      if (nrow(df) == 0) {
        return(data.frame(Message = "No operations yet"))
      }

      # Format for display
      data.frame(
        Operation = vapply(df$operation, function(op) {
          switch(op,
                 "chat" = "\U1F4AC Chat",
                 "embedding" = "\U1F9E0 Embed",
                 "query_build" = "\U2728 Query",
                 "slide_generation" = "\U1F4CA Slides",
                 op)
        }, character(1)),
        Requests = df$request_count,
        `Total Cost` = sprintf("$%.4f", df$total_cost),
        `Avg Cost` = sprintf("$%.4f", df$avg_cost_per_request),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = FALSE, spacing = "xs", width = "100%")
  })
}
