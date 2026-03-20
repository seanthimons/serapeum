library(testthat)

# Source required files from project root
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "utils_scoring.R"))) {
  project_root <- getwd()
}

source(file.path(project_root, "R", "utils_scoring.R"))

# ============================================================================
# citation velocity
# ============================================================================

test_that("compute_citation_velocity calculates citations per year", {
  current_year <- as.integer(format(Sys.Date(), "%Y"))

  # 100 citations over 10 years = 10 per year
  expect_equal(compute_citation_velocity(100, current_year - 10), 10)

  # Paper from this year: age clamped to 1

  expect_equal(compute_citation_velocity(50, current_year), 50)

  # Zero citations
  expect_equal(compute_citation_velocity(0, current_year - 5), 0)
})

# ============================================================================
# ubiquity penalty
# ============================================================================

test_that("compute_ubiquity_penalty returns 0 for below-threshold papers", {
  pool <- c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
  # The 90th percentile is 91 (quantile default method)
  # Papers below that should have 0 penalty
  expect_equal(compute_ubiquity_penalty(50, pool), 0)
  expect_equal(compute_ubiquity_penalty(10, pool), 0)
})

test_that("compute_ubiquity_penalty penalizes high-citation papers", {
  pool <- c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100)
  # 100 is the max and above 90th percentile — should have positive penalty
  penalty <- compute_ubiquity_penalty(100, pool)
  expect_gt(penalty, 0)
  expect_lte(penalty, 1)
})

test_that("compute_ubiquity_penalty handles empty pool", {
  expect_equal(compute_ubiquity_penalty(100, numeric(0)), 0)
})

test_that("compute_ubiquity_penalty handles all-zero pool", {
  expect_equal(compute_ubiquity_penalty(0, c(0, 0, 0)), 0)
})

# ============================================================================
# seed connectivity
# ============================================================================

test_that("compute_seed_connectivity counts forward connections", {
  anchor_refs <- list(
    c("W1", "W2", "W3"),  # seed 1 cites W1, W2, W3
    c("W2", "W4")          # seed 2 cites W2, W4
  )
  anchor_ids <- c("S1", "S2")

  # W2 is cited by both seeds
  expect_equal(compute_seed_connectivity("W2", anchor_refs, anchor_ids), 2)

  # W1 is cited by seed 1 only
  expect_equal(compute_seed_connectivity("W1", anchor_refs, anchor_ids), 1)

  # W5 is not cited by any seed
  expect_equal(compute_seed_connectivity("W5", anchor_refs, anchor_ids), 0)
})

test_that("compute_seed_connectivity counts backward connections", {
  anchor_refs <- list(character(0))
  anchor_ids <- c("S1", "S2")

  # Candidate cites both seeds
  expect_equal(
    compute_seed_connectivity("W1", anchor_refs, anchor_ids,
                               candidate_refs = c("S1", "S2")),
    2
  )

  # Candidate cites one seed
  expect_equal(
    compute_seed_connectivity("W1", anchor_refs, anchor_ids,
                               candidate_refs = c("S1", "X1")),
    1
  )
})

test_that("compute_seed_connectivity combines forward and backward", {
  anchor_refs <- list(c("W1"))  # seed cites W1
  anchor_ids <- c("S1")

  # W1 is cited by the seed (forward=1) AND cites the seed back (backward=1)
  expect_equal(
    compute_seed_connectivity("W1", anchor_refs, anchor_ids,
                               candidate_refs = c("S1")),
    2
  )
})

# ============================================================================
# preset weights
# ============================================================================

test_that("get_preset_weights returns valid weights for all modes", {
  for (mode in c("discovery", "comprehensive", "emerging")) {
    w <- get_preset_weights(mode)
    expect_true(is.list(w))
    expect_named(w, c("w1", "w2", "w3", "w4", "w5", "w6"))
    # All weights should be positive
    expect_true(all(vapply(w, function(x) x >= 0, logical(1))))
  }
})

test_that("get_preset_weights returns discovery for unknown mode", {
  expect_equal(get_preset_weights("unknown"), get_preset_weights("discovery"))
})

# ============================================================================
# utility score with re-normalization
# ============================================================================

test_that("compute_utility_score works with all components available", {
  weights <- list(w1 = 0.2, w2 = 0.2, w3 = 0.2, w4 = 0.2, w5 = 0.2)
  score <- compute_utility_score(1.0, 0.5, 0.8, 0.6, 0.3, weights)
  # Expected: 0.2*1.0 + 0.2*0.5 + 0.2*0.8 + 0.2*0.6 - 0.2*0.3 = 0.52
  expect_equal(score, 0.52, tolerance = 1e-10)
})

test_that("compute_utility_score re-normalizes when FWCI is NA", {
  weights <- list(w1 = 0.2, w2 = 0.2, w3 = 0.2, w4 = 0.2, w5 = 0.2)

  # With FWCI NA: only 4 components active (w1+w2+w3+w5 = 0.8)
  # Scale factor: 1.0 / 0.8 = 1.25
  # Score: 1.25 * (0.2*1.0 + 0.2*0.5 + 0.2*0.8 - 0.2*0.3)
  #      = 1.25 * (0.2 + 0.1 + 0.16 - 0.06) = 1.25 * 0.4 = 0.5
  score <- compute_utility_score(1.0, 0.5, 0.8, NA, 0.3, weights)
  expect_equal(score, 0.5, tolerance = 1e-10)
})

test_that("compute_utility_score re-normalizes when bridge and FWCI are NA", {
  weights <- list(w1 = 0.2, w2 = 0.2, w3 = 0.2, w4 = 0.2, w5 = 0.2)

  # Only w1, w3, w5 active (total = 0.6). Scale = 1.0 / 0.6 = 5/3
  # Score: (5/3) * (0.2*1.0 + 0.2*0.8 - 0.2*0.3)
  #      = (5/3) * (0.2 + 0.16 - 0.06) = (5/3) * 0.3 = 0.5
  score <- compute_utility_score(1.0, NA, 0.8, NA, 0.3, weights)
  expect_equal(score, 0.5, tolerance = 1e-10)
})

test_that("compute_utility_score returns 0 when all components are NA", {
  weights <- list(w1 = 0.2, w2 = 0.2, w3 = 0.2, w4 = 0.2, w5 = 0.2)
  expect_equal(compute_utility_score(NA, NA, NA, NA, NA, weights), 0)
})

# ============================================================================
# normalize_01
# ============================================================================

test_that("normalize_01 scales to 0-1", {
  expect_equal(normalize_01(c(0, 5, 10)), c(0, 0.5, 1))
})

test_that("normalize_01 handles constant values", {
  expect_equal(normalize_01(c(5, 5, 5)), c(0.5, 0.5, 0.5))
})

test_that("normalize_01 handles empty input", {
  expect_equal(normalize_01(numeric(0)), numeric(0))
})

# ============================================================================
# score_candidate_pool integration
# ============================================================================

test_that("score_candidate_pool scores and ranks a small pool", {
  candidates <- data.frame(
    paper_id = c("W1", "W2", "W3"),
    title = c("Paper A", "Paper B", "Paper C"),
    authors = c("[]", "[]", "[]"),
    abstract = c(NA, NA, NA),
    year = c(2020, 2023, 2015),
    venue = c(NA, NA, NA),
    doi = c(NA, NA, NA),
    cited_by_count = c(100, 50, 500),
    fwci = c(2.0, 3.5, 1.0),
    referenced_works_count = c(30, 20, 80),
    stringsAsFactors = FALSE
  )

  weights <- get_preset_weights("discovery")
  result <- score_candidate_pool(candidates, weights)

  expect_equal(nrow(result), 3)
  expect_true("utility_score" %in% names(result))
  expect_true("rank" %in% names(result))
  expect_true("citation_velocity" %in% names(result))
  expect_true("ubiquity_penalty" %in% names(result))

  # Results should be sorted by utility_score descending
  expect_true(all(diff(result$utility_score) <= 0))

  # Rank should be 1, 2, 3
  expect_equal(result$rank, 1:3)
})

test_that("score_candidate_pool handles missing FWCI gracefully", {
  candidates <- data.frame(
    paper_id = c("W1", "W2"),
    title = c("A", "B"),
    authors = c("[]", "[]"),
    abstract = c(NA, NA),
    year = c(2020, 2022),
    venue = c(NA, NA),
    doi = c(NA, NA),
    cited_by_count = c(100, 50),
    fwci = c(NA_real_, NA_real_),
    referenced_works_count = c(30, 20),
    stringsAsFactors = FALSE
  )

  weights <- get_preset_weights("discovery")
  result <- score_candidate_pool(candidates, weights)

  # Should still produce scores
  expect_equal(nrow(result), 2)
  expect_true(all(!is.na(result$utility_score)))
})

test_that("score_candidate_pool handles empty data frame", {
  empty <- data.frame(
    paper_id = character(0), title = character(0), authors = character(0),
    abstract = character(0), year = integer(0), venue = character(0),
    doi = character(0), cited_by_count = integer(0), fwci = double(0),
    referenced_works_count = integer(0),
    stringsAsFactors = FALSE
  )

  result <- score_candidate_pool(empty, get_preset_weights("discovery"))
  expect_equal(nrow(result), 0)
})
