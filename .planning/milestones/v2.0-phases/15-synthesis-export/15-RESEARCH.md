# Phase 15: Synthesis Export - Research

**Researched:** 2026-02-12
**Domain:** Markdown/HTML generation, chat conversation export
**Confidence:** HIGH

## Summary

Phase 15 enables users to export chat conversations (from document and search notebooks) as Markdown or HTML files. This is a **formatting and download** phase building on Phase 14's export patterns. The core challenge is formatting chat messages with timestamps and role labels, generating clean Markdown syntax, and optionally wrapping Markdown in standalone HTML with CSS for browser viewing.

**Key finding:** No complex libraries needed. Use base R string concatenation for Markdown generation, commonmark package for Markdown-to-HTML conversion, and Shiny's downloadHandler pattern already proven in Phase 14.

**Primary recommendation:** Build chat export formatters using string templates for Markdown (timestamp + role + message), use commonmark::markdown_html() for HTML conversion with embedded CSS, and add download buttons to existing chat interfaces in both notebook modules.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R | 4.5.1 | String concatenation, file I/O | Built-in, no dependencies |
| Shiny | current | downloadHandler, downloadButton | Already in project (Phase 14) |
| commonmark | 2.0.0+ | Markdown to HTML conversion | Fast C-based parser, GitHub-flavored markdown support |

### Supporting
None required - this is a formatting task similar to Phase 14's citation export.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| commonmark | rmarkdown::render() | Heavier (requires pandoc), overkill for simple markdown-to-HTML |
| commonmark | markdown package | Older, less maintained, uses commonmark internally anyway |
| Custom HTML | HTML templates with htmltools | More complex, unnecessary for simple chat export |

**Why commonmark:** Lightweight, actively maintained by rOpenSci, supports GitHub-flavored markdown (needed for code blocks in chat responses), and provides single-function conversion (markdown_html()). The rmarkdown package is designed for full document rendering with YAML headers, not simple text conversion.

**Installation:**
```r
# commonmark is likely already installed as a Shiny dependency
# If not: install.packages("commonmark")
```

## Architecture Patterns

### Recommended Project Structure
```
R/
├── utils_export.R          # Chat export formatters (Markdown, HTML)
├── mod_search_notebook.R   # Add download button to existing chat UI
├── mod_document_notebook.R # Add download button to existing chat UI
```

### Pattern 1: Markdown Chat Formatting
**What:** Format each message with timestamp, role label (User/Assistant), and content.
**When to use:** Always for chat exports - provides human-readable structure.

**Example:**
```r
# Based on conversation export best practices
format_chat_as_markdown <- function(messages) {
  if (length(messages) == 0) {
    return("# Chat Conversation\n\nNo messages yet.")
  }

  lines <- c("# Chat Conversation", "")

  for (msg in messages) {
    # Add timestamp if available (optional)
    timestamp <- if (!is.null(msg$timestamp)) {
      format(msg$timestamp, "%Y-%m-%d %H:%M:%S")
    } else {
      NULL
    }

    # Role header (User or Assistant)
    role_label <- if (msg$role == "user") "**User**" else "**Assistant**"
    header <- if (!is.null(timestamp)) {
      sprintf("%s — %s", role_label, timestamp)
    } else {
      role_label
    }

    lines <- c(lines, header, "")
    lines <- c(lines, msg$content, "")
  }

  paste(lines, collapse = "\n")
}
```

### Pattern 2: Markdown to HTML with Embedded CSS
**What:** Convert markdown to HTML using commonmark, wrap in full HTML document with CSS.
**When to use:** For browser-viewable exports with visual styling.

**Example:**
```r
format_chat_as_html <- function(messages) {
  # Generate markdown first
  markdown_content <- format_chat_as_markdown(messages)

  # Convert to HTML body
  html_body <- commonmark::markdown_html(markdown_content,
                                          extensions = TRUE,  # GitHub flavored
                                          smart = TRUE)       # Smart quotes, dashes

  # Wrap in full HTML document with embedded CSS
  html_template <- sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Chat Conversation</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      line-height: 1.6;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f5f5f5;
    }
    h1 { color: #333; border-bottom: 2px solid #007bff; padding-bottom: 10px; }
    p { margin: 10px 0; }
    strong { color: #007bff; }
    pre { background-color: #f8f8f8; padding: 10px; border-radius: 5px; overflow-x: auto; }
    code { background-color: #f0f0f0; padding: 2px 4px; border-radius: 3px; font-family: "Courier New", monospace; }
  </style>
</head>
<body>
%s
</body>
</html>', html_body)

  html_template
}
```

### Pattern 3: Shiny downloadHandler with Format-Specific Filename
**What:** Reuse Phase 14's downloadHandler pattern with separate handlers for .md and .html.
**When to use:** All file exports in Shiny.

**Example (adapting from mod_search_notebook.R lines 400-432):**
```r
# In UI (add to card_header actions):
div(
  class = "btn-group btn-group-sm",
  tags$button(
    class = "btn btn-outline-secondary dropdown-toggle",
    `data-bs-toggle` = "dropdown",
    icon("download"), " Export Chat"
  ),
  tags$ul(
    class = "dropdown-menu",
    tags$li(downloadLink(ns("download_chat_md"), class = "dropdown-item",
                         icon("file-text"), " Markdown (.md)")),
    tags$li(downloadLink(ns("download_chat_html"), class = "dropdown-item",
                         icon("file-code"), " HTML (.html)"))
  )
)

# In Server:
output$download_chat_md <- downloadHandler(
  filename = function() {
    paste0("chat-", Sys.Date(), ".md")
  },
  content = function(file) {
    msgs <- messages()  # Reactive list of messages
    markdown_content <- format_chat_as_markdown(msgs)
    writeLines(markdown_content, file, useBytes = TRUE)
  }
)

output$download_chat_html <- downloadHandler(
  filename = function() {
    paste0("chat-", Sys.Date(), ".html")
  },
  content = function(file) {
    msgs <- messages()
    html_content <- format_chat_as_html(msgs)
    writeLines(html_content, file, useBytes = TRUE)
  }
)
```

### Anti-Patterns to Avoid
- **Don't use rmarkdown::render() for simple chat export:** Overkill, requires pandoc, designed for full document rendering not text-to-HTML.
- **Don't embed images or external resources:** Chat exports should be standalone files, no CDN dependencies.
- **Don't forget UTF-8 encoding:** Chat messages may contain Unicode characters (emoji, accents). Always use useBytes = TRUE with writeLines.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown to HTML | Custom regex parser | commonmark::markdown_html() | GitHub-flavored markdown support, handles code blocks, lists, edge cases correctly |
| HTML escaping | Manual gsub patterns | commonmark handles it | Markdown-to-HTML conversion includes proper escaping of <, >, &, etc. |

**Key insight:** Markdown generation is simple enough to hand-roll (just string concatenation with proper structure). Markdown-to-HTML conversion is NOT - use proven library to handle edge cases (nested lists, code blocks, special characters).

## Common Pitfalls

### Pitfall 1: Missing Timestamps in Chat Messages
**What goes wrong:** Exported chat shows messages without timestamps, user can't tell when conversation happened.
**Why it happens:** Current codebase stores messages as `list(role = "user", content = "text")` without timestamp field.
**How to avoid:** Add optional timestamp field to message structure, or generate timestamp at export time based on message order:
```r
# Option 1: Add timestamp to messages() reactive when creating messages
msgs <- messages()
msgs <- c(msgs, list(list(role = "user", content = user_msg, timestamp = Sys.time())))

# Option 2: Generate relative timestamps at export (Message 1, Message 2, etc.)
for (i in seq_along(messages)) {
  header <- sprintf("**%s** (Message %d)", role_label, i)
}
```
**Warning signs:** Exported files have no temporal context, can't tell message order.

### Pitfall 2: Code Blocks Not Rendering in HTML
**What goes wrong:** Assistant's code examples in chat appear as plain text without syntax highlighting or monospace font.
**Why it happens:** Not using GitHub-flavored markdown extensions in commonmark.
**How to avoid:** Enable extensions parameter in markdown_html():
```r
commonmark::markdown_html(markdown_content, extensions = TRUE)
```
**Warning signs:** Code blocks look like regular paragraphs in HTML export.

### Pitfall 3: UTF-8 Encoding Issues with Emoji
**What goes wrong:** Chat messages with emoji render as � or garbled characters in downloaded files.
**Why it happens:** Windows default encoding is not UTF-8. writeLines without useBytes uses native encoding.
**How to avoid:** Always use useBytes = TRUE with writeLines for both Markdown and HTML:
```r
writeLines(content, file, useBytes = TRUE)
```
For HTML, also specify UTF-8 in meta tag (already in Pattern 2 example):
```html
<meta charset="UTF-8">
```
**Warning signs:** Emoji or Unicode characters appear corrupted when opening downloaded files.

### Pitfall 4: No Visual Distinction Between User and Assistant
**What goes wrong:** HTML export shows all messages in same style, hard to follow conversation flow.
**Why it happens:** CSS doesn't differentiate message roles.
**How to avoid:** Use semantic HTML classes based on role and style differently:
```r
# Enhanced HTML generation with role classes
html_body <- ""
for (msg in messages) {
  role_class <- if (msg$role == "user") "user-message" else "assistant-message"
  html_body <- paste0(html_body, sprintf(
    '<div class="%s"><strong>%s:</strong> %s</div>\n',
    role_class,
    if (msg$role == "user") "User" else "Assistant",
    msg$content
  ))
}

# CSS for distinction
.user-message {
  background-color: #e3f2fd;
  padding: 10px;
  margin: 10px 0;
  border-left: 4px solid #007bff;
}
.assistant-message {
  background-color: #f5f5f5;
  padding: 10px;
  margin: 10px 0;
  border-left: 4px solid #28a745;
}
```
**Alternative approach:** Use markdown syntax to create visual distinction without custom HTML:
```r
# User messages as blockquotes, assistant as regular text
if (msg$role == "user") {
  lines <- c(lines, sprintf("> %s", msg$content), "")
} else {
  lines <- c(lines, msg$content, "")
}
```
**Warning signs:** Users complain HTML export is "hard to read" or "confusing".

### Pitfall 5: Large Chat Exports Crash Browser
**What goes wrong:** Very long conversations (100+ messages) create huge HTML files that browsers struggle to render.
**Why it happens:** Embedding full conversation in single file with no pagination.
**How to avoid:** For Phase 15 scope, accept this limitation (success criteria don't mention pagination). Document as known issue. Future enhancement could add message limit or pagination.
**Recommendation:** Add user-facing note: "Exports are optimized for conversations under 100 messages."
**Warning signs:** Browser hangs or crashes when opening exported HTML.

## Code Examples

Verified patterns from official sources:

### commonmark Markdown to HTML Conversion
```r
# Source: https://docs.ropensci.org/commonmark/
library(commonmark)

# Basic conversion
html <- markdown_html("## Hello\n\nThis is **markdown**.")
# Output: "<h2>Hello</h2>\n<p>This is <strong>markdown</strong>.</p>\n"

# With GitHub-flavored markdown extensions (tables, strikethrough, autolinks)
html <- markdown_html(md, extensions = TRUE)

# With smart typography (quotes, dashes)
html <- markdown_html(md, smart = TRUE)

# Full featured
html <- markdown_html(md, extensions = TRUE, smart = TRUE, normalize = TRUE)
```

### Shiny downloadHandler for Text Files
```r
# Source: https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html
# Adapted from Phase 14 patterns in mod_search_notebook.R

output$download_report <- downloadHandler(
  filename = function() {
    paste0("report-", Sys.Date(), ".md")
  },
  content = function(file) {
    # Generate content
    content <- generate_markdown_report()

    # Write with UTF-8 encoding
    writeLines(content, file, useBytes = TRUE)
  }
)
```

### Chat Message Markdown Formatting
```r
# Based on best practices from:
# - https://blog.jakelee.co.uk/markdown-conversation-formatting/
# - https://github.com/daugaard47/ChatGPT_Conversations_To_Markdown

format_chat_message <- function(role, content, timestamp = NULL) {
  # Role header in bold
  role_label <- if (role == "user") "**User**" else "**Assistant**"

  # Add timestamp if available
  header <- if (!is.null(timestamp)) {
    ts_str <- format(timestamp, "%Y-%m-%d %H:%M:%S")
    sprintf("%s — %s", role_label, ts_str)
  } else {
    role_label
  }

  # Format: Header, blank line, content, blank line
  paste(header, "", content, "", sep = "\n")
}

# Example output:
# **User** — 2026-02-12 14:30:45
#
# How do I export citations?
#
# **Assistant** — 2026-02-12 14:30:52
#
# You can export citations as BibTeX or CSV...
```

### Standalone HTML with Embedded CSS
```r
# Based on CSS chat box patterns:
# - https://www.w3schools.com/howto/howto_css_chat.asp
# - https://wpdean.com/css-chat-box/

generate_standalone_html <- function(title, body_html) {
  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>%s</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      line-height: 1.6;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f8f9fa;
    }
    h1, h2, h3 { color: #333; }
    strong { color: #007bff; }
    pre {
      background-color: #f5f5f5;
      padding: 12px;
      border-radius: 4px;
      overflow-x: auto;
      border-left: 3px solid #007bff;
    }
    code {
      background-color: #f0f0f0;
      padding: 2px 6px;
      border-radius: 3px;
      font-family: "Courier New", Consolas, Monaco, monospace;
      font-size: 0.9em;
    }
    blockquote {
      border-left: 4px solid #ddd;
      padding-left: 16px;
      margin-left: 0;
      color: #666;
    }
  </style>
</head>
<body>
%s
</body>
</html>', title, body_html)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| rmarkdown::render() | commonmark::markdown_html() | ~2020 | Lighter dependency, no pandoc needed, faster for simple conversions |
| Manual HTML escaping | Markdown libraries handle it | Always | Safer, handles edge cases (nested quotes, special chars) |
| External CSS files | Embedded CSS in HTML | ~2015 (HTML email era) | Standalone files work in any browser without network |
| Plain text export | Markdown export | ~2018 (GitHub adoption) | Human-readable plain text that's also machine-parseable |

**Deprecated/outdated:**
- Using rmarkdown for simple text-to-HTML (designed for full documents with YAML)
- External CSS/JS dependencies (breaks standalone requirement)
- Not using useBytes = TRUE for UTF-8 files on Windows

## Open Questions

1. **Should we add timestamps to existing chat messages retroactively?**
   - What we know: Current messages() reactive doesn't store timestamps
   - What's unclear: Should we modify message structure now or just add for new messages?
   - Recommendation: Add timestamps at export time as "Message 1", "Message 2" for Phase 15. Phase 16+ can add real timestamps to message structure if needed.

2. **Should HTML export include notebook metadata (name, search query)?**
   - What we know: Success criteria only mention "full conversation with timestamps"
   - What's unclear: Whether metadata adds value or clutter
   - Recommendation: Keep simple for Phase 15. Add just conversation messages. Metadata can be Phase 16+ enhancement.

3. **Should we export only chat or include paper list context?**
   - What we know: Plan 15-01 says "chat interface", success criteria say "conversation"
   - What's unclear: In search notebook, chat refers to abstracts - should we list papers discussed?
   - Recommendation: Export only conversation messages for Phase 15. Context export (papers, filters) is separate feature.

## Sources

### Primary (HIGH confidence)
- [commonmark package (rOpenSci)](https://docs.ropensci.org/commonmark/) - Markdown to HTML conversion API
- [commonmark CRAN](https://cran.r-project.org/web/packages/commonmark/commonmark.pdf) - Package documentation
- [Shiny downloadHandler](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html) - File download API
- [Mastering Shiny: Uploads and downloads](https://mastering-shiny.org/action-transfer.html) - Best practices chapter

### Secondary (MEDIUM confidence)
- [W3Schools: How To Create Chat Messages](https://www.w3schools.com/howto/howto_css_chat.asp) - CSS styling patterns
- [Markdown conversation formatting](https://blog.jakelee.co.uk/markdown-conversation-formatting/) - Best practices for chat in markdown
- [ChatGPT to Markdown exporter](https://github.com/daugaard47/ChatGPT_Conversations_To_Markdown) - Reference implementation
- [Shiny markdown() function](https://shiny.posit.co/r/reference/shiny/1.7.3/markdown.html) - Inline markdown rendering (different from export)

### Tertiary (LOW confidence)
- None - all core claims verified with official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - commonmark is well-documented rOpenSci package, downloadHandler proven in Phase 14
- Architecture: HIGH - Markdown formatting is straightforward string concatenation, patterns verified
- Pitfalls: MEDIUM - UTF-8 encoding and CSS styling have known edge cases, but solutions verified

**Research date:** 2026-02-12
**Valid until:** 2026-03-12 (30 days - stable technology domain)
