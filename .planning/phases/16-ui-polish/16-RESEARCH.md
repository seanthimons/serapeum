# Phase 16: UI Polish - Research

**Researched:** 2026-02-13
**Domain:** R/Shiny UI customization with bslib (icons, favicon, layout optimization)
**Confidence:** HIGH

## Summary

Phase 16 focuses on three isolated UI improvements for the Serapeum R/Shiny application: adding distinct icons to synthesis preset buttons, implementing a favicon, and optimizing sidebar space usage. All three tasks involve standard Shiny patterns with bslib/Bootstrap 5 compatibility.

The R/Shiny ecosystem provides mature solutions for all requirements. Icons can be updated via the `icon()` function using Font Awesome names. Favicons are added through standard HTML `<link>` tags in `tags$head()` with the file placed in the `www/` directory. Sidebar layout optimization involves CSS refinements and removing redundant UI elements.

**Primary recommendation:** Use Font Awesome icons via Shiny's `icon()` function for preset buttons, place favicon files in `www/` directory with HTML link tags, and consolidate sidebar footer elements to reclaim vertical space.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shiny | Latest (1.8+) | Web application framework | Official R web framework from Posit |
| bslib | 0.10.0+ (2026) | Bootstrap 5 theming | Official Bootstrap integration for Shiny |
| Font Awesome | 6.x (via shiny::icon) | Icon library | Default icon system in Shiny, 2000+ free icons |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bsicons | Latest | Bootstrap Icons | Alternative to Font Awesome, better Bootstrap integration |
| fontawesome | Latest | Direct FA access | Advanced FA features (sizes, styles, animations) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Font Awesome (shiny::icon) | bsicons::bs_icon() | bsicons renders as inline SVG (better performance), but Font Awesome has larger icon library and is Shiny default |
| www/ directory | addResourcePath() | Dynamic paths useful for packages, but www/ is simpler for single apps |

**Installation:**
```r
# Core dependencies (already in project)
# install.packages("shiny")
# install.packages("bslib")

# Optional: for Bootstrap Icons alternative
# install.packages("bsicons")
```

## Architecture Patterns

### Standard Shiny Static Assets Structure
```
app.R                    # Main application file
www/
├── favicon.ico         # 16x16, 32x32, 48x48 multi-resolution ICO
├── favicon-32x32.png   # Optional: modern browsers support PNG
├── favicon-16x16.png   # Optional: smaller size variant
└── custom.css          # Application-specific styles
R/
└── mod_*.R             # Shiny modules
```

### Pattern 1: Icon Updates in Shiny
**What:** Use `icon()` function to render Font Awesome icons in action buttons
**When to use:** All buttons, links, nav items requiring visual indicators
**Example:**
```r
# Source: https://shiny.posit.co/r/reference/shiny/0.14/icon.html
# Icon names omit "fa-" prefix
actionButton("btn_summarize", "Summarize",
             icon = icon("file-lines"))  # fa-file-lines
actionButton("btn_keypoints", "Key Points",
             icon = icon("list-check"))  # fa-list-check
```

**Available icon libraries:**
- Font Awesome: `icon("name", lib = "font-awesome")` (default)
- Bootstrap Glyphicons: `icon("name", lib = "glyphicon")`
- Browse icons: https://fontawesome.com/icons

### Pattern 2: Favicon Implementation
**What:** Add favicon.ico to www/ directory and link in UI head
**When to use:** All Shiny apps for browser tab branding
**Example:**
```r
# Source: https://shiny.posit.co/r/articles/build/css/
ui <- page_sidebar(
  tags$head(
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    # Optional: modern browsers support PNG favicons
    tags$link(rel = "icon", type = "image/png", sizes = "32x32", href = "favicon-32x32.png"),
    tags$link(rel = "icon", type = "image/png", sizes = "16x16", href = "favicon-16x16.png")
  ),
  # ... rest of UI
)
```

**File placement rule:** Files in `www/` are served at root path (no "www/" prefix in href).

### Pattern 3: Sidebar Space Optimization with bslib
**What:** Use bslib's `sidebar()` function with strategic layout and CSS
**When to use:** Page-level or card-level sidebars needing vertical space efficiency
**Example:**
```r
# Source: https://rstudio.github.io/bslib/articles/sidebars/
sidebar = sidebar(
  title = "Navigation",
  width = 280,  # Fixed width for predictability

  # Primary actions (top)
  div(class = "d-grid gap-2 mb-3",
      actionButton("action1", "Action", icon = icon("icon-name"))
  ),

  # Scrollable content (middle - consumes available space)
  div(style = "flex-grow: 1; overflow-y: auto;",
      uiOutput("dynamic_content")
  ),

  # Compact footer (bottom - minimal vertical space)
  div(class = "d-flex justify-content-between align-items-center",
      actionLink("settings", tagList(icon("gear"), "Settings")),
      actionLink("about", tagList(icon("info-circle"), "About"))
  )
)
```

**Space-saving techniques:**
- Combine related links into single row with `d-flex`
- Remove redundant `hr()` separators
- Use icon-only buttons with tooltips for secondary actions
- Consolidate duplicate information (e.g., session cost inline + dedicated costs page)

### Anti-Patterns to Avoid
- **Including "www/" in asset paths:** `href="www/favicon.ico"` won't work; use `href="favicon.ico"`
- **Using "fa-" prefix in icon names:** `icon("fa-gear")` is wrong; use `icon("gear")`
- **Redundant UI elements:** Displaying same information in multiple sidebar locations wastes space
- **Inconsistent icon libraries:** Mixing Font Awesome, Glyphicons, and Bootstrap Icons without design intent confuses users

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Icon rendering | Custom SVG inlining | `shiny::icon()` or `bsicons::bs_icon()` | Handles accessibility (ARIA), size scaling, color theming automatically |
| Favicon generation | Manual ICO file creation | Online converters (favicon.io, realfavicongenerator.net) | ICO format requires multiple resolutions; tools handle this correctly |
| Static asset serving | Custom HTTP handlers | `www/` directory convention | Shiny automatically serves www/ files with correct MIME types and caching headers |
| Dark mode icon switching | JavaScript toggle logic for each icon | CSS `[data-bs-theme="dark"]` selectors | bslib's theme system manages dark/light automatically |

**Key insight:** Shiny and bslib have mature conventions for all three UI polish tasks. Custom solutions add complexity without benefit.

## Common Pitfalls

### Pitfall 1: Incorrect Icon Names
**What goes wrong:** `icon("fa-calendar")` renders as broken icon or missing
**Why it happens:** Icon name includes library prefix that should be omitted
**How to avoid:** Remove "fa-", "glyphicon-", "bi-" prefixes; use bare name
**Warning signs:** Empty box, missing icon, browser console errors

### Pitfall 2: Favicon Not Appearing in Browser
**What goes wrong:** Favicon file exists but doesn't show in browser tab
**Why it happens:** Browser caching, incorrect file path, or missing `<link>` tag
**How to avoid:**
1. Verify file is in `www/` directory (not root or subdirectory)
2. Use correct path in `<link>` tag: `href="favicon.ico"` not `href="www/favicon.ico"`
3. Hard-refresh browser (Ctrl+Shift+R) to bypass cache
4. Check browser dev tools Network tab to verify file loads (200 status)
**Warning signs:** Browser requests `/favicon.ico` but gets 404 error

### Pitfall 3: Sidebar Layout Breaking on Small Screens
**What goes wrong:** Fixed sidebar width causes horizontal scrolling on mobile
**Why it happens:** bslib sidebar is responsive by default, but custom CSS can break it
**How to avoid:** Test sidebar layout at narrow widths; avoid `min-width` on sidebar content
**Warning signs:** Horizontal scrollbar appears, content cut off on mobile

### Pitfall 4: Redundant HR() Elements Consuming Space
**What goes wrong:** Multiple `hr()` elements between sidebar sections waste 20-30px each
**Why it happens:** Copy-paste from examples without considering cumulative vertical space
**How to avoid:** Use `hr()` sparingly (1-2 max); rely on margin classes (`mb-3`, `mt-3`) for spacing
**Warning signs:** Sidebar feels cramped, scrolling needed for short content lists

### Pitfall 5: Icon Selection Lacks Visual Hierarchy
**What goes wrong:** All preset buttons use similar icons (e.g., all "file" variants)
**Why it happens:** Choosing icons by name similarity rather than visual distinction
**How to avoid:** Select icons with different shapes/metaphors to aid quick recognition
**Warning signs:** Users can't quickly identify which button is which without reading labels

## Code Examples

Verified patterns from official sources:

### Icon Implementation for Synthesis Presets
```r
# Source: https://rstudio.github.io/shiny/reference/icon.html
# Current code (lines 35-45 in mod_document_notebook.R):
actionButton(ns("btn_summarize"), "Summarize",
             class = "btn-sm btn-outline-primary")
actionButton(ns("btn_keypoints"), "Key Points",
             class = "btn-sm btn-outline-primary")
actionButton(ns("btn_studyguide"), "Study Guide",
             class = "btn-sm btn-outline-primary")
actionButton(ns("btn_outline"), "Outline",
             class = "btn-sm btn-outline-primary")
actionButton(ns("btn_slides"), "Slides",
             class = "btn-sm btn-outline-primary",
             icon = icon("file-powerpoint"))  # Only slides has icon currently

# Recommended icons (distinct visual metaphors):
actionButton(ns("btn_summarize"), "Summarize",
             class = "btn-sm btn-outline-primary",
             icon = icon("file-lines"))  # Document with text lines
actionButton(ns("btn_keypoints"), "Key Points",
             class = "btn-sm btn-outline-primary",
             icon = icon("list-check"))  # Checked list items
actionButton(ns("btn_studyguide"), "Study Guide",
             class = "btn-sm btn-outline-primary",
             icon = icon("lightbulb"))  # Learning/ideas
actionButton(ns("btn_outline"), "Outline",
             class = "btn-sm btn-outline-primary",
             icon = icon("list-ol"))  # Numbered/hierarchical list
# btn_slides already has icon("file-powerpoint") - keep as-is
```

**Icon selection rationale:**
- **file-lines** (Summarize): Text document metaphor
- **list-check** (Key Points): Bullet list with checkmarks
- **lightbulb** (Study Guide): Learning/understanding metaphor
- **list-ol** (Outline): Numbered/ordered hierarchy
- **file-powerpoint** (Slides): Presentation deck (already implemented)

**Source:** Font Awesome icon reference: https://fontawesome.com/icons

### Favicon Setup
```r
# Source: https://shiny.posit.co/r/articles/build/css/
# Add to ui (app.R line 22-33, inside page_sidebar() call):
ui <- page_sidebar(
  title = div(
    class = "d-flex align-items-center gap-2",
    icon("book-open"),
    "Serapeum"
  ),
  theme = bs_theme(...),
  tags$head(
    # Add favicon links HERE (before existing style tags)
    tags$link(rel = "shortcut icon", href = "favicon.ico"),
    tags$link(rel = "icon", type = "image/png", sizes = "32x32", href = "favicon-32x32.png"),
    tags$link(rel = "icon", type = "image/png", sizes = "16x16", href = "favicon-16x16.png"),

    # Existing styles...
    tags$style(HTML("..."))
  ),
  # ... rest of UI
)
```

**Favicon file creation:**
1. Create square logo/icon (512x512 PNG recommended source)
2. Use online converter: https://favicon.io/favicon-converter/
3. Download generated files (favicon.ico, PNG variants)
4. Place all files in `www/` directory

### Sidebar Layout Optimization
```r
# Source: https://rstudio.github.io/bslib/articles/sidebars/
# Current code (app.R lines 99-120): Session cost display + 3 hr() + separate rows
# Problems:
# - Line 98: hr() before session cost
# - Line 106: hr() after session cost
# - Line 115-120: Cost link in dedicated row with empty span for spacing
# - Wastes ~60-80px vertical space

# Optimized approach: Combine footer elements into single compact section
sidebar = sidebar(
  title = "Notebooks",
  width = 280,

  # ... (new notebook buttons and notebook list unchanged) ...

  hr(),  # Single separator before footer

  # Compact footer combining all navigation + session cost
  div(
    class = "d-flex flex-column gap-2",

    # Row 1: Settings + About
    div(
      class = "d-flex justify-content-between align-items-center",
      actionLink("settings_link", tagList(icon("gear"), "Settings"),
                 class = "text-muted small"),
      actionLink("about_link", tagList(icon("info-circle"), "About"),
                 class = "text-muted small")
    ),

    # Row 2: Costs + GitHub
    div(
      class = "d-flex justify-content-between align-items-center",
      actionLink("cost_link", tagList(icon("dollar-sign"), "Costs"),
                 class = "text-muted small"),
      tags$a(
        href = "https://github.com/seanthimons/serapeum",
        target = "_blank",
        class = "text-muted small d-flex align-items-center gap-1",
        icon("github"), "GitHub"
      )
    ),

    # Row 3: Session cost + Dark mode toggle
    div(
      class = "d-flex justify-content-between align-items-center",
      div(
        class = "d-flex align-items-center gap-1",
        span(class = "text-muted small", icon("coins"), "Session:"),
        textOutput("session_cost_inline", inline = TRUE) |>
          tagAppendAttributes(class = "text-muted small fw-semibold")
      ),
      tags$button(
        id = "dark_mode_toggle",
        class = "btn btn-sm btn-outline-secondary",
        onclick = "...",  # Existing JS unchanged
        icon("moon")
      )
    )
  )
)
```

**Space savings:**
- Removed 2 redundant `hr()` elements: ~40px
- Consolidated 4 layout rows into 3: ~30px
- Used `gap-2` (8px) between rows instead of `mb-2` (8px) + hr() (20px): ~20px
- **Total reclaimed:** ~90px vertical space for notebook list

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Glyphicons (Bootstrap 3) | Font Awesome 6 / Bootstrap Icons | Bootstrap 4+ (2018+) | Larger icon library, better licensing, SVG support |
| .ico files only | .ico + PNG favicons | ~2020 | Better resolution on high-DPI displays, Safari/mobile support |
| Fixed sidebar layouts | Responsive sidebars via bslib | bslib 0.3.0+ (2021) | Mobile-friendly, collapsible, better space management |
| Custom icon rendering | shiny::icon() wrapper | Shiny 1.0+ (2017) | Automatic accessibility, consistent styling |

**Deprecated/outdated:**
- **Glyphicons:** Bootstrap 4+ removed default Glyphicons; use Font Awesome or Bootstrap Icons
- **addResourcePath() for www/:** Still works but unnecessary; `www/` convention is simpler
- **ICO-only favicons:** Modern browsers prefer PNG; provide both for compatibility

## Open Questions

1. **Specific icon choices for synthesis presets**
   - What we know: Font Awesome has suitable icons (file-lines, list-check, lightbulb, list-ol)
   - What's unclear: User preference for metaphors (lightbulb vs. book for "study guide")
   - Recommendation: Use proposed icons initially, gather user feedback, iterate if needed

2. **Favicon design source**
   - What we know: Need square logo/icon in high resolution
   - What's unclear: Does project have existing logo/branding assets?
   - Recommendation: Check for existing assets first; if none, create simple "S" lettermark or book icon

3. **Sidebar space priorities**
   - What we know: Session cost display, settings/about links, GitHub link, dark mode toggle all present
   - What's unclear: Are all footer elements equally important to users?
   - Recommendation: Keep all elements but consolidate layout; monitor usage analytics if available

## Sources

### Primary (HIGH confidence)
- Shiny icon() function: https://shiny.posit.co/r/reference/shiny/0.14/icon.html
- bslib sidebars documentation: https://rstudio.github.io/bslib/articles/sidebars/
- Shiny CSS/static assets: https://shiny.posit.co/r/articles/build/css/
- Font Awesome icon search: https://fontawesome.com/icons
- Bootstrap Icons library: https://icons.getbootstrap.com/

### Secondary (MEDIUM confidence)
- R Shiny & FontAwesome guide: https://www.appsilon.com/post/r-shiny-fontawesome-icons
- Favicon setup discussion: https://groups.google.com/g/shiny-discuss/c/TfLawWitzNs
- bslib package reference (Jan 2026): https://cran.r-project.org/web/packages/bslib/bslib.pdf
- UI design principles 2026: https://www.uxdesigninstitute.com/blog/ux-design-principles-2026/
- Sidebar UX best practices: https://uxplanet.org/best-ux-practices-for-designing-a-sidebar-9174ee0ecaa2

### Tertiary (LOW confidence)
- Favicon conversion tools: https://favicon.io/favicon-converter/ (tool functionality, not design guidance)
- Icon selection trends 2026: https://medium.com/@ariniwrites/a-strategic-guide-to-2026-iconography-trends-how-to-choose-the-right-visual-style-for-your-73833baf2394 (trends, not specific to R/Shiny)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Shiny documentation, mature ecosystem
- Architecture: HIGH - Verified patterns from Posit/RStudio sources, existing codebase review
- Pitfalls: HIGH - Common issues documented in community forums and personal observation from codebase

**Research date:** 2026-02-13
**Valid until:** ~90 days (stable domain; icon libraries and Shiny conventions change slowly)
