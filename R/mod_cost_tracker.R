#' Cost tracker palette by operation
COST_OPERATION_COLORS <- c(
  "chat" = "#2AA198",
  "embedding" = "#6C7086",
  "query_build" = "#B58900",
  "slide_generation" = "#FF6B00",
  "slide_healing" = "#8C7BFF",
  "conclusion_synthesis" = "#C061CB",
  "overview" = "#5B8DEF",
  "overview_summary" = "#00B8D9",
  "overview_keypoints" = "#2FBF71",
  "research_questions" = "#F59F00",
  "lit_review_table" = "#7CB342",
  "methodology_extractor" = "#E11D48",
  "gap_analysis" = "#16A3FF"
)

format_cost_currency <- function(value) {
  sprintf("$%.4f", value)
}

format_compact_integer <- function(value) {
  format(as.integer(value), big.mark = ",", scientific = FALSE, trim = TRUE)
}

get_cost_operation_color <- function(operation) {
  color <- unname(COST_OPERATION_COLORS[operation])
  if (length(color) == 1 && !is.na(color)) {
    return(color)
  }

  LATTE$lavender
}

render_cost_operation_icon <- function(operation, class = "small") {
  meta <- get_cost_operation_meta(operation)
  icon_fun <- get(meta$icon_fun, mode = "function")
  do.call(icon_fun, list(class = paste(class, meta$accent_class)))
}

build_cost_history_chart_data <- function(segments) {
  if (nrow(segments) == 0) {
    return(data.frame())
  }

  grouped <- stats::aggregate(
    cbind(total_cost, request_count, total_tokens) ~ date + operation + operation_label,
    data = segments,
    FUN = sum
  )
  day_totals <- stats::aggregate(total_cost ~ date, data = grouped, FUN = sum)
  names(day_totals)[2] <- "day_total"

  grouped <- merge(grouped, day_totals, by = "date", all.x = TRUE, sort = TRUE)

  present_ops <- unique(grouped$operation)
  op_levels <- c(
    intersect(names(COST_OPERATION_COLORS), present_ops),
    setdiff(sort(present_ops), names(COST_OPERATION_COLORS))
  )
  grouped$operation <- factor(grouped$operation, levels = op_levels)
  grouped$operation_label <- factor(
    grouped$operation_label,
    levels = vapply(op_levels, format_cost_operation_name, character(1))
  )

  grouped <- grouped[order(grouped$date, grouped$operation), ]
  date_levels <- sort(unique(grouped$date))
  grouped$date_label <- factor(format(grouped$date, "%m/%d"), levels = format(date_levels, "%m/%d"))
  grouped$x_position <- match(grouped$date, date_levels)
  grouped$ymin <- ave(grouped$total_cost, grouped$date, FUN = function(values) c(0, head(cumsum(values), -1)))
  grouped$ymax <- ave(grouped$total_cost, grouped$date, FUN = cumsum)

  grouped
}

locate_cost_history_segment <- function(chart_data, hover, tolerance = 0.45) {
  if (
    is.null(hover$x) || is.null(hover$y) ||
    nrow(chart_data) == 0
  ) {
    return(NULL)
  }

  candidates <- chart_data[
    abs(chart_data$x_position - hover$x) <= tolerance &
      hover$y >= chart_data$ymin &
      hover$y <= chart_data$ymax &
      chart_data$total_cost > 0,
    ,
    drop = FALSE
  ]

  if (nrow(candidates) == 0) {
    return(NULL)
  }

  candidates <- candidates[order(candidates$ymax - candidates$ymin, decreasing = TRUE), , drop = FALSE]
  candidates[1, , drop = FALSE]
}

locate_cost_history_day <- function(chart_data, hover, tolerance = 0.45) {
  if (is.null(hover$x) || nrow(chart_data) == 0) {
    return(NULL)
  }

  day_index <- unique(chart_data[, c("date", "date_label", "x_position", "day_total"), drop = FALSE])
  day_index$distance <- abs(day_index$x_position - hover$x)
  day_index <- day_index[day_index$distance <= tolerance, , drop = FALSE]

  if (nrow(day_index) == 0) {
    return(NULL)
  }

  day_index <- day_index[order(day_index$distance, day_index$date), , drop = FALSE]
  day_index[1, , drop = FALSE]
}

build_cost_history_tooltip <- function(date, chart_data, segments, segment_row = NULL) {
  day_rows <- chart_data[chart_data$date == date, , drop = FALSE]
  day_rows <- day_rows[order(-day_rows$total_cost), , drop = FALSE]
  day_total <- if (nrow(day_rows) > 0) day_rows$day_total[1] else 0

  day_segments <- segments[segments$date == date, , drop = FALSE]
  total_requests <- sum(day_segments$request_count, na.rm = TRUE)
  total_tokens <- sum(day_segments$total_tokens, na.rm = TRUE)

  model_rows <- stats::aggregate(
    cbind(total_cost, request_count, total_tokens) ~ model_label,
    data = day_segments,
    FUN = sum
  )
  model_rows <- model_rows[order(-model_rows$total_cost, model_rows$model_label), , drop = FALSE]

  header_title <- "Daily Usage"
  header_icon <- icon_chart_bar()
  header_amount <- format_cost_currency(day_total)
  header_subtitle <- paste(format(date, "%b %d, %Y"), "total", format_cost_currency(day_total))
  detail_requests <- total_requests
  detail_tokens <- total_tokens

  if (!is.null(segment_row)) {
    operation_key <- as.character(segment_row$operation[1])
    segment_models <- segments[
      segments$date == date & segments$operation == operation_key,
      ,
      drop = FALSE
    ]
    segment_models <- segment_models[order(-segment_models$total_cost, segment_models$model_label), , drop = FALSE]
    header_title <- as.character(segment_row$operation_label[1])
    header_icon <- render_cost_operation_icon(operation_key, class = "small")
    header_amount <- format_cost_currency(segment_row$total_cost[1])
    detail_requests <- segment_row$request_count[1]
    detail_tokens <- segment_row$total_tokens[1]
  } else {
    segment_models <- model_rows
  }

  tags$div(
    class = "cost-history-tooltip-card",
    tags$div(
      class = "d-flex justify-content-between align-items-start gap-3 mb-2",
      div(
        class = "d-flex align-items-center gap-2",
        header_icon,
        div(
          tags$div(class = "fw-semibold", header_title),
          tags$div(
            class = "small text-muted",
            header_subtitle
          )
        )
      ),
      tags$span(class = "fw-semibold text-nowrap", header_amount)
    ),
    tags$div(
      class = "d-flex flex-wrap gap-3 small mb-3",
      tags$span(tags$strong("Requests:"), format_compact_integer(detail_requests)),
      tags$span(tags$strong("Tokens:"), format_compact_integer(detail_tokens))
    ),
    tags$div(
      class = "cost-tooltip-section",
      tags$div(class = "cost-tooltip-section-title", "Model Breakdown"),
      if (nrow(segment_models) == 0) {
        tags$div(class = "small text-muted", "No model detail available")
      } else {
        tagList(lapply(seq_len(nrow(segment_models)), function(i) {
          row <- segment_models[i, ]
          tags$div(
            class = "cost-tooltip-row",
            tags$span(class = "text-truncate", row$model_label),
            tags$span(class = "text-nowrap", format_cost_currency(row$total_cost))
          )
        }))
      }
    ),
    tags$div(
      class = "cost-tooltip-section mt-3",
      tags$div(class = "cost-tooltip-section-title", "Day Breakdown"),
      tagList(lapply(seq_len(nrow(day_rows)), function(i) {
        row <- day_rows[i, ]
        tags$div(
          class = "cost-tooltip-row",
          tags$span(as.character(row$operation_label)),
          tags$span(class = "text-nowrap", format_cost_currency(row$total_cost))
        )
      }))
    )
  )
}

build_cost_operation_table <- function(df) {
  if (nrow(df) == 0) {
    return(tags$p(class = "text-muted mb-0", "No operations yet"))
  }

  tags$table(
    class = "table table-sm align-middle mb-0 cost-operation-table",
    tags$thead(
      tags$tr(
        tags$th("Operation"),
        tags$th("Models Used"),
        tags$th(class = "text-end", "Requests"),
        tags$th(class = "text-end", "Total Cost"),
        tags$th(class = "text-end", "Avg Cost")
      )
    ),
    tags$tbody(lapply(seq_len(nrow(df)), function(i) {
      row <- df[i, ]
      model_badges <- strsplit(row$models_used, ", ", fixed = TRUE)[[1]]
      tags$tr(
        tags$td(
          div(
            class = "d-flex align-items-start gap-2",
            tags$span(class = "cost-operation-icon", render_cost_operation_icon(row$operation)),
            div(
              tags$div(class = "fw-semibold", row$operation_label),
              tags$div(class = "small text-muted", row$top_models)
            )
          )
        ),
        tags$td(
          div(
            class = "d-flex flex-wrap gap-1",
            lapply(model_badges, function(model_label) {
              tags$span(class = "badge rounded-pill text-bg-light cost-model-badge", model_label)
            })
          )
        ),
        tags$td(class = "text-end text-nowrap", format_compact_integer(row$request_count)),
        tags$td(class = "text-end text-nowrap fw-semibold", format_cost_currency(row$total_cost)),
        tags$td(class = "text-end text-nowrap", format_cost_currency(row$avg_cost_per_request))
      )
    }))
  )
}

build_cost_tooltip_panel_style <- function(theme_mode) {
  base_style <- paste(
    "box-sizing: border-box;"
  )

  if (identical(theme_mode, "dark")) {
    paste(
      base_style,
      "background: rgba(49, 50, 68, 0.98);",
      "border: 1px solid #6c7086;",
      "border-radius: 0;",
      "box-shadow: 0 14px 30px rgba(0, 0, 0, 0.45);"
    )
  } else {
    paste(
      base_style,
      "background: rgba(245, 244, 237, 0.98);",
      "border: 1px solid #bcc0cc;",
      "border-radius: 0;",
      "box-shadow: 0 12px 28px rgba(0, 0, 0, 0.18);"
    )
  }
}

format_latency_ms <- function(ms) {
  if (is.null(ms) || is.na(ms)) return("--")
  if (ms < 1000) return(sprintf("%dms", as.integer(ms)))
  sprintf("%.1fs", ms / 1000)
}

build_latency_table <- function(df, key_col, label_fn) {
  tags$table(
    class = "table table-sm align-middle mb-0",
    tags$thead(
      tags$tr(
        tags$th(tools::toTitleCase(key_col)),
        tags$th(class = "text-end", "Avg"),
        tags$th(class = "text-end", "p50"),
        tags$th(class = "text-end", "p95"),
        tags$th(class = "text-end", "Calls")
      )
    ),
    tags$tbody(lapply(seq_len(nrow(df)), function(i) {
      row <- df[i, ]
      tags$tr(
        tags$td(label_fn(row[[key_col]])),
        tags$td(class = "text-end text-nowrap", format_latency_ms(row$avg_latency_ms)),
        tags$td(class = "text-end text-nowrap", format_latency_ms(row$p50_latency_ms)),
        tags$td(class = "text-end text-nowrap", format_latency_ms(row$p95_latency_ms)),
        tags$td(class = "text-end", format_compact_integer(row$call_count))
      )
    }))
  )
}

build_latency_sparkline <- function(trend) {
  if (nrow(trend) < 2) return(NULL)

  max_ms <- max(trend$avg_latency_ms, na.rm = TRUE)
  if (max_ms == 0) return(NULL)

  bar_heights <- (trend$avg_latency_ms / max_ms) * 40

  tags$div(
    class = "d-flex align-items-end gap-1",
    style = "height: 48px;",
    lapply(seq_len(nrow(trend)), function(i) {
      tags$div(
        style = sprintf(
          "width: 6px; height: %dpx; background: var(--bs-secondary); border-radius: 2px 2px 0 0; opacity: 0.7;",
          max(as.integer(bar_heights[i]), 2)
        ),
        title = sprintf("%s: %s (%d calls)",
                        format(trend$date[i], "%b %d"),
                        format_latency_ms(trend$avg_latency_ms[i]),
                        trend$call_count[i])
      )
    })
  )
}

#' Cost Tracker Module UI
#' @param id Module ID
mod_cost_tracker_ui <- function(id) {
  ns <- NS(id)

  card(
    fill = FALSE,
    card_header("Cost Tracker"),
    card_body(
      fillable = FALSE,
      uiOutput(ns("openrouter_balance")),
      value_box(
        title = "Session Cost",
        value = textOutput(ns("session_total"), inline = TRUE),
        showcase = icon_dollar(),
        showcase_layout = "left center",
        theme = "primary"
      ),
      uiOutput(ns("oa_usage_section")),
      hr(),
      h6("Recent Requests"),
      div(
        style = "max-height: 300px; overflow-y: auto;",
        tableOutput(ns("recent_requests"))
      ),
      hr(),
      tags$details(
        tags$summary(
          class = "fw-semibold mb-2",
          style = "cursor: pointer;",
          "Cost History (Last 30 Days)"
        ),
        div(
          class = "small text-muted mb-2",
          "Click a segment for detail, again for day view, once more to dismiss."
        ),
        div(
          class = "cost-history-row",
          div(
            class = "cost-history-chart-wrap",
            plotOutput(
              ns("cost_history_plot"),
              height = "280px",
              click = clickOpts(ns("cost_history_click"), clip = TRUE)
            )
          ),
          uiOutput(ns("cost_history_tooltip"))
        ),
        hr(),
        h6("Cost by Operation"),
        uiOutput(ns("cost_by_operation"))
      ),
      hr(),
      tags$details(
        tags$summary(
          class = "fw-semibold mb-2",
          style = "cursor: pointer;",
          "Latency (Last 7 Days)"
        ),
        uiOutput(ns("latency_section"))
      )
    )
  )
}

#' Cost Tracker Module Server
#' @param id Module ID
#' @param con_r Reactive database connection
#' @param session_id_r Reactive session ID
#' @param config_r Reactive effective config (from mod_settings)
#' @param theme_mode_r Reactive theme mode value
mod_cost_tracker_server <- function(id, con_r, session_id_r, config_r = NULL, theme_mode_r = NULL) {
  moduleServer(id, function(input, output, session) {

    session_timer <- reactiveTimer(10000)
    history_timer <- reactiveTimer(60000)

    credits_data <- reactive({
      history_timer()
      req(config_r)
      cfg <- config_r()
      api_key <- cfg$openrouter$api_key
      req(api_key, nchar(api_key) > 0)
      get_openrouter_credits(api_key)
    })

    output$openrouter_balance <- renderUI({
      creds <- credits_data()
      if (is.null(creds)) return(NULL)

      remaining <- creds$remaining
      theme <- if (remaining > 10) "success" else if (remaining > 2) "warning" else "danger"

      tagList(
        value_box(
          title = "OpenRouter Balance",
          value = sprintf("$%.2f", remaining),
          showcase = icon_wallet(),
          showcase_layout = "left center",
          theme = theme,
          p(class = "small mb-0",
            sprintf("$%.2f used of $%.2f", creds$total_usage, creds$total_credits))
        ),
        hr()
      )
    })

    session_total <- reactive({
      session_timer()
      req(con_r(), session_id_r())

      costs <- get_session_costs(con_r(), session_id_r())
      attr(costs, "total_cost") %||% 0
    })

    recent_requests <- reactive({
      session_timer()
      req(con_r(), session_id_r())

      costs <- get_session_costs(con_r(), session_id_r())
      if (nrow(costs) > 20) {
        costs <- costs[1:20, ]
      }

      costs
    })

    cost_history_segments <- reactive({
      history_timer()
      req(con_r())

      get_cost_history_segments(con_r(), 30)
    })

    cost_history_chart <- reactive({
      build_cost_history_chart_data(cost_history_segments())
    })

    theme_mode <- reactive({
      if (is.null(theme_mode_r)) {
        return("light")
      }

      mode <- theme_mode_r()
      if (isTRUE(mode) || identical(mode, "dark")) {
        return("dark")
      }

      "light"
    })

    cost_by_operation <- reactive({
      history_timer()
      req(con_r())

      get_cost_by_operation(con_r(), 30)
    })

    selected_cost_segment <- reactiveVal(NULL)

    output$session_total <- renderText({
      total <- session_total()
      format_cost_currency(total)
    })

    output$recent_requests <- renderTable({
      df <- recent_requests()

      if (nrow(df) == 0) {
        return(data.frame(Message = "No requests yet"))
      }

      data.frame(
        Time = vapply(df$created_at, function(t) {
          diff <- as.numeric(difftime(Sys.time(), t, units = "mins"))
          if (diff < 1) "Just now"
          else if (diff < 60) sprintf("%dm ago", round(diff))
          else if (diff < 1440) sprintf("%dh ago", round(diff / 60))
          else sprintf("%dd ago", round(diff / 1440))
        }, character(1)),
        Operation = vapply(df$operation, format_cost_operation_name, character(1)),
        Model = vapply(df$model, format_cost_model_name, character(1)),
        Tokens = df$total_tokens,
        Cost = format_cost_currency(df$estimated_cost),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, hover = TRUE, bordered = FALSE, spacing = "xs", width = "100%")

    output$cost_history_plot <- renderPlot({
      chart <- cost_history_chart()

      if (nrow(chart) == 0) {
        plot.new()
        text(0.5, 0.5, "No cost data yet", cex = 1.2, col = "gray")
        return()
      }

      present_ops <- unique(as.character(chart$operation))
      op_levels <- c(
        intersect(names(COST_OPERATION_COLORS), present_ops),
        setdiff(sort(present_ops), names(COST_OPERATION_COLORS))
      )
      label_levels <- vapply(op_levels, format_cost_operation_name, character(1))
      chart$operation_label <- factor(as.character(chart$operation_label), levels = label_levels)

      palette <- setNames(
        vapply(op_levels, get_cost_operation_color, character(1)),
        label_levels
      )

      dark_mode <- identical(theme_mode(), "dark")
      axis_color <- if (dark_mode) MOCHA$text else LATTE$text
      grid_color <- if (dark_mode) MOCHA$surface1 else LATTE$surface1
      legend_text_color <- if (dark_mode) MOCHA$text else LATTE$text
      plot_bg <- if (dark_mode) MOCHA$base else LATTE$base

      ggplot2::ggplot(
        chart,
        ggplot2::aes(x = date_label, y = total_cost, fill = operation_label)
      ) +
        ggplot2::geom_col(width = 0.72, color = NA) +
        ggplot2::scale_fill_manual(values = palette, drop = FALSE) +
        ggplot2::scale_y_continuous(labels = function(values) sprintf("$%.3f", values)) +
        ggplot2::labs(x = NULL, y = NULL, fill = NULL) +
        ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
        ggplot2::theme_minimal(base_size = 13) +
        ggplot2::theme(
          plot.background = ggplot2::element_rect(fill = plot_bg, color = NA),
          panel.background = ggplot2::element_rect(fill = plot_bg, color = NA),
          panel.grid.minor = ggplot2::element_blank(),
          panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.major.y = ggplot2::element_line(color = grid_color, linewidth = 0.35),
          axis.text.x = ggplot2::element_text(color = axis_color, angle = 35, hjust = 1, size = 12),
          axis.text.y = ggplot2::element_text(color = axis_color, size = 12),
          legend.position = "bottom",
          legend.title = ggplot2::element_blank(),
          legend.text = ggplot2::element_text(color = legend_text_color, size = 12),
          legend.key.size = grid::unit(14, "pt"),
          plot.margin = ggplot2::margin(8, 8, 8, 8)
        )
    }, bg = "transparent")

    observeEvent(input$cost_history_click, {
      click <- input$cost_history_click
      chart <- cost_history_chart()
      req(!is.null(click), nrow(chart) > 0)

      current <- selected_cost_segment()

      # Determine which date was clicked (segment or day)
      segment_row <- locate_cost_history_segment(chart, click)
      day_row <- locate_cost_history_day(chart, click)
      clicked_date <- if (!is.null(segment_row)) segment_row$date[1]
                      else if (!is.null(day_row)) day_row$date[1]
                      else NULL

      if (is.null(clicked_date)) {
        selected_cost_segment(NULL)
        return()
      }

      # If clicking the same date, cycle: segment -> day -> dismiss
      if (!is.null(current) && identical(as.character(current$date), as.character(clicked_date))) {
        if (identical(current$mode, "segment")) {
          selected_cost_segment(list(mode = "day", date = clicked_date))
        } else {
          selected_cost_segment(NULL)
        }
        return()
      }

      # New date: show segment if available, otherwise day
      if (!is.null(segment_row)) {
        selected_cost_segment(list(mode = "segment", date = clicked_date, segment_row = segment_row))
      } else {
        selected_cost_segment(list(mode = "day", date = clicked_date))
      }
    })

    output$cost_history_tooltip <- renderUI({
      selected <- selected_cost_segment()
      chart <- cost_history_chart()
      segments <- cost_history_segments()

      req(!is.null(selected), nrow(chart) > 0)

      tags$div(
        class = "cost-history-tooltip-panel",
        style = build_cost_tooltip_panel_style(theme_mode()),
        build_cost_history_tooltip(
          date = selected$date,
          chart_data = chart,
          segments = segments,
          segment_row = if (identical(selected$mode, "segment")) selected$segment_row else NULL
        )
      )
    })

    output$cost_by_operation <- renderUI({
      build_cost_operation_table(cost_by_operation())
    })

    # --- Latency Section ---

    output$latency_section <- renderUI({
      history_timer()
      req(con_r())

      summary <- get_latency_summary(con_r(), days = 7)

      if (is.null(summary)) {
        return(tags$p(class = "text-muted mb-0", "No latency data yet. Latency will appear after your next LLM call."))
      }

      by_model <- get_latency_by_model(con_r(), days = 7)
      by_op <- get_latency_by_operation(con_r(), days = 7)
      trend <- get_latency_trend(con_r(), days = 30)

      tagList(
        value_box(
          title = "Avg Latency (7 days)",
          value = format_latency_ms(summary$avg_latency_ms),
          showcase = icon_clock(),
          showcase_layout = "left center",
          theme = "secondary",
          p(class = "small mb-0", sprintf("%s calls tracked", format_compact_integer(summary$total_calls)))
        ),
        if (nrow(by_model) > 0) {
          tagList(
            h6(class = "mt-3", "By Model"),
            build_latency_table(by_model, "model", format_cost_model_name)
          )
        },
        if (nrow(by_op) > 0) {
          tagList(
            h6(class = "mt-3", "By Operation"),
            build_latency_table(by_op, "operation", format_cost_operation_name)
          )
        },
        if (nrow(trend) > 1) {
          tagList(
            h6(class = "mt-3", "Daily Trend (30 days)"),
            build_latency_sparkline(trend)
          )
        }
      )
    })

    # --- OpenAlex Usage Section ---

    oa_usage_data <- reactive({
      session_timer()
      req(con_r())
      get_oa_daily_usage(con_r())
    })

    output$oa_usage_section <- renderUI({
      req(config_r)
      cfg <- config_r()

      # Only show for users with an OA API key
      oa_key <- cfg$openalex$api_key
      if (is.null(oa_key) || !nzchar(trimws(oa_key))) return(NULL)

      usage <- oa_usage_data()
      pct <- oa_budget_percentage(usage$remaining, usage$daily_limit)
      color <- oa_budget_color(pct) %||% "secondary"

      pct_display <- if (!is.na(pct)) paste0(pct, "%") else "N/A"
      remaining_display <- if (!is.na(usage$remaining)) sprintf("$%.4f", usage$remaining) else "N/A"
      limit_display <- if (!is.na(usage$daily_limit)) sprintf("$%.2f", usage$daily_limit) else "N/A"

      last_updated_display <- if (!is.na(usage$last_updated)) {
        format(as.POSIXct(usage$last_updated), "%H:%M")
      } else {
        "no data"
      }

      tagList(
        value_box(
          title = "OpenAlex Daily Budget",
          value = paste0(remaining_display, " remaining"),
          showcase = icon_search(),
          showcase_layout = "left center",
          theme = color,
          p(class = "small mb-0",
            sprintf("%s used of %s (%s) \u2022 %d requests today",
                    sprintf("$%.4f", usage$total_credits_used),
                    limit_display, pct_display,
                    usage$request_count)),
          p(class = "small text-muted mb-0",
            sprintf("as of %s", last_updated_display))
        ),
        hr()
      )
    })
  })
}
