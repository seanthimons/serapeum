# Catppuccin Color Palettes for Serapeum
# Phase 30: Core Dark Mode Palette
#
# Provides MOCHA (dark) and LATTE (light) color constants from the
# official Catppuccin palette (https://catppuccin.com/palette/),
# plus catppuccin_dark_css() which generates all [data-bs-theme="dark"]
# CSS overrides in a single centralized string.

# Helper: convert hex color to "R,G,B" string for Bootstrap RGB variables
hex_to_rgb <- function(hex) {
  hex <- sub("^#", "", hex)
  r <- strtoi(substr(hex, 1, 2), 16L)
  g <- strtoi(substr(hex, 3, 4), 16L)
  b <- strtoi(substr(hex, 5, 6), 16L)
  paste(r, g, b, sep = ",")
}

# Catppuccin Mocha (dark theme)
MOCHA <- list(
  # Backgrounds
  base     = "#1e1e2e",
  mantle   = "#181825",
  crust    = "#11111b",
  # Text
  text     = "#cdd6f4",
  subtext1 = "#bac2de",
  subtext0 = "#a6adc8",
  # Surfaces
  surface0 = "#313244",
  surface1 = "#45475a",
  surface2 = "#585b70",
  # Overlays
  overlay0 = "#6c7086",
  overlay1 = "#7f849c",
  overlay2 = "#9399b2",
  # Accents
  lavender = "#b4befe",
  sapphire = "#74c7ec",
  sky      = "#89dceb",
  # Semantic
  blue     = "#89b4fa",
  green    = "#a6e3a1",
  yellow   = "#f9e2af",
  red      = "#f38ba8",
  peach    = "#fab387"
)

# Catppuccin Latte (light theme)
LATTE <- list(
  # Backgrounds
  base     = "#eff1f5",
  mantle   = "#e6e9ef",
  crust    = "#dce0e8",
  # Text
  text     = "#4c4f69",
  subtext1 = "#5c5f77",
  subtext0 = "#6c6f85",
  # Surfaces
  surface0 = "#ccd0da",
  surface1 = "#bcc0cc",
  surface2 = "#acb0be",
  # Overlays
  overlay0 = "#9ca0b0",
  overlay1 = "#8c8fa1",
  overlay2 = "#7c7f93",
  # Accents
  lavender = "#7287fd",
  sapphire = "#209fb5",
  sky      = "#04a5e5",
  # Semantic
  blue     = "#1e66f5",
  green    = "#40a02b",
  yellow   = "#df8e1d",
  red      = "#d20f39",
  peach    = "#fe640b"
)

# =============================================================================
# Semantic Color Policy (DSGN-01)
# =============================================================================
#
# Maps Catppuccin palette colors to Bootstrap semantic roles.
# This is the single source of truth for all button/badge/alert coloring.
# Phase 47 will apply these mappings across the UI.
#
# PRIMARY (lavender) — Main actions: Search, Save, Add to Notebook
#   Mocha: #b4befe | Latte: #7287fd
#   Button: .btn-primary (solid fill, white text)
#   Sidebar: Active items inherit primary lavender
#
# DANGER (red) — Destructive: Delete, Remove, Clear
#   Mocha: #f38ba8 | Latte: #d20f39
#   Button: .btn-danger (solid fill). No confirmation dialog — color IS the warning.
#   Reserve confirmation for irreversible bulk actions only.
#
# SUCCESS (green) — Confirmations: Paper Added, Export Complete
#   Mocha: #a6e3a1 | Latte: #40a02b
#   Button: .btn-success. Also used for completion badges and form validation.
#
# WARNING (yellow) — Cautions: API Key Missing, Rate Limit
#   Mocha: #f9e2af | Latte: #df8e1d
#   Button: .btn-warning. Also used for caution alerts.
#
# INFO (sapphire) — Informational: Tooltips, Help Text
#   Mocha: #74c7ec | Latte: #209fb5
#   Button: .btn-info. Distinct from primary lavender.
#
# SECONDARY (surface0/surface1) — Less Important: Cancel, Close
#   Mocha: #313244/#45475a | Latte: #ccd0da/#bcc0cc
#   Button: .btn-outline-secondary (outline style, transparent bg)
#
# PEACH (candidate accent) — Highlights, Badges (PENDING VALIDATION)
#   Mocha: #fab387 | Latte: #fe640b
#   Concern: May look too similar to warning yellow. Evaluate in swatch sheet.
#
# Button Variant Policy:
#   - Primary actions: solid fill (.btn-primary, .btn-danger, etc.)
#   - Secondary actions: outline (.btn-outline-secondary)
#   - Three sizes: btn-sm (inline), default, btn-lg (hero/CTA)
# =============================================================================

# =============================================================================
# Icon Wrapper Functions (DSGN-01)
# =============================================================================
#
# Semantic icon wrappers standardize Font Awesome icon usage across the app.
# Icons are color-neutral — color comes from button/context, not the icon.
# All wrappers pass through ... args to shiny::icon() for additional classes.

#' Save action icon (floppy disk)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_save <- function(...) shiny::icon("floppy-disk", ...)

#' Delete/Remove action icon (trash can)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_delete <- function(...) shiny::icon("trash", ...)

#' Search action icon (magnifying glass)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_search <- function(...) shiny::icon("magnifying-glass", ...)

#' Add/Create action icon (plus)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_add <- function(...) shiny::icon("plus", ...)

#' Download action icon (down arrow)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_download <- function(...) shiny::icon("download", ...)

#' Upload action icon (up arrow)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_upload <- function(...) shiny::icon("upload", ...)

#' Settings/Config action icon (gear)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_settings <- function(...) shiny::icon("gear", ...)

#' Info/Help icon (circle with i)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_info <- function(...) shiny::icon("circle-info", ...)

#' Warning icon (triangle with exclamation)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_warning <- function(...) shiny::icon("triangle-exclamation", ...)

#' Close/Cancel action icon (X)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_close <- function(...) shiny::icon("xmark", ...)

#' Edit action icon (pen and square)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_edit <- function(...) shiny::icon("pen-to-square", ...)

#' Refresh/Reload action icon (rotating arrows)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_refresh <- function(...) shiny::icon("arrows-rotate", ...)

#' Export action icon (file with arrow)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_export <- function(...) shiny::icon("file-export", ...)

#' Copy action icon (duplicate)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_copy <- function(...) shiny::icon("copy", ...)

#' Expand action icon (expand arrows)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_expand <- function(...) shiny::icon("expand", ...)

#' Collapse action icon (compress arrows)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_collapse <- function(...) shiny::icon("compress", ...)

#' Filter action icon (funnel)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_filter <- function(...) shiny::icon("filter", ...)

#' Sort action icon (sort arrows)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_sort <- function(...) shiny::icon("sort", ...)

#' Book/Reading icon (open book)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_book <- function(...) shiny::icon("book", ...)

#' Paper/Document icon (file with lines)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_paper <- function(...) shiny::icon("file-lines", ...)

# =============================================================================
# Decorative/Status Icons
# =============================================================================

#' Coins icon (cost display)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_coins <- function(...) shiny::icon("coins", ...)

#' Dollar sign icon (cost details)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_dollar <- function(...) shiny::icon("dollar-sign", ...)

#' Brain icon (AI/LLM actions)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_brain <- function(...) shiny::icon("brain", ...)

#' Seedling icon (discover from paper)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_seedling <- function(...) shiny::icon("seedling", ...)

#' Compass icon (explore topics)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_compass <- function(...) shiny::icon("compass", ...)

#' Wand magic sparkles icon (query builder)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_wand <- function(...) shiny::icon("wand-magic-sparkles", ...)

#' Diagram project icon (citation network)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_diagram <- function(...) shiny::icon("diagram-project", ...)

#' Magnifying glass chart icon (citation audit)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_audit <- function(...) shiny::icon("magnifying-glass-chart", ...)

#' File import icon (import papers)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_import <- function(...) shiny::icon("file-import", ...)

#' File PDF icon (document notebook)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_pdf <- function(...) shiny::icon("file-pdf", ...)

#' File PowerPoint icon (slides)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_powerpoint <- function(...) shiny::icon("file-powerpoint", ...)

#' Layer group icon (overview preset)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_layer_group <- function(...) shiny::icon("layer-group", ...)

#' Table cells icon (lit review)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_table <- function(...) shiny::icon("table-cells", ...)

#' List check icon (key points)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_key_points <- function(...) shiny::icon("list-check", ...)

#' Shield halved icon (quality filters)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_shield <- function(...) shiny::icon("shield-halved", ...)

#' Check icon (checkmark)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_check <- function(...) shiny::icon("check", ...)

#' Circle check icon (status OK)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_check_circle <- function(...) shiny::icon("circle-check", ...)

#' Circle xmark icon (status error)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_circle_xmark <- function(...) shiny::icon("circle-xmark", ...)

#' Stop icon (cancel/stop)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_stop <- function(...) shiny::icon("stop", ...)

#' Play icon (start/run)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_play <- function(...) shiny::icon("play", ...)

#' Times icon (small close)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_times <- function(...) shiny::icon("times", ...)

#' Book open icon (app branding)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_book_open <- function(...) shiny::icon("book-open", ...)

#' Paper plane icon (send message)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_paper_plane <- function(...) shiny::icon("paper-plane", ...)

#' Spinner icon (loading)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_spinner <- function(...) shiny::icon("spinner", ...)

#' Question icon (help)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_question <- function(...) shiny::icon("circle-question", ...)

#' Link icon (URLs)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_link <- function(...) shiny::icon("link", ...)

#' External link icon (external links)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_external_link <- function(...) shiny::icon("arrow-up-right-from-square", ...)

#' Chevron down icon (dropdowns)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_chevron_down <- function(...) shiny::icon("chevron-down", ...)

#' Bars icon (menu)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_bars <- function(...) shiny::icon("bars", ...)

#' Robot icon (AI preset indicator)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_robot <- function(...) shiny::icon("robot", ...)

#' Quote left icon (research questions)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_quote <- function(...) shiny::icon("quote-left", ...)

#' Clipboard icon (copy to clipboard)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_clipboard <- function(...) shiny::icon("clipboard", ...)

#' File arrow down icon (download file)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_arrow_down <- function(...) shiny::icon("file-arrow-down", ...)

#' Circle info icon (about/info)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_circle_info <- function(...) shiny::icon("info-circle", ...)

#' Microscope icon (research presets)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_microscope <- function(...) shiny::icon("microscope", ...)

#' Lightbulb icon (suggestions)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_lightbulb <- function(...) shiny::icon("lightbulb", ...)

#' GitHub icon (external links)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_github <- function(...) shiny::icon("github", ...)

#' Wrench icon (advanced features)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_wrench <- function(...) shiny::icon("wrench", ...)

#' Arrow left icon (navigation)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_arrow_left <- function(...) shiny::icon("arrow-left", ...)

#' Arrow right icon (navigation)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_arrow_right <- function(...) shiny::icon("arrow-right", ...)

#' File code icon (code/technical)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_code <- function(...) shiny::icon("file-code", ...)

#' File CSV icon (data export)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_csv <- function(...) shiny::icon("file-csv", ...)

#' List icon (list view)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_list <- function(...) shiny::icon("list", ...)

#' List ordered icon (numbered list)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_list_ol <- function(...) shiny::icon("list-ol", ...)

#' Check double icon (verified/confirmed)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_check_double <- function(...) shiny::icon("check-double", ...)

#' Ban icon (blocked/disabled)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_ban <- function(...) shiny::icon("ban", ...)

#' Rotate icon (refresh/reload)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_rotate <- function(...) shiny::icon("rotate", ...)

#' Angles down icon (double chevron down — load more)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_angles_down <- function(...) shiny::icon("angles-down", ...)

#' Rotate right icon (refresh/reload)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_rotate_right <- function(...) shiny::icon("rotate-right", ...)

#' Trash can icon (delete)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_trash_can <- function(...) shiny::icon("trash-can", ...)

#' Broom icon (clear/clean)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_broom <- function(...) shiny::icon("broom", ...)

#' Fingerprint icon (uniqueness)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_fingerprint <- function(...) shiny::icon("fingerprint", ...)

#' Star icon (favorites)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_star <- function(...) shiny::icon("star", ...)

#' Diamond icon (quality)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_diamond <- function(...) shiny::icon("diamond", ...)

#' Circle icon (general marker)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_circle <- function(...) shiny::icon("circle", ...)

#' File text icon (text document)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_text <- function(...) shiny::icon("file-text", ...)

#' File alt icon (alternative file)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_alt <- function(...) shiny::icon("file-alt", ...)

#' File circle question icon (unknown file)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_file_question <- function(...) shiny::icon("file-circle-question", ...)

#' External link alt icon (external link alternative)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_external_link_alt <- function(...) shiny::icon("external-link-alt", ...)

#' Mouse pointer icon (selection)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_mouse_pointer <- function(...) shiny::icon("mouse-pointer", ...)

#' Circle pause icon (pause)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_circle_pause <- function(...) shiny::icon("circle-pause", ...)

#' Comments icon (discussion)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_comments <- function(...) shiny::icon("comments", ...)

#' Chart bar icon (statistics)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_chart_bar <- function(...) shiny::icon("chart-bar", ...)

#' Database icon (data storage)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_database <- function(...) shiny::icon("database", ...)

#' Share nodes icon (network sharing)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_share_nodes <- function(...) shiny::icon("share-nodes", ...)

#' Box icon (container)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_box <- function(...) shiny::icon("box", ...)

#' Key icon (access/security)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_key <- function(...) shiny::icon("key", ...)

#' Sliders icon (settings/adjustments)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_sliders <- function(...) shiny::icon("sliders", ...)

#' Wallet icon (billing/payment)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_wallet <- function(...) shiny::icon("wallet", ...)

#' Clock icon (latency/timing)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_clock <- function(...) shiny::icon("clock", ...)

#' Save icon (alternative name)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_floppy_disk <- function(...) shiny::icon("floppy-disk", ...)

#' Arrow down icon (download direction)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_arrow_down <- function(...) shiny::icon("arrow-down", ...)

#' Arrow up icon (upload direction)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_arrow_up <- function(...) shiny::icon("arrow-up", ...)

#' Scale balanced icon (comparison)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_scale_balanced <- function(...) shiny::icon("scale-balanced", ...)

#' Minus icon (remove/subtract)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_minus <- function(...) shiny::icon("minus", ...)

#' Window maximize icon (expand window)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_window_maximize <- function(...) shiny::icon("window-maximize", ...)

#' Arrow right to bracket icon (enter/login)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_arrow_right_bracket <- function(...) shiny::icon("arrow-right-to-bracket", ...)

#' Flask icon (methodology/laboratory)
#' @param ... Additional arguments passed to shiny::icon()
#' @return Icon tag
icon_flask <- function(...) shiny::icon("flask", ...)

# Generate all dark mode CSS overrides as a single string
# Injected via bslib::bs_add_rules() for centralized dark mode (DARK-05)
catppuccin_dark_css <- function() {
  paste0('
/* Catppuccin Mocha Dark Mode Overrides (Phase 30) */
[data-bs-theme="dark"] {
  /* Body colors */
  --bs-body-bg: ', MOCHA$base, ';
  --bs-body-color: ', MOCHA$text, ';

  /* Secondary/tertiary backgrounds */
  --bs-secondary-bg: ', MOCHA$surface0, ';
  --bs-tertiary-bg: ', MOCHA$surface1, ';

  /* Primary */
  --bs-primary: ', MOCHA$lavender, ';
  --bs-primary-rgb: ', hex_to_rgb(MOCHA$lavender), ';

  /* Links */
  --bs-link-color: ', MOCHA$sapphire, ';
  --bs-link-color-rgb: ', hex_to_rgb(MOCHA$sapphire), ';
  --bs-link-hover-color: ', MOCHA$sky, ';
  --bs-link-hover-color-rgb: ', hex_to_rgb(MOCHA$sky), ';

  /* Semantic colors */
  --bs-success: ', MOCHA$green, ';
  --bs-success-rgb: ', hex_to_rgb(MOCHA$green), ';
  --bs-danger: ', MOCHA$red, ';
  --bs-danger-rgb: ', hex_to_rgb(MOCHA$red), ';
  --bs-warning: ', MOCHA$yellow, ';
  --bs-warning-rgb: ', hex_to_rgb(MOCHA$yellow), ';
  --bs-info: ', MOCHA$sapphire, ';
  --bs-info-rgb: ', hex_to_rgb(MOCHA$sapphire), ';

  /* Borders */
  --bs-border-color: ', MOCHA$surface2, ';

  /* Cards */
  --bs-card-bg: ', MOCHA$surface0, ';
  --bs-card-border-color: ', MOCHA$surface1, ';
}

/* Dark mode input fields */
[data-bs-theme="dark"] .form-control,
[data-bs-theme="dark"] .form-select {
  background-color: ', MOCHA$surface1, ';
  border-color: ', MOCHA$surface2, ';
  color: ', MOCHA$text, ';
}

/* Dark mode chat-markdown tables */
[data-bs-theme="dark"] .chat-markdown th {
  background: ', MOCHA$surface0, ';
}

[data-bs-theme="dark"] .chat-markdown th,
[data-bs-theme="dark"] .chat-markdown td {
  border-color: ', MOCHA$surface2, ';
}

/* Dark mode chat-markdown code blocks */
[data-bs-theme="dark"] .chat-markdown pre {
  background: ', MOCHA$surface0, ';
}

/* Dark mode lit-review tables */
[data-bs-theme="dark"] .lit-review-scroll {
  border-color: ', MOCHA$surface2, ';
}

[data-bs-theme="dark"] .lit-review-scroll th:first-child,
[data-bs-theme="dark"] .lit-review-scroll td:first-child {
  background-color: ', MOCHA$surface0, ';
  border-right-color: ', MOCHA$overlay0, ';
}

[data-bs-theme="dark"] .lit-review-scroll th:first-child {
  background-color: ', MOCHA$surface1, ';
}

/* Safety net: catch any remaining bg-light/text-dark in dark mode (Phase 31) */
[data-bs-theme="dark"] .bg-light {
  background-color: var(--bs-secondary-bg) !important;
  color: var(--bs-body-color) !important;
}

[data-bs-theme="dark"] .text-dark {
  color: var(--bs-body-color) !important;
}

/* Override .bg-white in dark mode (document notebook chat uses this) */
[data-bs-theme="dark"] .bg-white {
  background-color: var(--bs-secondary-bg) !important;
  color: var(--bs-body-color) !important;
}

/* Dark mode alert overrides for better readability */
[data-bs-theme="dark"] .alert-warning {
  background-color: rgba(249, 226, 175, 0.22);
  border-color: rgba(249, 226, 175, 0.5);
  color: var(--bs-body-color);
}

/* Phase 31-03: Value box text overrides for dark mode (UAT tests 10+11) */
/* Sass compiles .bg-primary/.bg-success text to black at build time. */
/* Dark mode updates backgrounds to bright Catppuccin pastels via CSS vars, */
/* but text stays black. Override to Mocha Crust for readable dark text on pastel bg. */
[data-bs-theme="dark"] .bg-primary,
[data-bs-theme="dark"] .bg-success,
[data-bs-theme="dark"] .bg-danger,
[data-bs-theme="dark"] .bg-warning,
[data-bs-theme="dark"] .bg-info {
  color: ', MOCHA$crust, ' !important;
}

/* Target value_box specifically for bslib-specific selectors */
[data-bs-theme="dark"] .value-box.bg-primary .value-box-title,
[data-bs-theme="dark"] .value-box.bg-primary .value-box-value,
[data-bs-theme="dark"] .value-box.bg-success .value-box-title,
[data-bs-theme="dark"] .value-box.bg-success .value-box-value,
[data-bs-theme="dark"] .value-box.bg-warning .value-box-title,
[data-bs-theme="dark"] .value-box.bg-warning .value-box-value,
[data-bs-theme="dark"] .value-box.bg-danger .value-box-title,
[data-bs-theme="dark"] .value-box.bg-danger .value-box-value,
[data-bs-theme="dark"] .value-box.bg-info .value-box-title,
[data-bs-theme="dark"] .value-box.bg-info .value-box-value {
  color: ', MOCHA$crust, ' !important;
}

/* Phase 31-03: Progress/notification base class styling (UAT test 9) */
/* Existing rules only style typed notifications (message/warning/error). */
/* Add base .shiny-notification and .shiny-progress-notification for visibility. */
[data-bs-theme="dark"] .shiny-notification {
  background-color: ', MOCHA$surface0, ' !important;
  color: ', MOCHA$text, ' !important;
  border-color: ', MOCHA$surface1, ' !important;
}

/* Typed notification overrides — chained class for higher specificity than base */
[data-bs-theme="dark"] .shiny-notification.shiny-notification-message {
  background-color: ', MOCHA$green, ' !important;
  color: ', MOCHA$base, ' !important;
}

[data-bs-theme="dark"] .shiny-notification.shiny-notification-warning {
  background-color: ', MOCHA$yellow, ' !important;
  color: ', MOCHA$base, ' !important;
}

[data-bs-theme="dark"] .shiny-notification.shiny-notification-error {
  background-color: ', MOCHA$red, ' !important;
  color: ', MOCHA$base, ' !important;
}

[data-bs-theme="dark"] .shiny-progress-notification .progress {
  background-color: ', MOCHA$surface1, ';
}

[data-bs-theme="dark"] .shiny-progress-notification .progress-bar {
  background-color: ', MOCHA$lavender, ';
}

[data-bs-theme="dark"] .shiny-progress-notification .progress-text {
  color: ', MOCHA$text, ';
}
')
}

# =============================================================================
# Swatch Sheet Generator (DSGN-02)
# =============================================================================

#' Generate Design System Swatch Sheet
#'
#' Creates a standalone HTML file showing all design system components
#' (buttons, badges, alerts, forms, sidebar, cards, icons) in both
#' Catppuccin Latte (light) and Mocha (dark) flavors side-by-side.
#'
#' The swatch sheet serves as a visual validation gate before Phase 47
#' applies the design system to the actual app UI.
#'
#' @param output_path Path to save the HTML file (default: "www/swatch.html")
#' @return Invisibly returns the path to the generated file
#' @export
generate_swatch_html <- function(output_path = "www/swatch.html") {

  # Build comprehensive CSS with embedded Catppuccin colors
  swatch_css <- paste0('
    /* Reset and base styles */
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }

    /* Grid layout: side-by-side */
    .swatch-container { display: flex; min-height: 100vh; }
    .theme-column { flex: 1; padding: 2rem; }

    /* Latte (light) theme */
    .theme-latte {
      background: ', LATTE$base, ';
      color: ', LATTE$text, ';
      --primary: ', LATTE$lavender, ';
      --danger: ', LATTE$red, ';
      --success: ', LATTE$green, ';
      --warning: ', LATTE$yellow, ';
      --info: ', LATTE$sapphire, ';
      --secondary: ', LATTE$surface1, ';
      --surface0: ', LATTE$surface0, ';
      --surface1: ', LATTE$surface1, ';
      --surface2: ', LATTE$surface2, ';
      --text: ', LATTE$text, ';
      --subtext0: ', LATTE$subtext0, ';
      --peach: ', LATTE$peach, ';
      --border: ', LATTE$surface2, ';
    }

    /* Mocha (dark) theme */
    .theme-mocha {
      background: ', MOCHA$base, ';
      color: ', MOCHA$text, ';
      --primary: ', MOCHA$lavender, ';
      --danger: ', MOCHA$red, ';
      --success: ', MOCHA$green, ';
      --warning: ', MOCHA$yellow, ';
      --info: ', MOCHA$sapphire, ';
      --secondary: ', MOCHA$surface1, ';
      --surface0: ', MOCHA$surface0, ';
      --surface1: ', MOCHA$surface1, ';
      --surface2: ', MOCHA$surface2, ';
      --text: ', MOCHA$text, ';
      --subtext0: ', MOCHA$subtext0, ';
      --peach: ', MOCHA$peach, ';
      --border: ', MOCHA$surface2, ';
    }

    /* Typography */
    h1 { font-size: 2rem; margin-bottom: 1.5rem; border-bottom: 2px solid var(--border); padding-bottom: 0.5rem; }
    h2 { font-size: 1.5rem; margin-top: 2rem; margin-bottom: 1rem; color: var(--primary); }
    h3 { font-size: 1.25rem; margin-top: 1.5rem; margin-bottom: 0.75rem; }
    p { margin-bottom: 1rem; line-height: 1.6; }

    /* Section spacing */
    .section { margin-bottom: 2.5rem; }

    /* Color swatches */
    .color-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
    .color-swatch { padding: 1rem; border-radius: 8px; border: 1px solid var(--border); }
    .color-name { font-weight: 600; margin-bottom: 0.25rem; }
    .color-hex { font-family: monospace; font-size: 0.875rem; color: var(--subtext0); }

    /* Buttons */
    .btn {
      display: inline-block;
      padding: 0.5rem 1rem;
      margin: 0.25rem;
      border: 1px solid transparent;
      border-radius: 6px;
      font-size: 1rem;
      font-weight: 500;
      text-align: center;
      cursor: pointer;
      transition: all 0.15s ease-in-out;
    }
    .btn-sm { padding: 0.25rem 0.5rem; font-size: 0.875rem; }
    .btn-lg { padding: 0.75rem 1.5rem; font-size: 1.125rem; }

    .btn-primary { background: var(--primary); color: white; border-color: var(--primary); }
    .btn-primary:hover { opacity: 0.85; }
    .btn-danger { background: var(--danger); color: white; border-color: var(--danger); }
    .btn-danger:hover { opacity: 0.85; }
    .btn-success { background: var(--success); color: white; border-color: var(--success); }
    .btn-success:hover { opacity: 0.85; }
    .btn-warning { background: var(--warning); color: var(--text); border-color: var(--warning); }
    .btn-warning:hover { opacity: 0.85; }
    .btn-info { background: var(--info); color: white; border-color: var(--info); }
    .btn-info:hover { opacity: 0.85; }
    .btn-secondary { background: var(--secondary); color: var(--text); border-color: var(--secondary); }
    .btn-secondary:hover { opacity: 0.85; }

    .btn-outline-primary { background: transparent; color: var(--primary); border-color: var(--primary); }
    .btn-outline-primary:hover { background: var(--primary); color: white; }
    .btn-outline-secondary { background: transparent; color: var(--text); border-color: var(--border); }
    .btn-outline-secondary:hover { background: var(--surface0); }
    .btn-outline-danger { background: transparent; color: var(--danger); border-color: var(--danger); }
    .btn-outline-danger:hover { background: var(--danger); color: white; }

    .btn:disabled { opacity: 0.65; cursor: not-allowed; }

    /* Badges */
    .badge {
      display: inline-block;
      padding: 0.35rem 0.65rem;
      margin: 0.25rem;
      border-radius: 4px;
      font-size: 0.875rem;
      font-weight: 600;
      color: white;
    }
    .badge.bg-primary { background: var(--primary); }
    .badge.bg-danger { background: var(--danger); }
    .badge.bg-success { background: var(--success); }
    .badge.bg-warning { background: var(--warning); color: var(--text); }
    .badge.bg-info { background: var(--info); }
    .badge.bg-peach { background: var(--peach); color: var(--text); }

    /* Alerts */
    .alert {
      padding: 1rem;
      margin-bottom: 1rem;
      border-radius: 6px;
      border: 1px solid transparent;
    }
    .alert-primary { background: color-mix(in srgb, var(--primary) 15%, transparent); border-color: var(--primary); color: var(--text); }
    .alert-danger { background: color-mix(in srgb, var(--danger) 15%, transparent); border-color: var(--danger); color: var(--text); }
    .alert-success { background: color-mix(in srgb, var(--success) 15%, transparent); border-color: var(--success); color: var(--text); }
    .alert-warning { background: color-mix(in srgb, var(--warning) 15%, transparent); border-color: var(--warning); color: var(--text); }
    .alert-info { background: color-mix(in srgb, var(--info) 15%, transparent); border-color: var(--info); color: var(--text); }

    /* Cards */
    .card {
      background: var(--surface0);
      border: 1px solid var(--border);
      border-radius: 8px;
      margin-bottom: 1rem;
      overflow: hidden;
    }
    .card-header {
      padding: 0.75rem 1rem;
      background: var(--surface1);
      border-bottom: 1px solid var(--border);
      font-weight: 600;
    }
    .card-body { padding: 1rem; }
    .card-footer {
      padding: 0.75rem 1rem;
      background: var(--surface1);
      border-top: 1px solid var(--border);
      font-size: 0.875rem;
      color: var(--subtext0);
    }

    /* Form inputs */
    .form-control {
      display: block;
      width: 100%;
      padding: 0.5rem 0.75rem;
      margin-bottom: 1rem;
      background: var(--surface0);
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--text);
      font-size: 1rem;
    }
    .form-control:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px color-mix(in srgb, var(--primary) 25%, transparent);
    }
    .form-control:disabled {
      opacity: 0.6;
      cursor: not-allowed;
      background: var(--surface1);
    }

    /* Sidebar simulation */
    .sidebar-demo {
      background: var(--surface0);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 0.5rem;
    }
    .sidebar-item {
      padding: 0.75rem 1rem;
      border-radius: 6px;
      margin-bottom: 0.25rem;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .sidebar-item:hover { background: var(--surface1); }
    .sidebar-item.active {
      background: var(--primary);
      color: white;
      font-weight: 600;
    }

    /* Comparison boxes */
    .comparison-box {
      display: flex;
      gap: 1rem;
      margin-bottom: 1rem;
    }
    .comparison-item {
      flex: 1;
      padding: 1rem;
      border: 2px solid var(--border);
      border-radius: 8px;
      text-align: center;
    }

    /* Icon grid */
    .icon-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 1rem; }
    .icon-item { text-align: center; padding: 1rem; }
    .icon-item i { font-size: 2rem; margin-bottom: 0.5rem; color: var(--primary); }
    .icon-label { font-size: 0.875rem; color: var(--subtext0); font-family: monospace; }
  ')

  # Create HTML structure using htmltools
  swatch_ui <- htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$meta(charset = "UTF-8"),
      htmltools::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1.0"),
      htmltools::tags$title("Serapeum Design System Swatch Sheet"),
      htmltools::tags$link(
        rel = "stylesheet",
        href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css"
      ),
      htmltools::tags$style(htmltools::HTML(swatch_css))
    ),
    htmltools::tags$body(
      htmltools::tags$div(
        class = "swatch-container",

        # LEFT COLUMN: Latte (Light)
        htmltools::tags$div(
          class = "theme-column theme-latte",
          htmltools::tags$h1("Catppuccin Latte (Light)"),
          htmltools::tags$p(
            "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
            htmltools::tags$br(),
            "Phase 45 Design System Foundation"
          ),

          # 1. Raw Palette
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("1. Raw Palette"),
            htmltools::tags$div(
              class = "color-grid",
              lapply(names(LATTE), function(name) {
                htmltools::tags$div(
                  class = "color-swatch",
                  style = paste0("background: ", LATTE[[name]], ";"),
                  htmltools::tags$div(class = "color-name", name),
                  htmltools::tags$div(class = "color-hex", LATTE[[name]])
                )
              })
            )
          ),

          # 2. Semantic Color Mapping
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("2. Semantic Color Mapping"),
            htmltools::tags$p(htmltools::tags$strong("PRIMARY (lavender)"), " — Main actions: Search, Save, Add to Notebook"),
            htmltools::tags$p(htmltools::tags$strong("DANGER (red)"), " — Destructive: Delete, Remove, Clear"),
            htmltools::tags$p(htmltools::tags$strong("SUCCESS (green)"), " — Confirmations: Paper Added, Export Complete"),
            htmltools::tags$p(htmltools::tags$strong("WARNING (yellow)"), " — Cautions: API Key Missing, Rate Limit"),
            htmltools::tags$p(htmltools::tags$strong("INFO (sapphire)"), " — Informational: Tooltips, Help Text"),
            htmltools::tags$p(htmltools::tags$strong("SECONDARY (surface0/surface1)"), " — Less Important: Cancel, Close")
          ),

          # 3. Buttons
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("3. Buttons"),
            htmltools::tags$h3("Solid Variants"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-primary", "Primary"),
              htmltools::tags$button(class = "btn btn-danger", "Danger"),
              htmltools::tags$button(class = "btn btn-success", "Success"),
              htmltools::tags$button(class = "btn btn-warning", "Warning"),
              htmltools::tags$button(class = "btn btn-info", "Info"),
              htmltools::tags$button(class = "btn btn-secondary", "Secondary")
            ),
            htmltools::tags$h3("Outline Variants"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-outline-primary", "Outline Primary"),
              htmltools::tags$button(class = "btn btn-outline-secondary", "Outline Secondary"),
              htmltools::tags$button(class = "btn btn-outline-danger", "Outline Danger")
            ),
            htmltools::tags$h3("Sizes"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-sm btn-primary", "Small"),
              htmltools::tags$button(class = "btn btn-primary", "Default"),
              htmltools::tags$button(class = "btn btn-lg btn-primary", "Large")
            ),
            htmltools::tags$h3("Disabled State"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-primary", disabled = NA, "Disabled Primary"),
              htmltools::tags$button(class = "btn btn-outline-secondary", disabled = NA, "Disabled Outline")
            )
          ),

          # 4. Peach vs Yellow Comparison
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("4. Peach vs Yellow Comparison"),
            htmltools::tags$p("Evaluate visual ambiguity — are these distinct enough?"),
            htmltools::tags$div(
              class = "comparison-box",
              htmltools::tags$div(
                class = "comparison-item",
                style = paste0("background: ", LATTE$peach, ";"),
                htmltools::tags$h3("Peach"),
                htmltools::tags$p(LATTE$peach),
                htmltools::tags$div(class = "badge bg-peach", "Peach Badge")
              ),
              htmltools::tags$div(
                class = "comparison-item",
                style = paste0("background: ", LATTE$yellow, ";"),
                htmltools::tags$h3("Yellow"),
                htmltools::tags$p(LATTE$yellow),
                htmltools::tags$div(class = "badge bg-warning", "Warning Badge")
              )
            )
          ),

          # 5. Badges
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("5. Badges"),
            htmltools::tags$div(
              htmltools::tags$span(class = "badge bg-primary", "Primary"),
              htmltools::tags$span(class = "badge bg-danger", "Danger"),
              htmltools::tags$span(class = "badge bg-success", "Success"),
              htmltools::tags$span(class = "badge bg-warning", "Warning"),
              htmltools::tags$span(class = "badge bg-info", "Info"),
              htmltools::tags$span(class = "badge bg-peach", "Peach (candidate)")
            )
          ),

          # 6. Sidebar
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("6. Sidebar Simulation"),
            htmltools::tags$div(
              class = "sidebar-demo",
              htmltools::tags$div(class = "sidebar-item active", "Active Item (Primary Lavender)"),
              htmltools::tags$div(class = "sidebar-item", "Inactive Item"),
              htmltools::tags$div(class = "sidebar-item", "Hover to See Effect")
            )
          ),

          # 7. Alerts
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("7. Alerts"),
            htmltools::tags$div(class = "alert alert-primary", htmltools::tags$strong("Primary alert:"), " Informational message"),
            htmltools::tags$div(class = "alert alert-danger", htmltools::tags$strong("Danger alert:"), " Something went wrong"),
            htmltools::tags$div(class = "alert alert-success", htmltools::tags$strong("Success alert:"), " Operation completed"),
            htmltools::tags$div(class = "alert alert-warning", htmltools::tags$strong("Warning alert:"), " Please check this"),
            htmltools::tags$div(class = "alert alert-info", htmltools::tags$strong("Info alert:"), " Helpful information")
          ),

          # 8. Form Inputs
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("8. Form Inputs"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Default state"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Focus state (click to see focus ring)"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Disabled state", disabled = NA)
          ),

          # 9. Cards
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("9. Cards"),
            htmltools::tags$div(
              class = "card",
              htmltools::tags$div(class = "card-header", "Card Header"),
              htmltools::tags$div(class = "card-body", "Card body content with proper border colors and background."),
              htmltools::tags$div(class = "card-footer", "Card Footer")
            )
          ),

          # 10. Icons
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("10. Icon Wrappers"),
            htmltools::tags$div(
              class = "icon-grid",
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-floppy-disk"), htmltools::tags$div(class = "icon-label", "icon_save")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-trash"), htmltools::tags$div(class = "icon-label", "icon_delete")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-magnifying-glass"), htmltools::tags$div(class = "icon-label", "icon_search")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-plus"), htmltools::tags$div(class = "icon-label", "icon_add")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-download"), htmltools::tags$div(class = "icon-label", "icon_download")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-upload"), htmltools::tags$div(class = "icon-label", "icon_upload")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-gear"), htmltools::tags$div(class = "icon-label", "icon_settings")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-circle-info"), htmltools::tags$div(class = "icon-label", "icon_info")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-triangle-exclamation"), htmltools::tags$div(class = "icon-label", "icon_warning")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-xmark"), htmltools::tags$div(class = "icon-label", "icon_close")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-pen-to-square"), htmltools::tags$div(class = "icon-label", "icon_edit")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-arrows-rotate"), htmltools::tags$div(class = "icon-label", "icon_refresh")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-file-export"), htmltools::tags$div(class = "icon-label", "icon_export")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-copy"), htmltools::tags$div(class = "icon-label", "icon_copy")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-expand"), htmltools::tags$div(class = "icon-label", "icon_expand")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-compress"), htmltools::tags$div(class = "icon-label", "icon_collapse")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-filter"), htmltools::tags$div(class = "icon-label", "icon_filter")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-sort"), htmltools::tags$div(class = "icon-label", "icon_sort")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-book"), htmltools::tags$div(class = "icon-label", "icon_book")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-file-lines"), htmltools::tags$div(class = "icon-label", "icon_paper"))
            )
          )
        ),

        # RIGHT COLUMN: Mocha (Dark) - Same structure with Mocha colors
        htmltools::tags$div(
          class = "theme-column theme-mocha",
          htmltools::tags$h1("Catppuccin Mocha (Dark)"),
          htmltools::tags$p(
            "Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
            htmltools::tags$br(),
            "Phase 45 Design System Foundation"
          ),

          # 1. Raw Palette
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("1. Raw Palette"),
            htmltools::tags$div(
              class = "color-grid",
              lapply(names(MOCHA), function(name) {
                htmltools::tags$div(
                  class = "color-swatch",
                  style = paste0("background: ", MOCHA[[name]], ";"),
                  htmltools::tags$div(class = "color-name", name),
                  htmltools::tags$div(class = "color-hex", MOCHA[[name]])
                )
              })
            )
          ),

          # 2. Semantic Color Mapping
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("2. Semantic Color Mapping"),
            htmltools::tags$p(htmltools::tags$strong("PRIMARY (lavender)"), " — Main actions: Search, Save, Add to Notebook"),
            htmltools::tags$p(htmltools::tags$strong("DANGER (red)"), " — Destructive: Delete, Remove, Clear"),
            htmltools::tags$p(htmltools::tags$strong("SUCCESS (green)"), " — Confirmations: Paper Added, Export Complete"),
            htmltools::tags$p(htmltools::tags$strong("WARNING (yellow)"), " — Cautions: API Key Missing, Rate Limit"),
            htmltools::tags$p(htmltools::tags$strong("INFO (sapphire)"), " — Informational: Tooltips, Help Text"),
            htmltools::tags$p(htmltools::tags$strong("SECONDARY (surface0/surface1)"), " — Less Important: Cancel, Close")
          ),

          # 3. Buttons
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("3. Buttons"),
            htmltools::tags$h3("Solid Variants"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-primary", "Primary"),
              htmltools::tags$button(class = "btn btn-danger", "Danger"),
              htmltools::tags$button(class = "btn btn-success", "Success"),
              htmltools::tags$button(class = "btn btn-warning", "Warning"),
              htmltools::tags$button(class = "btn btn-info", "Info"),
              htmltools::tags$button(class = "btn btn-secondary", "Secondary")
            ),
            htmltools::tags$h3("Outline Variants"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-outline-primary", "Outline Primary"),
              htmltools::tags$button(class = "btn btn-outline-secondary", "Outline Secondary"),
              htmltools::tags$button(class = "btn btn-outline-danger", "Outline Danger")
            ),
            htmltools::tags$h3("Sizes"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-sm btn-primary", "Small"),
              htmltools::tags$button(class = "btn btn-primary", "Default"),
              htmltools::tags$button(class = "btn btn-lg btn-primary", "Large")
            ),
            htmltools::tags$h3("Disabled State"),
            htmltools::tags$div(
              htmltools::tags$button(class = "btn btn-primary", disabled = NA, "Disabled Primary"),
              htmltools::tags$button(class = "btn btn-outline-secondary", disabled = NA, "Disabled Outline")
            )
          ),

          # 4. Peach vs Yellow Comparison
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("4. Peach vs Yellow Comparison"),
            htmltools::tags$p("Evaluate visual ambiguity — are these distinct enough?"),
            htmltools::tags$div(
              class = "comparison-box",
              htmltools::tags$div(
                class = "comparison-item",
                style = paste0("background: ", MOCHA$peach, ";"),
                htmltools::tags$h3("Peach"),
                htmltools::tags$p(MOCHA$peach),
                htmltools::tags$div(class = "badge bg-peach", "Peach Badge")
              ),
              htmltools::tags$div(
                class = "comparison-item",
                style = paste0("background: ", MOCHA$yellow, ";"),
                htmltools::tags$h3("Yellow"),
                htmltools::tags$p(MOCHA$yellow),
                htmltools::tags$div(class = "badge bg-warning", "Warning Badge")
              )
            )
          ),

          # 5. Badges
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("5. Badges"),
            htmltools::tags$div(
              htmltools::tags$span(class = "badge bg-primary", "Primary"),
              htmltools::tags$span(class = "badge bg-danger", "Danger"),
              htmltools::tags$span(class = "badge bg-success", "Success"),
              htmltools::tags$span(class = "badge bg-warning", "Warning"),
              htmltools::tags$span(class = "badge bg-info", "Info"),
              htmltools::tags$span(class = "badge bg-peach", "Peach (candidate)")
            )
          ),

          # 6. Sidebar
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("6. Sidebar Simulation"),
            htmltools::tags$div(
              class = "sidebar-demo",
              htmltools::tags$div(class = "sidebar-item active", "Active Item (Primary Lavender)"),
              htmltools::tags$div(class = "sidebar-item", "Inactive Item"),
              htmltools::tags$div(class = "sidebar-item", "Hover to See Effect")
            )
          ),

          # 7. Alerts
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("7. Alerts"),
            htmltools::tags$div(class = "alert alert-primary", htmltools::tags$strong("Primary alert:"), " Informational message"),
            htmltools::tags$div(class = "alert alert-danger", htmltools::tags$strong("Danger alert:"), " Something went wrong"),
            htmltools::tags$div(class = "alert alert-success", htmltools::tags$strong("Success alert:"), " Operation completed"),
            htmltools::tags$div(class = "alert alert-warning", htmltools::tags$strong("Warning alert:"), " Please check this"),
            htmltools::tags$div(class = "alert alert-info", htmltools::tags$strong("Info alert:"), " Helpful information")
          ),

          # 8. Form Inputs
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("8. Form Inputs"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Default state"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Focus state (click to see focus ring)"),
            htmltools::tags$input(class = "form-control", type = "text", placeholder = "Disabled state", disabled = NA)
          ),

          # 9. Cards
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("9. Cards"),
            htmltools::tags$div(
              class = "card",
              htmltools::tags$div(class = "card-header", "Card Header"),
              htmltools::tags$div(class = "card-body", "Card body content with proper border colors and background."),
              htmltools::tags$div(class = "card-footer", "Card Footer")
            )
          ),

          # 10. Icons
          htmltools::tags$div(
            class = "section",
            htmltools::tags$h2("10. Icon Wrappers"),
            htmltools::tags$div(
              class = "icon-grid",
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-floppy-disk"), htmltools::tags$div(class = "icon-label", "icon_save")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-trash"), htmltools::tags$div(class = "icon-label", "icon_delete")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-magnifying-glass"), htmltools::tags$div(class = "icon-label", "icon_search")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-plus"), htmltools::tags$div(class = "icon-label", "icon_add")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-download"), htmltools::tags$div(class = "icon-label", "icon_download")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-upload"), htmltools::tags$div(class = "icon-label", "icon_upload")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-gear"), htmltools::tags$div(class = "icon-label", "icon_settings")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-circle-info"), htmltools::tags$div(class = "icon-label", "icon_info")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-triangle-exclamation"), htmltools::tags$div(class = "icon-label", "icon_warning")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-xmark"), htmltools::tags$div(class = "icon-label", "icon_close")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-pen-to-square"), htmltools::tags$div(class = "icon-label", "icon_edit")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-arrows-rotate"), htmltools::tags$div(class = "icon-label", "icon_refresh")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-file-export"), htmltools::tags$div(class = "icon-label", "icon_export")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-copy"), htmltools::tags$div(class = "icon-label", "icon_copy")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-expand"), htmltools::tags$div(class = "icon-label", "icon_expand")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-compress"), htmltools::tags$div(class = "icon-label", "icon_collapse")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-filter"), htmltools::tags$div(class = "icon-label", "icon_filter")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-sort"), htmltools::tags$div(class = "icon-label", "icon_sort")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-book"), htmltools::tags$div(class = "icon-label", "icon_book")),
              htmltools::tags$div(class = "icon-item", htmltools::tags$i(class = "fa-solid fa-file-lines"), htmltools::tags$div(class = "icon-label", "icon_paper"))
            )
          )
        )
      )
    )
  )

  # Save to file
  htmltools::save_html(swatch_ui, file = output_path)
  message("Swatch sheet generated: ", output_path)
  invisible(output_path)
}
