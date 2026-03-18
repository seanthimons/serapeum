library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "pdf_extraction.R"))) {
  project_root <- getwd()
}
source(file.path(project_root, "R", "pdf_extraction.R"))

# =============================================================================
# extraction_config()
# =============================================================================

test_that("extraction_config returns expected defaults", {
  cfg <- extraction_config()
  expect_type(cfg, "list")
  expect_equal(cfg$render_dpi, 150)
  expect_equal(cfg$min_width, 50)
  expect_equal(cfg$min_height, 50)
  expect_equal(cfg$max_text_coverage, 0.92)
  expect_equal(cfg$min_gap_frac, 0.10)
  expect_equal(cfg$min_gap_frac_hint, 0.05)
  expect_equal(cfg$sparse_text_max_boxes, 350)
  expect_equal(cfg$min_file_size, 1000)
  expect_equal(cfg$min_caption_chars, 50)
  expect_equal(cfg$max_caption_chars, 500)
  expect_equal(cfg$max_cont_lines, 5)
  expect_true(length(cfg$caption_patterns) > 0)
})

# =============================================================================
# find_gaps()
# =============================================================================

test_that("find_gaps detects a single gap", {
  occupancy <- c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 1)
  expect_equal(gaps[[1]]$start, 3)
  expect_equal(gaps[[1]]$end, 5)
})

test_that("find_gaps detects multiple gaps", {
  occupancy <- c(TRUE, FALSE, FALSE, TRUE, FALSE, TRUE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 2)
  expect_equal(gaps[[1]]$start, 2)
  expect_equal(gaps[[1]]$end, 3)
  expect_equal(gaps[[2]]$start, 5)
  expect_equal(gaps[[2]]$end, 5)
})

test_that("find_gaps handles gap at end", {
  occupancy <- c(TRUE, TRUE, FALSE, FALSE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 1)
  expect_equal(gaps[[1]]$start, 3)
  expect_equal(gaps[[1]]$end, 4)
})

test_that("find_gaps handles gap at start", {
  occupancy <- c(FALSE, FALSE, TRUE, TRUE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 1)
  expect_equal(gaps[[1]]$start, 1)
  expect_equal(gaps[[1]]$end, 2)
})

test_that("find_gaps returns empty for fully occupied vector", {
  occupancy <- c(TRUE, TRUE, TRUE, TRUE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 0)
})

test_that("find_gaps returns one gap for fully empty vector", {
  occupancy <- c(FALSE, FALSE, FALSE, FALSE)
  gaps <- find_gaps(occupancy, length(occupancy))
  expect_length(gaps, 1)
  expect_equal(gaps[[1]]$start, 1)
  expect_equal(gaps[[1]]$end, 4)
})

# =============================================================================
# bitmap_to_array()
# =============================================================================

test_that("bitmap_to_array transposes dimensions correctly", {
  # Simulate raw bitmap: 4 channels, 10 wide, 5 high
  n_ch <- 4; w <- 10; h <- 5
  bm <- array(as.raw(seq_len(n_ch * w * h) %% 256), dim = c(n_ch, w, h))

  result <- bitmap_to_array(bm)

  expect_equal(dim(result), c(h, w, n_ch))
  expect_type(result, "integer")
})

test_that("bitmap_to_array handles 3-channel bitmap", {
  n_ch <- 3; w <- 8; h <- 6
  bm <- array(as.raw(0), dim = c(n_ch, w, h))

  result <- bitmap_to_array(bm)

  expect_equal(dim(result), c(h, w, n_ch))
})

# =============================================================================
# is_mostly_blank()
# =============================================================================

test_that("is_mostly_blank returns TRUE for white image", {
  white <- array(255L, dim = c(10, 10, 3))
  expect_true(is_mostly_blank(white))
})

test_that("is_mostly_blank returns FALSE for non-white image", {
  dark <- array(50L, dim = c(10, 10, 3))
  expect_false(is_mostly_blank(dark))
})

test_that("is_mostly_blank respects threshold", {
  # 80% white
  img <- array(255L, dim = c(10, 10, 3))
  img[1:2, , ] <- 0L  # 20% black

  expect_true(is_mostly_blank(img, threshold = 0.70))
  expect_false(is_mostly_blank(img, threshold = 0.90))
})

# =============================================================================
# filter_by_size()
# =============================================================================

test_that("filter_by_size removes small figures", {
  cfg <- extraction_config()
  manifest <- data.frame(
    page = c(1L, 2L, 3L),
    figure_index = c(1L, 1L, 1L),
    width = c(100L, 10L, 200L),
    height = c(100L, 10L, 200L),
    file_size = c(5000L, 500L, 10000L),
    method = c("crop", "crop", "crop"),
    stringsAsFactors = FALSE
  )

  result <- filter_by_size(manifest, cfg)
  expect_equal(nrow(result), 2)
  expect_equal(result$page, c(1L, 3L))
})

test_that("filter_by_size returns empty for empty input", {
  cfg <- extraction_config()
  manifest <- data.frame(
    page = integer(), width = integer(), height = integer(),
    file_size = integer(), method = character(),
    stringsAsFactors = FALSE
  )
  result <- filter_by_size(manifest, cfg)
  expect_equal(nrow(result), 0)
})

# =============================================================================
# extract_captions()
# =============================================================================

test_that("extract_captions finds Figure N patterns", {
  # Mock pdf_data output: one page with "Figure 1 Shows results"
  text_data <- list(
    data.frame(
      x = c(72, 120, 160, 220),
      y = c(100, 100, 100, 100),
      width = c(40, 10, 50, 60),
      height = c(10, 10, 10, 10),
      space = c(TRUE, TRUE, TRUE, FALSE),
      text = c("Figure", "1", "Shows", "results"),
      stringsAsFactors = FALSE
    )
  )

  captions <- extract_captions(text_data)
  expect_equal(nrow(captions), 1)
  expect_equal(captions$page, 1L)
  expect_true(grepl("Figure", captions$figure_label))
  expect_true(grepl("Shows results", captions$caption_text))
})

test_that("extract_captions handles Fig. abbreviation", {
  text_data <- list(
    data.frame(
      x = c(72, 100, 140),
      y = c(200, 200, 200),
      width = c(25, 10, 60),
      height = c(10, 10, 10),
      space = c(TRUE, TRUE, FALSE),
      text = c("Fig.", "2", "Distribution"),
      stringsAsFactors = FALSE
    )
  )

  captions <- extract_captions(text_data)
  expect_equal(nrow(captions), 1)
  expect_true(grepl("2", captions$figure_label))
})

test_that("extract_captions is case-insensitive", {
  text_data <- list(
    data.frame(
      x = c(72, 140),
      y = c(300, 300),
      width = c(55, 10),
      height = c(10, 10),
      space = c(TRUE, FALSE),
      text = c("FIGURE", "3"),
      stringsAsFactors = FALSE
    )
  )

  captions <- extract_captions(text_data)
  expect_equal(nrow(captions), 1)
})

test_that("extract_captions returns empty for no captions", {
  text_data <- list(
    data.frame(
      x = c(72, 120),
      y = c(100, 100),
      width = c(40, 60),
      height = c(10, 10),
      space = c(TRUE, FALSE),
      text = c("Hello", "world"),
      stringsAsFactors = FALSE
    )
  )

  captions <- extract_captions(text_data)
  expect_equal(nrow(captions), 0)
})

# =============================================================================
# filter_margin_watermark()
# =============================================================================

test_that("filter_margin_watermark removes rotated text at page edge", {
  # Simulate a Wiley-style watermark: narrow boxes at x=579, spanning full page
  body <- data.frame(
    x = c(72, 150, 72, 150),
    y = c(100, 100, 500, 500),
    width = c(40, 60, 40, 60),
    height = c(10, 10, 10, 10),
    text = c("Body", "text", "more", "text"),
    stringsAsFactors = FALSE
  )
  watermark <- data.frame(
    x = rep(579, 10),
    y = seq(20, 740, length.out = 10),
    width = rep(4, 10),
    height = rep(10, 10),
    text = c("Downloaded", "from", "https://example.com", "by", "US",
             "EPA", "Library", "on", "2026", "Terms"),
    stringsAsFactors = FALSE
  )
  page_text <- rbind(body, watermark)

  result <- filter_margin_watermark(page_text)
  # Watermark should be removed, body text kept
  expect_equal(nrow(result), 4)
  expect_true(all(result$text %in% c("Body", "text", "more", "text")))
})

test_that("filter_margin_watermark preserves narrow content text in page interior", {
  # Narrow boxes in the MIDDLE of the page (e.g., table cells) should be kept
  page_text <- data.frame(
    x = c(72, 200, 300, 400, 72, 200, 300, 400),
    y = c(100, 100, 100, 100, 600, 600, 600, 600),
    width = c(40, 5, 5, 5, 40, 5, 5, 5),
    height = rep(10, 8),
    text = c("Body", "1", "2", "3", "More", "4", "5", "6"),
    stringsAsFactors = FALSE
  )

  result <- filter_margin_watermark(page_text)
  expect_equal(nrow(result), nrow(page_text))
})

test_that("filter_margin_watermark handles empty/NULL input", {
  expect_null(filter_margin_watermark(NULL))

  empty <- data.frame(x = numeric(), y = numeric(), width = numeric(),
                      height = numeric(), text = character(),
                      stringsAsFactors = FALSE)
  result <- filter_margin_watermark(empty)
  expect_equal(nrow(result), 0)
})

# =============================================================================
# empty_figures_df()
# =============================================================================

test_that("empty_figures_df has expected columns", {
  df <- empty_figures_df()
  expect_equal(nrow(df), 0)
  expected_cols <- c("page", "figure_index", "image_data", "width", "height",
                     "file_size", "method", "figure_label", "caption", "caption_quality")
  expect_true(all(expected_cols %in% names(df)))
})

# =============================================================================
# figure_census()
# =============================================================================

test_that("figure_census finds highest figure number", {
  text_data <- list(
    data.frame(
      text = c("Figure", "1", "shows", "the", "results"),
      stringsAsFactors = FALSE
    ),
    data.frame(
      text = c("See", "Figure", "5", "for", "details"),
      stringsAsFactors = FALSE
    )
  )

  expect_equal(figure_census(text_data), 5)
})

test_that("figure_census returns 0 when no figures referenced", {
  text_data <- list(
    data.frame(text = c("No", "figures", "here"), stringsAsFactors = FALSE)
  )

  expect_equal(figure_census(text_data), 0)
})

# =============================================================================
# deduplicate()
# =============================================================================

test_that("deduplicate removes identical content", {
  skip_if_not_installed("digest")

  img_bytes <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 1:20))
  manifest <- data.frame(
    page = c(1L, 2L, 3L),
    figure_index = c(1L, 1L, 1L),
    image_data = I(list(img_bytes, img_bytes, as.raw(c(0x89, 0x50, 1:10)))),
    width = c(100L, 100L, 200L),
    height = c(100L, 100L, 200L),
    file_size = c(24L, 24L, 12L),
    method = rep("crop", 3),
    stringsAsFactors = FALSE
  )

  result <- deduplicate(manifest)
  expect_equal(nrow(result), 2)
  expect_equal(result$page, c(1L, 3L))
})
