library(testthat)

project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "config.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "db_migrations.R"))
source(file.path(project_root, "R", "db.R"))
source(file.path(project_root, "R", "cost_tracking.R"))
source(file.path(project_root, "R", "api_openalex.R"))
source(file.path(project_root, "R", "api_openrouter.R"))
source(file.path(project_root, "R", "api_provider.R"))
source(file.path(project_root, "R", "theme_catppuccin.R"))
source(file.path(project_root, "R", "mod_cost_tracker.R"))
source(file.path(project_root, "R", "mod_settings.R"))

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

# --- Latency query tests ---

test_that("get_latency_summary returns NULL when no latency data", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # No duration_ms column yet (pre-migration)
  expect_null(get_latency_summary(con, days = 7))
})

test_that("latency queries return empty frames when column missing", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  by_model <- get_latency_by_model(con, days = 7)
  expect_equal(nrow(by_model), 0)
  expect_true("avg_latency_ms" %in% names(by_model))

  by_op <- get_latency_by_operation(con, days = 7)
  expect_equal(nrow(by_op), 0)

  trend <- get_latency_trend(con, days = 30)
  expect_equal(nrow(trend), 0)
})

test_that("latency queries work after migration with data", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Apply migration 012
  DBI::dbExecute(con, "ALTER TABLE cost_log ADD COLUMN duration_ms INTEGER")

  # Insert rows with duration
  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50,
           estimated_cost = 0.001, session_id = "s1", duration_ms = 1500L)
  log_cost(con, "chat", "openai/gpt-4o-mini", 80, 40,
           estimated_cost = 0.0008, session_id = "s1", duration_ms = 1200L)
  log_cost(con, "embedding", "openai/text-embedding-3-small", 200, 0,
           estimated_cost = 0.0001, session_id = "s1", duration_ms = 300L)

  # Summary
  summary <- get_latency_summary(con, days = 7)
  expect_false(is.null(summary))
  expect_equal(summary$total_calls, 3)
  expect_equal(summary$avg_latency_ms, 1000L)  # (1500+1200+300)/3 = 1000

  # By model
  by_model <- get_latency_by_model(con, days = 7)
  expect_equal(nrow(by_model), 2)
  gpt_row <- by_model[by_model$model == "openai/gpt-4o-mini", ]
  expect_equal(gpt_row$call_count, 2)
  expect_equal(gpt_row$avg_latency_ms, 1350L)  # (1500+1200)/2

  # By operation
  by_op <- get_latency_by_operation(con, days = 7)
  expect_equal(nrow(by_op), 2)
  chat_op <- by_op[by_op$operation == "chat", ]
  expect_equal(chat_op$call_count, 2)

  # Trend
  trend <- get_latency_trend(con, days = 30)
  expect_equal(nrow(trend), 1)  # all in one day
  expect_equal(trend$call_count, 3)
})

test_that("latency queries exclude NULL duration rows", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  DBI::dbExecute(con, "ALTER TABLE cost_log ADD COLUMN duration_ms INTEGER")

  # One with duration, one without

  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50,
           estimated_cost = 0.001, session_id = "s1", duration_ms = 2000L)
  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50,
           estimated_cost = 0.001, session_id = "s1", duration_ms = NULL)

  summary <- get_latency_summary(con, days = 7)
  expect_equal(summary$total_calls, 1)
  expect_equal(summary$avg_latency_ms, 2000L)
})

test_that("latency queries respect day window", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  DBI::dbExecute(con, "ALTER TABLE cost_log ADD COLUMN duration_ms INTEGER")

  # Insert a row with today's date
  log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50,
           estimated_cost = 0.001, session_id = "s1", duration_ms = 1000L)

  # Insert an old row by direct SQL (10 days ago)
  old_date <- as.character(Sys.Date() - 10)
  DBI::dbExecute(con, sprintf("
    INSERT INTO cost_log (id, session_id, operation, model, prompt_tokens,
                          completion_tokens, total_tokens, estimated_cost, duration_ms, created_at)
    VALUES ('old-1', 's1', 'chat', 'openai/gpt-4o-mini', 100, 50, 150, 0.001, 5000,
            TIMESTAMP '%s 12:00:00')
  ", old_date))

  # 7-day window should only see today's row
  summary <- get_latency_summary(con, days = 7)
  expect_equal(summary$total_calls, 1)
  expect_equal(summary$avg_latency_ms, 1000L)

  # 30-day window should see both
  by_model <- get_latency_by_model(con, days = 30)
  expect_equal(by_model$call_count, 2)
})

test_that("format_latency_ms formats correctly", {
  expect_equal(format_latency_ms(500), "500ms")
  expect_equal(format_latency_ms(1500), "1.5s")
  expect_equal(format_latency_ms(NULL), "--")
  expect_equal(format_latency_ms(NA), "--")
  expect_equal(format_latency_ms(50), "50ms")
  expect_equal(format_latency_ms(999), "999ms")
  expect_equal(format_latency_ms(1000), "1.0s")
})

# --- Model slot migration tests ---

test_that("migrate_model_slots copies chat_model to quality_model", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  save_db_setting(con, "chat_model", "openai/gpt-4o-mini")

  migrate_model_slots(con)

  quality <- get_db_setting(con, "quality_model")
  expect_equal(quality, "openai/gpt-4o-mini")
})

test_that("migrate_model_slots is idempotent", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  save_db_setting(con, "quality_model", "anthropic/claude-sonnet-4")
  save_db_setting(con, "chat_model", "openai/gpt-4o-mini")

  # Should NOT overwrite existing quality_model

  migrate_model_slots(con)

  quality <- get_db_setting(con, "quality_model")
  expect_equal(quality, "anthropic/claude-sonnet-4")
})

test_that("migrate_model_slots does nothing when no chat_model exists", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  migrate_model_slots(con)

  quality <- get_db_setting(con, "quality_model")
  expect_null(quality)
})

# --- #234: log_cost returns NULL on INSERT failure ---

test_that("log_cost returns NULL and warns on INSERT failure", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Close the connection to force INSERT failure
  close_db_connection(con)

  expect_warning(
    result <- log_cost(con, "chat", "openai/gpt-4o-mini", 100, 50,
                       estimated_cost = 0.001, session_id = "s1"),
    "Failed to log cost"
  )

  expect_null(result)
})
