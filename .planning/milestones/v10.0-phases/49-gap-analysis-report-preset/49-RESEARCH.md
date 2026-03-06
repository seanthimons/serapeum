# Phase 49: Gap Analysis Report Preset - Research

**Researched:** 2026-03-06
**Domain:** Cross-paper synthesis, Gap identification, LLM-based narrative generation
**Confidence:** HIGH

## Summary

Phase 49 adds a Gap Analysis Report preset that synthesizes methodological and topical gaps across research papers through section-targeted RAG retrieval. The implementation follows the validated patterns from Phase 48 (Methodology Extractor) and Phase 47 (Conclusions Synthesis), using section-filtered hybrid search prioritizing Discussion/Limitations/Future Work sections with 3-level fallback for graceful degradation.

The preset generates narrative prose (not tabular format) organized by five gap categories: Methodological, Geographic, Population, Measurement, and Theoretical. Contradictory findings are integrated inline with bold visual distinction. Minimum threshold of 3 papers enforced at button click (15+ papers trigger quality degradation warning). Button labeled "Research Gaps" placed in Deep presets row after Methods, before Slides.

**Primary recommendation:** Clone `generate_methodology_extractor()` structure from R/rag.R as foundation, adapting the system prompt for gap synthesis narrative output. Reuse section-targeted retrieval pattern with expanded section filter (`c("discussion", "limitations", "future_work")`) and increased chunk limit (20 vs Methods' 15) to support broader cross-paper synthesis. Add "gap_analysis" to `is_synthesis` check in mod_document_notebook.R line 717 to trigger AI disclaimer banner.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Output structure:**
- Narrative prose organized by gap category, not tabular
- Opening summary (2-3 sentences) highlighting the most critical gaps identified
- All 5 gap categories always shown as headings: Methodological Gaps, Geographic Gaps, Population Gaps, Measurement Gaps, Theoretical Gaps
- If no gaps found for a category: "No significant [type] gaps identified across the reviewed papers."
- Inline Author (Year) citations woven into narrative — matches Lit Review Table convention

**Contradictions display:**
- Contradictions integrated within their relevant gap category (not a separate section)
- Visually distinguished with bold prefix: "**Contradictory finding:** Smith (2023) reports X while Jones (2024) found Y."
- LLM prompt explicitly instructs to actively identify and highlight contradictory findings between papers (GAPS-03)

**Button & threshold UX:**
- Button label: "Research Gaps"
- Placement: Deep presets row, after Methods, before Slides
- Order: Conclusions, Lit Review, Methods, Research Gaps, Slides
- Minimum 3 papers enforced — error toast on click: "Gap analysis requires at least 3 papers. Add more papers to this notebook."
- Large-collection warning at 15+ papers (lower than Methods/Lit Review's 20 threshold): "Analyzing N papers — output quality may degrade with large collections."
- Uses existing `btn-sm btn-outline-primary` styling per design system (Phase 45)

**Section targeting & RAG:**
- Section filter targets: `c("discussion", "limitations", "future_work")` — all three section types from detect_section_hint()
- 20 chunks per retrieval (more generous than Methods' 15 — cross-paper synthesis needs broader context)
- 3-level fallback: section-filtered → unfiltered hybrid search → direct DB query (same as Methods preset)
- Gap-specific retrieval query emphasizing limitations, future work, contradictions, and research gaps

**Edge cases & coverage:**
- Transparent coverage note when fallback was needed: "Note: Some papers lacked structured Discussion/Limitations sections; analysis drew from available content."
- RAG guard required: "Synthesis unavailable — re-index this notebook first." (same as other presets)

**Disclaimer:**
- AI disclaimer banner shown on output (GAPS-05) — add "gap_analysis" to `is_synthesis` check in chat renderer

### Claude's Discretion

- Exact LLM prompt wording for gap identification and contradiction detection
- How to word the coverage transparency note
- Icon choice for the Research Gaps button (from existing icon wrappers in theme_catppuccin.R)
- Markdown formatting details within narrative sections

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GAPS-01 | User can generate Gap Analysis Report from document notebook | Button handler + generate_gap_analysis() function following methodology_extractor pattern |
| GAPS-02 | Report identifies methodological/geographic/population/measurement/theoretical gaps | LLM system prompt with structured output format and 5 gap category headings |
| GAPS-03 | Report highlights contradictory findings with citations | Prompt instruction for active contradiction detection + bold prefix formatting |
| GAPS-04 | Section-targeted RAG prioritizes Discussion/Limitations/Future Work | section_filter parameter with ["discussion", "limitations", "future_work"] + 3-level fallback |
| GAPS-05 | AI disclaimer banner shown on output | Add "gap_analysis" to is_synthesis check (line 717 in mod_document_notebook.R) |
| GAPS-06 | Minimum 3 papers threshold enforced | Paper count check before processing + error toast for < 3 papers |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R/Shiny | 4.5.1 / bslib | UI framework | Existing project foundation |
| DuckDB | via DBI | Chunk storage & metadata | Existing data layer |
| ragnar (internal) | Custom | Hybrid RAG retrieval | Phase 22 per-notebook store pattern |
| OpenRouter API | claude-sonnet-4 | LLM synthesis | Existing chat_model config setting |
| commonmark | CRAN | Markdown rendering | Existing chat message renderer |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | CRAN | Author metadata parsing | Extract last names for citations |
| tryCatch | R base | Error handling | Graceful degradation for all RAG/DB calls |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Narrative prose | Tabular output (like Lit Review/Methods) | User explicitly chose narrative — better for gap synthesis storytelling |
| 3-level fallback | RAG-only (no DB fallback) | Fallback ensures preset works even for pre-migration notebooks |
| 20 chunk limit | 15 (like Methods) | Gap synthesis needs broader context across multiple papers |

**Installation:**
No new dependencies — uses existing project libraries.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── rag.R                        # Add generate_gap_analysis() after generate_methodology_extractor()
├── mod_document_notebook.R      # Add btn_gaps button + handler, update is_synthesis check
└── theme_catppuccin.R           # Icon wrapper already exists (choose appropriate one)
```

### Pattern 1: Section-Targeted Preset Function
**What:** Function signature matching existing presets with section-filtered RAG retrieval and 3-level fallback
**When to use:** Any preset needing content from specific paper sections
**Example:**
```r
# Source: R/rag.R lines 1077-1273 (generate_methodology_extractor)
generate_gap_analysis <- function(con, config, notebook_id, session_id = NULL) {
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

    if (nrow(docs) < 3) {
      return("Gap analysis requires at least 3 papers to identify meaningful patterns.")
    }

    paper_count <- nrow(docs)

    # Build paper labels with metadata fallback (same as methodology_extractor)
    # ... [citation label generation code] ...

    # Section-aware chunk retrieval with 3-level fallback
    # Priority: discussion/limitations/future_work sections
    chunks_per_paper <- 7L  # Starting point, adjust dynamically if needed

    # ... [chunk retrieval logic with section filter] ...

    # Build context string
    context <- build_context_by_paper(papers_data)

    # System prompt for gap synthesis
    system_prompt <- paste0(
      "You are a research gap analyst. Generate a Gap Analysis Report analyzing methodological and topical gaps across the provided research.\n\n",
      "OUTPUT FORMAT:\n",
      "## Summary\n",
      "[2-3 sentence overview of the most critical gaps identified]\n\n",
      "## Methodological Gaps\n",
      "[Narrative analysis with inline Author (Year) citations]\n\n",
      "## Geographic Gaps\n",
      "[Narrative analysis with inline Author (Year) citations]\n\n",
      "## Population Gaps\n",
      "[Narrative analysis with inline Author (Year) citations]\n\n",
      "## Measurement Gaps\n",
      "[Narrative analysis with inline Author (Year) citations]\n\n",
      "## Theoretical Gaps\n",
      "[Narrative analysis with inline Author (Year) citations]\n\n",
      "RULES:\n",
      "- All 5 gap categories MUST appear as headings, even if no gaps found\n",
      "- If no gaps for a category: 'No significant [type] gaps identified across the reviewed papers.'\n",
      "- Weave Author (Year) citations inline (e.g., 'Smith et al. (2023) examined X but did not address Y')\n",
      "- Actively identify contradictory findings — prefix with '**Contradictory finding:**' in bold\n",
      "- Integrate contradictions within their relevant gap category\n",
      "- Base all analysis ONLY on provided sources\n"
    )

    user_prompt <- sprintf(
      "===== DOCUMENTS (%d papers) =====\n%s\n===== END =====\n\nGenerate the gap analysis report.",
      paper_count, context
    )

    messages <- format_chat_messages(system_prompt, user_prompt)
    result <- chat_completion(api_key, chat_model, messages)

    # Log cost
    if (!is.null(session_id) && !is.null(result$usage)) {
      cost <- estimate_cost(chat_model,
                            result$usage$prompt_tokens %||% 0,
                            result$usage$completion_tokens %||% 0)
      log_cost(con, "gap_analysis", chat_model,
               result$usage$prompt_tokens %||% 0,
               result$usage$completion_tokens %||% 0,
               result$usage$total_tokens %||% 0,
               cost, session_id)
    }

    response <- result$content

    # Check if fallback was used and add transparency note
    # ... [fallback detection logic] ...

    response
  }, error = function(e) {
    sprintf("Error generating gap analysis: %s", e$message)
  })
}
```

### Pattern 2: Button Handler with RAG Guard
**What:** observeEvent handler for preset button with RAG availability check and paper count threshold
**When to use:** All synthesis presets requiring indexed content
**Example:**
```r
# Source: R/mod_document_notebook.R lines 984-1031 (Methods handler)
observeEvent(input$btn_gaps, {
  req(!is_processing())
  req(has_api_key())

  # Guard: RAG must be available
  if (!isTRUE(rag_available())) {
    showNotification("Synthesis unavailable - re-index this notebook first.", type = "warning")
    return()
  }

  # Paper count validation (minimum 3 for gap analysis)
  nb_id <- notebook_id()
  doc_count <- tryCatch(nrow(list_documents(con(), nb_id)), error = function(e) 0L)
  if (doc_count < 3L) {
    showNotification(
      "Gap analysis requires at least 3 papers. Add more papers to this notebook.",
      type = "warning", duration = 5
    )
    return()
  }

  # Warning toast for large notebooks (15+ papers, lower than Methods/Lit Review's 20)
  if (doc_count >= 15L) {
    showNotification(
      sprintf("Analyzing %d papers - output quality may degrade with large collections.", doc_count),
      type = "warning", duration = 8
    )
  }

  is_processing(TRUE)

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = "Generate: Research Gaps",
    timestamp = Sys.time(),
    preset_type = "gap_analysis"
  )))
  messages(msgs)

  cfg <- config()

  response <- tryCatch({
    generate_gap_analysis(con(), cfg, nb_id, session_id = session$token)
  }, error = function(e) {
    sprintf("Error: %s", e$message)
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "gap_analysis"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### Pattern 3: AI Disclaimer Banner Trigger
**What:** Add preset_type to is_synthesis check to trigger disclaimer rendering
**When to use:** All LLM-generated synthesis presets (not simple chat)
**Example:**
```r
# Source: R/mod_document_notebook.R line 717
# BEFORE:
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions", "lit_review", "methodology_extractor")

# AFTER:
is_synthesis <- !is.null(msg$preset_type) && msg$preset_type %in% c("overview", "conclusions", "research_questions", "lit_review", "methodology_extractor", "gap_analysis")
```

### Anti-Patterns to Avoid
- **Skipping RAG guard:** Leads to runtime errors when store doesn't exist — always check `rag_available()` before synthesis operations
- **Hard threshold without warning:** User confusion when button silently fails — always show toast notification explaining why action blocked
- **Single fallback level:** Pre-migration notebooks lack section_hint data — 3-level fallback ensures graceful degradation
- **Tabular output for narrative synthesis:** Gap analysis storytelling requires prose flow — tables would fragment the narrative

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hybrid RAG retrieval | Custom vector search + BM25 | `search_chunks_hybrid()` with `section_filter` | Handles embeddings, fallback, connection management, already validated Phase 48 |
| Author citation formatting | String parsing logic | Existing paper_labels pattern from `generate_methodology_extractor()` | Handles JSON authors, multiple formats, DOI links |
| Chat message rendering | Custom markdown parser | `commonmark::markdown_html()` in mod_document_notebook.R | Existing renderer with GFM extensions |
| Cost tracking | Manual token counting | `log_cost()` with `estimate_cost()` | Centralized cost logging already integrated |
| Section classification | Manual regex patterns | `detect_section_hint()` from R/pdf.R | Validated heuristics covering all section types |

**Key insight:** Phase 48 (Methodology Extractor) already validated section-targeted RAG pattern. Gap Analysis is same technical pattern with different LLM prompt and section filter. Reuse entire infrastructure, only change: prompt, section_filter array, and chunk limit.

## Common Pitfalls

### Pitfall 1: Insufficient Context for Cross-Paper Synthesis
**What goes wrong:** Using same 15-chunk limit as Methods causes LLM to miss critical gaps mentioned across papers
**Why it happens:** Gap synthesis requires broader context than single-paper methodology extraction
**How to avoid:** Increase limit to 20 chunks (user-specified in CONTEXT.md) to balance context breadth vs API cost
**Warning signs:** Generated report only identifies gaps from 1-2 papers, missing patterns across full collection

### Pitfall 2: Contradictions Lost in Separate Section
**What goes wrong:** Grouping all contradictions under dedicated heading fragments context — reader loses connection between contradiction and gap type
**Why it happens:** Assumption that contradictions are separate from gaps, but they're evidence OF gaps
**How to avoid:** Integrate contradictions inline within their relevant gap category with bold prefix for visual distinction
**Warning signs:** User feedback that contradictions feel disconnected from gap analysis narrative

### Pitfall 3: Silent Failure on Small Notebooks
**What goes wrong:** Button click on 1-2 paper notebooks produces meaningless output or hallucinates gaps
**Why it happens:** LLM cannot identify meaningful gaps without comparative context
**How to avoid:** Enforce minimum 3 papers at button handler, show error toast explaining requirement
**Warning signs:** Generated reports with vague or speculative gap claims unsupported by sources

### Pitfall 4: Section Filter Too Restrictive
**What goes wrong:** Papers using non-standard section names (e.g., "Implications" instead of "Discussion") get excluded, reducing coverage
**Why it happens:** Over-reliance on keyword matching without positional fallback
**How to avoid:** Use 3-level fallback: section-filtered → unfiltered hybrid → direct DB query. Add transparency note when fallback used
**Warning signs:** Coverage note appears frequently, suggesting section detection isn't matching many papers

### Pitfall 5: Forgetting AI Disclaimer
**What goes wrong:** Users trust AI-generated gap analysis without verification, leading to citation errors or missed nuances
**Why it happens:** Missing `is_synthesis` check update after adding new preset type
**How to avoid:** Add "gap_analysis" to is_synthesis check (line 717) during UI integration — validate disclaimer renders in output
**Warning signs:** Gap analysis messages lack yellow warning banner present on other synthesis presets

## Code Examples

Verified patterns from official sources:

### Section-Filtered Hybrid Search with Fallback
```r
# Source: R/rag.R lines 1148-1174 (generate_methodology_extractor chunk retrieval)
# Try section-filtered first (discussion/limitations/future_work)
section_chunks <- dbGetQuery(con, "
  SELECT chunk_index, content, page_number, section_hint
  FROM chunks
  WHERE source_id = ? AND section_hint IN ('discussion', 'limitations', 'future_work')
  ORDER BY chunk_index
  LIMIT ?
", list(doc$id, chunks_per_paper))

if (nrow(section_chunks) < 2) {
  # Fallback: distributed sampling across all chunks
  all_chunks <- dbGetQuery(con, "
    SELECT chunk_index, content, page_number,
           COALESCE(section_hint, 'general') as section_hint
    FROM chunks WHERE source_id = ?
    ORDER BY chunk_index
  ", list(doc$id))

  if (nrow(all_chunks) > chunks_per_paper) {
    n <- nrow(all_chunks)
    indices <- unique(c(1, 2, ceiling(n/2), n-1, n))
    indices <- indices[indices >= 1 & indices <= n]
    indices <- sort(head(indices, chunks_per_paper))
    all_chunks <- all_chunks[indices, ]
  }
  section_chunks <- all_chunks
}
```

### Citation Label Generation
```r
# Source: R/rag.R lines 1101-1136 (paper_labels construction)
paper_labels <- lapply(seq_len(nrow(docs)), function(i) {
  doc <- docs[i, ]
  if (!is.na(doc$title) && !is.na(doc$authors) && !is.na(doc$year)) {
    authors_parsed <- tryCatch(jsonlite::fromJSON(doc$authors), error = function(e) NULL)
    if (!is.null(authors_parsed) && length(authors_parsed) > 0) {
      # Extract last names - authors stored as JSON array of objects with display_name
      if (is.data.frame(authors_parsed) && "display_name" %in% names(authors_parsed)) {
        last_names <- vapply(authors_parsed$display_name, function(a) {
          parts <- strsplit(trimws(a), "\\s+")[[1]]
          parts[length(parts)]
        }, character(1))
      } else if (is.character(authors_parsed)) {
        last_names <- vapply(authors_parsed, function(a) {
          parts <- strsplit(trimws(a), "\\s+")[[1]]
          parts[length(parts)]
        }, character(1))
      } else {
        last_names <- "Unknown"
      }

      author_str <- if (length(last_names) > 2) {
        paste0(last_names[1], " et al.")
      } else if (length(last_names) == 2) {
        paste0(last_names[1], " & ", last_names[2])
      } else {
        last_names[1]
      }
      label <- sprintf("%s (%d)", author_str, doc$year)
    } else {
      label <- sprintf("Unknown (%s)", if (!is.na(doc$year)) as.character(doc$year) else "n.d.")
    }
  } else {
    label <- tools::file_path_sans_ext(doc$filename)
  }
  list(label = label, doi = doc$doi, doc_id = doc$id)
})
```

### Button UI Addition
```r
# Source: R/mod_document_notebook.R lines 102-118 (Deep presets row)
# Row 2: Deep presets + Export
div(
  class = "d-flex gap-1",
  div(
    class = "btn-group btn-group-sm",
    actionButton(ns("btn_conclusions"), "Conclusions",
                 class = "btn-sm btn-outline-primary",
                 icon = icon_microscope()),
    actionButton(ns("btn_lit_review"), "Lit Review",
                 class = "btn-sm btn-outline-primary",
                 icon = icon_table()),
    actionButton(ns("btn_methods"), "Methods",
                 class = "btn-sm btn-outline-primary",
                 icon = icon_flask()),
    actionButton(ns("btn_gaps"), "Research Gaps",  # NEW BUTTON
                 class = "btn-sm btn-outline-primary",
                 icon = icon_magnifying_glass()),  # Choose appropriate icon
    actionButton(ns("btn_slides"), "Slides",
                 class = "btn-sm btn-outline-primary",
                 icon = icon_file_powerpoint())
  ),
  # ... export dropdown ...
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single fallback (RAG only) | 3-level fallback (section → hybrid → DB) | Phase 48 (2026-03-06) | Graceful degradation for pre-migration notebooks |
| Flat chunk sampling | Section-targeted retrieval | Phase 48 (2026-03-06) | Improved content relevance for synthesis tasks |
| Fixed chunk limit across presets | Adaptive limits (15 for Methods, 20 for Gaps) | Phase 49 design | Balances context needs vs API cost per preset type |
| 20-paper threshold for warnings | 15-paper threshold for gap analysis | Phase 49 design | Gap synthesis degrades faster with collection size |

**Deprecated/outdated:**
- Global ragnar store (Phase 22): Replaced with per-notebook stores at `.temp/ragnar/{notebook_id}.db` — ensures isolation, enables concurrent operations
- Direct PDF chunking: Replaced with ragnar semantic chunking via `chunk_with_ragnar()` — better context preservation

## Open Questions

1. **Icon Choice for Research Gaps Button**
   - What we know: Phase 47 established icon wrappers in theme_catppuccin.R (lines 130-250). Existing options: icon_microscope (Conclusions), icon_table (Lit Review), icon_flask (Methods)
   - What's unclear: Best semantic match for "gap analysis" concept
   - Recommendation: icon_magnifying_glass() — evokes discovery/search for missing elements. Alternative: icon_lightbulb() (insight/ideas) if magnifying glass reads as too similar to search. Test both in UI before finalizing.

2. **Coverage Transparency Note Placement**
   - What we know: Fallback to unfiltered/DB query means some papers lacked structured sections
   - What's unclear: Append note at end vs inline warning at beginning vs per-category notes
   - Recommendation: Single note at end of report (after Theoretical Gaps section): "Note: Some papers lacked structured Discussion/Limitations sections; analysis drew from available content." Avoids interrupting narrative flow.

3. **LLM Prompt Emphasis Balance**
   - What we know: Prompt must instruct gap identification AND contradiction detection without biasing toward one
   - What's unclear: Optimal wording to achieve balanced output
   - Recommendation: Two-part instruction: "1. Analyze gaps in methodology, geography, population, measurement, and theory. 2. Actively identify contradictory findings between papers." Separate numbering emphasizes equal priority.

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is explicitly set to false in .planning/config.json. If the key is absent, treat as enabled.

**Note:** `.planning/config.json` does not include `workflow.nyquist_validation` key — treating as enabled (default true).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | tests/testthat.R |
| Quick run command | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GAPS-01 | User can generate Gap Analysis Report from document notebook | integration | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='button_handler')"` | ❌ Wave 0 |
| GAPS-02 | Report identifies 5 gap categories | unit | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='gap_categories')"` | ❌ Wave 0 |
| GAPS-03 | Report highlights contradictions with citations | unit | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='contradictions')"` | ❌ Wave 0 |
| GAPS-04 | Section-targeted RAG with 3-level fallback | unit | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='section_targeting')"` | ❌ Wave 0 |
| GAPS-05 | AI disclaimer banner shown | unit | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='disclaimer')"` | ❌ Wave 0 |
| GAPS-06 | Minimum 3 papers threshold enforced | unit | `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R', filter='threshold')"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "testthat::test_file('tests/testthat/test-gap-analysis.R') -x"` (stop on first failure)
- **Per wave merge:** Full suite: `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-gap-analysis.R` — covers GAPS-01 through GAPS-06
  - test_that("button_handler triggers generate_gap_analysis", ...)
  - test_that("gap_categories all 5 headings present in output", ...)
  - test_that("contradictions formatted with bold prefix", ...)
  - test_that("section_targeting filters discussion/limitations/future_work", ...)
  - test_that("disclaimer is_synthesis includes gap_analysis", ...)
  - test_that("threshold blocks < 3 papers with toast", ...)

## Sources

### Primary (HIGH confidence)
- R/rag.R (lines 1077-1273) — `generate_methodology_extractor()` implementation, section-targeted RAG pattern validated Phase 48
- R/mod_document_notebook.R (lines 984-1031) — Methods button handler with RAG guard and threshold validation
- R/mod_document_notebook.R (line 717) — `is_synthesis` check controlling AI disclaimer banner
- R/pdf.R (lines 23-75) — `detect_section_hint()` section classification logic
- .planning/phases/49-gap-analysis-report-preset/49-CONTEXT.md — User decisions from discussion session
- .planning/REQUIREMENTS.md (lines 43-50) — GAPS-01 through GAPS-06 requirement definitions

### Secondary (MEDIUM confidence)
- R/theme_catppuccin.R (lines 130-250) — Icon wrapper functions for button icons
- .planning/STATE.md (lines 186-187) — Phase 48 decision: section-targeted RAG pattern validation
- .planning/config.json — Workflow settings (no explicit nyquist_validation key, default true)

### Tertiary (LOW confidence)
- None — all research based on existing codebase patterns and user decisions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Reuses existing R/Shiny, DuckDB, ragnar infrastructure with no new dependencies
- Architecture: HIGH - Directly clones validated Phase 48 pattern with only prompt/filter changes
- Pitfalls: HIGH - Based on actual Phase 48 implementation learnings and user decisions from CONTEXT.md

**Research date:** 2026-03-06
**Valid until:** 2026-04-05 (30 days — stable codebase, no fast-moving dependencies)
