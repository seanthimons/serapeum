---
phase: 64
slug: additive-guards
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 64 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run Shiny smoke test (app starts without error)
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green (minus 13 pre-existing failures)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 64-01-01 | 01 | 1 | GARD-01 | manual | Shiny smoke test | N/A | ⬜ pending |
| 64-01-02 | 01 | 1 | GARD-02 | grep | `grep -n "isolate(fig_refresh())" R/mod_document_notebook.R` | ✅ | ⬜ pending |
| 64-01-03 | 01 | 1 | GARD-03 | unit | `grep -n "is.null(openrouter_id)" R/api_artificialanalysis.R` | ✅ | ⬜ pending |
| 64-01-04 | 01 | 1 | GARD-03 | grep | `grep -n "is.na" R/db.R` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed — guards are verified by grep and smoke test.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Query builder doesn't crash with no model | GARD-01 | Requires Shiny session with NULL provider | Start app, go to query builder without configuring API key, click Generate |
| fig_refresh doesn't cause infinite loop | GARD-02 | Observable only via CPU usage and UI behavior | Process documents, monitor for repeated toasts or CPU spike |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
