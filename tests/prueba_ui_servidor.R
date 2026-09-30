#!/usr/bin/env Rscript

# Abre una sesión Shiny de prueba y ejecuta el callback posterior al primer flush.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo)) {
  normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
stopifnot(
  requireNamespace("shiny", quietly = TRUE),
  requireNamespace("htmltools", quietly = TRUE)
)

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
source(file.path(raiz, "observabilidad.R"), local = globalenv(), encoding = "UTF-8")
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")
source(file.path(raiz, "app.R"), local = globalenv(), encoding = "UTF-8")

renderizado_ui <- htmltools::renderTags(ui)
html_ui <- paste(c(renderizado_ui$head, renderizado_ui$html), collapse = "\n")
rutas_recursos <- shiny::resourcePaths()
stopifnot(
  length(html_ui) == 1L,
  grepl("reporte-telecom-app", html_ui, fixed = TRUE),
  grepl("logo_crt_blanco.png", html_ui, fixed = TRUE),
  grepl("Historial de reportes", html_ui, fixed = TRUE),
  grepl("Fuentes de datos", html_ui, fixed = TRUE),
  grepl("actualizar_fuentes", html_ui, fixed = TRUE),
  grepl("Actualizar los seis CSV", html_ui, fixed = TRUE),
  grepl("reporte-activos/app.css", html_ui, fixed = TRUE),
  grepl("reporte-activos/app.js", html_ui, fixed = TRUE),
  grepl("reporte-activos/logo_crt_blanco.png", html_ui, fixed = TRUE),
  "reporte-activos" %in% names(rutas_recursos),
  identical(
    normalizePath(unname(rutas_recursos[["reporte-activos"]]), mustWork = TRUE),
    normalizePath(file.path(raiz, "www"), mustWork = TRUE)
  ),
  file.exists(file.path(raiz, "www", "app.css")),
  file.exists(file.path(raiz, "www", "app.js")),
  file.exists(file.path(raiz, "www", "logo_crt_blanco.png")),
  !grepl("shiny::small", paste(readLines(file.path(raiz, "app.R"), warn = FALSE), collapse = "\n"),
         fixed = TRUE)
)

shiny::testServer(server, {
  session$flushReact()
  stopifnot(identical(seccion_activa(), "generar"))
  session$setInputs(nav_fuentes = 1L)
  session$flushReact()
  stopifnot(identical(seccion_activa(), "fuentes"))
  session$setInputs(nav_configuracion = 1L)
  session$flushReact()
  stopifnot(identical(seccion_activa(), "configuracion"))
})

cat("OK: carga inicial, activos web y navegación Shiny válidos.\n")
