#!/usr/bin/env Rscript

# Punto de entrada: interfaz Shiny o ejecución automática por año/trimestre.
args_completos <- commandArgs(trailingOnly = FALSE)
archivo_main <- sub("^--file=", "", args_completos[grepl("^--file=", args_completos)])
raiz <- if (length(archivo_main)) dirname(normalizePath(archivo_main[[1]])) else getwd()
args_usuario <- commandArgs(trailingOnly = TRUE)
options(reporte.raiz = raiz)

valor_logico_entorno <- function(nombre, defecto = FALSE) {
  valor <- tolower(trimws(Sys.getenv(nombre, unset = if (defecto) "true" else "false")))
  valor %in% c("1", "true", "si", "sí", "yes", "on")
}

biblioteca <- trimws(Sys.getenv("REPORTE_R_LIB", unset = ""))
if (nzchar(biblioteca)) {
  dir.create(biblioteca, recursive = TRUE, showWarnings = FALSE)
  .libPaths(unique(c(biblioteca, .libPaths())))
}
options(
  datatable.fread.datatable = FALSE,
  datatable.nthreads = max(1L, suppressWarnings(as.integer(Sys.getenv("REPORTE_DATA_THREADS", "4")))),
  timeout = max(60L, suppressWarnings(as.integer(Sys.getenv("REPORTE_HTTP_TIMEOUT", "900"))))
)

asegurar_paquetes <- function(paquetes) {
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan) && !valor_logico_entorno("REPORTE_INSTALL_PACKAGES", TRUE)) {
    stop(
      "Faltan paquetes R y la instalación automática está desactivada: ",
      paste(faltan, collapse = ", "), ". Ejecute renv::restore()."
    )
  }
  if (length(faltan)) {
    message("Instalando paquetes faltantes: ", paste(faltan, collapse = ", "))
    utils::install.packages(
      faltan,
      lib = if (nzchar(biblioteca)) biblioteca else .libPaths()[[1]],
      repos = Sys.getenv("REPORTE_CRAN", unset = "https://cloud.r-project.org")
    )
  }
  pendientes <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(pendientes)) stop("No fue posible instalar: ", paste(pendientes, collapse = ", "))
  invisible(TRUE)
}

valor_opcion <- function(nombre, defecto = NULL) {
  prefijo <- paste0(nombre, "=")
  coincidencias <- args_usuario[startsWith(args_usuario, prefijo)]
  if (!length(coincidencias)) return(defecto)
  substring(coincidencias[[length(coincidencias)]], nchar(prefijo) + 1L)
}

mostrar_ayuda <- function() {
  cat(paste(
    "Reporte de Datos del Sector de Telecomunicaciones v3.6.7",
    "",
    "Uso:",
    "  Rscript main.R --ui --host=127.0.0.1 --port=3838",
    "  Rscript main.R --automatico --anio=2024 --trimestre=todos",
    "  Rscript api/run_api.R --host=127.0.0.1 --port=8000",
    "",
    "Opciones:",
    "  --anio=AAAA          Año del reporte (predeterminado: 2024).",
    "  --trimestre=VALOR    todos, 1, 2, 3, 4 o Q1, Q2, Q3, Q4.",
    "  --actualizar         Fuerza la descarga de las seis fuentes.",
    "  --sin-red            No intenta descargar ni actualizar archivos.",
    "  --catalogo=RUTA      Excel que contiene los seis enlaces.",
    "  --cache=RUTA         Carpeta de CSV descargados.",
    "  --salidas=RUTA       Carpeta de resultados.",
    "  --python=RUTA        Ejecutable de Python 3 para crear las gráficas.",
    "  --host=IP            Dirección de escucha de Shiny.",
    "  --port=PUERTO        Puerto de escucha de Shiny.",
    "  --no-browser         No abre el navegador.",
    sep = "\n"
  ), "\n")
}

if (any(args_usuario %in% c("--ayuda", "-h", "--help"))) {
  mostrar_ayuda()
  quit(save = "no", status = 0L)
}

modo_ui <- !length(args_usuario) || "--ui" %in% args_usuario
paquetes_motor <- c("readxl", "xml2", "zip", "data.table", "jsonlite")
asegurar_paquetes(if (modo_ui) c(paquetes_motor, "shiny") else paquetes_motor)
source(file.path(raiz, "observabilidad.R"), local = globalenv(), encoding = "UTF-8")
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

if (modo_ui) {
  host <- valor_opcion("--host", Sys.getenv("REPORTE_HOST", unset = "127.0.0.1"))
  port <- suppressWarnings(as.integer(valor_opcion(
    "--port", Sys.getenv("REPORTE_PORT", unset = "3838")
  )))
  if (is.na(port) || port < 1L || port > 65535L) stop("Puerto Shiny no válido")
  options(
    shiny.host = host,
    shiny.port = port,
    shiny.launch.browser = !"--no-browser" %in% args_usuario &&
      !valor_logico_entorno("REPORTE_MODO_SERVIDOR", FALSE)
  )
  source(file.path(raiz, "app.R"), local = globalenv(), encoding = "UTF-8")
} else {
  anio <- valor_opcion("--anio", "2024")
  trimestre <- valor_opcion("--trimestre", "todos")
  carpeta_salidas <- valor_opcion(
    "--salidas", Sys.getenv("REPORTE_SALIDAS_DIR", unset = file.path(raiz, "salidas"))
  )
  catalogo <- valor_opcion(
    "--catalogo", Sys.getenv(
      "REPORTE_CATALOGO",
      unset = file.path(raiz, "config", "reporte-datos-sector-telecomunicaciones.xlsx")
    )
  )
  cache <- valor_opcion(
    "--cache", Sys.getenv("REPORTE_DATOS_DIR", unset = file.path(raiz, "entrada", "datos_bit"))
  )
  python <- valor_opcion("--python", "")
  if (nzchar(trimws(python))) options(reporte.python = trimws(python))
  actualizar <- "--actualizar" %in% args_usuario
  permitir_red <- !"--sin-red" %in% args_usuario
  inicio <- Sys.time()
  estado <- 0L
  resultado <- tryCatch(
    ejecutar_generacion(
      raiz = raiz, anio = anio, trimestre = trimestre,
      carpeta_salidas = carpeta_salidas, catalogo_excel = catalogo,
      carpeta_cache = cache, actualizar = actualizar, permitir_red = permitir_red
    ),
    error = function(e) {
      estado <<- 1L
      detalle <- conditionMessage(e)
      registrar_log("ERROR", "generacion_cli_fallida", detalle,
                    list(anio = anio, trimestre = trimestre))
      registrar_metrica_generacion(
        FALSE, as.numeric(difftime(Sys.time(), inicio, units = "secs")),
        anio, trimestre, detalle
      )
      message("\nERROR: ", detalle)
      NULL
    }
  )

  if (!is.null(resultado)) {
    registrar_log("INFO", "generacion_cli_completada", "Reporte generado",
                  list(anio = anio, trimestre = trimestre,
                       duracion_segundos = resultado$duracion_segundos))
    registrar_metrica_generacion(
      TRUE, resultado$duracion_segundos, anio, trimestre,
      paste(resultado$advertencias, collapse = " | ")
    )
    evaluar_alertas_fuentes(resultado$advertencias)
    message("\n================ RESULTADO ================")
    message("Año: ", resultado$anio)
    message("Trimestres disponibles: ", paste0("Q", resultado$trimestres_disponibles, collapse = ", "))
    message("Trimestres generados: ", paste0("Q", resultado$trimestres_generados, collapse = ", "))
    message("Entregable: ", resultado$entregable)
    message("Diagnóstico: ", resultado$diagnostico)
    if (length(resultado$advertencias)) message(
      "Advertencias: ", paste(resultado$advertencias, collapse = " | ")
    )
    message("Duración: ", resultado$duracion_segundos, " segundos")
    message("Estado: PROCESO COMPLETADO")
    message("===========================================")
  }
  if (estado != 0L) quit(save = "no", status = estado)
}
