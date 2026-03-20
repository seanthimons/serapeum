library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "pdf_images.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "pdf_images.R"))

# =============================================================================
# figure_vision_config()
# =============================================================================

test_that("figure_vision_config returns expected defaults", {
  cfg <- figure_vision_config()
  expect_type(cfg, "list")
  expect_equal(cfg$primary_model, "openai/gpt-4.1-nano")
  expect_equal(cfg$fallback_model, "google/gemini-2.5-flash-lite")
  expect_equal(cfg$max_tokens, 500)
  expect_equal(cfg$temperature, 0.2)
  expect_equal(cfg$timeout, 60)
})

# =============================================================================
# build_figure_system_prompt()
# =============================================================================

test_that("system prompt mentions required JSON keys", {
  prompt <- build_figure_system_prompt()
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 100)
  expect_true(grepl("type", prompt))
  expect_true(grepl("summary", prompt))
  expect_true(grepl("details", prompt))
  expect_true(grepl("suggested_caption", prompt))
  expect_true(grepl("JSON", prompt))
})

# =============================================================================
# build_vision_messages()
# =============================================================================

test_that("build_vision_messages creates correct structure from raw bytes", {
  # Minimal PNG-like bytes (just for structure testing, not a real PNG)
  raw_data <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:20))

  msgs <- build_vision_messages(raw_data)
  expect_length(msgs, 2)

  # System message
  expect_equal(msgs[[1]]$role, "system")
  expect_type(msgs[[1]]$content, "character")

  # User message with multipart content
  expect_equal(msgs[[2]]$role, "user")
  expect_type(msgs[[2]]$content, "list")
  expect_length(msgs[[2]]$content, 2)

  # Text part
  expect_equal(msgs[[2]]$content[[1]]$type, "text")
  expect_true(grepl("Describe this figure", msgs[[2]]$content[[1]]$text))

  # Image part
  expect_equal(msgs[[2]]$content[[2]]$type, "image_url")
  expect_true(grepl("^data:image/png;base64,", msgs[[2]]$content[[2]]$image_url$url))
})

test_that("build_vision_messages includes figure_label when provided", {
  raw_data <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:10))
  msgs <- build_vision_messages(raw_data, figure_label = "Figure 3")

  user_text <- msgs[[2]]$content[[1]]$text
  expect_true(grepl("Figure 3", user_text))
})

test_that("build_vision_messages includes caption when provided", {
  raw_data <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:10))
  msgs <- build_vision_messages(raw_data, extracted_caption = "Distribution of results")

  user_text <- msgs[[2]]$content[[1]]$text
  expect_true(grepl("Distribution of results", user_text))
})

test_that("build_vision_messages skips NA label and caption", {
  raw_data <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:10))
  msgs <- build_vision_messages(raw_data, figure_label = NA, extracted_caption = NA)

  user_text <- msgs[[2]]$content[[1]]$text
  expect_false(grepl("Label:", user_text))
  expect_false(grepl("Extracted caption:", user_text))
})

test_that("build_vision_messages works with file path", {
  tmp <- tempfile(fileext = ".png")
  on.exit(unlink(tmp))
  writeBin(as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:20)), tmp)

  msgs <- build_vision_messages(tmp)
  expect_length(msgs, 2)
  expect_true(grepl("^data:image/png;base64,", msgs[[2]]$content[[2]]$image_url$url))
})

# =============================================================================
# parse_vision_response()
# =============================================================================

test_that("parse_vision_response handles clean JSON", {
  json <- '{"type": "plot", "summary": "A scatter plot", "details": "X vs Y", "suggested_caption": "Fig 1", "presentation_hint": "hero"}'
  result <- parse_vision_response(json)
  expect_equal(result$type, "plot")
  expect_equal(result$summary, "A scatter plot")
  expect_equal(result$details, "X vs Y")
  expect_equal(result$suggested_caption, "Fig 1")
  expect_equal(result$presentation_hint, "hero")
})

test_that("parse_vision_response strips markdown code fences", {
  json <- '```json\n{"type": "chart", "summary": "Bar chart", "details": "Counts", "suggested_caption": "Fig 2"}\n```'
  result <- parse_vision_response(json)
  expect_equal(result$type, "chart")
  expect_equal(result$summary, "Bar chart")
})

test_that("parse_vision_response strips bare code fences", {
  json <- '```\n{"type": "diagram", "summary": "Flow", "details": "Steps", "suggested_caption": "Fig 3"}\n```'
  result <- parse_vision_response(json)
  expect_equal(result$type, "diagram")
})

test_that("parse_vision_response falls back on invalid JSON", {
  result <- parse_vision_response("This is not JSON at all")
  expect_equal(result$type, "unknown")
  expect_equal(result$summary, "This is not JSON at all")
  expect_true(is.na(result$details))
})

test_that("parse_vision_response handles missing fields", {
  json <- '{"type": "photo", "summary": "A microscope image"}'
  result <- parse_vision_response(json)
  expect_equal(result$type, "photo")
  expect_equal(result$summary, "A microscope image")
  expect_true(is.na(result$details))
  expect_true(is.na(result$suggested_caption))
  # Missing presentation_hint defaults to "supporting"
  expect_equal(result$presentation_hint, "supporting")
})

test_that("parse_vision_response defaults presentation_hint on fallback", {
  result <- parse_vision_response("Not JSON")
  expect_equal(result$presentation_hint, "supporting")
})
