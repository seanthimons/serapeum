# Generate simple favicon files
# Using base R without graphics device

# Ensure www directory exists
dir.create("www", showWarnings = FALSE)

# Simple approach: create a very basic PNG manually
# Since R's png() crashes in headless mode, we'll use magick if available
# or fall back to copying a placeholder

if (requireNamespace("magick", quietly = TRUE)) {
  library(magick)

  # Create 32x32 favicon
  img32 <- image_blank(32, 32, color = "#6366f1")
  img32 <- image_annotate(img32, "S", size = 20, color = "white",
                          gravity = "center", font = "sans", weight = 700)
  image_write(img32, "www/favicon-32x32.png")

  # Create 16x16 favicon
  img16 <- image_blank(16, 16, color = "#6366f1")
  img16 <- image_annotate(img16, "S", size = 10, color = "white",
                          gravity = "center", font = "sans", weight = 700)
  image_write(img16, "www/favicon-16x16.png")

  # Copy 32x32 as .ico
  file.copy("www/favicon-32x32.png", "www/favicon.ico", overwrite = TRUE)

  cat("Favicons created using magick package\n")
} else {
  # Fallback: create minimal 1x1 PNG and resize
  # This is a minimal valid PNG file (1x1 blue pixel)
  # PNG signature + IHDR + IDAT + IEND chunks

  # For 32x32 solid color favicon
  png_32 <- as.raw(c(
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
    0x00, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x20,  # 32x32
    0x08, 0x02, 0x00, 0x00, 0x00, 0xFC, 0x18, 0xED, 0xA3,
    0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54,  # IDAT chunk
    0x08, 0xD7, 0x63, 0x60, 0x18, 0x05, 0x00, 0x00, 0x01, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,  # IEND chunk
    0xAE, 0x42, 0x60, 0x82
  ))

  writeBin(png_32, "www/favicon-32x32.png")
  writeBin(png_32, "www/favicon-16x16.png")
  writeBin(png_32, "www/favicon.ico")

  cat("Basic favicons created (install magick package for better quality)\n")
}

# List created files
cat("Created files:\n")
print(list.files("www", pattern = "favicon", full.names = TRUE))
