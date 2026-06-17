# Phase 59: Theme Swatches, Upload, and Management - Research

**Researched:** 2026-03-19
**Domain:** Shiny UI (selectizeInput with HTML rendering), R file I/O, SCSS parsing
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Swatch presentation**
- Three color dots (bg/fg/accent) next to each theme name in the dropdown
- Built-in theme swatches come from a hardcoded named list mapping theme name to 3 hex values — no runtime parsing of RevealJS .scss
- Custom (uploaded) themes also show swatch dots — parse `$backgroundColor`, `$mainColor`, `$linkColor` from the .scss's `scss:defaults` section at upload time

**Upload + persistence**
- Upload button lives directly below the theme dropdown in the slide generation modal — small "Upload custom theme (.scss)" link/button
- Uploaded .scss files are validated: must contain `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` section markers — reject with inline error message if missing
- Files saved to `data/themes/` — global, available across all notebooks
- Duplicate filenames overwrite silently (user is intentionally updating their theme)
- `data/themes/` directory created on first upload if it doesn't exist

**Theme management UI**
- Single unified dropdown with two groups: "Built-in" (no delete icon) and "Custom" (with × delete icon next to each)
- Clicking × deletes the theme file immediately — no confirmation dialog
- Deleted themes removed from disk and from the dropdown choices

**Base theme selector**
- One unified dropdown for both built-in and custom themes — selecting any theme sets it as the base for Phase 60's color pickers
- When a custom .scss is selected, it always layers on top of RevealJS "default" base: `theme: [default, custom.scss]`
- When a built-in theme is selected (no custom .scss), scalar syntax is used: `theme: moon` (unchanged behavior from Phase 58)

### Claude's Discretion
- Exact implementation of selectizeInput with HTML rendering for swatch dots (CSS approach)
- How to group built-in vs custom in the dropdown (optgroup, separator, etc.)
- How delete icon click is handled without selecting the theme (event propagation)
- Toast notification style after successful upload
- Whether to sort custom themes alphabetically or by upload date

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| THME-01 | User sees color swatches (bg/fg/accent) next to each built-in theme in the dropdown | selectizeInput `render` option with HTML; hardcoded swatch table |
| THME-02 | User can upload a custom `.scss` file as a slide theme | `fileInput` + server validation of section markers; `file.copy` to `data/themes/` |
| THME-03 | Uploaded themes stored in `data/themes/` and persist across sessions | `dir.create` + `file.copy`; reload list from disk on modal open |
| THME-04 | User can manage (list/delete) uploaded custom themes | Delete × buttons in dropdown via `selectizeInput` HTML rendering + server `observeEvent` |
| THME-09 | Base theme selector determines starting point for custom themes | Unified dropdown value wired to `options$theme` and `options$custom_scss` |
</phase_requirements>

## Summary

Phase 59 adds three UI capabilities on top of Phase 58's pipeline plumbing: color swatches in the theme dropdown, file upload and persistence for custom .scss themes, and a management UI (inline delete) for uploaded themes. All work happens in `R/mod_slides.R` and a new `R/themes.R` helper module — nothing in `R/slides.R` needs to change because the pipeline contract (`options$theme`, `options$custom_scss`) is already in place.

The core technical challenge is the theme dropdown: it must show (a) color swatch dots next to every option, (b) grouped sections for Built-in vs Custom, and (c) a × delete button on each Custom row that deletes the file without also selecting that theme. Shiny's `selectizeInput` with a JavaScript `render` callback is the idiomatic solution. The delete button uses `stopPropagation()` on the click event and sends a custom Shiny input value to the server.

File operations are straightforward R: `dir.create()`, `file.copy()`, `file.remove()`, and `list.files()`. SCSS color parsing uses regex on the `scss:defaults` block. The hardcoded swatch table for built-in RevealJS themes is a named list in R — no external tool required.

**Primary recommendation:** Use `selectizeInput` with a `render` JS callback for the HTML dropdown; use a named R list for built-in swatches; use regex-based SCSS parsing for custom theme swatch extraction at upload time; store all state in `generation_state$custom_scss` and reload the dropdown via `updateSelectizeInput` whenever the custom theme list changes.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | 1.x (project already uses) | `selectizeInput`, `fileInput`, `observeEvent`, `updateSelectizeInput` | Project foundation |
| bslib | 0.x (project already uses) | Bootstrap layout, `showNotification` | Project foundation |
| base R | N/A | `dir.create`, `file.copy`, `file.remove`, `list.files`, `readLines`, `grepl` | No extra dependencies needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tools (base) | N/A | `file_path_sans_ext` for display names | Already used in `slides.R` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| selectizeInput with JS render | Custom `htmlwidget` | selectizeInput render is sufficient; htmlwidget adds bundle complexity |
| Regex-based SCSS parsing | sass R package | sass package adds C dependency; regex on the `scss:defaults` block is reliable for the specific variables we parse |
| Inline delete via selectizeInput | Separate management panel | Unified dropdown is what the user decided; separate panel is deferred |

**Installation:** No new packages — all required functionality is in base R and existing project dependencies.

## Architecture Patterns

### Recommended Project Structure
```
R/
├── mod_slides.R     # Primary change site: new UI elements, server observers, reactive state
├── themes.R         # NEW: theme helper functions (swatch table, SCSS parsing, file ops)
├── slides.R         # NO CHANGES needed — pipeline contract already in place (Phase 58)
data/
└── themes/          # NEW: created on first upload; persists across sessions
tests/testthat/
└── test-themes.R    # NEW: unit tests for themes.R helpers
```

### Pattern 1: selectizeInput with HTML Render Callback (Swatch Dots)

**What:** `selectizeInput` accepts a `options` list containing a JavaScript `render` object with an `option` function. The function receives the item data and returns an HTML string. Color dots are `<span>` elements with `background-color` set inline.

**When to use:** When dropdown options must contain arbitrary HTML — color swatches, icons, grouped entries with action buttons.

**Key constraint:** The `choices` for `selectizeInput` must be a named character vector where names are labels and values are the option values. To pass extra data (swatch colors, whether deletable), pass a `data.frame` as `choices` with additional columns — selectize will make those columns available as `item.colname` in the JS render callback.

**Example pattern (server-side):**
```r
# Source: Shiny docs — selectizeInput options$render
# Build choices data frame with extra columns for JS render
theme_choices_df <- data.frame(
  value = c("default", "moon", "custom-theme.scss"),
  label = c("Default", "Moon", "custom-theme"),
  bg    = c("#FFFFFF", "#002b36", "#F0F4F5"),
  fg    = c("#000000", "#93a1a1", "#212529"),
  accent = c("#157efb", "#268bd2", "#0D5C63"),
  group  = c("builtin", "builtin", "custom"),
  stringsAsFactors = FALSE
)

selectizeInput(
  ns("theme"),
  "Theme",
  choices = NULL,  # populated via updateSelectizeInput
  options = list(
    render = I('{
      option: function(item, escape) {
        var dots = \'<span style="display:inline-flex;gap:3px;margin-right:6px;">\' +
          \'<span style="width:10px;height:10px;border-radius:50%;background:\' + item.bg + \'"></span>\' +
          \'<span style="width:10px;height:10px;border-radius:50%;background:\' + item.fg + \'"></span>\' +
          \'<span style="width:10px;height:10px;border-radius:50%;background:\' + item.accent + \'"></span>\' +
          \'</span>\';
        var del = item.group === "custom"
          ? \'<span class="theme-delete-btn" data-value="\' + escape(item.value) + \'" style="margin-left:auto;cursor:pointer;color:#dc3545;" onclick="event.stopPropagation();Shiny.setInputValue(\\\'theme_delete\\\', item.value, {priority:\'event\'})">×</span>\'
          : \'\';
        return \'<div style="display:flex;align-items:center;">\' + dots + escape(item.label) + del + \'</div>\';
      }
    }')
  )
)
```

**Important:** Pass `I()` to prevent Shiny from JSON-encoding the JS string. The delete button calls `Shiny.setInputValue` with `priority: 'event'` to ensure repeated clicks on the same theme still fire.

### Pattern 2: Passing Data Frame Choices to selectizeInput

Shiny's `selectizeInput` accepts a data.frame for `choices` when using server-side mode. Each column becomes a property accessible in the JS render callback.

```r
# Server side — populate with full data frame
updateSelectizeInput(
  session,
  "theme",
  choices = theme_choices_df,   # data frame with value, label, bg, fg, accent, group cols
  selected = current_theme,
  server = TRUE
)
```

**Confirmed behavior (HIGH confidence):** `server = TRUE` sends choices to the client lazily, which also enables the data frame column passthrough used by the render callback.

### Pattern 3: Reactive Theme List with Disk Reload

```r
# Reactive that reads disk state — invalidated after upload or delete
custom_themes_list <- reactiveVal(list_custom_themes())  # initial load

# After upload:
custom_themes_list(list_custom_themes())  # reload from disk
updateSelectizeInput(session, "theme", choices = build_theme_choices_df(custom_themes_list()))

# After delete:
file.remove(file.path("data/themes", theme_filename))
custom_themes_list(list_custom_themes())
updateSelectizeInput(session, "theme", choices = build_theme_choices_df(custom_themes_list()))
```

### Pattern 4: SCSS Color Parsing at Upload Time

Parse `$backgroundColor` / `$body-bg`, `$mainColor` / `$body-color`, and `$linkColor` / `$link-color` from the `scss:defaults` block using regex. Fall back to neutral grays if variables are not found.

```r
# Source: Inspection of epa-owm.scss fixture and Quarto RevealJS SCSS variable names
parse_scss_swatches <- function(scss_text) {
  defaults_block <- regmatches(
    scss_text,
    regexpr("(?s)/\\*-- scss:defaults --\\*/(.*?)(/\\*--|$)", scss_text, perl = TRUE)
  )
  if (length(defaults_block) == 0) return(list(bg = "#FFFFFF", fg = "#000000", accent = "#157efb"))

  extract_hex <- function(block, patterns) {
    for (pat in patterns) {
      m <- regmatches(block, regexpr(paste0(pat, "\\s*:\\s*(#[0-9A-Fa-f]{3,6})"), block, perl = TRUE))
      if (length(m) > 0 && nchar(m) > 0) {
        return(sub(paste0(".*:\\s*"), "", m))
      }
    }
    NULL
  }

  bg     <- extract_hex(defaults_block, c("\\$body-bg", "\\$backgroundColor")) %||% "#FFFFFF"
  fg     <- extract_hex(defaults_block, c("\\$body-color", "\\$mainColor"))    %||% "#000000"
  accent <- extract_hex(defaults_block, c("\\$link-color", "\\$linkColor",
                                           "\\$presentation-heading-color"))   %||% "#157efb"
  list(bg = bg, fg = fg, accent = accent)
}
```

**Note on epa-owm.scss variables:** The fixture uses `$body-bg`, `$body-color`, `$link-color`, `$presentation-heading-color` — all Quarto RevealJS convention. The CONTEXT.md mentions `$backgroundColor`, `$mainColor`, `$linkColor` which are older Reveal.js variable names. Parse both patterns.

### Pattern 5: fileInput Server Handler

```r
observeEvent(input$upload_scss, {
  req(input$upload_scss)
  tmp_path <- input$upload_scss$datapath
  orig_name <- input$upload_scss$name

  # Validate extension
  if (!grepl("\\.scss$", orig_name, ignore.case = TRUE)) {
    # Show inline error
    return()
  }

  # Read and validate content
  scss_text <- paste(readLines(tmp_path, warn = FALSE), collapse = "\n")
  if (!grepl("/\\*-- scss:defaults --\\*/", scss_text) ||
      !grepl("/\\*-- scss:rules --\\*/", scss_text)) {
    # Show inline error
    return()
  }

  # Ensure directory exists
  dir.create("data/themes", recursive = TRUE, showWarnings = FALSE)

  # Save (overwrite on duplicate filename)
  dest <- file.path("data/themes", orig_name)
  file.copy(tmp_path, dest, overwrite = TRUE)

  # Parse swatches from uploaded file
  swatches <- parse_scss_swatches(scss_text)
  # ... store swatches, update dropdown
})
```

### Anti-Patterns to Avoid

- **Using `selectInput` for swatch dropdown:** `selectInput` does not support HTML in options. Must use `selectizeInput` with a render callback.
- **Parsing SCSS at render time on every slide generation:** Parse swatches once at upload time; cache in a sidecar metadata structure (named list in memory, or a JSON file at `data/themes/metadata.json`).
- **Absolute paths in YAML frontmatter:** Phase 58 already enforces `basename(custom_scss)` — do not change this behavior.
- **Selecting the theme when the delete × is clicked:** Use `event.stopPropagation()` and `Shiny.setInputValue` for the delete, not a normal button click inside the option HTML.
- **Hardcoding `data/themes/` relative to working directory without dir.create:** The directory won't exist on a fresh install; always call `dir.create(..., recursive = TRUE, showWarnings = FALSE)` before any write.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SCSS compilation/rendering | Custom SCSS parser | Regex on raw text (for variable extraction only) | We only need 3 color hex values — full parsing is not required |
| Option grouping in selectize | Custom accordion or modal | selectize `optgroupField` + `optgroups` option | selectize has native optgroup support — use it for Built-in vs Custom separation |
| File deduplication | Hash-based comparison | Overwrite-by-filename (user's explicit decision) | Simpler and matches the stated intent |
| Theme persistence across restarts | Database table | `list.files("data/themes/")` | Directory IS the persistence layer; no schema needed |

**Key insight:** The SCSS file system IS the persistent store. On modal open, scan `data/themes/` with `list.files()`. No DuckDB tables, no config files, no additional state layer needed for the theme list.

## Common Pitfalls

### Pitfall 1: Shiny Input Namespace in JS Render Callback

**What goes wrong:** The JS render callback uses `Shiny.setInputValue('theme_delete', ...)` with a bare input name. Inside a Shiny module, input names are namespaced. The callback must use the namespaced name.

**Why it happens:** The render callback is a JavaScript string — it runs in the browser where R's `ns()` function is not available. The namespace prefix must be baked into the string at render time.

**How to avoid:** Inject the namespace prefix into the JS string when building the selectizeInput options:

```r
ns_prefix <- session$ns("")  # e.g., "slides-"
# Then embed ns_prefix in the JS string for Shiny.setInputValue
```

**Warning signs:** Delete × is clicked but no server-side `observeEvent(input$theme_delete, ...)` fires.

### Pitfall 2: selectizeInput Data Frame Choices Column Names

**What goes wrong:** selectize's JS render callback references item properties by exact column name from the data frame. If the R data frame uses `bg_color` but the JS references `item.bg`, nothing renders.

**How to avoid:** Keep column names short and exactly matching the JS property references. Define both in one place (the `build_theme_choices_df()` helper).

### Pitfall 3: fileInput Provides Temporary Path, Not Original Path

**What goes wrong:** `input$upload_scss$datapath` is a temp path that Shiny will clean up. The original filename is in `input$upload_scss$name`. If you copy the file using `datapath` as the destination name, you lose the user's filename.

**How to avoid:** Always use `input$upload_scss$name` for the destination filename and `input$upload_scss$datapath` as the source.

### Pitfall 4: Custom Theme Swatch Metadata Survival

**What goes wrong:** If swatches are only parsed at upload time and stored in a Shiny `reactiveVal`, they are lost on app restart. On next launch, `data/themes/` has the files but no swatch data.

**How to avoid:** Parse swatches at upload time AND also parse them lazily when `list_custom_themes()` is called at modal open time. This means `list_custom_themes()` reads each `.scss` file and extracts colors — the directory scan always re-parses. Given typical theme file sizes (< 5KB), this is fast enough.

**Alternative:** Store swatch metadata in a JSON sidecar (`data/themes/metadata.json`). This trades file I/O for simplicity. Given the small number of themes expected, re-parsing on load is simpler.

### Pitfall 5: updateSelectizeInput Timing

**What goes wrong:** `updateSelectizeInput` called in `observeEvent(trigger(), ...)` before the modal has rendered — the select element doesn't exist in the DOM yet.

**How to avoid:** Call `showModal(...)` first, then `updateSelectizeInput(...)` in the same observer. Shiny defers UI updates until after the current reactive flush, so the modal will be in the DOM when the update arrives.

### Pitfall 6: Delete Button Inside selectize Option Needs stopPropagation

**What goes wrong:** Clicking the × delete button inside a selectize option also selects that option, changing `input$theme`. Server logic then tries to load a deleted theme.

**How to avoid:** The JS render callback's delete button must call `event.stopPropagation()` (or `event.preventDefault()`) before calling `Shiny.setInputValue`. The `onclick` handler on the `<span>` element must explicitly stop propagation.

## Code Examples

Verified patterns from project codebase and Shiny docs:

### Built-in Theme Swatch Table
```r
# R/themes.R — hardcoded, no SCSS parsing needed
BUILTIN_THEME_SWATCHES <- list(
  "default"   = list(bg = "#FFFFFF", fg = "#000000", accent = "#157efb"),
  "beige"     = list(bg = "#F7F3DE", fg = "#333333", accent = "#8B743D"),
  "blood"     = list(bg = "#160a0a", fg = "#EEEEE2", accent = "#A23"),
  "dark"      = list(bg = "#111111", fg = "#EEEEE2", accent = "#E7AD52"),
  "league"    = list(bg = "#1C1E20", fg = "#EEEEE2", accent = "#F0DB4F"),
  "moon"      = list(bg = "#002b36", fg = "#93a1a1", accent = "#268bd2"),
  "night"     = list(bg = "#1C1E20", fg = "#EEEEE2", accent = "#F28705"),
  "serif"     = list(bg = "#F0F1EB", fg = "#333333", accent = "#51483D"),
  "simple"    = list(bg = "#FFFFFF", fg = "#000000", accent = "#007CAD"),
  "sky"       = list(bg = "#F2F6F9", fg = "#333333", accent = "#3B759E"),
  "solarized" = list(bg = "#FDF6E3", fg = "#333333", accent = "#259286")
)
```

**Note:** These values are approximate — the planner should verify against official Reveal.js theme CSS. They are reasonable defaults for swatch display.

### list_custom_themes() with Swatch Parsing
```r
# R/themes.R
list_custom_themes <- function(themes_dir = "data/themes") {
  if (!dir.exists(themes_dir)) return(list())
  scss_files <- list.files(themes_dir, pattern = "\\.scss$", full.names = TRUE)
  if (length(scss_files) == 0) return(list())

  lapply(scss_files, function(path) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    swatches <- parse_scss_swatches(text)
    list(
      filename = basename(path),
      path = path,
      label = tools::file_path_sans_ext(basename(path)),
      bg = swatches$bg,
      fg = swatches$fg,
      accent = swatches$accent
    )
  })
}
```

### build_theme_choices_df() — Unified Dropdown Data
```r
# R/themes.R
build_theme_choices_df <- function(custom_themes = list()) {
  # Built-in rows
  builtin_rows <- lapply(names(BUILTIN_THEME_SWATCHES), function(name) {
    sw <- BUILTIN_THEME_SWATCHES[[name]]
    data.frame(
      value  = name,
      label  = paste0(toupper(substr(name, 1, 1)), substr(name, 2, nchar(name))),
      bg     = sw$bg,
      fg     = sw$fg,
      accent = sw$accent,
      group  = "builtin",
      stringsAsFactors = FALSE
    )
  })

  # Custom rows
  custom_rows <- lapply(custom_themes, function(ct) {
    data.frame(
      value  = ct$path,   # full path — server uses this as custom_scss
      label  = ct$label,
      bg     = ct$bg,
      fg     = ct$fg,
      accent = ct$accent,
      group  = "custom",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, c(builtin_rows, custom_rows))
}
```

### Wiring: options$theme and options$custom_scss from Unified Dropdown

When assembling `generation_state$last_options`, check whether the selected theme value is a built-in name or a file path:

```r
selected_theme <- input$theme
if (selected_theme %in% names(BUILTIN_THEME_SWATCHES)) {
  # Built-in theme
  generation_state$last_options <- list(
    ...,
    theme = selected_theme,
    custom_scss = NULL
  )
} else {
  # Custom theme — value is the full file path
  generation_state$last_options <- list(
    ...,
    theme = "default",   # base for array syntax: theme: [default, custom.scss]
    custom_scss = selected_theme
  )
}
```

This preserves the Phase 58 contract exactly — `build_qmd_frontmatter(title, theme, custom_scss)` works unchanged.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `selectInput` with plain text choices | `selectizeInput` with JS render callback for HTML | Shiny 1.0+ — always supported | Enables swatch dots and delete buttons without a custom widget |
| LLM-generated YAML with theme path | Programmatic YAML with `basename(custom_scss)` | v7.0 decision, Phase 58 implementation | Safe from path injection; relative path resolves from tempdir |

**Deprecated/outdated:**
- Reveal.js variable names `$backgroundColor`, `$mainColor`, `$linkColor`: These are older Reveal.js variables. Quarto's built-in themes use `$body-bg`, `$body-color`, `$link-color`. Parse both for compatibility.

## Open Questions

1. **Exact built-in theme swatch colors**
   - What we know: Approximate hex values for all 11 RevealJS themes can be estimated from their CSS
   - What's unclear: Whether the planner wants to invest time verifying exact colors from the Reveal.js source
   - Recommendation: Use reasonable approximations for now — swatch dots convey relative tone (dark/light/accent), not exact reproduction. Exact verification is optional for this phase.

2. **optgroupField vs separator for Built-in/Custom grouping**
   - What we know: selectize supports `optgroupField`, `optgroups`, and `labelField` for native group headers
   - What's unclear: Whether a static label "Custom" is sufficient or whether the group should be hidden when empty
   - Recommendation: Use selectize's native `optgroupField` — it handles empty groups gracefully (hides the header automatically).

3. **Swatch metadata persistence across restarts (re-parse vs sidecar JSON)**
   - What we know: Re-parsing on modal open is simple; sidecar JSON is faster but adds a second file to manage
   - Recommendation: Re-parse from disk on modal open. With < 20 themes and < 5KB per file, this is negligible. Avoids metadata/file drift.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | none (tests/testthat/ directory convention) |
| Quick run command | `testthat::test_file("tests/testthat/test-themes.R")` |
| Full suite command | `testthat::test_dir("tests/testthat")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| THME-01 | Built-in swatch table has correct keys; `build_theme_choices_df()` produces rows with bg/fg/accent | unit | `testthat::test_file("tests/testthat/test-themes.R")` | ❌ Wave 0 |
| THME-02 | `parse_scss_swatches()` extracts colors from valid SCSS; validates section markers | unit | `testthat::test_file("tests/testthat/test-themes.R")` | ❌ Wave 0 |
| THME-03 | `list_custom_themes()` returns files from `data/themes/`; survives empty dir | unit | `testthat::test_file("tests/testthat/test-themes.R")` | ❌ Wave 0 |
| THME-04 | Delete path removes file and file no longer appears in `list_custom_themes()` | unit | `testthat::test_file("tests/testthat/test-themes.R")` | ❌ Wave 0 |
| THME-09 | `build_theme_choices_df()` assigns correct `group` column; built-in uses theme name as value, custom uses file path | unit | `testthat::test_file("tests/testthat/test-themes.R")` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-themes.R")`
- **Per wave merge:** `testthat::test_dir("tests/testthat")`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-themes.R` — covers all 5 requirements above
- [ ] `R/themes.R` — helper module with `BUILTIN_THEME_SWATCHES`, `parse_scss_swatches()`, `list_custom_themes()`, `build_theme_choices_df()`

## Sources

### Primary (HIGH confidence)
- Project codebase — `R/mod_slides.R` lines 1-113 (current theme dropdown, modal structure)
- Project codebase — `R/slides.R` lines 129-173 (`build_qmd_frontmatter`, Phase 58 custom_scss implementation)
- Project codebase — `www/themes/epa-owm.scss` (real SCSS fixture showing variable naming patterns)
- Project codebase — `tests/testthat/test-slides.R` (existing test patterns to follow)
- `.planning/phases/58-theme-infrastructure/58-01-SUMMARY.md` (confirmed Phase 58 implementation details)

### Secondary (MEDIUM confidence)
- Shiny documentation — `selectizeInput` options.render for HTML option rendering
- Shiny documentation — `updateSelectizeInput` with data frame choices and `server = TRUE`
- Quarto RevealJS SCSS variable conventions — confirmed by epa-owm.scss using `$body-bg`, `$body-color`, `$link-color`

### Tertiary (LOW confidence)
- Built-in RevealJS theme hex color approximations — estimated from known Reveal.js color scheme descriptions; exact values require checking Reveal.js source CSS

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are existing project dependencies; no new packages
- Architecture patterns: HIGH — selectizeInput render callback is documented Shiny behavior; file I/O is base R
- Pitfalls: HIGH — namespace injection in JS, fileInput temp path, stopPropagation are well-known Shiny patterns documented in the ecosystem
- Built-in swatch colors: LOW — approximate values; planner may choose to verify or leave for UAT

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable APIs — selectizeInput, base R file ops)
