# Project Research Summary

**Project:** Serapeum v7.0 — Citation Audit + Bulk Import + Prompt Healing
**Domain:** Academic research assistant (R/Shiny) with citation analysis and literature management
**Researched:** 2026-02-25
**Confidence:** HIGH

## Executive Summary

Serapeum v7.0 adds citation audit and bulk import capabilities to an existing R/Shiny research assistant. The research reveals a clear technical path: leverage existing DuckDB infrastructure for citation frequency analysis, use OpenAlex API batch endpoints for efficient bulk lookups, and adopt established BibTeX parsing libraries (bib2df) for interoperability with reference managers. All features integrate cleanly with the current Shiny module architecture and async patterns—no new infrastructure required.

The recommended approach prioritizes foundational utilities first (DOI parsing, batch API operations), then builds user-facing features on that foundation (bulk import UI, citation audit, BibTeX support). This order mitigates the highest risk: OpenAlex rate limiting during bulk operations. Research shows that naive sequential API calls fail catastrophically at 20+ DOIs due to rate limits—batching 50 DOIs per request with proper delays is non-negotiable. The second major risk is BibTeX parsing fragility with real-world files, addressed by using tolerant parsers with per-entry error handling.

Citation gap detection emerges as a key differentiator—most competitors (Connected Papers, Scite) show what you have, but identifying frequently-cited papers missing from your collection provides unique research insight. Combined with local-first analysis (no cloud upload required), Serapeum occupies a distinct position in the literature management landscape.

## Key Findings

### Recommended Stack

The v7.0 features require only one new dependency: **bib2df** for BibTeX parsing. All other functionality leverages existing packages (readr for CSV parsing, httr2 for API calls, DuckDB for citation aggregation). This minimal stack addition reduces integration risk and maintains the project's lightweight philosophy.

**Core technologies:**
- **bib2df 1.1.2.0**: Parse BibTeX to tibbles — rOpenSci package with clean API, handles malformed entries gracefully, direct DOI extraction
- **readr 2.2.0** (existing): CSV/text parsing for DOI lists — 10-100x faster than base R, already in tidyverse dependencies
- **httr2** (existing): OpenAlex batch requests — supports pipe-separated filter syntax for 50 DOIs per request
- **DuckDB** (existing): Citation frequency aggregation — `UNNEST()` + `GROUP BY` for single-query analysis, 10-100x faster than R loops

**What NOT to add:**
- **RefManageR**: Heavyweight bibliography manager—overkill for simple DOI extraction
- **Base R read.csv()**: 10-100x slower than readr on large files
- **bibtex package**: Lower-level parser requiring manual data frame conversion

### Expected Features

Research identified a clear MVP (v7.0) vs deferred features (v7.x+) split. The MVP focuses on core citation audit workflow and bulk import table stakes. Advanced features like prompt healing and network seeding are validated as valuable but non-blocking for launch.

**Must have (table stakes for v7.0):**
- **Citation frequency analysis** — Count references across papers to identify seminal works (standard methodology in systematic reviews)
- **Citation gap detection** — Show frequently-cited papers missing from collection (differentiator vs competitors)
- **Bulk DOI import** — Paste/upload DOI lists for batch import (expected by all modern reference managers)
- **BibTeX file upload** — Universal interchange format for library migration and tool integration
- **Select-all batch operations** — Standard UI pattern for efficient multi-paper workflows

**Should have (competitive advantage, v7.x):**
- **Prompt healing for slides** — Auto-detect and correct malformed LLM-generated YAML (quality-of-life improvement)
- **BibTeX for network seeding** — Novel workflow using .bib files to seed citation network exploration
- **Export citation gaps as BibTeX** — Convenience feature for importing gaps into other tools

**Defer (v8+ — requires significant infrastructure):**
- **Multi-level backward citation mining** (depth=2+) — Advanced discovery requiring API quota management
- **Citation context analysis** — Classify HOW papers cite each other (supporting/contrasting) like Scite—requires full-text PDF analysis
- **Temporal citation trends** — Distinguish recent relevance from historical importance
- **Journal impact weighting** — Weight citation frequency by source journal quality

### Architecture Approach

All v7.0 features integrate with existing patterns—Shiny modules, DuckDB schema, async ExtendedTask for long operations. The architecture research validated that no schema changes are needed: the `referenced_works` column (added in v2.0) already stores citation data as JSON arrays. The key architectural insight is reusing the producer-consumer discovery pattern (search → preview → import) for all bulk import workflows.

**Major components:**
1. **Citation Audit Module** (new: `R/citation_audit.R`) — Analyze `referenced_works` column with DuckDB `UNNEST()`, batch fetch missing papers from OpenAlex, present ranked import UI
2. **Bulk Import Utilities** (new: `R/utils_doi.R`, `R/utils_bibtex.R`) — Parse DOI lists and BibTeX files, normalize formats, extract DOIs for batch lookup
3. **Batch API Operations** (modified: `R/api_openalex.R`) — Add `batch_fetch_works_by_doi()` using pipe-separated filter syntax (50 DOIs per request) with rate limiting
4. **Select-All UI Pattern** (modified: `R/mod_search_notebook.R`) — Checkbox for bulk selection, reactive selection state, batch import with progress indicator
5. **Slide Healing Workflow** (modified: `R/slides.R`, `R/mod_slides.R`) — Pre-inject YAML template in prompts, add regeneration UI with healing instructions

**Integration patterns to reuse:**
- **ExtendedTask + mirai** for async batch operations (>5 seconds) with progress updates and cancellation
- **Modal-driven workflows** for multi-step operations (input → validate → confirm → execute)
- **JSON column analysis** with DuckDB aggregation functions for citation frequency counting

### Critical Pitfalls

Research uncovered six critical pitfalls, with OpenAlex rate limiting being the highest risk. The pitfalls map directly to specific phases, enabling targeted prevention during implementation.

1. **OpenAlex Rate Limit Cascade Failure** — Bulk imports trigger rapid-fire requests hitting 100 req/sec limit or $1/day budget, causing 429 errors that block all operations. **Prevention:** Batch 50 DOIs per request using pipe-separated filter syntax, add 0.1-0.2s delays between batches, implement exponential backoff on 429 errors.

2. **BibTeX Parsing Malformed Entry Silent Failure** — Real-world .bib files from Zotero/Mendeley contain malformed entries (nested braces, unescaped characters) that crash parsers or silently skip without notification. **Prevention:** Use tolerant parsers (rbibutils or bib2df), implement per-entry try-catch, show parse diagnostics ("Parsed 42/50 entries. 8 failed"), extract DOIs via regex fallback.

3. **Citation Audit SQL N+1 Query Explosion** — Naive loop over abstracts to count references takes 30+ seconds with 500 papers, locks UI, times out at 5000 papers. **Prevention:** Single SQL query with `UNNEST(referenced_works) ... GROUP BY` aggregation, materialize top-N only (limit 20-50), cache results in session variable.

4. **LLM Prompt Healing Infinite Loop on YAML Validation** — Generic "fix this YAML" prompts create retry loops with smaller models, burning tokens and time without fixing errors. **Prevention:** Validate YAML programmatically first with `yaml::yaml.load()`, provide specific error feedback ("missing colon at line 3"), limit to 2 retries maximum, fall back to template YAML with only title customized.

5. **Select-All Import Memory Explosion with Large Result Sets** — Importing 500 abstracts serializes 3-5MB data through reactive values, crashes with memory allocation errors or Shiny disconnects. **Prevention:** Batch size warning if >100 papers, paginated transfer via DuckDB temp table (not reactive serialization), exclude `referenced_works` column from transfer, add progress indicator with ExtendedTask.

6. **BibTeX Import Referenced_Works Data Loss During OpenAlex Enrichment** — Naive pattern overwrites .bib metadata with NULL when OpenAlex lookup fails for preprints/gray literature, losing author/title from original file. **Prevention:** Merge metadata (coalesce pattern: `openalex$title %||% bib$title`), mark enrichment status, show stats ("42 enriched, 8 from .bib only"), preserve DOI even on API failure.

## Implications for Roadmap

Based on research, suggested 7-phase structure with clear dependency chain:

### Phase 1: DOI Parsing Utilities (Foundation)
**Rationale:** All bulk import features depend on robust DOI parsing and validation. Build this foundation first to avoid rework. Low complexity (utilities only, no UI), high reusability.

**Delivers:** `parse_doi_list()` and `validate_doi_batch()` functions in `utils_doi.R` with unit tests covering edge cases (URLs, bare DOIs, comma/newline/space-separated input).

**Addresses:** Foundation for Bulk DOI Import, BibTeX Import, Citation Audit features.

**Avoids:** Malformed input causing downstream errors in OpenAlex API calls. Early validation reduces debugging later.

---

### Phase 2: OpenAlex Batch API Support
**Rationale:** Citation audit and bulk import both require efficient batch fetching. Implementing this before UI prevents discovering rate limit issues late in development. Critical pitfall mitigation (rate limit cascade) happens here.

**Delivers:** `batch_fetch_works_by_doi()` in `api_openalex.R` with chunking (50 DOIs per request), rate limiting (0.1s delays between batches), exponential backoff on 429 errors, graceful handling of missing DOIs.

**Uses:** OpenAlex pipe-separated filter syntax (`filter=doi:A|B|C`), existing httr2 infrastructure.

**Avoids:** **Pitfall #1 (Rate Limit Cascade)** — batching and delays prevent 429 errors, exponential backoff handles budget exhaustion gracefully.

---

### Phase 3: Bulk DOI Import UI
**Rationale:** First user-facing feature, validates that batch API operations work end-to-end before building more complex features on top. Provides immediate value (users can import paper lists from other tools).

**Delivers:** "Bulk Import" → "DOI List..." modal in search notebook with textarea/file upload, ExtendedTask for async import with progress bar, error handling (invalid DOIs, API failures, duplicates), success notification with import stats.

**Uses:** Phase 1 DOI parsing, Phase 2 batch API, existing `create_abstract()` for persistence.

**Implements:** Modal-driven workflow pattern, ExtendedTask + mirai for async operations (standard architecture pattern).

---

### Phase 4: BibTeX File Import
**Rationale:** Thin wrapper over Phase 3 bulk import—reuses all backend logic, just adds .bib parsing layer. Low risk, high user value (library migration from Zotero/Mendeley).

**Delivers:** "Bulk Import" → "BibTeX File..." modal, `parse_bibtex_file()` in `utils_bibtex.R` using bib2df, DOI extraction with normalization, wire to existing batch import flow, per-entry error handling with diagnostics.

**Uses:** bib2df package (new dependency), Phase 1 DOI parsing, Phase 2 batch API.

**Avoids:** **Pitfall #2 (BibTeX Parse Failure)** — per-entry try-catch prevents one malformed entry from blocking entire import, diagnostics show users what succeeded/failed.

**Avoids:** **Pitfall #6 (Metadata Loss)** — merge-not-replace pattern preserves .bib metadata when OpenAlex lookup fails for unindexed papers.

---

### Phase 5: Citation Audit Analysis
**Rationale:** Most complex feature—depends on batch API (Phase 2) and requires careful SQL optimization. Build after validating batch operations work reliably. Provides key differentiator (citation gap detection).

**Delivers:** "Find Missing Papers" button in search notebook, `analyze_citation_gaps()` in `citation_audit.R` with single-query SQL aggregation (`UNNEST() + GROUP BY`), OpenAlex batch query by work ID (not DOI—critical distinction discovered in research), modal with ranked checkbox list, import via existing `create_abstract()`.

**Uses:** DuckDB array functions for JSON parsing, Phase 2 batch API for metadata fetch.

**Avoids:** **Pitfall #3 (SQL N+1 Explosion)** — single aggregation query with `UNNEST()` scales to 5000+ abstracts, R loop pattern would time out at 500.

**Critical discovery:** OpenAlex `referenced_works` stores **work IDs** (`https://openalex.org/W123`), not DOIs. Must batch query by work ID to get DOI/title/author, then filter by work ID (not DOI) against corpus.

---

### Phase 6: Select-All Batch Import
**Rationale:** Independent of other features (pure UI change), can be built in parallel with Phase 5. Enables efficient bulk workflows for filtered search results. UI refactor requires careful reactive logic.

**Delivers:** Select-all checkbox above paper list, move predatory journal toggle into filter modal (UI refactor), `selected_papers_rv()` reactive merging select-all + individual checkboxes, import loop with transaction wrapper for atomicity.

**Addresses:** Table stakes feature (expected by users from other reference managers).

**Avoids:** **Pitfall #5 (Memory Explosion)** — batch size warning if >100 papers selected, progress indicator with ExtendedTask for large imports, paginated transfer via DuckDB (not reactive serialization).

---

### Phase 7: Slide Prompt Healing
**Rationale:** Independent of all other features (operates on existing slide generation), lowest priority (quality-of-life improvement vs core workflow). Can be built in parallel with other phases or deferred to v7.x if needed.

**Delivers:** YAML template pre-injection in `build_slides_prompt()`, `heal_qmd_yaml()` fallback function, "Regenerate" button + textarea in slides modal, healing observer that amends prompt with specific instructions, max 2 retries + template fallback.

**Uses:** Existing `chat_completion()` with history context, `yaml::yaml.load()` for validation.

**Avoids:** **Pitfall #4 (YAML Healing Infinite Loop)** — specific error feedback ("missing colon at line 3") instead of generic "fix this", 2-retry limit prevents cost runaway, template fallback ensures user gets usable output.

### Phase Ordering Rationale

- **Phase 1 → Phase 2 dependency:** DOI utilities must exist before batch API operations can validate input
- **Phase 2 → Phase 3 → Phase 4 dependency chain:** Batch API must work before bulk import UI, bulk import must work before .bib import (which reuses it)
- **Phase 2 → Phase 5 dependency:** Batch API must work before citation audit (which fetches missing paper metadata)
- **Phase 6 and Phase 7 parallelizable:** Both independent of other features—can be built concurrently with Phase 3-5
- **Pitfall mitigation embedded in phase order:** Rate limiting (Phase 2) addressed before any bulk operations exposed to users, SQL optimization (Phase 5) required before citation audit ships, memory handling (Phase 6) required before select-all ships

This order minimizes rework: foundational utilities first, then features built on top. Critical pitfalls are addressed in the phases where they occur, not retroactively fixed later.

### Research Flags

**Phases needing standard patterns only (skip research-phase):**
- **Phase 1 (DOI utilities):** Text parsing and regex validation—well-documented, no special research needed
- **Phase 3 (Bulk DOI UI):** Reuses existing async patterns (ExtendedTask + mirai), modal workflows—established in codebase
- **Phase 4 (BibTeX import):** bib2df is well-documented rOpenSci package, reuses Phase 3 infrastructure
- **Phase 6 (Select-all):** Pure Shiny reactive UI logic, no external integration complexity
- **Phase 7 (Slide healing):** Prompt engineering iteration, no research-phase needed (just testing)

**Phases where research already complete (use this research):**
- **Phase 2 (Batch API):** OpenAlex API batching fully researched (pipe-separated syntax, 50 DOI limit, rate limiting strategies documented)
- **Phase 5 (Citation audit):** DuckDB array aggregation patterns researched, OpenAlex work ID vs DOI distinction documented

**No phases need additional research-phase.** This project research was comprehensive—all technical unknowns resolved. During implementation, if unexpected complexity emerges (e.g., bib2df can't handle a specific .bib format), handle with targeted task-level research rather than formal research-phase.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | bib2df is rOpenSci package (peer-reviewed, actively maintained). OpenAlex batch API syntax verified in official docs. All other packages already in use (readr, httr2, DuckDB). |
| Features | MEDIUM | Feature list validated against competitors (Litmaps, Connected Papers, Scite), but v7.0 scope based on inference from user needs (no user interviews conducted). Table stakes features (bulk import, .bib support) confirmed via reference manager landscape research. Citation gap detection validated as differentiator. |
| Architecture | HIGH | Integration points verified by reading existing codebase. `referenced_works` column confirmed to exist (v2.0 migration). ExtendedTask + mirai pattern proven in production (Phase 30 citation network). No schema changes required. |
| Pitfalls | HIGH | Rate limiting and batch API patterns verified in OpenAlex docs (Feb 2026 updates). BibTeX parsing pitfalls documented in rOpenSci roundup and GitHub issues. DuckDB performance characteristics confirmed in official docs. LLM YAML healing validated in research papers (2024-2026). |

**Overall confidence:** HIGH

Research sources are authoritative (official docs, rOpenSci peer-reviewed packages, OpenAlex API documentation, academic papers on LLM self-correction). The one MEDIUM confidence area (Features) reflects lack of direct user validation—feature priorities inferred from competitor analysis and systematic review methodology standards. This gap can be addressed during implementation by iterating on UX based on user feedback.

### Gaps to Address

- **BibTeX DOI quality validation:** Many real-world .bib files have missing or malformed DOI fields. Research identified this gap but didn't quantify prevalence. **Mitigation:** Phase 4 should test with diverse .bib exports (Zotero, Mendeley, EndNote) to measure skip rates and refine fallback strategies (title search vs skip-and-warn).

- **OpenAlex work ID resolution performance:** Citation audit must batch-query work IDs from `referenced_works` to get DOIs/titles. Research confirmed this is possible but didn't benchmark speed. **Mitigation:** Phase 5 should performance-test with 500+ abstracts (thousands of work IDs) to validate single-query aggregation scales as expected.

- **User expectations for citation audit threshold:** Research found 3-5 citations as common threshold for "frequently cited," but didn't determine optimal default. **Mitigation:** Phase 5 should start with threshold=3 (inclusive), add UI control in v7.x if users request configurability.

- **LLM model variability in YAML generation:** Slide healing assumes smaller models produce malformed YAML more often, but research didn't quantify rates per model. **Mitigation:** Phase 7 should test with Claude Haiku, GPT-4o-mini, Llama 3.1 to validate healing improves success rates across model tiers.

## Sources

### Primary (HIGH confidence)

**OpenAlex API:**
- [OpenAlex rate limits and authentication](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication) — 100 req/sec limit, $1/day free tier, batch syntax verified
- [OpenAlex API batch DOI requests](https://blog.openalex.org/fetch-multiple-dois-in-one-openalex-api-request/) — Official guide to pipe-separated filter syntax (50 DOI limit per request)
- [OpenAlex filter entity lists](https://docs.openalex.org/how-to-use-the-api/get-lists-of-entities/filter-entity-lists) — Filter syntax documentation
- [OpenAlex Work object](https://docs.openalex.org/api-entities/works/work-object) — `referenced_works` field stores work IDs, not DOIs

**R Packages:**
- [bib2df CRAN vignette](https://cran.r-project.org/web/packages/bib2df/vignettes/bib2df.html) — Version 1.1.2.0, rOpenSci peer-reviewed
- [bib2df GitHub (rOpenSci)](https://github.com/ropensci/bib2df) — Active maintenance, last updated Jan 2026
- [rOpenSci BibTeX parser roundup](https://ropensci.org/blog/2020/05/07/rmd-citations/) — Comparison of bib2df, bibtex, RefManageR, rbibutils
- [ExtendedTask with mirai](https://mirai.r-lib.org/articles/shiny.html) — Official Shiny integration guide
- [DuckDB Performance Tuning](https://duckdb.org/docs/stable/guides/performance/how_to_tune_workloads) — Columnar-vectorized execution, array aggregation

**Citation Audit Methodology:**
- [Litmaps research gap detection](https://www.litmaps.com) — Dynamic citation mapping competitor with gap detection
- [Scite AI Smart Citations review](https://effortlessacademic.com/scite-ai-review-2026-literature-review-tool-for-researchers/) — Citation context analysis (supporting/contrasting)
- [Finding Seminal Works - National University Library](https://resources.nu.edu/researchprocess/seminalworks) — Citation analysis methodology (3-5 citation threshold standard)
- [In-text Citation Frequencies for Relevancy](https://pmc.ncbi.nlm.nih.gov/articles/PMC8189020/) — Papers cited >5 times in text = high relevance (academic standard)

### Secondary (MEDIUM confidence)

**Reference Management Landscape:**
- [Best Reference Management Software 2026](https://research.com/software/best-reference-management-software) — Industry standards for bulk import (DOI lists, .bib files expected)
- [Paperguide AI Reference Manager](https://paperguide.ai/blog/ai-reference-manager-tools/) — BibTeX/RIS/DOI import patterns across tools
- [Zotero/Mendeley bulk import guides](https://libguides.ucalgary.ca/guides/endnote/EN20references) — BibTeX batch workflow patterns

**LLM Structured Output:**
- [When Can LLMs Actually Correct Their Own Mistakes? (2024)](https://direct.mit.edu/tacl/article/doi/10.1162/tacl_a_00713/125177/) — Self-correction works only with reliable external feedback
- [LLM Infinite Loops In Entity Extraction - GDELT](https://blog.gdeltproject.org/llm-infinite-loops-in-llm-entity-extraction-when-temperature-basic-prompt-engineering-cant-fix-things/) — Temperature=0 creates deterministic loops
- [Implementing Retry Mechanisms for LLM Calls](https://apxml.com/courses/prompt-engineering-llm-application-development/chapter-7-output-parsing-validation-reliability/implementing-retry-mechanisms) — Best practices: validate → retry 1-2 times → escalate

### Tertiary (LOW confidence)

**BibTeX Edge Cases:**
- [bibtex-parsing edge cases - citation-js Issue #73](https://github.com/citation-js/citation-js/issues/73) — Valid but unusual BibTeX entries (missing keys, arbitrary types)
- [Parsing BibTeX in Racket](https://matt.might.net/articles/parsing-bibtex/) — Nested braces and string literal tokenization rules

---
*Research completed: 2026-02-25*
*Ready for roadmap: yes*
