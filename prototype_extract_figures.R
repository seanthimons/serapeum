#!/usr/bin/env Rscript
# ============================================================================
# v17.0 PDF Image Pipeline — Stage 1 Prototype
# Standalone script: extracts figures from academic PDFs
#
# Strategy: Option A
#   - Primary:  Poppler `pdfimages` CLI (native-resolution embedded images)
#   - Fallback: pdftools page rendering + text-gap cropping (pure R)
#
# Usage:
#   Rscript prototype_extract_figures.R <pdf_or_dir> [more_pdfs...] [--out DIR] [--smoke]
#
# Examples:
#   Rscript prototype_extract_figures.R paper.pdf
#   Rscript prototype_extract_figures.R paper1.pdf paper2.pdf paper3.pdf
#   Rscript prototype_extract_figures.R ./my_papers/              # all PDFs in dir
#   Rscript prototype_extract_figures.R paper.pdf --out results/
#   Rscript prototype_extract_figures.R paper.pdf --smoke          # dry run
#
# Output: extracted PNGs per PDF in output_dir, plus a CSV manifest.
# ============================================================================

#renv::activate(project = ".")

suppressPackageStartupMessages({
  library(pdftools)
  library(png)
})

# --- User toggles (flip these in IDE) ----------------------------------------

SMOKE    <- FALSE    # TRUE = dry run (report strategy + PDF stats, no extraction)
INPUT    <- "test-data"        # folder or file path(s)
OUT_DIR  <- "extracted_figures"

# --- Configuration -----------------------------------------------------------

CONFIG <- list(
  render_dpi     = 150,   # 150 is enough for figure detection; 300 was 4x slower
  min_width      = 50,    # scaled down with DPI (100px @ 300dpi = 50px @ 150dpi)
  min_height     = 50,
  min_area_frac  = 0.02,
  header_zone    = 0.08,
  footer_zone    = 0.08,
  min_gap_frac   = 0.10,

  # Caption-hint detection: regex patterns that signal a figure is on this page
  caption_patterns = c(
    "^Fig(ure)?[\\.]?\\s*\\d",
    "^Table\\s+\\d",
    "^Scheme\\s+\\d",
    "^Chart\\s+\\d"
  ),
  # Pages with text coverage below this are candidates (inline figures reduce coverage)
  max_text_coverage = 0.92,
  # Relaxed gap threshold for pages with caption hints
  min_gap_frac_hint = 0.05,
  # Pages with few text boxes + low coverage are likely full-page plots
  # (axis labels and legends produce few boxes but still register as text)
  sparse_text_max_boxes = 350
)

# --- Poppler detection -------------------------------------------------------

has_pdfimages <- function() {
  result <- tryCatch(
    system2("pdfimages", "-v", stdout = TRUE, stderr = TRUE),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  !is.null(result)
}

poppler_version <- function() {
  tryCatch({
    lines <- system2("pdfimages", "-v", stdout = TRUE, stderr = TRUE)
    paste(lines, collapse = " ")
  }, error = function(e) "unknown")
}

# --- Smoke test --------------------------------------------------------------

smoke_test <- function(pdf_paths) {
  use_poppler <- has_pdfimages()

  message("=== v17 Smoke Test ===")
  message("")

  # Extraction strategy
  message("--- Extraction Strategy ---")
  if (use_poppler) {
    message(sprintf("  Path:    POPPLER (native embedded image extraction)"))
    message(sprintf("  Binary:  pdfimages (%s)", poppler_version()))
  } else {
    message(sprintf("  Path:    RENDER FALLBACK (page render + text-gap cropping)"))
    message(sprintf("  Reason:  pdfimages not found on PATH"))
    message(sprintf("  Note:    Install Poppler for higher quality extraction"))
    message(sprintf("           Windows: scoop install poppler / choco install poppler"))
    message(sprintf("           Mac:     brew install poppler"))
    message(sprintf("           Linux:   apt install poppler-utils"))
  }

  message("")

  # R packages
  message("--- R Packages ---")
  message(sprintf("  pdftools: %s", as.character(packageVersion("pdftools"))))
  message(sprintf("  png:      %s", as.character(packageVersion("png"))))
  has_digest <- requireNamespace("digest", quietly = TRUE)
  message(sprintf("  digest:   %s%s",
    if (has_digest) as.character(packageVersion("digest")) else "NOT INSTALLED",
    if (!has_digest) " (dedup will be skipped)" else ""))

  message("")

  # PDF inventory
  message(sprintf("--- PDF Inventory (%d file%s) ---",
    length(pdf_paths), if (length(pdf_paths) != 1) "s" else ""))

  total_pages <- 0
  for (p in pdf_paths) {
    n <- tryCatch(pdf_length(p), error = function(e) NA)
    size_mb <- file.info(p)$size / 1024 / 1024
    if (is.na(n)) {
      message(sprintf("  [ERROR] %s — could not read PDF", basename(p)))
    } else {
      total_pages <- total_pages + n

      # Quick text data probe on page 1 to check pdf_data works
      text_ok <- tryCatch({
        td <- pdf_data(p)
        nrow(td[[1]])
      }, error = function(e) NA)

      message(sprintf("  %s — %d pages, %.1f MB, text_data: %s",
        basename(p), n, size_mb,
        if (is.na(text_ok)) "FAILED" else sprintf("%d boxes on p1", text_ok)))
    }
  }

  message("")
  message(sprintf("--- Estimate ---"))
  message(sprintf("  Total pages to process: %d", total_pages))

  if (use_poppler) {
    message(sprintf("  Expected speed: ~1-2 sec/PDF (Poppler, fast)"))
  } else {
    message(sprintf("  Expected speed: ~2-5 sec/page at %d DPI (render fallback)", CONFIG$render_dpi))
    message(sprintf("  Estimated time: ~%d-%d seconds",
      total_pages * 2, total_pages * 5))
  }

  message("")
  message("Smoke test passed. Run without --smoke to extract.")
}

# --- Path A: Poppler pdfimages -----------------------------------------------

extract_via_poppler <- function(pdf_path, output_dir) {
  message("  [poppler] Extracting embedded images with pdfimages...")
  prefix <- file.path(output_dir, "fig")

  system2(
    "pdfimages",
    args = c("-png", "-all", shQuote(pdf_path), shQuote(prefix)),
    stdout = TRUE, stderr = TRUE
  )

  extracted <- list.files(output_dir, pattern = "^fig-\\d+\\.png$", full.names = TRUE)
  message(sprintf("  [poppler] Raw extraction: %d images", length(extracted)))

  if (length(extracted) == 0) return(data.frame())

  manifest <- do.call(rbind, lapply(extracted, function(f) {
    info <- file.info(f)
    img_data <- tryCatch(readPNG(f), error = function(e) NULL)
    if (is.null(img_data)) {
      w <- 0; h <- 0
    } else if (is.matrix(img_data)) {
      h <- nrow(img_data); w <- ncol(img_data)
    } else {
      h <- dim(img_data)[1]; w <- dim(img_data)[2]
    }
    data.frame(
      file_path  = f,
      width      = w,
      height     = h,
      file_size  = info$size,
      method     = "poppler",
      page       = NA_integer_,
      stringsAsFactors = FALSE
    )
  }))

  # Try to get page numbers using pdfimages -list
  page_info <- tryCatch({
    lines <- system2("pdfimages", args = c("-list", shQuote(pdf_path)),
                      stdout = TRUE, stderr = FALSE)
    if (length(lines) > 2) {
      data_lines <- lines[3:length(lines)]
      parsed <- lapply(data_lines, function(l) {
        fields <- strsplit(trimws(l), "\\s+")[[1]]
        if (length(fields) >= 2) {
          data.frame(page = as.integer(fields[1]),
                     img_num = as.integer(fields[2]),
                     stringsAsFactors = FALSE)
        }
      })
      do.call(rbind, Filter(Negate(is.null), parsed))
    }
  }, error = function(e) NULL)

  if (!is.null(page_info) && nrow(page_info) == nrow(manifest)) {
    manifest$page <- page_info$page
  }

  manifest
}

# --- Path B: Page rendering + text-gap cropping (fallback) -------------------

extract_via_rendering <- function(pdf_path, output_dir) {
  message("  [render] Using page rendering + text-gap detection...")

  n_pages <- pdf_length(pdf_path)
  message(sprintf("  [render] PDF has %d pages", n_pages))

  text_data <- pdf_data(pdf_path)
  all_figures <- list()

  # --- Figure census: how many figures does this paper claim to have? ---
  # Scan for "Figure N" patterns and find the highest N.
  # Only check the immediately next token to avoid false matches.
  max_fig_num <- 0
  for (pg in seq_along(text_data)) {
    words <- text_data[[pg]]$text
    fig_tokens <- grep("^(Fig(ure)?[\\.]?|Figure)$", words, perl = TRUE, ignore.case = TRUE)
    for (ft in fig_tokens) {
      if (ft >= length(words)) next
      next_word <- words[ft + 1]
      # Must start with a digit, extract leading number (handles "3a", "3.", "3b)")
      if (grepl("^\\d", next_word)) {
        num <- as.integer(gsub("^(\\d+).*", "\\1", next_word))
        if (!is.na(num) && num > 0 && num < 50) {
          max_fig_num <- max(max_fig_num, num)
        }
      }
    }
  }
  if (max_fig_num > 0) {
    message(sprintf("  [census] Paper references up to Figure %d", max_fig_num))
  }

  # --- Back-matter detection: find where references/acknowledgements start ---
  # Everything after this page is citations, author info, etc. — no figures.
  backmatter_patterns <- c(
    "^references$", "^bibliography$",
    "^acknowledge?ments?$", "^conflicts? of interest",
    "^data availability", "^author contributions?",
    "^supplementary materials?$", "^supporting information$",
    "^declaration of", "^funding$", "^credit author"
  )
  backmatter_page <- n_pages + 1  # default: no cutoff

  for (pg in seq_along(text_data)) {
    p_text <- text_data[[pg]]
    if (is.null(p_text) || nrow(p_text) == 0) next

    # Reconstruct lines by y position
    y_groups <- split(p_text$text, round(p_text$y, 0))
    for (words_in_line in y_groups) {
      if (length(words_in_line) > 8) next  # headings are short
      line_lower <- tolower(trimws(paste(words_in_line, collapse = " ")))
      if (any(vapply(backmatter_patterns, grepl, logical(1), x = line_lower))) {
        backmatter_page <- pg
        break
      }
    }
    if (backmatter_page <= n_pages) break
  }

  if (backmatter_page <= n_pages) {
    message(sprintf("  [backmatter] Detected at page %d — skipping pages %d+", backmatter_page, backmatter_page))
  }

  # --- Pre-scan: identify which pages are worth rendering ---
  # Three signals (any one triggers rendering):
  #   1. Text gap detection (original) — large vertical gaps between text
  #   2. Caption hints — page contains "Figure X" / "Table X" text
  #   3. Low text coverage — inline figures reduce text coverage below threshold
  pages_to_render <- c()
  page_reasons <- character()  # for logging

  for (page_num in seq_len(n_pages)) {
    # Skip back-matter pages (references, acknowledgements, etc.)
    if (page_num >= backmatter_page) next

    page_text <- text_data[[page_num]]

    if (is.null(page_text) || nrow(page_text) == 0) {
      pages_to_render <- c(pages_to_render, page_num)
      page_reasons <- c(page_reasons, "no_text")
      next
    }

    # --- Signal 1: Text gap detection ---
    page_height_pts <- max(page_text$y + page_text$height) * 1.05
    text_tops_pts    <- page_text$y
    text_bottoms_pts <- page_text$y + page_text$height

    occupancy_pts <- rep(FALSE, ceiling(page_height_pts))
    for (i in seq_len(nrow(page_text))) {
      y1 <- max(1, floor(text_tops_pts[i]))
      y2 <- min(length(occupancy_pts), ceiling(text_bottoms_pts[i]))
      if (y1 <= y2) occupancy_pts[y1:y2] <- TRUE
    }

    gaps_pts <- find_gaps(occupancy_pts, length(occupancy_pts))
    header_pts <- page_height_pts * CONFIG$header_zone
    footer_pts <- page_height_pts * (1 - CONFIG$footer_zone)

    # --- Signal 2: Caption hints ---
    # pdf_data returns one word per text box, so match on individual tokens.
    # Look for "Figure", "Fig.", "Table" etc. followed by a number.
    # We can't filter out in-text references ("in Figure 3") because inline-figure
    # papers have the figure AND the reference on the same page. Instead, we rely
    # on the coverage threshold (signal 3) to reject text-heavy pages that merely
    # reference figures on other pages.
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

    # Use relaxed gap threshold if caption hints present
    gap_threshold <- if (has_caption) CONFIG$min_gap_frac_hint else CONFIG$min_gap_frac
    min_gap_pts <- page_height_pts * gap_threshold

    has_big_gap <- any(vapply(gaps_pts, function(g) {
      gap_h <- g$end - g$start
      gap_center <- (g$start + g$end) / 2
      gap_h >= min_gap_pts && gap_center > header_pts && gap_center < footer_pts
    }, logical(1)))

    # --- Signal 3: Text coverage ---
    text_coverage <- mean(occupancy_pts)
    low_coverage <- text_coverage < CONFIG$max_text_coverage

    # --- Signal 4: Sparse text (full-page plots) ---
    # Pages dominated by a figure have few text boxes (axis labels, legends)
    # even though coverage can be moderate. Low box count + low coverage = plot page.
    sparse_text <- nrow(page_text) <= CONFIG$sparse_text_max_boxes && low_coverage

    # --- Decide ---
    if (has_big_gap) {
      pages_to_render <- c(pages_to_render, page_num)
      page_reasons <- c(page_reasons, "gap")
    } else if (has_caption && low_coverage) {
      # Caption + low coverage = inline figure (text wraps around it, reducing coverage)
      pages_to_render <- c(pages_to_render, page_num)
      page_reasons <- c(page_reasons, "caption+coverage")
    } else if (sparse_text) {
      # Few text boxes + low coverage = likely a full-page plot/figure
      pages_to_render <- c(pages_to_render, page_num)
      page_reasons <- c(page_reasons, "sparse_text")
    }
  }

  skipped <- n_pages - length(pages_to_render)
  if (skipped > 0) {
    message(sprintf("  [render] Skipping %d text-only pages, rendering %d candidate pages",
      skipped, length(pages_to_render)))
  }
  # Log reasons
  reason_table <- table(page_reasons)
  reason_str <- paste(sprintf("%s:%d", names(reason_table), reason_table), collapse = ", ")
  if (length(pages_to_render) > 0) {
    message(sprintf("  [render] Reasons: %s", reason_str))
  }

  for (pi in seq_along(pages_to_render)) {
    page_num <- pages_to_render[pi]
    reason <- page_reasons[pi]
    message(sprintf("  [render] Rendering page %d (%s)", page_num, reason))

    raw_bitmap <- pdf_render_page(pdf_path, page = page_num, dpi = CONFIG$render_dpi)
    img <- bitmap_to_array(raw_bitmap)  # numeric [height x width x channels]
    page_h <- dim(img)[1]
    page_w <- dim(img)[2]

    page_text <- text_data[[page_num]]

    if (is.null(page_text) || nrow(page_text) == 0) {
      fig_path <- file.path(output_dir, sprintf("fig_p%03d_full.png", page_num))
      writePNG(img[, , 1:3, drop = FALSE] / 255, fig_path)

      all_figures[[length(all_figures) + 1]] <- data.frame(
        file_path  = fig_path,
        width      = page_w,
        height     = page_h,
        file_size  = file.info(fig_path)$size,
        method     = "render_full_page",
        page       = page_num,
        stringsAsFactors = FALSE
      )
      next
    }

    scale_factor <- CONFIG$render_dpi / 72
    text_tops    <- page_text$y * scale_factor
    text_bottoms <- (page_text$y + page_text$height) * scale_factor

    occupancy <- rep(FALSE, page_h)
    for (i in seq_len(nrow(page_text))) {
      y1 <- max(1, floor(text_tops[i]))
      y2 <- min(page_h, ceiling(text_bottoms[i]))
      if (y1 <= y2) occupancy[y1:y2] <- TRUE
    }

    gaps <- find_gaps(occupancy, page_h)

    # Use relaxed threshold for caption-hinted pages
    gap_frac <- if (reason %in% c("caption_hint", "caption+coverage", "sparse_text")) {
      CONFIG$min_gap_frac_hint
    } else {
      CONFIG$min_gap_frac
    }
    min_gap_px <- page_h * gap_frac
    header_cutoff <- page_h * CONFIG$header_zone
    footer_cutoff <- page_h * (1 - CONFIG$footer_zone)

    good_gaps <- Filter(function(g) {
      gap_height <- g$end - g$start
      gap_center <- (g$start + g$end) / 2
      gap_height >= min_gap_px &&
        gap_center > header_cutoff &&
        gap_center < footer_cutoff
    }, gaps)

    # No croppable gaps — if this page was flagged by heuristics, save full page
    if (length(good_gaps) == 0) {
      if (reason %in% c("caption_hint", "caption+coverage", "sparse_text")) {
        fig_path <- file.path(output_dir, sprintf("fig_p%03d_full.png", page_num))
        writePNG(img[, , 1:3, drop = FALSE] / 255, fig_path)

        all_figures[[length(all_figures) + 1]] <- data.frame(
          file_path  = fig_path,
          width      = page_w,
          height     = page_h,
          file_size  = file.info(fig_path)$size,
          method     = "render_caption_hint",
          page       = page_num,
          stringsAsFactors = FALSE
        )
      }
      next
    }

    for (gi in seq_along(good_gaps)) {
      g <- good_gaps[[gi]]
      y1 <- max(1, g$start)
      y2 <- min(page_h, g$end)

      crop_h <- y2 - y1
      crop_w <- page_w

      if (crop_w < CONFIG$min_width || crop_h < CONFIG$min_height) next

      cropped <- img[y1:y2, , 1:3, drop = FALSE]  # RGB, drop alpha
      if (is_mostly_blank(cropped)) next

      fig_path <- file.path(output_dir, sprintf("fig_p%03d_%02d.png", page_num, gi))
      writePNG(cropped / 255, fig_path)

      all_figures[[length(all_figures) + 1]] <- data.frame(
        file_path  = fig_path,
        width      = crop_w,
        height     = crop_h,
        file_size  = file.info(fig_path)$size,
        method     = "render_crop",
        page       = page_num,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(all_figures) == 0) {
    result <- data.frame()
  } else {
    result <- do.call(rbind, all_figures)

    # Extract and associate captions
    captions <- extract_captions(text_data)
    if (nrow(captions) > 0) {
      message(sprintf("  [captions] Found %d figure captions", nrow(captions)))
      result <- associate_captions(result, captions)
    } else {
      result$figure_label <- NA_character_
      result$caption <- NA_character_
    }

    # Flag caption quality for follow-up
    # TUNABLE: min_caption_chars — captions shorter than this are likely
    # truncated, label-only, or failed extraction. These are prime candidates
    # for Stage 5 vision model enrichment.
    min_caption_chars <- 50
    result$caption_quality <- ifelse(
      is.na(result$caption), "missing",
      ifelse(nchar(result$caption) < min_caption_chars, "short", "ok")
    )

    n_missing <- sum(result$caption_quality == "missing")
    n_short <- sum(result$caption_quality == "short")
    n_ok <- sum(result$caption_quality == "ok")
    if (n_missing > 0 || n_short > 0) {
      message(sprintf("  [captions] Quality: %d ok, %d short (<50 chars), %d missing — short/missing need vision model",
        n_ok, n_short, n_missing))
    }
  }
  attr(result, "figure_census") <- max_fig_num
  result
}

# --- Caption extraction -------------------------------------------------------
# Finds figure captions in pdf_data() text and returns a data frame of
# {page, figure_label, caption_text} for each detected caption.

extract_captions <- function(text_data) {
  all_captions <- list()

  for (pg in seq_along(text_data)) {
    p <- text_data[[pg]]
    if (is.null(p) || nrow(p) == 0) next

    # Sort by y then x to get reading order
    p <- p[order(p$y, p$x), ]

    # Find figure label tokens
    fig_idx <- grep("^(Fig(ure)?[\\.]?)$", p$text, perl = TRUE, ignore.case = TRUE)

    for (fi in fig_idx) {
      if (fi >= nrow(p)) next

      # Check next token is a number
      next_word <- p$text[fi + 1]
      if (!grepl("^\\d", next_word)) next

      # Extract the figure number/label (e.g., "5", "3a", "3b")
      fig_num <- gsub("[^0-9a-zA-Z]", "", next_word)
      fig_label <- paste(p$text[fi], fig_num)

      # Reconstruct the caption: collect text from the label token onward.
      # Follow continuation lines using text box height as a proxy for line spacing.
      label_y <- p$y[fi]
      label_x <- p$x[fi]
      label_h <- p$height[fi]  # text box height (proxy for font size)

      # First, get all words on the label line (same y, approximately)
      same_line <- which(abs(p$y - label_y) < 2 & p$x >= label_x)
      same_line <- same_line[same_line >= fi]
      same_line <- same_line[order(p$x[same_line])]
      caption_words <- p$text[same_line]

      # Follow continuation lines
      # TUNABLE: caption continuation is the hardest part of heuristic extraction.
      # Captions vary wildly across publishers. These stop conditions work for
      # major publishers but may need adjustment for preprints or unusual layouts.
      if (length(same_line) > 0) {
        last_y <- max(p$y[same_line])
        line_height <- if (label_h > 0) label_h * 1.5 else 12

        # TUNABLE: max continuation lines before hard stop
        max_cont_lines <- 5

        for (cont in seq_len(max_cont_lines)) {
          # Find words on the next line down
          remaining <- which(p$y > last_y + 1)
          if (length(remaining) == 0) break

          next_y <- min(p$y[remaining])

          # TUNABLE: gap multiplier — larger = more tolerant of spacing
          # 2x line height catches tight layouts; 3x was too generous
          if ((next_y - last_y) > line_height * 2) break

          cont_line <- which(abs(p$y - next_y) < 2)
          cont_line <- cont_line[order(p$x[cont_line])]
          cont_text <- paste(p$text[cont_line], collapse = " ")

          # Stop if we hit a new figure label or section heading
          if (grepl("^(Fig(ure)?[\\.]?\\s+\\d|FIGURE\\s+\\d|Table\\s+\\d|References)", cont_text, ignore.case = TRUE)) break

          # Stop if text box height changes significantly (different text style = new section)
          cont_h <- p$height[cont_line[1]]
          if (cont_h > 0 && label_h > 0 && cont_h > label_h * 1.5) break

          # TUNABLE: x-offset drift — if continuation starts much further right
          # or left than the caption label, it's probably body text in a different
          # column, not a continuation. Tolerance: 50% of page width.
          cont_x <- min(p$x[cont_line])
          if (abs(cont_x - label_x) > 200) break

          caption_words <- c(caption_words, p$text[cont_line])
          last_y <- next_y
        }
      }

      caption_text <- paste(caption_words, collapse = " ")
      caption_text <- gsub("\\s+", " ", trimws(caption_text))

      # TUNABLE: max caption length — truncate to prevent body text bleed.
      # Most real captions are under 500 chars. Long ones are usually errors.
      max_caption_chars <- 500
      if (nchar(caption_text) > max_caption_chars) {
        # Truncate at last sentence boundary before the limit
        truncated <- substr(caption_text, 1, max_caption_chars)
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

  if (length(all_captions) == 0) return(data.frame(page = integer(), figure_label = character(), caption_text = character()))
  do.call(rbind, all_captions)
}

# --- Helper: associate captions with extracted figures -----------------------
# Match captions to figures by page number. If multiple figures on a page,
# match by y-proximity (TODO when we have bounding boxes for crops).

associate_captions <- function(manifest, captions) {
  if (nrow(manifest) == 0 || nrow(captions) == 0) {
    manifest$figure_label <- NA_character_
    manifest$caption <- NA_character_
    return(manifest)
  }

  manifest$figure_label <- NA_character_
  manifest$caption <- NA_character_

  for (i in seq_len(nrow(manifest))) {
    pg <- manifest$page[i]
    page_captions <- captions[captions$page == pg, , drop = FALSE]

    if (nrow(page_captions) == 0) next

    # For now: use the first caption on the page (most pages have one figure)
    # TODO: when we have crop y-coordinates, match by proximity
    manifest$figure_label[i] <- page_captions$figure_label[1]
    manifest$caption[i] <- page_captions$caption_text[1]

    # If we used this caption, remove it so the next figure on the same page
    # gets a different one
    if (nrow(page_captions) > 1) {
      captions <- captions[!(captions$page == pg & captions$caption_text == page_captions$caption_text[1]), ]
    }
  }

  manifest
}

# --- Helper: find contiguous gaps in a boolean occupancy vector --------------

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

# --- Helper: convert raw bitmap to numeric array ----------------------------
# pdf_render_page returns a raw bitmap with dims [channels x width x height].
# We need numeric [height x width x channels] for cropping and writePNG.

bitmap_to_array <- function(bm) {
  dims <- dim(bm)           # channels x width x height
  n_ch <- dims[1]
  img_w <- dims[2]
  img_h <- dims[3]
  arr <- array(as.integer(bm), dim = c(n_ch, img_w, img_h))
  aperm(arr, c(3, 2, 1))   # -> height x width x channels
}

# --- Helper: check if a cropped region is mostly blank -----------------------

is_mostly_blank <- function(img_array, threshold = 0.95) {
  white_frac <- mean(img_array > 240)
  white_frac > threshold
}

# --- Basic size filtering ----------------------------------------------------

filter_by_size <- function(manifest) {
  if (nrow(manifest) == 0) return(manifest)

  keep <- manifest$width  >= CONFIG$min_width &
          manifest$height >= CONFIG$min_height &
          manifest$file_size > 1000

  removed <- sum(!keep)
  if (removed > 0) {
    message(sprintf("  [filter] Removed %d images below size thresholds", removed))
  }

  manifest[keep, , drop = FALSE]
}

# --- Basic deduplication (byte-level hash) -----------------------------------

deduplicate <- function(manifest) {
  if (nrow(manifest) == 0) return(manifest)

  hashes <- vapply(manifest$file_path, function(f) {
    digest::digest(file = f, algo = "md5")
  }, character(1), USE.NAMES = FALSE)

  manifest$hash <- hashes
  dupes <- duplicated(hashes)

  if (any(dupes)) {
    message(sprintf("  [dedup] Removed %d duplicate images", sum(dupes)))
  }

  manifest[!dupes, , drop = FALSE]
}

# --- Process a single PDF ----------------------------------------------------

process_one_pdf <- function(pdf_path, output_dir, use_poppler) {
  pdf_name <- tools::file_path_sans_ext(basename(pdf_path))
  pdf_out <- file.path(output_dir, pdf_name)
  dir.create(pdf_out, recursive = TRUE, showWarnings = FALSE)

  message(sprintf("\n>>> Processing: %s", basename(pdf_path)))
  message(sprintf("    Output:     %s", pdf_out))

  if (use_poppler) {
    manifest <- extract_via_poppler(pdf_path, pdf_out)
  } else {
    manifest <- extract_via_rendering(pdf_path, pdf_out)
  }

  if (is.null(manifest) || nrow(manifest) == 0) {
    message("    No images found.")
    return(data.frame())
  }

  message(sprintf("    Raw: %d images", nrow(manifest)))

  manifest <- filter_by_size(manifest)

  if (requireNamespace("digest", quietly = TRUE)) {
    manifest <- deduplicate(manifest)
  }

  census <- attr(manifest, "figure_census")
  if (!is.null(census) && census > 0) {
    message(sprintf("    Final: %d figures (paper references up to Figure %d — recall: %d/%d)",
      nrow(manifest), census, min(nrow(manifest), census), census))
  } else {
    message(sprintf("    Final: %d figures", nrow(manifest)))
  }

  # Tag with source PDF
  manifest$source_pdf <- basename(pdf_path)

  manifest
}

# --- Argument parsing --------------------------------------------------------

parse_args <- function() {
  raw <- commandArgs(trailingOnly = TRUE)

  # When run from IDE (no CLI args), use the toggles at the top of the script
  if (length(raw) == 0) {
    raw   <- INPUT
    smoke <- SMOKE
    out_dir <- OUT_DIR
  } else {
    smoke <- "--smoke" %in% raw
    raw   <- raw[raw != "--smoke"]

    out_dir <- "extracted_figures"
    out_idx <- which(raw == "--out")
    if (length(out_idx) > 0 && out_idx < length(raw)) {
      out_dir <- raw[out_idx + 1]
      raw <- raw[-c(out_idx, out_idx + 1)]
    }
  }

  inputs <- raw

  # Resolve inputs: expand directories to their PDF contents
  pdf_paths <- character()
  for (inp in inputs) {
    inp <- normalizePath(inp, mustWork = FALSE)
    if (dir.exists(inp)) {
      found <- list.files(inp, pattern = "\\.pdf$", full.names = TRUE, ignore.case = TRUE)
      if (length(found) == 0) {
        message(sprintf("Warning: no PDFs found in directory %s", inp))
      }
      pdf_paths <- c(pdf_paths, found)
    } else if (file.exists(inp)) {
      pdf_paths <- c(pdf_paths, inp)
    } else {
      message(sprintf("Warning: %s not found, skipping", inp))
    }
  }

  if (length(pdf_paths) == 0) {
    message("Error: no valid PDF files found.")
    quit(status = 1)
  }

  list(pdf_paths = pdf_paths, output_dir = out_dir, smoke = smoke)
}

# --- Main entry point --------------------------------------------------------

main <- function() {
  args <- parse_args()

  message("=== v17 PDF Image Extraction Prototype ===")
  message("")

  # --- Smoke test mode ---
  if (args$smoke) {
    smoke_test(args$pdf_paths)
    return(invisible(NULL))
  }

  # --- Full extraction ---
  use_poppler <- has_pdfimages()

  message("--- Strategy ---")
  if (use_poppler) {
    message(sprintf("  Using POPPLER (%s)", poppler_version()))
  } else {
    message("  Using RENDER FALLBACK (pdfimages not on PATH)")
  }
  message(sprintf("  Output: %s", args$output_dir))
  message(sprintf("  PDFs:   %d file%s",
    length(args$pdf_paths),
    if (length(args$pdf_paths) != 1) "s" else ""))

  # Process each PDF
  all_manifests <- list()
  for (pdf_path in args$pdf_paths) {
    result <- tryCatch(
      process_one_pdf(pdf_path, args$output_dir, use_poppler),
      error = function(e) {
        message(sprintf("    ERROR: %s", conditionMessage(e)))
        data.frame()
      }
    )
    if (nrow(result) > 0) {
      all_manifests[[length(all_manifests) + 1]] <- result
    }
  }

  # Combined summary
  if (length(all_manifests) == 0) {
    message("\n=== No figures extracted from any PDF ===")
    return(invisible(NULL))
  }

  combined <- do.call(rbind, all_manifests)
  combined$filename <- basename(combined$file_path)

  message("\n=== Combined Results ===")
  message(sprintf("  Total figures: %d from %d PDF%s",
    nrow(combined),
    length(args$pdf_paths),
    if (length(args$pdf_paths) != 1) "s" else ""))

  # Per-PDF breakdown
  message("")
  message("  Per-PDF breakdown:")
  for (src in unique(combined$source_pdf)) {
    n <- sum(combined$source_pdf == src)
    message(sprintf("    %s: %d figures", src, n))
  }

  # Print summary table
  summary_cols <- c("source_pdf", "filename", "page", "figure_label", "caption_quality", "method")
  avail_cols <- intersect(summary_cols, names(combined))
  message("")
  print(combined[, avail_cols, drop = FALSE], row.names = FALSE)

  # Save combined manifest
  csv_path <- file.path(args$output_dir, "manifest_all.csv")
  dir.create(args$output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(combined, csv_path, row.names = FALSE)
  message(sprintf("\nCombined manifest: %s", csv_path))

  message("\nDone. Review extracted images in the output directory.")
  invisible(combined)
}

# --- Run it ------------------------------------------------------------------
main()
