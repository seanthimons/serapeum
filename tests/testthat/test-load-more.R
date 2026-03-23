# Test icon_angles_down helper (Phase 52)

source_app("theme_catppuccin.R")

test_that("icon_angles_down returns a shiny.tag with angles-down icon", {
  icon <- icon_angles_down()

  # Check that it returns a shiny tag
  expect_s3_class(icon, "shiny.tag")

  # Check that it contains the angles-down icon class
  # Font Awesome 6 uses fa-angles-down class
  icon_html <- as.character(icon)
  expect_match(icon_html, "fa-angles-down", fixed = TRUE)
})

test_that("icon_angles_down accepts additional arguments", {
  icon <- icon_angles_down(class = "fa-spin")

  # Check that it returns a shiny tag
  expect_s3_class(icon, "shiny.tag")

  # Check that it includes the additional class
  icon_html <- as.character(icon)
  expect_match(icon_html, "fa-spin", fixed = TRUE)
})
