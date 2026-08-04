#!/usr/bin/env Rscript

# Único punto de entrada del proyecto.
args_completos <- commandArgs(trailingOnly = FALSE)
archivo_main <- sub("^--file=", "", args_completos[grepl("^--file=", args_completos)])
raiz <- if (length(archivo_main)) dirname(normalizePath(archivo_main[1])) else getwd()
args_usuario <- commandArgs(trailingOnly = TRUE)

opciones_google <- c(
  "--google-enabled" = "GOOGLE_ENABLED",
  "--google-email" = "GOOGLE_USER_EMAIL",
  "--google-folder-name" = "GOOGLE_DRIVE_FOLDER_NAME",
  "--google-folder-id" = "GOOGLE_DRIVE_FOLDER_ID",
  "--google-upload-files" = "GOOGLE_UPLOAD_FILES",
  "--google-create-sheets" = "GOOGLE_CREATE_SHEETS"
)
for (opcion in names(opciones_google)) {
  prefijo <- paste0(opcion, "=")
  coincidencias <- args_usuario[startsWith(args_usuario, prefijo)]
  if (length(coincidencias)) {
    valor <- substring(coincidencias[[length(coincidencias)]], nchar(prefijo) + 1L)
    do.call(Sys.setenv, setNames(list(valor), opciones_google[[opcion]]))
  }
}

asegurar_paquetes <- function(paquetes, obligatorios = TRUE) {
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) {
    message("Instalando paquetes faltantes: ", paste(faltan, collapse = ", "))
    try(utils::install.packages(faltan, repos = "https://cloud.r-project.org"), silent = TRUE)
  }
  pendientes <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(pendientes) && obligatorios) {
    stop("No fue posible instalar: ", paste(pendientes, collapse = ", "))
  }
  length(pendientes) == 0
}

if ("--ayuda" %in% args_usuario || "-h" %in% args_usuario) {
  cat(paste(
    "Uso:",
    "  Rscript main.R                         Abre la interfaz local",
    "  Rscript main.R --automatico            Genera con el Excel de prueba",
    "  Rscript main.R --automatico EXCEL [PLANTILLA] [SALIDAS]",
    "  Google personal es opcional y se configura desde la interfaz.",
    sep = "\n"
  ), "\n")
  quit(save = "no", status = 0L)
}

modo_ui <- !length(args_usuario) || "--ui" %in% args_usuario
if (modo_ui) {
  asegurar_paquetes("shiny")
  options(reporte.raiz = raiz)
  source(file.path(raiz, "app.R"), local = globalenv(), encoding = "UTF-8")
} else {
  inicio <- Sys.time()
  estado <- 0L
  entorno <- new.env(parent = globalenv())
  advertencias <- character()

  tryCatch({
    asegurar_paquetes(c("readxl", "xml2", "zip"))
    withCallingHandlers(
      source(file.path(raiz, "generar_reporte.R"), local = entorno, encoding = "UTF-8"),
      warning = function(w) {
        advertencias <<- unique(c(advertencias, conditionMessage(w)))
        invokeRestart("muffleWarning")
      }
    )

    if (length(advertencias)) {
      detalle <- paste(utils::head(advertencias, 10), collapse = " | ")
      if (length(advertencias) > 10) detalle <- paste(detalle, "| Hay advertencias adicionales")
      entorno$registrar("Advertencias", "Advertencia", detalle)
    } else {
      entorno$registrar("Advertencias", "Completado", "La generación local no produjo advertencias")
    }

    duracion <- round(as.numeric(difftime(Sys.time(), inicio, units = "secs")), 1)
    entorno$registrar("Resultado local", "Completado", paste("Ejecución", entorno$id_ejecucion))
    entorno$registrar("Duración", "Completado", paste(duracion, "segundos"))

    source(file.path(raiz, "google_api.R"), local = entorno, encoding = "UTF-8")
    entorno$respaldar_google(
      archivo_excel = entorno$archivo_excel,
      salida_word = entorno$salida_word,
      carpeta_ejecucion = entorno$carpeta_ejecucion,
      carpeta_monitoreo = entorno$carpeta_monitoreo,
      id_ejecucion = entorno$id_ejecucion,
      tablas = entorno$tablas,
      registrar = entorno$registrar,
      asegurar_paquetes = asegurar_paquetes
    )

    message("\nPROCESO COMPLETADO")
    message("Word: ", normalizePath(entorno$salida_word))
    message("Salida: ", normalizePath(entorno$carpeta_ejecucion))
  }, error = function(e) {
    estado <<- 1L
    detalle <- conditionMessage(e)
    if (exists("registrar", envir = entorno, inherits = FALSE)) {
      try(entorno$registrar("Resultado", "Error", detalle), silent = TRUE)
    } else {
      dir.create(file.path(raiz, "salidas"), recursive = TRUE, showWarnings = FALSE)
      ruta_error <- file.path(raiz, "salidas", paste0("error_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
      writeLines(c(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), detalle), ruta_error, useBytes = TRUE)
    }
    message("\nERROR: ", detalle)
  })

  if (estado != 0L) quit(save = "no", status = estado)
}
