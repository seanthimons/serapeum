# Phase 39: Slide Healing - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Improve slide generation reliability with better prompts, YAML validation, and a regeneration/healing workflow. Users can heal broken or imperfect slides with targeted instructions. System validates output programmatically and falls back gracefully after repeated failures. Creating new slide features (new export formats, slide templates, etc.) is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Healing Instructions UX
- Separate healing modal (not inline on results modal)
- Modal shows the validation error summary at the top so user knows what went wrong
- Quick-pick chips for common healing instructions: context-aware chips based on error type PLUS a baseline set of common suggestions (e.g., "Fix YAML syntax", "Fix CSS", "Simplify slides")
- Free text input below chips for custom healing instructions
- Clicking a chip auto-fills the text input

### Validation Feedback
- YAML validation runs BEFORE attempting Quarto render (faster feedback, avoids wasting render time)
- Errors include specific line/column info when available (e.g., "YAML parse error at line 5: unexpected indentation")
- Error panel replaces the preview area in the results modal (not a banner above it)
- Collapsible "Show raw output" toggle reveals the generated QMD in a scrollable code block for power users

### Fallback Behavior
- After 2 failed healing attempts, fall back to template YAML
- Template fallback: title slide + section headers extracted from source content (not just a blank title slide)
- Warning banner in results modal explains fallback: "Generation failed after 2 attempts. Showing template outline — download the .qmd and edit manually."
- Retry counter visible during healing: "Attempt 1 of 2"
- After fallback, full regeneration (via Regenerate button) is still available — the 2-retry limit only applies to healing, not fresh generation

### Regeneration Flow
- Two separate buttons on the results modal: "Heal" and "Regenerate"
- **Heal** button: opens the healing modal (lightweight — instructions + retry). Sends previous QMD output + healing instructions to LLM for targeted fixing (preserves what was good)
- **Regenerate** button: reopens the full config modal for a completely fresh generation
- Heal button is ALWAYS visible on results modal — even on successful generation (user can heal cosmetic issues like "fewer bullet points", "make text bigger")
- During healing: loading overlay on preview area, replaced with new preview on completion. If fails, shows error panel

### Claude's Discretion
- Exact YAML validation library/approach in R
- Specific chip labels and which are context-aware vs static
- Loading overlay animation style
- How section headers are extracted from source chunks for the fallback template
- Prompt engineering for the YAML template structure in the system prompt

</decisions>

<specifics>
## Specific Ideas

- Quick-pick chips should adapt to error context: YAML parse error shows "Fix YAML syntax", Quarto render error shows "Fix Quarto formatting", successful generation shows cosmetic options like "Fewer bullet points" or "Simplify"
- The healing LLM call receives the previous QMD output + error details + user instructions — it's a targeted fix, not a from-scratch regeneration
- The prompt improvement (SLIDE-01) should include a proper YAML template structure in the system prompt to reduce malformed output in the first place

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 39-slide-healing*
*Context gathered: 2026-02-27*
