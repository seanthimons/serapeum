# Serapeum Setup
# Run this script once after cloning to install dependencies.
# Usage: Rscript setup.R

cat("\n=== Serapeum Setup ===\n\n")

# 1. Install renv if needed
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv...\n")
  install.packages("renv")
}

# 2. Restore dependencies from lockfile
cat("Restoring packages from renv.lock...\n")
renv::restore(prompt = FALSE)

# 3. Ensure data directories exist
dir.create("data", showWarnings = FALSE)
dir.create("data/support", showWarnings = FALSE)

cat("\n=== Setup Complete ===\n")
cat("\nNext steps:\n")
cat("  1. Run the app:    shiny::runApp()\n")
cat("  2. Configure API keys in the Settings page\n")
cat("  3. Quality data (predatory journals, retractions) loads automatically\n")
cat("\n")
