# Lectura, descarga, validación y agregación de las seis fuentes del BIT.

ESPECIFICACIONES_FUENTES <- list(
  lineas_movil = list(
    id = "lineas_movil", orden = 1L,
    etiqueta = "Líneas activas de telefonía móvil",
    archivo = "TD_LINEAS_TELMOVIL_ITE_VA.csv",
    periodo = "MES", valor = "L_TOTAL_E", tipo_periodo = "mensual",
    divisor = 1,
    objetivos = c("AMERICA MOVIL", "AT&T", "TELEFONICA", "GRUPO WALMART")
  ),
  internet_movil = list(
    id = "internet_movil", orden = 2L,
    etiqueta = "Accesos activos a internet en el servicio móvil",
    archivo = "TD_LINEAS_INTMOVIL_ITE_VA.csv",
    periodo = "MES", valor = "L_TOTAL_E", tipo_periodo = "mensual",
    divisor = 1,
    objetivos = c("AMERICA MOVIL", "AT&T", "TELEFONICA", "GRUPO WALMART")
  ),
  ingresos = list(
    id = "ingresos", orden = 3L,
    etiqueta = "Ingresos",
    archivo = "TD_INGRESOS_TELECOM_ITE_VA.csv",
    periodo = "TRIM", valor = "INGRESOS_TOTAL_E", tipo_periodo = "trimestral",
    divisor = 1e6,
    objetivos = c(
      "AMERICA MOVIL", "AT&T", "GRUPO TELEVISA", "MEGACABLE-MCM",
      "GRUPO SALINAS", "TELEFONICA", "GRUPO WALMART", "AXTEL", "ALTAN"
    ),
    capacidades = c(
      "AMERICA MOVIL" = 3L, "AT&T" = 1L, "GRUPO TELEVISA" = 5L,
      "MEGACABLE-MCM" = 3L, "GRUPO SALINAS" = 1L, "TELEFONICA" = 2L,
      "GRUPO WALMART" = 1L, "AXTEL" = 1L, "ALTAN" = 1L
    ),
    permitir_negativos = TRUE
  ),
  lineas_fijas = list(
    id = "lineas_fijas", orden = 4L,
    etiqueta = "Líneas del servicio fijo de telefonía",
    archivo = "TD_LINEAS_TELFIJA_ITE_VA.csv",
    periodo = "MES", valor = "L_TOTAL_E", tipo_periodo = "mensual",
    divisor = 1,
    objetivos = c("AMERICA MOVIL", "GRUPO TELEVISA", "MEGACABLE-MCM", "GRUPO SALINAS"),
    capacidades = c(
      "AMERICA MOVIL" = 1L, "GRUPO TELEVISA" = 5L,
      "MEGACABLE-MCM" = 3L, "GRUPO SALINAS" = 1L
    )
  ),
  internet_fijo = list(
    id = "internet_fijo", orden = 5L,
    etiqueta = "Accesos a internet en el servicio fijo",
    archivo = "TD_ACC_BAF_ITE_VA.csv",
    periodo = "MES", valor = "A_TOTAL_E", tipo_periodo = "mensual",
    divisor = 1,
    objetivos = c("AMERICA MOVIL", "GRUPO TELEVISA", "MEGACABLE-MCM", "GRUPO SALINAS"),
    capacidades = c(
      "AMERICA MOVIL" = 1L, "GRUPO TELEVISA" = 4L,
      "MEGACABLE-MCM" = 3L, "GRUPO SALINAS" = 1L
    )
  ),
  tv_restringida = list(
    id = "tv_restringida", orden = 6L,
    etiqueta = "Accesos a televisión restringida",
    archivo = "TD_ACC_TVRES_ITE_VA.csv",
    periodo = "MES", valor = "A_TOTAL_E", tipo_periodo = "mensual",
    divisor = 1,
    objetivos = c("GRUPO TELEVISA", "MEGACABLE-MCM", "GRUPO SALINAS", "DISH-MVS"),
    capacidades = c(
      "GRUPO TELEVISA" = 4L, "MEGACABLE-MCM" = 1L,
      "GRUPO SALINAS" = 1L, "DISH-MVS" = 1L
    )
  )
)

normalizar_clave <- function(x) {
  x <- trimws(as.character(x))
  x <- toupper(x)
  x <- chartr("ÁÉÍÓÚÜÑ", "AEIOUUN", x)
  gsub("[[:space:]]+", " ", x)
}

presentar_nombre <- function(x) {
  x <- trimws(as.character(x))
  if (!length(x) || is.na(x) || !nzchar(x)) return("Sin información")
  y <- tools::toTitleCase(tolower(x))
  reemplazos <- c(
    "At&T" = "AT&T", "At&t" = "AT&T", "Mcm" = "MCM", "Pcs" = "PCS", "Altan" = "Altán",
    "Telefonica" = "Telefónica", "Mexico" = "México",
    "Movil" = "Móvil", "Telefonia" = "Telefonía",
    "Comunicacion" = "Comunicación", "Innovacion" = "Innovación",
    "Integracion" = "Integración", "Corporacion" = "Corporación",
    "Radiomovil" = "Radiomóvil", "Telefonos" = "Teléfonos",
    "Television" = "Televisión", "Tecnologia" = "Tecnología",
    "S.a.b." = "S.A.B.", "S.a.p.i." = "S.A.P.I.",
    "S.a." = "S.A.", "C.v." = "C.V.", "R.l." = "R.L."
  )
  for (patron in names(reemplazos)) y <- gsub(patron, reemplazos[[patron]], y, fixed = TRUE)
  y <- gsub("Comunicaciónes", "Comunicaciones", y, fixed = TRUE)
  y <- gsub("Integraciónes", "Integraciones", y, fixed = TRUE)
  y <- gsub("Innovaciónes", "Innovaciones", y, fixed = TRUE)
  y <- gsub("Corporaciónes", "Corporaciones", y, fixed = TRUE)
  y <- gsub("TecnologíaS", "Tecnologías", y, fixed = TRUE)
  y <- gsub("Tecnologíaes", "Tecnologías", y, fixed = TRUE)
  y <- gsub("Telecomunicaciónes", "Telecomunicaciones", y, fixed = TRUE)
  y <- gsub(" De ", " de ", y, fixed = TRUE)
  y <- gsub(" Del ", " del ", y, fixed = TRUE)
  y <- gsub(" Y ", " y ", y, fixed = TRUE)
  y
}

presentar_grupo <- function(clave) {
  mapa <- c(
    "AMERICA MOVIL" = "América Móvil", "AT&T" = "AT&T",
    "TELEFONICA" = "Telefónica", "GRUPO WALMART" = "Grupo Walmart",
    "GRUPO TELEVISA" = "Grupo Televisa", "GRUPO SALINAS" = "Grupo Salinas",
    "MEGACABLE-MCM" = "Megacable-MCM", "DISH-MVS" = "Dish",
    "ALTAN" = "Altán", "AXTEL" = "Axtel", "OTROS" = "Otros"
  )
  if (clave %in% names(mapa)) unname(mapa[[clave]]) else presentar_nombre(clave)
}

trimestre_texto <- function(trimestre) {
  c("primer", "segundo", "tercer", "cuarto")[[as.integer(trimestre)]]
}

periodo_codigo <- function(anio, trimestre) paste0(as.integer(anio), "Q", as.integer(trimestre))

detectar_codificacion <- function(ruta) {
  tamano <- file.info(ruta)$size
  conexion <- file(ruta, open = "rb")
  on.exit(close(conexion), add = TRUE)
  contenido <- readBin(conexion, what = "raw", n = tamano)
  texto <- rawToChar(contenido)
  if (!is.na(iconv(texto, from = "UTF-8", to = "UTF-8"))) "UTF-8-BOM" else "latin1"
}

leer_csv_fuente <- function(ruta, especificacion) {
  if (!file.exists(ruta)) stop("No existe el CSV: ", ruta)
  codificacion <- detectar_codificacion(ruta)
  datos <- utils::read.csv(
    ruta,
    fileEncoding = codificacion,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA", "N/A"),
    quote = "\"",
    comment.char = ""
  )
  names(datos) <- trimws(sub("^\ufeff", "", names(datos)))
  requeridas <- unique(c(
    "FOLIO", "ANIO", especificacion$periodo, "K_GRUPO", "GRUPO",
    "K_EMPRESA", "EMPRESA", "CONCESIONARIO", especificacion$valor
  ))
  if (identical(especificacion$id, "ingresos")) requeridas <- c(requeridas, "I_ANUAL_TRIM")
  faltantes <- setdiff(requeridas, names(datos))
  if (length(faltantes)) {
    stop(
      "El archivo ", especificacion$archivo,
      " no contiene las columnas requeridas: ", paste(faltantes, collapse = ", ")
    )
  }

  columnas_texto <- intersect(
    c("FOLIO", "K_GRUPO", "GRUPO", "K_EMPRESA", "EMPRESA", "CONCESIONARIO", "I_ANUAL_TRIM"),
    names(datos)
  )
  datos[columnas_texto] <- lapply(datos[columnas_texto], function(x) trimws(as.character(x)))
  datos$.ANIO <- suppressWarnings(as.integer(datos$ANIO))
  datos$.PERIODO <- suppressWarnings(as.integer(datos[[especificacion$periodo]]))
  datos$.VALOR <- suppressWarnings(as.numeric(datos[[especificacion$valor]]))

  if (identical(especificacion$id, "ingresos")) {
    tipo <- normalizar_clave(datos$I_ANUAL_TRIM)
    datos <- datos[!is.na(tipo) & tipo == "TRIMESTRAL", , drop = FALSE]
  }
  if (!nrow(datos)) stop("La fuente no contiene observaciones utilizables: ", especificacion$archivo)

  grupo <- datos$GRUPO
  grupo[is.na(grupo) | !nzchar(trimws(grupo))] <- "Sin información"
  empresa <- datos$EMPRESA
  empresa[is.na(empresa) | !nzchar(trimws(empresa))] <- "Sin información"
  concesionario <- datos$CONCESIONARIO
  concesionario[is.na(concesionario) | !nzchar(trimws(concesionario))] <- "Sin información"
  datos$.GRUPO_CLAVE <- normalizar_clave(grupo)
  datos$.EMPRESA_PRESENTACION <- vapply(empresa, presentar_nombre, character(1))
  datos$.CONCESIONARIO_PRESENTACION <- vapply(concesionario, presentar_nombre, character(1))
  datos$.CODIFICACION <- codificacion
  datos
}

leer_catalogo_fuentes <- function(ruta_excel) {
  if (!file.exists(ruta_excel)) stop("No existe el catálogo de enlaces: ", ruta_excel)
  catalogo <- as.data.frame(
    readxl::read_excel(ruta_excel, sheet = 1, col_names = TRUE, .name_repair = "minimal"),
    stringsAsFactors = FALSE
  )
  if (ncol(catalogo) < 2) stop("El catálogo debe contener las columnas Sector y Enlaces")
  urls <- trimws(as.character(catalogo[[2]]))
  urls <- urls[!is.na(urls) & nzchar(urls)]
  archivos <- basename(sub("[?#].*$", "", urls))
  salida <- setNames(rep(NA_character_, length(ESPECIFICACIONES_FUENTES)), names(ESPECIFICACIONES_FUENTES))
  for (id in names(ESPECIFICACIONES_FUENTES)) {
    archivo <- ESPECIFICACIONES_FUENTES[[id]]$archivo
    coincidencias <- which(archivos == archivo)
    if (length(coincidencias) != 1L) {
      stop("El catálogo debe contener exactamente un enlace para ", archivo)
    }
    salida[[id]] <- urls[[coincidencias]]
  }
  salida
}

trimestres_disponibles <- function(datos, especificacion, anio) {
  periodos <- sort(unique(datos$.PERIODO[datos$.ANIO == as.integer(anio) & !is.na(datos$.PERIODO)]))
  if (identical(especificacion$tipo_periodo, "mensual")) {
    return(which(((1:4) * 3L) %in% periodos))
  }
  intersect(1:4, periodos)
}

diagnosticar_fuente <- function(datos, especificacion, anio, url, ruta, origen) {
  del_anio <- datos[datos$.ANIO == as.integer(anio), , drop = FALSE]
  trimestres <- trimestres_disponibles(datos, especificacion, anio)
  anios <- sort(unique(datos$.ANIO[!is.na(datos$.ANIO)]))
  data.frame(
    Seccion = especificacion$orden,
    Fuente = especificacion$etiqueta,
    Archivo = especificacion$archivo,
    URL = url,
    Ruta_local = normalizePath(ruta, winslash = "/", mustWork = TRUE),
    Origen = origen,
    Anio_solicitado = as.integer(anio),
    Estado_anual = if (!nrow(del_anio)) "Ausente" else if (identical(trimestres, 1:4)) "Completo" else "Parcial",
    Trimestres_disponibles = if (length(trimestres)) paste0("Q", trimestres, collapse = ",") else "",
    Periodos_crudos = paste(sort(unique(del_anio$.PERIODO[!is.na(del_anio$.PERIODO)])), collapse = ","),
    Anio_minimo = if (length(anios)) min(anios) else NA_integer_,
    Anio_maximo = if (length(anios)) max(anios) else NA_integer_,
    Filas_anio = nrow(del_anio),
    Valores_invalidos_anio = sum(is.na(del_anio$.VALOR)),
    Valores_negativos_anio = sum(del_anio$.VALOR < 0, na.rm = TRUE),
    Filas_duplicadas_exactas_anio = sum(duplicated(del_anio)),
    Codificacion = unique(datos$.CODIFICACION)[[1]],
    MD5 = unname(tools::md5sum(ruta)),
    stringsAsFactors = FALSE
  )
}

descargar_y_validar_fuente <- function(url, destino, especificacion) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  temporal <- tempfile(paste0(especificacion$id, "_"), fileext = ".csv")
  on.exit(unlink(temporal), add = TRUE)
  estado <- utils::download.file(url, temporal, mode = "wb", quiet = TRUE)
  if (!identical(estado, 0L) && !identical(estado, 0)) stop("La descarga devolvió el código ", estado)
  invisible(leer_csv_fuente(temporal, especificacion))
  if (!file.copy(temporal, destino, overwrite = TRUE)) {
    stop("No fue posible guardar la fuente descargada: ", destino)
  }
  normalizePath(destino, winslash = "/", mustWork = TRUE)
}

cargar_fuente <- function(especificacion, url, carpeta_cache, anio,
                           trimestres_solicitados = 1:4, actualizar = FALSE,
                           permitir_red = TRUE) {
  ruta <- file.path(carpeta_cache, especificacion$archivo)
  advertencias <- character()
  origen <- "caché local"
  descargar <- actualizar || !file.exists(ruta)

  if (descargar) {
    if (!permitir_red) stop("No existe una copia local válida y la red está desactivada: ", ruta)
    intento <- tryCatch(
      descargar_y_validar_fuente(url, ruta, especificacion),
      error = function(e) e
    )
    if (inherits(intento, "error")) {
      if (!file.exists(ruta)) stop("No se pudo descargar ", especificacion$archivo, ": ", conditionMessage(intento))
      advertencias <- c(advertencias, paste("No se pudo actualizar", especificacion$archivo, conditionMessage(intento)))
    } else {
      origen <- "descarga BIT"
    }
  }

  datos <- tryCatch(leer_csv_fuente(ruta, especificacion), error = function(e) e)
  if (inherits(datos, "error")) {
    if (!permitir_red) stop(conditionMessage(datos))
    descargar_y_validar_fuente(url, ruta, especificacion)
    datos <- leer_csv_fuente(ruta, especificacion)
    origen <- "descarga BIT"
  }

  faltan <- setdiff(trimestres_solicitados, trimestres_disponibles(datos, especificacion, anio))
  if (length(faltan) && permitir_red && !actualizar) {
    intento <- tryCatch(
      descargar_y_validar_fuente(url, ruta, especificacion),
      error = function(e) e
    )
    if (inherits(intento, "error")) {
      advertencias <- c(
        advertencias,
        paste0(
          especificacion$archivo, " no contiene Q", paste(faltan, collapse = ",Q"),
          " de ", anio, " y no pudo actualizarse: ", conditionMessage(intento)
        )
      )
    } else {
      datos <- leer_csv_fuente(ruta, especificacion)
      origen <- "descarga BIT por cobertura faltante"
    }
  }

  list(
    datos = datos,
    ruta = ruta,
    origen = origen,
    advertencias = advertencias,
    diagnostico = diagnosticar_fuente(datos, especificacion, anio, url, ruta, origen)
  )
}

cargar_todas_fuentes <- function(catalogo, carpeta_cache, anio,
                                  trimestres_solicitados = 1:4,
                                  actualizar = FALSE, permitir_red = TRUE) {
  fuentes <- vector("list", length(ESPECIFICACIONES_FUENTES))
  names(fuentes) <- names(ESPECIFICACIONES_FUENTES)
  advertencias <- character()
  diagnosticos <- vector("list", length(fuentes))
  for (i in seq_along(ESPECIFICACIONES_FUENTES)) {
    id <- names(ESPECIFICACIONES_FUENTES)[[i]]
    especificacion <- ESPECIFICACIONES_FUENTES[[id]]
    message("Validando ", especificacion$archivo)
    cargada <- cargar_fuente(
      especificacion = especificacion,
      url = catalogo[[id]],
      carpeta_cache = carpeta_cache,
      anio = anio,
      trimestres_solicitados = trimestres_solicitados,
      actualizar = actualizar,
      permitir_red = permitir_red
    )
    fuentes[[id]] <- cargada
    advertencias <- c(advertencias, cargada$advertencias)
    diagnosticos[[i]] <- cargada$diagnostico
  }
  list(
    fuentes = fuentes,
    diagnostico = do.call(rbind, diagnosticos),
    advertencias = unique(advertencias)
  )
}

compactar_lista <- function(x, max_elementos = 3L) {
  x <- unique(trimws(as.character(x)))
  x <- x[!is.na(x) & nzchar(x) & x != "Sin información"]
  if (!length(x)) return("Sin información")
  visibles <- utils::head(x, max_elementos)
  texto <- paste(visibles, collapse = "; ")
  if (length(x) > max_elementos) texto <- paste0(texto, "; +", length(x) - max_elementos, " más")
  texto
}

datos_periodo <- function(datos, especificacion, anio, trimestre) {
  periodo_objetivo <- if (identical(especificacion$tipo_periodo, "mensual")) {
    as.integer(trimestre) * 3L
  } else {
    as.integer(trimestre)
  }
  salida <- datos[
    datos$.ANIO == as.integer(anio) & datos$.PERIODO == periodo_objetivo,
    , drop = FALSE
  ]
  if (!nrow(salida)) {
    stop(
      "No hay datos para ", especificacion$etiqueta, " en ",
      periodo_codigo(anio, trimestre)
    )
  }
  # Algunos CSV oficiales contienen celdas de total vacías aun cuando el
  # periodo sí está publicado. Se conservan como una incidencia auditable y
  # se imputan a cero para no impedir la generación del resto del reporte.
  salida$.VALOR_IMPUTADO <- is.na(salida$.VALOR)
  salida$.VALOR[salida$.VALOR_IMPUTADO] <- 0
  permitir_negativos <- isTRUE(especificacion$permitir_negativos)
  if (!permitir_negativos && any(salida$.VALOR < 0)) {
    stop(especificacion$archivo, " contiene valores negativos en ", periodo_codigo(anio, trimestre))
  }
  salida
}

agrupar_periodo <- function(periodo) {
  por_grupo <- stats::aggregate(
    periodo$.VALOR,
    by = list(GRUPO_CLAVE = periodo$.GRUPO_CLAVE),
    FUN = sum,
    na.rm = TRUE
  )
  names(por_grupo)[[2]] <- "VALOR"
  por_grupo <- por_grupo[order(-por_grupo$VALOR, por_grupo$GRUPO_CLAVE), , drop = FALSE]
  detalle <- stats::aggregate(
    periodo$.VALOR,
    by = list(
      GRUPO_CLAVE = periodo$.GRUPO_CLAVE,
      EMPRESA = periodo$.EMPRESA_PRESENTACION,
      CONCESIONARIO = periodo$.CONCESIONARIO_PRESENTACION
    ),
    FUN = sum,
    na.rm = TRUE
  )
  names(detalle)[[4]] <- "VALOR"
  detalle <- detalle[order(detalle$GRUPO_CLAVE, -detalle$VALOR), , drop = FALSE]
  list(por_grupo = por_grupo, detalle = detalle)
}

crear_tabla_simple <- function(resumen, especificacion) {
  filas <- lapply(especificacion$objetivos, function(clave) {
    d <- resumen$detalle[resumen$detalle$GRUPO_CLAVE == clave, , drop = FALSE]
    d <- d[order(-d$VALOR), , drop = FALSE]
    total <- sum(d$VALOR)
    data.frame(
      grupo = presentar_grupo(clave),
      empresa = if (nrow(d)) d$EMPRESA[[1]] else "",
      concesionario = if (nrow(d)) compactar_lista(d$CONCESIONARIO, 4L) else "",
      valor = total / especificacion$divisor,
      stringsAsFactors = FALSE
    )
  })
  tabla <- do.call(rbind, filas)
  otros <- sum(resumen$por_grupo$VALOR[!resumen$por_grupo$GRUPO_CLAVE %in% especificacion$objetivos])
  total <- sum(resumen$por_grupo$VALOR)
  tabla <- rbind(
    tabla,
    data.frame(grupo = "Otros", empresa = "", concesionario = "", valor = otros, stringsAsFactors = FALSE),
    data.frame(grupo = "TOTAL", empresa = "", concesionario = "", valor = total, stringsAsFactors = FALSE)
  )
  nombre_valor <- if (especificacion$orden == 1L) "Líneas activas" else "Accesos activos"
  names(tabla) <- c("Grupo Económico", "Empresa", "Concesionario", nombre_valor)
  tabla
}

crear_filas_detalle <- function(resumen, especificacion, clave, capacidad) {
  d <- resumen$detalle[resumen$detalle$GRUPO_CLAVE == clave, , drop = FALSE]
  d <- d[order(-d$VALOR), , drop = FALSE]
  total <- sum(d$VALOR)
  if (!nrow(d)) {
    d <- data.frame(
      GRUPO_CLAVE = clave, EMPRESA = "", CONCESIONARIO = "", VALOR = 0,
      stringsAsFactors = FALSE
    )
  } else if (nrow(d) > capacidad) {
    if (capacidad == 1L) {
      d <- data.frame(
        GRUPO_CLAVE = clave,
        EMPRESA = paste0(presentar_grupo(clave), " (consolidado)"),
        CONCESIONARIO = paste(nrow(d), "operadores consolidados"),
        VALOR = total,
        stringsAsFactors = FALSE
      )
    } else {
      principales <- d[seq_len(capacidad - 1L), , drop = FALSE]
      resto <- d[capacidad:nrow(d), , drop = FALSE]
      d <- rbind(
        principales,
        data.frame(
          GRUPO_CLAVE = clave,
          EMPRESA = "Otros del GIE",
          CONCESIONARIO = paste(nrow(resto), "operadores consolidados"),
          VALOR = sum(resto$VALOR),
          stringsAsFactors = FALSE
        )
      )
    }
  }
  if (nrow(d) < capacidad) {
    faltan <- capacidad - nrow(d)
    d <- rbind(
      d,
      data.frame(
        GRUPO_CLAVE = rep(clave, faltan), EMPRESA = rep("", faltan),
        CONCESIONARIO = rep("", faltan), VALOR = rep(NA_real_, faltan),
        stringsAsFactors = FALSE
      )
    )
  }
  data.frame(
    grupo = rep(presentar_grupo(clave), capacidad),
    total_gie = rep(total / especificacion$divisor, capacidad),
    empresa = d$EMPRESA,
    concesionario = d$CONCESIONARIO,
    valor = d$VALOR / especificacion$divisor,
    stringsAsFactors = FALSE
  )
}

crear_tabla_detallada <- function(resumen, especificacion) {
  filas <- lapply(especificacion$objetivos, function(clave) {
    crear_filas_detalle(
      resumen, especificacion, clave,
      as.integer(especificacion$capacidades[[clave]])
    )
  })
  tabla <- do.call(rbind, filas)
  otros <- sum(resumen$por_grupo$VALOR[!resumen$por_grupo$GRUPO_CLAVE %in% especificacion$objetivos])
  total <- sum(resumen$por_grupo$VALOR)
  tabla <- rbind(
    tabla,
    data.frame(
      grupo = "Otros", total_gie = NA_real_, empresa = "", concesionario = "",
      valor = otros / especificacion$divisor, stringsAsFactors = FALSE
    ),
    data.frame(
      grupo = "TOTAL", total_gie = NA_real_, empresa = "", concesionario = "",
      valor = total / especificacion$divisor, stringsAsFactors = FALSE
    )
  )
  encabezados <- switch(
    as.character(especificacion$orden),
    "3" = c(
      "Grupo Económico", "Ingresos por GIE (millones de pesos)",
      "Empresa", "Concesionario", "Ingresos (millones de pesos)"
    ),
    "4" = c("Grupo Económico", "Líneas fijas por GIE", "Empresa", "Concesionario", "Líneas fijas"),
    "5" = c("Grupo Económico", "Acceso por GIE", "Empresa", "Concesionario", "Accesos"),
    "6" = c("Grupo Económico", "Accesos por GIE", "Empresa", "Concesionario", "Accesos")
  )
  names(tabla) <- encabezados
  tabla
}

preparar_tabla_fuente <- function(datos, especificacion, anio, trimestre) {
  periodo <- datos_periodo(datos, especificacion, anio, trimestre)
  resumen <- agrupar_periodo(periodo)
  total <- sum(resumen$por_grupo$VALOR)
  if (!is.finite(total) || total <= 0) {
    stop("El total de ", especificacion$etiqueta, " no es positivo en ", periodo_codigo(anio, trimestre))
  }
  tabla <- if (especificacion$orden <= 2L) {
    crear_tabla_simple(resumen, especificacion)
  } else {
    crear_tabla_detallada(resumen, especificacion)
  }
  fuera <- periodo[!periodo$.GRUPO_CLAVE %in% especificacion$objetivos, , drop = FALSE]
  empresas_otros <- length(unique(fuera$K_EMPRESA[!is.na(fuera$K_EMPRESA) & nzchar(fuera$K_EMPRESA)]))
  control <- data.frame(
    Periodo = periodo_codigo(anio, trimestre),
    Seccion = especificacion$orden,
    Fuente = especificacion$etiqueta,
    Filas = nrow(periodo),
    Total_raw = total,
    Total_reporte = total / especificacion$divisor,
    Grupos = nrow(resumen$por_grupo),
    Empresas_en_otros = empresas_otros,
    Valores_imputados_cero = sum(periodo$.VALOR_IMPUTADO),
    Valores_negativos = sum(periodo$.VALOR < 0),
    Filas_duplicadas_exactas = sum(duplicated(periodo)),
    stringsAsFactors = FALSE
  )
  list(tabla = tabla, control = control, empresas_otros = empresas_otros)
}

preparar_tablas_periodo <- function(fuentes, anio, trimestre) {
  tablas <- vector("list", 6L)
  controles <- vector("list", 6L)
  empresas_otros <- integer(6L)
  for (id in names(ESPECIFICACIONES_FUENTES)) {
    especificacion <- ESPECIFICACIONES_FUENTES[[id]]
    resultado <- preparar_tabla_fuente(
      fuentes[[id]]$datos, especificacion, anio, trimestre
    )
    tablas[[especificacion$orden]] <- resultado$tabla
    controles[[especificacion$orden]] <- resultado$control
    empresas_otros[[especificacion$orden]] <- resultado$empresas_otros
  }
  list(
    tablas = tablas,
    control = do.call(rbind, controles),
    empresas_otros = empresas_otros
  )
}
