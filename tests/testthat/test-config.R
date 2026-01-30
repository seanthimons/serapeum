library(testthat)

# Source the config file
source(file.path(getwd(), "R", "config.R"))

test_that("load_config reads yaml file", {
  tmp <- tempfile(fileext = ".yml")
  writeLines('openrouter:\n  api_key: "test-key"', tmp)

  config <- load_config(tmp)

  expect_equal(config$openrouter$api_key, "test-key")
  unlink(tmp)
})

test_that("load_config returns NULL for missing file", {
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

test_that("null coalescing operator works", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
})
