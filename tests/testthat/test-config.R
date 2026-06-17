library(testthat)

source_app("config.R")

test_that("load_config reads yaml file", {
  tmp <- tempfile(fileext = ".yml")
  writeLines('openrouter:\n  api_key: "test-key"', tmp)

  config <- load_config(tmp)

  expect_equal(config$openrouter$api_key, "test-key")
  unlink(tmp)
})

test_that("load_config returns NULL for missing file", {
  withr::local_envvar(c(
    OPENROUTER_API_KEY = NA,
    OPENALEX_EMAIL = NA,
    OPENALEX_API_KEY = NA
  ))

  config <- load_config("nonexistent.yml")
  expect_null(config)
})

test_that("get_setting returns config value", {
  tmp <- tempfile(fileext = ".yml")
  yaml::write_yaml(list(
    defaults = list(chat_model = "test-model"),
    app = list(port = 3000)
  ), tmp)

  config <- load_config(tmp)

  expect_equal(get_setting(config, "defaults", "chat_model"), "test-model")
  expect_equal(get_setting(config, "app", "port"), 3000)
  expect_null(get_setting(config, "missing", "key"))
  unlink(tmp)
})

test_that("resolve_mirai_daemons falls back when missing", {
  value <- expect_warning(
    resolve_mirai_daemons(list(app = list())),
    "missing"
  )

  expect_equal(value, 2L)
})

test_that("resolve_mirai_daemons uses valid configured count", {
  config <- list(app = list(mirai_daemons = 6))

  expect_equal(resolve_mirai_daemons(config, warn = FALSE), 6L)
})

test_that("resolve_mirai_daemons falls back for invalid values", {
  negative <- expect_warning(
    resolve_mirai_daemons(list(app = list(mirai_daemons = -1))),
    "non-negative integer"
  )
  text_value <- expect_warning(
    resolve_mirai_daemons(list(app = list(mirai_daemons = "many"))),
    "non-negative integer"
  )

  expect_equal(negative, 2L)
  expect_equal(text_value, 2L)
})

test_that("null coalescing operator works", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
})
