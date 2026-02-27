# Phase 39: Slide Healing - Research

**Researched:** 2026-02-27
**Domain:** YAML validation, LLM prompt engineering, Shiny modal UX
**Confidence:** HIGH

## Summary

Phase 39 improves slide generation reliability through three mechanisms: (1) better prompts with YAML template structure, (2) programmatic YAML validation before Quarto render, and (3) a healing workflow where users can fix broken or imperfect slides with targeted instructions.

The existing codebase (`R/slides.R` and `R/mod_slides.R`) provides a solid foundation. The `generate_slides()` function already handles LLM calls, theme injection, and QMD rendering. The results modal already has a Regenerate button (which reopens the config modal). The key additions are: YAML validation, a new healing modal, a healing LLM call that passes previous output + errors + instructions, retry tracking, and template fallback.

**Primary recommendation:** Add `validate_qmd_yaml()` using the `yaml` R package for validation, create `heal_slides()` function that sends previous QMD + errors + instructions to LLM, and build a healing modal with error summary + quick-pick chips + free text input.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Separate healing modal (not inline on results modal)
- Modal shows the validation error summary at the top so user knows what went wrong
- Quick-pick chips for common healing instructions: context-aware chips based on error type PLUS a baseline set of common suggestions (e.g., "Fix YAML syntax", "Fix CSS", "Simplify slides")
- Free text input below chips for custom healing instructions
- Clicking a chip auto-fills the text input
- YAML validation runs BEFORE attempting Quarto render (faster feedback, avoids wasting render time)
- Errors include specific line/column info when available (e.g., "YAML parse error at line 5: unexpected indentation")
- Error panel replaces the preview area in the results modal (not a banner above it)
- Collapsible "Show raw output" toggle reveals the generated QMD in a scrollable code block for power users
- After 2 failed healing attempts, fall back to template YAML
- Template fallback: title slide + section headers extracted from source content (not just a blank title slide)
- Warning banner in results modal explains fallback: "Generation failed after 2 attempts. Showing template outline - download the .qmd and edit manually."
- Retry counter visible during healing: "Attempt 1 of 2"
- After fallback, full regeneration (via Regenerate button) is still available - the 2-retry limit only applies to healing, not fresh generation
- Two separate buttons on the results modal: "Heal" and "Regenerate"
- Heal button: opens the healing modal (lightweight - instructions + retry). Sends previous QMD output + healing instructions to LLM for targeted fixing (preserves what was good)
- Regenerate button: reopens the full config modal for a completely fresh generation
- Heal button is ALWAYS visible on results modal - even on successful generation (user can heal cosmetic issues like "fewer bullet points", "make text bigger")
- During healing: loading overlay on preview area, replaced with new preview on completion. If fails, shows error panel

### Claude's Discretion
- Exact YAML validation library/approach in R
- Specific chip labels and which are context-aware vs static
- Loading overlay animation style
- How section headers are extracted from source chunks for the fallback template
- Prompt engineering for the YAML template structure in the system prompt

### Deferred Ideas (OUT OF SCOPE)
None - discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SLIDE-01 | Slide generation prompt includes proper YAML template structure | Improved system prompt with explicit YAML frontmatter template and example structure |
| SLIDE-02 | User can click Regenerate to re-attempt failed slide generation | Existing Regenerate button reopens config modal; needs to also work from error states |
| SLIDE-03 | User can provide specific healing instructions (e.g., "fix YAML", "fix CSS") | New healing modal with chips + free text, `heal_slides()` function |
| SLIDE-04 | System limits healing to 2 retries, then falls back to template YAML | Retry counter in `generation_state`, `build_fallback_qmd()` for template generation |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| yaml | 2.3.10+ | YAML parsing and validation | Base R ecosystem standard for YAML; `yaml::yaml.load()` gives structured errors with line info |
| bslib | 0.8+ | Modal and UI components | Already used in project for all UI |
| shiny | 1.9+ | Reactive framework | Already the project's framework |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| processx | existing | Quarto rendering | Already used for `render_qmd_to_html` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| yaml::yaml.load | Custom regex YAML parser | yaml package provides structured error messages with line numbers; regex would miss edge cases |

**No new dependencies needed** - the `yaml` package is already an indirect dependency through other packages in the project.

## Architecture Patterns

### Current Architecture (slides.R + mod_slides.R)
```
R/
├── slides.R           # Pure functions: build_slides_prompt(), generate_slides(), render_qmd_to_html()
├── mod_slides.R       # Shiny module: UI modals, server logic, download handlers
```

### New Functions to Add

**In `slides.R` (pure functions):**
```r
validate_qmd_yaml()      # Extract YAML frontmatter, parse with yaml package, return errors
build_healing_prompt()    # Build LLM prompt for targeted healing (previous QMD + errors + instructions)
heal_slides()             # Call LLM with healing prompt, validate result, return healed QMD
build_fallback_qmd()      # Generate template QMD from source chunks (title + section headers)
```

**In `mod_slides.R` (Shiny module):**
```r
mod_slides_heal_modal_ui()  # Healing modal: error summary, chips, text input
# Updated mod_slides_results_ui() - add Heal button, error panel, raw output toggle
# Updated mod_slides_server() - healing observers, retry tracking, fallback logic
```

### Pattern: Validation Before Render
```r
validate_qmd_yaml <- function(qmd_content) {
  # 1. Extract YAML frontmatter between --- markers
  # 2. Parse with yaml::yaml.load() in tryCatch
  # 3. Return list(valid = TRUE/FALSE, errors = character(), parsed = list())
  # 4. Errors include line/column info from yaml package error messages
}
```

### Pattern: Healing LLM Call
```r
heal_slides <- function(api_key, model, previous_qmd, errors, instructions, con = NULL, session_id = NULL) {
  # 1. Build healing prompt with previous QMD, error details, user instructions
  # 2. Call chat_completion() (same as generate_slides)
  # 3. Clean up response (strip code fences)
  # 4. Validate YAML of result
  # 5. Return list(qmd, qmd_path, error, validation)
}
```

### Pattern: Context-Aware Chips
```r
get_healing_chips <- function(errors, is_success) {
  # Always-available chips
  chips <- c("Simplify slides", "Fewer bullet points", "Make text bigger")

  if (is_success) {
    # Cosmetic chips for successful generation
    chips <- c(chips, "Add more detail", "Shorten content")
  } else {
    # Error-specific chips
    if (any(grepl("YAML|parse|syntax", errors))) chips <- c("Fix YAML syntax", chips)
    if (any(grepl("CSS|style|format", errors))) chips <- c("Fix CSS formatting", chips)
    if (any(grepl("render|quarto", errors, ignore.case = TRUE))) chips <- c("Fix Quarto formatting", chips)
  }
  chips
}
```

### Anti-Patterns to Avoid
- **Don't re-generate from scratch in heal**: Healing sends previous QMD to LLM for targeted fix, not a fresh generation
- **Don't block on Quarto render for validation**: YAML validation is fast and catches most issues before the slow render step
- **Don't reset retry counter on Regenerate**: Retry counter applies to healing only; Regenerate starts fresh

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing | Regex-based YAML extractor | `yaml::yaml.load()` | Handles edge cases, provides line numbers in errors |
| YAML frontmatter extraction | Custom parser | Regex `^---\n(.+?)\n---` with `regmatches` | Simple, well-known pattern for QMD/Rmd files |
| Modal UI | Custom HTML modals | `bslib::modalDialog()` | Consistent with project patterns, proper Shiny lifecycle |

## Common Pitfalls

### Pitfall 1: YAML Frontmatter May Not Exist
**What goes wrong:** LLM sometimes omits the `---` delimiters entirely
**Why it happens:** Despite prompt instructions, LLMs occasionally produce malformed output
**How to avoid:** `validate_qmd_yaml()` should handle missing frontmatter as a specific error case, not crash
**Warning signs:** `regmatches` returns empty list

### Pitfall 2: yaml::yaml.load Error Messages Are R Conditions
**What goes wrong:** `yaml::yaml.load()` throws errors as R conditions, not structured data
**Why it happens:** The yaml package uses `stop()` with message strings
**How to avoid:** Use `tryCatch()` and parse the error message for line/column info. The yaml package error messages typically contain "line X, column Y" format.
**Warning signs:** Unhandled errors from yaml.load

### Pitfall 3: Code Fence Wrapping in LLM Healing Output
**What goes wrong:** LLM wraps healed output in ```yaml or ```qmd fences
**Why it happens:** LLMs default to code-fenced output in conversational context
**How to avoid:** Same cleanup as `generate_slides()` already does - strip code fences. Also include "Output ONLY valid Quarto markdown" in healing prompt.

### Pitfall 4: Healing Prompt Must Include Full Previous QMD
**What goes wrong:** Partial context leads to LLM generating incomplete healing
**Why it happens:** Without the full previous output, LLM can't do targeted fixes
**How to avoid:** Include complete previous QMD in healing prompt, clearly marked

### Pitfall 5: Retry Counter State Management
**What goes wrong:** Counter persists across regenerations or gets lost on modal close
**Why it happens:** reactiveValues not properly reset
**How to avoid:** Reset `heal_attempts` to 0 when: (a) Regenerate is clicked, (b) new generation succeeds, (c) modal is closed. Only increment on heal attempts.

## Code Examples

### YAML Frontmatter Extraction and Validation
```r
validate_qmd_yaml <- function(qmd_content) {
  # Extract YAML frontmatter
  yaml_match <- regmatches(qmd_content, regexpr("^---\\n(.*?)\\n---", qmd_content, perl = TRUE))

  if (length(yaml_match) == 0 || nchar(yaml_match) == 0) {
    return(list(
      valid = FALSE,
      errors = "No YAML frontmatter found (missing --- delimiters)",
      parsed = NULL
    ))
  }

  # Extract just the YAML content between delimiters
  yaml_text <- sub("^---\\n", "", yaml_match)
  yaml_text <- sub("\\n---$", "", yaml_text)

  # Parse with yaml package
  tryCatch({
    parsed <- yaml::yaml.load(yaml_text)
    list(valid = TRUE, errors = character(0), parsed = parsed)
  }, error = function(e) {
    list(valid = FALSE, errors = e$message, parsed = NULL)
  })
}
```

### Improved System Prompt (SLIDE-01)
```r
system_prompt <- paste0(
  "You are an expert presentation designer. Generate a Quarto RevealJS presentation in valid .qmd format.\n\n",
  "CRITICAL: Your output must start with valid YAML frontmatter using this exact structure:\n",
  "---\n",
  "title: \"Your Title Here\"\n",
  "format:\n",
  "  revealjs:\n",
  "    theme: default\n",
  "---\n\n",
  "Content rules:\n",
  "- Use ## for slide titles (each ## starts a new slide)\n",
  "- Use # for section titles (creates section dividers)\n",
  "- Keep slides concise - max 5-7 bullet points per slide\n",
  if (include_notes) "- Include speaker notes using ::: {.notes} blocks\n" else "",
  "- Output ONLY valid Quarto markdown, no explanations or code fences around the output\n",
  "- Ensure all YAML is properly indented with spaces (not tabs)\n",
  "- Do not include any content before the opening ---"
)
```

### Healing Prompt
```r
build_healing_prompt <- function(previous_qmd, errors, instructions) {
  system_prompt <- paste0(
    "You are an expert Quarto presentation fixer. You receive a broken or imperfect .qmd file ",
    "and specific instructions on what to fix. Make targeted changes while preserving the parts that work.\n\n",
    "Output ONLY the complete fixed .qmd content. No explanations, no code fences.\n",
    "Ensure YAML frontmatter is valid (proper --- delimiters, correct indentation with spaces)."
  )

  error_section <- if (length(errors) > 0 && nchar(paste(errors, collapse = "")) > 0) {
    paste0("\n\nValidation errors found:\n", paste(errors, collapse = "\n"))
  } else {
    ""
  }

  user_prompt <- sprintf(
    "Here is the current .qmd file:\n\n```\n%s\n```\n%s\n\nUser instructions: %s\n\nFix the issues and return the complete corrected .qmd file.",
    previous_qmd,
    error_section,
    instructions
  )

  list(system = system_prompt, user = user_prompt)
}
```

### Fallback Template Generation
```r
build_fallback_qmd <- function(chunks, notebook_name = "Presentation") {
  # Extract potential section headers from chunk content
  # Look for common academic paper section patterns
  sections <- unique(chunks$doc_name)

  # Build minimal valid QMD
  qmd <- paste0(
    "---\n",
    "title: \"", notebook_name, "\"\n",
    "format:\n",
    "  revealjs:\n",
    "    theme: default\n",
    "---\n\n",
    "## Overview\n\n",
    "- Presentation generated from ", length(sections), " source document(s)\n\n"
  )

  # Add section slides from document names
  for (doc in sections) {
    doc_chunks <- chunks[chunks$doc_name == doc, ]
    qmd <- paste0(qmd, "## ", tools::file_path_sans_ext(doc), "\n\n")
    # Extract first line of first chunk as a summary point
    first_content <- trimws(strsplit(doc_chunks$content[1], "\n")[[1]][1])
    if (nchar(first_content) > 0) {
      qmd <- paste0(qmd, "- ", substr(first_content, 1, 100), "\n\n")
    }
  }

  qmd
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Simple "generate and hope" | Validate-then-render with healing loop | This phase | Catches YAML errors before expensive Quarto render |
| Single retry button | Separate Heal vs Regenerate | This phase | Users can do targeted fixes or start fresh |

## Open Questions

1. **yaml package multiline string handling**
   - What we know: yaml::yaml.load handles standard YAML well
   - What's unclear: Edge cases with Quarto-specific YAML extensions (e.g., revealjs sub-options)
   - Recommendation: Validate basic structure only (frontmatter parses, has title/format); don't validate Quarto-specific semantics

## Sources

### Primary (HIGH confidence)
- Codebase analysis of R/slides.R and R/mod_slides.R - current implementation fully read
- Codebase analysis of R/api_openrouter.R - chat_completion and format_chat_messages APIs
- yaml R package documentation - yaml.load error behavior

### Secondary (MEDIUM confidence)
- Quarto RevealJS documentation - frontmatter structure and rendering

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - using existing project dependencies + yaml package
- Architecture: HIGH - follows existing patterns in slides.R / mod_slides.R
- Pitfalls: HIGH - derived from actual codebase analysis

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable domain)
