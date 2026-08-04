# Reporte de datos del sector de telecomunicaciones — v1.2.1

Aplicación en R que genera obligatoriamente el reporte Word, seis gráficas PNG, seis copias CSV y un control de ejecución. Google Drive y Google Sheets son salidas adicionales y opcionales para cuentas personales.

El Excel incluido contiene datos ficticios del primer trimestre de 2026. La plantilla Word y el diseño de las gráficas conservan la versión previamente validada.

## Correcciones de v1.2.1

- La renovación de Google ignora el token anterior y solicita explícitamente permisos de Drive y Sheets.
- La conexión comprueba acceso real a Drive antes de marcar la cuenta como autorizada.
- La consola de la interfaz lee el registro como UTF-8 para mostrar correctamente los acentos en Windows.
- Las gráficas usan la familia portátil `sans`, que corresponde a Arial en Windows, para evitar la advertencia de fuente sin cambiar su diseño.

## Uso normal

1. Instale R 4.3 o superior.
2. Abra una terminal en esta carpeta.
3. Ejecute:

~~~bash
Rscript main.R
~~~

También puede iniciar desde RStudio:

~~~r
source("main.R")
~~~

El programa instala los paquetes faltantes y abre una interfaz local. No necesita un archivo .bat.

## Generación obligatoria del Word

Google está desactivado inicialmente. Para crear el reporte:

1. Seleccione el Excel del trimestre o deje el campo vacío para usar el Excel ficticio incluido.
2. Confirme la carpeta local de resultados.
3. Presione **Generar reporte**.

Cada ejecución crea una carpeta dentro de salidas/ con:

- Reporte_Telecomunicaciones_...docx.
- monitoreo/grafica_1.png a grafica_6.png.
- monitoreo/tabla_1.csv a tabla_6.csv.
- control_ejecucion.csv.
- ejecucion.log.

La generación local ocurre antes que Google. Un problema de red, permisos o autenticación no invalida el Word.

## Google personal opcional

La versión 1.2.1 utiliza OAuth personal. No usa cuentas de servicio, unidades compartidas ni llaves JSON.

Primera conexión:

1. Abra **Ajustes avanzados**.
2. Active **Guardar también en Google Drive / Sheets**.
3. Puede escribir su correo de Google o dejarlo vacío para elegirlo en el navegador.
4. Presione **Conectar o renovar permisos**.
5. Inicie sesión en Google y acepte los permisos de Drive y Sheets.
6. Confirme que la interfaz muestre **Cuenta conectada**.
7. Indique el nombre de la carpeta o su ID.
8. Presione **Generar reporte**.

El permiso se guarda en la caché personal de R, normalmente debajo de ~/.R/gargle/gargle-oauth, fuera de este proyecto. Las ejecuciones posteriores reutilizan el token. Cada programador debe autorizar su propia cuenta. Si Google informa `Insufficient Permission`, vuelva a pulsar **Conectar o renovar permisos** y acepte la nueva solicitud.

Si la carpeta indicada no existe, el programa la crea en Mi unidad. Si existen varias carpetas con el mismo nombre, debe indicarse el ID para evitar ambigüedad. El ID es el texto de la URL situado después de /folders/.

Cuando Google está activo, cada ejecución:

- Crea una subcarpeta identificada por periodo, versión y fecha.
- Puede subir Excel, Word, PNG, CSV y registros.
- Puede crear un Google Sheet con Control y Tabla_1 a Tabla_6.
- Guarda enlaces_google.txt en la salida local.

## Si no abre la autorización

Ejecute una vez en la consola interactiva de RStudio:

~~~r
install.packages(c("googledrive", "googlesheets4"))
alcances <- c(
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/spreadsheets"
)
googledrive::drive_auth(email = NA, scopes = alcances, cache = TRUE)
googlesheets4::gs4_auth(token = googledrive::drive_token())
googledrive::drive_find(n_max = 1)
~~~

Después vuelva a iniciar main.R. Este paso solo es necesario si el navegador no se abre desde la interfaz.

## Ajustes disponibles

| Ajuste | Valor inicial | Uso |
| --- | --- | --- |
| Excel | entrada/Entrada_Reporte_Telecom_PRUEBA.xlsx | Archivo ficticio usado si no se selecciona otro. |
| Plantilla Word | plantilla/Plantilla_Reporte_Telecom_Automatizable.docx | Mantiene tablas, textos y posiciones. |
| Carpeta local | salidas/ | Crea una subcarpeta nueva por ejecución. |
| Google | Desactivado | Respaldo personal opcional. |
| Cuenta Google | Vacía | Permite elegir la cuenta en el navegador. |
| Carpeta de Drive | Reporte_de_Datos_del_Sector_de_Telecomunicaciones | Se busca o se crea en Mi unidad. |
| ID de carpeta | Vacío | Recomendado si hay nombres repetidos. |
| Subir archivos | Activado | Sube Word y archivos de monitoreo cuando Google está activo. |
| Crear Sheets | Activado | Crea Control y Tabla_1 a Tabla_6 cuando Google está activo. |

## Modo automático

Sin interfaz:

~~~bash
Rscript main.R --automatico
~~~

Con rutas personalizadas:

~~~bash
Rscript main.R --automatico "ruta/datos.xlsx" "ruta/plantilla.docx" "ruta/salidas"
~~~

Google en modo automático requiere que la cuenta haya sido autorizada previamente. Puede configurarse con:

- GOOGLE_ENABLED
- GOOGLE_USER_EMAIL
- GOOGLE_DRIVE_FOLDER_NAME
- GOOGLE_DRIVE_FOLDER_ID
- GOOGLE_UPLOAD_FILES
- GOOGLE_CREATE_SHEETS

Los valores lógicos aceptan true o false.

## Archivos esenciales

- main.R: único punto de entrada.
- app.R: interfaz y autorización OAuth personal.
- generar_reporte.R: validación, gráficas y actualización del Word.
- google_api.R: Drive y Sheets opcionales.
- entrada/: Excel ficticio predeterminado.
- plantilla/: plantilla Word automatizable.
- salidas/: resultados locales.

## Lista de verificación para la entrega

- Ejecutar primero con Google desactivado.
- Abrir el Word y revisar sus 19 páginas.
- Confirmar seis PNG y seis CSV.
- Como demostración adicional, conectar una cuenta personal y ejecutar Google.
- Confirmar la carpeta creada en Mi unidad.
- Confirmar que el Sheet tenga Control y Tabla_1 a Tabla_6.
- No entregar la caché OAuth ni ningún archivo de credenciales.
