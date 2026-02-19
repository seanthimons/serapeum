# Phase 26: Unified Overview Preset - Research

**Researched:** 2026-02-19
**Domain:** R/Shiny preset system, bslib popover UX, LLM prompt engineering, token-limited batching
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Output structure
- Two-section format: Summary paragraph(s) first, then Key Points grouped by theme below
- Summary depth is user-selectable: Concise (1-2 paragraphs) or Detailed (3-4 paragraphs)
- Key Points are organized under thematic subheadings (e.g., Methodology, Findings, Gaps) — not a flat list

#### Preset transition
- Remove both Summarize and Key Points buttons entirely — Overview fully replaces them
- Existing chat messages from old presets are left as-is in history (still render, just can't generate new ones)

#### LLM call strategy
- User-selectable: "Quick" (single LLM call) vs "Thorough" (two separate calls for summary and key points)
- Framed as Speed vs Quality tradeoff in the UI

#### Button & naming
- Label: "Overview"
- Click triggers a popover with two options: depth (Concise/Detailed) and quality (Quick/Thorough), then a "Generate" confirm button
- Popover always resets to defaults (Concise + Quick) — no persisted state
- Button placed in the same slot where Summarize/Key Points currently are, in both document and search notebook preset panels

#### Content scope
- Overview covers ALL papers in the notebook (not RAG top-k retrieval)
- For large notebooks that exceed token limits: batch papers into groups, make parallel LLM calls to OpenRouter, then concatenate results
- Concatenation strategy for now (stitch batch results together); flag as future TODO if model compliance across batches diverges

### Claude's Discretion
- Exact prompt engineering for the Overview system/user prompts
- Batch size threshold (when to switch from single call to parallel batching)
- Popover styling and animation
- Icon choice for the Overview button
- Default ordering of thematic subheadings in Key Points section

### Deferred Ideas (OUT OF SCOPE)
- Prompt inspection/editing UI — A control plane in Settings where users can view the prompt being sent to models (without data) and make one-off adjustments. Suggested as a debugging tool. — future phase
</user_constraints>

---

## Summary

Phase 26 replaces the existing `btn_summarize` and `btn_keypoints` buttons in both the document notebook and search notebook preset panels with a single "Overview" button. The Overview button uses a bslib `popover()` containing two radio options (depth: Concise/Detailed; mode: Quick/Thorough) and a Generate action button. Clicking Generate invokes a new `generate_overview_preset()` function in `R/rag.R`.

The core technical distinction from existing presets is **data retrieval strategy**: existing presets like `summarize` and `keypoints` use a `LIMIT 50` SQL query against chunks (top-50 chunks). The Overview preset uses ALL abstracts/documents directly from the database (not RAG top-k), which matches the scope decision. For large notebooks, the implementation batches papers into groups and makes parallel calls using the existing `chat_completion()` function, then concatenates results.

The output renders in the chat panel with the AI-Generated Content disclaimer banner (same as `conclusions` preset), since Overview is explicitly a synthesis operation.

**Primary recommendation:** Add `generate_overview_preset()` to `R/rag.R` following the `generate_conclusions_preset()` pattern; replace the two existing buttons with a single bslib `popover()`-wrapped Overview button in both notebook modules; use `renderUI()` for the button so it can be disabled when RAG is unavailable.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | 0.9.0 | `popover()` component for the options UI | Already installed; has native `popover()` with `trigger`, content, and `id` params |
| DBI/DuckDB | existing | Direct SQL to retrieve all abstracts/documents | Already used; Overview bypasses RAG in favor of full-corpus SQL |
| httr2 | existing | `chat_completion()` for LLM calls | Already the API client; used directly in `generate_overview_preset()` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| commonmark | existing | `markdown_html()` for rendering output | Already used in `output$messages` render loop |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bslib `popover()` | Bootstrap 5 raw HTML popover via `data-bs-toggle="popover"` | Raw HTML works but requires manual JS initialization on each render; bslib handles it automatically and is consistent with the rest of the codebase |
| bslib `popover()` | `showModal()`/`modalDialog()` | Modal is heavier UX; user chose popover for lightweight inline options |
| Sequential calls (Thorough mode) | Parallel calls with `mirai` | Sequential is simpler and sufficient for 2 calls; mirai is used for long-running operations. Thorough mode only makes 2 LLM calls so sequential is acceptable |

---

## Architecture Patterns

### Recommended Project Structure

No new files needed. Changes are confined to:
```
R/
├── rag.R                    # Add generate_overview_preset()
├── mod_document_notebook.R  # Replace btn_summarize + btn_keypoints with Overview popover
└── mod_search_notebook.R    # Replace btn_conclusions area with Overview popover
```

### Pattern 1: bslib Popover as Button Wrapper

**What:** `bslib::popover()` wraps an `actionButton()` trigger. The popover body contains radio inputs and a Generate action button.

**When to use:** When a button needs inline options before execution — avoids modal overhead.

**Signature (verified from installed bslib 0.9.0):**
```r
popover(trigger, ..., title = NULL, id = NULL,
        placement = c("auto","top","right","bottom","left"),
        options = list())
```

**Example pattern for Overview button:**
```r
# In UI (inside btn-group div):
popover(
  trigger = actionButton(
    ns("btn_overview"),
    "Overview",
    class = "btn-sm btn-outline-primary",
    icon = icon("layer-group")  # or "rectangle-list", "file-circle-plus"
  ),
  title = "Overview Options",
  id = ns("overview_popover"),
  placement = "bottom",
  # Popover body content:
  div(
    radioButtons(
      ns("overview_depth"),
      "Summary Depth",
      choices = c("Concise (1-2 paragraphs)" = "concise",
                  "Detailed (3-4 paragraphs)" = "detailed"),
      selected = "concise"
    ),
    radioButtons(
      ns("overview_mode"),
      "Quality Mode",
      choices = c("Quick (single call)" = "quick",
                  "Thorough (two calls)" = "thorough"),
      selected = "quick"
    ),
    actionButton(ns("btn_overview_generate"), "Generate",
                 class = "btn-primary btn-sm w-100")
  )
)
```

**CRITICAL:** The `id` param on `popover()` is the popover widget ID, NOT namespaced — but the `trigger` button and inner inputs MUST use `ns()`. The `toggle_popover()` function uses the raw popover id to dismiss it from the server: `toggle_popover(id = ns("overview_popover"))`.

**Popover reset to defaults:** Since the user chose "always reset," do NOT use `updateRadioButtons()` to persist — just let Shiny rebuild the UI naturally. The `selected` values are hard-coded to defaults and Shiny resets them each session already.

### Pattern 2: Full-Corpus SQL Retrieval (not RAG)

**What:** Query ALL abstracts/documents for the notebook rather than top-k from ragnar.

**Why:** Overview is a synthesis of the entire notebook, not a RAG query. This matches how `generate_preset()` already works for summarize/keypoints with `LIMIT 50` — but Overview removes the LIMIT since it covers all content.

**For search notebooks:**
```r
# Get all abstracts with non-empty abstracts for this notebook
abstracts <- dbGetQuery(con,
  "SELECT id, title, abstract, authors, year, venue
   FROM abstracts
   WHERE notebook_id = ?
     AND abstract IS NOT NULL
     AND LENGTH(abstract) > 0
   ORDER BY year DESC",
  list(notebook_id)
)
```

**For document notebooks:**
```r
# Get all chunks for documents in this notebook
chunks <- dbGetQuery(con,
  "SELECT c.content, d.filename as doc_name, c.page_number
   FROM chunks c
   JOIN documents d ON c.source_id = d.id
   WHERE d.notebook_id = ?
   ORDER BY d.created_at, c.chunk_index",
  list(notebook_id)
)
```

### Pattern 3: Batching for Token Limits

**What:** When total content exceeds a threshold, split into groups, call LLM for each group, concatenate.

**Batch threshold recommendation (Claude's discretion):** Use character count as a proxy for token count. Each token is approximately 4 characters. For a 128k context model, safe content budget is ~80k tokens = ~320k characters. Default batch size: **20 papers per batch** for search notebooks (abstracts average ~1500 chars each, so 20 papers = ~30k chars, leaving headroom for prompt + response). For document notebooks, use **10 chunks per batch** (PDF chunks can be ~500 chars each).

**Batching logic for search notebooks:**
```r
# In generate_overview_preset()
BATCH_SIZE <- 20L  # papers per batch

if (nrow(abstracts) <= BATCH_SIZE) {
  # Single call
  overview_text <- call_overview_llm(abstracts, depth, api_key, chat_model, ...)
} else {
  # Batch into groups
  batches <- split(seq_len(nrow(abstracts)),
                   ceiling(seq_len(nrow(abstracts)) / BATCH_SIZE))
  batch_results <- lapply(batches, function(idx) {
    call_overview_llm(abstracts[idx, ], depth, api_key, chat_model, ...)
  })
  overview_text <- paste(batch_results, collapse = "\n\n---\n\n")
  # TODO (future): if batch divergence causes inconsistency, add merge-pass LLM call
}
```

**Note on "Thorough" mode with batching:** Thorough mode makes 2 LLM calls (summary call + key points call) sequentially. If batching is also needed, each of those 2 calls batches independently. The result is: summary batches concatenated, then key points batches concatenated, then the two sections combined.

### Pattern 4: AI Disclaimer Banner

**What:** Overview is a synthesis preset — it must show the AI-Generated Content banner, identical to `conclusions`.

**Current implementation (in both `output$messages` render loops):**
```r
is_synthesis <- !is.null(msg$preset_type) && identical(msg$preset_type, "conclusions")
```

**Change needed:** Expand this check to also match `"overview"`:
```r
is_synthesis <- !is.null(msg$preset_type) &&
                msg$preset_type %in% c("conclusions", "overview")
```

**Message tagging:** When adding the overview response to `messages()`:
```r
msgs <- c(msgs, list(list(
  role = "assistant",
  content = response,
  timestamp = Sys.time(),
  preset_type = "overview"  # triggers disclaimer banner
)))
```

### Pattern 5: Disabled Button State (rag_available guard)

The Overview button should be disabled when `rag_available()` is FALSE (store unhealthy), consistent with the Conclusions button pattern.

**In search notebook**, Conclusions is rendered via `output$conclusions_btn_ui` as a `renderUI`. Overview should follow the same pattern — a `renderUI` output replacing the static btn-group.

**In document notebook**, the preset buttons are currently static HTML (not `renderUI`). However, Overview can gate behind `req(rag_available())` in the `observeEvent(input$btn_overview_generate)` handler instead.

**Recommendation:** For consistency, wrap the Overview button in a `renderUI` in both notebooks so the disabled state is visible, not just blocked server-side.

### Anti-Patterns to Avoid

- **Modifying popover trigger via observeEvent(input$btn_overview):** The `btn_overview` actionButton is the popover trigger — clicking it just opens the popover. Do NOT attach `observeEvent(input$btn_overview, ...)` for the LLM call. Instead, observe `input$btn_overview_generate` (the Generate button inside the popover).
- **Using LIMIT in the full-corpus query:** Unlike `generate_preset()` which caps at 50 chunks, Overview must not cap. Remove LIMIT to honor the "all papers" scope decision.
- **Persisting popover state:** Don't store depth/mode selections in DB or reactive state. The user chose "always reset to defaults."
- **Forgetting to dismiss the popover after Generate:** Call `toggle_popover(id = ns("overview_popover"))` or use `shinyjs::click()` after the Generate button is pressed, so the popover closes while the LLM is running.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Popover component | Custom JS popover with `data-bs-toggle` + manual init | `bslib::popover()` | bslib handles Bootstrap 5 lifecycle correctly; manual init breaks on dynamic UI |
| Token estimation | Character counting or tiktoken port | Simple heuristic (chars / 4) as a proxy | Exact token counting requires model-specific tokenizer; heuristic is sufficient for batch splitting |
| Parallel LLM calls | Custom async workers | Sequential `lapply` for 2 calls (Thorough mode), or simple sequential batching | Overhead not justified for 2 calls; mirai is reserved for long file operations |

**Key insight:** The `chat_completion()` function in `api_openrouter.R` is already the right abstraction. Overview calls it directly, same as `generate_conclusions_preset()`.

---

## Common Pitfalls

### Pitfall 1: Popover Body Inputs Not Namespaced
**What goes wrong:** `input$overview_depth` is undefined because the radio button ID was not wrapped in `ns()`.
**Why it happens:** HTML `id` attributes inside `popover()` content must be namespaced like any other Shiny input inside a module.
**How to avoid:** Always use `ns("overview_depth")`, `ns("overview_mode")`, `ns("btn_overview_generate")` for all inputs inside the popover body.
**Warning signs:** `input$overview_depth` returns NULL in the server even after clicking.

### Pitfall 2: Overview Button in Search Notebook Uses Wrong Panel Slot
**What goes wrong:** Overview button is added to the main paper panel instead of the offcanvas chat panel's preset row.
**Why it happens:** The search notebook has two distinct areas — the main layout_columns area and the offcanvas chat. The existing Conclusions button is in `div(class = "border-bottom px-3 py-2", div(class = "btn-group btn-group-sm w-100", uiOutput(ns("conclusions_btn_ui"))))` inside the offcanvas body.
**How to avoid:** Place the Overview `renderUI` output in the same offcanvas preset row where `conclusions_btn_ui` currently lives. Replace `conclusions_btn_ui` with `overview_btn_ui`.

### Pitfall 3: Summarize/Keypoints observeEvent Handlers Still Present
**What goes wrong:** After removing the UI buttons, the server still has `observeEvent(input$btn_summarize, ...)` and `observeEvent(input$btn_keypoints, ...)`. These are harmless (they never fire) but are dead code.
**How to avoid:** Remove the `handle_preset("summarize", ...)` and `handle_preset("keypoints", ...)` observeEvent calls from the server. Also remove `btn_summarize` and `btn_keypoints` from the `handle_preset` dispatch block.

### Pitfall 4: Token Budget Exceeded Without Batching
**What goes wrong:** A notebook with 200+ papers sends all abstracts to the LLM in a single call. The request fails with a context length exceeded error.
**Why it happens:** `generate_preset()` used LIMIT 50 as a safety cap; Overview removes that limit but doesn't implement batching.
**How to avoid:** Implement batch size check before calling the LLM. Use char count as proxy: if `sum(nchar(abstracts$abstract)) > 300000`, switch to batched mode. Set BATCH_SIZE = 20 as the default.

### Pitfall 5: User Message Label for Overview
**What goes wrong:** The user message in the chat history shows "Generate: undefined" because the label is not passed to the message builder.
**Why it happens:** Looking at the existing `handle_preset()` helper, it takes a `label` parameter: `list(role = "user", content = paste("Generate:", label), ...)`. The Overview handler must build a richer label that includes depth/mode.
**How to avoid:** Build the user message label dynamically: `paste0("Generate: Overview (", depth_label, ", ", mode_label, ")")`.

---

## Code Examples

Verified patterns from the existing codebase:

### Existing: generate_conclusions_preset() call pattern
```r
# In mod_document_notebook.R server, Conclusions handler:
observeEvent(input$btn_conclusions, {
  req(!is_processing())
  req(has_api_key())
  is_processing(TRUE)

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = "Generate: Conclusion Synthesis",
    timestamp = Sys.time(),
    preset_type = "conclusions"
  )))
  messages(msgs)

  nb_id <- notebook_id()
  cfg <- config()

  response <- tryCatch({
    generate_conclusions_preset(con(), cfg, nb_id,
                                notebook_type = "document",
                                session_id = session$token)
  }, error = function(e) {
    sprintf("Error: %s", e$message)
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "conclusions"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### New: Overview handler (document notebook)
```r
observeEvent(input$btn_overview_generate, {
  req(!is_processing())
  req(has_api_key())
  is_processing(TRUE)

  depth <- input$overview_depth %||% "concise"
  mode  <- input$overview_mode  %||% "quick"

  # Close popover
  toggle_popover(id = ns("overview_popover"))

  depth_label <- if (depth == "concise") "Concise" else "Detailed"
  mode_label  <- if (mode == "quick") "Quick" else "Thorough"

  msgs <- messages()
  msgs <- c(msgs, list(list(
    role = "user",
    content = paste0("Generate: Overview (", depth_label, ", ", mode_label, ")"),
    timestamp = Sys.time(),
    preset_type = "overview"
  )))
  messages(msgs)

  nb_id <- notebook_id()
  cfg <- config()

  response <- tryCatch({
    generate_overview_preset(
      con(), cfg, nb_id,
      notebook_type = "document",
      depth = depth,
      mode = mode,
      session_id = session$token
    )
  }, error = function(e) {
    sprintf("Error: %s", e$message)
  })

  msgs <- c(msgs, list(list(
    role = "assistant",
    content = response,
    timestamp = Sys.time(),
    preset_type = "overview"
  )))
  messages(msgs)
  is_processing(FALSE)
})
```

### New: generate_overview_preset() skeleton in rag.R
```r
#' Generate unified Overview preset (Summary + Key Points)
#'
#' Covers ALL content in the notebook (not RAG top-k).
#' Supports Concise/Detailed depth and Quick/Thorough mode.
#'
#' @param con Database connection
#' @param config App config
#' @param notebook_id Notebook ID
#' @param notebook_type "document" or "search"
#' @param depth "concise" or "detailed"
#' @param mode "quick" (single call) or "thorough" (two calls)
#' @param session_id Optional session ID for cost logging
#' @return Generated markdown content
generate_overview_preset <- function(con, config, notebook_id,
                                     notebook_type = "document",
                                     depth = "concise",
                                     mode = "quick",
                                     session_id = NULL) {
  api_key <- get_setting(config, "openrouter", "api_key")
  if (length(api_key) > 1) api_key <- api_key[1]

  chat_model <- get_setting(config, "defaults", "chat_model") %||%
    "anthropic/claude-sonnet-4"

  # Check api_key
  api_key_empty <- is.null(api_key) || isTRUE(is.na(api_key)) ||
    (is.character(api_key) && nchar(api_key) == 0)
  if (api_key_empty) {
    return("Error: OpenRouter API key not configured.")
  }

  # Retrieve ALL content (not RAG top-k)
  if (notebook_type == "document") {
    content_df <- dbGetQuery(con, "
      SELECT c.content, d.filename as source_name, c.page_number
      FROM chunks c
      JOIN documents d ON c.source_id = d.id
      WHERE d.notebook_id = ?
      ORDER BY d.created_at, c.chunk_index
    ", list(notebook_id))
    content_col <- "content"
    label_col   <- "source_name"
  } else {
    content_df <- dbGetQuery(con, "
      SELECT abstract as content, title as source_name, year
      FROM abstracts
      WHERE notebook_id = ?
        AND abstract IS NOT NULL
        AND LENGTH(abstract) > 0
      ORDER BY year DESC
    ", list(notebook_id))
    content_col <- "content"
    label_col   <- "source_name"
  }

  if (nrow(content_df) == 0) {
    return("No content found in this notebook.")
  }

  # Batch threshold: ~300k chars as single-call limit
  BATCH_SIZE   <- if (notebook_type == "document") 10L else 20L
  CHAR_LIMIT   <- 300000L
  total_chars  <- sum(nchar(content_df[[content_col]]), na.rm = TRUE)
  use_batching <- total_chars > CHAR_LIMIT || nrow(content_df) > BATCH_SIZE * 2

  # [summary prompt + key points prompt built from depth/mode params]
  # ... (see Prompt Engineering section below)
}
```

---

## Prompt Engineering (Claude's Discretion)

### Depth Parameters
- **Concise:** "Write a summary of 1-2 paragraphs."
- **Detailed:** "Write a detailed summary of 3-4 paragraphs."

### Single-Call Overview Prompt (Quick mode)

**System prompt:**
```
You are a research synthesis assistant. Generate an Overview of the provided research sources.
The Overview must have exactly two sections:

## Summary
[depth_instruction]
Cover main themes, key findings, and important conclusions.
Base your summary ONLY on the provided sources.

## Key Points
Organize key points under thematic subheadings (e.g., ## Methodology, ## Findings, ## Limitations, ## Future Directions).
Each subheading should contain 3-5 bullet points.
Do not use a flat list — group related points together.

IMPORTANT: Base all content ONLY on the provided sources. Do not invent findings.
```

**User prompt:**
```
===== BEGIN SOURCES =====
[formatted sources]
===== END SOURCES =====

Generate an Overview with a Summary and thematically organized Key Points.
```

### Two-Call Overview Prompt (Thorough mode)

**Call 1 — Summary only:**
System: `You are a research summarizer. Write a [concise/detailed] summary of the provided research.`
User: `[sources] ... Write a [concise: 1-2 paragraph / detailed: 3-4 paragraph] summary.`

**Call 2 — Key Points only:**
System: `You are a research analyst. Extract key points organized by theme from the provided research.`
User: `[sources] ... Extract key points organized under thematic subheadings (e.g., Methodology, Findings, Limitations, Future Directions). Each section: 3-5 bullet points.`

**Merge:** Concatenate as `## Summary\n{call1_result}\n\n## Key Points\n{call2_result}`.

### Default Thematic Subheading Order (Claude's Discretion)
Recommended order: **Background/Context → Methodology → Findings/Results → Limitations → Future Directions/Gaps**

This follows the standard IMRAD structure that readers expect, making it predictable.

### Icon Choice (Claude's Discretion)
Recommended: `icon("layer-group")` — visually communicates "combined/unified" concept, available in Font Awesome 6 (which Shiny uses). Alternative: `icon("rectangle-list")`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate Summarize and Key Points buttons | Single Overview button with popover options | Phase 26 | Reduces preset count, unifies UX |
| LIMIT 50 SQL query for presets | Full corpus SQL query (no LIMIT) for Overview | Phase 26 | Overview covers all content |
| Top-k RAG for conclusions preset | Same top-k RAG for conclusions (unchanged) | N/A | Conclusions stays separate |

**Existing deprecated in this phase:**
- `btn_summarize` (actionButton): removed from both notebook UIs
- `btn_keypoints` (actionButton): removed from both notebook UIs
- `handle_preset("summarize", ...)` observeEvent: removed from document notebook server
- `handle_preset("keypoints", ...)` observeEvent: removed from document notebook server
- `presets$summarize` and `presets$keypoints` entries in `generate_preset()`: can stay (they are dead code but harmless; removing them reduces clutter)

---

## Open Questions

1. **Search notebook: where exactly does the Overview button go?**
   - What we know: The Conclusions button lives in the offcanvas chat panel's preset row (`output$conclusions_btn_ui`), rendered as a `renderUI` with disabled state. This is the correct slot.
   - What's unclear: Does Overview fully replace Conclusions, or do both coexist? (Based on CONTEXT.md, Overview replaces only Summarize/Key Points; Conclusions stays. So both Overview and Conclusions should be in the offcanvas preset row.)
   - Recommendation: Rename `output$conclusions_btn_ui` → `output$preset_btns_ui` (or add `output$overview_btn_ui` as a sibling). Both buttons in the same `btn-group`.

2. **Cost logging category name for overview**
   - What we know: `generate_conclusions_preset()` logs with category `"conclusion_synthesis"`.
   - What's unclear: Should overview use `"overview"`, `"overview_quick"`, or `"overview_thorough"`?
   - Recommendation: Use `"overview"` for Quick mode, `"overview_summary"` and `"overview_keypoints"` for Thorough mode's two calls. This gives granular cost tracking.

3. **Popover dismissal after Generate is clicked**
   - What we know: `bslib::toggle_popover(id)` can programmatically show/hide a popover from the server.
   - What's unclear: Does the popover `id` need `ns()` prefix when calling `toggle_popover()` from inside the module?
   - Recommendation: Based on bslib patterns, pass `id = ns("overview_popover")` to `toggle_popover()`. Test this during implementation.

---

## Sources

### Primary (HIGH confidence)
- Verified from installed bslib 0.9.0: `args(popover)`, `ls(getNamespace('bslib'))` — confirmed `popover()`, `toggle_popover()`, `update_popover()` exist
- Read `R/rag.R` directly — confirmed `generate_preset()` and `generate_conclusions_preset()` patterns
- Read `R/mod_document_notebook.R` directly — confirmed button positions, `handle_preset()` dispatch, message tagging
- Read `R/mod_search_notebook.R` directly — confirmed offcanvas chat structure, `conclusions_btn_ui` renderUI pattern
- Read `R/api_openrouter.R` directly — confirmed `chat_completion()` signature
- Read `R/db.R` directly — confirmed `list_abstracts()`, `abstracts` table schema

### Secondary (MEDIUM confidence)
- bslib popover documentation pattern inferred from `args(popover)` + existing Bootstrap 5 dropdown patterns in codebase

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — bslib 0.9.0 installed and verified; all functions confirmed
- Architecture: HIGH — patterns directly traced from existing codebase code paths
- Prompt engineering: MEDIUM — recommendations from first principles and LLM best practices; validate during implementation
- Batching threshold: MEDIUM — heuristic (20 papers / 300k chars); may need tuning
- Pitfalls: HIGH — traced from reading actual code, not speculation

**Research date:** 2026-02-19
**Valid until:** 2026-03-19 (30 days; stable stack)
