#' Async task observability helpers
#'
#' Structured JSONL diagnostics for background tasks. Logging is opt-in via
#' `options(serapeum.async_observability_enabled = TRUE)`.

ASYNC_TASK_EVENT_COLUMNS <- c(
  "timestamp", "event", "task_id", "task_type", "session_id", "notebook_id",
  "pid", "status", "stage", "message"
)

async_task_coalesce <- function(x, y) {
  if (is.null(x)) y else x
}

async_task_enabled <- function() {
  isTRUE(getOption("serapeum.async_observability_enabled", FALSE))
}

async_task_default_log_path <- function() {
  root <- getOption(".serapeum_app_root", NULL)
  if (is.null(root) || !is.character(root) || nchar(root) == 0) {
    root <- getwd()
  }
  file.path(root, "data", "diagnostics", "async_tasks.jsonl")
}

async_task_log_path <- function() {
  getOption("serapeum.async_task_log_path", async_task_default_log_path())
}

async_task_id <- function(task_type) {
  prefix <- gsub("[^A-Za-z0-9_-]+", "-", task_type)
  stamp <- gsub("[^0-9]", "", format(Sys.time(), "%Y%m%d%H%M%OS3"))
  suffix <- paste(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")
  paste(prefix, Sys.getpid(), stamp, suffix, sep = "-")
}

async_task_context <- function(task_id = NULL, task_type = NULL,
                               session_id = NULL, notebook_id = NULL,
                               enabled = NULL, log_path = NULL) {
  if (is.null(enabled)) {
    enabled <- async_task_enabled()
  }
  if (is.null(log_path)) {
    log_path <- async_task_log_path()
  }

  list(
    task_id = task_id,
    task_type = task_type,
    session_id = session_id,
    notebook_id = notebook_id,
    enabled = isTRUE(enabled),
    log_path = log_path
  )
}

async_task_set_context <- function(context = NULL, task_id = NULL,
                                   task_type = NULL, session_id = NULL,
                                   notebook_id = NULL, enabled = NULL,
                                   log_path = NULL) {
  if (is.list(context)) {
    task_id <- context$task_id
    task_type <- context$task_type
    session_id <- context$session_id
    notebook_id <- context$notebook_id
    enabled <- context$enabled
    log_path <- context$log_path
  }

  opts <- list()
  if (!is.null(task_id)) opts$serapeum.async_task_id <- task_id
  if (!is.null(task_type)) opts$serapeum.async_task_type <- task_type
  if (!is.null(session_id)) opts$serapeum.async_session_id <- session_id
  if (!is.null(notebook_id)) opts$serapeum.async_notebook_id <- notebook_id
  if (!is.null(enabled)) opts$serapeum.async_observability_enabled <- isTRUE(enabled)
  if (!is.null(log_path)) opts$serapeum.async_task_log_path <- log_path

  if (length(opts) > 0) {
    do.call(options, opts)
  }

  invisible(async_task_context(
    task_id = getOption("serapeum.async_task_id", NULL),
    task_type = getOption("serapeum.async_task_type", NULL),
    session_id = getOption("serapeum.async_session_id", NULL),
    notebook_id = getOption("serapeum.async_notebook_id", NULL),
    enabled = async_task_enabled(),
    log_path = async_task_log_path()
  ))
}

async_task_context_value <- function(metadata, key, option_name = NULL,
                                     default = NULL) {
  if (is.list(metadata) && key %in% names(metadata) && !is.null(metadata[[key]])) {
    return(metadata[[key]])
  }
  if (!is.null(option_name)) {
    return(getOption(option_name, default))
  }
  default
}

async_task_without_event_fields <- function(metadata) {
  if (!is.list(metadata)) {
    return(list())
  }
  metadata[c("task_type", "session_id", "notebook_id")] <- NULL
  metadata
}

async_task_redact_string <- function(value, key = "") {
  if (!is.character(value)) {
    return(value)
  }

  redact_all <- grepl(
    "(api[_-]?key|token|secret|password|prompt|email|full[_-]?text|document[_-]?text|raw[_-]?text)",
    key,
    ignore.case = TRUE
  )

  is_url_key <- grepl("(url|uri|link)", key, ignore.case = TRUE)

  vapply(value, function(x) {
    if (is.na(x)) {
      return(NA_character_)
    }

    if (redact_all && !is_url_key) {
      return("[REDACTED]")
    }

    out <- x
    if (is_url_key || grepl("^https?://", out, ignore.case = TRUE)) {
      out <- sub("([?&]).*$", "", out)
    }

    out <- gsub(
      "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
      "[REDACTED_EMAIL]",
      out,
      perl = TRUE
    )
    out <- gsub(
      "(sk-[A-Za-z0-9_-]{10,}|sk-or-[A-Za-z0-9_-]{10,}|openalex[_-]api[_-]key[_-]?[A-Za-z0-9_-]*)",
      "[REDACTED_SECRET]",
      out,
      ignore.case = TRUE,
      perl = TRUE
    )

    if (nchar(out) > 500) {
      out <- paste0(substr(out, 1, 500), "...[truncated]")
    }

    out
  }, character(1))
}

async_task_sanitize_metadata <- function(value, key = "") {
  if (is.null(value)) {
    return(NULL)
  }

  if (is.data.frame(value)) {
    return(list(
      rows = nrow(value),
      columns = names(value)
    ))
  }

  if (is.list(value)) {
    keys <- names(value)
    if (is.null(keys)) {
      keys <- rep("", length(value))
    }
    out <- vector("list", length(value))
    names(out) <- names(value)
    for (i in seq_along(value)) {
      out[[i]] <- async_task_sanitize_metadata(value[[i]], keys[i])
    }
    return(out)
  }

  if (is.character(value)) {
    cleaned <- async_task_redact_string(value, key)
    if (length(cleaned) > 20) {
      cleaned <- c(head(cleaned, 20), sprintf("[TRUNCATED_%d_MORE]", length(cleaned) - 20))
    }
    return(cleaned)
  }

  value
}

capture_async_mirai_status <- function() {
  empty <- list(
    available = FALSE,
    awaiting = NA_integer_,
    executing = NA_integer_,
    completed = NA_integer_,
    connections = NA_integer_,
    daemons = NA_integer_,
    error = NULL
  )

  if (!requireNamespace("mirai", quietly = TRUE)) {
    empty$error <- "mirai package is not available"
    return(empty)
  }

  status <- tryCatch(
    mirai::status(),
    error = function(e) e
  )

  if (inherits(status, "error")) {
    empty$error <- conditionMessage(status)
    return(empty)
  }

  mirai_counts <- status$mirai
  get_count <- function(name) {
    if (is.null(mirai_counts) || !name %in% names(mirai_counts)) {
      return(0L)
    }
    as.integer(mirai_counts[[name]])
  }

  daemon_count <- if (is.null(status$daemons)) {
    0L
  } else if (is.numeric(status$daemons)) {
    as.integer(status$daemons[1])
  } else {
    length(status$daemons)
  }

  list(
    available = TRUE,
    awaiting = get_count("awaiting"),
    executing = get_count("executing"),
    completed = get_count("completed"),
    connections = as.integer(async_task_coalesce(status$connections, 0L)),
    daemons = daemon_count,
    error = NULL
  )
}

async_task_timestamp <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
}

async_task_write_event <- function(event, task_id, task_type = NULL,
                                   status = NULL, stage = NULL,
                                   message = NULL, metadata = list()) {
  if (!async_task_enabled()) {
    return(invisible(FALSE))
  }

  metadata <- if (is.list(metadata)) metadata else list(value = metadata)

  task_type <- async_task_coalesce(task_type,
    async_task_context_value(metadata, "task_type", "serapeum.async_task_type")
  )
  session_id <- async_task_context_value(
    metadata,
    "session_id",
    "serapeum.async_session_id"
  )
  notebook_id <- async_task_context_value(
    metadata,
    "notebook_id",
    "serapeum.async_notebook_id"
  )

  metadata <- async_task_without_event_fields(metadata)

  event_record <- list(
    timestamp = async_task_timestamp(),
    event = event,
    task_id = task_id,
    task_type = task_type,
    session_id = session_id,
    notebook_id = notebook_id,
    pid = Sys.getpid(),
    mirai_status = capture_async_mirai_status(),
    status = status,
    stage = stage,
    message = if (!is.null(message)) async_task_redact_string(message, "message") else NULL,
    metadata = async_task_sanitize_metadata(metadata)
  )

  log_path <- async_task_log_path()
  tryCatch({
    dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
    json <- jsonlite::toJSON(
      event_record,
      auto_unbox = TRUE,
      null = "null",
      na = "null"
    )
    cat(json, "\n", file = log_path, append = TRUE)
    TRUE
  }, error = function(e) {
    FALSE
  }) |>
    invisible()
}

async_task_submitted <- function(task_type, task_id, metadata = list()) {
  async_task_write_event(
    event = "submitted",
    task_id = task_id,
    task_type = task_type,
    status = "submitted",
    metadata = metadata
  )
}

async_task_worker_started <- function(task_id, metadata = list()) {
  async_task_write_event(
    event = "worker_started",
    task_id = task_id,
    status = "running",
    metadata = metadata
  )
}

async_task_progress <- function(task_id, stage, message = NULL,
                                metadata = list()) {
  async_task_write_event(
    event = "progress",
    task_id = task_id,
    status = "running",
    stage = stage,
    message = message,
    metadata = metadata
  )
}

async_task_completed <- function(task_id, status, error = NULL,
                                 metadata = list()) {
  if (!is.null(error)) {
    error_message <- if (inherits(error, "condition")) {
      conditionMessage(error)
    } else {
      as.character(error)
    }
    metadata$error <- async_task_redact_string(error_message, "error")
  }

  async_task_write_event(
    event = "completed",
    task_id = task_id,
    status = status,
    metadata = metadata
  )
}

async_task_status_from_result <- function(result) {
  if (!is.null(result$error)) {
    return("failed")
  }
  if (isTRUE(result$cancelled) || isTRUE(result$partial)) {
    return("cancelled")
  }
  if (!is.null(result$status)) {
    return(as.character(result$status))
  }
  if (identical(result$success, FALSE)) {
    return("failed")
  }
  "completed"
}

async_task_current_id <- function(default = NULL) {
  getOption("serapeum.async_task_id", default)
}

async_task_emit_progress <- function(stage, message = NULL, metadata = list()) {
  task_id <- async_task_current_id()
  if (!is.null(task_id) && exists("async_task_progress", mode = "function")) {
    async_task_progress(task_id, stage, message, metadata)
  }
  invisible(NULL)
}

async_task_empty_events <- function() {
  df <- as.data.frame(
    setNames(rep(list(character()), length(ASYNC_TASK_EVENT_COLUMNS)), ASYNC_TASK_EVENT_COLUMNS),
    stringsAsFactors = FALSE
  )
  df$pid <- integer()
  df$mirai_status <- list()
  df$metadata <- list()
  df
}

async_task_event_value <- function(event, key, default = NA_character_) {
  if (is.list(event) && key %in% names(event) && !is.null(event[[key]])) {
    return(event[[key]])
  }
  default
}

async_task_events_to_df <- function(events) {
  if (length(events) == 0) {
    return(async_task_empty_events())
  }

  df <- data.frame(
    timestamp = vapply(events, async_task_event_value, character(1), key = "timestamp"),
    event = vapply(events, async_task_event_value, character(1), key = "event"),
    task_id = vapply(events, async_task_event_value, character(1), key = "task_id"),
    task_type = vapply(events, async_task_event_value, character(1), key = "task_type"),
    session_id = vapply(events, async_task_event_value, character(1), key = "session_id"),
    notebook_id = vapply(events, async_task_event_value, character(1), key = "notebook_id"),
    pid = as.integer(vapply(events, async_task_event_value, integer(1), key = "pid", default = NA_integer_)),
    status = vapply(events, async_task_event_value, character(1), key = "status"),
    stage = vapply(events, async_task_event_value, character(1), key = "stage"),
    message = vapply(events, async_task_event_value, character(1), key = "message"),
    stringsAsFactors = FALSE
  )
  df$mirai_status <- lapply(events, async_task_event_value, key = "mirai_status", default = list())
  df$metadata <- lapply(events, async_task_event_value, key = "metadata", default = list())
  df
}

read_async_task_events <- function(limit = 500, task_id = NULL) {
  log_path <- async_task_log_path()
  if (is.null(log_path) || !file.exists(log_path)) {
    return(async_task_empty_events())
  }

  lines <- tryCatch(
    readLines(log_path, warn = FALSE),
    error = function(e) character()
  )
  if (length(lines) == 0) {
    return(async_task_empty_events())
  }

  events <- lapply(lines, function(line) {
    tryCatch(
      jsonlite::fromJSON(line, simplifyVector = FALSE),
      error = function(e) NULL
    )
  })
  events <- events[!vapply(events, is.null, logical(1))]

  if (!is.null(task_id)) {
    events <- Filter(function(event) identical(event$task_id, task_id), events)
  }

  if (!is.null(limit) && is.numeric(limit) && length(events) > limit) {
    events <- tail(events, limit)
  }

  async_task_events_to_df(events)
}

async_task_parse_time <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || nchar(value) == 0) {
    return(as.POSIXct(NA))
  }
  as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
}

async_task_first_non_missing <- function(values) {
  values <- values[!is.na(values) & nchar(values) > 0]
  if (length(values) == 0) NA_character_ else values[1]
}

async_task_time_diff_ms <- function(end, start) {
  if (is.na(end) || is.na(start)) {
    return(NA_real_)
  }
  as.numeric(difftime(end, start, units = "secs")) * 1000
}

summarize_async_task_events <- function(events) {
  if (is.null(events) || nrow(events) == 0) {
    return(data.frame(
      task_id = character(),
      task_type = character(),
      status = character(),
      submitted_at = as.POSIXct(character()),
      worker_started_at = as.POSIXct(character()),
      first_progress_at = as.POSIXct(character()),
      completed_at = as.POSIXct(character()),
      wait_ms = numeric(),
      first_feedback_ms = numeric(),
      work_ms = numeric(),
      last_message = character(),
      stringsAsFactors = FALSE
    ))
  }

  events$parsed_time <- vapply(
    events$timestamp,
    function(x) as.numeric(async_task_parse_time(x)),
    numeric(1)
  )

  task_ids <- unique(events$task_id[!is.na(events$task_id) & nchar(events$task_id) > 0])
  rows <- lapply(task_ids, function(id) {
    task_events <- events[events$task_id == id, , drop = FALSE]
    task_events <- task_events[order(task_events$parsed_time), , drop = FALSE]

    submitted <- async_task_parse_time(async_task_first_non_missing(
      task_events$timestamp[task_events$event == "submitted"]
    ))
    worker_started <- async_task_parse_time(async_task_first_non_missing(
      task_events$timestamp[task_events$event == "worker_started"]
    ))
    first_progress <- async_task_parse_time(async_task_first_non_missing(
      task_events$timestamp[task_events$event == "progress"]
    ))
    completed_values <- task_events$timestamp[task_events$event == "completed"]
    completed <- async_task_parse_time(if (length(completed_values) == 0) {
      NA_character_
    } else {
      completed_values[length(completed_values)]
    })

    statuses <- task_events$status[!is.na(task_events$status) & nchar(task_events$status) > 0]
    status <- if (length(statuses) > 0) {
      statuses[length(statuses)]
    } else if (!is.na(worker_started)) {
      "running"
    } else {
      "queued"
    }

    messages <- task_events$message[!is.na(task_events$message) & nchar(task_events$message) > 0]

    data.frame(
      task_id = id,
      task_type = async_task_first_non_missing(task_events$task_type),
      status = status,
      submitted_at = submitted,
      worker_started_at = worker_started,
      first_progress_at = first_progress,
      completed_at = completed,
      wait_ms = async_task_time_diff_ms(worker_started, submitted),
      first_feedback_ms = async_task_time_diff_ms(first_progress, submitted),
      work_ms = async_task_time_diff_ms(completed, worker_started),
      last_message = if (length(messages) > 0) messages[length(messages)] else NA_character_,
      stringsAsFactors = FALSE
    )
  })

  summary <- do.call(rbind, rows)
  summary[order(summary$submitted_at, decreasing = TRUE, na.last = TRUE), , drop = FALSE]
}

clear_async_task_events <- function() {
  log_path <- async_task_log_path()
  if (!is.null(log_path) && file.exists(log_path)) {
    file.remove(log_path)
  }
  invisible(TRUE)
}
