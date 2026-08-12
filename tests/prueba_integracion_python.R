#!/usr/bin/env Rscript

# Comprueba que R puede invocar Python y recibir los seis PNG.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo_arg <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo_arg)) {
  normalizePath(file.path(dirname(archivo_arg[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
source(file.path(raiz, "graficas_python.R"), encoding = "UTF-8")

valores <- list(
  c("América Móvil" = 83780000, "AT&T" = 22860000, "Telefónica" = 21630000,
    "Grupo Walmart" = 18060000, "Otros" = 6150000),
  c("América Móvil" = 81090000, "AT&T" = 20910000, "Telefónica" = 9480000,
    "Grupo Walmart" = 18240000, "Otros" = 6090000),
  c("América Móvil" = 88450.81, "AT&T" = 20936.86, "Grupo Televisa" = 14130.48,
    "Grupo Salinas" = 9276.73, "Megacable-MCM" = 8834.29, "Telefónica" = 7329.63,
    "Otros" = 5772.56, "Grupo Walmart" = 2275.67, "Altán" = 2823.52, "Axtel" = 3307.36),
  c("América Móvil" = 10160000, "Grupo Televisa" = 8340000, "Megacable-MCM" = 6120000,
    "Grupo Salinas" = 6090000, "Otros" = 650000),
  c("América Móvil" = 11210000, "Grupo Televisa" = 5970000, "Megacable-MCM" = 5320000,
    "Grupo Salinas" = 5310000, "Otros" = 1190000),
  c("Grupo Televisa" = 11550000, "Megacable-MCM" = 5850000,
    "Grupo Salinas" = 2480000, "Dish" = 1130000, "Otros" = 780000)
)

entorno <- validar_entorno_graficas_python(raiz)
temporal <- tempfile("prueba_integracion_python_")
dir.create(temporal, recursive = TRUE)
on.exit(unlink(temporal, recursive = TRUE), add = TRUE)

for (seccion in 1:6) {
  datos <- data.frame(
    grupo = names(valores[[seccion]]),
    valor = as.numeric(valores[[seccion]]),
    stringsAsFactors = FALSE
  )
  salida <- file.path(temporal, paste0("grafica_", seccion, ".png"))
  guardar_grafica_python(datos, seccion, salida, entorno)
  stopifnot(file.exists(salida), file.info(salida)$size > 0)
}

salida_vacia <- file.path(temporal, "grafica_sin_datos.png")
guardar_grafica_python(
  data.frame(grupo = character(), valor = numeric()),
  5L, salida_vacia, entorno, periodo = "2025Q4"
)
stopifnot(file.exists(salida_vacia), file.info(salida_vacia)$size > 0)

cat("OK: R invocó Python y recibió seis gráficas y un marcador sin datos.\n")
