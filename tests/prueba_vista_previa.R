#!/usr/bin/env Rscript

argumentos <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo)) normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE) else getwd()
source(file.path(raiz, "vista_previa.R"), encoding = "UTF-8")

libreoffice <- resolver_libreoffice()
if (!nzchar(libreoffice)) {
  cat("OMITIDA: LibreOffice no está instalado; la UI usará su degradación segura.\n")
  quit(save = "no", status = 0L)
}

docx <- list.files(file.path(raiz, "ejemplo"), pattern = "\\.docx$", full.names = TRUE)
if (!length(docx)) docx <- file.path(raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
temporal <- tempfile("prueba_preview_")
dir.create(temporal, recursive = TRUE)
on.exit(unlink(temporal, recursive = TRUE, force = TRUE), add = TRUE)
pdf <- crear_vista_previa_docx(docx[[1]], temporal)
stopifnot(file.exists(pdf), file.info(pdf)$size > 0, identical(tolower(tools::file_ext(pdf)), "pdf"))
cat("OK: LibreOffice creó una vista previa PDF válida.\n")
