---
title: "feat: Add figure review and selection UI"
type: feat
date: 2026-03-18
epic: "#44"
stage: 6
---

# Figure Review & Selection UI

## Overview

Add a figure gallery to `mod_document_notebook.R` that lets users extract figures from PDFs, review them visually, and control which figures are available for downstream use (slides). This is Stage 6 of the PDF image pipeline (Epic #44).

## Proposed Solution

### Architecture

Follow the existing sub-module trigger pattern (like `mod_slides`). The figure gallery renders in a **collapsible panel** below the document list, showing figures for the currently-selected document. Extraction is triggered by a per-document button and blocks the UI with a progress modal.

### UI Layout

```
┌──────────────────────────────────────────┐
│ Documents                    [+ Upload]  │
├──────────────────────────────────────────┤
│  paper1.pdf  [5 figs] [📊] [🗑]         │
│  paper2.pdf           [📊] [🗑]         │
│  paper3.pdf  [8 figs] [📊] [🗑]         │
├──────────────────────────────────────────┤
│ ▼ Figures: paper1.pdf   [List|Grid]     │
│                                          │
│  ┌─────┐  Figure 1 (p.3)               │
│  │ img │  Caption: PCA embeddings...     │
│  │     │  AI: Scatter plot showing...    │
│  └─────┘  [Keep ✓] [Retry ↻] [Ban ✕]   │
│                                          │
│  ┌─────┐  Figure 2 (p.5)               │
│  │ img │  Caption: Distribution of...    │
│  │     │  AI: No description. [Retry]    │
│  └─────┘  [Keep ✓] [Ban ✕]             │
│                                          │
└──────────────────────────────────────────┘
```

### Implementation Phases

#### Phase 1: Extract Button + Progress Modal

**Files:** `R/mod_document_notebook.R`

Add an "Extract Figures" button to each PDF document row. The button:
- Only appears for `.pdf` documents
- Shows figure count badge if figures already exist (e.g., "5 figs")
- On click:
  - If figures exist: confirmation dialog ("Replace 5 existing figures?")
  - Shows blocking modal with progress text
  - Calls `extract_and_describe_figures()` with a progress callback that updates the modal
  - On completion: closes modal, refreshes figure gallery, shows notification

```r
# R/mod_document_notebook.R — inside document list renderUI
extract_id <- ns(paste0("extract_figs_", doc$id))

# Check if figures already exist
fig_count <- nrow(db_get_figures_for_document(con(), doc$id))

# Button with badge
if (grepl("\\.pdf$", doc$filename, ignore.case = TRUE)) {
  actionButton(extract_id,
    label = if (fig_count > 0) paste0(fig_count, " figs") else icon_image(),
    class = if (fig_count > 0) "btn btn-sm btn-outline-success" else "btn btn-sm btn-outline-secondary"
  )
}
```

**Observer pattern** — use `reactiveValues()` tracker to prevent duplicate observers:

```r
extract_observers <- reactiveValues()

# Inside document list renderUI loop:
if (is.null(extract_observers[[doc$id]])) {
  local({
    d_id <- doc$id
    d_filename <- doc$filename
    d_filepath <- doc$filepath

    observeEvent(input[[paste0("extract_figs_", d_id)]], {
      # Check for existing figures -> confirmation if needed
      existing <- nrow(db_get_figures_for_document(con(), d_id))
      if (existing > 0) {
        showModal(modalDialog(
          title = "Replace existing figures?",
          paste0("This will replace ", existing, " existing figures for ", d_filename, "."),
          footer = tagList(
            actionButton(ns("confirm_reextract"), "Replace", class = "btn-warning"),
            modalButton("Cancel")
          )
        ))
        return()
      }
      # Otherwise start extraction directly
      run_extraction(d_id, nb_id, d_filepath, d_filename)
    }, ignoreInit = TRUE)
  })
  extract_observers[[doc$id]] <- TRUE
}
```

**Progress modal:**

```r
run_extraction <- function(doc_id, notebook_id, pdf_path, filename) {
  showModal(modalDialog(
    title = "Extracting Figures",
    tags$div(id = "extract-progress",
      tags$p(id = "extract-status", "Starting..."),
      tags$div(class = "progress",
        tags$div(id = "extract-bar", class = "progress-bar",
                 role = "progressbar", style = "width: 0%")
      )
    ),
    footer = NULL, easyClose = FALSE
  ))

  cfg <- config()
  api_key <- cfg$openrouter$api_key

  result <- extract_and_describe_figures(
    con = con(), api_key = api_key,
    document_id = doc_id, notebook_id = notebook_id,
    pdf_path = pdf_path, session_id = session$token,
    progress = function(value, detail) {
      # Update modal via session$sendCustomMessage or direct JS
    }
  )

  removeModal()

  if (result$n_extracted == 0) {
    showNotification(
      paste0("No figures found in ", filename, ". This may be a text-only document."),
      type = "warning", duration = 6
    )
  } else {
    showNotification(
      sprintf("Extracted %d figures (%d described) from %s",
              result$n_extracted, result$n_described, filename),
      type = "message"
    )
    selected_doc(doc_id)  # Open gallery for this document
    fig_refresh(fig_refresh() + 1)
  }
}
```

**Dependencies:** `R/pdf_images.R` (extract_and_describe_figures), `R/db.R` (db_get_figures_for_document)

---

#### Phase 2: Figure Gallery Panel

**Files:** `R/mod_document_notebook.R`

Add a collapsible figure gallery below the document list. The gallery:
- Appears only when a document with figures is selected
- Has a view toggle: List (default) | Thumbnail
- Renders via `output$figure_gallery <- renderUI({ ... })`
- Loads figures via `db_get_figures_for_document(con(), selected_doc())`
- Serves images via `addResourcePath()` for the notebook's figure directory

**Reactive state:**

```r
selected_doc <- reactiveVal(NULL)     # Which document's figures to show
fig_refresh <- reactiveVal(0)         # Trigger gallery re-render
gallery_view <- reactiveVal("list")   # "list" or "grid"
```

**Image serving:**

```r
# Register resource path when gallery renders
figures_dir <- file.path("data", "figures", nb_id)
if (dir.exists(figures_dir)) {
  resource_name <- paste0("figures_", gsub("-", "", nb_id))
  addResourcePath(resource_name, normalizePath(figures_dir))
}

# Image URL for a figure:
img_src <- file.path(resource_name, doc_id, basename(fig$file_path))
```

**List view** — each figure is a card with:

```r
# R/mod_document_notebook.R — figure card helper
figure_card_list <- function(fig, ns, resource_prefix) {
  img_src <- file.path(resource_prefix, fig$document_id, basename(fig$file_path))
  is_excluded <- isTRUE(fig$is_excluded)
  has_desc <- !is.na(fig$llm_description) && nchar(fig$llm_description) > 0

  card(
    class = if (is_excluded) "opacity-50 border-danger" else "",
    card_body(
      class = "p-2",
      layout_columns(
        col_widths = c(4, 8),
        # Image column
        tags$img(src = img_src, class = "img-fluid rounded",
                 style = "max-height: 200px; object-fit: contain;"),
        # Info column
        tags$div(
          tags$strong(paste0(
            fig$figure_label %||% paste("Figure", fig$page_number),
            " (p.", fig$page_number, ")"
          )),
          if (!is.na(fig$extracted_caption))
            tags$p(class = "text-muted small mb-1",
                   substr(fig$extracted_caption, 1, 200)),
          if (has_desc)
            tags$p(class = "small mb-1", icon_brain(), " ",
                   substr(fig$llm_description, 1, 150))
          else
            tags$p(class = "text-warning small mb-1",
                   "No description available"),
          # Action buttons
          tags$div(class = "btn-group btn-group-sm mt-1",
            actionButton(ns(paste0("keep_", fig$id)),
              label = tagList(icon_check(), "Keep"),
              class = if (!is_excluded) "btn-success" else "btn-outline-success"
            ),
            actionButton(ns(paste0("retry_", fig$id)),
              label = tagList(icon_refresh(), "Retry"),
              class = "btn-outline-primary"
            ),
            actionButton(ns(paste0("ban_", fig$id)),
              label = tagList(icon_ban(), "Ban"),
              class = if (is_excluded) "btn-danger" else "btn-outline-danger"
            )
          )
        )
      )
    )
  )
}
```

**Thumbnail/grid view** — smaller cards in a responsive grid:

```r
figure_card_grid <- function(fig, ns, resource_prefix) {
  img_src <- file.path(resource_prefix, fig$document_id, basename(fig$file_path))
  is_excluded <- isTRUE(fig$is_excluded)

  tags$div(
    class = paste("p-1", if (is_excluded) "opacity-50"),
    style = "width: 200px; display: inline-block; vertical-align: top;",
    card(
      card_body(
        class = "p-1 text-center",
        tags$img(src = img_src, class = "img-fluid rounded",
                 style = "max-height: 120px; object-fit: contain;"),
        tags$small(class = "d-block text-muted",
          fig$figure_label %||% paste0("p.", fig$page_number)
        ),
        tags$div(class = "btn-group btn-group-sm mt-1",
          actionButton(ns(paste0("keep_", fig$id)), icon_check(),
            class = if (!is_excluded) "btn-success btn-sm" else "btn-outline-success btn-sm"),
          actionButton(ns(paste0("ban_", fig$id)), icon_ban(),
            class = if (is_excluded) "btn-danger btn-sm" else "btn-outline-danger btn-sm")
        )
      )
    )
  )
}
```

---

#### Phase 3: Per-Figure Actions (Keep / Retry / Ban)

**Files:** `R/mod_document_notebook.R`, `R/pdf_images.R`

**Observer pattern** — persistent observers per figure, tracked in reactiveValues:

```r
fig_action_observers <- reactiveValues()

# Inside gallery renderUI, for each figure:
if (is.null(fig_action_observers[[fig$id]])) {
  local({
    f_id <- fig$id
    f_path <- fig$file_path
    f_label <- fig$figure_label
    f_caption <- fig$extracted_caption

    # Keep
    observeEvent(input[[paste0("keep_", f_id)]], {
      db_update_figure(con(), f_id, is_excluded = FALSE)
      fig_refresh(fig_refresh() + 1)
    }, ignoreInit = TRUE)

    # Ban
    observeEvent(input[[paste0("ban_", f_id)]], {
      db_update_figure(con(), f_id, is_excluded = TRUE)
      fig_refresh(fig_refresh() + 1)
    }, ignoreInit = TRUE)

    # Retry
    observeEvent(input[[paste0("retry_", f_id)]], {
      cfg <- config()
      api_key <- cfg$openrouter$api_key
      if (is.null(api_key) || nchar(api_key) == 0) {
        showNotification("Configure an API key in Settings to describe figures.",
                         type = "warning")
        return()
      }

      # Disable button, show spinner (via JS)
      shinyjs::disable(paste0("retry_", f_id))

      desc <- describe_figure(
        api_key = api_key,
        image_data = f_path,  # file path
        figure_label = f_label,
        extracted_caption = f_caption
      )

      if (desc$success) {
        description_text <- desc$summary
        if (!is.na(desc$details) && nchar(desc$details) > 0) {
          description_text <- paste0(description_text, "\n\n", desc$details)
        }
        db_update_figure(con(), f_id,
          llm_description = description_text,
          image_type = desc$type
        )
        # Log cost
        if (desc$prompt_tokens > 0 || desc$completion_tokens > 0) {
          cost <- estimate_cost(desc$model_used, desc$prompt_tokens, desc$completion_tokens)
          log_cost(con(), "figure_description", desc$model_used,
                   desc$prompt_tokens, desc$completion_tokens,
                   desc$prompt_tokens + desc$completion_tokens,
                   cost, session$token)
        }
        showNotification("Description updated", type = "message", duration = 3)
      } else {
        showNotification("Failed to describe figure", type = "error", duration = 5)
      }

      shinyjs::enable(paste0("retry_", f_id))
      fig_refresh(fig_refresh() + 1)
    }, ignoreInit = TRUE)
  })
  fig_action_observers[[f_id]] <- TRUE
}
```

**Cleanup on re-extraction:** When `run_extraction()` is called, clear the observer tracker so new observers are registered for the new figure IDs:

```r
# Inside run_extraction(), after successful extraction:
for (old_id in names(fig_action_observers)) {
  fig_action_observers[[old_id]] <- NULL
}
```

---

#### Phase 4: Icon Registration + Polish

**Files:** `R/theme_catppuccin.R`, `R/mod_document_notebook.R`

- Add `icon_image <- function(...) shiny::icon("image", ...)` to theme_catppuccin.R
- Add `icon_refresh <- function(...) shiny::icon("rotate", ...)` if not already present
- Wire gallery view toggle (List/Grid buttons)
- Style excluded figures with `opacity-50` and red border
- Show "No description" placeholder with contextual message:
  - API key exists: "No description. Click Retry to generate."
  - No API key: "Configure API key in Settings to enable descriptions."

---

#### Phase 5: Smoke Test + Shiny Validation

- Start the app with `shiny::runApp()`
- Verify:
  - Extract button appears only for PDF documents
  - Extraction modal shows and updates progress
  - Gallery renders with correct images
  - List/Grid toggle works
  - Keep/Ban toggles update DB and refresh gallery
  - Retry calls vision API and updates description
  - Re-extraction warns and replaces figures
  - App doesn't crash on documents with 0 figures

---

## Acceptance Criteria

### Functional Requirements

- [ ] "Extract Figures" button appears for PDF documents only
- [ ] Clicking extract shows a blocking progress modal
- [ ] Extraction completes and gallery appears with extracted figures
- [ ] Gallery has two views: list (large images + full metadata) and thumbnail grid
- [ ] Each figure shows: image, page number, label, caption, LLM description, status
- [ ] Keep button marks figure as included (is_excluded=FALSE)
- [ ] Ban button marks figure as excluded (is_excluded=TRUE), visually dims it
- [ ] Retry button re-runs vision description on one figure, updates DB
- [ ] Re-extraction on a document with existing figures shows confirmation dialog
- [ ] Figure count badge shows on document rows that have extracted figures
- [ ] 0-figure extraction shows a warning notification
- [ ] Vision API costs are logged via log_cost()

### Edge Cases

- [ ] PDF file not found on disk → error notification, no crash
- [ ] No API key configured → extraction runs (figures extracted), vision skipped, gallery shows "No description" placeholder
- [ ] Retry without API key → warning notification
- [ ] Document deletion cascades to figure cleanup (already handled by db_delete_figures_for_document)
- [ ] Gallery persists across sessions (figures in DB + PNGs on disk)

### Quality Gates

- [ ] App starts without errors (Shiny smoke test)
- [ ] Existing document notebook functionality unaffected
- [ ] All existing tests pass

---

## Dependencies

- `R/pdf_images.R` — extract_and_describe_figures(), describe_figure()
- `R/pdf_extraction.R` — extract_figures_from_pdf()
- `R/db.R` — db_get_figures_for_document(), db_update_figure()
- `R/cost_tracking.R` — log_cost(), estimate_cost()
- `R/theme_catppuccin.R` — icon helpers

## Out of Scope

- Bulk select/deselect actions (v2 if needed)
- Drag-and-drop figure reordering
- Figure cropping/editing in browser
- Async/background extraction (current synchronous approach is fine for <60s operations)
- Stage 7 (slide injection) — separate work

## References

- `R/mod_document_notebook.R` — existing module to extend
- `R/mod_slides.R` — sub-module trigger pattern reference
- `docs/plans/2026-03-17-feat-pdf-image-pipeline-app-integration-plan.md` — backend pipeline plan
- Epic #44 on GitHub
