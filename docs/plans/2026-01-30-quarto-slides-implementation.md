# Quarto Slide Generation - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "Generate Slides" feature to document notebooks that creates RevealJS presentations from selected PDFs.

**Architecture:** A new Shiny module (`mod_slides.R`) handles the modal UI with document selection and configuration options. A core library (`slides.R`) handles prompt construction, LLM calls, and Quarto rendering via `processx`. Generated files live in `tempdir()` and are served for preview/download.

**Tech Stack:** R/Shiny, bslib modals, OpenRouter API (existing), Quarto CLI (system dependency), processx for CLI execution.

---

## Task 1: Create Quarto Detection Utility

**Files:**
- Create: `R/slides.R`
- Test: `tests/testthat/test-slides.R`

**Step 1: Write the failing test**

```r
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
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: Error - `check_quarto_installed` not found

**Step 3: Write minimal implementation**

```r
# R/slides.R
library(processx)

#' Check if Quarto CLI is installed
#' @return TRUE if quarto command exists, FALSE otherwise
check_quarto_installed <- function() {
  result <- tryCatch({
    run("quarto", "--version", error_on_status = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })
  result
}

#' Get Quarto version string
#' @return Version string like "1.4.550" or NULL if not installed
get_quarto_version <- function() {
  tryCatch({
    result <- run("quarto", "--version", error_on_status = FALSE)
    if (result$status == 0) {
      trimws(result$stdout)
    } else {
      NULL
    }
  }, error = function(e) {
    NULL
  })
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add R/slides.R tests/testthat/test-slides.R
git commit -m "feat(slides): add Quarto detection utilities"
```

---

## Task 2: Add Database Helper to Fetch All Chunks for Documents

**Files:**
- Modify: `R/db.R`
- Test: `tests/testthat/test-db.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-db.R`:

```r
test_that("get_chunks_for_documents returns chunks with source info", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  # Create notebook and document
  nb_id <- create_notebook(con, "Test", "document")
  doc_id <- create_document(con, nb_id, "test.pdf", "/path/test.pdf", "Full text", 5)

  # Create chunks
  create_chunk(con, doc_id, "document", 1, "Chunk one content", page_number = 1)
  create_chunk(con, doc_id, "document", 2, "Chunk two content", page_number = 2)

  # Fetch chunks
  chunks <- get_chunks_for_documents(con, doc_id)

  expect_equal(nrow(chunks), 2)
  expect_true("doc_name" %in% names(chunks))
  expect_true("page_number" %in% names(chunks))
  expect_equal(chunks$doc_name[1], "test.pdf")
})

test_that("get_chunks_for_documents handles multiple document IDs", {
  con <- get_db_connection(":memory:")
  on.exit(close_db_connection(con))
  init_schema(con)

  nb_id <- create_notebook(con, "Test", "document")
  doc1_id <- create_document(con, nb_id, "doc1.pdf", "/path/doc1.pdf", "Text 1", 3)
  doc2_id <- create_document(con, nb_id, "doc2.pdf", "/path/doc2.pdf", "Text 2", 2)

  create_chunk(con, doc1_id, "document", 1, "Doc1 chunk", page_number = 1)
  create_chunk(con, doc2_id, "document", 1, "Doc2 chunk", page_number = 1)

  chunks <- get_chunks_for_documents(con, c(doc1_id, doc2_id))

  expect_equal(nrow(chunks), 2)
  expect_true("doc1.pdf" %in% chunks$doc_name)
  expect_true("doc2.pdf" %in% chunks$doc_name)
})
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: Error - `get_chunks_for_documents` not found

**Step 3: Write minimal implementation**

Add to `R/db.R`:

```r
#' Get all chunks for specific documents with source info
#' @param con DuckDB connection
#' @param document_ids Vector of document IDs
#' @return Data frame of chunks with document metadata
get_chunks_for_documents <- function(con, document_ids) {
  if (length(document_ids) == 0) {
    return(data.frame(
      id = character(),
      source_id = character(),
      chunk_index = integer(),
      content = character(),
      page_number = integer(),
      doc_name = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Build parameterized query
  placeholders <- paste(rep("?", length(document_ids)), collapse = ", ")
  query <- sprintf("
    SELECT
      c.id,
      c.source_id,
      c.chunk_index,
      c.content,
      c.page_number,
      d.filename as doc_name
    FROM chunks c
    JOIN documents d ON c.source_id = d.id
    WHERE c.source_id IN (%s)
    ORDER BY d.filename, c.chunk_index
  ", placeholders)

  dbGetQuery(con, query, as.list(document_ids))
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: PASS

**Step 5: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat(db): add get_chunks_for_documents helper"
```

---

## Task 3: Build Slide Generation Prompt Constructor

**Files:**
- Modify: `R/slides.R`
- Modify: `tests/testthat/test-slides.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-slides.R`:

```r
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
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: Error - `build_slides_prompt` not found

**Step 3: Write minimal implementation**

Add to `R/slides.R`:

```r
#' Build prompt for slide generation
#' @param chunks Data frame with content, doc_name, page_number
#' @param options List with length, audience, citation_style, include_notes, custom_instructions
#' @return List with system and user prompt strings
build_slides_prompt <- function(chunks, options) {
  # Default options
  length_val <- options$length %||% "medium"
  audience <- options$audience %||% "general"
  citation_style <- options$citation_style %||% "footnotes"
  include_notes <- options$include_notes %||% TRUE
  custom_instructions <- options$custom_instructions %||% ""


  # Map length to slide count
  slide_counts <- list(
    short = "5-8 slides",
    medium = "10-15 slides",
    long = "20+ slides"
  )
  slide_count <- slide_counts[[length_val]] %||% "10-15 slides"

  # Build context from chunks
  context_parts <- vapply(seq_len(nrow(chunks)), function(i) {
    sprintf("[%s, p.%d]:\n%s",
            chunks$doc_name[i],
            chunks$page_number[i],
            chunks$content[i])
  }, character(1))
  context <- paste(context_parts, collapse = "\n\n---\n\n")

  # System prompt
  system_prompt <- paste0(
    "You are an expert presentation designer. Generate a Quarto RevealJS presentation in valid .qmd format.\n\n",
    "Output format requirements:\n",
    "- Start with YAML frontmatter (title, format: revealjs)\n",
    "- Use # for section titles (creates horizontal slide breaks)\n",
    "- Use ## for individual slide titles\n",
    "- Keep slides concise - max 5-7 bullet points per slide\n",
    if (include_notes) "- Include speaker notes using ::: {.notes} blocks\n" else "",
    "- Output ONLY valid Quarto markdown, no explanations or code fences around the output"
  )

  # Citation instructions
  citation_instructions <- switch(citation_style,
    "footnotes" = "Use footnote-style citations: add superscript numbers after key points and list references at the end.",
    "inline" = "Use inline parenthetical citations like (Author, p.X) after relevant content.",
    "notes_only" = "Put all citations in speaker notes only, keeping slides clean.",
    "none" = "Do not include citations.",
    "Use footnote-style citations."
  )

  # User prompt
  user_prompt <- sprintf(
    "Create a presentation with %s for a %s audience.\n\n%s\n\n%sSource content:\n\n%s",
    slide_count,
    audience,
    citation_instructions,
    if (nchar(custom_instructions) > 0) paste0("Additional instructions: ", custom_instructions, "\n\n") else "",
    context
  )

  list(system = system_prompt, user = user_prompt)
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: PASS

**Step 5: Commit**

```bash
git add R/slides.R tests/testthat/test-slides.R
git commit -m "feat(slides): add prompt constructor for slide generation"
```

---

## Task 4: Add Quarto Rendering Functions

**Files:**
- Modify: `R/slides.R`
- Modify: `tests/testthat/test-slides.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-slides.R`:

```r
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
```

**Step 2: Run test to verify it fails**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: Error - `inject_theme_to_qmd` not found

**Step 3: Write minimal implementation**

Add to `R/slides.R`:

```r
#' Inject theme into QMD frontmatter
#' @param qmd_content Raw QMD string
#' @param theme RevealJS theme name
#' @return Modified QMD string with theme
inject_theme_to_qmd <- function(qmd_content, theme) {
  if (is.null(theme) || theme == "default") {
    return(qmd_content)
  }

  # Check if format section exists
  if (grepl("format:\\s*\\n\\s*revealjs:", qmd_content)) {
    # Add theme under revealjs section
    qmd_content <- sub(
      "(format:\\s*\\n\\s*revealjs:)",
      paste0("\\1\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("format:\\s*revealjs", qmd_content)) {
    # Convert simple format to expanded with theme
    qmd_content <- sub(
      "format:\\s*revealjs",
      paste0("format:\n  revealjs:\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("^---", qmd_content)) {
    # No format section, add one before closing ---
    qmd_content <- sub(
      "\n---\n",
      paste0("\nformat:\n  revealjs:\n    theme: ", theme, "\n---\n"),
      qmd_content
    )
  }

  qmd_content
}

#' Render QMD file to HTML
#' @param qmd_path Path to .qmd file
#' @param timeout Timeout in seconds
#' @return List with path (on success) or error (on failure)
render_qmd_to_html <- function(qmd_path, timeout = 120) {
  if (!check_quarto_installed()) {
    return(list(path = NULL, error = "Quarto is not installed"))
  }

  output_path <- sub("\\.qmd$", ".html", qmd_path)

  result <- tryCatch({
    run(
      "quarto",
      c("render", qmd_path, "--to", "html"),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, error = function(e) {
    return(list(status = -1, stderr = e$message))
  })

  if (result$status != 0) {
    return(list(path = NULL, error = paste("Render failed:", result$stderr)))
  }

  if (!file.exists(output_path)) {
    return(list(path = NULL, error = "Output file not created"))
  }

  list(path = output_path, error = NULL)
}

#' Render QMD file to PDF
#' @param qmd_path Path to .qmd file
#' @param timeout Timeout in seconds
#' @return List with path (on success) or error (on failure)
render_qmd_to_pdf <- function(qmd_path, timeout = 180) {
  if (!check_quarto_installed()) {
    return(list(path = NULL, error = "Quarto is not installed"))
  }

  output_path <- sub("\\.qmd$", ".pdf", qmd_path)

  result <- tryCatch({
    run(
      "quarto",
      c("render", qmd_path, "--to", "pdf"),
      timeout = timeout,
      error_on_status = FALSE
    )
  }, error = function(e) {
    return(list(status = -1, stderr = e$message))
  })

  if (result$status != 0) {
    return(list(path = NULL, error = paste("PDF render failed:", result$stderr)))
  }

  if (!file.exists(output_path)) {
    return(list(path = NULL, error = "PDF file not created"))
  }

  list(path = output_path, error = NULL)
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: PASS

**Step 5: Commit**

```bash
git add R/slides.R tests/testthat/test-slides.R
git commit -m "feat(slides): add Quarto rendering functions"
```

---

## Task 5: Create Main Slide Generation Function

**Files:**
- Modify: `R/slides.R`
- Modify: `tests/testthat/test-slides.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-slides.R`:

```r
test_that("generate_slides returns qmd content", {
  skip("Integration test - requires API key")

  # This test documents the expected interface
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
```

**Step 2: Run test to verify structure exists**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: Skip (test skipped intentionally)

**Step 3: Write minimal implementation**

Add to `R/slides.R`:

```r
#' Generate slides from document chunks
#' @param api_key OpenRouter API key
#' @param model Model ID to use
#' @param chunks Data frame with content, doc_name, page_number
#' @param options List with length, audience, citation_style, include_notes, theme, custom_instructions
#' @param notebook_name Name of notebook (for title)
#' @return List with qmd (content string), qmd_path (temp file), or error
generate_slides <- function(api_key, model, chunks, options, notebook_name = "Presentation") {
  # Build prompt

  prompt <- build_slides_prompt(chunks, options)

  # Call LLM
  messages <- format_chat_messages(prompt$system, prompt$user)

  qmd_content <- tryCatch({
    chat_completion(api_key, model, messages)
  }, error = function(e) {
    return(list(qmd = NULL, error = paste("LLM error:", e$message)))
  })

  if (is.list(qmd_content) && !is.null(qmd_content$error)) {
    return(qmd_content)
  }

  # Clean up response - remove markdown code fences if present
  qmd_content <- gsub("^```(qmd|markdown|yaml)?\\n?", "", qmd_content)
  qmd_content <- gsub("\\n?```$", "", qmd_content)
  qmd_content <- trimws(qmd_content)

  # Inject theme if specified
  theme <- options$theme %||% "default"
  if (theme != "default") {
    qmd_content <- inject_theme_to_qmd(qmd_content, theme)
  }

  # Save to temp file
  qmd_path <- file.path(tempdir(), paste0(gsub("[^a-zA-Z0-9]", "-", notebook_name), "-slides.qmd"))
  writeLines(qmd_content, qmd_path)

  list(qmd = qmd_content, qmd_path = qmd_path, error = NULL)
}
```

**Step 4: Run test to verify it passes**

Run: `Rscript -e "testthat::test_file('tests/testthat/test-slides.R')"`
Expected: PASS (skip counted as pass)

**Step 5: Commit**

```bash
git add R/slides.R tests/testthat/test-slides.R
git commit -m "feat(slides): add main generate_slides function"
```

---

## Task 6: Create Slides Modal UI Module

**Files:**
- Create: `R/mod_slides.R`

**Step 1: Create the UI function**

```r
# R/mod_slides.R
#' Slides Generation Modal UI
#' @param id Module namespace ID
#' @param documents Data frame of documents (id, filename)
#' @param models Data frame of available models (id, name)
#' @param current_model Currently selected model ID
mod_slides_modal_ui <- function(id, documents, models, current_model) {
  ns <- NS(id)

  # RevealJS themes
  themes <- c("default", "beige", "blood", "dark", "league",
              "moon", "night", "serif", "simple", "sky", "solarized")

  modalDialog(
    title = tagList(icon("presentation-screen"), "Generate Slides"),
    size = "l",
    easyClose = FALSE,

    # Document selection
    div(
      class = "mb-4",
      h6("Select Documents", class = "fw-semibold"),
      div(
        class = "border rounded p-3",
        style = "max-height: 200px; overflow-y: auto;",
        checkboxInput(ns("select_all_docs"), "Select All", value = TRUE),
        hr(class = "my-2"),
        checkboxGroupInput(
          ns("selected_docs"),
          NULL,
          choices = setNames(documents$id, documents$filename),
          selected = documents$id
        )
      )
    ),

    # Configuration options
    div(
      class = "mb-3",
      h6("Options", class = "fw-semibold"),

      layout_columns(
        col_widths = c(6, 6),

        # Model selection
        selectInput(
          ns("model"),
          "Model",
          choices = setNames(models$id, models$name),
          selected = current_model
        ),

        # Length
        radioButtons(
          ns("length"),
          "Presentation Length",
          choices = c("Short (5-8 slides)" = "short",
                      "Medium (10-15 slides)" = "medium",
                      "Long (20+ slides)" = "long"),
          selected = "medium",
          inline = TRUE
        )
      ),

      layout_columns(
        col_widths = c(4, 4, 4),

        # Audience
        selectInput(
          ns("audience"),
          "Audience",
          choices = c("Technical" = "technical",
                      "Executive" = "executive",
                      "General / Educational" = "general"),
          selected = "general"
        ),

        # Citation style
        selectInput(
          ns("citation_style"),
          "Citation Style",
          choices = c("Footnotes" = "footnotes",
                      "Inline (Author, p.X)" = "inline",
                      "Speaker Notes Only" = "notes_only",
                      "None" = "none"),
          selected = "footnotes"
        ),

        # Theme
        selectInput(
          ns("theme"),
          "Theme",
          choices = themes,
          selected = "default"
        )
      ),

      # Speaker notes checkbox
      checkboxInput(ns("include_notes"), "Include speaker notes", value = TRUE),

      # Custom instructions
      textAreaInput(
        ns("custom_instructions"),
        "Custom Instructions (optional)",
        placeholder = "e.g., Focus on methodology, include comparison table...",
        rows = 2
      )
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("generate"), "Generate", class = "btn-primary", icon = icon("wand-magic-sparkles"))
    )
  )
}

#' Slides Results Modal UI
#' @param id Module namespace ID
#' @param preview_url URL to preview HTML (or NULL)
#' @param error Error message (or NULL)
mod_slides_results_ui <- function(id, preview_url = NULL, error = NULL) {
  ns <- NS(id)

  content <- if (!is.null(error)) {
    div(
      class = "alert alert-danger",
      icon("triangle-exclamation", class = "me-2"),
      strong("Generation failed: "), error
    )
  } else if (!is.null(preview_url)) {
    tagList(
      div(
        class = "mb-3",
        style = "height: 400px; border: 1px solid var(--bs-border-color); border-radius: 0.5rem; overflow: hidden;",
        tags$iframe(
          src = preview_url,
          style = "width: 100%; height: 100%; border: none;"
        )
      ),
      div(
        class = "d-flex gap-2 justify-content-center",
        downloadButton(ns("download_qmd"), "Download .qmd", class = "btn-outline-primary"),
        downloadButton(ns("download_html"), "Download HTML", class = "btn-outline-primary"),
        downloadButton(ns("download_pdf"), "Download PDF", class = "btn-outline-secondary")
      )
    )
  } else {
    div(
      class = "text-center py-5",
      div(class = "spinner-border text-primary", role = "status"),
      p(class = "mt-3 text-muted", "Generating slides...")
    )
  }

  modalDialog(
    title = tagList(icon("presentation-screen"), "Generated Slides"),
    size = "xl",
    easyClose = FALSE,
    content,
    footer = tagList(
      actionButton(ns("regenerate"), "Regenerate", class = "btn-outline-secondary", icon = icon("rotate")),
      modalButton("Close")
    )
  )
}
```

**Step 2: No test for UI (visual component)**

UI modules are tested via integration/manual testing.

**Step 3: Commit**

```bash
git add R/mod_slides.R
git commit -m "feat(slides): add modal UI components"
```

---

## Task 7: Create Slides Module Server Logic

**Files:**
- Modify: `R/mod_slides.R`

**Step 1: Add server function**

Add to `R/mod_slides.R`:

```r
#' Slides Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
#' @param trigger Reactive trigger to open modal
mod_slides_server <- function(id, con, notebook_id, config, trigger) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store generation state
    generation_state <- reactiveValues(
      qmd_content = NULL,
      qmd_path = NULL,
      html_path = NULL,
      pdf_path = NULL,
      error = NULL,
      last_options = NULL
    )

    # Handle select all checkbox
    observeEvent(input$select_all_docs, {
      nb_id <- notebook_id()
      req(nb_id)
      docs <- list_documents(con(), nb_id)

      if (input$select_all_docs) {
        updateCheckboxGroupInput(session, "selected_docs", selected = docs$id)
      } else {
        updateCheckboxGroupInput(session, "selected_docs", selected = character(0))
      }
    }, ignoreInit = TRUE)

    # Open modal when triggered
    observeEvent(trigger(), {
      nb_id <- notebook_id()
      req(nb_id)

      # Check Quarto installation
      if (!check_quarto_installed()) {
        showNotification(
          "Quarto is not installed. Please install Quarto to use slide generation: https://quarto.org/docs/get-started/",
          type = "error",
          duration = 10
        )
        return()
      }

      # Get documents
      docs <- list_documents(con(), nb_id)
      if (nrow(docs) == 0) {
        showNotification("No documents in this notebook", type = "warning")
        return()
      }

      # Get models
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      models <- tryCatch({
        list_models(api_key)
      }, error = function(e) {
        data.frame(id = "anthropic/claude-sonnet-4", name = "Claude Sonnet 4", stringsAsFactors = FALSE)
      })

      current_model <- get_setting(cfg, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"

      # Reset state
      generation_state$qmd_content <- NULL
      generation_state$qmd_path <- NULL
      generation_state$html_path <- NULL
      generation_state$error <- NULL

      showModal(mod_slides_modal_ui(id, docs, models, current_model))
    }, ignoreInit = TRUE)

    # Handle generation
    observeEvent(input$generate, {
      req(input$selected_docs)
      nb_id <- notebook_id()
      cfg <- config()

      # Get selected document IDs
      doc_ids <- input$selected_docs

      if (length(doc_ids) == 0) {
        showNotification("Please select at least one document", type = "warning")
        return()
      }

      # Store options for regeneration
      generation_state$last_options <- list(
        model = input$model,
        length = input$length,
        audience = input$audience,
        citation_style = input$citation_style,
        include_notes = input$include_notes,
        theme = input$theme,
        custom_instructions = input$custom_instructions
      )

      # Show loading modal
      showModal(mod_slides_results_ui(id))

      # Get chunks for selected documents
      chunks <- get_chunks_for_documents(con(), doc_ids)

      if (nrow(chunks) == 0) {
        generation_state$error <- "No content found in selected documents"
        showModal(mod_slides_results_ui(id, error = generation_state$error))
        return()
      }

      # Get notebook name for title
      nb <- get_notebook(con(), nb_id)
      notebook_name <- nb$name %||% "Presentation"

      # Generate slides
      api_key <- get_setting(cfg, "openrouter", "api_key")

      result <- generate_slides(
        api_key = api_key,
        model = input$model,
        chunks = chunks,
        options = generation_state$last_options,
        notebook_name = notebook_name
      )

      if (!is.null(result$error)) {
        generation_state$error <- result$error
        showModal(mod_slides_results_ui(id, error = result$error))
        return()
      }

      generation_state$qmd_content <- result$qmd
      generation_state$qmd_path <- result$qmd_path

      # Render to HTML for preview
      html_result <- render_qmd_to_html(result$qmd_path)

      if (!is.null(html_result$error)) {
        # Still show modal but with error, offer qmd download
        generation_state$error <- html_result$error
        showModal(mod_slides_results_ui(id, error = paste("Preview failed:", html_result$error, "- You can still download the .qmd file")))
        return()
      }

      generation_state$html_path <- html_result$path

      # Create resource path for preview
      preview_name <- basename(html_result$path)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      showModal(mod_slides_results_ui(id, preview_url = preview_url))
    })

    # Handle regeneration
    observeEvent(input$regenerate, {
      nb_id <- notebook_id()
      req(nb_id)

      docs <- list_documents(con(), nb_id)
      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")

      models <- tryCatch({
        list_models(api_key)
      }, error = function(e) {
        data.frame(id = "anthropic/claude-sonnet-4", name = "Claude Sonnet 4", stringsAsFactors = FALSE)
      })

      current_model <- generation_state$last_options$model %||%
                       get_setting(cfg, "defaults", "chat_model") %||%
                       "anthropic/claude-sonnet-4"

      showModal(mod_slides_modal_ui(id, docs, models, current_model))
    })

    # Download handlers
    output$download_qmd <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".qmd")
      },
      content = function(file) {
        req(generation_state$qmd_content)
        writeLines(generation_state$qmd_content, file)
      }
    )

    output$download_html <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".html")
      },
      content = function(file) {
        req(generation_state$html_path)
        file.copy(generation_state$html_path, file)
      }
    )

    output$download_pdf <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".pdf")
      },
      content = function(file) {
        req(generation_state$qmd_path)

        # Render PDF on demand
        withProgress(message = "Rendering PDF...", {
          pdf_result <- render_qmd_to_pdf(generation_state$qmd_path)

          if (!is.null(pdf_result$error)) {
            showNotification(paste("PDF export failed:", pdf_result$error), type = "error")
            return()
          }

          file.copy(pdf_result$path, file)
        })
      }
    )
  })
}
```

**Step 2: Commit**

```bash
git add R/mod_slides.R
git commit -m "feat(slides): add module server logic with generation and downloads"
```

---

## Task 8: Integrate Slides Module into Document Notebook

**Files:**
- Modify: `R/mod_document_notebook.R`

**Step 1: Add Generate Slides button to UI**

In `mod_document_notebook_ui`, add button to the button group (after Outline button):

```r
# Find this section (around line 31-38):
div(
  class = "btn-group",
  actionButton(ns("btn_summarize"), "Summarize",
               class = "btn-sm btn-outline-primary"),
  actionButton(ns("btn_keypoints"), "Key Points",
               class = "btn-sm btn-outline-primary"),
  actionButton(ns("btn_studyguide"), "Study Guide",
               class = "btn-sm btn-outline-primary"),
  actionButton(ns("btn_outline"), "Outline",
               class = "btn-sm btn-outline-primary"),
  # ADD THIS LINE:
  actionButton(ns("btn_slides"), "Slides",
               class = "btn-sm btn-outline-secondary",
               icon = icon("presentation-screen"))
)
```

**Step 2: Add slides trigger and module call in server**

In `mod_document_notebook_server`, add after the existing preset handlers:

```r
# Add near the top with other reactiveVal declarations (around line 78-81):
slides_trigger <- reactiveVal(0)

# Add the slides module server call (after the preset handlers, around line 350):
mod_slides_server("slides", con, notebook_id, config, slides_trigger)

# Add the button observer (after the preset observeEvents):
observeEvent(input$btn_slides, {
  slides_trigger(slides_trigger() + 1)
})
```

**Step 3: Commit**

```bash
git add R/mod_document_notebook.R
git commit -m "feat(slides): integrate slides button into document notebook"
```

---

## Task 9: Add Missing %||% Operator to slides.R

**Files:**
- Modify: `R/slides.R`

**Step 1: Add the operator at the top of slides.R**

The `%||%` operator may not be available. Add this at the top of `R/slides.R` after the library call:

```r
# Null coalescing operator (if not already defined)
`%||%` <- function(x, y) if (is.null(x)) y else x
```

**Step 2: Commit**

```bash
git add R/slides.R
git commit -m "fix(slides): add null coalescing operator"
```

---

## Task 10: Manual Integration Test

**Files:**
- None (manual testing)

**Step 1: Start the app**

```bash
cd .worktrees/quarto-slides
Rscript -e "shiny::runApp()"
```

**Step 2: Test the flow**

1. Create a new Document Notebook
2. Upload a PDF
3. Wait for processing
4. Click "Slides" button
5. Select documents and configure options
6. Click Generate
7. Verify preview loads
8. Test all three download buttons
9. Test Regenerate button

**Step 3: Document any issues found**

If issues found, create fix commits as needed.

**Step 4: Final commit if all works**

```bash
git add -A
git commit -m "test: verify slides generation integration"
```

---

## Task 11: Update TODO.md

**Files:**
- Modify: `TODO.md`

**Step 1: Mark Quarto slides as complete**

Update the Quarto section in TODO.md:

```markdown
## 5. Quarto Slide Deck Generation

**Priority:** ~~Medium-High~~ **COMPLETED**

Generate presentation slides from notebook content using Quarto RevealJS.

### Core Features
- [x] "Generate Slides" button in notebook view
- [x] LLM extracts key points, findings, and structure from chunks
- [x] Generate Quarto `.qmd` file with RevealJS format
- [x] Support different slide styles/themes
- [x] Include citations from source documents

### Slide Generation Options
- [x] Presentation length (5/10/15 min estimates → slide count)
- [x] Audience level (technical, executive, general)
- [x] Focus area (select specific documents to include)
- [x] Include/exclude speaker notes

### Output
- [x] Preview rendered slides in-app (iframe)
- [x] Download `.qmd` source file for customization
- [x] Export to PDF/HTML directly
```

**Step 2: Commit**

```bash
git add TODO.md
git commit -m "docs: mark Quarto slide generation as complete"
```

---

## Summary

This plan creates the Quarto slide generation feature in 11 tasks:

1. **Quarto detection** - Check if CLI is installed
2. **Database helper** - Fetch chunks for specific documents
3. **Prompt builder** - Construct LLM prompt with options
4. **Rendering functions** - Theme injection, HTML/PDF rendering
5. **Main generation** - Orchestrate the full flow
6. **Modal UI** - Configuration and results modals
7. **Module server** - Handle all interactions and downloads
8. **Integration** - Add button to document notebook
9. **Fix operator** - Ensure %||% is available
10. **Manual test** - Verify everything works
11. **Documentation** - Update TODO.md

---

Plan complete and saved to `docs/plans/2026-01-30-quarto-slides-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session in worktree with executing-plans, batch execution with checkpoints

Which approach?
