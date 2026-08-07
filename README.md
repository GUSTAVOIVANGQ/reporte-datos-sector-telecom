# Reporte de Datos del Sector de Telecomunicaciones — v3.0.0

Aplicación en R que descarga, valida y procesa seis fuentes del Banco de Información de Telecomunicaciones (BIT) para generar el reporte Word del año seleccionado.

## Periodicidad

Sí: el documento de referencia es **trimestral**. Al seleccionar un año, el programa puede generar Q1, Q2, Q3 y Q4.

- En las cinco fuentes mensuales toma el cierre de marzo, junio, septiembre y diciembre.
- En ingresos toma `TRIM = 1, 2, 3, 4` y conserva únicamente `I_ANUAL_TRIM = Trimestral`.
- Un trimestre se genera solo cuando las seis secciones contienen el cierre requerido.
- La opción `todos` produce únicamente los trimestres comunes completos y documenta los faltantes.

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

2025 no tiene todavía cobertura común en las copias incluidas: telefonía fija solo contiene Q1 e internet fijo no contiene 2025. Las demás fuentes sí llegan a Q4. Esta condición no está codificada de forma permanente: cada ejecución vuelve a leer los CSV y, si se permite acceso a red, intenta actualizarlos desde el BIT.

Algunas filas oficiales de 2024 tienen el total vacío. Para no perder todo el trimestre, el motor las trata como cero y las registra en `diagnostico_fuentes.csv`, `control_ejecucion.csv` y `advertencias.txt`. No se oculta esta imputación.

## Descarga y caché

Para cada una de las seis fuentes:

1. Busca el nombre canónico en `entrada/datos_bit/`.
2. Si no existe, descarga el enlace del catálogo.
3. Antes de sustituir la caché, comprueba que el archivo descargado sea un CSV legible y tenga el esquema requerido.
4. Si el archivo existe pero no contiene el año/trimestre solicitado, intenta una actualización una vez.
5. Si la red falla y hay una copia local válida, conserva esa copia y emite una advertencia.
6. Si no existe una copia válida, detiene el proceso con un mensaje explícito.

La opción **Forzar actualización** descarga las seis fuentes antes de procesar. La opción **sin red** permite una ejecución totalmente local y reproducible.

## Validaciones

| Comprobación | Acción |
|---|---|
| Archivo inexistente | Descarga automática si la red está permitida |
| Descarga corrupta o esquema incompleto | No reemplaza una caché válida; informa el error |
| Año sin observaciones | Estado `Ausente`; no genera ese trimestre |
| Año con algunos cierres | Estado `Parcial`; genera solo trimestres comunes |
| Cierre trimestral ausente en una sección | Omite ese trimestre en modo `todos`; bloquea una solicitud individual |
| Total vacío/no numérico en una fila publicada | Imputa cero, cuenta la incidencia y advierte |
| Valor negativo en ingresos | Lo conserva como ajuste posterior y lo registra |
| Valor negativo en líneas o accesos | Detiene ese trimestre |
| Fila exactamente duplicada | La conserva como está publicada y registra el conteo |
| Totales de tabla y de grupo | Deben conciliar antes de modificar el Word |
| Estructura del Word | Verifica las seis tablas, campos, imágenes y estructura interna del DOCX |

Estas reglas permiten comparar después las cifras del BIT con el reporte histórico sin borrar ajustes posteriores de los operadores.

## Requisitos

- R 4.1 o superior.
- Windows, macOS o Linux.
- Internet únicamente para instalar paquetes y descargar/actualizar fuentes.
- Paquetes: `readxl`, `xml2`, `zip` y `shiny`.

Los paquetes faltantes se instalan automáticamente desde CRAN.

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

Generar todos los trimestres completos de 2024 con la caché incluida:

```bash
Rscript main.R --automatico --anio=2024 --trimestre=todos --sin-red
```

Generar solo Q4 y actualizar las fuentes si hace falta:

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
  --salidas="ruta/salidas"
```

Ayuda y prueba rápida:

```bash
Rscript main.R --ayuda
Rscript tests/prueba_motor.R
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
        └── grafica_1.png ... grafica_6.png
```

El ZIP anual incluye los Word y los tres archivos CSV de control. Si se solicita un solo trimestre, el entregable principal es el DOCX individual y los controles permanecen en la carpeta de ejecución.

## Archivos principales

- `main.R`: interfaz o línea de comandos.
- `app.R`: interfaz Shiny.
- `fuentes_bit.R`: catálogo, descarga, codificación, cobertura, validación y agregación.
- `generar_reporte.R`: orquestación anual, gráficas, Word y controles.
- `motor_word_plantilla.R`: sustitución de controles de contenido en la plantilla histórica.
- `config/reporte-datos-sector-telecomunicaciones.xlsx`: catálogo de enlaces.
- `entrada/datos_bit/`: caché local de las seis fuentes.
- `plantilla/Plantilla_Reporte_Telecom_Automatizable.docx`: diseño Word original automatizado.
- `ejemplo/Reporte_Telecomunicaciones_2024Q4_vBIT.docx`: salida de referencia verificada visualmente.
- `tests/prueba_motor.R`: prueba local de cobertura y conciliación.

## Criterio de comparación

Las cifras nuevas se calculan siempre desde los CSV vigentes del BIT. Por ello pueden diferir del Word histórico debido a correcciones posteriores, reclasificaciones, filas duplicadas o cambios en la integración de grupos. `control_ejecucion.csv` conserva los totales procesados y la huella MD5 de cada fuente para que la comparación sea reproducible.

## Autoría

Proyecto desarrollado para la Dirección Ejecutiva de Indicadores (DEI).

- Gustavo Ivan Garcia Quiroz
- Actualizaciones y despliegue: Equipo de la Dirección Ejecutiva de Indicadores

Contacto: <gustavo.garcia@crt.gob.mx>
