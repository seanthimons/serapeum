# Assimilate Report: liteparse

Direction: Evaluate as PDF preparsing dependency for speed + accuracy of table/fig extraction
Source: https://github.com/run-llama/liteparse
Date: 2026-03-29

## Current Repo Profile (Serapeum)

- **Stack:** R/Shiny + bslib + DuckDB + ragnar (RAG)
- **PDF pipeline:** pdftools (`pdf_text()`, `pdf_data()`, `pdf_render_page()`) → ragnar semantic chunking → DuckDB storage → embedding → hybrid search
- **Figure extraction:** Custom R pipeline (gap detection + caption matching + vision API description) — sophisticated but R-native
- **OCR:** None. Scanned PDFs are silently skipped (0 text boxes → no content)
- **Table extraction:** Tables captured as PNG screenshots via figure pipeline, not as structured data

## Source Repo Profile (liteparse)

- **Stack:** TypeScript/Node.js (ESM), monorepo
- **Core engines:** PDF.js (text extraction) + PDFium (rendering) + Tesseract.js (OCR) + optional HTTP OCR servers
- **Key innovation:** Grid projection algorithm (~1,650 lines) that reconstructs spatial layout from raw PDF text coordinates using anchor detection, column inference, and rotation handling
- **Output:** JSON (structured textItems with x/y/width/height/font/confidence per word) or plain text with spatial layout preserved
- **License:** Apache 2.0
- **Version:** 1.4.1 (active development)
- **Size:** ~7,100 lines TypeScript, 39 source files

## Architecture Delta

| Dimension | Serapeum | liteparse |
|-----------|----------|-----------|
| Language | R | TypeScript/Node.js |
| Runtime | R process | Node.js >= 18 |
| PDF library | pdftools (poppler) | PDF.js (Mozilla) |
| OCR | None | Tesseract.js + pluggable HTTP OCR |
| Table handling | Screenshot → PNG | Spatial text reconstruction |
| Figure handling | Render + gap detect + vision API | Image extraction + OCR text only |
| Output | R data frames | JSON / plain text |
| Integration model | In-process R functions | CLI (`lit parse`) or Node.js library |

**Critical gap:** liteparse is Node.js. Serapeum is R. Integration requires either CLI subprocess calls or a local HTTP wrapper — not a direct R library import.

## Findings (ranked by practical value)

### 1. [HIGH] OCR for Scanned PDFs — Fills Serapeum's Biggest Gap
- **What**: Selective OCR that only processes text-sparse pages (<100 chars) and embedded images. Tesseract.js built-in, zero setup.
- **Where**: `src/engines/ocr/tesseract.ts`, `src/core/parser.ts`
- **Extractability**: Adapt (CLI subprocess from R)
- **Effort**: Medium
- **Why it is useful**: Serapeum currently **silently drops** scanned PDFs. This is the #1 data loss vector for academic papers (older journals, dissertations, conference proceedings).
- **How to adapt**: Call `lit parse --ocr scanned.pdf` from R via `system2()` or `processx::run()`, parse JSON output back into R data frames.

### 2. [HIGH] Spatial Layout Reconstruction for Tables
- **What**: Grid projection algorithm that preserves column alignment, detects multi-column layouts, and maintains spatial relationships between text items.
- **Where**: `src/processing/gridProjection.ts` (1,947 lines)
- **Extractability**: Inspiration / Adapt via CLI
- **Effort**: Low (use as-is via CLI) or Very High (port to R)
- **Why it is useful**: Serapeum's current table handling captures tables as PNGs — useful for display but unusable for search, comparison, or structured extraction. liteparse's spatial text output preserves table structure as text with precise coordinates.
- **Limitation**: liteparse does NOT do explicit table detection or cell extraction. It preserves spatial layout, which makes tables *readable as text* but doesn't produce structured row/column data. For true structured table extraction, you'd still need a downstream parser on the spatial output.

### 3. [MEDIUM] JSON Output with Per-Word Coordinates
- **What**: Structured JSON output with every text item's x, y, width, height, fontName, fontSize, and confidence score.
- **Where**: `src/output/json.ts`, `src/core/types.ts`
- **Extractability**: Direct use (parse JSON in R)
- **Effort**: Low
- **Why it is useful**: Could replace `pdftools::pdf_data()` for figure detection. Coordinates + font info enable better heuristics for detecting headings, captions, table headers, and figure regions.
- **How to adapt**: `jsonlite::fromJSON()` on CLI output → R data frame with one row per text item per page.

### 4. [MEDIUM] Pluggable OCR Server Architecture
- **What**: Standard HTTP API spec for OCR backends. Swap Tesseract for EasyOCR, PaddleOCR, or cloud APIs without code changes.
- **Where**: `ocr/`, `OCR_API_SPEC.md`, `src/engines/ocr/http-simple.ts`
- **Extractability**: Adapt
- **Effort**: Medium
- **Why it is useful**: For scientific papers in non-Latin scripts or with complex equations, Tesseract is mediocre. The HTTP OCR interface lets you slot in PaddleOCR (better for CJK) or a cloud API (better for math).
- **How to adapt**: Run one of the example OCR servers alongside liteparse. Or implement the simple HTTP API spec yourself around any OCR engine.

### 5. [LOW] Multi-Format Conversion (DOCX, XLSX, PPTX, Images)
- **What**: Automatic conversion of non-PDF formats to PDF before parsing, using LibreOffice and ImageMagick.
- **Where**: `src/conversion/`
- **Extractability**: Inspiration
- **Effort**: Medium
- **Why it is useful**: Some supplementary materials come as DOCX/XLSX. Currently Serapeum only handles PDFs.
- **Caveat**: Requires LibreOffice installed. Probably not worth the complexity for Serapeum's primary use case (academic papers are almost always PDF).

### 6. [LOW] Screenshot Generation
- **What**: High-quality page rendering via PDFium WASM for LLM vision workflows.
- **Where**: `src/engines/pdf/pdfium-renderer.ts`
- **Extractability**: Redundant — Serapeum already does this with `pdftools::pdf_render_page()`
- **Effort**: N/A
- **Why it is useful**: Not useful. Serapeum's existing figure extraction pipeline is more sophisticated than liteparse's image handling.

## Quick Wins

- **Add OCR support**: `npm install -g @llamaindex/liteparse` + call `lit parse --format json <pdf>` from R for scanned PDFs. Could be added as a fallback path when `pdftools::pdf_text()` returns empty. (~1 hour)
- **Richer text coordinates**: Use liteparse JSON output to get font names/sizes per text item, improving section detection heuristics (Introduction vs Methods vs References). (~2 hours)
- **Batch processing**: `lit batch-parse` for bulk import of scanned PDFs. (~30 min to wire up)

## Not Worth It

- **Porting grid projection to R**: 1,947 lines of TypeScript with complex spatial algorithms. Would take weeks and the CLI gives you the same output.
- **Replacing pdftools entirely**: pdftools works well for native PDFs and is deeply integrated. liteparse adds value as a *complement*, not a replacement.
- **Using liteparse for figure extraction**: Serapeum's pipeline (render + gap detect + caption match + vision API) is significantly more sophisticated. liteparse extracts embedded images but doesn't detect figure regions or extract captions.
- **Multi-format support**: Academic papers are PDF. The DOCX/XLSX conversion adds complexity for a rare edge case.

## Dependency Decision Analysis

### The Case FOR Taking the Dependency

1. **OCR is table-stakes**: Serapeum silently drops scanned PDFs. This is the single biggest data quality gap.
2. **Low integration cost**: CLI-based integration via `system2()` is trivial. No tight coupling.
3. **Apache 2.0**: Permissive license, no concerns.
4. **Active maintenance**: LlamaIndex team, regular releases, CI on 3 Node.js versions.
5. **Selective OCR is smart**: Only OCRs what needs OCR. Fast for native PDFs.

### The Case AGAINST Taking the Dependency

1. **Node.js runtime dependency**: Serapeum is pure R. Adding Node.js as a runtime requirement is a significant complexity increase for users. They need `npm` installed and working.
2. **Not actually good at tables**: The README itself says "for complex documents with dense tables... we recommend cloud-based LlamaParse." The grid projection preserves layout but doesn't extract structured table data.
3. **Figure extraction is worse**: Serapeum's existing pipeline is far superior for academic figures.
4. **Overlapping functionality**: For native PDFs, pdftools already extracts text well. liteparse adds value mainly for OCR.
5. **Maintenance burden**: Another runtime to keep updated, another point of failure, another thing to debug when it breaks on Windows.

### Recommendation

**Don't take liteparse as a hard dependency. Instead:**

1. **For OCR**: Use Tesseract directly from R via the `tesseract` R package (CRAN). It wraps the same Tesseract engine without requiring Node.js. This fills the scanned-PDF gap without adding a runtime dependency.

2. **For spatial text coordinates**: Continue using `pdftools::pdf_data()` which already provides x/y/width/height per word. If you need richer layout reconstruction, consider the `tabulapdf` R package for table extraction specifically.

3. **Optional enhancement**: If you want liteparse's grid projection quality, offer it as an *optional* backend that users can enable by installing Node.js. Feature-detect `lit` on PATH and use it when available, fall back to pdftools otherwise.

**The speed + accuracy claim for tables/figures doesn't hold up on inspection.** liteparse is fast for text extraction but its table handling is spatial-text-as-layout (not structured), and its figure handling is inferior to what Serapeum already has. The real value proposition is OCR — and that's available natively in R.
