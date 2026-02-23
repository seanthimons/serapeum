---
phase: 05-cost-visibility
plan: 02
subsystem: cost-visibility-ui
tags: [ui, shiny, cost-tracking, modules]
dependency_graph:
  requires: [cost-tracking-infrastructure, usage-metadata-api]
  provides: [cost-tracker-ui, session-cost-display]
  affects: [mod_document_notebook, mod_search_notebook, mod_query_builder, mod_slides, rag, slides, _ragnar, app]
tech_stack:
  added: [mod_cost_tracker.R]
  patterns: [reactive-cost-polling, graceful-cost-logging, session-based-tracking]
key_files:
  created:
    - R/mod_cost_tracker.R
  modified:
    - R/rag.R
    - R/slides.R
    - R/mod_query_builder.R
    - R/mod_document_notebook.R
    - R/mod_search_notebook.R
    - R/_ragnar.R
    - R/mod_slides.R
    - app.R
decisions:
  - context: "Cost logging should not break existing functionality if session_id unavailable"
    decision: "Made session_id and con parameters optional in all helper functions (rag_query, generate_preset, generate_slides)"
    rationale: "Graceful degradation - functions work with or without cost tracking. Only log if both con and session_id are provided"
    alternatives: ["Require session_id everywhere", "Create wrapper functions"]
  - context: "Where to display session cost in UI"
    decision: "Show inline in sidebar (always visible) AND on dedicated Costs page"
    rationale: "Sidebar gives at-a-glance awareness, dedicated page provides detailed breakdown"
    alternatives: ["Only on dedicated page", "Modal on demand"]
  - context: "Cost polling frequency"
    decision: "10 seconds for session data, 60 seconds for history data"
    rationale: "Session data changes frequently (per-request), history data changes slowly (daily aggregation)"
    alternatives: ["Same frequency for both", "Manual refresh only"]
metrics:
  duration_minutes: 5
  tasks_completed: 2
  files_created: 1
  files_modified: 8
  commits: 2
  completed_at: "2026-02-11T14:37:06Z"
---

# Phase 05 Plan 02: Cost Visibility UI Summary

**One-liner:** All API callers now log costs to database, and users see real-time session totals in sidebar plus detailed cost breakdowns on dedicated Costs page.

## What Was Built

### 1. Updated All API Callers to Handle New Return Types and Log Costs

**Modified 7 files to extract content/embeddings from list returns and log costs:**

**R/rag.R:**
- `rag_query()` now accepts optional `session_id` parameter
- Extracts `result$embeddings[[1]]` instead of `result[[1]]` from `get_embeddings()`
- Logs embedding cost after successful embedding generation
- Extracts `result$content` from `chat_completion()` instead of using result directly
- Logs chat cost with operation = "chat"
- `generate_preset()` also updated with same pattern

**R/slides.R:**
- `generate_slides()` now accepts optional `con` and `session_id` parameters
- Extracts `result$content` from `chat_completion()`
- Logs cost with operation = "slide_generation"

**R/mod_query_builder.R:**
- Extracts `result$content` from `chat_completion()`
- Logs cost with operation = "query_build"
- Uses `session$token` for session_id (available in Shiny module servers)

**R/mod_document_notebook.R:**
- During PDF embedding batch processing, extracts `embeddings_result$embeddings` instead of direct list
- Logs embedding cost for each batch
- Updated `rag_query()` call to pass `session_id = session$token`
- Updated `generate_preset()` call to pass `session_id = session$token`

**R/mod_search_notebook.R:**
- Updated `rag_query()` call to pass `session_id = session$token`

**R/mod_slides.R:**
- Updated `generate_slides()` call to pass `con = con()` and `session_id = session$token`

**R/_ragnar.R:**
- Updated `embed_via_openrouter()` function to extract `result$embeddings` from new return type

**Cost logging strategy:**
- All cost logging is **graceful** - functions only log if both `con` and `session_id` are provided
- Helper functions (rag.R, slides.R) have optional parameters with defaults of `NULL`
- Module callers always pass session_id using `session$token`
- No breaking changes - functions still work without cost tracking

### 2. Created Cost Tracker UI Module and Wired into App

**Created R/mod_cost_tracker.R:**

**UI function (`mod_cost_tracker_ui`):**
- **Session summary value_box** at top showing total session cost formatted as "$0.0000"
  - Uses bslib `value_box()` with dollar-sign icon
  - showcase_layout = "left center"
- **Recent requests table** showing last 20 cost_log entries
  - Columns: Time (relative, e.g., "2m ago"), Operation (with emoji icons), Model (shortened), Tokens, Cost
  - Operation icons: 💬 Chat, 🧠 Embed, ✨ Query, 📊 Slides
- **Cost history section** (collapsible via `<details>`)
  - Bar chart showing daily costs for last 30 days (base R barplot)
  - Cost by operation summary table with columns: Operation, Requests, Total Cost, Avg Cost

**Server function (`mod_cost_tracker_server`):**
- Accepts reactive `con_r` and `session_id_r`
- **Session data polling** every 10 seconds using `reactiveTimer(10000)`
  - Calls `get_session_costs()` to get current session data
  - Extracts `attr(result, "total_cost")` for value box
  - Returns top 20 rows for recent requests table
- **History data polling** every 60 seconds using `reactiveTimer(60000)`
  - Calls `get_cost_history(con, 30)` for daily aggregation
  - Calls `get_cost_by_operation(con, 30)` for operation breakdown
- Renders all outputs with proper formatting

**Updated app.R:**
- **Sidebar inline session cost display:**
  - Added between notebook list and settings/about links
  - Shows "💰 Session: $0.0000"
  - Updates every 10 seconds via `invalidateLater(10000)`
  - Uses `get_session_costs()` and extracts `total_cost` attribute
- **Costs link in sidebar:**
  - Added next to Settings and About links
  - Icon: dollar-sign
  - Navigates to "costs" view
- **Session ID creation:**
  - `session_id <- session$token` stored at server startup
  - Passed to cost tracker module as `reactive(session_id)`
- **Cost tracker module wiring:**
  - `mod_cost_tracker_server("cost_tracker", con_r, reactive(session_id))`
- **Main content routing:**
  - Added `if (view == "costs")` case that returns `mod_cost_tracker_ui("cost_tracker")`

## Deviations from Plan

None - plan executed exactly as written.

## Testing Performed

**Manual verification:**
1. All R files source without errors (checked via Rscript loop)
2. Git commits created for both tasks (462f740, a8dd782)

**Pending human verification (Task 3 checkpoint):**
- App starts without errors
- Session cost displays in sidebar
- Costs link navigates to cost tracker page
- After sending chat message:
  - cost_log table has new row
  - Session cost updates
  - Recent requests table shows entry
  - All existing functionality works

## Known Issues / Follow-up

**Task 3 is a checkpoint:human-verify** - Awaiting user to:
1. Start the app
2. Verify sidebar shows "Session: $0.0000"
3. Send a chat message in a document notebook
4. Verify session cost updates and cost tracker page shows the request
5. Confirm all 5 phase success criteria are met:
   - COST-01: Per-request cost visible after each chat message and embedding operation
   - COST-02: Running session cost total visible in sidebar
   - COST-03: Cost history and trends visible on dedicated costs page

## Files Changed

### Created
- `R/mod_cost_tracker.R` (215 lines) - Cost tracker UI module with session summary, recent requests, and history

### Modified
- `R/rag.R` - Updated rag_query and generate_preset to log costs
- `R/slides.R` - Updated generate_slides to log slide_generation costs
- `R/mod_query_builder.R` - Logs query_build costs
- `R/mod_document_notebook.R` - Logs embedding costs, passes session_id to rag functions
- `R/mod_search_notebook.R` - Passes session_id to rag_query
- `R/_ragnar.R` - Updated embed function to handle new return type
- `R/mod_slides.R` - Passes con and session_id to generate_slides
- `app.R` - Added session cost display, costs link, cost tracker module wiring, and costs view routing

## Commits

- `462f740`: feat(05-02): update API callers to handle new return types and log costs
- `a8dd782`: feat(05-02): create cost tracker UI module and wire into app

## Self-Check: PASSED

**Created files exist:**
- FOUND: R/mod_cost_tracker.R

**Modified files exist:**
- FOUND: R/rag.R
- FOUND: R/slides.R
- FOUND: R/mod_query_builder.R
- FOUND: R/mod_document_notebook.R
- FOUND: R/mod_search_notebook.R
- FOUND: R/_ragnar.R
- FOUND: R/mod_slides.R
- FOUND: app.R

**Commits exist:**
- FOUND: 462f740
- FOUND: a8dd782

**All R files source without errors:**
- VERIFIED: No syntax errors found
