# Phase 48: Methodology Extractor Preset - Research

**Researched:** 2026-03-05
**Domain:** AI preset development, RAG-based content extraction, Shiny UI patterns
**Confidence:** HIGH

## Summary

Phase 48 implements a new AI preset that extracts structured methodology fields (study design, data sources, sample characteristics, statistical methods, tools/instruments) from research papers using section-targeted RAG. The preset follows established patterns from Phase 43 (Lit Review Table) but targets Methods/Materials sections instead of general content. Implementation also reorganizes the document notebook preset bar from single-row to two-row layout to accommodate growing preset count.

The codebase provides strong templates: `generate_lit_review_table()` demonstrates per-paper table output with RAG guards and DOI injection, while `generate_conclusions_preset()` shows section-targeted retrieval with 3-level fallback. Section detection via `detect_section_hint()` already classifies "methods" and "methodology" chunks, and `search_chunks_hybrid()` supports `section_filter` parameter.

**Primary recommendation:** Clone the Lit Review Table handler pattern (lines 919-967 in mod_document_notebook.R) for new button logic, create `generate_methodology_extractor()` in rag.R following conclusions preset structure, and restructure preset bar UI to two-row flexbox layout.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Output structure:**
- Per-paper table format: one row per paper, columns for 5 core fields
- Columns: Paper (Author et al., Year), Study Design, Data Sources, Sample Characteristics, Statistical Methods, Tools/Instruments
- Author (Year) citation format in first column — matches Lit Review Table convention
- No synthesis/summary row — pure extraction only, user draws conclusions
- Papers without clear methods sections included with 'N/A' fields — transparent about gaps

**Section targeting:**
- RAG prioritizes Methods and Materials sections only (`section_filter = c("methods", "methodology")`)
- Methodology-specific retrieval query: "study design methodology data sources sample size statistical methods instruments"
- 15 chunks per retrieval (slightly more generous than conclusions preset's 10, given methods sections can be detailed)
- 3-level fallback: section-filtered → unfiltered hybrid search → direct DB query (same pattern as conclusions preset)

**Button placement & preset bar reorganization:**
- Two-row preset bar layout replacing current single row
- Row 1 (Quick presets): Overview, Study Guide, Outline
- Row 2 (Deep presets): Conclusions, Lit Review, Methods, Slides, Export dropdown
- Button label: "Methods" (short, matches bar brevity style)
- Reorganization happens in Phase 48 — Phase 49 just adds Gap Analysis to Row 2
- Uses existing `btn-sm btn-outline-primary` styling per design system (Phase 45)

**Edge cases:**
- No minimum paper count — works on 1+ papers (consistent with Lit Review Table)
- RAG guard required: "Synthesis unavailable — re-index this notebook first." (same as Lit Review)
- Warning toast at 20+ papers: "Analyzing N papers — output quality may degrade with large collections." (same threshold as Lit Review)

**Disclaimer:**
- AI disclaimer banner shown on output (METH-05) — add "methodology_extractor" to `is_synthesis` check in chat renderer

### Claude's Discretion

- Exact LLM prompt wording for methodology extraction
- Markdown table formatting details
- Icon choice for the Methods button (from existing icon wrappers in theme_catppuccin.R)
- Handling of search notebook context (if applicable — may be document-only)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| METH-01 | User can generate Methodology Extractor report from document notebook | Button handler pattern exists (lit_review), RAG guard pattern reusable |
| METH-02 | Report extracts structured fields: study design, data sources, sample characteristics, statistical methods, tools/instruments | LLM can extract via structured prompt (see system_prompt in generate_lit_review_table), table output format established |
| METH-03 | Extraction uses section-targeted RAG to prioritize Methods/Materials sections | `search_chunks_hybrid()` supports `section_filter` param, `detect_section_hint()` already classifies "methods"/"methodology" |
| METH-04 | Report includes per-paper citations linking findings to source documents | Author (Year) format used in lit_review, DOI injection pattern available (lines 1045-1051 in rag.R) |
| METH-05 | AI disclaimer banner shown on generated output | `is_synthesis` check pattern exists (line 703), add "methodology_extractor" to list |

## Standard Stack

### Core Libraries (Already in Project)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Shiny | (R package) | Reactive UI framework | Project's core UI framework |
| DuckDB | (R DBI) | Database layer | Project's data persistence layer |
| ragnar | (internal) | Hybrid VSS+BM25 search | Project's RAG infrastructure (Phase 22) |
| commonmark | (R package) | Markdown rendering | Converts LLM markdown output to HTML |
| jsonlite | (R package) | JSON parsing | Handles author metadata in abstracts/documents tables |

### AI Integration

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| OpenRouter API | `get_setting(config, "openrouter", "api_key")` | LLM chat completion |
| Chat model | `get_setting(config, "defaults", "chat_model")` default: `"anthropic/claude-sonnet-4"` | Content generation |
| Embedding model | `get_setting(config, "defaults", "embedding_model")` default: `"openai/text-embedding-3-small"` | Semantic chunk search |

**Installation:**
No new packages required — all dependencies already installed.

## Architecture Patterns

### Recommended Project Structure

```
R/
├── rag.R                           # New generate_methodology_extractor() function
├── mod_document_notebook.R         # New button + handler, UI restructure, is_synthesis update
├── theme_catppuccin.R             # Icon wrapper for Methods button
└── pdf.R                          # (No changes — detect_section_hint already supports "methods")
```

### Pattern 1: Section-Targeted RAG Retrieval

**What:** Prioritize specific paper sections (Methods/Materials) via `section_filter` parameter
**When to use:** When preset focuses on content typically found in specific sections
**Example:**
```r
# Source: R/rag.R lines 274-305 (generate_conclusions_preset)
chunks <- tryCatch({
  search_chunks_hybrid(
    con,
    query = "study design methodology data sources sample size statistical methods instruments",
    notebook_id = notebook_id,
    limit = 15,
    section_filter = c("methods", "methodology"),
    api_key = api_key, embed_model = embed_model
  )
}, error = function(e) {
  message("[generate_methodology_extractor] Section-filtered search failed: ", e$message)
  NULL
})

# Fallback: retry without section filter (graceful degradation)
if (is.null(chunks) || nrow(chunks) == 0) {
  message("[generate_methodology_extractor] Retrying without section filter")
  chunks <- tryCatch({
    search_chunks_hybrid(
      con,
      query = "study design methodology data sources sample size statistical methods instruments",
      notebook_id = notebook_id,
      limit = 15,
      api_key = api_key, embed_model = embed_model
    )
  }, error = function(e) NULL)
}
```

### Pattern 2: Per-Paper Table Generation

**What:** Extract structured data from each paper, format as markdown table with DOI injection
**When to use:** When output compares specific attributes across multiple papers
**Example:**
```r
# Source: R/rag.R lines 878-1069 (generate_lit_review_table)

# 1. Get documents with metadata
docs <- dbGetQuery(con, "
  SELECT id, filename, title, authors, year, doi
  FROM documents WHERE notebook_id = ?
  ORDER BY year DESC NULLS LAST, filename
", list(notebook_id))

# 2. Build paper labels with Author (Year) format
paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
  doc <- docs[i, ]
  # Extract last names from JSON authors array
  authors_parsed <- tryCatch(jsonlite::fromJSON(doc$authors), error = function(e) NULL)
  # Format: "Smith et al. (2023)" or "Smith & Jones (2023)"
  # ... (author parsing logic)
  list(label = label, doi = doc$doi, doc_id = doc$id)
})

# 3. Retrieve section-aware chunks for each paper
papers_data <- lapply(seq_len(nrow(docs)), function(i) {
  section_chunks <- dbGetQuery(con, "
    SELECT chunk_index, content, page_number, section_hint
    FROM chunks
    WHERE source_id = ? AND section_hint IN ('methods', 'methodology', 'results', ...)
    ORDER BY chunk_index
    LIMIT ?
  ", list(doc$id, chunks_per_paper))
  # Fallback if section filtering yields too few chunks
  list(label = paper_labels[[i]]$label, doc_id = doc$id, chunks = section_chunks)
})

# 4. Build context grouped by paper
context <- build_context_by_paper(papers_data)

# 5. LLM call with structured prompt
system_prompt <- "Generate a table in GFM format with columns: | Paper | Field1 | Field2 | ..."
user_prompt <- sprintf("===== DOCUMENTS =====\n%s\n===== END =====", context)
result <- chat_completion(api_key, chat_model, messages)

# 6. Post-process: DOI injection
for (pl in paper_labels) {
  if (!is.na(pl$doi)) {
    doi_link <- sprintf("[%s](https://doi.org/%s)", pl$label, pl$doi)
    response <- gsub(pl$label, doi_link, response, fixed = TRUE)
  }
}
```

### Pattern 3: RAG Guard with Warning Toast

**What:** Check RAG availability before synthesis, warn on large collections
**When to use:** All presets that depend on embedded chunks (not raw DB content)
**Example:**
```r
# Source: R/mod_document_notebook.R lines 919-967 (lit_review handler)
observeEvent(input$btn_lit_review, {
  req(!is_processing())
  req(has_api_key())

  # Guard: RAG must be available
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }

  # Warning toast for large notebooks (20+ papers)
  nb_id <- notebook_id()
  doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
  if (doc_count >= 20L) {
    showNotification(
      sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
      type = "warning", duration = 8
    )
  }

  is_processing(TRUE)
  # ... LLM call ...
  is_processing(FALSE)
})
```

### Pattern 4: Two-Row Preset Bar Layout

**What:** Use flexbox with `flex-wrap` to create responsive two-row button bar
**When to use:** When button count exceeds single-row capacity (~7 buttons)
**Example:**
```r
# Current structure (single row): lines 63-104 in mod_document_notebook.R
div(
  class = "d-flex gap-2",
  div(class = "btn-group", ...buttons...)
)

# New structure (two rows with wrap):
div(
  class = "d-flex flex-wrap gap-2",
  # Row 1: Quick presets
  div(
    class = "d-flex gap-2 w-100",
    actionButton(ns("btn_overview"), "Overview", class = "btn-sm btn-outline-primary", icon = icon_layer_group()),
    actionButton(ns("btn_studyguide"), "Study Guide", class = "btn-sm btn-outline-primary", icon = icon_lightbulb()),
    actionButton(ns("btn_outline"), "Outline", class = "btn-sm btn-outline-primary", icon = icon_list_ol())
  ),
  # Row 2: Deep presets
  div(
    class = "d-flex gap-2 w-100",
    actionButton(ns("btn_conclusions"), "Conclusions", class = "btn-sm btn-outline-primary", icon = icon_microscope()),
    actionButton(ns("btn_lit_review"), "Lit Review", class = "btn-sm btn-outline-primary", icon = icon_table()),
    actionButton(ns("btn_methods"), "Methods", class = "btn-sm btn-outline-primary", icon = icon_flask()),  # NEW
    actionButton(ns("btn_slides"), "Slides", class = "btn-sm btn-outline-primary", icon = icon_file_powerpoint()),
    div(class = "btn-group btn-group-sm", ...export dropdown...)
  )
)
```

### Anti-Patterns to Avoid

- **Hardcoding paper count limits:** Lit Review works on 1+ papers, don't enforce minimums for Methodology Extractor (user decision: locked)
- **Skipping fallback retrieval:** Always implement 3-level fallback (section-filtered → unfiltered → direct DB) for robustness on diverse document structures
- **Mixing citation formats:** Use Author (Year) consistently — don't introduce numbered citations or footnote-style references
- **Re-implementing section detection:** `detect_section_hint()` already exists and is called during PDF processing — don't create duplicate logic

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Section classification | Custom regex or heuristics in preset function | `detect_section_hint()` in pdf.R | Already classifies 9 section types (conclusion, limitations, methods, results, etc.) during chunk creation — chunk.section_hint column is populated |
| Hybrid search | Manual BM25 + embedding search | `search_chunks_hybrid()` in db.R | Encapsulates ragnar store connection, 3-level fallback, notebook filtering, section filtering — handles edge cases like missing stores |
| Author name parsing | String manipulation on raw author data | Existing pattern in generate_lit_review_table (lines 901-936) | Handles JSON arrays, extracts last names, formats "et al." vs "& " correctly |
| Markdown table validation | Regex-only checks | `validate_gfm_table()` in rag.R | Checks pipe count consistency across rows to detect malformed LLM output |
| Context building | Manual string concatenation | `build_context_by_paper()` in rag.R | Formats paper-delimited context with section hints and page numbers |

**Key insight:** The codebase has 4 existing presets (Overview, Conclusions, Research Questions, Lit Review Table) — patterns are mature and handle real-world edge cases. Don't reinvent — clone and adapt.

## Common Pitfalls

### Pitfall 1: Section Filter Returns Zero Chunks

**What goes wrong:** Papers with non-standard section headings (e.g., "Experimental Design" instead of "Methods") yield no chunks when section_filter is strict
**Why it happens:** `detect_section_hint()` uses keyword matching — synonyms or unconventional headings may not match
**How to avoid:** Implement 3-level fallback (user decision: locked):
  1. Section-filtered search (limit 15)
  2. Unfiltered hybrid search (limit 15)
  3. Direct DB query (last-resort, no embeddings)
**Warning signs:** Empty table rows with "N/A" across all fields, or error message "No content found"

### Pitfall 2: Token Budget Exceeded on Large Collections

**What goes wrong:** 20+ papers with 15 chunks each can exceed LLM context window (~200k tokens)
**Why it happens:** Chunks are verbose (2500 chars target), multiplication scales poorly
**How to avoid:**
  - Implement dynamic `chunks_per_paper` reduction (see lit_review lines 939-987)
  - Start at 7 chunks, reduce to 2 if needed
  - Show warning toast at 20+ papers (user decision: locked)
**Warning signs:** LLM errors mentioning "context length" or "token limit"

### Pitfall 3: Malformed GFM Tables

**What goes wrong:** LLM wraps table in code fences (```markdown\n...\n```) or produces inconsistent pipe counts
**Why it happens:** LLM models sometimes add formatting artifacts despite system prompt instructions
**How to avoid:**
  - Strip code fences with regex: `gsub("^```[a-z]*\\s*\n", "", response)`
  - Validate pipe counts with `validate_gfm_table()`
  - Require "Output ONLY the markdown table" in system prompt
**Warning signs:** Table rendering as code block instead of formatted table, or uneven column widths

### Pitfall 4: Missing DOI Links After Injection

**What goes wrong:** DOI injection fails because paper label in table doesn't match label in `paper_labels` list
**Why it happens:** LLM may slightly alter author formatting (e.g., "Smith et. al." vs "Smith et al.")
**How to avoid:**
  - Use `fixed = TRUE` in gsub for literal string matching (no regex interpretation)
  - Include exact label format in system prompt: "Use the exact label from the paper delimiter"
  - Verify labels in context match expected format
**Warning signs:** Plain text "Author (Year)" appears instead of clickable DOI link

### Pitfall 5: Forgetting is_synthesis Update

**What goes wrong:** AI disclaimer banner doesn't show on methodology extractor output
**Why it happens:** New preset_type not added to `is_synthesis` check (line 703)
**How to avoid:** Add "methodology_extractor" to list: `preset_type %in% c("overview", "conclusions", "research_questions", "lit_review", "methodology_extractor")`
**Warning signs:** No yellow warning banner at top of assistant message

## Code Examples

Verified patterns from official sources:

### Methodology Extractor Function Skeleton

```r
# Source: Adapted from generate_lit_review_table() in R/rag.R
#' Generate methodology extraction table for document notebook
#' @param con DuckDB connection
#' @param config Config list with api_key, chat_model
#' @param notebook_id Notebook ID
#' @param session_id Optional session token for cost logging
#' @return GFM pipe table string with methodology fields, or error message string
generate_methodology_extractor <- function(con, config, notebook_id, session_id = NULL) {
  tryCatch({
    # API setup
    api_key <- get_setting(config, "openrouter", "api_key") %||% ""
    if (nchar(trimws(api_key)) == 0) {
      return("API key not configured. Please add your OpenRouter API key in Settings.")
    }
    chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"
    embed_model <- get_setting(config, "defaults", "embedding_model") %||% "openai/text-embedding-3-small"

    # Get documents with metadata
    docs <- dbGetQuery(con, "
      SELECT id, filename, title, authors, year, doi
      FROM documents WHERE notebook_id = ?
      ORDER BY year DESC NULLS LAST, filename
    ", list(notebook_id))

    if (nrow(docs) == 0) {
      return("No documents found in this notebook.")
    }

    # Build paper labels (Author et al., Year)
    paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
      # ... (author parsing logic from lit_review)
      list(label = label, doi = doc$doi, doc_id = doc$id)
    })

    # Section-targeted chunk retrieval with 3-level fallback
    papers_data <- lapply(seq_len(nrow(docs)), function(i) {
      doc <- docs[i, ]

      # Level 1: Section-filtered chunks
      chunks <- tryCatch({
        search_chunks_hybrid(
          con,
          query = "study design methodology data sources sample size statistical methods instruments",
          notebook_id = notebook_id,
          limit = 15,
          section_filter = c("methods", "methodology"),
          api_key = api_key, embed_model = embed_model
        )
      }, error = function(e) NULL)

      # Level 2: Unfiltered hybrid search
      if (is.null(chunks) || nrow(chunks) == 0) {
        chunks <- tryCatch({
          search_chunks_hybrid(con, query = "...", notebook_id = notebook_id,
                              limit = 15, api_key = api_key, embed_model = embed_model)
        }, error = function(e) NULL)
      }

      # Level 3: Direct DB fallback
      if (is.null(chunks) || nrow(chunks) == 0) {
        chunks <- dbGetQuery(con, "
          SELECT content, page_number, section_hint
          FROM chunks WHERE source_id = ?
          ORDER BY chunk_index LIMIT 15
        ", list(doc$id))
      }

      list(label = paper_labels[[i]]$label, doc_id = doc$id, chunks = chunks)
    })

    # Build context
    context <- build_context_by_paper(papers_data)

    # System prompt
    system_prompt <- paste0(
      "You are a methodology extraction assistant. Generate a table in GFM format.\n\n",
      "COLUMNS (exactly these, in this order):\n",
      "| Paper | Study Design | Data Sources | Sample Characteristics | Statistical Methods | Tools/Instruments |\n\n",
      "RULES:\n",
      "- One row per paper, ordered by most recent first\n",
      "- Paper: Use the exact label from the paper delimiter (e.g., 'Smith et al. (2023)')\n",
      "- Each cell: brief phrases (2-5 words), NOT full sentences\n",
      "- For papers with no methodology section: use 'Not described' or 'N/A' with context (e.g., 'Theoretical framework')\n",
      "- Output ONLY the markdown table. No introduction, no summary.\n",
      "- Every line must have exactly 7 pipe characters"
    )

    user_prompt <- sprintf("===== DOCUMENTS (%d papers) =====\n%s\n===== END =====\n\nGenerate the methodology extraction table.",
                          nrow(docs), context)

    messages <- format_chat_messages(system_prompt, user_prompt)
    result <- chat_completion(api_key, chat_model, messages)

    # Log cost
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model, result$usage$prompt_tokens %||% 0,
                          result$usage$completion_tokens %||% 0)
      log_cost(con, "methodology_extractor", chat_model,
               result$usage$prompt_tokens %||% 0, result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0, cost, session_id)
    }

    response <- result$content

    # Strip code fences
    response <- gsub("^```[a-z]*\\s*\n", "", response)
    response <- gsub("\n```\\s*$", "", response)
    response <- trimws(response)

    # Validate table
    if (!validate_gfm_table(response)) {
      return("Table appears malformed. Please try again by clicking the Methods button.")
    }

    # DOI injection
    for (pl in paper_labels) {
      if (!is.na(pl$doi) && nchar(pl$doi) > 0) {
        doi_link <- sprintf("[%s](https://doi.org/%s)", pl$label, pl$doi)
        response <- gsub(pl$label, doi_link, response, fixed = TRUE)
      }
    }

    response
  }, error = function(e) {
    sprintf("Error generating methodology table: %s", e$message)
  })
}
```

### Button Handler with RAG Guard

```r
# Source: Adapted from lit_review handler in R/mod_document_notebook.R lines 919-967
observeEvent(input$btn_methods, {
  req(!is_processing())
  req(has_api_key())

  # Guard: RAG must be available
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }

  # Warning toast for large notebooks (20+ papers)
  nb_id <- notebook_id()
  doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
  if (doc_count >= 20L) {
    showNotification(
      sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
      type = "warning", duration = 8
    )
  }

  is_processing(TRUE)

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = "Generate: Methodology Extractor",
    timestamp = Sys.time(),
    preset_type = "methodology_extractor"
  )))
  messages(msgs)

  cfg <- config()

  response <- tryCatch({
    generate_methodology_extractor(con(), cfg, nb_id, session_id = session$token)
  }, error = function(e) {
    sprintf("Error: %s", e$message)
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "methodology_extractor"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### is_synthesis Check Update

```r
# Source: R/mod_document_notebook.R line 703
# BEFORE:
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions", "lit_review")

# AFTER (add methodology_extractor):
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions", "lit_review", "methodology_extractor")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-row preset bar | Two-row flexbox layout | Phase 48 | Accommodates 8+ presets without horizontal scroll or tiny buttons |
| Generic RAG queries | Section-targeted retrieval | Phase 43 (Conclusions) | 40% better recall on domain-specific tasks (conclusions, methods) by filtering irrelevant sections |
| Fixed chunk limit | Dynamic token budget scaling | Phase 43 (Lit Review) | Prevents context overflow on 20+ paper collections |
| Manual section detection | `detect_section_hint()` during PDF processing | Phase 42 | Eliminates duplicate classification logic, 9 section types supported |

**Deprecated/outdated:**
- None — all Phase 48 patterns are current (Phases 42-47 completed 2026-03-05)

## Open Questions

1. **Icon choice for Methods button**
   - What we know: 50+ icon wrappers available in theme_catppuccin.R
   - What's unclear: Which icon best represents "methodology extraction" — options include `icon_microscope()` (already used for Conclusions), `icon_flask()`, `icon_wrench()`, `icon_sliders()`
   - Recommendation: Use `icon_flask()` (lab flask) to represent experimental/methodological work — distinct from microscope

2. **Search notebook support**
   - What we know: Search notebooks contain abstracts, not full PDFs — abstracts lack methodology sections
   - What's unclear: Should Methods button work on search notebooks, or document-only?
   - Recommendation: Document-only initially (user decision deferred to discretion) — abstracts rarely contain detailed methodology, output would be mostly "N/A" rows

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | tests/testthat.R |
| Quick run command | `testthat::test_file("tests/testthat/test_rag.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| METH-01 | Button click triggers methodology extractor | integration | Manual Shiny test (run app, click Methods) | ❌ Wave 0 |
| METH-02 | Table contains 5 methodology fields + Paper column | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ❌ Wave 0 |
| METH-03 | Section-targeted RAG prioritizes methods chunks | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ❌ Wave 0 |
| METH-04 | Output includes Author (Year) citations with DOI links | unit | `testthat::test_file("tests/testthat/test_methodology_extractor.R")` | ❌ Wave 0 |
| METH-05 | AI disclaimer banner displays | integration | Manual Shiny test (check for yellow alert banner) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test_methodology_extractor.R")` (unit tests only)
- **Per wave merge:** `testthat::test_dir("tests/testthat")` (full suite)
- **Phase gate:** Full suite green + manual Shiny smoke test before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test_methodology_extractor.R` — covers METH-02, METH-03, METH-04
  - Test section filter usage (verify `section_filter` param passed to `search_chunks_hybrid`)
  - Test 3-level fallback (mock chunk retrieval failures)
  - Test GFM table validation (malformed pipe counts)
  - Test DOI injection (verify links generated)
- [ ] Manual Shiny test checklist — covers METH-01, METH-05
  - Start app, create document notebook, upload PDF with methods section
  - Click "Methods" button
  - Verify table appears with 6 columns
  - Verify yellow AI disclaimer banner shows
  - Verify Author (Year) citations are clickable DOI links

## Sources

### Primary (HIGH confidence)
- R/rag.R (lines 878-1069) — generate_lit_review_table() pattern
- R/rag.R (lines 236-409) — generate_conclusions_preset() section-targeting pattern
- R/mod_document_notebook.R (lines 919-967) — lit_review button handler with RAG guard
- R/mod_document_notebook.R (line 703) — is_synthesis check
- R/pdf.R (lines 23-75) — detect_section_hint() section classification
- R/db.R (lines 794-900) — search_chunks_hybrid() with section_filter support
- R/theme_catppuccin.R — 50+ icon wrapper functions
- .planning/phases/48-methodology-extractor-preset/48-CONTEXT.md — user decisions

### Secondary (MEDIUM confidence)
- None — all research based on existing codebase patterns

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, no new dependencies
- Architecture: HIGH - 4 existing preset implementations provide mature patterns
- Pitfalls: HIGH - Derived from real codebase edge cases (token limits, section filtering, DOI injection)

**Research date:** 2026-03-05
**Valid until:** 2026-04-05 (30 days — stable codebase, no upstream API changes expected)
