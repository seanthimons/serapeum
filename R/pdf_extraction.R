# ==============================================================================
# PDF Image Pipeline — Figure Extraction (Stages 1+3, Epic #44)
#
# Extracts figures from academic PDFs using page rendering + text-gap cropping.
# Pure R implementation using pdftools (no Poppler CLI dependency).
# ==============================================================================

suppressPackageStartupMessages({
  library(pdftools)
  library(png)
})

#' Default extraction configuration
#'
#' Returns a named list of tunables for figure extraction. Callers can override
#' individual fields by passing a partial list to extraction functions.
#'
#' @return Named list of config values
extraction_config <- function() {
  list(
    render_dpi        = 150,   # 150 DPI is fast; 300 DPI is 4x slower
    min_width         = 50,
    min_height        = 50,
    min_area_frac     = 0.02,
    header_zone       = 0.08,
    footer_zone       = 0.08,
    min_gap_frac      = 0.10,
    max_text_coverage = 0.92,  # pages below this are figure candidates
    min_gap_frac_hint = 0.05,  # relaxed gap threshold for caption-hinted pages
    sparse_text_max_boxes = 400,  # pages with fewer boxes + low coverage → figure candidates
    min_file_size     = 1000,  # bytes — smaller PNGs are likely artifacts
    min_caption_chars = 50,    # captions shorter than this flagged as "short"
    max_caption_chars = 500,   # truncate captions beyond this
    max_cont_lines    = 5,     # max continuation lines for caption extraction
    caption_patterns  = c(
      "^Fig(ure)?[\\\\.]?\\s*\\d",
      "^Table\\s+\\d",
      "^Scheme\\s+\\d",
      "^Chart\\s+\\d"
    )
  )
}

#' Extract figures from a PDF file
#'
#' Renders candidate pages, detects text gaps, crops figure regions, extracts
#' captions, and returns a data.frame of figure metadata with raw PNG bytes.
#'
#' @param pdf_path Path to the PDF file
#' @param config Extraction config list (default: extraction_config())
#' @return Data.frame with columns: page, figure_index, image_data (raw PNG bytes),
#'   width, height, file_size, method, figure_label, caption, caption_quality.
#'   Empty data.frame if no figures found.
extract_figures_from_pdf <- function(pdf_path, config = extraction_config()) {
  n_pages <- pdf_length(pdf_path)
  message(sprintf("[extract] PDF has %d pages: %s", n_pages, basename(pdf_path)))

  text_data <- pdf_data(pdf_path)

  # Guard: scanned/image-only PDFs — all pages have 0 text boxes
  total_text_boxes <- sum(vapply(text_data, nrow, integer(1)))
  if (total_text_boxes == 0) {
    warning("PDF appears to be scanned/image-only (0 text boxes). Skipping extraction.")
    return(empty_figures_df())
  }

  # Figure census: how many figures does the paper reference?
  max_fig_num <- figure_census(text_data)
  if (max_fig_num > 0) {
    message(sprintf("[census] Paper references up to Figure %d", max_fig_num))
  }

  # Back-matter detection
  backmatter_page <- detect_backmatter(text_data, n_pages)
  if (backmatter_page <= n_pages) {
    message(sprintf("[backmatter] Detected at page %d — skipping pages %d+",
                    backmatter_page, backmatter_page))
  }

  # Pre-scan: identify which pages to render
  scan <- prescan_pages(text_data, n_pages, backmatter_page, config)
  if (length(scan$pages) == 0) {
    message("[extract] No candidate pages found")
    return(empty_figures_df())
  }

  skipped <- n_pages - length(scan$pages)
  if (skipped > 0) {
    message(sprintf("[extract] Skipping %d text-only pages, rendering %d candidates",
                    skipped, length(scan$pages)))
  }

  # Render and crop
  all_figures <- list()

  for (pi in seq_along(scan$pages)) {
    page_num <- scan$pages[pi]
    reason <- scan$reasons[pi]

    raw_bitmap <- pdf_render_page(pdf_path, page = page_num, dpi = config$render_dpi)
    img <- bitmap_to_array(raw_bitmap)
    page_h <- dim(img)[1]
    page_w <- dim(img)[2]

    page_text <- filter_margin_watermark(text_data[[page_num]])

    # No text on page — save full page as figure
    if (is.null(page_text) || nrow(page_text) == 0) {
      png_bytes <- to_png_bytes(img)
      all_figures[[length(all_figures) + 1]] <- figure_row(
        page = page_num, figure_index = 1L, image_data = png_bytes,
        width = page_w, height = page_h, method = "render_full_page"
      )
      next
    }

    # Scale text coordinates to pixel space
    scale_factor <- config$render_dpi / 72
    text_tops    <- page_text$y * scale_factor
    text_bottoms <- (page_text$y + page_text$height) * scale_factor

    occupancy <- rep(FALSE, page_h)
    for (i in seq_len(nrow(page_text))) {
      y1 <- max(1, floor(text_tops[i]))
      y2 <- min(page_h, ceiling(text_bottoms[i]))
      if (y1 <= y2) occupancy[y1:y2] <- TRUE
    }

    gaps <- find_gaps(occupancy, page_h)

    # Use relaxed threshold for caption-hinted or sparse-text pages
    gap_frac <- if (reason %in% c("caption_hint", "caption+coverage", "sparse_text")) {
      config$min_gap_frac_hint
    } else {
      config$min_gap_frac
    }
    min_gap_px <- page_h * gap_frac
    header_cutoff <- page_h * config$header_zone
    footer_cutoff <- page_h * (1 - config$footer_zone)

    good_gaps <- Filter(function(g) {
      gap_height <- g$end - g$start
      gap_center <- (g$start + g$end) / 2
      gap_height >= min_gap_px &&
        gap_center > header_cutoff &&
        gap_center < footer_cutoff
    }, gaps)

    # No croppable gaps — save full page if heuristic-flagged
    if (length(good_gaps) == 0) {
      if (reason %in% c("caption_hint", "caption+coverage", "sparse_text")) {
        png_bytes <- to_png_bytes(img)
        all_figures[[length(all_figures) + 1]] <- figure_row(
          page = page_num, figure_index = 1L, image_data = png_bytes,
          width = page_w, height = page_h, method = "render_caption_hint"
        )
      }
      next
    }

    # Crop each gap region
    for (gi in seq_along(good_gaps)) {
      g <- good_gaps[[gi]]
      y1 <- max(1, g$start)
      y2 <- min(page_h, g$end)
      crop_h <- y2 - y1
      crop_w <- page_w

      if (crop_w < config$min_width || crop_h < config$min_height) next

      cropped <- img[y1:y2, , 1:3, drop = FALSE]
      if (is_mostly_blank(cropped)) next

      png_bytes <- to_png_bytes(cropped)
      all_figures[[length(all_figures) + 1]] <- figure_row(
        page = page_num, figure_index = gi, image_data = png_bytes,
        width = crop_w, height = crop_h, method = "render_crop"
      )
    }
  }

  if (length(all_figures) == 0) {
    message("[extract] No figures extracted")
    return(empty_figures_df())
  }

  result <- do.call(rbind, all_figures)

  # Size filtering
  result <- filter_by_size(result, config)

  # Deduplication
  if (requireNamespace("digest", quietly = TRUE)) {
    result <- deduplicate(result)
  }

  # Caption extraction and association
  captions <- extract_captions(text_data, config)
  if (nrow(captions) > 0) {
    message(sprintf("[captions] Found %d figure captions", nrow(captions)))
    result <- associate_captions(result, captions)
  } else {
    result$figure_label <- NA_character_
    result$caption <- NA_character_
  }

  # Flag caption quality
  result$caption_quality <- ifelse(
    is.na(result$caption), "missing",
    ifelse(nchar(result$caption) < config$min_caption_chars, "short", "ok")
  )

  message(sprintf("[extract] Final: %d figures", nrow(result)))
  result
}


# ==============================================================================
# Internal helpers
# ==============================================================================

#' Create an empty figures data.frame with the expected columns
#' @keywords internal
empty_figures_df <- function() {
  data.frame(
    page           = integer(),
    figure_index   = integer(),
    image_data     = I(list()),
    width          = integer(),
    height         = integer(),
    file_size      = integer(),
    method         = character(),
    figure_label   = character(),
    caption        = character(),
    caption_quality = character(),
    stringsAsFactors = FALSE
  )
}

#' Build a single-row figure data.frame
#' @keywords internal
figure_row <- function(page, figure_index, image_data, width, height, method) {
  data.frame(
    page         = as.integer(page),
    figure_index = as.integer(figure_index),
    image_data   = I(list(image_data)),
    width        = as.integer(width),
    height       = as.integer(height),
    file_size    = as.integer(length(image_data)),
    method       = method,
    stringsAsFactors = FALSE
  )
}

#' Convert an image array (integer 0-255) to raw PNG bytes
#' @keywords internal
to_png_bytes <- function(img_array) {
  tmp <- tempfile(fileext = ".png")
  on.exit(unlink(tmp), add = TRUE)
  # writePNG expects 0-1 range, RGB only (drop alpha if present)
  n_ch <- dim(img_array)[3]
  if (n_ch >= 3) {
    img_array <- img_array[, , 1:3, drop = FALSE]
  }
  writePNG(img_array / 255, tmp)
  readBin(tmp, "raw", file.info(tmp)$size)
}

#' Filter out rotated margin watermark text from pdf_data output
#'
#' Publisher watermarks (e.g., Wiley "Downloaded from...") appear as narrow
#' text boxes (width < 10 pts) stacked vertically at the same x position,
#' spanning most of the page height. These fill every vertical band and
#' destroy gap detection. This function removes them.
#'
#' @param page_text Data.frame from pdf_data() for one page
#' @return Filtered data.frame with watermark boxes removed
#' @keywords internal
filter_margin_watermark <- function(page_text) {
  if (is.null(page_text) || nrow(page_text) == 0) return(page_text)
  page_h <- max(page_text$y + page_text$height) * 1.05

  # Only consider narrow boxes — rotated text renders with tiny width
  narrow_mask <- page_text$width < 10
  if (!any(narrow_mask)) return(page_text)

  # TUNABLE: margin_band — only filter narrow boxes within 30 pts of page edge.
  # Without this, narrow table cells in the content area (e.g., Sentinel-2 p8
  # at x=185-429) get falsely removed. Real watermarks sit at extreme margins.
  page_left <- min(page_text$x)
  page_right <- max(page_text$x + page_text$width)
  margin_band <- 30
  margin_mask <- narrow_mask &
    (page_text$x <= page_left + margin_band |
     page_text$x >= page_right - margin_band)
  if (!any(margin_mask)) return(page_text)

  narrow <- page_text[margin_mask, ]

  # Group by x position (bin to nearest 3 pts)
  x_bins <- round(narrow$x / 3) * 3
  watermark_rows <- logical(nrow(page_text))

  for (xb in unique(x_bins)) {
    grp_mask <- x_bins == xb
    grp <- narrow[grp_mask, ]
    if (nrow(grp) < 5) next

    y_span <- max(grp$y + grp$height) - min(grp$y)
    # Must span >60% of page height — definitionally a margin watermark
    if (y_span > page_h * 0.6) {
      orig_indices <- which(margin_mask)[grp_mask]
      watermark_rows[orig_indices] <- TRUE
    }
  }

  n_removed <- sum(watermark_rows)
  if (n_removed > 0) {
    message(sprintf("[watermark] Removed %d rotated margin text boxes", n_removed))
    page_text <- page_text[!watermark_rows, ]
  }
  page_text
}

#' Count the highest figure number referenced in the paper
#' @keywords internal
figure_census <- function(text_data) {
  max_fig_num <- 0
  for (pg in seq_along(text_data)) {
    words <- text_data[[pg]]$text
    fig_tokens <- grep("^(Fig(ure)?[\\.]?|Figure)$", words, perl = TRUE, ignore.case = TRUE)
    for (ft in fig_tokens) {
      if (ft >= length(words)) next
      next_word <- words[ft + 1]
      if (grepl("^\\d", next_word)) {
        num <- as.integer(gsub("^(\\d+).*", "\\1", next_word))
        if (!is.na(num) && num > 0 && num < 50) {
          max_fig_num <- max(max_fig_num, num)
        }
      }
    }
  }
  max_fig_num
}

#' Detect where back-matter (references, acknowledgements) starts
#' @keywords internal
detect_backmatter <- function(text_data, n_pages) {
  backmatter_patterns <- c(
    "^references$", "^bibliography$",
    "^acknowledge?ments?$", "^conflicts? of interest",
    "^data availability", "^author contributions?",
    "^supplementary materials?$", "^supporting information$",
    "^declaration of", "^funding$", "^credit author"
  )
  backmatter_page <- n_pages + 1

  for (pg in seq_along(text_data)) {
    p_text <- text_data[[pg]]
    if (is.null(p_text) || nrow(p_text) == 0) next

    y_groups <- split(p_text$text, round(p_text$y, 0))
    for (words_in_line in y_groups) {
      if (length(words_in_line) > 8) next
      line_lower <- tolower(trimws(paste(words_in_line, collapse = " ")))
      if (any(vapply(backmatter_patterns, grepl, logical(1), x = line_lower))) {
        backmatter_page <- pg
        break
      }
    }
    if (backmatter_page <= n_pages) break
  }

  backmatter_page
}

#' Pre-scan pages to identify rendering candidates
#' @return List with $pages (integer vector) and $reasons (character vector)
#' @keywords internal
prescan_pages <- function(text_data, n_pages, backmatter_page, config) {
  pages <- c()
  reasons <- character()

  for (page_num in seq_len(n_pages)) {
    if (page_num >= backmatter_page) next

    page_text <- text_data[[page_num]]

    if (is.null(page_text) || nrow(page_text) == 0) {
      pages <- c(pages, page_num)
      reasons <- c(reasons, "no_text")
      next
    }

    # TUNABLE: Watermark vs coverage split
    # Gap detection uses FILTERED text — publisher watermarks (e.g., Wiley
    # "Downloaded from...") are rotated text spanning the full page height,
    # filling every vertical band and hiding real figure gaps.
    # Coverage/sparse_text use ORIGINAL text — the 0.92 coverage threshold
    # was calibrated with watermarks present; filtering would lower coverage
    # on text-heavy pages and create false positives.
    page_text_filtered <- filter_margin_watermark(page_text)
    if (nrow(page_text_filtered) == 0) {
      pages <- c(pages, page_num)
      reasons <- c(reasons, "no_text")
      next
    }

    page_height_pts <- max(page_text_filtered$y + page_text_filtered$height) * 1.05
    text_tops_pts    <- page_text_filtered$y
    text_bottoms_pts <- page_text_filtered$y + page_text_filtered$height

    occupancy_filtered <- rep(FALSE, ceiling(page_height_pts))
    for (i in seq_len(nrow(page_text_filtered))) {
      y1 <- max(1, floor(text_tops_pts[i]))
      y2 <- min(length(occupancy_filtered), ceiling(text_bottoms_pts[i]))
      if (y1 <= y2) occupancy_filtered[y1:y2] <- TRUE
    }

    gaps_pts <- find_gaps(occupancy_filtered, length(occupancy_filtered))
    header_pts <- page_height_pts * config$header_zone
    footer_pts <- page_height_pts * (1 - config$footer_zone)

    # Coverage + sparse_text use ORIGINAL text (threshold was calibrated against it)
    page_height_orig <- max(page_text$y + page_text$height) * 1.05
    occupancy_orig <- rep(FALSE, ceiling(page_height_orig))
    for (i in seq_len(nrow(page_text))) {
      y1 <- max(1, floor(page_text$y[i]))
      y2 <- min(length(occupancy_orig), ceiling(page_text$y[i] + page_text$height[i]))
      if (y1 <= y2) occupancy_orig[y1:y2] <- TRUE
    }

    # Caption hints — match Figure/Fig followed by a number (tables excluded — separate workflow)
    words <- page_text$text
    caption_tokens <- grep("^(Fig(ure)?[\\.]?)$", words, perl = TRUE, ignore.case = TRUE)
    has_caption <- FALSE
    for (ct in caption_tokens) {
      lookahead <- words[seq(min(ct + 1, length(words)), min(ct + 3, length(words)))]
      if (any(grepl("^\\d", lookahead))) {
        has_caption <- TRUE
        break
      }
    }

    gap_threshold <- if (has_caption) config$min_gap_frac_hint else config$min_gap_frac
    min_gap_pts <- page_height_pts * gap_threshold

    has_big_gap <- any(vapply(gaps_pts, function(g) {
      gap_h <- g$end - g$start
      gap_center <- (g$start + g$end) / 2
      gap_h >= min_gap_pts && gap_center > header_pts && gap_center < footer_pts
    }, logical(1)))

    # Coverage and sparse text use ORIGINAL occupancy (calibrated thresholds)
    text_coverage <- mean(occupancy_orig)
    low_coverage <- text_coverage < config$max_text_coverage

    sparse_text <- nrow(page_text) <= config$sparse_text_max_boxes && low_coverage

    # TUNABLE: text-heavy FP guard — pages with 1000+ text boxes that match
    # caption+coverage are dense body text with in-text figure references
    # (e.g., "see Fig. 5)"), not actual figure pages. Von Borries pages 2,4,6,9,11,13
    # all had 1200+ boxes with even vertical distribution.
    text_heavy <- nrow(page_text_filtered) > 1000

    # Decision
    if (has_big_gap) {
      pages <- c(pages, page_num)
      reasons <- c(reasons, "gap")
    } else if (has_caption && low_coverage && !text_heavy) {
      pages <- c(pages, page_num)
      reasons <- c(reasons, "caption+coverage")
    } else if (sparse_text) {
      pages <- c(pages, page_num)
      reasons <- c(reasons, "sparse_text")
    }
  }

  list(pages = pages, reasons = reasons)
}


# ==============================================================================
# Caption extraction (Stage 3)
# ==============================================================================

#' Extract figure captions from PDF text data
#'
#' Finds "Figure N" patterns in pdf_data() output and reconstructs the
#' caption text by following continuation lines.
#'
#' @param text_data List of data.frames from pdf_data()
#' @param config Extraction config list
#' @return Data.frame with columns: page, figure_label, caption_text
extract_captions <- function(text_data, config = extraction_config()) {
  all_captions <- list()

  for (pg in seq_along(text_data)) {
    p <- text_data[[pg]]
    if (is.null(p) || nrow(p) == 0) next

    p <- p[order(p$y, p$x), ]

    fig_idx <- grep("^(Fig(ure)?[\\.]?)$", p$text, perl = TRUE, ignore.case = TRUE)

    for (fi in fig_idx) {
      if (fi >= nrow(p)) next

      next_word <- p$text[fi + 1]
      if (!grepl("^\\d", next_word)) next

      fig_num <- gsub("[^0-9a-zA-Z]", "", next_word)
      fig_label <- paste(p$text[fi], fig_num)

      label_y <- p$y[fi]
      label_x <- p$x[fi]
      label_h <- p$height[fi]

      # Words on the label line
      same_line <- which(abs(p$y - label_y) < 2 & p$x >= label_x)
      same_line <- same_line[same_line >= fi]
      same_line <- same_line[order(p$x[same_line])]
      caption_words <- p$text[same_line]

      # Follow continuation lines
      if (length(same_line) > 0) {
        last_y <- max(p$y[same_line])
        line_height <- if (label_h > 0) label_h * 1.5 else 12

        for (cont in seq_len(config$max_cont_lines)) {
          remaining <- which(p$y > last_y + 1)
          if (length(remaining) == 0) break

          next_y <- min(p$y[remaining])
          if ((next_y - last_y) > line_height * 2) break

          cont_line <- which(abs(p$y - next_y) < 2)
          cont_line <- cont_line[order(p$x[cont_line])]
          cont_text <- paste(p$text[cont_line], collapse = " ")

          # Stop at new figure label or section heading
          if (grepl("^(Fig(ure)?[\\.]?\\s+\\d|FIGURE\\s+\\d|Table\\s+\\d|References)",
                    cont_text, ignore.case = TRUE)) break

          # Stop if text style changes significantly
          cont_h <- p$height[cont_line[1]]
          if (cont_h > 0 && label_h > 0 && cont_h > label_h * 1.5) break

          # Stop if x-offset drifts too far (different column)
          cont_x <- min(p$x[cont_line])
          if (abs(cont_x - label_x) > 200) break

          caption_words <- c(caption_words, p$text[cont_line])
          last_y <- next_y
        }
      }

      caption_text <- paste(caption_words, collapse = " ")
      caption_text <- gsub("\\s+", " ", trimws(caption_text))

      # Truncate long captions
      if (nchar(caption_text) > config$max_caption_chars) {
        truncated <- substr(caption_text, 1, config$max_caption_chars)
        last_period <- regexpr("\\.[^.]*$", truncated)
        if (last_period > nchar(caption_text) * 0.3) {
          caption_text <- substr(truncated, 1, last_period)
        } else {
          caption_text <- paste0(truncated, "...")
        }
      }

      if (nchar(caption_text) > 0) {
        all_captions[[length(all_captions) + 1]] <- data.frame(
          page = pg,
          figure_label = fig_label,
          caption_text = caption_text,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(all_captions) == 0) {
    return(data.frame(page = integer(), figure_label = character(),
                      caption_text = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, all_captions)
}


# ==============================================================================
# Shared helpers
# ==============================================================================

#' Match captions to extracted figures by page number
#' @keywords internal
associate_captions <- function(manifest, captions) {
  manifest$figure_label <- NA_character_
  manifest$caption <- NA_character_

  if (nrow(manifest) == 0 || nrow(captions) == 0) return(manifest)

  for (i in seq_len(nrow(manifest))) {
    pg <- manifest$page[i]
    page_captions <- captions[captions$page == pg, , drop = FALSE]
    if (nrow(page_captions) == 0) next

    manifest$figure_label[i] <- page_captions$figure_label[1]
    manifest$caption[i] <- page_captions$caption_text[1]

    if (nrow(page_captions) > 1) {
      captions <- captions[!(captions$page == pg &
                             captions$caption_text == page_captions$caption_text[1]), ]
    }
  }

  manifest
}

#' Find contiguous gaps in a boolean occupancy vector
#' @param occupancy Logical vector
#' @param total_length Length of the vector
#' @return List of lists with $start and $end indices
find_gaps <- function(occupancy, total_length) {
  gaps <- list()
  in_gap <- FALSE
  gap_start <- 0

  for (i in seq_along(occupancy)) {
    if (!occupancy[i] && !in_gap) {
      in_gap <- TRUE
      gap_start <- i
    } else if (occupancy[i] && in_gap) {
      in_gap <- FALSE
      gaps[[length(gaps) + 1]] <- list(start = gap_start, end = i - 1)
    }
  }
  if (in_gap) {
    gaps[[length(gaps) + 1]] <- list(start = gap_start, end = total_length)
  }
  gaps
}

#' Convert raw bitmap from pdf_render_page to numeric array
#'
#' pdf_render_page returns raw bytes with dim [channels x width x height].
#' This converts to integer [height x width x channels] for cropping.
#'
#' @param bm Raw bitmap from pdf_render_page()
#' @return Integer array [height x width x channels]
bitmap_to_array <- function(bm) {
  dims <- dim(bm)
  n_ch <- dims[1]
  img_w <- dims[2]
  img_h <- dims[3]
  arr <- array(as.integer(bm), dim = c(n_ch, img_w, img_h))
  aperm(arr, c(3, 2, 1))
}

#' Check if a cropped image region is mostly blank (white)
#' @param img_array Numeric array [h x w x channels]
#' @param threshold Fraction of white pixels to consider "blank"
#' @return TRUE if the region is mostly blank
# TUNABLE: blank threshold — 0.98 not 0.95. Gap-based crops often include
# white margins around a small figure. At 0.95, figures with ~4-5% non-white
# pixels were rejected (e.g., Orlov Figure 9). Truly blank regions are 0.99+.
is_mostly_blank <- function(img_array, threshold = 0.98) {
  mean(img_array > 240) > threshold
}

#' Filter figures by minimum size thresholds
#' @keywords internal
filter_by_size <- function(manifest, config = extraction_config()) {
  if (nrow(manifest) == 0) return(manifest)

  keep <- manifest$width  >= config$min_width &
          manifest$height >= config$min_height &
          manifest$file_size > config$min_file_size

  removed <- sum(!keep)
  if (removed > 0) {
    message(sprintf("[filter] Removed %d images below size thresholds", removed))
  }

  manifest[keep, , drop = FALSE]
}

#' Deduplicate figures by content hash
#' @keywords internal
deduplicate <- function(manifest) {
  if (nrow(manifest) == 0) return(manifest)

  hashes <- vapply(seq_len(nrow(manifest)), function(i) {
    digest::digest(manifest$image_data[[i]], algo = "md5")
  }, character(1))

  dupes <- duplicated(hashes)
  if (any(dupes)) {
    message(sprintf("[dedup] Removed %d duplicate images", sum(dupes)))
  }

  manifest[!dupes, , drop = FALSE]
}
