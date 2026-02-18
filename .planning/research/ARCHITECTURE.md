# Architecture Research: v4.0 Stability + Synthesis Features

**Domain:** R/Shiny local-first research assistant — feature integration analysis
**Researched:** 2026-02-18
**Confidence:** HIGH (based on direct codebase analysis)

---

## Current Architecture Snapshot

The codebase is post-Phase-22 (per-notebook ragnar stores fully shipped). Key structural facts:

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Shiny UI Layer (bslib)                        │
├──────────────────────────────────────────────────────────────────────┤
│  mod_document_notebook.R        mod_search_notebook.R                 │
│  ┌─────────────────────┐        ┌──────────────────────────────────┐  │
│  │ Preset buttons:     │        │ Preset buttons:                   │  │
│  │  btn_summarize      │        │  btn_conclusions                  │  │
│  │  btn_keypoints      │        │                                  │  │
│  │  btn_studyguide     │        │ Chat: offcanvas panel             │  │
│  │  btn_outline        │        │ Papers: filter + list             │  │
│  │  btn_conclusions    │        └──────────────────────────────────┘  │
│  │  btn_slides         │                                              │
│  │                     │                                              │
│  │ Chat: card panel    │                                              │
│  └─────────────────────┘                                              │
├──────────────────────────────────────────────────────────────────────┤
│                      Business Logic Layer                             │
├──────────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌──────────────────────────┐  ┌──────────────────┐   │
│  │ R/rag.R   │  │ R/api_openrouter.R       │  │ R/_ragnar.R      │   │
│  │           │  │                          │  │                  │   │
│  │ rag_query │  │ chat_completion()        │  │ search_chunks_   │   │
│  │ generate_ │  │  → list(content,usage,   │  │  hybrid() [has   │   │
│  │  preset() │  │     model, id)           │  │  conn leak #117] │   │
│  │ generate_ │  │                          │  │                  │   │
│  │  conclus_ │  │ format_chat_messages()   │  │ insert_chunks_   │   │
│  │  ions_    │  │                          │  │  to_ragnar()     │   │
│  │  preset() │  │ estimate_cost()          │  │                  │   │
│  └─────┬─────┘  └──────────┬───────────────┘  └──────┬───────────┘   │
│        │                   │                          │               │
├────────┴───────────────────┴──────────────────────────┴───────────────┤
│                         Data Storage Layer                            │
├──────────────────────────────────────────────────────────────────────┤
│  data/notebooks.duckdb          data/ragnar/{notebook_id}.duckdb      │
│  ┌─────────────────────┐        ┌───────────────────────────────────┐ │
│  │ notebooks           │        │ Per-notebook VSS + BM25 index     │ │
│  │ documents           │        │                                   │ │
│  │ abstracts           │        │ origin field encodes:             │ │
│  │ chunks (legacy)     │        │  "filename#page=N|section=hint"   │ │
│  │ cost_log            │        │  "abstract:id|section=general"    │ │
│  └─────────────────────┘        └───────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### Existing Preset Pattern (Single Source of Truth)

All presets follow this fixed pipeline — understanding it is required before adding new ones:

```
Button click (observeEvent)
    ↓
is_processing(TRUE)
    ↓
Append user message to messages() reactiveVal
    ↓
Call function in R/rag.R:
  - rag_query()              — for free-text questions
  - generate_preset()        — for summarize/keypoints/studyguide/outline
  - generate_conclusions_preset() — for cross-source synthesis
    ↓
Each rag.R function:
  1. get_setting() for api_key, chat_model
  2. search_chunks_hybrid() or direct DB query for context
  3. build_context(chunks) → formatted string
  4. format_chat_messages(system, user) → message list
  5. chat_completion(api_key, model, messages)
     → result$content (markdown string)
  6. log_cost(con, ...) using result$usage
    ↓
Append assistant message to messages() reactiveVal
    ↓
is_processing(FALSE)
    ↓
output$messages renderUI re-fires:
  - HTML(commonmark::markdown_html(msg$content, extensions = TRUE))
```

**Critical:** All current presets return plain markdown strings. The render path uses `commonmark::markdown_html()` directly — no structured data, no tables beyond what markdown syntax produces.

---

## Integration Analysis: Three New Features

### Feature 1: Unified Overview Preset (Issue #98)

**What it is:** Merge `btn_summarize` + `btn_keypoints` into a single "Overview" button that produces a structured synthesis: summary paragraph + bulleted key points in one response.

**Integration point:** Both `mod_document_notebook.R` and `mod_search_notebook.R` have preset buttons. This is a modification to the existing preset system, not a new component.

**Data flow — MODIFIED (not new):**

```
btn_overview click
    ↓
handle_preset("overview", "Overview")   [replaces 2 button handlers]
    ↓
generate_preset(con, cfg, nb_id, "overview", session_id)
    ↓
R/rag.R: generate_preset() — add "overview" case to presets list:
  "Provide a structured overview of these documents. Begin with a 2-3
   paragraph summary of the main themes and findings, then provide a
   bulleted list of the 8-10 most important key points."
    ↓
chat_completion() → markdown string with ## Summary + ## Key Points sections
    ↓
commonmark::markdown_html() renders correctly (## headers, bullets)
```

**Files to modify:**
- `R/rag.R` — add "overview" entry to `presets` list inside `generate_preset()`
- `mod_document_notebook.R` — replace two buttons with one `btn_overview`; remove `btn_summarize` and `btn_keypoints` handlers; add single `handle_preset("overview", "Overview")` handler
- `mod_search_notebook.R` — same button replacement (if Summarize/Key Points buttons are added to search notebooks in this milestone; currently only "Conclusions" exists there)

**No new files needed.** No new RAG functions needed.

**Risk:** Low. One-line prompt addition in rag.R. UI change only removes/replaces buttons. Zero data flow changes.

---

### Feature 2: Literature Review Table (Issue #99)

**What it is:** A structured comparison matrix where rows = papers, columns = user-defined dimensions (e.g., methodology, sample size, findings, limitations). Requires structured output from the LLM, not prose markdown.

**This is architecturally different from all existing presets.** Existing presets: LLM returns markdown prose → rendered via `commonmark::markdown_html()`. Literature Review Table: LLM must return structured data → rendered as an HTML `<table>`.

**Integration options — evaluated:**

**Option A: LLM returns markdown table**
Ask the LLM to output a GitHub-Flavored Markdown (GFM) table. `commonmark::markdown_html(extensions = TRUE)` renders GFM tables natively.

```
| Paper | Methodology | Finding | Limitation |
|-------|-------------|---------|------------|
| Smith 2020 | RCT | ... | ... |
```

Pros: Zero new rendering code. Works within existing message pipeline.
Cons: LLM reliability for wide tables is poor. Column alignment degrades with long cell content. No user-defined columns without a UI element.

**Option B: LLM returns JSON → R parses → renders as HTML table**
Ask the LLM to return structured JSON. Parse in R. Build an HTML table using `htmltools::tags$table()`. Return the rendered HTML as a message with a special `content_type = "table"` flag.

Pros: Reliable structure, full control over column widths, sortable, exportable.
Cons: Requires changes to the message rendering pipeline (currently assumes plain markdown strings).

**Recommendation: Option A for MVP, Option B as enhancement.**

For v4.0, use Option A with a well-structured prompt. The LLM prompt must instruct: output ONLY a markdown table with defined columns. `commonmark` with `extensions = TRUE` renders this correctly. If table quality is unsatisfactory after testing, upgrade to Option B in a follow-on phase.

**Data flow for Option A:**

```
btn_lit_review click (new button in mod_search_notebook.R offcanvas)
    ↓
is_processing(TRUE)
    ↓
Append "Generate: Literature Review Table" to messages()
    ↓
generate_lit_review_table(con, cfg, nb_id, session_id)   [NEW function in R/rag.R]
    ↓
  1. Retrieve abstracts: dbGetQuery for all abstracts in notebook
     (not RAG — need ALL papers for comparison, not semantic top-k)
  2. Format paper list as JSON-like structured context:
     [Paper: Smith et al. 2020 | Title: X | Abstract: Y]
     [Paper: Jones 2019 | Title: A | Abstract: B]
  3. System prompt: "Output ONLY a GFM markdown table. Columns:
     Author/Year | Research Question | Methodology | Key Finding | Limitations.
     One row per paper. Do not output any prose."
  4. chat_completion()
    ↓
Return markdown table string
    ↓
commonmark::markdown_html(msg$content, extensions = TRUE)
  → <table><thead>...</thead><tbody>...</tbody></table>
```

**Critical implementation note:** The retrieve-all-papers approach (direct DB query) is intentional. RAG retrieval (top-k semantic search) would miss papers — for a comparison matrix you need coverage, not relevance ranking. This matches the pattern already used in `generate_preset()` where a `LIMIT 50` query is used.

**Files to add/modify:**
- `R/rag.R` — add `generate_lit_review_table()` function (new, ~60 lines)
- `mod_search_notebook.R` — add `btn_lit_review` button in offcanvas preset row; add `observeEvent(input$btn_lit_review, ...)` handler
- `mod_document_notebook.R` — optionally add to document notebooks as well (cross-document comparison)

**Table export:** The existing chat export (Markdown .md / HTML .html via `downloadHandler`) handles GFM tables correctly because `format_chat_as_markdown()` passes through the content verbatim, and `format_chat_as_html()` runs `commonmark::markdown_html()` on it. No new export logic needed.

**Risk:** Medium. LLM compliance with "output ONLY a table" instructions varies by model. Test with the configured default model. A fallback message ("Could not generate table — try with fewer papers") should be included.

---

### Feature 3: Research Question Generator (Issue #102)

**What it is:** Given the papers in a search notebook, generate a list of research questions derived from identified gaps, contradictions, and under-explored areas.

**Integration point:** Same pattern as `generate_conclusions_preset()`. New function in `R/rag.R`, new button in the preset row, same rendering pipeline.

**Data flow:**

```
btn_rq_generator click (new button in mod_search_notebook.R offcanvas)
    ↓
is_processing(TRUE)
    ↓
generate_research_questions(con, cfg, nb_id, session_id)   [NEW function in R/rag.R]
    ↓
  1. search_chunks_hybrid() with query:
     "research gaps limitations future work unanswered questions"
     (reuses RAG retrieval — gap-related sections are best via semantic search)
  2. Fallback: direct DB query (same pattern as generate_conclusions_preset)
  3. System prompt instructs: "Based on these sources, generate 8-12 specific,
     actionable research questions. Format as numbered list. Organize under:
     ## Methodological Gaps, ## Empirical Gaps, ## Theoretical Gaps"
  4. chat_completion()
    ↓
Markdown string with ## headers and numbered lists
    ↓
commonmark::markdown_html() — renders correctly
```

**Files to add/modify:**
- `R/rag.R` — add `generate_research_questions()` function (new, ~50 lines)
- `mod_search_notebook.R` — add `btn_rq_generator` in offcanvas preset row

**Risk:** Low. Identical pattern to existing `generate_conclusions_preset()`. Retrieval approach proven. Markdown output renders without changes.

---

## Bug Fix Integration Analysis

### Bug #110: Seed paper not appearing in abstract search

**Root cause (from code analysis):** `mod_search_notebook.R` returns `seed_request` reactive with a DOI. The receiver in `app.R` uses this DOI to trigger a seed discovery search. The paper fetched as the seed paper is likely being added to `abstracts` table but not appearing in `filtered_papers()` because the `paper_refresh()` trigger is not being fired after seed import, or the seed paper passes the abstract-exists check but the UI doesn't re-render.

**Fix location:** `mod_search_notebook.R` — wherever the seed paper is saved after DOI lookup, ensure `paper_refresh(paper_refresh() + 1)` is called. Check that `seed_request` handler in `app.R` correctly triggers a refresh in the search notebook module.

**No architecture changes needed.** Bug fix only.

### Bug #111: Abstract removal modal repeating multiple times

**Root cause (from code analysis):** The delete handler pattern in `mod_search_notebook.R` (lines 966-999) registers `observeEvent(input[[delete_id]], ...)` inside an `observe({})` block that re-fires whenever `filtered_papers()` changes. Each re-fire creates a NEW observer for the same input ID. With `once = TRUE` this should self-limit, but Shiny's observer accumulation means multiple observers fire before each destroys itself.

**Fix:** Use `observeEvent` with `ignoreInit = TRUE` and track registered paper IDs in a `reactiveVal` set to avoid re-registering observers for already-registered IDs. Alternatively, use a single delegated event pattern: one `observeEvent` for a generic `input$delete_paper_id` input that reads which paper to delete from a separate input.

**No architecture changes needed.** Bug fix in observer registration pattern.

### Bug #116: Cost tracking not updating with new model prices

**Root cause:** `estimate_cost()` in `R/cost_tracking.R` (or `api_openrouter.R`) uses a hardcoded price table. When new models are added or prices change, the static table is stale.

**Fix direction:** Two options:
1. Pull pricing from OpenRouter's `/models` endpoint at cost-log time (live lookup)
2. Update the static table periodically

For a local-first app, option 1 adds latency and network dependency to every LLM call. Option 2 is safer: update the hardcoded table in `api_openrouter.R`'s `get_default_chat_models()` and add a comment with the last-verified date.

**No architecture changes needed.** Data update in existing static table.

### Tech Debt #117: Connection leak in search_chunks_hybrid

**Root cause (confirmed in code):** `db.R:search_chunks_hybrid()` line 710:
```r
store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)
```
When `ragnar_store` is NULL (the common case — callers never pass a pre-opened store), `connect_ragnar_store()` opens a new DuckDB connection. This connection is never closed. After the function returns, the `store` variable goes out of scope, and DuckDB connections are not garbage-collected reliably in R.

**Fix:** Wrap the body of `search_chunks_hybrid()` in an `on.exit()` that closes the connection if it was created internally:

```r
store_was_created_here <- FALSE
if (is.null(ragnar_store) && !is.null(ragnar_store_path) && file.exists(ragnar_store_path)) {
  store <- connect_ragnar_store(ragnar_store_path)
  store_was_created_here <- TRUE
  on.exit({
    if (store_was_created_here && !is.null(store)) {
      tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
    }
  }, add = TRUE)
} else {
  store <- ragnar_store
}
```

**File:** `R/db.R` — `search_chunks_hybrid()` function.

**No architecture changes.** Local fix inside one function.

### Tech Debt #118: section_hint not encoded in PDF ragnar origins

**Root cause:** `insert_chunks_to_ragnar()` in `R/_ragnar.R` creates `ragnar_chunks` with `origin = chunks$origin`, but the `section_hint` detected by `detect_section_hint()` in `pdf.R` is stored in the chunks data frame as `chunks$section_hint` — it's never encoded into the origin string. The `encode_origin_metadata()` function exists and works, but is only called for abstract indexing (in `mod_search_notebook.R` line ~2013), not for document chunks.

**Fix:** In `insert_chunks_to_ragnar()`, if `chunks` has a `section_hint` column, use `encode_origin_metadata()` to build the origin string:

```r
# R/_ragnar.R: insert_chunks_to_ragnar()
ragnar_chunks <- data.frame(
  origin = vapply(seq_len(nrow(chunks)), function(i) {
    section_hint <- if ("section_hint" %in% names(chunks)) chunks$section_hint[i] else "general"
    encode_origin_metadata(chunks$origin[i], section_hint = section_hint, source_type = "document")
  }, character(1)),
  ...
)
```

**File:** `R/_ragnar.R` — `insert_chunks_to_ragnar()`.

**Impact:** After this fix, `search_chunks_hybrid()` can rely on the decoded section_hint from origin (already implemented in `retrieve_with_ragnar()`), removing the need for the content-prefix lookup in the chunks table (db.R lines 754-786). That lookup can then be removed as a follow-on cleanup.

### Tech Debt #119: Remove dead code with_ragnar_store() and register_ragnar_cleanup()

**Root cause:** These functions exist in `R/_ragnar.R` (lines 296-361) but are never called anywhere in the codebase. They were written during Phase 21 planning as candidate patterns but the actual implementation used a different approach.

**Fix:** Delete both functions from `R/_ragnar.R`. Verify with `grep -r "with_ragnar_store\|register_ragnar_cleanup"` before deletion.

---

## New Components Required

| Component | Type | File | Why New |
|-----------|------|------|---------|
| `generate_lit_review_table()` | Function | `R/rag.R` | No existing preset does retrieve-all + tabular output |
| `generate_research_questions()` | Function | `R/rag.R` | New prompt pattern + section-targeted retrieval |
| `btn_overview` button | UI | `mod_document_notebook.R`, `mod_search_notebook.R` | Replaces two buttons |
| `btn_lit_review` button | UI | `mod_search_notebook.R` (offcanvas) | New feature |
| `btn_rq_generator` button | UI | `mod_search_notebook.R` (offcanvas) | New feature |

## Modified Components

| Component | Modification | Impact |
|-----------|-------------|--------|
| `generate_preset()` in `R/rag.R` | Add "overview" to presets named list | Zero impact on other presets |
| `mod_document_notebook.R` | Remove `btn_summarize`, `btn_keypoints`; add `btn_overview`; update handlers | UI change only |
| `mod_search_notebook.R` | Add `btn_lit_review`, `btn_rq_generator` to offcanvas preset row | Additive |
| `search_chunks_hybrid()` in `R/db.R` | Add `on.exit()` for connection cleanup | Purely internal, no API change |
| `insert_chunks_to_ragnar()` in `R/_ragnar.R` | Encode section_hint into origin field | Affects future-uploaded chunks only; existing stores unaffected |
| `R/_ragnar.R` | Delete `with_ragnar_store()` and `register_ragnar_cleanup()` | Dead code removal, zero runtime impact |

---

## How Structured Table Output Integrates with Shiny/bslib

**Verdict: Use GFM markdown tables for v4.0. The render path already supports them.**

Evidence: `commonmark::markdown_html(msg$content, extensions = TRUE)` is the current render call (both `mod_document_notebook.R:613` and `mod_search_notebook.R:2179`). The `extensions = TRUE` parameter enables GitHub-Flavored Markdown table parsing. A well-formed GFM table in the LLM response will render as a styled HTML table.

**Styling concern:** Bootstrap 5 (bslib default) does not automatically style `<table>` elements. The rendered table will appear unstyled. Fix with CSS targeting `.chat-markdown table`:

```css
/* Add to app.R or a www/custom.css file */
.chat-markdown table {
  border-collapse: collapse;
  width: 100%;
  margin: 1rem 0;
  font-size: 0.875rem;
}
.chat-markdown table th,
.chat-markdown table td {
  border: 1px solid #dee2e6;
  padding: 0.5rem 0.75rem;
  text-align: left;
}
.chat-markdown table thead th {
  background-color: var(--bs-light);
  font-weight: 600;
}
.chat-markdown table tbody tr:nth-child(odd) {
  background-color: rgba(0,0,0,0.02);
}
```

This CSS is scoped to `.chat-markdown` (the div class already on all assistant messages in both modules), so it cannot leak to other UI sections.

**Alternative if LLM table quality is poor:** Build the table in R from per-paper API calls (one call per paper asking for structured fields). This is more expensive but reliable. Defer to v4.1 if needed.

---

## Suggested Build Order

### Phase 1: Bug Fixes and Tech Debt (No Feature Risk)

Fix bugs and tech debt first. These are self-contained, reduce noise, and unblock clean implementation of new features.

1. **#119 Dead code removal** — Delete `with_ragnar_store()` and `register_ragnar_cleanup()` from `R/_ragnar.R`. Pure deletion, zero risk.

2. **#117 Connection leak** — Add `on.exit()` in `search_chunks_hybrid()`. Single-function change. Write a test that calls `search_chunks_hybrid()` multiple times and verify no accumulating handles.

3. **#118 section_hint encoding** — Fix `insert_chunks_to_ragnar()` to call `encode_origin_metadata()`. Affects new uploads only; existing stores continue working. The downstream content-prefix lookup (db.R:754-786) can stay or be removed as a follow-on; don't remove it in this phase (regression risk).

4. **#111 Modal repeating** — Fix observer registration in `mod_search_notebook.R` delete handler.

5. **#110 Seed paper missing** — Trace `seed_request` reactive flow from `mod_search_notebook.R` through `app.R` and verify `paper_refresh()` fires after seed import.

6. **#116 Cost tracking** — Update static price table in `api_openrouter.R`. Add `# Last updated: 2026-02-18` comment.

7. **#86 Refresh button behavior** — Decide and document: should Refresh add papers up to the configured count after removals? If yes, modify `do_search_refresh()` to subtract existing papers from the requested count before querying OpenAlex.

### Phase 2: Unified Overview Preset

Simplest new feature. No new files, minimal code change.

8. Add `"overview"` entry to `presets` list in `generate_preset()` (`R/rag.R`)
9. Replace `btn_summarize` + `btn_keypoints` with `btn_overview` in `mod_document_notebook.R`
10. Update the button group in `mod_search_notebook.R` if applicable

**Dependency:** None. Can be done in isolation.

### Phase 3: Research Question Generator

Follows exactly the same pattern as `generate_conclusions_preset()`.

11. Add `generate_research_questions()` to `R/rag.R` — copy structure of `generate_conclusions_preset()`, change the prompt
12. Add `btn_rq_generator` to `mod_search_notebook.R` offcanvas preset row
13. Add `observeEvent(input$btn_rq_generator, ...)` handler in server

**Dependency:** Phase 2 complete (ensures button layout patterns are settled).

### Phase 4: Literature Review Table

Most complex feature. Do last because it has a CSS component and an LLM reliability risk.

14. Add `.chat-markdown table` CSS styling (in `app.R` with `tags$style()` or `www/custom.css`)
15. Add `generate_lit_review_table()` to `R/rag.R` — direct DB retrieval, tabular prompt
16. Add `btn_lit_review` to `mod_search_notebook.R` offcanvas preset row
17. Add `observeEvent(input$btn_lit_review, ...)` handler in server
18. Test with real notebook data; adjust prompt if output quality is poor

**Dependency:** CSS styling (step 14) must be in place before testing, otherwise table renders but is unreadable.

---

## Data Flow: Literature Review Table (Full)

```
btn_lit_review click
    ↓
is_processing(TRUE)
messages() += {role: "user", content: "Generate: Literature Review Table"}
    ↓
generate_lit_review_table(con, cfg, nb_id, session_id)
    ↓
  # Retrieve all papers (not RAG — need ALL for comparison)
  papers <- dbGetQuery(con,
    "SELECT title, authors, year, abstract FROM abstracts
     WHERE notebook_id = ? AND abstract IS NOT NULL
     ORDER BY year DESC LIMIT 30",  # Cap at 30 for context window
    list(nb_id))
    ↓
  if (nrow(papers) == 0) return("No papers with abstracts found.")
    ↓
  # Build structured context (not build_context() which formats for prose RAG)
  paper_blocks <- paste(lapply(seq_len(nrow(papers)), function(i) {
    p <- papers[i,]
    sprintf("[%d] %s (%s). %s. Abstract: %s",
            i, p$title, p$year, p$authors, substr(p$abstract, 1, 500))
  }), collapse = "\n\n")
    ↓
  system_prompt <- "You are a research synthesis tool.
Output ONLY a GitHub-Flavored Markdown table.
Columns: | # | Author(s) & Year | Research Question | Methodology | Key Finding | Limitation |
One row per paper. No prose before or after the table."
  user_prompt <- sprintf("Papers:\n%s\n\nGenerate the comparison table.", paper_blocks)
    ↓
  result <- chat_completion(api_key, model, messages)
  log_cost(con, "lit_review_table", model, ...)
  return(result$content)
    ↓
messages() += {role: "assistant", content: <GFM table string>, preset_type: "lit_review"}
    ↓
output$messages renderUI:
  HTML(commonmark::markdown_html(msg$content, extensions = TRUE))
  → <table class applied via .chat-markdown CSS>
```

---

## Component Boundaries

| Component | Owns | Does NOT Own |
|-----------|------|-------------|
| `mod_document_notebook.R` | Button UI, message state, send/preset handlers | RAG logic, prompt text, API calls |
| `mod_search_notebook.R` | Same as above + paper list state | Same as above |
| `R/rag.R` | Prompt templates, retrieval strategy, cost logging | API transport, DB schema, UI rendering |
| `R/api_openrouter.R` | HTTP transport, request/response format | Prompt construction, business logic |
| `R/_ragnar.R` | Vector store lifecycle, chunk insert/retrieve | Prompt logic, Shiny UI |
| `R/db.R` | DB queries, schema migrations | RAG logic, API calls |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Adding RAG Retrieval to Literature Review Table

**What people might do:** Use `search_chunks_hybrid()` to retrieve "relevant" chunks for the table.

**Why it's wrong:** RAG retrieval returns semantically similar chunks (top-k), meaning papers that aren't similar to the query are omitted. A comparison matrix needs all papers to be meaningful. Selective retrieval produces a biased or incomplete table.

**Do this instead:** Direct SQL query for all abstracts in the notebook, with a cap (e.g., 30) for context window safety.

### Anti-Pattern 2: Returning Structured Data Through the Message Pipeline

**What people might do:** Add `content_type = "table"` to message objects and branch the render logic.

**Why it's wrong:** It complicates the message pipeline, breaks export (which assumes string content), and adds a new code path to test. The existing pipeline handles GFM markdown tables natively.

**Do this instead:** Keep the message content as a string. Use GFM tables. Style with CSS. If richer table interaction is needed later, it can be added as a standalone UI element, not through the chat pipeline.

### Anti-Pattern 3: Modifying messages() List Structure for New Presets

**What people might do:** Add new fields to message objects beyond `{role, content, timestamp, preset_type}`.

**Why it's wrong:** The message list structure is used by both `output$messages` rendering and by `format_chat_as_markdown()` / `format_chat_as_html()` export. Adding undocumented fields creates a silent contract that must be maintained in all consumers.

**Do this instead:** Only add `preset_type` to distinguish rendering behavior. All other differentiation should be in the content string itself.

### Anti-Pattern 4: One-Off Presets in Module Files

**What people might do:** Put the prompt text directly in `mod_search_notebook.R` `observeEvent` handlers.

**Why it's wrong:** Prompt text belongs in `R/rag.R`. This is the existing pattern and makes prompts testable and discoverable in one file.

**Do this instead:** Add prompt functions to `R/rag.R`, call them from the module observers. Keep observers thin (is_processing, messages update, function call, cost logging call).

---

## CSS Integration for Table Styling

**Location decision:** Add to `app.R` using a `tags$style()` call in the UI definition rather than a separate `www/custom.css` file. The project has no `www/` directory currently, and adding one for a small CSS block is unnecessary overhead.

```r
# In app.R UI definition, after bslib theme setup:
tags$style(HTML("
  .chat-markdown table {
    border-collapse: collapse;
    width: 100%;
    margin: 1rem 0;
    font-size: 0.875rem;
    overflow-x: auto;
    display: block;
  }
  .chat-markdown table th,
  .chat-markdown table td {
    border: 1px solid #dee2e6;
    padding: 0.4rem 0.6rem;
    text-align: left;
    vertical-align: top;
  }
  .chat-markdown table thead th {
    background-color: var(--bs-light);
    font-weight: 600;
    white-space: nowrap;
  }
  .chat-markdown table tbody tr:nth-child(odd) {
    background-color: rgba(0,0,0,0.02);
  }
"))
```

The `display: block; overflow-x: auto` on the table allows horizontal scrolling for wide tables without breaking the card layout.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Bug fix root causes | HIGH | Confirmed by reading specific code lines |
| Overview preset integration | HIGH | Identical to existing pattern, minimal change |
| Research Question Generator integration | HIGH | Direct copy of conclusions_preset pattern |
| Literature Review Table (GFM path) | MEDIUM | LLM compliance with "only table" instructions is model-dependent; needs testing |
| Literature Review Table (CSS) | HIGH | Bootstrap 5 + `.chat-markdown` scoping is safe |
| Build order | HIGH | Dependencies are clear and low-coupling |
| Connection leak fix | HIGH | Root cause confirmed; on.exit() is the correct R pattern |
| section_hint encoding fix | HIGH | Root cause confirmed; encode_origin_metadata() already exists |

---

## Sources

- Direct codebase analysis: `R/rag.R`, `R/db.R`, `R/_ragnar.R`, `mod_document_notebook.R`, `mod_search_notebook.R`, `R/api_openrouter.R`, `R/utils_export.R`
- GitHub issue analysis: #98, #99, #102, #110, #111, #116, #117, #118, #119
- commonmark R package documentation (GFM table extension support)
- Bootstrap 5 table styling documentation

---
*Architecture research for: Serapeum v4.0 Stability + Synthesis features*
*Researched: 2026-02-18*
