# Keyword Filter & Deferred Embedding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add keyword tag cloud for filtering papers, deferred embedding with explicit "Embed Papers" button, and paper exclusion tracking.

**Architecture:** Add `excluded_paper_ids` column to notebooks table. Modify refresh to skip embedding. Add keyword panel UI in right column header area. Add X button to paper list items. Track exclusions and filter on refresh.

**Tech Stack:** R/Shiny, DuckDB, bslib, jsonlite

---

## Task 1: Add excluded_paper_ids Column to Database

**Files:**
- Modify: `R/db.R:102-109`
- Test: `tests/testthat/test-db.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-db.R`:

```r
test_that("notebook stores excluded_paper_ids", {
  con <- init_db(":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  create_notebook(con, "test-nb", "Test", "search")

  # Update with excluded papers
  excluded <- c("W12345", "W67890")
  update_notebook(con, "test-nb", excluded_paper_ids = excluded)

  # Retrieve and verify
  nb <- get_notebook(con, "test-nb")
  stored_excluded <- jsonlite::fromJSON(nb$excluded_paper_ids)
  expect_equal(stored_excluded, excluded)
})

test_that("notebook excluded_paper_ids defaults to empty array", {
  con <- init_db(":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  create_notebook(con, "test-nb", "Test", "search")

  nb <- get_notebook(con, "test-nb")
  # Should be NULL, NA, or empty JSON array
expect_true(is.na(nb$excluded_paper_ids) || nb$excluded_paper_ids == "[]" || is.null(nb$excluded_paper_ids))
})
```

**Step 2: Run test to verify it fails**

Run: `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: FAIL - column doesn't exist

**Step 3: Add migration for excluded_paper_ids column**

In `R/db.R`, after the keywords migration (around line 108), add:

```r
  # Migration: Add excluded_paper_ids column to notebooks table (added 2026-02-06)
  tryCatch({
    dbExecute(con, "ALTER TABLE notebooks ADD COLUMN excluded_paper_ids VARCHAR DEFAULT '[]'")
  }, error = function(e) {
    # Column already exists, ignore
  })
```

**Step 4: Update update_notebook function**

Find `update_notebook` function in `R/db.R` and add support for `excluded_paper_ids` parameter:

```r
update_notebook <- function(con, id, name = NULL, search_query = NULL,
                            search_filters = NULL, excluded_paper_ids = NULL) {
  updates <- c()
  params <- list()

  if (!is.null(name)) {
    updates <- c(updates, "name = ?")
    params <- c(params, list(name))
  }
  if (!is.null(search_query)) {
    updates <- c(updates, "search_query = ?")
    params <- c(params, list(search_query))
  }
  if (!is.null(search_filters)) {
    updates <- c(updates, "search_filters = ?")
    filters_json <- jsonlite::toJSON(search_filters, auto_unbox = TRUE)
    params <- c(params, list(filters_json))
  }
  if (!is.null(excluded_paper_ids)) {
    updates <- c(updates, "excluded_paper_ids = ?")
    excluded_json <- jsonlite::toJSON(excluded_paper_ids, auto_unbox = TRUE)
    params <- c(params, list(excluded_json))
  }

  if (length(updates) == 0) return(invisible(NULL))

  updates <- c(updates, "updated_at = CURRENT_TIMESTAMP")
  params <- c(params, list(id))

  query <- paste0("UPDATE notebooks SET ", paste(updates, collapse = ", "), " WHERE id = ?")
  dbExecute(con, query, params)
}
```

**Step 5: Run test to verify it passes**

Run: `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-db.R')"`
Expected: PASS

**Step 6: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat(db): add excluded_paper_ids column to notebooks table"
```

---

## Task 2: Add delete_abstract Function

**Files:**
- Modify: `R/db.R`
- Test: `tests/testthat/test-db.R`

**Step 1: Write the failing test**

Add to `tests/testthat/test-db.R`:

```r
test_that("delete_abstract removes paper and its chunks", {
  con <- init_db(":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  create_notebook(con, "test-nb", "Test", "search")

  # Create an abstract
  abstract_id <- create_abstract(
    con, "test-nb", "W12345", "Test Paper", list("Author"),
    "This is the abstract text.", 2024, "Nature", NULL
  )

  # Create a chunk for it
  create_chunk(con, abstract_id, "abstract", 0, "This is the abstract text.")

  # Verify they exist
  abstracts <- list_abstracts(con, "test-nb")
  expect_equal(nrow(abstracts), 1)

  chunks <- dbGetQuery(con, "SELECT * FROM chunks WHERE source_id = ?", list(abstract_id))
  expect_equal(nrow(chunks), 1)

  # Delete the abstract
  delete_abstract(con, abstract_id)

  # Verify both are gone
  abstracts_after <- list_abstracts(con, "test-nb")
  expect_equal(nrow(abstracts_after), 0)

  chunks_after <- dbGetQuery(con, "SELECT * FROM chunks WHERE source_id = ?", list(abstract_id))
  expect_equal(nrow(chunks_after), 0)
})
```

**Step 2: Run test to verify it fails**

Expected: FAIL - function doesn't exist

**Step 3: Implement delete_abstract function**

Add to `R/db.R` (after `create_abstract` function):

```r
#' Delete an abstract and its chunks
#' @param con DuckDB connection
#' @param id Abstract ID
delete_abstract <- function(con, id) {
  # Delete chunks first (foreign key-like behavior)
  dbExecute(con, "DELETE FROM chunks WHERE source_id = ?", list(id))
  # Delete the abstract
  dbExecute(con, "DELETE FROM abstracts WHERE id = ?", list(id))
}
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add R/db.R tests/testthat/test-db.R
git commit -m "feat(db): add delete_abstract function"
```

---

## Task 3: Remove Auto-Embedding from Refresh

**Files:**
- Modify: `R/mod_search_notebook.R:682-760`

**Step 1: Find the embedding code in refresh handler**

The embedding code is in the `observeEvent(input$refresh_search, ...)` handler, starting around line 682. It includes:
- Ragnar indexing (lines 690-729)
- Legacy embedding fallback (lines 731-760)

**Step 2: Comment out or remove embedding code**

Replace lines 682-760 (the entire embedding section) with a comment:

```r
        # NOTE: Embedding is now deferred - user must click "Embed Papers" button
        # Old auto-embedding code removed (2026-02-06)

        incProgress(1.0, detail = "Done")
```

**Step 3: Manual test**

1. Start app
2. Create/open search notebook
3. Click Refresh
4. Verify papers appear but no embedding happens (check console for ragnar messages)

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "refactor(search): remove auto-embedding from refresh"
```

---

## Task 4: Add Keyword Panel UI

**Files:**
- Modify: `R/mod_search_notebook.R:58-69`

**Step 1: Locate the right column card**

The right column card starts around line 58-69 with the "Abstract Details" header.

**Step 2: Add keyword panel above Abstract Details**

Replace the right column card (lines 58-69) with a layout that includes the keyword panel:

```r
      # Right: Keyword panel + Abstract detail view
      div(
        # Keyword filter panel
        card(
          card_header("Keywords"),
          card_body(
            style = "max-height: 200px; overflow-y: auto;",
            uiOutput(ns("keyword_panel"))
          ),
          card_footer(
            class = "d-flex flex-column gap-2",
            uiOutput(ns("embed_button")),
            uiOutput(ns("exclusion_info"))
          )
        ),
        # Abstract detail view
        card(
          class = "mt-2",
          card_header(
            class = "d-flex justify-content-between align-items-center",
            span("Abstract Details"),
            uiOutput(ns("detail_actions"))
          ),
          card_body(
            style = "height: 350px; overflow-y: auto;",
            uiOutput(ns("abstract_detail"))
          )
        )
      )
```

**Step 3: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(ui): add keyword panel layout above abstract details"
```

---

## Task 5: Implement Keyword Panel Rendering

**Files:**
- Modify: `R/mod_search_notebook.R` (server section)

**Step 1: Add reactive for aggregated keywords**

Add after `filtered_papers` reactive (around line 210):

```r
    # Aggregate keywords from all papers
    all_keywords <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(data.frame(keyword = character(), count = integer()))

      # Parse keywords from each paper and count
      keyword_list <- lapply(seq_len(nrow(papers)), function(i) {
        kw <- papers$keywords[i]
        if (is.na(kw) || is.null(kw) || nchar(kw) == 0) return(character())
        tryCatch({
          jsonlite::fromJSON(kw)
        }, error = function(e) character())
      })

      all_kw <- unlist(keyword_list)
      if (length(all_kw) == 0) return(data.frame(keyword = character(), count = integer()))

      # Count and sort
      kw_table <- table(all_kw)
      data.frame(
        keyword = names(kw_table),
        count = as.integer(kw_table),
        stringsAsFactors = FALSE
      ) |>
        dplyr::arrange(dplyr::desc(count))
    })
```

**Step 2: Add keyword panel renderUI**

```r
    # Keyword panel
    output$keyword_panel <- renderUI({
      keywords <- all_keywords()
      papers <- papers_data()

      if (nrow(papers) == 0) {
        return(div(class = "text-muted text-center py-2", "No papers loaded"))
      }

      if (nrow(keywords) == 0) {
        return(div(class = "text-muted text-center py-2", "No keywords available"))
      }

      # Limit to top 30 keywords
      keywords <- head(keywords, 30)

      div(
        div(class = "mb-2 text-muted small",
            paste(nrow(papers), "papers")),
        div(
          class = "d-flex flex-wrap gap-1",
          lapply(seq_len(nrow(keywords)), function(i) {
            kw <- keywords[i, ]
            actionLink(
              ns(paste0("kw_", gsub("[^a-zA-Z0-9]", "_", kw$keyword))),
              span(
                class = "badge bg-secondary",
                style = "cursor: pointer;",
                paste0(kw$keyword, " (", kw$count, ")")
              ),
              title = paste("Click to remove", kw$count, "papers")
            )
          })
        )
      )
    })
```

**Step 3: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(ui): implement keyword panel rendering with counts"
```

---

## Task 6: Implement Keyword Click-to-Delete

**Files:**
- Modify: `R/mod_search_notebook.R`

**Step 1: Add observer for keyword clicks**

Add after the keyword panel renderUI:

```r
    # Handle keyword clicks - show confirmation then delete
    observe({
      keywords <- all_keywords()
      if (nrow(keywords) == 0) return()

      lapply(seq_len(min(nrow(keywords), 30)), function(i) {
        kw <- keywords[i, ]
        input_id <- paste0("kw_", gsub("[^a-zA-Z0-9]", "_", kw$keyword))

        observeEvent(input[[input_id]], {
          showModal(modalDialog(
            title = "Delete Papers",
            paste0("Delete ", kw$count, " papers tagged '", kw$keyword, "'?"),
            footer = tagList(
              modalButton("Cancel"),
              actionButton(ns(paste0("confirm_delete_kw_", i)), "Delete",
                          class = "btn-danger")
            )
          ))
        }, ignoreInit = TRUE)

        observeEvent(input[[paste0("confirm_delete_kw_", i)]], {
          removeModal()

          # Find papers with this keyword
          papers <- papers_data()
          papers_to_delete <- character()

          for (j in seq_len(nrow(papers))) {
            paper_kw <- tryCatch({
              jsonlite::fromJSON(papers$keywords[j])
            }, error = function(e) character())

            if (kw$keyword %in% paper_kw) {
              papers_to_delete <- c(papers_to_delete, papers$paper_id[j])
            }
          }

          # Add to exclusion list
          nb <- get_notebook(con(), notebook_id())
          existing_excluded <- tryCatch({
            if (!is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
              jsonlite::fromJSON(nb$excluded_paper_ids)
            } else {
              character()
            }
          }, error = function(e) character())

          new_excluded <- unique(c(existing_excluded, papers_to_delete))
          update_notebook(con(), notebook_id(), excluded_paper_ids = new_excluded)

          # Delete from database
          for (paper_id in papers_to_delete) {
            abstract_row <- dbGetQuery(con(),
              "SELECT id FROM abstracts WHERE notebook_id = ? AND paper_id = ?",
              list(notebook_id(), paper_id))
            if (nrow(abstract_row) > 0) {
              delete_abstract(con(), abstract_row$id[1])
            }
          }

          # Trigger refresh
          paper_refresh(paper_refresh() + 1)

          showNotification(
            paste("Deleted", length(papers_to_delete), "papers"),
            type = "message"
          )
        }, ignoreInit = TRUE)
      })
    })
```

**Step 2: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): implement keyword click-to-delete with confirmation"
```

---

## Task 7: Add X Button to Paper List Items

**Files:**
- Modify: `R/mod_search_notebook.R:228-280`

**Step 1: Find paper list item rendering**

The paper list items are rendered around lines 228-280 in the `output$paper_list` renderUI.

**Step 2: Add X button to each paper item**

Modify the paper item div to include a delete button. Update the div structure (around line 250-280):

```r
        div(
          class = paste("border-bottom py-2 position-relative", if (is_viewed) "bg-light"),
          # Delete button (top-right)
          actionLink(
            ns(paste0("delete_", paper$id)),
            icon("xmark", class = "text-muted"),
            class = "position-absolute",
            style = "top: 4px; right: 4px; cursor: pointer;",
            title = "Remove paper"
          ),
          div(
            class = "d-flex align-items-start gap-2 pe-4",
            checkboxInput(ns(checkbox_id), label = NULL, width = "25px"),
            # ... rest of paper content unchanged ...
          )
        )
```

**Step 3: Add observer for paper delete clicks**

```r
    # Handle individual paper delete
    observe({
      papers <- filtered_papers()
      if (nrow(papers) == 0) return()

      lapply(seq_len(nrow(papers)), function(i) {
        paper <- papers[i, ]

        observeEvent(input[[paste0("delete_", paper$id)]], {
          # Add to exclusion list
          nb <- get_notebook(con(), notebook_id())
          existing_excluded <- tryCatch({
            if (!is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
              jsonlite::fromJSON(nb$excluded_paper_ids)
            } else {
              character()
            }
          }, error = function(e) character())

          new_excluded <- unique(c(existing_excluded, paper$paper_id))
          update_notebook(con(), notebook_id(), excluded_paper_ids = new_excluded)

          # Delete from database
          delete_abstract(con(), paper$id)

          # Trigger refresh
          paper_refresh(paper_refresh() + 1)
        }, ignoreInit = TRUE, once = TRUE)
      })
    })
```

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(ui): add X button to delete individual papers"
```

---

## Task 8: Filter Excluded Papers on Refresh

**Files:**
- Modify: `R/mod_search_notebook.R:660-680`

**Step 1: Find where papers are saved in refresh handler**

The paper saving loop is around lines 660-680.

**Step 2: Add exclusion filtering before saving**

Before the `for (paper in papers)` loop, add:

```r
        # Filter out excluded papers
        nb <- get_notebook(con(), nb_id)
        excluded_ids <- tryCatch({
          if (!is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
            jsonlite::fromJSON(nb$excluded_paper_ids)
          } else {
            character()
          }
        }, error = function(e) character())

        if (length(excluded_ids) > 0) {
          papers <- Filter(function(p) !(p$paper_id %in% excluded_ids), papers)
          if (length(papers) == 0) {
            showNotification("All papers were previously excluded", type = "warning")
            return()
          }
        }
```

**Step 3: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): filter excluded papers on refresh"
```

---

## Task 9: Implement Embed Button

**Files:**
- Modify: `R/mod_search_notebook.R`

**Step 1: Add reactive to check embedding status**

```r
    # Check if papers need embedding
    papers_need_embedding <- reactive({
      papers <- papers_data()
      if (nrow(papers) == 0) return(0)

      # Check chunks table for papers without embeddings
      unembedded <- dbGetQuery(con(), "
        SELECT COUNT(DISTINCT a.id) as count
        FROM abstracts a
        LEFT JOIN chunks c ON a.id = c.source_id
        WHERE a.notebook_id = ?
          AND a.abstract IS NOT NULL
          AND LENGTH(a.abstract) > 0
          AND (c.embedding IS NULL OR c.id IS NULL)
      ", list(notebook_id()))

      unembedded$count[1]
    })
```

**Step 2: Add embed button renderUI**

```r
    # Embed button
    output$embed_button <- renderUI({
      papers <- papers_data()
      need_embed <- papers_need_embedding()

      if (nrow(papers) == 0) {
        return(
          actionButton(ns("embed_papers"), "No Papers to Embed",
                      class = "btn-secondary w-100", disabled = TRUE)
        )
      }

      if (need_embed == 0) {
        return(
          actionButton(ns("embed_papers"),
                      HTML("&#10003; All Papers Embedded"),
                      class = "btn-success w-100", disabled = TRUE)
        )
      }

      actionButton(ns("embed_papers"),
                  HTML(paste0("&#129504; Embed ", need_embed, " Papers")),
                  class = "btn-primary w-100",
                  icon = NULL)
    })
```

**Step 3: Add embed button click handler**

Copy the embedding logic from the old refresh handler (lines 682-760 that we commented out) into a new observeEvent:

```r
    # Handle embed button click
    observeEvent(input$embed_papers, {
      nb_id <- notebook_id()
      req(nb_id)

      withProgress(message = "Embedding papers...", value = 0, {
        cfg <- get_config()
        api_key_or <- get_setting(cfg, "openrouter", "api_key")
        embed_model <- get_setting(cfg, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

        if (is.null(api_key_or) || nchar(api_key_or) == 0) {
          showNotification("OpenRouter API key required for embedding", type = "error")
          return()
        }

        incProgress(0.2, detail = "Building search index")

        ragnar_indexed <- FALSE

        # Index with ragnar if available
        if (ragnar_available()) {
          tryCatch({
            abstracts_to_index <- dbGetQuery(con(), "
              SELECT a.id, a.title, a.abstract
              FROM abstracts a
              WHERE a.notebook_id = ? AND a.abstract IS NOT NULL AND LENGTH(a.abstract) > 0
            ", list(nb_id))

            if (nrow(abstracts_to_index) > 0) {
              ragnar_store_path <- file.path(
                dirname(get_setting(cfg, "app", "db_path") %||% "data/notebooks.duckdb"),
                "serapeum.ragnar.duckdb")
              store <- get_ragnar_store(ragnar_store_path,
                                        openrouter_api_key = api_key_or,
                                        embed_model = embed_model)

              for (i in seq_len(nrow(abstracts_to_index))) {
                abs_row <- abstracts_to_index[i, ]
                abs_chunks <- data.frame(
                  content = abs_row$abstract,
                  page_number = 1L,
                  chunk_index = 0L,
                  context = abs_row$title,
                  origin = paste0("abstract:", abs_row$id),
                  stringsAsFactors = FALSE
                )
                insert_chunks_to_ragnar(store, abs_chunks, abs_row$id, "abstract")
                incProgress(0.6 * i / nrow(abstracts_to_index))
              }

              build_ragnar_index(store)
              ragnar_indexed <- TRUE
            }
          }, error = function(e) {
            message("Ragnar indexing error: ", e$message)
          })
        }

        # Fallback to legacy embedding if ragnar failed
        if (!ragnar_indexed) {
          incProgress(0.7, detail = "Generating embeddings")
          chunks <- dbGetQuery(con(), "
            SELECT c.* FROM chunks c
            JOIN abstracts a ON c.source_id = a.id
            WHERE a.notebook_id = ? AND c.embedding IS NULL
          ", list(nb_id))

          if (nrow(chunks) > 0) {
            for (i in seq_len(nrow(chunks))) {
              embedding <- get_embedding(chunks$content[i], api_key_or, embed_model)
              if (!is.null(embedding)) {
                embedding_str <- paste(embedding, collapse = ",")
                dbExecute(con(), "UPDATE chunks SET embedding = ? WHERE id = ?",
                         list(embedding_str, chunks$id[i]))
              }
              incProgress(0.3 * i / nrow(chunks))
            }
          }
        }

        incProgress(1.0, detail = "Done")
      })

      showNotification("Embedding complete!", type = "message")
      paper_refresh(paper_refresh() + 1)
    })
```

**Step 4: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(search): add Embed Papers button with deferred embedding"
```

---

## Task 10: Add Exclusion Info Display

**Files:**
- Modify: `R/mod_search_notebook.R`

**Step 1: Add exclusion info renderUI**

```r
    # Exclusion info
    output$exclusion_info <- renderUI({
      nb <- get_notebook(con(), notebook_id())
      excluded <- tryCatch({
        if (!is.na(nb$excluded_paper_ids) && nchar(nb$excluded_paper_ids) > 0) {
          jsonlite::fromJSON(nb$excluded_paper_ids)
        } else {
          character()
        }
      }, error = function(e) character())

      if (length(excluded) == 0) return(NULL)

      div(
        class = "text-muted small text-center",
        paste(length(excluded), "papers excluded"),
        actionLink(ns("clear_exclusions"), "(clear)", class = "ms-1")
      )
    })
```

**Step 2: Add clear exclusions handler**

```r
    # Clear exclusions
    observeEvent(input$clear_exclusions, {
      showModal(modalDialog(
        title = "Clear Exclusions",
        "Clear all exclusions? Excluded papers may reappear on next refresh.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_clear_exclusions"), "Clear", class = "btn-warning")
        )
      ))
    })

    observeEvent(input$confirm_clear_exclusions, {
      removeModal()
      update_notebook(con(), notebook_id(), excluded_paper_ids = character())
      paper_refresh(paper_refresh() + 1)
      showNotification("Exclusions cleared", type = "message")
    })
```

**Step 3: Commit**

```bash
git add R/mod_search_notebook.R
git commit -m "feat(ui): add exclusion count display with clear option"
```

---

## Task 11: Final Integration Test

**Step 1: Manual test workflow**

1. Delete `data/notebooks.duckdb` to start fresh
2. Start app: `shiny::runApp()`
3. Create new search notebook
4. Enter query, click Refresh
5. Verify:
   - Papers appear in list
   - Keywords appear in tag cloud with counts
   - "Embed N Papers" button is enabled
   - No embedding happened yet (check console)
6. Click a keyword → confirm delete → verify papers removed
7. Click X on a paper → verify paper removed
8. Click "Embed Papers" → verify embedding runs
9. Button changes to "All Papers Embedded"
10. Verify Chat works after embedding
11. Click Refresh again → verify excluded papers don't return

**Step 2: Commit any fixes**

```bash
git add -A
git commit -m "test: verify keyword filter and deferred embedding integration"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add excluded_paper_ids column | `R/db.R`, `tests/testthat/test-db.R` |
| 2 | Add delete_abstract function | `R/db.R`, `tests/testthat/test-db.R` |
| 3 | Remove auto-embedding from refresh | `R/mod_search_notebook.R` |
| 4 | Add keyword panel UI layout | `R/mod_search_notebook.R` |
| 5 | Implement keyword panel rendering | `R/mod_search_notebook.R` |
| 6 | Implement keyword click-to-delete | `R/mod_search_notebook.R` |
| 7 | Add X button to paper list items | `R/mod_search_notebook.R` |
| 8 | Filter excluded papers on refresh | `R/mod_search_notebook.R` |
| 9 | Implement embed button | `R/mod_search_notebook.R` |
| 10 | Add exclusion info display | `R/mod_search_notebook.R` |
| 11 | Final integration test | - |

**Estimated commits:** 11
**Key patterns:** JSON storage for exclusions, reactive UI updates, confirmation modals, deferred actions
