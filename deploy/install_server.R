#!/usr/bin/env Rscript

raiz <- normalizePath(Sys.getenv("APP_DIR", unset = getwd()), mustWork = TRUE)
biblioteca <- file.path(raiz, ".R", "library")
dir.create(biblioteca, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(biblioteca, .libPaths())))
repos <- Sys.getenv(
  "REPORTE_CRAN", unset = "https://packagemanager.posit.co/cran/2026-08-03"
)

if (!requireNamespace("renv", quietly = TRUE)) {
  utils::install.packages("renv", lib = biblioteca, repos = repos)
}
renv::restore(project = raiz, lockfile = file.path(raiz, "renv.lock"), prompt = FALSE)

requeridos <- c("data.table", "jsonlite", "plumber", "readxl", "shiny", "xml2", "zip")
faltan <- requeridos[!vapply(requeridos, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) stop("No fue posible instalar: ", paste(faltan, collapse = ", "))
versiones <- vapply(requeridos, function(x) as.character(utils::packageVersion(x)), character(1))
print(data.frame(Paquete = requeridos, Version = versiones, row.names = NULL))
