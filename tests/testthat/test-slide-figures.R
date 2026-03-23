library(testthat)

source_app("slides.R")

# =============================================================================
# classify_aspect_ratio()
# =============================================================================

test_that("classify_aspect_ratio identifies wide figures", {
  expect_equal(classify_aspect_ratio(1200, 400), "wide")   # ratio = 3.0
  expect_equal(classify_aspect_ratio(1800, 900), "wide")   # ratio = 2.0
  expect_equal(classify_aspect_ratio(1240, 190), "wide")   # ratio = 6.5
})

test_that("classify_aspect_ratio identifies landscape figures", {
  expect_equal(classify_aspect_ratio(800, 600), "landscape")  # ratio = 1.33
  expect_equal(classify_aspect_ratio(150, 100), "landscape")  # ratio = 1.5
})

test_that("classify_aspect_ratio identifies square figures", {
  expect_equal(classify_aspect_ratio(500, 500), "square")  # ratio = 1.0
  expect_equal(classify_aspect_ratio(900, 800), "square")  # ratio = 1.125
  expect_equal(classify_aspect_ratio(800, 900), "square")  # ratio = 0.89
})

test_that("classify_aspect_ratio identifies portrait figures", {
  expect_equal(classify_aspect_ratio(1240, 1630), "portrait")  # ratio = 0.76
  expect_equal(classify_aspect_ratio(600, 800), "portrait")    # ratio = 0.75
  expect_equal(classify_aspect_ratio(1240, 1648), "portrait")  # ratio = 0.75
})

test_that("classify_aspect_ratio identifies tall figures", {
  expect_equal(classify_aspect_ratio(300, 800), "tall")   # ratio = 0.375
  expect_equal(classify_aspect_ratio(100, 500), "tall")   # ratio = 0.2
})

test_that("classify_aspect_ratio handles boundary values", {
  # Exactly at 1.8 boundary — should be landscape (not wide)
  expect_equal(classify_aspect_ratio(180, 100), "landscape")
  # Just above 1.8
  expect_equal(classify_aspect_ratio(181, 100), "wide")
  # Exactly at 1.2 boundary — should be landscape (not square)
  expect_equal(classify_aspect_ratio(120, 100), "landscape")
  # Just below 1.2
  expect_equal(classify_aspect_ratio(119, 100), "square")
  # Exactly at 0.8 boundary — should be square (not portrait)
  expect_equal(classify_aspect_ratio(80, 100), "square")
  # Just below 0.8
  expect_equal(classify_aspect_ratio(79, 100), "portrait")
  # Exactly at 0.6 boundary — should be portrait (not tall)
  expect_equal(classify_aspect_ratio(60, 100), "portrait")
  # Just below 0.6
  expect_equal(classify_aspect_ratio(59, 100), "tall")
})

test_that("classify_aspect_ratio handles edge cases", {
  expect_equal(classify_aspect_ratio(NA, 100), "square")
  expect_equal(classify_aspect_ratio(100, NA), "square")
  expect_equal(classify_aspect_ratio(100, 0), "square")
})

# =============================================================================
# recommend_layout()
# =============================================================================

test_that("recommend_layout returns skip for reference hint", {
  expect_true(grepl("SKIP", recommend_layout("wide", "reference")))
  expect_true(grepl("SKIP", recommend_layout("square", "reference")))
})

test_that("recommend_layout returns hero for hero hint regardless of shape", {
  expect_true(grepl("Pattern 1", recommend_layout("square", "hero")))
  expect_true(grepl("Pattern 1", recommend_layout("tall", "hero")))
})

test_that("recommend_layout maps shapes correctly for supporting hint", {
  expect_true(grepl("Pattern 1 or 4", recommend_layout("wide", "supporting")))
  expect_true(grepl("Pattern 4", recommend_layout("landscape", "supporting")))
  expect_true(grepl("Pattern 2", recommend_layout("square", "supporting")))
  expect_true(grepl("Pattern 3", recommend_layout("portrait", "supporting")))
  expect_true(grepl("Pattern 3", recommend_layout("tall", "supporting")))
})

test_that("recommend_layout defaults hint to supporting when NULL", {
  expect_true(grepl("Pattern 2", recommend_layout("square", NULL)))
  expect_true(grepl("Pattern 4", recommend_layout("landscape")))
})

# =============================================================================
# extract_description_summary()
# =============================================================================

test_that("extract_description_summary returns first paragraph", {
  desc <- "This is the summary.\n\nThis is the details section with more info."
  expect_equal(extract_description_summary(desc), "This is the summary.")
})

test_that("extract_description_summary handles single paragraph", {
  desc <- "Just a summary, no details."
  expect_equal(extract_description_summary(desc), "Just a summary, no details.")
})

test_that("extract_description_summary handles NULL and NA", {
  expect_equal(extract_description_summary(NULL), "")
  expect_equal(extract_description_summary(NA), "")
  expect_equal(extract_description_summary(""), "")
  expect_equal(extract_description_summary("  "), "")
})

test_that("extract_description_summary trims whitespace", {
  desc <- "  Summary with whitespace  \n\nDetails."
  expect_equal(extract_description_summary(desc), "Summary with whitespace")
})

# =============================================================================
# build_figure_manifest()
# =============================================================================

# Helper to create a test figures data frame
make_test_figures <- function(n = 3) {
  data.frame(
    id = paste0("fig_", seq_len(n)),
    document_id = rep("doc_1", n),
    notebook_id = rep("nb_1", n),
    page_number = seq_len(n),
    file_path = paste0("data/figures/nb_1/doc_1/fig_00", seq_len(n), "_1.png"),
    extracted_caption = paste("Caption for figure", seq_len(n)),
    llm_description = paste0("Summary line ", seq_len(n), ".\n\nDetailed description ", seq_len(n), "."),
    figure_label = paste("Figure", seq_len(n)),
    width = rep(c(1200L, 600L, 300L), length.out = n),
    height = rep(c(400L, 500L, 800L), length.out = n),
    file_size = rep(50000L, n),
    image_type = rep(c("chart", "plot", "diagram"), length.out = n),
    quality_score = rep(NA_real_, n),
    is_excluded = rep(FALSE, n),
    presentation_hint = rep(c("hero", "supporting", "reference"), length.out = n),
    doc_name = rep("test_paper.pdf", n),
    stringsAsFactors = FALSE
  )
}

test_that("build_figure_manifest returns NULL for empty input", {
  expect_null(build_figure_manifest(NULL))
  expect_null(build_figure_manifest(data.frame()))
})

test_that("build_figure_manifest includes all figure IDs", {
  figs <- make_test_figures()
  manifest <- build_figure_manifest(figs)
  expect_true(grepl("fig_1", manifest))
  expect_true(grepl("fig_2", manifest))
  expect_true(grepl("fig_3", manifest))
})

test_that("build_figure_manifest includes aspect ratio classification", {
  figs <- make_test_figures()
  manifest <- build_figure_manifest(figs)
  # fig_1: 1200x400 = wide (ratio 3.0)
  expect_true(grepl("wide", manifest))
  # fig_2: 600x500 = landscape (ratio 1.2)
  expect_true(grepl("landscape", manifest))
  # fig_3: 300x800 = tall (ratio 0.375)
  expect_true(grepl("tall", manifest))
})

test_that("build_figure_manifest includes document name and page", {
  figs <- make_test_figures()
  manifest <- build_figure_manifest(figs)
  expect_true(grepl("test_paper.pdf", manifest))
  expect_true(grepl("p\\.1", manifest))
  expect_true(grepl("p\\.2", manifest))
})

test_that("build_figure_manifest includes type and caption", {
  figs <- make_test_figures()
  manifest <- build_figure_manifest(figs)
  expect_true(grepl("Type: chart", manifest))
  expect_true(grepl("Caption: \"Caption for figure 1\"", manifest, fixed = TRUE))
})

test_that("build_figure_manifest extracts only summary from description", {
  figs <- make_test_figures()
  manifest <- build_figure_manifest(figs)
  # Summary should be present
  expect_true(grepl("Description: Summary line 1.", manifest, fixed = TRUE))
  # Details should NOT be present
  expect_false(grepl("Detailed description", manifest))
})

test_that("build_figure_manifest respects max_figures limit", {
  figs <- make_test_figures(20)
  figs$id <- paste0("fig_", seq_len(20))
  manifest <- build_figure_manifest(figs, max_figures = 5L)
  # Should have exactly 5 figures (4 separators)
  separators <- gregexpr("---", manifest)[[1]]
  expect_equal(length(separators), 4)
})

test_that("build_figure_manifest separates entries with ---", {
  figs <- make_test_figures(2)
  manifest <- build_figure_manifest(figs)
  expect_true(grepl("---", manifest))
})

test_that("build_figure_manifest handles missing optional fields", {
  figs <- make_test_figures(1)
  figs$image_type <- NA_character_
  figs$extracted_caption <- NA_character_
  figs$llm_description <- NA_character_
  figs$presentation_hint <- NA_character_
  manifest <- build_figure_manifest(figs)
  # Should still produce a valid manifest entry
  expect_true(grepl("fig_1", manifest))
  # Should not have Hint/Type/Caption/Description lines
  expect_false(grepl("Hint:", manifest))
  expect_false(grepl("Type:", manifest))
  expect_false(grepl("Caption:", manifest))
  expect_false(grepl("Description:", manifest))
})

test_that("build_figure_manifest includes presentation hint", {
  figs <- make_test_figures(2)
  figs$presentation_hint <- c("hero", "supporting")
  manifest <- build_figure_manifest(figs)
  expect_true(grepl("Hint: hero", manifest))
  expect_true(grepl("Hint: supporting", manifest))
})

test_that("build_figure_manifest includes recommended layout", {
  figs <- make_test_figures(3)
  # fig_1: 1200x400 = wide, hint = hero → Pattern 1
  # fig_2: 600x500 = landscape, hint = supporting → Pattern 4
  # fig_3: 300x800 = tall, hint = reference → SKIP
  figs$presentation_hint <- c("hero", "supporting", "reference")
  manifest <- build_figure_manifest(figs)
  expect_true(grepl(">>> Recommended:", manifest))
  expect_true(grepl("Pattern 1", manifest))  # hero override
  expect_true(grepl("Pattern 4", manifest))  # landscape + supporting
  expect_true(grepl("SKIP", manifest))       # reference
})

# =============================================================================
# stage_figures_for_quarto()
# =============================================================================

test_that("stage_figures_for_quarto copies files to target dir", {
  # Create temp source and target dirs
  src_dir <- file.path(tempdir(), "test_stage_src")
  tgt_dir <- file.path(tempdir(), "test_stage_tgt")
  dir.create(src_dir, showWarnings = FALSE)
  dir.create(tgt_dir, showWarnings = FALSE)
  on.exit({
    unlink(src_dir, recursive = TRUE)
    unlink(tgt_dir, recursive = TRUE)
  })

  # Create a fake PNG
  src_file <- file.path(src_dir, "fig_001_1.png")
  writeBin(as.raw(c(0x89, 0x50, 0x4E, 0x47)), src_file)

  figs <- data.frame(
    id = "abc123",
    file_path = src_file,
    stringsAsFactors = FALSE
  )

  staged <- stage_figures_for_quarto(figs, tgt_dir)
  expect_equal(staged[["abc123"]], "abc123.png")
  expect_true(file.exists(file.path(tgt_dir, "abc123.png")))
})

test_that("stage_figures_for_quarto returns empty for NULL input", {
  expect_equal(length(stage_figures_for_quarto(NULL, tempdir())), 0)
  expect_equal(length(stage_figures_for_quarto(data.frame(), tempdir())), 0)
})

test_that("stage_figures_for_quarto warns on missing files", {
  figs <- data.frame(
    id = "missing123",
    file_path = "/nonexistent/path/fig.png",
    stringsAsFactors = FALSE
  )
  expect_warning(
    staged <- stage_figures_for_quarto(figs, tempdir()),
    "Figure file missing"
  )
  expect_equal(length(staged), 0)
})

test_that("stage_figures_for_quarto handles multiple figures without collision", {
  src_dir <- file.path(tempdir(), "test_multi_src")
  tgt_dir <- file.path(tempdir(), "test_multi_tgt")
  dir.create(src_dir, showWarnings = FALSE)
  dir.create(tgt_dir, showWarnings = FALSE)
  on.exit({
    unlink(src_dir, recursive = TRUE)
    unlink(tgt_dir, recursive = TRUE)
  })

  # Create two fake PNGs
  for (name in c("a.png", "b.png")) {
    writeBin(as.raw(c(0x89, 0x50)), file.path(src_dir, name))
  }

  figs <- data.frame(
    id = c("id_aaa", "id_bbb"),
    file_path = c(file.path(src_dir, "a.png"), file.path(src_dir, "b.png")),
    stringsAsFactors = FALSE
  )

  staged <- stage_figures_for_quarto(figs, tgt_dir)
  expect_equal(length(staged), 2)
  expect_true(file.exists(file.path(tgt_dir, "id_aaa.png")))
  expect_true(file.exists(file.path(tgt_dir, "id_bbb.png")))
})

# =============================================================================
# inline_figure_data_uris()
# =============================================================================

test_that("inline_figure_data_uris replaces references with data URIs", {
  src_dir <- file.path(tempdir(), "test_inline_src")
  dir.create(src_dir, showWarnings = FALSE)
  on.exit(unlink(src_dir, recursive = TRUE))

  # Create a small fake PNG
  src_file <- file.path(src_dir, "fig.png")
  writeBin(as.raw(c(0x89, 0x50, 0x4E, 0x47)), src_file)

  figs <- data.frame(
    id = "abc-123",
    file_path = src_file,
    stringsAsFactors = FALSE
  )

  qmd <- "## Slide\n\n![Caption](abc-123.png){width=\"90%\"}"
  result <- inline_figure_data_uris(qmd, figs)

  expect_true(grepl("data:image/png;base64,", result, fixed = TRUE))
  expect_false(grepl("abc-123.png", result, fixed = TRUE))
})

test_that("inline_figure_data_uris skips unreferenced figures", {
  src_dir <- file.path(tempdir(), "test_inline_skip")
  dir.create(src_dir, showWarnings = FALSE)
  on.exit(unlink(src_dir, recursive = TRUE))

  src_file <- file.path(src_dir, "fig.png")
  writeBin(as.raw(c(0x89, 0x50)), src_file)

  figs <- data.frame(
    id = "not-in-qmd",
    file_path = src_file,
    stringsAsFactors = FALSE
  )

  qmd <- "## Slide\n\nNo figures here."
  result <- inline_figure_data_uris(qmd, figs)
  expect_equal(result, qmd)
})

test_that("inline_figure_data_uris warns on missing files", {
  figs <- data.frame(
    id = "missing-fig",
    file_path = "/nonexistent/fig.png",
    stringsAsFactors = FALSE
  )

  qmd <- "![Alt](missing-fig.png)"
  expect_warning(
    inline_figure_data_uris(qmd, figs),
    "Figure file missing"
  )
})

test_that("inline_figure_data_uris handles NULL input", {
  expect_equal(inline_figure_data_uris("some content", NULL), "some content")
  expect_equal(inline_figure_data_uris("some content", data.frame()), "some content")
})

# =============================================================================
# normalize_figure_refs()
# =============================================================================

test_that("normalize_figure_refs adds .png to bare UUID references", {
  qmd <- "![Caption](abc-123-def)\n\nSome text"
  result <- normalize_figure_refs(qmd, "abc-123-def")
  expect_true(grepl("abc-123-def.png)", result, fixed = TRUE))
})

test_that("normalize_figure_refs adds .png before { attributes", {
  qmd <- '![Caption](abc-123){width="90%"}'
  result <- normalize_figure_refs(qmd, "abc-123")
  expect_true(grepl('abc-123.png){width="90%"}', result, fixed = TRUE))
})

test_that("normalize_figure_refs does not double-add .png", {
  qmd <- "![Caption](abc-123.png)"
  result <- normalize_figure_refs(qmd, "abc-123")
  # Should NOT become abc-123.png.png
  expect_false(grepl(".png.png", result, fixed = TRUE))
  expect_true(grepl("abc-123.png)", result, fixed = TRUE))
})

test_that("normalize_figure_refs handles multiple figures", {
  qmd <- "![A](fig-1)\n![B](fig-2)"
  result <- normalize_figure_refs(qmd, c("fig-1", "fig-2"))
  expect_true(grepl("fig-1.png)", result, fixed = TRUE))
  expect_true(grepl("fig-2.png)", result, fixed = TRUE))
})

test_that("normalize_figure_refs handles empty figure_ids", {
  qmd <- "no figures here"
  expect_equal(normalize_figure_refs(qmd, character(0)), qmd)
})

# =============================================================================
# post_process_figure_layouts()
# =============================================================================

test_that("post_process_figure_layouts adds attrs to bare wide figure", {
  qmd <- "![Caption](abc.png)"
  figs <- data.frame(id = "abc", width = 1200L, height = 400L, stringsAsFactors = FALSE)
  result <- post_process_figure_layouts(qmd, figs)
  expect_true(grepl('width="90%"', result))
})

test_that("post_process_figure_layouts adds height for portrait figure", {
  qmd <- "![Caption](abc.png)"
  figs <- data.frame(id = "abc", width = 1240L, height = 1648L, stringsAsFactors = FALSE)
  result <- post_process_figure_layouts(qmd, figs)
  expect_true(grepl('height="500px"', result))
})

test_that("post_process_figure_layouts skips figures with existing attrs", {
  qmd <- '![Caption](abc.png){width="50%"}'
  figs <- data.frame(id = "abc", width = 1200L, height = 400L, stringsAsFactors = FALSE)
  result <- post_process_figure_layouts(qmd, figs)
  # Should NOT modify — already has attributes
  expect_equal(result, qmd)
})

test_that("post_process_figure_layouts overrides width with height for portrait figures", {
  qmd <- '![Caption](abc.png){width="100%"}'
  figs <- data.frame(id = "abc", width = 1240L, height = 1648L, stringsAsFactors = FALSE)
  result <- post_process_figure_layouts(qmd, figs)
  # Should replace width with height for portrait figure
  expect_true(grepl('height="500px"', result))
  expect_false(grepl('width="100%"', result))
})

test_that("post_process_figure_layouts skips unreferenced figures", {
  qmd <- "No figures here."
  figs <- data.frame(id = "abc", width = 1200L, height = 400L, stringsAsFactors = FALSE)
  result <- post_process_figure_layouts(qmd, figs)
  expect_equal(result, qmd)
})

test_that("post_process_figure_layouts handles NULL input", {
  expect_equal(post_process_figure_layouts("content", NULL), "content")
  expect_equal(post_process_figure_layouts("content", data.frame()), "content")
})

# =============================================================================
# build_slides_prompt() with figures
# =============================================================================

test_that("build_slides_prompt without figures matches original behavior", {
  chunks <- data.frame(
    content = c("Some content", "More content"),
    doc_name = c("paper.pdf", "paper.pdf"),
    page_number = c(1L, 2L),
    stringsAsFactors = FALSE
  )
  options <- list(length = "medium", audience = "general", citation_style = "footnotes",
                  include_notes = TRUE, custom_instructions = "")

  # Without figures
  prompt_no_figs <- build_slides_prompt(chunks, options, figures = NULL)
  # Should NOT contain figure instructions
  expect_false(grepl("Figure Integration", prompt_no_figs$system))
  expect_false(grepl("Available figures", prompt_no_figs$user))
})

test_that("build_slides_prompt with figures adds layout patterns to system prompt", {
  chunks <- data.frame(
    content = "Some content",
    doc_name = "paper.pdf",
    page_number = 1L,
    stringsAsFactors = FALSE
  )
  options <- list(length = "medium", audience = "general", citation_style = "footnotes",
                  include_notes = TRUE, custom_instructions = "")
  figs <- make_test_figures(1)

  prompt <- build_slides_prompt(chunks, options, figures = figs)
  expect_true(grepl("Figure Integration", prompt$system))
  # Should have layout patterns
  expect_true(grepl("Pattern 1", prompt$system))
  expect_true(grepl("Pattern 2", prompt$system))
  expect_true(grepl("Pattern 3", prompt$system))
  expect_true(grepl("Pattern 4", prompt$system))
  # Should have hard rules enforcing recommendations
  expect_true(grepl("MUST follow", prompt$system))
  expect_true(grepl("NEVER put wide", prompt$system))
  expect_true(grepl("NEVER use.*width.*90.*portrait", prompt$system))
  # Should instruct to vary layouts
  expect_true(grepl("Vary your layouts", prompt$system))
})

test_that("build_slides_prompt with figures adds manifest to user prompt", {
  chunks <- data.frame(
    content = "Some content",
    doc_name = "paper.pdf",
    page_number = 1L,
    stringsAsFactors = FALSE
  )
  options <- list(length = "medium", audience = "general", citation_style = "footnotes",
                  include_notes = TRUE, custom_instructions = "")
  figs <- make_test_figures(2)

  prompt <- build_slides_prompt(chunks, options, figures = figs)
  expect_true(grepl("Available figures", prompt$user))
  expect_true(grepl("fig_1", prompt$user))
  expect_true(grepl("fig_2", prompt$user))
})
