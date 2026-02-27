---
status: complete
phase: 39-slide-healing
source: 39-01-SUMMARY.md, 39-02-SUMMARY.md
started: 2026-02-27T12:00:00Z
updated: 2026-02-27T12:30:00Z
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

### 9. Improved generation prompt reduces bad YAML
expected: Generate slides normally. The generated QMD should have valid YAML frontmatter (proper --- delimiters, valid format/revealjs structure). The prompt improvement makes well-formed output more likely than before.
result: issue
reported: "Model doesn't improve response from chip prompts + errors alone. It revised footnotes only when given proper format explicitly. Prompt needs distilled RevealJS/Quarto formatting reference (footnotes, speaker notes, etc.) so the LLM produces correct output without user teaching it."
severity: major

## Summary

total: 9
passed: 8
issues: 1
pending: 0
skipped: 0

## Deferred Ideas

- Model selector in healing modal — let user pick a different model for healing attempts
- Regenerate with cached chunks — skip re-fetching documents to save context/cost

## Gaps

- truth: "Slide generation prompt includes sufficient formatting reference for RevealJS/Quarto constructs (footnotes, speaker notes, etc.) so LLM produces correct output"
  status: failed
  reason: "User reported: Model doesn't improve response from chip prompts + errors alone. It revised footnotes only when given proper format explicitly. Prompt needs distilled RevealJS/Quarto formatting reference (footnotes, speaker notes, etc.) so the LLM produces correct output without user teaching it."
  severity: major
  test: 9
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
