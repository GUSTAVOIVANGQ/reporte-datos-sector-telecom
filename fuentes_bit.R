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

CACHE_LECTURA_VERSION <- 2L

firma_archivo <- function(ruta) {
  info <- file.info(ruta)
  list(
    size = as.numeric(info$size[[1]]),
    mtime = as.numeric(info$mtime[[1]])
  )
}

misma_firma <- function(a, b) {
  is.list(a) && is.list(b) &&
    identical(as.numeric(a$size), as.numeric(b$size)) &&
    identical(as.numeric(a$mtime), as.numeric(b$mtime))
}

carpeta_cache_procesada <- function(ruta) {
  file.path(dirname(ruta), "_cache_reporte")
}

inspeccionar_codificacion <- function(ruta, bytes_muestra = 131072L) {
  conexion <- file(ruta, open = "rb")
  on.exit(close(conexion), add = TRUE)
  contenido <- readBin(conexion, what = "raw", n = bytes_muestra)
  enteros <- as.integer(contenido)
  if (length(enteros) >= 2L && identical(enteros[1:2], c(255L, 254L))) {
    return(list(codificacion = "UTF-16LE", contiene_nulos = TRUE))
  }
  if (length(enteros) >= 2L && identical(enteros[1:2], c(254L, 255L))) {
    return(list(codificacion = "UTF-16BE", contiene_nulos = TRUE))
  }
  if (length(enteros) >= 3L && identical(enteros[1:3], c(239L, 187L, 191L))) {
    return(list(codificacion = "UTF-8-BOM", contiene_nulos = any(enteros == 0L)))
  }
  contiene_nulos <- any(enteros == 0L)
  if (contiene_nulos && length(enteros) >= 32L) {
    posiciones_pares <- enteros[seq.int(2L, length(enteros), 2L)]
    posiciones_impares <- enteros[seq.int(1L, length(enteros), 2L)]
    proporcion_pares <- mean(posiciones_pares == 0L)
    proporcion_impares <- mean(posiciones_impares == 0L)
    if (proporcion_pares > 0.35 && proporcion_impares < 0.05) {
      return(list(codificacion = "UTF-16LE", contiene_nulos = TRUE))
    }
    if (proporcion_impares > 0.35 && proporcion_pares < 0.05) {
      return(list(codificacion = "UTF-16BE", contiene_nulos = TRUE))
    }
  }
  # La muestra puede terminar a la mitad de un carácter UTF-8. Se omiten
  # cuatro bytes finales únicamente para esta prueba de codificación.
  contenido_texto <- contenido[contenido != as.raw(0)]
  if (length(contenido_texto) > 4L) contenido_texto <- head(contenido_texto, -4L)
  texto <- rawToChar(contenido_texto, multiple = FALSE)
  utf8_valido <- !is.na(suppressWarnings(iconv(texto, from = "UTF-8", to = "UTF-8")))
  list(
    codificacion = if (utf8_valido) "UTF-8" else "latin1",
    contiene_nulos = contiene_nulos
  )
}

detectar_codificacion <- function(ruta) inspeccionar_codificacion(ruta)$codificacion

crear_copia_normalizada <- function(ruta, destino, codificacion) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  temporal <- tempfile("texto_normalizado_", tmpdir = dirname(destino), fileext = ".csv")
  on.exit(unlink(temporal), add = TRUE)
  if (codificacion %in% c("UTF-16LE", "UTF-16BE")) {
    entrada <- file(ruta, open = "rt", encoding = codificacion)
    salida <- file(temporal, open = "wt", encoding = "UTF-8")
    on.exit(try(close(entrada), silent = TRUE), add = TRUE)
    on.exit(try(close(salida), silent = TRUE), add = TRUE)
    repeat {
      lineas <- readLines(entrada, n = 25000L, warn = FALSE, skipNul = TRUE)
      if (!length(lineas)) break
      writeLines(enc2utf8(lineas), salida, useBytes = TRUE)
    }
    close(entrada)
    close(salida)
  } else {
    entrada <- file(ruta, open = "rb")
    salida <- file(temporal, open = "wb")
    on.exit(try(close(entrada), silent = TRUE), add = TRUE)
    on.exit(try(close(salida), silent = TRUE), add = TRUE)
    repeat {
      bloque <- readBin(entrada, what = "raw", n = 8L * 1024L * 1024L)
      if (!length(bloque)) break
      bloque <- bloque[bloque != as.raw(0)]
      writeBin(bloque, salida)
    }
    close(entrada)
    close(salida)
  }
  if (!file.copy(temporal, destino, overwrite = TRUE)) {
    stop("No fue posible crear la copia de lectura sin caracteres NUL: ", destino)
  }
  normalizePath(destino, winslash = "/", mustWork = TRUE)
}

preparar_ruta_lectura <- function(ruta, inspeccion) {
  requiere_copia <- inspeccion$codificacion %in% c("UTF-16LE", "UTF-16BE") ||
    isTRUE(inspeccion$contiene_nulos)
  if (!requiere_copia) {
    return(list(ruta = ruta, codificacion_fread = inspeccion$codificacion, normalizada = FALSE))
  }
  carpeta <- carpeta_cache_procesada(ruta)
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  destino <- file.path(carpeta, paste0(basename(ruta), ".normalizado.csv"))
  meta_ruta <- paste0(destino, ".meta.rds")
  firma <- firma_archivo(ruta)
  meta <- if (file.exists(meta_ruta)) {
    tryCatch(readRDS(meta_ruta), error = function(e) NULL)
  } else {
    NULL
  }
  vigente <- file.exists(destino) && is.list(meta) && misma_firma(meta$firma, firma) &&
    identical(meta$codificacion, inspeccion$codificacion)
  if (!vigente) {
    message("  Preparando una copia de lectura sin NUL/UTF-16 (se hace una sola vez)...")
    crear_copia_normalizada(ruta, destino, inspeccion$codificacion)
    saveRDS(list(firma = firma, codificacion = inspeccion$codificacion), meta_ruta)
  }
  list(
    ruta = destino,
    codificacion_fread = if (inspeccion$codificacion %in% c("UTF-16LE", "UTF-16BE")) {
      "UTF-8"
    } else {
      inspeccion$codificacion
    },
    normalizada = TRUE
  )
}

transformar_unicos <- function(x, funcion) {
  x <- as.character(x)
  unicos <- unique(x)
  transformados <- vapply(unicos, funcion, character(1), USE.NAMES = FALSE)
  transformados[match(x, unicos)]
}

leer_cache_datos <- function(ruta, especificacion) {
  cache_ruta <- file.path(
    carpeta_cache_procesada(ruta), paste0(basename(ruta), ".", especificacion$id, ".rds")
  )
  if (!file.exists(cache_ruta)) return(NULL)
  objeto <- tryCatch(readRDS(cache_ruta), error = function(e) NULL)
  if (!is.list(objeto) || !identical(objeto$version, CACHE_LECTURA_VERSION) ||
      !identical(objeto$fuente, especificacion$id) ||
      !misma_firma(objeto$firma, firma_archivo(ruta)) || !is.data.frame(objeto$datos)) {
    return(NULL)
  }
  datos <- objeto$datos
  attr(datos, "reporte_codificacion") <- objeto$codificacion
  attr(datos, "reporte_cache_usada") <- TRUE
  datos
}

guardar_cache_datos <- function(datos, ruta, especificacion, codificacion) {
  carpeta <- carpeta_cache_procesada(ruta)
  intento <- tryCatch({
    dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
    destino <- file.path(carpeta, paste0(basename(ruta), ".", especificacion$id, ".rds"))
    temporal <- tempfile("datos_procesados_", tmpdir = carpeta, fileext = ".rds")
    on.exit(unlink(temporal), add = TRUE)
    saveRDS(
      list(
        version = CACHE_LECTURA_VERSION,
        fuente = especificacion$id,
        firma = firma_archivo(ruta),
        codificacion = codificacion,
        datos = datos
      ),
      temporal,
      compress = FALSE
    )
    if (!file.copy(temporal, destino, overwrite = TRUE)) stop("no se pudo copiar el RDS")
    TRUE
  }, error = function(e) e)
  if (inherits(intento, "error")) {
    warning("No se pudo guardar la caché procesada de ", basename(ruta), ": ", conditionMessage(intento))
  }
  invisible(datos)
}

leer_csv_fuente <- function(ruta, especificacion, usar_cache = TRUE) {
  if (!file.exists(ruta)) stop("No existe el CSV: ", ruta)
  inicio <- proc.time()[["elapsed"]]
  if (isTRUE(usar_cache)) {
    datos_cache <- leer_cache_datos(ruta, especificacion)
    if (!is.null(datos_cache)) {
      attr(datos_cache, "reporte_segundos_lectura") <- proc.time()[["elapsed"]] - inicio
      return(datos_cache)
    }
  }

  inspeccion <- inspeccionar_codificacion(ruta)
  codificacion <- inspeccion$codificacion
  requeridas <- unique(c(
    "FOLIO", "ANIO", especificacion$periodo, "K_GRUPO", "GRUPO",
    "K_EMPRESA", "EMPRESA", "CONCESIONARIO", especificacion$valor
  ))
  if (identical(especificacion$id, "ingresos")) requeridas <- c(requeridas, "I_ANUAL_TRIM")

  if (requireNamespace("data.table", quietly = TRUE)) {
    lectura <- preparar_ruta_lectura(ruta, inspeccion)
    codificacion_fread <- if (identical(lectura$codificacion_fread, "latin1")) {
      "Latin-1"
    } else {
      "UTF-8"
    }
    datos <- tryCatch(
      data.table::fread(
        lectura$ruta,
        select = requeridas,
        encoding = codificacion_fread,
        na.strings = c("", "NA", "N/A"),
        strip.white = TRUE,
        check.names = FALSE,
        data.table = FALSE,
        showProgress = FALSE
      ),
      error = function(e) e
    )
    # En algunos archivos oficiales el NUL aparece después de la muestra
    # inicial. En ese caso se crea una copia saneada y se reintenta una vez.
    if (inherits(datos, "error") && grepl(
      "nul|UTF-16|invalid multibyte|embedded",
      conditionMessage(datos), ignore.case = TRUE
    )) {
      inspeccion_reintento <- inspeccion
      inspeccion_reintento$contiene_nulos <- TRUE
      lectura <- preparar_ruta_lectura(ruta, inspeccion_reintento)
      datos <- tryCatch(
        data.table::fread(
          lectura$ruta,
          select = requeridas,
          encoding = if (identical(lectura$codificacion_fread, "latin1")) "Latin-1" else "UTF-8",
          na.strings = c("", "NA", "N/A"),
          strip.white = TRUE,
          check.names = FALSE,
          data.table = FALSE,
          showProgress = FALSE
        ),
        error = function(e) e
      )
    }
    if (inherits(datos, "error")) {
      stop("No se pudo leer rápidamente ", especificacion$archivo, ": ", conditionMessage(datos))
    }
  } else {
    # Ruta de compatibilidad para instalaciones antiguas y las pruebas WebR.
    datos <- utils::read.csv(
      ruta,
      fileEncoding = codificacion,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA", "N/A"),
      quote = "\"",
      comment.char = "",
      skipNul = TRUE
    )
    datos <- datos[intersect(requeridas, names(datos))]
  }
  names(datos) <- trimws(sub("^\ufeff", "", names(datos)))
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
  datos$.GRUPO_CLAVE <- transformar_unicos(grupo, normalizar_clave)
  datos$.EMPRESA_PRESENTACION <- transformar_unicos(empresa, presentar_nombre)
  datos$.CONCESIONARIO_PRESENTACION <- transformar_unicos(concesionario, presentar_nombre)
  attr(datos, "reporte_codificacion") <- codificacion
  attr(datos, "reporte_cache_usada") <- FALSE
  attr(datos, "reporte_segundos_lectura") <- proc.time()[["elapsed"]] - inicio
  if (isTRUE(usar_cache)) guardar_cache_datos(datos, ruta, especificacion, codificacion)
  datos
}

obtener_md5_cacheado <- function(ruta) {
  carpeta <- carpeta_cache_procesada(ruta)
  dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
  meta_ruta <- file.path(carpeta, paste0(basename(ruta), ".md5.rds"))
  firma <- firma_archivo(ruta)
  meta <- if (file.exists(meta_ruta)) {
    tryCatch(readRDS(meta_ruta), error = function(e) NULL)
  } else {
    NULL
  }
  if (is.list(meta) && misma_firma(meta$firma, firma) &&
      is.character(meta$md5) && length(meta$md5) == 1L && nzchar(meta$md5)) {
    return(meta$md5)
  }
  md5 <- unname(tools::md5sum(ruta))
  try(saveRDS(list(firma = firma, md5 = md5), meta_ruta), silent = TRUE)
  md5
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

diagnosticar_fuente <- function(datos, especificacion, anio, url, ruta, origen, md5) {
  del_anio <- datos[datos$.ANIO == as.integer(anio), , drop = FALSE]
  trimestres <- trimestres_disponibles(datos, especificacion, anio)
  anios <- sort(unique(datos$.ANIO[!is.na(datos$.ANIO)]))
  columnas_duplicados <- intersect(
    c("FOLIO", "ANIO", especificacion$periodo, "K_GRUPO", "GRUPO",
      "K_EMPRESA", "EMPRESA", "CONCESIONARIO", especificacion$valor),
    names(del_anio)
  )
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
    Filas_duplicadas_exactas_anio = sum(duplicated(del_anio[columnas_duplicados])),
    Codificacion = as.character(attr(datos, "reporte_codificacion")),
    Cache_procesada = isTRUE(attr(datos, "reporte_cache_usada")),
    Segundos_lectura = round(as.numeric(attr(datos, "reporte_segundos_lectura")), 3),
    MD5 = md5,
    stringsAsFactors = FALSE
  )
}

descargar_y_validar_fuente <- function(url, destino, especificacion) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)
  temporal <- tempfile(paste0(especificacion$id, "_"), fileext = ".csv")
  on.exit(unlink(temporal), add = TRUE)
  estado <- utils::download.file(url, temporal, mode = "wb", quiet = TRUE)
  if (!identical(estado, 0L) && !identical(estado, 0)) stop("La descarga devolvió el código ", estado)
  datos <- leer_csv_fuente(temporal, especificacion, usar_cache = FALSE)
  if (!file.copy(temporal, destino, overwrite = TRUE)) {
    stop("No fue posible guardar la fuente descargada: ", destino)
  }
  guardar_cache_datos(
    datos, destino, especificacion, as.character(attr(datos, "reporte_codificacion"))
  )
  list(
    ruta = normalizePath(destino, winslash = "/", mustWork = TRUE),
    datos = datos
  )
}

cargar_fuente <- function(especificacion, url, carpeta_cache, anio,
                           trimestres_solicitados = 1:4, actualizar = FALSE,
                           permitir_red = TRUE) {
  inicio_carga <- proc.time()[["elapsed"]]
  ruta <- file.path(carpeta_cache, especificacion$archivo)
  advertencias <- character()
  origen <- "caché local"
  descargar <- actualizar || !file.exists(ruta)
  datos <- NULL

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
      datos <- intento$datos
    }
  }

  if (is.null(datos)) {
    datos <- tryCatch(leer_csv_fuente(ruta, especificacion), error = function(e) e)
  }
  if (inherits(datos, "error")) {
    if (!permitir_red) stop(conditionMessage(datos))
    descargada <- descargar_y_validar_fuente(url, ruta, especificacion)
    datos <- descargada$datos
    origen <- "descarga BIT"
  }

  faltan <- setdiff(trimestres_solicitados, trimestres_disponibles(datos, especificacion, anio))
  if (length(faltan)) {
    advertencias <- c(
      advertencias,
      paste0(
        especificacion$archivo, " no contiene Q", paste(faltan, collapse = ",Q"),
        " de ", anio, ". Se conserva el CSV local; use 'Forzar actualización' ",
        "cuando el CRT publique una versión nueva."
      )
    )
  }

  md5 <- obtener_md5_cacheado(ruta)
  diagnostico <- diagnosticar_fuente(
    datos, especificacion, anio, url, ruta, origen, md5
  )
  diagnostico$Segundos_validacion <- round(
    proc.time()[["elapsed"]] - inicio_carga, 3
  )

  list(
    datos = datos,
    ruta = ruta,
    origen = origen,
    md5 = md5,
    advertencias = advertencias,
    diagnostico = diagnostico
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
    message(sprintf(
      "  OK: %s filas; lectura %s; %.2f s",
      format(nrow(cargada$datos), big.mark = ",", scientific = FALSE),
      if (isTRUE(cargada$diagnostico$Cache_procesada[[1]])) "desde caché procesada" else "desde CSV",
      cargada$diagnostico$Segundos_validacion[[1]]
    ))
    advertencias <- c(advertencias, cargada$advertencias)
    diagnosticos[[i]] <- cargada$diagnostico
  }
  list(
    fuentes = fuentes,
    diagnostico = do.call(rbind, diagnosticos),
    advertencias = unique(advertencias)
  )
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
  if (requireNamespace("data.table", quietly = TRUE)) {
    dt <- data.table::as.data.table(periodo)
    por_grupo <- dt[, list(VALOR = sum(.VALOR, na.rm = TRUE)),
                    by = list(GRUPO_CLAVE = .GRUPO_CLAVE)]
    detalle <- dt[, list(VALOR = sum(.VALOR, na.rm = TRUE)), by = list(
      GRUPO_CLAVE = .GRUPO_CLAVE,
      EMPRESA = .EMPRESA_PRESENTACION,
      CONCESIONARIO = .CONCESIONARIO_PRESENTACION
    )]
    data.table::setorder(por_grupo, -VALOR, GRUPO_CLAVE)
    data.table::setorder(detalle, GRUPO_CLAVE, -VALOR)
    data.table::setDF(por_grupo)
    data.table::setDF(detalle)
    return(list(por_grupo = por_grupo, detalle = detalle))
  }
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
    if (!nrow(d)) {
      d <- data.frame(
        EMPRESA = "", CONCESIONARIO = "", VALOR = 0,
        stringsAsFactors = FALSE
      )
    }
    data.frame(
      grupo = rep(presentar_grupo(clave), nrow(d)),
      empresa = d$EMPRESA,
      concesionario = d$CONCESIONARIO,
      valor = d$VALOR / especificacion$divisor,
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

crear_filas_detalle <- function(resumen, especificacion, clave) {
  d <- resumen$detalle[resumen$detalle$GRUPO_CLAVE == clave, , drop = FALSE]
  d <- d[order(-d$VALOR), , drop = FALSE]
  total <- sum(d$VALOR)
  if (!nrow(d)) {
    d <- data.frame(
      GRUPO_CLAVE = clave, EMPRESA = "", CONCESIONARIO = "", VALOR = 0,
      stringsAsFactors = FALSE
    )
  }
  data.frame(
    grupo = rep(presentar_grupo(clave), nrow(d)),
    total_gie = rep(total / especificacion$divisor, nrow(d)),
    empresa = d$EMPRESA,
    concesionario = d$CONCESIONARIO,
    valor = d$VALOR / especificacion$divisor,
    stringsAsFactors = FALSE
  )
}

crear_tabla_detallada <- function(resumen, especificacion) {
  filas <- lapply(especificacion$objetivos, function(clave) {
    crear_filas_detalle(resumen, especificacion, clave)
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

crear_tabla_vacia <- function(especificacion) {
  if (especificacion$orden <= 2L) {
    nombre_valor <- if (especificacion$orden == 1L) "Líneas activas" else "Accesos activos"
    tabla <- data.frame(
      grupo = c("-", "TOTAL"), empresa = c("-", ""),
      concesionario = c("-", ""), valor = c(NA_real_, NA_real_),
      stringsAsFactors = FALSE
    )
    names(tabla) <- c("Grupo Económico", "Empresa", "Concesionario", nombre_valor)
    return(tabla)
  }

  tabla <- data.frame(
    grupo = c("-", "TOTAL"), total_gie = c(NA_real_, NA_real_),
    empresa = c("-", ""), concesionario = c("-", ""),
    valor = c(NA_real_, NA_real_), stringsAsFactors = FALSE
  )
  names(tabla) <- switch(
    as.character(especificacion$orden),
    "3" = c(
      "Grupo Económico", "Ingresos por GIE (millones de pesos)",
      "Empresa", "Concesionario", "Ingresos (millones de pesos)"
    ),
    "4" = c("Grupo Económico", "Líneas fijas por GIE", "Empresa", "Concesionario", "Líneas fijas"),
    "5" = c("Grupo Económico", "Acceso por GIE", "Empresa", "Concesionario", "Accesos"),
    "6" = c("Grupo Económico", "Accesos por GIE", "Empresa", "Concesionario", "Accesos")
  )
  tabla
}

control_sin_datos <- function(especificacion, anio, trimestre) {
  data.frame(
    Periodo = periodo_codigo(anio, trimestre),
    Seccion = especificacion$orden,
    Fuente = especificacion$etiqueta,
    Estado = "Sin datos",
    Filas = 0L,
    Total_raw = NA_real_,
    Total_reporte = NA_real_,
    Grupos = 0L,
    Empresas_en_otros = 0L,
    Valores_imputados_cero = 0L,
    Valores_negativos = 0L,
    Filas_duplicadas_exactas = 0L,
    stringsAsFactors = FALSE
  )
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
    Estado = "Disponible",
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
  advertencias <- character()
  for (id in names(ESPECIFICACIONES_FUENTES)) {
    especificacion <- ESPECIFICACIONES_FUENTES[[id]]
    disponible <- trimestre %in% trimestres_disponibles(
      fuentes[[id]]$datos, especificacion, anio
    )
    if (!disponible) {
      aviso <- paste0(
        "ADVERTENCIA: ", periodo_codigo(anio, trimestre), " / sección ",
        especificacion$orden, " (", especificacion$etiqueta, "): ",
        especificacion$archivo, " no contiene el cierre requerido. ",
        "La tabla y la gráfica se generan con '-' y el resto del reporte continúa."
      )
      message(aviso)
      advertencias <- c(advertencias, aviso)
      tablas[[especificacion$orden]] <- crear_tabla_vacia(especificacion)
      controles[[especificacion$orden]] <- control_sin_datos(
        especificacion, anio, trimestre
      )
      empresas_otros[[especificacion$orden]] <- 0L
      next
    }
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
    empresas_otros = empresas_otros,
    advertencias = unique(advertencias)
  )
}
