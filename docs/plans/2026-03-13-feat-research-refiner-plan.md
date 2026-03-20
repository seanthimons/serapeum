---
title: "feat: Research Refiner — Recursive Abstract Scoring & Triage"
type: feat
date: 2026-03-13
issue: https://github.com/seanthimons/serapeum/issues/11
milestone: v13.0 Search & Discovery
brainstorm: docs/brainstorms/2026-03-13-recursive-abstract-searching.md
---

# Research Refiner — Recursive Abstract Scoring & Triage

## Overview

A dedicated **Research Refiner** module (new sidebar entry) that scores, ranks, and triages a large pool of candidate papers against a user-defined anchor. Returns papers most *useful* to the research narrative, not just the most *relevant* to the field.

Two-tier scoring architecture:
- **Tier 1 (Metadata)** — fast, free, composite score from citation velocity, FWCI, connectivity, and ubiquity penalty
- **Tier 2 (LLM-as-judge)** — optional, user-initiated, embedding similarity + LLM narrative utility evaluation

## Problem Statement

Serapeum's discovery tools (citation audit, network graph, seed search, query builder) generate large candidate pools — potentially thousands of papers. Most are topically relevant but not useful: foundational papers everyone knows, tangential work, redundant findings. There's no way to separate signal from noise at scale without reading every abstract.

## Proposed Solution

A standalone Shiny module (`mod_research_refiner.R`) with its own sidebar button, accessible from any point in the app. Users define an anchor (what they're looking for), select a candidate source (existing notebook papers or fetch from seeds), choose a scoring mode, and get a ranked list they can curate into notebooks.

## Technical Approach

### Architecture

```
app.R
├── sidebar: "Research Refiner" button (btn-outline-flamingo)
├── current_view("refiner") → mod_research_refiner_ui("refiner")
└── server: mod_research_refiner_server("refiner", con_r, effective_config, ...)

R/mod_research_refiner.R    # UI + server module
R/research_refiner.R        # Business logic (scoring engine, candidate fetching)
R/utils_scoring.R           # Shared scoring utilities (reusable by other modules later)
```

**Module signature follows existing pattern:**

```r
# R/mod_research_refiner.R
mod_research_refiner_ui <- function(id) { ... }

mod_research_refiner_server <- function(id, con_r, config_r,
                                         notebook_refresh = NULL,
                                         navigate_to_notebook = NULL) { ... }
```

**Wiring in app.R** (follows citation audit pattern):

```r
# Sidebar button
actionButton("research_refiner", "Research Refiner",
             class = "btn-outline-flamingo",
             icon = icon_funnel())

# View routing
observeEvent(input$research_refiner, {
  current_notebook(NULL)
  current_view("refiner")
})

# In output$main_content renderUI:
if (view == "refiner") {
  return(mod_research_refiner_ui("refiner"))
}

# Server module
mod_research_refiner_server("refiner", con_r,
  config_r = effective_config,
  navigate_to_notebook = function(notebook_id) {
    current_notebook(notebook_id)
    current_view("notebook")
    notebook_refresh(notebook_refresh() + 1)
  },
  notebook_refresh = notebook_refresh
)
```

### Database Schema

New tables for refiner runs and scored results:

```sql
CREATE TABLE IF NOT EXISTS refiner_runs (
  id VARCHAR PRIMARY KEY,
  anchor_type VARCHAR NOT NULL,        -- 'seeds', 'intent', 'both'
  anchor_intent VARCHAR,               -- Natural language intent text
  anchor_seed_ids VARCHAR,             -- JSON array of seed paper_ids
  source_type VARCHAR NOT NULL,        -- 'notebook', 'fetch'
  source_notebook_id VARCHAR,          -- Source notebook (Path A)
  mode VARCHAR DEFAULT 'discovery',    -- 'discovery', 'comprehensive', 'emerging', 'custom'
  weights VARCHAR,                     -- JSON: {w1: 0.3, w2: 0.2, ...}
  status VARCHAR DEFAULT 'running',
  total_candidates INTEGER DEFAULT 0,
  scored_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP
)

CREATE TABLE IF NOT EXISTS refiner_results (
  id VARCHAR PRIMARY KEY,
  run_id VARCHAR NOT NULL,
  paper_id VARCHAR NOT NULL,           -- OpenAlex work ID
  title VARCHAR,
  authors VARCHAR,
  abstract VARCHAR,
  year INTEGER,
  venue VARCHAR,
  doi VARCHAR,
  -- Raw metadata
  cited_by_count INTEGER DEFAULT 0,
  fwci DOUBLE,
  -- Computed scores
  seed_connectivity DOUBLE DEFAULT 0,  -- How many anchors connect
  bridge_score DOUBLE DEFAULT 0,       -- Cross-cluster connectivity
  citation_velocity DOUBLE DEFAULT 0,  -- citations_per_year
  ubiquity_penalty DOUBLE DEFAULT 0,   -- High if foundational bloat
  utility_score DOUBLE DEFAULT 0,      -- Final composite score
  -- Tier 2 scores (NULL until LLM evaluation)
  embedding_similarity DOUBLE,
  llm_utility_score DOUBLE,
  llm_rationale VARCHAR,
  -- User actions
  user_action VARCHAR DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  FOREIGN KEY (run_id) REFERENCES refiner_runs(id)
)
```

### Scoring Engine

Located in `R/utils_scoring.R` — a pure function library with no Shiny dependencies.

```r
# R/utils_scoring.R

#' Compute citation velocity (citations per year since publication)
compute_citation_velocity <- function(cited_by_count, year) {
  age <- max(as.integer(format(Sys.Date(), "%Y")) - year, 1)
  cited_by_count / age
}

#' Compute ubiquity penalty
#' Papers cited by >X% of the candidate pool are "assumed knowledge"
compute_ubiquity_penalty <- function(cited_by_count, pool_median_citations,
                                      pool_max_citations, threshold = 0.8) {
  # Normalize to 0-1 range relative to pool
  if (pool_max_citations == 0) return(0)
  normalized <- cited_by_count / pool_max_citations
  if (normalized > threshold) {
    (normalized - threshold) / (1 - threshold)  # Scale 0-1 above threshold
  } else {
    0
  }
}

#' Compute seed connectivity
#' How many anchor papers cite or are cited by this candidate
compute_seed_connectivity <- function(paper_id, anchor_refs, anchor_cited_by) {
  sum(paper_id %in% anchor_refs) + sum(paper_id %in% anchor_cited_by)
}

#' Compute composite utility score
compute_utility_score <- function(seed_connectivity, bridge_score,
                                   citation_velocity, fwci, ubiquity_penalty,
                                   weights) {
  weights$w1 * seed_connectivity +
    weights$w2 * bridge_score +
    weights$w3 * citation_velocity +
    weights$w4 * (fwci %||% 0) -
    weights$w5 * ubiquity_penalty
}

#' Get preset weights for a mode
get_preset_weights <- function(mode = "discovery") {
  switch(mode,
    discovery = list(w1 = 0.25, w2 = 0.30, w3 = 0.20, w4 = 0.15, w5 = 0.30),
    comprehensive = list(w1 = 0.30, w2 = 0.10, w3 = 0.20, w4 = 0.30, w5 = 0.05),
    emerging = list(w1 = 0.10, w2 = 0.15, w3 = 0.40, w4 = 0.25, w5 = 0.20),
    # Default to discovery
    list(w1 = 0.25, w2 = 0.30, w3 = 0.20, w4 = 0.15, w5 = 0.30)
  )
}
```

**Preset mode behavior:**

| Mode | w1 (connectivity) | w2 (bridge) | w3 (velocity) | w4 (fwci) | w5 (ubiquity) | Character |
|------|-------------------|-------------|---------------|-----------|---------------|-----------|
| Discovery | 0.25 | 0.30 | 0.20 | 0.15 | 0.30 | Bridge papers, novel connections, emerging work |
| Comprehensive | 0.30 | 0.10 | 0.20 | 0.30 | 0.05 | Broad coverage, high-impact, minimal penalty |
| Emerging | 0.10 | 0.15 | 0.40 | 0.25 | 0.20 | Recent, fast-rising, high field-relative impact |

### UI Layout

```
┌──────────────────────────────────────────────────────────────┐
│ 🔬 Research Refiner                                          │
│ Score and rank papers against your research anchor           │
├──────────────────────────────────────────────────────────────┤
│ STEP 1: Define Anchor                                        │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Anchor Type: ○ Seed Papers  ○ Research Intent  ○ Both   │ │
│ │                                                          │ │
│ │ [Seed paper DOI input / notebook selector]               │ │
│ │ [Research intent text area]                               │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ STEP 2: Select Candidates                                    │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Source: ○ From Notebook  ○ Fetch from Seeds              │ │
│ │ [Notebook selector dropdown] or [Fetch controls]         │ │
│ │                                        [N candidates]    │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ STEP 3: Scoring Mode                                         │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Mode: [Discovery ▾]  [▸ Advanced Weights]                │ │
│ │                                                          │ │
│ │ (Advanced: 5 sliders for w1-w5 when expanded)            │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ [Score Papers]                                               │
│                                                              │
│ RESULTS                                                      │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ Batch: [Accept All Top-N] [Prune Below Threshold]        │ │
│ │                                                          │ │
│ │ #1  Paper Title (2023)         Score: 0.87  [✓] [✗]     │ │
│ │     Authors | Venue | 45 cit/yr | FWCI 3.2              │ │
│ │                                                          │ │
│ │ #2  Paper Title (2022)         Score: 0.74  [✓] [✗]     │ │
│ │     Authors | Venue | 32 cit/yr | FWCI 2.1              │ │
│ │     ...                                                  │ │
│ │                                                          │ │
│ │ [▸ Run Deep Analysis (Tier 2)] — est. $0.04              │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ ACTIONS                                                      │
│ [Import Accepted → Notebook ▾] [Create New Notebook]         │
└──────────────────────────────────────────────────────────────┘
```

### Implementation Phases

#### Phase 1: Scoring Engine + UI Shell

**Goal:** Working Tier 1 scoring with static test data, module wired into app.

**Tasks:**
- [x] Create `R/utils_scoring.R` with pure scoring functions
- [x] Create `R/research_refiner.R` with business logic (candidate processing, batch scoring)
- [x] Create `R/mod_research_refiner.R` with UI shell (anchor setup, mode selector, results table)
- [x] Add sidebar button in `app.R` and wire view routing
- [x] Add `refiner_runs` and `refiner_results` tables to `R/db.R`
- [x] Add icon helper `icon_funnel()` to `R/theme_catppuccin.R`
- [x] Write unit tests for scoring functions in `tests/testthat/test-utils_scoring.R`

**Files touched:**
- `R/utils_scoring.R` (new)
- `R/research_refiner.R` (new)
- `R/mod_research_refiner.R` (new)
- `R/theme_catppuccin.R` (add icon_funnel)
- `R/db.R` (add tables + helpers)
- `R/cost_tracking.R` (add refiner_eval operation)
- `app.R` (sidebar button, view routing, module server)
- `tests/testthat/test-utils_scoring.R` (new)

**Success criteria:**
- [x] Sidebar button appears and navigates to refiner view
- [x] Scoring functions produce correct results for known inputs (42 tests pass)
- [x] DB tables create on startup without errors

#### Phase 2: Path A — Score from Existing Notebook

**Goal:** User can select a search notebook and score its papers against an anchor.

**Tasks:**
- [x] Implement notebook selector (search notebooks only, like citation audit)
- [x] Fetch anchor paper metadata from OpenAlex when seed DOI/ID entered
- [x] Compute seed_connectivity by fetching anchor's referenced_works and cited_by from OpenAlex
- [x] Score all papers in selected notebook using Tier 1 formula
- [x] Display scored results as ranked list with accept/reject buttons
- [x] Persist scores to `refiner_results` table
- [x] Progress indicator during scoring (withProgress)

**Success criteria:**
- [ ] Selecting a notebook with 50+ papers scores and ranks them in <5 seconds
- [ ] Accept/reject state persists across page navigation
- [ ] Scoring produces sensible rankings (not all tied, not random)

#### Phase 3: Preset Modes + Advanced Sliders

**Goal:** Full mode selection UX with Discovery/Comprehensive/Emerging and Advanced toggle.

**Tasks:**
- [x] Add mode radio buttons (Discovery/Comprehensive/Emerging)
- [x] Implement Advanced toggle that reveals 5 weight sliders (w1-w5)
- [x] Sliders initialize from preset weights when mode changes
- [ ] Custom slider positions switch mode indicator to "Custom"
- [x] Re-score button after changing weights
- [x] Store selected weights in `refiner_runs.weights` as JSON

**Success criteria:**
- [ ] Switching modes visibly changes ranking order
- [x] Advanced sliders update in sync with preset selection
- [ ] Manual slider changes mark mode as "Custom"

#### Phase 4: Path B — Fetch from Seeds

**Goal:** User can provide seed paper(s) and the system fetches related/citing/cited papers to build a candidate pool.

**Tasks:**
- [x] Add DOI/search input for seed papers (reuse seed discovery pattern)
- [x] Support multiple seeds (add/remove list)
- [x] Fetch citing papers, cited papers, and related papers from OpenAlex for each seed
- [x] De-duplicate across seeds
- [x] Feed combined pool into scoring pipeline
- [x] Show candidate count and fetch progress

**Success criteria:**
- [ ] 3 seed papers produce a de-duplicated candidate pool
- [ ] Pool is scored identically to Path A
- [ ] Fetch progress shows paper count accumulating

#### Phase 5: Curation + Notebook Export

**Goal:** Accepted papers can be imported into an existing notebook or a new one.

**Tasks:**
- [x] "Import Accepted" button with notebook selector dropdown
- [x] "Create New Notebook" option that creates a search notebook
- [x] Bulk insert accepted papers into target notebook's abstracts (reuse `create_abstract` pattern)
- [x] Create chunks for papers with abstracts
- [x] Navigate to target notebook after import
- [x] Show import count notification

**Success criteria:**
- [ ] Accepted papers appear in target notebook after import
- [ ] No duplicate papers if some already exist in target
- [ ] Notification confirms import count

#### Phase 6: Tier 2 — LLM Evaluation

**Goal:** Optional deep analysis using embeddings + LLM narrative utility scoring.

**Tasks:**
- [ ] Modal nudge at 50-100 accepted papers: "Run deep analysis?"
- [ ] Cost estimate based on paper count and current embedding/chat model pricing
- [ ] Embed accepted paper abstracts using `get_embeddings()` from `api_openrouter.R`
- [ ] Embed anchor (seed abstracts + intent text)
- [ ] Compute cosine similarity between each candidate and anchor embeddings
- [ ] LLM evaluation: for top-N candidates, use `chat_completion()` to judge narrative utility
- [ ] LLM prompt: "Given this research anchor: [anchor]. Does this paper add something the current accepted set doesn't cover? Rate 1-5 and explain."
- [ ] Store `embedding_similarity`, `llm_utility_score`, `llm_rationale` in refiner_results
- [ ] Display combined score (metadata + LLM) with expandable rationale per paper
- [ ] Log costs via existing cost tracking

**Files touched:**
- `R/mod_research_refiner.R` (Tier 2 UI, modal, rationale display)
- `R/research_refiner.R` (embedding + LLM scoring pipeline)
- `R/api_openrouter.R` (reuse chat_completion, get_embeddings)

**Success criteria:**
- [ ] Cost estimate shown before user opts in
- [ ] LLM rationale is coherent and specific to anchor
- [ ] Costs tracked in cost_log table
- [ ] Combined ranking meaningfully differs from metadata-only ranking

## Edge Cases & Mitigations

| Edge Case | Mitigation |
|-----------|-----------|
| Empty notebook selected as source | Show "No papers to score" message, disable Score button |
| Seed paper not found in OpenAlex | Show error toast, allow retry with different DOI |
| All papers score identically (e.g., no FWCI data) | Fall back to citation velocity + recency; show warning about limited metadata |
| Bridge score unavailable (no graph structure) | Set bridge_score = 0 for all, note in UI that bridge scoring requires network graph source |
| Very large candidate pool (>1000 papers) | Pagination on results; Tier 2 only on accepted subset; warn about API costs |
| Papers with no abstract | Still score on metadata; skip from Tier 2 embedding; flag in results |
| User re-runs refiner on same source | Create new run; previous run results preserved for comparison |
| LLM returns unparseable utility score | Default to metadata score; log parse failure |
| Session timeout during Tier 2 batch | Use mirai async like bulk import; results saved per-paper as scored |

## Open Questions (Deferred to Tuning)

1. **Weight defaults** — Initial presets above are starting points; needs tuning against real seed paper sets
2. **Ubiquity threshold** — Hardcoded at 0.8 normalized citation ratio; may need field-specific calibration
3. **Tier 2 prompt engineering** — "Narrative utility" framing needs iteration; may need few-shot examples
4. **Iterative feedback loop** — Deferred to post-MVP; Phase 1-6 covers batch scoring only
5. **One-shot prune** — Can be added as a threshold slider + "Remove below" button after Phase 3

## Dependencies & Prerequisites

- OpenAlex API access (email configured) — required for all paths
- OpenRouter API key — required only for Tier 2
- Existing search notebooks with papers — required for Path A
- `icon_funnel()` or similar icon — needs to be added to `utils_icons.R`

## References

### Internal References
- Module pattern: `R/mod_citation_audit.R` (closest architectural match)
- Business logic separation: `R/citation_audit.R` (scoring engine pattern)
- Sidebar wiring: `app.R:161-224` (button layout), `app.R:654-658` (view routing)
- View rendering: `app.R:971-1008` (main_content switch)
- Module server wiring: `app.R:1105-1113` (citation audit server call)
- DB schema: `R/db.R:62-76` (abstracts table), `R/db.R:237-268` (audit tables pattern)
- API clients: `R/api_openalex.R` (OpenAlex), `R/api_openrouter.R:37-63` (chat_completion), `R/api_openrouter.R:70-80` (get_embeddings)
- Progress pattern: `R/citation_audit.R:6-38` (file-based progress)
- Paper creation: `R/db.R:502` (create_abstract)

### Brainstorm
- `docs/brainstorms/2026-03-13-recursive-abstract-searching.md`

### Issue
- https://github.com/seanthimons/serapeum/issues/11
