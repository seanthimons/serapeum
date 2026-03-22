# Phase 58: Theme Infrastructure - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The slide generation pipeline supports custom .scss themes via `theme: [base, custom.scss]` YAML frontmatter, unblocking all subsequent theme UI work (Phases 59-61). This is plumbing only — no UI changes, no theme management, no color pickers.

</domain>

<decisions>
## Implementation Decisions

### YAML array syntax
- When `custom_scss` is NULL (default): emit `theme: default` — single-value, unchanged from current behavior
- When `custom_scss` is provided: emit `theme: [base, custom.scss]` — array form with base theme first, custom .scss second (custom overrides base, per Quarto convention)
- The .scss file listed second takes precedence — this is the documented Quarto behavior
- Custom .scss must use `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` section markers (Quarto requirement)

### Custom .scss path contract
- New parameter: `build_qmd_frontmatter(title, theme = "default", custom_scss = NULL)`
- The .scss file is copied to `tempdir()` next to the QMD file before rendering — YAML uses a relative filename, not an absolute path
- This avoids machine-specific paths in YAML and keeps the QMD portable

### Pipeline threading
- Thread `custom_scss` through the full pipeline: `generate_slides()` options -> `build_qmd_frontmatter()` -> file copy to tempdir
- Healing flow (`build_healing_prompt()` / healing render path) also threads `custom_scss` through so healed slides preserve the custom theme
- `mod_slides.R` caller sites updated to pass `custom_scss` (NULL for now — Phase 59 wires in the UI)

### Claude's Discretion
- Exact file copy implementation (file.copy vs fs::file_copy)
- Error handling when .scss file doesn't exist at the provided path
- Whether to validate .scss section markers before copying

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Quarto theme documentation
- Quarto RevealJS themes: `theme: [default, custom.scss]` array syntax — https://quarto.org/docs/presentations/revealjs/themes.html
- Custom .scss must have `/*-- scss:defaults --*/` and `/*-- scss:rules --*/` sections

### Codebase files
- `R/slides.R` — `build_qmd_frontmatter()` (line ~129): current function to modify; `generate_slides()` (line ~270): caller that passes theme option; healing flow (line ~371+): also calls `build_qmd_frontmatter()`
- `R/mod_slides.R` — UI theme dropdown (line ~8-9) and generation call sites (line ~399, ~436, ~621): callers that need `custom_scss` threaded through

### Requirements
- `.planning/REQUIREMENTS.md` — THME-12: Custom themes applied via `theme: [base, custom.scss]` in QMD frontmatter

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build_qmd_frontmatter(title, theme)` — already handles theme as a parameter, just needs `custom_scss` added
- `generate_slides()` — already receives `options$theme`, easy to add `options$custom_scss`
- Healing flow already preserves theme when rebuilding YAML

### Established Patterns
- Programmatic YAML frontmatter via `paste0()` string building (v7.0 decision — no LLM-generated YAML)
- `strip_llm_yaml()` removes any YAML the LLM includes despite instructions
- Options passed as named list through the pipeline: `options$theme`, `options$citation_style`, etc.
- Temp file handling: QMD written to `tempdir()` with sanitized filename

### Integration Points
- `build_qmd_frontmatter()` — single function that generates all YAML; the only place theme YAML is emitted
- `generate_slides()` line ~314-315 — extracts `options$theme` and calls `build_qmd_frontmatter()`
- `mod_slides.R` line ~621 — healing flow also calls `build_qmd_frontmatter(title, theme)`
- Future phases (59-61) will pass `custom_scss` path from UI selections / AI-generated .scss files

</code_context>

<specifics>
## Specific Ideas

- Quarto docs confirmed: `theme: [default, custom.scss]` is the exact syntax — validated via Context7
- The .scss file path in YAML is relative to the QMD file location, so file must be copied to tempdir() alongside the QMD
- v7.0 decision to use programmatic YAML (not LLM-generated) makes this change safe — we control the exact YAML output

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 58-theme-infrastructure*
*Context gathered: 2026-03-19*
