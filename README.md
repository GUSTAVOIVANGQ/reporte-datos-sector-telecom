# Reporte de datos del sector de telecomunicaciones — v1.1.0

Aplicación en R que genera el reporte Word, seis gráficas PNG, seis copias CSV, un control de ejecución y, de forma opcional, un respaldo en Google Drive con una copia de las tablas en Google Sheets.

El Excel incluido contiene datos ficticios del primer trimestre de 2026. La plantilla Word y el diseño de las gráficas conservan la versión previamente validada.

## Uso normal

1. Instale R 4.3 o superior.
2. Abra una terminal en esta carpeta.
3. Ejecute una sola línea:

~~~bash
Rscript main.R
~~~

El programa instala los paquetes faltantes y abre una interfaz local en el navegador. No necesita un archivo .bat.

En la pantalla:

- Seleccione el Excel del trimestre o deje el campo vacío para usar el Excel ficticio incluido.
- Confirme la carpeta local de resultados.
- Abra **Ajustes avanzados** únicamente si necesita cambiar la plantilla o la configuración de Google.
- Presione **Generar reporte**.

La interfaz muestra el estado, el registro de la ejecución y permite descargar el último Word.

## Ajustes disponibles

| Ajuste | Valor inicial | Uso |
| --- | --- | --- |
| Excel | entrada/Entrada_Reporte_Telecom_PRUEBA.xlsx | Se usa cuando el usuario no selecciona otro archivo. |
| Plantilla Word | plantilla/Plantilla_Reporte_Telecom_Automatizable.docx | Mantiene estructura, tablas, textos y posiciones. |
| Carpeta local | salidas/ | Crea una subcarpeta nueva por ejecución. |
| Google | Activado en la interfaz | Puede desactivarse sin afectar la generación local. |
| Llave JSON | C:\Users\gustavo.garcia\Documents\GitHub\reporte-datos-sector-telecom\animated-radar-504520-c3-279497a6262f.json | Puede escribirse la ruta o seleccionar otro JSON; el archivo no se copia al proyecto. |
| Carpeta de Drive | Reporte_de_Datos_del_Sector_de_Telecomunicaciones | Se busca por nombre exacto. |
| ID de carpeta | Vacío | Si hay nombres repetidos, el ID identifica la carpeta sin ambigüedad. |
| Subir archivos | Activado | Sube Excel, Word, PNG, CSV y registros. |
| Crear Sheets | Activado | Crea Control y Tabla_1 a Tabla_6. |

## Resultados

Cada ejecución crea salidas/AAAAQN_version_fecha/ con:

- Reporte_Telecomunicaciones_...docx.
- monitoreo/grafica_1.png a grafica_6.png.
- monitoreo/tabla_1.csv a tabla_6.csv.
- control_ejecucion.csv.
- ejecucion.log.
- enlaces_google.txt, únicamente cuando Google responde correctamente.

La generación local ocurre primero. Si Google está desactivado, no está configurado o presenta un error, el Word y los archivos locales se conservan; el problema queda registrado como advertencia.

## Google Drive y Sheets

La integración usa una cuenta de servicio, por lo que no solicita la cuenta personal del usuario.

Configuración necesaria:

1. Active **Google Drive API** y **Google Sheets API** en el proyecto de Google Cloud.
2. Conserve la llave JSON fuera del repositorio y del ZIP.
3. En Google Workspace, cree o elija una carpeta dentro de una **unidad compartida**.
4. Agregue como miembro de la unidad compartida el correo client_email de la cuenta de servicio y otorgue permiso para agregar archivos.
5. Use en la interfaz el nombre exacto de la carpeta o, de preferencia, su ID.

Si la búsqueda por nombre encuentra más de una carpeta, el programa no adivina: solicita configurar el ID. El ID es el texto de la URL situado después de /folders/.

El libro creado en cada ejecución contiene:

- Control: etapas, estado, fecha y detalle.
- Tabla_1 a Tabla_6: copias de monitoreo de las tablas procesadas.

## Modo automático para otro programador

Sin abrir la interfaz:

~~~bash
Rscript main.R --automatico
~~~

Con rutas personalizadas:

~~~bash
Rscript main.R --automatico "ruta/datos.xlsx" "ruta/plantilla.docx" "ruta/salidas"
~~~

Las opciones de Google también pueden definirse como variables de entorno:

- GOOGLE_ENABLED
- GOOGLE_APPLICATION_CREDENTIALS
- GOOGLE_DRIVE_FOLDER_NAME
- GOOGLE_DRIVE_FOLDER_ID
- GOOGLE_UPLOAD_FILES
- GOOGLE_CREATE_SHEETS

Los valores lógicos aceptan true o false.

## Archivos esenciales

- main.R: único punto de entrada y selección entre interfaz/modo automático.
- app.R: interfaz local.
- generar_reporte.R: validación, gráficas y actualización del Word.
- google_api.R: Drive y Sheets opcionales.
- entrada/: Excel ficticio predeterminado.
- plantilla/: plantilla Word automatizable.
- salidas/: resultados locales.

## Lista de verificación para la entrega

- Ejecutar Rscript main.R en la computadora de demostración.
- Generar una vez con el Excel ficticio.
- Abrir el Word y revisar las 19 páginas.
- Confirmar seis PNG y seis CSV.
- Si se demostrará Google, comprobar previamente que la cuenta de servicio vea la carpeta compartida.
- Verificar que el Sheet tenga siete pestañas: Control y Tabla_1 a Tabla_6.
- No entregar ni publicar la llave JSON.
