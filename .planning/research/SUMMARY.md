# Project Research Summary

**Project:** Serapeum Discovery & Export Enhancements (v1.3)
**Domain:** Research Assistant - Citation Network Visualization & Citation Export
**Researched:** 2026-02-12
**Confidence:** HIGH

## Executive Summary

The v1.3 milestone enhances Serapeum's discovery workflow with citation network visualization, citation export (BibTeX/CSV), synthesis export, and DOI-based workflows. Research reveals this is **low-complexity infrastructure enhancement** requiring only one new dependency (visNetwork) while leveraging Serapeum's existing R/Shiny + DuckDB + OpenAlex stack. The technical approach is well-established: citation network tools (Connected Papers, ResearchRabbit) prove visualization is table stakes, while reference managers (Zotero, Mendeley) set export format expectations.

The recommended approach builds citation networks incrementally with strict depth limits (1-hop default, 2-hop max) to prevent exponential API explosion. BibTeX export should be constructed directly from OpenAlex metadata rather than adding export dependencies. All features follow existing Serapeum patterns: Shiny modules for UI, DuckDB for persistence, downloadHandler for exports. The primary technical risk is citation graph exponential growth; mitigation requires breadth capping (100 nodes max) and batch API fetching (50 papers per request using OpenAlex OR syntax).

Critical implementation insight: **DOI storage requires migration infrastructure BEFORE feature implementation**. Existing databases have 1000+ papers without DOIs — adding a column is insufficient. A backfill strategy (mark as PENDING, async fetch in batches) prevents user-facing breakage. Cross-module navigation must use session-scoped reactiveValues to avoid state contamination in multi-user deployments. Export features demand UTF-8 encoding discipline and tempdir usage to prevent production failures.

## Key Findings

### Recommended Stack

**Minimal stack additions required.** All core capabilities exist in Serapeum's current infrastructure. Add visNetwork for citation graphs, optionally defer handlr package until multi-format export (RIS/RDF) is requested.

**New packages:**
- **visNetwork 2.1.4**: Interactive network graphs — vis.js wrapper with native Shiny integration, htmlwidget support, proven citation network use cases. Industry standard for R network visualization.

**Optional packages (defer to v1.4):**
- **handlr 0.3.1**: Multi-format citation export (RIS/RDF/Schema.org) — only needed if users request beyond BibTeX/CSV.

**Existing stack (no changes):**
- **httr2 1.2.1**: Bulk citation fetching from OpenAlex (pipe-separated IDs, up to 50 per request)
- **DuckDB 1.3.2**: Store citation relationships (add referenced_works column as JSON array)
- **Base R utils**: write.csv() for CSV export, writeLines() for BibTeX/markdown
- **Shiny 1.11.1**: downloadHandler() + downloadButton() for all export formats

**Data source insight:** OpenAlex already provides citation relationships (referenced_works, cited_by_api_url). No new data sources needed. This is a presentation and export layer, not a data ingestion layer.

### Expected Features

Research on competitive tools (Connected Papers, Zotero, Mendeley, Web of Science) reveals clear feature expectations.

**Must have (table stakes):**
- **DOI display on abstract preview** — Standard metadata in all academic tools. Users need to copy DOI for citations.
- **BibTeX export** — Universal standard for LaTeX users, supported by every reference manager. Non-negotiable.
- **CSV export** — Expected for data analysis, spreadsheet import. Common in all academic databases.
- **Basic citation metadata** — Title, authors, year, DOI, journal required for any export.

**Should have (competitive differentiators):**
- **Citation network graph** — Visual discovery beats list-based search. Connected Papers built business on this. Local-first = privacy + offline + unlimited graphs (competitors charge for saved graphs).
- **Export abstract to seeded search** — One-click workflow (discover in search → seed new search from abstract) vs. manual copy/paste DOI.
- **Seeded search uses search notebook UI** — Consistency reduces learning curve (same filters, sorting, selection as keyword search).
- **Export synthesis outputs** — Markdown/HTML export for RAG chat summaries completes the research workflow.

**Defer (v2+):**
- **Multi-format citation export** — RIS, Schema.org, RDF (handlr package). Only if users request. BibTeX + CSV sufficient for v1.3.
- **PDF export for synthesis** — Requires pandoc or pagedown. Complexity spike. Markdown/HTML covers most use cases.
- **Multi-origin citation graphs** — Connected Papers allows multiple seed papers. Defer to v1.4. Single-origin is complex enough.

**Anti-features (explicitly avoid):**
- **Custom citation styles** — APA/MLA/Chicago formatting. Complexity explosion (9000+ styles). Let Zotero/LaTeX handle formatting.
- **PDF annotation** — Different product category. Users have preferred PDF readers.
- **Real-time graph physics** — Performance issues with 100+ nodes. Static layout computed once, pan/zoom only.

### Architecture Approach

All features integrate into existing producer-consumer pattern. Discovery modules produce requests, app.R consumes and creates notebooks. New features follow same pattern: citation network consumes from abstract detail view, export features consume from search notebook.

**Major components:**

1. **DOI Storage (data layer enhancement)** — Migration adds doi VARCHAR column to abstracts table. parse_openalex_work() already extracts DOI (line 181-186 in api_openalex.R). Update create_abstract() to store doi parameter. No module changes required (all callers already pass parsed work objects).

2. **Citation Network Module (mod_citation_network.R)** — New Shiny module integrated into abstract detail view (mod_search_notebook.R lines 691-833). Uses visNetwork for rendering, fetch_citation_network() utility for OpenAlex API calls. Reactive updates via visNetworkProxy (no full redraw on filter changes). Caches graph data in DuckDB by seed DOI.

3. **Export-to-Seed Workflow (cross-module communication)** — Abstract detail view adds "Use as Seed" button. Emits seed_request reactive consumed by app.R. Navigates to discover view with pre-filled DOI. Alternative: modal confirmation dialog (simpler than reactive communication).

4. **Citation/Synthesis Export (download handlers)** — Add download buttons to chat output and abstract list. Use Shiny downloadHandler pattern. Export utilities (R/export_utils.R): format_chat_as_markdown() for synthesis, direct BibTeX string construction for citations. Always use tempdir() for intermediate files (production permission safety).

**Integration points:**
- Database: Add migration for referenced_works column (follow existing migration pattern lines 98-149 in db.R)
- OpenAlex API: Extract referenced_works list in parse_openalex_work(), add batch fetching helper
- Shiny modules: Wire citation network into abstract detail, export buttons into search notebook
- No new sidebar links needed (features live within existing notebooks)

### Critical Pitfalls

Research identified 12 pitfalls across critical/moderate/minor categories. Top 5 for immediate attention:

1. **Citation Network Exponential Explosion** — Average paper cites 25 others. Recursive fetching without depth limit causes API exhaustion and browser crashes. **Prevention:** Default 1-hop (direct citations only), max 2-hop with warning. Cap at 100 papers per level. Batch fetch using OpenAlex OR syntax (50 IDs per request). Require user confirmation if >1000 API credits estimated.

2. **DOI Field Migration Breaking Existing Databases** — Adding doi column leaves existing papers with NULL DOI. Feature appears broken for users with 1000+ papers. **Prevention:** Use PRAGMA user_version for migration tracking. Backfill script marks rows as PENDING, async background job fetches DOIs in batches (50 per API call). Progress indicator. Graceful degradation (UI handles NULL DOI, export generates citation keys from title+year if DOI missing).

3. **Cross-Module State Contamination** — Global reactiveValues shared across sessions causes User A's selections to appear in User B's UI. **Prevention:** Session-scoped reactiveValues (define inside server function, not outside). Pass to modules explicitly as parameters. Test multi-session behavior with shinytest2. Never rely on session$userData for cross-module state.

4. **BibTeX Export Encoding Corruption** — System locale mismatches cause garbled characters ("café" → "cafÃ©"). LaTeX special characters break compilation. **Prevention:** Specify UTF-8 explicitly in downloadHandler (file(..., encoding = "UTF-8")). Escape LaTeX special characters (&, %, $, _, {, }, ~, ^). Use rbibutils for standards-compliant output or build BibTeX directly with proper escaping.

5. **Download Handler Tempdir Permission Errors** — Works locally but fails on shinyapps.io/RStudio Connect with "Permission denied" errors. Cannot write to working directory in production. **Prevention:** Always use tempdir() for intermediate files. Test on production-like environment with restricted permissions. Windows Storage Sense may delete tempdir contents — check existence before use.

**Phase-specific warnings:**
- **Phase 05 (DOI Storage):** Migration infrastructure required before adding column. Test with 1000+ paper database.
- **Phase 06 (Citation Discovery):** Depth/breadth limits non-negotiable. Cycle detection + fallback layouts required.
- **Phase 07 (Export Features):** UTF-8 handling, tempdir usage, unique citation keys must work from day 1.

## Implications for Roadmap

Based on research, suggested phase structure prioritizes data foundation, then visualization, then export workflows:

### Phase 1: DOI Storage & Migration Infrastructure
**Rationale:** DOI field is dependency for export-to-seed workflow, BibTeX export, and citation network API calls. Migration infrastructure must exist before adding column — existing users have 1000+ papers without DOIs that need backfill.

**Delivers:**
- Migration versioning system (PRAGMA user_version)
- DOI column in abstracts table
- Backfill strategy for existing papers (PENDING marker + async batch fetching)
- DOI normalization utility (URL → bare DOI, validation)
- Graceful degradation for NULL DOIs in UI

**Addresses:** Database Enhancement requirement from FEATURES.md. Prevents critical pitfall #2 (migration breaking existing databases).

**Avoids:** Silent feature breakage for existing users. Enables all downstream features.

### Phase 2: Citation Network Visualization
**Rationale:** Marquee differentiator feature. Complex enough to warrant dedicated phase. Dependency on Phase 1 (needs DOI for API calls). Requires careful handling of exponential growth and graph cycles.

**Delivers:**
- visNetwork package integration
- mod_citation_network.R Shiny module
- fetch_citation_network() utility with batch API fetching
- Depth limiting (1-hop default, 2-hop max)
- Breadth capping (100 nodes)
- Cycle detection + fallback layouts (force-directed if cycles, hierarchical if DAG)
- Graph caching in DuckDB by seed DOI
- Interactive features: zoom, pan, click node → abstract detail

**Uses:** visNetwork 2.1.4 (STACK.md), OpenAlex citation API (existing infrastructure).

**Implements:** Citation Network Module architecture component. Follows existing producer-consumer pattern.

**Avoids:** Critical pitfall #1 (exponential explosion) via depth/breadth limits. Moderate pitfall #7 (reactivity cascade) via visNetworkProxy for incremental updates.

**Research flag:** Test with seminal papers (500+ citations) to verify performance. May need layout optimization for large graphs.

### Phase 3: Export-to-Seed Workflow
**Rationale:** Quick win building on Phase 1 DOI infrastructure. Seamless cross-module navigation improves discovery workflow. Lower complexity than citation network or exports.

**Delivers:**
- "Use as Seed" button in abstract detail view
- seed_request reactive communication (search notebook → app.R)
- Navigation to discover view with pre-filled DOI
- State preservation (search results persist when switching tabs)
- Session-scoped reactiveValues for cross-module communication

**Addresses:** Export abstract to seeded search (#67), Seeded search same view (#71) from FEATURES.md.

**Avoids:** Critical pitfall #3 (state contamination) via session-scoped reactiveValues. Moderate pitfall #9 (navigation state loss) via state persistence in reactiveValues.

**Research flag:** Standard Shiny module communication pattern. No phase-specific research needed.

### Phase 4: Citation Export (BibTeX, CSV)
**Rationale:** Table stakes feature. Dependency on Phase 1 (needs DOI). Lower complexity than citation network (no graph rendering). Build BibTeX directly rather than adding export library.

**Delivers:**
- BibTeX formatter (OpenAlex → BibTeX fields, LaTeX escaping)
- CSV formatter (flatten data frame)
- Export UI (dropdown: "Export as BibTeX / CSV")
- downloadHandler with UTF-8 encoding
- Unique citation key generation (author_year with suffix for duplicates)
- DOI normalization (bare DOI, not URL)
- Handle edge cases (missing authors, no DOI, special characters)

**Uses:** Base R write.csv(), Shiny downloadHandler (existing stack). No new dependencies.

**Addresses:** Citation export (#64) from FEATURES.md. Table stakes requirement from competitive research.

**Avoids:** Critical pitfall #4 (encoding corruption) via explicit UTF-8. Critical pitfall #5 (tempdir permissions) via tempdir() usage. Moderate pitfall #10 (citation key collisions) via suffix generation.

**Research flag:** Test BibTeX import in Zotero/Mendeley to verify format compliance. Test on restricted environment (shinyapps.io) to verify tempdir usage.

### Phase 5: Synthesis Export (Markdown, HTML)
**Rationale:** Completes research workflow. Lower complexity (text export, no citation formatting). Can defer PDF to v1.4.

**Delivers:**
- Download button for chat output
- format_chat_as_markdown() utility
- Markdown export (.md) for chat summaries
- HTML export (wrap in basic template)
- Timestamp and metadata inclusion
- Full conversation (user + assistant messages)

**Uses:** Base R writeLines(), Shiny downloadHandler (existing stack). No new dependencies.

**Addresses:** Export synthesis outputs (#49) from FEATURES.md.

**Avoids:** Critical pitfall #5 (tempdir permissions). Defers PDF complexity to future milestone.

**Research flag:** Standard text export. No phase-specific research needed.

### Phase Ordering Rationale

- **DOI first** because it's a data dependency for all other features. Migration complexity justifies dedicated phase. Prevents user-facing breakage.
- **Citation network second** because it's the most complex feature (graph rendering, API management, performance optimization). Marquee differentiator justifies early delivery.
- **Export-to-seed third** because it's a quick win leveraging DOI infrastructure. Improves UX before adding export features.
- **Citation export fourth** because it's table stakes but complex (encoding, citation keys, format compliance). Builds on DOI infrastructure.
- **Synthesis export last** because it's simplest and independent of other phases. Lower priority than citation features.

**Dependency chain:** Phase 1 (DOI) → Phase 2 (citation network), Phase 3 (export-to-seed), Phase 4 (citation export). Phase 5 (synthesis export) is independent.

**Avoids pitfalls through ordering:** Migration infrastructure before features prevents breakage. Complex features (citation network) get dedicated focus. Simple features (synthesis export) defer until core capabilities proven.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 2 (Citation Network):** Graph layout performance optimization for 100+ nodes. Need to test with real seminal papers (500+ citations). May need to research vis.js configuration options for large graphs.
- **Phase 4 (Citation Export):** BibTeX format compliance validation. Need to verify export works with multiple citation managers (Zotero, Mendeley, EndNote). Field mapping edge cases (no DOI, multiple authors, special characters).

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (DOI Storage):** Database migrations follow existing pattern (lines 98-149 in db.R). DuckDB ALTER TABLE is documented.
- **Phase 3 (Export-to-Seed):** Shiny module communication is well-established pattern. Existing codebase has examples.
- **Phase 5 (Synthesis Export):** Text export via downloadHandler is standard Shiny pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | visNetwork is mature (v2.1.4, Sept 2025), well-documented, proven Shiny integration. Base R export capabilities verified. OpenAlex API features confirmed. |
| Features | HIGH | Competitive analysis of Connected Papers, Zotero, Mendeley shows clear table stakes vs. differentiators. BibTeX/CSV are universal standards. |
| Architecture | HIGH | All features follow existing Serapeum patterns. Integration points identified in current codebase. Producer-consumer pattern proven. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls verified with official sources (OpenAlex rate limits, DuckDB limitations, Shiny deployment constraints). Moderate pitfalls based on community best practices and GitHub issues. |

**Overall confidence:** HIGH

### Gaps to Address

**During Phase Planning:**
- **Graph layout algorithm selection:** visNetwork supports 20+ layouts. Need to test hierarchical vs. force-directed vs. radial with real citation data to determine best default. Can be decided during Phase 2 planning.

- **Export format priority:** Research suggests BibTeX + CSV are essential, RIS is nice-to-have. Need user validation during Phase 4 planning to confirm whether RIS should be in v1.3 or defer to v1.4.

- **Citation network depth defaults:** 1-hop vs. 2-hop default needs UX decision. 1-hop is safer (performance) but 2-hop may be more useful (discovery). Can A/B test during Phase 2 implementation.

**During Execution:**
- **OpenAlex field mapping validation:** handlr package requires Citeproc intermediate format. Need to validate that OpenAlex authorships structure maps cleanly to BibTeX author format (multi-author edge cases). Relevant for Phase 4 if handlr is used (currently recommended to build BibTeX directly).

- **Migration backfill performance:** Async DOI fetching for 1000 papers = ~20 API calls at 50 papers/batch. Estimated 2-4 seconds. Need to verify this is acceptable startup time or needs background job. Relevant for Phase 1 execution.

- **Cross-module navigation UX:** Export-to-seed workflow can use reactive communication (complex) or modal dialog (simpler). Need to prototype both approaches in Phase 3 to determine which feels better.

## Sources

### Primary (HIGH confidence)
- [OpenAlex API Works documentation](https://docs.openalex.org/api-entities/works)
- [OpenAlex Work object fields](https://docs.openalex.org/api-entities/works/work-object)
- [OpenAlex Rate Limits](https://docs.openalex.org/how-to-use-the-api/rate-limits-and-authentication)
- [Fetch multiple DOIs in one request](https://blog.ourresearch.org/fetch-multiple-dois-in-one-openalex-api-request/)
- [visNetwork CRAN page](https://cran.r-project.org/web/packages/visNetwork/index.html)
- [visNetwork official docs](https://datastorm-open.github.io/visNetwork/)
- [visNetwork Shiny integration](https://datastorm-open.github.io/visNetwork/shiny.html)
- [Shiny downloadHandler reference](https://shiny.posit.co/r/reference/shiny/latest/downloadhandler.html)
- [Mastering Shiny - Uploads and Downloads](https://mastering-shiny.org/action-transfer.html)
- [DuckDB ALTER TABLE](https://duckdb.org/docs/stable/sql/statements/alter_table)
- [BibTeX format specification](https://www.bibtex.com/g/bibtex-format/)

### Secondary (MEDIUM confidence)
- [Connected Papers](https://www.connectedpapers.com/) — Citation network visualization patterns
- [ResearchRabbit](https://www.researchrabbit.ai) — Seeded search workflow patterns
- [Litmaps](https://www.litmaps.com/) — Visual network UX patterns
- [Zotero Documentation](https://www.zotero.org/) — BibTeX export expectations
- [Interactive Network Visualization with R](https://www.statworx.com/en/content-hub/blog/interactive-network-visualization-with-r)
- [R Graph Gallery - Interactive Networks](https://r-graph-gallery.com/network-interactive.html)
- [Shiny Modules: Communication Patterns](https://mastering-shiny.org/scaling-modules.html)
- [handlr rOpenSci docs](https://docs.ropensci.org/handlr/) — Multi-format export reference

### Tertiary (LOW confidence)
- [DuckDB NOT NULL Constraint Limitation](https://github.com/duckdb/duckdb/issues/3248) — Migration edge case
- [Shiny tempdir Windows Issue](https://github.com/rstudio/shiny/issues/2542) — Production deployment concern
- [Communication Between Modules Anti-Patterns](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/) — Best practices guidance

---
*Research completed: 2026-02-12*
*Ready for roadmap: yes*
