---
phase: 27-research-question-generator
plan: "01"
subsystem: rag-synthesis
tags: [rag, research-questions, synthesis, ui, search-notebook]
dependency_graph:
  requires: [R/rag.R (generate_conclusions_preset pattern), R/mod_search_notebook.R (conclusions button pattern)]
  provides: [generate_research_questions() function, Research Questions button, widened disclaimer]
  affects: [mod_search_notebook.R chat panel, mod_document_notebook.R disclaimer, rag.R synthesis functions]
tech_stack:
  added: []
  patterns: [gap-focused RAG retrieval with limit=15, paper metadata enrichment for citations, PICO-invisible adaptive framing, early-return guard for small notebooks]
key_files:
  created: []
  modified:
    - R/rag.R
    - R/mod_search_notebook.R
    - R/mod_document_notebook.R
decisions:
  - "Separate function (not added to generate_preset()): generate_research_questions() is standalone per CONTEXT.md requirement"
  - "RAG query targets gap-revealing content: 'research gaps limitations future work methodology population understudied contradictions' with limit=15"
  - "Paper metadata queried separately from abstracts table (ragnar chunks lack author/year); formatted as 'LastName et al. (Year)'"
  - "Disclaimer check widened using %in% set membership instead of identical() for extensibility"
metrics:
  duration: "~2 minutes"
  completed: "2026-02-19"
  tasks_completed: 2
  files_modified: 3
---

# Phase 27 Plan 01: Research Question Generator Summary

**One-liner:** Gap-grounded research question synthesis with PICO-invisible adaptive framing, paper citation metadata, and scaled question counts via standalone `generate_research_questions()`.

## What Was Built

Added a Research Questions synthesis preset to the search notebook. When clicked, it:

1. Guards against small notebooks (< 2 papers) with an early return message
2. Queries the `abstracts` table for paper count and metadata (authors, year, title)
3. Formats author citations as "LastName et al. (Year)" / "A & B (Year)" / single name
4. Retrieves 15 chunks via hybrid RAG with gap-focused query terms
5. Falls back to direct DB query if hybrid search returns nothing
6. Sends a gap analyst system prompt with PICO-invisible adaptive framing, scaling rules (3-4 questions for 2-3 papers, 5-7 for 5+ papers), and citation format instructions
7. Logs cost under the `"research_questions"` category
8. Renders output in the chat panel with the AI-Generated Content disclaimer

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create generate_research_questions() in rag.R | 438a8e8 | R/rag.R (+177 lines) |
| 2 | Wire Research Questions button and fix disclaimer in UI modules | 6c2a456 | R/mod_search_notebook.R, R/mod_document_notebook.R (+64, -3 lines) |

## Key Changes

**R/rag.R** — New `generate_research_questions()` function at line 407:
- Early return: `paper_count < 2` → "At least 2 papers are needed..."
- Paper metadata: `SELECT id, title, authors, year FROM abstracts WHERE notebook_id = ?`
- RAG retrieval: `search_chunks_hybrid(..., query = "research gaps limitations...", limit = 15)`
- Full fallback chain (hybrid -> direct DB)
- System prompt: gap analyst role, PICO-invisible, scaling rules, citation format
- User prompt: `===== PAPER METADATA =====` block + RAG content
- Cost logging: `log_cost(con, "research_questions", ...)`

**R/mod_search_notebook.R** — Four changes:
1. Line 253: `uiOutput(ns("research_questions_btn_ui"))` added after conclusions button
2. Lines 582-597: `output$research_questions_btn_ui <- renderUI({...})` with enable/disable based on `rag_available()`
3. Line 2250: Disclaimer widened to `msg$preset_type %in% c("conclusions", "research_questions")`
4. Lines 2364-2408: `observeEvent(input$btn_research_questions, {...})` handler

**R/mod_document_notebook.R** — One change:
- Line 600: Disclaimer widened to `msg$preset_type %in% c("conclusions", "research_questions")`

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Verification

- [x] `generate_research_questions()` exists as a standalone function in rag.R (NOT inside `generate_preset()`)
- [x] Function queries abstracts table for paper count and metadata (authors, year, title)
- [x] Function returns early with message if < 2 papers
- [x] Prompt includes PICO-invisible adaptive framing, gap-type grouping, scaling rules, and citation format instructions
- [x] RAG query uses gap-focused terms with limit=15
- [x] Research Questions button visible in search notebook preset panel
- [x] Click triggers LLM call and renders numbered markdown in chat
- [x] AI-generated content disclaimer appears on research questions output
- [x] Cost logged under "research_questions" category

## Self-Check: PASSED
