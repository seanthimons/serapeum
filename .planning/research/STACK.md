# Stack Research

**Domain:** v4.0 Stability + Synthesis — Overview preset, Literature Review Table, Research Question Generator
**Researched:** 2026-02-18
**Confidence:** HIGH

## Context

This is a SUBSEQUENT MILESTONE on an existing 14,000+ LOC R/Shiny codebase. The validated base stack (R, Shiny, bslib, DuckDB, OpenRouter, ragnar, igraph, visNetwork, commonmark, mirai, ExtendedTask) is NOT re-researched here. This document covers ONLY the additions or changes needed for three new features:

1. **Overview preset** — A unified "Overview" synthesis button that aggregates multiple section-targeted RAG retrievals into one structured response
2. **Literature Review Table** — A structured comparison matrix of papers (methods, findings, limitations) rendered as an interactive table with export
3. **Research Question Generator** — LLM-generated research questions derived from gap analysis across the notebook

---

## Recommended Stack

### New Libraries to Add

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| DT | 0.34.0 | Interactive HTML table widget for Literature Review Table | Mature Shiny-native table package with built-in export buttons (CSV, Excel, copy), server-side rendering, column filtering, and inline styling. Maintained by Posit. DTOutput/renderDT avoid namespace conflicts with Shiny. Does not require Java. |
| writexl | 1.5.4 | Excel export for Literature Review Table via downloadHandler | Zero-dependency (no Java, no Rtools beyond base R). `write_xlsx()` accepts a named list for multi-sheet workbooks. Fastest benchmark performance among R Excel writers. writexl is the right choice when you just need to write clean .xlsx without formatting complexity. |

### Existing Libraries with New Usage Patterns

| Library | Current Version | New Usage | Notes |
|---------|----------------|-----------|-------|
| jsonlite | 2.0.0 | Parse structured JSON returned by LLM (for table row extraction) | Already in project. `jsonlite::fromJSON()` converts LLM JSON output into R data frames. Use `simplifyDataFrame = TRUE` (default) for automatic conversion of JSON arrays of objects. |
| httr2 | 1.2.1 | Add `response_format` parameter to `chat_completion()` calls for JSON mode | Already in project. Pass `response_format = list(type = "json_object")` via `req_body_json()`. No new library needed — this is an API parameter change to the existing `chat_completion()` function. |
| commonmark | 2.0.0 | Render Overview and Research Question outputs (same pattern as existing presets) | No change. Existing markdown-to-HTML pipeline handles all unstructured text outputs. |
| bslib | 0.9.0 | Layout for Literature Review Table card within existing notebook modules | No change. Existing `card()`, `layout_columns()`, and `card_body()` handle the new table container. |

### Libraries Evaluated and Rejected

| Library | Verdict | Reason |
|---------|---------|--------|
| reactable | Rejected | Better aesthetics but no built-in CSV/Excel export without reactable.extras addon. DT Buttons extension provides export natively. For a comparison matrix with export as a primary use case, DT is the direct choice. |
| gt | Rejected | Designed for publication-quality static tables (reports, documents), not interactive Shiny tables with row filtering and CSV download. Heavyweight for this use case. |
| flextable | Rejected | Output targets Word/PowerPoint/HTML reports, not interactive Shiny widgets. Wrong tool for this domain. |
| openxlsx2 | Rejected | Adds significant complexity for formatted workbooks. writexl is sufficient because Literature Review Table export is a flat data frame dump, not a styled report. |
| jsonvalidate | Not needed | Schema validation of LLM JSON output adds latency and complexity with marginal benefit. The LLM JSON mode produces consistently parseable output; `tryCatch(jsonlite::fromJSON(...))` is sufficient error handling. |
| ellmer | Not needed | Posit's new LLM client. Project already has a working, well-tested httr2-based OpenRouter client. Migrating for this milestone creates churn without benefit. |

---

## Structured LLM Output: JSON Mode

The Literature Review Table and Research Question Generator both require the LLM to return structured data (not free-form markdown). The correct approach is OpenRouter's `json_object` mode via `response_format`.

### How to Add to Existing `chat_completion()`

The existing function in `R/api_openrouter.R` uses `req_body_json()`. Add `response_format` as an optional parameter:

```r
chat_completion <- function(api_key, model, messages, response_format = NULL) {
  body <- list(
    model = model,
    messages = messages
  )
  if (!is.null(response_format)) {
    body$response_format <- response_format
  }

  req <- build_openrouter_request(api_key, "chat/completions") |>
    req_body_json(body) |>
    req_timeout(120)
  # ... rest unchanged
}
```

### JSON Mode vs JSON Schema Mode

OpenRouter supports two modes:

| Mode | Parameter | Model Support | Use For |
|------|-----------|---------------|---------|
| `json_object` | `list(type = "json_object")` | Near-universal (all major models) | Literature Review Table rows, Research Questions list |
| `json_schema` | `list(type = "json_schema", json_schema = list(...))` | OpenAI GPT-4o+, Anthropic Sonnet 4.5+, Gemini | Strict schema enforcement |

**Use `json_object` mode** (not `json_schema`) because:
- The user may choose any model from the OpenRouter list — many models don't support `json_schema`
- `json_object` is sufficient: the prompt instructs the exact structure, and `tryCatch(jsonlite::fromJSON())` handles malformed output gracefully
- `json_schema` adds request complexity and fails hard on unsupported models

### Parsing Pattern

```r
# In generate_lit_review_table() or generate_research_questions()
result <- chat_completion(api_key, model, messages,
                          response_format = list(type = "json_object"))

parsed <- tryCatch(
  jsonlite::fromJSON(result$content, simplifyDataFrame = TRUE),
  error = function(e) NULL
)

if (is.null(parsed) || !is.data.frame(parsed$papers)) {
  # Fallback: return error message or re-invoke without json_object mode
  return("Error: Could not parse structured output.")
}

parsed$papers  # Use as data frame
```

---

## DT: Literature Review Table Integration

DT is the correct choice for the Literature Review Table because it:
- Integrates directly with Shiny via `DTOutput()` / `renderDT()`
- Provides built-in export (CSV, copy) via the Buttons extension without additional packages
- Supports column filtering (`filter = "top"`) for searching across paper metadata
- Handles varying column counts gracefully (the matrix columns vary by notebook content)

### Installation

```r
install.packages("DT")  # v0.34.0
```

### Usage Pattern

```r
# UI
DTOutput(ns("lit_review_table"))

# Server
output$lit_review_table <- renderDT({
  df <- lit_review_data()
  req(is.data.frame(df) && nrow(df) > 0)

  datatable(
    df,
    extensions = "Buttons",
    filter = "top",
    rownames = FALSE,
    options = list(
      dom = "Bfrtip",
      buttons = c("copy", "csv"),
      pageLength = 25,
      scrollX = TRUE,
      columnDefs = list(
        list(width = "200px", targets = 0)  # Title column
      )
    ),
    escape = FALSE  # Allow HTML in cells if needed for citations
  )
})
```

### Export Pattern (downloadHandler for .xlsx)

The DT Buttons extension handles CSV client-side. For a formatted Excel download:

```r
downloadHandler(
  filename = function() paste0("literature-review-", Sys.Date(), ".xlsx"),
  content = function(file) {
    writexl::write_xlsx(lit_review_data(), file)
  }
)
```

---

## Overview Preset: No New Libraries Needed

The Overview preset aggregates multiple existing RAG retrievals (introduction, methods, results, conclusions sections) into a single structured markdown response. This is a **prompt engineering and orchestration change**, not a library change.

The existing pipeline handles this completely:
- `search_chunks_hybrid()` with `section_filter` parameter (already implemented)
- `chat_completion()` (existing)
- `commonmark::markdown_html()` for rendering (existing)
- `format_chat_as_markdown()` / `format_chat_as_html()` for export (existing)

No new library additions required.

---

## Research Question Generator: No New Libraries Needed

The Research Question Generator returns a structured list of questions. Two implementation options, both using existing libraries:

**Option A — JSON mode (structured, renderable as list):**
Uses `chat_completion()` with `response_format = list(type = "json_object")` (the same addition needed for Literature Review Table). Returns `{"questions": [...]}` parsed via `jsonlite::fromJSON()`.

**Option B — Markdown mode (simpler, same pattern as other presets):**
Prompt instructs the model to return a numbered markdown list. No JSON parsing needed. Rendered via existing `commonmark::markdown_html()`.

**Recommendation: Option B** for Research Question Generator. A numbered markdown list is easier to read, export, and render than a parsed JSON list. Reserve JSON mode for the Literature Review Table where structured data is required for table rendering.

---

## Installation Summary

```r
# New packages to add
install.packages("DT")       # 0.34.0
install.packages("writexl")  # 1.5.4

# No other additions — all other capabilities use existing packages
```

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| reactable | No built-in export; requires reactable.extras for Shiny interactivity that DT already provides | DT with Buttons extension |
| gt / flextable | Static report output, not interactive Shiny tables | DT |
| openxlsx2 | Overkill for flat data frame export | writexl |
| json_schema mode for response_format | Fails on models without strict schema support (most budget models the user may select) | json_object mode with prompt-guided structure |
| ellmer / chattr | Full LLM client framework migration mid-project creates churn; existing httr2 client works and is tested | Extend existing chat_completion() |
| jsonvalidate | Schema validation of LLM output is over-engineering; tryCatch + fromJSON handles failures | tryCatch(jsonlite::fromJSON()) |

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| DT 0.34.0 | Shiny 1.11.1 | DTOutput/renderDT are the correct Shiny-compatible functions (not dataTableOutput/renderDataTable) |
| DT 0.34.0 | bslib 0.9.0 | DT renders inside bslib cards without issues; Bootstrap 5 theming applies |
| writexl 1.5.4 | R 4.5.1 | No external Java or system dependency required |
| jsonlite 2.0.0 | httr2 1.2.1 | Already used together in api_openrouter.R; `fromJSON()` on `resp_body_json()` output works cleanly |

---

## Sources

- [OpenRouter Structured Outputs docs](https://openrouter.ai/docs/guides/features/structured-outputs) — json_object vs json_schema mode, model support — HIGH confidence (official docs, verified 2026-02-18)
- [OpenRouter API Parameters docs](https://openrouter.ai/docs/api/reference/parameters) — response_format parameter syntax — HIGH confidence
- DT package v0.34.0 — [rdrr.io/cran/DT](https://rdrr.io/cran/DT/) — version confirmed, Buttons extension — HIGH confidence
- reactable v0.4.5 — [CRAN package page](https://cran.r-project.org/web/packages/reactable/index.html) — no built-in export confirmed — HIGH confidence
- writexl v1.5.4 — [rdrr.io/cran/writexl](https://rdrr.io/cran/writexl/) — zero-dependency, current version — HIGH confidence
- jsonlite v2.0.0 — renv.lock (codebase) + [CRAN](https://jeroen.r-universe.dev/jsonlite) — existing dependency confirmed — HIGH confidence
- Existing codebase: `R/api_openrouter.R`, `R/rag.R`, `R/utils_export.R` — integration points verified by direct read — HIGH confidence

---
*Stack research for: v4.0 Stability + Synthesis (Overview preset, Literature Review Table, Research Question Generator)*
*Researched: 2026-02-18*
