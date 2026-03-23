# TODO

Future enhancements for the Research Notebook tool, organized by milestone.

---

## Pending PRs (Resolve Immediately)

- [x] PR #233: fix: v16 uncommitted changes — cost logging, prompt wiring, indexes [merged]
- [x] PR #237: HOTFIX: Fix download button for abstract-imported documents [merged]
- [ ] PR #241: fix: v18 Bug Bash — all 13 milestone issues [open] — v18-bug-bash -> integration

---

## v18: Bug Bash (Complete)

*Critical bugs, security, data integrity, broken tests. All 13 issues resolved across 5 sessions.*

| Issue | Title | Resolution |
|-------|-------|------------|
| ~~[#235](https://github.com/seanthimons/serapeum/issues/235)~~ | ~~Missing semicolon in migration 018~~ | Fixed + retroactive migration 019 |
| ~~[#165](https://github.com/seanthimons/serapeum/issues/165)~~ | ~~Email not redacted in OA logs~~ | Fixed — `gsub()` for mailto |
| ~~[#229](https://github.com/seanthimons/serapeum/issues/229)~~ | ~~p.NA in build_context/slides~~ | Fixed — `is.na()` guards |
| ~~[#234](https://github.com/seanthimons/serapeum/issues/234)~~ | ~~log_cost stale ID on INSERT fail~~ | Fixed — restructured tryCatch |
| ~~[#193](https://github.com/seanthimons/serapeum/issues/193)~~ | ~~Weight preset sums exceed 1.0~~ | Fixed — normalize preserving ratios |
| ~~[#179](https://github.com/seanthimons/serapeum/issues/179)~~ | ~~%\|\|% not defined in utils_scoring~~ | Non-issue — base R since 4.4.0 |
| ~~[#181](https://github.com/seanthimons/serapeum/issues/181)~~ | ~~XSS injection in keyword onclick~~ | Non-issue — jsonlite+htmltools already escape |
| ~~[#213](https://github.com/seanthimons/serapeum/issues/213)~~ | ~~test-config.R path resolution~~ | Fixed — `source_app()` helper across 29 files |
| ~~[#214](https://github.com/seanthimons/serapeum/issues/214)~~ | ~~test-db.R schema drift~~ | Fixed — `run_pending_migrations()` + source pdf_images |
| ~~[#177](https://github.com/seanthimons/serapeum/issues/177)~~ | ~~Double JSON encoding of authors~~ | Fixed — detect pre-serialized values |
| ~~[#185](https://github.com/seanthimons/serapeum/issues/185)~~ | ~~Silent API failure in Refiner~~ | Fixed — error accumulation + notification |
| ~~[#186](https://github.com/seanthimons/serapeum/issues/186)~~ | ~~Missing ON DELETE CASCADE~~ | Fixed — app-level `delete_refiner_run()` |
| ~~[#154](https://github.com/seanthimons/serapeum/issues/154)~~ | ~~Import badge doesn't update~~ | Fixed — `notebook_refresh` increment |
| ~~[#159](https://github.com/seanthimons/serapeum/issues/159)~~ | ~~Abstract chat wrong citations~~ | Fixed — author/year enrichment + prompt update |

*Bonus:* Fixed infinite notification loop in document re-index handler (reactive `observe()` without `isolate()`).

---

## Milestone Execution Notes

- **v12 through v16 are fully parallel** — no cross-milestone dependencies; any can be started independently
- **v17 is internally sequential** (stages 1→7) but independent of all other milestones
- **v12 is the recommended starting point** — all quick wins that clear the decks before heavier work
- **Within each milestone**, issues can generally be worked in parallel unless noted otherwise

---

## v12.0: UX Polish & Onboarding

*Quick wins — mostly low complexity, immediate user-facing value. All issues are parallel.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| ~~[#149](https://github.com/seanthimons/serapeum/issues/149)~~ | ~~Major buttons should have tooltips~~ | ~~Low~~ | ~~High~~ |
| [#150](https://github.com/seanthimons/serapeum/issues/150) | Notebook paths should have short descriptions for new users | Low | Medium |
| [#87](https://github.com/seanthimons/serapeum/issues/87) | Chat UX: modal messaging (remaining — spinners done Phase 29) | Medium | Medium |
| [#60](https://github.com/seanthimons/serapeum/issues/60) | Toggle/UI to expose API queries | Medium | Medium |
| [#9](https://github.com/seanthimons/serapeum/issues/9) | Versioning for releases | Low | Low |

---

## v13.0: Search & Discovery

*Improve how users find and filter papers. All issues are parallel except #122 which is a research spike that may inform #11.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#176](https://github.com/seanthimons/serapeum/issues/176) | Research Refiner: add index on refiner_results(run_id) | Low | Medium |
| [#174](https://github.com/seanthimons/serapeum/issues/174) | Research Refiner: batch accept/reject uses per-row DB writes | Low | Medium |
| [#173](https://github.com/seanthimons/serapeum/issues/173) | Research Refiner: results UI silently caps at 100 papers | Low | Medium |
| ~~[#151](https://github.com/seanthimons/serapeum/issues/151)~~ | ~~Duplicate keyword ban/keep behavior to per-abstract keywords~~ | ~~Medium~~ | ~~Medium~~ |
| ~~[#125](https://github.com/seanthimons/serapeum/issues/125)~~ | ~~Update file/document filter types reported by OpenAlex~~ | ~~Medium~~ | ~~Medium~~ |
| ~~[#11](https://github.com/seanthimons/serapeum/issues/11)~~ | ~~Recursive abstract searching~~ | ~~High~~ | ~~High~~ |
| ~~[#160](https://github.com/seanthimons/serapeum/issues/160)~~ | ~~Research Refiner: start from notebook option~~ | ~~Medium~~ | ~~High~~ |
| [#122](https://github.com/seanthimons/serapeum/issues/122) | Follow up research | Low | Low |

---

## v14.0: Citation Network Evolution

*Network graph features and new visualization modes. All issues are parallel. #135 and #145 both touch citation audit UI — coordinate if worked simultaneously.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| ~~[#145](https://github.com/seanthimons/serapeum/issues/145)~~ | ~~Citation audit filters and controls (sorting, filtering by year/citation/FWCI)~~ | ~~Medium~~ | ~~Medium~~ |
| ~~[#135](https://github.com/seanthimons/serapeum/issues/135)~~ | ~~Changing citation size by new calculation metric~~ | ~~High~~ | ~~Medium~~ |
| [#84](https://github.com/seanthimons/serapeum/issues/84) | Export from network graph to abstract search + vice versa | High | Medium |
| [#126](https://github.com/seanthimons/serapeum/issues/126) | Partial BFS graph as intentional visualization mode | Medium | Medium |
| ~~[#6](https://github.com/seanthimons/serapeum/issues/6)~~ | ~~Timeline heatmap~~ | ~~Medium~~ | ~~Low~~ |

---

## v15.0: AI Infrastructure

*Core AI pipeline — model routing, retrieval, local models. #12 (evaluate reranker) should be done before or alongside #142 (retrieval pipeline). #48 feeds into #142. #144 and #8 are parallel to each other and to the retrieval work.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| ~~[#157](https://github.com/seanthimons/serapeum/issues/157)~~ | ~~OA request usage tracking~~ | ~~Medium~~ | ~~High~~ |
| ~~[#144](https://github.com/seanthimons/serapeum/issues/144)~~ | ~~AA Integration + Split Models + Latency Tracking~~ | ~~High~~ | ~~High~~ |
| ~~[#142](https://github.com/seanthimons/serapeum/issues/142)~~ | ~~Epic: Advanced Retrieval Pipeline (reranking, RRF, structural signals)~~ | ~~High~~ | ~~High~~ |
| ~~[#48](https://github.com/seanthimons/serapeum/issues/48)~~ | ~~Tighter RAG document retrieval controls~~ | ~~Low~~ | ~~Medium~~ |
| [#12](https://github.com/seanthimons/serapeum/issues/12) | ~~Evaluate reranker need~~ — deferred, using RRF + query reformulation instead | Low | TBD |
| ~~[#8](https://github.com/seanthimons/serapeum/issues/8)~~ | ~~Local model support~~ | ~~High~~ | ~~High~~ |

---

## v16.0: Content & Output Quality

*Improve generated slides, prompts, and exports. All issues are parallel. #22 (audio overview) is the heaviest lift and can be deferred within this milestone.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#132](https://github.com/seanthimons/serapeum/issues/132) | Themes for slides need better descriptions | High | High |
| [#120](https://github.com/seanthimons/serapeum/issues/120) | UI for viewing/editing prompts for research outputs | Medium | Medium |
| [#52](https://github.com/seanthimons/serapeum/issues/52) | Quarto citation support exploration | Low | Medium |
| [#22](https://github.com/seanthimons/serapeum/issues/22) | Audio overview (NotebookLM style) | High | Medium |

*PR review follow-ups (from PR #233 review):*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| ~~[#234](https://github.com/seanthimons/serapeum/issues/234)~~ | ~~log_cost returns stale ID when INSERT fails~~ | ~~Low~~ | ~~Medium~~ |
| ~~[#235](https://github.com/seanthimons/serapeum/issues/235)~~ | ~~Missing trailing semicolon in migration 018 CREATE INDEX~~ | ~~Low~~ | ~~Medium~~ |
| [#236](https://github.com/seanthimons/serapeum/issues/236) | Redundant role prefix in overview summary system prompt | Low | Low |

*PR #237 review follow-ups:*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#238](https://github.com/seanthimons/serapeum/issues/238) | Defensive NA check for docs$filepath in text file generation | Low | Low |
| [#239](https://github.com/seanthimons/serapeum/issues/239) | Cached .txt download files not refreshed if abstract is edited | Low | Medium |
| [#240](https://github.com/seanthimons/serapeum/issues/240) | Sanitize paper titles before using as filenames at abstract import time | Low | Medium |

*PR #241 review follow-ups:*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#242](https://github.com/seanthimons/serapeum/issues/242) | N+1 DB queries in enrich_retrieval_results() | Low | Medium |
| [#244](https://github.com/seanthimons/serapeum/issues/244) | JSON validate() guard too permissive for bare strings in create_abstract() | Low | Medium |
| [#245](https://github.com/seanthimons/serapeum/issues/245) | Refiner API error-path tests are placeholders with dead mock code | Low | Medium |
| [#250](https://github.com/seanthimons/serapeum/issues/250) | Duplicate error notification code in mod_research_refiner.R | Low | Low |
| [#243](https://github.com/seanthimons/serapeum/issues/243) | Error accumulation uses fragile index assignment in research_refiner.R | Low | Low |
| [#246](https://github.com/seanthimons/serapeum/issues/246) | Malformed JSON test assertion too permissive in test-rag-citations.R | Low | Low |
| [#247](https://github.com/seanthimons/serapeum/issues/247) | No test for migration 019 (retroactive index) | Low | Low |
| [#248](https://github.com/seanthimons/serapeum/issues/248) | Test comment/name mismatch in test-db-migrations.R | Low | Low |
| [#249](https://github.com/seanthimons/serapeum/issues/249) | setwd() in migration test risks corrupting test suite cwd | Low | Low |
| [#251](https://github.com/seanthimons/serapeum/issues/251) | Document metadata lookup by filename not unique across notebooks | Low | Medium |

---

## v17.0: PDF Image Pipeline

*Epic [#44](https://github.com/seanthimons/serapeum/issues/44) — 7 sequential stages. Stages 1-3, 5-7 complete. Stage 4 deferred.*

| Stage | Issue | Title | Complexity | Impact |
|-------|-------|-------|------------|--------|
| ~~1~~ | ~~[#38](https://github.com/seanthimons/serapeum/issues/38)~~ | ~~PDF image extraction (pdftools)~~ | ~~High~~ | ~~High~~ |
| ~~2~~ | ~~[#146](https://github.com/seanthimons/serapeum/issues/146)~~ | ~~Figure storage schema & DB helpers~~ | ~~Medium~~ | ~~High~~ |
| ~~3~~ | ~~[#28](https://github.com/seanthimons/serapeum/issues/28)~~ | ~~Caption extraction (heuristic pass)~~ | ~~High~~ | ~~High~~ |
| 4 | [#147](https://github.com/seanthimons/serapeum/issues/147) | Figure quality filtering & dedup (deferred) | Medium | Medium |
| ~~5~~ | ~~[#148](https://github.com/seanthimons/serapeum/issues/148)~~ | ~~Vision model enrichment (optional)~~ | ~~High~~ | ~~High~~ |
| ~~6~~ | ~~[#37](https://github.com/seanthimons/serapeum/issues/37)~~ | ~~Figure review & selection UI~~ | ~~Medium~~ | ~~Medium~~ |
| ~~7~~ | ~~[#29](https://github.com/seanthimons/serapeum/issues/29)~~ | ~~Figure injection into Quarto slides~~ | ~~High~~ | ~~High~~ |

*PR review follow-ups (from PR #163 review):*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#222](https://github.com/seanthimons/serapeum/issues/222) | Heal flow sends base64-inlined QMD to LLM on second attempt | Medium | Medium |
| [#223](https://github.com/seanthimons/serapeum/issues/223) | Re-extraction: all-saves-fail after delete leaves no figures | Medium | Medium |
| [#224](https://github.com/seanthimons/serapeum/issues/224) | Figure manifest: NA rendered as literal string in LLM prompt | Low | Low |

---

## Parking Lot

*Low priority, unslotted — assign to a milestone when ready.*

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#30](https://github.com/seanthimons/serapeum/issues/30) | Demo mode | Medium | Low |
| [#21](https://github.com/seanthimons/serapeum/issues/21) | Semantic Scholar integration | High | Low |

---

## Moonshot Goals

High-effort, high-payoff features for the future.

| Issue | Title | Complexity | Impact |
|-------|-------|------------|--------|
| [#109](https://github.com/seanthimons/serapeum/issues/109) | moonshot: Flag to disable AI features, pure abstract searching app | High | High |
| [#41](https://github.com/seanthimons/serapeum/issues/41) | moonshot: Full OpenAlex Corpus Ingestion | Very High | Very High |
| [#42](https://github.com/seanthimons/serapeum/issues/42) | moonshot: DuckDB Native Vector Search | High | High |

---

## Completed

- [x] Basic document notebooks with PDF upload
- [x] Search notebooks via OpenAlex
- [x] RAG chat with citations
- [x] Preset generation (summary, key points, etc.)
- [x] Settings page with model configuration
- [x] Quarto slide deck generation
- [x] [#5](https://github.com/seanthimons/serapeum/issues/5): Filter papers without abstracts
- [x] [#7](https://github.com/seanthimons/serapeum/issues/7): Retraction watch / junk journal filtering
- [x] [#13](https://github.com/seanthimons/serapeum/issues/13): Paper keywords from API
- [x] [#23](https://github.com/seanthimons/serapeum/issues/23): API key status indicators
- [x] OpenAlex Phase 1: Document type filter and badges
- [x] OpenAlex Phase 2: OA status badges and citation metrics
- [x] Deferred embedding workflow (Embed Papers button)
- [x] [#34](https://github.com/seanthimons/serapeum/issues/34): Embed count reflects filtered papers (PR #36)
- [x] [#35](https://github.com/seanthimons/serapeum/issues/35): Citation/reference display fix (PR #36)
- [x] [#45](https://github.com/seanthimons/serapeum/issues/45): About page layout overflow fix (PR #46)
- [x] [#47](https://github.com/seanthimons/serapeum/issues/47): API key status validates config.yaml on initial load (PR #47)
- [x] [#55](https://github.com/seanthimons/serapeum/issues/55): Fix abstract embedding (v1.0)
- [x] [#25](https://github.com/seanthimons/serapeum/issues/25): Seed paper for searching (v1.0)
- [x] [#10](https://github.com/seanthimons/serapeum/issues/10): Meta-prompt query builder (v1.0)
- [x] [#40](https://github.com/seanthimons/serapeum/issues/40): OpenAlex Topics & Discovery (v1.0)
- [x] [#43](https://github.com/seanthimons/serapeum/issues/43): Startup wizard UI (v1.0)
- [x] [#54](https://github.com/seanthimons/serapeum/issues/54): Rich sorting for search results (v1.0)
- [x] [#51](https://github.com/seanthimons/serapeum/issues/51): Slide citation CSS fix (v1.0)
- [x] [#19](https://github.com/seanthimons/serapeum/issues/19): OpenRouter cost tracking (v1.1 Phase 5)
- [x] [#20](https://github.com/seanthimons/serapeum/issues/20): Expanded model selection (v1.1 Phase 6)
- [x] [#17](https://github.com/seanthimons/serapeum/issues/17): Enhanced keyword tag behavior (v1.1 Phase 7)
- [x] [#26](https://github.com/seanthimons/serapeum/issues/26): Ban/hard filter for suspect journals (v1.1 Phase 8)
- [x] [#57](https://github.com/seanthimons/serapeum/issues/57): Seed discovery email prompt bug fix
- [x] [#59](https://github.com/seanthimons/serapeum/issues/59): Fix 401 error on OpenAlex topic searches (v1.2 Phase 9)
- [x] [#65](https://github.com/seanthimons/serapeum/issues/65): User-friendly API error messages (v1.2 Phase 9)
- [x] [#68](https://github.com/seanthimons/serapeum/issues/68): Fix tab-swap OpenAlex re-request (v1.2 Phase 9)
- [x] [#73](https://github.com/seanthimons/serapeum/issues/73): Collapsible Journal Quality card (v1.2 Phase 10)
- [x] [#72](https://github.com/seanthimons/serapeum/issues/72): Fix block badge vertical misalignment (v1.2 Phase 10)
- [x] [#66](https://github.com/seanthimons/serapeum/issues/66): DOI on abstract preview (v2.0 Phase 11)
- [x] [#53](https://github.com/seanthimons/serapeum/issues/53): Citation network graph for paper discovery (v2.0 Phase 12)
- [x] [#67](https://github.com/seanthimons/serapeum/issues/67): Export abstract to seeded paper search (v2.0 Phase 13)
- [x] [#64](https://github.com/seanthimons/serapeum/issues/64): Citation export - BibTeX/CSV (v2.0 Phase 14)
- [x] [#49](https://github.com/seanthimons/serapeum/issues/49): Export synthesis outputs as Markdown/HTML (v2.0 Phase 15)
- [x] [#50](https://github.com/seanthimons/serapeum/issues/50): Rich markdown rendering in chat windows (v2.0 Phase 15)
- [x] [#63](https://github.com/seanthimons/serapeum/issues/63): Additional synthesis outputs (v2.0 Phase 15)
- [x] [#69](https://github.com/seanthimons/serapeum/issues/69): Community standards (PR #70)
- [x] Citation network node sizing — cube-root transform + wider range (fix/citation-node-sizing)
- [x] Citation network self-loop filtering (fix/citation-node-sizing)
- [x] Citation network year-to-color percentile mapping (fix/citation-node-sizing)
- [x] Citation network physics auto-freeze + spacing (fix/citation-node-sizing)
- [x] [#80](https://github.com/seanthimons/serapeum/issues/80): Progress modal with stop button for citation network (v2.1 Phase 18)
- [x] [#33](https://github.com/seanthimons/serapeum/issues/33): Favicon (v2.1 Phase 16)
- [x] [#61](https://github.com/seanthimons/serapeum/issues/61): Conclusion synthesis icon (v2.1 Phase 16)
- [x] [#62](https://github.com/seanthimons/serapeum/issues/62): Preset icons (v2.1 Phase 16)
- [x] [#27](https://github.com/seanthimons/serapeum/issues/27): Conclusion synthesis → future directions (v2.1 Phase 19)
- [x] [#81](https://github.com/seanthimons/serapeum/issues/81): UI improvements to reclaim space (sidebar rebalance)
- [x] [#90](https://github.com/seanthimons/serapeum/issues/90): Move to renv for package namespace management
- [x] [#78](https://github.com/seanthimons/serapeum/issues/78): Set up GHA/local functions for RDS support files
- [x] [#77](https://github.com/seanthimons/serapeum/issues/77): ragnar package integration (v3.0)
- [x] [#91](https://github.com/seanthimons/serapeum/issues/91): Migrate existing PDF chunks to ragnar store (v3.0)
- [x] [#92](https://github.com/seanthimons/serapeum/issues/92): Migrate existing abstracts to ragnar store (v3.0)
- [x] [#93](https://github.com/seanthimons/serapeum/issues/93): search_chunks_hybrid fallback fix (v3.0)
- [x] [#94](https://github.com/seanthimons/serapeum/issues/94): Fix lossy metadata persistence (v3.0)
- [x] [#95](https://github.com/seanthimons/serapeum/issues/95): E2E test — PDF through ragnar query (v3.0)
- [x] [#96](https://github.com/seanthimons/serapeum/issues/96): E2E test — abstract through ragnar query (v3.0)
- [x] [#97](https://github.com/seanthimons/serapeum/issues/97): Benchmark hybrid vs legacy — obsolete (v3.0)
- [x] bug: Ragnar embed closure serialization — runtime `@embed` attachment bypasses broken deserialization (Phase 29)
- [x] fix: RAG retrieval path needs embed for query vectorization (Phase 29)
- [x] fix: Origin metadata suffix breaking notebook filter — all retrieved rows dropped (Phase 29)
- [x] fix: Stale ragnar chunks on document delete (Phase 29)
- [x] feat: Chat send button spinner during RAG processing (Phase 29, partial #87)
- [x] [#117](https://github.com/seanthimons/serapeum/issues/117): tech-debt: Connection leak in search_chunks_hybrid (v6.0)
- [x] [#116](https://github.com/seanthimons/serapeum/issues/116): [BUG] Cost tracking table update (v6.0)
- [x] [#114](https://github.com/seanthimons/serapeum/issues/114): Hide keywords panel (v6.0)
- [x] [#111](https://github.com/seanthimons/serapeum/issues/111): Modal repeats on abstract removal (v6.0)
- [x] [#110](https://github.com/seanthimons/serapeum/issues/110): Seed paper not showing in abstract search (v6.0)
- [x] [#98](https://github.com/seanthimons/serapeum/issues/98): Merge Summarize + Key Points into unified Overview (v6.0)
- [x] [#99](https://github.com/seanthimons/serapeum/issues/99): feat: Literature Review Table (v6.0)
- [x] [#102](https://github.com/seanthimons/serapeum/issues/102): feat: Research Question Generator (v6.0)
- [x] [#86](https://github.com/seanthimons/serapeum/issues/86): [BUG] Refresh button adding papers after removal (v6.0)
- [x] [#89](https://github.com/seanthimons/serapeum/issues/89): Citation network background color blending [gsd] (v6.0)
- [x] [#71](https://github.com/seanthimons/serapeum/issues/71): Seeded search same view as abstract preview (v6.0)
- [x] [#119](https://github.com/seanthimons/serapeum/issues/119): tech-debt: Remove dead code — with_ragnar_store() (v6.0)
- [x] [#121](https://github.com/seanthimons/serapeum/issues/121): Dark mode properly considered (v6.0)
- [x] [#123](https://github.com/seanthimons/serapeum/issues/123): UI touch ups (v6.0)
- [x] [#118](https://github.com/seanthimons/serapeum/issues/118): tech-debt: section_hint not encoded in PDF ragnar origins (v6.0)
- [x] [#124](https://github.com/seanthimons/serapeum/issues/124): Slide generation prompt tweak / healing
- [x] [#103](https://github.com/seanthimons/serapeum/issues/103): feat: Citation Audit — find missing seminal papers (v8.0)
- [x] [#24](https://github.com/seanthimons/serapeum/issues/24): feat: Bulk DOI upload (v7.0 Phase 35)
- [x] [#85](https://github.com/seanthimons/serapeum/issues/85): Select all to be imported into document notebook (v7.0 Phase 38)
- [x] [#113](https://github.com/seanthimons/serapeum/issues/113): Bulk upload for network analysis/seeding (v7.0/v8.0)
- [x] [#79](https://github.com/seanthimons/serapeum/issues/79): bug: Tooltip overflows graph container and overlaps side panel (v9.0 Phase 43)
- [x] [#127](https://github.com/seanthimons/serapeum/issues/127): bug: Tooltips on citation network impossible to read on dark mode (v9.0 Phase 43)
- [x] [#128](https://github.com/seanthimons/serapeum/issues/128): bug: Network graph year filters lower-bounds are wrong (v9.0 Phase 42)
- [x] [#129](https://github.com/seanthimons/serapeum/issues/129): feat: Trim network graph to only influential papers (v9.0 Phase 42)
- [x] [#130](https://github.com/seanthimons/serapeum/issues/130): Adjust network physics to restore rotation for smaller networks (v9.0 Phase 41)
- [x] [#131](https://github.com/seanthimons/serapeum/issues/131): bug: Network collapses to singularity when toggling physics (v9.0 Phase 41)
- [x] [#134](https://github.com/seanthimons/serapeum/issues/134): bug: Citation audit shows error when adding multiple papers (v10.0 Phase 46)
- [x] [#133](https://github.com/seanthimons/serapeum/issues/133): bug: Citation audit papers do not appear in abstract notebook (v10.0 Phase 46)
- [x] [#139](https://github.com/seanthimons/serapeum/issues/139): bug: UI adjustment to abstract buttons (v10.0 Phase 47)
- [x] [#137](https://github.com/seanthimons/serapeum/issues/137): bug: Fix sidebar colors + theming (v10.0 Phase 47)
- [x] [#138](https://github.com/seanthimons/serapeum/issues/138): Global color theme for buttons/UI (v10.0 Phase 45/47)
- [x] [#100](https://github.com/seanthimons/serapeum/issues/100): feat: Methodology Extractor preset (v10.0 Phase 48)
- [x] [#101](https://github.com/seanthimons/serapeum/issues/101): feat: Gap Analysis Report preset (v10.0 Phase 49)
- [x] [#88](https://github.com/seanthimons/serapeum/issues/88): Slim Conclusions preset — remove redundant gaps section (covered by Gap Analysis #101)
- [x] [#143](https://github.com/seanthimons/serapeum/issues/143): bug: Slider and histogram do not align on year filter (v11.0 Phase 56)
- [x] [#149](https://github.com/seanthimons/serapeum/issues/149): Major buttons should have tooltips (v12.0)
- [x] [#125](https://github.com/seanthimons/serapeum/issues/125): Update file/document filter types reported by OpenAlex (v13.0)
- [x] [#6](https://github.com/seanthimons/serapeum/issues/6): Timeline heatmap (v14.0)
- [x] feat: Community-aware edge weighting for citation network cluster separation
- [x] [#44](https://github.com/seanthimons/serapeum/issues/44): Epic: PDF Image Pipeline (v17.0)
- [x] [#38](https://github.com/seanthimons/serapeum/issues/38): PDF image extraction via page rendering + text-gap cropping (v17.0 Stage 1)
- [x] [#146](https://github.com/seanthimons/serapeum/issues/146): Figure storage schema & DB helpers (v17.0 Stage 2)
- [x] [#28](https://github.com/seanthimons/serapeum/issues/28): Caption extraction with continuation line following (v17.0 Stage 3)
- [x] [#148](https://github.com/seanthimons/serapeum/issues/148): Vision model figure description via GPT-4.1 Nano (v17.0 Stage 5)
- [x] [#37](https://github.com/seanthimons/serapeum/issues/37): Figure review & selection UI with gallery views (v17.0 Stage 6)
- [x] [#29](https://github.com/seanthimons/serapeum/issues/29): Figure injection into Quarto slides with manifest-driven selection (v17.0 Stage 7)
- [x] [#151](https://github.com/seanthimons/serapeum/issues/151): Per-abstract keyword ban/keep filtering (v13.0)
- [x] [#11](https://github.com/seanthimons/serapeum/issues/11): Recursive abstract searching — Research Refiner with Tier 1 citation scoring + Tier 2 semantic relevance via ragnar BM25+VSS (v13.0)
- [x] [#160](https://github.com/seanthimons/serapeum/issues/160): Research Refiner "From Notebook" anchor type — use entire notebook as seed set (v13.0)
- [x] [#145](https://github.com/seanthimons/serapeum/issues/145): Citation audit filters and controls — ASC/DESC sort, FWCI sort/filter, year range, min citations/frequency (v14.0)
- [x] [#135](https://github.com/seanthimons/serapeum/issues/135): Node sizing by citations, age-weighted, FWCI, or connectivity + FWCI in network tooltips (v14.0)
- [x] [#157](https://github.com/seanthimons/serapeum/issues/157): OA request usage tracking (v15.0)
- [x] [#142](https://github.com/seanthimons/serapeum/issues/142): Advanced Retrieval Pipeline — contextual headers, stale detection, query reformulation (v15.0)
- [x] [#48](https://github.com/seanthimons/serapeum/issues/48): Tighter RAG document retrieval controls (v15.0)
- [x] [#144](https://github.com/seanthimons/serapeum/issues/144): AA Integration + Split Models + Latency Tracking — provider abstraction, 3-slot routing, latency analytics, AA benchmarks (v15.0)
- [x] [#8](https://github.com/seanthimons/serapeum/issues/8): Local model support — multi-provider management, Ollama/LM Studio/vLLM endpoints (v15.0)

---

## Labels Guide

**Complexity** (effort required):
- `complexity:low` - Quick fix, < 1 hour
- `complexity:medium` - Half day to full day
- `complexity:high` - Multiple days or significant refactoring

**Impact** (value delivered):
- `impact:low` - Nice to have, minor improvement
- `impact:medium` - Improves workflow or fixes notable issue
- `impact:high` - Critical feature or blocking issue

**Priority** (derived from complexity + impact):
- `priority:high` - High impact + Low/Medium complexity (quick wins, critical fixes)
- `priority:medium` - Medium impact or High impact + High complexity
- `priority:low` - Low impact items

**Milestones** are tracked via [GitHub Milestones](https://github.com/seanthimons/serapeum/milestones), not labels.
