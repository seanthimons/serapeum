# Architecture Integration Analysis: v2.1 Polish & Analysis

**Project:** Serapeum v2.1
**Researched:** 2026-02-13
**Domain:** R/Shiny Research Assistant

## Executive Summary

v2.1 adds four feature categories to the existing R/Shiny application: year range slider filtering, conclusion synthesis, progress modals with cancellation, and UI polish. The existing architecture supports these additions through established patterns:

1. **Year Range Slider:** Extends the composable filter chain (keyword → journal quality → display) with a new reactive filter step. Integrates with both search notebook UI and citation network visualization.

2. **Conclusion Synthesis:** New RAG variant function that targets conclusion sections via multi-step prompting. Uses existing `rag_query()` pattern with specialized context filtering and prompt engineering.

3. **Progress Modal with Cancellation:** Shiny's `withProgress()` has no native cancellation. Requires custom interruption mechanism via reactive polling and external flag. Build on existing `progress_callback` pattern in `fetch_citation_network()`.

4. **UI Polish:** Icon changes and sidebar modifications are isolated CSS/UI updates. No architectural changes required.

**Integration Complexity:** LOW to MEDIUM. All features build on existing patterns. Year filter and conclusion synthesis are compositional. Only progress cancellation requires new infrastructure (interrupt flag pattern).

## Integration Point Analysis

### 1. Year Range Slider Filter

#### Where It Fits in Filter Chain

**Current Filter Chain (Search Notebook):**
```
papers_data (DB query with sort)
  → keyword_filtered_papers (mod_keyword_filter)
  → journal_filtered_papers (mod_journal_filter)
  → filtered_papers (has_abstract checkbox)
  → display (paper_list UI)
```

**Integration Point:** Insert between `journal_filtered_papers` and `has_abstract` filter.

**New Chain:**
```
papers_data
  → keyword_filtered_papers
  → journal_filtered_papers
  → year_filtered_papers (NEW)
  → filtered_papers (has_abstract)
  → display
```

**Implementation:**
- Add `sliderInput()` to search notebook UI (alongside has_abstract checkbox)
- Add reactive `year_filtered_papers()` that filters `journal_filtered_papers()` by year range
- Update `filtered_papers()` to consume `year_filtered_papers()` instead of `journal_filtered_papers()`
- Save year range to `notebooks.search_filters` JSON (same pattern as existing filters)

**Data Flow:** Reactive chain, no new modules needed.

#### Citation Network Integration

**Different Data Flow:** Citation networks use `fetch_citation_network()` which returns nodes directly, not via filter chain.

**Integration Point:** Filter nodes AFTER fetch, BEFORE visualization.

**Current Flow:**
```
fetch_citation_network() → result$nodes
  → compute_layout_positions()
  → build_network_data()
  → current_network_data()
  → visNetwork render
```

**New Flow:**
```
fetch_citation_network() → result$nodes
  → filter_by_year_range(nodes, year_min, year_max) (NEW)
  → compute_layout_positions()
  → build_network_data()
  → current_network_data()
  → visNetwork render
```

**Implementation:**
- Add `sliderInput()` to citation network controls (near direction/depth/node_limit)
- Add `filter_by_year_range()` helper function in `citation_network.R`
- Apply filter in `observeEvent(input$build_network)` before visualization
- Store year range in network metadata (for saved networks)

**Key Difference:** Search notebook = filter reactive chain. Citation network = filter raw data frame before viz.

### 2. Conclusion Synthesis

#### New Module vs. Extend Existing?

**Analysis:** Extend existing `rag.R` with new function, NOT a new module.

**Rationale:**
- Conclusion synthesis is a RAG variant, not a separate UI component
- Uses existing chat model, cost logging, chunk retrieval
- Adds to search/document notebook chat, not standalone feature

**Integration Point:** New function `rag_query_conclusions()` in `rag.R`, callable from existing chat handlers.

#### RAG Targeting Architecture

**Problem:** Need to filter retrieved chunks to conclusion sections before LLM processing.

**Current RAG Flow (`rag_query()`):**
```
1. User question → embed OR hybrid search
2. search_chunks() / search_chunks_hybrid() → top 5 chunks
3. build_context(chunks) → formatted context
4. chat_completion(system + context + question) → response
```

**Conclusion-Targeted Flow (`rag_query_conclusions()`):**
```
1. User question → embed OR hybrid search with "conclusion" keyword boost
2. search_chunks() with conclusion filtering → top 5 conclusion chunks
3. build_context(chunks) → formatted context
4. chat_completion(CONCLUSION_SYSTEM_PROMPT + context + question) → synthesis
```

**Key Changes:**
1. **Retrieval Filtering:** Modify search query to prefer chunks containing conclusion keywords ("conclusion", "summary", "findings", "implications")
2. **Specialized Prompt:** Different system prompt focusing on synthesis across papers

**Implementation in Ragnar (Hybrid Search):**
```r
search_chunks_hybrid_conclusions <- function(con, query, notebook_id, limit = 10) {
  # Boost query with conclusion terms
  boosted_query <- paste(query, "conclusion findings summary implications")
  chunks <- search_chunks_hybrid(con, boosted_query, notebook_id, limit = limit)

  # Post-filter: prefer chunks mentioning conclusion keywords
  chunks$conclusion_score <- str_count(tolower(chunks$content),
    "conclusion|summary|findings|implications|in conclusion|to summarize")
  chunks <- chunks[order(-chunks$conclusion_score), ]
  head(chunks, limit)
}
```

**Implementation in Legacy (Cosine Search):**
```r
# No modification to embedding itself
# Post-filter chunks by keyword matching
conclusion_keywords <- c("conclusion", "findings", "summary", "implications")
chunks$is_conclusion <- grepl(paste(conclusion_keywords, collapse = "|"),
                               tolower(chunks$content))
chunks <- chunks[chunks$is_conclusion | chunks$similarity > 0.9, ]
```

#### Multi-Step Prompt Pipeline

**Question:** Do we need multi-step prompting (retrieve → summarize each → synthesize)?

**Answer:** NO for v2.1. Use single-step synthesis with specialized prompt.

**Single-Step Architecture (RECOMMENDED):**
```
1. Retrieve top 10 conclusion-tagged chunks (5 per paper limit)
2. Build context with paper titles as separators
3. Prompt: "Synthesize the key conclusions across these papers.
   Identify common themes, contradictions, and gaps. Cite each paper."
4. Generate synthesis in one LLM call
```

**Multi-Step Architecture (FUTURE):**
```
1. Retrieve all conclusion chunks
2. For each paper: summarize_conclusions(paper_chunks) → paper_summary
3. synthesize_across_papers([paper_summary_1, paper_summary_2, ...]) → final_synthesis
```

**Rationale for Single-Step:**
- Simpler implementation, fewer API calls, lower cost
- Current context window (Claude Sonnet 4: 200K tokens) can handle 10 abstracts easily
- Multi-step adds latency without clear quality improvement for typical notebook sizes (5-50 papers)

**When to Use Multi-Step:**
- Notebooks with >100 papers (context overflow)
- Need per-paper summaries as intermediate artifacts
- Requires complex reasoning chains (contradiction resolution, evidence weighing)

#### Integration with Existing Chat

**UI Integration Point:** Add "Synthesize Conclusions" preset button to chat panel.

**Current Presets (Document Notebook):**
- Summarize
- Key Points
- Study Guide
- Outline

**New Preset (Search Notebook):**
- **Synthesize Conclusions** → calls `rag_query_conclusions()`

**Implementation:**
```r
# In mod_search_notebook.R chat panel
actionButton(ns("preset_synthesize"), "Synthesize Conclusions",
             class = "btn-outline-info btn-sm", icon = icon("lightbulb"))

observeEvent(input$preset_synthesize, {
  response <- rag_query_conclusions(con(), config(), notebook_id(),
                                     session_id = session$token)
  msgs <- messages()
  msgs <- c(msgs, list(
    list(role = "assistant", content = response, timestamp = Sys.time())
  ))
  messages(msgs)
})
```

**No Module Needed:** Extends existing chat offcanvas, uses existing `messages()` reactive.

### 3. Progress Modal with Cancellation

#### Shiny Interruption Limitations

**Core Problem:** Shiny's `withProgress()` has no built-in cancellation mechanism.

**From Documentation ([Mastering Shiny](https://mastering-shiny.org/action-feedback.html)):**
> "withProgress wraps the scope of your work and causes a new progress panel to be created; when withProgress exits, the corresponding progress panel will be removed."

**From RStudio Docs ([Case Study: Async](https://rstudio.github.io/promises/articles/casestudy.html)):**
> "The withProgress function cannot be used with async operations; withProgress is designed to wrap a slow synchronous action and dismisses its progress dialog when the code completes."

**Limitation:** No standard way to interrupt a running reactive computation.

#### Interrupt Mechanism Architecture

**Pattern (from [Long Running Tasks With Shiny](https://blog.fellstat.com/?p=407)):**
> "To enable cancellation and monitoring, you can use a file where progress and interrupt requests are read and written—if the user clicks the cancel button, "interrupt" is written to the file, and during computation the analysis code checks whether interrupt has been signaled and throws an error."

**Implementation for Serapeum:**

**Step 1: Create Interrupt Flag System**
```r
# In new file: R/interrupt.R
create_interrupt_flag <- function(session_id) {
  flag_file <- tempfile(pattern = paste0("interrupt_", session_id, "_"))
  writeLines("running", flag_file)
  flag_file
}

check_interrupt <- function(flag_file) {
  if (!file.exists(flag_file)) return(FALSE)
  status <- readLines(flag_file, n = 1, warn = FALSE)
  status == "interrupt"
}

signal_interrupt <- function(flag_file) {
  if (file.exists(flag_file)) writeLines("interrupt", flag_file)
}

clear_interrupt_flag <- function(flag_file) {
  if (file.exists(flag_file)) unlink(flag_file)
}
```

**Step 2: Modify Long-Running Operations**

**Current (Search Refresh):**
```r
observeEvent(input$refresh_search, {
  withProgress(message = "Searching OpenAlex...", {
    # Fetch papers
    for (paper in papers) {
      # Process...
    }
  })
})
```

**New (With Cancellation):**
```r
observeEvent(input$refresh_search, {
  flag_file <- create_interrupt_flag(session$token)
  on.exit(clear_interrupt_flag(flag_file))

  withProgress(message = "Searching OpenAlex...", {
    for (i in seq_along(papers)) {
      # Check for interrupt every 5 papers
      if (i %% 5 == 0 && check_interrupt(flag_file)) {
        showNotification("Search cancelled", type = "warning")
        return()
      }
      # Process paper...
      incProgress(1 / length(papers))
    }
  })
})

# Cancel button handler
observeEvent(input$cancel_search, {
  flag_file <- paste0(tempdir(), "/interrupt_", session$token, "_*")
  files <- Sys.glob(flag_file)
  lapply(files, signal_interrupt)
})
```

**Step 3: Modify `fetch_citation_network()` for Cancellation**

**Current Signature:**
```r
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                   direction = "both", depth = 2,
                                   node_limit = 100, progress_callback = NULL)
```

**New Signature:**
```r
fetch_citation_network <- function(seed_paper_id, email, api_key = NULL,
                                   direction = "both", depth = 2,
                                   node_limit = 100, progress_callback = NULL,
                                   interrupt_flag = NULL)  # NEW
```

**Implementation:**
```r
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
      partial = TRUE
    ))
  }

  # Continue with BFS traversal...
}
```

**Key Decisions:**
- **Interrupt check frequency:** Every BFS hop (depth 3 = max 3 checks) + every 10 API calls
- **Partial results:** Return accumulated nodes/edges on interrupt (useful for large networks)
- **Error handling:** Interrupt is NOT an error, returns normally with `partial = TRUE` flag

#### UI for Progress Modal

**Current:** `withProgress()` shows auto-positioned progress bar (top-right corner).

**New:** Custom modal dialog with progress bar + cancel button.

**Implementation:**
```r
# Show custom progress modal
showModal(modalDialog(
  title = tagList(icon("spinner", class = "fa-spin"), " Building Network"),
  div(
    class = "progress",
    div(class = "progress-bar progress-bar-striped progress-bar-animated",
        role = "progressbar",
        id = ns("build_progress_bar"),
        style = "width: 0%")
  ),
  uiOutput(ns("build_progress_message")),
  footer = tagList(
    actionButton(ns("cancel_build"), "Cancel", class = "btn-warning")
  ),
  size = "m",
  easyClose = FALSE
))

# Update progress from callback
progress_cb <- function(message, fraction) {
  session$sendCustomMessage("updateProgress", list(
    percent = fraction * 100,
    message = message
  ))
}
```

**JavaScript Handler:**
```javascript
Shiny.addCustomMessageHandler('updateProgress', function(data) {
  $('#build_progress_bar').css('width', data.percent + '%');
  $('#build_progress_message').text(data.message);
});
```

**Alternative (Simpler):** Use `Progress` reference class instead of `withProgress()`.

```r
# Supports manual control and long-lived progress objects
progress <- Progress$new(session, min = 0, max = 1)
progress$set(message = "Building network", value = 0)

# Update from anywhere
progress$set(value = 0.5, detail = "Hop 2 of 3")

# Close when done
progress$close()
```

**Recommendation:** Use `Progress` reference class for cancellable operations. Simpler than custom modals, supports `detail` for sub-messages.

### 4. UI Polish

#### Icon Changes

**Current Icons (app.R sidebar):**
- New Document Notebook: `icon("file-pdf")`
- New Search Notebook: `icon("magnifying-glass")`
- Discover from Paper: `icon("seedling")`
- Build a Query: `icon("wand-magic-sparkles")`
- Explore Topics: `icon("compass")`
- Citation Network: `icon("diagram-project")`

**Integration:** Direct replacement in UI code, no reactive changes.

**Example:**
```r
# Before
actionButton("new_document_nb", "New Document Notebook",
             icon = icon("file-pdf"))

# After (if changing to different icon)
actionButton("new_document_nb", "New Document Notebook",
             icon = icon("file-alt"))
```

**Verification:** Check [Font Awesome 6.x](https://fontawesome.com/icons) for available icon names.

#### Sidebar Modifications

**Current Structure:**
```
Sidebar (280px)
├── New Notebook Buttons (6 buttons)
├── Notebook List (scrollable)
│   ├── DOCUMENTS section
│   ├── SEARCHES section
│   └── NETWORKS section
├── Session Cost Display
├── Settings / About / Costs Links
└── GitHub Link + Dark Mode Toggle
```

**Potential Modifications:**
- Adjust button sizing/spacing
- Reorder sections
- Add collapsible sections
- Change color scheme

**Integration Point:** Pure UI changes in `app.R` sidebar definition. No server logic affected.

**Testing Needs:**
- Ensure responsive layout at different window sizes
- Verify scrollable area (`max-height: calc(100vh - 350px)`) still works
- Check dark mode compatibility if color changes

## Component Boundaries

| Component | What Changes | What Stays Same |
|-----------|--------------|-----------------|
| **Search Notebook Module** | Add year slider UI, year filter reactive, year range storage | Filter chain architecture, keyword/journal modules, chat functionality |
| **Citation Network Module** | Add year slider UI, node filtering function, metadata storage | BFS traversal, visNetwork rendering, physics engine |
| **RAG System** | New `rag_query_conclusions()` function, conclusion-targeted retrieval | Core `rag_query()`, embedding flow, cost logging |
| **Database (db.R)** | No changes (year range → JSON in existing `search_filters` column) | Schema, migration system |
| **UI (app.R)** | Icon changes, sidebar layout tweaks | Module wiring, reactive structure |
| **Interruption (NEW)** | New `interrupt.R` file with flag system | - |

## Data Flow Changes

### Year Filter Data Flow

**Search Notebook:**
```
User drags slider (input$year_range)
  → year_filtered_papers() reactive triggers
  → filters journal_filtered_papers() by year column
  → filtered_papers() consumes year_filtered_papers()
  → paper_list UI re-renders
  → observeEvent saves to notebooks.search_filters JSON
```

**Citation Network:**
```
User drags slider (input$year_range)
  → triggers rebuild (via observeEvent dependency)
  → fetch_citation_network() runs
  → nodes_df returned
  → filter_by_year_range(nodes_df, input$year_range) applied
  → build_network_data() proceeds with filtered nodes
  → visNetwork re-renders
```

### Conclusion Synthesis Data Flow

```
User clicks "Synthesize Conclusions" preset
  → rag_query_conclusions() called
  → search_chunks_hybrid() with conclusion keyword boost
  → chunks filtered by conclusion keywords
  → build_context(chunks) with paper titles
  → chat_completion() with synthesis prompt
  → response appended to messages()
  → chat UI re-renders with synthesis
  → cost logged to database
```

### Progress Cancellation Data Flow

```
User clicks action (e.g., "Build Network")
  → create_interrupt_flag(session_id) → temp file created
  → Progress$new() creates progress object
  → fetch_citation_network(..., interrupt_flag) starts
  → Every BFS hop: check_interrupt(flag_file)
  → If user clicks "Cancel": signal_interrupt(flag_file)
  → Next check_interrupt() returns TRUE
  → Function returns partial results
  → Progress$close() removes progress UI
  → clear_interrupt_flag() cleans up temp file
```

## Build Order & Dependencies

### Phase 1: Foundation (No Dependencies)
1. **Interrupt System** (NEW file, no deps)
   - Create `R/interrupt.R` with flag functions
   - Test with simple example (sleep loop with cancel button)

### Phase 2: Year Range Filter (Depends on UI)
2. **Year Slider UI** (Search Notebook)
   - Add `sliderInput()` to `mod_search_notebook_ui()`
   - Wire to `search_filters` save/restore logic

3. **Year Filter Reactive** (Search Notebook)
   - Add `year_filtered_papers()` between journal and has_abstract filters
   - Update `filtered_papers()` to consume it

4. **Year Filter UI** (Citation Network)
   - Add `sliderInput()` to `mod_citation_network_ui()`
   - Store in network metadata

5. **Year Filter Logic** (Citation Network)
   - Add `filter_by_year_range()` helper in `citation_network.R`
   - Apply in build network observer

### Phase 3: Conclusion Synthesis (Depends on RAG)
6. **Conclusion Retrieval**
   - Add `search_chunks_hybrid_conclusions()` variant
   - Implement keyword boosting

7. **Synthesis Function**
   - Add `rag_query_conclusions()` to `rag.R`
   - Define conclusion-specific system prompt

8. **Synthesis UI**
   - Add preset button to search notebook chat
   - Wire to new function

### Phase 4: Progress Cancellation (Depends on Interrupt System)
9. **Citation Network Cancellation**
   - Modify `fetch_citation_network()` signature (add `interrupt_flag`)
   - Add interrupt checks in BFS loop
   - Update module to use `Progress` class

10. **Search Refresh Cancellation**
    - Add interrupt checks to search loop
    - Add cancel button to progress UI

### Phase 5: UI Polish (No Dependencies, Can Be Done Anytime)
11. **Icon Updates**
    - Replace icon names in `app.R`
    - Verify Font Awesome names

12. **Sidebar Layout**
    - Adjust spacing/sizing
    - Test responsive behavior

## Integration Risks & Mitigations

### Risk 1: Year Filter Performance (Search Notebook)

**Problem:** Adding another reactive filter step increases cascade complexity. If papers_data() has 1000 papers, every year slider drag triggers full filter chain recalculation.

**Mitigation:**
- Use `debounce(reactive(...), 500)` on year filter to prevent rapid re-filtering during drag
- Filter chain is already lazy (reactive, not observe), so doesn't recalculate unless downstream consumers invalidated
- Current chain handles this well (keyword filter already filters 1000s of papers)

**Test:** Load notebook with 200 papers, drag year slider rapidly, ensure UI stays responsive.

### Risk 2: Citation Network Year Filter Breaks Layout

**Problem:** Filtering nodes AFTER layout computation means some nodes may be positioned but hidden, leaving gaps.

**Mitigation:**
- Filter nodes BEFORE layout computation, not after
- Correct integration point: `fetch_citation_network() → filter → compute_layout_positions() → build_network_data()`
- Ensure edge filtering: remove edges where either endpoint was filtered out

**Test:** Build network with year range 2000-2024, then narrow to 2020-2024, verify layout re-computes cleanly.

### Risk 3: Conclusion Synthesis Returns Low-Quality Results

**Problem:** Keyword boosting may retrieve irrelevant chunks if papers don't have explicit conclusion sections.

**Mitigation:**
- **Fallback strategy:** If <3 chunks with conclusion keywords found, fall back to regular RAG
- **Prompt engineering:** System prompt instructs LLM to say "Some papers lack explicit conclusions, synthesizing from available content"
- **UI messaging:** Add note "Works best with papers that have conclusion sections"

**Test:** Test with mixed dataset (some papers with conclusions, some without), verify graceful degradation.

### Risk 4: Interrupt Flag Doesn't Work (Race Conditions)

**Problem:** File-based flag may have read/write race conditions if check happens exactly when signal written.

**Mitigation:**
- Use atomic file writes (`writeLines()` is atomic on most filesystems)
- Check interrupt at coarse intervals (every hop, not every paper)
- Worst case: interrupt takes one extra hop to register (acceptable latency)
- Use `tryCatch()` around file operations to handle missing files gracefully

**Test:** Rapid start/cancel cycles, verify no crashes and cancellation always eventually works.

### Risk 5: Progress Class Breaks with Multiple Concurrent Operations

**Problem:** If user triggers two long operations (e.g., build network + search refresh), progress objects may conflict.

**Mitigation:**
- Shiny's `Progress` class is session-scoped, not app-scoped (safe for multi-user)
- Use separate progress objects per operation (different session IDs if needed)
- Disable operation buttons while operation running (`build_in_progress()` reactive pattern already exists)

**Test:** Try to trigger two operations simultaneously, verify buttons disabled or operations queued.

## Sources

### Shiny Progress and Cancellation
- [Long Running Tasks With Shiny: Challenges and Solutions](https://blog.fellstat.com/?p=407)
- [Chapter 8 User feedback | Mastering Shiny](https://mastering-shiny.org/action-feedback.html)
- [Shiny - Progress indicators](https://shiny.posit.co/r/articles/build/progress/)
- [Case study: converting a Shiny app to async](https://rstudio.github.io/promises/articles/casestudy.html)

### Shiny Reactive Patterns
- [Chapter 15 Reactive building blocks | Mastering Shiny](https://mastering-shiny.org/reactivity-objects.html)

### Shiny Slider Inputs
- [Shiny - Slider Range](https://shiny.posit.co/r/components/inputs/slider-range/)
- [Add a year filter: numeric slider input | R](https://campus.datacamp.com/courses/case-studies-building-web-applications-with-shiny-in-r/make-the-perfect-plot-using-shiny?ex=11)

### RAG Architecture
- [Synergizing RAG and Reasoning: A Systematic Review](https://arxiv.org/html/2504.15909v1)
- [Retrieval Augmented Generation (RAG) for LLMs | Prompt Engineering Guide](https://www.promptingguide.ai/research/rag)
- [Advanced RAG Techniques for High-Performance LLM Applications](https://neo4j.com/blog/genai/advanced-rag-techniques/)
