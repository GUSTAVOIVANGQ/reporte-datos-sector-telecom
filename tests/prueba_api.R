#!/usr/bin/env Rscript

argumentos <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo)) normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE) else getwd()
Sys.setenv(REPORTE_RAIZ = raiz)
options(reporte.raiz = raiz)
stopifnot(requireNamespace("plumber", quietly = TRUE))

ruta_api <- file.path(raiz, "api", "plumber.R")
api <- plumber::plumb(ruta_api)
stopifnot(inherits(api, "Plumber"))
texto <- readLines(ruta_api, warn = FALSE, encoding = "UTF-8")
rutas <- c(
  "@get /salud", "@get /v1/fuentes", "@get /v1/metricas",
  "@post /v1/reportes", "@get /v1/reportes/<id>/descarga"
)
stopifnot(all(vapply(rutas, function(x) any(grepl(x, texto, fixed = TRUE)), logical(1))))
cat("OK: Plumber cargó la API y están declarados todos los endpoints v1.\n")
