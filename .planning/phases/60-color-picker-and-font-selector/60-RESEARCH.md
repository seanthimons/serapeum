# Phase 60: Color Picker and Font Selector - Research

**Researched:** 2026-03-20
**Domain:** R/Shiny UI — native HTML color inputs, Shiny reactive wiring, SCSS generation
**Confidence:** HIGH (all findings based on direct codebase inspection and established HTML/Shiny patterns)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Picker placement & layout**
- Collapsible "Customize colors & font" panel below the existing theme dropdown — collapsed by default
- Expanding the panel pre-fills pickers with the currently selected theme's colors (built-in or custom)
- Changing the theme dropdown while panel is expanded resets pickers to the new theme's colors
- Panel works for both built-in and custom themes — custom theme values are read from parsed .scss variables

**Color picker interaction**
- Each of the 4 colors (BG, Text, Accent, Link) uses a native HTML color input (clickable swatch) paired with an editable hex text field
- 2x2 grid layout: BG/Text on top row, Accent/Link on bottom row
- Hex validation on blur — invalid values get a red border (supports Phase 61's AI validation requirement)
- Live swatch update: as user changes picker values, the 3 swatch dots in the theme dropdown update to reflect customized colors

**Font selector design**
- ~10-12 curated, widely-available professional fonts (serif, sans-serif, monospace)
- Plain text dropdown with font names grouped by category — no font preview rendering
- Single font selector controlling $mainFont only (no separate heading font)
- Examples: Source Sans Pro, Lato, Merriwaether, Fira Sans, PT Serif, Roboto Slab, IBM Plex Mono

**Custom .scss generation**
- "Save as custom theme" button with inline text input for theme name
- Generates a minimal .scss file with 5 variables: $backgroundColor, $mainColor, $linkColor, $accentColor, $mainFont
- File saved to `data/themes/{name}.scss` with standard `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` sections
- Duplicate filenames overwrite silently (consistent with Phase 59 upload behavior)
- After save: new theme auto-selected in dropdown, panel collapses, swatch dots reflect saved colors

### Claude's Discretion
- Exact font list curation (which 10-12 fonts to include)
- How the collapsible panel animation/toggle works (bslib accordion, custom div toggle, etc.)
- How native color input and hex text field are synced (oninput vs onchange events)
- Toast notification after successful theme save
- How accent color maps to Quarto/RevealJS variables (may need scss:rules for accent usage)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-08 | User can manually customize theme via color pickers (bg/text/accent/link) and font selector | Native HTML color inputs + selectInput; reactive wiring to update swatch display; .scss write on save |
| THME-10 | AI-generated values populate color picker fields for manual tweaking | updateTextInput/updateSelectInput server calls; same picker fields exposed as reactive targets |
| THME-11 | Font selector offers curated list of widely-available professional fonts | selectInput with grouped choices; curated 10-12 font list |
</phase_requirements>

---

## Summary

Phase 60 adds a collapsible customization panel below the existing theme dropdown in the slides modal. The panel contains four color pickers (bg/text/accent/link) each implemented as a native HTML `<input type="color">` element paired with a hex text field, plus a font selector `selectInput`. The implementation is pure R/Shiny with no external JS libraries — `<input type="color">` is universally supported and already the cross-browser standard for color selection.

The core technical challenge is the two-way sync between the color picker and the hex text field, handled via JavaScript `oninput` events injected through `tags$script`. The other significant challenge is the swatch-dot live update: when the user changes picker values, the three dots in the selectizeInput must reflect the customized colors. This is done by calling `updateSelectizeInput` to refresh the dropdown choices with the new color values in the matching entry.

When the user saves, an R function generates a minimal 5-variable .scss file, writes it to `data/themes/`, calls `refresh_theme_dropdown()` (Phase 59 pattern), and auto-selects the new theme. Phase 61 will later populate these same picker fields reactively using the same server-side update mechanism — the picker inputs need no structural change to support that.

**Primary recommendation:** Use native HTML `<input type="color">` + `textInput` pairs wired via inline `oninput` JS. Panel toggling via a simple `shinyjs::toggle()` or manual `div` with a Bootstrap collapse. `generate_custom_scss()` writes a minimal 5-variable .scss file directly.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny (base) | 1.x (project-installed) | `textInput`, `selectInput`, `observeEvent`, `updateTextInput`, `updateSelectInput` | All picker wiring is pure Shiny reactive inputs |
| bslib | project-installed | `layout_columns()` for 2x2 grid layout | Already used in modal for layout_columns |
| shinyjs | project-installed | `toggle()` for panel show/hide | Already available; or use Bootstrap collapse without extra dep |
| htmltools / tags | base shiny | `tags$input(type="color")`, `tags$script()` | Native color input + inline JS sync |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| base R `writeLines` | base | Write generated .scss to disk | Used in Phase 59 upload pattern |
| base R `file.path` | base | Path construction for `data/themes/` | Consistent with existing pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native `<input type="color">` | colourpicker R package | colourpicker adds a JS dependency for no benefit; native input is zero-dep and cross-browser |
| `shinyjs::toggle()` | Bootstrap collapse via `data-bs-toggle` | Either works; shinyjs is already a project dep, Bootstrap collapse requires no server interaction |

**Installation:** No new packages needed. All required packages are already present in the project.

---

## Architecture Patterns

### Where New Code Lives
```
R/
├── themes.R           # Add: generate_custom_scss(), extend parse_scss_swatches for $accentColor/$mainFont
├── mod_slides.R       # Add: collapsible panel UI + server reactive logic
tests/testthat/
└── test-themes.R      # Add: tests for generate_custom_scss(), scss round-trip
```

### Pattern 1: Native Color Input + Hex Text Sync

The user decision mandates a native `<input type="color">` swatch paired with an editable hex text field. These need bidirectional sync via JS:

```r
# In mod_slides_modal_ui()
color_picker_pair <- function(ns, id, label) {
  div(
    class = "mb-2",
    tags$label(label, `for` = ns(paste0(id, "_hex")), class = "form-label small fw-semibold"),
    div(
      class = "d-flex align-items-center gap-2",
      tags$input(
        type = "color",
        id = ns(paste0(id, "_swatch")),
        value = "#FFFFFF",
        style = "width:40px;height:38px;padding:2px;border:1px solid #ced4da;border-radius:4px;cursor:pointer;"
      ),
      textInput(
        ns(paste0(id, "_hex")),
        NULL,
        value = "#FFFFFF",
        width = "100px",
        placeholder = "#RRGGBB"
      )
    ),
    # JS sync: color swatch -> hex field (oninput for live update)
    tags$script(HTML(sprintf(
      "document.getElementById('%s').addEventListener('input', function(e) {
         var el = document.getElementById('%s');
         if (el) { el.value = e.target.value.toUpperCase(); el.dispatchEvent(new Event('change')); }
       });",
      ns(paste0(id, "_swatch")),
      ns(paste0(id, "_hex"))
    )))
  )
}
```

**Note:** The hex text field (`textInput`) is a Shiny reactive input — its value is readable as `input$bg_hex`, `input$text_hex`, etc. The reverse sync (hex field -> color swatch) is done similarly via `oninput` on the text field.

### Pattern 2: Panel Pre-fill on Theme Change

When the theme dropdown changes, the collapsible panel must pre-fill from the selected theme's colors:

```r
# Server: observe theme selection changes
observeEvent(input$theme, {
  selected <- input$theme
  if (selected %in% names(BUILTIN_THEME_SWATCHES)) {
    sw <- BUILTIN_THEME_SWATCHES[[selected]]
    bg_hex <- sw$bg; fg_hex <- sw$fg; acc_hex <- sw$accent
    link_hex <- acc_hex  # fallback: same as accent for built-ins
  } else if (nzchar(selected)) {
    # Custom theme: parse .scss for all 4 variables
    path <- file.path("data/themes", selected)
    sw <- parse_scss_colors_full(path)
    bg_hex <- sw$bg; fg_hex <- sw$fg; acc_hex <- sw$accent; link_hex <- sw$link
  }
  updateTextInput(session, "bg_hex",   value = bg_hex)
  updateTextInput(session, "text_hex", value = fg_hex)
  updateTextInput(session, "accent_hex", value = acc_hex)
  updateTextInput(session, "link_hex",   value = link_hex)
  # Also update the native color swatches via JS session$sendCustomMessage or
  # synchronize via Shiny.setInputValue trigger
})
```

**Key insight for THME-10:** This same `updateTextInput` call path is the contract Phase 61 will use to populate AI-generated values. No structural change needed — Phase 61 just calls the same updates.

### Pattern 3: Live Swatch Dot Update in Dropdown

The selectizeInput swatch dots show the chosen theme's colors. When the user changes pickers, the dots must update to reflect customized values:

```r
# Approach: maintain a reactiveVal for "current custom colors" and
# call updateSelectizeInput() when values change — updating the row
# data for the currently selected theme.
# The selectizeInput render function already reads item$bg/item$fg/item$accent.
# So updating the choices df with new hex values for that row refreshes the dots.
observeEvent(c(input$bg_hex, input$text_hex, input$accent_hex), {
  # Rebuild choices df with overridden colors for current theme row
  refresh_theme_dropdown_with_override(session, input$theme,
    bg = input$bg_hex, fg = input$text_hex, accent = input$accent_hex)
})
```

### Pattern 4: .scss Generation

New helper function in `R/themes.R`:

```r
#' Generate a minimal custom theme .scss file
#' @param name Theme name (becomes filename, sanitized)
#' @param bg_color Background hex (#RRGGBB)
#' @param text_color Text hex (#RRGGBB)
#' @param accent_color Accent hex (#RRGGBB)
#' @param link_color Link hex (#RRGGBB)
#' @param font_name Font name string (e.g. "Lato")
#' @param themes_dir Directory to write to (default "data/themes")
#' @return Path to written file, or NULL on failure
generate_custom_scss <- function(name, bg_color, text_color, accent_color,
                                  link_color, font_name,
                                  themes_dir = "data/themes") {
  safe_name <- gsub("[^a-zA-Z0-9_-]", "-", name)
  fname <- paste0(safe_name, ".scss")
  fpath <- file.path(themes_dir, fname)
  dir.create(themes_dir, showWarnings = FALSE, recursive = TRUE)

  scss <- paste0(
    "/*-- scss:defaults --*/\n\n",
    "$backgroundColor: ", bg_color, ";\n",
    "$mainColor: ", text_color, ";\n",
    "$linkColor: ", link_color, ";\n",
    "$accentColor: ", accent_color, ";\n",
    "$mainFont: \"", font_name, "\", sans-serif;\n\n",
    "/*-- scss:rules --*/\n\n",
    "/* Generated by Serapeum theme customizer */\n"
  )

  tryCatch({
    writeLines(scss, fpath)
    fpath
  }, error = function(e) NULL)
}
```

**Note on $accentColor vs RevealJS variables:** RevealJS uses `$linkColor` (not `$accentColor`) as a primary accent variable. The generated .scss uses both — `$linkColor` controls links, `$accentColor` is available as a custom variable that scss:rules can reference. For Phase 61's accent usage, a scss:rules block may be added to wire `$accentColor` to heading colors.

### Pattern 5: SCSS Parsing Extension for 4 Colors + Font

The existing `parse_scss_swatches()` in `R/themes.R` returns 3 colors (bg/fg/accent). For the pre-fill use case, we need 4 colors + font. Options:

**Option A (recommended):** Create `parse_scss_colors_full()` that extends the existing pattern to also extract `$linkColor` and `$mainFont`. Keep existing `parse_scss_swatches()` unchanged (callers depend on its 3-field return).

**Option B:** Extend `parse_scss_swatches()` return to include link and font — requires updating all callers. More disruptive.

Use Option A.

### Pattern 6: Font Selector

```r
selectInput(
  ns("font"),
  "Font",
  choices = list(
    "Sans-serif" = c(
      "Source Sans Pro" = "Source Sans Pro",
      "Lato" = "Lato",
      "Fira Sans" = "Fira Sans",
      "Roboto" = "Roboto",
      "Open Sans" = "Open Sans"
    ),
    "Serif" = c(
      "Merriweather" = "Merriweather",
      "PT Serif" = "PT Serif",
      "Roboto Slab" = "Roboto Slab",
      "Playfair Display" = "Playfair Display"
    ),
    "Monospace" = c(
      "IBM Plex Mono" = "IBM Plex Mono",
      "Fira Code" = "Fira Code"
    )
  ),
  selected = "Source Sans Pro"
)
```

**Font availability note:** These fonts are widely available but not guaranteed on every OS. The generated SCSS should include a fallback stack (e.g., `"Lato", sans-serif`). RevealJS will load them from system fonts — if a user's Quarto install has Google Fonts integration enabled, they render from the web; otherwise they fall back gracefully.

### Anti-Patterns to Avoid

- **Do not use `colourpicker::colourInput()`:** adds a JS widget dependency and doesn't accept programmatic color values as cleanly as native inputs. Native `<input type="color">` is the locked decision.
- **Do not attempt to sync swatch to hex via Shiny reactive inputs alone:** Shiny doesn't observe `<input type="color">` changes unless registered. Use `tags$script` inline JS to bridge the native DOM event to the Shiny input value.
- **Do not add the native color input to `inputIds` directly:** Shiny doesn't know about raw `tags$input`. Only the paired `textInput` (via `input$bg_hex` etc.) carries the value server-side.
- **Do not render the collapsible panel inside the existing `layout_columns` grid:** Insert it as its own full-width div below the theme div block (lines 86-145 of mod_slides.R), before the speaker notes checkbox.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hex validation regex | Custom validator | `grepl("^#[0-9A-Fa-f]{6}$", val)` inline | One-liner; already used in themes.R |
| Theme file writing | Complex templating | `writeLines(paste0(...), fpath)` | 5-variable .scss is simple string concat |
| Panel toggle | jQuery-based accordion | `shinyjs::toggle()` or Bootstrap `data-bs-toggle="collapse"` | Both already available; no new code |
| SCSS parsing | Full SCSS parser | Regex on `/*-- scss:defaults --*/` block (existing `parse_scss_swatches` pattern) | Sufficient for Serapeum's minimal generated format |

**Key insight:** The generated .scss is deliberately minimal (5 variables). This means full SCSS parsing is never needed — only regex extraction of those exact 5 known variable names.

---

## Common Pitfalls

### Pitfall 1: Native Color Input Not Registering as Shiny Input
**What goes wrong:** `input$bg_swatch` is always NULL because Shiny doesn't auto-register raw `tags$input`.
**Why it happens:** Shiny only tracks inputs created with `shiny::*Input()` functions or registered via `shiny::registerInputHandler()`.
**How to avoid:** The native color input is purely a UI convenience. All server logic reads from the paired `textInput` (e.g., `input$bg_hex`). The JS sync keeps the text field in sync with the color swatch.
**Warning signs:** `input$bg_swatch` is NULL; `input$bg_hex` has the value.

### Pitfall 2: Hex Text -> Color Swatch Sync Requires JS
**What goes wrong:** User types in hex field but color swatch doesn't update.
**Why it happens:** The hex text field is a Shiny `textInput` rendered as `<input type="text">`. The native color input is a separate DOM element — no automatic binding.
**How to avoid:** Add a JS `oninput` listener on the text field that sets `document.getElementById(swatchId).value = hexValue`. Must sanitize input (ensure `#` prefix is present).
**Warning signs:** Picker and text field appear out of sync after typing.

### Pitfall 3: Updating Swatch Dots When Pickers Change
**What goes wrong:** The theme dropdown swatch dots still show the base theme colors while the user has customized values.
**Why it happens:** The selectizeInput renders from the choices df, which has the static base color values.
**How to avoid:** On picker change, call `updateSelectizeInput` to push a modified choices df where the active theme row has the new hex values. Only the currently selected theme row needs updating.
**Warning signs:** Swatch dots in dropdown show old colors; only visible when user re-opens dropdown.

### Pitfall 4: $accentColor vs RevealJS Variables
**What goes wrong:** `$accentColor` is not a standard RevealJS variable — setting it has no effect.
**Why it happens:** RevealJS built-in themes use `$linkColor` for link text. Custom variables like `$accentColor` are only used if referenced in scss:rules.
**How to avoid:** The generated .scss sets `$linkColor` (used by RevealJS natively) AND `$accentColor` (available for Phase 61 to use in scss:rules for headings, borders, etc.). The CONTEXT notes this as Claude's Discretion — add a minimal scss:rules block that wires `$accentColor` to heading colors.
**Warning signs:** Accent color appears to have no effect on rendered slides.

### Pitfall 5: Panel Pre-fill for Built-in Themes Only Has 3 Colors
**What goes wrong:** Pre-fill fires for built-in theme, but `$linkColor` and `$mainFont` aren't available in `BUILTIN_THEME_SWATCHES`.
**Why it happens:** `BUILTIN_THEME_SWATCHES` only has `bg/fg/accent` — no link or font.
**How to avoid:** For built-in themes, pre-fill link = accent (reasonable default), font = "Source Sans Pro" (the safe fallback). For custom themes, parse the .scss for all 5 fields.
**Warning signs:** Link color picker is blank or shows wrong color after theme change.

### Pitfall 6: Font Name with Spaces in SCSS
**What goes wrong:** `$mainFont: Source Sans Pro, sans-serif;` is invalid SCSS — unquoted font name with spaces.
**Why it happens:** SCSS requires quotes around font names containing spaces.
**How to avoid:** The `generate_custom_scss()` function must wrap `font_name` in double quotes: `"Source Sans Pro"`.
**Warning signs:** Quarto render error about invalid SCSS variable value.

---

## Code Examples

### Verified Pattern: Swatch Pre-fill from Built-in Theme
```r
# Source: R/themes.R - BUILTIN_THEME_SWATCHES (existing)
# Built-in themes have bg/fg/accent. For link, fall back to accent.
observeEvent(input$theme, {
  sel <- input$theme
  if (sel %in% names(BUILTIN_THEME_SWATCHES)) {
    sw <- BUILTIN_THEME_SWATCHES[[sel]]
    updateTextInput(session, "bg_hex",     value = sw$bg)
    updateTextInput(session, "text_hex",   value = sw$fg)
    updateTextInput(session, "accent_hex", value = sw$accent)
    updateTextInput(session, "link_hex",   value = sw$accent)  # fallback
    updateSelectInput(session, "font",     selected = "Source Sans Pro")
  }
})
```

### Verified Pattern: Saving Custom Theme and Refreshing Dropdown
```r
# Source: mod_slides.R Phase 59 - refresh_theme_dropdown() pattern
observeEvent(input$save_custom_theme, {
  name <- trimws(input$custom_theme_name)
  req(nzchar(name))

  path <- generate_custom_scss(
    name       = name,
    bg_color   = input$bg_hex,
    text_color = input$text_hex,
    accent_color = input$accent_hex,
    link_color = input$link_hex,
    font_name  = input$font
  )

  if (!is.null(path)) {
    refresh_theme_dropdown(selected = basename(path))  # Phase 59 helper
    showNotification(paste0("Theme '", name, "' saved"), type = "message")
    shinyjs::hide("customize_panel")
  }
})
```

### Verified Pattern: Minimal .scss Template
```scss
/*-- scss:defaults --*/

$backgroundColor: #FFFFFF;
$mainColor: #000000;
$linkColor: #157efb;
$accentColor: #157efb;
$mainFont: "Source Sans Pro", sans-serif;

/*-- scss:rules --*/

/* Generated by Serapeum theme customizer */
.reveal h1, .reveal h2, .reveal h3 {
  color: $accentColor;
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Full SCSS parsing via R package | Regex on known variables in scss:defaults block | Phase 59 | Sufficient for Serapeum's minimal format; avoids dep |
| R `colourpicker` package | Native HTML `<input type="color">` | Phase 60 decision | Zero deps, cross-browser, programmatically settable |
| Free-text font input | Curated dropdown (REQUIREMENTS.md Out of Scope) | Requirements doc | Prevents broken themes from unavailable fonts |

---

## Open Questions

1. **Accent color scss:rules block**
   - What we know: `$accentColor` is not a RevealJS variable; setting it in scss:defaults has no effect unless referenced in scss:rules.
   - What's unclear: Should the minimal template include scss:rules that wire `$accentColor` to heading colors?
   - Recommendation: Yes — add a minimal 3-line scss:rules block (`.reveal h1, .reveal h2, .reveal h3 { color: $accentColor; }`). This makes the accent picker meaningful. Left to Claude's Discretion per CONTEXT.md.

2. **Color swatch update event frequency**
   - What we know: The CONTEXT says "live swatch update as user changes picker values."
   - What's unclear: Update on every `oninput` event (every character) or on `onblur` (on field exit)?
   - Recommendation: Update the dropdown swatch dots `onblur`/on-save rather than live. Live updating would call `updateSelectizeInput` on every keypress, which could cause dropdown flicker. The color swatch native input can live-update its paired hex field, but the selectizeInput dots update on blur or save.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | `tests/testthat.R` (project standard) |
| Quick run command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-themes.R')"` |
| Full suite command | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-08 | `generate_custom_scss()` writes valid .scss with 5 variables | unit | `testthat::test_file('tests/testthat/test-themes.R')` | Wave 0 — add to test-themes.R |
| THME-08 | `generate_custom_scss()` sanitizes filename (removes special chars) | unit | `testthat::test_file('tests/testthat/test-themes.R')` | Wave 0 |
| THME-08 | `generate_custom_scss()` wraps font name in quotes in output | unit | `testthat::test_file('tests/testthat/test-themes.R')` | Wave 0 |
| THME-08 | `parse_scss_colors_full()` extracts all 4 colors + font | unit | `testthat::test_file('tests/testthat/test-themes.R')` | Wave 0 |
| THME-10 | Picker fields are `textInput`/`selectInput` — addressable by `updateTextInput` | design | manual | n/a |
| THME-11 | Font list contains >= 10 fonts across >= 2 categories | unit | `testthat::test_file('tests/testthat/test-themes.R')` | Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file('tests/testthat/test-themes.R')`
- **Per wave merge:** `testthat::test_dir('tests/testthat')`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] New test cases in `tests/testthat/test-themes.R` — covers THME-08 (generate_custom_scss), THME-11 (font list validation)
- [ ] New `parse_scss_colors_full()` in `R/themes.R` — needed before tests can be written

*(Existing test-themes.R covers parse_scss_swatches, validate_scss_file, list_custom_themes, build_theme_choices_df — all remain valid. Only new helper functions need new tests.)*

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — `R/themes.R`, `R/mod_slides.R`, `R/slides.R` (lines confirmed live)
- `data/themes/epa-owm.scss` — reference .scss for variable naming conventions
- `tests/testthat/test-themes.R` — existing test coverage confirmed
- `.planning/phases/60-color-picker-and-font-selector/60-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- Quarto RevealJS variable reference: `$backgroundColor`, `$mainColor`, `$linkColor`, `$mainFont` from https://quarto.org/docs/presentations/revealjs/themes.html (cited in CONTEXT.md canonical refs)
- Native HTML `<input type="color">` MDN spec: universally supported in all modern browsers, value attribute is always a valid hex string in `#RRGGBB` lowercase format

### Tertiary (LOW confidence)
- None — all findings have direct codebase or specification support

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already installed; no new deps
- Architecture: HIGH — patterns extrapolated directly from existing Phase 59 code in the same file
- Pitfalls: HIGH — derived from actual code inspection (BUILTIN_THEME_SWATCHES shape, RevealJS variable names from epa-owm.scss)

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable domain — R/Shiny patterns, HTML spec)
