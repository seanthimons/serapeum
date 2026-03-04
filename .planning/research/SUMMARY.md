# Project Research Summary

**Project:** Serapeum v10.0 Theme Harmonization & AI Synthesis
**Domain:** R/Shiny Research Assistant UI Design System + AI Synthesis Presets
**Researched:** 2026-03-04
**Confidence:** HIGH

## Executive Summary

This milestone extends Serapeum's existing R/Shiny research assistant with a global design system policy and two new AI synthesis presets (Methodology Extractor, Gap Analysis Report). The research reveals **excellent architectural alignment** — all features integrate cleanly with existing patterns. Theme policy extends the established Catppuccin system, new presets reuse section-targeted RAG from v2.1, and critical bugs are self-contained fixes to existing modules. No new dependencies required, no architectural changes needed.

The recommended approach is **foundation-first, bugs-second, features-third**: establish design system policy before touching any UI code, fix citation audit race conditions before increasing rendering load, then build on this stable foundation with new presets. This ordering prevents CSS specificity wars (pitfall #1), connection leak amplification (pitfall #8), and module theme desynchronization (pitfall #3).

Key risks center on **consistency and brittleness**: icon library fragmentation across 18 modules, section-targeted RAG keyword heuristics failing on non-standard papers, and prompt template coupling as preset count grows from 5 to 7. All are preventable with proper phasing: audit icons before harmonizing buttons, test retrieval on diverse paper types before writing preset prompts, and refactor shared prompt components before adding new presets.

## Key Findings

### Recommended Stack

**No new dependencies required.** All v10.0 features can be implemented with the existing stack (bslib 0.9.0, pdftools 3.6.0, bsicons 0.1.2, ragnar). The milestone extends current capabilities rather than adding new ones.

**Core technologies (unchanged):**
- **bslib 0.9.0** — Bootstrap 5 theming with Catppuccin palette; `bs_add_variables()` handles semantic color mapping for design system
- **bsicons 0.1.2** — Bootstrap-native icon library with 2000+ icons; already used for citation audit, extend to all modules for consistency
- **pdftools 3.6.0** — PDF text extraction; methods sections already extracted, methodology preset reuses existing chunks
- **ragnar** — Section-aware chunking with `detect_section_hint()`; recognizes "methods", "limitations", "discussion" sections for targeted retrieval

**Optional upgrades (not required):**
- bslib 0.10.0 (latest) deferred to v11.0 — current version sufficient for theme variables, upgrade during active milestone risky
- pdftools 3.7.0 (latest) deferred — no new API, methodology extraction uses same `pdf_text()` function

**What NOT to add:**
- sass package standalone — already bundled with bslib
- tabulizer/tesseract — methods text already extracted by pdftools, no OCR needed
- fontawesome as alternative — stick to bsicons for consistency, avoid library fragmentation

### Expected Features

**Must have (table stakes):**
- **Consistent button semantics** — primary (main action), secondary (alternative), danger (destructive) with uniform colors/meanings across app
- **Dark mode compatibility** — all UI elements readable in both Catppuccin Latte/Mocha without manual switching
- **AI output disclaimers** — warnings when content is AI-generated (research integrity, already in v2.1)
- **Structured output format** — research synthesis as tables/lists, not prose walls (validated in Literature Review Table v4.0)

**Should have (competitive differentiators):**
- **Methodology Extractor preset** — auto-extract methods sections using PICO/IMRAD framework, section-targeted RAG, structured output
- **Gap Analysis Report preset** — cross-paper synthesis using PICOS framework to identify under-researched areas, conflicting findings, methodological gaps
- **Design token system** — single source of truth for colors/spacing/icons documented as policy (not just scattered CSS)
- **Preset icon system** — consistent icons per preset type (already implemented for Overview, Research Questions, Literature Review; extend to new presets)

**Defer (v2+ / anti-features):**
- Custom color themes (breaks accessibility, maintenance burden)
- Per-preset color customization (conflicts with semantic color meaning)
- Global "Regenerate All" button (expensive, slow, unclear UX)
- Gap analysis on single paper (gaps are comparative, require 3-5+ papers)
- Live theme preview in settings (adds complexity, fixed palette means preview unnecessary)

### Architecture Approach

All new features integrate with existing patterns through pure extension — no architectural changes required. Theme policy extends `R/theme_catppuccin.R` with documentation. Presets extend `R/rag.R` by cloning `generate_conclusions_preset()` architecture. Citation audit fixes touch `R/mod_citation_audit.R` and `R/mod_search_notebook.R` with defensive SQL and reactive invalidation. Build order: design policy (foundation) → bug fixes (critical path) → sidebar/button theming (apply policy) → methodology preset → gap analysis preset.

**Major components (modified/new):**
1. **R/theme_catppuccin.R** — ADD semantic action color policy documentation (e.g., danger=destructive, primary=main action)
2. **R/rag.R** — ADD `generate_methodology_preset()` and `generate_gap_analysis_preset()` using section-targeted RAG with three-level fallback
3. **R/mod_citation_audit.R** — FIX multi-paper import error (#134) with defensive SQL/error handling
4. **R/mod_search_notebook.R** — FIX abstract refresh reactive (#133), apply button theming (#137, #139), add preset buttons
5. **R/mod_document_notebook.R** — ADD methodology + gap analysis preset buttons following existing pattern
6. **app.R** — APPLY design policy to sidebar buttons (#137)

**Key patterns leveraged:**
- **Shiny module pattern** — 14 production modules with namespace isolation, reactive communication
- **Preset function pattern** — RAG retrieval → prompt building → LLM call → cost logging (established in v2.1)
- **Section-targeted RAG** — `detect_section_hint()` + `search_chunks_hybrid(section_filter)` with three-level fallback (graceful degradation)
- **Theme system** — Catppuccin LATTE/MOCHA via `bs_theme()` + `bs_add_rules()`, applied in app.R

### Critical Pitfalls

1. **CSS Specificity Wars** — Custom design system rules fail to override Bootstrap, developers use `!important` repeatedly creating cascade hell. **Prevention:** Use `bs_add_variables()` for Sass variables BEFORE compilation, leverage Bootstrap semantic classes (`bg-body-secondary`), document specificity hierarchy, audit existing `!important` usage before adding more.

2. **Icon Library Fragmentation** — Mixed fontawesome/bsicons usage across 18 modules with inconsistent semantic naming. **Prevention:** Choose bsicons as primary library, create `R/icons.R` with semantic wrappers (`icon_save()`, `icon_download()`), audit all existing icon calls, document nav_panel integration issue (bsicons requires `tags$i()` wrapper).

3. **Module Theme State Desynchronization** — Design system applied to some modules but not others causes "half-migrated" UI, saved content uses old theme. **Prevention:** Audit modules for cached UI elements, test theme consistency after design system → reload saved network → toggle dark mode, document components that can't react to runtime theme changes.

4. **Section-Targeted RAG Brittleness** — Keyword heuristics fail on non-standard papers (preprints, reviews, non-IMRAD structure), presets return wrong sections. **Prevention:** Expand keyword dictionaries for methodology/future work, implement multi-tier fallback (section-filtered → keyword-boosted → direct vector search), test on diverse paper types (journal, preprint, conference), add retrieval diagnostics.

5. **Prompt Template Coupling** — Duplicated prompt components across 7 presets scale O(n) maintenance cost, inconsistencies accumulate. **Prevention:** Extract shared components to reusable functions (`prompt_header()`, `prompt_rag_context()`, `prompt_citation_format()`), presets compose task instructions + shared components, version prompt components, test matrix for format compliance.

6. **Citation Audit Race Conditions** — Concurrent multi-paper imports cause foreign key violations, lost writes, duplicate entries. **Prevention:** Batch citation audits in single mirai task, use DuckDB transactions with SERIALIZABLE isolation, implement retry logic with exponential backoff, fix connection leaks (#117, #119) before adding citation audit fixes.

7. **Dark Mode Collision** — Browser `prefers-color-scheme` media queries compete with app `input_dark_mode()` toggle, some components ignore toggle. **Prevention:** Replace `@media (prefers-color-scheme: dark)` with class-based targeting, set explicit default mode independent of OS preference, add localStorage persistence for user preference.

8. **Connection Leak Amplification** — Design system rendering load triggers existing connection leaks in `search_chunks_hybrid()` and ragnar stores, database exhausts. **Prevention:** FIX connection leaks (#117, #119) in Phase 0 before any design system work, audit all `dbConnect()` calls for paired `on.exit(dbDisconnect())`, add leak detection tests to CI.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 0: Tech Debt Cleanup (BLOCKER)
**Rationale:** Connection leaks (#117, #119) amplify under design system rendering load. Fix before increasing load prevents database exhaustion, app crashes, emergency hotfixes.
**Delivers:** All database connections properly closed with `on.exit()`, leak detection test in CI, stable foundation for design system work.
**Addresses:** Pitfall #8 (connection leak amplification), prevents pitfall #6 (citation audit race conditions) from compounding.
**Avoids:** App performance degradation, database locks, memory usage climbing.

### Phase 1: Design System Foundation
**Rationale:** Policy document defines semantics before touching any UI code. Prevents CSS specificity wars, icon fragmentation, inconsistent implementations across 18 modules.
**Delivers:** Semantic action color policy in `R/theme_catppuccin.R`, icon library audit + semantic wrapper functions in `R/icons.R`, CSS specificity hierarchy documentation.
**Addresses:** Features — design token system (differentiator); Pitfalls #1 (CSS specificity), #2 (icon fragmentation).
**Avoids:** Developers making inconsistent choices, Bootstrap override cascade hell, mixing icon libraries.

### Phase 2: Citation Audit Bug Fixes
**Rationale:** Critical blockers (#134, #133) before new features. Race conditions must be fixed before increasing complexity.
**Delivers:** Multi-paper import works without errors, papers appear immediately in abstract notebook after import, defensive SQL + reactive invalidation.
**Addresses:** GitHub issues #134, #133; Pitfall #6 (citation audit race conditions).
**Avoids:** Database corruption, lost writes, user workflow blocked.

### Phase 3: Sidebar & Button Theming
**Rationale:** Policy defined (Phase 1), bugs fixed (Phase 2), now harmonize UI. Apply design system atomically across all modules to avoid "half-migrated" appearance.
**Delivers:** All buttons follow semantic policy, sidebar icons consistent, WCAG AA contrast in both themes, dark mode toggle works across all components.
**Addresses:** Features — consistent button semantics, dark mode compatibility; Issues #137, #139; Pitfall #3 (module theme desync), #7 (dark mode collision).
**Avoids:** Users seeing inconsistent UI, accessibility violations, theme toggle ignored by some components.

### Phase 4: AI Preset Foundation Refactor
**Rationale:** Extract shared prompt components BEFORE adding new presets. Prevents prompt template coupling as preset count grows from 5 to 7.
**Delivers:** Reusable prompt component functions (`prompt_header()`, `prompt_rag_context()`, `prompt_citation_format()`), existing 5 presets refactored to use components, test matrix for format compliance.
**Addresses:** Pitfall #5 (prompt template coupling), prepares for methodology + gap analysis presets.
**Avoids:** Maintenance cost scaling O(n) with presets, inconsistent citation formats, bug fixes requiring 7-file edits.

### Phase 5: Methodology Extractor Preset
**Rationale:** Easier preset first (factual extraction, lower hallucination risk). Validates section-targeted RAG pattern reuse on new section type (methods vs conclusions).
**Delivers:** `generate_methodology_preset()` in R/rag.R with PICO/IMRAD structured output, section filter for methods/introduction/results, buttons in document + search notebooks, AI disclaimer banner.
**Addresses:** Features — methodology extractor (differentiator); Pitfall #4 (section RAG brittleness) with expanded keyword dictionary + multi-tier fallback.
**Avoids:** RAG retrieval failures on non-standard papers, preset returning abstract instead of methods.

### Phase 6: Gap Analysis Report Preset
**Rationale:** More complex preset last (inferential, higher hallucination risk). Build after simpler methodology preset validates retrieval pattern.
**Delivers:** `generate_gap_analysis_preset()` in R/rag.R with PICOS framework for cross-paper synthesis, section filter for limitations/future work/discussion, minimum 3-paper validation, AI disclaimer.
**Addresses:** Features — gap analysis (unique differentiator); Issue #101; Pitfall #4 (section RAG brittleness) on future work/limitations sections.
**Avoids:** Hallucinated gaps not supported by sources, single-paper "gap analysis" confusion.

### Phase Ordering Rationale

**Critical path dependencies:**
1. **Phase 0 → all other phases** — Connection leaks must be fixed before increasing rendering load
2. **Phase 1 → Phase 3** — Design policy informs button/sidebar theming implementation
3. **Phase 4 → Phases 5, 6** — Shared prompt components prevent preset coupling
4. **Phase 5 → Phase 6** — Simpler preset validates retrieval pattern before complex preset

**Parallelizable work:**
- Phase 2 (citation audit bugs) can run parallel to Phase 1 (design policy writing) — independent concerns
- Phases 5, 6 (presets) independent of citation audit (Phase 2) — different modules

**Why this ordering avoids pitfalls:**
- Foundation-first (Phase 1) prevents specificity wars (#1) and icon fragmentation (#2)
- Bugs-second (Phase 2) prevents race conditions (#6) from blocking user workflow
- Refactor-before-extend (Phase 4 before 5, 6) prevents prompt coupling (#5)
- Simple-before-complex (Phase 5 before 6) validates RAG brittleness fixes (#4) on easier use case
- Tech debt cleanup (Phase 0) before load increase prevents leak amplification (#8)

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 0:** Tech debt cleanup — known connection leak locations, standard `on.exit()` pattern
- **Phase 1:** Design system foundation — Bootstrap 5 documentation authoritative, Catppuccin palette already validated
- **Phase 2:** Citation audit bugs — debugging task, not research task
- **Phase 3:** Sidebar/button theming — applies documented policy, bslib semantic classes well-documented
- **Phase 4:** Preset refactor — code reorganization, not new functionality
- **Phase 5, 6:** AI presets — reuse section-targeted RAG pattern from v2.1, PICO/PICOS frameworks documented in systematic review literature

**Phases needing validation (not deep research, but testing):**
- **Phase 4:** Test section-targeted RAG on diverse paper corpus (journal, preprint, conference, review) to validate keyword expansion
- **Phase 5, 6:** Test prompt engineering on real papers to verify structured output quality

**Overall:** No phases require `/gsd:research-phase`. All patterns established in prior milestones (v2.1 section RAG, v4.0 structured output, v6.0 Catppuccin theming, v7.0 mirai async). This is **execution-focused milestone**, not discovery-focused.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new dependencies, bslib/pdftools/bsicons versions verified from CRAN PDFs (Jan-Feb 2026), all patterns tested in v1.0-v9.0 |
| Features | MEDIUM-HIGH | Bootstrap/bslib docs authoritative (HIGH), AI tool feature landscape from web search (MEDIUM), gap analysis methodology from systematic review literature (HIGH) |
| Architecture | HIGH | Existing codebase (~20,000 LOC) analyzed, all integration points verified in app.R/R/rag.R/R/mod_*.R, pure extension pattern confirmed |
| Pitfalls | HIGH | Pitfalls sourced from official docs (MDN CSS specificity, bslib dark mode, Bootstrap overrides), arXiv RAG research papers, project tech debt (#117, #118, #119), milestone decision logs |

**Overall confidence:** HIGH

Research converges on clear recommendations with minimal uncertainty. Stack requires no changes, architecture is pure extension, pitfalls are well-documented with prevention strategies. Only uncertainty is MEDIUM on AI tool competitive feature landscape (web search coverage incomplete), but this doesn't affect technical implementation — design system and presets are based on validated patterns regardless of competitor features.

### Gaps to Address

**Gap: Section-targeted RAG recall on non-standard papers**
- Research shows keyword heuristics are brittle, error rates increase ~1% per 5 documents
- **Mitigation:** Test methodology/gap presets on diverse paper corpus during Phase 4-5, expand keyword dictionaries iteratively, document retrieval diagnostics in preset disclaimers
- **Future enhancement:** ML-based section classifier (out of scope for v10.0, but document as known limitation with workaround)

**Gap: Citation audit race condition root cause**
- Issue #134 lacks error message details, can't confirm if foreign key violation or other concurrency issue
- **Mitigation:** Reproduce locally in Phase 2, add integration test for concurrent writes, implement transactions + retry logic regardless of specific error type

**Gap: Prompt template component boundary**
- Research shows prompt coupling is common mistake, but which components to extract requires codebase-specific judgment
- **Mitigation:** Start with obvious duplicates (instruction-data separation, RAG citation format, safety constraints), iterate based on actual preset diff analysis in Phase 4

**Gap: Icon coverage between bsicons (2000+) vs fontawesome (16,000+)**
- bsicons recommended for consistency, but may lack specific icons needed
- **Mitigation:** Audit current icon usage (grep for `fa()` and `bs_icon()`), map to bsicons equivalents, document fontawesome as fallback ONLY when bsicons lacks required icon, handle nav_panel integration issue (bsicons requires `tags$i()` wrapper)

**Gap: Theme persistence across sessions**
- Dark mode toggle doesn't persist to localStorage, users re-toggle every session
- **Mitigation:** Add in Phase 3 sidebar theming: `observeEvent(input$dark_mode, { # store in localStorage or DB })`, restore on session start

## Sources

### Primary (HIGH confidence)
- **Existing codebase** — app.R (sidebar, theme), R/theme_catppuccin.R (Catppuccin palette), R/rag.R (preset functions), R/db.R (section-targeted RAG), R/pdf.R (section detection), R/mod_*.R (18 modules)
- **bslib documentation** — [Theming guide](https://rstudio.github.io/bslib/articles/theming/index.html), [Sass variables](https://rstudio.github.io/bslib/reference/bs_bundle.html), [Dark mode input](https://rstudio.github.io/bslib/reference/input_dark_mode.html), [Sidebars](https://rstudio.github.io/bslib/articles/sidebars/index.html)
- **Bootstrap 5 documentation** — [Buttons](https://getbootstrap.com/docs/5.3/components/buttons/), [Color modes](https://getbootstrap.com/docs/5.3/customize/color-modes/)
- **CRAN package PDFs** — bslib 0.10.0 (Jan 2026), pdftools 3.7.0 (Jan 2026), bsicons 0.1.2 (Jul 2025)
- **ragnar documentation** — [Semantic chunking](https://ragnar.tidyverse.org/articles/ragnar.html)
- **Project context** — .planning/PROJECT.md (decision log v1.0-v9.0), GitHub issues #133, #134, #137, #138, #139, #100, #101

### Secondary (MEDIUM confidence)
- **RAG pitfalls** — [Seven Failure Points When Engineering a RAG System (arXiv)](https://arxiv.org/pdf/2401.05856) — keyword brittleness, error rates scaling with document count
- **Prompt engineering** — [Prompt Engineering for RAG Pipelines (StackAI)](https://www.stackai.com/blog/prompt-engineering-for-rag-pipelines-the-complete-guide-to-prompt-engineering-for-retrieval-augmented-generation), [10 Common LLM Prompt Mistakes (GoInsight.ai)](https://www.goinsight.ai/blog/llm-prompt-mistake/) — prompt template coupling anti-pattern
- **CSS specificity** — [MDN: CSS Specificity](https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity), [How To Override Bootstrap 5 CSS (ThemeSelection)](https://themeselection.com/override-bootstrap-css-styles/)
- **Dark mode** — [Dark Mode Toggle and prefers-color-scheme (DEV Community)](https://dev.to/abbeyperini/dark-mode-toggle-and-prefers-color-scheme-4f3m), [prefers-color-scheme browser vs OS (Sara Soueidan)](https://www.sarasoueidan.com/blog/prefers-color-scheme-browser-vs-os/)
- **Icon systems** — [Iconography In Design Systems (Smashing Magazine)](https://www.smashingmagazine.com/2024/04/iconography-design-systems-troubleshooting-maintenance/), [bsicons GitHub Issue #639](https://github.com/rstudio/bslib/issues/639) (nav_panel integration)
- **Citation errors** — [Citation Errors in Scientific Research (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10307651/) — ~20% citations contain errors, automated tools prone to matching errors
- **Systematic review methodology** — [Framework for Determining Research Gaps (NCBI)](https://www.ncbi.nlm.nih.gov/books/NBK126702/), [IMRAD Structure Classification (Semantic Scholar)](https://www.semanticscholar.org/paper/Discovering-IMRaD-Structure-with-Different-Ribeiro-Yao/be2ef84f950edf665924cbb7d24545eeb319dffd) — PICO/PICOS frameworks, 81% accuracy for IMRAD classification

### Tertiary (LOW confidence)
- **AI research tool competitors** — [Elicit](https://elicit.com/), [Paperguide](https://paperguide.ai/), [11 Best AI Tools for Scientific Literature Review (Cypris)](https://www.cypris.ai/insights/11-best-ai-tools-for-scientific-literature-review-in-2026) — feature landscape (methodology extraction table stakes, gap analysis differentiator), needs validation
- **Design system patterns** — [Design Patterns For AI Interfaces (Smashing Magazine)](https://www.smashingmagazine.com/2025/07/design-patterns-ai-interfaces/) — general patterns, not R/Shiny-specific
- **DuckDB concurrency** — [DuckDB Memory Behavior Issue #464](https://github.com/duckdb/duckdb/issues/464), [Garbage-collected warning (GitHub Issue #34)](https://github.com/duckdb/duckdb-r/issues/34) — connection leak symptoms, transaction behavior inferred

---
*Research completed: 2026-03-04*
*Ready for roadmap: yes*
