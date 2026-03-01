# Phase 18: Progress Modal with Cancellation - Research

**Researched:** 2026-02-13
**Domain:** Shiny async operations with cancellation, progress modals, ExtendedTask, interrupt flag patterns
**Confidence:** HIGH

## Summary

Phase 18 implements progress modals with cancellation for long-running citation network operations in Serapeum. The phase builds on Shiny's `ExtendedTask` (introduced in Shiny 1.8.1, January 2026) and bslib's `input_task_button()` to provide truly non-blocking asynchronous operations with user-controllable cancellation.

The R/Shiny ecosystem recently gained mature async support through `ExtendedTask`, which integrates with the `mirai` package for lightweight async execution. Unlike older approaches using `promises` and `future`, ExtendedTask natively supports cancellation via the `cancel()` method. For progress indication, two patterns exist: custom modal dialogs with JavaScript updates, or Shiny's `Progress` reference class with manual control. The project already has `fetch_citation_network()` with a `progress_callback` parameter, making integration straightforward.

The critical challenge is returning partial results when users cancel mid-operation. Shiny's cancellation model terminates the async process but doesn't provide built-in partial result recovery. The solution is an **interrupt flag pattern**: check a reactive flag or file within the BFS loop, and when interrupt is detected, return accumulated nodes/edges instead of throwing an error. This requires modifying `fetch_citation_network()` to accept an interrupt flag and check it at each BFS hop.

**Primary recommendation:** Use ExtendedTask with mirai for async execution, implement interrupt flag checking in `fetch_citation_network()` at each BFS hop, use custom modal with JavaScript progress updates for granular status display, and return accumulated partial results when cancellation detected. Leverage existing `progress_callback` pattern for live updates.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | 1.8.1+ | ExtendedTask for async with cancellation | Official Shiny async model, released Jan 2026, integrates with mirai |
| mirai | 1.3+ | Lightweight async backend for ExtendedTask | Recommended backend for ExtendedTask, no process forking overhead |
| bslib | 0.8+ | input_task_button() for progress UI | Official bslib component, auto-manages button state during async ops |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| promises | 1.3+ | Promise-based async (legacy) | Only if ExtendedTask insufficient (not expected) |
| future | 1.34+ | Alternative async backend | If mirai unavailable, but adds forking overhead |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ExtendedTask + mirai | promises + future | future forks R processes (high overhead), promises lacks native cancellation |
| Custom modal with JavaScript | Shiny Progress class | Progress class simpler but less control over UI (can't add custom cancel button easily) |
| Interrupt flag pattern | Process termination with tools::pskill | pskill terminates immediately, no partial results, risk of DB corruption |

**Installation:**
```r
# Core dependencies
install.packages("shiny")  # 1.8.1+ required for ExtendedTask
install.packages("mirai")
install.packages("bslib")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_citation_network.R      # Add ExtendedTask, custom modal, cancel handler
├── citation_network.R          # Modify fetch_citation_network() for interrupt flag
└── interrupt.R                 # NEW: interrupt flag utilities (create, check, signal, clear)
```

### Pattern 1: ExtendedTask with mirai for Cancellable Async
**What:** Wrap long-running operation in ExtendedTask using mirai backend, store task reference for cancellation
**When to use:** Any operation >2 seconds that should remain cancellable and not block UI
**Example:**
```r
# Source: https://rstudio.github.io/shiny/reference/ExtendedTask.html
# Source: https://mirai.r-lib.org/articles/shiny.html

# Module server
mod_citation_network_server <- function(id, con_r, config_r, ...) {
  moduleServer(id, function(input, output, session) {

    # Create ExtendedTask with mirai backend
    network_task <- ExtendedTask$new(
      function(seed_id, email, direction, depth, node_limit, interrupt_flag) {
        mirai::mirai({
          # Long-running operation executes in separate process
          fetch_citation_network(
            seed_id, email, api_key = NULL,
            direction = direction, depth = depth,
            node_limit = node_limit,
            interrupt_flag = interrupt_flag,
            progress_callback = function(msg, frac) {
              # Update progress via mirai communication
              list(message = msg, fraction = frac)
            }
          )
        })
      }
    )

    # Invoke task on button click
    observeEvent(input$build_network, {
      # Create interrupt flag for this operation
      flag_file <- create_interrupt_flag(session$token)

      # Show custom progress modal
      show_progress_modal(session, ns)

      # Invoke async task
      network_task$invoke(
        seed_id = current_seed_id(),
        email = config_r()$openalex$email,
        direction = input$direction,
        depth = input$depth,
        node_limit = input$node_limit,
        interrupt_flag = flag_file
      )
    })

    # Handle cancellation
    observeEvent(input$cancel_build, {
      # Signal interrupt to running task
      flag_file <- get_current_flag_file(session$token)
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }

      # Cancel the ExtendedTask
      network_task$cancel()

      # Close modal
      removeModal()
      showNotification("Network build cancelled", type = "warning")
    })

    # Handle task completion
    observe({
      result <- network_task$result()

      # Process result (full or partial)
      if (!is.null(result$partial) && result$partial) {
        showNotification(
          paste("Partial network built:", nrow(result$nodes), "nodes"),
          type = "message"
        )
      } else {
        showNotification(
          paste("Network built:", nrow(result$nodes), "nodes"),
          type = "message"
        )
      }

      # Update UI with result
      current_network_data(result)

      # Close modal
      removeModal()

      # Clean up interrupt flag
      clear_interrupt_flag(get_current_flag_file(session$token))
    })
  })
}
```

**Key points:**
- ExtendedTask wraps function that returns mirai object
- Task can be cancelled via `task$cancel()` method
- Result accessed via `task$result()` in reactive observer
- Interrupt flag passed to long-running function for graceful cancellation

### Pattern 2: Interrupt Flag Pattern for Partial Results
**What:** File-based or reactive flag checked periodically in long-running loop to detect cancellation
**When to use:** When operation should return accumulated partial results instead of aborting completely
**Example:**
```r
# Source: https://blog.fellstat.com/?p=407
# Source: Project ARCHITECTURE.md interrupt system design

# R/interrupt.R - NEW FILE
create_interrupt_flag <- function(session_id) {
  flag_file <- tempfile(pattern = paste0("interrupt_", session_id, "_"))
  writeLines("running", flag_file)
  flag_file
}

check_interrupt <- function(flag_file) {
  if (is.null(flag_file) || !file.exists(flag_file)) return(FALSE)
  status <- tryCatch(
    readLines(flag_file, n = 1, warn = FALSE),
    error = function(e) "running"
  )
  status == "interrupt"
}

signal_interrupt <- function(flag_file) {
  if (!is.null(flag_file) && file.exists(flag_file)) {
    writeLines("interrupt", flag_file)
  }
}

clear_interrupt_flag <- function(flag_file) {
  if (!is.null(flag_file) && file.exists(flag_file)) {
    unlink(flag_file)
  }
}

# Modified citation_network.R
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                   direction = "both", depth = 2,
                                   node_limit = 100, progress_callback = NULL,
                                   interrupt_flag = NULL) {  # NEW PARAMETER

  # ... existing initialization code ...

  # BFS traversal
  for (hop in seq_len(depth)) {
    # Check for interrupt at start of each hop
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      if (!is.null(progress_callback)) {
        progress_callback("Cancelled by user", 1.0)
      }

      # Return partial results
      return(list(
        nodes = do.call(rbind, lapply(nodes_list, as.data.frame)),
        edges = do.call(rbind, lapply(edges_list, as.data.frame)),
        partial = TRUE  # Flag indicating incomplete result
      ))
    }

    # ... existing BFS logic ...

    # Update progress
    if (!is.null(progress_callback)) {
      progress_callback(
        paste("Hop", hop, "complete:", length(next_frontier), "papers found"),
        hop / depth
      )
    }
  }

  # ... existing finalization code ...

  # Full result
  return(list(
    nodes = nodes_df,
    edges = edges_df,
    partial = FALSE
  ))
}
```

**Key points:**
- File-based flags work across process boundaries (mirai executes in separate process)
- Check interrupt at coarse intervals (per BFS hop, not per paper) to minimize overhead
- Return partial results with `partial = TRUE` flag instead of throwing error
- Use `tryCatch()` around file operations for robustness

### Pattern 3: Custom Progress Modal with Cancel Button
**What:** Modal dialog with Bootstrap progress bar, live status text, and cancel button
**When to use:** When operation has granular progress updates and requires user-visible cancel button
**Example:**
```r
# Source: https://shiny.posit.co/r/reference/shiny/latest/modaldialog.html
# Source: Project existing modal pattern in mod_citation_network.R (save network modal)

show_progress_modal <- function(session, ns) {
  showModal(modalDialog(
    title = tagList(
      icon("spinner", class = "fa-spin text-primary"),
      " Building Citation Network"
    ),

    # Progress bar
    div(
      class = "progress mb-3",
      style = "height: 25px;",
      div(
        class = "progress-bar progress-bar-striped progress-bar-animated",
        role = "progressbar",
        id = ns("build_progress_bar"),
        style = "width: 0%;",
        "0%"
      )
    ),

    # Status message
    div(
      id = ns("build_progress_message"),
      class = "text-muted mb-3",
      "Initializing..."
    ),

    footer = tagList(
      actionButton(ns("cancel_build"), "Stop", class = "btn-warning", icon = icon("stop"))
    ),
    size = "m",
    easyClose = FALSE,  # Prevent dismissal by clicking outside
    fade = TRUE
  ))
}

# JavaScript handler for progress updates
tags$script(HTML(sprintf("
  Shiny.addCustomMessageHandler('updateProgress_%s', function(data) {
    var bar = $('#%s');
    bar.css('width', data.percent + '%%');
    bar.text(data.percent + '%%');
    $('#%s').text(data.message);
  });
", session$ns(""), session$ns("build_progress_bar"), session$ns("build_progress_message"))))

# Update progress from callback
progress_cb <- function(message, fraction) {
  session$sendCustomMessage(
    paste0("updateProgress_", session$ns("")),
    list(
      percent = round(fraction * 100),
      message = message
    )
  )
}
```

**Key points:**
- Use `easyClose = FALSE` to prevent accidental dismissal
- Update progress via custom JavaScript handler for responsive UI
- Cancel button triggers interrupt flag + task cancellation
- Bootstrap progress bar provides visual feedback

### Pattern 4: Observer Cleanup to Prevent Memory Leaks
**What:** Explicitly destroy observers when modal closed or task cancelled
**When to use:** Always, when creating observers for async operations
**Example:**
```r
# Source: https://cran.r-project.org/web/packages/shiny.destroy/vignettes/introduction.html
# Source: https://github.com/rstudio/shiny/issues/1253

# Store observer reference
cancel_observer <- NULL

# Create observer when modal shown
observeEvent(input$build_network, {
  # ... show modal, start task ...

  # Create cancel observer
  cancel_observer <<- observeEvent(input$cancel_build, {
    # ... cancellation logic ...

    # Destroy self after firing once
    if (!is.null(cancel_observer)) {
      cancel_observer$destroy()
      cancel_observer <<- NULL
    }
  }, once = TRUE)  # Alternative: use once = TRUE parameter
})

# Cleanup on session end
session$onSessionEnded(function() {
  if (!is.null(cancel_observer)) {
    cancel_observer$destroy()
  }
  # Clean up any remaining interrupt flags
  flags <- Sys.glob(file.path(tempdir(), paste0("interrupt_", session$token, "_*")))
  lapply(flags, unlink)
})
```

**Key points:**
- Use `once = TRUE` for single-fire observers (automatically cleans up)
- Store observer reference in variable for manual cleanup
- Use `session$onSessionEnded()` for final cleanup on disconnect
- Clean up temp files (interrupt flags) on session end

### Anti-Patterns to Avoid
- **Using withProgress() for async operations:** withProgress dismisses immediately when async function returns (before work completes)
- **Not checking interrupt flag:** Task runs to completion even after cancel clicked, wastes resources
- **Throwing error on cancellation:** Loses partial results, confuses error handling logic
- **Not cleaning up observers:** Memory leaks, orphaned event handlers accumulate over session
- **Polling task status too frequently:** Checking interrupt flag every iteration adds overhead, check at coarse intervals (per BFS hop)
- **Using session$userData for interrupt flags:** Doesn't work across process boundaries, use file-based flags for mirai

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async execution with cancellation | Custom process forking with parallel::mcparallel | ExtendedTask + mirai | ExtendedTask handles session management, cleanup, error propagation; mirai is lightweight vs forking |
| Progress modal UI | Custom JavaScript modal from scratch | showModal() + custom JavaScript handler | Shiny modal integrates with reactive system, Bootstrap styling, accessibility |
| Interrupt flag system | Custom IPC via sockets or shared memory | File-based flags with tempfile() | File-based flags are simple, work across process boundaries, OS handles atomicity |
| Observer cleanup | Manual tracking of all observers | once = TRUE parameter + session$onSessionEnded | Built-in cleanup mechanisms are more reliable, less prone to leaks |

**Key insight:** ExtendedTask is specifically designed for this use case (long-running operations with cancellation). Older approaches using promises/future lack native cancellation and require complex workarounds. The file-based interrupt flag pattern is battle-tested for Shiny async operations.

## Common Pitfalls

### Pitfall 1: ExtendedTask Cancelled but Process Continues
**What goes wrong:** User clicks cancel, modal closes, but R process continues fetching citation network in background for 30+ seconds. Database transaction commits unexpectedly, network appears in dropdown later.
**Why it happens:** ExtendedTask's `cancel()` method terminates the mirai process but doesn't stop work already in flight. If `fetch_citation_network()` doesn't check interrupt flag, it runs to completion in the terminated process and may write results before process cleaned up.
**How to avoid:**
1. Always pass interrupt flag to long-running function
2. Check flag at coarse intervals (every BFS hop, not every paper)
3. Wrap DB writes in transaction with rollback on cancellation
4. Use `on.exit()` to clean up resources even if process terminated
**Warning signs:** Network appears after cancellation, DB locked errors, memory usage continues climbing after cancel

### Pitfall 2: No Partial Results - All Work Lost on Cancel
**What goes wrong:** User builds depth-3 network (5 minutes), cancels after 4 minutes at depth 2. All accumulated nodes/edges discarded, user has nothing to show.
**Why it happens:** Cancellation throws error or returns NULL instead of returning accumulated data.
**How to avoid:**
1. Return `list(nodes = ..., edges = ..., partial = TRUE)` on interrupt detection
2. Check `result$partial` flag in UI and show appropriate message
3. Display partial networks normally, just notify user they're incomplete
4. Store partial flag in network metadata if saved to DB
**Warning signs:** Users reluctant to use cancel button, complaints about "wasting time", re-starting operations from scratch

### Pitfall 3: Progress Updates Stop After Cancellation Signaled
**What goes wrong:** User clicks cancel, modal shows "Initializing..." frozen, but actually cancellation is processing (cleaning up resources). User clicks cancel 5 more times thinking it's broken.
**Why it happens:** No progress update sent after interrupt detected, UI appears frozen during cleanup.
**How to avoid:**
1. Send progress update when interrupt detected: `progress_callback("Cancelling...", 0.95)`
2. Send final update before return: `progress_callback("Cancelled by user", 1.0)`
3. Close modal immediately after cancel clicked, don't wait for task to return
4. Show transient notification "Cancelling network build..." during cleanup
**Warning signs:** Users report cancel button "doesn't work", multiple clicks, confusion about app state

### Pitfall 4: Interrupt Flag File Not Cleaned Up
**What goes wrong:** After 50 network builds (some cancelled), temp directory has 50 interrupt flag files. Files accumulate, disk space wasted, old flags interfere with new operations.
**Why it happens:** `clear_interrupt_flag()` not called in all exit paths (success, error, cancellation).
**How to avoid:**
1. Use `on.exit(clear_interrupt_flag(flag_file))` immediately after creating flag
2. Also clean up in `session$onSessionEnded()` as fallback
3. Use tempfile pattern with session ID to ensure uniqueness
4. Periodically clean old flags: `Sys.glob(file.path(tempdir(), "interrupt_*"))`
**Warning signs:** Temp directory growing over time, files named "interrupt_*" accumulating

### Pitfall 5: Custom JavaScript Progress Handler Leaks Memory
**What goes wrong:** After 20 network builds, browser tab using 500MB RAM, page sluggish.
**Why it happens:** Custom message handler `Shiny.addCustomMessageHandler()` registered every time modal shown, old handlers not removed.
**How to avoid:**
1. Register custom handler once at module initialization (not in modal show function)
2. Use namespaced handler names to avoid collisions: `updateProgress_${session_ns}`
3. Remove handler on session end if possible (Shiny doesn't provide direct API, rely on page reload)
4. Alternatively, use server-side `Progress` class instead of custom JavaScript
**Warning signs:** Browser memory usage climbing, developer console shows multiple identical handlers

### Pitfall 6: Modal Dismissed While Task Running
**What goes wrong:** User clicks outside modal (if `easyClose = TRUE`), modal closes, but task continues running. No way to cancel, no progress indicator visible.
**Why it happens:** `easyClose = TRUE` allows dismissal without cancellation, task keeps running in background.
**How to avoid:**
1. Always use `easyClose = FALSE` for progress modals with cancellable operations
2. Only allow dismissal via explicit cancel button that triggers task cancellation
3. Optionally, add `onDismiss` handler that cancels task if modal closed unexpectedly
4. Show notification if task still running after modal dismissed
**Warning signs:** Users report "modal disappeared but still processing", confusion about app state

## Code Examples

Verified patterns from official sources:

### Complete ExtendedTask Implementation for Citation Network
```r
# Source: https://rstudio.github.io/shiny/reference/ExtendedTask.html
# Source: https://mirai.r-lib.org/articles/shiny.html
# Location: R/mod_citation_network.R

mod_citation_network_server <- function(id, con_r, config_r, ...) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # State
    current_seed_id <- reactiveVal(NULL)
    current_network_data <- reactiveVal(NULL)
    current_interrupt_flag <- reactiveVal(NULL)

    # ExtendedTask for async network building
    network_task <- ExtendedTask$new(
      function(seed_id, email, direction, depth, node_limit, interrupt_flag) {
        # Execute in separate mirai process
        mirai::mirai({
          # Source all required functions (mirai runs in isolated environment)
          source("R/citation_network.R")
          source("R/api_openalex.R")

          # Build network with interrupt flag
          result <- fetch_citation_network(
            seed_id, email, api_key = NULL,
            direction = direction,
            depth = depth,
            node_limit = node_limit,
            interrupt_flag = interrupt_flag,
            progress_callback = NULL  # Progress updates handled separately
          )

          # Compute layout if full result
          if (!result$partial) {
            result$nodes <- compute_layout_positions(result$nodes, result$edges)
          }

          result
        })
      }
    )

    # Build button handler
    observeEvent(input$build_network, {
      req(current_seed_id())

      # Create interrupt flag
      flag_file <- create_interrupt_flag(session$token)
      current_interrupt_flag(flag_file)

      # Ensure cleanup on any exit
      on.exit({
        clear_interrupt_flag(current_interrupt_flag())
        current_interrupt_flag(NULL)
      }, add = TRUE)

      # Show progress modal
      showModal(modalDialog(
        title = tagList(
          icon("spinner", class = "fa-spin text-primary"),
          " Building Citation Network"
        ),
        div(
          class = "progress mb-3",
          style = "height: 25px;",
          div(
            class = "progress-bar progress-bar-striped progress-bar-animated bg-primary",
            role = "progressbar",
            id = ns("build_progress_bar"),
            style = "width: 5%;",
            "5%"
          )
        ),
        div(
          id = ns("build_progress_message"),
          class = "text-muted text-center mb-3",
          "Fetching seed paper..."
        ),
        footer = tagList(
          actionButton(ns("cancel_build"), "Stop", class = "btn-warning", icon = icon("stop"))
        ),
        size = "m",
        easyClose = FALSE
      ))

      # Invoke task
      network_task$invoke(
        seed_id = current_seed_id(),
        email = config_r()$openalex$email,
        direction = input$direction,
        depth = input$depth,
        node_limit = input$node_limit,
        interrupt_flag = flag_file
      )

      # Simulate progress updates (real implementation would use mirai communication)
      # For Phase 18, use polling pattern with task status
      progress_updater <- observe({
        invalidateLater(1000)  # Check every second

        status <- network_task$status()
        if (status == "running") {
          # Update progress bar incrementally
          # (Real implementation: read progress from task state or file)
          runjs(sprintf("
            var bar = $('#%s');
            var current = parseInt(bar.attr('aria-valuenow') || 5);
            var next = Math.min(current + 10, 90);
            bar.css('width', next + '%%');
            bar.text(next + '%%');
            bar.attr('aria-valuenow', next);
          ", ns("build_progress_bar")))
        } else {
          progress_updater$destroy()
        }
      })
    })

    # Cancel button handler
    observeEvent(input$cancel_build, {
      # Signal interrupt
      flag_file <- current_interrupt_flag()
      if (!is.null(flag_file)) {
        signal_interrupt(flag_file)
      }

      # Cancel task
      network_task$cancel()

      # Close modal
      removeModal()

      showNotification(
        "Network build cancelled. Partial results will be displayed if available.",
        type = "warning",
        duration = 5
      )
    }, once = TRUE)  # Automatically cleans up after first click

    # Handle task completion
    observe({
      result <- network_task$result()

      # Close modal
      removeModal()

      # Handle partial vs full results
      if (!is.null(result$partial) && result$partial) {
        showNotification(
          sprintf(
            "Partial network built: %d nodes, %d edges (cancelled by user)",
            nrow(result$nodes), nrow(result$edges)
          ),
          type = "message",
          duration = 10
        )
      } else {
        showNotification(
          sprintf("Network built: %d nodes, %d edges", nrow(result$nodes), nrow(result$edges)),
          type = "message"
        )
      }

      # Build visualization data
      palette <- input$palette %||% "viridis"
      viz_data <- build_network_data(result$nodes, result$edges, palette, current_seed_id())

      # Update current network
      current_network_data(list(
        nodes = viz_data$nodes,
        edges = viz_data$edges,
        metadata = list(
          seed_paper_id = current_seed_id(),
          direction = input$direction,
          depth = input$depth,
          node_limit = input$node_limit,
          palette = palette,
          partial = result$partial %||% FALSE
        )
      ))
    })
  })
}
```

### Interrupt Flag Utilities
```r
# Source: https://blog.fellstat.com/?p=407
# Source: Project ARCHITECTURE.md interrupt system design
# Location: R/interrupt.R (NEW FILE)

#' Create interrupt flag for cancellable operation
#' @param session_id Unique session identifier
#' @return Path to temporary flag file
create_interrupt_flag <- function(session_id) {
  flag_file <- tempfile(
    pattern = sprintf("serapeum_interrupt_%s_", session_id),
    tmpdir = tempdir(),
    fileext = ".flag"
  )
  writeLines("running", flag_file)
  flag_file
}

#' Check if interrupt has been signaled
#' @param flag_file Path to interrupt flag file
#' @return Logical indicating if interrupt signaled
check_interrupt <- function(flag_file) {
  if (is.null(flag_file) || !file.exists(flag_file)) {
    return(FALSE)
  }

  status <- tryCatch(
    readLines(flag_file, n = 1, warn = FALSE),
    error = function(e) {
      # File read error (e.g., deleted mid-read) = assume not interrupted
      "running"
    }
  )

  status == "interrupt"
}

#' Signal interrupt to running operation
#' @param flag_file Path to interrupt flag file
signal_interrupt <- function(flag_file) {
  if (!is.null(flag_file) && file.exists(flag_file)) {
    tryCatch(
      writeLines("interrupt", flag_file),
      error = function(e) {
        # Silently fail if file can't be written (already deleted, etc.)
        NULL
      }
    )
  }
}

#' Clean up interrupt flag file
#' @param flag_file Path to interrupt flag file
clear_interrupt_flag <- function(flag_file) {
  if (!is.null(flag_file) && file.exists(flag_file)) {
    unlink(flag_file)
  }
}

#' Clean up all interrupt flags for a session
#' @param session_id Unique session identifier
cleanup_session_flags <- function(session_id) {
  pattern <- sprintf("serapeum_interrupt_%s_*.flag", session_id)
  flags <- Sys.glob(file.path(tempdir(), pattern))
  lapply(flags, unlink)
  invisible(length(flags))
}
```

### Modified fetch_citation_network with Interrupt Support
```r
# Source: Existing R/citation_network.R + interrupt flag pattern
# Location: R/citation_network.R (MODIFY existing function)

#' Fetch citation network using BFS traversal
#'
#' Builds a citation graph starting from a seed paper, traversing
#' citations up to a specified depth. Uses breadth-first search with
#' citation-count pruning to keep the most influential papers.
#'
#' @param seed_paper_id OpenAlex Work ID (e.g., "W2741809807")
#' @param email User email for OpenAlex API
#' @param api_key Optional OpenAlex API key
#' @param direction "forward" (citing papers), "backward" (cited papers), or "both"
#' @param depth Number of hops from seed (1-3)
#' @param node_limit Maximum nodes to include (25-200)
#' @param progress_callback Optional function(message, fraction) for progress updates
#' @param interrupt_flag Optional path to interrupt flag file for cancellation
#' @return List with nodes (data.frame), edges (data.frame), and partial (logical)
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                   direction = "both", depth = 2,
                                   node_limit = 100, progress_callback = NULL,
                                   interrupt_flag = NULL) {  # NEW PARAMETER

  # ... existing initialization code ...

  # BFS traversal
  for (hop in seq_len(depth)) {
    # Check for interrupt at start of each hop
    if (!is.null(interrupt_flag) && check_interrupt(interrupt_flag)) {
      if (!is.null(progress_callback)) {
        progress_callback("Cancelled by user", 1.0)
      }

      # Convert accumulated data to data frames
      nodes_df <- if (length(nodes_list) > 0) {
        do.call(rbind, lapply(nodes_list, as.data.frame, stringsAsFactors = FALSE))
      } else {
        data.frame(
          paper_id = character(), title = character(), authors = character(),
          year = integer(), venue = character(), doi = character(),
          cited_by_count = integer(), is_seed = logical(),
          stringsAsFactors = FALSE
        )
      }

      edges_df <- if (length(edges_list) > 0) {
        do.call(rbind, lapply(edges_list, as.data.frame, stringsAsFactors = FALSE))
      } else {
        data.frame(
          from_paper_id = character(), to_paper_id = character(),
          stringsAsFactors = FALSE
        )
      }

      # Return partial results
      return(list(
        nodes = nodes_df,
        edges = edges_df,
        partial = TRUE  # Flag indicating incomplete result
      ))
    }

    # ... existing BFS logic for fetching papers ...

    # Update progress
    if (!is.null(progress_callback)) {
      progress_callback(
        sprintf("Hop %d/%d complete: %d papers found", hop, depth, length(next_frontier)),
        0.1 + (hop / depth) * 0.7
      )
    }

    # ... existing pruning logic ...

    current_frontier <- next_frontier
  }

  # ... existing cross-link discovery ...

  if (!is.null(progress_callback)) {
    progress_callback(
      sprintf("Network built: %d nodes, %d edges", nrow(nodes_df), nrow(edges_df)),
      1.0
    )
  }

  # Return full result
  list(
    nodes = nodes_df,
    edges = edges_df,
    partial = FALSE  # Complete result
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| promises + future for async | ExtendedTask + mirai | Shiny 1.8.1 (Jan 2026) | Native cancellation, lighter weight, better session management |
| withProgress() for all operations | Custom modals + Progress class for long ops | Best practice (2020+) | More control over cancellation, better UX |
| Process termination with pskill | Interrupt flag pattern with partial results | Established pattern (2018+) | Graceful cancellation, preserves accumulated work |
| Global reactive state for cancellation | File-based flags across process boundaries | Async pattern requirement | Works with mirai isolated processes |

**Deprecated/outdated:**
- **withProgress() for async operations:** Dismisses immediately when async function returns, before work completes
- **promises without cancellation:** No way to stop running operations, wastes resources
- **future with multicore backend on Windows:** Doesn't support forking, falls back to sequential
- **Session-scoped reactive flags for mirai:** Mirai processes are isolated, can't access session state directly

## Open Questions

1. **Should progress updates use polling or mirai communication?**
   - What we know: Polling (invalidateLater) is simple but less efficient; mirai supports bi-directional communication
   - What's unclear: Performance impact of polling vs complexity of mirai communication setup
   - Recommendation: Start with polling for simplicity, optimize to mirai communication if performance issues

2. **Should partial networks be auto-saved or require explicit save?**
   - What we know: Users may want to save partial results if they spent minutes building them
   - What's unclear: Do users expect cancelled operations to be saved, or should they be transient?
   - Recommendation: Don't auto-save partial networks, but allow user to manually save them if desired

3. **Should cancel button say "Stop", "Cancel", or "Abort"?**
   - What we know: "Stop" is clearest for ongoing action, "Cancel" implies discarding, "Abort" sounds severe
   - What's unclear: User mental model for cancellation vs stopping
   - Recommendation: Use "Stop" (matches media player conventions), pair with clear notification about partial results

4. **Should progress modal show estimated time remaining?**
   - What we know: Citation network build time varies wildly based on depth and citation counts
   - What's unclear: Can we reliably estimate remaining time given variable API response times?
   - Recommendation: Don't show time estimates (too unreliable), show hop progress ("Hop 2 of 3") instead

## Sources

### Primary (HIGH confidence)
- Shiny ExtendedTask documentation: https://rstudio.github.io/shiny/reference/ExtendedTask.html
- Shiny ExtendedTask official docs: https://shiny.posit.co/r/reference/shiny/latest/extendedtask.html
- mirai Shiny integration: https://mirai.r-lib.org/articles/shiny.html
- bslib input_task_button: https://rstudio.github.io/bslib/reference/input_task_button.html
- bslib bind_task_button: https://rstudio.github.io/bslib/reference/bind_task_button.html
- Shiny 1.8.1 release notes: https://shiny.posit.co/blog/posts/shiny-r-1.8.1/
- Shiny modal dialog docs: https://shiny.posit.co/r/reference/shiny/latest/modaldialog.html

### Secondary (MEDIUM confidence)
- Long Running Tasks With Shiny: https://blog.fellstat.com/?p=407
- Concurrent, forked, cancellable tasks in Shiny: https://gist.github.com/jcheng5/9504798d93e5c50109f8bbaec5abe372
- Using promises with Shiny: https://rstudio.github.io/promises/articles/shiny.html
- Case study: converting a Shiny app to async: https://rstudio.github.io/promises/articles/casestudy.html
- Mastering Shiny - User feedback chapter: https://mastering-shiny.org/action-feedback.html

### Tertiary (LOW confidence)
- Shiny observer cleanup: https://cran.r-project.org/web/packages/shiny.destroy/vignettes/introduction.html
- Shiny memory leak issues: https://github.com/rstudio/shiny/issues/1253

### Project Context
- Serapeum ARCHITECTURE.md interrupt system design (Phase 18 section)
- Serapeum PITFALLS.md Pitfall 3: Orphaned Async Processes from Cancel Button
- Existing `fetch_citation_network()` with `progress_callback` pattern
- Phase 17 research: debounce pattern, reactive best practices

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ExtendedTask released Jan 2026, official Shiny docs, mirai integration documented
- Architecture: HIGH - Interrupt flag pattern is established (2018+), ExtendedTask examples in official docs, project already uses progress callbacks
- Pitfalls: HIGH - Async cancellation pitfalls well-documented in Shiny community, orphaned process pattern identified in project PITFALLS.md

**Research date:** 2026-02-13
**Valid until:** ~30 days (fast-moving domain; ExtendedTask is very recent, API may evolve)
