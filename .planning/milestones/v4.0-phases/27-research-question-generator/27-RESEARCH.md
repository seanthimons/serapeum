# Phase 27: Research Question Generator - Research

**Researched:** 2026-02-19
**Domain:** LLM-driven research gap analysis, R/Shiny UI wiring, RAG retrieval
**Confidence:** HIGH

## Summary

Phase 27 adds a "Research Questions" button to the search notebook's chat panel preset bar. When clicked, it calls a new `generate_research_questions()` function in `rag.R` that retrieves paper content via the existing hybrid RAG pipeline, sends it to the LLM with a carefully structured prompt, and returns a numbered markdown list of research questions with inline rationales citing specific papers.

The implementation is straightforward because it follows the exact pattern established by `generate_conclusions_preset()` (Phase 26). The function signature, data retrieval, prompt construction, cost logging, error handling, and UI wiring all have direct precedents. The primary engineering challenge is prompt design: getting the LLM to reliably produce gap-grounded questions with proper author/year citations, adaptive framework selection, and scaled question counts.

**Primary recommendation:** Clone the `generate_conclusions_preset()` pattern for both the backend function and UI wiring. Start with RAG retrieval (simpler, already proven). The prompt is the only novel component.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
1. **PICO Framing Style:** Natural language questions with PICO guiding the prompt invisibly. Adaptive framing (PICO/PEO/SPIDER/freeform). No intro paragraph. 5-7 questions for 5+ papers, 3-4 for 2-3 papers.
2. **Gap-to-Question Grounding:** Cite specific papers by author/year in each rationale. 2-3 sentence rationale inline under each question. All relevant papers named when gap spans multiple.
3. **Data Source Strategy:** Full papers (PDF-chunked content). Defer RAG vs SQL to implementation, start simpler. Metadata included (title + year + authors). Separate function `generate_research_questions()` -- NOT added to `generate_preset()`.
4. **Question Diversity & Coverage:** Strongest gaps with diversity hint. Ordered by gap type. No scope note. Scale to collection size.

### Deferred Ideas (OUT OF SCOPE)
None identified during discussion.
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R/Shiny + bslib | existing | UI framework | Already in use |
| DuckDB | existing | Local database | Already in use |
| OpenRouter API | existing | LLM chat completion | Already in use |
| ragnar | existing | Hybrid VSS+BM25 retrieval | Already in use for search notebooks |
| commonmark | existing | Markdown rendering in chat | Already in use |

### Supporting
No new libraries needed. This phase uses only existing dependencies.

## Architecture Patterns

### Pattern 1: Separate Preset Function (like `generate_conclusions_preset`)

**What:** A standalone function in `rag.R` with its own prompt, retrieval strategy, and cost logging category.

**When to use:** Always for this phase -- the CONTEXT.md explicitly requires a separate function.

**Example (skeleton following `generate_conclusions_preset` at rag.R:237-393):**

```r
# Source: /home/sean/Documents/serapeum/R/rag.R lines 237-393 (conclusions pattern)
generate_research_questions <- function(con, config, notebook_id, notebook_type = "search", session_id = NULL) {
  # 1. Extract API settings (identical to generate_conclusions_preset)
  api_key <- get_setting(config, "openrouter", "api_key")
  chat_model <- get_setting(config, "defaults", "chat_model") %||% "anthropic/claude-sonnet-4"

  # 2. Validate API key (identical pattern)

  # 3. Get paper count to determine question range
  paper_count <- dbGetQuery(con, "SELECT COUNT(*) as cnt FROM abstracts WHERE notebook_id = ?", list(notebook_id))$cnt[1]

  # 4. Get paper metadata for citation info
  paper_metadata <- dbGetQuery(con, "
    SELECT id, title, authors, year FROM abstracts WHERE notebook_id = ?
  ", list(notebook_id))

  # 5. Retrieve chunks via search_chunks_hybrid (RAG approach)
  chunks <- search_chunks_hybrid(
    con,
    query = "research gaps limitations future work methodology population understudied",
    notebook_id = notebook_id,
    limit = 15  # More chunks for comprehensive gap analysis
  )

  # 6. Build context with build_context()
  # 7. Construct prompt with paper metadata + adaptive framing
  # 8. Call chat_completion, log cost, return response
}
```

### Pattern 2: UI Button Wiring (search notebook preset bar)

**What:** Add a "Research Questions" button alongside the existing "Conclusions" button in the offcanvas chat panel.

**Where:** The preset buttons live in `mod_search_notebook.R` at lines 247-253. Currently only `conclusions_btn_ui` is rendered there.

**Key detail:** The `conclusions_btn_ui` renderUI (line 565) handles both enabled/disabled states based on `rag_available()`. The Research Questions button needs the same pattern.

**Example:**
```r
# In UI (mod_search_notebook.R ~line 250-253), change:
#   uiOutput(ns("conclusions_btn_ui"))
# To include both buttons:
#   uiOutput(ns("conclusions_btn_ui")),
#   uiOutput(ns("research_questions_btn_ui"))

# In server, add renderUI for the new button:
output$research_questions_btn_ui <- renderUI({
  if (isTRUE(rag_available())) {
    actionButton(ns("btn_research_questions"), "Research Questions",
                 class = "btn-sm btn-outline-primary",
                 icon = icon("lightbulb"))
  } else {
    tags$button(
      class = "btn btn-sm btn-outline-primary disabled",
      disabled = "disabled",
      title = "Synthesis unavailable - re-index this notebook first",
      icon("lightbulb"), " Research Questions"
    )
  }
})
```

### Pattern 3: Preset Handler in Server (message queue pattern)

**What:** The observeEvent handler that adds user/assistant messages to the reactive message list.

**Source:** `mod_search_notebook.R` lines 2312-2344 (conclusions handler).

**Key details:**
- Adds a user message with `preset_type` field (used for AI disclaimer rendering)
- Calls the generate function
- Adds assistant response with same `preset_type`
- The `preset_type` value triggers the AI-Generated Content disclaimer in the message renderer (line 2233: `is_synthesis <- !is.null(msg$preset_type) && identical(msg$preset_type, "conclusions")`)

**Important:** The disclaimer check currently only fires for `preset_type == "conclusions"`. It needs to also fire for `"research_questions"`. Update the check to: `!is.null(msg$preset_type) && msg$preset_type %in% c("conclusions", "research_questions")`.

### Pattern 4: Paper Metadata Enrichment for Citations

**What:** The LLM needs author/year data to generate proper citations. RAG chunks from ragnar have `content` and `origin` fields but no author/year metadata directly. The function must query the `abstracts` table separately.

**How authors are stored:** JSON array in `abstracts.authors` column (e.g., `["Smith, J.", "Jones, A."]`). See `create_abstract` at db.R:406.

**Approach:** Query all abstracts for the notebook, parse authors JSON, format as "LastName et al. (Year)" strings, and include this metadata block in the prompt alongside the RAG context.

```r
# Get paper metadata for prompt enrichment
papers <- dbGetQuery(con, "
  SELECT id, title, authors, year FROM abstracts WHERE notebook_id = ?
", list(notebook_id))

# Format citation-ready paper list for the prompt
paper_refs <- vapply(seq_len(nrow(papers)), function(i) {
  authors <- tryCatch(jsonlite::fromJSON(papers$authors[i]), error = function(e) character())
  author_str <- if (length(authors) == 0) "Unknown"
    else if (length(authors) > 2) paste0(authors[1], " et al.")
    else paste(authors, collapse = " & ")
  sprintf("- %s (%s): \"%s\"", author_str, papers$year[i] %||% "n.d.", papers$title[i])
}, character(1))

paper_list_text <- paste(paper_refs, collapse = "\n")
```

### Anti-Patterns to Avoid
- **Adding to `generate_preset()` switch statement:** CONTEXT.md explicitly forbids this. The function needs its own retrieval strategy and prompt.
- **Hardcoding PICO labels in output:** PICO guides the prompt but must NOT appear in the output text.
- **Vague citations:** The prompt must instruct the LLM to cite "Smith et al. (2023)" not "the literature" or "previous studies."

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hybrid search retrieval | Custom vector search | `search_chunks_hybrid()` | Already handles ragnar stores, section filtering, notebook scoping |
| Context formatting | Custom chunk formatter | `build_context()` | Handles doc_name, abstract_title, page numbers |
| Chat message formatting | Custom message builder | `format_chat_messages()` | Handles system/user/history message structure |
| Markdown rendering | Custom HTML builder | `commonmark::markdown_html()` | Already used in chat renderer |
| Cost logging | Custom tracking | `log_cost()` + `estimate_cost()` | Standard pattern in all LLM calls |

## Common Pitfalls

### Pitfall 1: Paper Count Detection for Scaling

**What goes wrong:** The question count range (3-4 vs 5-7) depends on paper count, but `nrow(chunks)` != paper count. Chunks are sub-paper fragments.
**Why it happens:** RAG retrieval returns chunks, not papers. A notebook with 3 papers might return 10 chunks.
**How to avoid:** Query `abstracts` table directly for paper count: `SELECT COUNT(*) FROM abstracts WHERE notebook_id = ?`
**Warning signs:** Getting 5-7 questions for a 2-paper notebook.

### Pitfall 2: Author Metadata Not in RAG Chunks

**What goes wrong:** RAG chunks from ragnar contain `content`, `origin`, `doc_name`/`abstract_title` but NOT author names or years. If you only pass chunks, the LLM cannot generate "Smith et al. (2023)" citations.
**Why it happens:** Ragnar stores content + embeddings, not full metadata.
**How to avoid:** Query `abstracts` table separately for author/year data and include as a metadata block in the prompt.
**Warning signs:** LLM output says "the first paper" or "Paper 1" instead of author/year citations.

### Pitfall 3: AI Disclaimer Only Shows for "conclusions"

**What goes wrong:** The chat message renderer checks `msg$preset_type == "conclusions"` to show the AI-generated content warning. A new preset type won't trigger it.
**Why it happens:** The check is hardcoded to one string value.
**How to avoid:** Update the check in both `mod_search_notebook.R` (line 2233) and `mod_document_notebook.R` (line 600) to accept a set of synthesis preset types.
**Warning signs:** Research questions appear without the yellow warning banner.

### Pitfall 4: Prompt Too Long for Large Notebooks

**What goes wrong:** A notebook with 50+ papers could produce an enormous prompt if all chunks are included.
**Why it happens:** `search_chunks_hybrid` with `limit = 15` returns 15 chunks, but the paper metadata list could be large.
**How to avoid:** Cap the retrieval. 15 chunks is reasonable. For the metadata block, include all papers (they're just one line each -- 50 papers = ~50 lines of metadata, trivial).
**Warning signs:** API errors for token limit exceeded.

### Pitfall 5: Search Notebook Has Abstracts, Not PDFs

**What goes wrong:** CONTEXT.md says "Full papers (PDF-chunked content)" but search notebooks typically contain abstracts, not full PDFs.
**Why it happens:** Search notebooks import from OpenAlex which provides abstracts. PDF-chunked content is in document notebooks.
**How to avoid:** The function should work with whatever content is in the ragnar store. For search notebooks, this will be abstracts. For document notebooks (if ever exposed there), it would be full PDFs. The RAG query handles this transparently -- `search_chunks_hybrid` returns chunks regardless of source type.
**Warning signs:** None -- this is by design. The "full papers" decision means "use the richest content available," which for search notebooks is abstracts.

### Pitfall 6: Empty Notebook Edge Case

**What goes wrong:** User clicks Research Questions on a notebook with 0-1 papers.
**Why it happens:** Button is visible even when notebook has no content.
**How to avoid:** Early return with helpful message: "At least 2 papers are needed to identify research gaps." The button could also be disabled when paper count < 2, but the early return in the function is simpler and sufficient.

## Code Examples

### Complete Prompt Structure

```r
# System prompt (PICO-guided but invisible in output)
system_prompt <- "You are a research gap analyst. Your task is to identify gaps in the existing research and generate focused research questions.

INSTRUCTIONS:
1. Analyze the provided research sources to identify gaps, contradictions, and unexplored areas
2. Generate research questions that address the most significant gaps
3. For each question, provide a 2-3 sentence rationale citing specific papers by author name and year
4. Use an appropriate research framework internally (PICO for clinical/health topics, PEO for qualitative, SPIDER for mixed methods, or freeform for other domains) but do NOT label or mention the framework in your output
5. Group questions by gap type (methodological, population/sample, temporal, theoretical, etc.)
6. Prioritize the strongest/most significant gaps; vary gap types when possible

OUTPUT FORMAT:
- Numbered list of questions, each followed by an indented rationale
- No introductory paragraph or scope note
- Each rationale MUST name specific papers by 'Author et al. (Year)' format
- When a gap spans multiple papers, name ALL relevant papers

SCALING:
- For collections of 2-3 papers: generate 3-4 questions
- For collections of 5+ papers: generate 5-7 questions

IMPORTANT: Base analysis ONLY on the provided sources. Do not invent findings. Every claim in a rationale must trace to a specific source."

# User prompt structure
user_prompt <- sprintf(
  '===== PAPER METADATA =====
%s

===== RETRIEVED CONTENT =====
%s
===== END SOURCES =====

Analyze the research above and generate research questions that address identified gaps.',
  paper_list_text,
  context
)
```

### Expected Output Format

```markdown
1. How does [intervention X] affect [outcome Y] in [population Z] over periods longer than 12 months?

   Smith et al. (2023) demonstrated short-term efficacy of X but their study was limited to 6 months. Jones & Lee (2022) noted similar temporal constraints, calling for longitudinal follow-up to assess sustained effects.

2. What methodological approaches can address the measurement inconsistencies in [domain]?

   Chen et al. (2024) used self-report measures while Park et al. (2023) relied on clinical assessment, producing divergent findings on the same construct. Neither study compared measurement approaches directly.
```

### Handler Wiring (complete)

```r
# In server function:
observeEvent(input$btn_research_questions, {
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }
  req(!is_processing())
  req(has_api_key())
  is_processing(TRUE)

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = "Generate: Research Questions",
    timestamp = Sys.time(),
    preset_type = "research_questions"
  )))
  messages(msgs)

  nb_id <- notebook_id()
  cfg <- config()

  response <- tryCatch({
    generate_research_questions(con(), cfg, nb_id, notebook_type = "search", session_id = session$token)
  }, error = function(e) {
    if (inherits(e, "api_error")) {
      show_error_toast(e$message, e$details, e$severity)
    } else {
      err <- classify_api_error(e, "OpenRouter")
      show_error_toast(err$message, err$details, err$severity)
    }
    "Sorry, I encountered an error generating research questions."
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "research_questions"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### Disclaimer Check Update

```r
# In message renderer (both mod_search_notebook.R and mod_document_notebook.R):
# Change from:
is_synthesis <- !is.null(msg$preset_type) && identical(msg$preset_type, "conclusions")
# To:
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("conclusions", "research_questions")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `generate_preset()` for all types | Separate functions per synthesis type | Phase 26 | Each synthesis type gets its own retrieval strategy and prompt |
| Global ragnar store | Per-notebook ragnar stores | Phase 22 | `search_chunks_hybrid` handles per-notebook routing |

## Open Questions

1. **RAG query string for gap detection**
   - What we know: `generate_conclusions_preset` uses "conclusions limitations future work research gaps directions" as its RAG query
   - What's unclear: Whether a different query string would retrieve better chunks for gap identification specifically
   - Recommendation: Start with "research gaps limitations future work methodology population understudied contradictions" and iterate based on output quality. This is easily tuned.

2. **Chunk limit for comprehensive gap analysis**
   - What we know: `rag_query` uses limit=5, `generate_conclusions_preset` uses limit=10
   - What's unclear: Whether 10-15 chunks is sufficient for identifying diverse gaps across many papers
   - Recommendation: Start with limit=15 (retrieves 30 from ragnar, filters to 15). This balances coverage with prompt length. Adjust if output quality suffers.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `R/rag.R` (generate_conclusions_preset pattern, lines 237-393)
- Direct codebase inspection: `R/mod_search_notebook.R` (UI layout lines 247-253, button rendering 564-578, handler 2312-2344, disclaimer 2233)
- Direct codebase inspection: `R/db.R` (abstracts schema lines 59-74, list_abstracts 568-584, search_chunks_hybrid 698-807)
- Direct codebase inspection: `R/api_openrouter.R` (format_chat_messages line 23)

### Secondary (MEDIUM confidence)
- Phase context: 27-CONTEXT.md decisions and constraints

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, all existing libraries
- Architecture: HIGH - Direct clone of generate_conclusions_preset pattern
- Pitfalls: HIGH - Identified from actual code inspection of data flow
- Prompt design: MEDIUM - LLM prompt quality requires empirical testing

**Research date:** 2026-02-19
**Valid until:** 2026-03-19 (stable codebase, no external dependency changes)
