library(testthat)
library(DBI)
library(duckdb)

# ---------------------------------------------------------------------------
# Test fixture: in-memory DuckDB with prompt_versions table (mirrors migration 011)
# ---------------------------------------------------------------------------

make_test_con <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  DBI::dbExecute(con, "
    CREATE TABLE prompt_versions (
      preset_slug  VARCHAR   NOT NULL,
      version_date DATE      NOT NULL,
      prompt_text  TEXT      NOT NULL,
      created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (preset_slug, version_date)
    )
  ")
  con
}

# ---------------------------------------------------------------------------
# Source the helper file
# ---------------------------------------------------------------------------

source_app("prompt_helpers.R")

# ---------------------------------------------------------------------------
# PROMPT_DEFAULTS registry tests
# ---------------------------------------------------------------------------

test_that("PROMPT_DEFAULTS exists and has exactly 11 named entries", {
  expect_true(exists("PROMPT_DEFAULTS"))
  expect_equal(length(PROMPT_DEFAULTS), 11)
  expected_slugs <- c(
    "summarize", "keypoints", "studyguide", "outline",
    "conclusions", "overview", "research_questions",
    "lit_review", "methodology", "gap_analysis", "slides"
  )
  expect_setequal(names(PROMPT_DEFAULTS), expected_slugs)
})

test_that("Each PROMPT_DEFAULTS entry is a non-empty character string", {
  for (slug in names(PROMPT_DEFAULTS)) {
    expect_type(PROMPT_DEFAULTS[[slug]], "character")
    expect_gt(nchar(PROMPT_DEFAULTS[[slug]]), 0,
              label = paste("PROMPT_DEFAULTS[[", slug, "]] is non-empty"))
  }
})

test_that("PRESET_GROUPS has Quick (4 slugs) and Deep (7 slugs)", {
  expect_true(exists("PRESET_GROUPS"))
  expect_equal(sort(names(PRESET_GROUPS)), sort(c("Quick", "Deep")))
  expect_equal(length(PRESET_GROUPS[["Quick"]]), 4)
  expect_equal(length(PRESET_GROUPS[["Deep"]]), 7)
  expect_setequal(PRESET_GROUPS[["Quick"]],
                  c("summarize", "keypoints", "studyguide", "outline"))
  expect_setequal(PRESET_GROUPS[["Deep"]],
                  c("overview", "conclusions", "research_questions",
                    "lit_review", "methodology", "gap_analysis", "slides"))
})

test_that("PRESET_DISPLAY_NAMES has 11 named entries covering all slugs", {
  expect_true(exists("PRESET_DISPLAY_NAMES"))
  expect_equal(length(PRESET_DISPLAY_NAMES), 11)
  all_slugs <- c(names(PRESET_GROUPS[["Quick"]]), names(PRESET_GROUPS[["Deep"]]))
  for (slug in all_slugs) {
    expect_true(slug %in% names(PRESET_DISPLAY_NAMES),
                label = paste(slug, "present in PRESET_DISPLAY_NAMES"))
  }
})

# ---------------------------------------------------------------------------
# get_effective_prompt — fallback to hardcoded default
# ---------------------------------------------------------------------------

test_that("get_effective_prompt returns hardcoded default when no custom version exists", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  result <- get_effective_prompt(con, "summarize")
  expect_equal(result, PROMPT_DEFAULTS[["summarize"]])
})

# ---------------------------------------------------------------------------
# save_prompt_version + get_effective_prompt round-trip
# ---------------------------------------------------------------------------

test_that("save_prompt_version + get_effective_prompt returns the custom text", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  save_prompt_version(con, "summarize", "custom text")
  result <- get_effective_prompt(con, "summarize")
  expect_equal(result, "custom text")
})

test_that("save_prompt_version same-day UPSERT replaces existing row", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  save_prompt_version(con, "summarize", "v1")
  save_prompt_version(con, "summarize", "v2")
  result <- get_effective_prompt(con, "summarize")
  expect_equal(result, "v2")
})

# ---------------------------------------------------------------------------
# list_prompt_versions
# ---------------------------------------------------------------------------

test_that("list_prompt_versions returns dates in descending order", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-01-01', 'old')
  ")
  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-01', 'newer')
  ")
  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-06-01', 'newest')
  ")

  dates <- list_prompt_versions(con, "summarize")
  expect_equal(length(dates), 3)
  expect_equal(dates, c("2026-06-01", "2026-03-01", "2026-01-01"))
})

test_that("list_prompt_versions returns empty character vector when no versions exist", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  result <- list_prompt_versions(con, "summarize")
  expect_equal(result, character(0))
})

# ---------------------------------------------------------------------------
# get_prompt_version
# ---------------------------------------------------------------------------

test_that("get_prompt_version returns correct text for a specific date", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-21', 'test prompt text')
  ")

  result <- get_prompt_version(con, "summarize", "2026-03-21")
  expect_equal(result, "test prompt text")
})

test_that("get_prompt_version returns NULL when no matching version", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  result <- get_prompt_version(con, "summarize", "1999-01-01")
  expect_null(result)
})

# ---------------------------------------------------------------------------
# get_active_prompt
# ---------------------------------------------------------------------------

test_that("get_active_prompt returns NULL when no custom versions exist", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  result <- get_active_prompt(con, "summarize")
  expect_null(result)
})

test_that("get_active_prompt returns most recent custom text when versions exist", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-01-01', 'old version')
  ")
  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-21', 'new version')
  ")

  result <- get_active_prompt(con, "summarize")
  expect_equal(result, "new version")
})

# ---------------------------------------------------------------------------
# reset_prompt_to_default
# ---------------------------------------------------------------------------

test_that("reset_prompt_to_default deletes all rows for a slug", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-01-01', 'v1')
  ")
  DBI::dbExecute(con, "
    INSERT INTO prompt_versions (preset_slug, version_date, prompt_text)
    VALUES ('summarize', '2026-03-21', 'v2')
  ")

  reset_prompt_to_default(con, "summarize")

  remaining <- DBI::dbGetQuery(con, "
    SELECT COUNT(*) AS n FROM prompt_versions WHERE preset_slug = 'summarize'
  ")
  expect_equal(remaining$n[[1]], 0)
})

test_that("After reset, get_effective_prompt returns hardcoded default", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  save_prompt_version(con, "summarize", "my custom prompt")
  expect_equal(get_effective_prompt(con, "summarize"), "my custom prompt")

  reset_prompt_to_default(con, "summarize")
  expect_equal(get_effective_prompt(con, "summarize"), PROMPT_DEFAULTS[["summarize"]])
})

# ---------------------------------------------------------------------------
# Cross-slug isolation
# ---------------------------------------------------------------------------

test_that("reset_prompt_to_default only deletes rows for the target slug", {
  con <- make_test_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  save_prompt_version(con, "summarize", "summarize custom")
  save_prompt_version(con, "keypoints", "keypoints custom")

  reset_prompt_to_default(con, "summarize")

  expect_equal(get_effective_prompt(con, "summarize"), PROMPT_DEFAULTS[["summarize"]])
  expect_equal(get_effective_prompt(con, "keypoints"), "keypoints custom")
})
