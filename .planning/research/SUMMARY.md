# Project Research Summary

**Project:** Serapeum v20.0 — Shiny Reactivity Cleanup
**Domain:** R/Shiny reactive lifecycle correctness — observer leaks, isolate() guards, req() guards, error handling
**Researched:** 2026-03-26
**Confidence:** HIGH

## Executive Summary

This is a correctness fix milestone, not a feature milestone. Serapeum is a 27,000+ LOC, 15-module R/Shiny application with systematic reactive lifecycle bugs: accumulated observers that never get destroyed, missing `isolate()` guards that risk infinite reactive loops, missing `req()` guards that produce cryptic crashes, inconsistent error handling that hides errors from users, and SQL migration code that may fail on fresh installs. None of these require new libraries. Every fix uses primitives already in the codebase (`observe()`, `observeEvent()`, `isolate()`, `req()`, `$destroy()`, `reactiveValues()`).

The recommended approach is surgical, module-by-module correction following patterns that already exist in the codebase. `mod_document_notebook.R` has the correct observer lifecycle pattern (`reactiveValues()` registry + explicit `$destroy()`) and `mod_research_refiner.R` has the correct per-item observer teardown pattern. The work is applying these established patterns consistently to the three modules that diverged: `mod_search_notebook.R`, `mod_slides.R`, and `mod_citation_network.R`. The `mod_query_builder.R` needs two lines of `req()` guards. DB migrations need an idempotency audit.

The primary risk during this milestone is introducing new bugs while fixing old ones. The two highest-risk mistakes are: (1) over-applying `isolate()` to the primary trigger of an observer, which silently kills reactivity with no error surfaced; and (2) placing `req()` guards after side effects, which leaves modals or progress overlays stuck open. Both are prevented by following the specific patterns documented in this research rather than applying fixes mechanically.

---

## Key Findings

### Recommended Stack

No new production dependencies are required. Shiny 1.11.1 (currently installed) provides all needed primitives. The single recommended development tool addition is `reactlog` 1.1.1 — a dev-only diagnostic that visualizes the reactive dependency graph to confirm whether observer accumulation is actually occurring and which reads are creating unintended dependencies. It must never be enabled in production (memory leak, exposes reactive source code).

**Core technologies:**
- **shiny 1.11.1** — `observe()`, `observeEvent()`, `isolate()`, `req()`, `$destroy()`, `reactiveValues()` are all present and correct; the problem is inconsistent application across modules
- **testthat 3.2.3** — `shiny::testServer()` for module-level reactive testing of fixes
- **reactlog 1.1.1** (dev only) — observer dependency graph visualization for audit and post-fix verification; install with `install.packages("reactlog")`, use `reactlog::reactlog_enable()` before `runApp()`, then Ctrl+F3

### Expected Fixes (Feature Landscape)

This milestone has 10 issues across two priority tiers. All 10 should be resolved within the milestone.

**P1 — Fixes that prevent crashes or silent failures:**
- **Issue 1: Chip observer accumulation** (mod_slides.R) — chip observers registered via `lapply(seq_len(10), ...)` accumulate on every heal modal open; destroy before re-registering
- **Issue 2: Missing isolate() on fig_refresh counter reads** (mod_document_notebook.R) — `fig_refresh(fig_refresh() + 1)` inside `observe()` is a self-triggering loop; wrap the read in `isolate()`
- **Issue 3: Missing req() for NULL provider/model** (mod_query_builder.R) — NULL model passed to `provider_chat_completion()` causes cryptic crash; add `req(provider, model)` after resolution
- **Issue 4: Error toast z-index behind synthesis modal** — `showNotification()` renders under the modal backdrop; fix by calling `removeModal()` before `showNotification()` (modal-then-notify pattern)
- **Issue 10: SQL migration on fresh installs** — migration SQL must use `CREATE TABLE IF NOT EXISTS` throughout; audit all 9 migrations for idempotency

**P2 — Quality and consistency improvements:**
- **Issue 5: renderUI re-query reduction** — extract `list_documents()` into a shared `reactive()` so multiple `renderUI` blocks share one DB call per invalidation cycle
- **Issue 6: Figure action observer destruction on re-extraction** — `fig_action_observers[[f_id]] <- NULL` drops the R reference but does not call `$destroy()`; fix to explicitly destroy before clearing
- **Issue 7: Observer lifecycle cleanup in slides/notebook** — same pattern as Issue 6 for the slides module
- **Issue 8: Standardize error handling across presets** — define a single `handle_preset_error(e, session)` helper and apply uniformly across all 7 preset handlers
- **Issue 9: Input validation for match_aa_model() and section_filter** — add `req(openrouter_id)` at top of `match_aa_model()` to guard startup race condition

**Anti-features to avoid:**
- Blanket `isolate()` around entire observer bodies — silently breaks legitimate reactive dependencies
- `onStop(session, ...)` as substitute for mid-session `$destroy()` — does not solve within-session accumulation
- Global `z-index: 9999` override for notifications — destabilizes Catppuccin CSS z-index layering
- Global `list_documents()` cache in app.R — couples module invalidation cycles

**Issue dependencies:**
- Issues 1, 6, 7 share one root cause (observer registration without destroy); fix the pattern once, apply to all three
- Issue 8 resolves Issue 4 as a side effect if "modal-then-notify" is adopted as the standard
- Issue 10 is fully independent of all reactive work

### Architecture Approach

The existing module structure is correct and requires no changes. All fixes are in-place modifications to 6 existing files. The codebase already has the correct patterns in `mod_document_notebook.R` (per-item observer registry with explicit `$destroy()`) and `mod_research_refiner.R` (destroy-before-replace in a seed observer loop). The audit must confirm that correct patterns are exhaustive — that no code paths reach `renderUI` re-execution without passing through the appropriate destroy block.

**Modules requiring changes:**
1. **mod_document_notebook.R** — verify fig_action_observer destroy path is reached by all document-change code paths; audit remaining `fig_refresh()` calls
2. **mod_search_notebook.R** — fix `type_chip_observers` always-overwrite without destroy (line 2457); verify `block_journal_observers` and `unblock_journal_observers` guard exhaustiveness
3. **mod_citation_network.R** — add old-poller destroy before new poller creation; add `isolate()` on secondary reactive writes in network task result handler
4. **mod_slides.R** — add `isolate()` on `current_chips()` reads inside chip click handlers; verify `generation_state` writes use `isolate()`
5. **mod_query_builder.R** — add `req(provider, model)` after resolution in `observeEvent(input$generate_btn)`
6. **db_migrations.R + migrations/*.sql** — audit fresh-install bootstrap; ensure all migration SQL is idempotent; also fix `_ragnar.R` connection leak on `ensure_ragnar_store()` error path

### Critical Pitfalls

1. **isolate() over-application kills reactivity silently** — wrapping the primary trigger in `isolate()` makes the observer dead; rule is "isolate the reads, not the trigger." Warning sign: observer fires once on startup but never again after user action.

2. **observe() + read/write same reactiveVal = infinite loop** — this is the documented v3.0 incident (`doc_refresh(doc_refresh() + 1)` without isolate). Adding new counter increments during cleanup without `isolate()` will re-introduce it. Warning sign: CPU spikes to 100%, toast appears repeatedly.

3. **req() after side effects leaves state corrupted** — `req()` is a silent abort; any `showModal()`, `withProgress()`, or reactiveVal mutation before the `req()` call executes and persists. All `req()` guards must appear at the top of the observer body before any side effects.

4. **Poller not destroyed on all exit paths** — the happy path destroys the poller; error and re-invoke paths often do not. After N task cycles without proper cleanup, N pollers run simultaneously reading files that may no longer exist.

5. **Destroying observers from within their own execution context** — calling `$destroy()` or setting the registry entry to NULL from inside the observer's own body can cause one additional fire after destroy. Destroy from the parent context, or use `once = TRUE` for genuinely single-fire cases.

---

## Implications for Roadmap

Based on combined research, a 4-phase structure is recommended. Phase ordering is driven by regression risk, dependency between fixes, and the build order documented in ARCHITECTURE.md.

### Phase 1: Additive Guards (Pure Safety, Zero Regression Risk)

**Rationale:** These are additive-only changes — they add defensive guards without modifying any existing control flow. Lowest risk, fastest to validate. Building confidence before touching reactive lifecycle code.

**Delivers:** NULL crash prevention in query builder; explicit intent declaration in slides chip handlers.

**Addresses:** Issue 3 (req() for NULL provider/model), Issue 1 partial (isolate() on current_chips() in slides).

**Avoids:** Pitfall — req() after side effects: guards are placed at observer top before any side effects in these files.

### Phase 2: Observer Lifecycle Fixes (Targeted, Moderate Risk)

**Rationale:** The three accumulation bugs (Issues 1, 6, 7) share a root cause. Fixing them together prevents cross-contamination analysis. The citation network poller fix is simplest to verify (trigger two builds, confirm one poller fires). Sequence: mod_citation_network.R first for confidence, then document notebook, then search notebook.

**Delivers:** Elimination of observer accumulation across all affected modules; correct fig_action_observer destroy path; type_chip_observers registration fix.

**Addresses:** Issues 1, 6, 7 (observer accumulation); Issue 2 (fig_refresh isolate() audit).

**Avoids:** Pitfall — dynamic observer accumulation without destroy; Pitfall — destroying observers from within their own context (destroy from parent, not from self).

### Phase 3: Infrastructure Fixes (Isolated from Reactive Work)

**Rationale:** DB migration audit and ragnar connection leak are independent of all reactive patterns. Running them after Phase 2 means reactive fixes are stable before touching startup and async infrastructure. Full test suite run after this phase.

**Delivers:** Fresh install reliability; no orphaned DuckDB connections on ragnar setup failure.

**Addresses:** Issue 10 (SQL migration fresh install); ragnar connection leak in `_ragnar.R`.

**Avoids:** Pitfall — poller not destroyed on all exit paths: the ragnar fix template mirrors the poller cleanup pattern — explicit disconnect on all error paths.

### Phase 4: Error Handling and Polish (Cross-Cutting)

**Rationale:** Error handling standardization (Issue 8) resolves the toast z-index bug (Issue 4) as a side effect via the modal-then-notify pattern, making Issue 4 a natural consequence rather than a separate CSS fix. Performance improvement (Issue 5) and remaining input validation (Issue 9) belong here as non-correctness improvements.

**Delivers:** Consistent user-visible error feedback across all preset handlers; reduced DB query load during async processing; defensive input validation.

**Addresses:** Issues 4, 5, 8, 9 (error handling, renderUI re-query, toast z-index, input validation).

**Avoids:** Pitfall — isolate() over-application: the modal-then-notify pattern in Issue 4/8 does not involve any reactive dependency changes.

### Phase Ordering Rationale

- Phase 1 before Phase 2 because additive guards catch the NULL crashes that would otherwise surface during Phase 2 reactive testing.
- Phase 3 is fully isolated — it could run in parallel with Phase 2, but sequencing after Phase 2 means two separate smoke test surfaces rather than one combined one, reducing debugging ambiguity.
- Phase 4 last because Issue 8 (error handling standardization) is cross-cutting across multiple modules; doing it after all structural fixes are stable prevents merge conflicts and allows the standardized pattern to incorporate lessons from Phase 2 fixes.

### Research Flags

Phases with well-documented patterns (skip research-phase):
- **Phase 1:** Standard `req()` and `isolate()` patterns verified in Mastering Shiny Chapter 15 and Shiny official reference; no open questions.
- **Phase 2:** Observer lifecycle patterns are established in codebase; `mod_document_notebook.R` and `mod_research_refiner.R` are the authoritative templates.
- **Phase 4:** Modal-then-notify error handling pattern is documented in FEATURES.md Pattern D with working code.

Phases that benefit from targeted investigation before planning:
- **Phase 3 (migrations):** Fresh-install bootstrap ordering needs a hands-on read of all 9 migration SQL files and `init_schema()` to identify any table conflicts. Low risk if all migrations already use `CREATE TABLE IF NOT EXISTS`, but this needs verification rather than assumption.
- **Phase 3 (ragnar):** The `ensure_ragnar_store()` error path and S7 object serialization behavior may have edge cases not covered by existing tests. Recommend reproducing the error path with an intentionally broken embed function before writing the fix.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies; all primitives verified in Shiny 1.11.1 official docs and CRAN NEWS |
| Features | HIGH | All 10 issues mapped to specific code locations with exact line numbers from direct codebase inspection |
| Architecture | HIGH | Based on direct code inspection of all 6 affected modules; patterns cross-referenced with CLAUDE.md project docs |
| Pitfalls | HIGH | Grounded in documented prior incidents (v3.0 UAT), Mastering Shiny, Appsilon production engineering blog, and GitHub issue thread |

**Overall confidence:** HIGH

### Gaps to Address

- **Migration idempotency:** Research identified the risk but not whether the problem actually exists. The 9 migration SQL files have not been read in this research pass. Phase 3 planning should begin with a read of each migration file to confirm `CREATE TABLE IF NOT EXISTS` usage before writing any code.

- **mod_search_notebook.R type_chip_observers exact context:** Architecture research identifies line 2457 as an always-overwrite pattern without destroy. The exact observer creation context (inside `observe()` or `renderUI()`) needs confirmation during Phase 2 planning to determine whether the fix is a guard, a destroy-before-replace, or both.

- **reactlog diagnostic results:** The actual reactive dependency graph has not been visualized. The research describes expected behavior based on code reading. Installing `reactlog` and running it in dev mode would confirm whether the identified accumulation bugs are active and reveal any additional undiagnosed ones.

---

## Sources

### Primary (HIGH confidence)
- Shiny 1.11.1 CRAN NEWS — https://cran.r-project.org/web/packages/shiny/news/news.html
- Mastering Shiny Ch.15 Reactive building blocks — https://mastering-shiny.org/reactivity-objects.html
- Shiny Official Reference — observeEvent, isolate(), req(), ExtendedTask — https://shiny.posit.co/r/reference/shiny/latest/
- reactlog CRAN and docs — https://rstudio.github.io/reactlog/
- Serapeum source code — `R/mod_document_notebook.R`, `R/mod_slides.R`, `R/mod_search_notebook.R`, `R/mod_citation_network.R`, `R/mod_query_builder.R`, `R/db_migrations.R`, `R/_ragnar.R`
- CLAUDE.md project instructions — documented prior infinite loop incident and established `isolate()` pattern

### Secondary (MEDIUM confidence)
- Appsilon — How to Safely Remove a Dynamic Shiny Module — https://www.appsilon.com/post/how-to-safely-remove-a-dynamic-shiny-module
- Engineering Production-Grade Shiny Apps Ch.15 — https://engineering-shiny.org/common-app-caveats.html
- Kyle Husmann: A Shiny Puzzle — Dynamic Observers (2025) — https://www.kylehusmann.com/posts/2025/shiny-dynamic-observers/

### Tertiary (context only)
- GitHub: observeEvent stays registered after destroy() — https://github.com/rstudio/shiny/issues/1486

---
*Research completed: 2026-03-26*
*Ready for roadmap: yes*
