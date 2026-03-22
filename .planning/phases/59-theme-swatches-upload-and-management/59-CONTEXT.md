# Phase 59: Theme Swatches, Upload, and Management - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can see visual previews of built-in themes and upload, persist, and manage their own .scss theme files. This phase builds the theme selector UI and file management — it does NOT include color pickers (Phase 60) or AI generation (Phase 61).

</domain>

<decisions>
## Implementation Decisions

### Swatch presentation
- Three color dots (bg/fg/accent) next to each theme name in the dropdown
- Built-in theme swatches come from a hardcoded named list mapping theme name to 3 hex values — no runtime parsing of RevealJS .scss
- Custom (uploaded) themes also show swatch dots — parse `$backgroundColor`, `$mainColor`, `$linkColor` from the .scss's `scss:defaults` section at upload time

### Upload + persistence
- Upload button lives directly below the theme dropdown in the slide generation modal — small "Upload custom theme (.scss)" link/button
- Uploaded .scss files are validated: must contain `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` section markers — reject with inline error message if missing
- Files saved to `data/themes/` — global, available across all notebooks
- Duplicate filenames overwrite silently (user is intentionally updating their theme)
- `data/themes/` directory created on first upload if it doesn't exist

### Theme management UI
- Single unified dropdown with two groups: "Built-in" (no delete icon) and "Custom" (with × delete icon next to each)
- Clicking × deletes the theme file immediately — no confirmation dialog
- Deleted themes removed from disk and from the dropdown choices

### Base theme selector
- One unified dropdown for both built-in and custom themes — selecting any theme sets it as the base for Phase 60's color pickers
- When a custom .scss is selected, it always layers on top of RevealJS "default" base: `theme: [default, custom.scss]`
- When a built-in theme is selected (no custom .scss), scalar syntax is used: `theme: moon` (unchanged behavior from Phase 58)

### Claude's Discretion
- Exact implementation of selectizeInput with HTML rendering for swatch dots (CSS approach)
- How to group built-in vs custom in the dropdown (optgroup, separator, etc.)
- How delete icon click is handled without selecting the theme (event propagation)
- Toast notification style after successful upload
- Whether to sort custom themes alphabetically or by upload date

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Quarto theme documentation
- Quarto RevealJS themes: `theme: [default, custom.scss]` array syntax — https://quarto.org/docs/presentations/revealjs/themes.html
- Custom .scss must have `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` sections

### Phase 58 context (predecessor)
- `.planning/phases/58-theme-infrastructure/58-CONTEXT.md` — YAML array syntax contract, custom_scss parameter signature, pipeline threading decisions
- `.planning/phases/58-theme-infrastructure/58-01-SUMMARY.md` — What was actually implemented

### Requirements
- `.planning/REQUIREMENTS.md` — THME-01 (swatches), THME-02 (upload), THME-03 (persist), THME-04 (manage), THME-09 (base theme selector)

### Codebase files
- `R/mod_slides.R` — Lines 8-10: built-in theme list; Line 88-93: current `selectInput` for themes; Line 399: `custom_scss = NULL` in last_options (Phase 58 placeholder)
- `R/slides.R` — `build_qmd_frontmatter(title, theme, custom_scss)`: the function that emits YAML; `generate_slides()`: copies .scss to tempdir
- `www/themes/epa-owm.scss` — Test fixture with real scss:defaults + scss:rules sections (EPA OWM branded theme)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build_qmd_frontmatter(title, theme, custom_scss)` — already accepts custom_scss and emits array syntax (Phase 58)
- `generate_slides()` — already copies .scss to tempdir when custom_scss is provided
- `mod_slides.R` last_options — has `custom_scss = NULL` placeholder ready for wiring
- `www/themes/epa-owm.scss` — real custom theme file, usable for testing upload flow

### Established Patterns
- Slide generation modal uses `modalDialog()` with standard Shiny inputs (selectInput, checkboxInput, textAreaInput)
- Options passed as named list: `options$theme`, `options$custom_scss`, etc.
- Toast notifications via `showNotification()` for user feedback
- File-based storage for user data under `data/` directory (e.g., `data/ragnar/`)

### Integration Points
- `selectInput(ns("theme"), ...)` at line 88 — replace with selectizeInput or custom HTML rendering for swatch dots
- `options$custom_scss` in generation pipeline — wire from UI selection to this field
- `data/themes/` — new directory for persistent custom theme storage
- Healing path at line 622 — already threads `custom_scss` through (Phase 58)

</code_context>

<specifics>
## Specific Ideas

- Dropdown should feel like a native selectInput with color dots as visual enhancement, not a custom widget
- Built-in and custom themes are visually separated in the dropdown (groups/sections)
- The × delete button must not trigger theme selection when clicked — needs event propagation handling

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 59-theme-swatches-upload-and-management*
*Context gathered: 2026-03-19*
