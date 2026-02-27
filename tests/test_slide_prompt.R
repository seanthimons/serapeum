# Test script: Generate slides with current prompt and evaluate output quality
# Usage: Rscript tests/test_slide_prompt.R <api_key> [model_id]

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript tests/test_slide_prompt.R <api_key> [model_id]")
}

api_key <- args[1]
model_id <- if (length(args) >= 2) args[2] else "anthropic/claude-sonnet-4"

source("R/slides.R")
source("R/api_openrouter.R")

# Synthetic academic chunks
chunks <- data.frame(
  content = c(
    "Antimicrobial resistance (AMR) is a growing global health threat. The WHO estimates that by 2050, AMR could cause 10 million deaths annually. Key drivers include overuse of antibiotics in agriculture and healthcare. Recent studies show that machine learning models can predict resistance patterns with 87% accuracy using genomic data.",
    "A systematic review of 42 studies found that rapid diagnostic tests (RDTs) reduce unnecessary antibiotic prescriptions by 30-50%. The most effective interventions combined RDTs with antimicrobial stewardship programs. Cost-effectiveness analysis shows $2.3 saved per $1 invested in stewardship.",
    "Novel antimicrobial peptides (AMPs) derived from amphibian skin secretions show promising activity against MRSA and VRE. In vitro studies demonstrate MIC values of 2-8 ug/mL. However, clinical translation remains challenging due to peptide stability and manufacturing costs."
  ),
  doc_name = c("WHO_AMR_Report_2024.pdf", "RDT_Systematic_Review.pdf", "Novel_AMPs_Study.pdf"),
  page_number = c(12, 5, 23),
  stringsAsFactors = FALSE
)

# Build the prompt exactly as the app does
options <- list(
  length = "short",
  audience = "academic",
  citation_style = "footnotes",
  include_notes = TRUE,
  custom_instructions = ""
)

prompt <- build_slides_prompt(chunks, options)

cat("=== SYSTEM PROMPT ===\n")
cat(prompt$system, "\n\n")
cat("=== USER PROMPT ===\n")
cat(prompt$user, "\n\n")

# Send to LLM
messages <- list(
  list(role = "system", content = prompt$system),
  list(role = "user", content = prompt$user)
)

cat("=== CALLING MODEL:", model_id, "===\n\n")
result <- chat_completion(api_key, model_id, messages)
qmd_output <- result$content

cat("=== LLM RESPONSE ===\n")
cat(qmd_output, "\n\n")

# Evaluate output
cat("=== EVALUATION ===\n\n")

checks <- list()

# 1. Valid YAML frontmatter
has_yaml <- grepl("^---\\s*\\n", qmd_output)
checks$yaml_present <- has_yaml
cat("YAML frontmatter present:", has_yaml, "\n")

# 2. Check footnote style - should use ^[text] inline syntax
has_inline_footnote <- grepl("\\^\\[", qmd_output)
has_bracket_caret <- grepl("\\[\\^[0-9]+\\]", qmd_output)
has_bare_caret <- grepl("\\^[0-9]+[^\\[]", qmd_output)
checks$correct_footnotes <- has_inline_footnote && !has_bracket_caret && !has_bare_caret
cat("Uses ^[text] inline footnotes (CORRECT):", has_inline_footnote, "\n")
cat("Uses [^N] reference-style (WRONG):", has_bracket_caret, "\n")
cat("Uses bare ^N (WRONG):", has_bare_caret, "\n")

# 3. Speaker notes
has_notes <- grepl(":::\\s*\\{.notes\\}", qmd_output)
checks$speaker_notes <- has_notes
cat("Has ::: {.notes} blocks:", has_notes, "\n")

# 4. Slide separators (check for ## at start of any line)
has_slides <- grepl("(^|\\n)## ", qmd_output)
checks$slide_headers <- has_slides
cat("Has ## slide headers:", has_slides, "\n")

# 5. No custom theme/css in YAML (app injects these)
has_theme_in_yaml <- grepl("theme:", qmd_output) && grepl("---[\\s\\S]*theme:[\\s\\S]*---", qmd_output, perl = TRUE)
has_css_in_yaml <- grepl("---[\\s\\S]*css:[\\s\\S]*---", qmd_output, perl = TRUE)
checks$no_custom_styling <- !has_theme_in_yaml && !has_css_in_yaml
cat("No custom theme/css in YAML:", !has_theme_in_yaml && !has_css_in_yaml, "\n")

# 6. No code fences wrapping entire output
starts_with_fence <- grepl("^```", qmd_output)
checks$no_code_fence <- !starts_with_fence
cat("No wrapping code fence:", !starts_with_fence, "\n")

# 7. YAML validation
validation <- validate_qmd_yaml(qmd_output)
checks$yaml_valid <- validation$valid
cat("YAML validates:", validation$valid, "\n")
if (!validation$valid) {
  cat("YAML errors:", paste(validation$errors, collapse = "; "), "\n")
}

# Summary
passed <- sum(unlist(checks))
total <- length(checks)
cat("\n=== SCORE:", passed, "/", total, "===\n")

if (!checks$correct_footnotes) {
  cat("\nFAILED: Footnote style.\n")
  # Extract footnote patterns found
  inline_matches <- regmatches(qmd_output, gregexpr("\\^\\[[^]]+\\]", qmd_output))[[1]]
  bracket_caret_matches <- regmatches(qmd_output, gregexpr("\\[\\^[0-9]+\\]", qmd_output))[[1]]
  bare_caret_matches <- regmatches(qmd_output, gregexpr("\\^[0-9]+", qmd_output))[[1]]
  if (length(inline_matches) > 0) cat("  ^[text] (correct):", length(inline_matches), "instances\n")
  if (length(bracket_caret_matches) > 0) cat("  [^N] (wrong):", paste(bracket_caret_matches, collapse = ", "), "\n")
  if (length(bare_caret_matches) > 0) cat("  ^N (wrong):", paste(bare_caret_matches, collapse = ", "), "\n")
}

if (!checks$no_custom_styling) {
  cat("\nFAILED: LLM added custom theme/css to YAML (app injects these post-generation).\n")
}
