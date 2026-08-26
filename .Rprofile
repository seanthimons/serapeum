# Configure boosterpak package installation.
options(renv.config.pak.enabled = TRUE)
options(renv.config.ppm.enabled = TRUE)
options(install.packages.compile.from.source = "never")
options(install.packages.check.source = "no")
# Configure boosterpak package repositories.
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"))
options(renv.config.repos.override = c(CRAN = "https://packagemanager.posit.co/cran/latest"))
source("renv/activate.R")
# BEGIN boosterpak managed startup
try(if (dir.exists("boosters")) { attach <- file.path("boosters", "attach.R"); if (file.exists(attach)) source(attach); invisible(lapply(list.files("boosters", "^fn_.*\\.R$", full.names = TRUE), source)) })
# END boosterpak managed startup
