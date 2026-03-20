# Phase 60: Color Picker and Font Selector - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can manually customize slide theme colors (background, text, accent, link) and select a font via pickers in the slide generation modal. These pickers are also the target for AI-populated values (Phase 61). Saving produces a named custom .scss theme file. This phase does NOT include AI generation (Phase 61) or prompt editing (Phase 62+).

</domain>

<decisions>
## Implementation Decisions

### Picker placement & layout
- Collapsible "Customize colors & font" panel below the existing theme dropdown — collapsed by default
- Expanding the panel pre-fills pickers with the currently selected theme's colors (built-in or custom)
- Changing the theme dropdown while panel is expanded resets pickers to the new theme's colors
- Panel works for both built-in and custom themes — custom theme values are read from parsed .scss variables

### Color picker interaction
- Each of the 4 colors (BG, Text, Accent, Link) uses a native HTML color input (clickable swatch) paired with an editable hex text field
- 2×2 grid layout: BG/Text on top row, Accent/Link on bottom row
- Hex validation on blur — invalid values get a red border (supports Phase 61's AI validation requirement)
- Live swatch update: as user changes picker values, the 3 swatch dots in the theme dropdown update to reflect customized colors

### Font selector design
- ~10-12 curated, widely-available professional fonts (serif, sans-serif, monospace)
- Plain text dropdown with font names grouped by category — no font preview rendering
- Single font selector controlling $mainFont only (no separate heading font)
- Examples: Source Sans Pro, Lato, Merriweather, Fira Sans, PT Serif, Roboto Slab, IBM Plex Mono

### Custom .scss generation
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Quarto theme documentation
- Quarto RevealJS themes: `theme: [default, custom.scss]` array syntax — https://quarto.org/docs/presentations/revealjs/themes.html
- Custom .scss must have `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` sections
- RevealJS SCSS variables: `$backgroundColor`, `$mainColor`, `$linkColor`, `$mainFont`

### Predecessor phase context
- `.planning/phases/58-theme-infrastructure/58-CONTEXT.md` — YAML array syntax contract, custom_scss parameter signature, pipeline threading
- `.planning/phases/59-theme-swatches-upload-and-management/59-CONTEXT.md` — Swatch dropdown with optgroups, upload/delete UI, custom theme persistence in data/themes/

### Requirements
- `.planning/REQUIREMENTS.md` — THME-08 (color pickers for bg/text/accent/link), THME-10 (AI values populate pickers), THME-11 (curated font list)

### Codebase files
- `R/mod_slides.R` — Lines 86-144: existing theme selectizeInput with swatch rendering, upload link, delete handler; Lines 505-526: theme vs custom_scss resolution logic
- `R/slides.R` — `build_qmd_frontmatter(title, theme, custom_scss)`: emits YAML; `generate_slides()`: copies .scss to tempdir
- `data/themes/epa-owm.scss` — Real custom theme file with scss:defaults variables (reference for parsing pattern)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `selectizeInput(ns("theme"), ...)` — already has swatch dot rendering with custom JS render functions, optgroup support for built-in/custom groups
- `build_qmd_frontmatter(title, theme, custom_scss)` — already handles array syntax for custom .scss
- `generate_slides()` — already copies .scss to tempdir and passes to Quarto
- Phase 59's .scss parsing logic (extracting $backgroundColor, $mainColor, $linkColor from scss:defaults) — reusable for pre-filling pickers
- `data/themes/` directory and file management patterns from Phase 59

### Established Patterns
- Modal uses `layout_columns(col_widths = c(4, 4, 4))` for option grid layout
- Options passed as named list: `options$theme`, `options$custom_scss`
- Toast notifications via `showNotification()` for user feedback
- `selectizeInput` with custom JS render for rich dropdown items

### Integration Points
- Collapsible panel goes directly below the existing theme `selectizeInput` + upload link (lines 86-144 in mod_slides.R)
- Color/font values feed into .scss generation → saved to `data/themes/` → wired via `options$custom_scss`
- Phase 61 will call the same picker update mechanism to populate AI-generated values into the color/font fields

</code_context>

<specifics>
## Specific Ideas

- The collapsible panel should feel lightweight — not a heavy modal-within-modal. Think bslib accordion or a simple div toggle.
- Native HTML color input (`<input type="color">`) paired with text field is zero-dependency and cross-browser.
- The .scss template is minimal: 5 variables in scss:defaults, a comment in scss:rules. This keeps generated files simple and parseable.
- Phase 61's AI generation will target these same picker fields — the "populate from AI" contract is: set the 4 color inputs + font selector reactively, same as if the user manually changed them.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 60-color-picker-and-font-selector*
*Context gathered: 2026-03-20*
