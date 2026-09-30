#!/usr/bin/env Rscript

# Verifica que el lote solo se reemplace cuando las seis fuentes pasan la validación.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo)) {
  normalizePath(file.path(dirname(archivo[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
options(reporte.raiz = raiz)
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

origen <- file.path(raiz, "entrada", "datos_bit")
destino <- tempfile("prueba_actualizacion_")
dir.create(destino, recursive = TRUE)
on.exit(unlink(destino, recursive = TRUE, force = TRUE), add = TRUE)

catalogo <- vapply(ESPECIFICACIONES_FUENTES, function(x) {
  file.path(origen, x$archivo)
}, character(1))
stopifnot(all(file.exists(catalogo)))

for (especificacion in ESPECIFICACIONES_FUENTES) {
  writeLines("COPIA LOCAL ANTERIOR", file.path(destino, especificacion$archivo))
}
md5_anteriores <- tools::md5sum(file.path(
  destino, vapply(ESPECIFICACIONES_FUENTES, `[[`, character(1), "archivo")
))

contador <- 0L
descarga_fallida <- function(url, temporal, especificacion, reintentos) {
  contador <<- contador + 1L
  if (contador == 3L) stop("fallo simulado")
  stopifnot(file.copy(url, temporal, overwrite = TRUE))
  datos <- leer_csv_fuente(temporal, especificacion, usar_cache = FALSE)
  list(datos = datos, bytes = file.info(temporal)$size, filas = nrow(datos), intentos = 1L)
}
fallo <- tryCatch(
  actualizar_todas_fuentes(catalogo, destino, funcion_descarga = descarga_fallida),
  error = function(e) e
)
stopifnot(
  inherits(fallo, "error"),
  identical(unname(tools::md5sum(names(md5_anteriores))), unname(md5_anteriores)),
  !dir.exists(file.path(destino, ".actualizacion_fuentes.lock"))
)

descarga_local <- function(url, temporal, especificacion, reintentos) {
  stopifnot(file.copy(url, temporal, overwrite = TRUE))
  datos <- leer_csv_fuente(temporal, especificacion, usar_cache = FALSE)
  list(datos = datos, bytes = file.info(temporal)$size, filas = nrow(datos), intentos = 1L)
}
actualizadas <- actualizar_todas_fuentes(
  catalogo, destino, funcion_descarga = descarga_local
)
destinos <- file.path(destino, actualizadas$archivo)
stopifnot(
  nrow(actualizadas) == 6L,
  all(actualizadas$filas > 0L),
  identical(unname(tools::md5sum(destinos)), unname(tools::md5sum(catalogo))),
  !dir.exists(file.path(destino, ".actualizacion_fuentes.lock")),
  !length(list.files(destino, pattern = "^\\.actualizacion_"))
)
cat("OK: actualización de seis fuentes validada; fallo conserva el lote anterior.\n")
