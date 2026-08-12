# Logging JSONL, métricas persistentes y alertas configurables.

ruta_observabilidad <- function(nombre) {
  base <- Sys.getenv("REPORTE_OBSERVABILIDAD_DIR", unset = file.path(
    getOption("reporte.raiz", getwd()), "salidas", "observabilidad"
  ))
  dir.create(base, recursive = TRUE, showWarnings = FALSE)
  file.path(base, nombre)
}

rotar_archivo <- function(ruta, max_bytes = 10 * 1024^2, copias = 5L) {
  if (!file.exists(ruta) || file.info(ruta)$size < max_bytes) return(invisible(FALSE))
  for (i in rev(seq_len(copias))) {
    origen <- if (i == 1L) ruta else paste0(ruta, ".", i - 1L)
    destino <- paste0(ruta, ".", i)
    if (file.exists(origen)) file.rename(origen, destino)
  }
  invisible(TRUE)
}

registrar_log <- function(nivel, evento, mensaje, datos = list()) {
  ruta <- ruta_observabilidad("aplicacion.jsonl")
  rotar_archivo(ruta)
  registro <- c(list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
    nivel = toupper(as.character(nivel)),
    evento = as.character(evento),
    mensaje = as.character(mensaje),
    pid = Sys.getpid(),
    servicio = Sys.getenv("REPORTE_SERVICIO", unset = "ui")
  ), datos)
  linea <- jsonlite::toJSON(registro, auto_unbox = TRUE, null = "null", na = "null")
  cat(linea, "\n", file = ruta, append = TRUE, sep = "")
  message("[", registro$nivel, "] ", registro$evento, ": ", registro$mensaje)
  invisible(registro)
}

registrar_metrica_generacion <- function(ok, duracion, anio, trimestre, detalle = "") {
  ruta <- ruta_observabilidad("generaciones.csv")
  nueva <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
    ok = isTRUE(ok),
    duracion_segundos = as.numeric(duracion),
    anio = as.integer(anio),
    trimestre = as.character(trimestre),
    detalle = substr(gsub("[\r\n]+", " ", as.character(detalle)), 1L, 1000L),
    stringsAsFactors = FALSE
  )
  utils::write.table(
    nueva, ruta, sep = ",", row.names = FALSE,
    col.names = !file.exists(ruta), append = file.exists(ruta), qmethod = "double"
  )
  invisible(nueva)
}

resumen_metricas <- function() {
  ruta <- ruta_observabilidad("generaciones.csv")
  if (!file.exists(ruta)) {
    return(list(total = 0L, exitos = 0L, fallos = 0L, tasa_exito = NA_real_,
                duracion_promedio_segundos = NA_real_))
  }
  datos <- tryCatch(utils::read.csv(ruta, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(datos) || !nrow(datos)) {
    return(list(total = 0L, exitos = 0L, fallos = 0L, tasa_exito = NA_real_,
                duracion_promedio_segundos = NA_real_))
  }
  ok <- as.logical(datos$ok)
  list(
    total = nrow(datos),
    exitos = sum(ok, na.rm = TRUE),
    fallos = sum(!ok, na.rm = TRUE),
    tasa_exito = round(mean(ok, na.rm = TRUE), 4),
    duracion_promedio_segundos = round(mean(datos$duracion_segundos, na.rm = TRUE), 2),
    ultima_generacion = datos$timestamp[[nrow(datos)]]
  )
}

enviar_alerta <- function(titulo, mensaje, datos = list()) {
  webhook <- trimws(Sys.getenv("REPORTE_ALERT_WEBHOOK_URL", unset = ""))
  registrar_log("WARN", "alerta", paste(titulo, mensaje), datos)
  if (!nzchar(webhook)) return(invisible(FALSE))
  cuerpo <- jsonlite::toJSON(
    c(list(title = titulo, text = mensaje), datos), auto_unbox = TRUE, null = "null"
  )
  temporal <- tempfile("alerta_", fileext = ".json")
  on.exit(unlink(temporal), add = TRUE)
  writeLines(cuerpo, temporal, useBytes = TRUE)
  curl <- unname(Sys.which("curl"))
  if (!nzchar(curl)) return(invisible(FALSE))
  estado <- system2(
    curl,
    c("--fail", "--silent", "--show-error", "--max-time", "15",
      "-H", shQuote("Content-Type: application/json"), "--data-binary",
      paste0("@", shQuote(temporal)), shQuote(webhook)),
    stdout = FALSE, stderr = FALSE
  )
  invisible(identical(as.integer(estado), 0L))
}

evaluar_alertas_fuentes <- function(advertencias, umbral = 3L) {
  ruta <- ruta_observabilidad("estado_fuentes.rds")
  estado <- if (file.exists(ruta)) tryCatch(readRDS(ruta), error = function(e) list()) else list()
  archivos <- unique(unlist(regmatches(
    advertencias, gregexpr("TD_[A-Z0-9_]+\\.csv", advertencias, perl = TRUE)
  )))
  conocidas <- vapply(ESPECIFICACIONES_FUENTES, function(x) x$archivo, character(1))
  for (archivo in conocidas) {
    anterior <- if (is.null(estado[[archivo]])) 0L else as.integer(estado[[archivo]])
    estado[[archivo]] <- if (archivo %in% archivos) anterior + 1L else 0L
    if (identical(estado[[archivo]], as.integer(umbral))) {
      enviar_alerta(
        "Fuente BIT con fallos repetidos",
        paste0(archivo, " produjo advertencias en ", umbral, " ejecuciones consecutivas."),
        list(fuente = archivo, repeticiones = umbral)
      )
    }
  }
  guardar <- tempfile("estado_fuentes_", tmpdir = dirname(ruta), fileext = ".rds")
  saveRDS(estado, guardar)
  file.rename(guardar, ruta)
  invisible(estado)
}
