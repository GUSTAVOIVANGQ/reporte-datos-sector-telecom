# Reporte de datos del sector de telecomunicaciones — v1.3.0

Aplicación en R para generar el reporte Word y respaldar automáticamente la ejecución en Google Drive y Google Sheets.

El Word local es el resultado obligatorio. Si Google no está disponible, el reporte, las gráficas, las tablas y los controles locales permanecen completos.

## Contenido

- [Flujo general](#flujo-general)
- [Requisitos](#requisitos)
- [Ejecutar](#ejecutar)
- [Interfaz](#interfaz)
- [Capturas](#capturas)
- [Drive y Sheets automáticos](#drive-y-sheets-automáticos)
- [Información mostrada en terminal](#información-mostrada-en-terminal)
- [Resultados locales](#resultados-locales)
- [Modo automático](#modo-automático)
- [Archivos esenciales](#archivos-esenciales)
- [Historial de cambios](#historial-de-cambios)
- [Autor](#autor)

## Flujo general

```mermaid
flowchart TD
    A["Abrir programa"] --> B{"¿Seleccionó Excel?"}
    B -- No --> C["Usar Excel 2026Q1 de prueba"]
    B -- Sí --> D["Usar Excel seleccionado"]
    C --> E["Validar y generar"]
    D --> E
    E --> F["Guardar todo localmente"]
    F --> G{"¿Drive disponible?"}
    G -- Sí --> H["Subir resultados"]
    G -- No --> I["Continuar solo local"]
    H --> J["Mostrar resultado"]
    I --> J
```

## Requisitos

- R 4.1 o superior.
- Windows, macOS o Linux (el programa detecta el sistema operativo automáticamente, por ejemplo para abrir la carpeta de resultados).
- Conexión a internet: para instalar paquetes la primera vez y para usar Drive/Sheets.
- Paquetes de R: `shiny`, `readxl`, `xml2` y `zip` (se instalan automáticamente si faltan); `googledrive` y `googlesheets4` solo si se usa el respaldo en Google.
- Cuenta personal de Google, únicamente si se quiere el respaldo automático en Drive y Sheets. No es necesaria para generar el Word local.

## Ejecutar

Desde una terminal abierta en la carpeta del proyecto:

~~~bash
Rscript main.R
~~~

Desde RStudio:

~~~r
source("main.R")
~~~

Los paquetes faltantes se instalan automáticamente.

## Interfaz

La interfaz solo contiene:

- Excel de entrada. Si no se selecciona, utiliza el Excel ficticio incluido.
- Carpeta local de salida.
- Cuenta personal de Google.
- Botón **Generar reporte**.
- Botón **Descargar Word**.
- Botón **Abrir carpeta**.

El registro detallado no aparece en la interfaz; se muestra en la terminal o consola de RStudio.

## Capturas

**Interfaz**

![Interfaz de la aplicación](screenshots/interface.png)

**Reporte generado (Word)**

![Página 1 del reporte generado](screenshots/report_one.png)
![Página 2 del reporte generado](screenshots/report_two.png)

## Drive y Sheets automáticos

Al generar, el programa solicita o reutiliza la autorización de la cuenta indicada y usa estos valores fijos:

| Configuración | Valor automático |
| --- | --- |
| Carpeta principal | `Reporte_de_Datos_del_Sector_de_Telecomunicaciones` |
| Subcarpeta | Periodo, versión, fecha y hora de la ejecución |
| Subida a Drive | Excel, Word, PNG, CSV y controles |
| Google Sheets | `Control` y `Tabla_1` a `Tabla_6` |

Si la carpeta principal no existe, se crea en Mi unidad. La interfaz no pregunta nombre de carpeta, ID, tipos de archivo ni pestañas.

La primera ejecución puede abrir el navegador para seleccionar la cuenta y aceptar permisos. Si un token anterior tiene permisos insuficientes, el programa intenta renovarlo automáticamente.

No se utiliza una cuenta de servicio ni una llave JSON. La autorización OAuth se guarda en la caché personal de R y no debe incluirse al entregar el proyecto.

## Información mostrada en terminal

La terminal registra de forma descriptiva:

- Validación del Excel y conciliación de totales.
- Creación de tablas CSV y gráficas PNG.
- Creación y validación del Word.
- Cuenta autorizada y carpeta de Drive utilizada.
- Cantidad de archivos subidos y pestañas creadas.
- Advertencias, duración local y duración total.
- Ruta del Excel local, Word y carpeta local.
- Enlace del Excel y Word en Drive.
- Enlace de la carpeta de Drive.
- Enlace del Google Sheet.

Los mismos registros se conservan en `ejecucion.log`, `control_ejecucion.csv` y `enlaces_google.txt` dentro de la carpeta de cada ejecución.

## Resultados locales

Cada ejecución crea una carpeta nueva dentro de `salidas/` con:

- `Reporte_Telecomunicaciones_...docx`.
- `monitoreo/grafica_1.png` a `grafica_6.png`.
- `monitoreo/tabla_1.csv` a `tabla_6.csv`.
- `control_ejecucion.csv`.
- `ejecucion.log`.
- `enlaces_google.txt`, cuando Google termina correctamente.

## Modo automático

Sin interfaz y usando los archivos incluidos:

~~~bash
Rscript main.R --automatico
~~~

Con rutas personalizadas:

~~~bash
Rscript main.R --automatico "ruta/datos.xlsx" "ruta/plantilla.docx" "ruta/salidas"
~~~

En modo automático, Google reutiliza una cuenta previamente autorizada. Para desactivarlo en una ejecución técnica puede definirse `GOOGLE_ENABLED=false`.

## Archivos esenciales

- `main.R`: único punto de entrada.
- `app.R`: interfaz mínima y autorización personal.
- `generar_reporte.R`: validación, gráficas y Word.
- `google_api.R`: respaldo automático en Drive y Sheets.
- `entrada/`: Excel ficticio predeterminado.
- `plantilla/`: plantilla Word automatizable.
- `salidas/`: resultados de cada ejecución.
- `screenshots/`: capturas usadas en este README.

## Historial de cambios

El detalle de cada versión está en [CHANGELOG.md](CHANGELOG.md).

## Autor

Proyecto desarrollado para:

- Dirección Ejecutiva de Indicadores (DEI)

Desarrolladores:

- Gustavo Ivan Garcia Quiroz
- Actualizaciones y despliegue en Linux: Equipo de la Dirección Ejecutiva de Indicadores

Contacto: [gustavo.garcia@crt.gob.mx](mailto:gustavo.garcia@crt.gob.mx)