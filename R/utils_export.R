#' Format chat messages as Markdown
#'
#' Converts a list of message objects into Markdown format with headers,
#' timestamps, and message content.
#'
#' @param messages List of message objects (each with role, content, timestamp)
#' @param notebook_name Optional notebook name for subtitle
#' @return Markdown string
#' @examples
#' msgs <- list(
#'   list(role = "user", content = "Hello", timestamp = Sys.time()),
#'   list(role = "assistant", content = "Hi there", timestamp = Sys.time())
#' )
#' cat(format_chat_as_markdown(msgs))
format_chat_as_markdown <- function(messages, notebook_name = NULL) {
  if (length(messages) == 0) {
    return("# Chat Export\n\nNo messages in this conversation.")
  }

  # Header
  md <- "# Chat Export\n\n"
  if (!is.null(notebook_name) && nchar(notebook_name) > 0) {
    md <- paste0(md, "## ", notebook_name, "\n\n")
  }

  # Export date
  export_date <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  md <- paste0(md, "Exported: ", export_date, "\n\n")
  md <- paste0(md, "---\n\n")

  # Messages
  for (msg in messages) {
    # Role header
    role_header <- if (msg$role == "user") "### User" else "### Assistant"
    md <- paste0(md, role_header, "\n\n")

    # Timestamp (if available)
    if (!is.null(msg$timestamp) && !is.na(msg$timestamp)) {
      timestamp_str <- format(msg$timestamp, "%Y-%m-%d %H:%M:%S")
      md <- paste0(md, "*", timestamp_str, "*\n\n")
    }

    # Content
    md <- paste0(md, msg$content, "\n\n")

    # Separator
    md <- paste0(md, "---\n\n")
  }

  md
}

#' Format chat messages as HTML
#'
#' Converts chat messages to Markdown, then to HTML with embedded CSS.
#' Creates a standalone HTML document with no external dependencies.
#'
#' @param messages List of message objects (each with role, content, timestamp)
#' @param notebook_name Optional notebook name for page title
#' @return Complete HTML document string
#' @examples
#' msgs <- list(
#'   list(role = "user", content = "Hello", timestamp = Sys.time()),
#'   list(role = "assistant", content = "Hi there", timestamp = Sys.time())
#' )
#' html <- format_chat_as_html(msgs)
#' writeLines(html, "chat.html")
format_chat_as_html <- function(messages, notebook_name = NULL) {
  # Get Markdown content
  markdown_content <- format_chat_as_markdown(messages, notebook_name)

  # Convert to HTML
  html_body <- commonmark::markdown_html(markdown_content, extensions = TRUE, smart = TRUE)

  # Page title
  page_title <- if (!is.null(notebook_name) && nchar(notebook_name) > 0) {
    notebook_name
  } else {
    "Chat Export"
  }

  # Build standalone HTML document
  html <- paste0(
    '<!DOCTYPE html>',
    '<html lang="en">',
    '<head>',
    '<meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    '<title>', htmltools::htmlEscape(page_title), '</title>',
    '<style>',
    'body {',
    '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;',
    '  line-height: 1.6;',
    '  max-width: 800px;',
    '  margin: 0 auto;',
    '  padding: 2rem;',
    '  background-color: #f8f9fa;',
    '  color: #333;',
    '}',
    'h1, h2, h3 {',
    '  color: #333;',
    '  margin-top: 1.5rem;',
    '  margin-bottom: 0.5rem;',
    '}',
    'h1 {',
    '  border-bottom: 2px solid #dee2e6;',
    '  padding-bottom: 0.5rem;',
    '}',
    'h3 {',
    '  color: #495057;',
    '  margin-top: 1rem;',
    '}',
    'hr {',
    '  border: none;',
    '  border-top: 1px solid #dee2e6;',
    '  margin: 1rem 0;',
    '}',
    'pre, code {',
    '  background-color: #e9ecef;',
    '  border-radius: 0.25rem;',
    '  padding: 0.2rem 0.4rem;',
    '  font-family: "Courier New", Courier, monospace;',
    '}',
    'pre {',
    '  padding: 1rem;',
    '  overflow-x: auto;',
    '}',
    'em {',
    '  color: #6c757d;',
    '  font-size: 0.9rem;',
    '}',
    '</style>',
    '</head>',
    '<body>',
    html_body,
    '</body>',
    '</html>'
  )

  html
}
