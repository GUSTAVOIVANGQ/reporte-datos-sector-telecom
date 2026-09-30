#!/usr/bin/env Rscript
# Regresión real: mismas fuentes del caso 2026Q1, sin descargas.
args <- commandArgs(trailingOnly = FALSE)
archivo <- sub('^--file=', '', args[grepl('^--file=', args)])
raiz <- if (length(archivo)) normalizePath(file.path(dirname(archivo[[1]]), '..')) else getwd()
options(reporte.raiz = raiz)
source(file.path(raiz, 'generar_reporte.R'), encoding = 'UTF-8')

stopifnot(identical(
  resolver_grupos_bit(c('G006', ' g004 ', '', NA, 'C584', 'G002', 'C000',
                       'Empresa A', 'Empresa B', 'Nombre histórico'),
                     c('G006', 'G004', 'G008', 'G007', 'C584', 'G002', 'C000',
                       'G999', 'G999', 'G006')),
  c('AMERICA MOVIL', 'GRUPO TELEVISA', 'MEGACABLE-MCM', 'AT&T', 'GRUPO SALINAS',
    'DISH-MVS', 'C000', 'EMPRESA A', 'EMPRESA B', 'NOMBRE HISTORICO')
))
stopifnot(inherits(try(resolver_grupos_bit('G004', 'G006'), silent = TRUE), 'try-error'))

trabajo <- tempfile('regresion_2026Q1_')
dir.create(trabajo)
cache <- file.path(trabajo, 'datos')
dir.create(cache)
zip_arg <- sub('^--datos-zip=', '', grep('^--datos-zip=', commandArgs(TRUE), value = TRUE))
datos_zip <- if (length(zip_arg)) zip_arg[[1]] else file.path(raiz, 'tests', 'fixtures', '2026Q1.zip')
utils::unzip(datos_zip, exdir = cache)
fuentes <- list()
for (id in names(ESPECIFICACIONES_FUENTES)) {
  e <- ESPECIFICACIONES_FUENTES[[id]]
  ruta <- file.path(cache, e$archivo)
  d <- leer_csv_fuente(ruta, e)
  # Simular un RDS de v3.8.0 con la clasificación que produjo los ceros.
  ruta_rds <- file.path(carpeta_cache_procesada(ruta), paste0(e$archivo, '.', id, '.rds'))
  antiguo <- readRDS(ruta_rds)
  antiguo$version <- 2L
  antiguo$datos$.GRUPO_CLAVE <- normalizar_clave(d$GRUPO)
  saveRDS(antiguo, ruta_rds)
  corregido <- leer_csv_fuente(ruta, e)
  stopifnot(!isTRUE(attr(corregido, 'reporte_cache_usada')),
            identical(corregido$.GRUPO_CLAVE, d$.GRUPO_CLAVE))
  segunda <- leer_csv_fuente(ruta, e)
  stopifnot(isTRUE(attr(segunda, 'reporte_cache_usada')),
            identical(segunda$.GRUPO_CLAVE, corregido$.GRUPO_CLAVE))
  fuentes[[id]] <- list(datos = segunda)
}
stopifnot(identical(vapply(fuentes, function(x) nrow(x$datos), integer(1), USE.NAMES = FALSE),
                    c(32L, 27L, 53L, 4241L, 10343L, 4643L)))
preparado <- preparar_tablas_periodo(fuentes, 2026L, 1L)
tablas <- preparado$tablas
validar_entrada(tablas)
stopifnot(preparado$empresas_otros[[5]] == 13L, is.na(preparado$empresas_otros[[6]]))
stopifnot(all(abs(preparado$control$Total_reporte -
  c(141646269, 143080203, 175709.9943583, 31082469, 30082310, 29705462)) < 0.00001))

esperados <- list(
  c('América Móvil' = 12175137, 'Grupo Televisa' = 5876041,
    'Megacable-MCM' = 5876410, 'Grupo Salinas' = 5660570, 'Otros' = 494152),
  c('Grupo Televisa' = 9331187, 'Megacable-MCM' = 5675402,
    'Grupo Salinas' = 2322420, 'Dish' = 923638, 'Otros' = 11452815)
)
datos <- lapply(1:6, function(i) datos_seccion(tablas[[i]], i))
for (s in 5:6) {
  esperado <- esperados[[s - 4L]]
  obtenido <- setNames(datos[[s]]$valor, datos[[s]]$grupo)
  stopifnot(identical(sort(names(obtenido)), sort(names(esperado))),
            all(obtenido[names(esperado)] == esperado))
  # Las mismas cifras deben alimentar el detalle por concesionario.
  detalle <- tablas[[s]]
  stopifnot(all(tapply(detalle[[5]][detalle[[1]] != 'TOTAL'],
                      detalle[[1]][detalle[[1]] != 'TOTAL'], sum)[names(esperado)] == esperado))
}
# El código genérico permanece en Otros, sin atribuirlo a una empresa real.
stopifnot(all(fuentes$tv_restringida$datos$.GRUPO_CLAVE[
  fuentes$tv_restringida$datos$K_GRUPO == 'C000'] == 'C000'))

param <- crear_parametros_periodo(2026L, 1L, preparado$empresas_otros)
texto <- valores_texto(param, tablas, datos)
stopifnot(identical(texto$S5_L1_NOMBRE, 'América Móvil'),
          identical(texto$S5_L1_PCT, '40.47%'),
          identical(texto$S5_L2_NOMBRE, 'Megacable-MCM'),
          identical(texto$S5_L3_NOMBRE, 'Grupo Televisa'),
          identical(texto$S5_L4_PCT, '18.82%'),
          identical(texto$S6_L1_NOMBRE, 'Grupo Televisa'),
          identical(texto$S6_L1_PCT, '31.41%'),
          identical(texto$S6_L2_PCT, '19.11%'),
          identical(texto$S6_L3_PCT, '7.82%'),
          !any(unlist(texto[grepl('^S[56]_L', names(texto))]) == '-'))
cat('OK: clasificación, totales, porcentajes, detalle y caché 2026Q1.\n')

# --solo-datos permite verificar el lector sin dependencias del Word.
if (!'--solo-datos' %in% commandArgs(trailingOnly = TRUE)) {
  args_salida <- sub('^--salidas=', '', grep('^--salidas=', commandArgs(TRUE), value = TRUE))
  salida <- if (length(args_salida)) args_salida[[1]] else file.path(trabajo, 'salidas')
  plantilla <- file.path(raiz, 'plantilla', 'Plantilla_Reporte_Telecom_Automatizable.docx')
  hash_plantilla <- tools::md5sum(plantilla)
  resultado <- ejecutar_generacion(raiz, 2026L, '1', carpeta_salidas = salida,
                                    carpeta_cache = cache, permitir_red = FALSE)
  stopifnot(resultado$ok, identical(hash_plantilla, tools::md5sum(plantilla)))
  extraido <- file.path(trabajo, 'word')
  utils::unzip(resultado$reportes[[1]], exdir = extraido)
  doc <- xml2::read_xml(file.path(extraido, 'word', 'document.xml'))
  ns <- c(w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
  texto_word <- paste(xml2::xml_text(xml2::xml_find_all(doc, './/w:t', ns)), collapse = ' ')
  for (valor in c('12,175,137', '5,876,041', '5,876,410', '5,660,570', '494,152',
                  '9,331,187', '5,675,402', '2,322,420', '923,638', '11,452,815',
                  '40.47%', '31.41%')) stopifnot(grepl(valor, texto_word, fixed = TRUE))
  enlaces <- xml2::xml_text(xml2::xml_find_all(doc, './/w:hyperlink', ns))
  stopifnot(sum(grepl('/descargas/datos/tabs/TD_', enlaces, fixed = TRUE)) == 12L,
            !grepl('-, con el -', texto_word, fixed = TRUE),
            !grepl('incluye 1 empresas', texto_word, fixed = TRUE),
            !grepl('incluye NA', texto_word, fixed = TRUE))
  for (tabla_xml in xml2::xml_find_all(doc, './/w:tbl', ns)) {
    cabecera <- xml2::xml_find_first(tabla_xml, './w:tr', ns)
    for (celda in xml2::xml_find_all(cabecera, './w:tc', ns)) {
      color <- xml2::xml_attr(xml2::xml_find_first(celda, './w:tcPr/w:shd', ns), 'w:fill', ns)
      bordes <- xml2::xml_find_all(celda, './w:tcPr/w:tcBorders/*', ns)
      stopifnot(all(xml2::xml_attr(bordes, 'w:color', ns) == color),
                all(xml2::xml_attr(bordes, 'w:val', ns) == 'single'))
    }
    stopifnot(xml2::xml_attr(xml2::xml_find_first(tabla_xml, './w:tblPr/w:tblCellSpacing', ns), 'w:w', ns) == '0')
  }
  cat('OK: Word 2026Q1 generado con seis gráficas y plantilla original intacta.\n')
  cat('Reporte:', resultado$reportes[[1]], '\n')
}
unlink(trabajo, recursive = TRUE)
