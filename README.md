# Reporte de Datos del Sector de Telecomunicaciones — v3.6.7

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

## Entorno certificado

| Componente | Versión certificada |
|---|---:|
| Proyecto | 3.6.7 |
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

Al abrirse, la interfaz muestra el DOCX existente más reciente cuando lo encuentra. Al terminar una
nueva generación, convierte el primer DOCX a PDF y lo muestra a la izquierda. Si se generaron varios
trimestres, el selector superior permite cambiar el documento visualizado. El panel de año,
trimestre, estado y descarga permanece a la derecha.

## Línea de comandos

```bash
Rscript main.R --automatico --anio=2024 --trimestre=todos
Rscript main.R --automatico --anio=2024 --trimestre=4 --sin-red
Rscript main.R --automatico --anio=2024 --trimestre=todos --actualizar
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
| `GET` | `/v1/metricas` | Totales, éxito, fallos y duración promedio |
| `POST` | `/v1/reportes` | Genera uno o todos los trimestres |
| `GET` | `/v1/reportes/{id}/descarga` | Descarga segura de DOCX, ZIP o control |
| `GET` | `/__docs__/` | Swagger UI automático |
| `GET` | `/openapi.json` | Especificación OpenAPI |

Ejemplo:

```bash
curl -X POST http://127.0.0.1:8000/v1/reportes \
  -H 'Content-Type: application/json' \
  -d '{"anio":2024,"trimestre":"Q4","actualizar":false,"permitir_red":true}'
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
