# Reporte de Datos del Sector de Telecomunicaciones — v3.4.0

Aplicación en R que descarga, valida y procesa seis fuentes del Banco de Información de Telecomunicaciones (BIT) para generar el reporte Word del año seleccionado.

R realiza la descarga, validación, agregación de datos, controles y construcción del Word. Únicamente las seis gráficas jerárquicas se crean en Python mediante Pillow. Reproducen los mosaicos proporcionales del Word histórico: rectángulos por grupo económico, paleta institucional, rótulos blancos y dimensiones compatibles con la plantilla. El tamaño de cada rectángulo se recalcula con los datos del trimestre solicitado. Si un área es demasiado pequeña, se omite únicamente ese rótulo para evitar invasiones.

## Periodicidad

Sí: el documento de referencia es **trimestral**. Al seleccionar un año, el programa puede generar Q1, Q2, Q3 y Q4.

- En las cinco fuentes mensuales toma el cierre de marzo, junio, septiembre y diciembre.
- En ingresos toma `TRIM = 1, 2, 3, 4` y conserva únicamente `I_ANUAL_TRIM = Trimestral`.
- Un trimestre se genera cuando al menos una de las seis fuentes contiene el cierre requerido.
- Si una sección no está publicada para ese periodo, su tabla usa `-`, Python crea un gráfico de
  **Datos no disponibles** y la terminal registra una advertencia; las demás secciones continúan.
- La opción `todos` produce todos los trimestres presentes en al menos una fuente del año.

## Fuentes

El archivo `config/reporte-datos-sector-telecomunicaciones.xlsx` contiene los enlaces. El programa identifica cada fuente por el nombre del CSV, no por la posición de la fila.

| Sección | CSV | Periodo usado |
|---|---|---|
| Líneas activas de telefonía móvil | `TD_LINEAS_TELMOVIL_ITE_VA.csv` | Mes 3, 6, 9 o 12 |
| Accesos activos a internet móvil | `TD_LINEAS_INTMOVIL_ITE_VA.csv` | Mes 3, 6, 9 o 12 |
| Ingresos | `TD_INGRESOS_TELECOM_ITE_VA.csv` | Trimestre 1, 2, 3 o 4 |
| Líneas del servicio fijo de telefonía | `TD_LINEAS_TELFIJA_ITE_VA.csv` | Mes 3, 6, 9 o 12 |
| Accesos a internet fijo | `TD_ACC_BAF_ITE_VA.csv` | Mes 3, 6, 9 o 12 |
| Accesos a televisión restringida | `TD_ACC_TVRES_ITE_VA.csv` | Mes 3, 6, 9 o 12 |

Las copias de referencia recibidas están en `entrada/datos_bit/`.

## Cobertura comprobada en las copias incluidas

2024 tiene los cuatro cierres trimestrales en las seis fuentes, por lo que es el año predeterminado y se pueden generar sus cuatro reportes.

2025 no tiene todavía cobertura completa en las copias incluidas: telefonía fija solo contiene Q1 e internet fijo no contiene 2025. Las demás fuentes sí llegan a Q4. El programa sí genera esos reportes parciales y deja visibles las secciones ausentes. Esta condición no está codificada de forma permanente: cuando el CRT sustituya un CSV, el cambio de tamaño o fecha invalida automáticamente la caché procesada. Para buscar deliberadamente una publicación nueva se usa **Forzar actualización**.

Algunas filas oficiales de 2024 tienen el total vacío. Para no perder todo el trimestre, el motor las trata como cero y las registra en `diagnostico_fuentes.csv`, `control_ejecucion.csv` y `advertencias.txt`. No se oculta esta imputación.

## Descarga y caché

Para cada una de las seis fuentes:

1. Busca el nombre canónico en `entrada/datos_bit/`.
2. Si no existe, descarga el enlace del catálogo.
3. Antes de sustituir la caché, comprueba que el archivo descargado sea un CSV legible y tenga el esquema requerido.
4. Si el archivo local es válido pero no contiene el año/trimestre solicitado, lo conserva, informa qué periodo falta y continúa con `-` en esa sección. Esto evita volver a descargar archivos grandes que todavía no han sido actualizados por el CRT.
5. Si la red falla y hay una copia local válida, conserva esa copia y emite una advertencia.
6. Si no existe una copia válida, detiene el proceso con un mensaje explícito.

La opción **Forzar actualización** descarga las seis fuentes antes de procesar. La opción **sin red** permite una ejecución totalmente local y reproducible.

### Optimización de archivos grandes

- `data.table::fread()` lee únicamente las 9 o 10 columnas necesarias, en lugar de interpretar todas las columnas de los CSV de 68–146 MB.
- La detección de codificación consulta una muestra de 128 KB; ya no carga el archivo completo como bytes.
- Los caracteres NUL y los archivos UTF-16 se normalizan por bloques una sola vez.
- Después de la primera lectura se guarda una caché RDS sin compresión en `entrada/datos_bit/_cache_reporte/`.
- La caché se invalida automáticamente si cambia el tamaño o la fecha de modificación del CSV.
- Los nombres de grupo, empresa y concesionario se normalizan por valor único, no fila por fila.
- La huella MD5 se calcula una sola vez por versión del CSV y se reutiliza al generar varios trimestres.
- La terminal muestra filas, origen (`CSV` o `caché procesada`) y segundos de validación por fuente.

La primera ejecución todavía debe leer los CSV y crear la caché. Las siguientes deben ser sensiblemente más rápidas. La carpeta `_cache_reporte` es derivada y puede eliminarse de forma segura si se desea reconstruirla.

## Validaciones

| Comprobación | Acción |
|---|---|
| Archivo inexistente | Descarga automática si la red está permitida |
| Descarga corrupta o esquema incompleto | No reemplaza una caché válida; informa el error |
| Año sin observaciones en las seis fuentes | Estado `Ausente`; no genera reportes para ese año |
| Año con algunos cierres | Estado `Parcial`; genera cada trimestre presente en al menos una fuente |
| Cierre trimestral ausente en una sección | Tabla con `-`, gráfico de ausencia y advertencia; el reporte continúa |
| Total vacío/no numérico en una fila publicada | Imputa cero, cuenta la incidencia y advierte |
| Valor negativo en ingresos | Lo conserva como ajuste posterior y lo registra |
| Valor negativo en líneas o accesos | Detiene ese trimestre |
| Fila exactamente duplicada | La conserva como está publicada y registra el conteo |
| Totales de tabla y de grupo | Deben conciliar antes de modificar el Word |
| Python 3 o Pillow no disponibles | Detiene la ejecución antes de crear el Word y muestra cómo configurar la dependencia |
| CSV intermedio sin grupos requeridos | Python rechaza la gráfica; si toda la sección está ausente usa el marcador de ausencia |
| Valores no finitos o negativos en una gráfica | Detiene la creación de esa gráfica con un mensaje explícito |
| Concesionarios de los GIE principales | Una fila por nombre exacto; nunca usa “N operadores consolidados” |
| Títulos de tablas y gráficas | Se mantienen encima del objeto; los encabezados de tablas largas se repiten |
| Pies de fuente | Las 12 fuentes incluyen la URL específica del CSV utilizado |
| Estructura del Word | Verifica las seis tablas variables, campos, imágenes y estructura interna del DOCX |

Estas reglas permiten comparar después las cifras del BIT con el reporte histórico sin borrar ajustes posteriores de los operadores.

## Requisitos

- R 4.1 o superior.
- Python 3.9 o superior.
- Windows, macOS o Linux.
- Internet únicamente para instalar paquetes y descargar/actualizar fuentes.
- Paquetes R: `readxl`, `xml2`, `zip`, `data.table` y `shiny`.
- Paquete Python: `Pillow`.

Los paquetes R faltantes se instalan automáticamente desde CRAN. Pillow se instala una vez desde la carpeta del proyecto:

```bash
python -m pip install -r requirements-python.txt
```

El programa busca `python3`, `python` o el iniciador `py` de Windows. También puede indicarse una ruta con `--python=RUTA` o con la variable de entorno `REPORTE_PYTHON`. Para usar una fuente TTF institucional específica en los rótulos, defina `REPORTE_FUENTE_GRAFICAS`.

## Uso con interfaz

Desde la carpeta del proyecto:

```bash
Rscript main.R
```

También puede ejecutarse desde RStudio:

```r
source("main.R")
```

La interfaz permite seleccionar año, todos los trimestres o uno específico, forzar actualización, desactivar la red y elegir las rutas del catálogo, caché y salida.

## Uso automático

Generar todos los trimestres disponibles de 2024 con la caché incluida:

```bash
Rscript main.R --automatico --anio=2024 --trimestre=todos --sin-red
```

Generar solo Q4 y descargar una fuente únicamente si falta o es inválida:

```bash
Rscript main.R --automatico --anio=2024 --trimestre=4
```

Forzar la descarga de las seis fuentes:

```bash
Rscript main.R --automatico --anio=2024 --trimestre=todos --actualizar
```

Usar ubicaciones diferentes:

```bash
Rscript main.R --automatico \
  --anio=2024 \
  --trimestre=todos \
  --catalogo="ruta/reporte-datos-sector-telecomunicaciones.xlsx" \
  --cache="ruta/datos_bit" \
  --salidas="ruta/salidas" \
  --python="ruta/python3"
```

Ayuda y prueba rápida:

```bash
Rscript main.R --ayuda
Rscript tests/prueba_motor.R
Rscript tests/prueba_integracion_python.R
Rscript tests/benchmark_lectura.R
python tests/prueba_graficas_python.py
```

## Resultados

Cada ejecución crea una carpeta independiente:

```text
salidas/ejecucion_2024_AAAAMMDD_HHMMSS_PID/
├── Reportes_Telecomunicaciones_2024_Q1_Q2_Q3_Q4.zip
├── diagnostico_fuentes.csv
├── control_ejecucion.csv
├── resumen_totales.csv
├── advertencias.txt                 # solo cuando existen incidencias
├── reportes/
│   ├── Reporte_Telecomunicaciones_2024Q1_vBIT.docx
│   ├── Reporte_Telecomunicaciones_2024Q2_vBIT.docx
│   ├── Reporte_Telecomunicaciones_2024Q3_vBIT.docx
│   └── Reporte_Telecomunicaciones_2024Q4_vBIT.docx
└── monitoreo/
    └── 2024QX/
        ├── tabla_1.csv ... tabla_6.csv
        ├── datos_grafica_1.csv ... datos_grafica_6.csv
        └── grafica_1.png ... grafica_6.png
```

El ZIP anual incluye los Word y los tres archivos CSV de control. Si se solicita un solo trimestre, el entregable principal es el DOCX individual y los controles permanecen en la carpeta de ejecución.

## Archivos principales

- `main.R`: interfaz o línea de comandos.
- `app.R`: interfaz Shiny.
- `fuentes_bit.R`: catálogo, descarga, codificación, cobertura, validación y agregación.
- `generar_reporte.R`: orquestación anual, Word y controles.
- `graficas_python.R`: puente seguro que entrega a Python solo los datos agregados de cada gráfica.
- `python/graficas_jerarquia.py`: geometría, colores, rótulos y exportación PNG de los seis mosaicos.
- `requirements-python.txt`: dependencia Python reproducible.
- `motor_word_plantilla.R`: filas variables, fusiones, títulos, fuentes URL y sustitución de controles de la plantilla histórica.
- `config/reporte-datos-sector-telecomunicaciones.xlsx`: catálogo de enlaces.
- `entrada/datos_bit/`: caché local de las seis fuentes.
- `plantilla/Plantilla_Reporte_Telecom_Automatizable.docx`: diseño Word original automatizado.
- `ejemplo/Reporte_Telecomunicaciones_2024Q1_vBIT.docx`: salida con concesionarios desglosados y títulos corregidos.
- `tests/prueba_motor.R`: prueba local de cobertura, conciliación, filas variables y datos parciales.
- `tests/benchmark_lectura.R`: cronometra una primera y una segunda lectura de las seis fuentes y verifica el uso de la caché procesada.
- `tests/prueba_integracion_python.R`: prueba de la invocación de Python desde R.
- `tests/prueba_graficas_python.py`: prueba de las seis geometrías y dimensiones PNG.

## Criterio de comparación

Las cifras nuevas se calculan siempre desde los CSV vigentes del BIT. Por ello pueden diferir del Word histórico debido a correcciones posteriores, reclasificaciones, filas duplicadas o cambios en la integración de grupos. `control_ejecucion.csv` conserva los totales procesados y la huella MD5 de cada fuente para que la comparación sea reproducible.

## Autoría

Proyecto desarrollado para la Dirección Ejecutiva de Indicadores (DEI).

- Gustavo Ivan Garcia Quiroz
- Actualizaciones y despliegue: Equipo de la Dirección Ejecutiva de Indicadores

Contacto: <gustavo.garcia@crt.gob.mx>
