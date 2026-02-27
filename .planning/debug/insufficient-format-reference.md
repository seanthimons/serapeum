---
status: diagnosed
trigger: "Investigate the root cause of this UAT gap for Phase 39 (Slide Healing): The slide generation and healing prompts in `R/slides.R` lack sufficient RevealJS/Quarto formatting reference. The LLM produces incorrect syntax for footnotes, speaker notes, etc."
created: 2026-02-27T12:45:00Z
updated: 2026-02-27T12:52:00Z
---

## Current Focus

hypothesis: The system and user prompts in build_slides_prompt() and build_healing_prompt() provide only minimal formatting guidance (e.g., "Use ::: {.notes} blocks") without concrete syntax examples, causing LLMs to guess at or invent incorrect Quarto/RevealJS constructs
test: Read the actual prompts in R/slides.R and compare against the working example (AMR.qmd) to identify missing formatting reference material
expecting: Will find that prompts lack specific examples for footnotes (^N syntax), speaker notes (::: {.notes}), proper reference list syntax, column layouts, and other Quarto-specific markdown
next_action: Analyze prompt content against working examples

## Symptoms

expected: LLM generates slides with correct Quarto/RevealJS syntax for footnotes, speaker notes, references, etc. without requiring user intervention
actual: LLM produces incorrect syntax until user explicitly provides the correct format (e.g., footnote syntax)
errors: User reported "Model doesn't improve response from chip prompts + errors alone. It revised footnotes only when given proper format explicitly."
reproduction: Generate slides with citation_style="footnotes" and observe incorrect footnote syntax; heal with generic "fix citations" instruction and observe it doesn't improve; heal with explicit "use ^N syntax for footnotes" and observe it then works
started: Phase 39 UAT (test 9), during slide generation with citations

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-02-27T12:46:00Z
  checked: build_slides_prompt() system prompt (lines 64-81 in R/slides.R)
  found: Minimal formatting instructions - only mentions "Use ## for slide titles", "Use # for sections", "Include speaker notes using ::: {.notes} blocks"
  implication: No concrete syntax examples for any Quarto/RevealJS constructs

- timestamp: 2026-02-27T12:47:00Z
  checked: citation_instructions in build_slides_prompt() (lines 84-90)
  found: Generic text-only guidance like "Use footnote-style citations: add superscript numbers after key points and list references at the end" - no syntax examples showing ^N notation
  implication: LLM must guess how to implement "footnote-style citations" in Quarto markdown

- timestamp: 2026-02-27T12:48:00Z
  checked: Working example AMR.qmd (lines 33-41, 200-232)
  found: Actual working syntax - footnotes use ^1 ^9 ^13 notation, speaker notes use ::: {.notes} ... ::: blocks, references are numbered lists under ## headings
  implication: These are the concrete patterns the LLM should be taught but aren't in the prompt

- timestamp: 2026-02-27T12:49:00Z
  checked: build_healing_prompt() system prompt (lines 382-394)
  found: Similarly vague - "You are an expert Quarto presentation fixer" but no reference material showing correct formats
  implication: Even when healing, LLM has no reference for what "correct" Quarto syntax looks like

- timestamp: 2026-02-27T12:50:00Z
  checked: UAT gap report (39-UAT.md line 50)
  found: User had to manually tell LLM the correct footnote format before it could fix it
  implication: Confirms LLM lacks knowledge - needed explicit instruction rather than being able to self-correct

- timestamp: 2026-02-27T12:51:00Z
  checked: Comparison of working AMR.qmd against prompt instructions
  found: Missing formatting references for:
    1. Footnote syntax: ^N for inline references (e.g., "resistance^1")
    2. Speaker notes: ::: {.notes} ... ::: block structure (mentioned but no example)
    3. References section: ## References heading with numbered list (1. Author - Title)
    4. Section dividers: # for major sections (mentioned but not emphasized)
    5. Slide separators: ## for each slide (mentioned)
    6. Tables: | syntax for markdown tables
    7. Code blocks: ``` fence syntax (not relevant for current use case)
    8. Columns: Not in example but is a common Quarto feature (:::: {.columns})
  implication: At minimum need footnote syntax examples and reference list format since these were cited as problematic

## Resolution

root_cause: |
  The system prompts in both build_slides_prompt() and build_healing_prompt() provide only abstract formatting instructions without concrete syntax examples.

  Specifically:
  1. citation_instructions (lines 84-90) says "Use footnote-style citations: add superscript numbers" but doesn't show the ^N syntax
  2. system_prompt (lines 64-81) mentions "::: {.notes} blocks" but doesn't show the complete block structure with closing :::
  3. No reference showing how to format the References section (## References + numbered list format)
  4. No examples of ANY working Quarto/RevealJS markdown constructs

  This forces the LLM to guess at implementation details. Different models may have different training data about Quarto syntax, leading to inconsistent or incorrect output. When healing, the LLM still has no reference material, so generic healing instructions like "fix citations" fail - only explicit format instructions work.

  The working AMR.qmd example demonstrates the correct patterns that should be taught in the prompts.

fix: (diagnosis only - not implementing)
verification: (diagnosis only)
files_changed: [R/slides.R]
