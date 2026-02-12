---
phase: 05-cost-visibility
plan: 01
subsystem: cost-tracking-backend
tags: [api, database, cost-tracking]
dependency_graph:
  requires: []
  provides: [cost-tracking-infrastructure, usage-metadata-api]
  affects: [api_openrouter, database-schema]
tech_stack:
  added: [cost_tracking.R, migration-003]
  patterns: [usage-metadata-return, cost-estimation, session-based-tracking]
key_files:
  created:
    - R/cost_tracking.R
    - migrations/003_create_cost_log.sql
  modified:
    - R/api_openrouter.R
    - R/db.R
decisions:
  - context: "API return type changes are breaking"
    decision: "Modified chat_completion() and get_embeddings() to return structured lists instead of direct values"
    rationale: "All downstream callers will be updated in Plan 02, enabling cost tracking without duplicating API calls"
    alternatives: ["Wrapper functions to preserve backward compatibility"]
  - context: "Model pricing data storage"
    decision: "Hardcoded pricing table in R/cost_tracking.R with 7 known models plus default fallback"
    rationale: "Simple, fast lookups. OpenRouter pricing rarely changes. Can be externalized to DB if needed later"
    alternatives: ["Store in database", "Fetch from OpenRouter API"]
  - context: "Session-based cost grouping"
    decision: "Use Shiny session_id to group costs per user session"
    rationale: "Enables per-session totals and session-scoped cost visibility in UI"
    alternatives: ["User-based tracking", "Global tracking only"]
metrics:
  duration_minutes: 2
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  commits: 2
  completed_at: "2026-02-11T14:28:59Z"
---

# Phase 05 Plan 01: Cost Tracking Backend Summary

**One-liner:** API functions now return usage metadata (tokens, model) and cost_log table enables persistent cost tracking with session-based grouping and historical queries.

## What Was Built

### 1. API Functions Return Usage Metadata (Breaking Change)

**Modified `chat_completion()` in R/api_openrouter.R:**
- **Before:** Returned `string` (just the response content)
- **After:** Returns `list(content, usage, model, id)` where usage contains `prompt_tokens`, `completion_tokens`, `total_tokens`

**Modified `get_embeddings()` in R/api_openrouter.R:**
- **Before:** Returned `list` of embedding vectors
- **After:** Returns `list(embeddings, usage, model)` where embeddings is the list of vectors and usage contains token counts

**Impact:** All callers of these functions (in rag.R, slides.R, mod_query_builder.R, mod_document_notebook.R, _ragnar.R) will need updating to extract `.content` or `.embeddings` from the returned list. This is intentional and will be handled in Plan 02.

### 2. Cost Tracking Helper Functions (R/cost_tracking.R)

**Created 5 exported functions:**

1. **`estimate_cost(model, prompt_tokens, completion_tokens)`** - Calculates USD cost from token usage using a pricing table
   - Supports 7 known models (GPT-4o, GPT-4o-mini, Gemini variants, Claude Sonnet 4, OpenAI embeddings)
   - Falls back to conservative default ($1/M prompt, $3/M completion) for unknown models
   - Returns numeric cost (e.g., 0.00045 for 1000 prompt + 500 completion tokens on gpt-4o-mini)

2. **`log_cost(con, operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost, session_id)`** - Inserts cost record into cost_log table
   - operation: one of "chat", "embedding", "query_build", "slide_generation"
   - session_id: Shiny session identifier for grouping session costs
   - Returns UUID of created record

3. **`get_session_costs(con, session_id)`** - Retrieves all cost records for a session
   - Returns data frame with columns: operation, model, prompt_tokens, completion_tokens, total_tokens, estimated_cost, created_at
   - Attaches `total_cost` attribute with sum of estimated_cost

4. **`get_cost_history(con, days = 30)`** - Daily cost aggregation
   - Returns: date, total_cost, request_count, total_tokens
   - Useful for historical cost charts

5. **`get_cost_by_operation(con, days = 30)`** - Cost breakdown by operation type
   - Returns: operation, total_cost, request_count, avg_cost_per_request
   - Useful for understanding which features drive costs

### 3. Database Schema (Migration 003)

**Created `migrations/003_create_cost_log.sql`:**
```sql
CREATE TABLE cost_log (
  id VARCHAR PRIMARY KEY,
  session_id VARCHAR NOT NULL,
  operation VARCHAR NOT NULL,
  model VARCHAR NOT NULL,
  prompt_tokens INTEGER DEFAULT 0,
  completion_tokens INTEGER DEFAULT 0,
  total_tokens INTEGER DEFAULT 0,
  estimated_cost DOUBLE DEFAULT 0.0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

**Indexes:**
- `idx_cost_log_session` on session_id (for get_session_costs)
- `idx_cost_log_date` on created_at (for get_cost_history)

**Also added to init_schema()** in R/db.R as a CREATE TABLE IF NOT EXISTS fallback (for fresh databases that somehow skip migrations).

## Deviations from Plan

None - plan executed exactly as written.

## Testing Performed

**Manual verification:**
1. `estimate_cost("openai/gpt-4o-mini", 1000, 500)` → 0.00045 (correct)
2. `estimate_cost("unknown/model", 1000, 500)` → 0.0025 (correct default)
3. Migration 003 applied successfully, cost_log table exists with all columns
4. `log_cost()` successfully inserted record
5. `get_session_costs()` retrieved record and calculated total_cost attribute
6. All 5 cost tracking functions defined and callable
7. `chat_completion` and `get_embeddings` are both functions (structure change verified)

## Known Issues / Follow-up

**Breaking changes to API functions:**
- All callers of `chat_completion()` must change from `result` to `result$content`
- All callers of `get_embeddings()` must change from `result` to `result$embeddings`
- **Plan 02 will update all callers** (rag.R, slides.R, mod_query_builder.R, mod_document_notebook.R, _ragnar.R)

**No cost logging is active yet:**
- This plan creates the infrastructure
- Plan 02 will integrate cost logging into actual API calls

## Files Changed

### Created
- `R/cost_tracking.R` (156 lines) - Cost estimation, logging, and query functions
- `migrations/003_create_cost_log.sql` (15 lines) - Database schema for cost tracking

### Modified
- `R/api_openrouter.R` - Changed chat_completion and get_embeddings return types
- `R/db.R` - Added cost_log table to init_schema()

## Commits

- `e2f7e7d`: feat(05-01): add usage metadata to API functions and create cost tracking
- `01a1db4`: feat(05-01): create cost_log database table via migration 003

## Self-Check: PASSED

**Created files exist:**
- FOUND: R/cost_tracking.R
- FOUND: migrations/003_create_cost_log.sql

**Modified files exist:**
- FOUND: R/api_openrouter.R
- FOUND: R/db.R

**Commits exist:**
- FOUND: e2f7e7d
- FOUND: 01a1db4

**Database verification:**
- Migration 003 applied successfully
- cost_log table has all required columns
- Indexes created successfully

**Function verification:**
- All 5 cost tracking functions defined and working
- API functions return new structured format
