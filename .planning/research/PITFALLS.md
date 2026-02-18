# Pitfalls Research: v4.0 Stability + Synthesis Features

**Domain:** Adding structured synthesis outputs, merging presets, and fixing tech debt in an existing R/Shiny RAG research assistant
**Researched:** 2026-02-18
**Confidence:** HIGH

---

## Critical Pitfalls

### Pitfall 1: LLM Structured Output Schema Adherence vs. Syntax Correctness Are Different Problems

**What goes wrong:**
The Literature Review Table feature requires the LLM to emit a multi-row structured comparison matrix. Developers use OpenRouter's `response_format: json_schema` (or ask for markdown table via prompt alone) and assume "if it parses, it's correct." In practice, the LLM returns valid JSON or valid markdown but with wrong field names, missing rows, merged cells, inconsistent column counts, or hallucinated paper attributes — none of which are caught by JSON parsers or OpenRouter's Response Healing feature.

**Why it happens:**
OpenRouter's Response Healing (launched 2025) fixes *syntax* errors only — trailing commas, unescaped control characters, unclosed brackets. It explicitly does not fix schema adherence. A response that returns `{"papers": [...]}` when you expected `{"rows": [...]}` is syntactically valid JSON that fails schema validation and still breaks the parsing code. Additionally, models have a U-shaped positional bias: they handle the first and last items in a large context reliably but lose fidelity in the middle — which is exactly where most papers in a literature review live.

**How to avoid:**
- **Use OpenRouter structured outputs with `strict: true`** — pass `response_format: {type: "json_schema", json_schema: {...}, strict: true}` in the API request body. This enforces schema at the provider level, not just via prompt.
- **Add require_parameters constraint:** OpenRouter may fall back to `json_object` for providers that don't support `json_schema`. Set `providers: {require_parameters: true}` to prevent silent schema downgrade.
- **Parse defensively in R:** After receiving the JSON, validate field presence, row count > 0, and required fields before rendering the table. Return a user-facing error, not a crash, if validation fails.
- **Decompose the task:** If strict schema mode causes quality degradation (models sometimes produce worse answers when constrained), use a two-step approach: first generate prose synthesis, then call LLM again to "format the above into this JSON schema" with the prose as input.
- **Limit row count:** Request 5–10 rows per call, not all papers at once. Attention drops at scale — the model will silently drop papers after the first 40 entries. If the notebook has 20+ papers, consider chunking the table generation into batches.
- **Cap context window:** Don't send all 50 chunks when 10 focused chunks will do. The existing `generate_preset` function sends up to 50 chunks — for structured table output, quality improves with targeted retrieval (reduce `LIMIT` and increase query specificity).

**Warning signs:**
- LLM returns a table with 3 rows when the notebook has 15 papers
- Column names in the response differ from the schema (e.g., `author` vs `first_author`)
- Some rows have 5 columns, others have 3
- `fromJSON()` succeeds but `tbl$required_field` returns NULL
- The rendered table shows NA or empty cells for most rows

**Phase to address:**
The phase implementing Literature Review Table (likely Phase 27 or equivalent). Implement schema validation and fallback *before* connecting the UI. Test with a notebook containing 3, 10, and 20 papers to verify scaling behavior.

---

### Pitfall 2: Merging Presets Breaks Existing Chat Histories and Export Files

**What goes wrong:**
The `summarize` and `keypoints` presets in `generate_preset()` are identified by `preset_type` string. Chat messages store `preset_type` on the message object. Export functions may branch on `preset_type`. Merging these two into a unified "Overview" preset by removing the old IDs and adding a new one means:

1. Existing chat sessions (loaded from `messages` reactiveVal) that contain `preset_type = "summarize"` will hit unmatched branches if any code checks for specific preset types.
2. If bookmark/session persistence is added later, old sessions with removed preset types will fail to render correctly.
3. Cost tracking uses `log_cost(con, "chat", ...)` — the feature type label is currently generic, but if preset tracking was added, removing `"summarize"` as a key could silently drop those cost rows.
4. The UI button `btn_summarize` and `btn_keypoints` have hardcoded `inputId`s used in `observeEvent`. Removing them removes their observers — if any JavaScript, CSS, or test references those IDs, they silently break.

**Why it happens:**
The preset system was built incrementally across multiple phases. The IDs `"summarize"` and `"keypoints"` appear in at least four places: the `presets` list in `generate_preset()`, the `observeEvent` bindings in `mod_document_notebook_server()`, the button `inputId` values in `mod_document_notebook_ui()`, and potentially in any test that clicks those buttons. Merging requires updating all four, and it is easy to miss the test layer or forget that the search notebook has its own preset section (the offcanvas chat panel in `mod_search_notebook.R`).

**How to avoid:**
- **Audit all occurrences before touching code:** `grep -r "summarize\|keypoints\|btn_summarize\|btn_keypoints"` across R/, tests/, and any UI snapshot files before removing anything.
- **Check both modules:** The document notebook and search notebook are separate modules. If either has a `btn_summarize`, it must be updated. From reading `mod_search_notebook.R`, the search notebook offcanvas chat only has a `conclusions_btn_ui` — confirm whether `generate_preset("summarize", ...)` is called from the search notebook too.
- **Keep the `"summarize"` key in `generate_preset()` as an alias** during the transition phase — have it call the new "overview" implementation rather than deleting the key. This avoids breakage if any code constructs the preset type string dynamically.
- **Verify cost log categories:** Check `log_cost()` calls to ensure removing `"summarize"` as a preset type does not orphan existing cost records. The cost tracking table stores `feature_type` as a VARCHAR — old records remain valid; future records will use the new label.
- **Update tests first:** If `tests/testthat/` has tests that click `btn_summarize` or call `generate_preset("summarize", ...)`, update them *before* removing the old IDs, so the failing test catches the gap.

**Warning signs:**
- `observeEvent(input$btn_overview, ...)` is present in server but `actionButton(ns("btn_overview"), ...)` is missing from UI (or vice versa) — the UI renders but the button does nothing
- Tests that previously tested the summary feature now error with "object not found" or "unused argument"
- Cost tracker shows no costs for synthesis operations after the merge

**Phase to address:**
The tech-debt/bug-fix phase (Phase 25 or equivalent). Run `grep` audit before writing code. Update tests first, then rename UI IDs, then update server observers, then update `generate_preset()`.

---

### Pitfall 3: DuckDB Connection Leak in search_chunks_hybrid — Known Issue

**What goes wrong:**
`search_chunks_hybrid()` in `R/db.R` calls `connect_ragnar_store(ragnar_store_path)` to open a ragnar (DuckDB) connection for retrieval. The connection is never explicitly closed within this function. The opened `store` object goes out of scope when the function returns, relying on R's garbage collector to finalize the DuckDB connection. This is tracked as issue #117.

Specific consequences:
- Every call to `rag_query()` or `generate_preset()` opens a new ragnar DuckDB connection that is not cleaned up until GC runs.
- Under Shiny, GC is infrequent. A session with 10 RAG queries has 10 open file handles to the same `.duckdb` file.
- On Windows (which this project runs on), file handles held by DuckDB prevent deletion of ragnar store files. The `delete_notebook_store()` function will fail silently while handles are open.
- When `rebuild_notebook_store()` deletes the store and creates a new one, stale handles from prior `search_chunks_hybrid` calls may hold a lock on the old file path, causing the new store to fail to open.
- The DuckDB R package emits a warning: "Database is garbage-collected, use dbDisconnect(con, shutdown=TRUE)" — which appears in the Shiny console and can mask other warnings.

**Why it happens:**
`search_chunks_hybrid()` was written with a `ragnar_store` optional parameter (pass in an already-open store to avoid creating one). When the caller does NOT pass a store, the function creates one internally. The intent was that callers managing their own store lifecycle would pass it in, but all actual callers (`rag_query`, `generate_conclusions_preset`) pass `NULL`, so the function always creates and leaks a connection.

**How to avoid:**
- **Fix is simple: wrap the internal store open/close in a `tryCatch` with `on.exit`:**
  ```r
  if (!is.null(ragnar_store_path) && file.exists(ragnar_store_path)) {
    store <- ragnar_store %||% connect_ragnar_store(ragnar_store_path)
    own_store <- is.null(ragnar_store)  # We created it, we close it
    if (own_store) {
      on.exit({
        tryCatch(DBI::dbDisconnect(store@con, shutdown = TRUE), error = function(e) NULL)
      }, add = TRUE)
    }
    # ... rest of function unchanged ...
  }
  ```
- **Do not add `shutdown = TRUE` if `ragnar_store` was passed by caller** — the caller owns that connection lifecycle.
- **Fix this before implementing new synthesis features** — Literature Review Table and Research Question Generator both call `generate_preset()` which calls `search_chunks_hybrid()`. Adding more callers amplifies the leak.
- **Test on Windows specifically:** File locking is more aggressive on Windows. Verify that after calling `search_chunks_hybrid()` twice in a row, the ragnar store file can be deleted without error.

**Warning signs:**
- DuckDB "Database is garbage-collected" warnings appearing in Shiny console during normal use
- `delete_notebook_store()` returns FALSE or errors with "permission denied" immediately after a RAG query
- `rebuild_notebook_store()` fails with "file in use" on Windows
- Memory usage grows gradually over a long session with repeated RAG queries

**Phase to address:**
The tech-debt/bug-fix phase (Phase 25 / issue #117). Fix `search_chunks_hybrid()` before any new synthesis feature is added. This is a 5-line fix with clear scope — do not expand it into a connection-pooling refactor during a bug fix phase.

---

### Pitfall 4: Removing Dead Code That Has Hidden Callers in a 14,000+ LOC Codebase

**What goes wrong:**
`with_ragnar_store()` and `register_ragnar_cleanup()` in `R/_ragnar.R` are flagged as dead code in issue #119. They look unused because no production code calls them by name. However, dead code in a 14k+ LOC R codebase can have hidden callers:

1. **Test files** — tests may call the function directly to test it, or use it as a helper. Removing the function breaks the test.
2. **Commented-out code** — if any module has `# with_ragnar_store(...)` in a comment (leftover from v3.0 refactor), that's low risk, but it signals the function was recently used.
3. **String-based dispatch** — if any code constructs function names as strings and calls `do.call()` or `match.fun()`, static grep will miss it.
4. **Documentation or examples** — if the function is in a vignette or `@examples`, the `devtools::check()` will run those examples and fail.
5. **Future phases** — the roadmap may reference these functions in a `.planning/` file without them being in `R/`. Removing without checking `.planning/` causes confusion.

Specific risk for this codebase: `with_ragnar_store()` wraps the `on.exit()` connection cleanup pattern. The new `search_chunks_hybrid` fix (Pitfall 3 above) needs exactly this pattern. Removing `with_ragnar_store()` and then reimplementing the same logic inline is more work, not less.

**Why it happens:**
The v3.0 ragnar overhaul was a rapid refactor across ~9 phases in a single milestone. Functions designed for one approach get replaced by a better approach but not immediately deleted. The TODO captures them as "low priority" dead code, which is correct — but "low priority" gets treated as "safe to delete anytime."

**How to avoid:**
- **Grep for callers before deleting:** `grep -r "with_ragnar_store\|register_ragnar_cleanup"` across `R/`, `tests/`, `app.R`, and `.planning/` before removing.
- **Check test files explicitly:** `tests/testthat/` may have tests targeting these functions. Run `testthat::test_dir("tests/testthat")` before and after removal and compare.
- **Consider keeping `with_ragnar_store()` as the fix for Pitfall 3** — it already implements `on.exit()` cleanup correctly. Instead of deleting it and writing new inline cleanup, keep it and route `search_chunks_hybrid()` through it. This converts "dead code removal" + "connection leak fix" into a single coherent change.
- **Delete one function per PR, not both at once** — isolation makes it easier to identify which deletion caused a test failure.

**Warning signs:**
- Test suite fails after deletion with "could not find function" errors
- `R CMD check` reports errors in examples after deletion
- A subsequent phase needs to reimplement the same pattern from scratch

**Phase to address:**
The tech-debt/bug-fix phase. Address after the connection leak fix (Pitfall 3) is resolved — the decision of whether `with_ragnar_store()` can be deleted depends on whether the connection leak fix uses it.

---

### Pitfall 5: section_hint Not Encoded in PDF Ragnar Origins — Silent Degradation for Structured Synthesis

**What goes wrong:**
Issue #118 identifies that `section_hint` is not being encoded into the `origin` field when PDFs are chunked. `encode_origin_metadata()` is defined in `_ragnar.R` and the abstract path calls it correctly. But in `mod_document_notebook.R` (line ~533), when inserting document chunks via `insert_chunks_to_ragnar()`, the `chunks` data frame from `pdf.R` may have `section_hint` values that are NOT encoded into the `origin` field.

This matters for v4.0 because:
- The Literature Review Table generation needs to retrieve methodology/results sections specifically.
- The Research Question Generator benefits from gap-analysis-targeted retrieval.
- Both features will call `search_chunks_hybrid()` with `section_filter` — which already queries the `chunks` table to look up `section_hint` by content prefix matching.

If `section_hint` is not stored in the `chunks` table for PDFs uploaded before this fix, all section-filtered queries fall back to `"general"` silently. Users get a broader-than-expected result set with no error. The structured output then includes full paper content instead of targeted methodology/conclusion chunks.

**Why it happens:**
The `chunk_with_ragnar()` function builds `all_chunks` with an `origin` field but does not call `encode_origin_metadata()`. The origin is just `"filename.pdf#page=N"`. The `section_hint` is detected separately in `pdf.R` and stored in the `chunks` table, but the ragnar store's `origin` field doesn't carry it. The `search_chunks_hybrid()` workaround (content prefix join to `chunks` table) is the bridge — but it only works if `pdf.R` correctly populates `section_hint` in the main `chunks` table during upload.

**How to avoid:**
- **Fix the encoding path in PDF upload** (issue #118): In `mod_document_notebook.R` upload handler, after `create_chunk()` sets `section_hint`, also call `encode_origin_metadata()` when building the `origin` for ragnar. This ensures both storage locations are populated.
- **Do not depend on the content-prefix join for new features** — it is O(n) and fragile (whitespace normalization can cause mismatches). New synthesis features should document that section filtering is "best effort" on pre-#118-fix notebooks.
- **Add a validation check** in the new synthesis feature: if `section_filter` returns 0 results, fall back to unfiltered retrieval and log a warning. Do not silently return empty context.

**Warning signs:**
- `search_chunks_hybrid()` with `section_filter = c("conclusion")` returns 0 results for a notebook that definitely has conclusion sections
- All chunks have `section_hint = "general"` in the `chunks` table after PDF upload (check with `dbGetQuery(con, "SELECT DISTINCT section_hint FROM chunks WHERE source_type='document'")`)
- Console message: `[search_chunks_hybrid] section_hint column not found, skipping section filter` (even though the column exists — this fires when the content-prefix join finds no matches)

**Phase to address:**
The tech-debt phase (issue #118) — fix the encoding before implementing structured synthesis features that depend on section filtering. If this fix ships in Phase 25, new synthesis features in Phase 26+ can rely on section filtering for newly uploaded PDFs, with documented degraded behavior for pre-fix notebooks.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Prompt-only structured output (no `json_schema`) | Simpler API call, works with all models | LLM produces markdown tables, CSV, prose, or mixed formats unpredictably; parsing code becomes a brittle regex farm | Never for user-facing structured output that is parsed programmatically |
| Keep old preset IDs as no-ops after merge | Zero breakage risk during merge | Orphaned `observeEvent` handlers waste memory, confuse future developers, cause duplicate observers if both old and new buttons are registered | Acceptable for 1 phase as alias, then remove |
| Skip `on.exit` cleanup in `search_chunks_hybrid` | Faster implementation | File handle leak on Windows; blocks `delete_notebook_store()`; GC warning spam in console | Never — this is a 5-line fix with no tradeoff |
| Generate entire lit review table in one LLM call | Simpler code | Context window pressure causes silent row omission for large notebooks (>15 papers); no way to detect missing rows | Acceptable at MVP for small notebooks (<10 papers), needs batch strategy for larger sets |
| Delete `with_ragnar_store` and `register_ragnar_cleanup` immediately | Slightly smaller codebase | Removes a working connection-management pattern that may be the solution to the connection leak; increases risk of Pitfall 3 fix introducing new bugs | Delete only after connection leak is fixed and confirmed not to use these functions |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OpenRouter structured outputs | Assume all models support `json_schema` mode | Check model compatibility first; set `require_parameters: true` to prevent silent fallback to `json_object`; handle 400 errors gracefully with fallback to prose |
| OpenRouter Response Healing | Assume it catches schema violations | Response Healing fixes syntax only. Schema violations (wrong field names, missing required properties) still reach your code. Add R-side validation. |
| ragnar + DuckDB file handles on Windows | Assume R GC closes connections promptly | Use explicit `DBI::dbDisconnect(store@con, shutdown = TRUE)` in `on.exit()`. On Windows, un-GC'd connections hold exclusive file locks that block `file.remove()`. |
| `generate_preset()` with structured output | Reuse existing prose-oriented `chat_completion()` call | Add a separate `chat_completion_structured()` helper that includes `response_format` in the request body. Do not modify the existing function — it will break prose presets. |
| Section filtering after Pitfall 5 | Expect `section_filter` to work reliably on all notebooks | Section filtering is best-effort. Pre-fix notebooks return `"general"` for all chunks. Add fallback: if filtered results < 3, retry without section filter. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Structured JSON for 20+ papers in one call | Table has 8 rows when notebook has 22 papers; no error raised | Batch: generate 5–7 paper rows per call, merge results | >15 papers in context |
| Sending all 50 chunks for structured synthesis | LLM ignores middle chunks; table has correct structure but wrong content | Reduce to 15–20 targeted chunks via focused query; increase `section_filter` specificity | >30 chunks in context |
| ragnar connection per `search_chunks_hybrid` call (open, use, leak) | Memory grows 10–30 MB/session; "Database is garbage-collected" warnings | `on.exit()` cleanup as described in Pitfall 3 | >5 RAG queries per session |
| Regenerating structured table on every reactive invalidation | LLM called repeatedly as user navigates tabs; high API cost | Gate structured generation behind explicit button click, not reactive dependency; cache result in `reactiveVal` | Any reactive dependency on the table output |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing raw JSON when structured output parsing fails | User sees `{"rows": [...]}` instead of a table; confused and thinks the feature is broken | Catch parse failures, show error toast with "Could not generate table — try again or use a different model" |
| Literature Review Table with missing papers (silent row omission) | User has 18 papers, table shows 10; user assumes 8 papers had no relevant content | Add a row count indicator: "Showing 10 of 18 papers — some may not have been included due to context limits" |
| Overview preset replacing both Summarize and Key Points with no user notice | Returning user clicks where "Summarize" was, finds "Overview" instead, doesn't know if it's the same | Minimal UI change: rename button label, keep same visual position, add tooltip "Combines summary and key points" |
| Research Question Generator producing generic questions | User gets "What are the future research directions in this field?" — questions not grounded in the specific papers | Require the LLM to cite the specific source(s) that motivated each question; validate that citations appear in output before accepting |

---

## "Looks Done But Isn't" Checklist

- [ ] **Literature Review Table:** Often missing row count validation — verify table has 1 row per paper that has relevant content, not just 1–3 rows of "best examples"
- [ ] **Structured output API call:** Often missing `require_parameters: true` — verify the request actually uses `json_schema` mode by checking network response headers (OpenRouter returns `x-model-provider` and routing info)
- [ ] **Preset merge (Overview):** Often missing update to the *search* notebook offcanvas chat panel — verify both `mod_document_notebook.R` AND `mod_search_notebook.R` are updated if either currently has `btn_summarize` or `btn_keypoints`
- [ ] **Connection leak fix:** Often "fixed" by only adding `on.exit` for the success path — verify the `on.exit` fires on error paths too (use `on.exit(..., add = TRUE)` not assignment after `on.exit`)
- [ ] **Dead code removal:** Often marked done after `grep` shows no callers in `R/` — verify `tests/testthat/` is also clean and the test suite still passes
- [ ] **section_hint encoding fix:** Often fixed in new upload flow but not retroactively — existing notebook content still has un-encoded origins; verify new synthesis features have graceful fallback for pre-fix data
- [ ] **Cost tracking for new presets:** Often the new `preset_type` label is never passed to `log_cost()` — verify new features pass `session_id` and `preset_type` strings that will appear correctly in the cost tracker

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Structured output returns wrong schema | LOW | Add R-side validation; retry with prose mode; surface error to user |
| Preset merge breaks existing button references in tests | LOW | `grep` for old IDs, update in one pass; tests catch it before users do |
| Connection leak causes "file in use" on Windows | LOW | Restart R process to release handles; apply Pitfall 3 fix; test on Windows before release |
| Dead code removal breaks tests | LOW | `git revert` the deletion commit; add `on.exit` fix to `with_ragnar_store` instead; remove after confirming |
| section_hint not populated (Pitfall 5) | LOW-MEDIUM | For pre-fix notebooks: accept degraded section filtering; for post-fix: re-upload PDFs or trigger re-index; document behavior difference |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| LLM schema adherence vs. syntax | Literature Review Table phase | Test with `strict: true` and a schema; verify R-side validation catches schema violations; test with 3, 10, 20 paper notebooks |
| Preset merge breaking observers | Bug-fix / tech-debt phase | `grep` audit before code change; run full test suite after merge; manually verify both doc notebook and search notebook UI |
| `search_chunks_hybrid` connection leak | Bug-fix / tech-debt phase (issue #117) | After fix: call `search_chunks_hybrid` 10 times in a test, verify no DuckDB GC warnings; verify ragnar store file deletable immediately after query |
| Dead code removal risks | Bug-fix / tech-debt phase (issue #119) | Run `testthat::test_dir("tests/testthat")` before AND after deletion; compare output line by line |
| section_hint encoding gap | Tech-debt phase (issue #118) | After fix: upload a PDF, query `SELECT DISTINCT section_hint FROM chunks`; verify values other than "general" appear; test section-filtered retrieval |

---

## Sources

- [OpenRouter Structured Outputs Documentation](https://openrouter.ai/docs/guides/features/structured-outputs) — Schema modes, `strict` parameter, model compatibility
- [OpenRouter Response Healing Announcement](https://openrouter.ai/announcements/response-healing-reduce-json-defects-by-80percent) — What it fixes and explicitly does NOT fix (schema adherence)
- [OpenRouter Provider Routing — require_parameters](https://openrouter.ai/docs/guides/routing/provider-selection) — Preventing silent fallback from `json_schema` to `json_object`
- [DuckDB File Locking Discussion](https://github.com/duckdb/duckdb/discussions/8126) — Windows file lock behavior
- [DuckDB Connection Lock Issue](https://github.com/duckdb/duckdb/discussions/10397) — Multiple connection locking patterns
- [DuckDB R Package GC Warning](https://github.com/duckdb/duckdb-r/issues/34) — "Database is garbage-collected" warning cause and fix
- [LLM Table Format Accuracy Study](https://www.improvingagents.com/blog/best-input-data-format-for-llms) — Markdown-KV outperforms CSV; format choice affects accuracy
- [LLM Positional Bias in Tables](https://arxiv.org/html/2305.13062v4) — U-shaped accuracy: good at start/end, drops in middle of large contexts
- [LLM Engineering Failure Modes 2025](https://medium.com/@gbalagangadhar/llm-engineering-in-2025-the-failure-modes-that-actually-matter-and-how-i-fix-them-ad1f6f1da77e) — Structured output latency and reliability issues
- Serapeum codebase analysis — `R/db.R` lines 698–834 (`search_chunks_hybrid` connection leak), `R/_ragnar.R` lines 296–361 (`with_ragnar_store`, `register_ragnar_cleanup` dead code), `R/rag.R` lines 134–223 (`generate_preset` preset system), `R/mod_document_notebook.R` lines 44–65 (preset button IDs)
- Serapeum issue tracker — #117 (connection leak), #118 (section_hint encoding), #119 (dead code removal), #98 (preset merge), #99 (Literature Review Table), #102 (Research Question Generator)

---
*Pitfalls research for: Serapeum v4.0 Stability + Synthesis Features*
*Researched: 2026-02-18*
*Confidence: HIGH — Based on official OpenRouter documentation, DuckDB issue tracker, LLM structured output research, and direct codebase analysis of the known bugs and planned features*
