library(testthat)

# Resolve project root regardless of whether we are called via test_file or test_dir
project_root <- normalizePath(file.path(dirname(dirname(getwd())), "."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "themes.R"))) {
  project_root <- getwd()
}

# Source the themes module
source(file.path(project_root, "R", "themes.R"))

# ── BUILTIN_THEME_SWATCHES ────────────────────────────────────────────────────

test_that("BUILTIN_THEME_SWATCHES contains all 11 RevealJS themes", {
  expect_type(BUILTIN_THEME_SWATCHES, "list")
  expect_length(BUILTIN_THEME_SWATCHES, 11)
  expected_names <- c("default", "beige", "blood", "dark", "league",
                       "moon", "night", "serif", "simple", "sky", "solarized")
  expect_equal(sort(names(BUILTIN_THEME_SWATCHES)), sort(expected_names))
})

test_that("BUILTIN_THEME_SWATCHES entries have bg, fg, accent hex values", {
  for (theme in names(BUILTIN_THEME_SWATCHES)) {
    entry <- BUILTIN_THEME_SWATCHES[[theme]]
    expect_named(entry, c("bg", "fg", "accent"), ignore.order = TRUE,
                 info = paste("theme:", theme))
    expect_match(entry$bg, "^#[0-9A-Fa-f]{6}$", info = paste("theme:", theme, "bg"))
    expect_match(entry$fg, "^#[0-9A-Fa-f]{6}$", info = paste("theme:", theme, "fg"))
    expect_match(entry$accent, "^#[0-9A-Fa-f]{6}$", info = paste("theme:", theme, "accent"))
  }
})

# ── parse_scss_swatches ───────────────────────────────────────────────────────

test_that("parse_scss_swatches returns fallback for empty string", {
  result <- parse_scss_swatches("")
  expect_equal(result$bg, "#FFFFFF")
  expect_equal(result$fg, "#000000")
  expect_equal(result$accent, "#157efb")
})

test_that("parse_scss_swatches resolves variable references for epa-owm.scss content", {
  scss_text <- paste(readLines(file.path(project_root, "www", "themes", "epa-owm.scss")), collapse = "\n")
  result <- parse_scss_swatches(scss_text)
  expect_equal(result$bg, "#FFFFFF")
  expect_equal(result$fg, "#212529")
  expect_equal(result$accent, "#0D5C63")
})

test_that("parse_scss_swatches handles direct hex values", {
  scss_text <- "/*-- scss:defaults --*/\n$body-bg: #FF0000;\n$body-color: #0000FF;\n$link-color: #00FF00;\n/*-- scss:rules --*/"
  result <- parse_scss_swatches(scss_text)
  expect_equal(result$bg, "#FF0000")
  expect_equal(result$fg, "#0000FF")
  expect_equal(result$accent, "#00FF00")
})

# ── validate_scss_file ────────────────────────────────────────────────────────

test_that("validate_scss_file returns TRUE when both section markers present", {
  valid_scss <- "/*-- scss:defaults --*/\n$body-bg: #FFFFFF;\n/*-- scss:rules --*/\n.foo { color: red; }"
  expect_true(validate_scss_file(valid_scss))
})

test_that("validate_scss_file returns FALSE when missing scss:rules marker", {
  invalid_scss <- "/*-- scss:defaults --*/\n$body-bg: #FFFFFF;"
  expect_false(validate_scss_file(invalid_scss))
})

test_that("validate_scss_file returns FALSE when missing scss:defaults marker", {
  invalid_scss <- "/*-- scss:rules --*/\n.foo { color: red; }"
  expect_false(validate_scss_file(invalid_scss))
})

test_that("validate_scss_file returns FALSE for empty string", {
  expect_false(validate_scss_file(""))
})

# ── list_custom_themes ────────────────────────────────────────────────────────

test_that("list_custom_themes returns empty list for non-existent directory", {
  result <- list_custom_themes("/path/that/does/not/exist/at/all")
  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("list_custom_themes returns metadata for directory with .scss files", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  scss_content <- "/*-- scss:defaults --*/\n$body-bg: #112233;\n$body-color: #445566;\n$link-color: #778899;\n/*-- scss:rules --*/"
  writeLines(scss_content, file.path(tmp_dir, "my-theme.scss"))

  result <- list_custom_themes(tmp_dir)
  expect_length(result, 1)

  theme <- result[[1]]
  expect_named(theme, c("filename", "label", "bg", "fg", "accent"), ignore.order = TRUE)
  expect_equal(theme$filename, "my-theme.scss")
  expect_equal(theme$label, "my-theme")
  expect_equal(theme$bg, "#112233")
  expect_equal(theme$fg, "#445566")
  expect_equal(theme$accent, "#778899")
})

test_that("list_custom_themes ignores non-.scss files", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  writeLines("not scss", file.path(tmp_dir, "readme.txt"))
  writeLines("/*-- scss:defaults --*/\n$body-bg: #AABBCC;\n/*-- scss:rules --*/", file.path(tmp_dir, "valid.scss"))

  result <- list_custom_themes(tmp_dir)
  expect_length(result, 1)
  expect_equal(result[[1]]$filename, "valid.scss")
})

test_that("After file.remove, list_custom_themes no longer includes the theme", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  scss_path <- file.path(tmp_dir, "removable.scss")
  writeLines("/*-- scss:defaults --*/\n$body-bg: #AABBCC;\n/*-- scss:rules --*/", scss_path)

  result_before <- list_custom_themes(tmp_dir)
  expect_length(result_before, 1)

  file.remove(scss_path)

  result_after <- list_custom_themes(tmp_dir)
  expect_length(result_after, 0)
})

# ── build_theme_choices_df ────────────────────────────────────────────────────

test_that("build_theme_choices_df returns 11-row data.frame for built-in only", {
  result <- build_theme_choices_df()
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 11)
  expect_named(result, c("value", "label", "bg", "fg", "accent", "group"), ignore.order = TRUE)
  expect_true(all(result$group == "builtin"))
})

test_that("build_theme_choices_df built-in rows have correct value and label", {
  result <- build_theme_choices_df()
  expect_true("default" %in% result$value)
  # Check that label is Title Case version of the name
  default_row <- result[result$value == "default", ]
  expect_equal(default_row$label, "Default")
})

test_that("build_theme_choices_df appends custom theme rows with group='custom'", {
  custom <- list(
    list(filename = "my-theme.scss", label = "my-theme", bg = "#111111", fg = "#EEEEEE", accent = "#FF0000")
  )
  result <- build_theme_choices_df(custom_themes = custom)
  expect_equal(nrow(result), 12)

  custom_rows <- result[result$group == "custom", ]
  expect_equal(nrow(custom_rows), 1)
  expect_equal(custom_rows$value, "my-theme.scss")
  expect_equal(custom_rows$label, "my-theme")
  expect_equal(custom_rows$group, "custom")
})

test_that("build_theme_choices_df custom value is filename not full path", {
  custom <- list(
    list(filename = "epa-owm.scss", label = "epa-owm", bg = "#FFFFFF", fg = "#212529", accent = "#0D5C63")
  )
  result <- build_theme_choices_df(custom_themes = custom)
  custom_rows <- result[result$group == "custom", ]
  # value must be filename only, NOT a path
  expect_false(grepl("/", custom_rows$value))
  expect_false(grepl("\\\\", custom_rows$value))
  expect_equal(custom_rows$value, "epa-owm.scss")
})

# ── CURATED_FONTS ─────────────────────────────────────────────────────────────

test_that("CURATED_FONTS is a named list with at least 2 groups", {
  expect_type(CURATED_FONTS, "list")
  expect_gte(length(CURATED_FONTS), 2)
  expect_true(!is.null(names(CURATED_FONTS)))
})

test_that("CURATED_FONTS contains at least 10 total font names", {
  total_fonts <- sum(lengths(CURATED_FONTS))
  expect_gte(total_fonts, 10)
})

test_that("CURATED_FONTS has Sans-serif, Serif, Monospace groups", {
  expect_true("Sans-serif" %in% names(CURATED_FONTS))
  expect_true("Serif" %in% names(CURATED_FONTS))
  expect_true("Monospace" %in% names(CURATED_FONTS))
})

test_that("CURATED_FONTS includes required sans-serif fonts", {
  sans <- CURATED_FONTS[["Sans-serif"]]
  expect_true("Source Sans Pro" %in% sans)
  expect_true("Lato" %in% sans)
  expect_true("Fira Sans" %in% sans)
  expect_true("Roboto" %in% sans)
  expect_true("Open Sans" %in% sans)
})

test_that("CURATED_FONTS includes required serif fonts", {
  serif <- CURATED_FONTS[["Serif"]]
  expect_true("Merriweather" %in% serif)
  expect_true("PT Serif" %in% serif)
  expect_true("Roboto Slab" %in% serif)
  expect_true("Playfair Display" %in% serif)
})

test_that("CURATED_FONTS includes required monospace fonts", {
  mono <- CURATED_FONTS[["Monospace"]]
  expect_true("IBM Plex Mono" %in% mono)
  expect_true("Fira Code" %in% mono)
})

# ── parse_scss_colors_full ────────────────────────────────────────────────────

test_that("parse_scss_colors_full returns fallback list for empty string", {
  result <- parse_scss_colors_full("")
  expect_named(result, c("bg", "fg", "accent", "link", "font"), ignore.order = TRUE)
  expect_equal(result$bg, "#FFFFFF")
  expect_equal(result$fg, "#000000")
  expect_equal(result$accent, "#157efb")
  expect_equal(result$link, "#157efb")
  expect_equal(result$font, "Source Sans Pro")
})

test_that("parse_scss_colors_full extracts all 5 fields from generated scss style", {
  scss_text <- paste0(
    "/*-- scss:defaults --*/\n",
    "$backgroundColor: #AABBCC;\n",
    "$mainColor: #112233;\n",
    "$linkColor: #445566;\n",
    "$accentColor: #778899;\n",
    '$mainFont: "Lato", sans-serif;\n',
    "/*-- scss:rules --*/"
  )
  result <- parse_scss_colors_full(scss_text)
  expect_equal(result$bg, "#AABBCC")
  expect_equal(result$fg, "#112233")
  expect_equal(result$link, "#445566")
  expect_equal(result$accent, "#778899")
  expect_equal(result$font, "Lato")
})

test_that("parse_scss_colors_full handles body-bg / body-color style variable names", {
  scss_text <- paste0(
    "/*-- scss:defaults --*/\n",
    "$body-bg: #FF0000;\n",
    "$body-color: #0000FF;\n",
    "$link-color: #00FF00;\n",
    "$presentation-heading-font: \"Merriweather\", serif;\n",
    "/*-- scss:rules --*/"
  )
  result <- parse_scss_colors_full(scss_text)
  expect_equal(result$bg, "#FF0000")
  expect_equal(result$fg, "#0000FF")
  expect_equal(result$link, "#00FF00")
  expect_equal(result$font, "Merriweather")
})

test_that("parse_scss_colors_full returns fallback font when no font variable present", {
  scss_text <- "/*-- scss:defaults --*/\n$body-bg: #FF0000;\n/*-- scss:rules --*/"
  result <- parse_scss_colors_full(scss_text)
  expect_equal(result$font, "Source Sans Pro")
})

# ── generate_custom_scss ──────────────────────────────────────────────────────

test_that("generate_custom_scss writes a valid .scss file with 5 variables", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path <- generate_custom_scss(
    name        = "My Theme",
    bg_color    = "#FFFFFF",
    text_color  = "#000000",
    accent_color = "#157efb",
    link_color  = "#157efb",
    font_name   = "Source Sans Pro",
    themes_dir  = tmp_dir
  )

  expect_false(is.null(path))
  expect_true(file.exists(path))

  contents <- paste(readLines(path), collapse = "\n")
  expect_true(grepl("$backgroundColor", contents, fixed = TRUE))
  expect_true(grepl("$mainColor", contents, fixed = TRUE))
  expect_true(grepl("$linkColor", contents, fixed = TRUE))
  expect_true(grepl("$accentColor", contents, fixed = TRUE))
  expect_true(grepl("$mainFont", contents, fixed = TRUE))
})

test_that("generate_custom_scss includes both section markers", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path <- generate_custom_scss("Test", "#FFF", "#000", "#123456", "#654321", "Lato", tmp_dir)
  contents <- paste(readLines(path), collapse = "\n")
  expect_true(validate_scss_file(contents))
})

test_that("generate_custom_scss sanitizes filename special characters", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path <- generate_custom_scss("Hello World!", "#FFF", "#000", "#123456", "#654321", "Lato", tmp_dir)
  expect_false(is.null(path))
  filename <- basename(path)
  expect_equal(filename, "Hello-World-.scss")
})

test_that("generate_custom_scss wraps multi-word font name in double quotes", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path <- generate_custom_scss("Theme", "#FFF", "#000", "#123456", "#654321", "Source Sans Pro", tmp_dir)
  contents <- paste(readLines(path), collapse = "\n")
  expect_true(grepl('"Source Sans Pro"', contents, fixed = TRUE))
})

test_that("generate_custom_scss overwrites existing file silently", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path1 <- generate_custom_scss("Dupe", "#FFF", "#000", "#111111", "#222222", "Lato", tmp_dir)
  path2 <- generate_custom_scss("Dupe", "#FFF", "#000", "#333333", "#444444", "Roboto", tmp_dir)
  expect_equal(path1, path2)
  contents <- paste(readLines(path2), collapse = "\n")
  expect_true(grepl("#333333", contents, fixed = TRUE))
})

test_that("generate_custom_scss returns NULL when directory does not exist", {
  path <- generate_custom_scss("Test", "#FFF", "#000", "#123456", "#654321", "Lato",
                                themes_dir = "/this/path/does/not/exist/at/all")
  expect_null(path)
})

test_that("generate_custom_scss includes scss:rules block with accentColor heading styles", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  path <- generate_custom_scss("Theme", "#FFF", "#000", "#123456", "#654321", "Lato", tmp_dir)
  contents <- paste(readLines(path), collapse = "\n")
  expect_true(grepl(".reveal h1", contents, fixed = TRUE))
  expect_true(grepl("$accentColor", contents, fixed = TRUE))
})

# ── extract_theme_json ─────────────────────────────────────────────────────

test_that("extract_theme_json extracts valid JSON from markdown fence", {
  response <- '```json\n{"backgroundColor":"#1A2B3C","mainColor":"#FFFFFF","accentColor":"#FF0000","linkColor":"#00FF00","mainFont":"Lato"}\n```'
  result <- extract_theme_json(response)
  expect_type(result, "list")
  expect_equal(result$backgroundColor, "#1A2B3C")
  expect_equal(result$mainFont, "Lato")
})

test_that("extract_theme_json returns NULL when no fence block", {
  expect_null(extract_theme_json("just some text without json"))
})

test_that("extract_theme_json returns NULL for malformed JSON in fence", {
  response <- '```json\n{not valid json}\n```'
  expect_null(extract_theme_json(response))
})

test_that("extract_theme_json handles whitespace variations in fence", {
  # No newline after opening fence
  r1 <- '```json{"backgroundColor":"#AABBCC","mainColor":"#112233","accentColor":"#445566","linkColor":"#778899","mainFont":"Roboto"}\n```'
  expect_type(extract_theme_json(r1), "list")

  # Extra whitespace
  r2 <- '```json  \n{"backgroundColor":"#AABBCC","mainColor":"#112233","accentColor":"#445566","linkColor":"#778899","mainFont":"Roboto"}\n```'
  expect_type(extract_theme_json(r2), "list")
})

test_that("extract_theme_json handles surrounding text before/after fence", {
  response <- 'Here is your theme:\n```json\n{"backgroundColor":"#000000","mainColor":"#FFFFFF","accentColor":"#FF0000","linkColor":"#00FF00","mainFont":"Lato"}\n```\nEnjoy!'
  result <- extract_theme_json(response)
  expect_equal(result$backgroundColor, "#000000")
})

# ── validate_theme_colors ──────────────────────────────────────────────────

test_that("validate_theme_colors returns empty vector for valid hex colors", {
  theme <- list(backgroundColor = "#1A2B3C", mainColor = "#FFFFFF",
                accentColor = "#ff0000", linkColor = "#00FF00")
  expect_length(validate_theme_colors(theme), 0)
})

test_that("validate_theme_colors returns bad field names for invalid hex", {
  theme <- list(backgroundColor = "#FFF", mainColor = "#FFFFFF",
                accentColor = "red", linkColor = "#00FF00")
  bad <- validate_theme_colors(theme)
  expect_true("backgroundColor" %in% bad)
  expect_true("accentColor" %in% bad)
  expect_false("mainColor" %in% bad)
  expect_false("linkColor" %in% bad)
})

test_that("validate_theme_colors rejects 8-digit hex", {
  theme <- list(backgroundColor = "#FFFFFF00", mainColor = "#000000",
                accentColor = "#FF0000", linkColor = "#00FF00")
  bad <- validate_theme_colors(theme)
  expect_true("backgroundColor" %in% bad)
})

test_that("validate_theme_colors rejects missing fields", {
  theme <- list(backgroundColor = "#FFFFFF", mainColor = "#000000")
  bad <- validate_theme_colors(theme)
  expect_true("accentColor" %in% bad)
  expect_true("linkColor" %in% bad)
})

# ── validate_and_fix_font ──────────────────────────────────────────────────

test_that("validate_and_fix_font accepts valid CURATED_FONTS member", {
  result <- validate_and_fix_font("Lato")
  expect_equal(result$font, "Lato")
  expect_null(result$warning)
})

test_that("validate_and_fix_font falls back to Source Sans Pro for unknown font", {
  result <- validate_and_fix_font("Comic Sans MS")
  expect_equal(result$font, "Source Sans Pro")
  expect_true(grepl("not recognized", result$warning))
})

test_that("validate_and_fix_font handles whitespace", {
  result <- validate_and_fix_font("  Lato  ")
  expect_equal(result$font, "Lato")
  expect_null(result$warning)
})

test_that("validate_and_fix_font handles case-insensitive matching", {
  result <- validate_and_fix_font("source sans pro")
  expect_equal(result$font, "Source Sans Pro")
  expect_null(result$warning)
})

# ── generate_theme_from_description ────────────────────────────────────────

test_that("generate_theme_from_description system prompt contains CURATED_FONTS", {
  # Capture the messages argument passed to chat_completion
  captured_messages <- NULL
  mock_chat <- function(api_key, model, messages) {
    captured_messages <<- messages
    list(
      content = '```json\n{"backgroundColor":"#000000","mainColor":"#FFFFFF","accentColor":"#FF0000","linkColor":"#00FF00","mainFont":"Lato"}\n```',
      usage = list(prompt_tokens = 100, completion_tokens = 50)
    )
  }

  # Temporarily override chat_completion
  original_fn <- if (exists("chat_completion", envir = .GlobalEnv)) get("chat_completion", envir = .GlobalEnv) else NULL
  assign("chat_completion", mock_chat, envir = .GlobalEnv)
  on.exit({
    if (is.null(original_fn)) rm("chat_completion", envir = .GlobalEnv)
    else assign("chat_completion", original_fn, envir = .GlobalEnv)
  })

  # Also need format_chat_messages
  if (!exists("format_chat_messages", envir = .GlobalEnv)) {
    assign("format_chat_messages", function(system_prompt, user_message, history = list()) {
      messages <- list(list(role = "system", content = system_prompt))
      messages <- c(messages, history)
      messages <- c(messages, list(list(role = "user", content = user_message)))
      messages
    }, envir = .GlobalEnv)
  }

  result <- generate_theme_from_description("fake-key", "fake-model", "ocean blues")

  # System prompt should mention all curated fonts
  sys_prompt <- captured_messages[[1]]$content
  expect_true(grepl("Source Sans Pro", sys_prompt, fixed = TRUE))
  expect_true(grepl("Lato", sys_prompt, fixed = TRUE))
  expect_true(grepl("Merriweather", sys_prompt, fixed = TRUE))
  expect_true(grepl("IBM Plex Mono", sys_prompt, fixed = TRUE))
  expect_true(grepl("backgroundColor", sys_prompt, fixed = TRUE))
  expect_equal(result$content, '```json\n{"backgroundColor":"#000000","mainColor":"#FFFFFF","accentColor":"#FF0000","linkColor":"#00FF00","mainFont":"Lato"}\n```')
})
