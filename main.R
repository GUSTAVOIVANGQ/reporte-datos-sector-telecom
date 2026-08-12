#!/usr/bin/env Rscript

# Punto de entrada: interfaz Shiny o ejecución automática por año/trimestre.
args_completos <- commandArgs(trailingOnly = FALSE)
archivo_main <- sub("^--file=", "", args_completos[grepl("^--file=", args_completos)])
raiz <- if (length(archivo_main)) dirname(normalizePath(archivo_main[[1]])) else getwd()
args_usuario <- commandArgs(trailingOnly = TRUE)
options(reporte.raiz = raiz)

asegurar_paquetes <- function(paquetes) {
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) {
    message("Instalando paquetes faltantes: ", paste(faltan, collapse = ", "))
    utils::install.packages(faltan, repos = "https://cloud.r-project.org")
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
    "Reporte de Datos del Sector de Telecomunicaciones",
    "",
    "Uso:",
    "  Rscript main.R",
    "      Abre la interfaz local.",
    "",
    "  Rscript main.R --automatico --anio=2024 --trimestre=todos",
    "      Genera cada trimestre presente en al menos una fuente.",
    "      Las secciones ausentes se marcan con '-' y producen advertencias.",
    "",
    "  Rscript main.R --automatico --anio=2024 --trimestre=4",
    "      Genera únicamente 2024Q4.",
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
    sep = "\n"
  ), "\n")
}

if (any(args_usuario %in% c("--ayuda", "-h", "--help"))) {
  mostrar_ayuda()
  quit(save = "no", status = 0L)
}

modo_ui <- !length(args_usuario) || "--ui" %in% args_usuario
paquetes_motor <- c("readxl", "xml2", "zip", "data.table")
asegurar_paquetes(if (modo_ui) c(paquetes_motor, "shiny") else paquetes_motor)
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

if (modo_ui) {
  source(file.path(raiz, "app.R"), local = globalenv(), encoding = "UTF-8")
} else {
  anio <- valor_opcion("--anio", "2024")
  trimestre <- valor_opcion("--trimestre", "todos")
  carpeta_salidas <- valor_opcion("--salidas", file.path(raiz, "salidas"))
  catalogo <- valor_opcion(
    "--catalogo", file.path(raiz, "config", "reporte-datos-sector-telecomunicaciones.xlsx")
  )
  cache <- valor_opcion("--cache", file.path(raiz, "entrada", "datos_bit"))
  python <- valor_opcion("--python", "")
  if (nzchar(trimws(python))) options(reporte.python = trimws(python))
  actualizar <- "--actualizar" %in% args_usuario
  permitir_red <- !"--sin-red" %in% args_usuario

  estado <- 0L
  resultado <- tryCatch(
    ejecutar_generacion(
      raiz = raiz,
      anio = anio,
      trimestre = trimestre,
      carpeta_salidas = carpeta_salidas,
      catalogo_excel = catalogo,
      carpeta_cache = cache,
      actualizar = actualizar,
      permitir_red = permitir_red
    ),
    error = function(e) {
      estado <<- 1L
      message("\nERROR: ", conditionMessage(e))
      NULL
    }
  )

  if (!is.null(resultado)) {
    message("\n================ RESULTADO ================")
    message("Año: ", resultado$anio)
    message("Trimestres disponibles: ", paste0("Q", resultado$trimestres_disponibles, collapse = ", "))
    message("Trimestres generados: ", paste0("Q", resultado$trimestres_generados, collapse = ", "))
    message("Entregable: ", resultado$entregable)
    message("Diagnóstico: ", resultado$diagnostico)
    if (length(resultado$advertencias)) {
      message("Advertencias: ", paste(resultado$advertencias, collapse = " | "))
    }
    message("Duración: ", resultado$duracion_segundos, " segundos")
    message("Estado: PROCESO COMPLETADO")
    message("===========================================")
  }
  if (estado != 0L) quit(save = "no", status = estado)
}
