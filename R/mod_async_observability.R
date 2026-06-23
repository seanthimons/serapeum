#' Async Observability Module UI
#' @param id Module ID
mod_async_observability_ui <- function(id) {
  ns <- NS(id)

  div(
    class = "async-observability-panel",
    div(
      class = "d-flex gap-2 mb-2",
      actionButton(
        ns("async_diag_refresh"),
        NULL,
        icon = icon_refresh(),
        class = "btn-outline-secondary btn-sm",
        title = "Refresh"
      ),
      actionButton(
        ns("async_diag_clear"),
        NULL,
        icon = icon_trash_can(),
        class = "btn-outline-danger btn-sm",
        title = "Clear log"
      )
    ),
    uiOutput(ns("async_observability_status")),
    uiOutput(ns("async_mirai_status")),
    uiOutput(ns("async_task_summary")),
    uiOutput(ns("async_recent_event_picker")),
    verbatimTextOutput(ns("async_event_detail"))
  )
}

#' Async Observability Module Server
#' @param id Module ID
mod_async_observability_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    async_diag_refresh <- reactiveVal(0)

    async_format_ms <- function(ms) {
      if (is.null(ms) || is.na(ms)) {
        return("")
      }
      if (ms < 1000) {
        sprintf("%d ms", round(ms))
      } else {
        sprintf("%.1f s", ms / 1000)
      }
    }

    async_format_time <- function(value) {
      if (is.null(value) || is.na(value)) {
        return("")
      }
      format(value, "%H:%M:%S")
    }

    async_events <- reactive({
      async_diag_refresh()
      read_async_task_events(limit = 500)
    })

    observeEvent(input$async_diag_refresh, {
      async_diag_refresh(async_diag_refresh() + 1)
    })

    observeEvent(input$async_diag_clear, {
      clear_async_task_events()
      async_diag_refresh(async_diag_refresh() + 1)
      showNotification("Async diagnostics log cleared.", type = "message")
    })

    output$async_observability_status <- renderUI({
      async_diag_refresh()
      enabled <- async_task_enabled()
      log_path <- async_task_log_path()

      div(
        class = "small d-flex flex-wrap align-items-center gap-2 mb-2",
        span(
          class = paste(
            "badge",
            if (enabled) "bg-success" else "bg-secondary"
          ),
          if (enabled) "Enabled" else "Disabled"
        ),
        span(
          class = "text-muted text-break",
          "Log:",
          tags$code(log_path)
        )
      )
    })

    output$async_mirai_status <- renderUI({
      async_diag_refresh()
      status <- capture_async_mirai_status()

      if (!isTRUE(status$available)) {
        return(div(
          class = "alert alert-warning py-2 small",
          icon_warning(),
          " mirai status unavailable"
        ))
      }

      div(
        class = "small d-flex flex-wrap gap-2 mb-2",
        span(class = "badge bg-secondary", paste("awaiting", status$awaiting)),
        span(class = "badge bg-secondary", paste("executing", status$executing)),
        span(class = "badge bg-secondary", paste("completed", status$completed)),
        span(class = "badge bg-secondary", paste("connections", status$connections)),
        span(class = "badge bg-secondary", paste("daemons", status$daemons))
      )
    })

    output$async_task_summary <- renderUI({
      summary <- summarize_async_task_events(async_events())
      if (nrow(summary) == 0) {
        return(div(class = "text-muted small mb-2", "No async task events."))
      }

      rows <- head(summary, 10)
      tags$table(
        class = "table table-sm small align-middle mb-2",
        tags$thead(tags$tr(
          tags$th("Task"),
          tags$th("Status"),
          tags$th("Submitted"),
          tags$th("Worker"),
          tags$th("Wait"),
          tags$th("Work")
        )),
        tags$tbody(lapply(seq_len(nrow(rows)), function(i) {
          tags$tr(
            tags$td(rows$task_type[i]),
            tags$td(rows$status[i]),
            tags$td(async_format_time(rows$submitted_at[i])),
            tags$td(async_format_time(rows$worker_started_at[i])),
            tags$td(async_format_ms(rows$wait_ms[i])),
            tags$td(async_format_ms(rows$work_ms[i]))
          )
        }))
      )
    })

    output$async_recent_event_picker <- renderUI({
      events <- async_events()
      if (nrow(events) == 0) {
        return(NULL)
      }

      idx <- rev(seq_len(nrow(events)))
      labels <- vapply(idx, function(i) {
        paste(
          events$timestamp[i],
          events$event[i],
          events$task_type[i],
          events$stage[i],
          events$status[i]
        )
      }, character(1))

      selectInput(
        ns("async_event_index"),
        "Recent event",
        choices = stats::setNames(idx, labels),
        selected = idx[1],
        width = "100%"
      )
    })

    output$async_event_detail <- renderText({
      events <- async_events()
      if (nrow(events) == 0 || is.null(input$async_event_index)) {
        return("")
      }

      idx <- as.integer(input$async_event_index)
      if (is.na(idx) || idx < 1 || idx > nrow(events)) {
        return("")
      }

      event <- list()
      for (name in names(events)) {
        event[[name]] <- if (is.list(events[[name]])) {
          events[[name]][[idx]]
        } else {
          events[[name]][idx]
        }
      }

      jsonlite::prettify(jsonlite::toJSON(
        event,
        auto_unbox = TRUE,
        null = "null",
        na = "null"
      ))
    })

    for (output_id in c(
      "async_observability_status",
      "async_mirai_status",
      "async_task_summary",
      "async_recent_event_picker",
      "async_event_detail"
    )) {
      outputOptions(output, output_id, suspendWhenHidden = FALSE)
    }
  })
}
