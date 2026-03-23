---
title: "fix: v18 Bug Bash Session A — Surgical Fixes"
type: fix
date: 2026-03-22
milestone: v18
issues: [235, 165, 179, 229, 234, 181, 193]
---

# fix: v18 Bug Bash Session A — Surgical Fixes

## Overview

Batch fix for 7 small, well-scoped bugs from the v18 Bug Bash milestone. Each is a one-line to few-line fix with an exact file:line reference. These are independent of each other and can be committed atomically per-fix or batched.

## Bugs & Fixes

### 1. #235 — Missing semicolon in migration 018 CREATE INDEX

**File:** `migrations/018_create_prompt_versions.sql:16`
**Severity:** HIGH — silently drops index creation; existing databases may be missing `idx_prompt_versions_slug_date`

**Root cause:** The final `CREATE INDEX` statement lacks a trailing `;`. The migration runner splits on `;`, so the last statement is silently dropped when concatenated.

**Fix:**
```sql
-- Before
CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug_date ON prompt_versions(preset_slug, version_date DESC)

-- After
CREATE INDEX IF NOT EXISTS idx_prompt_versions_slug_date ON prompt_versions(preset_slug, version_date DESC);
```

**Edge case:** Existing databases that already ran migration 018 are missing this index. Add a new migration (019) that creates the index `IF NOT EXISTS` to retroactively fix deployed databases.

**Test:** Add assertion in `test-db.R` that all migration files end each statement with `;`.

---

### 2. #165 — Email not redacted in verbose OpenAlex logs

**File:** `R/api_openalex.R:10-11` (inside `perform_openalex()`)
**Severity:** MEDIUM — PII leak in verbose logging mode

**Root cause:** The `api_key` parameter is redacted from logged URLs, but the `mailto` parameter (containing user email) is not.

**Fix:**
```r
# Before (line 10)
url <- gsub("api_key=[^&]+", "api_key=<REDACTED>", req$url)

# After
url <- gsub("api_key=[^&]+", "api_key=<REDACTED>", req$url)
url <- gsub("mailto=[^&]+", "mailto=<REDACTED>", url)
```

**Edge case:** httr2 error messages may also contain the full URL with email. Check `classify_api_error()` for secondary leak — if present, apply same redaction there.

**Test:** Unit test in `test-api-openalex.R` that constructs a URL with `mailto=user@example.com` and verifies redaction.

---

### 3. #179 — `%||%` not defined in `utils_scoring.R`

**File:** `R/utils_scoring.R`
**Severity:** LOW — non-issue on R 4.5.1

**Root cause analysis:** `%||%` is a **base R operator since R 4.4.0**. The project targets R 4.5.1 (per CLAUDE.md), so `%||%` is always available. The custom definitions in `R/config.R:64` and `R/slides.R:32` are redundant overrides.

`utils_scoring.R` does not currently use `%||%` anywhere. The bug is a latent test-isolation concern, not an active failure.

**Fix (minimal):** Close as "not applicable on target R version (4.5.1)." Optionally:
- Remove redundant `%||%` definitions from `config.R:64` and `slides.R:32` (cleanup)
- OR add a guarded definition to a shared test helper for R < 4.4.0 compat (defensive)

**Recommended:** Close the issue with a comment explaining R 4.5.1 has `%||%` in base. If the project ever needs to support R < 4.4.0, revisit then.

---

### 4. #229 — `p.NA` in `build_context_by_paper()` and `build_slides_prompt()`

**Files:** `R/rag.R:1005-1011`, `R/slides.R:57-62`
**Severity:** MEDIUM — user-visible "p.NA" degrades LLM prompt quality

**Root cause:** Both functions use `sprintf("[p.%d, ...]", page_number)` without checking for `NA`. The older `build_context()` function (rag.R:155-173) correctly guards with `!isTRUE(is.na(page_number))`.

**Fix for `build_context_by_paper()` (rag.R ~line 1005):**
```r
# Guard page_number — omit page ref when NA, matching build_context() pattern
page_ref <- if (!isTRUE(is.na(paper$chunks$page_number[i]))) {
  sprintf("p.%d, ", paper$chunks$page_number[i])
} else {
  ""
}
chunk_text <- sprintf("[%s%s] %s", page_ref, hint, paper$chunks$content[i])
```

**Fix for `build_slides_prompt()` (slides.R ~line 57):**
```r
# Guard both doc_name and page_number
doc_label <- if (!isTRUE(is.na(chunks$doc_name[i]))) chunks$doc_name[i] else "unknown"
page_ref <- if (!isTRUE(is.na(chunks$page_number[i]))) {
  sprintf(", p.%d", chunks$page_number[i])
} else {
  ""
}
chunk_text <- sprintf("[%s%s]:\n%s", doc_label, page_ref, chunks$content[i])
```

**Design decision:** When page_number is NA, omit the page reference entirely (matching existing `build_context()` behavior). Do NOT use placeholders like "p.?" — they add noise to LLM context.

**Test:** Add test cases in `test-slides.R` with NA page_number values. Add tests for `build_context_by_paper()` (none exist currently).

---

### 5. #234 — `log_cost` returns stale ID on INSERT fail

**File:** `R/cost_tracking.R:192-235`
**Severity:** MEDIUM — correctness defect (though no callers currently use the return value)

**Root cause:** Classic R tryCatch pitfall. `return(invisible(NULL))` inside the error handler returns from the anonymous function, not from `log_cost()`. After a failed INSERT, execution falls through to line 234 which returns the UUID that was never persisted.

**Fix:** Restructure so tryCatch expression itself evaluates to the correct value:
```r
# Replace lines 208-234 with:
result <- tryCatch({
  dbExecute(con, insert_sql, params = param_list)
  id  # return id only on success
}, error = function(e) {
  warning("Failed to log cost: ", e$message, call. = FALSE)
  NULL  # becomes tryCatch return value
})

result
```

**Edge case:** No callers assign `log_cost()`'s return value (all fire-and-forget), so runtime impact is zero today. Fix is for API contract correctness and future callers.

**Test:** Add test in `test-cost-tracking.R` for the failure path — pass a closed connection, verify `NULL` return and warning.

---

### 6. #181 — XSS-adjacent JS injection in keyword onclick

**File:** `R/mod_search_notebook.R:1885-1901`
**Severity:** LOW — likely false positive after analysis

**Root cause analysis:** The code already uses `jsonlite::toJSON(k_lower, auto_unbox = TRUE)` for JS string escaping (line 1886). Combined with `htmltools::tags$span()` which HTML-escapes attribute values during rendering, the double-encoding chain is correct:
1. `jsonlite::toJSON` escapes quotes/backslashes/control chars for JS
2. `htmltools` escapes `<`, `>`, `"`, `&` for HTML attribute context
3. Browser HTML-decodes the attribute, then evaluates as JS

**Verification needed:** Test with adversarial keyword values to confirm:
- `"; alert(1); "` — should be safely escaped
- `</span><script>alert(1)</script>` — should be escaped by htmltools
- `' onclick='alert(1)` — should be escaped by htmltools attribute rendering

**Fix (if needed):** Add `htmltools::htmlEscape()` as a belt-and-suspenders measure on the keyword before JSON encoding:
```r
k_safe <- htmltools::htmlEscape(k_lower)
k_js <- jsonlite::toJSON(k_safe, auto_unbox = TRUE)
```

**Recommended:** Verify with the adversarial test cases first. If `htmltools` handles them correctly (it should), close with a comment. If not, apply the `htmlEscape` fix.

**Test:** Add a test that renders keywords containing `"`, `<`, `>`, `'`, `\n` and verifies the HTML output is safe.

---

### 7. #193 — Weight preset sums exceed 1.0

**File:** `R/utils_scoring.R:70-99`
**Severity:** LOW — cosmetic; runtime re-normalization in `compute_utility_score()` prevents scoring errors

**Root cause:** Hand-edited weight values don't sum to 1.0:
- discovery: 1.50
- comprehensive: 1.20
- emerging: 1.30

`compute_utility_score()` (line 141) always re-normalizes, so actual scores are correct. The issue is readability and potential confusion if raw weights are displayed or used without normalization.

**Fix:** Normalize raw values to sum to 1.0, preserving ratios:
```r
# discovery (current ratios: 0.25:0.30:0.20:0.15:0.30:0.30 = sum 1.50)
# normalized: 0.167:0.200:0.133:0.100:0.200:0.200
discovery = list(
  w1_seed_connectivity = round(0.25 / 1.50, 3),  # 0.167
  w2_bridge_score      = round(0.30 / 1.50, 3),  # 0.200
  w3_recency           = round(0.20 / 1.50, 3),  # 0.133
  w4_citation_impact   = round(0.15 / 1.50, 3),  # 0.100
  w5_ubiquity_penalty  = round(0.30 / 1.50, 3),  # 0.200
  w6_embedding_sim     = round(0.30 / 1.50, 3)   # 0.200
)
```

Repeat for comprehensive and emerging presets.

**Test:** Add assertion in `test-utils_scoring.R`:
```r
test_that("preset weights sum to 1.0", {
  for (mode in c("discovery", "comprehensive", "emerging")) {
    w <- get_preset_weights(mode)
    expect_equal(sum(unlist(w)), 1.0, tolerance = 0.01)
  }
})
```

---

## Implementation Order

All fixes are independent. Recommended order by severity/risk:

1. **#235** — Migration semicolon (highest risk, simplest fix)
2. **#229** — p.NA guards (user-visible impact)
3. **#234** — log_cost stale ID (correctness)
4. **#165** — Email redaction (privacy)
5. **#193** — Weight normalization (cosmetic)
6. **#181** — XSS verification (likely close as not-a-bug)
7. **#179** — %||% (close as not applicable on R 4.5.1)

## Acceptance Criteria

- [x] #235: Migration 018 ends with `;`; new migration 019 creates index IF NOT EXISTS
- [x] #165: Logged URLs show `mailto=<REDACTED>`; test verifies redaction
- [x] #179: Issue closed with R 4.5.1 explanation (or redundant definitions removed)
- [x] #229: No `p.NA` in output when page_number is NA; tests cover NA inputs
- [x] #234: `log_cost()` returns `NULL` on INSERT failure; test covers failure path
- [x] #181: Verified safe with adversarial keywords; closed or hardened
- [x] #193: All preset weights sum to 1.0 (tolerance 0.01); test asserts sum
- [x] All existing tests pass after changes
- [x] Shiny smoke test passes (`runApp` starts without error)

## References

- Brainstorm: `docs/brainstorms/2026-03-22-v18-bug-bash-brainstorm.md`
- PR #233 review findings: `docs/reviews/PR-233-r1-2026-03-22.md`
- Migration runner: `R/db_migrations.R:55-68`
- Existing NA guard pattern: `R/rag.R:155-173` (`build_context()`)
- tryCatch pitfall: R's `return()` in error handler exits the handler, not the enclosing function
