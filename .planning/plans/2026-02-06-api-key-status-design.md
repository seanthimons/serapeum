# Design: API Key Status Indicators (#14)

**Date:** 2026-02-06
**Status:** Ready for implementation
**Effort:** Low | **Impact:** Medium

## Overview

Add visual status indicators next to API key fields in Settings to show whether keys are configured and valid.

## Current State

The Settings page has two API key fields:
- **OpenRouter API Key** (`sk-or-...`) - Required for chat and embeddings
- **OpenAlex Email** - Optional but recommended for "polite pool" access

Currently, users have no visual feedback about whether their keys are present, valid, or working.

## Proposed Design

### Visual Indicators

Add status icons to the right of each API key field:

| State | Icon | Color | Meaning |
|-------|------|-------|---------|
| Empty | `circle-xmark` | Red | No key entered |
| Validating | `spinner` | Blue | Currently testing key |
| Valid | `circle-check` | Green | Key tested and working |
| Invalid | `circle-exclamation` | Red | Key tested but failed |

### Validation Trigger

**Auto-validate on blur** - Validate when user tabs away from the field. This provides immediate feedback without constant API calls while typing.

### Validation Methods

**OpenRouter:**
- Call `/models` endpoint (reuses existing `list_models()` function)
- Success = key is valid, returns model list

**OpenAlex:**
- Make minimal API call (`/works?per_page=1`) with email in `mailto` param
- Success = polite pool access confirmed

## Implementation

### New Functions

**R/api_openrouter.R:**
```r
#' Validate OpenRouter API key
#' @param api_key API key to validate
#' @return list(valid = TRUE/FALSE, error = NULL or error message)
validate_openrouter_key <- function(api_key) {
  if (is.null(api_key) || nchar(api_key) < 10) {
    return(list(valid = FALSE, error = "Key too short"))
  }

  tryCatch({
    models <- list_models(api_key)
    list(valid = nrow(models) > 0, error = NULL)
  }, error = function(e) {
    list(valid = FALSE, error = e$message)
  })
}
```

**R/api_openalex.R:**
```r
#' Validate OpenAlex email by making a minimal API call
#' @param email Email address to validate
#' @return list(valid = TRUE/FALSE, error = NULL or message)
validate_openalex_email <- function(email) {
  if (is.null(email) || nchar(email) < 5 || !grepl("@", email)) {
    return(list(valid = FALSE, error = "Invalid email format"))
  }

  tryCatch({
    req <- build_openalex_request("works", email) |>
      req_url_query(per_page = 1)
    resp <- req_perform(req)
    list(valid = TRUE, error = NULL)
  }, error = function(e) {
    list(valid = FALSE, error = e$message)
  })
}
```

### UI Changes (mod_settings.R)

Wrap each API key field with a flex container and status output:

```r
# OpenRouter API Key with status indicator
div(
  class = "d-flex align-items-end gap-2",
  div(style = "flex-grow: 1;",
    textInput(ns("openrouter_key"), "OpenRouter API Key", placeholder = "sk-or-...")
  ),
  uiOutput(ns("openrouter_status"))
)
```

### Status Icon Rendering

```r
output$openrouter_status <- renderUI({
  status <- api_status$openrouter

  icon_info <- switch(status$status,
    "empty" = list(icon = "circle-xmark", class = "text-danger", title = "No API key entered"),
    "validating" = list(icon = "spinner", class = "text-primary", title = "Checking..."),
    "valid" = list(icon = "circle-check", class = "text-success", title = "API key validated"),
    "invalid" = list(icon = "circle-exclamation", class = "text-danger", title = status$message),
    list(icon = "circle-question", class = "text-muted", title = "Unknown status")
  )

  div(
    class = icon_info$class,
    style = "margin-bottom: 15px; font-size: 1.2em;",
    icon(icon_info$icon, class = if (status$status == "validating") "fa-spin" else NULL),
    title = icon_info$title
  )
})
```

### Server Logic

```r
# Reactive values for API status
api_status <- reactiveValues(
  openrouter = list(status = "unknown", message = NULL),
  openalex = list(status = "unknown", message = NULL)
)

# Validate OpenRouter key on blur (debounced to avoid rapid re-validation)
observeEvent(input$openrouter_key, {
  key <- input$openrouter_key

  if (is.null(key) || nchar(key) == 0) {
    api_status$openrouter <- list(status = "empty", message = "No API key entered")
  } else {
    api_status$openrouter <- list(status = "validating", message = "Checking...")

    # Run validation
    result <- validate_openrouter_key(key)

    api_status$openrouter <- if (result$valid) {
      list(status = "valid", message = "API key validated")
    } else {
      list(status = "invalid", message = result$error)
    }
  }
}, ignoreInit = FALSE)

# Similar pattern for OpenAlex email validation
observeEvent(input$openalex_email, {
  email <- input$openalex_email

  if (is.null(email) || nchar(email) == 0) {
    api_status$openalex <- list(status = "empty", message = "No email entered")
  } else {
    api_status$openalex <- list(status = "validating", message = "Checking...")

    result <- validate_openalex_email(email)

    api_status$openalex <- if (result$valid) {
      list(status = "valid", message = "Polite pool access confirmed")
    } else {
      list(status = "invalid", message = result$error)
    }
  }
}, ignoreInit = FALSE)
```

## File Changes Summary

| File | Changes |
|------|---------|
| `R/api_openrouter.R` | Add `validate_openrouter_key()` function |
| `R/api_openalex.R` | Add `validate_openalex_email()` function |
| `R/mod_settings.R` | Add status icons UI, reactive validation logic |

## Testing

- [ ] Empty field shows red X icon
- [ ] Valid OpenRouter key shows green checkmark
- [ ] Invalid OpenRouter key shows red exclamation with error tooltip
- [ ] Valid email shows green checkmark after API ping
- [ ] Invalid email format shows red exclamation
- [ ] Spinner shows briefly during validation
- [ ] Status persists correctly when navigating away and back
