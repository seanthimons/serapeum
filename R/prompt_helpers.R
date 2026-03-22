# prompt_helpers.R
# CRUD helpers and PROMPT_DEFAULTS registry for the prompt editing feature.
# All functions take a DBI connection as the first argument.

# ---------------------------------------------------------------------------
# PROMPT_DEFAULTS — hardcoded default text for all 11 AI preset slugs
# Extracted from R/rag.R (quick presets lines 158-161, deep presets) and R/slides.R
# ---------------------------------------------------------------------------

PROMPT_DEFAULTS <- list(
  # Quick presets (from rag.R generate_preset list, lines 158-161)
  summarize = "Provide a comprehensive summary of all the documents. Highlight the main themes, key findings, and important conclusions. Organize your summary with clear sections.",

  keypoints = "Extract the key points from these documents as a bulleted list. Focus on the most important facts, findings, arguments, and conclusions. Group related points together.",

  studyguide = "Create a study guide based on these documents. Include:\n1. Key concepts and definitions\n2. Important facts and figures\n3. Main arguments and their supporting evidence\n4. Potential exam questions with brief answers",

  outline = "Create a structured outline of the main topics covered in these documents. Use hierarchical headings (I, A, 1, a) to organize the content logically. Include brief descriptions under each heading.",

  # Deep presets — editable portions only (role preamble and CITATION RULES excluded)

  # conclusions: from rag.R lines 385-389 (task instructions only, no role line, no CITATION/OUTPUT FORMAT blocks)
  conclusions = "1. Summarize the key conclusions across the provided research sources\n2. Identify common themes, agreements, and divergent positions\n\nIMPORTANT: Base your synthesis ONLY on the provided sources. Do not invent findings or cite sources not provided. If sources conflict, note the disagreement explicitly.",

  # overview: from rag.R lines 551-564 (task instruction portion, no role line, no CITATION RULES block)
  # The %s placeholder for depth_instruction is kept as-is for sprintf() in the generator
  overview = "Generate an Overview of the provided research sources.\nThe Overview must have exactly two sections:\n\n## Summary\n%s\nCover main themes, key findings, and important conclusions.\nBase your summary ONLY on the provided sources.\n\n## Key Points\nOrganize key points under thematic subheadings in this order: Background/Context, Methodology, Findings/Results, Limitations, Future Directions/Gaps.\nEach subheading should contain 3-5 bullet points.\nDo not use a flat bullet list - group all related points under their subheading.\n\nIMPORTANT: Base all content ONLY on the provided sources. Do not invent findings.",

  # research_questions: from rag.R lines 813-833 (INSTRUCTIONS through end, no role line)
  # OUTPUT FORMAT and SCALING blocks are included as they are substantive instructions
  research_questions = "INSTRUCTIONS:\n1. Analyze the provided research sources to identify gaps, contradictions, and unexplored areas\n2. Generate research questions that address the most significant gaps\n3. For each question, provide a 2-3 sentence rationale citing specific papers by author name and year\n4. Use an appropriate research framework internally (PICO for clinical/health topics, PEO for qualitative, SPIDER for mixed methods, or freeform for other domains) but do NOT label or mention the framework in your output\n5. Group questions by gap type (methodological, population/sample, temporal, theoretical, etc.)\n6. Prioritize the strongest/most significant gaps; vary gap types when possible\n\nOUTPUT FORMAT:\n- Numbered list of questions, each followed by an indented rationale\n- No introductory paragraph or scope note\n- Each rationale MUST name specific papers with page numbers: 'Smith et al. (2023, p.14) found that...'\n- Each rationale MUST include page numbers where available: Author et al. (Year, p.X)\n- When no page number is available (abstract-only source): Author et al. (Year, abstract)\n- When a gap spans multiple papers, name ALL relevant papers\n\nSCALING:\n- For collections of 2-3 papers: generate 3-4 questions\n- For collections of 5+ papers: generate 5-7 questions\n\nIMPORTANT: Base analysis ONLY on the provided sources. Do not invent findings. Every claim in a rationale must trace to a specific source.",

  # lit_review: from rag.R lines 1040-1053 (COLUMNS through end, no role line)
  lit_review = paste0(
    "COLUMNS (exactly these, in this order):\n",
    "| Author/Year | Methodology | Sample | Key Findings | Limitations |\n\n",
    "RULES:\n",
    "- One row per paper, ordered by most recent first\n",
    "- Author/Year: Use the exact label from the paper delimiter (e.g., 'Smith et al. (2023)')\n",
    "- Each cell: brief phrases (2-5 words), NOT full sentences\n",
    "- Key Findings: single consolidated statement per paper, no bullet points\n",
    "- For N/A columns: use contextual notes (e.g., 'Theoretical framework', 'Systematic review') instead of literal 'N/A'\n",
    "- Output ONLY the markdown table followed by a Sources section. No introduction before the table.\n",
    "- Every line of the table must have exactly 6 pipe characters (| col1 | col2 | col3 | col4 | col5 |)\n\n",
    "FOOTNOTES:\n",
    "After the table, add a '### Sources' section with numbered footnotes linking key findings to specific page numbers.\n",
    "Format: [1] Author (Year), p.X \u2014 brief finding description\n",
    "Only include footnotes for Key Findings column entries."
  ),

  # methodology: from rag.R lines 1244-1261 (COLUMNS through end, no role line)
  methodology = paste0(
    "COLUMNS (exactly these, in this order):\n",
    "| Paper | Study Design | Data Sources | Sample Characteristics | Statistical Methods | Tools/Instruments |\n\n",
    "RULES:\n",
    "- One row per paper, ordered by most recent first\n",
    "- Paper: Use the exact label from the paper delimiter (e.g., 'Smith et al. (2023)')\n",
    "- Each cell: brief phrases (2-5 words), NOT full sentences\n",
    "- Study Design: experimental, quasi-experimental, observational, case study, systematic review, meta-analysis, qualitative, mixed methods, etc.\n",
    "- Data Sources: specify databases, surveys, instruments, or datasets used\n",
    "- Sample Characteristics: population type, size (n=X), demographics\n",
    "- Statistical Methods: specific tests or analytical approaches (e.g., regression, ANOVA, thematic analysis)\n",
    "- Tools/Instruments: software, scales, measurement tools\n",
    "- For papers with no clear methodology: use 'Not described' or contextual notes (e.g., 'Theoretical framework')\n",
    "- Output ONLY the markdown table followed by a Sources section. No introduction before the table.\n",
    "- Every line must have exactly 7 pipe characters\n\n",
    "FOOTNOTES:\n",
    "After the table, add a '### Sources' section with numbered footnotes linking methodology details to specific page numbers.\n",
    "Format: [1] Author (Year), p.X \u2014 methodology detail\n",
    "Include footnotes for Study Design and Statistical Methods columns."
  ),

  # gap_analysis: from rag.R lines 1473-1492 (OUTPUT FORMAT through end, no role line)
  gap_analysis = paste0(
    "OUTPUT FORMAT:\n",
    "Use these 5 section headings (always show all 5):\n",
    "## Summary\n",
    "## Methodological Gaps\n",
    "## Geographic Gaps\n",
    "## Population Gaps\n",
    "## Measurement Gaps\n",
    "## Theoretical Gaps\n\n",
    "RULES:\n",
    "- Write in narrative prose, not bullet points\n",
    "- Weave inline citations with page numbers: 'Smith et al. (2020, p.14) found...', 'contradicting Johnson (2018, p.8)'\n",
    "- When citing abstracts without page numbers, use: 'Smith et al. (2020, abstract)'\n",
    "- When no gaps found in a category: 'No significant [type] gaps identified across the reviewed papers.'\n",
    "- Actively search for contradictions between papers\n",
    "- Format contradictions as visually separated blockquotes on their own line:\n",
    "  > **Contradictory finding:** Jones (2021) reported X while Lee (2022) found Y\n",
    "- Integrate contradictions within their relevant gap category (e.g., methodological contradictions go in Methodological Gaps)\n",
    "- Base analysis ONLY on the provided sources\n",
    "- Summary: 2-3 sentences capturing the corpus's main themes and overall gap landscape\n",
    "- Each gap section: identify specific absent elements, underrepresented contexts, or unresolved questions"
  ),

  # slides: from slides.R lines 92-100 (content rules block only, no system prompt preamble)
  slides = paste0(
    "- Use ## for individual slide titles (each ## starts a new slide)\n",
    "- Use # for section titles (creates section dividers)\n",
    "- Keep slides concise - max 5-7 bullet points per slide\n",
    "- Always leave a blank line between a heading and the first bullet point\n",
    "- Each bullet point must be on its own line starting with - (not inline)\n",
    "- Output ONLY valid Quarto markdown slide content, no explanations or code fences\n",
    "- Do NOT include any YAML frontmatter, --- delimiters, title:, format:, theme:, or css:"
  )
)

# ---------------------------------------------------------------------------
# PRESET_GROUPS — organizes slugs into UI groups
# ---------------------------------------------------------------------------

PRESET_GROUPS <- list(
  Quick = c("summarize", "keypoints", "studyguide", "outline"),
  Deep  = c("overview", "conclusions", "research_questions",
            "lit_review", "methodology", "gap_analysis", "slides")
)

# ---------------------------------------------------------------------------
# PRESET_DISPLAY_NAMES — human-readable labels for UI
# ---------------------------------------------------------------------------

PRESET_DISPLAY_NAMES <- c(
  summarize          = "Summarize",
  keypoints          = "Key Points",
  studyguide         = "Study Guide",
  outline            = "Outline",
  overview           = "Overview",
  conclusions        = "Conclusions",
  research_questions = "Research Questions",
  lit_review         = "Literature Review",
  methodology        = "Methodology Extractor",
  gap_analysis       = "Gap Analysis",
  slides             = "Slides"
)

# ---------------------------------------------------------------------------
# CRUD functions
# ---------------------------------------------------------------------------

#' List all version dates for a preset slug, most recent first
#'
#' @param con DBI connection
#' @param preset_slug Character. One of the 11 preset slugs.
#' @return Character vector of ISO date strings, descending order. Empty if none.
list_prompt_versions <- function(con, preset_slug) {
  result <- DBI::dbGetQuery(
    con,
    "SELECT version_date FROM prompt_versions WHERE preset_slug = ? ORDER BY version_date DESC",
    params = list(preset_slug)
  )
  as.character(result$version_date)
}

#' Get the prompt text for a specific preset slug and date
#'
#' @param con DBI connection
#' @param preset_slug Character. Preset slug.
#' @param version_date Character. ISO date string (e.g. "2026-03-21").
#' @return Character string, or NULL if not found.
get_prompt_version <- function(con, preset_slug, version_date) {
  result <- DBI::dbGetQuery(
    con,
    "SELECT prompt_text FROM prompt_versions WHERE preset_slug = ? AND version_date = ?",
    params = list(preset_slug, version_date)
  )
  if (nrow(result) == 0) return(NULL)
  result$prompt_text[[1]]
}

#' Get the most recent custom prompt text for a slug
#'
#' @param con DBI connection
#' @param preset_slug Character. Preset slug.
#' @return Character string of most recent custom text, or NULL if no custom versions.
get_active_prompt <- function(con, preset_slug) {
  result <- DBI::dbGetQuery(
    con,
    "SELECT prompt_text FROM prompt_versions WHERE preset_slug = ? ORDER BY version_date DESC LIMIT 1",
    params = list(preset_slug)
  )
  if (nrow(result) == 0) return(NULL)
  result$prompt_text[[1]]
}

#' Save (or replace) a prompt version for today's date
#'
#' Uses UPSERT so calling twice on the same day replaces the existing row.
#'
#' @param con DBI connection
#' @param preset_slug Character. Preset slug.
#' @param prompt_text Character. The custom prompt text to save.
#' @return invisible(TRUE)
save_prompt_version <- function(con, preset_slug, prompt_text) {
  tryCatch({
    DBI::dbExecute(
      con,
      "INSERT OR REPLACE INTO prompt_versions (preset_slug, version_date, prompt_text) VALUES (?, ?, ?)",
      params = list(preset_slug, as.character(Sys.Date()), prompt_text)
    )
    invisible(TRUE)
  }, error = function(e) {
    stop(sprintf("Failed to save prompt version: %s", e$message), call. = FALSE)
  })
}

#' Delete all custom versions for a preset slug (reset to hardcoded default)
#'
#' @param con DBI connection
#' @param preset_slug Character. Preset slug.
#' @return invisible(TRUE)
reset_prompt_to_default <- function(con, preset_slug) {
  tryCatch({
    DBI::dbExecute(
      con,
      "DELETE FROM prompt_versions WHERE preset_slug = ?",
      params = list(preset_slug)
    )
    invisible(TRUE)
  }, error = function(e) {
    stop(sprintf("Failed to reset prompt: %s", e$message), call. = FALSE)
  })
}

#' Get the effective prompt for a preset slug
#'
#' Returns the most recent custom version if one exists, otherwise falls back
#' to the hardcoded default in PROMPT_DEFAULTS.
#'
#' @param con DBI connection
#' @param preset_slug Character. Preset slug.
#' @return Character string.
get_effective_prompt <- function(con, preset_slug) {
  active <- get_active_prompt(con, preset_slug)
  if (!is.null(active)) return(active)
  default <- PROMPT_DEFAULTS[[preset_slug]]
  if (!is.null(default)) return(default)
  warning(sprintf("Unknown preset slug: '%s'", preset_slug))
  ""
}
