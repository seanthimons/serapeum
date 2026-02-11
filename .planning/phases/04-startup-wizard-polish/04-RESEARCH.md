# Phase 4: Startup Wizard + Polish - Research

**Researched:** 2026-02-11
**Domain:** R Shiny UI orchestration, user preferences persistence, Quarto RevealJS CSS customization
**Confidence:** HIGH

## Summary

This phase adds guided onboarding for new users and fixes slide citation formatting. The wizard orchestrates routing to three existing discovery modules (seed paper, query builder, topic explorer). User preference persistence uses browser localStorage via JavaScript. The slide citation fix requires CSS overrides in the generated Quarto documents.

The codebase already demonstrates the producer-consumer pattern between discovery modules and search notebook creation (Phase 1-3). The wizard extends this pattern with conditional first-run detection and modal-based routing UI. All three discovery modules return reactive requests consumed by app.R to create notebooks, so wizard implementation requires minimal changes to existing modules.

**Primary recommendation:** Build wizard as a Shiny modal shown on first app load, persist "skip wizard" preference via localStorage JavaScript, and inject custom CSS into Quarto slide generation to constrain footnote font sizes.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R Shiny | Current | Web framework | Project foundation (app.R, existing modules) |
| bslib | Current | Bootstrap 5 UI components | Used throughout app for cards, layouts |
| DuckDB | Current | Local database | Already stores settings table (lines 91-95 in db.R) |
| JavaScript (vanilla) | ES6+ | localStorage access | Native browser API, no dependencies needed |
| Quarto CLI | Current | Slide rendering | Already integrated (R/slides.R) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| shinyjs | Latest | Enhanced JavaScript integration | If complex JS-R communication needed beyond basic Shiny.setInputValue |
| Custom SCSS | N/A | RevealJS theme overrides | For slide citation sizing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| localStorage | DuckDB settings table | localStorage persists per-browser not per-database file; better for "skip wizard" preference |
| Shiny modal | Separate onboarding page | Modal keeps user in app context, simpler navigation flow |
| shinyStore package | Custom localStorage JS | shinyStore adds dependencies; direct JS is simpler for single boolean flag |

**Installation:**
No new R packages required. All needed libraries already in project dependencies.

## Architecture Patterns

### Recommended Pattern: Conditional Modal on App Load

Current app structure:
```r
# app.R lines 148, 474
current_view <- reactiveVal("welcome")

if (view == "welcome" || is.null(nb_id)) {
  return(
    card(
      card_body(
        h2("Welcome to Serapeum"),
        # Static welcome content
      )
    )
  )
}
```

Wizard pattern:
```r
# Check on session start if user has seen wizard
observe({
  has_seen_wizard <- get_wizard_preference()
  if (is.null(has_seen_wizard)) {
    showModal(modalDialog(
      title = "Welcome to Serapeum",
      # Wizard content with three path buttons
      footer = tagList(
        actionLink("skip_wizard", "Skip and don't show again"),
        modalButton("Close")
      ),
      size = "l",
      easyClose = FALSE
    ))
  }
}) |> bindEvent(TRUE, once = TRUE)
```

### Pattern 1: localStorage Persistence via JavaScript

**What:** Store user preferences in browser localStorage, readable across Shiny sessions.

**When to use:** For client-side preferences that should persist per-user per-browser (not per-database).

**Example:**
```javascript
// Embedded in app.R tags$script()
// Set preference
localStorage.setItem('serapeum_skip_wizard', 'true');

// Read on app load
var skipWizard = localStorage.getItem('serapeum_skip_wizard');
if (skipWizard) {
  Shiny.setInputValue('has_seen_wizard', true, {priority: 'event'});
}
```

**R side:**
```r
# Read JS-provided input
get_wizard_preference <- reactive({
  input$has_seen_wizard
})

# When user clicks "skip"
observeEvent(input$skip_wizard, {
  session$sendCustomMessage('setWizardPreference', TRUE)
  removeModal()
})

# JavaScript handler registered in UI
tags$script(HTML("
  Shiny.addCustomMessageHandler('setWizardPreference', function(value) {
    localStorage.setItem('serapeum_skip_wizard', 'true');
  });

  // On document ready, check localStorage and set input
  document.addEventListener('DOMContentLoaded', function() {
    var skipWizard = localStorage.getItem('serapeum_skip_wizard');
    if (skipWizard === 'true') {
      Shiny.setInputValue('has_seen_wizard', true, {priority: 'event'});
    } else {
      Shiny.setInputValue('has_seen_wizard', false, {priority: 'event'});
    }
  });
"))
```

**Source:** Adapted from [Posit LocalStorage Usage Guide](https://posit-conf-2024.github.io/level-up-shiny/workshop-06-chat.html)

### Pattern 2: Wizard Modal with Routing Buttons

**What:** Modal dialog with three action buttons routing to existing discovery modules.

**When to use:** For first-time user onboarding that guides toward existing features.

**Example:**
```r
modalDialog(
  title = tagList(icon("compass"), "Choose Your Path"),
  div(
    class = "text-center py-3",
    p(class = "lead", "How would you like to start exploring research?")
  ),
  layout_columns(
    col_widths = c(4, 4, 4),
    div(
      actionButton("wizard_seed_paper",
        label = div(
          icon("seedling", class = "fa-2x mb-2"),
          h5("Start with a Paper"),
          p(class = "small", "Have a paper in mind? Find related work.")
        ),
        class = "btn-outline-success w-100 py-4"
      )
    ),
    div(
      actionButton("wizard_query_builder",
        label = div(
          icon("wand-magic-sparkles", class = "fa-2x mb-2"),
          h5("Build a Query"),
          p(class = "small", "Describe your research interest.")
        ),
        class = "btn-outline-info w-100 py-4"
      )
    ),
    div(
      actionButton("wizard_topic_explorer",
        label = div(
          icon("compass", class = "fa-2x mb-2"),
          h5("Browse Topics"),
          p(class = "small", "Explore research areas.")
        ),
        class = "btn-outline-warning w-100 py-4"
      )
    )
  ),
  footer = tagList(
    actionLink("skip_wizard", "Skip and don't show again", class = "text-muted"),
    modalButton("Close")
  ),
  size = "l",
  easyClose = FALSE
)
```

**Routing handlers:**
```r
observeEvent(input$wizard_seed_paper, {
  removeModal()
  current_view("discover")  # Routes to mod_seed_discovery
})

observeEvent(input$wizard_query_builder, {
  removeModal()
  current_view("query_builder")  # Routes to mod_query_builder
})

observeEvent(input$wizard_topic_explorer, {
  removeModal()
  current_view("topic_explorer")  # Routes to mod_topic_explorer
})
```

**Source:** Existing app.R routing pattern (lines 238-253)

### Pattern 3: CSS Injection for Quarto Slide Citations

**What:** Add custom CSS to generated Quarto .qmd files to constrain footnote font sizes.

**When to use:** When LLM-generated slide content includes citations that overflow.

**Example:**
```r
# In R/slides.R, modify inject_theme_to_qmd or create new function
inject_citation_styles <- function(qmd_content) {
  # Check if frontmatter exists
  if (grepl("^---", qmd_content)) {
    # Look for existing css or add new
    citation_css <- "
format:
  revealjs:
    css:
      - |
        .reveal .footnotes {
          font-size: 0.5em;
          line-height: 1.2;
        }
        .reveal .footnote-ref {
          font-size: 0.6em;
          vertical-align: super;
        }
"
    # Insert before closing ---
    qmd_content <- sub(
      "\n---\n",
      paste0("\n", citation_css, "---\n"),
      qmd_content
    )
  }
  qmd_content
}
```

**Alternative approach (inline CSS):**
```yaml
---
title: "Presentation Title"
format:
  revealjs:
    theme: default
    css:
      - |
        .reveal .footnotes {
          font-size: 0.5em !important;
          max-height: 15vh;
          overflow-y: auto;
        }
        .reveal sup {
          font-size: 0.6em;
        }
---
```

**Source:** [Quarto RevealJS CSS customization patterns](https://quarto.org/docs/presentations/revealjs/themes.html) and [GitHub discussion #12961](https://github.com/quarto-dev/quarto-cli/discussions/12961)

### Anti-Patterns to Avoid

- **Don't use DuckDB for wizard preference:** Database file is user-specific, but wizard preference should be browser-specific. User with multiple database files should only see wizard once per browser, not once per database.
- **Don't create new discovery modules:** All three discovery paths already exist (Phase 1-3). Wizard only routes to them, never duplicates functionality.
- **Don't modify welcome screen logic:** Wizard is a modal overlay, not a replacement for the welcome card. Welcome screen should remain for users who dismiss wizard or open app without notebooks.
- **Don't use global CSS files for slides:** Each generated slide deck should be self-contained. Inject CSS into individual .qmd files, not into app-wide stylesheets.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser storage | Custom cookie parser | localStorage JavaScript API | Native, simple, persistent across sessions |
| Wizard state management | Complex multi-step form state | Single modal with three action buttons | All three paths are independent, no shared state needed |
| User preference syncing | Server-side session storage | Browser localStorage | Preference is client-side (per-browser), not server-side |
| RevealJS theming | Parse and rebuild CSS | Quarto YAML frontmatter | Quarto handles CSS injection, just provide YAML config |

**Key insight:** The wizard orchestrates existing functionality rather than implementing new features. Routing logic already exists in app.R (lines 238-253), localStorage is browser-native, and Quarto handles CSS compilation.

## Common Pitfalls

### Pitfall 1: localStorage Not Available on First Load

**What goes wrong:** JavaScript tries to read localStorage before Shiny session initializes, causing race condition.

**Why it happens:** DOMContentLoaded fires before Shiny.setInputValue is ready.

**How to avoid:** Wrap localStorage read in `$(document).on('shiny:connected', ...)` instead of DOMContentLoaded.

**Warning signs:** Console errors "Shiny.setInputValue is not a function" or wizard shows inconsistently.

**Example:**
```javascript
$(document).on('shiny:connected', function() {
  var skipWizard = localStorage.getItem('serapeum_skip_wizard');
  if (skipWizard === 'true') {
    Shiny.setInputValue('has_seen_wizard', true, {priority: 'event'});
  } else {
    Shiny.setInputValue('has_seen_wizard', false, {priority: 'event'});
  }
});
```

### Pitfall 2: Modal Shown Before Modules Initialize

**What goes wrong:** User clicks wizard button, but discovery module hasn't loaded yet, causing navigation to fail silently.

**Why it happens:** Modal shown in `observe({...}) |> bindEvent(TRUE, once = TRUE)` executes before module servers register.

**How to avoid:** Delay wizard display by 500ms or use `shiny::onFlushed()` to wait for reactive flush cycle.

**Warning signs:** Clicking wizard buttons does nothing, or current_view() changes but UI doesn't update.

**Example:**
```r
observe({
  has_seen_wizard <- input$has_seen_wizard

  # Wait for reactive flush to ensure modules loaded
  shiny::onFlushed(function() {
    if (is.null(has_seen_wizard) || !has_seen_wizard) {
      showModal(wizard_modal())
    }
  }, once = TRUE)
}) |> bindEvent(input$has_seen_wizard, once = TRUE)
```

### Pitfall 3: Citation CSS Overridden by Theme

**What goes wrong:** Custom citation font-size styles have no effect because RevealJS theme styles take precedence.

**Why it happens:** CSS specificity—theme rules like `.reveal .slides section .footnotes` are more specific than `.reveal .footnotes`.

**How to avoid:** Use `!important` flag or match theme specificity with `.reveal .slide .footnotes`.

**Warning signs:** Inspecting generated HTML shows custom CSS present but not applied.

**Example:**
```css
/* Won't work - insufficient specificity */
.reveal .footnotes {
  font-size: 0.5em;
}

/* Will work - matches theme specificity */
.reveal .slides section .footnotes {
  font-size: 0.5em !important;
}
```

### Pitfall 4: Wizard Routing Conflicts with Sidebar Buttons

**What goes wrong:** User clicks wizard "Start with a Paper" but sidebar "Discover from Paper" button also triggers, showing duplicate UI.

**Why it happens:** Both wizard and sidebar buttons set `current_view("discover")`.

**How to avoid:** Wizard buttons should removeModal() before setting current_view(), ensuring modal closes first.

**Warning signs:** Modal doesn't close when wizard button clicked, or discovery module appears twice.

**Example:**
```r
# Correct order
observeEvent(input$wizard_seed_paper, {
  removeModal()  # Close wizard first
  current_view("discover")  # Then navigate
})

# Wrong order causes race condition
observeEvent(input$wizard_seed_paper, {
  current_view("discover")  # Module loads while modal open
  removeModal()  # Modal removal queued after module render
})
```

## Code Examples

Verified patterns from codebase and official sources:

### Existing Discovery Module Routing

From app.R lines 238-253:
```r
# Discover from paper button
observeEvent(input$discover_paper, {
  current_view("discover")
  current_notebook(NULL)
})

# Build a query button
observeEvent(input$build_query, {
  current_notebook(NULL)
  current_view("query_builder")
})

# Explore topics button
observeEvent(input$explore_topics, {
  current_notebook(NULL)
  current_view("topic_explorer")
})
```

**Pattern:** Set current_notebook(NULL) to clear selection, then set current_view() to route.

### Existing Modal Pattern

From app.R lines 257-266:
```r
observeEvent(input$new_document_nb, {
  showModal(modalDialog(
    title = tagList(icon("file-pdf"), "New Document Notebook"),
    textInput("new_doc_nb_name", "Notebook Name",
              placeholder = "e.g., Research Papers"),
    footer = tagList(
      modalButton("Cancel"),
      actionButton("create_doc_nb", "Create", class = "btn-primary")
    )
  ))
})
```

**Pattern:** showModal() in observeEvent for button click, modalButton() for cancel, actionButton for primary action.

### Existing Theme Injection Pattern

From R/slides.R lines 101-131:
```r
inject_theme_to_qmd <- function(qmd_content, theme) {
  if (is.null(theme) || theme == "default") {
    return(qmd_content)
  }

  # Check if format section exists
  if (grepl("format:\\s*\\n\\s*revealjs:", qmd_content)) {
    # Add theme under revealjs section
    qmd_content <- sub(
      "(format:\\s*\\n\\s*revealjs:)",
      paste0("\\1\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("format:\\s*revealjs", qmd_content)) {
    # Convert simple format to expanded with theme
    qmd_content <- sub(
      "format:\\s*revealjs",
      paste0("format:\n  revealjs:\n    theme: ", theme),
      qmd_content
    )
  } else if (grepl("^---", qmd_content)) {
    # No format section, add one before closing ---
    qmd_content <- sub(
      "\n---\n",
      paste0("\nformat:\n  revealjs:\n    theme: ", theme, "\n---\n"),
      qmd_content
    )
  }

  qmd_content
}
```

**Pattern:** Use regex sub() to inject YAML into frontmatter at correct indentation level. Check for existing structure before inserting.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static welcome screen only | Wizard + welcome screen | 2024-2025 | Modern Shiny apps guide new users with contextual onboarding |
| Cookies for preferences | localStorage | 2020+ | localStorage is GDPR-friendly, doesn't require server roundtrip |
| Hard-coded CSS in separate files | Inline CSS in YAML | Quarto 1.3+ (2023) | Self-contained documents, no external dependencies |
| `observe({...}, priority = -1)` for init | `bindEvent(TRUE, once = TRUE)` | Shiny 1.6+ (2021) | Clearer intent, avoids negative priority anti-pattern |

**Deprecated/outdated:**
- **shinyStore package**: Last updated 2016, localStorage now standard in modern browsers, direct JavaScript simpler
- **observe() without bindEvent() for once-on-load**: Modern Shiny uses `bindEvent(TRUE, once = TRUE)` pattern
- **Quarto theme files**: Can use inline CSS in YAML for small customizations instead of separate .scss files

## Open Questions

1. **Should wizard remember last-used discovery path?**
   - What we know: localStorage can store strings, wizard could default to last path
   - What's unclear: Whether users want "last used" or always see all three options
   - Recommendation: Phase 4.1 shows all three options. If analytics later show strong preference for one path, Phase 4.2+ could add smart defaults

2. **Should wizard include notebook creation in one step?**
   - What we know: GitHub #43 mentions "both modes be combinable"
   - What's unclear: Whether wizard should collect inputs (DOI, query, topic) or just route to modules
   - Recommendation: Route only. Discovery modules already have good UX for collecting inputs. Wizard duplicating those inputs creates maintenance burden

3. **Should citation CSS be user-configurable?**
   - What we know: GitHub #51 wants citations "small and not overlap"
   - What's unclear: Whether users want control over citation size or just want it fixed
   - Recommendation: Fix with reasonable defaults (0.5em for footnotes, 0.6em for references). If users request customization later, add to slide generation options

## Sources

### Primary (HIGH confidence)
- Existing codebase: `C:\Users\sxthi\Documents\serapeum\app.R` - Current routing and modal patterns
- Existing codebase: `C:\Users\sxthi\Documents\serapeum\R\slides.R` - Quarto YAML injection pattern
- Existing codebase: `C:\Users\sxthi\Documents\serapeum\R\db.R` - Settings table schema and functions
- GitHub Issue #43: [feat: Startup UI for seed papers or search term generation](https://github.com/seanthimons/serapeum/issues/43)
- GitHub Issue #51: [bugfix: On slide generation, citations are too large](https://github.com/seanthimons/serapeum/issues/51)

### Secondary (MEDIUM confidence)
- [Posit LocalStorage Usage Guide](https://posit-conf-2024.github.io/level-up-shiny/workshop-06-chat.html) - Official Shiny localStorage pattern (2024 workshop)
- [Mastering Shiny - Dynamic UI](https://mastering-shiny.org/action-dynamic.html) - Wizard pattern documentation
- [Quarto RevealJS Options](https://quarto.org/docs/reference/formats/presentations/revealjs.html) - Official CSS customization docs
- [Quarto RevealJS Themes](https://quarto.org/docs/presentations/revealjs/themes.html) - Theme and styling patterns
- [Shiny Modal Dialogs Documentation](https://shiny.posit.co/r/articles/build/modal-dialogs/index.html) - Official modal API reference

### Tertiary (LOW confidence)
- [GitHub quarto-dev/quarto-cli Discussion #12961](https://github.com/quarto-dev/quarto-cli/discussions/12961) - Community discussion on smallest font overrides (not official recommendation)
- [Sling Academy - JavaScript Storage Persistence](https://www.slingacademy.com/article/persist-user-preferences-and-sessions-via-javascript-storage/) - General web dev tutorial (not R-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, verified in codebase
- Architecture: HIGH - Existing patterns (modal, routing, YAML injection) verified in app.R and R/slides.R
- Pitfalls: MEDIUM - Based on common Shiny patterns and web dev experience, not project-specific incidents
- localStorage integration: MEDIUM - Pattern documented in Posit workshop (2024) but not tested in this codebase yet
- CSS injection: MEDIUM - Quarto docs clear, but specific citation selector may need empirical testing

**Research date:** 2026-02-11
**Valid until:** 2026-03-11 (30 days - stable stack, mature patterns)
