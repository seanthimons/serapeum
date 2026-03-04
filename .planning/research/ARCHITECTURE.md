# Architecture Integration Research

**Domain:** Theme Harmonization + AI Synthesis Presets in R/Shiny Research Assistant
**Researched:** 2026-03-04
**Confidence:** HIGH

## Executive Summary

This milestone adds **global theme policy**, **citation audit bug fixes**, **sidebar/button theming**, and **two new AI synthesis presets** (Methodology Extractor, Gap Analysis Report) to an existing R/Shiny app with ~20,000 LOC across 18 production files.

**Key architectural insight:** All new features integrate with existing patterns. Theme policy extends `R/theme_catppuccin.R`. Presets extend `R/rag.R` preset functions. Citation audit fixes touch `R/mod_citation_audit.R` and `R/mod_search_notebook.R`. No new modules, no architectural changes — pure extension.

**Build order recommendation:** Theme policy first (foundation) → Citation audit fixes (critical bugs) → Sidebar/button theming (apply policy) → Methodology preset → Gap Analysis preset.

## Existing Architecture Overview

### System Structure

```
┌─────────────────────────────────────────────────────────┐
│                       UI Layer                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │ app.R: page_sidebar() + bs_theme()               │   │
│  │  - Sidebar: notebook list + discovery buttons    │   │
│  │  - Main: navset_card_tab() for notebooks/modules │   │
│  └────────────────┬─────────────────────────────────┘   │
├──────────────────┬┴─────────────────────────────────────┤
│             Module Layer (14 Shiny modules)              │
│  ┌────────────┐ ┌────────────┐ ┌────────────────────┐   │
│  │ Document   │ │ Search     │ │ Citation           │   │
│  │ Notebook   │ │ Notebook   │ │ Network/Audit      │   │
│  └──────┬─────┘ └──────┬─────┘ └──────┬─────────────┘   │
│         │              │               │                 │
│  ┌──────┴──────────────┴───────────────┴──────────────┐  │
│  │  Discovery Modules (producer-consumer pattern)     │  │
│  │  - Seed Discovery, Query Builder, Topic Explorer   │  │
│  └─────────────────────┬──────────────────────────────┘  │
├──────────────────────┬─┴─────────────────────────────────┤
│              Business Logic Layer                        │
│  ┌────────────┐ ┌────────────┐ ┌────────────────────┐   │
│  │ R/rag.R    │ │ R/pdf.R    │ │ R/api_*.R          │   │
│  │ - Presets  │ │ - Section  │ │ - OpenRouter       │   │
│  │ - Retrieval│ │   Detection│ │ - OpenAlex         │   │
│  └──────┬─────┘ └──────┬─────┘ └──────┬─────────────┘   │
│         │              │               │                 │
│  ┌──────┴──────────────┴───────────────┴──────────────┐  │
│  │ R/db.R: Database operations + hybrid search        │  │
│  └─────────────────────┬──────────────────────────────┘  │
├──────────────────────┬─┴─────────────────────────────────┤
│               Data Layer                                 │
│  ┌────────────┐ ┌────────────┐ ┌────────────────────┐   │
│  │ DuckDB     │ │ Ragnar     │ │ Theme              │   │
│  │ notebooks  │ │ per-notebook│ │ R/theme_catppuccin │   │
│  │ .duckdb    │ │ stores      │ │ - MOCHA/LATTE      │   │
│  └────────────┘ └────────────┘ └────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns

**1. Shiny Module Pattern** (`mod_*_ui()` + `mod_*_server()`)
- 14 production modules in `R/mod_*.R`
- Namespace isolation via `NS(id)` in UI, `ns()` in server
- Reactive communication via `reactiveVal()` and callbacks
- Example: `mod_search_notebook.R` (2634 lines), `mod_document_notebook.R` (789 lines)

**2. Preset Function Pattern** (R/rag.R)
- `generate_preset()`: Simple presets (summarize, keypoints, studyguide, outline)
- `generate_conclusions_preset()`: Section-targeted RAG with three-level fallback
- `generate_research_questions()`: Standalone function with paper metadata enrichment
- Common: RAG retrieval → prompt building → LLM call → cost logging

**3. Theme System** (R/theme_catppuccin.R)
- Catppuccin LATTE (light) and MOCHA (dark) palettes
- `bs_theme()` for base colors in `app.R` (lines 57-72)
- `catppuccin_dark_css()` generates all `[data-bs-theme="dark"]` overrides (~244 lines)
- Applied via `bs_add_rules()` in `app.R` theme block

**4. Section-Targeted RAG** (R/db.R + R/pdf.R)
- `detect_section_hint()`: Keyword heuristics classify chunks (methods, conclusion, discussion, etc.)
- `search_chunks_hybrid()`: Optional `section_filter` parameter for targeted retrieval
- Three-level fallback: section-filtered → unfiltered → direct DB (graceful degradation)
- Used by Conclusions preset, Research Questions preset

## Integration Points for New Features

### 1. Global Theme Policy (Issue #138)

**Existing touchpoint:** `R/theme_catppuccin.R`

**Integration pattern:**
- Define semantic color mapping in new section of `theme_catppuccin.R`
- Document mapping: action type → Bootstrap semantic class → Catppuccin color
- Example structure:
  ```r
  # Semantic Action Color Policy
  # - Destructive/delete: danger (MOCHA$red / LATTE$red)
  # - Primary/create: primary (MOCHA$lavender / LATTE$lavender)
  # - Success/import: success (MOCHA$green / LATTE$green)
  # - Info/explore: info (MOCHA$blue / LATTE$blue)
  # - Warning/caution: warning (MOCHA$yellow / LATTE$yellow)
  ```

**What changes:**
- ADD: Design policy documentation in `theme_catppuccin.R` (comment block or exported constant)
- MODIFY: None (policy is documentation, not code)

**Data flow:**
- One-way: Policy document → Developer reads → Applies to buttons

**Why this works:**
- Policy extends existing theme system without new abstractions
- Catppuccin palette already defines all semantic colors
- Bootstrap 5 semantic classes (`btn-primary`, `btn-danger`) automatically theme-aware

---

### 2. Citation Audit Bug Fixes (Issues #134, #133)

**Existing touchpoints:**
- `R/mod_citation_audit.R` (error on adding multiple papers)
- `R/mod_search_notebook.R` (papers not appearing in abstract notebook)

**Integration pattern:**
- Bug #134: Likely error in `check_audit_imports()` or batch import SQL (line 111 in mod_citation_audit.R)
- Bug #133: Abstract refresh reactive not triggering after import (line 2483-2493 in mod_search_notebook.R)

**What changes:**
- MODIFY: `R/mod_citation_audit.R` — Fix SQL/error handling in audit import flow
- MODIFY: `R/mod_search_notebook.R` — Fix reactive invalidation in abstract list after import

**Data flow:**
```
Citation Audit Import Flow (Current):
1. User selects papers → selected_ids reactive
2. Click import → mod_citation_audit imports to target notebook DB
3. Navigate to target notebook → mod_search_notebook loads abstracts
   [BUG: Abstracts not refreshed if notebook already open]

Expected Flow:
1-2. Same
3. Navigate + invalidate abstracts reactive → reload from DB
```

**Why these are bugs, not features:**
- Code path exists, fails under specific conditions (multiple papers, already-open notebook)
- No new architecture — just defensive checks and reactive invalidation

---

### 3. Sidebar + Button Theming (Issues #137, #139)

**Existing touchpoints:**
- `app.R` lines 160-221 (sidebar structure)
- `R/mod_search_notebook.R` abstract preview buttons (lines 1682-1767)

**Integration pattern:**
- Apply theme policy from #138 to sidebar discovery buttons
- Standardize button style: icon-only vs icon+label, outline vs filled
- Ensure WCAG AA contrast in both light/dark modes

**What changes:**
- MODIFY: `app.R` sidebar button classes (apply semantic classes from policy)
- MODIFY: `R/mod_search_notebook.R` abstract preview button classes
- POSSIBLY ADD: New CSS rules in `catppuccin_dark_css()` if buttons need dark mode overrides

**Current sidebar button pattern:**
```r
actionButton("new_document_nb", "New Document Notebook",
             class = "btn-primary", icon = icon("file-pdf"))
actionButton("new_search_nb", "New Search Notebook",
             class = "btn-outline-primary", icon = icon("magnifying-glass"))
actionButton("discover_paper", "Discover from Paper",
             class = "btn-outline-success", icon = icon("seedling"))
```

**Needs harmonization:**
- Consistency: `btn-outline-*` for discovery actions, `btn-*` for primary create?
- Theme alignment: Apply policy (e.g., "Import Papers" should be `btn-outline-success`, not `btn-outline-primary`)
- Dark mode: Verify `btn-outline-secondary` contrast (Issue #137 mentions citation audit hard to read in light mode)

**Data flow:**
- One-way: User clicks button → Shiny input event → Module handles

---

### 4. Methodology Extractor Preset (Issue #100)

**Existing touchpoint:** `R/rag.R` — extends preset system

**Integration pattern:**
- Clone `generate_conclusions_preset()` architecture
- Use section-targeted RAG with `section_filter = c("methods", "introduction")`
- Structured prompt for: Study Design | Sample | Measures | Analysis

**What changes:**
- ADD: `generate_methodology_preset()` function in `R/rag.R` (after line 664)
- MODIFY: `R/mod_document_notebook.R` — Add "Extract Methods" button in preset section
- MODIFY: `R/mod_search_notebook.R` — Add "Extract Methods" button in preset section (if applies to search notebooks)

**New function signature:**
```r
generate_methodology_preset <- function(con, config, notebook_id,
                                        notebook_type = "document",
                                        session_id = NULL)
```

**Section filter strategy:**
```r
# Try section-filtered search first
chunks <- search_chunks_hybrid(
  con,
  query = "methods methodology study design sample statistical analysis",
  notebook_id = notebook_id,
  limit = 10,
  section_filter = c("methods", "introduction", "results"),  # Methods often in intro for some papers
  api_key = api_key,
  embed_model = embed_model
)

# Fallback: retry without section filter (graceful degradation)
if (is.null(chunks) || nrow(chunks) == 0) {
  chunks <- search_chunks_hybrid(..., section_filter = NULL)
}
```

**Prompt structure:**
```r
system_prompt <- "You are a research methodology expert. Extract and organize methodological details from the provided sources."

user_prompt <- sprintf("Sources:\n%s\n\nTask: Extract research methods as a structured report:

## Study Design
[Type of study, research design, approach]

## Sample Characteristics
[Population, sample size, demographics, selection criteria]

## Data Collection
[Instruments, measures, materials, procedures]

## Analysis Methods
[Statistical tests, software, analytical approach]

Cite sources for each claim.", context)
```

**Data flow:**
```
User clicks "Extract Methods"
  ↓
mod_document_notebook observeEvent(input$btn_methodology)
  ↓
generate_methodology_preset(con, config_r(), notebook_id, "document", session$token)
  ↓
search_chunks_hybrid(section_filter = c("methods", "introduction", "results"))
  ↓
build_context(chunks)
  ↓
chat_completion(api_key, chat_model, messages)
  ↓
log_cost() + return markdown
  ↓
Insert into chat history with AI disclaimer
```

**Why this works:**
- Reuses existing `search_chunks_hybrid()` with `section_filter` (already tested for Conclusions preset)
- Same RAG retrieval → LLM generation → cost logging pattern
- `detect_section_hint()` already classifies "methods" chunks (line 60 in pdf.R)

---

### 5. Gap Analysis Report Preset (Issue #101)

**Existing touchpoint:** `R/rag.R` — extends preset system

**Integration pattern:**
- Clone `generate_conclusions_preset()` architecture
- Use section-targeted RAG with `section_filter = c("conclusion", "limitations", "discussion")`
- Inferential prompt: Identify absences, contradictions, underexplored areas

**What changes:**
- ADD: `generate_gap_analysis_preset()` function in `R/rag.R` (after Methodology preset)
- MODIFY: `R/mod_document_notebook.R` — Add "Gap Analysis" button in preset section
- MODIFY: `R/mod_search_notebook.R` — Add "Gap Analysis" button in preset section

**New function signature:**
```r
generate_gap_analysis_preset <- function(con, config, notebook_id,
                                         notebook_type = "document",
                                         session_id = NULL)
```

**Section filter strategy:**
```r
# Same three-level fallback as Conclusions preset
chunks <- search_chunks_hybrid(
  con,
  query = "limitations gaps future research contradictions underexplored",
  notebook_id = notebook_id,
  limit = 10,
  section_filter = c("conclusion", "limitations", "future_work", "discussion"),
  api_key = api_key,
  embed_model = embed_model
)
```

**Prompt structure:**
```r
system_prompt <- "You are a research synthesis expert. Systematically identify gaps, contradictions, and underexplored areas in the literature."

user_prompt <- sprintf("Sources:\n%s\n\nTask: Analyze research gaps across this corpus. Organize by:

## Methodological Gaps
[Missing methods, design limitations, measurement issues]

## Population Gaps
[Underrepresented demographics, geographic regions, contexts]

## Theoretical Gaps
[Unexplored mechanisms, missing frameworks, unanswered questions]

## Contradictory Findings
[Where studies disagree or produce inconsistent results]

## Emerging Opportunities
[New research directions suggested by recent work]

For each gap, cite specific sources that reveal or discuss it. Mark contradictions clearly.", context)
```

**Data flow:**
- Identical to Methodology preset flow
- Difference: Different prompt, different section filter priority, higher inferential nature

**Risk mitigation:**
- AI disclaimer banner (same as Conclusions preset, line 764-780 in mod_search_notebook.R)
- OWASP instruction-data separation (already in all presets)
- Higher hallucination risk acknowledged in Issue #101 — prompt should explicitly request citations

**Why this works:**
- Same architecture as Conclusions and Methodology presets
- Section detection already handles "limitations", "discussion", "conclusion" (lines 40-54 in pdf.R)
- Three-level fallback ensures graceful degradation on older notebooks without section hints

---

## Component Responsibilities (Modified)

| Component | Current Responsibility | New Additions |
|-----------|------------------------|---------------|
| `R/theme_catppuccin.R` | MOCHA/LATTE palette + dark CSS overrides | ADD: Semantic action color policy documentation |
| `R/rag.R` | RAG retrieval + preset generation (4 presets) | ADD: `generate_methodology_preset()`, `generate_gap_analysis_preset()` |
| `R/mod_citation_audit.R` | Citation audit UI + async analysis | FIX: Error handling for multi-paper import (#134) |
| `R/mod_search_notebook.R` | Search notebook UI (papers, filters, chat, presets) | FIX: Abstract refresh reactive (#133), MODIFY: Button theming (#137, #139), ADD: Methodology + Gap buttons |
| `R/mod_document_notebook.R` | Document notebook UI (PDFs, chat, presets) | ADD: Methodology + Gap buttons |
| `app.R` | Main UI layout + sidebar | MODIFY: Sidebar button theming (#137) |

## Data Flow Changes

### New Preset Generation Flow

```
User clicks "Extract Methods" or "Gap Analysis"
  ↓
Shiny input event → observeEvent() in mod_*_notebook.R
  ↓
generate_methodology_preset() OR generate_gap_analysis_preset()
  ↓
search_chunks_hybrid(section_filter = [...])
  ↓ (three-level fallback if needed)
search_chunks_hybrid(section_filter = NULL)
  ↓ (if still empty)
Direct DB query for chunks
  ↓
build_context(chunks)
  ↓
chat_completion(api_key, chat_model, formatted_messages)
  ↓
log_cost(con, "chat", chat_model, usage, session_id)
  ↓
Return markdown string
  ↓
Insert into chat history with AI disclaimer banner
```

**Key characteristics:**
- Synchronous (user waits for LLM response)
- Cost-tracked (every preset generation logs to `cost_log` table)
- Section-aware (leverages existing `section_hint` metadata from PDF ingestion)
- Failsafe (graceful degradation if section hints missing)

---

## Build Order Recommendation

### Phase 1: Foundation (Theme Policy)
**Why first:** Design policy document informs all theming work

1. Define semantic action color policy in `R/theme_catppuccin.R`
2. Document mapping: action type → Bootstrap class → Catppuccin color
3. No code changes — pure documentation

**Validation:**
- Design doc complete
- Developer can reference policy for button styling

---

### Phase 2: Critical Bugs (Citation Audit)
**Why second:** Blocking issues before new features

1. Fix #134: Citation audit error on multiple papers
   - Debug `R/mod_citation_audit.R` import flow
   - Add error handling / defensive SQL

2. Fix #133: Citation audit papers not appearing in abstract notebook
   - Fix reactive invalidation in `R/mod_search_notebook.R`
   - Ensure abstracts reload after import

**Validation:**
- Import multiple papers from citation audit → no error
- Navigate to target notebook → papers appear immediately

---

### Phase 3: Apply Theme (Sidebar + Buttons)
**Why third:** Policy defined, bugs fixed, now harmonize UI

1. Apply policy to sidebar buttons (`app.R` lines 160-190)
   - Standardize outline vs filled, colors per policy
   - Fix #137: Citation audit button contrast

2. Apply policy to abstract preview buttons (`R/mod_search_notebook.R` lines 1682-1767)
   - Standardize icon vs icon+label
   - Fix #139: Abstract button theming

3. Add dark mode CSS overrides if needed (in `catppuccin_dark_css()`)

**Validation:**
- All buttons follow policy
- WCAG AA contrast in light and dark modes
- Visual consistency across modules

---

### Phase 4: Methodology Extractor Preset
**Why fourth:** Easier preset (factual extraction, lower hallucination risk)

1. Add `generate_methodology_preset()` to `R/rag.R`
   - Clone `generate_conclusions_preset()` structure
   - Section filter: `c("methods", "introduction", "results")`
   - Structured prompt for Study Design | Sample | Measures | Analysis

2. Add "Extract Methods" button to `R/mod_document_notebook.R`
   - Same pattern as existing preset buttons (lines 728-791)
   - Render conditionally based on `rag_available()`

3. Add "Extract Methods" button to `R/mod_search_notebook.R`
   - Same pattern as existing preset buttons (lines 728-791)

**Validation:**
- Button appears when RAG available
- Section-filtered retrieval works (check chunks have methods sections)
- Fallback to unfiltered works (try on notebook without section hints)
- Output structured as expected
- Cost logged correctly

---

### Phase 5: Gap Analysis Report Preset
**Why fifth:** More inferential, higher hallucination risk — build after simpler preset

1. Add `generate_gap_analysis_preset()` to `R/rag.R`
   - Clone `generate_conclusions_preset()` structure
   - Section filter: `c("conclusion", "limitations", "future_work", "discussion")`
   - Inferential prompt for gaps, contradictions, opportunities

2. Add "Gap Analysis" button to `R/mod_document_notebook.R`
   - Same pattern as Methodology preset

3. Add "Gap Analysis" button to `R/mod_search_notebook.R`
   - Same pattern as Methodology preset

**Validation:**
- Same validation as Methodology preset
- Verify AI disclaimer banner appears (inferential content)
- Check prompt requests citations (mitigate hallucination)

---

## New vs Modified Components

### NEW Components
- `generate_methodology_preset()` in `R/rag.R`
- `generate_gap_analysis_preset()` in `R/rag.R`
- Semantic action color policy documentation in `R/theme_catppuccin.R`

### MODIFIED Components
- `R/mod_citation_audit.R` — Bug fix for multi-paper import (#134)
- `R/mod_search_notebook.R` — Bug fix for abstract refresh (#133), button theming (#137, #139), new preset buttons
- `R/mod_document_notebook.R` — New preset buttons
- `app.R` — Sidebar button theming (#137)
- `R/theme_catppuccin.R` — Possibly new dark mode CSS rules for button contrast

### NO CHANGES
- `R/db.R` — Section-targeted RAG already exists
- `R/pdf.R` — Section detection already exists
- `R/rag.R` preset infrastructure — Only adding new functions, not modifying existing
- Database schema — No new migrations needed

---

## Risk Assessment

### Low Risk
- **Theme policy:** Documentation only, no code
- **Sidebar theming:** Changing CSS classes, well-tested Bootstrap classes
- **Methodology preset:** Factual extraction, existing section detection works

### Medium Risk
- **Citation audit bug fixes:** Debugging without clear reproduction steps (issues lack details)
- **Gap Analysis preset:** Higher inferential nature → hallucination risk (mitigated with AI disclaimer + citation requirement)

### High Risk
- None — All features extend existing patterns, no architectural changes

---

## Dependencies Between Components

```
Theme Policy (Phase 1)
    ↓ (informs)
Sidebar/Button Theming (Phase 3)

Citation Audit Bugs (Phase 2)
    ↓ (independent of theme, but blocks user workflow)
[No dependencies on other phases]

Methodology Preset (Phase 4)
    ↓ (depends on)
Section-Targeted RAG (existing, R/db.R + R/pdf.R)
    ↓ (independent of)
Gap Analysis Preset (Phase 5)
```

**Critical path:**
1. Theme Policy → Sidebar/Button Theming
2. Methodology Preset → Gap Analysis Preset (same pattern, validate simpler one first)

**Parallelizable:**
- Citation audit bugs (Phase 2) can run parallel to theme work (Phases 1, 3)
- Methodology and Gap presets share no dependencies with citation audit

---

## Testing Strategies

### Theme Policy
- **Manual:** Review policy doc for completeness
- **Visual:** Screenshot sidebar in light/dark mode, verify contrast

### Citation Audit Bugs
- **Unit:** Mock multi-paper import, verify no SQL errors
- **Integration:** Import papers from audit → navigate to notebook → verify papers appear
- **Regression:** Ensure single-paper import still works

### Sidebar/Button Theming
- **Manual:** Visual review of all buttons in light/dark mode
- **Accessibility:** WCAG AA contrast checker on all button states (hover, active, disabled)

### Methodology Preset
- **Unit:** Test `generate_methodology_preset()` with mock chunks
- **Integration:** Run on document notebook with PDFs containing methods sections
- **Fallback:** Test on notebook without section hints (should gracefully degrade)
- **Cost:** Verify cost logging to `cost_log` table

### Gap Analysis Preset
- **Same as Methodology preset**
- **Additional:** Review output for hallucination (do cited sources actually support claims?)

---

## Open Questions for Implementer

1. **Citation Audit Bug #134:** Error message not provided in issue — need to reproduce locally first
2. **Citation Audit Bug #133:** Is reactive invalidation the issue, or does `get_abstracts()` query need fixing?
3. **Sidebar Theming #137:** "Citation audit hard to read in light mode" — is this a contrast issue or color choice?
4. **Abstract Buttons #139:** "Convert all to symbols or add text to all" — which direction? (Recommend: icon + text for clarity)
5. **Preset Applicability:** Should Methodology and Gap Analysis apply to search notebooks, or document notebooks only? (Recommend: Both, since search notebooks have abstracts with methods/limitations sections)

---

## Sources

**Existing Codebase:**
- `app.R` — Main UI structure, sidebar, theme setup
- `R/theme_catppuccin.R` — Catppuccin palette, dark mode CSS
- `R/rag.R` — Preset generation functions (existing 3 presets)
- `R/db.R` — `search_chunks_hybrid()` with section filtering
- `R/pdf.R` — `detect_section_hint()` keyword heuristics
- `R/mod_citation_audit.R` — Citation audit module
- `R/mod_search_notebook.R` — Search notebook module
- `R/mod_document_notebook.R` — Document notebook module

**GitHub Issues:**
- #138: Global color theme for buttons/UI
- #137: Fix sidebar colors + theming
- #139: UI adjustment to abstract buttons
- #134: Citation audit shows error when adding multiple papers
- #133: Citation audit papers do not appear in abstract notebook
- #100: feat: Methodology Extractor preset
- #101: feat: Gap Analysis Report preset

**Milestone Context:**
- `.planning/PROJECT.md` — Project state, tech stack, architectural decisions
- Milestone v10.0 — Theme Harmonization & AI Synthesis

---

*Architecture integration research for: Serapeum v10.0 Theme Harmonization & AI Synthesis*
*Researched: 2026-03-04*
