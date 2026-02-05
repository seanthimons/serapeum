#' About Module UI
#' @param id Module ID
mod_about_ui <- function(id) {
  ns <- NS(id)

  card(
    class = "border-0",
    card_body(
      class = "py-4",

      # Header
      div(
        class = "text-center mb-4",
        icon("book-open", class = "fa-3x text-primary mb-3"),
        h2("About Serapeum"),
        p(class = "lead text-muted",
          "A local-first, self-hosted research assistant inspired by NotebookLM")
      ),

      hr(class = "my-4"),

      # Main content in columns
      layout_columns(
        col_widths = c(6, 6),

        # Left column - Built With
        div(
          h4(icon("wrench"), " Built With"),
          div(
            class = "d-flex flex-wrap gap-2 mb-4",
            span(class = "badge bg-primary fs-6", "R"),
            span(class = "badge bg-primary fs-6", "Shiny"),
            span(class = "badge bg-primary fs-6", "bslib"),
            span(class = "badge bg-primary fs-6", "DuckDB")
          ),

          h5(class = "mt-4", "Core Technologies"),
          tags$ul(
            class = "list-unstyled",
            tags$li(
              class = "mb-2",
              icon("database", class = "text-primary me-2"),
              tags$strong("DuckDB"), " - Embedded analytical database with vector search"
            ),
            tags$li(
              class = "mb-2",
              icon("robot", class = "text-primary me-2"),
              tags$strong("OpenRouter"), " - Unified API for multiple LLM providers"
            ),
            tags$li(
              class = "mb-2",
              icon("magnifying-glass", class = "text-primary me-2"),
              tags$strong("OpenAlex"), " - Free academic paper search API (240M+ works)"
            ),
            tags$li(
              class = "mb-2",
              icon("file-pdf", class = "text-danger me-2"),
              tags$strong("pdftools"), " - PDF text extraction"
            )
          )
        ),

        # Right column - Key Packages
        div(
          h4(icon("box"), " Key Packages"),
          div(
            class = "row g-2",

            # Package badges with links
            div(
              class = "col-6",
              tags$a(
                href = "https://shiny.posit.co/",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://raw.githubusercontent.com/rstudio/shiny/main/man/figures/logo.png",
                           height = "30", alt = "shiny", onerror = "this.style.display='none'"),
                  span("shiny")
                )
              )
            ),
            div(
              class = "col-6",
              tags$a(
                href = "https://rstudio.github.io/bslib/",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://raw.githubusercontent.com/rstudio/bslib/main/man/figures/logo.png",
                           height = "30", alt = "bslib", onerror = "this.style.display='none'"),
                  span("bslib")
                )
              )
            ),
            div(
              class = "col-6",
              tags$a(
                href = "https://duckdb.org/docs/api/r.html",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://duckdb.org/images/logo-dl/DuckDB_Logo-horizontal.png",
                           height = "30", alt = "duckdb", onerror = "this.style.display='none'"),
                  span("duckdb")
                )
              )
            ),
            div(
              class = "col-6",
              tags$a(
                href = "https://docs.ropensci.org/pdftools/",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://docs.ropensci.org/pdftools/logo.png",
                           height = "30", alt = "pdftools", onerror = "this.style.display='none'"),
                  span("pdftools")
                )
              )
            ),
            div(
              class = "col-6",
              tags$a(
                href = "https://httr2.r-lib.org/",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://raw.githubusercontent.com/r-lib/httr2/main/man/figures/logo.png",
                           height = "30", alt = "httr2", onerror = "this.style.display='none'"),
                  span("httr2")
                )
              )
            ),
            div(
              class = "col-6",
              tags$a(
                href = "https://www.tidyverse.org/",
                target = "_blank",
                class = "text-decoration-none",
                div(
                  class = "p-2 border rounded d-flex align-items-center gap-2 hover-bg-light",
                  tags$img(src = "https://raw.githubusercontent.com/tidyverse/tidyverse/main/man/figures/logo.png",
                           height = "30", alt = "tidyverse", onerror = "this.style.display='none'"),
                  span("tidyverse")
                )
              )
            )
          )
        )
      ),

      hr(class = "my-4"),

      # Credits and Links
      layout_columns(
        col_widths = c(4, 4, 4),

        # Source
        div(
          class = "text-center",
          icon("github", class = "fa-2x mb-2"),
          h5("Source Code"),
          tags$a(
            href = "https://github.com/seanthimons/serapeum",
            target = "_blank",
            class = "btn btn-outline-dark",
            icon("github"), " View on GitHub"
          )
        ),

        # Inspiration
        div(
          class = "text-center",
          icon("lightbulb", class = "fa-2x mb-2 text-warning"),
          h5("Inspiration"),
          p(class = "text-muted small mb-1", "Inspired by"),
          tags$a(
            href = "https://notebooklm.google.com/",
            target = "_blank",
            "NotebookLM"
          )
        ),

        # Data Sources
        div(
          class = "text-center",
          icon("database", class = "fa-2x mb-2 text-info"),
          h5("Data Sources"),
          p(class = "small mb-0",
            tags$a(href = "https://openalex.org/", target = "_blank", "OpenAlex"), " for papers"
          ),
          p(class = "small mb-0",
            tags$a(href = "https://openrouter.ai/", target = "_blank", "OpenRouter"), " for LLMs"
          )
        )
      ),

      hr(class = "my-4"),

      # Disclaimer
      div(
        class = "alert alert-warning",
        h5(class = "alert-heading", icon("triangle-exclamation"), " Important Disclaimer"),
        p(class = "mb-2", tags$strong("Serapeum is a research tool powered by AI language models.")),
        tags$ul(
          class = "small mb-0",
          tags$li(tags$strong("Not an Oracle:"), " AI-generated responses may contain errors, hallucinations, or inaccuracies. Always verify important information from primary sources."),
          tags$li(tags$strong("Not Professional Advice:"), " Not a substitute for professional, medical, legal, financial, or other expert advice."),
          tags$li(tags$strong("Makes Mistakes:"), " AI models can misinterpret documents, generate plausible-sounding but incorrect answers, and miss important context."),
          tags$li(tags$strong("Not a Flotation Device:"), " Use at your own risk. The authors and contributors assume no liability for decisions made based on AI-generated content."),
          tags$li(tags$strong("Research Tool Only:"), " Intended for exploratory research. Critical decisions should be based on original sources.")
        )
      ),

      hr(class = "my-4"),

      # Footer with naming
      div(
        class = "text-center text-muted",
        p(
          tags$em("Named after the "),
          tags$a(
            href = "https://en.wikipedia.org/wiki/Serapeum_of_Alexandria",
            target = "_blank",
            "Serapeum of Alexandria"
          ),
          tags$em(", the daughter library of the ancient Library of Alexandria.")
        ),
        p(class = "small", "MIT License")
      )
    )
  )
}

#' About Module Server
#' @param id Module ID
mod_about_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # No server logic needed for about page
  })
}
