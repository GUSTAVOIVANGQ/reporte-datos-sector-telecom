# API REST del generador. La documentación Swagger se publica automáticamente.
`%||%` <- function(x, y) if (is.null(x) || !length(x) || !nzchar(as.character(x[[1]]))) y else x

raiz_api <- normalizePath(
  Sys.getenv("REPORTE_RAIZ", unset = file.path(dirname(sys.frame(1)$ofile %||% "api/plumber.R"), "..")),
  winslash = "/", mustWork = TRUE
)
options(reporte.raiz = raiz_api)
source(file.path(raiz_api, "observabilidad.R"), local = globalenv(), encoding = "UTF-8")
source(file.path(raiz_api, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

api_bool <- function(x, defecto = FALSE) {
  if (is.null(x) || !length(x)) return(defecto)
  tolower(trimws(as.character(x[[1]]))) %in% c("1", "true", "si", "sí", "yes", "on")
}

api_rutas <- function() list(
  catalogo = Sys.getenv(
    "REPORTE_CATALOGO",
    unset = file.path(raiz_api, "config", "reporte-datos-sector-telecomunicaciones.xlsx")
  ),
  datos = Sys.getenv("REPORTE_DATOS_DIR", unset = file.path(raiz_api, "entrada", "datos_bit")),
  salidas = Sys.getenv("REPORTE_SALIDAS_DIR", unset = file.path(raiz_api, "salidas"))
)

resolver_archivo_reporte <- function(id, archivo = "") {
  rutas <- api_rutas()
  if (!grepl("^ejecucion_[A-Za-z0-9_.-]+$", id)) stop("Identificador de ejecución no válido")
  carpeta <- normalizePath(file.path(rutas$salidas, id), winslash = "/", mustWork = TRUE)
  base_salidas <- normalizePath(rutas$salidas, winslash = "/", mustWork = TRUE)
  if (!startsWith(carpeta, paste0(base_salidas, "/"))) stop("Ejecución fuera de la carpeta de salidas")
  candidatos <- list.files(carpeta, recursive = TRUE, full.names = TRUE)
  candidatos <- candidatos[file.exists(candidatos) & !dir.exists(candidatos)]
  permitidos <- candidatos[tolower(tools::file_ext(candidatos)) %in% c("docx", "zip", "csv", "txt")]
  if (nzchar(archivo)) permitidos <- permitidos[basename(permitidos) == basename(archivo)]
  if (!length(permitidos)) stop("No se encontró un archivo descargable en la ejecución")
  normalizePath(permitidos[[1]], winslash = "/", mustWork = TRUE)
}

#* @apiTitle API del Reporte de Datos del Sector de Telecomunicaciones
#* @apiDescription Generación auditable de reportes trimestrales desde las seis fuentes BIT.

#* Estado del servicio y sus dependencias críticas.
#* @get /salud
function(res) {
  rutas <- api_rutas()
  plantilla <- file.path(raiz_api, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
  dir.create(rutas$salidas, recursive = TRUE, showWarnings = FALSE)
  python <- tryCatch(validar_entorno_graficas_python(raiz_api), error = function(e) e)
  fuentes <- vapply(ESPECIFICACIONES_FUENTES, function(x) {
    ruta <- file.path(rutas$datos, x$archivo)
    file.exists(ruta) && file.info(ruta)$size > 0
  }, logical(1))
  critico <- file.exists(plantilla) && file.access(rutas$salidas, 2L) == 0L &&
    !inherits(python, "error")
  if (!critico) res$status <- 503L
  list(
    estado = if (critico) if (all(fuentes)) "ok" else "degradado" else "error",
    version = trimws(readLines(file.path(raiz_api, "VERSION"), n = 1L, warn = FALSE)),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
    r = paste(R.version$major, R.version$minor, sep = "."),
    python = if (inherits(python, "error")) conditionMessage(python) else python$python$version,
    plantilla = file.exists(plantilla),
    salidas_escribibles = file.access(rutas$salidas, 2L) == 0L,
    fuentes_presentes = sum(fuentes),
    fuentes_esperadas = length(fuentes)
  )
}

#* Inventario ligero de las fuentes BIT locales y sus URLs.
#* @get /v1/fuentes
function() {
  rutas <- api_rutas()
  catalogo <- tryCatch(leer_catalogo_fuentes(rutas$catalogo), error = function(e) NULL)
  filas <- lapply(names(ESPECIFICACIONES_FUENTES), function(id) {
    especificacion <- ESPECIFICACIONES_FUENTES[[id]]
    ruta <- file.path(rutas$datos, especificacion$archivo)
    info <- if (file.exists(ruta)) file.info(ruta) else NULL
    list(
      id = id,
      seccion = especificacion$orden,
      archivo = especificacion$archivo,
      url = if (is.null(catalogo)) NA_character_ else unname(catalogo[[id]]),
      presente = file.exists(ruta),
      bytes = if (is.null(info)) 0 else unname(info$size),
      modificado = if (is.null(info)) NA_character_ else format(info$mtime, "%Y-%m-%dT%H:%M:%S%z")
    )
  })
  list(fuentes = filas)
}

#* Métricas acumuladas de generación.
#* @get /v1/metricas
function() resumen_metricas()

#* Genera uno o todos los reportes trimestrales disponibles.
#* @param req Cuerpo JSON: anio, trimestre, actualizar, permitir_red.
#* @post /v1/reportes
#* @parser json
function(req, res) {
  cuerpo <- req$body %||% list()
  anio <- suppressWarnings(as.integer(cuerpo$anio %||% 2024L))
  trimestre <- as.character(cuerpo$trimestre %||% "todos")
  actualizar <- api_bool(cuerpo$actualizar, FALSE)
  permitir_red <- api_bool(cuerpo$permitir_red, TRUE)
  if (is.na(anio) || anio < 2013L || anio > 2100L) {
    res$status <- 400L
    return(list(error = "El año debe estar entre 2013 y 2100"))
  }
  rutas <- api_rutas()
  inicio <- Sys.time()
  registrar_log("INFO", "api_generacion_iniciada", "Solicitud recibida",
                list(anio = anio, trimestre = trimestre))
  generado <- tryCatch(
    ejecutar_generacion(
      raiz = raiz_api, anio = anio, trimestre = trimestre,
      carpeta_salidas = rutas$salidas, catalogo_excel = rutas$catalogo,
      carpeta_cache = rutas$datos, actualizar = actualizar, permitir_red = permitir_red
    ), error = function(e) e
  )
  duracion <- as.numeric(difftime(Sys.time(), inicio, units = "secs"))
  if (inherits(generado, "error")) {
    detalle <- conditionMessage(generado)
    registrar_log("ERROR", "api_generacion_fallida", detalle,
                  list(anio = anio, trimestre = trimestre))
    registrar_metrica_generacion(FALSE, duracion, anio, trimestre, detalle)
    res$status <- 422L
    return(list(ok = FALSE, error = detalle))
  }
  registrar_metrica_generacion(TRUE, generado$duracion_segundos, anio, trimestre,
                               paste(generado$advertencias, collapse = " | "))
  evaluar_alertas_fuentes(generado$advertencias)
  id <- basename(generado$carpeta)
  list(
    ok = TRUE,
    id = id,
    anio = generado$anio,
    trimestres_generados = generado$trimestres_generados,
    duracion_segundos = generado$duracion_segundos,
    advertencias = generado$advertencias,
    archivos = basename(generado$reportes),
    entregable = basename(generado$entregable),
    descarga = paste0("v1/reportes/", id, "/descarga?archivo=", basename(generado$entregable))
  )
}

#* Descarga segura del entregable de una ejecución.
#* @param id Identificador devuelto por POST /v1/reportes.
#* @param archivo Nombre del DOCX o ZIP; si se omite entrega el primero disponible.
#* @get /v1/reportes/<id>/descarga
#* @serializer contentType list(type="application/octet-stream")
function(id, archivo = "", res) {
  ruta <- tryCatch(resolver_archivo_reporte(id, archivo), error = function(e) e)
  if (inherits(ruta, "error")) {
    res$status <- 404L
    return(charToRaw(conditionMessage(ruta)))
  }
  res$setHeader("Content-Disposition", paste0("attachment; filename=\"", basename(ruta), "\""))
  readBin(ruta, what = "raw", n = file.info(ruta)$size)
}

#* Redirección corta hacia Swagger UI.
#* @get /docs
function(res) {
  res$status <- 302L
  res$setHeader("Location", "./__docs__/")
  ""
}
