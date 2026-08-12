# Puente entre el motor R y el generador Python de gráficas jerárquicas.
# Ninguna descarga, agregación o modificación del Word se realiza en Python.

resolver_python <- function() {
  configurado <- trimws(as.character(getOption(
    "reporte.python", Sys.getenv("REPORTE_PYTHON", unset = "")
  )))
  candidatos <- unique(c(
    configurado,
    if (.Platform$OS.type == "windows") c("python", "python3", "py") else c("python3", "python")
  ))
  candidatos <- candidatos[nzchar(candidatos)]

  # En Windows, buscar también en ubicaciones comunes como fallback.
  if (.Platform$OS.type == "windows") {
    rutas_extra <- c(
      file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Python",
                list.files(file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Python"),
                           pattern = "^Python3", full.names = FALSE)),
      Sys.glob("C:/Python3*/python.exe"),
      Sys.glob(file.path(Sys.getenv("USERPROFILE"), "Downloads",
                         "python-*-embed-*/python.exe"))
    )
    rutas_extra <- unique(c(
      file.path(rutas_extra, "python.exe")[dir.exists(rutas_extra)],
      rutas_extra[!dir.exists(rutas_extra)]
    ))
    rutas_extra <- rutas_extra[file.exists(rutas_extra) & !dir.exists(rutas_extra)]
    candidatos <- unique(c(candidatos, rutas_extra))
  }

  for (candidato in candidatos) {
    # Descartar directorios que coincidan con el nombre (e.g. ./python/).
    ruta <- if (file.exists(candidato) && !dir.exists(candidato)) {
      normalizePath(candidato, winslash = "/", mustWork = TRUE)
    } else {
      unname(Sys.which(candidato))
    }
    if (!nzchar(ruta)) next
    prefijo <- if (tolower(basename(ruta)) %in% c("py", "py.exe")) "-3" else character()
    prueba <- suppressWarnings(system2(
      ruta,
      args = c(prefijo, "--version"),
      stdout = TRUE,
      stderr = TRUE
    ))
    estado <- attr(prueba, "status")
    if (is.null(estado) || identical(as.integer(estado), 0L)) {
      return(list(comando = ruta, prefijo = prefijo, version = paste(prueba, collapse = " ")))
    }
  }
  stop(
    "No se encontró Python 3. Instálelo o indique su ruta con --python=RUTA ",
    "o la variable REPORTE_PYTHON."
  )
}

ejecutar_script_graficas <- function(python, script, argumentos = character()) {
  salida <- suppressWarnings(system2(
    python$comando,
    args = c(python$prefijo, shQuote(script), argumentos),
    stdout = TRUE,
    stderr = TRUE
  ))
  estado <- attr(salida, "status")
  if (is.null(estado)) estado <- 0L
  if (as.integer(estado) != 0L) {
    detalle <- trimws(paste(salida, collapse = "\n"))
    if (!nzchar(detalle)) detalle <- paste0("código de salida ", estado)
    stop("Python no pudo crear la gráfica jerárquica: ", detalle)
  }
  invisible(salida)
}

validar_entorno_graficas_python <- function(raiz) {
  script <- file.path(raiz, "python", "graficas_jerarquia.py")
  if (!file.exists(script)) stop("No existe el generador Python: ", script)
  python <- resolver_python()
  ejecutar_script_graficas(python, script, "--check")
  list(python = python, script = normalizePath(script, winslash = "/", mustWork = TRUE))
}

guardar_grafica_python <- function(datos, seccion, ruta, entorno, periodo = "") {
  if (!seccion %in% 1:6) stop("La sección de la gráfica debe estar entre 1 y 6")
  if (!all(c("grupo", "valor") %in% names(datos))) {
    stop("Los datos para Python deben contener las columnas grupo y valor")
  }
  sin_datos <- !nrow(datos)
  if (!sin_datos &&
      (any(!is.finite(datos$valor)) || any(datos$valor < 0) || sum(datos$valor) <= 0)) {
    stop("La sección ", seccion, " contiene valores no válidos para la gráfica")
  }

  dir.create(dirname(ruta), recursive = TRUE, showWarnings = FALSE)
  if (sin_datos) {
    ejecutar_script_graficas(
      entorno$python,
      entorno$script,
      c(
        "--seccion", as.character(seccion),
        "--salida", shQuote(normalizePath(ruta, winslash = "/", mustWork = FALSE)),
        "--sin-datos",
        "--periodo", shQuote(as.character(periodo))
      )
    )
    if (!file.exists(ruta) || file.info(ruta)$size <= 0) {
      stop("Python no creó la gráfica sin datos de la sección ", seccion)
    }
    return(invisible(normalizePath(ruta, winslash = "/", mustWork = TRUE)))
  }

  entrada <- file.path(dirname(ruta), paste0("datos_grafica_", seccion, ".csv"))
  utils::write.csv(
    datos[c("grupo", "valor")],
    entrada,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  ejecutar_script_graficas(
    entorno$python,
    entorno$script,
    c(
      "--seccion", as.character(seccion),
      "--entrada", shQuote(normalizePath(entrada, winslash = "/", mustWork = TRUE)),
      "--salida", shQuote(normalizePath(ruta, winslash = "/", mustWork = FALSE))
    )
  )
  if (!file.exists(ruta) || file.info(ruta)$size <= 0) {
    stop("Python no creó correctamente la gráfica de la sección ", seccion)
  }
  invisible(normalizePath(ruta, winslash = "/", mustWork = TRUE))
}
