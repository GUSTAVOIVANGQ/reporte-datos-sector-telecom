# Historial de cambios

Todos los cambios notables de este proyecto se documentan en este archivo.

## v3.4.0

- Lectura selectiva y multihilo de los CSV grandes mediante `data.table::fread()`.
- Detección de codificación limitada a una muestra de 128 KB.
- Normalización por bloques de archivos UTF-16 o con caracteres NUL, sin cargar el archivo completo en memoria.
- Caché RDS procesada, sin compresión e invalidada automáticamente cuando cambia el CSV.
- Transformación de nombres por valores únicos y agregación rápida con `data.table`.
- Caché de MD5 y reutilización de los datos ya leídos durante descargas y reportes multitrimestre.
- Eliminación de descargas automáticas repetidas cuando un CSV válido aún no contiene el periodo solicitado.
- Cronómetros por fuente, por carga total y por trimestre, además de una prueba de benchmark reproducible.
- Pruebas de equivalencia de resultados, reutilización de caché y reconocimiento de UTF-16.

## v3.3.0

- Tablas de longitud variable con una fila por concesionario publicado en cada GIE principal.
- Eliminación de “N operadores consolidados”, capacidades fijas y listas truncadas de concesionarios.
- Conversión de las seis tablas Word de flotantes a elementos en línea para conservar el orden visual.
- Títulos de tablas y gráficas configurados para mantenerse con el objeto correspondiente.
- Encabezados repetidos automáticamente cuando una tabla se divide entre páginas.
- URL específica del CSV BIT en los 12 pies de tabla y gráfica.
- Selección de trimestres por unión de cobertura: basta con que una fuente contenga el periodo.
- Secciones ausentes representadas con `-`, advertencia de terminal y gráfico Python de datos no disponibles.
- Diseño jerárquico Python flexible para grupos publicados con valor cero.
- Pruebas nuevas para desglose exacto, periodo parcial, marcador de ausencia y paginación del Word.

## v3.2.0

- Migración exclusiva de las seis gráficas jerárquicas a Python y Pillow.
- Conservación en R de la descarga, validación, agregación, controles y creación del Word.
- Puente R-Python mediante CSV intermedios auditables con columnas `grupo` y `valor`.
- Detección configurable de Python 3 y validación previa de Pillow y la fuente tipográfica.
- Validación Python de grupos faltantes, duplicados, valores, geometría y dimensiones PNG.
- Pruebas independientes de Python y de la integración R-Python para las seis secciones.

## v3.1.0

- Restauración de las seis gráficas de mosaicos proporcionales del documento histórico.
- Conservación de la geometría, paleta institucional, rótulos internos y dimensiones de imagen del Word de referencia.
- Ajuste automático de rótulos largos para impedir desbordamientos entre rectángulos.
- Validación explícita de sección, valores y archivo PNG generado.
- Ajuste de la plantilla para mantener juntas las líneas de fuente y nota cuando una tabla cambia de altura.

## v3.0.0

- Integración de las seis fuentes BIT del reporte completo.
- Selección de año y generación de uno o todos los trimestres comunes.
- Uso del cierre mensual de marzo, junio, septiembre y diciembre para indicadores mensuales.
- Catálogo Excel de enlaces identificado por nombre canónico de archivo.
- Caché local con descarga automática cuando un CSV no existe.
- Actualización de una fuente cuando le falta el periodo solicitado.
- Diagnóstico anual por sección: ausente, parcial o completo.
- Registro de cobertura, codificación, valores vacíos, negativos, duplicados y MD5.
- Imputación auditable a cero para totales vacíos publicados, sin ocultar la incidencia.
- Conservación de ajustes negativos de ingresos y filas duplicadas oficiales.
- Salida anual con un Word por trimestre, ZIP y archivos de control.
- Interfaz y línea de comandos actualizadas para año, trimestre, red, caché y catálogo.
- Prueba reproducible de cobertura y conciliación de 2024.

## v2.0.0

- Sustitución del Excel manual por el CSV `TD_INGRESOS_TELECOM_ITE_VA.csv`.
- Descarga automática desde el BIT con respaldo local si la red no está disponible.
- Filtrado explícito de registros trimestrales para evitar mezclar observaciones anuales.
- Selección de último periodo, un periodo `AAAAQN` o todos los periodos existentes.
- Generación de un Word por trimestre y ZIP consolidado en modo `todos`.
- Tabla dinámica por grupo, empresa y concesionario.
- Gráfica de participación de los grupos principales.
- Registro de controles de calidad por periodo.
- Nueva interfaz Shiny y nuevas opciones de línea de comandos.
- Alcance limitado a ingresos, única métrica contenida en la nueva fuente.

## v1.3.0

- Interfaz reducida a los campos y acciones esenciales.
- Eliminación del panel de registros de la interfaz.
- Drive y Sheets activados y configurados automáticamente.
- Selección de carpeta de Drive eliminada de la interfaz.
- Botón para abrir la carpeta local de resultados.
- Resumen final con rutas y enlaces en la terminal.
- Registros más descriptivos para autenticación, cargas, archivos y duración.
