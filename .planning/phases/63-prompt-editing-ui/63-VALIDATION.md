---
phase: 63
slug: prompt-editing-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"` |
| **Full suite command** | `Rscript -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"`
- **After every plan wave:** Run `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 63-01-01 | 01 | 1 | PRMT-01,02,03 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"` | ❌ W0 | ⬜ pending |
| 63-01-02 | 01 | 1 | PRMT-04,05 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"` | ❌ W0 | ⬜ pending |
| 63-01-03 | 01 | 1 | PRMT-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-prompt-helpers.R')"` | ❌ W0 | ⬜ pending |
| 63-02-01 | 02 | 2 | PRMT-01,02 | manual | Shiny smoke test | N/A | ⬜ pending |
| 63-02-02 | 02 | 2 | PRMT-05 | manual | Shiny smoke test | N/A | ⬜ pending |
| 63-02-03 | 02 | 2 | PRMT-06 | manual | Shiny smoke test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-prompt-helpers.R` — stubs for PRMT-01 through PRMT-06 (CRUD functions, default extraction, version retrieval)
- [ ] Test fixtures for prompt_versions table creation in test DB

*Existing test infrastructure (testthat, DuckDB test helpers) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Modal opens with preset prompt text | PRMT-01 | Shiny UI interaction | Click preset in Settings → verify modal shows correct prompt text |
| Edit and save updates prompt | PRMT-02 | Shiny UI interaction | Modify text → Save → Re-open → verify new text persists |
| RAG plumbing hidden | PRMT-03 | Visual verification | Open any preset → verify no CITATION RULES or OWASP markers visible |
| Version dropdown shows dates | PRMT-05 | Shiny UI interaction | Save 2+ versions → verify dropdown shows dates, selecting loads correct text |
| Reset to default restores original | PRMT-06 | Shiny UI interaction | Edit a preset → Reset → verify hardcoded default text appears |
| Edited prompts used in generation | PRMT-02 | End-to-end | Edit a preset prompt → run preset in notebook → verify output reflects new instructions |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
