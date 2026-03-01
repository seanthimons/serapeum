---
phase: 27-research-question-generator
verified: 2026-02-19T00:00:00Z
status: passed
score: 3/3 must-haves verified
re_verification: false
---

# Phase 27: Research Question Generator Verification Report

**Phase Goal:** Users can generate a structured list of research questions derived from their notebook's papers, grounded in identified gaps and framed with PICO structure.
**Verified:** 2026-02-19
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                                                              | Status     | Evidence                                                                                                                          |
|----|----------------------------------------------------------------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------------------------------------------|
| 1  | User sees a Research Questions button in the search notebook preset panel                                                                          | VERIFIED | `uiOutput(ns("research_questions_btn_ui"))` at line 253 inside the btn-group div; `renderUI` at lines 582–595 renders enabled/disabled `actionButton` |
| 2  | User clicks Research Questions and receives 5-7 numbered questions (or 3-4 for small notebooks) each with a 2-3 sentence rationale citing specific papers by author/year | VERIFIED | `generate_research_questions()` exists at rag.R:407; system prompt contains explicit scaling rules ("2-3 papers: 3-4 questions", "5+ papers: 5-7 questions") and citation format instructions ("Author et al. (Year)"); paper metadata queried from `abstracts` table and injected into user prompt under `===== PAPER METADATA =====` block |
| 3  | Research question output renders as a numbered markdown list in the chat panel with the AI-generated content disclaimer                             | VERIFIED | Handler at mod_search_notebook.R:2364 sets `preset_type = "research_questions"` on both user and assistant messages; disclaimer check at line 2250 uses `msg$preset_type %in% c("conclusions", "research_questions")`; mod_document_notebook.R line 600 widened identically |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact                          | Expected                                             | Status   | Details                                                                                         |
|-----------------------------------|------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------|
| `R/rag.R`                         | `generate_research_questions()` function             | VERIFIED | Standalone function at line 407; not inside `generate_preset()`; 163 lines of substantive implementation |
| `R/mod_search_notebook.R`         | Research Questions button and observeEvent handler   | VERIFIED | `btn_research_questions` appears at lines 253, 582, 584, 2364 (UI output, renderUI, actionButton, observeEvent) |
| `R/mod_document_notebook.R`       | Updated disclaimer check for research_questions      | VERIFIED | Line 600: `msg$preset_type %in% c("conclusions", "research_questions")` |

### Key Link Verification

| From                          | To                            | Via                                                     | Status   | Details                                                                                    |
|-------------------------------|-------------------------------|---------------------------------------------------------|----------|--------------------------------------------------------------------------------------------|
| `R/mod_search_notebook.R`     | `R/rag.R`                     | `observeEvent` calls `generate_research_questions()`    | WIRED    | Line 2386: `generate_research_questions(con(), cfg, nb_id, notebook_type = "search", session_id = session$token)` |
| `R/mod_search_notebook.R`     | chat message renderer         | `preset_type = "research_questions"` triggers disclaimer | WIRED   | Line 2378 (user msg) and 2401 (assistant msg) set `preset_type`; disclaimer at line 2250 reads it |
| `R/mod_document_notebook.R`   | chat message renderer         | disclaimer check widened to include research_questions  | WIRED    | Line 600 uses `%in% c("conclusions", "research_questions")`                                |

### Requirements Coverage

| Requirement                                                                 | Status    | Blocking Issue |
|-----------------------------------------------------------------------------|-----------|----------------|
| Button visible in search notebook preset panel                              | SATISFIED | —              |
| Generates 5-7 questions (3-4 for small notebooks) with paper-citing rationale | SATISFIED | —              |
| Numbered markdown output in chat panel with AI disclaimer                   | SATISFIED | —              |
| Cost logged under "research_questions" category                             | SATISFIED | `log_cost(con, "research_questions", ...)` at rag.R:557 |
| Early return guard for < 2 papers                                           | SATISFIED | rag.R:430 returns "At least 2 papers are needed..." |
| RAG retrieval uses gap-focused query with limit=15                          | SATISFIED | `search_chunks_hybrid(..., query = "research gaps limitations...", limit = 15)` at rag.R:464–470 |
| Paper metadata (authors, year, title) injected into prompt                  | SATISFIED | `paper_list_text` built at rag.R:443–458 and formatted as "LastName et al. (Year): Title" |

### Anti-Patterns Found

None. No TODO/FIXME/placeholder comments found in the new code block (rag.R lines 407–570). No stub return patterns. No empty handlers.

### Human Verification Required

#### 1. End-to-end UI flow

**Test:** Open the app with a search notebook containing 3+ embedded papers. Click the "Research Questions" button in the preset panel.
**Expected:** Button is enabled (rag_available is TRUE), clicking it appends a user message "Generate: Research Questions" and then an assistant message containing 3-7 numbered questions, each with a 2-3 sentence rationale naming specific papers by "Author et al. (Year)". An "AI-Generated Content" disclaimer banner appears below the response.
**Why human:** Cannot verify reactive state (rag_available, is_processing), live LLM output format, or disclaimer visual rendering programmatically.

#### 2. Small notebook guard

**Test:** Open a search notebook containing exactly 1 embedded paper. Click "Research Questions".
**Expected:** Assistant response is "At least 2 papers are needed to identify research gaps and generate research questions." (no LLM call made).
**Why human:** Guard logic verified in code; runtime behaviour requires a live session.

#### 3. Disabled button state

**Test:** Open a search notebook that has papers but has not been indexed (rag_available = FALSE).
**Expected:** "Research Questions" button is rendered as a disabled button with tooltip "Synthesis unavailable — re-index this notebook first".
**Why human:** Requires a session with un-indexed notebook to observe the disabled state.

### Gaps Summary

No gaps. All three observable truths are fully satisfied. The `generate_research_questions()` function is substantive (163 lines), standalone (not inside `generate_preset()`), wired to the UI via a proper `observeEvent`, costs are logged under the correct category, and the AI disclaimer check is widened in both notebook modules. Commits 438a8e8 and 6c2a456 are confirmed in the git log.

---

_Verified: 2026-02-19_
_Verifier: Claude (gsd-verifier)_
