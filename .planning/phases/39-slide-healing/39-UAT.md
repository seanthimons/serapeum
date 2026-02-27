---
status: diagnosed
phase: 39-slide-healing
source: 39-01-SUMMARY.md, 39-02-SUMMARY.md, 39-03-SUMMARY.md
started: 2026-02-27T14:00:00Z
updated: 2026-02-27T14:45:00Z
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
expected: Generate slides with citation style set to "footnotes". The LLM should produce footnotes using ^1 superscript syntax (not bracketed [1] or parenthetical). Speaker notes should use ::: {.notes} blocks. The LLM should get this right on first generation without you needing to teach it the syntax.
result: issue
reported: "fail. footnotes are still being generated in the wrong style. Address this in a gap fixing session."
severity: major

### 10. Healing with format reference enables self-correction
expected: If slides have formatting issues (e.g., wrong footnote syntax), use Heal with a chip like "Fix citations" or custom instruction. The healed output should correct to proper ^1 syntax and ::: {.notes} structure without you providing explicit format examples.
result: issue
reported: "fail. CSS injection + proper YAML structure still very hard for most models. Could be related to context not being sent to the model properly. Address this in a gap fixing session; we'll need to find a good way of injecting a proper YAML block + any custom CSS."
severity: major

## Summary

total: 10
passed: 8
issues: 2
pending: 0
skipped: 0

## Gaps

- truth: "Slide generation prompt includes sufficient formatting reference for footnotes so LLM produces ^1 superscript syntax on first generation"
  status: failed
  reason: "User reported: footnotes are still being generated in the wrong style."
  severity: major
  test: 9
  root_cause: "Format reference added in 39-03 uses plain descriptive language without emphasis. No negative instruction warning against [^1], [1], or (1) styles. LLMs default to Quarto's native [^1] syntax from training data. Format reference is one paragraph among many, easy for LLMs to deprioritize."
  artifacts:
    - path: "R/slides.R"
      issue: "build_slides_prompt() format reference line 74: descriptive, not emphatic"
    - path: "R/slides.R"
      issue: "citation_instructions line 93: mentions ^1 but no negative instruction"
  missing:
    - "Add emphasis markers (CRITICAL) and negative instruction (Do NOT use [^1] or [1])"
    - "Add explicit contrast showing wrong vs right styles"
  debug_session: ".planning/debug/footnote-style-still-wrong.md"

- truth: "Healing with format reference enables LLM to self-correct CSS injection and YAML structure issues"
  status: failed
  reason: "User reported: CSS injection + proper YAML structure still very hard for most models. Context may not be reaching model properly. Need better way of injecting YAML block + custom CSS."
  severity: major
  test: 10
  root_cause: "build_healing_prompt() hardcodes theme: default in YAML template (line 398) while previous_qmd has custom theme + CSS. Creates conflicting instructions — LLM follows explicit CRITICAL template and strips CSS. heal_slides() doesn't pass theme parameter. Post-healing CSS injection in mod_slides.R only works after validation passes."
  artifacts:
    - path: "R/slides.R"
      issue: "build_healing_prompt() lines 389-426: hardcoded YAML with theme: default, no CSS example"
    - path: "R/slides.R"
      issue: "heal_slides() lines 437-479: doesn't pass theme or inject post-LLM"
    - path: "R/mod_slides.R"
      issue: "healing observer lines 614-627: post-healing injection only after validation"
  missing:
    - "Make build_healing_prompt() use dynamic YAML template with actual theme instead of hardcoded default"
    - "Instruct LLM to preserve existing YAML frontmatter structure unless specifically asked to change it"
    - "Pass theme parameter through heal_slides() pipeline"
  debug_session: ".planning/debug/css-yaml-healing-broken.md"
