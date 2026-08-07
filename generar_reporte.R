#!/usr/bin/env Rscript

# Orquestador del reporte completo de seis secciones a partir de fuentes BIT.

raiz_motor <- getOption("reporte.raiz", getwd())
source(file.path(raiz_motor, "fuentes_bit.R"), local = globalenv(), encoding = "UTF-8")
source(file.path(raiz_motor, "motor_word_plantilla.R"), local = globalenv(), encoding = "UTF-8")

unidades_seccion <- c(
  "líneas", "accesos", "millones de pesos",
  "líneas", "accesos", "accesos"
)

# Las gráficas usan el diseño de mosaicos de la plantilla histórica.
# La implementación vive en motor_word_plantilla.R para mantener en un solo
# lugar la geometría, los colores y el ajuste de rótulos del documento modelo.

crear_parametros_periodo <- function(anio, trimestre, empresas_otros, version = "vBIT") {
  frase <- paste0(trimestre_texto(trimestre), " trimestre de ", as.integer(anio))
  parametros <- list(
    reporte = "Reporte de Datos del Sector de Telecomunicaciones",
    periodo_codigo = periodo_codigo(anio, trimestre),
    trimestre_numero = as.integer(trimestre),
    anio = as.integer(anio),
    periodo_texto = frase,
    periodo_portada = toupper(frase),
    version = version,
    estructura_tablas = "Fija; igual al DOCX de referencia",
    modo_control = "Validación automática de seis fuentes BIT",
    archivo_referencia = "Fuentes CSV publicadas en el BIT"
  )
  for (i in 1:6) {
    parametros[[paste0("empresas_otros_tabla_", i)]] <- as.integer(empresas_otros[[i]])
  }
  parametros
}

enriquecer_control <- function(control, fuentes, catalogo) {
  control$Archivo <- NA_character_
  control$URL <- NA_character_
  control$Ruta_local <- NA_character_
  control$MD5 <- NA_character_
  control$Unidad_reporte <- unidades_seccion[control$Seccion]
  for (id in names(ESPECIFICACIONES_FUENTES)) {
    e <- ESPECIFICACIONES_FUENTES[[id]]
    filas <- control$Seccion == e$orden
    control$Archivo[filas] <- e$archivo
    control$URL[filas] <- catalogo[[id]]
    control$Ruta_local[filas] <- normalizePath(
      fuentes[[id]]$ruta, winslash = "/", mustWork = TRUE
    )
    control$MD5[filas] <- unname(tools::md5sum(fuentes[[id]]$ruta))
  }
  control
}

generar_documento_periodo <- function(raiz, fuentes, catalogo, anio, trimestre,
                                      carpeta_reportes, carpeta_monitoreo,
                                      plantilla) {
  codigo <- periodo_codigo(anio, trimestre)
  preparado <- preparar_tablas_periodo(fuentes, anio, trimestre)
  tablas <- preparado$tablas
  parametros <- crear_parametros_periodo(anio, trimestre, preparado$empresas_otros)
  validar_parametros(parametros)
  validar_entrada(tablas)
  datos <- lapply(1:6, function(i) datos_seccion(tablas[[i]], i))

  monitoreo_periodo <- file.path(carpeta_monitoreo, codigo)
  dir.create(monitoreo_periodo, recursive = TRUE, showWarnings = FALSE)
  for (i in 1:6) {
    utils::write.csv(
      tablas[[i]],
      file.path(monitoreo_periodo, paste0("tabla_", i, ".csv")),
      row.names = FALSE,
      na = "",
      fileEncoding = "UTF-8"
    )
  }
  graficas <- file.path(monitoreo_periodo, paste0("grafica_", 1:6, ".png"))
  for (i in 1:6) guardar_grafica(datos[[i]], i, graficas[[i]])

  salida <- file.path(
    carpeta_reportes,
    paste0("Reporte_Telecomunicaciones_", codigo, "_vBIT.docx")
  )
  actualizar_word(
    plantilla = plantilla,
    salida = salida,
    tablas = tablas,
    textos = valores_texto(parametros, tablas, datos),
    graficas = graficas
  )
  if (!file.exists(salida) || file.info(salida)$size <= 0) {
    stop("No se creó correctamente el Word: ", salida)
  }
  list(
    reporte = normalizePath(salida, winslash = "/", mustWork = TRUE),
    control = enriquecer_control(preparado$control, fuentes, catalogo)
  )
}

interpretar_trimestre <- function(trimestre) {
  x <- normalizar_clave(trimestre)
  if (x %in% c("TODOS", "TODAS", "DISPONIBLES")) return(1:4)
  x <- sub("^Q", "", x)
  valor <- suppressWarnings(as.integer(x))
  if (is.na(valor) || !valor %in% 1:4) {
    stop("El trimestre debe ser todos, 1, 2, 3 o 4")
  }
  valor
}

trimestres_comunes <- function(fuentes, anio) {
  disponibles <- lapply(names(ESPECIFICACIONES_FUENTES), function(id) {
    trimestres_disponibles(
      fuentes[[id]]$datos,
      ESPECIFICACIONES_FUENTES[[id]],
      anio
    )
  })
  sort(Reduce(intersect, disponibles))
}

escribir_advertencias <- function(advertencias, ruta) {
  if (!length(advertencias)) return(invisible(NULL))
  writeLines(enc2utf8(unique(advertencias)), ruta, useBytes = TRUE)
  invisible(ruta)
}

ejecutar_generacion <- function(
    raiz,
    anio = 2024L,
    trimestre = "todos",
    carpeta_salidas = file.path(raiz, "salidas"),
    catalogo_excel = file.path(raiz, "config", "reporte-datos-sector-telecomunicaciones.xlsx"),
    carpeta_cache = file.path(raiz, "entrada", "datos_bit"),
    actualizar = FALSE,
    permitir_red = TRUE) {
  inicio <- Sys.time()
  anio <- suppressWarnings(as.integer(anio))
  if (is.na(anio) || anio < 2013L || anio > 2100L) stop("El año debe estar entre 2013 y 2100")
  if (isTRUE(actualizar) && !isTRUE(permitir_red)) {
    stop("No puede forzarse una actualización cuando la red está desactivada")
  }
  solicitado <- interpretar_trimestre(trimestre)
  modo_todos <- length(solicitado) == 4L

  marca <- format(inicio, "%Y%m%d_%H%M%S")
  carpeta_base <- file.path(
    carpeta_salidas,
    paste0("ejecucion_", anio, "_", marca, "_", Sys.getpid())
  )
  carpeta_ejecucion <- carpeta_base
  consecutivo <- 2L
  while (dir.exists(carpeta_ejecucion)) {
    carpeta_ejecucion <- paste0(carpeta_base, "_", consecutivo)
    consecutivo <- consecutivo + 1L
  }
  carpeta_reportes <- file.path(carpeta_ejecucion, "reportes")
  carpeta_monitoreo <- file.path(carpeta_ejecucion, "monitoreo")
  dir.create(carpeta_reportes, recursive = TRUE, showWarnings = FALSE)
  dir.create(carpeta_monitoreo, recursive = TRUE, showWarnings = FALSE)

  catalogo <- leer_catalogo_fuentes(catalogo_excel)
  cargadas <- cargar_todas_fuentes(
    catalogo = catalogo,
    carpeta_cache = carpeta_cache,
    anio = anio,
    trimestres_solicitados = solicitado,
    actualizar = actualizar,
    permitir_red = permitir_red
  )
  ruta_diagnostico <- file.path(carpeta_ejecucion, "diagnostico_fuentes.csv")
  utils::write.csv(
    cargadas$diagnostico,
    ruta_diagnostico,
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )

  comunes <- trimestres_comunes(cargadas$fuentes, anio)
  advertencias <- cargadas$advertencias
  if (modo_todos) {
    seleccionados <- intersect(solicitado, comunes)
    faltantes <- setdiff(solicitado, seleccionados)
    if (length(faltantes)) {
      advertencias <- c(
        advertencias,
        paste0(
          "El año ", anio, " no tiene cobertura común para Q",
          paste(faltantes, collapse = ", Q"),
          ". Solo se generan los trimestres completos."
        )
      )
    }
  } else {
    seleccionados <- solicitado
    if (!all(seleccionados %in% comunes)) {
      stop(
        "No puede generarse ", periodo_codigo(anio, seleccionados),
        " porque una o más secciones carecen del cierre requerido. Consulte ",
        normalizePath(ruta_diagnostico, winslash = "/", mustWork = TRUE)
      )
    }
  }
  if (!length(seleccionados)) {
    stop(
      "No existe ningún trimestre común a las seis fuentes para ", anio,
      ". Consulte ", normalizePath(ruta_diagnostico, winslash = "/", mustWork = TRUE)
    )
  }

  plantilla <- file.path(raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
  if (!file.exists(plantilla)) stop("No existe la plantilla Word: ", plantilla)
  resultados <- vector("list", length(seleccionados))
  controles <- vector("list", length(seleccionados))
  for (i in seq_along(seleccionados)) {
    q <- seleccionados[[i]]
    message(sprintf("[%d/%d] Generando %s", i, length(seleccionados), periodo_codigo(anio, q)))
    generado <- generar_documento_periodo(
      raiz = raiz,
      fuentes = cargadas$fuentes,
      catalogo = catalogo,
      anio = anio,
      trimestre = q,
      carpeta_reportes = carpeta_reportes,
      carpeta_monitoreo = carpeta_monitoreo,
      plantilla = plantilla
    )
    resultados[[i]] <- generado$reporte
    controles[[i]] <- generado$control
  }

  control <- do.call(rbind, controles)
  incidencias_valor <- control[control$Valores_imputados_cero > 0, , drop = FALSE]
  if (nrow(incidencias_valor)) {
    advertencias <- c(
      advertencias,
      vapply(seq_len(nrow(incidencias_valor)), function(i) {
        fila <- incidencias_valor[i, ]
        paste0(
          fila$Periodo, " / ", fila$Fuente, ": ",
          fila$Valores_imputados_cero,
          " valor(es) total(es) vacío(s) se trataron como cero y quedaron registrados."
        )
      }, character(1))
    )
  }
  ajustes_negativos <- control[control$Valores_negativos > 0, , drop = FALSE]
  if (nrow(ajustes_negativos)) {
    advertencias <- c(
      advertencias,
      vapply(seq_len(nrow(ajustes_negativos)), function(i) {
        fila <- ajustes_negativos[i, ]
        paste0(
          fila$Periodo, " / ", fila$Fuente, ": ", fila$Valores_negativos,
          " ajuste(s) negativo(s) se conservaron como están publicados."
        )
      }, character(1))
    )
  }
  ruta_control <- file.path(carpeta_ejecucion, "control_ejecucion.csv")
  utils::write.csv(control, ruta_control, row.names = FALSE, fileEncoding = "UTF-8")
  resumen_totales <- control[c("Periodo", "Seccion", "Fuente", "Total_reporte", "Unidad_reporte")]
  ruta_totales <- file.path(carpeta_ejecucion, "resumen_totales.csv")
  utils::write.csv(resumen_totales, ruta_totales, row.names = FALSE, fileEncoding = "UTF-8")
  ruta_advertencias <- file.path(carpeta_ejecucion, "advertencias.txt")
  escribir_advertencias(advertencias, ruta_advertencias)

  reportes <- unlist(resultados, use.names = FALSE)
  if (length(reportes) == 1L) {
    entregable <- reportes[[1]]
  } else {
    etiqueta_q <- paste0("Q", seleccionados, collapse = "_")
    entregable <- file.path(
      carpeta_ejecucion,
      paste0("Reportes_Telecomunicaciones_", anio, "_", etiqueta_q, ".zip")
    )
    archivos_zip <- c(
      file.path("reportes", basename(reportes)),
      basename(ruta_diagnostico),
      basename(ruta_control),
      basename(ruta_totales)
    )
    if (length(advertencias)) archivos_zip <- c(archivos_zip, basename(ruta_advertencias))
    zip::zipr(
      entregable,
      files = archivos_zip,
      root = carpeta_ejecucion,
      include_directories = FALSE
    )
  }

  list(
    ok = TRUE,
    anio = anio,
    trimestres_disponibles = comunes,
    trimestres_generados = seleccionados,
    reportes = normalizePath(reportes, winslash = "/", mustWork = TRUE),
    entregable = normalizePath(entregable, winslash = "/", mustWork = TRUE),
    carpeta = normalizePath(carpeta_ejecucion, winslash = "/", mustWork = TRUE),
    diagnostico = normalizePath(ruta_diagnostico, winslash = "/", mustWork = TRUE),
    control = normalizePath(ruta_control, winslash = "/", mustWork = TRUE),
    advertencias = unique(advertencias),
    duracion_segundos = round(as.numeric(difftime(Sys.time(), inicio, units = "secs")), 1)
  )
}
