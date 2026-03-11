library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "cost_tracking.R"))
source(file.path(project_root, "R", "theme_catppuccin.R"))
source(file.path(project_root, "R", "mod_cost_tracker.R"))

test_that("cost operation and model formatters normalize current labels", {
  expect_equal(format_cost_operation_name("overview_keypoints"), "Overview Key Points")
  expect_equal(format_cost_operation_name("research_questions"), "Research Questions")
  expect_equal(format_cost_operation_name("unknown_operation"), "Unknown Operation")

  gap_meta <- get_cost_operation_meta("gap_analysis")
  expect_equal(gap_meta$icon_fun, "icon_search")
  expect_equal(gap_meta$label, "Gap Analysis")

  expect_equal(format_cost_model_name("openai/gpt-4o-mini"), "GPT-4o mini")
  expect_equal(
    format_cost_model_name("vendor/custom-model-preview-2026-01-01"),
    "Custom Model"
  )
  expect_equal(format_cost_model_name("vendor/brand-new-model"), "Brand New Model")
  expect_equal(format_cost_model_name(NA_character_), "Unknown Model")
  expect_equal(format_cost_model_name(""), "Unknown Model")
  expect_equal(format_cost_operation_name(NA_character_), "Unknown Operation")
  expect_equal(format_cost_operation_name(""), "Unknown Operation")
  expect_equal(get_cost_operation_color("totally_new_operation"), LATTE$lavender)
})

test_that("get_cost_history_segments returns tooltip-ready grouped rows", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50, estimated_cost = 0.0010, session_id = "s1")
  log_cost(con, "chat", "anthropic/claude-sonnet-4", 120, 80, estimated_cost = 0.0030, session_id = "s2")
  log_cost(con, "research_questions", "google/gemini-2.0-flash-001", 80, 40, estimated_cost = 0.0005, session_id = "s3")

  segments <- get_cost_history_segments(con, 30)
  expect_true(all(c("operation_label", "model_label", "request_count", "total_tokens") %in% names(segments)))
  expect_equal(nrow(segments), 3)
  expect_true(all(segments$date == Sys.Date()))

  chat_rows <- segments[segments$operation == "chat", , drop = FALSE]
  expect_equal(nrow(chat_rows), 2)
  expect_true(all(chat_rows$operation_label == "Chat"))
  expect_true("GPT-4o mini" %in% chat_rows$model_label)
  expect_true("Claude Sonnet 4" %in% chat_rows$model_label)
})

test_that("get_cost_by_operation summarizes model usage for the table", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50, estimated_cost = 0.0010, session_id = "s1")
  log_cost(con, "chat", "anthropic/claude-sonnet-4", 120, 80, estimated_cost = 0.0030, session_id = "s2")
  log_cost(con, "gap_analysis", "google/gemini-2.0-flash-001", 90, 60, estimated_cost = 0.0008, session_id = "s3")

  summary <- get_cost_by_operation(con, 30)
  expect_true(all(c("operation_label", "model_count", "models_used", "top_models") %in% names(summary)))
  expect_equal(summary$operation[1], "chat")

  chat_row <- summary[summary$operation == "chat", , drop = FALSE]
  expect_equal(chat_row$operation_label, "Chat")
  expect_equal(chat_row$model_count, 2)
  expect_equal(chat_row$request_count, 2)
  expect_equal(chat_row$total_cost, 0.0040)
  expect_match(chat_row$models_used, "GPT-4o mini")
  expect_match(chat_row$models_used, "Claude Sonnet 4")
  expect_match(chat_row$top_models, "Claude Sonnet 4")
})
