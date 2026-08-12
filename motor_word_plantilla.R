# Funciones de diseño y sustitución de la plantilla Word histórica.
# Este archivo no se ejecuta directamente; generar_reporte.R lo carga.

leer_parametros <- function(ruta) {
  x <- readxl::read_excel(ruta, sheet = "Parametros", skip = 2, .name_repair = "minimal")
  setNames(as.character(x[[2]]), as.character(x[[1]]))
}

leer_tablas <- function(ruta) {
  lapply(1:6, function(i) {
    as.data.frame(readxl::read_excel(
      ruta, sheet = paste0("Tabla_", i), skip = 3, .name_repair = "minimal"
    ), check.names = FALSE)
  })
}

numero <- function(x) suppressWarnings(as.numeric(x))
fmt_numero <- function(x, decimales) {
  y <- numero(x)
  if (!length(y)) return("-")
  salida <- rep("-", length(y))
  validos <- is.finite(y)
  salida[validos] <- formatC(
    y[validos], format = "f", digits = decimales, big.mark = ","
  )
  salida
}
fmt_entero <- function(x) fmt_numero(x, 0L)
fmt_decimal <- function(x) fmt_numero(x, 2L)

validar_parametros <- function(param) {
  requeridos <- c(
    "periodo_codigo", "trimestre_numero", "anio", "periodo_texto",
    "periodo_portada", "version"
  )
  faltantes <- setdiff(requeridos, names(param))
  if (length(faltantes)) stop("Faltan parámetros: ", paste(faltantes, collapse = ", "))
  if (!grepl("^[0-9]{4}Q[1-4]$", param[["periodo_codigo"]])) {
    stop("periodo_codigo debe tener formato AAAAQN; ejemplo: 2026Q1")
  }
  trimestre <- numero(param[["trimestre_numero"]])
  anio <- numero(param[["anio"]])
  if (!trimestre %in% 1:4 || is.na(anio) || anio < 2000) stop("Trimestre o año inválido")
  esperado <- paste0(as.integer(anio), "Q", as.integer(trimestre))
  if (!identical(param[["periodo_codigo"]], esperado)) {
    stop("periodo_codigo no coincide con trimestre_numero y anio: se esperaba ", esperado)
  }
  if (!grepl("^[A-Za-z0-9_-]+$", param[["version"]])) {
    stop("version contiene caracteres no permitidos para un nombre de archivo")
  }
}

validar_entrada <- function(tablas) {
  columnas <- c(4, 4, 5, 5, 5, 5)
  grupos_requeridos <- list(
    c("América Móvil", "AT&T", "Telefónica", "Grupo Walmart", "Otros"),
    c("América Móvil", "AT&T", "Telefónica", "Grupo Walmart", "Otros"),
    c("América Móvil", "AT&T", "Grupo Televisa", "Megacable-MCM", "Grupo Salinas",
      "Telefónica", "Grupo Walmart", "Axtel", "Altán", "Otros"),
    c("América Móvil", "Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Otros"),
    c("América Móvil", "Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Otros"),
    c("Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Dish", "Otros")
  )
  for (i in 1:6) {
    if (nrow(tablas[[i]]) < 2L || ncol(tablas[[i]]) != columnas[i]) {
      stop(sprintf(
        "Tabla_%d cambió de estructura: se esperaban al menos 2 filas y %d columnas; se recibió %dx%d.",
        i, columnas[i], nrow(tablas[[i]]), ncol(tablas[[i]])
      ))
    }
    grupos <- trimws(as.character(tablas[[i]][[1]]))
    valores <- numero(tablas[[i]][[ncol(tablas[[i]])]])
    sin_datos <- identical(grupos[[1]], "-") && grupos[[nrow(tablas[[i]])]] == "TOTAL" &&
      all(is.na(valores))
    if (sin_datos) next

    faltantes <- setdiff(grupos_requeridos[[i]], grupos)
    if (length(faltantes)) stop("Faltan grupos en Tabla_", i, ": ", paste(faltantes, collapse = ", "))
    concesionarios <- trimws(as.character(tablas[[i]][[ncol(tablas[[i]]) - 1L]]))
    if (any(grepl("operadores consolidados|\\+[0-9]+ más", concesionarios, ignore.case = TRUE))) {
      stop("Tabla_", i, " todavía contiene concesionarios consolidados")
    }
    if (i != 3L && any(valores < 0, na.rm = TRUE)) stop("Hay valores negativos en Tabla_", i)
    total <- valores[nrow(tablas[[i]])]
    if (is.na(total) || total <= 0) stop("El TOTAL es vacío o no positivo en Tabla_", i)
    detalle <- sum(valores[-nrow(tablas[[i]])], na.rm = TRUE)
    if (abs(total - detalle) > 0.01) stop("El TOTAL no concilia en Tabla_", i)
    if (i >= 3) {
      for (grupo in setdiff(unique(grupos), c("Otros", "TOTAL"))) {
        filas_grupo <- grupos == grupo
        total_gie <- unique(numero(tablas[[i]][filas_grupo, 2]))
        total_gie <- total_gie[!is.na(total_gie)]
        if (length(total_gie) != 1 ||
            abs(total_gie - sum(valores[filas_grupo], na.rm = TRUE)) > 0.01) {
          stop("El total por GIE no concilia para ", grupo, " en Tabla_", i)
        }
      }
    }
  }
}

datos_seccion <- function(tabla, seccion) {
  grupo <- trimws(as.character(tabla[[1]]))
  if (identical(grupo[[1]], "-")) {
    return(data.frame(grupo = character(), valor = numeric(), stringsAsFactors = FALSE))
  }
  if (seccion <= 2) {
    valor <- numero(tabla[[ncol(tabla)]])
    salida <- data.frame(grupo, valor, stringsAsFactors = FALSE)
    salida <- salida[!is.na(salida$grupo) & salida$grupo != "TOTAL" & !is.na(salida$valor), ]
    salida <- stats::aggregate(valor ~ grupo, data = salida, FUN = sum, na.rm = TRUE)
  } else {
    valor_gie <- numero(tabla[[2]])
    salida <- data.frame(grupo, valor = valor_gie, stringsAsFactors = FALSE)
    salida <- salida[!is.na(salida$grupo) & salida$grupo != "TOTAL" & !is.na(salida$valor), ]
    salida <- salida[!duplicated(salida$grupo), ]
    fila_otros <- which(grupo == "Otros")
    if (length(fila_otros)) {
      salida <- rbind(salida, data.frame(
        grupo = "Otros", valor = numero(tabla[fila_otros[1], ncol(tabla)])
      ))
    }
  }
  salida[order(-salida$valor), , drop = FALSE]
}

mapear <- function(grupo, mapa) {
  x <- unname(mapa[grupo])
  x[is.na(x)] <- grupo[is.na(x)]
  x
}

mapas_texto <- list(
  c("América Móvil" = "América Móvil (Telcel)", "AT&T" = "AT&T",
    "Telefónica" = "Telefónica (Movistar)", "Grupo Walmart" = "Grupo Walmart (Bait)"),
  c("América Móvil" = "América Móvil (Telcel)", "AT&T" = "AT&T",
    "Telefónica" = "Telefónica (Movistar)", "Grupo Walmart" = "Grupo Walmart (Bait)"),
  character(), character(), character(), character()
)

valores_texto <- function(param, tablas, datos) {
  v <- list(
    PERIODO_PORTADA = param[["periodo_portada"]],
    PERIODO_PIE = gsub(" DE ", " ", param[["periodo_portada"]], fixed = TRUE),
    PERIODO_TEXTO = param[["periodo_texto"]],
    TOTAL_LINEAS_MOVIL = fmt_entero(tablas[[1]][nrow(tablas[[1]]), 4]),
    TOTAL_INTERNET_MOVIL = fmt_entero(tablas[[2]][nrow(tablas[[2]]), 4]),
    TOTAL_INGRESOS = fmt_decimal(tablas[[3]][nrow(tablas[[3]]), 5]),
    TOTAL_LINEAS_FIJAS = fmt_entero(tablas[[4]][nrow(tablas[[4]]), 5]),
    TOTAL_INTERNET_FIJO = fmt_entero(tablas[[5]][nrow(tablas[[5]]), 5]),
    TOTAL_TV_RESTRINGIDA = fmt_entero(tablas[[6]][nrow(tablas[[6]]), 5])
  )
  lideres <- c(4, 4, 5, 4, 4, 3)
  for (s in 1:6) {
    d <- datos[[s]][datos[[s]]$grupo != "Otros" & is.finite(datos[[s]]$valor) &
                        datos[[s]]$valor > 0, , drop = FALSE]
    d <- d[order(-d$valor), , drop = FALSE]
    total <- numero(tablas[[s]][nrow(tablas[[s]]), ncol(tablas[[s]])])
    nombres <- mapear(d$grupo, mapas_texto[[s]])
    for (j in seq_len(lideres[s])) {
      if (j <= nrow(d) && is.finite(total) && total > 0) {
        v[[sprintf("S%d_L%d_NOMBRE", s, j)]] <- nombres[j]
        v[[sprintf("S%d_L%d_PCT", s, j)]] <- sprintf("%.2f%%", 100 * d$valor[j] / total)
      } else {
        v[[sprintf("S%d_L%d_NOMBRE", s, j)]] <- "-"
        v[[sprintf("S%d_L%d_PCT", s, j)]] <- "-"
      }
    }
    v[[sprintf("S%d_OTROS_EMPRESAS", s)]] <- param[[paste0("empresas_otros_tabla_", s)]]
  }
  v
}

formatear_celda <- function(valor, tabla, columna) {
  if (length(valor) == 0 || is.na(valor)) return("")
  if (is.numeric(valor)) {
    if (tabla == 3 && columna %in% c(2, 5)) return(fmt_decimal(valor))
    return(fmt_entero(valor))
  }
  as.character(valor)
}

actualizar_word <- function(plantilla, salida, tablas, textos, graficas, urls) {
  ns <- c(
    w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    a = "http://schemas.openxmlformats.org/drawingml/2006/main",
    r = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  )
  tmp <- tempfile("reporte_word_")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  utils::unzip(plantilla, exdir = tmp)
  doc_xml <- file.path(tmp, "word", "document.xml")
  rel_xml <- file.path(tmp, "word", "_rels", "document.xml.rels")
  doc <- xml2::read_xml(doc_xml)

  rellenar_controles <- function(xml) {
    sdts <- xml2::xml_find_all(xml, ".//w:sdt", ns)
    for (sdt in sdts) {
      tag <- xml2::xml_attr(xml2::xml_find_first(sdt, "./w:sdtPr/w:tag", ns), "w:val", ns)
      valor <- NULL
      if (!is.na(tag) && tag %in% names(textos)) valor <- textos[[tag]]
      if (!is.null(valor)) {
        nodos <- xml2::xml_find_all(sdt, "./w:sdtContent//w:t", ns)
        if (!length(nodos) && identical(as.character(valor), "")) next
        if (!length(nodos)) stop("El control no contiene texto: ", tag)
        xml2::xml_text(nodos[[1]]) <- enc2utf8(as.character(valor))
        if (length(nodos) > 1) for (j in 2:length(nodos)) xml2::xml_text(nodos[[j]]) <- ""
      }
    }
  }
  rellenar_controles(doc)

  # Las tablas de la plantilla histórica eran flotantes y tenían un número
  # fijo de filas. Eso permitía que Word las colocara antes del título y
  # obligaba a consolidar concesionarios. Se reconstruye cada cuerpo con una
  # fila por concesionario, conservando el encabezado, anchos y estilos.
  vmerge_restart <- xml2::xml_find_first(doc, ".//w:vMerge[@w:val='restart']", ns)
  vmerge_continue <- xml2::xml_find_first(doc, ".//w:vMerge[@w:val='continue']", ns)
  sombreado_blanco <- xml2::xml_find_first(doc, ".//w:shd[@w:fill='ffffff']", ns)
  sombreado_gris <- xml2::xml_find_first(doc, ".//w:shd[@w:fill='efefef']", ns)

  estados_fusion <- function(tabla, seccion) {
    n <- nrow(tabla) - 1L
    salida <- matrix("", nrow = n, ncol = ncol(tabla))
    if (n <= 1L || identical(as.character(tabla[[1]][[1]]), "-")) return(salida)
    grupo <- trimws(as.character(tabla[[1]][seq_len(n)]))
    empresa <- trimws(as.character(tabla[[if (seccion <= 2L) 2L else 3L]][seq_len(n)]))
    claves <- if (seccion <= 2L) {
      list(`1` = grupo, `2` = paste(grupo, empresa, sep = "\r"))
    } else {
      list(
        `1` = grupo,
        `2` = grupo,
        `3` = paste(grupo, empresa, sep = "\r")
      )
    }
    for (columna in names(claves)) {
      clave <- claves[[columna]]
      inicio <- 1L
      while (inicio <= n) {
        fin <- inicio
        while (fin < n && identical(clave[[fin + 1L]], clave[[inicio]])) fin <- fin + 1L
        fusionable <- fin > inicio && nzchar(clave[[inicio]]) &&
          !grupo[[inicio]] %in% c("Otros", "-")
        if (fusionable) {
          salida[inicio, as.integer(columna)] <- "restart"
          salida[(inicio + 1L):fin, as.integer(columna)] <- "continue"
        }
        inicio <- fin + 1L
      }
    }
    salida
  }

  escribir_celda <- function(celda, texto) {
    nodos <- xml2::xml_find_all(celda, ".//w:t", ns)
    if (!length(nodos) && !nzchar(as.character(texto))) return(invisible(NULL))
    if (!length(nodos)) stop("La fila modelo de la plantilla no contiene un nodo de texto")
    xml2::xml_text(nodos[[1]]) <- enc2utf8(as.character(texto))
    if (length(nodos) > 1L) {
      for (j in 2:length(nodos)) xml2::xml_text(nodos[[j]]) <- ""
    }
    invisible(NULL)
  }

  reconstruir_tabla <- function(tabla_xml, datos, seccion) {
    filas_modelo <- xml2::xml_find_all(tabla_xml, "./w:tr", ns)
    if (length(filas_modelo) < 3L) stop("La tabla ", seccion, " no contiene filas modelo")
    modelo_cuerpo <- filas_modelo[[2]]
    modelo_total <- filas_modelo[[length(filas_modelo)]]
    xml2::xml_remove(filas_modelo[-1])
    flotante <- xml2::xml_find_first(tabla_xml, "./w:tblPr/w:tblpPr", ns)
    if (!inherits(flotante, "xml_missing")) xml2::xml_remove(flotante)

    fusiones <- estados_fusion(datos, seccion)
    n_cuerpo <- nrow(datos) - 1L
    for (i in seq_len(n_cuerpo)) {
      fila <- xml2::xml_add_child(tabla_xml, modelo_cuerpo, .copy = TRUE)
      celdas <- xml2::xml_find_all(fila, "./w:tc", ns)
      if (length(celdas) != ncol(datos)) stop("Número de columnas inesperado en la tabla ", seccion)
      for (j in seq_along(celdas)) {
        celda <- celdas[[j]]
        xml2::xml_remove(xml2::xml_find_all(celda, "./w:tcPr/w:vMerge", ns))
        xml2::xml_remove(xml2::xml_find_all(celda, "./w:tcPr/w:shd", ns))
        sombrear_desde <- if (seccion <= 2L) 3L else 4L
        if (j >= sombrear_desde) {
          color <- if (i %% 2L == 0L) sombreado_gris else sombreado_blanco
          xml2::xml_add_child(
            xml2::xml_find_first(celda, "./w:tcPr", ns),
            color, .copy = TRUE
          )
        }
        estado <- fusiones[i, j]
        if (identical(estado, "restart")) {
          xml2::xml_add_child(
            xml2::xml_find_first(celda, "./w:tcPr", ns),
            vmerge_restart, .copy = TRUE
          )
        } else if (identical(estado, "continue")) {
          xml2::xml_add_child(
            xml2::xml_find_first(celda, "./w:tcPr", ns),
            vmerge_continue, .copy = TRUE
          )
        }
        valor <- datos[i, j]
        texto <- if (identical(as.character(datos[[1]][[i]]), "-") &&
                     (length(valor) == 0L || is.na(valor) || !nzchar(as.character(valor)))) {
          "-"
        } else {
          formatear_celda(valor, seccion, j)
        }
        if (identical(estado, "continue")) texto <- ""
        escribir_celda(celda, texto)
      }
    }

    fila_total <- xml2::xml_add_child(tabla_xml, modelo_total, .copy = TRUE)
    celdas_total <- xml2::xml_find_all(fila_total, "./w:tc", ns)
    for (j in seq_along(celdas_total)) {
      texto <- if (j == 1L) {
        "TOTAL"
      } else if (j == ncol(datos)) {
        valor <- datos[nrow(datos), j]
        if (is.na(valor)) "-" else formatear_celda(valor, seccion, j)
      } else {
        ""
      }
      escribir_celda(celdas_total[[j]], texto)
    }
  }

  for (i in 1:6) {
    prefijo <- sprintf("T%02d_", i)
    tabla_xml <- xml2::xml_find_first(
      doc,
      paste0(".//w:tbl[.//w:tag[starts-with(@w:val, '", prefijo, "')]]"),
      ns
    )
    if (inherits(tabla_xml, "xml_missing")) stop("Falta la tabla ", i, " en la plantilla")
    reconstruir_tabla(tabla_xml, tablas[[i]], i)
  }

  # Mantener cada título con el objeto que le sigue. Las tablas se dejaron en
  # línea (sin tblpPr) para impedir que Word las reordene visualmente.
  parrafos <- xml2::xml_find_all(doc, ".//w:body/w:p", ns)
  for (parrafo in parrafos) {
    texto <- trimws(paste(xml2::xml_text(xml2::xml_find_all(parrafo, ".//w:t", ns)), collapse = ""))
    if (!grepl("^(Tabla|Gráfica) [1-6]\\.", texto)) next
    if (startsWith(texto, "Tabla 3.") && grepl("\\|$", texto)) {
      nodos_texto <- xml2::xml_find_all(parrafo, ".//w:t", ns)
      ultimo <- nodos_texto[[length(nodos_texto)]]
      xml2::xml_text(ultimo) <- enc2utf8(sub("\\|$", "", xml2::xml_text(ultimo)))
    }
    keep_next <- xml2::xml_find_first(parrafo, "./w:pPr/w:keepNext", ns)
    keep_lines <- xml2::xml_find_first(parrafo, "./w:pPr/w:keepLines", ns)
    if (!inherits(keep_next, "xml_missing")) xml2::xml_attr(keep_next, "w:val", ns) <- "1"
    if (!inherits(keep_lines, "xml_missing")) xml2::xml_attr(keep_lines, "w:val", ns) <- "1"
  }

  if (length(urls) != 6L || any(!nzchar(trimws(as.character(urls))))) {
    stop("Se requieren exactamente seis URL de fuente para el Word")
  }
  parrafos_fuente <- Filter(function(parrafo) {
    texto <- paste(xml2::xml_text(xml2::xml_find_all(parrafo, ".//w:t", ns)), collapse = "")
    startsWith(trimws(texto), "Fuente:")
  }, as.list(parrafos))
  if (length(parrafos_fuente) != 12L) {
    stop("La plantilla debe contener 12 pies de fuente; se encontraron ", length(parrafos_fuente))
  }
  urls_pies <- rep(as.character(urls), each = 2L)
  for (i in seq_along(parrafos_fuente)) {
    nodos <- xml2::xml_find_all(parrafos_fuente[[i]], ".//w:t", ns)
    textos_nodos <- xml2::xml_text(nodos)
    indice_texto <- if (identical(textos_nodos[[1]], "Fuente:")) 2L else 3L
    if (length(nodos) < indice_texto) stop("Pie de fuente sin estructura editable")
    espacio_inicial <- if (indice_texto == 2L) " " else ""
    xml2::xml_text(nodos[[indice_texto]]) <- enc2utf8(paste0(
      espacio_inicial,
      "Elaboración propia con información de los operadores de telecomunicaciones, disponible en ",
      urls_pies[[i]], ". "
    ))
  }

  rels <- xml2::read_xml(rel_xml)
  xml2::xml_ns_strip(rels)
  for (i in 1:6) {
    tag <- paste0("GRAFICA_", i)
    sdt <- xml2::xml_find_first(doc, paste0(".//w:sdt[w:sdtPr/w:tag[@w:val='", tag, "']]"), ns)
    if (inherits(sdt, "xml_missing")) stop("Falta el campo ", tag, " en la plantilla")
    blip <- xml2::xml_find_first(sdt, ".//a:blip", ns)
    rid <- xml2::xml_attr(blip, "r:embed", ns)
    rel <- xml2::xml_find_first(rels, paste0(".//Relationship[@Id='", rid, "']"))
    destino <- xml2::xml_attr(rel, "Target")
    if (!file.copy(graficas[i], file.path(tmp, "word", destino), overwrite = TRUE)) {
      stop("No se pudo sustituir ", tag)
    }
  }

  xml2::write_xml(doc, doc_xml)
  pies <- list.files(file.path(tmp, "word"), pattern = "^footer.*\\.xml$", full.names = TRUE)
  for (pie_xml in pies) {
    pie <- xml2::read_xml(pie_xml)
    rellenar_controles(pie)
    xml2::write_xml(pie, pie_xml)
    invisible(xml2::read_xml(pie_xml))
  }
  invisible(xml2::read_xml(doc_xml))
  archivos <- list.files(tmp, recursive = TRUE, all.files = TRUE,
                         include.dirs = FALSE, no.. = TRUE)
  zip::zip(
    salida, archivos, recurse = FALSE, include_directories = FALSE,
    root = tmp, mode = "mirror"
  )
  contenido <- zip::zip_list(salida)$filename
  requeridos <- c("[Content_Types].xml", "_rels/.rels", "word/document.xml")
  faltantes <- setdiff(requeridos, contenido)
  if (length(faltantes)) {
    stop(
      "La copia Word no pasó la validación estructural. Faltan: ",
      paste(faltantes, collapse = ", "),
      ". Primeras rutas encontradas: ",
      paste(utils::head(contenido, 8), collapse = ", ")
    )
  }
  extras_raiz <- grepl("^(document|styles|settings|numbering|fontTable|footer|header|image)[^/]*", contenido)
  if (any(extras_raiz) || anyDuplicated(contenido)) stop("El DOCX contiene archivos duplicados o fuera de lugar")
}
