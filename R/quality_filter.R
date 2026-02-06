# Quality Filter Module
# Handles fetching, caching, and checking paper quality data
# Sources: Retraction Watch, predatoryjournals.org

library(httr2)

# Data source URLs (hardcoded)
QUALITY_DATA_SOURCES <- list(
  predatory_publishers = "https://docs.google.com/spreadsheets/d/1BHM4aJljhbOAzSpkX1kXDUEvy6vxREZu5WJaDH6M1Vk/export?format=csv&gid=0",
  predatory_journals = "https://docs.google.com/spreadsheets/d/1Qa1lAlSbl7iiKddYINNsDB4wxI7uUA4IVseeLnCc5U4/export?format=csv&gid=0",
  retraction_watch = "https://gitlab.com/crossref/retraction-watch-data/-/raw/main/retraction_watch.csv"
)

#' Normalize a name for matching
#'
#' Converts to lowercase, removes punctuation (except spaces),
#' and collapses whitespace.
#'
#' @param name Character string to normalize
#' @return Normalized string
#' @examples
#' normalize_name("Journal of Advanced Research")
#' # "journal of advanced research"
#' normalize_name("J. Adv. Res.")
#' # "j adv res"
normalize_name <- function(name) {
 if (is.null(name) || is.na(name)) return("")

  name |>
    tolower() |>
    gsub("[^a-z0-9 ]", "", x = _) |>
    gsub("\\s+", " ", x = _) |>
    trimws()
}

#' Fetch predatory publishers list from Google Sheets
#'
#' @return Data frame with 'name' column, or NULL on error
fetch_predatory_publishers <- function() {
  tryCatch({
    resp <- request(QUALITY_DATA_SOURCES$predatory_publishers) |>
      req_timeout(60) |>
      req_perform()

    # Parse CSV - has numbered list, second column is publisher name
    content <- resp_body_string(resp)
    df <- read.csv(text = content, header = FALSE, stringsAsFactors = FALSE)

    # Column 2 contains the publisher names
    if (ncol(df) >= 2) {
      publishers <- data.frame(
        name = trimws(df[[2]]),
        stringsAsFactors = FALSE
      )
      # Remove empty rows and header-like rows
      publishers <- publishers[publishers$name != "" & !grepl("^[0-9]+$", publishers$name), , drop = FALSE]
      publishers
    } else {
      NULL
    }
  }, error = function(e) {
    message("Failed to fetch predatory publishers: ", e$message)
    NULL
  })
}

#' Fetch predatory journals list from Google Sheets
#'
#' @return Data frame with 'name' and 'is_hijacked' columns, or NULL on error
fetch_predatory_journals <- function() {
  tryCatch({
    resp <- request(QUALITY_DATA_SOURCES$predatory_journals) |>
      req_timeout(60) |>
      req_perform()

    # Parse CSV - has numbered list, second column is journal name
    content <- resp_body_string(resp)
    df <- read.csv(text = content, header = FALSE, stringsAsFactors = FALSE)

    # Column 2 contains the journal names
    if (ncol(df) >= 2) {
      journals <- data.frame(
        name = trimws(df[[2]]),
        stringsAsFactors = FALSE
      )
      # Remove empty rows
      journals <- journals[journals$name != "", , drop = FALSE]

      # Detect hijacked journals (marked with "hijacker of" in the name)
      journals$is_hijacked <- grepl("hijacker of", journals$name, ignore.case = TRUE)

      journals
    } else {
      NULL
    }
  }, error = function(e) {
    message("Failed to fetch predatory journals: ", e$message)
    NULL
  })
}

#' Fetch retraction watch data from GitLab
#'
#' @return Data frame with doi, title, retraction_date, reason columns, or NULL on error
fetch_retraction_watch <- function() {
  tryCatch({
    resp <- request(QUALITY_DATA_SOURCES$retraction_watch) |>
      req_timeout(120) |>  # Larger file, longer timeout
      req_perform()

    content <- resp_body_string(resp)

    # Parse CSV - Retraction Watch format has many columns
    # Key columns: OriginalPaperDOI, Title, RetractionDate, Reason
    df <- read.csv(text = content, header = TRUE, stringsAsFactors = FALSE, quote = "\"")

    # Map to our schema - column names may vary, try common patterns
    doi_col <- intersect(names(df), c("OriginalPaperDOI", "DOI", "doi", "original_paper_doi"))[1]
    title_col <- intersect(names(df), c("Title", "title", "OriginalPaperTitle", "original_paper_title"))[1]
    date_col <- intersect(names(df), c("RetractionDate", "retraction_date", "Retraction Date"))[1]
    reason_col <- intersect(names(df), c("Reason", "reason", "RetractionReasons", "retraction_reasons"))[1]

    if (is.na(doi_col)) {
      message("Could not find DOI column in Retraction Watch data")
      return(NULL)
    }

    papers <- data.frame(
      doi = df[[doi_col]],
      title = if (!is.na(title_col)) df[[title_col]] else NA_character_,
      retraction_date = if (!is.na(date_col)) df[[date_col]] else NA_character_,
      reason = if (!is.na(reason_col)) df[[reason_col]] else NA_character_,
      stringsAsFactors = FALSE
    )

    # Remove rows without DOI
    papers <- papers[!is.na(papers$doi) & papers$doi != "", ]

    # Normalize DOIs (lowercase, trim)
    papers$doi <- tolower(trimws(papers$doi))

    papers
  }, error = function(e) {
    message("Failed to fetch Retraction Watch data: ", e$message)
    NULL
  })
}

#' Refresh all quality filter caches
#'
#' Fetches latest data from all sources and updates local cache.
#'
#' @param con DuckDB connection
#' @param progress_callback Optional function(message, step, total) for progress updates
#' @return List with success status and counts for each source
refresh_quality_cache <- function(con, progress_callback = NULL) {
  results <- list(
    success = TRUE,
    predatory_publishers = list(success = FALSE, count = 0, error = NULL),
    predatory_journals = list(success = FALSE, count = 0, error = NULL),
    retraction_watch = list(success = FALSE, count = 0, error = NULL)
  )

  # 1. Predatory Publishers
  message("[quality_refresh] Step 1/3: Fetching predatory publishers...")
  if (!is.null(progress_callback)) progress_callback("Fetching predatory publishers...", 1, 3)

  publishers_result <- tryCatch({
    publishers <- fetch_predatory_publishers()
    if (!is.null(publishers)) {
      message("[quality_refresh] Fetched ", nrow(publishers), " publishers, caching...")
      count <- cache_predatory_publishers(con, publishers, normalize_name)
      message("[quality_refresh] Publishers cached successfully: ", count)
      list(success = TRUE, count = count, error = NULL)
    } else {
      message("[quality_refresh] Publishers fetch returned NULL")
      list(success = FALSE, count = 0, error = "Empty response from Google Sheets")
    }
  }, error = function(e) {
    message("[quality_refresh] Publishers error: ", e$message)
    list(success = FALSE, count = 0, error = e$message)
  })
  results$predatory_publishers <- publishers_result
  if (!publishers_result$success) results$success <- FALSE

  # 2. Predatory Journals
  message("[quality_refresh] Step 2/3: Fetching predatory journals...")
  if (!is.null(progress_callback)) progress_callback("Fetching predatory journals...", 2, 3)

  journals_result <- tryCatch({
    journals <- fetch_predatory_journals()
    if (!is.null(journals)) {
      message("[quality_refresh] Fetched ", nrow(journals), " journals, caching...")
      count <- cache_predatory_journals(con, journals, normalize_name)
      message("[quality_refresh] Journals cached successfully: ", count)
      list(success = TRUE, count = count, error = NULL)
    } else {
      message("[quality_refresh] Journals fetch returned NULL")
      list(success = FALSE, count = 0, error = "Empty response from Google Sheets")
    }
  }, error = function(e) {
    message("[quality_refresh] Journals error: ", e$message)
    list(success = FALSE, count = 0, error = e$message)
  })
  results$predatory_journals <- journals_result
  if (!journals_result$success) results$success <- FALSE

  # 3. Retraction Watch
  message("[quality_refresh] Step 3/3: Fetching retraction data...")
  if (!is.null(progress_callback)) progress_callback("Fetching retraction data...", 3, 3)

  retraction_result <- tryCatch({
    papers <- fetch_retraction_watch()
    if (!is.null(papers)) {
      message("[quality_refresh] Fetched ", nrow(papers), " retractions, caching...")
      count <- cache_retracted_papers(con, papers)
      message("[quality_refresh] Retractions cached successfully: ", count)
      list(success = TRUE, count = count, error = NULL)
    } else {
      message("[quality_refresh] Retractions fetch returned NULL")
      list(success = FALSE, count = 0, error = "Empty response from GitLab")
    }
  }, error = function(e) {
    message("[quality_refresh] Retractions error: ", e$message)
    list(success = FALSE, count = 0, error = e$message)
  })
  results$retraction_watch <- retraction_result
  if (!retraction_result$success) results$success <- FALSE

  message("[quality_refresh] Complete. Success: ", results$success)

  results
}

#' Check quality flags for a single paper
#'
#' @param paper List with doi, venue (journal name), and publisher fields
#' @param retracted_dois Character vector of retracted DOIs (for fast lookup)
#' @param predatory_journals Character vector of normalized predatory journal names
#' @param predatory_publishers Character vector of normalized predatory publisher names
#' @return List with is_retracted, is_predatory_journal, is_predatory_publisher, flags (character vector)
check_paper_quality <- function(paper, retracted_dois = character(),
                                 predatory_journals = character(),
                                 predatory_publishers = character()) {
  result <- list(
    is_retracted = FALSE,
    is_predatory_journal = FALSE,
    is_predatory_publisher = FALSE,
    predatory_match = NULL,  # Which name matched
    flags = character()
  )

  # Check retraction by DOI
  if (!is.null(paper$doi) && !is.na(paper$doi) && paper$doi != "") {
    doi_normalized <- tolower(trimws(paper$doi))
    if (doi_normalized %in% retracted_dois) {
      result$is_retracted <- TRUE
      result$flags <- c(result$flags, "Retracted paper")
    }
  }

  # Check predatory journal by venue name
  if (!is.null(paper$venue) && !is.na(paper$venue) && paper$venue != "") {
    venue_normalized <- normalize_name(paper$venue)
    if (venue_normalized %in% predatory_journals) {
      result$is_predatory_journal <- TRUE
      result$predatory_match <- paper$venue
      result$flags <- c(result$flags, paste0("Predatory journal: ", paper$venue))
    }
  }

  # Check predatory publisher
  publisher <- paper$publisher %||% paper$host_organization_name %||% NULL
  if (!is.null(publisher) && !is.na(publisher) && publisher != "") {
    publisher_normalized <- normalize_name(publisher)
    if (publisher_normalized %in% predatory_publishers) {
      result$is_predatory_publisher <- TRUE
      result$predatory_match <- publisher
      result$flags <- c(result$flags, paste0("Predatory publisher: ", publisher))
    }
  }

  result
}

#' Check quality flags for multiple papers (batch)
#'
#' Loads lookup sets once and checks all papers efficiently.
#'
#' @param con DuckDB connection
#' @param papers List of paper objects (each with doi, venue, publisher fields)
#' @return List of quality check results, same length as papers
check_papers_quality_batch <- function(con, papers) {
  # Load lookup sets once
  retracted_dois <- get_retracted_dois_set(con)
  predatory_journals <- get_predatory_journals_set(con)
  predatory_publishers <- get_predatory_publishers_set(con)

  # Check each paper
  lapply(papers, function(paper) {
    check_paper_quality(paper, retracted_dois, predatory_journals, predatory_publishers)
  })
}

#' Check if quality cache is stale or empty
#'
#' @param con DuckDB connection
#' @param max_age_days Number of days before cache is considered stale
#' @return List with is_empty, is_stale, last_updated, sources (details per source)
check_quality_cache_status <- function(con, max_age_days = 7) {
  meta <- get_quality_cache_meta(con)

  if (is.null(meta) || nrow(meta) == 0) {
    return(list(
      is_empty = TRUE,
      is_stale = TRUE,
      last_updated = NULL,
      sources = list()
    ))
  }

  # Check staleness
  now <- Sys.time()
  max_age_secs <- max_age_days * 24 * 60 * 60

  sources <- list()
  oldest_update <- now
  any_stale <- FALSE

  for (i in seq_len(nrow(meta))) {
    source <- meta$source[i]
    last_updated <- as.POSIXct(meta$last_updated[i])
    age_secs <- as.numeric(difftime(now, last_updated, units = "secs"))
    is_stale <- age_secs > max_age_secs

    sources[[source]] <- list(
      last_updated = last_updated,
      record_count = meta$record_count[i],
      is_stale = is_stale
    )

    if (last_updated < oldest_update) oldest_update <- last_updated
    if (is_stale) any_stale <- TRUE
  }

  list(
    is_empty = FALSE,
    is_stale = any_stale,
    last_updated = oldest_update,
    sources = sources
  )
}

#' Format cache status for display
#'
#' @param status Result from check_quality_cache_status()
#' @return Character string for UI display
format_cache_status <- function(status) {
  if (status$is_empty) {
    return("No quality data cached. Click 'Refresh' to download.")
  }

  if (status$is_stale) {
    days_ago <- as.integer(difftime(Sys.time(), status$last_updated, units = "days"))
    return(sprintf("Data last updated %d days ago (stale)", days_ago))
  }

  format(status$last_updated, "Data updated: %Y-%m-%d %H:%M")
}
