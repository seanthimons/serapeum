# Scoring Utilities for Research Refiner
#
# Pure functions for computing paper utility scores.
# No Shiny dependencies — reusable by any module.

#' Compute citation velocity (citations per year since publication)
#'
#' @param cited_by_count Integer citation count
#' @param year Integer publication year
#' @return Numeric citations per year
compute_citation_velocity <- function(cited_by_count, year) {
  current_year <- as.integer(format(Sys.Date(), "%Y"))
  age <- max(current_year - year, 1L)
  cited_by_count / age
}

#' Compute ubiquity penalty
#'
#' Papers with citation counts above the pool's threshold percentile are
#' penalized as "assumed knowledge." Returns 0-1 where 1 = maximum penalty.
#'
#' @param cited_by_count Integer citation count for this paper
#' @param pool_citations Numeric vector of all citation counts in the pool
#' @param threshold Percentile above which papers are penalized (0-1, default 0.9)
#' @return Numeric penalty 0-1
compute_ubiquity_penalty <- function(cited_by_count, pool_citations,
                                      threshold = 0.9) {
  if (length(pool_citations) == 0) return(0)
  threshold_value <- quantile(pool_citations, probs = threshold, names = FALSE)
  if (threshold_value == 0) return(0)

  if (cited_by_count > threshold_value) {
    pool_max <- max(pool_citations)
    if (pool_max == threshold_value) return(1)
    min((cited_by_count - threshold_value) / (pool_max - threshold_value), 1)
  } else {
    0
  }
}

#' Compute seed connectivity
#'
#' Counts how many anchor (seed) papers have a direct citation link to this
#' candidate — either the seed cites the candidate, or the candidate cites the
#' seed.
#'
#' @param paper_id Character OpenAlex work ID (W-prefixed)
#' @param anchor_refs List of character vectors — each element is the
#'   referenced_works list for one seed paper
#' @param anchor_ids Character vector of seed paper IDs
#' @param candidate_refs Character vector of this candidate's referenced_works
#' @return Integer connectivity count
compute_seed_connectivity <- function(paper_id, anchor_refs, anchor_ids,
                                       candidate_refs = character(0)) {
  # How many seeds cite this candidate (candidate appears in seed's refs)
  forward <- sum(vapply(anchor_refs, function(refs) {
    paper_id %in% refs
  }, logical(1)))

  # How many seeds this candidate cites (seed appears in candidate's refs)
  backward <- sum(anchor_ids %in% candidate_refs)

  forward + backward
}

#' Get preset weights for a scoring mode
#'
#' @param mode Character: "discovery", "comprehensive", or "emerging"
#' @return Named list with w1-w6
get_preset_weights <- function(mode = "discovery") {
  switch(mode,
    discovery = list(
      w1 = 0.25,  # seed_connectivity
      w2 = 0.30,  # bridge_score
      w3 = 0.20,  # citation_velocity
      w4 = 0.15,  # fwci
      w5 = 0.30,  # ubiquity_penalty
      w6 = 0.30   # embedding_similarity
    ),
    comprehensive = list(
      w1 = 0.30,
      w2 = 0.10,
      w3 = 0.20,
      w4 = 0.30,
      w5 = 0.05,
      w6 = 0.25
    ),
    emerging = list(
      w1 = 0.10,
      w2 = 0.15,
      w3 = 0.40,
      w4 = 0.25,
      w5 = 0.20,
      w6 = 0.20
    ),
    # Default to discovery
    list(w1 = 0.25, w2 = 0.30, w3 = 0.20, w4 = 0.15, w5 = 0.30, w6 = 0.30)
  )
}

#' Compute composite utility score with weight re-normalization
#'
#' When a scoring component is unavailable (NA/NULL), its weight is excluded
#' and the remaining weights are re-normalized to sum to the original total.
#' This avoids penalizing papers that lack certain metadata (e.g., preprints
#' without FWCI, candidates without graph data for bridge scores).
#'
#' @param seed_connectivity Numeric or NA
#' @param bridge_score Numeric or NA
#' @param citation_velocity Numeric or NA
#' @param fwci Numeric or NA
#' @param ubiquity_penalty Numeric or NA (this is subtracted, not added)
#' @param embedding_similarity Numeric or NA (Tier 2 semantic signal)
#' @param weights Named list with w1-w6
#' @return Numeric composite score
compute_utility_score <- function(seed_connectivity, bridge_score,
                                   citation_velocity, fwci, ubiquity_penalty,
                                   weights,
                                   embedding_similarity = NA_real_) {
  # Build components: name, value, weight, is_penalty
  components <- list(
    list(val = seed_connectivity,   w = weights$w1, penalty = FALSE),
    list(val = bridge_score,        w = weights$w2, penalty = FALSE),
    list(val = citation_velocity,   w = weights$w3, penalty = FALSE),
    list(val = fwci,                w = weights$w4, penalty = FALSE),
    list(val = ubiquity_penalty,    w = weights$w5, penalty = TRUE),
    list(val = embedding_similarity, w = weights$w6 %||% 0, penalty = FALSE)
  )

  # Separate available from missing
  available <- Filter(function(c) !is.null(c$val) && !is.na(c$val), components)

  if (length(available) == 0) return(0)

  # Re-normalize weights for available components to sum to 1.0
  total_available_weight <- sum(vapply(available, function(c) c$w, numeric(1)))
  if (total_available_weight == 0) return(0)

  score <- 0
  for (comp in available) {
    normalized_weight <- comp$w / total_available_weight
    if (comp$penalty) {
      score <- score - normalized_weight * comp$val
    } else {
      score <- score + normalized_weight * comp$val
    }
  }

  score
}

#' Normalize a numeric vector to 0-1 range
#'
#' @param x Numeric vector
#' @return Numeric vector scaled to [0, 1]
normalize_01 <- function(x) {
  if (length(x) == 0) return(numeric(0))
  if (all(is.na(x))) return(x)
  rng <- range(x, na.rm = TRUE)
  if (rng[1] == rng[2]) return(rep(0.5, length(x)))
  (x - rng[1]) / (rng[2] - rng[1])
}

#' Score a pool of candidate papers
#'
#' Takes a data frame of candidates with metadata columns and computes
#' utility scores for each. Normalizes individual components to 0-1 before
#' combining.
#'
#' @param candidates Data frame with columns: paper_id, cited_by_count, year,
#'   fwci (optional), seed_connectivity (optional), bridge_score (optional)
#' @param weights Named list with w1-w5 from get_preset_weights()
#' @return Data frame with added columns: citation_velocity, ubiquity_penalty,
#'   utility_score, plus normalized versions of each component
score_candidate_pool <- function(candidates, weights) {
  n <- nrow(candidates)
  if (n == 0) return(candidates)

  # Compute raw citation velocity
  candidates$citation_velocity <- mapply(
    compute_citation_velocity,
    candidates$cited_by_count,
    candidates$year
  )

  # Compute ubiquity penalty
  pool_citations <- candidates$cited_by_count
  candidates$ubiquity_penalty <- vapply(candidates$cited_by_count, function(cc) {
    compute_ubiquity_penalty(cc, pool_citations)
  }, numeric(1))

  # Ensure optional columns exist (NA if not provided)
  if (is.null(candidates$seed_connectivity)) candidates$seed_connectivity <- NA_real_
  if (is.null(candidates$bridge_score)) candidates$bridge_score <- NA_real_
  if (is.null(candidates$embedding_similarity)) candidates$embedding_similarity <- NA_real_

  # Normalize available components to 0-1
  candidates$norm_velocity <- normalize_01(candidates$citation_velocity)
  candidates$norm_ubiquity <- normalize_01(candidates$ubiquity_penalty)

  # Normalize seed_connectivity if available
  if (any(!is.na(candidates$seed_connectivity))) {
    candidates$norm_connectivity <- normalize_01(
      ifelse(is.na(candidates$seed_connectivity), NA_real_, candidates$seed_connectivity)
    )
  } else {
    candidates$norm_connectivity <- NA_real_
  }

  # Normalize bridge_score if available
  if (any(!is.na(candidates$bridge_score))) {
    candidates$norm_bridge <- normalize_01(
      ifelse(is.na(candidates$bridge_score), NA_real_, candidates$bridge_score)
    )
  } else {
    candidates$norm_bridge <- NA_real_
  }

  # Normalize FWCI if available
  if ("fwci" %in% names(candidates) && any(!is.na(candidates$fwci))) {
    candidates$norm_fwci <- normalize_01(
      ifelse(is.na(candidates$fwci), NA_real_, candidates$fwci)
    )
  } else {
    candidates$norm_fwci <- NA_real_
  }

  # Normalize embedding_similarity if available
  if (any(!is.na(candidates$embedding_similarity))) {
    candidates$norm_embedding <- normalize_01(
      ifelse(is.na(candidates$embedding_similarity), NA_real_, candidates$embedding_similarity)
    )
  } else {
    candidates$norm_embedding <- NA_real_
  }

  # Compute composite utility score per paper
  candidates$utility_score <- mapply(
    function(conn, bridge, vel, fwci_val, ubiq, embed_sim) {
      compute_utility_score(conn, bridge, vel, fwci_val, ubiq, weights,
                            embedding_similarity = embed_sim)
    },
    candidates$norm_connectivity,
    candidates$norm_bridge,
    candidates$norm_velocity,
    candidates$norm_fwci,
    candidates$norm_ubiquity,
    candidates$norm_embedding
  )

  # Sort by utility score descending
  candidates <- candidates[order(candidates$utility_score, decreasing = TRUE), ]
  candidates$rank <- seq_len(nrow(candidates))

  candidates
}
