---
status: diagnosed
trigger: "Investigate why CSS injection and YAML structure are still hard for models during slide healing, possibly related to context not being sent to the model properly."
created: 2026-02-27T00:00:00Z
updated: 2026-02-27T00:20:00Z
symptoms_prefilled: true
goal: find_root_cause_only
---

## Current Focus

hypothesis: CONFIRMED - Healing prompt uses hardcoded "theme: default" and omits CSS block from YAML template
test: Compare healing prompt YAML template with what original generation produces
expecting: Root cause is prompt template inadequacy, not post-processing (module handles that)
next_action: Document root cause and write resolution

## Symptoms

expected: LLM should receive complete YAML template with revealjs theme/CSS + original generation config so it can maintain proper structure during healing
actual: UAT test 10 failed - "CSS injection + proper YAML structure still very hard for most models"
errors: No explicit errors, but models struggle to produce correct YAML + CSS during healing
reproduction: Use healing workflow on slides that need fixes
started: Discovered during phase 39 UAT (test 10)

## Eliminated

## Evidence

- timestamp: 2026-02-27T00:05:00Z
  checked: build_healing_prompt() in R/slides.R (lines 389-426)
  found: YAML template exists but hardcoded to "theme: default" - does NOT use original theme from generation
  implication: If user generated slides with custom theme (dark, night, etc.), healing will reset to default theme

- timestamp: 2026-02-27T00:05:30Z
  checked: build_healing_prompt() in R/slides.R (lines 389-426)
  found: No CSS injection in healing prompt - prompt only includes basic YAML template
  implication: Citation CSS that was injected during generation (inject_citation_css) is NOT included in healing instructions

- timestamp: 2026-02-27T00:06:00Z
  checked: heal_slides() in R/slides.R (lines 437-479)
  found: heal_slides() does NOT inject theme or CSS after LLM returns content (unlike generate_slides which calls inject_theme_to_qmd and inject_citation_css)
  implication: Even if healing prompt included theme/CSS, the post-processing doesn't apply them

- timestamp: 2026-02-27T00:10:00Z
  checked: mod_slides_server healing observer in R/mod_slides.R (lines 512-645)
  found: CRITICAL - Module does post-healing CSS/theme injection at lines 614-627 BUT only after validation passes
  implication: This is actually good - post-processing exists in module layer

- timestamp: 2026-02-27T00:12:00Z
  checked: build_healing_prompt() YAML template (lines 393-399)
  found: Hardcoded "theme: default" in healing prompt template, does NOT reflect original theme from generation_state$last_options$theme
  implication: LLM is being explicitly instructed to use "theme: default" even if user generated with dark/night/etc theme

- timestamp: 2026-02-27T00:15:00Z
  checked: build_healing_prompt() CSS instructions (lines 389-426)
  found: Healing prompt has NO mention of CSS injection, NO example of css: block in YAML template
  implication: LLM doesn't know it should preserve/include custom CSS blocks from original QMD

- timestamp: 2026-02-27T00:18:00Z
  checked: Flow comparison - generation vs healing
  found: |
    GENERATION FLOW:
    1. LLM generates QMD with basic YAML (theme: default per prompt template)
    2. inject_theme_to_qmd() adds user's chosen theme (dark, night, etc.) - line 332
    3. inject_citation_css() adds complex CSS block - line 336
    4. Result: QMD has theme + custom CSS

    HEALING FLOW:
    1. previous_qmd (with theme + CSS) sent to LLM in code fence - line 419
    2. LLM receives hardcoded "theme: default" template in system prompt - line 398
    3. LLM returns healed QMD (often loses theme + CSS)
    4. Module re-injects theme + CSS AFTER validation - lines 618-623
    5. But if LLM removed CSS block or changed theme, structure might break
  implication: LLM sees original QMD with CSS/theme in user prompt but gets conflicting hardcoded template in system prompt

## Resolution

root_cause: |
  The healing prompt template in build_healing_prompt() gives conflicting YAML instructions:

  1. SYSTEM PROMPT (lines 393-399): Shows hardcoded minimal YAML with "theme: default"
  2. USER PROMPT (line 419): Shows actual previous_qmd which contains custom theme + CSS block

  This creates a conflict:
  - The system prompt explicitly tells LLM: "CRITICAL: Your output must start with valid YAML frontmatter" using theme: default
  - But the actual QMD being healed has a different theme (dark, night, etc.) and a complex CSS block

  Result: LLMs often follow the explicit system prompt template (theme: default) and strip the CSS block because:
  - CSS block not shown in system prompt YAML example
  - System prompt says "CRITICAL" with simple template, implying that's the correct format
  - Especially problematic for smaller models that struggle with conflicting instructions

  The module DOES re-inject theme/CSS after healing (lines 618-623), BUT:
  - If LLM removed CSS block or restructured YAML badly, validation may fail before that point
  - If LLM reset to theme: default, the re-injection logic might not work correctly
  - User sees "CSS injection + proper YAML structure still very hard for most models"

fix: |
  Need to make healing prompt YAML template match what was actually generated:

  1. Pass original theme as parameter to build_healing_prompt()
  2. Include CSS block example in system prompt YAML template
  3. Make template dynamic instead of hardcoded

  Two approaches:

  A. EXTRACT original theme/CSS from previous_qmd and show in template
     - Parse previous_qmd YAML to extract theme
     - Show actual CSS block in template if present

  B. INSTRUCT to preserve existing frontmatter
     - Keep existing theme/format section verbatim
     - Only modify slide content unless frontmatter is specifically broken

  Approach B is safer - less prompt complexity, preserves user's exact YAML structure

verification: |
  After fix:
  1. Generate slides with theme: dark and footnote citations (triggers CSS injection)
  2. Use healing with "Fewer bullet points" instruction
  3. Verify healed QMD preserves theme: dark and CSS block
  4. Test with weaker model (e.g., claude-3-haiku) to ensure it handles it

files_changed:
  - R/slides.R: build_healing_prompt() - add theme parameter, update YAML template, add preservation instructions
  - R/slides.R: heal_slides() - pass theme to build_healing_prompt()
  - R/mod_slides.R: healing observer - pass theme from generation_state$last_options$theme to heal_slides()
