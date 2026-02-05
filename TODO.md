# TODO

Future enhancements for the Research Notebook tool.

## Priority Matrix

| Item | Effort | Impact | Priority Score |
|------|--------|--------|----------------|
| **Quick Wins (Low Effort, High Impact)** ||||
| #5: Filter papers without abstracts | Low | High | ★★★★★ |
| #13: Paper keywords from API | Low | Medium | ★★★★ |
| **Strategic (Medium Effort, High Impact)** ||||
| #10: Meta-prompt for query building | Medium | High | ★★★★ |
| #4: Enhanced OpenAlex filters | Medium | High | ★★★★ |
| **Investments (High Effort, High Impact)** ||||
| #7: Retraction/junk journal filtering | High | High | ★★★ |
| #8: Local model support | High | High | ★★★ |
| #11: Recursive abstract searching | High | High | ★★★ |
| **Moderate Value** ||||
| #1: Cost tracking | Medium | Medium | ★★★ |
| #2: Expanded model selection | Medium | Medium | ★★★ |
| **Low Priority** ||||
| #6: Timeline heatmap | Medium | Low | ★★ |
| #9: Versioning | Low | Low | ★★ |
| #3: Semantic Scholar | High | Low | ★ |
| #7: Audio overview | Very High | Medium | ★ |
| **Research Needed** ||||
| #12: Evaluate reranker need | Low | TBD | — |

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

Add more granular filtering options to the abstract search feature.

### High Priority Filters
- [ ] Document type (`type`: article, preprint, review, book, dissertation)
- [ ] Author institution country (`authorships.institutions.country_code`)
- [ ] Minimum citations (`cited_by_count:>N`)
- [ ] Granular OA status (`oa_status`: gold, green, hybrid, bronze, closed)
- [ ] Language filter (`language`: ISO codes like en, es, zh)

### Medium Priority Filters
- [ ] Journal/Source by ISSN (`primary_location.source.issn`)
- [ ] Topics/Concepts (`primary_topic.id`, `concepts.id`)
- [ ] Keywords (`keywords.keyword`)

### Limitations to Note
- No direct author name text search (requires OpenAlex ID or ORCID)
- Journal search requires ID/ISSN, no text search for journal names

### UI Considerations
- Keep the modal clean - consider "Advanced" expandable section
- Query preview already shows constructed filter string

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

### #5: Filter to remove papers without abstracts
**Effort:** Low | **Impact:** High

More relevant for Search Notebook - if you want to chat about a paper and it doesn't have an abstract, probably not great.

- [ ] Add filter at search query or paper list to keep/remove papers without abstracts

---

### #6: Timeline heatmap
**Effort:** Medium | **Impact:** Low

Feature to see a histogram/heatmap of papers for the given year range. Visually appealing even if not critical for tight ranges.

- [ ] Display histogram/heatmap of papers by year
- [ ] Inspiration: Google Trends timeline

---

### #7: Retraction watch / junk journal filtering / journal impact
**Effort:** High | **Impact:** High

Shouldn't include retracted papers. Need reliable source for junk journal registries.

- [ ] Filter out retracted papers (check OpenAlex/Semantic Scholar handling)
- [ ] Find junk journal registry source, add filter option
- [ ] Evaluate journal impact/citation counts for "most-relevant" view

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

### #13: Get paper keywords from API
**Effort:** Low | **Impact:** Medium (enables #10)

Feed into #10 (meta-prompt feature).

- [ ] Fetch paper keywords from OpenAlex API
- [ ] Use to help keep/remove abstracts

---

## 🚀 Moonshot Goals

High-effort / high-payoff features for the future.

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
