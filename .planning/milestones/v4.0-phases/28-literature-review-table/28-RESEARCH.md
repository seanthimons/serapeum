# Phase 28: Literature Review Table - Research

**Researched:** 2026-02-19
**Domain:** LLM-driven structured extraction, GFM table generation, document notebook UI, section-aware RAG
**Confidence:** HIGH

## Summary

Phase 28 adds a "Lit Review" button to the document notebook's preset button bar. When clicked, it queries chunks from all documents in the notebook grouped by source_id, prioritizing section hints for methodology/results/limitations/discussion, sends them to the LLM in a single call with per-paper delimiters, and returns a GFM markdown comparison table. The table renders in the chat panel with Bootstrap styling, horizontal scroll, sticky headers, and a frozen first column.

The core engineering work is: (1) a new `build_context_by_paper()` function that groups chunks under paper delimiters rather than flat listing, (2) a new `generate_lit_review_table()` function with section-aware SQL retrieval and dynamic token budgeting, (3) post-LLM validation via regex pipe-count checking, (4) server-side DOI injection matching Author/Year rows to document metadata, and (5) CSS for the scrollable table with frozen first column.

A critical finding: the `documents` table has NO `doi`, `authors`, `year`, or `title` fields beyond `filename`. Document notebooks store only filename, filepath, full_text, and page_count. For the Author/Year column with DOI links, we either need to extract metadata from the PDF content itself (via the LLM) or add metadata columns to the documents table. The CONTEXT.md decision to "inject DOIs server-side from metadata" requires metadata that does not currently exist in the documents table schema. This is the primary open question.

**Primary recommendation:** Follow the `generate_conclusions_preset()` pattern for the function skeleton. The new `build_context_by_paper()` is the key novel component. For document metadata (author/year/DOI), use an LLM-extracted approach where the table's Author/Year column comes from LLM analysis of document content (since documents table lacks structured metadata), with no DOI injection for documents that lack it.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **Cell Content & Format:** Brief phrases per cell (2-5 words), contextual N/A notes, Author/Year column with DOI links (DOIs injected server-side), Key Findings as single consolidated statement, reverse chronological ordering
2. **Data Retrieval Strategy:** Document notebook (full PDFs), section-aware SQL per paper prioritizing section_hint IN ('methodology', 'results', 'limitations', 'discussion'), fallback distributed chunk sampling, dynamic token budget starting at 7 chunks/paper, single LLM call with per-paper delimiters, new build_context_by_paper() function
3. **Paper Volume Handling:** No row cap, warning toast at 20+ papers, minimum 1 paper, token budget check before LLM call with graceful refusal
4. **Rendering & Visual Treatment:** Horizontal scroll container, Bootstrap table-striped + table-bordered, sticky column headers, frozen first column, GFM markdown table as primary format
5. **Malformed Output Recovery:** Broken table shows error with "Try Again" button, regex pipe-count validation, missing rows render partial table with note, DOI injection server-side post-processing

### Key Constraints
- Output renders in chat panel with AI-generated content disclaimer
- Button appears in document notebook preset panel
- Must work with pre-migration data where section_hint may be NULL
- Export via existing chat export mechanism (Markdown or HTML)
- GFM markdown tables per SYNTH-02 decision

### Deferred Ideas (OUT OF SCOPE)
- Two-stage extraction (first LLM pass for raw notes, second for table formatting) -- deferred due to 2x cost
- Search notebook variant using abstracts -- future phase
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R/Shiny + bslib | existing | UI framework | Already in use |
| DuckDB | existing | Local database, chunk/document queries | Already in use |
| OpenRouter API | existing | LLM chat completion | Already in use |
| commonmark | existing | GFM markdown to HTML rendering | Already in use, supports `extensions = TRUE` for tables |

### Supporting
No new libraries needed. This phase uses only existing dependencies.

### Key Note on commonmark
`commonmark::markdown_html(text, extensions = TRUE)` converts GFM pipe tables to HTML `<table>` elements. The `extensions = TRUE` flag is already used in the chat renderer (mod_document_notebook.R line 613). The existing `.chat-markdown table` CSS in app.R (lines 83-89) already styles these tables with borders and padding.

## Architecture Patterns

### Pattern 1: Document Notebook Preset Button Bar (Static Buttons)

**What:** The document notebook uses static `actionButton()` calls directly in the UI function, NOT dynamic `renderUI`/`uiOutput` like the search notebook. All preset buttons (Summarize, Key Points, Study Guide, Outline, Conclusions, Slides) are hardcoded in a `btn-group` div.

**Where:** `mod_document_notebook.R` lines 46-64.

**Key difference from search notebook:** The search notebook uses `uiOutput(ns("conclusions_btn_ui"))` with a `renderUI` that checks `rag_available()` for enabling/disabling. The document notebook just places all buttons statically and guards in the handler instead.

**How to add the Lit Review button:**
```r
# In mod_document_notebook.R UI, add to the btn-group div (around line 64):
actionButton(ns("btn_lit_review"), "Lit Review",
             class = "btn-sm btn-outline-primary",
             icon = icon("table-cells"))
```

### Pattern 2: Preset Handler Pattern (Document Notebook)

**What:** The document notebook has TWO handler patterns:
1. **Generic presets** (summarize, keypoints, studyguide, outline) use `handle_preset()` helper at line 705-726, which calls `generate_preset()` with a preset_type string. These do NOT set `preset_type` on messages (no AI disclaimer).
2. **Conclusions preset** (line 734-755) has its own `observeEvent` that calls `generate_conclusions_preset()` directly and sets `preset_type = "conclusions"` on both user and assistant messages.

**The Lit Review button needs pattern #2** -- a dedicated `observeEvent` calling a dedicated function, with `preset_type = "lit_review"` for the AI disclaimer.

```r
# Handler pattern (follows conclusions at line 734):
observeEvent(input$btn_lit_review, {
  req(!is_processing())
  req(has_api_key())

  # Guard: RAG must be available
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }

  is_processing(TRUE)

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = "Generate: Literature Review Table",
    timestamp = Sys.time(),
    preset_type = "lit_review"
  )))
  messages(msgs)

  nb_id <- notebook_id()
  cfg <- config()

  response <- tryCatch({
    generate_lit_review_table(con(), cfg, nb_id, session_id = session$token)
  }, error = function(e) {
    sprintf("Error: %s", e$message)
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "lit_review"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### Pattern 3: AI Disclaimer Check

**What:** The disclaimer check at line 600 already uses `%in%` for multiple preset types.

**Current code:**
```r
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("conclusions", "research_questions")
```

**Update needed:** Add `"lit_review"` to the vector:
```r
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("conclusions", "research_questions", "lit_review")
```

### Pattern 4: build_context_by_paper() -- New Function

**What:** Groups chunks under per-paper delimiters with metadata headers. Unlike `build_context()` which flat-lists all chunks with source labels, this groups by source_id.

**Design:**
```r
build_context_by_paper <- function(papers_with_chunks) {
  # Input: list of lists, each with:
  #   $filename, $doc_id, $chunks (data frame with content, page_number, section_hint)
  # Output: single string with delimiters

  sections <- vapply(papers_with_chunks, function(paper) {
    chunk_texts <- vapply(seq_len(nrow(paper$chunks)), function(i) {
      sprintf("[p.%d, %s] %s",
              paper$chunks$page_number[i],
              paper$chunks$section_hint[i],
              paper$chunks$content[i])
    }, character(1))

    sprintf("=== PAPER: %s ===\n%s",
            paper$filename,
            paste(chunk_texts, collapse = "\n\n"))
  }, character(1))

  paste(sections, collapse = "\n\n")
}
```

### Pattern 5: Section-Aware SQL Retrieval per Paper

**What:** Query chunks grouped by source_id, prioritizing section hints relevant to lit review extraction.

**SQL pattern for section-aware retrieval:**
```sql
-- Get chunks for a specific document, section-prioritized
SELECT c.id, c.source_id, c.chunk_index, c.content, c.page_number, c.section_hint
FROM chunks c
WHERE c.source_id = ?
  AND c.section_hint IN ('methods', 'results', 'limitations', 'discussion', 'conclusion')
ORDER BY c.chunk_index
LIMIT ?
```

**Fallback for no section hits (distributed sampling):**
```sql
-- Distributed sampling: beginning + middle + end
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (ORDER BY chunk_index) as rn,
         COUNT(*) OVER () as total
  FROM chunks WHERE source_id = ?
) sub
WHERE rn <= 2                    -- first 2 chunks
   OR rn >= total - 1            -- last 2 chunks
   OR rn = CAST(total/2 AS INT)  -- middle chunk
LIMIT ?
```

### Pattern 6: Dynamic Token Budget

**What:** Start at 7 chunks per paper, reduce if total exceeds threshold.

**Token estimation:** No existing token estimation function exists in the codebase. Use the standard heuristic of `nchar(text) / 4` as approximate token count (English text averages ~4 chars per token).

```r
estimate_tokens <- function(text) {
  ceiling(nchar(text) / 4)
}

# Budget logic:
max_context_tokens <- 80000  # Conservative for most models
chunks_per_paper <- 7L
paper_count <- length(doc_ids)

# Iteratively reduce if over budget
repeat {
  total_est <- sum(vapply(all_chunks, function(ch) {
    estimate_tokens(paste(ch$content, collapse = " "))
  }, numeric(1)))

  if (total_est <= max_context_tokens || chunks_per_paper <= 2L) break
  chunks_per_paper <- chunks_per_paper - 1L
  # Re-query with reduced limit...
}
```

### Anti-Patterns to Avoid
- **Using `build_context()` directly:** It flat-lists chunks without paper grouping. The LLM needs paper delimiters to produce a per-paper row table.
- **Trusting LLM for DOIs:** CONTEXT.md explicitly forbids this. DOIs must be injected server-side.
- **Using `generate_preset()` switch statement:** This needs its own function like conclusions/research questions.
- **Querying ragnar store instead of SQL:** For this use case, we need per-paper grouped chunks with section hints. Direct SQL on the chunks table is more appropriate than hybrid search, since we want ALL papers represented (not just the most semantically relevant).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GFM to HTML conversion | Custom table parser | `commonmark::markdown_html(text, extensions = TRUE)` | Already used, handles pipe tables |
| Chat message rendering | Custom HTML builder | Existing message renderer in mod_document_notebook.R | Already handles markdown, disclaimers |
| Cost logging | Custom tracking | `log_cost()` + `estimate_cost()` | Standard pattern |
| Chat message format | Custom message structure | `format_chat_messages()` | Existing API wrapper |
| Table CSS styling | Custom CSS framework | `.chat-markdown table` CSS already in app.R | Already styles borders, padding, headers |

## Common Pitfalls

### Pitfall 1: Documents Table Has No Author/Year/DOI Metadata

**What goes wrong:** CONTEXT.md requires "Author/Year column with DOI links, DOIs injected server-side from metadata." But the `documents` table schema is: `id, notebook_id, filename, filepath, full_text, page_count, created_at`. No title, authors, year, or DOI fields exist.
**Why it happens:** Document notebooks were designed for PDF upload with minimal metadata. Structured metadata lives only on the `abstracts` table (search notebooks).
**How to avoid:** Two options:
1. Let the LLM extract Author/Year from document content (it will see the paper text). DOI injection is skipped for documents without metadata. Add a note: "DOI links unavailable for uploaded PDFs."
2. (Better long-term) Add optional metadata columns to documents table, but this is scope creep for Phase 28.
**Recommendation:** Option 1 -- let LLM handle Author/Year extraction from content. Skip DOI injection for this phase. The filename serves as a fallback identifier.
**Warning signs:** Empty Author/Year cells or placeholder text.

### Pitfall 2: Section Hints May Be NULL for Pre-Migration Data

**What goes wrong:** Older documents indexed before the section_hint migration will have NULL section_hint values. The SQL `WHERE section_hint IN (...)` will exclude these chunks entirely.
**Why it happens:** section_hint was added in a migration; existing chunks weren't backfilled.
**How to avoid:** Always include a fallback path. If section-filtered query returns fewer than N chunks per paper, fall back to distributed sampling (beginning + middle + end chunks).
**Warning signs:** Papers with 0 chunks retrieved despite having content.

### Pitfall 3: Flat RAG Search Misses Papers

**What goes wrong:** Using `search_chunks_hybrid()` (semantic search) may return chunks from only 2-3 papers even when 10 papers exist. Semantic relevance doesn't guarantee coverage of all papers.
**Why it happens:** Hybrid search ranks by relevance, not coverage. Some papers may have no chunks in the top-k results.
**How to avoid:** Use direct SQL queries grouped by source_id (document ID), NOT ragnar hybrid search. Iterate over each document's chunks explicitly to guarantee every paper is represented.
**Warning signs:** Table has fewer rows than papers in notebook.

### Pitfall 4: GFM Table Malformation

**What goes wrong:** LLM produces a table with inconsistent pipe counts, missing delimiters, or merged cells. `commonmark` silently renders broken tables as plain text.
**Why it happens:** LLMs sometimes omit pipes, add extra columns, or wrap lines.
**How to avoid:** Regex pipe-count validation post-LLM. Check that every non-empty line in the table section has the same number of `|` characters.
**Validation pattern:**
```r
validate_gfm_table <- function(text) {
  lines <- strsplit(text, "\n")[[1]]
  # Find table lines (contain pipes)
  table_lines <- lines[grepl("\\|", lines)]
  table_lines <- trimws(table_lines)
  table_lines <- table_lines[nchar(table_lines) > 0]

  if (length(table_lines) < 3) return(FALSE)  # Need header + separator + at least 1 row

  pipe_counts <- vapply(table_lines, function(l) {
    nchar(gsub("[^|]", "", l))
  }, integer(1))

  # All lines should have same pipe count
  length(unique(pipe_counts)) == 1
}
```
**Warning signs:** Table renders as plain text in chat instead of formatted table.

### Pitfall 5: Horizontal Scroll CSS Conflicts

**What goes wrong:** Adding `overflow-x: auto` to the table wrapper may conflict with the existing `.chat-markdown table { width: 100% }` CSS, causing the table to not scroll and instead compress columns.
**Why it happens:** `width: 100%` forces the table to fit the container rather than overflow.
**How to avoid:** For lit review tables specifically, use a wrapper div with `overflow-x: auto` and set `min-width` on the table to force it wider than the container. The frozen first column requires `position: sticky; left: 0;` CSS on the first `td`/`th`.
**Warning signs:** Table columns are too narrow to read; first column scrolls away.

### Pitfall 6: Single LLM Call Token Limits

**What goes wrong:** With many papers (20+), the combined context exceeds the model's context window.
**Why it happens:** 7 chunks x 20 papers x ~500 chars/chunk = ~70,000 chars = ~17,500 tokens just for context, plus prompt and response.
**How to avoid:** Dynamic token budget with iterative reduction. Start at 7 chunks/paper, reduce to minimum 2. If still over budget at 2 chunks/paper, refuse with clear message: "Too many documents for a single analysis. Consider splitting into smaller groups."
**Warning signs:** API errors for token limit exceeded, or truncated/incomplete responses.

### Pitfall 7: Retry Button Needs State Management

**What goes wrong:** The "Try Again" button on malformed output needs to re-trigger the same generation, but the handler has already completed.
**Why it happens:** Shiny observeEvent fires once per input change.
**How to avoid:** Include the retry button as part of the assistant message content (as an actionButton rendered via `tagList`), or simpler: render the malformed output with a note and let the user click the main "Lit Review" button again. The simpler approach aligns with how other presets handle errors (just return an error string).
**Recommendation:** Return an error message string with instructions: "The generated table appears malformed. Please try again by clicking the Lit Review button." No special retry button needed -- keep it simple.

## Code Examples

### Complete generate_lit_review_table() Skeleton

```r
# Source: follows generate_conclusions_preset pattern (rag.R:237-393)
generate_lit_review_table <- function(con, config, notebook_id, session_id = NULL) {
  # 1. Extract API settings (identical to conclusions pattern)
  api_key <- get_setting(config, "openrouter", "api_key")
  if (length(api_key) > 1) api_key <- api_key[1]
  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
  if (length(chat_model) > 1) chat_model <- chat_model[1]

  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
                   (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured.")
  }

  # 2. Get all documents in this notebook
  docs <- list_documents(con, notebook_id)
  if (nrow(docs) == 0) {
    return("No documents found in this notebook.")
  }

  # 3. Warning toast for 20+ papers (handled in UI handler, not here)
  paper_count <- nrow(docs)

  # 4. Retrieve chunks per paper with section prioritization
  chunks_per_paper <- 7L
  max_context_tokens <- 80000L

  papers_data <- lapply(seq_len(nrow(docs)), function(i) {
    doc <- docs[i, ]

    # Try section-filtered first
    section_chunks <- dbGetQuery(con, "
      SELECT chunk_index, content, page_number, section_hint
      FROM chunks
      WHERE source_id = ? AND section_hint IN ('methods', 'results', 'limitations', 'discussion', 'conclusion')
      ORDER BY chunk_index
      LIMIT ?
    ", list(doc$id, chunks_per_paper))

    if (nrow(section_chunks) < 2) {
      # Fallback: distributed sampling
      section_chunks <- dbGetQuery(con, "
        SELECT chunk_index, content, page_number,
               COALESCE(section_hint, 'general') as section_hint
        FROM chunks WHERE source_id = ?
        ORDER BY chunk_index
      ", list(doc$id))

      if (nrow(section_chunks) > chunks_per_paper) {
        # Sample: first 2 + middle + last 2
        n <- nrow(section_chunks)
        indices <- unique(c(1, 2, ceiling(n/2), n-1, n))
        indices <- indices[indices >= 1 & indices <= n]
        section_chunks <- section_chunks[head(indices, chunks_per_paper), ]
      }
    }

    list(filename = doc$filename, doc_id = doc$id, chunks = section_chunks)
  })

  # 5. Dynamic token budget -- reduce chunks_per_paper if over limit
  # (implementation: re-query with lower limits if total too large)

  # 6. Build context with per-paper delimiters
  context <- build_context_by_paper(papers_data)

  # 7. Token budget check
  est_tokens <- ceiling(nchar(context) / 4)
  if (est_tokens > max_context_tokens) {
    return(sprintf(
      "The combined document content (%d estimated tokens) exceeds the analysis limit. Consider splitting documents across multiple notebooks.",
      est_tokens
    ))
  }

  # 8. Build prompt
  system_prompt <- "You are a systematic review assistant..."
  user_prompt <- sprintf("===== DOCUMENTS =====\n%s\n===== END =====\n\nGenerate the comparison table.", context)

  messages <- format_chat_messages(system_prompt, user_prompt)

  # 9. Call LLM
  result <- chat_completion(api_key, chat_model, messages)

  # 10. Log cost
  if (!is.null(session_id) && !is.null(result$usage)) {
    cost <- estimate_cost(chat_model,
                          result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
    log_cost(con, "lit_review_table", chat_model,
             result$usage$prompt_tokens %||% 0,
             result$usage$completion_tokens %||% 0,
             result$usage$total_tokens %||% 0,
             cost, session_id)
  }

  # 11. Validate table structure
  response <- result$content
  if (!validate_gfm_table(response)) {
    return("The generated table appears malformed. Please try again by clicking the Lit Review button.")
  }

  response
}
```

### CSS for Frozen First Column and Horizontal Scroll

```css
/* Literature review table: horizontal scroll + frozen first column */
.chat-markdown .lit-review-scroll {
  overflow-x: auto;
  max-width: 100%;
  border: 1px solid #dee2e6;
  border-radius: 0.25rem;
}

.chat-markdown .lit-review-scroll table {
  min-width: 800px;  /* Force horizontal scroll */
  border-collapse: separate;
  border-spacing: 0;
}

.chat-markdown .lit-review-scroll th:first-child,
.chat-markdown .lit-review-scroll td:first-child {
  position: sticky;
  left: 0;
  z-index: 1;
  background-color: #f1f3f5;
  border-right: 2px solid #adb5bd;
}

.chat-markdown .lit-review-scroll thead th {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f1f3f5;
}

.chat-markdown .lit-review-scroll thead th:first-child {
  z-index: 3;  /* Corner cell: both sticky row and column */
}
```

**Implementation note:** Since `commonmark::markdown_html()` outputs a bare `<table>`, the wrapper div must be injected server-side after HTML conversion:
```r
# Post-process: wrap table in scrollable div
html <- commonmark::markdown_html(response, extensions = TRUE)
html <- gsub("<table>", '<div class="lit-review-scroll"><table class="table table-striped table-bordered">', html)
html <- gsub("</table>", "</table></div>", html)
```

### GFM Table Validation

```r
validate_gfm_table <- function(text) {
  lines <- strsplit(text, "\n")[[1]]
  table_lines <- trimws(lines[grepl("\\|", lines)])
  table_lines <- table_lines[nchar(table_lines) > 0]

  if (length(table_lines) < 3) return(FALSE)

  pipe_counts <- vapply(table_lines, function(l) {
    nchar(gsub("[^|]", "", l))
  }, integer(1), USE.NAMES = FALSE)

  length(unique(pipe_counts)) == 1
}
```

### Cost Logging Category

Existing operation categories: `"chat"`, `"conclusion_synthesis"`, `"research_questions"`, `"slide_generation"`, `"query_build"`, `"embedding"`.

Use: `"lit_review_table"` for the new function.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `generate_preset()` for all types | Separate functions per synthesis type | Phase 26 | Each synthesis type gets its own retrieval strategy |
| Flat `build_context()` | Need `build_context_by_paper()` | Phase 28 (new) | Paper-grouped context enables per-paper table rows |
| RAG hybrid search for retrieval | Direct SQL per document for full coverage | Phase 28 (new) | Guarantees every paper is represented in the table |

## Open Questions

1. **Document metadata for Author/Year column**
   - What we know: The `documents` table has only `filename`, `filepath`, `full_text`, `page_count`. No author, year, title, or DOI columns exist.
   - What's unclear: How to reliably get Author/Year for the table's first column without structured metadata.
   - Recommendation: Let the LLM extract author/year from document content (it sees the paper text). Use filename as fallback. Skip DOI injection for Phase 28 -- document notebooks don't store DOIs. If this proves inadequate, a future phase could add metadata extraction during PDF upload.

2. **Wrapper div injection for CSS**
   - What we know: `commonmark::markdown_html()` produces bare `<table>` tags. We need to wrap in a scrollable div with specific classes.
   - What's unclear: Whether to post-process the HTML string with `gsub` or use a custom renderer.
   - Recommendation: Use `gsub` replacement on the HTML string. Simple, reliable, and the pattern is predictable (one `<table>` per response). This is done in the message renderer, NOT in the generate function.

3. **Custom HTML rendering for lit review vs standard markdown**
   - What we know: The message renderer currently does `HTML(commonmark::markdown_html(msg$content, extensions = TRUE))` for all assistant messages.
   - What's unclear: How to selectively apply the scroll wrapper only for lit review messages.
   - Recommendation: Check `msg$preset_type == "lit_review"` in the renderer and apply the wrapper div + class injection only for those messages. This is clean and scoped.

4. **Dark theme support for frozen column**
   - What we know: The app uses bslib with Bootstrap 5 dark theme support. The frozen column's `background-color: #f1f3f5` will look wrong in dark mode.
   - Recommendation: Add `[data-bs-theme="dark"]` variants for the frozen column CSS using dark background colors.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `R/mod_document_notebook.R` (UI layout lines 46-64, preset handlers 704-755, message renderer 555-635, disclaimer check line 600)
- Direct codebase inspection: `R/rag.R` (build_context lines 1-47, generate_conclusions_preset lines 237-393, generate_research_questions lines 407-570)
- Direct codebase inspection: `R/db.R` (documents table schema lines 44-56, chunks table schema lines 77-87, create_chunk with section_hint lines 360-373, search_chunks_hybrid lines 698-856)
- Direct codebase inspection: `R/pdf.R` (detect_section_hint lines 33-75, process_pdf lines 87-133)
- Direct codebase inspection: `R/cost_tracking.R` (estimate_cost line 51, log_cost line 73, operation categories)
- Direct codebase inspection: `app.R` (chat-markdown CSS lines 76-97)
- Direct codebase inspection: `www/custom.css` (existing CSS patterns)
- Direct codebase inspection: `28-CONTEXT.md` (locked decisions)

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` (prior research on lit review table CSS patterns)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, all existing libraries
- Architecture: HIGH - Direct extension of conclusions/research questions pattern with clear code references
- Pitfalls: HIGH - Identified from actual schema inspection (documents table lacks metadata) and code flow analysis
- CSS implementation: MEDIUM - Frozen first column CSS is standard but needs testing with bslib/Bootstrap 5 specifics
- Document metadata gap: HIGH certainty of the problem - documents table confirmed to lack author/year/DOI fields

**Research date:** 2026-02-19
**Valid until:** 2026-03-19 (stable codebase, no external dependency changes)
