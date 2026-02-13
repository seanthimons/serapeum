# Technology Stack Additions - v2.1 Polish & Analysis

**Project:** Serapeum v2.1 Polish & Analysis
**Researched:** 2026-02-13
**Confidence:** HIGH

## Executive Summary

The v2.1 milestone adds **interactive year filtering**, **conclusion synthesis with multi-step prompts**, **progress modals with cancellation**, and **UI icons/favicon** to the existing R/Shiny research assistant. Stack additions are **minimal and focused**:

1. **NO new packages needed** for year range slider (native Shiny sliderInput with histogram overlay)
2. **NO new packages needed** for multi-step RAG synthesis (existing OpenRouter + prompt engineering)
3. **NO new packages needed** for progress modal (native Shiny modalDialog + ExtendedTask patterns)
4. **ONE optional package** for favicon (favawesome or manual HTML approach)
5. **Existing stack handles everything else** (Shiny 1.11.1, promises 1.3.3, future 1.67.0)

**Key insight:** All v2.1 features use native Shiny capabilities already in the stack. No external dependencies required except for enhanced favicon support.

---

## New Features → Stack Mapping

### 1. Interactive Year Range Slider with Histogram

**Requirement:** Year range filter (e.g., 2015-2024) with distribution histogram overlay for search notebooks and citation networks.

**Stack Decision:** **Native Shiny sliderInput + custom histogram rendering**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Shiny sliderInput** | Built-in | Year range selection | Native range slider support (pass vector c(min, max) to value param). Already used throughout app. |
| **Base R graphics or ggplot2** | Built-in / Existing | Histogram overlay | Render histogram as background image or plotOutput overlay. No new dependencies needed. |

**Alternative Considered:** `histoslider` package (0.1.1)
- **Why NOT:** Adds React.js dependency, minimal CRAN documentation, last updated July 2025, experimental maturity. Solving a solved problem (Shiny already does range sliders).
- **When to use:** If future phases need synchronized brush-and-zoom histogram interaction (not in v2.1 scope).

**Implementation Pattern:**
```r
# Year range slider with two-value vector
sliderInput("year_range", "Publication Years",
            min = 1990, max = 2026, value = c(2015, 2024),
            step = 1, sep = "")

# Histogram as background via uiOutput + plotOutput overlay
# Or CSS background-image with data URI encoded PNG
```

**Confidence:** HIGH
- **Sources:** [Shiny sliderInput docs](https://shiny.posit.co/r/reference/shiny/0.14/sliderinput.html), [Slider Range component](https://shiny.posit.co/r/components/inputs/slider-range/), [histoslider CRAN](https://cran.r-project.org/package=histoslider)
- **Evidence:** Shiny sliderInput is production-ready. Histogram overlay is standard R graphics. No new dependencies justify minimal UX gain.

---

### 2. RAG-Targeted Conclusion Synthesis with Multi-Step Prompts

**Requirement:** Generate conclusion section with future research directions using multi-step prompt pipeline (retrieve relevant chunks → synthesize with disclaimers).

**Stack Decision:** **Existing OpenRouter API + prompt engineering patterns**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **OpenRouter API** | Existing | LLM inference | Already integrated. Supports all frontier models (Claude, GPT-4, Gemini). Multi-step = sequential API calls. |
| **Existing RAG pipeline** | Existing | Chunk retrieval + ranking | `rag.R` already implements semantic search with embeddings. Reuse for targeted retrieval. |
| **Prompt engineering** | N/A | Multi-step pipeline control | System prompt → retrieval → synthesis prompt. Pure software pattern, no new packages. |

**No New Packages Required**

**Multi-Step Prompt Pipeline Pattern:**
```r
# Step 1: Retrieval prompt (find relevant conclusions)
system_prompt_1 <- "You are a research synthesis assistant. Extract conclusion-related content."
chunks <- search_similar_chunks(con, notebook_id, query, top_k = 10)

# Step 2: Synthesis prompt (generate conclusion with disclaimers)
system_prompt_2 <- "Based on retrieved research, synthesize conclusions and future directions. Include heavy disclaimers about AI limitations."
conclusion <- chat_with_openrouter(
  messages = list(
    list(role = "system", content = system_prompt_2),
    list(role = "user", content = paste("Research excerpts:", paste(chunks$text, collapse = "\n\n")))
  ),
  model = "anthropic/claude-3.5-sonnet"
)
```

**RAG Evolution Context (2026):**
- **Agentic RAG:** LLM decides when to retrieve (not in scope for v2.1 — fixed pipeline sufficient)
- **Self-correcting retrieval:** Iterative refinement (not needed — single synthesis step)
- **StepBack prompting:** Abstract then reason (consider for quality improvement)

**Confidence:** HIGH
- **Sources:** [Prompt Engineering for RAG Pipelines](https://www.stack-ai.com/blog/prompt-engineering-for-rag-pipelines-the-complete-guide-to-prompt-engineering-for-retrieval-augmented-generation), [RAG in 2026](https://www.techment.com/blogs/rag-in-2026/), [Prompting Guide RAG](https://www.promptingguide.ai/techniques/rag)
- **Evidence:** Existing `rag.R` implements semantic search. OpenRouter supports all models. Multi-step = sequential calls (already done in chat loops).

---

### 3. Progress Modal with Cancellation Support

**Requirement:** Modal dialog showing progress for long-running citation network builds, with "Stop" button to cancel.

**Stack Decision:** **Shiny modalDialog + ExtendedTask + interrupt pattern**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Shiny modalDialog** | Built-in (1.11.1) | Modal UI container | Native Shiny modal system. Already used for exports in `mod_search_notebook.R`. |
| **Shiny ExtendedTask** | Built-in (≥1.8.1) | Async task management | Native async support (replaces older future+promises patterns). Queues invocations, non-blocking UI. |
| **promises** | 1.3.3 | Promise objects | Already installed. Required by ExtendedTask for async return values. |
| **future** | 1.67.0 | Background execution | Already installed. Used with ExtendedTask via `future_promise()`. |

**No New Packages Required**

**Cancellation Pattern (Manual Interrupt):**
```r
# ExtendedTask does NOT have built-in cancel() method (as of Shiny 1.11.1)
# Workaround: Use reactive flag + periodic checks in task code

# In module server
cancel_flag <- reactiveVal(FALSE)

task <- ExtendedTask$new(function(seed_id, depth, limit) {
  future_promise({
    # Check cancel flag periodically during BFS traversal
    for (hop in 1:depth) {
      if (isolate(cancel_flag())) stop("Cancelled by user")
      # ... fetch citations ...
    }
  })
})

# Cancel button in modal
observeEvent(input$cancel_btn, {
  cancel_flag(TRUE)
  removeModal()
})

# Show modal with progress updates
showModal(modalDialog(
  title = "Building Citation Network",
  uiOutput(ns("progress_text")),
  footer = actionButton(ns("cancel_btn"), "Stop", class = "btn-danger")
))
```

**Alternative Considered:** `shinybusy::modal_progress()`
- **Why NOT:** Another dependency for minimal UX gain. Native modalDialog + ExtendedTask sufficient.

**Confidence:** MEDIUM
- **Sources:** [ExtendedTask reference](https://rstudio.github.io/shiny/reference/ExtendedTask.html), [Mastering Shiny User Feedback](https://mastering-shiny.org/action-feedback.html), [Long Running Tasks with Shiny](https://www.r-bloggers.com/2018/07/long-running-tasks-with-shiny-challenges-and-solutions/), [Async Programming with ExtendedTask](https://rtask.thinkr.fr/parallel-and-asynchronous-programming-in-shiny-with-future-promise-future_promise-and-extendedtask/)
- **Evidence:** ExtendedTask exists in Shiny 1.11.1, but lacks native cancel() method (confirmed in docs). Manual interrupt flag is standard workaround. Already using promises/future in project.
- **Limitation:** ExtendedTask queues tasks but doesn't expose cancel() API. Must implement manual interrupt checks in task code.

---

### 4. UI Icons and Favicon

**Requirement:** Consistent synthesis icons throughout UI + custom favicon for browser tabs.

#### A. Inline Icons (Throughout UI)

**Stack Decision:** **Continue using existing Shiny icon() system (Font Awesome)**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Shiny icon()** | Built-in | Font Awesome icons | Already used extensively (25+ icon() calls in app.R). No changes needed. |
| **Font Awesome** | Free set | Icon library | Default Shiny icon library. 2000+ icons available. |

**Current Usage:**
```r
icon("book-open")              # App title
icon("file-pdf")               # Document notebooks
icon("magnifying-glass")       # Search notebooks
icon("diagram-project")        # Citation networks
icon("seedling")               # Seed discovery
icon("wand-magic-sparkles")    # Query builder
icon("compass")                # Topic explorer
icon("gear"), icon("dollar-sign"), icon("info-circle")  # Sidebar links
```

**For Synthesis Features:**
```r
icon("lightbulb")              # Conclusion synthesis button
icon("list-check")             # Future directions
icon("file-lines")             # Export synthesis
```

**Alternative Considered:** `bsicons` package (0.1.2)
- **Why NOT:** Experimental lifecycle, minimal advantage over Font Awesome (already integrated). Bootstrap Icons overlap significantly with FA free set.
- **When to use:** If need specific Bootstrap-only icons not in Font Awesome (unlikely for synthesis features).

**Confidence:** HIGH
- **Sources:** Existing codebase (25+ icon() calls), [Shiny icon() docs](https://shiny.posit.co/r/reference/shiny/0.14/icon.html), [Font Awesome gallery](https://fontawesome.com/icons), [bsicons GitHub](https://github.com/rstudio/bsicons)
- **Evidence:** Font Awesome already provides all needed icons. No gaps identified.

#### B. Favicon (Browser Tab Icon)

**Stack Decision:** **Manual HTML tag OR favawesome package (optional)**

| Approach | Complexity | Pros | Cons |
|----------|-----------|------|------|
| **Manual HTML** | Low | Zero dependencies, full control, standard practice | Requires icon file creation/hosting |
| **favawesome package** | Medium | Font Awesome icons as favicons, no file management | Adds dependency, experimental quality |

**Manual HTML Approach (Recommended):**
```r
# In app.R ui definition, inside tags$head()
tags$head(
  tags$link(rel = "icon", type = "image/png", href = "favicon.png"),
  tags$link(rel = "apple-touch-icon", sizes = "180x180", href = "apple-touch-icon.png")
  # ... existing styles ...
)

# Create favicon.png and place in www/ folder
# www/favicon.png (32x32 or 64x64 PNG)
```

**favawesome Package Approach (Optional):**
```r
# Install: install.packages("favawesome")
library(favawesome)

# In app.R ui definition
ui <- page_sidebar(
  title = ...,
  favawesome::fa_favicon("book-open", fill = "#6366f1")  # Uses Font Awesome icon
)
```

**Favicon Requirements (2026 Standards):**
- **Minimum:** 32x32 PNG with `<link rel="icon">` tag
- **Recommended:** 32x32 + 180x180 for Apple touch icon
- **Format:** PNG (modern browsers), SVG (progressive enhancement)

**Confidence:** HIGH
- **Sources:** [R golem favicon docs](https://thinkr-open.github.io/golem/reference/favicon.html), [favawesome CRAN](https://cran.r-project.org/web/packages/favawesome/favawesome.pdf), [Favicon best practices 2026](https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs)
- **Evidence:** Manual HTML is standard web practice. Shiny places www/ files at root path automatically. favawesome is experimental but functional alternative.

---

## Existing Stack (No Changes)

These packages **already installed** handle all v2.1 features:

| Technology | Version | New Use Case in v2.1 |
|------------|---------|----------------------|
| **Shiny** | 1.11.1 | sliderInput for year range, modalDialog for progress, ExtendedTask for async |
| **promises** | 1.3.3 | Async task handling with ExtendedTask |
| **future** | 1.67.0 | Background execution for citation network builds |
| **bslib** | 0.9.0 | UI layout (cards, sidebar) for new features |
| **DuckDB** | Existing | Store year range filters in search configs |
| **OpenRouter** | Existing | LLM inference for multi-step synthesis prompts |
| **igraph** | Existing | Already used for citation networks (v2.0) |
| **visNetwork** | Existing | Already used for citation networks (v2.0) — year filter applies to nodes |
| **viridisLite** | Existing | Color palettes (may use for histogram year distribution) |

**Confidence:** HIGH
- **Sources:** Verified via `Rscript -e "packageVersion('shiny')"` → 1.11.1, promises 1.3.3, future 1.67.0
- **Evidence:** All packages validated in v2.0 milestone. No new capabilities required.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **histoslider** | React.js dependency, experimental maturity, minimal value over native sliderInput | Native Shiny sliderInput + histogram overlay |
| **shinybusy** | Adds dependency for modal progress when native modalDialog sufficient | Shiny modalDialog + ExtendedTask |
| **bsicons** | Experimental lifecycle, no advantage over existing Font Awesome | Continue using Shiny icon() with Font Awesome |
| **New LLM API clients** | OpenRouter already supports all models (Claude, GPT-4, Gemini) | Existing `api_openrouter.R` |
| **Separate RAG frameworks** | Over-engineered for v2.1 scope (fixed retrieval pipeline sufficient) | Existing `rag.R` + prompt engineering |

---

## Integration Points

### Year Range Slider → Existing Filters

**Where:** `mod_search_notebook.R`, `mod_citation_network.R`

**Pattern:** Add to existing filter chain (keyword → journal quality → year range → display)

```r
# In mod_search_notebook.R server
filtered_papers <- reactive({
  papers <- all_papers()

  # Existing filters
  papers <- apply_keyword_filter(papers, included, excluded)
  papers <- apply_journal_filter(papers, blocked_journals, hide_predatory)

  # NEW: Year range filter
  year_range <- input$year_range
  if (!is.null(year_range)) {
    papers <- papers[papers$year >= year_range[1] & papers$year <= year_range[2], ]
  }

  papers
})
```

### Multi-Step Synthesis → Existing RAG

**Where:** `mod_search_notebook.R`, `mod_document_notebook.R`

**Pattern:** Reuse `search_similar_chunks()` + new synthesis prompt

```r
# In mod_search_notebook.R or mod_document_notebook.R
observeEvent(input$generate_conclusion, {
  # Step 1: Retrieve conclusion-relevant chunks
  query <- "conclusions, findings, future directions, limitations"
  chunks <- search_similar_chunks(con(), notebook_id, query, top_k = 15)

  # Step 2: Synthesis prompt with disclaimers
  system_prompt <- "Based on the research excerpts below, synthesize a conclusion section with future research directions. IMPORTANT: Include heavy disclaimers that this is AI-generated and requires expert validation."

  result <- chat_with_openrouter(
    messages = list(
      list(role = "system", content = system_prompt),
      list(role = "user", content = paste("Research excerpts:\n\n", paste(chunks$text, collapse = "\n\n---\n\n")))
    ),
    model = selected_model(),
    api_key = api_key()
  )

  # Display in UI with warning badges
})
```

### Progress Modal → Existing Citation Network

**Where:** `mod_citation_network.R` (already has progress_callback parameter)

**Pattern:** Replace existing `withProgress()` with modalDialog + ExtendedTask

```r
# Current (v2.0): withProgress() with inline callback
withProgress(message = "Fetching citation network...", {
  network <- fetch_citation_network(seed_id, email, api_key, progress_callback = progress_cb)
})

# New (v2.1): modalDialog + ExtendedTask with cancellation
showModal(modalDialog(
  title = "Building Citation Network",
  textOutput(ns("progress_text")),
  footer = tagList(
    actionButton(ns("cancel_btn"), "Stop", class = "btn-danger"),
    modalButton("Close")
  ),
  easyClose = FALSE
))

network_task$invoke(seed_id, email, api_key)
```

---

## Installation Commands

**No new packages required for core features.**

**Optional (favicon only):**
```r
# If using favawesome package instead of manual HTML
install.packages("favawesome")
```

**Verify existing packages:**
```r
packageVersion("shiny")     # Should be >= 1.8.1 for ExtendedTask (currently 1.11.1)
packageVersion("promises")  # 1.3.3
packageVersion("future")    # 1.67.0
```

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Shiny 1.11.1 | promises 1.3.3 | ExtendedTask requires promises for async returns |
| Shiny 1.11.1 | future 1.67.0 | ExtendedTask works with future via `future_promise()` |
| Shiny 1.11.1 | bslib 0.9.0 | Full compatibility, native theme integration |

**No version conflicts anticipated.**

---

## Architectural Decisions

### Why NOT histoslider?

**Reasoning:**
1. **Dependency cost:** Adds React.js htmlwidget for minimal UX improvement over native sliderInput
2. **Maturity:** Version 0.1.1, last updated July 2025, limited CRAN documentation
3. **Already solved:** Shiny sliderInput handles year ranges natively. Histogram overlay is simple R graphics.
4. **Scope creep:** v2.1 needs basic year filtering, not synchronized brush-and-zoom interaction

**When to reconsider:** If future milestone needs interactive histogram brushing where slider updates based on histogram selection (advanced interaction pattern).

### Why NOT new RAG framework?

**Reasoning:**
1. **Existing capabilities sufficient:** `rag.R` already implements semantic search with embeddings
2. **Scope fit:** v2.1 synthesis is fixed pipeline (retrieve → synthesize), not agentic RAG (LLM-decides-when-to-retrieve)
3. **Prompt engineering over packages:** Multi-step prompts = sequential API calls. Pure software pattern, no packages needed.
4. **OpenRouter flexibility:** Already supports all frontier models. No need for model-specific clients.

**When to reconsider:** If v3.0+ adds agentic RAG (LLM decides retrieval strategy), self-correcting retrieval loops, or multi-modal document understanding.

### Why ExtendedTask over shinybusy?

**Reasoning:**
1. **Native first:** ExtendedTask built into Shiny 1.8.1+, designed for async tasks
2. **Already using promises/future:** ExtendedTask integrates with existing stack
3. **shinybusy adds dependency:** For marginal UX gain (spinner themes)
4. **Cancellation limitation:** ExtendedTask lacks native cancel() method, BUT shinybusy doesn't solve this either (both require manual interrupt pattern)

**When to reconsider:** If need fancy spinner themes or overlay effects (not in v2.1 scope).

---

## Open Questions & Risks

### 1. ExtendedTask Cancellation Workaround

**Issue:** ExtendedTask has no built-in `cancel()` method (as of Shiny 1.11.1). Must implement manual interrupt flag.

**Risk:** If citation network fetch is blocking in C code (e.g., httr2 request), interrupt flag won't be checked until R code resumes.

**Mitigation:**
- Use `timeout` parameter on httr2 requests (allows cancellation at HTTP layer)
- Check interrupt flag after each API call in BFS traversal loop (not during single blocking call)
- Document in UI that "Stop" may take 5-10 seconds (completes current API request)

### 2. Year Range Histogram Rendering Performance

**Issue:** Rendering histogram overlay for 1000+ papers on every slider drag may cause lag.

**Risk:** Janky UI if histogram recalculates on every pixel of slider movement.

**Mitigation:**
- Use `debounce()` on year range input (500ms delay before updating histogram)
- Pre-compute histogram bins on paper load, only re-filter on slider change (not re-render entire histogram)
- Consider static background image histogram (update only on data refresh, not slider movement)

### 3. Multi-Step Synthesis Token Costs

**Issue:** Conclusion synthesis requires 2x API calls (retrieval prompt + synthesis prompt), doubling token costs.

**Risk:** User surprise at cost increase compared to single chat message.

**Mitigation:**
- Show estimated token count BEFORE generating conclusion (count retrieval context + prompt)
- Display warning: "This synthesis will use ~X tokens ($Y estimated)"
- Track in cost log as separate operation type ("synthesis" vs "chat")

---

## Sources

### High Confidence (Official Docs)
- [Shiny sliderInput Reference](https://shiny.posit.co/r/reference/shiny/0.14/sliderinput.html)
- [Shiny Slider Range Component](https://shiny.posit.co/r/components/inputs/slider-range/)
- [ExtendedTask API Reference](https://rstudio.github.io/shiny/reference/ExtendedTask.html)
- [Promises with Shiny Guide](https://rstudio.github.io/promises/articles/shiny.html)
- [Mastering Shiny: User Feedback](https://mastering-shiny.org/action-feedback.html)
- [Font Awesome Icons](https://fontawesome.com/icons)
- [bsicons GitHub](https://github.com/rstudio/bsicons)

### Medium Confidence (CRAN + Community)
- [histoslider CRAN Package](https://cran.r-project.org/package=histoslider)
- [favawesome CRAN Package](https://cran.r-project.org/web/packages/favawesome/favawesome.pdf)
- [Long Running Tasks with Shiny](https://www.r-bloggers.com/2018/07/long-running-tasks-with-shiny-challenges-and-solutions/)
- [Async Programming with ExtendedTask](https://rtask.thinkr.fr/parallel-and-asynchronous-programming-in-shiny-with-future-promise-future_promise-and-extendedtask/)

### RAG Architecture (Context Only)
- [Prompt Engineering for RAG Pipelines 2026](https://www.stack-ai.com/blog/prompt-engineering-for-rag-pipelines-the-complete-guide-to-prompt-engineering-for-retrieval-augmented-generation)
- [RAG in 2026](https://www.techment.com/blogs/rag-in-2026/)
- [Prompting Guide: RAG Techniques](https://www.promptingguide.ai/techniques/rag)

### Favicon Standards
- [Favicon Best Practices 2026](https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs)
- [Favicon.io Generator](https://favicon.io/)

---

*Stack research for: Serapeum v2.1 Polish & Analysis*
*Researched: 2026-02-13*
*Researcher: Claude (GSD Phase 6: Research)*
