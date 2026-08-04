#!/usr/bin/env Rscript

# Automatiza el reporte sin sobrescribir el Excel ni la plantilla Word.
paquetes <- c("readxl", "xml2", "zip")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) {
  stop("Faltan paquetes: ", paste(faltan, collapse = ", "),
       ". Ejecute primero: Rscript instalar_paquetes.R")
}

args_full <- commandArgs(trailingOnly = FALSE)
archivo_arg <- sub("^--file=", "", args_full[grepl("^--file=", args_full)])
raiz <- if (length(archivo_arg)) dirname(normalizePath(archivo_arg[1])) else getwd()
args <- commandArgs(trailingOnly = TRUE)
archivo_excel <- if (length(args) >= 1) args[1] else file.path(raiz, "entrada", "Entrada_Reporte_Telecom_2025Q4.xlsx")
archivo_plantilla <- if (length(args) >= 2) args[2] else file.path(raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
carpeta_salidas <- if (length(args) >= 3) args[3] else file.path(raiz, "salidas")

if (!file.exists(archivo_excel)) stop("No existe el Excel: ", archivo_excel)
if (!file.exists(archivo_plantilla)) stop("No existe la plantilla: ", archivo_plantilla)

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
fmt_entero <- function(x) formatC(numero(x), format = "f", digits = 0, big.mark = ",")
fmt_decimal <- function(x) formatC(numero(x), format = "f", digits = 2, big.mark = ",")

validar_entrada <- function(tablas) {
  filas <- c(6, 6, 20, 12, 11, 9)
  columnas <- c(4, 4, 5, 5, 5, 5)
  for (i in 1:6) {
    if (nrow(tablas[[i]]) != filas[i] || ncol(tablas[[i]]) != columnas[i]) {
      stop(sprintf("Tabla_%d cambió de estructura: se esperaba %dx%d y se recibió %dx%d.",
                   i, filas[i], columnas[i], nrow(tablas[[i]]), ncol(tablas[[i]])))
    }
    total <- numero(tablas[[i]][nrow(tablas[[i]]), ncol(tablas[[i]])])
    detalle <- sum(numero(tablas[[i]][-nrow(tablas[[i]]), ncol(tablas[[i]])]), na.rm = TRUE)
    if (abs(total - detalle) > 0.01) stop("El TOTAL no concilia en Tabla_", i)
  }
}

datos_seccion <- function(tabla, seccion) {
  grupo <- trimws(as.character(tabla[[1]]))
  if (seccion <= 2) {
    valor <- numero(tabla[[ncol(tabla)]])
    salida <- data.frame(grupo, valor, stringsAsFactors = FALSE)
    salida <- salida[!is.na(salida$grupo) & salida$grupo != "TOTAL" & !is.na(salida$valor), ]
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

mapas_grafica <- list(
  c("América Móvil" = "América Móvil (Telcel)", "AT&T" = "AT&T",
    "Telefónica" = "Telefónica (Movistar)", "Grupo Walmart" = "Grupo Walmart (Bait)"),
  c("América Móvil" = "América Móvil (Telcel)", "AT&T" = "AT&T",
    "Telefónica" = "Telefónica (Movistar)", "Grupo Walmart" = "Grupo Walmart (Bait)"),
  character(),
  c("América Móvil" = "América Móvil (Telmex-Telnor)",
    "Grupo Televisa" = "Grupo Televisa (Izzi, Sky)",
    "Grupo Salinas" = "Grupo Salinas (Totalplay)"),
  c("América Móvil" = "América Móvil (Telmex-Telnor)",
    "Grupo Televisa" = "Grupo Televisa (Izzi, Sky)",
    "Grupo Salinas" = "Grupo Salinas (Totalplay)"),
  c("Grupo Televisa" = "Grupo Televisa (Izzi, Sky)",
    "Grupo Salinas" = "Grupo Salinas (Totalplay)")
)

mapas_texto <- list(
  mapas_grafica[[1]], mapas_grafica[[2]], character(), character(), character(), character()
)

colores <- c(
  "América Móvil" = "#1E6284", "AT&T" = "#667489", "Telefónica" = "#368491",
  "Grupo Walmart" = "#1B4044", "Grupo Televisa" = "#ED8945",
  "Grupo Salinas" = "#99B554", "Megacable-MCM" = "#5844A0",
  "Altán" = "#8E244D", "Axtel" = "#994010", "Dish" = "#0F9ED5",
  "Otros" = "#728781"
)

rectangulo <- function(grupo, xmin, xmax, ymin, ymax) {
  data.frame(grupo, xmin, xmax, ymin, ymax, stringsAsFactors = FALSE)
}

diseno_rectangulos <- function(datos, seccion) {
  v <- setNames(datos$valor, datos$grupo)
  p <- function(nombre) unname(v[[nombre]])
  total <- sum(v)

  if (seccion == 1) {
    x <- p("América Móvil") / total
    h1 <- p("AT&T") / (total - p("América Móvil"))
    h3 <- p("Otros") / (total - p("América Móvil"))
    xm <- x + (1 - x) * p("Telefónica") / sum(v[c("Telefónica", "Grupo Walmart")])
    return(rbind(
      rectangulo("América Móvil", 0, x, 0, 1), rectangulo("AT&T", x, 1, 0, h1),
      rectangulo("Telefónica", x, xm, h1, 1 - h3),
      rectangulo("Grupo Walmart", xm, 1, h1, 1 - h3),
      rectangulo("Otros", x, 1, 1 - h3, 1)
    ))
  }
  if (seccion == 2) {
    x <- p("América Móvil") / total
    h <- sum(v[c("AT&T", "Telefónica")]) / (total - p("América Móvil"))
    xt <- x + (1 - x) * p("AT&T") / sum(v[c("AT&T", "Telefónica")])
    xb <- x + (1 - x) * p("Grupo Walmart") / sum(v[c("Grupo Walmart", "Otros")])
    return(rbind(
      rectangulo("América Móvil", 0, x, 0, 1), rectangulo("AT&T", x, xt, 0, h),
      rectangulo("Telefónica", xt, 1, 0, h), rectangulo("Grupo Walmart", x, xb, h, 1),
      rectangulo("Otros", xb, 1, h, 1)
    ))
  }
  if (seccion == 3) {
    x <- p("América Móvil") / total
    h1 <- sum(v[c("AT&T", "Grupo Televisa")]) / (total - p("América Móvil"))
    xt <- x + (1 - x) * p("AT&T") / sum(v[c("AT&T", "Grupo Televisa")])
    resto <- v[c("Grupo Salinas", "Megacable-MCM", "Telefónica", "Otros",
                 "Grupo Walmart", "Altán", "Axtel")]
    xm <- x + (1 - x) * sum(resto[c("Grupo Salinas", "Megacable-MCM")]) / sum(resto)
    hs <- h1 + (1 - h1) * p("Grupo Salinas") / sum(v[c("Grupo Salinas", "Megacable-MCM")])
    hr <- h1 + (1 - h1) * sum(v[c("Telefónica", "Otros")]) / sum(resto[c(
      "Telefónica", "Otros", "Grupo Walmart", "Altán", "Axtel")])
    xo <- xm + (1 - xm) * p("Telefónica") / sum(v[c("Telefónica", "Otros")])
    xa <- xm + (1 - xm) * sum(v[c("Grupo Walmart", "Altán")]) /
      sum(v[c("Grupo Walmart", "Altán", "Axtel")])
    hw <- hr + (1 - hr) * p("Grupo Walmart") / sum(v[c("Grupo Walmart", "Altán")])
    return(rbind(
      rectangulo("América Móvil", 0, x, 0, 1), rectangulo("AT&T", x, xt, 0, h1),
      rectangulo("Grupo Televisa", xt, 1, 0, h1),
      rectangulo("Grupo Salinas", x, xm, h1, hs), rectangulo("Megacable-MCM", x, xm, hs, 1),
      rectangulo("Telefónica", xm, xo, h1, hr), rectangulo("Otros", xo, 1, h1, hr),
      rectangulo("Grupo Walmart", xm, xa, hr, hw), rectangulo("Altán", xm, xa, hw, 1),
      rectangulo("Axtel", xa, 1, hr, 1)
    ))
  }
  if (seccion %in% c(4, 5)) {
    x <- p("América Móvil") / total
    h <- sum(v[c("Grupo Televisa", "Megacable-MCM")]) / (total - p("América Móvil"))
    xt <- x + (1 - x) * p("Grupo Televisa") / sum(v[c("Grupo Televisa", "Megacable-MCM")])
    xb <- x + (1 - x) * p("Grupo Salinas") / sum(v[c("Grupo Salinas", "Otros")])
    return(rbind(
      rectangulo("América Móvil", 0, x, 0, 1), rectangulo("Grupo Televisa", x, xt, 0, h),
      rectangulo("Megacable-MCM", xt, 1, 0, h), rectangulo("Grupo Salinas", x, xb, h, 1),
      rectangulo("Otros", xb, 1, h, 1)
    ))
  }
  x <- p("Grupo Televisa") / total
  h <- p("Megacable-MCM") / (total - p("Grupo Televisa"))
  xb <- x + (1 - x) * p("Grupo Salinas") / sum(v[c("Grupo Salinas", "Dish", "Otros")])
  hd <- h + (1 - h) * p("Dish") / sum(v[c("Dish", "Otros")])
  rbind(
    rectangulo("Grupo Televisa", 0, x, 0, 1), rectangulo("Megacable-MCM", x, 1, 0, h),
    rectangulo("Grupo Salinas", x, xb, h, 1), rectangulo("Dish", xb, 1, h, hd),
    rectangulo("Otros", xb, 1, hd, 1)
  )
}

ajustar_rotulo <- function(texto, ancho, alto, max_pt = 18, min_pt = 5) {
  palabras <- strsplit(texto, " +")[[1]]
  for (pt in seq(max_pt, min_pt, by = -0.5)) {
    gp <- grid::gpar(fontsize = pt, fontface = "bold", fontfamily = "Arial", col = "white")
    lineas <- character()
    actual <- ""
    for (palabra in palabras) {
      prueba <- trimws(paste(actual, palabra))
      medida <- grid::convertWidth(grid::grobWidth(grid::textGrob(prueba, gp = gp)), "npc", valueOnly = TRUE)
      if (nzchar(actual) && medida > ancho) {
        lineas <- c(lineas, actual); actual <- palabra
      } else actual <- prueba
    }
    lineas <- c(lineas, actual)
    hlinea <- grid::convertHeight(grid::grobHeight(grid::textGrob("Ágj", gp = gp)), "npc", valueOnly = TRUE) * 1.18
    if (length(lineas) * hlinea <= alto) return(list(texto = paste(lineas, collapse = "\n"), gp = gp))
  }
  NULL
}

guardar_grafica <- function(datos, seccion, ruta) {
  d <- diseno_rectangulos(datos, seccion)
  valores <- setNames(datos$valor, datos$grupo)
  etiquetas <- setNames(mapear(datos$grupo, mapas_grafica[[seccion]]), datos$grupo)
  if (seccion <= 2) colores["América Móvil"] <- "#683E5D"
  alturas <- c(1483, 1483, 1481, 1481, 1481, 1483)
  grDevices::png(ruta, width = 2048, height = alturas[seccion], res = 200, bg = "white")
  grid::grid.newpage()
  margen_total <- if (seccion %in% c(3, 4, 5)) 5.08 else 4
  grid::pushViewport(grid::viewport(
    width = grid::unit(1, "npc") - grid::unit(margen_total, "mm"),
    height = grid::unit(1, "npc") - grid::unit(margen_total, "mm")
  ))
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    grid::grid.rect(
      x = (r$xmin + r$xmax) / 2, y = 1 - (r$ymin + r$ymax) / 2,
      width = r$xmax - r$xmin, height = r$ymax - r$ymin,
      gp = grid::gpar(fill = unname(colores[r$grupo]), col = "white", lwd = 2)
    )
    valor <- if (seccion == 3) valores[[r$grupo]] else valores[[r$grupo]] / 1e6
    rotulo <- paste0(etiquetas[[r$grupo]], ", ", fmt_decimal(valor))
    padding <- 0.008
    ajuste <- ajustar_rotulo(rotulo, r$xmax - r$xmin - 2 * padding, r$ymax - r$ymin - 2 * padding)
    if (!is.null(ajuste)) grid::grid.text(
      ajuste$texto, x = r$xmin + padding, y = 1 - r$ymax + padding,
      just = c("left", "bottom"), gp = ajuste$gp
    )
  }
  grid::popViewport()
  grDevices::dev.off()
}

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
    d <- datos[[s]][datos[[s]]$grupo != "Otros", , drop = FALSE]
    d <- d[order(-d$valor), , drop = FALSE]
    total <- numero(tablas[[s]][nrow(tablas[[s]]), ncol(tablas[[s]])])
    nombres <- mapear(d$grupo, mapas_texto[[s]])
    for (j in seq_len(lideres[s])) {
      v[[sprintf("S%d_L%d_NOMBRE", s, j)]] <- nombres[j]
      v[[sprintf("S%d_L%d_PCT", s, j)]] <- sprintf("%.2f%%", 100 * d$valor[j] / total)
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

actualizar_word <- function(plantilla, salida, tablas, textos, graficas) {
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

  rellenar_controles <- function(xml, incluir_tablas = FALSE) {
    sdts <- xml2::xml_find_all(xml, ".//w:sdt", ns)
    for (sdt in sdts) {
      tag <- xml2::xml_attr(xml2::xml_find_first(sdt, "./w:sdtPr/w:tag", ns), "w:val", ns)
      valor <- NULL
      if (!is.na(tag) && tag %in% names(textos)) valor <- textos[[tag]]
      if (incluir_tablas && !is.na(tag) && grepl("^T[0-9]{2}_R[0-9]{2}_C[0-9]{2}$", tag)) {
        partes <- as.integer(sub("^T([0-9]{2})_R([0-9]{2})_C([0-9]{2})$", "\\1 \\2 \\3", tag) |>
                              strsplit(" ") |> unlist())
        valor <- formatear_celda(tablas[[partes[1]]][partes[2], partes[3]], partes[1], partes[3])
      }
      if (!is.null(valor)) {
        nodos <- xml2::xml_find_all(sdt, "./w:sdtContent//w:t", ns)
        if (!length(nodos) && identical(as.character(valor), "")) next
        if (!length(nodos)) stop("El control no contiene texto: ", tag)
        xml2::xml_text(nodos[[1]]) <- enc2utf8(as.character(valor))
        if (length(nodos) > 1) for (j in 2:length(nodos)) xml2::xml_text(nodos[[j]]) <- ""
      }
    }
  }
  rellenar_controles(doc, incluir_tablas = TRUE)

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

param <- leer_parametros(archivo_excel)
tablas <- leer_tablas(archivo_excel)
validar_entrada(tablas)
datos <- lapply(1:6, function(i) datos_seccion(tablas[[i]], i))

id_ejecucion <- paste(param[["periodo_codigo"]], param[["version"]],
                      format(Sys.time(), "%Y%m%d_%H%M%S"), sep = "_")
carpeta_ejecucion <- file.path(carpeta_salidas, id_ejecucion)
carpeta_monitoreo <- file.path(carpeta_ejecucion, "monitoreo")
dir.create(carpeta_monitoreo, recursive = TRUE, showWarnings = FALSE)

control <- data.frame(Etapa = character(), Estado = character(), Fecha = character(), Detalle = character())
registrar <- function(etapa, estado, detalle) {
  control <<- rbind(control, data.frame(
    Etapa = etapa, Estado = estado, Fecha = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    Detalle = detalle, stringsAsFactors = FALSE
  ))
  utils::write.csv(control, file.path(carpeta_ejecucion, "control_ejecucion.csv"),
                   row.names = FALSE, fileEncoding = "UTF-8")
}

registrar("Entrada", "Completado", "Excel leído; estructuras y totales conciliados")
for (i in 1:6) {
  utils::write.csv(tablas[[i]], file.path(carpeta_monitoreo, paste0("tabla_", i, ".csv")),
                   row.names = FALSE, na = "", fileEncoding = "UTF-8")
}
registrar("Tablas", "Completado", "Seis copias CSV creadas antes del Word")

rutas_graficas <- file.path(carpeta_monitoreo, paste0("grafica_", 1:6, ".png"))
for (i in 1:6) guardar_grafica(datos[[i]], i, rutas_graficas[i])
registrar("Gráficas", "Completado", "Seis PNG creados desde las tablas")

carpeta_drive <- Sys.getenv("REPORTE_DRIVE", "")
if (nzchar(carpeta_drive)) {
  destino_drive <- file.path(carpeta_drive, id_ejecucion, "monitoreo")
  dir.create(destino_drive, recursive = TRUE, showWarnings = FALSE)
  copiados <- file.copy(list.files(carpeta_monitoreo, full.names = TRUE), destino_drive)
  if (!all(copiados)) stop("No fue posible copiar todo el monitoreo a Google Drive")
  registrar("Drive", "Completado", paste("Copias guardadas en", destino_drive))
} else {
  registrar("Drive", "Local", "Defina REPORTE_DRIVE para copiar a una carpeta sincronizada")
}

salida_word <- file.path(
  carpeta_ejecucion,
  paste0("Reporte_Telecomunicaciones_", param[["periodo_codigo"]], "_", param[["version"]], ".docx")
)
actualizar_word(archivo_plantilla, salida_word, tablas, valores_texto(param, tablas, datos), rutas_graficas)
registrar("Word", "Completado", basename(salida_word))
registrar("Resultado", "Completado", paste("Ejecución", id_ejecucion))

message("Proceso terminado.")
message("Word: ", normalizePath(salida_word))
message("Monitoreo: ", normalizePath(carpeta_monitoreo))
