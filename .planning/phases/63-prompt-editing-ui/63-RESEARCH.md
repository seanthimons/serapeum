# Phase 63: Prompt Editing UI - Research

**Researched:** 2026-03-21
**Domain:** R/Shiny UI module, DuckDB CRUD, prompt text extraction from R/rag.R
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Prompt editor lives as a new section in the Settings page (right column or below existing sections)
- Presets listed in grouped format: Quick (Summarize, Key Points, Study Guide, Outline) and Deep (Overview, Conclusions, Research Questions, Literature Review, Methodology Extractor, Gap Analysis, Slides)
- Clicking a preset name opens a modal dialog with the prompt editor
- No preview/test button — users test by running the preset in their notebook after saving
- Only the task instruction portion of each prompt is exposed for editing
- Hidden: role preamble, CITATION RULES block, OWASP separator markers, source context formatting
- Read-only note: "This prompt is combined with citation rules and source context when generating output. You're editing the task instructions only."
- For `generate_preset()`: the values in the `presets` list are the editable portions
- For dedicated generators: the task-specific instruction paragraphs within `system_prompt` are editable
- Citation rules are NOT editable
- `rag_query()` chat prompt is excluded — only preset prompts are editable
- Dropdown/selectInput of dates (most recent first) above the editor textarea
- Selecting a date loads that version's text into the editor (non-destructive; must click Save to activate)
- "Reset to Default" loads hardcoded default into textarea; on save, all custom versions for that preset are deleted
- No diff view between versions
- Plain textAreaInput (rows=15) in modal dialog — no syntax highlighting
- Explicit save button in modal footer with confirmation toast
- Validation: non-empty check only

### Claude's Discretion
- Exact layout within Settings page (new section heading, position relative to existing sections)
- Modal sizing and styling details
- How to extract the "editable portion" from each preset's system_prompt (string splitting strategy)
- Whether to create a separate helper file (e.g., R/prompt_helpers.R) or add functions to R/db.R

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PRMT-01 | User can view the system/task prompt for each AI preset | Prompt defaults catalogued below; DB read function pattern established |
| PRMT-02 | User can edit the system/task prompt for each AI preset | UPSERT to prompt_versions via `INSERT OR REPLACE` confirmed in test-db-migrations.R |
| PRMT-03 | RAG plumbing is hidden; only instruction text is exposed with read-only description | Editable vs. hidden portions mapped for every generator; clear split points identified |
| PRMT-05 | User can recall previous prompt versions by date | prompt_versions table has version_date; query pattern: `ORDER BY version_date DESC` |
| PRMT-06 | User can reset any preset prompt to the hardcoded default | Reset = delete all rows for preset_slug, then use hardcoded default |
</phase_requirements>

---

## Summary

Phase 63 creates a prompt editing UI inside the Settings page. The `prompt_versions` DuckDB table already exists (Phase 62, migration 011). The UI work is: (1) a new Settings section listing presets in two groups, (2) a modal-per-preset with a selectInput version dropdown, a textAreaInput editor, Save and Reset buttons, and a read-only note. The DB work is: (3) CRUD helpers for prompt_versions — save (UPSERT), list versions, load specific version, reset (DELETE all). The pipeline work is: (4) each generator in R/rag.R checks prompt_versions before using its hardcoded default.

The most nuanced task is identifying the "editable portion" of each generator. For `generate_preset()`, the split is clean — the entire value in the `presets` named list is the editable task instruction. For the deep presets, the editable text is the task instruction section within `system_prompt`, clearly separated from role preamble, CITATION RULES, and OUTPUT FORMAT blocks.

**Primary recommendation:** Create `R/prompt_helpers.R` for CRUD and default extraction; add integration in each generator as a one-liner look-up before the hardcoded text.

---

## Editable Prompt Inventory

This is the most critical research output. The planner must know exactly what text is editable for each preset, what the slug is, and where the split points are.

### Quick Presets — `generate_preset()` (R/rag.R line 157–162)

These are the simplest case. The entire string in the `presets` named list is the editable instruction. Everything outside that list (role preamble starting "You are a helpful research assistant...", the CITATION RULES block, the `user_prompt` sprintf wrapper) is hidden machinery.

| Preset slug | Editable default text (full) |
|-------------|------------------------------|
| `summarize` | `"Provide a comprehensive summary of all the documents. Highlight the main themes, key findings, and important conclusions. Organize your summary with clear sections."` |
| `keypoints` | `"Extract the key points from these documents as a bulleted list. Focus on the most important facts, findings, arguments, and conclusions. Group related points together."` |
| `studyguide` | `"Create a study guide based on these documents. Include:\n1. Key concepts and definitions\n2. Important facts and figures\n3. Main arguments and their supporting evidence\n4. Potential exam questions with brief answers"` |
| `outline` | `"Create a structured outline of the main topics covered in these documents. Use hierarchical headings (I, A, 1, a) to organize the content logically. Include brief descriptions under each heading."` |

**Split strategy:** The editable text is `presets[[preset_type]]`. The system_prompt is built around it at lines 219–230 (role + CITATION RULES appended). The generator must call a lookup function BEFORE the `presets` list assignment and substitute that value in.

### Deep Presets — Dedicated Generators

Each generator builds a multi-paragraph `system_prompt` via `paste0()` or a multiline string. The editable portion is the task instruction block; CITATION RULES and OUTPUT FORMAT are hidden machinery.

#### `conclusions` — `generate_conclusions_preset()` (lines 270+, editable from ~line 370)

The editable task instruction is the core instruction block before the CITATION RULES appear. Looking at the actual system_prompt (lines ~370–406):

- **Role preamble (hidden):** `"You are a research synthesizer. Analyze the provided research and synthesize the key conclusions, findings, and areas of agreement or disagreement across sources."`
- **CITATION RULES (hidden):** The block starting "CITATION RULES: - Cite every..."
- **Editable portion (task instruction):** The instruction block immediately after role and before CITATION RULES: `"Synthesize the key conclusions from the provided research sources. Identify where sources agree and disagree, highlighting the most significant findings and their implications."` — NOTE: the actual text in the code must be verified line-by-line since conclusions uses a multiline sprintf. The OUTPUT FORMAT block (`## Research Conclusions`, `## Agreements & Disagreements`) is also hidden.

**Split strategy:** Role line = line 1 of system_prompt string. CITATION RULES section starts at the line containing "CITATION RULES:". Output format starts at "OUTPUT FORMAT:". Editable content = everything between role preamble end and CITATION RULES start.

#### `overview` — `generate_overview_preset()` (lines 454+)

The overview has multiple `call_*` helper functions with different system prompts depending on mode. The editable instruction differs by call:
- `call_overview_quick`: instruction includes the depth and key-points format description
- `call_overview_summary` / `call_overview_keypoints`: separate instructions

**Decision needed for planner:** Since overview has branching prompts (quick vs thorough mode), the editable portion should be the "base" instruction that applies to the quick path — the most commonly used path. The depth_instruction is parameterized (concise vs detailed), not a prompt to edit. The planner should define the editable text as the Quick path's primary instruction around lines 551–571.

Editable portion (quick path, lines 551–573): The instruction block starting with "Generate an overview..." through the thematic organization directives, stopping before CITATION RULES.

#### `research_questions` — `generate_research_questions()` (lines 700+, system_prompt at 811–833)

The entire system_prompt string is the editable portion. It begins with "You are a research gap analyst..." — but the role line should stay hidden. The INSTRUCTIONS block (1–6), OUTPUT FORMAT, and SCALING directives are all editable.

**Practical split:** The role preamble is line 1 ("You are a research gap analyst. Your task is to identify gaps..."). Everything from "INSTRUCTIONS:" through "IMPORTANT: Base analysis ONLY on the provided sources..." is the editable task instruction. The `user_prompt` sprintf wrapper (paper metadata + retrieved content injection) is always hidden.

#### `lit_review` — `generate_lit_review_table()` (lines 916+, system_prompt at ~1037–1054)

Editable portion: The COLUMNS, RULES, and FOOTNOTES blocks (lines 1040–1054 in the paste0 chain). Role line ("You are a literature review specialist generating a comparison table") is hidden.

#### `methodology` — `generate_methodology_extractor()` (lines 1119+, system_prompt at 1242–1262)

Editable portion: The COLUMNS, RULES, and FOOTNOTES blocks. Role line ("You are a methodology extraction assistant...") is hidden.

#### `gap_analysis` — `generate_gap_analysis()` (lines 1332+, system_prompt at 1470–1493)

Editable portion: The OUTPUT FORMAT section headers list and RULES block. Role line ("You are a research gap analyst. Generate a narrative prose gap analysis report.") is hidden.

#### `slides` — `build_slides_prompt()` in R/slides.R (lines 38+, system_prompt at 64–101)

The slides preset is more complex — the system_prompt is hardcoded Quarto syntax rules. The editable portion is limited to the content rules block (lines 93–100: "Use ## for individual slide titles...", max bullet count, etc.). The Quarto Syntax Reference section, footnote format instructions, and speaker notes format are hidden machinery.

**Practical consideration:** Slides has a `custom_instructions` field already exposed in the slide generation modal. This is a separate per-generation field, not the system prompt. The editable prompt for `slides` in the editor should target the core content rules block of `build_slides_prompt()`.

---

## Standard Stack

### Core (already in use — no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Existing | Module framework, reactiveVal, observeEvent, showModal | Project standard |
| bslib | Existing | card, card_header, layout_columns | Project standard |
| DBI + duckdb | Existing | dbGetQuery, dbExecute on prompt_versions | Phase 62 schema |

### UI Components (already in codebase)

| Component | Pattern | Where Used |
|-----------|---------|------------|
| `showModal(modalDialog(...))` | Modal dialogs | mod_document_notebook.R, mod_slides.R |
| `textAreaInput(ns("..."), rows = 15)` | Freeform text | Standard Shiny |
| `selectInput(ns("..."))` | Version dropdown | mod_settings.R |
| `showNotification(...)` | Save confirmation toast | Throughout |
| `icon_edit()` | Edit icon | theme_catppuccin.R line 183 |
| `icon_save()` | Save icon | theme_catppuccin.R line 133 |
| `icon_refresh()` | Reset icon | theme_catppuccin.R line 188 |

**Installation:** None required — all dependencies already present.

---

## Architecture Patterns

### Recommended Project Structure

New files:
```
R/
├── prompt_helpers.R        # CRUD helpers for prompt_versions + default text registry
R/mod_settings.R            # Add new Prompt Editor section (UI + server)
R/rag.R                     # Add lookup calls in each generator
R/slides.R                  # Add lookup call in build_slides_prompt()
tests/testthat/
└── test-prompt-helpers.R   # Unit tests for CRUD and default registry
```

### Pattern 1: Settings Module Extension

The Settings module (`mod_settings.R`) uses a two-column `layout_columns(col_widths = c(6, 6))`. The new "AI Prompts" section should be appended below existing content — it's wide enough to warrant spanning both columns or sitting in a full-width section below the two-column block.

The UI function adds a new `hr()` + `h5()` + action buttons section. The server function adds `observeEvent` handlers for the new inputs, following the existing pattern exactly.

**Example modal pattern (from mod_document_notebook.R lines 362–371):**
```r
showModal(modalDialog(
  title = paste(icon_edit(), "Edit Prompt:", preset_label),
  size = "l",
  easyClose = TRUE,
  # ... body content ...
  footer = tagList(
    actionButton(ns("save_prompt"), "Save", class = "btn-primary", icon = icon_save()),
    actionButton(ns("reset_prompt"), "Reset to Default", class = "btn-outline-secondary", icon = icon_refresh()),
    modalButton("Cancel")
  )
))
```

### Pattern 2: Prompt Helpers CRUD

Recommended helper functions in `R/prompt_helpers.R`:

```r
# Returns character vector of version_date strings for a preset, most recent first
list_prompt_versions <- function(con, preset_slug) {
  result <- DBI::dbGetQuery(con,
    "SELECT version_date FROM prompt_versions
     WHERE preset_slug = ?
     ORDER BY version_date DESC",
    list(preset_slug))
  as.character(result$version_date)
}

# Returns prompt_text for a specific version, or NULL if not found
get_prompt_version <- function(con, preset_slug, version_date) {
  result <- DBI::dbGetQuery(con,
    "SELECT prompt_text FROM prompt_versions
     WHERE preset_slug = ? AND version_date = ?",
    list(preset_slug, as.character(version_date)))
  if (nrow(result) == 0) NULL else result$prompt_text[1]
}

# Returns most recent custom prompt, or NULL if no custom versions exist
get_active_prompt <- function(con, preset_slug) {
  result <- DBI::dbGetQuery(con,
    "SELECT prompt_text FROM prompt_versions
     WHERE preset_slug = ?
     ORDER BY version_date DESC
     LIMIT 1",
    list(preset_slug))
  if (nrow(result) == 0) NULL else result$prompt_text[1]
}

# UPSERT: stores prompt for today's date (one version per preset per day)
save_prompt_version <- function(con, preset_slug, prompt_text) {
  today <- as.character(Sys.Date())
  DBI::dbExecute(con,
    "INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text)
     VALUES (?, ?, ?)",
    list(preset_slug, today, prompt_text))
  invisible(TRUE)
}

# Reset: delete all custom versions for a preset
reset_prompt_to_default <- function(con, preset_slug) {
  DBI::dbExecute(con,
    "DELETE FROM prompt_versions WHERE preset_slug = ?",
    list(preset_slug))
  invisible(TRUE)
}
```

### Pattern 3: Default Text Registry

A named list in `prompt_helpers.R` storing the hardcoded default for each preset slug. This is the single source of truth for "Reset to Default" and for displaying the initial text when no custom version exists.

```r
PROMPT_DEFAULTS <- list(
  summarize          = "Provide a comprehensive summary...",   # exact string from rag.R line 158
  keypoints          = "Extract the key points...",            # exact string from rag.R line 159
  studyguide         = "Create a study guide...",              # exact string from rag.R line 160
  outline            = "Create a structured outline...",       # exact string from rag.R line 161
  conclusions        = "<extracted from generate_conclusions_preset system_prompt>",
  overview           = "<extracted from generate_overview_preset quick path>",
  research_questions = "<extracted from generate_research_questions system_prompt>",
  lit_review         = "<extracted from generate_lit_review_table system_prompt>",
  methodology        = "<extracted from generate_methodology_extractor system_prompt>",
  gap_analysis       = "<extracted from generate_gap_analysis system_prompt>",
  slides             = "<extracted from build_slides_prompt content rules>"
)

# Lookup with fallback to default
get_effective_prompt <- function(con, preset_slug) {
  custom <- get_active_prompt(con, preset_slug)
  if (!is.null(custom)) custom else PROMPT_DEFAULTS[[preset_slug]]
}
```

### Pattern 4: Generator Integration

Each generator in R/rag.R replaces its hardcoded instruction string with a call to `get_effective_prompt()`. For `generate_preset()`:

```r
# Before: prompt <- presets[[preset_type]]
# After:
prompt <- get_effective_prompt(con, preset_type)
if (is.null(prompt)) {
  return(sprintf("Unknown preset type: %s", preset_type))
}
```

For dedicated generators, the system_prompt construction substitutes the task instruction block:

```r
# Before (example for conclusions):
task_instruction <- "Synthesize the key conclusions..."
# After:
task_instruction <- get_effective_prompt(con, "conclusions")
```

### Pattern 5: Modal UX Flow

```
Settings page → "AI Prompts" section → preset list (grouped: Quick / Deep)
  → Click preset name button
    → showModal opens with:
        [version dropdown] — "Current (2026-03-20)" / "2026-03-18" / "Default"
        [read-only note] — "This prompt is combined with citation rules..."
        [textAreaInput rows=15] — populated with selected version's text
    → User edits text
    → Click Save → save_prompt_version() → removeModal() → showNotification("Prompt saved!")
    → Click Reset to Default → reset_prompt_to_default() + load default text into textarea
        → User still needs to click Save to persist (by convention: reset loads into editor)
    → Click Cancel / easyClose → no change
```

**Key behavior:** When Reset is clicked, it populates the textarea with the default text but does NOT immediately delete custom versions — the user must click Save. This matches the CONTEXT.md decision: "on save, all custom versions for that preset are deleted."

Alternatively: Reset button could immediately delete and show confirmation. The CONTEXT.md says "loads the hardcoded default text into the textarea; user confirms by saving; on save, all custom versions for that preset are deleted." This confirms the two-step approach: Reset → populate textarea → Save → delete custom versions.

**Implementation detail:** The Save handler must detect whether the current text matches the default (i.e., Reset was triggered) and call `reset_prompt_to_default()` rather than `save_prompt_version()`. Cleanest approach: use a `reactiveVal(FALSE)` called `reset_pending` that Reset sets to TRUE and Save checks.

### Anti-Patterns to Avoid

- **Loading the full rag.R prompt string at runtime:** Don't parse the R source file to extract defaults. Hard-code defaults in `PROMPT_DEFAULTS` in prompt_helpers.R — this is the authoritative list.
- **Using a single global observeEvent for all presets:** The modal input IDs are the same for every preset (ns("prompt_text"), ns("save_prompt"), etc.) because each opens the same modal. Use a `reactiveVal` to track the currently-open preset slug.
- **Re-registering observers per modal open:** Use a single observer bound to `input$save_prompt` that reads the current-preset reactiveVal — not dynamic observers created in a loop.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UPSERT with composite PK | Custom UPDATE + INSERT logic | `INSERT OR REPLACE INTO` (DuckDB) | Composite PK (preset_slug, version_date) already enforces one-per-day |
| Date formatting | Custom date string | `as.character(Sys.Date())` → "YYYY-MM-DD" | DuckDB DATE type accepts ISO strings |
| Modal dialogs | Custom JS overlays | `showModal(modalDialog(...))` | Already used throughout codebase |
| Toast notifications | Custom UI messages | `showNotification()` | Already used throughout settings module |

---

## Common Pitfalls

### Pitfall 1: Stale Modal Input After Multiple Opens

**What goes wrong:** User opens preset A modal, closes it, opens preset B modal. The `input$prompt_text` value still reflects preset A's content on the first render.

**Why it happens:** Shiny's `textAreaInput` retains its value across `showModal` calls unless explicitly updated.

**How to avoid:** Use `updateTextAreaInput(session, "prompt_text", value = loaded_text)` inside the observer that opens the modal, not just in the UI. This forces a fresh value on each open.

**Warning signs:** Test by opening two different presets consecutively — verify the second modal shows the correct preset's text.

### Pitfall 2: `reactiveVal` Preset Tracker Not Set Before Observer Fires

**What goes wrong:** User clicks a preset button; the open-modal observer fires before the `current_preset_slug` reactiveVal is updated; Save uses the previous slug.

**How to avoid:** Set `current_preset_slug(slug)` before `showModal(...)` in the same `observeEvent` block. R executes sequentially within a single observer — this ordering is safe.

### Pitfall 3: Version Dropdown Choices Not Refreshed After Save

**What goes wrong:** User saves a new version; the dropdown still shows old dates.

**Why it happens:** The dropdown is populated when the modal opens; saving doesn't trigger a re-render of the already-open modal.

**How to avoid:** After `save_prompt_version()`, call `updateSelectInput(session, "version_select", choices = ...)` with refreshed choices from `list_prompt_versions()`. This updates the dropdown in-place while the modal stays open.

### Pitfall 4: Reset Logic Bug — Saving Default as a Version

**What goes wrong:** User clicks Reset, then Save — and the "default" text gets saved as a new row in prompt_versions, meaning "Reset" didn't actually reset (there are now custom rows again).

**How to avoid:** Track reset state with `reset_pending <- reactiveVal(FALSE)`. When Save fires and `reset_pending()` is TRUE: call `reset_prompt_to_default(con, slug)` (DELETE all rows), then `showNotification("Reset to default — no custom versions stored.")`. When `reset_pending()` is FALSE: call `save_prompt_version()` normally. Clear `reset_pending` to FALSE after either path.

### Pitfall 5: Generator Integration — NULL Handling

**What goes wrong:** `get_effective_prompt()` returns NULL for an unknown slug; generator crashes.

**How to avoid:** `get_effective_prompt()` should return NULL only for truly unknown slugs. Add a guard in each generator: `if (is.null(prompt)) return(sprintf("Unknown preset type: %s", preset_type))`.

---

## Code Examples

### Version Dropdown Population on Modal Open

```r
# Source: Shiny docs, established pattern from mod_settings.R
observeEvent(input[[paste0("edit_", slug)]], {
  current_preset_slug(slug)
  versions <- list_prompt_versions(con(), slug)

  choices <- if (length(versions) > 0) {
    setNames(versions, paste("Saved:", versions))
  } else {
    character(0)
  }

  # Load the most recent custom version, or the default
  initial_text <- get_effective_prompt(con(), slug)
  reset_pending(FALSE)

  showModal(modalDialog(
    title = paste(icon_edit(), "Edit Prompt:", preset_display_names[[slug]]),
    size = "l",
    easyClose = TRUE,
    selectInput(ns("version_select"),
      "Version History",
      choices = c("Current" = "current", choices),
      selected = "current"
    ),
    p(class = "text-muted small",
      icon_info(),
      "This prompt is combined with citation rules and source context when generating output.",
      "You're editing the task instructions only."
    ),
    textAreaInput(ns("prompt_text"), NULL, value = initial_text, rows = 15,
                  width = "100%"),
    footer = tagList(
      actionButton(ns("save_prompt"), "Save", class = "btn-primary", icon = icon_save()),
      actionButton(ns("reset_prompt"), "Reset to Default",
                   class = "btn-outline-secondary", icon = icon_refresh()),
      modalButton("Cancel")
    )
  ))
})
```

### Save Handler with Reset Detection

```r
observeEvent(input$save_prompt, {
  slug <- current_preset_slug()
  req(slug)

  if (reset_pending()) {
    reset_prompt_to_default(con(), slug)
    reset_pending(FALSE)
    removeModal()
    showNotification(
      paste("Reset to default for:", preset_display_names[[slug]]),
      type = "message"
    )
  } else {
    text <- trimws(input$prompt_text)
    if (nchar(text) == 0) {
      showNotification("Prompt cannot be empty.", type = "error")
      return()
    }
    save_prompt_version(con(), slug, text)
    # Refresh dropdown
    versions <- list_prompt_versions(con(), slug)
    updateSelectInput(session, "version_select",
      choices = c("Current" = "current",
                  setNames(versions, paste("Saved:", versions))),
      selected = "current"
    )
    showNotification(paste("Prompt saved for:", preset_display_names[[slug]]),
                     type = "message")
  }
})
```

### DuckDB UPSERT (confirmed from test-db-migrations.R line 261)

```r
# Source: test-db-migrations.R line 261 — confirmed DuckDB syntax
DBI::dbExecute(con,
  "INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text)
   VALUES (?, ?, ?)",
  list(preset_slug, as.character(Sys.Date()), prompt_text))
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ad-hoc DB changes | Versioned migrations (db_migrations.R) | Phase ~v8 | prompt_versions uses migration 011, already applied |
| Raw `icon("name")` calls | Semantic wrappers in theme_catppuccin.R | Phase v10 | Use `icon_edit()`, `icon_save()`, `icon_refresh()` — never raw `icon()` |
| Global shinyjs | session$sendCustomMessage for JS | Phase 60 | No useShinyjs() in this project |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (R) |
| Config file | None detected — tests run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRMT-01 | `get_effective_prompt()` returns hardcoded default when no custom versions | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-02 | `save_prompt_version()` writes to prompt_versions, `get_effective_prompt()` returns custom text | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-02 | `save_prompt_version()` same-day UPSERT replaces existing row | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-03 | `PROMPT_DEFAULTS` list has entries for all 11 slugs | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-05 | `list_prompt_versions()` returns dates in descending order | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-05 | `get_prompt_version()` returns correct text for a specific date | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-06 | `reset_prompt_to_default()` deletes all rows for a slug | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |
| PRMT-06 | After reset, `get_effective_prompt()` returns hardcoded default | unit | `test_file('test-prompt-helpers.R')` | Wave 0 |

### Sampling Rate

- **Per task commit:** `testthat::test_file('tests/testthat/test-prompt-helpers.R')`
- **Per wave merge:** `testthat::test_dir('tests/testthat')`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/testthat/test-prompt-helpers.R` — covers all PRMT-01 through PRMT-06 CRUD behaviors
- [ ] In-memory DuckDB fixture with prompt_versions table (same pattern as test-db-migrations.R)

---

## Open Questions

1. **Overview prompt editable scope**
   - What we know: `generate_overview_preset()` has multiple call paths (quick/thorough) and a `depth_instruction` parameter that varies at runtime
   - What's unclear: Which path's system_prompt string becomes the "editable portion" for the editor
   - Recommendation: Use the quick-path system prompt (`call_overview_quick`) as the editable text. It is the most commonly used path and the most complete instruction. Planner should note that `depth_instruction` is NOT part of the editable block — it is parameterized at call time.

2. **Slides preset — custom_instructions vs system_prompt**
   - What we know: `build_slides_prompt()` already exposes `custom_instructions` in the modal UI; the system_prompt contains Quarto syntax rules
   - What's unclear: Whether editing the system_prompt is useful, or if the existing `custom_instructions` field already meets the need
   - Recommendation: Include slides in the editor for completeness (the content rules block is editable), but note that `custom_instructions` continues to work as a per-generation override.

---

## Sources

### Primary (HIGH confidence)
- `R/rag.R` — All generator system_prompt strings read directly; editable portions identified line by line
- `R/mod_settings.R` — Existing Settings UI/server patterns read directly
- `R/db_migrations.R` — Migration runner and `apply_migration()` pattern confirmed
- `migrations/011_create_prompt_versions.sql` — Table schema confirmed: composite PK (preset_slug, version_date)
- `tests/testthat/test-db-migrations.R` lines 259–273 — `INSERT OR REPLACE` DuckDB UPSERT syntax confirmed working
- `R/theme_catppuccin.R` lines 133–488 — All available icon wrappers confirmed

### Secondary (MEDIUM confidence)
- `R/slides.R` lines 38–123 — `build_slides_prompt()` structure confirmed; editable portion identified

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in use; no new dependencies needed
- Architecture: HIGH — exact patterns confirmed from reading the codebase; CRUD helpers straightforward
- Editable prompt inventory: HIGH for quick presets (exact strings quoted); MEDIUM for deep presets (planner must extract exact strings from the generator code as part of implementation)
- Pitfalls: HIGH — reactive state management pitfalls are well-understood Shiny patterns

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable codebase; generators unlikely to change)
