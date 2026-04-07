# Assimilate Report: Scientific-Papers-MCP
Direction: data sources, DOI resolution pathway
Source: https://github.com/benedict2310/Scientific-Papers-MCP
Date: 2026-03-23

## Current Repo Profile
**Serapeum** -- R/Shiny + bslib research assistant. Uses DuckDB for local storage, OpenAlex for academic paper search, OpenRouter for LLM/embeddings. Has DOI normalization (`utils_doi.R`), bulk import, citation export, quality filters (retraction watch, predatory publisher checks). Currently OpenAlex is the **only** academic data source.

## Source Repo Profile
**Scientific-Papers-MCP** -- TypeScript MCP server (v0.1.40). Aggregates 6 academic paper sources: arXiv, OpenAlex, PubMed Central, Europe PMC, bioRxiv/medRxiv, CORE. Has a 3-tier DOI resolution chain (Unpaywall -> Crossref -> Semantic Scholar), HTML/PDF text extraction, token-bucket rate limiting, and LRU caching. Stateless -- no database.

## Architecture Delta
| Dimension | Serapeum | Source |
|-----------|----------|--------|
| Language | R | TypeScript |
| Framework | Shiny + bslib | MCP SDK |
| HTTP client | httr2 | axios |
| Storage | DuckDB | None (stateless) |
| Data model | Rich (abstracts, documents, chunks, notebooks) | Flat (PaperMetadata) |

**Key implication**: No code is directly portable. Everything is "Adapt" or "Data only" -- we're extracting API endpoints, field mappings, and resolution logic patterns to rewrite in R.

---

## Findings (ranked by practical value)

### 1. [HIGH] DOI Resolution Fallback Chain (Unpaywall -> Crossref -> Semantic Scholar)
- **What**: 3-tier DOI resolver that tries Unpaywall first (OA detection + PDF URLs), falls back to Crossref (publisher metadata + text-mining links), then Semantic Scholar (open access PDFs). Includes LRU cache (10k entries, 24h TTL) and per-service rate limiting.
- **Where**: `src/resolvers/doi-resolver.ts`
- **Extractability**: Adapt
- **Effort**: Medium
- **Why it is useful**: Serapeum currently has NO DOI resolution beyond OpenAlex. When OpenAlex lacks a PDF URL or OA location, there's no fallback. This chain would dramatically improve full-text retrieval success rates.
- **How to adapt**:
  1. Create `R/api_doi_resolver.R` with three functions: `resolve_via_unpaywall(doi)`, `resolve_via_crossref(doi)`, `resolve_via_s2ag(doi)`
  2. Wrap in `resolve_doi(doi)` that tries each in order, returns first success
  3. Cache results in DuckDB table (`doi_resolutions`: doi, pdf_url, landing_url, source, is_oa, license, resolved_at)
  4. API details:
     - Unpaywall: `GET https://api.unpaywall.org/v2/{doi}?email={email}` -- use `best_oa_location.url_for_pdf`
     - Crossref: `GET https://api.crossref.org/works/{doi}` -- check `message.link[]` for `intended-application: "text-mining"`
     - Semantic Scholar: `GET https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=openAccessPdf,url,isOpenAccess`

### 2. [HIGH] Unpaywall API Integration
- **What**: Free API (100k req/day) that resolves DOIs to open access locations with license info. No API key needed, just polite email.
- **Where**: `src/resolvers/doi-resolver.ts` (resolveWithUnpaywall method)
- **Extractability**: Data only (endpoint + field mapping)
- **Effort**: Low
- **Why it is useful**: Serapeum's quality filter already checks OA status via OpenAlex. Unpaywall is the authoritative OA source and would improve PDF URL discovery for the document import pipeline.
- **How to adapt**:
  - Endpoint: `https://api.unpaywall.org/v2/{doi}?email=thimons.sean@epa.gov`
  - Key fields: `is_oa`, `best_oa_location.url_for_pdf`, `best_oa_location.url_for_landing_page`, `best_oa_location.license`
  - Fallback: iterate `oa_locations[]` if `best_oa_location` is null

### 3. [HIGH] Crossref API Client
- **What**: Direct Crossref metadata lookup by DOI. Returns publisher links, text-mining URLs, license info, and richer bibliographic metadata than OpenAlex provides for some records.
- **Where**: `src/resolvers/doi-resolver.ts` (resolveWithCrossref method)
- **Extractability**: Data only
- **Effort**: Low
- **Why it is useful**: Serapeum has NO direct Crossref integration. OpenAlex proxies some Crossref data but loses fields like text-mining links and license details. Crossref is the canonical DOI registrar.
- **How to adapt**:
  - Endpoint: `https://api.crossref.org/works/{doi}`
  - Key fields: `message.URL`, `message.link[]` (filter for `content-type: "application/pdf"`), `message.license[].URL`
  - Rate limit: 50 req/sec (very generous)
  - Add `User-Agent` header with email for polite pool

### 4. [HIGH] Semantic Scholar API for Citation Context
- **What**: S2AG provides paper lookup by DOI with open access PDF detection and semantic paper IDs.
- **Where**: `src/resolvers/doi-resolver.ts` (resolveWithS2AG method)
- **Extractability**: Data only
- **Effort**: Low
- **Why it is useful**: Third fallback for PDF discovery. Also provides a pathway to future enrichment -- S2AG has citation context, influential citations, and TLDR summaries (fields not used by source repo but available).
- **How to adapt**:
  - Endpoint: `https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=paperId,externalIds,openAccessPdf,url,isOpenAccess`
  - Key fields: `openAccessPdf.url`, `openAccessPdf.status` (GOLD/GREEN), `isOpenAccess`
  - Rate limit: 100 req/min

### 5. [MEDIUM] Europe PMC as Additional Search Source
- **What**: REST API for life sciences literature. 14 biomedical categories, MeSH term support, full-text search, OA filtering.
- **Where**: `src/drivers/europepmc-driver.ts`
- **Extractability**: Adapt
- **Effort**: Medium
- **Why it is useful**: Serapeum focuses on OpenAlex which is broad but thin on biomedical full-text. Europe PMC has `has_fulltext:y` filtering and direct XML access to full articles.
- **How to adapt**:
  - Endpoint: `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query={query} AND has_fulltext:y&format=json&pageSize={n}&sort=date desc`
  - Field mapping to abstracts table: `title`, `authorString` (parse by comma), `pubYear`, `doi`, `pmcid`, `isOpenAccess`, `citedByCount`
  - Would need a new driver function in `api_openalex.R` or a new `api_europepmc.R`

### 6. [MEDIUM] bioRxiv/medRxiv API for Preprints
- **What**: Simple JSON API to fetch recent preprints by date range and category. 68 subject categories across both servers.
- **Where**: `src/drivers/biorxiv-driver.ts`
- **Extractability**: Data only
- **Effort**: Low
- **Why it is useful**: Serapeum can search OpenAlex for preprints but has no direct preprint server access. bioRxiv/medRxiv APIs return structured data with abstracts, version tracking, and publication status.
- **How to adapt**:
  - Endpoint: `https://api.biorxiv.org/details/biorxiv/{fromDate}/{toDate}` (same pattern for medrxiv)
  - Returns: doi, title, authors, date, category, abstract, version, type (new/revision)
  - Rate limit: 5 req/min

### 7. [MEDIUM] CORE API for Open Access Aggregation
- **What**: Aggregates 200M+ open access documents. POST-based search with optional API key for higher limits.
- **Where**: `src/drivers/core-driver.ts`
- **Extractability**: Data only
- **Effort**: Low-Medium
- **Why it is useful**: CORE often has full text and download URLs for papers that aren't OA through the publisher. Good complement to Unpaywall.
- **How to adapt**:
  - Search: `POST https://api.core.ac.uk/v3/search/works` with `{"q": "{query}", "limit": 100, "exclude_without_fulltext": true}`
  - Work details: `GET https://api.core.ac.uk/v3/works/{id}`
  - Key fields: `downloadUrl` (direct PDF), `fullText` (sometimes inline), `doi`
  - Optional: `CORE_API_KEY` env var for higher rate limits

### 8. [MEDIUM] DOI Normalization Logic
- **What**: Strips `https://doi.org/`, `dx.doi.org/`, `doi:` prefixes, lowercases, trims.
- **Where**: `src/resolvers/doi-resolver.ts` (normalizeDOI method)
- **Extractability**: Inspiration
- **Effort**: None
- **Why it is useful**: Serapeum already has `normalize_doi_bare()` in `utils_doi.R` that does the same thing with a Crossref-recommended regex. Source repo's approach is simpler but less thorough. **No action needed** -- serapeum's version is better.

### 9. [LOW] Token Bucket Rate Limiter
- **What**: Per-source rate limiting with configurable tokens and refill rates.
- **Where**: `src/core/rate-limiter.ts`
- **Extractability**: Inspiration
- **Effort**: Medium
- **Why it is useful**: Serapeum currently has no rate limiting on API calls. If adding 3+ new API sources, a rate limiter would prevent accidental abuse.
- **How to adapt**: R implementation could use a simple environment/closure tracking last-request timestamps per source. Or use `httr2::req_throttle()` which already provides this.

### 10. [LOW] arXiv Category System
- **What**: 8 predefined arXiv categories with search via Atom XML API.
- **Where**: `src/drivers/arxiv-driver.ts`, `src/config/constants.ts`
- **Extractability**: Data only
- **Effort**: Medium
- **Why it is useful**: arXiv is already searchable via OpenAlex. Direct arXiv API would only add value for very recent preprints (last few hours) not yet indexed by OpenAlex.

---

## Quick Wins
- **Unpaywall lookup function** -- single `httr2::request()` call, ~30 min to implement and test
- **Crossref DOI metadata function** -- single `httr2::request()` call, ~30 min
- **Semantic Scholar PDF lookup** -- single `httr2::request()` call, ~20 min
- **Wire all three into a `resolve_doi()` fallback chain** -- ~30 min after individual functions exist
- **bioRxiv date-range query** -- single endpoint, simple JSON response, ~30 min

## Not Worth It
- **MCP server architecture** -- Serapeum is a Shiny app, not an MCP server. The MCP tool definitions and protocol handling are irrelevant.
- **HTML text extraction (Cheerio-based)** -- Serapeum already uses `pdftools` for PDF text extraction and stores full text in DuckDB. The HTML extraction pipeline is TypeScript-specific and would need complete rewrite.
- **PDF extraction via pdf-parse** -- Serapeum already has this via `pdftools::pdf_text()`.
- **arXiv direct API** -- OpenAlex already indexes arXiv with richer metadata. Direct arXiv adds marginal value for significant effort (XML parsing in R).
- **PubMed Central E-utilities** -- Complex XML API with R-unfriendly response format. Europe PMC provides equivalent data with a cleaner REST/JSON interface.
