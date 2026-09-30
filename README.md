# Reporte de Datos del Sector de Telecomunicaciones — v3.8.4

Aplicación R que descarga, valida y procesa seis fuentes del Banco de Información de
Telecomunicaciones (BIT) para producir reportes Word trimestrales. R realiza todo el procesamiento y
la construcción del DOCX; Python y Pillow generan exclusivamente las seis gráficas jerárquicas.

El proyecto ofrece tres entradas equivalentes:

- interfaz Shiny con previsualización del documento;
- línea de comandos para automatizaciones;
- API REST `plumber` con Swagger/OpenAPI.

## Periodicidad y fuentes

El reporte es trimestral. Las fuentes mensuales usan marzo, junio, septiembre y diciembre; ingresos
usa los trimestres 1–4 marcados como trimestrales. Un trimestre se genera cuando al menos una fuente
contiene el periodo. Las secciones todavía no publicadas muestran `-`, emiten una advertencia y no
interrumpen las demás secciones.

| Sección | CSV |
|---|---|
| Telefonía móvil | `TD_LINEAS_TELMOVIL_ITE_VA.csv` |
| Internet móvil | `TD_LINEAS_INTMOVIL_ITE_VA.csv` |
| Ingresos | `TD_INGRESOS_TELECOM_ITE_VA.csv` |
| Telefonía fija | `TD_LINEAS_TELFIJA_ITE_VA.csv` |
| Internet fijo | `TD_ACC_BAF_ITE_VA.csv` |
| Televisión restringida | `TD_ACC_TVRES_ITE_VA.csv` |

Las URL están en `config/reporte-datos-sector-telecomunicaciones.xlsx`. Los CSV no se guardan en Git:
si un archivo falta, el programa lo descarga. La caché procesada se invalida automáticamente cuando
cambia el tamaño o la fecha del CSV.

El paquete v3.8.4 entregado incluye además una copia local de los seis CSV usados para la
regresión **2026Q1** en `entrada/datos_bit/`, de modo que ese trimestre puede reproducirse sin
descarga de red.

La sección **Fuentes de datos** incluye el botón **Actualizar los seis CSV**. La operación descarga
cada archivo con reintentos y validación de estructura en un área temporal. Los CSV locales solo se
reemplazan cuando las seis descargas son completas y válidas; ante cualquier fallo se conserva el
lote anterior. `REPORTE_DESCARGA_INTENTOS` controla los intentos por fuente (5 de forma
predeterminada) y `REPORTE_DESCARGA_TIMEOUT` el límite de cada transferencia en segundos (3600).

## Entorno certificado

| Componente | Versión certificada |
|---|---:|
| Proyecto | 3.8.4 |
| R | 4.6.1 |
| CPython | 3.9.25 |
| Pillow | 11.3.0 |
| RHEL | 9.7 |

Las versiones exactas de las dependencias R directas están en `renv.lock` y
`config/versiones-soportadas.json`. La resolución de dependencias transitivas queda congelada por el
repositorio CRAN con fecha `2026-08-03`, evitando que una restauración futura use publicaciones más
nuevas. Restaure el entorno con:

```r
install.packages("renv")
renv::restore()
```

Después instale la dependencia Python:

```bash
python -m pip install -r requirements-python.txt
```

LibreOffice es necesario únicamente para convertir el DOCX a PDF en la vista previa. Si no está
instalado, el reporte se genera y se descarga normalmente.

## Interfaz

```bash
Rscript main.R --ui
```

La interfaz institucional incluye navegación lateral funcional para generar reportes, consultar el
historial, revisar la presencia de las seis fuentes y visualizar la configuración del servicio. El
visor ocupa el área principal y la selección de año, trimestre, estado y descarga permanece a la
derecha. Al abrirse muestra el DOCX existente más reciente; al terminar una generación convierte el
primer DOCX a PDF. Si se generaron varios trimestres, el selector superior cambia el documento
visualizado.

La presentación es adaptable a escritorio, tableta y móvil; incluye navegación por teclado, enlace
para saltar al contenido, reducción de movimiento, avisos accesibles y tema claro/oscuro persistente.
CSS, JavaScript y el logotipo blanco transparente `www/logo_crt_blanco.png` se sirven mediante la
ruta de recursos Shiny `reporte-activos/`. Este registro explícito permite usar el objeto
`shinyApp` detrás del prefijo nginx `/telecom/` sin perder archivos estáticos.

## Línea de comandos

```bash
Rscript main.R --automatico --anio=2026 --trimestre=todos
Rscript main.R --automatico --anio=2026 --trimestre=1 --sin-red
Rscript main.R --automatico --anio=2026 --trimestre=todos --actualizar
```

Use `Rscript main.R --ayuda` para ver rutas y opciones adicionales.

## API REST

```bash
Rscript api/run_api.R --host=127.0.0.1 --port=8000
```

| Método | Ruta | Función |
|---|---|---|
| `GET` | `/salud` | Estado de R, Python, plantilla, almacenamiento y fuentes |
| `GET` | `/v1/fuentes` | Inventario de los seis CSV y sus URL |
| `POST` | `/v1/fuentes/actualizar` | Descarga y reemplaza de forma segura los seis CSV |
| `GET` | `/v1/metricas` | Totales, éxito, fallos y duración promedio |
| `POST` | `/v1/reportes` | Genera uno o todos los trimestres |
| `GET` | `/v1/reportes/{id}/descarga` | Descarga segura de DOCX, ZIP o control |
| `GET` | `/__docs__/` | Swagger UI automático |
| `GET` | `/openapi.json` | Especificación OpenAPI |

Ejemplo:

```bash
curl -X POST http://127.0.0.1:8000/v1/reportes \
  -H 'Content-Type: application/json' \
  -d '{"anio":2026,"trimestre":"Q1","actualizar":false,"permitir_red":true}'
```

Para actualizar las seis fuentes sin generar un reporte:

```bash
curl -X POST http://127.0.0.1:8000/v1/fuentes/actualizar \
  -H 'Content-Type: application/json' \
  -d '{"reintentos":5}'
```

La solicitud de generación es síncrona: el cliente debe usar un tiempo de espera suficiente. El
servidor Nginx incluido usa 3600 segundos.

## Docker

```bash
docker compose build
docker compose up -d
docker compose ps
```

- UI: `http://localhost:3838/`
- API: `http://localhost:8000/`
- Swagger: `http://localhost:8000/__docs__/`

Los volúmenes `entrada/datos_bit` y `salidas` persisten fuentes, caché, reportes, logs y métricas.

## RHEL 9.7

Consulte `DEPLOY_RHEL.md`. El despliegue instala dos servicios con reinicio automático:

- `reporte-telecom.service` para Shiny;
- `reporte-telecom-api.service` para la API.

Nginx publica `/telecom/` y `/telecom/api/`. El instalador usa un temporal ejecutable dentro de
`/data`, configura las rutas Python `lib/lib64` y deja los CSV existentes intactos.

## Observabilidad y alertas

Los eventos se escriben como JSONL en `salidas/observabilidad/aplicacion.jsonl`; las métricas se
guardan en `generaciones.csv`. La aplicación rota el JSONL al llegar a 10 MB y RHEL agrega rotación
diaria con 14 copias comprimidas.

Si `REPORTE_ALERT_WEBHOOK_URL` está configurada:

- `systemd` envía una alerta cuando falla la UI o la API;
- una fuente genera una alerta al acumular tres ejecuciones consecutivas con advertencias.

Sin webhook, los eventos siguen quedando en el log y en `journalctl`.

## Validaciones principales

- CSV ausente: descarga automática cuando la red está permitida.
- Archivo inválido: no sustituye una copia válida.
- Sección sin periodo: tabla y gráfica con ausencia; el reporte continúa.
- Empresas y concesionarios principales: una empresa ocupa un bloque continuo y cada concesionario
  aparece en una fila propia dentro de la celda combinada de su empresa.
- Títulos y fuentes: se mantienen encima del objeto; las URL BIT son hipervínculos azules y
  subrayados en los 12 pies de tabla y gráfica.
- Python/Pillow: se validan antes de modificar el Word.
- Totales, valores vacíos, negativos, duplicados y MD5: quedan en archivos de control.

## Pruebas

```bash
Rscript tests/prueba_motor.R
Rscript tests/prueba_integracion_python.R
Rscript tests/prueba_vista_previa.R
Rscript tests/prueba_ui_servidor.R
Rscript tests/prueba_api.R
python tests/prueba_graficas_python.py
python tests/prueba_estructura_docx.py salidas/Reporte_Telecomunicaciones_2025Q4_vBIT.docx
```

## Licencia y colaboración

El código se distribuye bajo la licencia MIT. Consulte `LICENSE` y `CONTRIBUTING.md`. Los datos
descargados conservan las condiciones publicadas por su fuente; la licencia del código no modifica
la titularidad ni las condiciones de los datos del BIT.

## Corrección 2026Q1 en v3.8.1

La plantilla original se conserva. El lector resuelve las claves de los grupos
cuando la columna GRUPO contiene códigos o está vacía, y conserva los nombres
explícitos. Los valores sin atribución permanecen en el renglón Otros existente;
no se inventan empresas ni se eliminan observaciones. La caché anterior se
reconstruye automáticamente al leer cada fuente.

Prueba de regresión con los seis CSV adjuntos al caso, sin descargas:

```bash
Rscript tests/prueba_2026Q1.R
```

Generación con los CSV que ya tengas en entrada/datos_bit:

```bash
Rscript main.R --automatico --anio=2026 --trimestre=1 --sin-red
```

Para conservar el Word de la prueba de regresión:

```bash
Rscript tests/prueba_2026Q1.R --salidas=salidas/regresion_2026Q1
```

Los CSV de prueba están en `tests/fixtures/2026Q1.zip`; se extraen a una carpeta
temporal. La prueba no reemplaza los datos de producción.


## Revisión de tablas y CSV actualizados en v3.8.2

El generador normaliza los bordes de las cabeceras con sus colores de fondo,
elimina los separadores verticales blancos del cuerpo y establece anchos
explícitos y medidas enteras en las tablas. La plantilla original permanece
intacta; los ajustes se aplican al documento generado, sin agregar contenido.

El lector descarta únicamente registros completamente vacíos. Conserva los
registros con ceros, los duplicados de origen y los importes de Otros. La caché
procesada se reconstruye automáticamente con la versión 4.

Regresión con los CSV actualizados del caso:

```bash
Rscript tests/prueba_2026Q1.R --datos-zip=tests/fixtures/2026Q1_actualizado.zip --salidas=salidas/regresion_2026Q1_actualizado
```

La conciliación independiente del caso verificó los 56 importes por
concesionario, los totales por grupo y de las seis tablas, Otros y los 24
porcentajes del texto. El documento generado conserva el texto y las cifras
del Word recibido. Se revisó visualmente su renderización de 16 páginas;
no se realizó una comprobación en Microsoft Word nativo.

Si Word muestra líneas de cuadrícula de edición, se pueden ocultar desde
Disposición de tabla > Ver líneas de cuadrícula. Estas guías no se imprimen;
son distintas de los bordes guardados en el documento.


## Diseño CRT de las seis tablas en v3.8.4

La generación aplica una definición común de formato basada en las tablas del
[reporte CRT 2025Q4](https://portal.crt.gob.mx/docs-bin/reportes/reporte-de-datos-del-sector-de-telecomunicaciones/estadistica-2025-q4.pdf):

- Cabeceras alternas #098F93 y #1A4043, texto blanco Noto Sans de 10 puntos.
- Separadores horizontales #7ECCC2 de 2 puntos, respetando las celdas combinadas.
- Cuerpo Noto Sans de 9 puntos, cifras alineadas a la derecha y sombreado alterno
  #EFEFEF únicamente en las columnas de concesionario e importe.
- Franja TOTAL #308288, con texto blanco en negrita de 10 puntos.
- Cabecera repetida al continuar en otra página, filas sin división y conservación
  de los bloques de grupo cuando caben en una página.

El archivo de plantilla original se conserva íntegro. El generador aplica el
acabado en la copia de salida, sin cambiar datos, textos, columnas ni fórmulas.
Los saltos y alturas se adaptan al número real de concesionarios de cada periodo.

Comprobación del diseño y, opcionalmente, del texto frente a una versión anterior:

```bash
python tests/prueba_diseno_crt.py RUTA_AL_REPORTE.docx
python tests/prueba_diseno_crt.py RUTA_AL_REPORTE.docx RUTA_AL_REPORTE_ANTERIOR.docx
```

La entrega 2026Q1 fue generada con los CSV actualizados y revisada visualmente
mediante LibreOffice. No se comprobó en Microsoft Word nativo.
