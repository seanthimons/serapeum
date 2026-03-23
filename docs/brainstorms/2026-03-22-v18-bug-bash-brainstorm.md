---
date: 2026-03-22
topic: v18-bug-bash
---

# v18 Bug Bash Triage

## What We're Doing

Triaging and fixing all 13 issues in the v18: Bug Bash milestone. Issues are organized
into 5 sessions by complexity, dependency, and whether they need live-app testing.

## Session Plan

### Session A: Surgical Fixes (batch, one session)

One-line to few-line fixes with exact file:line references. No ambiguity.

| # | Issue | Fix | Status |
|---|-------|-----|--------|
| [#235](https://github.com/seanthimons/serapeum/issues/235) | Missing `;` in migration 018 CREATE INDEX | Add semicolon to `migrations/018:16` | [ ] |
| [#165](https://github.com/seanthimons/serapeum/issues/165) | Email not redacted in verbose OA logs | Add `gsub()` for `mailto` in `api_openalex.R` | [ ] |
| [#179](https://github.com/seanthimons/serapeum/issues/179) | `%||%` not defined in `utils_scoring.R` | Add guarded definition or replace with base R | [ ] |
| [#229](https://github.com/seanthimons/serapeum/issues/229) | `p.NA` in `build_context_by_paper()` + `build_slides_prompt()` | Copy `is.na()` guard from `build_context()` | [ ] |
| [#234](https://github.com/seanthimons/serapeum/issues/234) | `log_cost` returns stale ID on INSERT fail | Move `id` return inside tryCatch success path | [ ] |
| [#181](https://github.com/seanthimons/serapeum/issues/181) | XSS-adjacent JS injection in keyword onclick | Use `jsonlite::toJSON()` for JS string escaping | [ ] |
| [#193](https://github.com/seanthimons/serapeum/issues/193) | Weight preset sums exceed 1.0 | Normalize preset values in `utils_scoring.R:70-99` | [ ] |

### Session B: Test Infrastructure (dedicated session)

Fix the test suite so all downstream DB work is verifiable. **Do before Session C.**

| # | Issue | What's Needed | Status |
|---|-------|---------------|--------|
| [#213](https://github.com/seanthimons/serapeum/issues/213) | `test-config.R` path resolution failure | Audit all test files for `getwd()` anti-pattern, switch to `test_path()` | [ ] |
| [#214](https://github.com/seanthimons/serapeum/issues/214) | `test-db.R` schema drift + missing source | Source `pdf_images.R` in test helper, ensure all migrations run | [ ] |

### Session C: Refiner Data Integrity (dedicated session, depends on B)

All Refiner-adjacent — touching similar code paths. Batch to avoid re-reading same files.

| # | Issue | What's Needed | Status |
|---|-------|---------------|--------|
| [#177](https://github.com/seanthimons/serapeum/issues/177) | Double JSON encoding of authors on import | Trace data flow, test double-encoded vs. already-decoded input | [ ] |
| [#185](https://github.com/seanthimons/serapeum/issues/185) | Silent API failure swallowing in Refiner | Decide on UX (warning/notification), test simulated API failure | [ ] |
| [#186](https://github.com/seanthimons/serapeum/issues/186) | Missing ON DELETE CASCADE on refiner tables | New migration, verify DuckDB FK alter support, test cascade | [ ] |

### Session D: Import Badge Reactivity (dedicated session, needs running app)

| # | Issue | What's Needed | Status |
|---|-------|---------------|--------|
| [#154](https://github.com/seanthimons/serapeum/issues/154) | Import badge doesn't update on citation mapping | Trace reactive chain across modules, reproduce in running app, fix observer/invalidation | [ ] |

### Session E: RAG Citation Quality (deepest investigation)

| # | Issue | What's Needed | Status |
|---|-------|---------------|--------|
| [#159](https://github.com/seanthimons/serapeum/issues/159) | Abstract chat doesn't reference papers correctly | Trace full RAG pipeline (retrieval -> context -> prompt -> output), needs real data and prompt iteration | [ ] |

## Key Decisions

- **Session order matters:** B before C (test infra before DB changes), A can go anytime
- **#159 is the riskiest:** may require prompt engineering, not just code fixes
- **#186 needs migration research:** DuckDB FK ALTER may require table recreation
- **#154 needs live testing:** cannot be verified without running the app interactively

## Open Questions

- [ ] Does the `getwd()` anti-pattern in #213 exist in other test files beyond `test-config.R`?
- [ ] Does DuckDB support `ALTER TABLE ADD CONSTRAINT FOREIGN KEY` or do we need table recreation for #186?
- [ ] Is #159 a context-building bug or a prompt instruction gap (or both)?
