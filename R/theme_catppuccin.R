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
  --bs-info: ', MOCHA$blue, ';
  --bs-info-rgb: ', hex_to_rgb(MOCHA$blue), ';

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

/* Toast notifications with semantic Catppuccin Mocha colors */
[data-bs-theme="dark"] .shiny-notification-message {
  background-color: ', MOCHA$green, ' !important;
  color: ', MOCHA$base, ' !important;
}

[data-bs-theme="dark"] .shiny-notification-warning {
  background-color: ', MOCHA$yellow, ' !important;
  color: ', MOCHA$base, ' !important;
}

[data-bs-theme="dark"] .shiny-notification-error {
  background-color: ', MOCHA$red, ' !important;
  color: ', MOCHA$base, ' !important;
}

/* Safety net: catch any remaining bg-light/text-dark in dark mode (Phase 31) */
[data-bs-theme="dark"] .bg-light {
  background-color: var(--bs-secondary-bg) !important;
  color: var(--bs-body-color) !important;
}

[data-bs-theme="dark"] .text-dark {
  color: var(--bs-body-color) !important;
}

/* Dark mode alert overrides for better readability */
[data-bs-theme="dark"] .alert-warning {
  background-color: rgba(249, 226, 175, 0.15);
  border-color: rgba(249, 226, 175, 0.3);
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
