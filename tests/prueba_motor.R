#!/usr/bin/env Rscript

# Prueba de las seis fuentes incluidas. No descarga archivos ni genera Word.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo_arg <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo_arg)) {
  normalizePath(file.path(dirname(archivo_arg[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
options(reporte.raiz = raiz)
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

cache <- file.path(raiz, "entrada", "datos_bit")
fuentes <- setNames(vector("list", length(ESPECIFICACIONES_FUENTES)), names(ESPECIFICACIONES_FUENTES))
for (id in names(ESPECIFICACIONES_FUENTES)) {
  especificacion <- ESPECIFICACIONES_FUENTES[[id]]
  ruta <- file.path(cache, especificacion$archivo)
  fuentes[[id]] <- list(
    datos = leer_csv_fuente(ruta, especificacion),
    ruta = ruta,
    origen = "archivo de prueba"
  )
}

stopifnot(identical(trimestres_comunes(fuentes, 2024L), 1:4))

esperados_q4 <- c(
  lineas_movil = 152476748,
  internet_movil = 135808948,
  ingresos = 163137.9235873667,
  lineas_fijas = 31361393,
  internet_fijo = 29003240,
  tv_restringida = 21787954
)

for (trimestre in 1:4) {
  preparado <- preparar_tablas_periodo(fuentes, 2024L, trimestre)
  validar_entrada(preparado$tablas)
  stopifnot(
    identical(vapply(preparado$tablas, nrow, integer(1)), c(6L, 6L, 20L, 12L, 11L, 9L)),
    identical(vapply(preparado$tablas, ncol, integer(1)), c(4L, 4L, 5L, 5L, 5L, 5L)),
    all(preparado$control$Total_reporte > 0)
  )
}

q4 <- preparar_tablas_periodo(fuentes, 2024L, 4L)$control
obtenidos_q4 <- setNames(q4$Total_reporte, names(ESPECIFICACIONES_FUENTES))
stopifnot(all(abs(obtenidos_q4 - esperados_q4) < 0.01))

# Con las copias proporcionadas, 2025 no tiene un trimestre común porque
# internet fijo termina en 2024. En una descarga futura esto puede cambiar.
stopifnot(length(trimestres_comunes(fuentes, 2025L)) == 0L)

cat(
  "OK: seis fuentes; 2024Q1-Q4 completos;",
  "tablas 6/6/20/12/11/9; totales Q4 conciliados;",
  "2025 sin cobertura común en las copias incluidas.\n"
)
