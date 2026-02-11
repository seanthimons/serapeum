---
phase: 04-startup-wizard-polish
plan: 02
subsystem: slide-generation
tags: [citations, css, revealjs, slides]
dependency_graph:
  requires: []
  provides: [citation-css-injection]
  affects: [slide-generation-pipeline]
tech_stack:
  added: []
  patterns: [css-injection, yaml-frontmatter-manipulation]
key_files:
  created: []
  modified: [R/slides.R]
decisions:
  - "CSS injection uses high specificity (.reveal .slides section .footnotes) with !important to override RevealJS theme defaults"
  - "Citation CSS is inline in YAML frontmatter (pipe literal syntax) rather than separate .css file for self-contained slides"
  - "Multiple font sizes for different citation elements: footnotes (0.5em), references (0.45em), footnote-ref (0.7em), sup (0.6em)"
  - "max-height: 15vh with overflow-y: auto prevents citations from pushing content off-slide"
metrics:
  duration_minutes: 1
  completed_date: "2026-02-11"
---

# Phase 04 Plan 02: Slide Citation CSS Fix Summary

**One-liner:** Inline CSS injection constrains RevealJS citation/footnote font sizes to prevent slide overflow using high-specificity selectors.

## What Was Built

Added citation CSS injection to the slide generation pipeline to fix oversized citations that overflow slide boundaries (GitHub #51). The implementation:

1. **New function `inject_citation_css()`** - Injects CSS rules into QMD frontmatter to constrain citation sizing
2. **Pipeline integration** - Wired into `generate_slides()` after theme injection
3. **Three frontmatter cases handled:**
   - Expanded format with theme (`format:\n  revealjs:\n    theme: moon`)
   - Simple format (`format: revealjs`)
   - No format section (adds complete format block)

## Key Technical Decisions

### CSS Specificity Strategy
Used `.reveal .slides section .footnotes` (full specificity chain) with `!important` on font-size rules. RevealJS themes apply high-specificity selectors, so normal CSS would be overridden. This ensures citation styling works across all themes.

### Inline CSS vs External File
CSS is embedded in YAML frontmatter using pipe literal syntax (`css:\n  - |`) rather than referencing external .css files. This keeps generated slides self-contained and portable.

### Font Size Hierarchy
Different citation elements use different font sizes:
- `.footnotes`: 0.5em (main citation list)
- `.references`: 0.45em (bibliography section)
- `.footnote-ref`: 0.7em (superscript citation markers)
- `sup`: 0.6em (generic superscripts)

### Overflow Protection
`max-height: 15vh` with `overflow-y: auto` prevents citations from pushing slide content off-screen. If citations exceed 15% of viewport height, they become scrollable.

## Deviations from Plan

None - plan executed exactly as written.

## Task Breakdown

| Task | Description | Commit | Files Modified |
|------|-------------|--------|----------------|
| 1 | Add citation CSS injection to slide generation | 39a5429 | R/slides.R |

## Implementation Notes

### Function Implementation
`inject_citation_css()` follows the same pattern as `inject_theme_to_qmd()`:
1. Detect which frontmatter format exists (expanded/simple/none)
2. Use regex substitution to insert CSS at correct position
3. Handle edge case where theme already exists (insert CSS after theme line)

### Pipeline Integration
Called in `generate_slides()` after theme injection:
```r
if (theme != "default") {
  qmd_content <- inject_theme_to_qmd(qmd_content, theme)
}
qmd_content <- inject_citation_css(qmd_content)
```

Order matters: theme injection may convert simple format to expanded, so CSS injection must come after to handle the expanded format correctly.

## Verification Results

All verification criteria passed:
- ✅ R/slides.R loads without errors
- ✅ inject_citation_css produces valid YAML for expanded format input
- ✅ inject_citation_css produces valid YAML for simple format input
- ✅ inject_citation_css produces valid YAML for no-format input
- ✅ CSS uses !important and high specificity selectors
- ✅ Function is called in slide generation pipeline

Tested all three frontmatter cases with Rscript commands - all produce valid YAML with CSS properly positioned.

## Self-Check

### Files Created
(None)

### Files Modified
- [x] R/slides.R - FOUND

### Commits
- [x] 39a5429 - FOUND

## Self-Check: PASSED

All files and commits verified successfully.

## Success Criteria Met

- [x] Generated Quarto slides include citation CSS that constrains font sizes
- [x] CSS prevents footnote/reference overflow with max-height and scroll
- [x] CSS is self-contained in each .qmd file (inline in YAML)
- [x] Implementation handles all three frontmatter format cases
- [x] High specificity with !important ensures CSS works across all themes

## Known Limitations

None identified. The CSS should work with all RevealJS themes since it uses maximum specificity and !important directives.

## Next Steps

This plan completes the slide citation fix. Next work in Phase 04 may include:
- Complete startup wizard implementation (04-01 if not yet done)
- Additional polish items identified during testing
- User acceptance testing of slide generation with various themes

## References

- GitHub Issue #51: LLM-generated slides produce citations that overflow slides
- RevealJS documentation: CSS customization and theme overrides
- Research: .planning/phases/04-startup-wizard-polish/04-RESEARCH.md
