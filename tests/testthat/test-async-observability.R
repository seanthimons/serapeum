source_app("async_observability.R")

test_that("async observability module exposes diagnostics controls and outputs", {
  skip_if_not_installed("shiny")
  library(shiny)
  source_app("theme_catppuccin.R", "mod_async_observability.R")

  ui <- mod_async_observability_ui("diag")
  ui_html <- as.character(ui)

  expect_true(grepl('id="diag-async_diag_refresh"', ui_html, fixed = TRUE))
  expect_true(grepl('id="diag-async_diag_clear"', ui_html, fixed = TRUE))
  expect_true(grepl('id="diag-async_mirai_status"', ui_html, fixed = TRUE))
  expect_true(grepl('id="diag-async_task_summary"', ui_html, fixed = TRUE))
  expect_true(grepl('id="diag-async_recent_event_picker"', ui_html, fixed = TRUE))
  expect_true(grepl('id="diag-async_event_detail"', ui_html, fixed = TRUE))
})

test_that("async task events append valid JSONL when enabled", {
  log_file <- tempfile(fileext = ".jsonl")
  withr::local_options(list(
    serapeum.async_observability_enabled = TRUE,
    serapeum.async_task_log_path = log_file,
    serapeum.async_task_type = NULL,
    serapeum.async_session_id = NULL,
    serapeum.async_notebook_id = NULL
  ))

  task_id <- "task-1"
  async_task_submitted(
    "bulk_doi_import",
    task_id,
    metadata = list(session_id = "session-1", notebook_id = "notebook-1", doi_count = 3)
  )
  async_task_worker_started(
    task_id,
    metadata = list(task_type = "bulk_doi_import", session_id = "session-1")
  )
  async_task_progress(task_id, "batch", "Batch 1/1", metadata = list(found = 2))
  async_task_completed(
    task_id,
    "completed",
    metadata = list(task_type = "bulk_doi_import", notebook_id = "notebook-1")
  )

  events <- read_async_task_events()

  expect_equal(nrow(events), 4)
  expect_equal(events$event, c("submitted", "worker_started", "progress", "completed"))
  expect_equal(events$task_id, rep(task_id, 4))
  expect_equal(events$task_type[1], "bulk_doi_import")
  expect_equal(events$session_id[1], "session-1")
  expect_equal(events$notebook_id[1], "notebook-1")
})

test_that("async task logging is a no-op when disabled", {
  log_file <- tempfile(fileext = ".jsonl")
  withr::local_options(list(
    serapeum.async_observability_enabled = FALSE,
    serapeum.async_task_log_path = log_file
  ))

  async_task_submitted("document_reindex", "task-off")

  expect_false(file.exists(log_file))
})

test_that("async task reader tolerates missing and corrupt log files", {
  log_file <- tempfile(fileext = ".jsonl")
  withr::local_options(list(serapeum.async_task_log_path = log_file))

  expect_equal(nrow(read_async_task_events()), 0)

  valid <- jsonlite::toJSON(
    list(
      timestamp = "2026-01-01T00:00:00.000Z",
      event = "submitted",
      task_id = "task-valid",
      task_type = "citation_audit",
      session_id = "session-1",
      notebook_id = "notebook-1",
      pid = 1,
      mirai_status = list(),
      status = "submitted",
      stage = NULL,
      message = NULL,
      metadata = list()
    ),
    auto_unbox = TRUE,
    null = "null"
  )
  writeLines(c("{not-json", valid), log_file)

  events <- read_async_task_events()

  expect_equal(nrow(events), 1)
  expect_equal(events$task_id, "task-valid")
})

test_that("async task metadata redacts sensitive values", {
  log_file <- tempfile(fileext = ".jsonl")
  withr::local_options(list(
    serapeum.async_observability_enabled = TRUE,
    serapeum.async_task_log_path = log_file
  ))

  async_task_submitted(
    "citation_network",
    "task-redact",
    metadata = list(
      api_key = "sk-or-secret-value",
      email = "person@example.com",
      raw_prompt = "send this prompt to a model",
      full_text = "full document text should not be logged",
      pdf_url = "https://example.com/paper.pdf?token=abc123",
      safe_count = 4
    )
  )

  log_text <- paste(readLines(log_file, warn = FALSE), collapse = "\n")

  expect_false(grepl("sk-or-secret-value", log_text, fixed = TRUE))
  expect_false(grepl("person@example.com", log_text, fixed = TRUE))
  expect_false(grepl("send this prompt", log_text, fixed = TRUE))
  expect_false(grepl("full document text", log_text, fixed = TRUE))
  expect_false(grepl("token=abc123", log_text, fixed = TRUE))
  expect_true(grepl("https://example.com/paper.pdf", log_text, fixed = TRUE))
  expect_true(grepl("\"safe_count\":4", log_text, fixed = TRUE))
})

test_that("async task summary computes wait, feedback, and work timings", {
  events <- data.frame(
    timestamp = c(
      "2026-01-01T00:00:00.000Z",
      "2026-01-01T00:00:01.000Z",
      "2026-01-01T00:00:02.500Z",
      "2026-01-01T00:00:05.000Z"
    ),
    event = c("submitted", "worker_started", "progress", "completed"),
    task_id = rep("task-summary", 4),
    task_type = rep("document_reindex", 4),
    session_id = rep("session-1", 4),
    notebook_id = rep("notebook-1", 4),
    pid = rep(1L, 4),
    status = c("submitted", "running", "running", "completed"),
    stage = c(NA, NA, "embed", NA),
    message = c(NA, NA, "Embedding 1 of 2", NA),
    stringsAsFactors = FALSE
  )
  events$mirai_status <- rep(list(list()), 4)
  events$metadata <- rep(list(list()), 4)

  summary <- summarize_async_task_events(events)

  expect_equal(nrow(summary), 1)
  expect_equal(summary$wait_ms, 1000)
  expect_equal(summary$first_feedback_ms, 2500)
  expect_equal(summary$work_ms, 4000)
  expect_equal(summary$status, "completed")
})

test_that("mirai status capture falls back when task counters are absent", {
  status <- capture_async_mirai_status()

  expect_named(
    status,
    c("available", "awaiting", "executing", "completed", "connections", "daemons", "error")
  )
  expect_true(is.logical(status$available))
  expect_true(is.integer(status$awaiting) || is.na(status$awaiting))
  expect_true(is.integer(status$connections) || is.na(status$connections))
})

test_that("progress-file writers emit async progress events with worker context", {
  source_app("config.R", "interrupt.R", "bulk_import.R", "citation_audit.R")

  log_file <- tempfile(fileext = ".jsonl")
  progress_file <- tempfile(fileext = ".progress")
  withr::local_options(list(
    serapeum.async_observability_enabled = TRUE,
    serapeum.async_task_log_path = log_file
  ))
  async_task_set_context(async_task_context(
    task_id = "task-progress",
    task_type = "bulk_doi_import",
    session_id = "session-1",
    notebook_id = "notebook-1",
    enabled = TRUE,
    log_path = log_file
  ))

  write_import_progress(progress_file, 1, 2, 4, 0, "Batch 1/2")
  write_audit_progress(progress_file, 2, 3, "Fetching forward citations")
  write_progress(progress_file, 1, 2, 1, 4, "Hop 1")

  events <- read_async_task_events()

  expect_equal(nrow(events), 3)
  expect_equal(events$event, rep("progress", 3))
  expect_equal(events$task_id, rep("task-progress", 3))
  expect_equal(events$stage, c("bulk_import", "citation_audit_step_2", "citation_network"))
})
