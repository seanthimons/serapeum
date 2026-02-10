# PDF Image Extraction Design

**Date:** 2026-02-10  
**Issue:** [#37 - dev: PDF image extraction process](https://github.com/seanthimons/serapeum/issues/37)  
**Status:** Implementation

## Problem Statement

Currently, `pdftools` can convert entire PDF pages to PNG/WEBP, but we need to extract only the embedded images from PDF documents (figures, charts, diagrams) for use in:
- Slide deck generation (GH #29)
- Document analysis and visualization
- Figure extraction for research notebooks

## Research Findings

### Available R Packages

1. **pdfimager** ⭐ RECOMMENDED
   - Interfaces with `pdfimages` tool from Poppler
   - Extracts only embedded images (not full-page renders)
   - GitHub: https://github.com/sckott/pdfimager
   - Installation: `pak::pak("sckott/pdfimager")`
   - Requires Poppler system dependency

2. **metagear**
   - Has `PDF_extractImages()` function
   - Extracts embedded images but has limitations with some compression formats (e.g., CCITT)
   - CRAN package

3. **pdftools** (existing)
   - Can render full pages as images
   - NOT suitable for extracting individual embedded images
   - Already in use for text extraction

## Design Decision

Use **pdfimager** as the primary solution because:
- Specifically designed for embedded image extraction
- Uses battle-tested Poppler `pdfimages` tool
- Extracts images in their original format and quality
- Returns metadata about extracted images (dimensions, page, type)

## Implementation Plan

### 1. Add Image Extraction Function

Add new function to `R/pdf.R`:

```r
#' Extract images from PDF file
#' @param path Path to PDF file
#' @param output_dir Directory to save extracted images (default: temp dir)
#' @return Data frame with image metadata (path, page, width, height, type)
extract_pdf_images <- function(path, output_dir = NULL) {
  if (!requireNamespace("pdfimager", quietly = TRUE)) {
    stop("Package 'pdfimager' is required. Install with: pak::pak('sckott/pdfimager')")
  }
  
  if (!file.exists(path)) {
    stop("PDF file not found: ", path)
  }
  
  # Use temp dir if not specified
  if (is.null(output_dir)) {
    output_dir <- tempfile("pdf_images_")
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Extract images using pdfimager
  result <- tryCatch({
    pdfimager::pdimg_images(path, format = "all", output_dir = output_dir)
  }, error = function(e) {
    stop("Failed to extract images from PDF: ", e$message)
  })
  
  # Return structured metadata
  result
}
```

### 2. Helper Function for Image Detection

Add utility to check if PDF contains extractable images:

```r
#' Check if PDF contains extractable images
#' @param path Path to PDF file
#' @return Logical indicating if images were found
has_pdf_images <- function(path) {
  tryCatch({
    images <- extract_pdf_images(path)
    return(!is.null(images) && nrow(images) > 0)
  }, error = function(e) {
    FALSE
  })
}
```

### 3. System Requirements

Add to documentation:
- **System dependency:** Poppler utilities must be installed
  - Ubuntu/Debian: `apt-get install poppler-utils`
  - macOS: `brew install poppler`
  - Windows: Download from https://github.com/oschwartz10612/poppler-windows/releases/

### 4. Testing Strategy

Add tests in `tests/testthat/`:
- Test extraction from sample PDF with images
- Test error handling for missing files
- Test with PDF containing no images
- Test output directory handling

### 5. Integration with Existing Features

This functionality will enable:
- **Slide generation (#29):** Extract figures to insert into Quarto slides
- **Document analysis:** Include image metadata in document processing
- **Future vision model integration:** Describe/caption extracted figures

## API Design

### Function Signature

```r
extract_pdf_images(
  path,              # Path to PDF file
  output_dir = NULL  # Optional output directory
)
```

### Return Value

Data frame with columns:
- `path`: Full path to extracted image file
- `page`: Page number where image was found
- `width`: Image width in pixels
- `height`: Image height in pixels
- `type`: Image format (jpg, png, ppm, etc.)
- `name`: Original image name/identifier

### Error Handling

- Validate file existence before extraction
- Check for pdfimager package installation
- Provide helpful error messages for missing Poppler
- Return empty data frame (not error) if no images found

## Future Enhancements

1. **Vision Model Captioning:** Use multimodal LLM to generate captions for extracted images
2. **Smart Cropping:** Auto-crop whitespace from extracted images
3. **Quality Assessment:** Filter low-quality/decorative images
4. **Figure Type Detection:** Classify as chart, diagram, photo, etc.
5. **Integration with Slides:** Automatically match figures to relevant slide content

## References

- pdfimager GitHub: https://github.com/sckott/pdfimager
- pdfimager docs: https://sckott.github.io/pdfimager/
- Poppler pdfimages: https://poppler.freedesktop.org/
- Related Issues: #28 (image extraction), #29 (slide insertion)
