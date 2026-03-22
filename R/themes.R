# R/themes.R
# Theme helper functions for RevealJS/Quarto slide themes.
# Provides: BUILTIN_THEME_SWATCHES, parse_scss_swatches, validate_scss_file,
#           list_custom_themes, build_theme_choices_df,
#           CURATED_FONTS, parse_scss_colors_full, generate_custom_scss

# ── Curated font list ─────────────────────────────────────────────────────────

#' Named list of curated Google Fonts grouped by category for the font selector.
#' Each group is a character vector of font names.
CURATED_FONTS <- list(
  "Sans-serif" = c("Source Sans Pro", "Lato", "Fira Sans", "Roboto", "Open Sans"),
  "Serif"      = c("Merriweather", "PT Serif", "Roboto Slab", "Playfair Display"),
  "Monospace"  = c("IBM Plex Mono", "Fira Code")
)

# ── Built-in theme swatches ───────────────────────────────────────────────────

#' Named list of 11 RevealJS built-in theme colour swatches.
#' Each entry is list(bg, fg, accent) with hex colour strings.
BUILTIN_THEME_SWATCHES <- list(
  default    = list(bg = "#FFFFFF", fg = "#000000", accent = "#157efb"),
  beige      = list(bg = "#F7F3DE", fg = "#333333", accent = "#8B743D"),
  blood      = list(bg = "#160a0a", fg = "#EEEEE2", accent = "#AA2233"),
  dark       = list(bg = "#111111", fg = "#EEEEE2", accent = "#E7AD52"),
  league     = list(bg = "#1C1E20", fg = "#EEEEE2", accent = "#F0DB4F"),
  moon       = list(bg = "#002b36", fg = "#93a1a1", accent = "#268bd2"),
  night      = list(bg = "#1C1E20", fg = "#EEEEE2", accent = "#F28705"),
  serif      = list(bg = "#F0F1EB", fg = "#333333", accent = "#51483D"),
  simple     = list(bg = "#FFFFFF", fg = "#000000", accent = "#007CAD"),
  sky        = list(bg = "#F2F6F9", fg = "#333333", accent = "#3B759E"),
  solarized  = list(bg = "#FDF6E3", fg = "#333333", accent = "#259286")
)

# ── SCSS colour parsing ───────────────────────────────────────────────────────

#' Extract bg/fg/accent hex colours from an SCSS defaults block.
#'
#' @param scss_text Character string with SCSS file contents.
#' @return Named list with bg, fg, accent hex strings (defaults applied for missing).
parse_scss_swatches <- function(scss_text) {
  fallback <- list(bg = "#FFFFFF", fg = "#000000", accent = "#157efb")

  if (!nzchar(scss_text)) return(fallback)

  # Extract the scss:defaults block (between first marker and next /*-- or EOF)
  defaults_match <- regexpr(
    "(?s)/\\*-- scss:defaults --\\*/(.*?)(?=/\\*--|$)",
    scss_text,
    perl = TRUE
  )

  if (defaults_match == -1) return(fallback)

  defaults_block <- regmatches(scss_text, defaults_match)

  # Build variable resolution table: $varname -> #hexvalue
  # Match patterns like: $some-var: #AABBCC;
  var_pattern <- "\\$([A-Za-z0-9_-]+):\\s*(#[0-9A-Fa-f]{6,8})\\s*;"
  var_matches <- gregexpr(var_pattern, defaults_block, perl = TRUE)
  resolution_table <- list()

  if (var_matches[[1]][1] != -1) {
    all_matches <- regmatches(defaults_block, var_matches)[[1]]
    for (m in all_matches) {
      parts <- regmatches(m, regexec(var_pattern, m, perl = TRUE))[[1]]
      # parts[1] = full match, parts[2] = varname, parts[3] = hex
      resolution_table[[parts[2]]] <- parts[3]
    }
  }

  # Resolve a SCSS value: either a direct hex or a variable reference
  resolve_value <- function(value) {
    value <- trimws(value)
    if (grepl("^#[0-9A-Fa-f]{6,8}$", value)) {
      return(toupper(value))
    }
    if (grepl("^\\$", value)) {
      varname <- sub("^\\$", "", value)
      if (!is.null(resolution_table[[varname]])) {
        return(toupper(resolution_table[[varname]]))
      }
    }
    NULL
  }

  # Look up target variables in priority order
  extract_color <- function(var_names) {
    for (vname in var_names) {
      # Match $vname: <value>; allowing for variable references too
      pattern <- paste0("\\$", vname, ":\\s*([^;]+);")
      m <- regexpr(pattern, defaults_block, perl = TRUE)
      if (m != -1) {
        full <- regmatches(defaults_block, m)
        parts <- regmatches(full, regexec(pattern, full, perl = TRUE))[[1]]
        if (length(parts) >= 2) {
          resolved <- resolve_value(parts[2])
          if (!is.null(resolved)) return(resolved)
        }
      }
    }
    NULL
  }

  bg     <- extract_color(c("body-bg", "backgroundColor"))
  fg     <- extract_color(c("body-color", "mainColor"))
  accent <- extract_color(c("link-color", "linkColor", "presentation-heading-color"))

  list(
    bg     = if (!is.null(bg))     bg     else fallback$bg,
    fg     = if (!is.null(fg))     fg     else fallback$fg,
    accent = if (!is.null(accent)) accent else fallback$accent
  )
}

# ── SCSS file validation ──────────────────────────────────────────────────────

#' Check whether SCSS text contains both required Quarto section markers.
#'
#' @param scss_text Character string.
#' @return TRUE if both markers present, FALSE otherwise.
validate_scss_file <- function(scss_text) {
  if (!nzchar(scss_text)) return(FALSE)
  has_defaults <- grepl("/*-- scss:defaults --*/", scss_text, fixed = TRUE)
  has_rules    <- grepl("/*-- scss:rules --*/",    scss_text, fixed = TRUE)
  has_defaults && has_rules
}

# ── Custom theme directory scanning ──────────────────────────────────────────

#' List custom themes from a directory of .scss files.
#'
#' @param themes_dir Path to directory containing .scss files.
#' @return List of lists, each with: filename, label, bg, fg, accent.
#'   Returns empty list() if directory missing or no .scss files found.
list_custom_themes <- function(themes_dir = "data/themes") {
  if (!dir.exists(themes_dir)) return(list())

  scss_files <- list.files(themes_dir, pattern = "\\.scss$", full.names = FALSE)
  if (length(scss_files) == 0) return(list())

  lapply(scss_files, function(fname) {
    fpath  <- file.path(themes_dir, fname)
    text   <- tryCatch(
      paste(readLines(fpath, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    swatches <- parse_scss_swatches(text)
    list(
      filename = fname,
      label    = tools::file_path_sans_ext(fname),
      bg       = swatches$bg,
      fg       = swatches$fg,
      accent   = swatches$accent
    )
  })
}

# ── Theme choices data frame ──────────────────────────────────────────────────

#' Build a data.frame of theme choices for the UI picker.
#'
#' @param custom_themes List of custom theme metadata (from list_custom_themes).
#' @return data.frame with columns: value, label, bg, fg, accent, group.
build_theme_choices_df <- function(custom_themes = list()) {
  # Built-in rows
  builtin_rows <- lapply(names(BUILTIN_THEME_SWATCHES), function(name) {
    sw <- BUILTIN_THEME_SWATCHES[[name]]
    data.frame(
      value  = name,
      label  = paste0(toupper(substr(name, 1, 1)), substr(name, 2, nchar(name))),
      bg     = sw$bg,
      fg     = sw$fg,
      accent = sw$accent,
      group  = "builtin",
      stringsAsFactors = FALSE
    )
  })
  builtin_df <- do.call(rbind, builtin_rows)

  if (length(custom_themes) == 0) return(builtin_df)

  # Custom rows
  custom_rows <- lapply(custom_themes, function(th) {
    data.frame(
      value  = th$filename,
      label  = th$label,
      bg     = th$bg,
      fg     = th$fg,
      accent = th$accent,
      group  = "custom",
      stringsAsFactors = FALSE
    )
  })
  custom_df <- do.call(rbind, custom_rows)

  rbind(builtin_df, custom_df)
}

# ── Extended colour + font parsing ────────────────────────────────────────────

#' Extract bg, fg, accent, link, and font from an SCSS defaults block.
#'
#' Extends parse_scss_swatches to also capture $linkColor/$link-color and
#' $mainFont/$presentation-heading-font. Returns a 5-element named list with
#' sensible fallbacks for any missing variables.
#'
#' @param scss_text Character string with SCSS file contents.
#' @return Named list: bg, fg, accent, link, font (all character).
parse_scss_colors_full <- function(scss_text) {
  fallback <- list(
    bg     = "#FFFFFF",
    fg     = "#000000",
    accent = "#157efb",
    link   = "#157efb",
    font   = "Source Sans Pro"
  )

  if (!nzchar(scss_text)) return(fallback)

  # Extract the scss:defaults block
  defaults_match <- regexpr(
    "(?s)/\\*-- scss:defaults --\\*/(.*?)(?=/\\*--|$)",
    scss_text,
    perl = TRUE
  )
  if (defaults_match == -1) return(fallback)
  defaults_block <- regmatches(scss_text, defaults_match)

  # Build variable resolution table for hex literals
  var_pattern <- "\\$([A-Za-z0-9_-]+):\\s*(#[0-9A-Fa-f]{6,8})\\s*;"
  var_matches <- gregexpr(var_pattern, defaults_block, perl = TRUE)
  resolution_table <- list()
  if (var_matches[[1]][1] != -1) {
    all_matches <- regmatches(defaults_block, var_matches)[[1]]
    for (m in all_matches) {
      parts <- regmatches(m, regexec(var_pattern, m, perl = TRUE))[[1]]
      resolution_table[[parts[2]]] <- parts[3]
    }
  }

  resolve_value <- function(value) {
    value <- trimws(value)
    if (grepl("^#[0-9A-Fa-f]{6,8}$", value)) return(toupper(value))
    if (grepl("^\\$", value)) {
      varname <- sub("^\\$", "", value)
      if (!is.null(resolution_table[[varname]])) return(toupper(resolution_table[[varname]]))
    }
    NULL
  }

  extract_color <- function(var_names) {
    for (vname in var_names) {
      pattern <- paste0("\\$", vname, ":\\s*([^;]+);")
      m <- regexpr(pattern, defaults_block, perl = TRUE)
      if (m != -1) {
        full  <- regmatches(defaults_block, m)
        parts <- regmatches(full, regexec(pattern, full, perl = TRUE))[[1]]
        if (length(parts) >= 2) {
          resolved <- resolve_value(parts[2])
          if (!is.null(resolved)) return(resolved)
        }
      }
    }
    NULL
  }

  # Extract first font name (unquoted) from $mainFont or $presentation-heading-font
  extract_font <- function() {
    font_pattern <- "\\$(?:mainFont|presentation-heading-font):\\s*\"?([^\";\n,]+)\"?"
    m <- regexpr(font_pattern, defaults_block, perl = TRUE)
    if (m == -1) return(NULL)
    full  <- regmatches(defaults_block, m)
    parts <- regmatches(full, regexec(font_pattern, full, perl = TRUE))[[1]]
    if (length(parts) >= 2) trimws(parts[2]) else NULL
  }

  bg     <- extract_color(c("body-bg", "backgroundColor"))
  fg     <- extract_color(c("body-color", "mainColor"))
  accent <- extract_color(c("accentColor", "presentation-heading-color", "link-color", "linkColor"))
  link   <- extract_color(c("linkColor", "link-color"))
  font   <- extract_font()

  list(
    bg     = if (!is.null(bg))     bg     else fallback$bg,
    fg     = if (!is.null(fg))     fg     else fallback$fg,
    accent = if (!is.null(accent)) accent else fallback$accent,
    link   = if (!is.null(link))   link   else fallback$link,
    font   = if (!is.null(font))   font   else fallback$font
  )
}

# ── Custom SCSS file generation ───────────────────────────────────────────────

#' Write a minimal 5-variable Quarto/RevealJS .scss file to disk.
#'
#' The filename is derived from \code{name} by replacing any characters that are
#' not alphanumeric, underscores, or hyphens with \code{"-"}.  An existing file
#' with the same sanitized name is silently overwritten.
#'
#' @param name         Human-readable theme name (used to derive the filename).
#' @param bg_color     Background colour hex string (e.g. "#FFFFFF").
#' @param text_color   Body text colour hex string.
#' @param accent_color Accent / heading colour hex string.
#' @param link_color   Link colour hex string.
#' @param font_name    Primary font family name (e.g. "Source Sans Pro").
#' @param themes_dir   Directory to write the .scss file into (default: "data/themes").
#' @return The file path on success, NULL on any error.
generate_custom_scss <- function(name, bg_color, text_color, accent_color, link_color,
                                  font_name, themes_dir = "data/themes") {
  safe_name <- gsub("[^a-zA-Z0-9_-]", "-", name)
  file_path <- file.path(themes_dir, paste0(safe_name, ".scss"))

  # Wrap font name in double quotes so multi-word families work in SCSS
  font_value <- paste0('"', font_name, '", sans-serif')

  scss_content <- paste0(
    "/*-- scss:defaults --*/\n",
    "\n",
    "$backgroundColor: ", bg_color,    ";\n",
    "$mainColor: ",       text_color,   ";\n",
    "$linkColor: ",       link_color,   ";\n",
    "$accentColor: ",     accent_color, ";\n",
    "$mainFont: ",        font_value,   ";\n",
    "\n",
    "/*-- scss:rules --*/\n",
    "\n",
    "/* Generated by Serapeum theme customizer */\n",
    ".reveal h1, .reveal h2, .reveal h3 {\n",
    "  color: $accentColor;\n",
    "}\n"
  )

  tryCatch({
    writeLines(scss_content, file_path)
    file_path
  }, error = function(e) NULL)
}

# ── JSON extraction from LLM response ────────────────────────────────────────

#' Extract a JSON object from a markdown ```json ... ``` fence block.
#'
#' Uses a permissive regex that handles whitespace variations in the fence
#' markers (no newline, extra spaces, \r\n). Returns the parsed list or
#' NULL if extraction or parsing fails.
#'
#' @param llm_response Character string — the raw LLM response text.
#' @return Parsed list from JSON, or NULL on failure.
extract_theme_json <- function(llm_response) {
  # Permissive regex: ```json optionally followed by whitespace/newline, then
  # capture everything up to the closing ``` (non-greedy, dotall mode).
  m <- regexpr("```json\\s*(\\{.*?\\})\\s*```", llm_response, perl = TRUE, useBytes = FALSE)
  if (m == -1) {
    # Try dotall mode for multi-line JSON
    m <- regexpr("(?s)```json\\s*(\\{.*?\\})\\s*```", llm_response, perl = TRUE)
  }
  if (m == -1) return(NULL)
  matched <- regmatches(llm_response, m)
  # Strip the fence markers
  json_str <- sub("^```json\\s*", "", matched)
  json_str <- sub("\\s*```$", "", json_str)
  tryCatch(jsonlite::fromJSON(json_str, simplifyVector = FALSE), error = function(e) NULL)
}

# ── Hex colour validation ─────────────────────────────────────────────────────

#' Validate that all 4 colour fields in a theme list are valid 6-digit hex.
#'
#' @param theme_list Named list with expected keys: backgroundColor, mainColor,
#'   accentColor, linkColor.
#' @return Character vector of invalid field names (empty if all valid).
validate_theme_colors <- function(theme_list) {
  fields <- c("backgroundColor", "mainColor", "accentColor", "linkColor")
  is_valid_hex <- function(v) {
    is.character(v) && length(v) == 1 && grepl("^#[0-9A-Fa-f]{6}$", v)
  }
  bad <- fields[!vapply(fields, function(f) {
    val <- theme_list[[f]]
    if (is.null(val)) return(FALSE)
    is_valid_hex(val)
  }, logical(1))]
  bad
}

# ── Font validation with fallback ─────────────────────────────────────────────

#' Validate a font name against CURATED_FONTS, falling back to Source Sans Pro.
#'
#' Applies trimws() and case-insensitive matching as safety nets.
#'
#' @param font_name Character string — font name from LLM response.
#' @return list(font = validated_name, warning = message_or_NULL)
validate_and_fix_font <- function(font_name) {
  font_name <- trimws(font_name)
  all_fonts <- unlist(CURATED_FONTS)
  # Exact match first
  if (font_name %in% all_fonts) {
    return(list(font = font_name, warning = NULL))
  }
  # Case-insensitive fallback
  idx <- match(tolower(font_name), tolower(all_fonts))
  if (!is.na(idx)) {
    return(list(font = all_fonts[[idx]], warning = NULL))
  }
  list(font = "Source Sans Pro",
       warning = "Font not recognized \u2014 using Source Sans Pro instead.")
}

# ── AI theme generation via LLM ───────────────────────────────────────────────

#' Generate a theme description via LLM and return raw response.
#'
#' Builds a system prompt that includes all CURATED_FONTS names and instructs
#' the LLM to return JSON in a markdown fence block with 5 required fields:
#' backgroundColor, mainColor, accentColor, linkColor, mainFont.
#'
#' @param api_key Character — OpenRouter API key.
#' @param model Character — model ID (e.g. "openai/gpt-4o-mini").
#' @param description Character — user's freeform theme description.
#' @return list(content = LLM_text, usage = list(prompt_tokens, completion_tokens))
generate_theme_from_description <- function(api_key, model, description) {
  font_list <- paste(unlist(CURATED_FONTS), collapse = ", ")
  system_prompt <- paste0(
    "You are a slide theme designer for RevealJS presentations. ",
    "Given a description, create a cohesive color scheme and font choice.\n\n",
    "Return ONLY a JSON object inside a markdown code fence like this:\n",
    "```json\n{...}\n```\n\n",
    "Required fields (all mandatory):\n",
    "- backgroundColor: slide background color as 6-digit hex (e.g. \"#1A2B3C\")\n",
    "- mainColor: body text color as 6-digit hex\n",
    "- accentColor: heading/accent color as 6-digit hex\n",
    "- linkColor: hyperlink color as 6-digit hex\n",
    "- mainFont: font family name, must be exactly one of: ", font_list, "\n\n",
    "Rules:\n",
    "- All hex values MUST be exactly 6 digits with # prefix\n",
    "- Ensure sufficient contrast between backgroundColor and mainColor\n",
    "- Choose colors that match the mood/aesthetic described\n",
    "- Do not include any text outside the JSON fence block"
  )
  messages <- format_chat_messages(system_prompt, description)
  result <- chat_completion(api_key, model, messages)
  list(content = result$content, usage = result$usage)
}
