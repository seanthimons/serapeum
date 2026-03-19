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
