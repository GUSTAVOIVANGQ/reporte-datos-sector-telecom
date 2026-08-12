#!/usr/bin/env Rscript

# Mide la lectura de las seis fuentes. La primera vuelta puede construir la
# caché procesada; la segunda debe reutilizarla si los CSV no cambiaron.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo_arg <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo_arg)) {
  normalizePath(file.path(dirname(archivo_arg[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
options(reporte.raiz = raiz)
source(file.path(raiz, "fuentes_bit.R"), local = globalenv(), encoding = "UTF-8")

carpeta_csv <- file.path(raiz, "entrada", "datos_bit")

medir_vuelta <- function(numero) {
  resultados <- lapply(names(ESPECIFICACIONES_FUENTES), function(id) {
    especificacion <- ESPECIFICACIONES_FUENTES[[id]]
    ruta <- file.path(carpeta_csv, especificacion$archivo)
    if (!file.exists(ruta)) stop("Falta el archivo de prueba: ", ruta)
    inicio <- proc.time()[["elapsed"]]
    datos <- leer_csv_fuente(ruta, especificacion)
    segundos <- proc.time()[["elapsed"]] - inicio
    data.frame(
      Vuelta = numero,
      Archivo = especificacion$archivo,
      Tamano_MB = round(file.info(ruta)$size / 1024^2, 1),
      Filas = nrow(datos),
      Origen = if (isTRUE(attr(datos, "reporte_cache_usada"))) "RDS procesado" else "CSV",
      Segundos = round(segundos, 3),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, resultados)
}

cat("Vuelta 1: lectura o creación de caché procesada\n")
primera <- medir_vuelta(1L)
print(primera, row.names = FALSE)

cat("\nVuelta 2: reutilización de caché procesada\n")
segunda <- medir_vuelta(2L)
print(segunda, row.names = FALSE)

cat(sprintf(
  "\nTotal vuelta 1: %.3f s | Total vuelta 2: %.3f s\n",
  sum(primera$Segundos), sum(segunda$Segundos)
))
if (!all(segunda$Origen == "RDS procesado")) {
  stop("La segunda vuelta no reutilizó la caché procesada en todas las fuentes.")
}
cat("OK: la caché procesada quedó activa para las seis fuentes.\n")
