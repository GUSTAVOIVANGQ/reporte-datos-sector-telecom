#!/usr/bin/env Rscript

# Abre una sesión Shiny de prueba y ejecuta el callback posterior al primer flush.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo)) {
  normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
stopifnot(requireNamespace("shiny", quietly = TRUE))

salidas <- tempfile("prueba_ui_salidas_")
dir.create(salidas, recursive = TRUE)
on.exit(unlink(salidas, recursive = TRUE, force = TRUE), add = TRUE)

variables <- c("REPORTE_NO_RUN_APP", "REPORTE_MODO_SERVIDOR", "REPORTE_SALIDAS_DIR")
anteriores <- Sys.getenv(variables, unset = NA_character_)
on.exit({
  presentes <- !is.na(anteriores)
  if (any(presentes)) do.call(Sys.setenv, as.list(stats::setNames(anteriores[presentes], variables[presentes])))
  if (any(!presentes)) Sys.unsetenv(variables[!presentes])
}, add = TRUE)

Sys.setenv(
  REPORTE_NO_RUN_APP = "true",
  REPORTE_MODO_SERVIDOR = "true",
  REPORTE_SALIDAS_DIR = salidas
)
options(reporte.raiz = raiz)
source(file.path(raiz, "app.R"), local = globalenv(), encoding = "UTF-8")

shiny::testServer(server, {
  session$flushReact()
})

cat("OK: la carga inicial de Shiny terminó sin lecturas fuera del contexto reactivo.\n")
