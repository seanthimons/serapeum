# R/themes.R
# Theme helper functions for RevealJS/Quarto slide themes.
# Provides: BUILTIN_THEME_SWATCHES, parse_scss_swatches, validate_scss_file,
#           list_custom_themes, build_theme_choices_df

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
