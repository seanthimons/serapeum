---
status: resolved
phase: 39-slide-healing
source: 39-01-SUMMARY.md, 39-02-SUMMARY.md, 39-03-SUMMARY.md
started: 2026-02-27T14:00:00Z
updated: 2026-02-27T16:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Results modal has Heal and Regenerate buttons
expected: After generating slides (from a notebook with documents), the results modal shows both a "Heal" button and a "Regenerate" button in the footer. Both are always visible, even when generation succeeds.
result: pass

### 2. Regenerate reopens full config modal
expected: Clicking the "Regenerate" button on the results modal closes it and reopens the full slide generation config modal (document selection, model, length, audience, etc.) for a fresh generation.
result: pass

### 3. Healing modal opens with chips and text input
expected: Clicking the "Heal" button opens a separate healing modal showing: an error summary (if errors exist) or a success context, quick-pick chip buttons (e.g., "Fix YAML syntax", "Simplify slides"), and a free text input for custom instructions.
result: pass

### 4. Chip click auto-fills instruction text
expected: Clicking one of the quick-pick chip buttons in the healing modal auto-fills the text input with that chip's label text.
result: pass

### 5. Healing sends previous output for targeted fix
expected: After entering healing instructions and clicking the heal button, the system sends the previous QMD output + instructions to the LLM. The result replaces the preview in the results modal (loading overlay shown during processing).
result: pass

### 6. Retry counter visible during healing
expected: When healing is in progress or on the healing modal, you can see an attempt counter like "Attempt 1 of 2" indicating how many healing tries remain.
result: pass

### 7. Fallback after 2 failed healing attempts
expected: If healing fails twice (YAML validation errors persist), the system falls back to a template presentation with title slide + section headers from your documents. A yellow warning banner appears explaining the fallback.
result: pass

### 8. Error panel with collapsible raw output
expected: When slide generation produces invalid YAML, the results modal shows an error panel (replacing the preview area) with specific error details. A "Show raw output" toggle reveals the generated QMD in a scrollable code block.
result: pass

### 9. Format reference improves LLM output quality
expected: Generate slides with citation style set to "footnotes". The LLM should produce correct Quarto ^[text] inline footnotes. Speaker notes should use ::: {.notes} blocks.
result: pass (resolved)
resolution: "Corrected footnote syntax from invalid ^1 to Quarto ^[text] inline format. LLM now outputs content only — YAML built programmatically. Tested 8/8 on Claude Sonnet 4 and Gemini Flash."

### 10. Healing with format reference enables self-correction
expected: Healing preserves theme, CSS, and YAML structure. Content renders with proper formatting.
result: pass (resolved)
resolution: "Eliminated regex YAML injection entirely. build_qmd_frontmatter() creates clean YAML with theme, CSS, reference-location, smaller, scrollable. strip_llm_yaml() handles LLMs that ignore no-YAML instruction. Healing uses same strip-and-rebuild approach."

## Summary

total: 10
passed: 10
issues: 0
pending: 0
skipped: 0

## Gaps

- truth: "Slide generation prompt includes sufficient formatting reference for footnotes so LLM produces correct Quarto syntax on first generation"
  status: resolved
  reason: "User reported: footnotes are still being generated in the wrong style."
  severity: major
  test: 9
  root_cause: "Prompt taught invalid ^1 syntax. Quarto uses ^[text] inline or [^1] reference-style. Also, LLM was generating YAML which got mangled by regex injection."
  resolution: "Switched to correct ^[text] syntax with negative instruction. LLM outputs content only, YAML built programmatically."
  debug_session: ".planning/debug/footnote-style-still-wrong.md"

- truth: "Healing with format reference enables LLM to self-correct CSS injection and YAML structure issues"
  status: resolved
  reason: "User reported: CSS injection + proper YAML structure still very hard for most models."
  severity: major
  test: 10
  root_cause: "Regex injection of theme/CSS into LLM-generated YAML was fundamentally fragile."
  resolution: "Removed inject_theme_to_qmd() and inject_citation_css(). All YAML now built by build_qmd_frontmatter(). Added smaller/scrollable/reference-location options."
  debug_session: ".planning/debug/css-yaml-healing-broken.md"
