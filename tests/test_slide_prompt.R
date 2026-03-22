# Test script: Generate slides with current prompt and evaluate output quality
# Tests the full pipeline: LLM output -> strip YAML -> build frontmatter -> assemble
# Usage: Rscript tests/test_slide_prompt.R <api_key> [model_id]

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript tests/test_slide_prompt.R <api_key> [model_id]")
}

api_key <- args[1]
model_id <- if (length(args) >= 2) args[2] else "anthropic/claude-sonnet-4"

source("R/prompt_helpers.R")
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
raw_output <- result$content

cat("=== RAW LLM RESPONSE ===\n")
cat(raw_output, "\n\n")

# Simulate the full generate_slides pipeline
# 1. Clean code fences
raw_output <- gsub("^```(qmd|markdown|yaml)?\\n?", "", raw_output)
raw_output <- gsub("\\n?```$", "", raw_output)
raw_output <- trimws(raw_output)

# 2. Strip any YAML the LLM included
stripped <- strip_llm_yaml(raw_output)
slide_content <- stripped$content
llm_title <- stripped$title

# 3. Build frontmatter programmatically
title <- llm_title %||% "Test Presentation"
frontmatter <- build_qmd_frontmatter(title, theme = "moon")

# 4. Assemble
qmd_output <- paste0(frontmatter, "\n", slide_content)

cat("=== ASSEMBLED QMD (first 30 lines) ===\n")
lines <- strsplit(qmd_output, "\n")[[1]]
cat(paste(head(lines, 30), collapse = "\n"), "\n\n")

# Evaluate
cat("=== EVALUATION ===\n\n")
checks <- list()

# 1. Valid YAML frontmatter
validation <- validate_qmd_yaml(qmd_output)
checks$yaml_valid <- validation$valid
cat("YAML validates:", validation$valid, "\n")
if (!validation$valid) {
  cat("YAML errors:", paste(validation$errors, collapse = "; "), "\n")
}

# 2. Theme is correct
has_correct_theme <- grepl("theme: moon", qmd_output)
checks$correct_theme <- has_correct_theme
cat("Theme is 'moon':", has_correct_theme, "\n")

# 3. CSS present in frontmatter
has_css <- grepl("\\.reveal .slides section", qmd_output)
checks$has_citation_css <- has_css
cat("Citation CSS present:", has_css, "\n")

# 4. Check footnote style - should use ^[text] inline syntax
has_inline_footnote <- grepl("\\^\\[", slide_content)
has_bracket_caret <- grepl("\\[\\^[0-9]+\\]", slide_content)
has_bare_caret <- grepl("\\^[0-9]+[^\\[]", slide_content)
checks$correct_footnotes <- has_inline_footnote && !has_bracket_caret && !has_bare_caret
cat("Uses ^[text] inline footnotes (CORRECT):", has_inline_footnote, "\n")
cat("Uses [^N] reference-style (WRONG):", has_bracket_caret, "\n")
cat("Uses bare ^N (WRONG):", has_bare_caret, "\n")

# 5. Speaker notes
has_notes <- grepl(":::\\s*\\{.notes\\}", slide_content)
checks$speaker_notes <- has_notes
cat("Has ::: {.notes} blocks:", has_notes, "\n")

# 6. Slide separators
has_slides <- grepl("(^|\\n)## ", slide_content)
checks$slide_headers <- has_slides
cat("Has ## slide headers:", has_slides, "\n")

# 7. No code fences wrapping
starts_with_fence <- grepl("^```", slide_content)
checks$no_code_fence <- !starts_with_fence
cat("No wrapping code fence:", !starts_with_fence, "\n")

# 8. LLM did NOT output YAML (followed instructions)
llm_had_yaml <- !is.null(stripped$title)
checks$llm_no_yaml <- !llm_had_yaml
cat("LLM omitted YAML (followed instruction):", !llm_had_yaml, "\n")

# Summary
passed <- sum(unlist(checks))
total <- length(checks)
cat("\n=== SCORE:", passed, "/", total, "===\n")

if (!checks$correct_footnotes) {
  cat("\nFAILED: Footnote style.\n")
  inline_matches <- regmatches(slide_content, gregexpr("\\^\\[[^]]+\\]", slide_content))[[1]]
  bracket_caret_matches <- regmatches(slide_content, gregexpr("\\[\\^[0-9]+\\]", slide_content))[[1]]
  bare_caret_matches <- regmatches(slide_content, gregexpr("\\^[0-9]+", slide_content))[[1]]
  if (length(inline_matches) > 0) cat("  ^[text] (correct):", length(inline_matches), "instances\n")
  if (length(bracket_caret_matches) > 0) cat("  [^N] (wrong):", paste(bracket_caret_matches, collapse = ", "), "\n")
  if (length(bare_caret_matches) > 0) cat("  ^N (wrong):", paste(bare_caret_matches, collapse = ", "), "\n")
}

if (llm_had_yaml) {
  cat("\nNOTE: LLM included YAML despite instructions — stripped and rebuilt. Title extracted:", llm_title, "\n")
}
