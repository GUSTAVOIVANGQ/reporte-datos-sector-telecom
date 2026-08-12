#!/usr/bin/env Rscript

args_all <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", args_all[grepl("^--file=", args_all)])
raiz <- if (length(archivo)) normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE) else getwd()
args <- commandArgs(trailingOnly = TRUE)
Sys.setenv(REPORTE_RAIZ = raiz, REPORTE_SERVICIO = "api")
options(reporte.raiz = raiz)

valor <- function(nombre, defecto) {
  encontrado <- args[startsWith(args, paste0(nombre, "="))]
  if (!length(encontrado)) return(defecto)
  sub(paste0("^", nombre, "="), "", encontrado[[length(encontrado)]])
}

biblioteca <- trimws(Sys.getenv("REPORTE_R_LIB", unset = ""))
if (nzchar(biblioteca)) .libPaths(unique(c(biblioteca, .libPaths())))
requeridos <- c("plumber", "jsonlite", "readxl", "xml2", "zip", "data.table")
faltan <- requeridos[!vapply(requeridos, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) stop("Faltan paquetes R; ejecute renv::restore(): ", paste(faltan, collapse = ", "))

host <- valor("--host", Sys.getenv("REPORTE_API_HOST", unset = "127.0.0.1"))
port <- suppressWarnings(as.integer(valor("--port", Sys.getenv("REPORTE_API_PORT", unset = "8000"))))
if (is.na(port) || port < 1L || port > 65535L) stop("Puerto API no válido")

pr <- plumber::plumb(file.path(raiz, "api", "plumber.R"))
registrar <- get("registrar_log", envir = pr$environment)
registrar("INFO", "api_iniciada", paste0("Escuchando en ", host, ":", port))
pr$run(host = host, port = port, swagger = TRUE)
