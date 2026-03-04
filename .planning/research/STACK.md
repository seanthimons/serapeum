# Stack Research — v10.0 Theme Harmonization & AI Synthesis

**Domain:** Global theme/icon design system, methodology extraction from PDFs, gap analysis synthesis
**Researched:** 2026-03-04
**Confidence:** HIGH

## Executive Summary

**No new dependencies required.** All features can be implemented with the existing stack. This milestone extends current capabilities rather than adding new ones.

- **Global theme/icon policy** → Use existing `bslib::bs_add_variables()` + `bsicons` (already in use)
- **Methodology extraction** → Reuse section-targeted RAG from Conclusions preset (existing `detect_section_hint()` recognizes "methods" sections)
- **Gap analysis synthesis** → Reuse existing preset architecture (`generate_conclusions_preset()` pattern)

## Recommended Stack (NO CHANGES)

### Core Framework — Already Validated

| Technology | Current | Latest | Status | Notes |
|------------|---------|--------|--------|-------|
| **bslib** | 0.9.0 | 0.10.0 | Optional upgrade | Theme system + `bs_add_rules()` sufficient for v10.0 |
| **pdftools** | 3.6.0 | 3.7.0 | No change needed | Current version handles PDF extraction |
| **bsicons** | 0.1.2 | 0.1.2 | Current | Bootstrap icons already integrated |
| **ragnar** | (installed) | (installed) | Current | Section detection already implemented |

### What NOT to Add

| Library | Reason NOT to Add |
|---------|-------------------|
| **sass** package standalone | Already bundled with bslib — `bs_add_rules()` accepts Sass |
| **tabulizer** / **tesseract** | Methodology text is already extracted by `pdftools::pdf_text()` — no OCR/table extraction needed |
| **fontawesome** alternative | `bsicons` already provides 2000+ Bootstrap icons — adding another library fragments icon usage |
| **Custom CSS frameworks** | Bootstrap + Catppuccin palette already validated across 9 milestones |
| **Additional NLP libraries** | Section detection via keyword heuristics (`detect_section_hint()`) works — LLM-based extraction is overkill |

## Integration Points

### 1. Global Theme/Icon Policy (#138)

**Current architecture:**
```r
# R/theme_catppuccin.R
catppuccin_dark_css() → bs_add_rules()

# app.R
bs_theme(
  version = 5,
  primary = "#7287fd",  # Catppuccin Lavender
  secondary = "#9ca0b0", # Catppuccin Overlay0
  ...
)
```

**What v10.0 adds:**
- Centralize button color mapping in `bs_theme()` using semantic Bootstrap variables
- Document icon-to-action mapping (destruction → `trash`, addition → `plus-circle`, etc.)
- Use `bs_add_variables()` to override Bootstrap's `$btn-*` Sass defaults for consistent states (hover, active, disabled)

**Why existing stack is sufficient:**
- `bslib::bs_add_variables()` sets Sass variables BEFORE Bootstrap compilation → affects all button variants
- `bsicons::bs_icon()` already used for citation audit value boxes → extend pattern to buttons
- No new dependencies required

### 2. Methodology Extractor Preset (#100)

**Current architecture:**
```r
# R/pdf.R
detect_section_hint() → recognizes "methods", "methodology", "approach", "experimental setup"

# R/rag.R
generate_conclusions_preset() → section-filtered hybrid search
```

**What v10.0 adds:**
```r
generate_methodology_preset(
  con, config, notebook_id,
  notebook_type = "document",
  session_id = NULL
) {
  # Query: "study design sample methods statistical analysis instruments"
  # Section filter: c("methods", "introduction", "general")
  # Same hybrid search + fallback pattern as conclusions preset
}
```

**Why existing stack is sufficient:**
- `detect_section_hint()` already tags chunks with `section_hint = "methods"` (R/pdf.R line 60)
- `search_chunks_hybrid()` already accepts `section_filter` parameter (R/_ragnar.R)
- `pdftools::pdf_text()` extracts all text — methods sections are already in chunks table
- No new PDF parsing needed

### 3. Gap Analysis Report Preset (#101)

**Current architecture:**
```r
# R/rag.R
generate_conclusions_preset() →
  - Section-filtered search for "limitations", "future_work", "discussion"
  - LLM synthesis with structured prompt
  - AI disclaimer banner
```

**What v10.0 adds:**
```r
generate_gap_analysis_preset(
  con, config, notebook_id,
  notebook_type = "document",
  session_id = NULL
) {
  # Query: "limitations contradictions underexplored missing gaps"
  # Section filter: c("limitations", "future_work", "discussion", "conclusion")
  # Structured prompt: methodological/geographic/population/theoretical gaps
  # AI disclaimer (like conclusions preset)
}
```

**Why existing stack is sufficient:**
- Same section-targeted RAG pattern as conclusions preset
- `detect_section_hint()` already tags limitations/future work sections
- OpenRouter LLM already handles synthesis — gap analysis is a different prompt, not new tech
- No new dependencies required

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Icon library | bsicons | fontawesome | Already using bsicons for citation audit — mixing icon libraries fragments design system |
| Theme framework | bslib + Sass | Custom CSS | Bootstrap + Catppuccin validated across 9 milestones — custom CSS adds tech debt |
| PDF parsing | pdftools + ragnar | tabulizer | Methods text is in plain text, no table extraction needed |
| Section detection | Keyword heuristics | LLM-based extraction | Current `detect_section_hint()` works — LLM adds latency + cost |

## Installation

**No new packages required.** All dependencies already in `renv.lock`.

```r
# Current renv.lock (verified 2026-03-04)
bslib: 0.9.0
pdftools: 3.6.0
bsicons: (via bslib Suggests)
ragnar: (installed as hard dependency)
```

## Design System Patterns

### Button Color Semantics (Bootstrap 5 Standard)

**Recommended mapping for #138:**

| Action Type | Bootstrap Class | Catppuccin Color | Icon Example |
|-------------|-----------------|------------------|--------------|
| **Primary action** | `btn-primary` | Lavender (#7287fd Latte) | `layer-group`, `search` |
| **Destructive** | `btn-danger` | Red (#d20f39 Latte / #f38ba8 Mocha) | `trash`, `x-circle` |
| **Confirmation** | `btn-success` | Green (#40a02b Latte / #a6e3a1 Mocha) | `check-circle`, `download` |
| **Secondary** | `btn-secondary` | Overlay0 (#9ca0b0) | `gear`, `eye` |
| **Warning** | `btn-warning` | Yellow (#df8e1d Latte / #f9e2af Mocha) | `exclamation-triangle` |

**Source:** [Bootstrap 5 button components](https://getbootstrap.com/docs/5.3/components/buttons/)

### Icon Consistency

**Current usage audit:**
- 4 bsicons in use: `file-text`, `arrow-left`, `arrow-right`, `search` (citation audit module)
- FontAwesome icons in document notebook: `layer-group`, `lightbulb`, `list-ol`, `microscope`

**Recommendation:**
- Migrate FontAwesome to `bsicons` for consistency (bsicons has 2000+ icons)
- Document icon → action mapping in `R/theme_catppuccin.R` or new `R/design_system.R`

### Sass Variable Strategy

**Use `bs_add_variables()` for button state overrides:**
```r
bs_theme(
  primary = LATTE$lavender,
  danger = LATTE$red,
  ...
) %>%
bs_add_variables(
  # Override button hover behavior
  "btn-hover-bg-scale" = "-10%",  # Darken on hover
  "btn-hover-border-scale" = "-12.5%"
)
```

**Source:** [bslib Sass variables documentation](https://rstudio.github.io/bslib/reference/bs_bundle.html)

## Version Verification

**Verification method:** WebSearch (CRAN package PDFs dated January–February 2026)

**Latest versions (as of 2026-03-04):**
- bslib 0.10.0 (January 26, 2026) — [CRAN package page](https://cran.r-project.org/web/packages/bslib/bslib.pdf)
- pdftools 3.7.0 (January 30, 2026) — [CRAN package page](https://cran.r-project.org/web/packages/pdftools/pdftools.pdf)
- bsicons 0.1.2 (July 22, 2025) — [CRAN package page](https://cran.r-project.org/web/packages/bsicons/bsicons.pdf)

### Optional Upgrades (Not Required for v10.0)

**bslib 0.9.0 → 0.10.0:**
- Pro: Latest Bootstrap 5.3 features, improved `bs_themer()` for real-time testing
- Con: Upgrade risk during active milestone (9 releases since 0.9.0)
- **Recommendation:** Defer to v11.0 — current version sufficient for theme variables

**pdftools 3.6.0 → 3.7.0:**
- Pro: Bug fixes in libpoppler backend
- Con: No new API — methodology extraction uses same `pdf_text()` function
- **Recommendation:** Defer — current version handles all use cases

## Pitfalls and Mitigations

### Theme/Icon Policy

**Risk:** Bootstrap state classes (hover, active, disabled) may not cascade correctly if variables set too late
**Mitigation:** Use `bs_add_variables(.where = "defaults")` to inject before Bootstrap compilation

### Methodology Extraction

**Risk:** Methods sections vary widely in structure (some papers use "Materials and Methods", others "Experimental Design")
**Mitigation:** Expand `detect_section_hint()` regex to catch variants: `"(method|material|experiment|procedure)"`

### Gap Analysis

**Risk:** Higher hallucination risk (inferring what's NOT in text vs extracting what IS there)
**Mitigation:**
- Use OWASP instruction-data separation (already in conclusions preset)
- AI disclaimer banner (already implemented for conclusions/research questions/lit review)
- Prompt engineering: "Only identify gaps supported by contradictions or omissions explicitly mentioned in the sources"

## Sources

**Official documentation:**
- [bslib theming guide](https://rstudio.github.io/bslib/articles/theming/index.html) — Theming approach for Bootstrap in R
- [bslib Sass variables reference](https://rstudio.github.io/bslib/reference/bs_bundle.html) — `bs_add_variables()` documentation
- [pdftools package documentation](https://cran.r-project.org/web/packages/pdftools/pdftools.pdf) — Version 3.7.0, January 2026
- [bsicons package documentation](https://cran.r-project.org/web/packages/bsicons/bsicons.pdf) — Version 0.1.2, July 2025
- [Bootstrap 5.3 button components](https://getbootstrap.com/docs/5.3/components/buttons/) — Official Bootstrap docs

**Community/Best Practices:**
- [Semantic button color design 2026](https://thelinuxcode.com/how-to-change-button-color-in-bootstrap-5-and-keep-it-consistent-accessible-and-scalable/) — Design system principles
- [sass R package overview](https://rstudio.github.io/sass/articles/sass.html) — How sass integrates with bslib
- [ragnar semantic chunking documentation](https://ragnar.tidyverse.org/articles/ragnar.html) — Section-aware chunking

---
*Stack research for: Serapeum v10.0 Theme Harmonization & AI Synthesis*
*Researched: 2026-03-04*
