---
gsd_state_version: 1.0
milestone: v16.0
milestone_name: Content & Output Quality
status: ready_to_plan
stopped_at: Completed 63-03-PLAN.md
last_updated: "2026-03-21T21:20:59.088Z"
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 12
  completed_plans: 12
---

---
gsd_state_version: 1.0
milestone: v16.0
milestone_name: Content & Output Quality
status: ready_to_plan
last_updated: "2026-03-18"
last_activity: 2026-03-18 — Roadmap created, phases 57-63 defined
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-18)

**Core value:** Researchers can efficiently discover relevant academic papers through seed papers, assisted query building, and topic exploration — then export and share their findings
**Current focus:** Phase 63 — prompt-editing-ui

## Current Position

Phase: 63 (prompt-editing-ui) — EXECUTING
Plan: 3 of 3

## Performance Metrics

**Velocity:**

- Total plans completed: 95 (v1.0–v11.0)
- Total phases completed: 58 (v1.0–v11.0 complete, v16.0 not started)
- Milestones shipped: 14 (v1.0–v11.0)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting v16.0 work:

- v7.0: Programmatic YAML via `build_qmd_frontmatter()` — custom theme path must thread through this function (THME-12)
- v7.0: Quarto `^[text]` inline footnotes are correct RevealJS syntax — page citations use this format in slide prompts (CITE-02)
- v10.0: Semantic icon wrappers in theme_catppuccin.R — new UI elements use wrappers, not raw `icon()` calls
- [Phase 57]: (Author, Year, p.X) APA-like citation format adopted for all non-slide prose AI presets in R/rag.R
- [Phase 58]: Use basename(custom_scss) in YAML so directory paths don't leak into QMD frontmatter
- [Phase 58]: custom_scss=NULL in last_options is explicit placeholder for Phase 59+ UI wiring
- [Phase 59]: Custom value in build_theme_choices_df is filename-only (e.g. epa-owm.scss); Plan 02 server wiring prepends data/themes/ when setting custom_scss
- [Phase 59]: Namespace prefix for JS delete button callback baked in from ns('') in the UI function rather than using session\ in server
- [Phase 59]: selectizeInput(choices=NULL) in UI + updateSelectizeInput(server=TRUE) in server avoids rendering full choices in initial HTML payload
- [Phase 59]: Upload trigger uses tags\(for=ns('theme_file')) not actionLink+jQuery — display:none blocks programmatic .click() in browsers; native label-for is a trusted event and always opens the file picker
- [Phase 60]: parse_scss_colors_full prioritizes accentColor over linkColor for accent field to correctly capture heading color in generated SCSS
- [Phase 60]: generate_custom_scss always appends sans-serif fallback in font value regardless of category — safe default for RevealJS
- [Phase 60]: color_picker_pair() local helper used for DRY UI; shinyjs replaced with session$sendCustomMessage for panel collapse (no useShinyjs() in app)
- [Phase 60]: color_picker_pair() local helper used for DRY UI; session$sendCustomMessage replaced shinyjs (no useShinyjs() in app); JS event listeners use DOMContentLoaded guard for modal-rendered elements
- [Phase 61-ai-theme-generation]: extract_theme_json uses DOTALL perl regex to handle multi-line JSON across fence blocks
- [Phase 61-ai-theme-generation]: generate_theme_from_description returns raw list(content, usage) only — JSON parsing delegated to Plan 02 UI wiring
- [Phase 61-ai-theme-generation]: Used Bootstrap 5 collapse block (not popover) for AI Generate form — avoids Shiny input registration issues with dynamically-inserted DOM
- [Phase 61-ai-theme-generation]: ai_generated reactiveVal gates Regenerate button via uiOutput, resets on save_custom_theme
- [Phase 62-prompt-storage-schema]: Composite PK (preset_slug, version_date) enforces one version per preset per day in prompt_versions table
- [Phase 63-prompt-editing-ui]: PROMPT_DEFAULTS stores editable portion only — role preamble lines and CITATION RULES blocks are excluded
- [Phase 63-prompt-editing-ui]: overview default keeps %s placeholder for depth_instruction so generators can sprintf() the effective prompt
- [Phase 63-prompt-editing-ui]: lapply+local({ s <- slug }) pattern used for per-preset observers to avoid R closure-over-loop-variable bug
- [Phase 63-prompt-editing-ui]: session$ns() used inside server for modal input IDs — ns() is UI-only
- [Phase 63-prompt-editing-ui]: reset_pending reactiveVal gates Save: TRUE confirms reset (delete all), FALSE upserts new version
- [Phase 63]: Role preamble and CITATION RULES stay hardcoded in all generators; only task instruction body is editable via prompt_versions
- [Phase 63]: overview double-sprintf: task_instruction contains %s for depth_instruction; inner sprintf injects before outer appends CITATION RULES
- [Phase 63]: build_slides_prompt() uses con = NULL default so callers without DB connection fall back to PROMPT_DEFAULTS[[slides]]

### Pending Todos

- Secondary ragnar leak: ensure_ragnar_store() in mod_search_notebook.R
- 13 pre-existing test fixture failures (missing schema columns)

### Blockers/Concerns

- Phase 60 (color picker UI) and Phase 61 (AI theme generation) have a soft circular dependency — resolved by building picker UI manually-only in Phase 60, then wiring AI-to-picker in Phase 61

## Session Continuity

Last session: 2026-03-21T21:20:59.084Z
Stopped at: Completed 63-03-PLAN.md
Next: Human verification of AI Prompts UI, then execute 63-03

---
*Updated: 2026-03-18 after v16.0 roadmap creation*
