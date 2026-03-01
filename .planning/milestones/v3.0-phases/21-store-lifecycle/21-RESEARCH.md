# Phase 21: Store Lifecycle - Research

**Researched:** 2026-02-16
**Domain:** File lifecycle management, DuckDB file operations, Shiny UI feedback patterns
**Confidence:** HIGH

## Summary

Phase 21 implements automatic ragnar store lifecycle management: lazy creation on first embedding, silent deletion on notebook removal, corruption detection with rebuild capability, and orphan cleanup. The core technical challenge is coordinating file operations (DuckDB stores) with database transactions (notebook metadata) while providing appropriate user feedback.

Research confirms R's `file.remove()` and `unlink()` provide safe file deletion with detailed error information, DuckDB has built-in checksums for corruption detection, and Shiny offers both `showNotification()` (toast) and `showModal()` (modal) for user feedback. The existing Phase 18 progress infrastructure (`withProgress`/`incProgress`) can be reused for rebuild progress tracking.

**Primary recommendation:** Use lazy store creation with subtle inline indicator, synchronous deletion with tryCatch fallback, DuckDB connection errors as corruption signals, and modal + progress bar for rebuild flows.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Store creation:**
- Lazy creation: store is created on first embedding operation (not on notebook creation or PDF upload)
- Show brief indicator during first-time creation (e.g., "Setting up index...")
- If store creation fails (disk full, permissions), block the embedding action with an error — do not proceed without a store

**Store deletion:**
- When notebook is deleted, store is cleaned up silently — delete confirmation does not mention the store/index
- Deletion timing is Claude's discretion (sync vs deferred) — optimize for not impacting UI performance
- If store deletion fails (file locked), notebook deletion still proceeds — orphaned store cleaned up later
- No automatic orphan cleanup on startup
- Manual orphan cleanup button in app settings panel

**Corruption detection and rebuild:**
- Proactive integrity check when notebook is opened — warn if store is corrupted
- Also detect corruption reactively when search/RAG operations fail
- "Rebuild index" action appears only in error context (not always-visible in menus)
- Notebook remains fully usable during rebuild — search/RAG disabled, everything else works normally
- Rebuild shows progress bar with document count (e.g., "Re-embedding 12/45 documents...")

**Error communication:**
- Transient store errors (single query fails): toast notification
- Persistent store errors (corruption, missing files): modal warning with rebuild option
- Never block content ingestion (PDF upload, abstract embedding) due to store errors — save to DB regardless, notify user that search is unavailable and show how to fix
- Orphan cleanup control lives in app settings

### Claude's Discretion

- Sync vs deferred deletion timing (optimize for performance)
- Integrity check implementation details (what constitutes "corruption")
- Toast/modal styling consistent with existing app patterns
- Progress bar implementation for rebuild

### Specific Ideas from Discussion

- Store creation indicator should be subtle and brief — not a modal or blocking UI
- Orphan cleanup in settings is a simple button, not a dedicated maintenance section
- Error → rebuild flow: user sees modal with explanation + "Rebuild" button, clicks it, modal closes, progress bar appears, notebook remains usable

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

## Standard Stack

### Core File Operations
| Function | Purpose | Why Standard |
|----------|---------|--------------|
| `file.exists()` | Check file existence | Base R, returns FALSE for missing files without error |
| `file.remove()` | Delete files | Base R, returns TRUE/FALSE per file, gives detailed error info |
| `unlink()` | Delete files/directories | Base R, `recursive=TRUE` for directories, `force=TRUE` for read-only |
| `file.path()` | Construct paths | Base R, cross-platform path construction |

### DuckDB Operations
| Function | Purpose | Why Standard |
|----------|---------|--------------|
| `DBI::dbConnect()` | Open connection | Used throughout codebase, automatic error on bad file |
| `DBI::dbDisconnect()` | Close connection | Existing pattern, `shutdown=TRUE` for clean close |
| `tryCatch()` | Error handling | R standard, used for corruption detection |

### Shiny UI Feedback
| Function | Purpose | Why Standard |
|----------|---------|--------------|
| `showNotification()` | Toast notifications | Built-in Shiny, used in mod_document_notebook.R |
| `showModal()` + `modalDialog()` | Modal dialogs | Built-in Shiny, used in mod_search_notebook.R |
| `withProgress()` + `incProgress()` | Progress bars | Built-in Shiny, used in mod_citation_network.R (Phase 18) |

### Installation
No new dependencies — all functions are base R or already-installed packages (DBI, shiny).

## Architecture Patterns

### Recommended Project Structure
```
R/
├── _ragnar.R              # Add lifecycle functions here
├── db.R                   # Modify delete_notebook() here
├── mod_settings.R         # Add orphan cleanup UI here
└── mod_document_notebook.R  # Add store creation + rebuild here
```

### Pattern 1: Lazy Store Creation on First Embedding
**What:** Create ragnar store only when first chunk needs to be inserted, not during notebook creation or PDF upload
**When to use:** Every embedding operation checks if store exists, creates if missing
**Example:**
```r
# In mod_document_notebook.R or mod_search_notebook.R
embed_content <- function(notebook_id, content, session) {
  store_path <- get_notebook_ragnar_path(notebook_id)

  # Lazy creation check
  if (!file.exists(store_path)) {
    showNotification("Setting up search index...",
                     type = "message", duration = 3)

    tryCatch({
      store <- get_ragnar_store(
        path = store_path,
        openrouter_api_key = api_key,
        embed_model = embed_model
      )
    }, error = function(e) {
      # Store creation failed (disk full, permissions)
      showNotification(
        paste("Failed to create search index:", e$message,
              "- Content saved but search unavailable"),
        type = "error",
        duration = NULL  # Persistent error
      )
      return(NULL)
    })
  }

  # Proceed with embedding...
}
```

### Pattern 2: Silent Deletion with Graceful Fallback
**What:** Delete store file when notebook deleted, but don't fail if file locked or missing
**When to use:** In `delete_notebook()` function in db.R
**Example:**
```r
# In R/db.R
delete_notebook <- function(con, id) {
  # Delete DB records first (existing code)
  dbExecute(con, "DELETE FROM chunks WHERE source_id IN (...)")
  # ... existing deletion code ...

  # Delete ragnar store file (new code)
  store_path <- get_notebook_ragnar_path(id)

  tryCatch({
    if (file.exists(store_path)) {
      file.remove(store_path)
    }
  }, error = function(e) {
    # File locked or permission denied - notebook deletion still succeeds
    # Orphaned store will be cleaned up via manual cleanup button
    message("[store_lifecycle] Failed to delete store ", store_path,
            ": ", e$message, " (orphaned, can be cleaned later)")
  })
}
```

### Pattern 3: Corruption Detection via Connection Failure
**What:** Detect corrupted stores by catching DuckDB connection errors
**When to use:** When opening notebook or performing search/RAG operations
**Example:**
```r
# In _ragnar.R or module server function
check_store_integrity <- function(store_path, session = NULL) {
  if (!file.exists(store_path)) {
    return(list(ok = FALSE, missing = TRUE))
  }

  result <- tryCatch({
    # Try to connect - DuckDB validates checksums on connect
    store <- ragnar::ragnar_store_connect(store_path)
    DBI::dbDisconnect(store, shutdown = TRUE)
    list(ok = TRUE)
  }, error = function(e) {
    # Connection failed - likely corruption
    list(ok = FALSE, error = e$message)
  })

  result
}
```

### Pattern 4: Modal + Progress Bar for Rebuild
**What:** Show modal with explanation and "Rebuild" button, then progress bar during rebuild
**When to use:** When corruption detected (proactive or reactive)
**Example:**
```r
# In module server when corruption detected
show_rebuild_modal <- function(session, notebook_id) {
  showModal(modalDialog(
    title = "Search Index Needs Rebuild",
    "The search index for this notebook appears to be corrupted.
     This can happen after crashes or disk errors. Rebuilding will
     re-embed all documents and abstracts.",
    footer = tagList(
      actionButton(ns("rebuild_index"), "Rebuild Index",
                   class = "btn-primary"),
      modalButton("Cancel")
    ),
    easyClose = FALSE
  ))
}

# When rebuild button clicked
observeEvent(input$rebuild_index, {
  removeModal()

  # Get all content IDs for this notebook
  documents <- list_documents(con, notebook_id)
  abstracts <- list_abstracts(con, notebook_id)
  total <- nrow(documents) + nrow(abstracts)

  # Delete corrupted store
  store_path <- get_notebook_ragnar_path(notebook_id)
  file.remove(store_path)

  # Rebuild with progress
  withProgress(message = "Rebuilding search index...", value = 0, {
    count <- 0

    # Re-embed documents
    for (i in seq_len(nrow(documents))) {
      # ... embedding logic ...
      count <- count + 1
      incProgress(1/total,
                  detail = paste("Re-embedding", count, "/", total, "items"))
    }

    # Re-embed abstracts
    for (i in seq_len(nrow(abstracts))) {
      # ... embedding logic ...
      count <- count + 1
      incProgress(1/total,
                  detail = paste("Re-embedding", count, "/", total, "items"))
    }
  })

  showNotification("Search index rebuilt successfully",
                   type = "message")
})
```

### Pattern 5: Orphan Cleanup in Settings
**What:** Manual button in settings to find and delete orphaned ragnar stores
**When to use:** User-initiated cleanup, not automatic
**Example:**
```r
# In R/mod_settings.R
ui <- function(id) {
  # ... existing settings UI ...

  card(
    card_header("Maintenance"),
    card_body(
      p("Remove orphaned search index files (left over from failed deletions):"),
      actionButton(ns("cleanup_orphans"), "Clean Up Orphaned Stores"),
      textOutput(ns("cleanup_status"))
    )
  )
}

server <- function(id, con) {
  # ... existing server code ...

  observeEvent(input$cleanup_orphans, {
    # Get all notebook IDs from database
    notebooks <- list_notebooks(con)
    valid_ids <- notebooks$id

    # Find all ragnar store files
    ragnar_dir <- file.path("data", "ragnar")
    if (!dir.exists(ragnar_dir)) {
      output$cleanup_status <- renderText("No stores found")
      return()
    }

    store_files <- list.files(ragnar_dir, pattern = "\\.duckdb$",
                               full.names = TRUE)

    # Identify orphans (store file but no matching notebook)
    orphans <- character()
    for (file_path in store_files) {
      # Extract notebook_id from filename (e.g., "abc-123.duckdb" -> "abc-123")
      file_name <- basename(file_path)
      notebook_id <- sub("\\.duckdb$", "", file_name)

      if (!notebook_id %in% valid_ids) {
        orphans <- c(orphans, file_path)
      }
    }

    if (length(orphans) == 0) {
      output$cleanup_status <- renderText("No orphaned stores found")
      return()
    }

    # Delete orphans
    removed <- vapply(orphans, function(f) {
      tryCatch({
        file.remove(f)
        TRUE
      }, error = function(e) FALSE)
    }, logical(1))

    output$cleanup_status <- renderText(
      paste("Cleaned up", sum(removed), "of", length(orphans),
            "orphaned stores")
    )
  })
}
```

### Anti-Patterns to Avoid

**Blocking UI during store creation:** Don't use modal dialogs or synchronous waits — user should see brief toast and operation continues in background

**Failing notebook deletion on store deletion error:** Notebook deletion must succeed even if store file is locked — orphans are cleaned up later via manual cleanup

**Automatic orphan cleanup on startup:** Don't scan and delete orphans on app startup — this could delete stores for notebooks that are still valid but slow to load

**Always-visible rebuild button:** Rebuild action should only appear when corruption is detected, not as a permanent UI element

**Silent corruption:** Don't ignore connection errors — surface them as modals with rebuild option

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File existence checking | Custom file system scanning | `file.exists()` | Handles edge cases (symlinks, permissions, race conditions) |
| File deletion | Custom unlink wrappers | `file.remove()` with `tryCatch()` | Returns detailed success/failure per file |
| Progress tracking | Custom progress widgets | `withProgress()` + `incProgress()` | Integrated with Shiny reactivity, handles edge cases |
| Modal dialogs | Custom Bootstrap modals | `showModal()` + `modalDialog()` | Manages focus, escape key, backdrop clicks automatically |
| Toast notifications | Custom notification system | `showNotification()` | Positioned, stacked, auto-dismissed, type styling built-in |
| DuckDB corruption detection | Custom checksum verification | `tryCatch(ragnar_store_connect())` | DuckDB validates checksums on connect, reports errors clearly |

**Key insight:** File operations and UI feedback have subtle edge cases (race conditions, permissions, focus management, reactivity). Use built-in functions that handle these cases.

## Common Pitfalls

### Pitfall 1: Silent File Deletion Failures
**What goes wrong:** Using `file.remove()` without checking return value or using `unlink()` with `force=FALSE` silently fails on read-only files
**Why it happens:** `file.remove()` returns FALSE on failure, `unlink()` returns 0 on success but doesn't error by default
**How to avoid:** Wrap in `tryCatch()` to catch permission errors, check return value, log failures
**Warning signs:** Orphaned stores accumulate, deletion "succeeds" but files remain

**Example:**
```r
# BAD: Silent failure
file.remove(store_path)  # Returns FALSE if locked, but code continues

# GOOD: Explicit error handling
tryCatch({
  result <- file.remove(store_path)
  if (!result) {
    warning("Failed to delete ", store_path)
  }
}, error = function(e) {
  message("[cleanup] ", e$message)
})
```

### Pitfall 2: Checking Corruption Only on Store Creation
**What goes wrong:** Store can become corrupted AFTER creation (crash, disk error, partial write)
**Why it happens:** Assuming `file.exists()` means "store is valid"
**How to avoid:** Always wrap `ragnar_store_connect()` in `tryCatch()`, treat connection errors as corruption signals
**Warning signs:** Users report "search not working" but store file exists

**Example:**
```r
# BAD: Assumes existing store is valid
if (file.exists(store_path)) {
  store <- ragnar_store_connect(store_path)  # Can error if corrupted
}

# GOOD: Detects corruption via connection error
if (file.exists(store_path)) {
  result <- tryCatch({
    ragnar_store_connect(store_path)
  }, error = function(e) {
    # Corruption detected
    show_rebuild_modal(session, notebook_id)
    NULL
  })
}
```

### Pitfall 3: Synchronous Rebuild Blocking UI
**What goes wrong:** Re-embedding 50+ documents takes 30+ seconds, app freezes
**Why it happens:** Running embedding loop in main thread without progress feedback
**How to avoid:** Use `withProgress()` + `incProgress()` for visual feedback, consider async rebuild for large notebooks (Phase 18 mirai pattern)
**Warning signs:** App becomes unresponsive during rebuild, users can't cancel

**Example:**
```r
# BAD: Blocks UI for 30+ seconds
for (doc in documents) {
  embed_document(doc)  # Slow operation
}

# GOOD: Shows progress, UI stays responsive
withProgress(message = "Rebuilding...", value = 0, {
  for (i in seq_along(documents)) {
    embed_document(documents[[i]])
    incProgress(1/length(documents),
                detail = paste(i, "/", length(documents)))
  }
})
```

### Pitfall 4: Not Coordinating DB and File Operations
**What goes wrong:** DB transaction rolls back but store file already deleted (or vice versa)
**Why it happens:** File operations are not transactional, can't be rolled back
**How to avoid:** Delete DB records first, THEN delete file — file deletion failure is recoverable (orphan cleanup), DB deletion failure would leave inconsistent state
**Warning signs:** Notebooks exist in DB but no store file, or store files with no notebook

**Example:**
```r
# BAD: File deleted first, then DB fails
file.remove(store_path)
dbExecute(con, "DELETE FROM notebooks WHERE id = ?", list(id))  # Error here leaves orphaned DB records

# GOOD: DB first, file second
dbExecute(con, "DELETE FROM notebooks WHERE id = ?", list(id))
tryCatch({
  file.remove(store_path)
}, error = function(e) {
  # File deletion failed, but DB is clean — orphan will be cleaned later
})
```

### Pitfall 5: Assuming Temp Directory is Writable
**What goes wrong:** Store creation fails with "permission denied" on restricted systems
**Why it happens:** `data/ragnar/` directory doesn't exist or has wrong permissions
**How to avoid:** Phase 20 creates `data/ragnar/` eagerly on startup with error handling, verify directory exists before store creation
**Warning signs:** Store creation errors on first embed, "directory does not exist" messages

**Example:**
```r
# GOOD: Verify directory exists (Phase 20 already does this on startup)
ragnar_dir <- file.path("data", "ragnar")
if (!dir.exists(ragnar_dir)) {
  dir.create(ragnar_dir, recursive = TRUE, showWarnings = FALSE)
}

# Then create store
store <- get_ragnar_store(path = store_path, ...)
```

## Code Examples

Verified patterns from official sources and existing codebase:

### Safe File Deletion
```r
# Source: https://sparkbyexamples.com/r-programming/delete-file-or-directory-in-r/
# Pattern: Check existence, delete with error handling
delete_store_file <- function(store_path) {
  if (!file.exists(store_path)) {
    return(TRUE)  # Already gone
  }

  tryCatch({
    result <- file.remove(store_path)
    if (!result) {
      warning("file.remove() returned FALSE for ", store_path)
    }
    result
  }, error = function(e) {
    message("[delete_store] Failed: ", e$message)
    FALSE
  })
}
```

### Toast Notification for Transient Errors
```r
# Source: https://mastering-shiny.org/action-feedback.html
# Pattern: Existing usage in R/mod_document_notebook.R:203
showNotification(
  paste("Search index error:", error_message),
  type = "warning",
  duration = 5  # Auto-dismiss after 5 seconds
)
```

### Modal for Persistent Errors
```r
# Source: https://shiny.posit.co/r/articles/build/modal-dialogs/
# Pattern: Similar to mod_search_notebook.R usage
showModal(modalDialog(
  title = "Search Index Corrupted",
  "The search index appears to be corrupted and needs rebuilding.",
  footer = tagList(
    actionButton(ns("rebuild"), "Rebuild Now"),
    modalButton("Later")
  ),
  easyClose = FALSE  # Force user choice
))
```

### Progress Bar Pattern
```r
# Source: https://shiny.posit.co/r/articles/build/progress/
# Pattern: Existing usage in R/mod_citation_network.R (Phase 18)
withProgress(message = "Re-embedding documents...", value = 0, {
  for (i in seq_along(items)) {
    # Process item
    process_item(items[[i]])

    # Update progress
    incProgress(
      1/length(items),
      detail = paste("Item", i, "of", length(items))
    )
  }
})
```

### Corruption Detection
```r
# Source: Existing pattern in R/_ragnar.R with_ragnar_store()
# Pattern: tryCatch on connection, return NULL on error
check_store_health <- function(store_path) {
  tryCatch({
    store <- ragnar::ragnar_store_connect(store_path)
    DBI::dbDisconnect(store, shutdown = TRUE)
    list(healthy = TRUE)
  }, error = function(e) {
    list(healthy = FALSE, error = e$message)
  })
}
```

### Orphan Detection
```r
# Source: Base R file operations
# Pattern: Find files not matching any notebook ID
find_orphaned_stores <- function(con) {
  # Get valid notebook IDs
  notebooks <- dbGetQuery(con, "SELECT id FROM notebooks")
  valid_ids <- notebooks$id

  # Find all store files
  ragnar_dir <- file.path("data", "ragnar")
  if (!dir.exists(ragnar_dir)) return(character(0))

  store_files <- list.files(ragnar_dir, pattern = "\\.duckdb$",
                             full.names = TRUE)

  # Filter to orphans
  orphans <- character()
  for (file_path in store_files) {
    notebook_id <- sub("\\.duckdb$", "", basename(file_path))
    if (!notebook_id %in% valid_ids) {
      orphans <- c(orphans, file_path)
    }
  }

  orphans
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single shared ragnar store | Per-notebook isolated stores | Phase 20 (v3.0) | Simpler lifecycle — delete notebook = delete store |
| Manual store initialization | Lazy creation on first embed | This phase (21) | No setup step, automatic management |
| Silent corruption | Detect and prompt rebuild | This phase (21) | Users can recover from corruption |
| Automatic cleanup | Manual orphan cleanup | User decision (21-CONTEXT) | No startup performance hit |

**Deprecated/outdated:**
- **Shared store path `data/serapeum.ragnar.duckdb`**: Replaced by per-notebook stores `data/ragnar/{notebook_id}.duckdb` (Phase 20)
- **Eager store creation**: Replaced by lazy creation on first embedding (this phase)
- **Manual rebuild via deletion + re-upload**: Replaced by automatic rebuild button (this phase)

## Open Questions

1. **Async rebuild for large notebooks**
   - What we know: Phase 18 established mirai + ExtendedTask pattern for async operations
   - What's unclear: Should rebuild use async pattern or is synchronous withProgress() sufficient?
   - Recommendation: Start with synchronous `withProgress()` (simpler), add async in Phase 22 if users report UI freezes on large notebooks (50+ documents)

2. **Proactive corruption check frequency**
   - What we know: User decision is "check when notebook is opened"
   - What's unclear: Does "opened" mean every time user switches to notebook tab, or only on app startup?
   - Recommendation: Check on notebook module initialization (when tab first clicked), not on every tab switch — cache health status in reactive value

3. **Store version upgrades**
   - What we know: ragnar supports v1 and v2 stores, Phase 20 uses v2 (default)
   - What's unclear: What happens if ragnar v3 is released with new store format?
   - Recommendation: Current approach (delete old store, rebuild with new version) works — no migration needed since rebuild is already implemented

## Sources

### Primary (HIGH confidence)
- Base R file operations documentation: https://stat.ethz.ch/R-manual/R-devel/library/base/html/unlink.html
- Shiny notification documentation: https://mastering-shiny.org/action-feedback.html
- Shiny modal documentation: https://shiny.posit.co/r/articles/build/modal-dialogs/
- Shiny progress bar documentation: https://shiny.posit.co/r/articles/build/progress/
- DuckDB transaction documentation: https://duckdb.org/docs/stable/sql/statements/transactions
- DuckDB data integrity: https://duckdb.org/2025/11/19/encryption-in-duckdb
- ragnar store functions: https://ragnar.tidyverse.org/reference/ragnar_store_create.html

### Secondary (MEDIUM confidence)
- R file deletion patterns: https://sparkbyexamples.com/r-programming/delete-file-or-directory-in-r/
- DuckDB corruption cases: https://github.com/duckdb/duckdb/issues/9667
- Existing codebase patterns: R/_ragnar.R, R/mod_document_notebook.R, R/mod_citation_network.R (Phase 18)

## Metadata

**Confidence breakdown:**
- File operations: HIGH - Well-documented base R functions, clear patterns in existing code
- DuckDB corruption detection: HIGH - Built-in checksums, connection errors signal corruption
- UI feedback patterns: HIGH - Existing usage in codebase (showNotification, showModal, withProgress)
- Lifecycle coordination: MEDIUM - Pattern is clear (DB first, file second) but no existing example in codebase

**Research date:** 2026-02-16
**Valid until:** 30 days (2026-03-18) — ragnar and DuckDB are stable, file operations don't change
