---
status: diagnosed
trigger: "Investigate why footnotes are still generated in the wrong style despite format reference being added to the slide generation prompt."
created: 2026-02-27T13:15:00Z
updated: 2026-02-27T13:50:00Z
---

## Current Focus

hypothesis: Despite the format reference showing ^1 syntax, LLMs are still generating OTHER footnote styles like [1], (1), [^1], or omitting footnotes entirely. The format reference might not be emphatic enough, or LLMs' prior training on Quarto's native [^1] syntax is overriding the instruction.
test: Need to see actual LLM output to confirm what style is being generated. Check if the issue is insufficient emphasis in the prompt or if there's a prompt structure problem that causes LLMs to ignore the format reference.
expecting: Will find either that the format reference needs stronger emphasis ("CRITICAL: use ^1 NOT [^1]") or that prompt structure buries the format reference where LLMs don't notice it
next_action: Analyze prompt structure for visibility/emphasis issues, compare against working AMR.qmd to confirm ^1 is the correct target format

## Symptoms

expected: LLM generates slides with ^1 superscript footnotes (e.g., "key finding^1") when citation_style="footnotes"
actual: LLM still produces incorrect footnote syntax (presumably [1] bracketed style based on UAT failure)
errors: UAT test 9 failed: "footnotes are still being generated in the wrong style"
reproduction: Generate slides with citation_style="footnotes" and observe footnote syntax is not ^1 style
started: Phase 39 UAT, persists after format reference was added

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-02-27T13:16:00Z
  checked: build_slides_prompt() system_prompt lines 64-89
  found: Format reference exists at lines 73-80 with explicit ^1 syntax example and reference list format
  implication: The format reference WAS successfully added as intended

- timestamp: 2026-02-27T13:17:00Z
  checked: citation_instructions for "footnotes" case, line 93
  found: "Use footnote-style citations: add ^1 superscript numbers after key points (e.g., 'key finding^1'), then add '## References' slide with numbered list at the end."
  implication: citation_instructions ALSO mentions ^1 syntax explicitly - should be reinforcing, not conflicting

- timestamp: 2026-02-27T13:18:00Z
  checked: Prompt assembly order in system_prompt (lines 64-89)
  found: Format reference appears at lines 73-80, BEFORE the "Content rules" section. The format reference is in the system prompt.
  implication: Format reference is prominent and early in system prompt

- timestamp: 2026-02-27T13:19:00Z
  checked: Prompt assembly order in user_prompt (lines 101-108)
  found: citation_instructions (which includes ^1 example) is inserted into user prompt at line 105, separate from system prompt
  implication: Both system and user prompts mention ^1 syntax - should be reinforcing

- timestamp: 2026-02-27T13:25:00Z
  checked: Example output files AMR.qmd (working, dated Feb 12) and AMR2.qmd (dated Feb 23, after format reference added)
  found: AMR.qmd uses correct ^1 syntax throughout. AMR2.qmd has NO footnotes at all despite CSS being injected for footnotes.
  implication: Problem might not be "wrong syntax" but rather LLM is OMITTING footnotes entirely, or user is not selecting citation_style="footnotes"

- timestamp: 2026-02-27T13:27:00Z
  checked: Format reference examples in lines 73-76 vs AMR.qmd working example
  found: Format reference shows 'Machine learning improves accuracy^1' inline and '## References\\n\\n1. Author et al.' for references. AMR.qmd (working example) uses same pattern: ^1 in text, numbered list in References section.
  implication: Format reference correctly shows the pattern - this is valid Quarto/markdown syntax where ^N creates superscripts linked to numbered references

- timestamp: 2026-02-27T13:30:00Z
  checked: UAT gap description more carefully
  found: UAT test 9 says "footnotes are still being generated in the wrong style" but doesn't specify WHAT wrong style. Test 10 mentions "CSS injection + proper YAML structure still very hard for most models"
  implication: The "wrong style" might not be about ^1 vs [1] syntax - might be about missing footnotes, or incorrect Quarto footnote processing. Need to understand what Quarto's NATIVE footnote syntax is vs the manual ^1 approach

- timestamp: 2026-02-27T13:35:00Z
  checked: Quarto official documentation for footnote syntax
  found: Quarto supports TWO footnote syntaxes:
    1. Inline footnotes: ^[footnote text here]
    2. Reference-style: [^1] in text, then [^1]: definition text separately
  implication: FOUND THE PROBLEM - The format reference teaches ^1 (literal superscript text) which is NOT Quarto footnote syntax. This creates plain superscript without automatic footnote processing, linking, or numbering.

- timestamp: 2026-02-27T13:37:00Z
  checked: R/slides.R line 74 - format reference footnote example
  found: "Footnotes: Add superscript citation numbers with ^1 syntax, then list references at end"
  implication: Format reference teaches ^1 which creates manual superscripts

- timestamp: 2026-02-27T13:40:00Z
  checked: UAT test 9 expectations and Quarto native footnote syntax documentation
  found: UAT explicitly expects "^1 superscript syntax (not bracketed [1] or parenthetical)". Quarto's native syntax is [^1] or ^[text]. User wants ^1 manual approach, NOT Quarto native footnotes.
  implication: HYPOTHESIS CORRECTION - ^1 IS the desired format. The problem is NOT that format reference teaches wrong syntax. Problem must be that LLMs are generating [1], (1), [^1] or other styles DESPITE the format reference.

- timestamp: 2026-02-27T13:45:00Z
  checked: Format reference placement and emphasis in system_prompt
  found: Format reference at lines 73-80 is just descriptive text. No emphasis markers like "CRITICAL" or "MUST use". Appears early but mixed with other content. No negative instruction ("do NOT use [1] or [^1]")
  implication: Format reference might lack sufficient emphasis. LLMs trained on Quarto documentation know [^1] syntax and might default to it without strong instruction to use ^1 instead.

## Resolution

root_cause: |
  The format reference in R/slides.R (lines 73-76) teaches ^1 syntax correctly, but lacks sufficient emphasis and negative instruction to override LLMs' prior knowledge of Quarto's native footnote syntax.

  **What's happening:**
  1. Format reference shows: "Footnotes: Add superscript citation numbers with ^1 syntax..."
  2. But LLMs are trained on Quarto documentation which teaches [^1] as the standard footnote syntax
  3. The format reference is descriptive but not emphatic - no "CRITICAL", "MUST", or "do NOT use [^1]" warnings
  4. LLMs likely default to their training (use [^1]) or invent other styles like [1] or (1)

  **Why the fix in Phase 39-03 didn't work:**
  - Added format reference with correct syntax ✓
  - But didn't add emphasis or negative instruction ✗
  - No explicit contrast: "Use ^1, NOT [^1] or [1]" ✗
  - Format reference is just one paragraph among many others ✗

  **Missing elements:**
  1. Emphasis: "CRITICAL: Use ^1 for footnotes"
  2. Negative instruction: "Do NOT use Quarto's native [^1] syntax or bracketed [1] style"
  3. Rationale: Brief explanation of why (RevealJS rendering, consistency, etc.)
  4. Stronger placement: Could move format reference higher or repeat in citation_instructions

artifacts: [R/slides.R lines 73-76 (format reference), line 93 (citation_instructions)]
missing: |
  - Emphatic instruction language ("CRITICAL", "MUST")
  - Negative instruction ("NOT [^1] or [1]")
  - Could benefit from repetition in both system prompt AND citation_instructions
  - Example showing WRONG styles to avoid alongside the correct style

fix: (diagnosis only - not implementing)
verification: (diagnosis only)
files_changed: [R/slides.R]
