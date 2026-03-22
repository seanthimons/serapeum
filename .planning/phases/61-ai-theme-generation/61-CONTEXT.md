# Phase 61: AI Theme Generation - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can describe a slide theme in plain language and receive a validated, editable .scss theme file. The app sends the description to the LLM, receives structured JSON containing 5 theme variables (bg, fg, accent, link, font), validates all values, and populates the Phase 60 color picker and font selector fields for manual tweaking before saving. This phase does NOT include prompt editing (Phase 62+) or any changes to the picker/save UI itself (Phase 60).

</domain>

<decisions>
## Implementation Decisions

### Input UX & placement
- Separate "AI Generate" button next to the theme dropdown (alongside the existing Upload link)
- Clicking opens a popover with a multi-line textarea (2-3 rows) and a "Generate" button
- Placeholder text only for guidance: e.g., "e.g., ocean blues, dark background, modern sans-serif font"
- No clickable examples or additional guidance UI

### LLM integration
- Use the user's selected chat model (from Settings) — consistent with all other AI features
- System prompt includes the full CURATED_FONTS list so LLM picks from valid options
- LLM returns JSON in a markdown fence block (```json ... ```); app extracts JSON via regex
- All 5 fields required in JSON response: backgroundColor, mainColor, accentColor, linkColor, mainFont

### Validation & error handling
- All 4 hex colors validated as valid 6-digit hex — if any invalid, reject entire response and show error toast naming the bad fields
- Font validated against CURATED_FONTS — if invalid, fall back to "Source Sans Pro" with a warning (don't reject the whole theme for one bad font)
- If JSON extraction fails entirely: silently retry the LLM call once, then show error "Couldn't generate theme. Try a more specific description."
- Maximum 2 LLM calls per Generate click (1 original + 1 retry)

### Post-generation flow
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — THME-05 (freeform description to AI theme), THME-06 (structured JSON with 8-9 variables), THME-07 (hex + font validation before saving)

### Predecessor phase context
- `.planning/phases/60-color-picker-and-font-selector/60-CONTEXT.md` — Color picker pair UI, font selector, generate_custom_scss(), parse_scss_colors_full(), save flow, reactive population contract
- `.planning/phases/59-theme-swatches-upload-and-management/59-CONTEXT.md` — Theme dropdown with optgroups, swatch rendering, custom theme persistence in data/themes/
- `.planning/phases/58-theme-infrastructure/58-CONTEXT.md` — YAML array syntax, custom_scss parameter threading, build_qmd_frontmatter()

### Quarto theme documentation
- Quarto RevealJS themes: `theme: [default, custom.scss]` array syntax — https://quarto.org/docs/presentations/revealjs/themes.html
- RevealJS SCSS variables: `$backgroundColor`, `$mainColor`, `$linkColor`, `$accentColor`, `$mainFont`

### Codebase files
- `R/themes.R` — CURATED_FONTS list (11 fonts), generate_custom_scss(), parse_scss_colors_full(), validate_scss_file()
- `R/mod_slides.R` — color_picker_pair() helper (line 13), customize panel UI + server, theme dropdown + AI button placement area
- `R/api_openrouter.R` — format_chat_messages(), OpenRouter API call pattern
- `R/rag.R` — format_chat_messages() usage pattern for system prompts, cost tracking integration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `generate_custom_scss(name, bg_color, text_color, accent_color, link_color, font_name)` — writes .scss file, reusable for AI-generated themes after validation
- `parse_scss_colors_full(scss_text)` — extracts bg/fg/accent/link/font from .scss, useful if regenerating from existing theme
- `CURATED_FONTS` — named list of 11 fonts grouped by category, used for both font selector and LLM prompt injection
- `format_chat_messages(system_prompt, user_message)` — standard message formatting for OpenRouter API calls
- `color_picker_pair(ns, id, label)` — local helper in mod_slides.R for the 4 color picker fields
- Phase 60's reactive population pattern: `updateColourInput()` + `updateSelectizeInput()` for font

### Established Patterns
- LLM calls use `format_chat_messages()` + OpenRouter API with cost tracking via pricing_env
- All AI features use the user's selected model from Settings
- Toast notifications via `showNotification()` for success/error feedback
- Button spinner pattern from v5.0 chat send button (disable + spinner during async)
- Slide generation has a "heal" button for regeneration — similar pattern for theme regeneration

### Integration Points
- AI Generate button goes next to existing Upload link in the theme dropdown area (mod_slides.R lines 86-144)
- After generation, populate the same reactive inputs that Phase 60's color pickers use
- Cost tracking: log the generation call via existing cost tracking infrastructure
- The "Regenerate" button lives inside the customize panel, alongside the color pickers

</code_context>

<specifics>
## Specific Ideas

- The AI button should feel like a peer to the Upload link — small, unobtrusive, not dominating the theme selection area
- The popover with textarea keeps the modal clean — AI generation is a secondary entry point, not the primary workflow
- "Regenerate" button in the customize panel mirrors the slide heal button pattern — users are already familiar with this regeneration UX
- The prompt should include CURATED_FONTS inline so the LLM picks valid fonts, reducing validation failures to near-zero for font names

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 61-ai-theme-generation*
*Context gathered: 2026-03-20*
