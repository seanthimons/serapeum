# Phase 55: Tests for get_type_badge() function

test_that("get_type_badge returns correct class and label for all 16 OpenAlex types", {
  # Source the module to get access to get_type_badge
  source("../../R/mod_search_notebook.R", local = TRUE)

  # Define expected mappings for all 16 types
  expected <- list(
    # Primary research (lavender/blue family)
    list(slug = "article", class = "bg-primary", label = "Article"),
    list(slug = "book", class = "bg-primary", label = "Book"),
    list(slug = "book-chapter", class = "bg-primary-subtle text-primary-emphasis", label = "Book Chapter"),
    list(slug = "dissertation", class = "bg-info-subtle text-info-emphasis", label = "Dissertation"),

    # Reviews/editorials (sapphire/info family)
    list(slug = "review", class = "bg-info", label = "Review"),
    list(slug = "editorial", class = "bg-info text-info-emphasis", label = "Editorial"),
    list(slug = "letter", class = "bg-info-subtle text-info-emphasis", label = "Letter"),
    list(slug = "peer-review", class = "bg-info-subtle text-info-emphasis", label = "Peer Review"),

    # Preprints/reports (yellow/warning family)
    list(slug = "preprint", class = "bg-warning text-body", label = "Preprint"),
    list(slug = "report", class = "bg-warning-subtle text-warning-emphasis", label = "Report"),
    list(slug = "standard", class = "bg-warning-subtle text-warning-emphasis", label = "Standard"),

    # Metadata/other (gray/neutral family)
    list(slug = "dataset", class = "bg-body-tertiary text-body", label = "Dataset"),
    list(slug = "erratum", class = "bg-body-tertiary text-body", label = "Erratum"),
    list(slug = "paratext", class = "bg-body-tertiary text-body", label = "Paratext"),
    list(slug = "grant", class = "bg-body-tertiary text-body", label = "Grant"),
    list(slug = "supplementary-materials", class = "bg-body-tertiary text-body", label = "Supplementary Materials")
  )

  # Test each type
  for (type_info in expected) {
    badge <- get_type_badge(type_info$slug)
    expect_equal(badge$class, type_info$class,
                 info = paste("Class mismatch for", type_info$slug))
    expect_equal(badge$label, type_info$label,
                 info = paste("Label mismatch for", type_info$slug))
  }
})

test_that("get_type_badge handles NULL, NA, and empty inputs", {
  source("../../R/mod_search_notebook.R", local = TRUE)

  # NULL input
  badge_null <- get_type_badge(NULL)
  expect_equal(badge_null$class, "bg-body-tertiary text-body")
  expect_equal(badge_null$label, "Unknown")

  # NA input
  badge_na <- get_type_badge(NA)
  expect_equal(badge_na$class, "bg-body-tertiary text-body")
  expect_equal(badge_na$label, "Unknown")

  # Empty string
  badge_empty <- get_type_badge("")
  expect_equal(badge_empty$class, "bg-body-tertiary text-body")
  expect_equal(badge_empty$label, "Unknown")
})

test_that("get_type_badge returns gray fallback for unknown types", {
  source("../../R/mod_search_notebook.R", local = TRUE)

  # Unknown type (tools::toTitleCase handles first word + proper nouns)
  badge <- get_type_badge("some-unknown-type")
  expect_equal(badge$class, "bg-body-tertiary text-body")
  expect_equal(badge$label, "some Unknown Type")  # Title-cased per tools::toTitleCase behavior
})

test_that("get_type_badge labels are human-friendly (not slugs)", {
  source("../../R/mod_search_notebook.R", local = TRUE)

  # Book Chapter should have space, not hyphen
  badge <- get_type_badge("book-chapter")
  expect_equal(badge$label, "Book Chapter")
  expect_false(grepl("-", badge$label))

  # Supplementary Materials should have space
  badge2 <- get_type_badge("supplementary-materials")
  expect_equal(badge2$label, "Supplementary Materials")
  expect_false(grepl("-", badge2$label))
})
