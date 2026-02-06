# TODO

Future enhancements for the Research Notebook tool.

## Priority Matrix

| Item | Effort | Impact | Priority Score |
|------|--------|--------|----------------|
| **Quick Wins (Low Effort, High Impact)** ||||
| ~~#5: Filter papers without abstracts~~ | ~~Low~~ | ~~High~~ | ✅ DONE |
| ~~#13: Paper keywords from API~~ | ~~Low~~ | ~~Medium~~ | ✅ DONE |
| ~~#14: API key status indicators (GH #23)~~ | ~~Low~~ | ~~Medium~~ | ✅ DONE |
| ~~#4 Phase 2: OA Status & Citations~~ | ~~Low~~ | ~~High~~ | ✅ DONE |
| **Strategic (Medium Effort, High Impact)** ||||
| #10: Meta-prompt for query building (GH #10) | Medium | High | ★★★★ |
| #4 Phase 3: Topics & Discovery | Medium | High | ★★★★ |
| #25: Seed paper for searching (GH #25) | Medium | High | ★★★★ |
| **Investments (High Effort, High Impact)** ||||
| ~~#7: Retraction/junk journal filtering~~ | ~~High~~ | ~~High~~ | ✅ DONE |
| #8: Local model support (GH #8) | High | High | ★★★ |
| #11: Recursive abstract searching (GH #11) | High | High | ★★★ |
| #27: Conclusion synthesis → future directions (GH #27) | High | High | ★★★ |
| **Moderate Value** ||||
| #1: Cost tracking (GH #19) | Medium | Medium | ★★★ |
| #2: Expanded model selection (GH #20) | Medium | Medium | ★★★ |
| #17: Enhanced keyword tag behavior (GH #17) | Medium | Medium | ★★★ |
| #26: Ban/hard filter for suspect journals (GH #26) | Low | Medium | ★★★ |
| **Low Priority** ||||
| #6: Timeline heatmap (GH #6) | Medium | Low | ★★ |
| #9: Versioning (GH #9) | Low | Low | ★★ |
| #3: Semantic Scholar (GH #21) | High | Low | ★ |
| Audio overview (GH #22) | Very High | Medium | ★ |
| #30: Demo mode (GH #30) | Medium | Low | ★★ |
| **Research Needed** ||||
| #12: Evaluate reranker need (GH #12) | Low | TBD | — |
| **Slide Enhancement** ||||
| #28: Image/table/chart extraction (GH #28) | High | High | ★★★ |
| #29: Image/chart injection into slides (GH #29) | High | High | ★★★ |

---

## 1. OpenRouter Cost Tracking

**Effort:** Medium | **Impact:** Medium

Track API costs from OpenRouter for transparency and budget management.

- [ ] Fetch model pricing from OpenRouter API
- [ ] Log token usage per request (prompt + completion tokens)
- [ ] Calculate cost per request based on model pricing
- [ ] Display running total in UI (Settings or dedicated page)
- [ ] Option to set budget alerts/limits

**Reference:** [OpenRouter API - Models](https://openrouter.ai/docs#models)

---

## 2. Expanded Model Selection

**Effort:** Medium | **Impact:** Medium

Add more high-quality models for chat and embeddings.

### Chat Models
- [ ] Fetch available models from OpenRouter dynamically
- [ ] Filter/categorize by capability (chat, code, etc.)

### Embedding Models
- [ ] Use top performers from MTEB leaderboard
- [ ] Reference: https://huggingface.co/spaces/mteb/leaderboard
- [ ] Consider adding:
  - [ ] Cohere embed-v3
  - [ ] Voyage AI models
  - [ ] BGE models (if available via OpenRouter)
- [ ] Allow custom embedding endpoint configuration

---

## 3. Semantic Scholar Integration

**Effort:** High | **Impact:** Low (OpenAlex works well)

Re-add Semantic Scholar as an alternative/additional paper source.

- [ ] Apply for API key: https://www.semanticscholar.org/product/api
- [ ] Implement endpoints following their strict specs
- [ ] Paper search endpoint
- [ ] Paper details endpoint
- [ ] Author search
- [ ] Citation/reference traversal
- [ ] Whole corpus download option (for offline/local search)
  - Reference: https://www.semanticscholar.org/product/api#datasets

**Note:** API approval process can be slow. Follow rate limits strictly.

---

## 4. Enhanced OpenAlex Search Filters

**Effort:** Medium | **Impact:** High

Add more granular filtering and richer metadata extraction from OpenAlex.

### Phase 1: Document & Paper Type ✅ COMPLETED
| Item | Effort | Impact | Status |
|------|--------|--------|--------|
| Document type filter (`type`: article, preprint, review, book, dissertation) | Low | High | ✅ Done |
| Extract & display document type in UI | Low | High | ✅ Done |
| Type distribution bar chart in Edit Search modal | Low | Medium | ✅ Done |
| Color-coded type badges in paper list and detail view | Low | Medium | ✅ Done |

### Phase 2: OA Status & Citations ✅ COMPLETED
| Item | Effort | Impact | Status |
|------|--------|--------|--------|
| Granular OA status filter (`oa_status`: gold, green, hybrid, bronze, closed) | Low | High | ✅ Done (display only, filter in Phase 3) |
| Display OA status badges in paper list | Low | Medium | ✅ Done |
| Extract `referenced_works_count` (outgoing citations) | Low | Medium | ✅ Done |
| Extract FWCI (field-weighted citation impact) | Low | Medium | ✅ Done |
| Display citation metrics row (cited-by, FWCI, refs) | Low | Medium | ✅ Done |

### Phase 3: Topics & Discovery
| Item | Effort | Impact | Status |
|------|--------|--------|--------|
| Extract `primary_topic` hierarchy (domain → field → subfield → topic) | Medium | High | Pending |
| Display topic info in paper detail view | Low | Medium | Pending |
| Topic-based search suggestions (feeds into #10) | Medium | High | Pending |

### Phase 4: Additional Filters
| Item | Effort | Impact | Status |
|------|--------|--------|--------|
| Language filter (`language`: ISO codes like en, es, zh) | Low | Medium | Pending |
| Author institution country (`authorships.institutions.country_code`) | Low | Medium | Pending |
| Journal/Source by ISSN (`primary_location.source.issn`) | Medium | Low | Pending |

### Limitations to Note
- No direct author name text search (requires OpenAlex ID or ORCID)
- Journal search requires ID/ISSN, no text search for journal names
- FWCI may be null for very recent papers

### UI Considerations
- Keep the modal clean - consider "Advanced" expandable section
- Query preview already shows constructed filter string
- Use color-coded badges for OA status and document type

**Reference:** https://docs.openalex.org/api-entities/works/filter-works

---

## 5. ~~DuckDB Native Vector Search~~

**Moved to Moonshot Goals section** - see 🚀 Moonshot Goals below.

---

## 6. Quarto Slide Deck Generation

**Priority:** ~~Medium-High~~ **COMPLETED**

Generate presentation slides from notebook content using Quarto RevealJS.

### Core Features
- [x] "Generate Slides" button in notebook view
- [x] LLM extracts key points, findings, and structure from chunks
- [x] Generate Quarto `.qmd` file with RevealJS format
- [x] Support different slide styles/themes (11 RevealJS themes)
- [x] Include citations from source documents (configurable style)

### Slide Generation Options
- [x] Presentation length (short/medium/long → slide count)
- [x] Audience level (technical, executive, general)
- [x] Focus area (select specific documents to include)
- [x] Include/exclude speaker notes
- [x] Model selection for generation
- [x] Custom instructions field

### Output
- [x] Preview rendered slides in-app (iframe)
- [x] Download `.qmd` source file for customization
- [x] Export to PDF/HTML directly

### Technical Approach
- [x] Use LLM to structure content into logical sections
- [x] Generate YAML frontmatter with RevealJS options
- [x] Create hierarchical slides (# for sections, ## for slides)
- [x] Auto-generate speaker notes from fuller context
- [ ] Handle images/figures from PDFs → **See Moonshot Goals: PDF Image Extraction**

### References
- Quarto RevealJS: https://quarto.org/docs/presentations/revealjs/
- RevealJS themes: https://quarto.org/docs/presentations/revealjs/#themes

---

## 7. Audio Overview Generation (Future)

**Effort:** Very High | **Impact:** Medium

Generate podcast-style audio summaries of notebook content.

- [ ] Research TTS APIs (ElevenLabs, OpenAI TTS, Azure)
- [ ] Generate conversational script from content
- [ ] Multi-voice dialogue option (NotebookLM style)
- [ ] Background music/transitions
- [ ] Export as MP3/WAV

**Note:** More complex than slides - requires TTS API integration and audio processing.

---

## GitHub Issues (Open)

### ~~#5: Filter to remove papers without abstracts~~ ✅ COMPLETED

Implemented: Checkbox filter, X button on papers, keyword click-to-delete, exclusion tracking.

---

### #6: Timeline heatmap
**Effort:** Medium | **Impact:** Low

Feature to see a histogram/heatmap of papers for the given year range. Visually appealing even if not critical for tight ranges.

- [ ] Display histogram/heatmap of papers by year
- [ ] Inspiration: Google Trends timeline

---

### ~~#7: Retraction watch / junk journal filtering / journal impact~~ ✅ COMPLETED

Implemented in PR #16:
- [x] Exclude retracted papers via OpenAlex API (`is_retracted:false`)
- [x] Flag predatory journals/publishers with ⚠️ warning icon
- [x] Local cache of quality data (Retraction Watch ~50k, predatoryjournals.org ~3k)
- [x] Download quality data from Settings page
- [x] Optional minimum citations filter

---

### #8: Local model support
**Effort:** High | **Impact:** High

Needs both chat models and embedding support for local/offline use.

- [ ] Add wiring for local chat models
- [ ] Add wiring for local embedding models

---

### #9: Versioning for releases
**Effort:** Low | **Impact:** Low

Changelog, new features, broken features/issues tracking.

- [ ] Add version numbering system
- [ ] Create changelog
- [ ] Track releases

---

### #10: Meta-prompt for query building
**Effort:** Medium | **Impact:** High

Popup window to help create the best query terms for abstract search (AND vs OR vs ...).

- [ ] Popup UI for query construction
- [ ] List of tags that can be removed
- [ ] Output must be OpenAlex API compliant

---

### #11: Recursive abstract searching
**Effort:** High | **Impact:** High

Sometimes the search query isn't perfect. Need a way to refine until the "perfect" set is found.

- [ ] Use embeddings to check closeness with desired search query
- [ ] Remove abstracts until {k} quality abstracts remain
- [ ] Assess embedding costs per abstract vs bulk
- [ ] Handle large OpenAlex requests for sufficient {k}

---

### #12: Evaluate reranker model need
**Effort:** Low | **Impact:** TBD (research)

Research question: Is there a need? What's the cost vs benefit?

- [ ] Research reranker models
- [ ] Evaluate cost/benefit for this use case

---

### ~~#13: Get paper keywords from API~~ ✅ COMPLETED

Implemented: Keywords extracted from OpenAlex (display_name field), displayed as clickable badges in keyword panel.

- [ ] Fetch paper keywords from OpenAlex API
- [ ] Use to help keep/remove abstracts

---

### ~~#14: API key status indicators~~ ✅ COMPLETED

Implemented in PR #31:
- [x] Add status indicator to API key input fields in Settings
- [x] Show checkmark or success icon when key is valid
- [x] Show red X when key is empty, red ! when invalid
- [x] Auto-validate on blur with 1-second debounce
- [x] OpenRouter validates via `/models` endpoint
- [x] OpenAlex validates via minimal API ping

---

### #17: Enhanced keyword tag behavior
**Effort:** Medium | **Impact:** Medium

Change tag cloud behavior to support include/exclude filtering by keyword.

- [ ] Remove papers with specific keyword (current: click to delete all with tag)
- [ ] Keep ONLY papers with specific keyword
- [ ] Add keyword to search query (relates to #10, #11)

---

### #25: Seed paper for searching (GH #25)
**Effort:** Medium | **Impact:** High

Use a known good paper as a seed to find similar papers.

- [ ] Input a DOI or OpenAlex ID as a seed paper
- [ ] Fetch cited-by and references from seed paper
- [ ] Use seed paper's topics/keywords to expand search
- [ ] Option to find papers that cite the same references

---

### #26: Ban/hard filter for suspect journals (GH #26)
**Effort:** Low | **Impact:** Medium

Extend quality filtering to allow hard exclusion of flagged papers.

- [ ] Option to completely hide (not just flag) predatory journal papers
- [ ] User-defined blocklist of journals/publishers
- [ ] Persist exclusion preferences

---

### #27: Conclusion synthesis → future directions (GH #27)
**Effort:** High | **Impact:** High

Synthesize conclusions across papers to generate future research directions.

- [ ] Extract conclusion sections from papers
- [ ] Identify common themes and gaps
- [ ] Generate "future directions" synthesis
- [ ] Highlight contradictions or debates in literature

---

### #28: Image/table/chart extraction (GH #28)
**Effort:** High | **Impact:** High

Extract visual elements from PDFs for reuse.

- [ ] Research PDF image extraction libraries
- [ ] Extract figures with captions
- [ ] Extract tables (OCR or structured extraction)
- [ ] Store extracted visuals with metadata

---

### #29: Image/chart injection into slides (GH #29)
**Effort:** High | **Impact:** High

Intelligently insert extracted images into generated slide decks.

- [ ] Match figures to relevant slide content
- [ ] Auto-caption using vision models
- [ ] Handle image quality and formatting
- [ ] Generate proper attribution

---

### #30: Demo mode (GH #30)
**Effort:** Medium | **Impact:** Low

Run app without API keys for demonstration purposes.

- [ ] Mock API responses for demo
- [ ] Pre-loaded sample notebooks
- [ ] Clear indication of demo mode limitations

---

## 🚀 Moonshot Goals

High-effort / high-payoff features for the future.

### Bulk DOI Upload (GH #24)

**Effort:** High | **Payoff:** Medium

Allow users to paste/upload a list of DOIs and fetch paper metadata from OpenAlex in bulk.

- [ ] Text area for pasting DOIs (one per line or comma-separated)
- [ ] CSV/TXT file upload option
- [ ] Parse and validate DOI format
- [ ] Batch query OpenAlex API (respect rate limits, ~50 DOIs per request)
- [ ] Handle missing/invalid DOIs gracefully
- [ ] Progress indicator for large batches

**Use cases:** Import from Zotero/Mendeley, recreate lit review from bibliography, add syllabus papers.

---

### Full OpenAlex Corpus Ingestion

**Effort:** Very High | **Payoff:** Very High

Download and index the entire OpenAlex dataset (300+ GB) for offline, unlimited local search.

- [ ] Set up storage infrastructure for 300+ GB dataset
- [ ] Download OpenAlex snapshot (S3 bucket or data dump)
- [ ] Design schema for local DuckDB/PostgreSQL storage
- [ ] Build incremental update pipeline (OpenAlex updates weekly)
- [ ] Index abstracts and metadata for fast full-text search
- [ ] Generate embeddings for semantic search (requires massive compute)
- [ ] Build efficient query interface matching OpenAlex API

**Challenges:**
- Storage: 300+ GB compressed, much larger uncompressed
- Compute: Embedding 200M+ abstracts is expensive (weeks of GPU time or $$$ API costs)
- Updates: Keeping in sync with weekly OpenAlex releases
- Infrastructure: Need robust ETL pipeline

**References:**
- OpenAlex Data Snapshot: https://docs.openalex.org/download-all-data/openalex-snapshot
- AWS S3 bucket: `s3://openalex`

**Prerequisite:** DuckDB Native Vector Search (below) for querying at scale

---

### PDF Image Extraction & Slide Insertion

**Effort:** Very High | **Payoff:** Very High

Extract figures, charts, and diagrams from PDFs and intelligently insert them into generated slide decks.

- [ ] Research PDF image extraction libraries (pdf-poppler, pdfimages, PyMuPDF)
- [ ] Extract images with bounding boxes and page context
- [ ] Use vision model to caption/describe extracted figures
- [ ] Match figures to relevant slide content during generation
- [ ] Handle figure quality (resolution, format conversion)
- [ ] Auto-crop whitespace and clean up extracted images
- [ ] Generate proper image attribution/citations

**Challenges:**
- PDF figure extraction is notoriously unreliable
- Figures span pages, have embedded text, varying quality
- Matching figures to slide content requires multimodal understanding

---

### DuckDB Native Vector Search (Large-Scale RAG)

**Effort:** High | **Payoff:** High

Move from R-based cosine similarity to in-database vector search for 100k+ chunk collections.

- [ ] Install DuckDB `vss` extension (manual install on Windows)
- [ ] Use `array_cosine_similarity()` in SQL
- [ ] Investigate HNSW index for approximate nearest neighbor
- [ ] Benchmark R-based vs DuckDB-native at scale

**References:**
- https://duckdb.org/docs/extensions/vss.html

**Note:** This is a prerequisite for Full OpenAlex Corpus Ingestion above.

---

## Completed

- [x] Basic document notebooks with PDF upload
- [x] Search notebooks via OpenAlex
- [x] RAG chat with citations
- [x] Preset generation (summary, key points, etc.)
- [x] Settings page with model configuration
- [x] Quarto slide deck generation
- [x] **#5**: Filter papers without abstracts (checkbox, X button, keyword delete, exclusion tracking)
- [x] **#13**: Paper keywords from OpenAlex API (keyword panel with counts, click-to-delete)
- [x] Deferred embedding workflow (Embed Papers button instead of auto-embed)
- [x] **#7**: Quality filters (retraction exclusion, predatory journal flagging, citation filter)
- [x] **#4 Phase 1**: Document type filter and badges (article, review, preprint, etc.)
- [x] **#14**: API key status indicators (GH #23) - visual validation in Settings
- [x] **#4 Phase 2**: OA status badges and citation metrics (cited-by, FWCI, refs)
