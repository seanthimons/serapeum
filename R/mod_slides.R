# R/mod_slides.R
#' Slides Generation Modal UI
#' @param ns Namespace function from session$ns
#' @param documents Data frame of documents (id, filename)
#' @param models Data frame of available models (id, name)
#' @param current_model Currently selected model ID
mod_slides_modal_ui <- function(ns, documents, models, current_model) {
  # Namespace prefix for JS strings (e.g. "slides-")
  ns_prefix <- ns("")

  # Helper: native color input + hex text field pair
  # Returns a div with label, swatch + hex field, and bidirectional JS sync
  color_picker_pair <- function(ns, id, label) {
    swatch_id <- ns(paste0(id, "_swatch"))
    hex_id    <- ns(paste0(id, "_hex"))
    div(
      class = "mb-2",
      tags$label(label, `for` = hex_id, class = "form-label small fw-semibold"),
      div(
        class = "d-flex align-items-center gap-2",
        tags$input(
          type = "color",
          id = swatch_id,
          value = "#ffffff",
          style = "width:40px;height:38px;padding:2px;border:1px solid #ced4da;border-radius:4px;cursor:pointer;"
        ),
        textInput(hex_id, NULL, value = "#FFFFFF", width = "100px", placeholder = "#RRGGBB")
      ),
      # JS: swatch -> hex (live, on every color picker change)
      tags$script(HTML(sprintf(
        "setTimeout(function() {
           var sw = document.getElementById('%s');
           var hx = document.getElementById('%s');
           if (sw && hx) {
             sw.addEventListener('input', function(e) {
               hx.value = e.target.value.toUpperCase();
               hx.dispatchEvent(new Event('change'));
             });
           }
         }, 0);",
        swatch_id, hex_id
      ))),
      # JS: hex -> swatch (updates swatch when valid hex typed)
      tags$script(HTML(sprintf(
        "setTimeout(function() {
           var hx = document.getElementById('%s');
           var sw = document.getElementById('%s');
           if (hx && sw) {
             hx.addEventListener('input', function(e) {
               var v = e.target.value.trim();
               if (/^#[0-9A-Fa-f]{6}$/.test(v)) {
                 sw.value = v.toLowerCase();
               }
             });
             hx.addEventListener('blur', function(e) {
               var v = e.target.value.trim();
               if (/^#[0-9A-Fa-f]{6}$/.test(v)) {
                 e.target.classList.remove('is-invalid');
               } else {
                 e.target.classList.add('is-invalid');
               }
             });
           }
         });",
        hex_id, swatch_id
      )))
    )
  }

  modalDialog(
    title = tagList(icon_file_powerpoint(), "Generate Slides"),
    size = "l",
    easyClose = FALSE,

    # Document selection
    div(
      class = "mb-4",
      h6("Select Documents", class = "fw-semibold"),
      div(
        class = "border rounded p-3",
        style = "max-height: 200px; overflow-y: auto;",
        checkboxInput(ns("select_all_docs"), "Select All", value = TRUE),
        hr(class = "my-2"),
        checkboxGroupInput(
          ns("selected_docs"),
          NULL,
          choices = setNames(documents$id, documents$filename),
          selected = documents$id
        )
      )
    ),

    # Configuration options
    div(
      class = "mb-3",
      h6("Options", class = "fw-semibold"),

      layout_columns(
        col_widths = c(6, 6),

        # Model selection
        selectInput(
          ns("model"),
          "Model",
          choices = setNames(models$id, models$name),
          selected = current_model
        ),

        # Length
        radioButtons(
          ns("length"),
          "Presentation Length",
          choices = c("Short (5-8 slides)" = "short",
                      "Medium (10-15 slides)" = "medium",
                      "Long (20+ slides)" = "long"),
          selected = "medium",
          inline = TRUE
        )
      ),

      layout_columns(
        col_widths = c(4, 4, 4),

        # Audience
        selectInput(
          ns("audience"),
          "Audience",
          choices = c("Technical" = "technical",
                      "Executive" = "executive",
                      "General / Educational" = "general"),
          selected = "general"
        ),

        # Citation style
        selectInput(
          ns("citation_style"),
          "Citation Style",
          choices = c("Footnotes" = "footnotes",
                      "Inline (Author, p.X)" = "inline",
                      "Speaker Notes Only" = "notes_only",
                      "None" = "none"),
          selected = "footnotes"
        ),

        # Speaker notes
        div(
          style = "padding-top: 32px;",
          checkboxInput(ns("include_notes"), "Include speaker notes", value = TRUE)
        )
      ),

      # Custom message handlers (must be in the modal body for Shiny to register)
      tags$script(HTML(
        "Shiny.addCustomMessageHandler('update_color_swatch', function(msg) {
           for (var i = 0; i < msg.ids.length; i++) {
             var el = document.getElementById(msg.ids[i]);
             if (el) el.value = msg.values[i];
           }
         });
         Shiny.addCustomMessageHandler('focus_element', function(id) {
           var el = document.getElementById(id);
           if (el) el.focus();
         });
         Shiny.addCustomMessageHandler('collapse_panel', function(id) {
           var el = document.getElementById(id);
           if (el && el.classList.contains('show')) {
             var bsCollapse = bootstrap.Collapse.getInstance(el);
             if (bsCollapse) { bsCollapse.hide(); } else { new bootstrap.Collapse(el).hide(); }
           }
         });
         Shiny.addCustomMessageHandler('expand_panel', function(id) {
           var el = document.getElementById(id);
           if (el && !el.classList.contains('show')) {
             bootstrap.Collapse.getOrCreateInstance(el).show();
           }
         });
         Shiny.addCustomMessageHandler('set_button_loading', function(msg) {
           var btn = document.getElementById(msg.id);
           if (!btn) return;
           if (msg.loading) {
             btn.disabled = true;
             btn.dataset.originalHtml = btn.innerHTML;
             btn.innerHTML = '<span class=\"spinner-border spinner-border-sm\" role=\"status\"><span class=\"visually-hidden\">Loading</span></span> ' + (msg.text || 'Generating...');
           } else {
             btn.disabled = false;
             btn.innerHTML = btn.dataset.originalHtml || msg.label || 'Generate';
           }
         });"
      )),

      # Theme section — dropdown row with AI generate
      layout_columns(
        col_widths = c(5, 7),
        # Theme dropdown with upload link
        div(
          selectizeInput(
            ns("theme"),
            "Theme",
            choices = NULL,
            options = list(
              render = I(paste0(
                '{option: function(item, escape) {',
                '  var dots = \'<span style="display:inline-flex;gap:3px;margin-right:6px;">\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.bg) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.fg) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.accent) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'</span>\';',
                '  var del = item.group === "custom"',
                '    ? \'<span class="theme-delete-btn" data-value="\' + escape(item.value) + \'"',
                '        onclick="event.stopPropagation();event.preventDefault();',
                '          Shiny.setInputValue(\\\'', ns_prefix, 'theme_delete\\\',',
                '          this.getAttribute(\\\'data-value\\\'), {priority:\\\'event\\\'});return false;"',
                '        style="margin-left:auto;cursor:pointer;color:#dc3545;padding:2px 6px;font-size:16px;line-height:1;">&#215;</span>\'',
                '    : \'\';',
                '  return \'<div style="display:flex;align-items:center;">\' + dots + escape(item.label) + del + \'</div>\';',
                '},',
                'item: function(item, escape) {',
                '  var dots = \'<span style="display:inline-flex;gap:3px;margin-right:6px;">\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.bg) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.fg) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'<span style="width:10px;height:10px;border-radius:50%;display:inline-block;background:\' + escape(item.accent) + \';border:2px solid rgba(128,128,128,0.3)"></span>\' +',
                '    \'</span>\';',
                '  return \'<div style="display:flex;align-items:center;">\' + dots + escape(item.label) + \'</div>\';',
                '}}'
              )),
              optgroupField = "group",
              optgroups = I('[{"value":"builtin","label":"Built-in"},{"value":"custom","label":"Custom"}]'),
              searchField = list("label"),
              labelField = "label",
              valueField = "value"
            )
          ),
          tags$label(
            `for` = ns("theme_file"),
            class = "small text-muted d-inline-flex align-items-center gap-1",
            style = "cursor:pointer; margin-top:-8px;",
            icon("upload"),
            " Upload .scss"
          ),
          div(
            style = "position:absolute; width:0; height:0; overflow:hidden;",
            fileInput(ns("theme_file"), NULL, accept = ".scss")
          ),
          uiOutput(ns("upload_error"))
        ),
        # AI Generate — label aligns with "Theme" label, input aligns with dropdown
        div(
          tags$label(
            class = "form-label",
            icon("wand-magic-sparkles", class = "text-muted"),
            " AI Generate"
          ),
          div(
            class = "d-flex gap-2 align-items-end",
            div(
              style = "flex:1; margin-bottom:0;",
              textInput(ns("ai_theme_description"), NULL,
                placeholder = "e.g., ocean blues, dark background",
                width = "100%"
              )
            ),
            tags$button(
              id = ns("ai_generate_btn"),
              type = "button",
              class = "btn btn-outline-primary",
              style = "white-space:nowrap;",
              onclick = sprintf(
                "Shiny.setInputValue('%s', Date.now(), {priority: 'event'});",
                ns("ai_generate_btn")
              ),
              "Generate"
            )
          ),
          uiOutput(ns("regenerate_btn_area"))
        )
      ),

      # Customize colors & font — collapsible panel
      div(
        # Chevron CSS for rotation animation
        tags$style(HTML(sprintf(
          "#%s.show ~ * .customize-chevron,
           [aria-expanded='true'] .customize-chevron {
             transform: rotate(90deg);
           }
           .customize-chevron { transition: transform 0.2s; }",
          ns("customize_panel")
        ))),
        # Toggle link
        tags$a(
          class = "small text-muted d-flex align-items-center gap-1 mt-1 customize-toggle",
          style = "cursor:pointer; text-decoration:none;",
          `data-bs-toggle` = "collapse",
          href = paste0("#", ns("customize_panel")),
          role = "button",
          `aria-expanded` = "false",
          `aria-controls` = ns("customize_panel"),
          icon("chevron-right", class = "customize-chevron"),
          " Customize colors & font"
        ),
        # Collapsible content
        div(
          id = ns("customize_panel"),
          class = "collapse mt-2 p-3 border rounded bg-body-secondary",
          # 2x2 color picker grid
          layout_columns(
            col_widths = c(6, 6),
            color_picker_pair(ns, "bg",     "Background"),
            color_picker_pair(ns, "text",   "Text"),
            color_picker_pair(ns, "accent", "Accent"),
            color_picker_pair(ns, "link",   "Link")
          ),
          # Font + Save row
          layout_columns(
            col_widths = c(5, 4, 3),
            selectInput(ns("font"), "Font", choices = CURATED_FONTS, selected = "Source Sans Pro"),
            textInput(ns("custom_theme_name"), "Theme name", placeholder = "My theme..."),
            div(
              style = "padding-top: 32px;",
              actionButton(ns("save_custom_theme"), "Save",
                           class = "btn-primary btn-sm w-100", icon = icon_save())
            )
          )
        )
      ),

      # Custom instructions
      textAreaInput(
        ns("custom_instructions"),
        "Custom Instructions (optional)",
        placeholder = "e.g., Focus on methodology, include comparison table...",
        rows = 2
      )
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("generate"), "Generate", class = "btn-primary", icon = icon_wand())
    )
  )
}

#' Slides Healing Modal UI
#' @param ns Namespace function from session$ns
#' @param errors Character vector of validation/render errors (or NULL)
#' @param is_success Logical - TRUE if generation was successful
mod_slides_heal_modal_ui <- function(ns, errors = NULL, is_success = FALSE) {
  # Error/info summary at top
  summary_panel <- if (is_success) {
    div(
      class = "alert alert-info mb-3",
      icon_circle_info(class = "me-2"),
      "Slides generated successfully. Use healing to make cosmetic adjustments."
    )
  } else if (!is.null(errors) && length(errors) > 0) {
    div(
      class = "alert alert-warning mb-3",
      icon_warning(class = "me-2"),
      strong("Issues found:"),
      tags$ul(
        class = "mb-0 mt-2",
        lapply(errors, function(err) tags$li(err))
      )
    )
  } else {
    NULL
  }

  # Quick-pick chips
  chip_labels <- get_healing_chips(errors %||% character(0), is_success)
  chip_buttons <- lapply(seq_along(chip_labels), function(i) {
    actionButton(
      ns(paste0("chip_", i)),
      chip_labels[i],
      class = "btn btn-outline-secondary btn-sm me-2 mb-2"
    )
  })

  modalDialog(
    title = tagList(icon_wrench(), "Heal Slides"),
    size = "m",
    easyClose = FALSE,

    summary_panel,

    # Quick-pick chips
    div(
      class = "mb-3",
      h6("Quick Fixes", class = "fw-semibold"),
      do.call(tagList, chip_buttons)
    ),

    # Free text input
    textAreaInput(
      ns("heal_instructions"),
      "Custom Instructions",
      placeholder = "Describe what to fix...",
      rows = 3
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns("do_heal"), "Heal", class = "btn-primary", icon = icon_wrench())
    )
  )
}

#' Slides Results Modal UI
#' @param ns Namespace function from session$ns
#' @param preview_url URL to preview HTML (or NULL)
#' @param error Error message (or NULL)
#' @param qmd_content Raw QMD content for "Show raw output" toggle (or NULL)
#' @param validation_errors Character vector of validation errors (or NULL)
#' @param heal_attempts Number of healing attempts so far
#' @param is_fallback TRUE if showing fallback template
mod_slides_results_ui <- function(ns, preview_url = NULL, error = NULL,
                                   qmd_content = NULL, validation_errors = NULL,
                                   heal_attempts = 0, is_fallback = FALSE) {

  # Raw output collapsible (used in multiple content branches)
  raw_output_toggle <- if (!is.null(qmd_content)) {
    tags$details(
      class = "mt-3",
      tags$summary(class = "text-muted small", style = "cursor: pointer;", "Show raw output"),
      div(
        class = "bg-dark text-light p-3 rounded mt-2",
        style = "max-height: 300px; overflow-y: auto; font-family: monospace; font-size: 0.8em; white-space: pre-wrap;",
        qmd_content
      )
    )
  } else {
    NULL
  }

  # Retry counter
  retry_counter <- if (heal_attempts > 0 && !is_fallback) {
    div(class = "text-muted small mb-2", sprintf("Healing attempt %d of 2", heal_attempts))
  } else {
    NULL
  }

  # Fallback warning banner
  fallback_banner <- if (is_fallback) {
    div(
      class = "alert alert-warning mb-3",
      icon_warning(class = "me-2"),
      "Generation failed after 2 attempts. Showing template outline ",
      tags$span(class = "fw-semibold", "-- download the .qmd and edit manually.")
    )
  } else {
    NULL
  }

  content <- if (!is.null(error)) {
    # Error panel replaces preview area
    div(
      class = "py-4 px-3",
      retry_counter,
      div(
        class = "alert alert-danger",
        icon_warning(class = "me-2"),
        strong("Generation failed: "), error
      ),
      raw_output_toggle
    )
  } else if (!is.null(preview_url)) {
    tagList(
      fallback_banner,
      retry_counter,
      div(
        class = "mb-3",
        style = "height: 400px; border: 1px solid var(--bs-border-color); border-radius: 0.5rem; overflow: hidden;",
        tags$iframe(
          src = preview_url,
          style = "width: 100%; height: 100%; border: none;"
        )
      ),
      div(
        class = "d-flex gap-2 justify-content-center",
        downloadButton(ns("download_qmd"), "Download .qmd", class = "btn-outline-primary"),
        downloadButton(ns("download_html"), "Download HTML", class = "btn-outline-primary"),
        downloadButton(ns("download_pdf"), "Download PDF", class = "btn-outline-primary")
      ),
      raw_output_toggle
    )
  } else {
    div(
      class = "text-center py-5",
      div(class = "spinner-border text-primary", role = "status"),
      p(class = "mt-3 text-muted", "Generating slides...")
    )
  }

  modalDialog(
    title = tagList(icon_file_powerpoint(), "Generated Slides"),
    size = "xl",
    easyClose = FALSE,
    content,
    footer = tagList(
      actionButton(ns("open_heal"), "Heal", class = "btn-outline-warning", icon = icon_wrench()),
      actionButton(ns("regenerate"), "Regenerate", class = "btn-outline-secondary", icon = icon_rotate()),
      modalButton("Close")
    )
  )
}

#' Slides Module Server
#' @param id Module ID
#' @param con Database connection (reactive)
#' @param notebook_id Reactive notebook ID
#' @param config App config (reactive)
#' @param trigger Reactive trigger to open modal
mod_slides_server <- function(id, con, notebook_id, config, trigger) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Store generation state
    generation_state <- reactiveValues(
      qmd_content = NULL,
      qmd_path = NULL,
      html_path = NULL,
      pdf_path = NULL,
      error = NULL,
      last_options = NULL,
      heal_attempts = 0,
      validation_errors = NULL,
      is_fallback = FALSE,
      last_chunks = NULL
    )

    # Store current chip labels for chip click handling
    current_chips <- reactiveVal(character(0))

    # Helper: rebuild and push the theme dropdown choices
    refresh_theme_dropdown <- function(selected = NULL) {
      custom <- list_custom_themes()
      df <- build_theme_choices_df(custom)
      updateSelectizeInput(
        session, "theme",
        choices = df,
        selected = selected %||% isolate(input$theme) %||% "default",
        server = TRUE
      )
    }

    # Track whether AI generation has occurred (controls Regenerate button visibility)
    ai_generated <- reactiveVal(FALSE)
    # Store the last AI description for Regenerate
    last_ai_description <- reactiveVal(NULL)

    # Helper to show results modal with current state
    show_results <- function(preview_url = NULL, error = NULL) {
      removeModal()
      showModal(mod_slides_results_ui(
        ns,
        preview_url = preview_url,
        error = error,
        qmd_content = generation_state$qmd_content,
        validation_errors = generation_state$validation_errors,
        heal_attempts = generation_state$heal_attempts,
        is_fallback = generation_state$is_fallback
      ))
    }

    # Handle select all checkbox
    observeEvent(input$select_all_docs, {
      nb_id <- notebook_id()
      req(nb_id)
      docs <- list_documents(con(), nb_id)

      if (input$select_all_docs) {
        updateCheckboxGroupInput(session, "selected_docs", selected = docs$id)
      } else {
        updateCheckboxGroupInput(session, "selected_docs", selected = character(0))
      }
    }, ignoreInit = TRUE)

    # Open modal when triggered
    observeEvent(trigger(), {
      nb_id <- notebook_id()
      req(nb_id)

      # Check Quarto installation
      if (!check_quarto_installed()) {
        showNotification(
          "Quarto is not installed. Please install Quarto to use slide generation: https://quarto.org/docs/get-started/",
          type = "error",
          duration = 10
        )
        return()
      }

      # Get documents
      docs <- list_documents(con(), nb_id)
      if (nrow(docs) == 0) {
        showNotification("No documents in this notebook", type = "warning")
        return()
      }

      # Get models
      cfg <- config()
      provider <- provider_from_config(cfg, con())
      models <- tryCatch({
        provider_list_models(provider)
      }, error = function(e) {
        data.frame(id = "google/gemini-3.1-flash-lite-preview", name = "Gemini 3.1 Flash Lite", stringsAsFactors = FALSE)
      })

      current_model <- resolve_model_for_operation(cfg, "slide_generation")

      # Reset state
      generation_state$qmd_content <- NULL
      generation_state$qmd_path <- NULL
      generation_state$html_path <- NULL
      generation_state$error <- NULL
      generation_state$heal_attempts <- 0
      generation_state$validation_errors <- NULL
      generation_state$is_fallback <- FALSE
      generation_state$last_chunks <- NULL

      showModal(mod_slides_modal_ui(ns, docs, models, current_model))
      # Populate theme dropdown with swatch choices after modal is shown
      refresh_theme_dropdown(selected = "default")
    }, ignoreInit = TRUE)

    # Handle upload of a custom theme .scss file
    observeEvent(input$theme_file, {
      req(input$theme_file)
      scss_text <- paste(readLines(input$theme_file$datapath, warn = FALSE), collapse = "\n")

      if (!validate_scss_file(scss_text)) {
        output$upload_error <- renderUI(
          div(
            class = "alert alert-danger py-1 px-2 small mt-1",
            "Invalid .scss file. Must contain /*-- scss:defaults --*/ and /*-- scss:rules --*/ sections."
          )
        )
        return()
      }

      # Clear previous error
      output$upload_error <- renderUI(NULL)

      # Save to data/themes/
      dir.create("data/themes", recursive = TRUE, showWarnings = FALSE)
      dest <- file.path("data/themes", input$theme_file$name)
      if (!file.copy(input$theme_file$datapath, dest, overwrite = TRUE)) {
        showNotification("Failed to save theme file. Check permissions.", type = "error")
        return()
      }

      showNotification(
        paste0("Theme '", input$theme_file$name, "' uploaded."),
        type = "message",
        duration = 3
      )

      # Refresh dropdown to include new theme, keep current selection
      refresh_theme_dropdown()
    })

    # Handle delete of a custom theme
    observeEvent(input$theme_delete, {
      req(input$theme_delete)
      theme_filename <- input$theme_delete
      theme_path <- file.path("data/themes", theme_filename)
      if (file.exists(theme_path)) {
        file.remove(theme_path)
      }
      # If the deleted theme was selected, reset to default
      current_sel <- isolate(input$theme)
      new_sel <- if (!is.null(current_sel) && current_sel == theme_filename) "default" else current_sel
      refresh_theme_dropdown(selected = new_sel)
    })

    # Theme pre-fill: when theme dropdown changes, populate all picker fields
    observeEvent(input$theme, {
      sel <- input$theme
      req(sel)

      if (sel %in% names(BUILTIN_THEME_SWATCHES)) {
        sw  <- BUILTIN_THEME_SWATCHES[[sel]]
        bg  <- sw$bg
        fg  <- sw$fg
        acc <- sw$accent
        lnk <- sw$accent  # fallback: link = accent for built-ins
        fnt <- "Source Sans Pro"
      } else if (nzchar(sel)) {
        path <- file.path("data/themes", sel)
        if (file.exists(path)) {
          scss_text <- paste(readLines(path, warn = FALSE), collapse = "\n")
          full <- parse_scss_colors_full(scss_text)
          bg  <- full$bg
          fg  <- full$fg
          acc <- full$accent
          lnk <- full$link
          fnt <- full$font
        } else {
          return()
        }
      } else {
        return()
      }

      updateTextInput(session, "bg_hex",     value = bg)
      updateTextInput(session, "text_hex",   value = fg)
      updateTextInput(session, "accent_hex", value = acc)
      updateTextInput(session, "link_hex",   value = lnk)
      updateSelectInput(session, "font",     selected = fnt)

      # Update native color swatches via JS (Shiny doesn't bind raw <input type="color">)
      session$sendCustomMessage("update_color_swatch", list(
        ids    = list(ns("bg_swatch"), ns("text_swatch"), ns("accent_swatch"), ns("link_swatch")),
        values = list(tolower(bg), tolower(fg), tolower(acc), tolower(lnk))
      ))
    }, ignoreInit = TRUE)

    # Swatch dot live update: rebuild dropdown choices with overridden colors for current theme
    observe({
      bg_val  <- input$bg_hex
      fg_val  <- input$text_hex
      acc_val <- input$accent_hex
      req(bg_val, fg_val, acc_val)

      is_hex <- function(v) grepl("^#[0-9A-Fa-f]{6}$", v)
      if (!all(sapply(c(bg_val, fg_val, acc_val), is_hex))) return()

      sel <- isolate(input$theme)
      req(sel)

      custom <- list_custom_themes()
      df <- build_theme_choices_df(custom)
      row_idx <- which(df$value == sel)
      if (length(row_idx) == 1) {
        df$bg[row_idx]     <- toupper(bg_val)
        df$fg[row_idx]     <- toupper(fg_val)
        df$accent[row_idx] <- toupper(acc_val)
      }
      updateSelectizeInput(session, "theme", choices = df, selected = sel, server = TRUE)
    })

    # Save custom theme: write .scss, auto-select, collapse panel, show toast
    observeEvent(input$save_custom_theme, {
      name <- trimws(input$custom_theme_name)
      if (!nzchar(name)) {
        # Focus the name field via JS
        session$sendCustomMessage("focus_element", ns("custom_theme_name"))
        return()
      }

      path <- generate_custom_scss(
        name         = name,
        bg_color     = input$bg_hex,
        text_color   = input$text_hex,
        accent_color = input$accent_hex,
        link_color   = input$link_hex,
        font_name    = input$font
      )

      if (!is.null(path)) {
        refresh_theme_dropdown(selected = basename(path))
        showNotification(paste0("Theme '", name, "' saved"), type = "message")
        # Collapse the panel via JS
        session$sendCustomMessage("collapse_panel", ns("customize_panel"))
        # Reset AI generation state
        ai_generated(FALSE)
        last_ai_description(NULL)
      } else {
        showNotification("Could not save theme. Check file permissions.", type = "error")
      }
    })

    # AI Theme Generation — Generate button observer
    observeEvent(input$ai_generate_btn, {
      description <- input$ai_theme_description
      if (is.null(description) || !nzchar(trimws(description))) {
        showNotification("Please enter a theme description.", type = "warning")
        return()
      }

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      model <- get_setting(cfg, "defaults", "chat_model") %||% "google/gemini-3.1-flash-lite-preview"

      if (is.null(api_key) || !nzchar(api_key)) {
        showNotification("Please set your API key in Settings first.", type = "error")
        return()
      }

      # Save description for Regenerate
      last_ai_description(trimws(description))

      # Spinner on
      session$sendCustomMessage("set_button_loading",
        list(id = ns("ai_generate_btn"), loading = TRUE, text = "Generating..."))

      # Attempt generation with 1 retry on JSON failure
      last_api_error <- NULL
      attempt_generate <- function(desc, attempt_num = 1) {
        result <- tryCatch(
          generate_theme_from_description(api_key, model, desc),
          error = function(e) {
            last_api_error <<- conditionMessage(e)
            list(content = NULL, usage = NULL)
          }
        )

        # Log cost regardless of parse success
        if (!is.null(result$usage)) {
          cost <- estimate_cost(model,
                                prompt_tokens = result$usage$prompt_tokens,
                                completion_tokens = result$usage$completion_tokens)
          log_cost(con(),
                   operation = "theme_generation",
                   model = model,
                   prompt_tokens = result$usage$prompt_tokens,
                   completion_tokens = result$usage$completion_tokens,
                   estimated_cost = cost,
                   session_id = session$token)
        }

        if (is.null(result$content)) {
          if (attempt_num < 2) return(attempt_generate(desc, 2))
          err_msg <- if (!is.null(last_api_error)) {
            paste0("Theme generation failed: ", last_api_error)
          } else {
            "Couldn't generate theme. Try a more specific description."
          }
          return(list(theme = NULL, error = err_msg))
        }

        json <- extract_theme_json(result$content)
        if (is.null(json)) {
          if (attempt_num < 2) return(attempt_generate(desc, 2))
          return(list(theme = NULL, error = "Couldn't parse theme from AI response. Try a more specific description."))
        }

        list(theme = json, usage = result$usage, error = NULL)
      }

      gen_result <- attempt_generate(description)

      # Spinner off
      session$sendCustomMessage("set_button_loading",
        list(id = ns("ai_generate_btn"), loading = FALSE, label = "Generate theme"))

      if (!is.null(gen_result$error)) {
        showNotification(gen_result$error, type = "error")
        return()
      }

      theme <- gen_result$theme

      # Validate hex colors
      bad_colors <- validate_theme_colors(theme)
      if (length(bad_colors) > 0) {
        showNotification(
          paste0("Theme has invalid colors (", paste(bad_colors, collapse = ", "),
                 "). Try a more specific description."),
          type = "error")
        return()
      }

      # Validate font
      font_result <- validate_and_fix_font(if (is.null(theme$mainFont)) "" else theme$mainFont)
      if (!is.null(font_result$warning)) {
        showNotification(font_result$warning, type = "warning")
      }

      # Populate color pickers and font selector
      bg  <- theme$backgroundColor
      fg  <- theme$mainColor
      acc <- theme$accentColor
      lnk <- theme$linkColor
      fnt <- font_result$font

      updateTextInput(session, "bg_hex",     value = bg)
      updateTextInput(session, "text_hex",   value = fg)
      updateTextInput(session, "accent_hex", value = acc)
      updateTextInput(session, "link_hex",   value = lnk)
      updateSelectInput(session, "font",     selected = fnt)

      session$sendCustomMessage("update_color_swatch", list(
        ids    = list(ns("bg_swatch"), ns("text_swatch"), ns("accent_swatch"), ns("link_swatch")),
        values = list(tolower(bg), tolower(fg), tolower(acc), tolower(lnk))
      ))

      # Auto-save as custom theme so it's immediately usable for slide generation
      ai_theme_name <- paste0("AI-", format(Sys.time(), "%H%M%S"))
      path <- generate_custom_scss(
        name         = ai_theme_name,
        bg_color     = bg,
        text_color   = fg,
        accent_color = acc,
        link_color   = lnk,
        font_name    = fnt
      )
      if (!is.null(path)) {
        refresh_theme_dropdown(selected = basename(path))
        updateTextInput(session, "custom_theme_name", value = ai_theme_name)
      }

      # Expand customize panel
      session$sendCustomMessage("expand_panel", ns("customize_panel"))

      # Mark AI generation as complete (shows Regenerate button)
      ai_generated(TRUE)
    })

    # Regenerate button — only visible after AI generation
    output$regenerate_btn_area <- renderUI({
      if (!ai_generated()) return(NULL)
      div(
        class = "mt-1",
        actionButton(ns("regenerate_theme"), "Regenerate",
                     class = "btn btn-outline-secondary btn-sm",
                     icon = icon("rotate"))
      )
    })

    # Regenerate observer — re-runs AI generation with last description
    observeEvent(input$regenerate_theme, {
      description <- last_ai_description()
      if (is.null(description) || !nzchar(description)) return()

      cfg <- config()
      api_key <- get_setting(cfg, "openrouter", "api_key")
      model <- get_setting(cfg, "defaults", "chat_model") %||% "google/gemini-3.1-flash-lite-preview"

      session$sendCustomMessage("set_button_loading",
        list(id = ns("regenerate_theme"), loading = TRUE, text = "Regenerating..."))

      last_api_error <- NULL
      attempt_generate <- function(desc, attempt_num = 1) {
        result <- tryCatch(
          generate_theme_from_description(api_key, model, desc),
          error = function(e) {
            last_api_error <<- conditionMessage(e)
            list(content = NULL, usage = NULL)
          }
        )
        if (!is.null(result$usage)) {
          cost <- estimate_cost(model,
                                prompt_tokens = result$usage$prompt_tokens,
                                completion_tokens = result$usage$completion_tokens)
          log_cost(con(),
                   operation = "theme_generation",
                   model = model,
                   prompt_tokens = result$usage$prompt_tokens,
                   completion_tokens = result$usage$completion_tokens,
                   estimated_cost = cost,
                   session_id = session$token)
        }
        if (is.null(result$content)) {
          if (attempt_num < 2) return(attempt_generate(desc, 2))
          err_msg <- if (!is.null(last_api_error)) {
            paste0("Theme generation failed: ", last_api_error)
          } else {
            "Couldn't generate theme. Try a more specific description."
          }
          return(list(theme = NULL, error = err_msg))
        }
        json <- extract_theme_json(result$content)
        if (is.null(json)) {
          if (attempt_num < 2) return(attempt_generate(desc, 2))
          return(list(theme = NULL, error = "Couldn't parse theme from AI response. Try a more specific description."))
        }
        list(theme = json, usage = result$usage, error = NULL)
      }

      gen_result <- attempt_generate(description)

      session$sendCustomMessage("set_button_loading",
        list(id = ns("regenerate_theme"), loading = FALSE, label = "Regenerate"))

      if (!is.null(gen_result$error)) {
        showNotification(gen_result$error, type = "error")
        return()
      }

      theme <- gen_result$theme
      bad_colors <- validate_theme_colors(theme)
      if (length(bad_colors) > 0) {
        showNotification(
          paste0("Theme has invalid colors (", paste(bad_colors, collapse = ", "),
                 "). Try a more specific description."),
          type = "error")
        return()
      }

      font_result <- validate_and_fix_font(if (is.null(theme$mainFont)) "" else theme$mainFont)
      if (!is.null(font_result$warning)) {
        showNotification(font_result$warning, type = "warning")
      }

      bg  <- theme$backgroundColor
      fg  <- theme$mainColor
      acc <- theme$accentColor
      lnk <- theme$linkColor
      fnt <- font_result$font

      updateTextInput(session, "bg_hex",     value = bg)
      updateTextInput(session, "text_hex",   value = fg)
      updateTextInput(session, "accent_hex", value = acc)
      updateTextInput(session, "link_hex",   value = lnk)
      updateSelectInput(session, "font",     selected = fnt)

      session$sendCustomMessage("update_color_swatch", list(
        ids    = list(ns("bg_swatch"), ns("text_swatch"), ns("accent_swatch"), ns("link_swatch")),
        values = list(tolower(bg), tolower(fg), tolower(acc), tolower(lnk))
      ))

      # Auto-save regenerated theme so it's immediately usable for slide generation
      ai_theme_name <- paste0("AI-", format(Sys.time(), "%H%M%S"))
      path <- generate_custom_scss(
        name         = ai_theme_name,
        bg_color     = bg,
        text_color   = fg,
        accent_color = acc,
        link_color   = lnk,
        font_name    = fnt
      )
      if (!is.null(path)) {
        refresh_theme_dropdown(selected = basename(path))
        updateTextInput(session, "custom_theme_name", value = ai_theme_name)
      }
    })

    # Handle generation
    observeEvent(input$generate, {
      req(input$selected_docs)
      nb_id <- notebook_id()
      cfg <- config()

      # Get selected document IDs
      doc_ids <- input$selected_docs

      if (length(doc_ids) == 0) {
        showNotification("Please select at least one document", type = "warning")
        return()
      }

      # Resolve theme vs custom_scss based on selected value
      # Theme resolution: if a picker-generated custom theme was saved and auto-selected,
      # it appears as a custom .scss filename in input$theme (same path as uploaded themes).
      # No special handling needed — the existing custom_scss logic covers it.
      selected_theme <- input$theme
      if (!is.null(selected_theme) && selected_theme %in% names(BUILTIN_THEME_SWATCHES)) {
        theme_val      <- selected_theme
        custom_scss_val <- NULL
      } else if (!is.null(selected_theme) && nzchar(selected_theme)) {
        theme_val      <- "default"
        custom_scss_val <- file.path("data/themes", selected_theme)
      } else {
        theme_val      <- "default"
        custom_scss_val <- NULL
      }

      # Store options for regeneration
      generation_state$last_options <- list(
        model = input$model,
        length = input$length,
        audience = input$audience,
        citation_style = input$citation_style,
        include_notes = input$include_notes,
        theme = theme_val,
        custom_scss = custom_scss_val,
        custom_instructions = input$custom_instructions
      )

      # Show loading modal
      show_results()

      # Get chunks for selected documents
      showNotification("Preparing content...", id = "slides_progress", duration = NULL, type = "message")
      chunks <- tryCatch({
        get_chunks_for_documents(con(), doc_ids)
      }, error = function(e) {
        removeNotification("slides_progress")
        generation_state$error <- paste("Failed to load documents:", e$message)
        show_results(error = generation_state$error)
        return(NULL)
      })
      if (is.null(chunks)) return()

      if (nrow(chunks) == 0) {
        removeNotification("slides_progress")
        generation_state$error <- "No content found in selected documents"
        show_results(error = generation_state$error)
        return()
      }

      # Store chunks for fallback
      generation_state$last_chunks <- chunks

      # Reset heal state for fresh generation
      generation_state$heal_attempts <- 0
      generation_state$is_fallback <- FALSE
      generation_state$validation_errors <- NULL

      # Get notebook name for title
      nb <- get_notebook(con(), nb_id)
      notebook_name <- nb$name %||% "Presentation"

      # Generate slides
      showNotification(
        paste0("Generating slides with ", input$model, "..."),
        id = "slides_progress", duration = NULL, type = "message"
      )
      provider <- provider_from_config(cfg, con())

      result <- generate_slides(
        provider = provider,
        model = input$model,
        chunks = chunks,
        options = generation_state$last_options,
        notebook_name = notebook_name,
        con = con(),
        session_id = session$token
      )

      if (!is.null(result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- result$error
        show_results(error = result$error)
        return()
      }

      generation_state$qmd_content <- result$qmd
      generation_state$qmd_path <- result$qmd_path

      # Store validation errors if any
      if (!is.null(result$validation) && !result$validation$valid) {
        generation_state$validation_errors <- result$validation$errors
      }

      # Render to HTML for preview
      showNotification("Rendering preview with Quarto...", id = "slides_progress", duration = NULL, type = "message")
      html_result <- render_qmd_to_html(result$qmd_path)

      if (!is.null(html_result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- paste("Preview failed:", html_result$error, "- You can still download the .qmd file")
        show_results(error = generation_state$error)
        return()
      }

      generation_state$html_path <- html_result$path
      generation_state$error <- NULL

      # Create resource path for preview
      preview_name <- basename(html_result$path)
      tryCatch(removeResourcePath("slides_preview"), error = function(e) NULL)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      removeNotification("slides_progress")
      show_results(preview_url = preview_url)
    })

    # Handle opening healing modal
    observeEvent(input$open_heal, {
      # Determine current errors
      errors <- generation_state$validation_errors %||% character(0)
      if (length(errors) == 0 && !is.null(generation_state$error)) {
        errors <- generation_state$error
      }

      # Determine if generation was successful
      is_success <- is.null(generation_state$error) && length(generation_state$validation_errors %||% character(0)) == 0

      # Store chips for click handlers
      current_chips(get_healing_chips(errors, is_success))

      showModal(mod_slides_heal_modal_ui(ns, errors, is_success))
    }, ignoreInit = TRUE)

    # Chip click handlers (up to 10 chips)
    lapply(seq_len(10), function(i) {
      observeEvent(input[[paste0("chip_", i)]], {
        chips <- current_chips()
        if (i <= length(chips)) {
          updateTextAreaInput(session, "heal_instructions", value = chips[i])
        }
      }, ignoreInit = TRUE)
    })

    # Handle healing execution
    observeEvent(input$do_heal, {
      generation_state$heal_attempts <- generation_state$heal_attempts + 1
      attempt <- generation_state$heal_attempts

      cfg <- config()
      provider <- provider_from_config(cfg, con())

      # Check if we've exceeded the retry limit
      if (attempt > 2) {
        # FALLBACK PATH
        chunks <- generation_state$last_chunks
        if (is.null(chunks) || nrow(chunks) == 0) {
          show_results(error = "Cannot generate fallback: no source content available")
          return()
        }

        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        notebook_name <- nb$name %||% "Presentation"

        # Generate fallback template
        fallback_qmd <- build_fallback_qmd(chunks, notebook_name)
        generation_state$qmd_content <- fallback_qmd
        generation_state$is_fallback <- TRUE
        generation_state$error <- NULL
        generation_state$validation_errors <- NULL

        # Save to temp file
        qmd_path <- file.path(tempdir(), paste0(gsub("[^a-zA-Z0-9]", "-", notebook_name), "-fallback-slides.qmd"))
        writeLines(fallback_qmd, qmd_path)
        generation_state$qmd_path <- qmd_path

        # Render fallback
        showNotification("Generating fallback template...", id = "slides_progress", duration = NULL, type = "message")
        html_result <- render_qmd_to_html(qmd_path)
        removeNotification("slides_progress")

        if (!is.null(html_result$error)) {
          generation_state$error <- paste("Fallback render failed:", html_result$error)
          show_results(error = generation_state$error)
          return()
        }

        generation_state$html_path <- html_result$path
        preview_name <- basename(html_result$path)
        tryCatch(removeResourcePath("slides_preview"), error = function(e) NULL)
      addResourcePath("slides_preview", dirname(html_result$path))
        preview_url <- paste0("slides_preview/", preview_name)

        show_results(preview_url = preview_url)
        return()
      }

      # HEALING PATH (attempt <= 2)
      # Show loading results modal
      show_results()

      previous_qmd <- generation_state$qmd_content
      errors <- generation_state$validation_errors %||% character(0)
      if (length(errors) == 0 && !is.null(generation_state$error)) {
        errors <- generation_state$error
      }
      instructions <- input$heal_instructions %||% ""

      model <- generation_state$last_options$model %||%
        resolve_model_for_operation(cfg, "slide_healing")

      showNotification(
        sprintf("Healing slides (attempt %d of 2)...", attempt),
        id = "slides_progress", duration = NULL, type = "message"
      )

      heal_result <- heal_slides(
        provider = provider,
        model = model,
        previous_qmd = previous_qmd,
        errors = errors,
        instructions = instructions,
        con = con(),
        session_id = session$token
      )

      if (!is.null(heal_result$error)) {
        removeNotification("slides_progress")
        generation_state$error <- heal_result$error
        show_results(error = heal_result$error)
        return()
      }

      # Validate healed output
      validation <- validate_qmd_yaml(heal_result$qmd)
      generation_state$qmd_content <- heal_result$qmd
      generation_state$qmd_path <- heal_result$qmd_path

      if (!validation$valid) {
        removeNotification("slides_progress")
        generation_state$validation_errors <- validation$errors
        generation_state$error <- paste("Validation failed:", paste(validation$errors, collapse = "; "))
        show_results(error = generation_state$error)
        return()
      }

      # Validation passed - rebuild with clean frontmatter, then render
      generation_state$validation_errors <- NULL
      generation_state$error <- NULL

      # Strip whatever YAML the LLM produced and rebuild with known-good frontmatter
      stripped <- strip_llm_yaml(heal_result$qmd)
      title <- stripped$title %||% generation_state$title %||% "Presentation"
      theme <- generation_state$last_options$theme %||% "default"
      custom_scss <- generation_state$last_options$custom_scss
      # Re-copy .scss to tempdir and resolve to absolute path for Quarto
      if (!is.null(custom_scss)) {
        scss_dest <- file.path(tempdir(), basename(custom_scss))
        file.copy(custom_scss, scss_dest, overwrite = TRUE)
        custom_scss <- normalizePath(scss_dest, winslash = "/", mustWork = FALSE)
      }
      frontmatter <- build_qmd_frontmatter(title, theme, custom_scss)
      qmd_content <- paste0(frontmatter, "\n", stripped$content)
      generation_state$qmd_content <- qmd_content

      # Re-save with clean frontmatter
      writeLines(qmd_content, heal_result$qmd_path)

      showNotification("Rendering healed preview...", id = "slides_progress", duration = NULL, type = "message")
      html_result <- render_qmd_to_html(heal_result$qmd_path)
      removeNotification("slides_progress")

      if (!is.null(html_result$error)) {
        generation_state$error <- paste("Render failed:", html_result$error)
        show_results(error = generation_state$error)
        return()
      }

      generation_state$html_path <- html_result$path
      preview_name <- basename(html_result$path)
      tryCatch(removeResourcePath("slides_preview"), error = function(e) NULL)
      addResourcePath("slides_preview", dirname(html_result$path))
      preview_url <- paste0("slides_preview/", preview_name)

      show_results(preview_url = preview_url)
    }, ignoreInit = TRUE)

    # Handle regeneration - reopens full config modal
    observeEvent(input$regenerate, {
      nb_id <- notebook_id()
      req(nb_id)

      # Reset healing state
      generation_state$heal_attempts <- 0
      generation_state$is_fallback <- FALSE
      generation_state$validation_errors <- NULL

      docs <- list_documents(con(), nb_id)
      cfg <- config()
      provider <- provider_from_config(cfg, con())

      models <- tryCatch({
        provider_list_models(provider)
      }, error = function(e) {
        data.frame(id = "google/gemini-3.1-flash-lite-preview", name = "Gemini 3.1 Flash Lite", stringsAsFactors = FALSE)
      })

      current_model <- generation_state$last_options$model %||%
                       resolve_model_for_operation(cfg, "slide_generation")

      showModal(mod_slides_modal_ui(ns, docs, models, current_model))
      # Restore previously selected theme in dropdown (built-in or custom .scss filename)
      last_custom_scss <- generation_state$last_options$custom_scss
      last_theme <- if (!is.null(last_custom_scss)) {
        basename(last_custom_scss)
      } else {
        generation_state$last_options$theme %||% "default"
      }
      refresh_theme_dropdown(selected = last_theme)
    })

    # Download handlers
    output$download_qmd <- downloadHandler(
      filename = function() {
        nb <- get_notebook(con(), notebook_id())
        base <- gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides")
        if (!is.null(generation_state$last_options$custom_scss)) {
          paste0(base, ".zip")
        } else {
          paste0(base, ".qmd")
        }
      },
      content = function(file) {
        req(generation_state$qmd_content)
        custom_scss <- generation_state$last_options$custom_scss
        if (!is.null(custom_scss) && file.exists(custom_scss)) {
          scss_basename <- basename(custom_scss)
          # Rebuild frontmatter with relative SCSS path instead of absolute temp path
          nb <- get_notebook(con(), notebook_id())
          title <- nb$name %||% "Slides"
          theme <- generation_state$last_options$theme %||% "default"
          portable_frontmatter <- build_qmd_frontmatter(title, theme, scss_basename)
          # Extract slide body (everything after closing --- of frontmatter)
          body <- sub("^---\\n.*?\\n---\\n?", "", generation_state$qmd_content)
          portable_qmd <- paste0(portable_frontmatter, "\n", body)
          # Bundle QMD + SCSS into zip
          tmp_dir <- file.path(tempdir(), "qmd_export")
          dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
          on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
          writeLines(portable_qmd, file.path(tmp_dir, "slides.qmd"))
          file.copy(custom_scss, file.path(tmp_dir, scss_basename), overwrite = TRUE)
          old_wd <- setwd(tmp_dir)
          on.exit(setwd(old_wd), add = TRUE)
          utils::zip(file, files = c("slides.qmd", scss_basename))
        } else {
          writeLines(generation_state$qmd_content, file)
        }
      }
    )

    output$download_html <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".html")
      },
      content = function(file) {
        req(generation_state$html_path)
        file.copy(generation_state$html_path, file)
      }
    )

    output$download_pdf <- downloadHandler(
      filename = function() {
        nb_id <- notebook_id()
        nb <- get_notebook(con(), nb_id)
        paste0(gsub("[^a-zA-Z0-9]", "-", nb$name %||% "slides"), ".pdf")
      },
      content = function(file) {
        req(generation_state$qmd_path)

        # Render PDF on demand
        withProgress(message = "Rendering PDF...", {
          pdf_result <- render_qmd_to_pdf(generation_state$qmd_path)

          if (!is.null(pdf_result$error)) {
            showNotification(
              tagList(
                "PDF export failed: ", pdf_result$error,
                tags$br(),
                "Tip: Run ", tags$code("quarto install tinytex"), " in your terminal to enable PDF export."
              ),
              type = "error",
              duration = 10
            )
            return()
          }

          file.copy(pdf_result$path, file)
        })
      }
    )
  })
}
