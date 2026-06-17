test_that("no raw icon() calls remain outside wrapper definitions", {
  # Use app_root() from helper-source.R

  r_files <- c(
    list.files(file.path(app_root(), "R"), pattern = "\\.R$", full.names = TRUE),
    file.path(app_root(), "app.R")
  )
  raw_calls <- character(0)

  for (f in r_files) {
    # Skip theme_catppuccin.R (contains wrapper definitions)
    if (basename(f) == "theme_catppuccin.R") next

    if (!file.exists(f)) next
    lines <- readLines(f)
    # Find lines with icon(" but NOT shiny::icon(" (which are wrapper definitions)
    matches <- grep('(?<!shiny::)icon\\("', lines, perl = TRUE)

    if (length(matches) > 0) {
      raw_calls <- c(raw_calls, paste0(f, ":", matches, ": ", trimws(lines[matches])))
    }
  }

  expect_equal(length(raw_calls), 0,
    info = paste("Raw icon() calls found:\n", paste(raw_calls, collapse = "\n")))
})

test_that("all icon wrapper functions exist and are callable", {
  # Use app_root() from helper-source.R
  source_app("theme_catppuccin.R")

  # Test a sample of wrapper functions
  expect_true(is.function(icon_save))
  expect_true(is.function(icon_delete))
  expect_true(is.function(icon_search))
  expect_true(is.function(icon_seedling))
  expect_true(is.function(icon_audit))
  expect_true(is.function(icon_brain))
  expect_true(is.function(icon_diagram))
  expect_true(is.function(icon_shield))
  expect_true(is.function(icon_check_circle))
  expect_true(is.function(icon_paper_plane))
  expect_true(is.function(icon_spinner))
  expect_true(is.function(icon_external_link))
  expect_true(is.function(icon_robot))
  expect_true(is.function(icon_microscope))
})
