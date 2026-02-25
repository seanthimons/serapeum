---
phase: 32-testing-polish
type: context
created: 2026-02-22
mode: auto
---

# Phase 32 Context: Testing & Polish

## Scope

Validation-only phase. No new features or CSS changes unless bugs are found during testing.

## Decisions

### Testing Approach
- **Automated verification**: Run the app, check for R errors/warnings on startup
- **Code audit**: Grep for any remaining non-theme-aware patterns (hardcoded hex colors, bg-light, text-dark)
- **CSS validation**: Verify catppuccin_dark_css() generates valid CSS with no syntax errors
- **Cross-module check**: Verify all modules load without errors

### What Constitutes a Bug
- R errors or warnings on app startup
- Remaining hardcoded hex colors in UI elements (not data viz)
- Missing dark mode overrides for Bootstrap components
- CSS specificity conflicts

### Out of Scope
- New features
- Performance optimization
- Refactoring beyond bug fixes found during testing

## Deferred Ideas
None — this is the final phase of v6.0.
