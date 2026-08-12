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

  for (candidato in candidatos) {
    ruta <- if (file.exists(candidato)) {
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
      codigo_rutas <- paste0(
        "import os,sysconfig; ",
        "p=[sysconfig.get_path('purelib'),sysconfig.get_path('platlib')]; ",
        "print(os.pathsep.join(dict.fromkeys(x for x in p if x)))"
      )
      rutas <- suppressWarnings(system2(
        ruta,
        args = c(prefijo, "-c", shQuote(codigo_rutas)),
        stdout = TRUE,
        stderr = TRUE
      ))
      heredado <- trimws(Sys.getenv(
        "REPORTE_PYTHONPATH", unset = Sys.getenv("PYTHONPATH", unset = "")
      ))
      partes <- unique(c(
        strsplit(paste(rutas, collapse = ""), .Platform$path.sep, fixed = TRUE)[[1]],
        strsplit(heredado, .Platform$path.sep, fixed = TRUE)[[1]]
      ))
      pythonpath <- paste(partes[nzchar(partes)], collapse = .Platform$path.sep)
      return(list(
        comando = ruta,
        prefijo = prefijo,
        version = paste(prueba, collapse = " "),
        pythonpath = pythonpath,
        env = if (nzchar(pythonpath)) paste0("PYTHONPATH=", pythonpath) else character()
      ))
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
    env = if (is.null(python$env)) character() else python$env,
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
