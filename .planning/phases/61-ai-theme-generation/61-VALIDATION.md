---
phase: 61
slug: ai-theme-generation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat (R) |
| **Config file** | none — run via `testthat::test_dir("tests/testthat")` |
| **Quick run command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-themes.R')"` |
| **Full suite command** | `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file('tests/testthat/test-themes.R')`
- **After every plan wave:** Run `testthat::test_dir('tests/testthat')`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 61-01-01 | 01 | 1 | THME-05 | unit | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ W0 | ⬜ pending |
| 61-01-02 | 01 | 1 | THME-06 | unit | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ W0 | ⬜ pending |
| 61-01-03 | 01 | 1 | THME-07 | unit | `testthat::test_file('tests/testthat/test-themes.R')` | ❌ W0 | ⬜ pending |
| 61-02-01 | 02 | 2 | THME-05 | manual + smoke | Shiny smoke test | N/A | ⬜ pending |
| 61-02-02 | 02 | 2 | THME-06 | manual + smoke | Shiny smoke test | N/A | ⬜ pending |
| 61-02-03 | 02 | 2 | THME-07 | manual + smoke | Shiny smoke test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-themes.R` — add tests for `extract_theme_json()` (THME-06)
- [ ] `tests/testthat/test-themes.R` — add tests for `validate_theme_colors()` (THME-07 hex)
- [ ] `tests/testthat/test-themes.R` — add tests for `validate_and_fix_font()` (THME-07 font)
- [ ] `tests/testthat/test-themes.R` — add tests for `generate_theme_from_description()` with mocked `chat_completion()` (THME-05)

*Existing infrastructure covers framework setup — only new test cases needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AI Generate button opens collapse panel with textarea | THME-05 | UI interaction in modal | Click "AI Generate" → verify collapse expands with textarea and Generate button |
| Spinner appears during LLM call | THME-05 | Visual browser behavior | Click Generate → verify spinner + "Generating..." text appears |
| Color pickers populated with AI values | THME-06 | Shiny reactive UI state | After generation → verify all 4 hex inputs + font selector show AI values |
| Error toast shows bad field names | THME-07 | Toast notification rendering | Force bad hex in test → verify toast names specific bad fields |
| Regenerate button appears after generation | THME-05 | Dynamic UI rendering | After generation → verify Regenerate button visible in customize panel |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
