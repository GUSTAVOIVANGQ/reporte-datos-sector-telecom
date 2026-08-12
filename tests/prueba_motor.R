#!/usr/bin/env Rscript

# Prueba de las seis fuentes incluidas. No descarga archivos; también genera
# un Word temporal para validar la integración OOXML de extremo a extremo.
argumentos <- commandArgs(trailingOnly = FALSE)
archivo_arg <- sub("^--file=", "", argumentos[grepl("^--file=", argumentos)])
raiz <- if (length(archivo_arg)) {
  normalizePath(file.path(dirname(archivo_arg[[1]]), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
options(reporte.raiz = raiz)
source(file.path(raiz, "generar_reporte.R"), local = globalenv(), encoding = "UTF-8")

cache <- file.path(raiz, "entrada", "datos_bit")
fuentes <- setNames(vector("list", length(ESPECIFICACIONES_FUENTES)), names(ESPECIFICACIONES_FUENTES))
for (id in names(ESPECIFICACIONES_FUENTES)) {
  especificacion <- ESPECIFICACIONES_FUENTES[[id]]
  ruta <- file.path(cache, especificacion$archivo)
  fuentes[[id]] <- list(
    datos = leer_csv_fuente(ruta, especificacion),
    ruta = ruta,
    origen = "archivo de prueba"
  )
}

# La segunda lectura debe reutilizar el RDS procesado si el CSV no cambió.
ruta_cache_prueba <- file.path(cache, ESPECIFICACIONES_FUENTES$lineas_movil$archivo)
segunda_lectura <- leer_csv_fuente(
  ruta_cache_prueba, ESPECIFICACIONES_FUENTES$lineas_movil
)
stopifnot(
  isTRUE(attr(segunda_lectura, "reporte_cache_usada")),
  nrow(segunda_lectura) == nrow(fuentes$lineas_movil$datos),
  identical(segunda_lectura$.VALOR, fuentes$lineas_movil$datos$.VALOR)
)

# La detección consulta solo una muestra y reconoce un BOM UTF-16LE sin
# intentar leer el archivo grande completo.
utf16_prueba <- tempfile(fileext = ".csv")
writeBin(as.raw(c(255, 254, 65, 0, 44, 0, 66, 0, 10, 0)), utf16_prueba)
stopifnot(identical(detectar_codificacion(utf16_prueba), "UTF-16LE"))
unlink(utf16_prueba)

stopifnot(identical(trimestres_comunes(fuentes, 2024L), 1:4))

esperados_q4 <- c(
  lineas_movil = 152476748,
  internet_movil = 135808948,
  ingresos = 163137.9235873667,
  lineas_fijas = 31361393,
  internet_fijo = 29003240,
  tv_restringida = 21787954
)

for (trimestre in 1:4) {
  preparado <- preparar_tablas_periodo(fuentes, 2024L, trimestre)
  validar_entrada(preparado$tablas)
  empresas_contiguas <- vapply(seq_along(preparado$tablas), function(i) {
    tabla <- preparado$tablas[[i]]
    grupos <- trimws(as.character(tabla[[1]]))
    empresas <- trimws(as.character(tabla[[if (i <= 2L) 2L else 3L]]))
    detalle <- !grupos %in% c("Otros", "TOTAL", "-") & nzchar(empresas)
    bloques <- rle(paste(grupos[detalle], empresas[detalle], sep = "\r"))$values
    !anyDuplicated(bloques)
  }, logical(1))
  stopifnot(
    identical(vapply(preparado$tablas, ncol, integer(1)), c(4L, 4L, 5L, 5L, 5L, 5L)),
    all(preparado$control$Total_reporte > 0),
    all(preparado$control$Estado == "Disponible"),
    all(empresas_contiguas),
    !any(grepl(
      "operadores consolidados|\\+[0-9]+ más",
      unlist(lapply(preparado$tablas, function(x) as.character(x[[ncol(x) - 1L]]))),
      ignore.case = TRUE
    ))
  )
}

# El desglose no se limita a la capacidad de la antigua plantilla. Grupo
# Televisa publica ocho concesionarios distintos en telefonía fija 2024Q1.
q1_tabla4 <- preparar_tablas_periodo(fuentes, 2024L, 1L)$tablas[[4]]
stopifnot(sum(q1_tabla4[[1]] == "Grupo Televisa") == 8L)

q4 <- preparar_tablas_periodo(fuentes, 2024L, 4L)$control
obtenidos_q4 <- setNames(q4$Total_reporte, names(ESPECIFICACIONES_FUENTES))
stopifnot(all(abs(obtenidos_q4 - esperados_q4) < 0.01))

# Con las copias proporcionadas, 2025 no tiene un trimestre común porque
# internet fijo termina en 2024. Aun así, hay datos parciales y el reporte
# debe poder generarse con marcadores '-' en las secciones ausentes.
stopifnot(length(trimestres_comunes(fuentes, 2025L)) == 0L)
stopifnot(identical(trimestres_disponibles_reporte(fuentes, 2025L), 1:4))
parcial <- preparar_tablas_periodo(fuentes, 2025L, 4L)
validar_entrada(parcial$tablas)
stopifnot(
  any(parcial$control$Estado == "Sin datos"),
  any(parcial$control$Estado == "Disponible"),
  length(parcial$advertencias) > 0L
)

# El motor Word debe construir los runs de los pies de fuente con nodos de
# texto propios e insertar los 12 hipervínculos esperados.
preparado_word <- preparar_tablas_periodo(fuentes, 2024L, 1L)
tablas_word <- preparado_word$tablas
datos_word <- lapply(seq_len(6L), function(i) datos_seccion(tablas_word[[i]], i))
parametros_word <- crear_parametros_periodo(
  2024L, 1L, preparado_word$empresas_otros
)
word_temporal <- tempfile("prueba_motor_", fileext = ".docx")
imagen_prueba <- file.path(raiz, "screenshots", "interface.png")
urls_prueba <- paste0("https://ejemplo.invalid/fuente_", seq_len(6L), ".csv")
actualizar_word(
  plantilla = file.path(
    raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx"
  ),
  salida = word_temporal,
  tablas = tablas_word,
  textos = valores_texto(parametros_word, tablas_word, datos_word),
  graficas = rep(imagen_prueba, 6L),
  urls = urls_prueba
)
stopifnot(file.exists(word_temporal), file.info(word_temporal)$size > 0L)

word_extraido <- tempfile("prueba_motor_word_")
dir.create(word_extraido, recursive = TRUE)
utils::unzip(word_temporal, exdir = word_extraido)
xml_word <- xml2::read_xml(file.path(word_extraido, "word", "document.xml"))
ns_word <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
parrafos_word <- xml2::xml_find_all(xml_word, ".//w:p", ns_word)
fuentes_word <- Filter(function(parrafo) {
  texto <- paste(
    xml2::xml_text(xml2::xml_find_all(parrafo, ".//w:t", ns_word)),
    collapse = ""
  )
  startsWith(trimws(texto), "Fuente:")
}, as.list(parrafos_word))
stopifnot(
  length(fuentes_word) == 12L,
  all(vapply(fuentes_word, function(parrafo) {
    length(xml2::xml_find_all(parrafo, "./w:hyperlink", ns_word)) == 1L
  }, logical(1))),
  identical(
    vapply(fuentes_word, function(parrafo) {
      enlace <- xml2::xml_find_first(parrafo, "./w:hyperlink", ns_word)
      paste(
        xml2::xml_text(xml2::xml_find_all(enlace, ".//w:t", ns_word)),
        collapse = ""
      )
    }, character(1)),
    rep(urls_prueba, each = 2L)
  ),
  all(vapply(fuentes_word, function(parrafo) {
    enlace <- xml2::xml_find_first(parrafo, "./w:hyperlink", ns_word)
    color <- xml2::xml_find_first(enlace, ".//w:color", ns_word)
    subrayado <- xml2::xml_find_first(enlace, ".//w:u", ns_word)
    identical(xml2::xml_attr(color, "w:val", ns_word), "0000FF") &&
      identical(xml2::xml_attr(subrayado, "w:val", ns_word), "single")
  }, logical(1))),
  sum(vapply(fuentes_word, function(parrafo) {
    grepl(
      "Nota:",
      paste(
        xml2::xml_text(xml2::xml_find_all(parrafo, ".//w:t", ns_word)),
        collapse = ""
      ),
      fixed = TRUE
    )
  }, logical(1))) == 2L
)
unlink(c(word_temporal, word_extraido), recursive = TRUE, force = TRUE)

cat(
  "OK: seis fuentes; 2024Q1-Q4 completos;",
  "caché procesada y UTF-16 verificados; empresas y concesionarios agrupados; totales Q4 conciliados;",
  "2025Q4 parcial continúa con marcadores y advertencias; Word e hipervínculos válidos.\n"
)
