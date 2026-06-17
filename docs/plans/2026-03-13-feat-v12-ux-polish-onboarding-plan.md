---
title: "feat: V12.0 UX Polish & Onboarding"
type: feat
date: 2026-03-13
issues: [150, 87, 60, 9]
brainstorm: docs/brainstorms/2026-03-13-v12-ux-polish-onboarding-brainstorm.md
---

# V12.0: UX Polish & Onboarding

## Overview

Four parallel features that improve the new-user experience, provide feedback during long operations, expose LLM prompts for user control, and add version tracking. All issues are independent and can be implemented in any order.

## Feature 1: Onboarding & Notebook Descriptions (#150)

### Problem

The welcome modal (wizard) only shows 3 options (seed paper, query builder, browse topics) and doesn't mention setup, importing, citation network, or citation audit. The welcome landing page shows a different framing (Search Papers, Upload Documents, Configure Settings). Neither reflects the actual workflow order. New users have no guidance on what each sidebar section does.

### Proposed Solution

Rework both the welcome modal and landing page to reflect a 5-step workflow progression, and add contextual help text on each sidebar section's empty/landing state.

### Implementation

#### 1a. Rework the welcome modal — `app.R:559-597`

Replace the current 3-card `wizard_modal()` with a 5-step workflow layout:

1. **Set up** — API keys, choose models, download/refresh metadata
2. **Find papers** — search, seed discovery, topics, query builder
3. **Collect** — import into notebooks, upload PDFs
4. **Analyze** — chat, synthesis presets, citation network
5. **Audit** — citation audit for gaps

Design: Use a vertical stepped layout instead of the current 3-column equal cards. Each step gets a number badge, title, 1-line description, and a button for the primary action of that step (e.g., step 1 → "Go to Settings", step 2 → "New Search Notebook").

Keep existing behavior:
- Show only when no notebooks exist (`app.R:599-609`)
- "Don't show this again" link with localStorage persistence
- `easyClose = TRUE`

**Bug fix:** The `has_seen_wizard` localStorage flag is stored but never checked (`app.R:141-143`). Wire it into the observe guard at line 600 so "Don't show again" actually works.

#### 1b. Rework the welcome landing page — `app.R:1010-1048`

Replace the current 3-card layout with the same 5-step progression used in the modal. This is the persistent landing page (shown whenever `current_view == "welcome"`), so it should be more detailed than the modal:

- Each step gets a card with icon, title, description, and action button(s)
- Use `layout_columns(col_widths = 12)` for a single-column stacked layout that reads top-to-bottom
- Step 1 (Setup) should show current status: API key configured? Models selected? Metadata downloaded?

#### 1c. Add contextual help text on sidebar section landing states

Each sidebar section's module should show a brief description when the user first lands on it (before they've taken action). Add help text to these views:

| View | Module | What to show |
|------|--------|-------------|
| Seed Discovery | `R/mod_seed_discovery.R` | "Paste a DOI or title to find related papers through citations and references." |
| Query Builder | `R/mod_query_builder.R` | "Describe your research interest and AI will help build an effective OpenAlex search query." |
| Topic Explorer | `R/mod_topic_explorer.R` | "Browse OpenAlex's topic hierarchy to discover research areas and find papers by field." |
| Citation Network | `R/mod_citation_network.R` | "Visualize citation relationships between papers to discover influential work and research clusters." |
| Citation Audit | `R/mod_citation_audit.R` | "Check your collection for missing seminal papers and citation gaps." |
| Document Notebook | `R/mod_document_notebook.R` | "Upload PDFs and use AI to chat with your documents, generate summaries, and extract insights." |
| Search Notebook | `R/mod_search_notebook.R` | "Search OpenAlex for academic papers, filter results, and import papers for analysis." |

Implementation: Add a `div(class = "text-muted mb-3", ...)` at the top of each module's UI, or within the module's empty state conditional.

### Acceptance Criteria

- [x] Welcome modal shows 5-step workflow progression
- [x] "Don't show this again" preference is actually respected
- [x] Welcome landing page matches the same 5-step progression
- [x] Landing page step 1 shows live setup status (keys, models, metadata)
- [x] Each sidebar section has contextual help text visible on first load
- [x] Dark mode styling works for all new elements

---

## Feature 2: Chat UX Progress Messaging (#87)

### Problem

Heavy synthesis presets (lit review, gap analysis, etc.) take 10+ seconds with no feedback beyond a spinner. The current `is_processing()` flag shows "Thinking..." but gives no indication of what stage the operation is in. Regular chat also just shows "Thinking..." with no context.

### Proposed Solution

Two-tier feedback:
- **Modal overlay** for heavy synthesis presets with 3-stage status text + stop button
- **Inline status text** for regular chat messages

### Implementation

#### 2a. Synthesis progress modal — `R/mod_document_notebook.R`

Reuse the citation network progress modal pattern from `R/mod_citation_network.R:518-543`.

Create a synthesis progress modal that shows:
- Spinner icon (no progress bar — LLM calls have no granular progress signal)
- Rotating status text: "Preparing context..." → "Sending to LLM..." → "Processing response..."
- **No stop button** — synthesis presets run synchronously via `chat_completion()`. Unlike the citation network (which uses `mirai` workers + interrupt flags), there is no mechanism to cancel a synchronous HTTP request mid-flight. Adding async would be a significant refactor out of scope for V12. The modal is display-only.

**Which presets get the modal:** All presets that call `generate_preset()` in `R/rag.R`:
- Literature Review (`btn_lit_review`)
- Research Gaps (`btn_gaps`)
- Research Questions (`btn_questions`)
- Methodology Extractor (`btn_methodology`)
- Overview (`btn_overview`)
- Conclusions / Future Directions (`btn_conclusions`)

**Other presets** (Study Guide, Outline) also get the modal — they use the same `generate_preset()` path and can be slow on large notebooks.

**Empty notebook guard:** If the notebook has no documents/papers, skip the modal and show an inline warning instead of flashing a modal then immediately showing an error.

**State management:** Add reactive values:
```r
synthesis_stage <- reactiveVal("idle")  # idle, preparing, sending, processing
```

**Stage transitions:**
1. User clicks preset → check notebook has content (if not, show warning and abort)
2. `synthesis_stage("preparing")` → show modal → build context from chunks
3. Context ready → `synthesis_stage("sending")` → make API call
4. Response received → `synthesis_stage("processing")` → format output
5. Output ready → `synthesis_stage("idle")` → remove modal, append to chat

**JavaScript handler** — create a `updateSynthesisStatus` handler that updates the message text (simpler than the citation network's `updateBuildProgress` since there's no progress bar).

#### 2b. Inline status text for regular chat — `R/mod_document_notebook.R:846-860`

Modify the existing spinner block to show contextual text instead of just "Thinking...":

```r
if (is_processing()) {
  status_text <- if (length(docs) > 0) {
    sprintf("Analyzing %d papers...", length(docs))
  } else {
    "Thinking..."
  }
  # ... render spinner with status_text
}
```

### Dark Mode Considerations

- Modal background: use `!important` on dark mode CSS for `.modal-content` (learned from `.planning/debug/resolved/shiny-notification-dark-mode.md`)
- Set `easyClose = FALSE` during synthesis to prevent accidental dismissal
- Test spinner visibility against dark background

### Acceptance Criteria

- [x] All synthesis presets (8 total) show a display-only modal with spinner + status text
- [x] Modal status rotates through 3 stages (preparing → sending → processing)
- [x] Empty notebooks skip the modal and show an inline warning
- [x] Regular chat shows contextual inline status ("Analyzing N papers...")
- [x] Modal styled correctly in both light and dark modes
- [x] `easyClose = FALSE` prevents accidental dismissal

---

## Feature 3: Prompt Transparency (#60)

### Problem

Users have no visibility into the LLM prompts being sent. Power users want to see and customize prompts before sending. Developers need visibility into OpenAlex API calls for debugging.

### Proposed Solution

- **Opt-in editable prompt window** for LLM calls (collapsed by default)
- **Verbose toggle** in settings for OpenAlex console logging

### Implementation

#### 3a. Editable prompt window — `R/mod_document_notebook.R` + `R/rag.R`

**Pattern:** Extend the slide generation `textAreaInput` pattern from `R/mod_slides.R:99-105`.

**UI change:** Add a collapsible prompt editor above the chat input area. When expanded, it shows the system prompt and user prompt that will be sent.

```r
# Collapsible prompt editor
bslib::accordion(
  id = ns("prompt_accordion"),
  open = FALSE,  # collapsed by default
  bslib::accordion_panel(
    title = "View/Edit Prompt",
    icon = icon_edit(),
    textAreaInput(ns("system_prompt_edit"), "System Prompt", rows = 4),
    textAreaInput(ns("user_prompt_edit"), "User Prompt", rows = 6)
  )
)
```

**Prompt flow change in `R/rag.R`:**

Currently `generate_preset()` builds prompts internally and calls `chat_completion()` directly. Refactor to:
1. Add a `build_preset_prompt(preset_type, context)` function that returns `list(system = ..., user = ...)`
2. `generate_preset()` calls `build_preset_prompt()` then `chat_completion()`
3. The UI can call `build_preset_prompt()` to populate the editor, let the user modify, then pass the modified prompts to `chat_completion()`

**For regular chat:** Same pattern — show the assembled RAG prompt (system prompt + retrieved context + user message) in the editor before sending.

**Scope — which LLM calls get the editor:**
- Synthesis presets (all 8) — show the task instruction portion of the prompt
- Regular RAG chat — show the user's question + system prompt context
- Query builder LLM assist — show the query generation prompt
- Slide generation — already has custom instructions field, no change needed
- **Do not expose:** the full system prompt internals (OWASP guards, output format instructions) or raw RAG context chunks. Show the user-facing task/instruction portion only.

**Interaction flow:**
1. User types a message or clicks a preset
2. If prompt editor is collapsed → send immediately (current behavior, no change)
3. If prompt editor is expanded → populate editor with the task prompt, wait for user to click "Send" from the editor
4. User can modify the prompt text before sending

**Edge case — prompt editor + synthesis modal:** If the prompt editor is expanded when a preset is clicked, show the prompt for review instead of the progress modal. The modal only appears for the "collapsed editor" fast path. Once the user clicks "Send" from the editor, the modal appears for the remaining stages (sending → processing).

**Preference persistence:** The collapsed/expanded state does not persist across sessions — defaults to collapsed every time.

#### 3b. Verbose toggle for OpenAlex — `R/mod_settings.R` + `R/api_openalex.R`

**Settings UI** — add to the left column "Advanced" section in `R/mod_settings.R`:

```r
bslib::input_switch(
  id = ns("verbose_mode"),
  label = "Verbose API logging",
  value = FALSE
)
p(class = "text-muted small", "Log OpenAlex API calls to the browser console for debugging.")
```

**Persistence:** Use existing `save_db_setting(con, "verbose_mode", value)` / `get_db_setting(con, "verbose_mode", default = FALSE)` pattern.

**Logging:** In `R/api_openalex.R`, wrap API calls to emit a `shiny::showNotification()` or JavaScript `console.log()` when verbose mode is enabled:

```r
if (get_db_setting(con, "verbose_mode", FALSE)) {
  session$sendCustomMessage("consoleLog", list(
    label = "OpenAlex API",
    url = request_url
  ))
}
```

Add a JavaScript handler:
```javascript
Shiny.addCustomMessageHandler('consoleLog', function(data) {
  console.log('[' + data.label + ']', data.url);
});
```

### Acceptance Criteria

- [x] Collapsible prompt editor appears above chat input (collapsed by default)
- [x] Expanding the editor populates it with the assembled prompt
- [x] User can edit prompt text before sending
- [x] Collapsed editor doesn't change current send behavior
- [x] Verbose toggle appears in Settings under Advanced
- [x] Toggle persists across sessions via DB setting
- [x] OpenAlex API URLs logged to R console when verbose mode is on
- [x] Works in both light and dark modes

---

## Feature 4: Versioning (#9)

### Problem

No version number displayed anywhere in the app. No changelog or release notes. Users (and the developer) have no way to know what version is running or what changed recently.

### Proposed Solution

- Version constant in code
- Version tag in the title bar
- "What's New" section on the About page

### Implementation

#### 4a. Version constant — `R/config.R`

Add a version constant at the top of `R/config.R`:

```r
SERAPEUM_VERSION <- "12.0.0"
```

Single source of truth — referenced by title bar and About page.

#### 4b. Version in title bar — `app.R:47-55`

Modify the title div to include a version badge:

```r
title = div(
  class = "d-flex align-items-center justify-content-between w-100",
  div(
    class = "d-flex align-items-center gap-2",
    icon_book_open(),
    "Serapeum",
    span(class = "badge bg-secondary small", paste0("v", SERAPEUM_VERSION))
  ),
  bslib::input_dark_mode(id = "dark_mode")
),
```

Also update `window_title` to include version:
```r
window_title = paste("Serapeum", paste0("v", SERAPEUM_VERSION)),
```

#### 4c. What's New section — `R/mod_about.R`

Add a new section to the About page between the two-column layout (line 172) and three-column layout (line 177). Follow the existing `hr(class = "my-4")` separator pattern.

```r
hr(class = "my-4"),
h4(class = "text-center mb-3", icon_star(), " What's New"),
div(
  class = "mx-auto", style = "max-width: 700px;",
  # v12.0
  h6(paste0("v", SERAPEUM_VERSION, " — UX Polish & Onboarding")),
  tags$ul(
    tags$li("Reworked welcome experience with guided workflow"),
    tags$li("Progress feedback for synthesis operations"),
    tags$li("Editable LLM prompts for power users"),
    tags$li("Version tracking and What's New section")
  ),
  # Previous versions
  h6("v11.0 — Citation Network Refinements"),
  tags$ul(
    tags$li("Year filter slider/histogram alignment fix"),
    tags$li("Community-aware edge weighting for cluster separation"),
    tags$li("Timeline heatmap visualization")
  ),
  # ... additional versions as desired
)
```

Keep the What's New content as a static list — no need to pull from GitHub or parse a CHANGELOG file for a local-first app.

### Acceptance Criteria

- [x] `SERAPEUM_VERSION` constant exists in `R/config.R`
- [x] Version badge visible in title bar (e.g., "Serapeum v12.0.0")
- [x] Browser tab title includes version
- [x] What's New section visible on About page with current + recent version notes
- [x] Badge styled correctly in both light and dark modes

---

## Technical Considerations

### Dark Mode
All new UI elements must include `!important` flags on dark mode CSS overrides per established project convention. Key areas:
- Synthesis progress modal background and text
- Welcome modal stepped layout
- Version badge colors
- Prompt editor textarea background

### Module Size
Per project concern about large modules (search notebook is 1,760 lines), keep changes focused:
- Welcome modal/landing page changes stay in `app.R` (where they already live)
- Synthesis modal logic added to `mod_document_notebook.R` (where presets already live)
- Prompt refactoring touches `R/rag.R` (where prompts already live)
- No new modules needed — changes extend existing patterns in their natural locations

### Namespace Safety
All new element IDs in modules must use `ns()` for proper namespacing.

### Settings Persistence
New settings (verbose mode) use existing `save_db_setting()`/`get_db_setting()` pattern — no schema migration needed.

---

## Dependencies & Risks

- **#60 depends loosely on #87**: If the prompt editor is expanded and a synthesis preset is clicked, both the prompt editor and progress modal could be active. Decision: when prompt editor is expanded, show the prompt for review instead of the progress modal — the modal only appears for the "collapsed editor" fast path.
- **No external dependencies**: All features use existing packages (bslib, shiny, htmltools).
- **Dark mode risk**: New modal components need explicit dark mode testing per project learnings. Use `!important` on all dark mode overrides for new modals.
- **Synchronous synthesis**: Synthesis presets run synchronously — no stop/cancel button possible without refactoring to `mirai` async workers. Out of scope for V12. Modal is display-only.
- **Welcome modal + landing page overlap**: Both show the 5-step workflow. The modal is a one-time onboarding prompt; the landing page is the persistent home screen. They share the same progression but differ in density — the modal is a quick overview, the landing page has action buttons and live status for each step.
- **localStorage wizard skip is dead code**: The `has_seen_wizard` input is wired in JS but never consumed server-side. Fix this as part of #150.

## References

### Internal
- Welcome modal: `app.R:558-633`
- Welcome landing page: `app.R:1010-1048`
- Title bar: `app.R:45-55`
- Synthesis presets: `R/mod_document_notebook.R:934-955`
- Preset prompts: `R/rag.R:145-234`
- Slide prompt editing: `R/mod_slides.R:99-105`
- Citation network progress modal: `R/mod_citation_network.R:501-594`
- Settings page: `R/mod_settings.R:1-140`
- About page: `R/mod_about.R:1-263`
- Icon helpers: `R/theme_catppuccin.R:122-617`
- Config loader: `R/config.R`
- Dark mode debug notes: `.planning/debug/resolved/shiny-notification-dark-mode.md`

### Issues
- #150: Notebook paths should have short descriptions for new users
- #87: Chat UX: modal messaging
- #60: Toggle/UI to expose API queries
- #9: Versioning for releases
