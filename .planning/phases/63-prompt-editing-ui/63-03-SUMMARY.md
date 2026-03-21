---
phase: 63-prompt-editing-ui
plan: 03
subsystem: ai
tags: [rag, prompts, prompt-versioning, duckdb, openrouter]

# Dependency graph
requires:
  - phase: 63-01
    provides: get_effective_prompt() in R/prompt_helpers.R with PROMPT_DEFAULTS fallback

provides:
  - All 7 generators in R/rag.R use get_effective_prompt() for task instruction text
  - build_slides_prompt() in R/slides.R accepts con parameter and uses get_effective_prompt()
  - Custom prompts saved via prompt_versions table now take effect in all AI generations

affects:
  - R/rag.R - all preset generators (summarize, keypoints, studyguide, outline, conclusions, overview, research_questions, lit_review, methodology, gap_analysis)
  - R/slides.R - build_slides_prompt, generate_slides

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "get_effective_prompt(con, slug) called at start of each generator to resolve custom vs default prompt text"
    - "Role preamble lines and CITATION RULES blocks remain hardcoded — only task instruction portion is editable"
    - "overview generator uses double-sprintf: sprintf(task_instruction, depth_instruction) inside outer sprintf for CITATION RULES"
    - "slides uses con = NULL guard: get_effective_prompt only called when con provided, PROMPT_DEFAULTS used otherwise"

key-files:
  created: []
  modified:
    - R/rag.R
    - R/slides.R

key-decisions:
  - "Role preamble lines ('You are a research synthesis assistant. Your task is to:') remain hardcoded — only the task instruction body is looked up from prompt_versions"
  - "CITATION RULES blocks remain hardcoded in all generators — not editable via prompt_versions"
  - "build_slides_prompt() uses con = NULL default so callers that don't have a connection still work; falls back to PROMPT_DEFAULTS[['slides']]"
  - "overview double-sprintf pattern: task_instruction contains %s placeholder for depth_instruction; inner sprintf injects depth before outer sprintf appends CITATION RULES"

patterns-established:
  - "Generator integration pattern: task_instruction <- get_effective_prompt(con, 'slug'); system_prompt <- paste0('Role preamble\n\n', task_instruction, '\n\nHARDCODED_RULES')"

requirements-completed: [PRMT-01, PRMT-02]

# Metrics
duration: 5min
completed: 2026-03-21
---

# Phase 63 Plan 03: Prompt Generator Wiring Summary

**get_effective_prompt() wired into all 7 rag.R generators and build_slides_prompt() so custom prompts from prompt_versions table take effect in AI generation**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-21T21:17:00Z
- **Completed:** 2026-03-21T21:20:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- All 7 R/rag.R generators (generate_preset, generate_conclusions_preset, call_overview_quick, generate_research_questions, generate_lit_review_table, generate_methodology_extractor, generate_gap_analysis) now call get_effective_prompt() for their task instruction text
- build_slides_prompt() in R/slides.R accepts `con = NULL` parameter and looks up effective slides prompt
- generate_slides() passes `con = con` to build_slides_prompt() so the connection threads through
- Role preamble lines and CITATION RULES blocks remain hardcoded in all generators (not editable)
- When no custom prompt exists in prompt_versions, all generators fall back to PROMPT_DEFAULTS — behavior is identical to pre-integration state

## Task Commits

Each task was committed atomically:

1. **Task 1: Integrate get_effective_prompt() into generate_preset() and all dedicated generators in R/rag.R** - `c08c902` (feat)
2. **Task 2: Integrate get_effective_prompt() into build_slides_prompt() in R/slides.R** - `0fc9360` (feat)

## Files Created/Modified
- `R/rag.R` - 7 generator functions wired to get_effective_prompt() for task instruction lookup
- `R/slides.R` - build_slides_prompt() gains `con = NULL` parameter; content rules block uses get_effective_prompt or PROMPT_DEFAULTS fallback

## Decisions Made
- Role preamble and CITATION RULES stay hardcoded because they control output structure and citation behavior — only the task instruction body is user-editable
- The overview generator uses a double-sprintf pattern: `sprintf(task_instruction, depth_instruction)` inside an outer `sprintf(...)` that appends CITATION RULES. This preserves the %s placeholder in PROMPT_DEFAULTS[["overview"]] for depth_instruction injection
- build_slides_prompt() uses `con = NULL` default (not required) so that any test or caller without a DB connection still works correctly by falling back to PROMPT_DEFAULTS

## Deviations from Plan

None — plan executed exactly as written.

One minor structural difference: the current `build_slides_prompt()` uses an `options` list parameter (not individual named parameters as the plan's interface section showed). The plan's action section correctly described Approach A and handled this — the actual signature change was `con = NULL` appended to the existing signature.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- The full prompt editing pipeline is now complete: prompt_versions table (Phase 62) + CRUD helpers (Plan 01) + UI (Plan 02) + generator wiring (this plan)
- Custom prompts saved via the prompt editor UI will take effect on the next AI generation call
- Phase 63 is complete

---
*Phase: 63-prompt-editing-ui*
*Completed: 2026-03-21*
