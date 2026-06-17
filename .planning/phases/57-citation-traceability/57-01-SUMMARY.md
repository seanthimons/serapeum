---
phase: 57-citation-traceability
plan: "01"
subsystem: AI prompts
tags: [citation, traceability, rag, slides, prompts]
dependency_graph:
  requires: []
  provides:
    - Page-level citation instructions in all AI preset prompts (R/rag.R)
    - Page-number citation instruction in slide generation prompts (R/slides.R)
  affects:
    - All AI-generated prose outputs (summaries, key points, conclusions, overview, research questions, gap analysis)
    - Structured table outputs (lit review table, methodology extractor) — footnote sections added
    - Slide generation and healing prompts
tech_stack:
  added: []
  patterns:
    - APA-like parenthetical citations (Author, Year, p.X) across all prose presets
    - Numbered footnote sections (### Sources) for structured table presets
    - Explicit fallback formats for abstracts (Author, Year, abstract) and missing pages (Author, Year, chunk N)
    - Correct/wrong example pairs in citation instruction blocks (v7.0 proven effective)
key_files:
  created: []
  modified:
    - R/rag.R
    - R/slides.R
decisions:
  - "(Author, Year, p.X) format used for all non-slide prose outputs per CONTEXT.md decision"
  - "Table presets (lit review, methodology) use footnote sections instead of inline citations to keep table cells clean"
  - "Slide ^[text] Quarto footnote syntax left unchanged — only instruction text updated to require page numbers"
  - "RAG chat prompt updated from [Document Name, p.X] bracket format to (Author, Year, p.X) parenthetical for consistency"
metrics:
  duration_minutes: 18
  completed_date: "2026-03-18"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 57 Plan 01: Citation Traceability — Prompt Updates Summary

**One-liner:** Added (Author, Year, p.X) citation instructions with fallback rules to all 10 AI preset prompts in R/rag.R and explicit page-number requirements to slide generation prompts in R/slides.R.

## What Was Built

Prompt-engineering-only changes across two files. Every AI-generated output now instructs the LLM to include page-level citations so users can trace claims back to specific pages in source documents.

### R/rag.R — 10 prompt functions updated

| Function | Change |
|---|---|
| `rag_query()` | Replaced `[Document Name, p.X]` with `(Author, Year, p.X)` CITATION RULES block + correct/wrong examples |
| `generate_preset()` | Added full CITATION RULES block (applies to all 4 basic presets: summarize, keypoints, studyguide, outline) |
| `generate_conclusions_preset()` | Replaced `[Source Name] format` with `(Author, Year, p.X)`, added CITATION RULES block + examples |
| `call_overview_quick()` | Added CITATION RULES block after groundedness instruction |
| `call_overview_summary()` | Added inline citation instruction with abstract/chunk fallbacks |
| `call_overview_keypoints()` | Added inline citation instruction with abstract/chunk fallbacks |
| `generate_research_questions()` | Updated from `Author et al. (Year)` to `Author et al. (Year, p.X)` with abstract fallback |
| `generate_lit_review_table()` | Added `### Sources` footnote section instruction for Key Findings column (table cells kept clean) |
| `generate_methodology_extractor()` | Added `### Sources` footnote section instruction for Study Design and Statistical Methods columns |
| `generate_gap_analysis()` | Updated inline citations to include page numbers; added abstract fallback |

### R/slides.R — 3 prompt locations updated

| Location | Change |
|---|---|
| `build_slides_prompt()` system_prompt | Added "IMPORTANT: Always include the page number in footnotes" instruction block |
| `build_slides_prompt()` footnotes citation_instructions | Changed "key points" to "ALL substantive claims"; added "Always include the page number from the source data" |
| `build_slides_prompt()` inline citation_instructions | Updated format from `(Author, p.X)` to `(Author, Year, p.X)`; added "ALL substantive claims" |
| `build_healing_prompt()` system_prompt | Added "When fixing citations, ensure page numbers from the source data are preserved in footnotes" |

## Verification Results

| Check | Result |
|---|---|
| `(Author, Year, p.X)` occurrences in rag.R | 11 (expect 5+) |
| `abstract)` fallback occurrences in rag.R | 9 (expect 5+) |
| `(Author, Year, p.X)\|page number` in slides.R | 5 (expect 2+) |
| Old `[Document Name, p.X]` in rag.R | 0 (removed) |
| Old `[Source Name] format` in rag.R | 0 (removed) |
| `^[text]` Quarto syntax preserved in slides.R | Yes — unchanged |
| Slides tests (with source): pass/fail/skip | 82 / 1 / 1 |
| Pre-existing test failure (revealjs in system_prompt) | Confirmed pre-existing — was failing before this plan |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] R/rag.R modified (Task 1 commit: a8a4f06)
- [x] R/slides.R modified (Task 2 commit: 3ea23d4)
- [x] All 10 rag.R prompt functions updated
- [x] All 3 slides.R prompt locations updated
- [x] No changes to build_context(), build_context_by_paper(), or non-prompt code
- [x] Existing test suite: 82 pass, 1 pre-existing fail (unchanged)

## Self-Check: PASSED
