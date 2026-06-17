# Phase 61: AI Theme Generation - Research

**Researched:** 2026-03-20
**Domain:** R/Shiny LLM integration, JSON extraction, hex/font validation, Bootstrap 5 popover UI
**Confidence:** HIGH — all findings verified directly from project source code and existing patterns

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Input UX & placement**
- Separate "AI Generate" button next to the theme dropdown (alongside the existing Upload link)
- Clicking opens a popover with a multi-line textarea (2-3 rows) and a "Generate" button
- Placeholder text only for guidance: "e.g., ocean blues, dark background, modern sans-serif font"
- No clickable examples or additional guidance UI

**LLM integration**
- Use the user's selected chat model (from Settings) — consistent with all other AI features
- System prompt includes the full CURATED_FONTS list so LLM picks from valid options
- LLM returns JSON in a markdown fence block (```json ... ```); app extracts JSON via regex
- All 5 fields required in JSON response: backgroundColor, mainColor, accentColor, linkColor, mainFont

**Validation & error handling**
- All 4 hex colors validated as valid 6-digit hex — if any invalid, reject entire response and show error toast naming the bad fields
- Font validated against CURATED_FONTS — if invalid, fall back to "Source Sans Pro" with a warning (don't reject the whole theme for one bad font)
- If JSON extraction fails entirely: silently retry the LLM call once, then show error "Couldn't generate theme. Try a more specific description."
- Maximum 2 LLM calls per Generate click (1 original + 1 retry)

**Post-generation flow**
- After successful generation: customize panel auto-expands with AI-populated color pickers and font selector
- Saving is manual — user reviews/tweaks AI values, then uses the existing "Save as custom theme" button from Phase 60
- Dedicated "Regenerate" button appears in the customize panel after AI generation (similar to slide generation's heal button pattern)
- Generation cost tracked in the session cost panel (existing cost tracking infrastructure) but not shown inline
- Spinner on Generate button during LLM call, button disabled to prevent double-clicks (same pattern as chat send button spinner from v5.0)

### Claude's Discretion
- Exact system prompt wording for theme generation
- Popover styling and positioning details
- How the "Regenerate" button integrates visually with the customize panel
- Whether to pre-fill the theme name input with a sanitized version of the description

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-05 | User can type a freeform description to generate a theme via AI | AI Generate trigger + popover textarea + LLM call pattern established in codebase |
| THME-06 | AI returns structured JSON (8-9 variables per REQUIREMENTS.md; 5 variables per CONTEXT.md decision), app templates into valid `.scss` | JSON extraction via regex on LLM response; `generate_custom_scss()` already handles SCSS templating |
| THME-07 | AI-generated themes validated for hex colors and real font names before saving | Hex regex pattern + CURATED_FONTS membership check; font fallback to "Source Sans Pro" |
</phase_requirements>

---

## Summary

Phase 61 adds AI-assisted theme generation on top of the Phase 60 color picker UI. The implementation is entirely self-contained in `R/mod_slides.R` with one new helper function added to `R/themes.R`. All infrastructure (LLM call pattern, cost tracking, panel expansion/collapse, color picker population, SCSS file writing) already exists and has been used in prior phases.

The primary challenge is the UI mechanism for the AI Generate trigger and its popover: Shiny inputs inside Bootstrap 5 popovers don't auto-register with the Shiny framework. The UI-SPEC (61-UI-SPEC.md) explicitly acknowledges this and recommends treating the popover as either (a) a Bootstrap collapse block within the modal, or (b) a true BS5 popover where the Generate button uses `Shiny.setInputValue()` directly. Both approaches are viable; the inline collapse is simpler for Shiny input wiring.

The JSON extraction + validation pipeline is the other key concern. The decided pattern (LLM returns ```json fence, regex extracts, validate all 5 fields) is a proven approach already used in other LLM features across the codebase.

**Primary recommendation:** Implement in two plans — Plan 01 adds the `generate_theme_from_description()` helper to themes.R (LLM call, JSON extraction, validation logic, unit tests), Plan 02 wires the UI into mod_slides.R (trigger, popover/collapse, spinner, panel expansion, Regenerate button, cost logging).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | project standard | HTTP calls to OpenRouter API | Already used in `api_openrouter.R` via `build_openrouter_request()` + `chat_completion()` |
| jsonlite | project standard | JSON parsing from LLM response | Already loaded in `api_openrouter.R`; `fromJSON()` for parsing extracted JSON string |
| testthat | project standard | Unit tests for new helper function | All project tests use testthat; `tests/testthat/test-themes.R` already tests themes.R |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Bootstrap 5 Collapse API | via bslib | Expand/collapse the customize panel programmatically | After successful AI generation, use `session$sendCustomMessage` + JS `bootstrap.Collapse.getOrCreateInstance(el).show()` |
| Bootstrap 5 Popover | via bslib | AI Generate popover (or use collapse block instead) | See popover vs. collapse tradeoff below |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap collapse for AI input area | True BS5 popover | Collapse is simpler — Shiny inputs inside a collapse div register normally; BS5 popover HTML is rendered outside Shiny's DOM tree, requiring manual `Shiny.setInputValue()` for the Generate button |
| Regex JSON extraction | `jsonlite::fromJSON()` directly on LLM response | LLM wraps JSON in ` ```json ``` ` fence per CONTEXT.md decision — regex extraction required before parsing |

**Installation:** No new packages required. All dependencies already in project.

---

## Architecture Patterns

### Recommended Project Structure

Phase 61 touches exactly two files:

```
R/
├── themes.R         # Add: generate_theme_from_description() helper
└── mod_slides.R     # Add: AI Generate UI, server observers, Regenerate button

tests/testthat/
└── test-themes.R    # Add: tests for generate_theme_from_description()
```

No new files needed. The new helper function belongs in `themes.R` with the other theme utilities.

### Pattern 1: LLM Call + JSON Extraction

**What:** Call `chat_completion()` with a system prompt containing CURATED_FONTS, parse JSON from the ` ```json ``` ` fence block.

**When to use:** Any time the LLM returns structured data embedded in a markdown code fence.

**Example (from rag.R and api_openrouter.R pattern):**
```r
# In themes.R — new helper
generate_theme_from_description <- function(api_key, model, description) {
  font_list <- paste(unlist(CURATED_FONTS), collapse = ", ")
  system_prompt <- paste0(
    "You generate RevealJS slide theme color schemes. ",
    "Return ONLY a JSON object inside a markdown code fence like this:\n",
    "```json\n{...}\n```\n",
    "Required fields: backgroundColor, mainColor, accentColor, linkColor, mainFont.\n",
    "All color values must be 6-digit hex strings (e.g. #1A2B3C).\n",
    "mainFont must be one of these exact values: ", font_list, "."
  )
  messages <- format_chat_messages(system_prompt, description)
  result <- chat_completion(api_key, model, messages)
  list(content = result$content, usage = result$usage)
}
```

**JSON extraction (regex):**
```r
extract_theme_json <- function(llm_response) {
  # Extract JSON from ```json ... ``` fence
  m <- regexpr("```json\\s*\\n(.*?)\\n```", llm_response, perl = TRUE)
  if (m == -1) return(NULL)
  json_str <- regmatches(llm_response, m)
  json_str <- sub("^```json\\s*\\n", "", json_str)
  json_str <- sub("\\n```$", "", json_str)
  tryCatch(jsonlite::fromJSON(json_str), error = function(e) NULL)
}
```

### Pattern 2: Hex Validation

**What:** Check all 4 color fields are valid 6-digit hex strings.

```r
is_valid_hex <- function(v) {
  is.character(v) && length(v) == 1 && grepl("^#[0-9A-Fa-f]{6}$", v)
}

validate_theme_colors <- function(theme_json) {
  fields <- c("backgroundColor", "mainColor", "accentColor", "linkColor")
  bad_fields <- fields[!sapply(fields, function(f) is_valid_hex(theme_json[[f]]))]
  bad_fields  # character(0) if all valid
}
```

### Pattern 3: Font Validation with Fallback

**What:** Check font name against CURATED_FONTS; fall back to "Source Sans Pro" with a warning notification (not an error).

```r
validate_and_fix_font <- function(font_name) {
  all_fonts <- unlist(CURATED_FONTS)
  if (font_name %in% all_fonts) {
    list(font = font_name, warning = NULL)
  } else {
    list(font = "Source Sans Pro",
         warning = "Font not recognized — using Source Sans Pro instead.")
  }
}
```

### Pattern 4: Spinner + Disable Button During LLM Call

**What:** Disable the Generate button and show a spinner during the async LLM call. This is driven by `session$sendCustomMessage()` since the button lives in a popover/collapse that is part of the modal DOM.

**Established pattern from Phase 60:**
```r
# JS message handler added to the collapse div's script block:
# Shiny.addCustomMessageHandler('set_button_loading', function(msg) {
#   var btn = document.getElementById(msg.id);
#   if (!btn) return;
#   if (msg.loading) {
#     btn.disabled = true;
#     btn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status">' +
#                     '<span class="visually-hidden">Loading</span></span> Generating...';
#   } else {
#     btn.disabled = false;
#     btn.innerHTML = msg.label;
#   }
# });

# In server:
session$sendCustomMessage("set_button_loading", list(id = ns("ai_generate_btn"), loading = TRUE, label = "Generate theme"))
```

### Pattern 5: Programmatic Panel Expansion

**What:** After successful AI generation, expand the customize panel via JS. This mirrors the existing collapse handler.

**From Phase 60 (mod_slides.R lines 247-252):**
```r
# Existing handler collapses the panel:
# Shiny.addCustomMessageHandler('collapse_panel', function(id) {
#   var el = document.getElementById(id);
#   if (el && el.classList.contains('show')) {
#     var bsCollapse = bootstrap.Collapse.getInstance(el);
#     if (bsCollapse) { bsCollapse.hide(); } else { new bootstrap.Collapse(el).hide(); }
#   }
# });

# New handler to expand:
# Shiny.addCustomMessageHandler('expand_panel', function(id) {
#   var el = document.getElementById(id);
#   if (el && !el.classList.contains('show')) {
#     bootstrap.Collapse.getOrCreateInstance(el).show();
#   }
# });
```

### Pattern 6: Retry Logic

**What:** On JSON extraction failure, retry once silently. After 2 failures, show error toast.

```r
# In server observer for ai_generate button:
attempt_generate <- function(description, api_key, model, attempt_num = 1) {
  result <- tryCatch(
    generate_theme_from_description(api_key, model, description),
    error = function(e) list(content = NULL, usage = NULL, error = e$message)
  )
  if (is.null(result$content)) {
    if (attempt_num < 2) return(attempt_generate(description, api_key, model, 2))
    return(list(theme = NULL, error = "Couldn't generate theme. Try a more specific description."))
  }

  json <- extract_theme_json(result$content)
  if (is.null(json)) {
    if (attempt_num < 2) return(attempt_generate(description, api_key, model, 2))
    return(list(theme = NULL, error = "Couldn't generate theme. Try a more specific description."))
  }

  list(theme = json, usage = result$usage, error = NULL)
}
```

### Pattern 7: Cost Tracking Integration

**What:** Log the AI generation call to the cost_log table using existing `log_cost()` infrastructure.

**From cost_tracking.R:**
```r
# After successful or failed LLM call that returned usage data:
if (!is.null(result$usage)) {
  cost <- estimate_cost(model,
                        prompt_tokens = result$usage$prompt_tokens,
                        completion_tokens = result$usage$completion_tokens)
  log_cost(con(),
           operation = "theme_generation",
           model = model,
           prompt_tokens = result$usage$prompt_tokens,
           completion_tokens = result$usage$completion_tokens,
           estimated_cost = cost,
           session_id = session$token)
}
```

Note: `"theme_generation"` is a new operation key. It will display with a generic label via `get_cost_operation_meta()` fallback — acceptable per CONTEXT.md ("not shown inline"). Optionally add to `COST_OPERATION_META` in cost_tracking.R for a clean label.

### Pattern 8: Color Picker Population (from Phase 60)

**What:** Populate all 4 hex text inputs and the color swatches with AI-returned values.

**From mod_slides.R lines 646-656:**
```r
updateTextInput(session, "bg_hex",     value = bg)
updateTextInput(session, "text_hex",   value = fg)
updateTextInput(session, "accent_hex", value = acc)
updateTextInput(session, "link_hex",   value = lnk)
updateSelectInput(session, "font",     selected = fnt)

session$sendCustomMessage("update_color_swatch", list(
  ids    = list(ns("bg_swatch"), ns("text_swatch"), ns("accent_swatch"), ns("link_swatch")),
  values = list(tolower(bg), tolower(fg), tolower(acc), tolower(lnk))
))
```

The mapping from LLM JSON fields to picker inputs:
- `backgroundColor` → `bg_hex` + `bg_swatch`
- `mainColor` → `text_hex` + `text_swatch`
- `accentColor` → `accent_hex` + `accent_swatch`
- `linkColor` → `link_hex` + `link_swatch`
- `mainFont` → `font` (selectInput)

### Anti-Patterns to Avoid

- **Shiny inputs inside Bootstrap 5 popover DOM:** Inputs rendered via `data-bs-content` HTML are not part of the Shiny DOM tree. Use a Bootstrap collapse block within the modal UI function instead, or use `Shiny.setInputValue()` explicitly for any button inside a true popover.
- **Using `display:none` to hide the AI Generate popover/form:** Phase 60 decision log explicitly warns against this. Use Bootstrap collapse (`class="collapse"`) instead.
- **Calling `useShinyjs()`:** Not present in app.R — all JS-driven state changes use `session$sendCustomMessage()`. Phase 60 decision log is explicit on this.
- **Rejecting the whole theme for a bad font:** CONTEXT.md decision: font validation uses fallback, not rejection. Only hex colors trigger a full rejection.
- **Showing retry count to users:** Users don't need to know about internal retries. The error message is the same regardless of whether it's the first or second failure.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LLM API call | Custom HTTP request | `chat_completion()` in api_openrouter.R | Already handles auth, timeout (120s), error extraction, usage parsing |
| Message formatting | Manual list construction | `format_chat_messages(system_prompt, user_message)` | Standard pattern used across all AI features |
| Cost logging | Custom DB insert | `log_cost()` + `estimate_cost()` in cost_tracking.R | Handles UUID generation, token accounting, session grouping |
| SCSS file writing | String concatenation to file | `generate_custom_scss()` in themes.R | Handles filename sanitization, font quoting, section markers, overwrite |
| Font list | Hardcoded strings in prompt | `CURATED_FONTS` from themes.R | Single source of truth; already used in font selector UI |
| Panel expansion/collapse | Raw JS manipulation | `session$sendCustomMessage("expand_panel", ...)` + existing handler pattern | Phase 60 established this pattern; consistent with existing collapse handler |
| Color swatch updates | Direct DOM manipulation | `session$sendCustomMessage("update_color_swatch", ...)` | Phase 60 custom message handler already registered in the modal DOM |

**Key insight:** Phase 61 has essentially zero new infrastructure to build. The entire phase is wiring existing components together with new glue code.

---

## Common Pitfalls

### Pitfall 1: Shiny Inputs in Bootstrap Popover DOM
**What goes wrong:** If the Generate button and textarea are rendered as Bootstrap 5 popover `data-bs-content`, they exist outside Shiny's reactive DOM. Clicking the Generate button won't trigger `observeEvent(input$ai_generate_btn, ...)`.
**Why it happens:** Bootstrap 5 popovers inject content into a `.popover` element appended to `<body>`, not within the Shiny module's namespace.
**How to avoid:** Use a Bootstrap collapse block (`class="collapse"`) rendered within the `mod_slides_modal_ui()` function instead of a true popover. The UI-SPEC explicitly permits this: "The exact mechanism (popover vs. collapse block) is executor discretion."
**Warning signs:** Generate button click does nothing; no reactive observation fires.

### Pitfall 2: Missing `\n` in JSON Fence Regex
**What goes wrong:** LLM sometimes returns ` ```json\n{...}\n``` ` with different whitespace (no newline after opening fence, trailing whitespace). Regex fails to match.
**Why it happens:** LLM output is non-deterministic; whitespace handling varies.
**How to avoid:** Use `perl = TRUE` with `(?s)` dotall flag or `\\s*` instead of `\\n` at fence boundaries. Test the regex against multiple LLM output formats.
**Warning signs:** `extract_theme_json()` returns NULL even though response looks valid.

### Pitfall 3: LLM Returns 3/4-Digit Hex or Named Colors
**What goes wrong:** LLM returns `#FFF`, `#FFFFFF00` (8-digit), or `"white"` instead of a 6-digit hex.
**Why it happens:** LLM doesn't strictly follow format instructions despite the system prompt.
**How to avoid:** Validation regex `^#[0-9A-Fa-f]{6}$` rejects these correctly. The retry logic handles it — the retry prompt can be the same original description (no need for special error-corrective prompt).
**Warning signs:** Validation flags all 4 hex fields as invalid after retry.

### Pitfall 4: Font Name with Extra Whitespace or Different Case
**What goes wrong:** LLM returns `"source sans pro"` or `" Source Sans Pro "` which fails the CURATED_FONTS membership check.
**Why it happens:** LLM case normalization varies.
**How to avoid:** Apply `trimws()` to the font name before CURATED_FONTS lookup. Consider case-insensitive matching as an extra guard (though the system prompt provides exact names, LLM should respect them).
**Warning signs:** Valid fonts always triggering the fallback warning.

### Pitfall 5: Regenerate Button State Not Reset After Save
**What goes wrong:** After saving a theme, the Regenerate button remains visible in the customize panel even though there's no longer an AI-generated state to regenerate from.
**Why it happens:** `uiOutput(ns("regenerate_btn_area"))` renders the button based on a reactiveVal tracking whether AI generation has occurred. If the reactiveVal isn't reset on save, the button persists.
**How to avoid:** Reset the AI generation state reactiveVal in the `observeEvent(input$save_custom_theme, ...)` handler. The Regenerate button visibility is controlled by a `reactiveVal(FALSE)` set to `TRUE` after generation, `FALSE` after save.
**Warning signs:** Regenerate button appears even on fresh modal opens after a save.

### Pitfall 6: DOMContentLoaded Guard for Modal-Rendered Elements
**What goes wrong:** JS event listeners for the spinner pattern or panel expansion fail because the modal DOM hasn't rendered yet when the script runs.
**Why it happens:** `tags$script()` in `modalDialog()` content runs before the modal is fully inserted into the DOM on some browsers.
**How to avoid:** Wrap JS listeners in `document.addEventListener('DOMContentLoaded', ...)` — this is the Phase 60 established pattern (mod_slides.R lines 31-66). For custom message handlers added to the collapse div (which run at handler registration, not at DOM time), no guard is needed.
**Warning signs:** JS errors in browser console about `null` element references.

---

## Code Examples

Verified from project source:

### Existing LLM Call Pattern (api_openrouter.R)
```r
# Source: R/api_openrouter.R lines 37-63
result <- chat_completion(
  api_key  = api_key,
  model    = model,
  messages = format_chat_messages(system_prompt, user_message)
)
# result$content — the LLM response text
# result$usage$prompt_tokens, result$usage$completion_tokens
# result$model, result$id
```

### Existing Color Picker Population Pattern (mod_slides.R)
```r
# Source: R/mod_slides.R lines 646-656
updateTextInput(session, "bg_hex",     value = bg)
updateTextInput(session, "text_hex",   value = fg)
updateTextInput(session, "accent_hex", value = acc)
updateTextInput(session, "link_hex",   value = lnk)
updateSelectInput(session, "font",     selected = fnt)
session$sendCustomMessage("update_color_swatch", list(
  ids    = list(ns("bg_swatch"), ns("text_swatch"), ns("accent_swatch"), ns("link_swatch")),
  values = list(tolower(bg), tolower(fg), tolower(acc), tolower(lnk))
))
```

### Existing Cost Tracking Pattern (cost_tracking.R)
```r
# Source: R/cost_tracking.R lines 167-191
log_cost(
  con              = con(),
  operation        = "slide_generation",  # replace with "theme_generation"
  model            = model,
  prompt_tokens    = result$usage$prompt_tokens,
  completion_tokens = result$usage$completion_tokens,
  estimated_cost   = estimate_cost(model,
                                    result$usage$prompt_tokens,
                                    result$usage$completion_tokens),
  session_id       = session$token
)
```

### Existing Panel Collapse (mod_slides.R) — Basis for Expand Handler
```r
# Source: R/mod_slides.R lines 248-252 (existing collapse handler)
# Shiny.addCustomMessageHandler('collapse_panel', function(id) {
#   var el = document.getElementById(id);
#   if (el && el.classList.contains('show')) {
#     var bsCollapse = bootstrap.Collapse.getInstance(el);
#     if (bsCollapse) { bsCollapse.hide(); } else { new bootstrap.Collapse(el).hide(); }
#   }
# });

# New expand handler (add alongside existing):
# Shiny.addCustomMessageHandler('expand_panel', function(id) {
#   var el = document.getElementById(id);
#   if (el && !el.classList.contains('show')) {
#     bootstrap.Collapse.getOrCreateInstance(el).show();
#   }
# });
```

### CURATED_FONTS Structure (themes.R)
```r
# Source: R/themes.R lines 11-15
CURATED_FONTS <- list(
  "Sans-serif" = c("Source Sans Pro", "Lato", "Fira Sans", "Roboto", "Open Sans"),
  "Serif"      = c("Merriweather", "PT Serif", "Roboto Slab", "Playfair Display"),
  "Monospace"  = c("IBM Plex Mono", "Fira Code")
)
# All valid font values: unlist(CURATED_FONTS) — 11 fonts total
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `shinyjs` for JS panel operations | `session$sendCustomMessage()` | Phase 60 | No `useShinyjs()` in app; all JS ops go through custom message handlers |
| `display:none` for hidden inputs | Bootstrap collapse / `position:absolute; clip` | Phase 59/60 | `display:none` blocks programmatic `.click()` in browsers |
| `tags$label(for=...)` workaround | Standard for file inputs (still used) | Phase 59 | Upload trigger pattern; not relevant to this phase |

**Deprecated/outdated:**
- shinyjs: Not used in this app. Do not add `useShinyjs()` calls.

---

## Open Questions

1. **Bootstrap collapse vs. true popover for AI Generate input area**
   - What we know: The UI-SPEC approves either mechanism; true popovers cause Shiny input registration issues; collapse blocks work natively
   - What's unclear: Whether a collapsible inline form (visually "drops down" below the Upload link) matches the intent of the UX design
   - Recommendation: Use Bootstrap collapse block. It is simpler, reliable, and the UI-SPEC explicitly allows it. The executor can match the visual popover feel by styling the collapse content as a bordered card.

2. **`"theme_generation"` operation key in COST_OPERATION_META**
   - What we know: `get_cost_operation_meta()` falls back gracefully for unknown keys; CONTEXT.md says cost is tracked but not shown inline
   - What's unclear: Whether it's worth adding the key to `COST_OPERATION_META` in cost_tracking.R for a clean label in the session cost panel
   - Recommendation: Add `"theme_generation"` to `COST_OPERATION_META` as a minor housekeeping step in Plan 01. It costs one line and makes the cost panel readable.

3. **JSON field name: CONTEXT.md says 5 fields; REQUIREMENTS.md says "8-9 variables"**
   - What we know: CONTEXT.md (locked decision) explicitly enumerates exactly 5 fields: `backgroundColor, mainColor, accentColor, linkColor, mainFont`. This matches what `generate_custom_scss()` accepts.
   - What's unclear: REQUIREMENTS.md THME-06 says "8-9 variables" — this appears to be an older/broader estimate
   - Recommendation: Follow the CONTEXT.md locked decision (5 fields). THME-06 is satisfied by the 5-variable approach since `generate_custom_scss()` produces a valid complete .scss file from these 5 inputs.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat (R) |
| Config file | none — run via `testthat::test_dir("tests/testthat")` |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-themes.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-05 | Textarea description accepted and passed to LLM | unit (generate_theme_from_description) | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ Wave 0 |
| THME-06 | JSON extraction from ` ```json ``` ` fence produces 5 fields | unit (extract_theme_json) | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ Wave 0 |
| THME-07 | Hex validation rejects bad colors; font fallback uses Source Sans Pro | unit (validate_theme_colors, validate_and_fix_font) | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ Wave 0 |

Note: All new test functions go in the existing `tests/testthat/test-themes.R` file — not a new file.

### Sampling Rate
- **Per task commit:** `testthat::test_file('tests/testthat/test-themes.R')`
- **Per wave merge:** `testthat::test_dir('tests/testthat')`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Tests for `generate_theme_from_description()` — covers THME-05 (requires mocking `chat_completion()`)
- [ ] Tests for `extract_theme_json()` — covers THME-06 (pure function, no mocking needed)
- [ ] Tests for `validate_theme_colors()` — covers THME-07 hex validation (pure function)
- [ ] Tests for `validate_and_fix_font()` — covers THME-07 font validation (pure function)

Note: `generate_theme_from_description()` unit tests should mock `chat_completion()` to avoid live API calls. The extract/validate helpers are pure functions that require no mocking and are straightforward to test.

---

## Sources

### Primary (HIGH confidence)
- `R/themes.R` — CURATED_FONTS, generate_custom_scss(), parse_scss_colors_full(), validate_scss_file() — all functions read directly
- `R/mod_slides.R` — color_picker_pair(), customize panel UI, existing observer patterns, update_color_swatch message handler, collapse_panel handler, theme prefill pattern (lines 617-681)
- `R/api_openrouter.R` — chat_completion(), format_chat_messages(), OpenRouter call pattern
- `R/cost_tracking.R` — log_cost(), estimate_cost(), COST_OPERATION_META pattern
- `tests/testthat/test-themes.R` — existing test structure and patterns for themes.R
- `.planning/phases/61-ai-theme-generation/61-CONTEXT.md` — locked decisions, code context, reusable assets
- `.planning/phases/61-ai-theme-generation/61-UI-SPEC.md` — component inventory, interaction states, implementation constraints

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Phase 60 decision log confirming: no useShinyjs(), sendCustomMessage pattern, DOMContentLoaded guard requirement

### Tertiary (LOW confidence)
- None — all findings verified from project source

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from api_openrouter.R, themes.R, cost_tracking.R source
- Architecture: HIGH — all patterns lifted directly from existing working code in mod_slides.R
- Pitfalls: HIGH — most derived from explicit STATE.md decision log entries and UI-SPEC implementation constraints

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable — no external APIs or framework versions in flux)
