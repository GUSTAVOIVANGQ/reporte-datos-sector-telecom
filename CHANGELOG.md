# Historial de cambios

## v3.8.3 — 2026-09-30

- Unifica las seis tablas con la paleta, tipografía, franjas y separadores horizontales de 2 puntos del reporte CRT 2025Q4.
- Sustituye las propiedades heredadas de las filas modelo para evitar bordes finos de colores distintos, cierres ausentes en grupos y separadores blancos sobre la franja TOTAL.
- Conserva las fusiones de grupo/empresa, repite encabezados y mantiene juntos los bloques de grupo que caben en una página.
- Ajusta márgenes, alturas mínimas y alineación sin agregar contenido ni modificar las cifras. Conserva el archivo de plantilla original.
- Añade una comprobación de diseño para las seis tablas y comparación exacta de texto con el reporte anterior. Generación completa con los CSV actualizados del caso 2026Q1.

## v3.8.2 — 2026-09-30

- Normaliza bordes, separación entre celdas, anchos y medidas de las seis tablas generadas para evitar separadores blancos sobre fondos de color. Conserva el archivo de plantilla original.
- Descarta registros completamente vacíos añadidos al exportar los CSV. No elimina ceros, duplicados ni observaciones con datos; no modifica fórmulas ni importes.
- Incrementa a 4 la versión de caché procesada para aplicar la lectura corregida.
- Incorpora los CSV actualizados del caso y la opción --datos-zip en la regresión 2026Q1; comprueba filas útiles, bordes de cabeceras y separación cero entre celdas.
- Generación completa verificada con los datos actualizados y revisión visual de 16 páginas. Los 56 importes por concesionario y los 24 porcentajes concilian con los CSV; el texto del reporte recibido se conserva.
- Verificación local con R 4.3.3 y renderización mediante LibreOffice; no comprobado en Microsoft Word nativo. La matriz de producción se mantiene.

## v3.8.1 — 2026-09-30

- Resuelve las etiquetas de grupo codificadas en GRUPO mediante K_GRUPO para las fuentes BIT 2026Q1. Conserva los nombres explícitos de los CSV y las claves genéricas en el renglón Otros existente.
- Invalida automáticamente la caché procesada v2. No modifica los CSV originales ni la plantilla Word.
- Corrige los datos que alimentan texto, tablas y gráficas de internet fijo y TV restringida.
- Si una clave genérica no identifica empresas, conserva el importe en Otros y omite solo la nota de conteo no determinable en la copia generada; no agrega avisos al Word.
- Incluye pruebas con los seis CSV del caso 2026Q1: totales, desglose, porcentajes, detalle, caché antigua y generación completa del DOCX.
- Verificación local con R 4.3.3, data.table 1.14.10 y xml2 1.3.6. La matriz de dependencias de producción se mantiene; ejecutar la regresión en el servidor para verificar sus versiones instaladas.


Todos los cambios notables de este proyecto se documentan en este archivo.

## v3.8.0

- Botón **Actualizar los seis CSV** en la sección de fuentes, con avance y resultado dentro de la
  interfaz.
- Descarga reanudable con reintentos, límite configurable y validación completa de estructura y
  filas antes de aceptar cada fuente.
- Reemplazo transaccional: se prepara el lote completo y, si alguna fuente falla, se conservan los
  seis CSV anteriores; un bloqueo compartido impide actualizaciones simultáneas.
- Endpoint `POST /v1/fuentes/actualizar` para ejecutar la misma operación desde automatizaciones.
- Registro estructurado de inicio, éxito y fallo; pruebas de conservación del lote anterior y de
  sustitución de los seis archivos.

## v3.7.4

- Sustitución de `shiny::small()` por `shiny::tags$small()`, compatible con Shiny 1.14, en la
  ficha del último documento generado.
- Nuevo logotipo institucional blanco en PNG transparente, conservando la imagen proporcionada.
- Pruebas de regresión para impedir el uso de la exportación inexistente y verificar formato,
  transparencia, resolución y publicación pública del logotipo.

## v3.7.3

- Publicación explícita de `www/` mediante `shiny::addResourcePath()` cuando la aplicación se
  ejecuta como objeto `shinyApp`, corrigiendo la interfaz sin CSS, JavaScript ni logotipo.
- URL relativas bajo `reporte-activos/`, compatibles con el proxy nginx en `/telecom/`.
- El despliegue ahora comprueba CSS y JavaScript directamente en Shiny, y CSS, JavaScript y
  logotipo a través de la URL pública antes de declarar la interfaz lista.
- Pruebas de regresión para el registro, destino y presencia física de los tres activos.

## v3.7.2

- La prueba Shiny ahora valida conjuntamente las secciones `head` y `html` producidas por
  `htmltools::renderTags()`, donde `fluidPage()` distribuye los activos de la página.
- Comprobación adicional de que `www/app.css` y `www/app.js` existen físicamente.
- Prueba estática de regresión para conservar la inspección completa del documento HTML.

## v3.7.1

- Corrección de la prueba Shiny de interfaz para validar el HTML completo como una sola cadena,
  evitando un falso negativo cuando `as.character(ui)` devuelve varios fragmentos.
- Sin cambios funcionales en la interfaz, la generación del reporte ni los servicios desplegados.

## v3.7.0

- Rediseño institucional de la interfaz con navegación lateral, barra superior y área principal de
  vista previa, siguiendo la propuesta visual de entrega.
- Secciones funcionales para generación, historial de documentos, disponibilidad de las seis
  fuentes y configuración/métricas del servicio.
- Logotipo CRT local, tema claro/oscuro persistente, menú móvil y diseño adaptable a escritorio,
  tableta y teléfono.
- Indicador de cuatro etapas, tiempo observado o estimado, avisos de sesión, ayuda y estados con
  mayor contraste y jerarquía visual.
- Mejoras de accesibilidad: navegación por teclado, salto al contenido, foco visible, textos
  alternativos y respeto de la preferencia de movimiento reducido.
- Pruebas estáticas de activos y resolución del logotipo, además de una prueba Shiny de navegación
  y carga inicial sin lecturas fuera del contexto reactivo.

## v3.6.7

- Construcción explícita de los cuatro fragmentos OOXML de cada pie de fuente, sin reutilizar runs
  incompletos de la plantilla ni depender de que contengan un nodo `w:t`.
- Conservación de las notas de “Otros” que comparten párrafo con dos pies de fuente.
- Validación del texto visible y del destino de los 12 hipervínculos antes de empaquetar el DOCX.

## v3.6.6

- Clonado directo de los runs OOXML usados en los pies de fuente, conservando el espacio de nombres
  `w` requerido por Word y `xml2`.
- Eliminación de los avisos `Namespace prefix w ... is not defined`; quedó pendiente un run sin
  nodo de texto en los dos pies que también contienen una nota.
- Prueba de integración que genera un DOCX temporal y verifica sus 12 hipervínculos de fuente.

## v3.6.5

- Corrección de la caída de Shiny al leer `resultado()` desde `session$onFlushed()` sin un contexto
  reactivo; la carga inicial ahora usa `shiny::isolate()`.
- Contención de cualquier error de la vista previa inicial dentro de la sesión, sin terminar el
  proceso Shiny compartido.
- Prueba de servidor que abre una sesión y ejecuta el primer flush para detectar esta regresión.
- Ejecución de los scripts de health check y alertas mediante `/usr/bin/bash`, evitando el error
  `203/EXEC` por permisos de ejecución bajo `/data`.

## v3.6.4

- Health check periódico basado en estado de `systemd` y puerto local, en lugar de reiniciar Shiny o
  la API cuando una petición HTTP tarda durante una generación o conversión de vista previa.
- Segunda comprobación después de cinco segundos antes de reiniciar un servicio realmente inactivo.
- Inclusión explícita de `iproute` en RHEL para disponer del comando `ss` usado por el monitor.

## v3.6.3

- Espera activa de hasta 60 segundos para los health checks de Plumber y Shiny después de reiniciar
  los servicios, evitando el falso `Connection refused` durante su arranque normal.
- Estado y últimas líneas del diario de `systemd` incluidos automáticamente si un servicio no queda
  disponible dentro del tiempo esperado.

## v3.6.2

- Instalación explícita de `libsodium-devel` y `pkgconf-pkg-config` en RHEL para compilar la
  dependencia R `sodium` requerida por `plumber`.
- Diagnóstico temprano cuando EPEL 9 o `libsodium.pc` no están disponibles, antes de iniciar la
  restauración lenta de `renv`.
- Inclusión equivalente de `libsodium-dev` en la imagen Docker y documentación para habilitar EPEL
  9 y CodeReady Builder en RHEL 9.

## v3.6.1

- Agrupación contigua de todos los concesionarios de una misma empresa y combinación vertical de su
  celda `Empresa`, incluso cuando la fuente BIT publica sus registros separados.
- Hipervínculos externos reales, azules y subrayados, en las 12 URL de fuente de tablas y gráficas.
- Validación del motor para impedir empresas divididas en bloques y prueba estructural independiente
  del DOCX para verificar agrupación, destino, color y subrayado de los enlaces.
- Conservación del comportamiento correcto de secciones sin datos mediante `-` y “Datos no
  disponibles”.

## v3.6.0

- Licencia MIT y guía breve `CONTRIBUTING.md`.
- API REST con `plumber`: salud, fuentes, métricas, generación y descarga segura.
- Swagger/OpenAPI automático en `/__docs__/` y `/openapi.json`.
- Interfaz adaptable en dos columnas, con visor PDF del Word existente más reciente a la izquierda y controles a la derecha.
- Conversión de DOCX a PDF mediante LibreOffice; su ausencia no bloquea la generación ni la descarga.
- Contenedores reproducibles con R 4.6.1, Python 3.9.25, Pillow 11.3.0 y volúmenes persistentes.
- `renv.lock`, catálogo de versiones directas certificadas y snapshot CRAN fechado para dependencias transitivas.
- Exclusión de los CSV pesados del repositorio; descarga bajo demanda desde el catálogo BIT.
- Logs estructurados JSONL, rotación, métricas de duración/éxito/fallo y alertas por fuente repetida.
- Alerta `systemd` configurable cuando falla la UI o la API.
- Servicios RHEL independientes para Shiny y API, ambos con reinicio automático.
- Compatibilidad RHEL con directorios `lib`/`lib64` de Python y temporales ejecutables en `/data`.

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
