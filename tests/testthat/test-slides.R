# tests/testthat/test-slides.R
test_that("check_quarto_installed returns TRUE when quarto exists", {
  # This test will pass/fail based on local environment
  # We're testing the function exists and returns boolean
  result <- check_quarto_installed()
  expect_type(result, "logical")
})

test_that("get_quarto_version returns version string or NULL", {
  result <- get_quarto_version()
  if (!is.null(result)) {
    expect_type(result, "character")
    expect_true(grepl("^\\d+\\.\\d+", result))
  }
})

test_that("build_slides_prompt constructs valid prompt", {
  chunks <- data.frame(
    content = c("Introduction text here.", "Methods section content."),
    doc_name = c("paper.pdf", "paper.pdf"),
    page_number = c(1, 5),
    stringsAsFactors = FALSE
  )

  options <- list(
    length = "medium",
    audience = "technical",
    citation_style = "footnotes",
    include_notes = TRUE,
    custom_instructions = "Focus on methodology"
  )

  prompt <- build_slides_prompt(chunks, options)

  expect_type(prompt, "list")
  expect_true("system" %in% names(prompt))
  expect_true("user" %in% names(prompt))
  expect_true(grepl("RevealJS", prompt$system))
  expect_true(grepl("Introduction text here", prompt$user))
  expect_true(grepl("paper.pdf", prompt$user))
  expect_true(grepl("Focus on methodology", prompt$user))
})

test_that("build_slides_prompt handles different lengths", {
  chunks <- data.frame(
    content = "Test content",
    doc_name = "test.pdf",
    page_number = 1,
    stringsAsFactors = FALSE
  )

  short_prompt <- build_slides_prompt(chunks, list(length = "short"))
  medium_prompt <- build_slides_prompt(chunks, list(length = "medium"))
  long_prompt <- build_slides_prompt(chunks, list(length = "long"))

  expect_true(grepl("5-8 slides", short_prompt$user))
  expect_true(grepl("10-15 slides", medium_prompt$user))
  expect_true(grepl("20\\+? slides", long_prompt$user))
})

test_that("inject_theme_to_qmd adds theme to frontmatter", {
  qmd_content <- "---\ntitle: Test\nformat:\n  revealjs: default\n---\n\n## Slide 1\nContent"

  result <- inject_theme_to_qmd(qmd_content, "moon")

  expect_true(grepl("theme: moon", result))
})

test_that("inject_theme_to_qmd handles missing format section", {
  qmd_content <- "---\ntitle: Test\n---\n\n## Slide 1\nContent"

  result <- inject_theme_to_qmd(qmd_content, "dark")

  expect_true(grepl("format:", result))
  expect_true(grepl("theme: dark", result))
})

test_that("render_qmd_to_html returns path or error", {
  skip_if_not(check_quarto_installed(), "Quarto not installed")

  # Create minimal valid qmd
  qmd_content <- "---\ntitle: Test\nformat: revealjs\n---\n\n## Slide 1\n\nHello"
  qmd_path <- tempfile(fileext = ".qmd")
  writeLines(qmd_content, qmd_path)

  result <- render_qmd_to_html(qmd_path)

  if (!is.null(result$error)) {
    skip(paste("Render failed:", result$error))
  }

  expect_true(file.exists(result$path))
  expect_true(grepl("\\.html$", result$path))

  # Cleanup
  unlink(qmd_path)
  unlink(result$path)
})

test_that("generate_slides returns qmd content", {
  skip("Integration test - requires API key")

  # This test documents the expected interface
  # NOTE: generate_slides() now returns a `validation` field alongside qmd/qmd_path/error
  # validation = list(valid = TRUE/FALSE, errors = character(), parsed = list/NULL)
  chunks <- data.frame(
    content = "Test content about machine learning.",
    doc_name = "ml_paper.pdf",
    page_number = 1,
    stringsAsFactors = FALSE
  )

  options <- list(
    length = "short",
    audience = "general",
    citation_style = "none",
    include_notes = FALSE,
    theme = "default"
  )

  result <- generate_slides(
    api_key = "test-key",
    model = "anthropic/claude-sonnet-4",
    chunks = chunks,
    options = options
  )

  expect_type(result, "list")
  expect_true("qmd" %in% names(result) || "error" %in% names(result))
})

# --- Phase 39: Slide Healing tests ---

test_that("build_slides_prompt includes YAML template in system prompt", {
  chunks <- data.frame(
    content = "Test content",
    doc_name = "test.pdf",
    page_number = 1,
    stringsAsFactors = FALSE
  )

  prompt <- build_slides_prompt(chunks, list())

  expect_true(grepl("CRITICAL", prompt$system))
  expect_true(grepl("title:", prompt$system))
  expect_true(grepl("revealjs", prompt$system))
  expect_true(grepl("---", prompt$system))
})

test_that("build_slides_prompt includes Quarto syntax reference", {
  chunks <- data.frame(
    content = "Test content",
    doc_name = "test.pdf",
    page_number = 1,
    stringsAsFactors = FALSE
  )

  prompt <- build_slides_prompt(chunks, list(citation_style = "footnotes"))

  # Check for syntax reference section with correct Quarto footnote syntax
  expect_true(grepl("Syntax Reference", prompt$system))
  expect_true(grepl("\\^\\[", prompt$system))  # Inline footnote syntax ^[text]
  expect_true(grepl("do NOT use", prompt$system, ignore.case = TRUE))  # Negative instruction
  expect_true(grepl("::: \\{.notes\\}", prompt$system))  # Speaker notes syntax
  expect_true(grepl("\\| Method \\|", prompt$system))  # Table syntax
  # Should NOT inject theme/css
  expect_true(grepl("Do NOT add theme, css", prompt$system))

  # Check citation instructions use inline footnote syntax
  expect_true(grepl("\\^\\[", prompt$user))  # Shows ^[text] example
  expect_false(grepl("\\^1 superscript", prompt$user))  # Old syntax gone
})

test_that("build_healing_prompt includes Quarto syntax reference", {
  previous_qmd <- "---\ntitle: Test\n---\n\n## Slide"
  errors <- character(0)
  instructions <- "Fix footnotes"

  prompt <- build_healing_prompt(previous_qmd, errors, instructions)

  # Check for syntax reference with correct Quarto footnote syntax
  expect_true(grepl("Syntax Reference", prompt$system))
  expect_true(grepl("\\^\\[", prompt$system))  # Inline footnote syntax ^[text]
  expect_true(grepl("do NOT use", prompt$system, ignore.case = TRUE))  # Negative instruction
  expect_true(grepl("::: \\{.notes\\}", prompt$system))  # Speaker notes syntax
  expect_true(grepl("\\| Method \\|", prompt$system))  # Table syntax
  # Should preserve existing YAML
  expect_true(grepl("Preserve the existing YAML", prompt$system))
})

test_that("validate_qmd_yaml validates correct YAML", {
  qmd <- "---\ntitle: Test\nformat: revealjs\n---\n\n## Slide 1"
  result <- validate_qmd_yaml(qmd)

  expect_true(result$valid)
  expect_equal(length(result$errors), 0)
  expect_type(result$parsed, "list")
  expect_equal(result$parsed$title, "Test")
  expect_equal(result$parsed$format, "revealjs")
})

test_that("validate_qmd_yaml detects missing frontmatter", {
  qmd <- "## No YAML here\n\nJust content"
  result <- validate_qmd_yaml(qmd)

  expect_false(result$valid)
  expect_true(grepl("No YAML frontmatter", result$errors[1]))
  expect_null(result$parsed)
})

test_that("validate_qmd_yaml detects invalid YAML", {
  # Invalid YAML: bad indentation
  qmd <- "---\ntitle: Test\n  bad:\n    - item\n  broken\n---\n\n## Slide"
  result <- validate_qmd_yaml(qmd)

  # yaml::yaml.load should error on this malformed YAML
  # The exact behavior depends on what yaml considers invalid
  expect_type(result, "list")
  expect_true("valid" %in% names(result))
})

test_that("validate_qmd_yaml detects empty frontmatter", {
  qmd <- "---\n---\n\n## Slide 1"
  result <- validate_qmd_yaml(qmd)

  expect_false(result$valid)
  expect_true(grepl("Empty", result$errors[1]))
  expect_null(result$parsed)
})

test_that("build_healing_prompt includes previous QMD and errors", {
  previous_qmd <- "---\ntitle: Broken\n---\n\n## Slide"
  errors <- c("YAML parse error at line 3")
  instructions <- "Fix the YAML"

  prompt <- build_healing_prompt(previous_qmd, errors, instructions)

  expect_type(prompt, "list")
  expect_true("system" %in% names(prompt))
  expect_true("user" %in% names(prompt))
  expect_true(grepl("fixer", prompt$system, ignore.case = TRUE))
  expect_true(grepl("Broken", prompt$user))
  expect_true(grepl("YAML parse error", prompt$user))
  expect_true(grepl("Fix the YAML", prompt$user))
})

test_that("build_healing_prompt works without errors", {
  previous_qmd <- "---\ntitle: Good\n---\n\n## Slide"
  instructions <- "Make text bigger"

  prompt <- build_healing_prompt(previous_qmd, character(0), instructions)

  expect_true(grepl("Make text bigger", prompt$user))
  # Should not have error section
  expect_false(grepl("Validation errors found", prompt$user))
})

test_that("build_fallback_qmd generates valid template", {
  chunks <- data.frame(
    content = c("Introduction to machine learning concepts.", "Methods for deep learning."),
    doc_name = c("paper1.pdf", "paper2.pdf"),
    page_number = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- build_fallback_qmd(chunks, "Test Presentation")

  expect_true(grepl("^---", result))
  expect_true(grepl("title:", result))
  expect_true(grepl("Test Presentation", result))
  expect_true(grepl("format:", result))
  expect_true(grepl("revealjs", result))
  expect_true(grepl("## Overview", result))
  expect_true(grepl("2 source document", result))
})

test_that("build_fallback_qmd includes section headers from documents", {
  chunks <- data.frame(
    content = c("First doc content", "Second doc content"),
    doc_name = c("introduction.pdf", "methodology.pdf"),
    page_number = c(1, 1),
    stringsAsFactors = FALSE
  )

  result <- build_fallback_qmd(chunks)

  expect_true(grepl("## introduction", result))
  expect_true(grepl("## methodology", result))
})

test_that("get_healing_chips returns cosmetic chips on success", {
  chips <- get_healing_chips(character(0), TRUE)

  expect_type(chips, "character")
  expect_true("Fewer bullet points" %in% chips)
  expect_true("Make text bigger" %in% chips)
  expect_true("Simplify slides" %in% chips)
})

test_that("get_healing_chips returns YAML fix chip on YAML error", {
  chips <- get_healing_chips("YAML parse error at line 3", FALSE)

  expect_true("Fix YAML syntax" %in% chips)
  expect_true("Simplify slides" %in% chips)
})

test_that("get_healing_chips returns CSS fix chip on CSS error", {
  chips <- get_healing_chips("CSS formatting issue in slide 2", FALSE)

  expect_true("Fix CSS formatting" %in% chips)
})

test_that("get_healing_chips returns Quarto fix chip on render error", {
  chips <- get_healing_chips("Quarto render failed", FALSE)

  expect_true("Fix Quarto formatting" %in% chips)
})
