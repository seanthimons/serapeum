---
phase: 59
slug: theme-swatches-upload-and-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 59 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-slides.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | THME-01 | unit | test-slides.R | ❌ W0 | ⬜ pending |
| 59-01-02 | 01 | 1 | THME-02, THME-03 | unit | test-themes.R | ❌ W0 | ⬜ pending |
| 59-01-03 | 01 | 1 | THME-04 | unit | test-themes.R | ❌ W0 | ⬜ pending |
| 59-01-04 | 01 | 1 | THME-09 | unit | test-slides.R | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-themes.R` — stubs for THME-02, THME-03, THME-04 (upload, persist, delete)
- [ ] Theme swatch tests added to existing `tests/testthat/test-slides.R`

*Existing infrastructure covers test framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Swatch dots render in dropdown | THME-01 | Visual rendering in browser | Open slide modal, verify colored dots next to theme names |
| Delete × button works without selecting theme | THME-04 | Browser event propagation | Click × on custom theme, verify deletion without theme selection |
| Shiny app starts without errors | All | Runtime smoke test | Run app, open slide generation modal |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
