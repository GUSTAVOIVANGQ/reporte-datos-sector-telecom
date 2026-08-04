# Interfaz local. Se inicia únicamente desde main.R.
raiz <- getOption("reporte.raiz", getwd())
options(shiny.maxRequestSize = 50 * 1024^2)
excel_prueba <- file.path(raiz, "entrada", "Entrada_Reporte_Telecom_PRUEBA.xlsx")
plantilla_defecto <- file.path(raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
salidas_defecto <- file.path(raiz, "salidas")
alcances_google <- c(
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/spreadsheets"
)

valor_logico <- function(nombre, defecto = TRUE) {
  valor <- tolower(trimws(Sys.getenv(nombre, if (defecto) "true" else "false")))
  valor %in% c("1", "true", "si", "sí", "yes")
}

autenticar_google_personal <- function(correo = "", forzar = FALSE) {
  if (!exists("asegurar_paquetes", mode = "function") ||
      !asegurar_paquetes(c("googledrive", "googlesheets4"), obligatorios = FALSE)) {
    stop("No fue posible instalar los paquetes necesarios para Google")
  }
  opciones_previas <- options(
    rlang_interactive = TRUE,
    gargle_oauth_cache = TRUE,
    googledrive_quiet = TRUE,
    googlesheets4_quiet = TRUE
  )
  on.exit(options(opciones_previas), add = TRUE)

  correo <- trimws(correo)
  if (isTRUE(forzar)) {
    googlesheets4::gs4_deauth()
    googledrive::drive_deauth()
  }
  objetivo <- if (isTRUE(forzar)) NA else if (nzchar(correo)) correo else TRUE
  googledrive::drive_auth(
    email = objetivo, scopes = alcances_google, cache = TRUE
  )
  googlesheets4::gs4_auth(token = googledrive::drive_token())
  googledrive::drive_find(n_max = 1)
  usuario <- googledrive::drive_user()
  if (is.null(usuario$emailAddress) || !nzchar(usuario$emailAddress)) {
    stop("Google no devolvió el correo de la cuenta autorizada")
  }
  usuario$emailAddress
}

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$title("Generador del reporte de telecomunicaciones"),
    shiny::tags$style(shiny::HTML("
      :root { --tinta:#173f43; --verde:#008f98; --claro:#e8f4f4; --acento:#f09a55; }
      body { background:linear-gradient(135deg,#f7fbfb 0%,#e3f0f1 100%); color:var(--tinta);
             font-family:'Segoe UI',Arial,sans-serif; min-height:100vh; }
      .container-fluid { max-width:1120px; padding:32px 24px 48px; }
      .hero { background:linear-gradient(120deg,#123d42,#086c74); color:white; border-radius:22px;
              padding:30px 34px; box-shadow:0 18px 45px rgba(18,61,66,.18); margin-bottom:22px; }
      .hero h1 { margin:0 0 8px; font-size:30px; font-weight:700; }
      .hero p { margin:0; opacity:.88; font-size:16px; }
      .card { background:white; border:1px solid rgba(23,63,67,.08); border-radius:18px;
              padding:25px; box-shadow:0 10px 28px rgba(23,63,67,.09); margin-bottom:20px; }
      .card h3 { margin-top:0; font-weight:700; font-size:19px; }
      .help-block { color:#5e7779; }
      .form-control { border-radius:10px; border-color:#bdd2d3; min-height:42px; }
      .form-control:focus { border-color:var(--verde); box-shadow:0 0 0 3px rgba(0,143,152,.14); }
      .btn-run { width:100%; background:var(--verde); border:0; border-radius:12px; color:white;
                 padding:13px 20px; font-size:16px; font-weight:700; box-shadow:0 9px 20px rgba(0,143,152,.24); }
      .btn-run:hover,.btn-run:focus { background:#007780; color:white; }
      details { border-top:1px solid #dfebec; margin-top:18px; padding-top:16px; }
      summary { cursor:pointer; font-weight:700; color:#22676d; margin-bottom:16px; }
      .status-box { background:#f4f9f9; border-left:5px solid var(--verde); border-radius:10px;
                    padding:16px 18px; white-space:pre-wrap; overflow-wrap:anywhere; }
      .console { background:#102f33; color:#d8f1ef; border-radius:12px; padding:16px;
                 min-height:110px; max-height:300px; overflow:auto; white-space:pre-wrap;
                 font-family:Consolas,monospace; font-size:12px; }
      .console pre { background:transparent; color:inherit; border:0; margin:0; padding:0;
                     white-space:pre-wrap; font:inherit; }
      .google-status { background:#f1f8f8; border-radius:10px; padding:10px 12px;
                       margin:8px 0 14px; font-size:13px; }
      .btn-google { border-color:#58aeb3; color:#176067; border-radius:10px; margin-bottom:8px; }
      .btn-google:hover,.btn-google:focus { background:#e3f3f3; color:#0c565c; }
      .pill { display:inline-block; background:#d8efef; color:#176067; border-radius:99px;
              padding:5px 11px; font-size:12px; font-weight:700; margin-bottom:12px; }
      @media (max-width:767px) { .container-fluid { padding:16px 12px 30px; } .hero { padding:24px; }
                                 .hero h1 { font-size:24px; } }
    "))
  ),
  shiny::div(class = "hero",
    shiny::span(class = "pill", "REPORTE AUTOMATIZADO"),
    shiny::h1("Datos del sector de telecomunicaciones"),
    shiny::p("Genera Word, gráficas, tablas de monitoreo y, si lo deseas, una copia en Google.")
  ),
  shiny::fluidRow(
    shiny::column(7,
      shiny::div(class = "card",
        shiny::h3("1. Datos y salida"),
        shiny::fileInput(
          "excel", "Excel del trimestre (.xlsx)", accept = ".xlsx",
          buttonLabel = "Seleccionar", placeholder = "Se usará el Excel de prueba"
        ),
        shiny::textInput("carpeta_salida", "Carpeta local de resultados", value = salidas_defecto),
        shiny::helpText("Si no seleccionas un Excel, el programa utiliza automáticamente el archivo ficticio incluido."),
        shiny::tags$details(
          shiny::tags$summary("Ajustes avanzados"),
          shiny::textInput("plantilla", "Plantilla Word", value = plantilla_defecto),
          shiny::checkboxInput(
            "usar_google", "Guardar también en Google Drive / Sheets",
            value = valor_logico("GOOGLE_ENABLED", FALSE)
          ),
          shiny::conditionalPanel(
            "input.usar_google",
            shiny::textInput(
              "google_email", "Cuenta personal de Google (opcional)",
              value = Sys.getenv("GOOGLE_USER_EMAIL", ""),
              placeholder = "nombre@gmail.com"
            ),
            shiny::actionButton(
              "conectar_google", "Conectar o renovar permisos",
              class = "btn-google", icon = shiny::icon("link")
            ),
            shiny::uiOutput("estado_google"),
            shiny::textInput(
              "carpeta_google", "Nombre exacto de la carpeta de Drive",
              value = Sys.getenv(
                "GOOGLE_DRIVE_FOLDER_NAME",
                "Reporte_de_Datos_del_Sector_de_Telecomunicaciones"
              )
            ),
            shiny::textInput(
              "carpeta_google_id", "ID de carpeta (opcional y preferible si hay nombres repetidos)",
              value = Sys.getenv("GOOGLE_DRIVE_FOLDER_ID", "")
            ),
            shiny::checkboxInput(
              "subir_archivos", "Subir Excel, Word, PNG, CSV y logs",
              value = valor_logico("GOOGLE_UPLOAD_FILES", TRUE)
            ),
            shiny::checkboxInput(
              "crear_sheets", "Crear un Google Sheet con Control y Tabla_1 a Tabla_6",
              value = valor_logico("GOOGLE_CREATE_SHEETS", TRUE)
            ),
            shiny::helpText(
              "La conexión abre Google y solicita permisos de Drive y Sheets. Úsala también para renovar un permiso insuficiente; no se necesita una llave JSON."
            )
          )
        ),
        shiny::actionButton("generar", "Generar reporte", class = "btn-run", icon = shiny::icon("play"))
      )
    ),
    shiny::column(5,
      shiny::div(class = "card",
        shiny::h3("2. Estado"),
        shiny::uiOutput("estado"),
        shiny::br(),
        shiny::downloadButton("descargar_word", "Descargar último Word", class = "btn-default")
      ),
      shiny::div(class = "card",
        shiny::h3("Registro de esta ejecución"),
        shiny::div(class = "console", shiny::verbatimTextOutput("consola", placeholder = TRUE))
      )
    )
  )
)

server <- function(input, output, session) {
  resultado <- shiny::reactiveVal(list(
    tipo = "listo", mensaje = "Listo para generar. Revisa los campos y presiona el botón.",
    consola = "Aún no se ha ejecutado el programa.", word = NULL
  ))
  cuenta_google <- shiny::reactiveVal("")
  conexion_google <- shiny::reactiveVal(list(
    tipo = "listo", texto = "Google no conectado. Esta salida es opcional."
  ))

  output$estado <- shiny::renderUI({
    x <- resultado()
    color <- if (identical(x$tipo, "error")) {
      "#b54a4a"
    } else if (identical(x$tipo, "ok")) {
      "#168160"
    } else if (identical(x$tipo, "advertencia")) {
      "#d17d22"
    } else {
      "#008f98"
    }
    shiny::div(class = "status-box", style = paste0("border-left-color:", color, ";"), x$mensaje)
  })
  output$consola <- shiny::renderText(resultado()$consola)
  output$estado_google <- shiny::renderUI({
    x <- conexion_google()
    color <- if (identical(x$tipo, "ok")) {
      "#168160"
    } else if (identical(x$tipo, "error")) {
      "#b54a4a"
    } else {
      "#5e7779"
    }
    shiny::div(class = "google-status", style = paste0("color:", color, ";"), x$texto)
  })

  shiny::observeEvent(input$conectar_google, {
    conexion_google(list(tipo = "listo", texto = "Abriendo la autorización de Google…"))
    shiny::withProgress(message = "Conectando con Google", value = 0.25, {
      respuesta <- tryCatch(
        list(ok = TRUE, correo = autenticar_google_personal(input$google_email, forzar = TRUE)),
        error = function(e) list(ok = FALSE, mensaje = conditionMessage(e))
      )
      shiny::incProgress(0.75)
      if (isTRUE(respuesta$ok)) {
        cuenta_google(respuesta$correo)
        shiny::updateTextInput(session, "google_email", value = respuesta$correo)
        conexion_google(list(
          tipo = "ok", texto = paste("Cuenta conectada:", respuesta$correo)
        ))
      } else {
        cuenta_google("")
        conexion_google(list(
          tipo = "error",
          texto = paste(
            "No fue posible conectar. Vuelve a pulsar Conectar o renovar permisos:",
            respuesta$mensaje
          )
        ))
      }
    })
  })

  shiny::observeEvent(input$generar, {
    excel <- if (!is.null(input$excel)) input$excel$datapath else excel_prueba
    plantilla <- trimws(input$plantilla)
    salidas <- trimws(input$carpeta_salida)
    errores <- character()
    if (!file.exists(excel)) errores <- c(errores, "No se encontró el Excel.")
    if (!file.exists(plantilla)) errores <- c(errores, "No se encontró la plantilla Word.")
    if (!nzchar(salidas)) errores <- c(errores, "Indica una carpeta de salida.")
    if (length(errores)) {
      resultado(list(
        tipo = "error", mensaje = paste(errores, collapse = "\n"),
        consola = "No se inició la ejecución porque hay ajustes pendientes.", word = NULL
      ))
      return(invisible(NULL))
    }

    dir.create(salidas, recursive = TRUE, showWarnings = FALSE)
    resultado(list(tipo = "proceso", mensaje = "Generando el reporte…", consola = "Proceso iniciado.", word = NULL))

    shiny::withProgress(message = "Generando reporte", value = 0.15, {
      correo_google <- trimws(input$google_email)
      if (isTRUE(input$usar_google)) {
        correo_guardado <- cuenta_google()
        if (nzchar(correo_guardado) &&
            (!nzchar(correo_google) || identical(correo_google, correo_guardado))) {
          correo_google <- correo_guardado
        } else {
          forzar_inicial <- !nzchar(correo_google)
          autenticacion <- tryCatch(
            list(
              ok = TRUE,
              correo = autenticar_google_personal(
                correo_google, forzar = forzar_inicial
              )
            ),
            error = function(e) list(ok = FALSE, mensaje = conditionMessage(e))
          )
          if (!isTRUE(autenticacion$ok) && !forzar_inicial) {
            autenticacion <- tryCatch(
              list(
                ok = TRUE,
                correo = autenticar_google_personal(correo_google, forzar = TRUE)
              ),
              error = function(e) list(ok = FALSE, mensaje = conditionMessage(e))
            )
          }
          if (isTRUE(autenticacion$ok)) {
            correo_google <- autenticacion$correo
            cuenta_google(correo_google)
            shiny::updateTextInput(session, "google_email", value = correo_google)
            conexion_google(list(
              tipo = "ok", texto = paste("Cuenta conectada:", correo_google)
            ))
          } else {
            conexion_google(list(
              tipo = "error",
              texto = paste(
                "Google no se conectó; el Word continuará:",
                autenticacion$mensaje
              )
            ))
          }
        }
      }

      rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
      argumentos <- c(
        shQuote(file.path(raiz, "main.R")), "--automatico",
        shQuote(excel), shQuote(plantilla), shQuote(salidas),
        shQuote(paste0("--google-enabled=", tolower(as.character(input$usar_google)))),
        shQuote(paste0("--google-email=", correo_google)),
        shQuote(paste0("--google-folder-name=", trimws(input$carpeta_google))),
        shQuote(paste0("--google-folder-id=", trimws(input$carpeta_google_id))),
        shQuote(paste0("--google-upload-files=", tolower(as.character(input$subir_archivos)))),
        shQuote(paste0("--google-create-sheets=", tolower(as.character(input$crear_sheets))))
      )
      archivo_consola <- tempfile("reporte_consola_", fileext = ".log")
      ejecucion <- tryCatch(
        list(
          codigo = system2(
            rscript, args = argumentos,
            stdout = archivo_consola, stderr = archivo_consola
          ),
          error = NULL
        ),
        error = function(e) list(codigo = 1L, error = conditionMessage(e))
      )
      shiny::incProgress(0.75)
      salida <- if (file.exists(archivo_consola)) {
        readLines(archivo_consola, encoding = "UTF-8", warn = FALSE)
      } else {
        character()
      }
      unlink(archivo_consola)
      if (!is.null(ejecucion$error)) {
        salida <- c(salida, paste("ERROR:", ejecucion$error))
      }
      codigo <- ejecucion$codigo
      if (is.null(codigo)) codigo <- 0L
      texto <- paste(salida, collapse = "\n")

      carpetas <- list.dirs(salidas, recursive = FALSE, full.names = TRUE)
      carpetas <- carpetas[file.info(carpetas)$isdir %in% TRUE]
      ultima <- if (length(carpetas)) carpetas[which.max(file.info(carpetas)$mtime)] else NULL
      words <- if (!is.null(ultima)) list.files(ultima, pattern = "^Reporte_.*\\.docx$", full.names = TRUE) else character()
      word <- if (length(words)) words[which.max(file.info(words)$mtime)] else NULL

      if (identical(as.integer(codigo), 0L) && !is.null(word)) {
        hay_advertencia <- grepl("\\[Advertencia\\]", texto)
        resultado(list(
          tipo = if (hay_advertencia) "advertencia" else "ok",
          mensaje = paste(
            if (hay_advertencia) {
              "Reporte local completado con una advertencia. Revisa el registro."
            } else {
              "Reporte completado."
            },
            "\nCarpeta:", normalizePath(ultima, winslash = "\\", mustWork = FALSE)
          ),
          consola = texto, word = word
        ))
      } else {
        resultado(list(
          tipo = "error",
          mensaje = "La ejecución no terminó correctamente. Revisa el registro mostrado abajo.",
          consola = texto, word = NULL
        ))
      }
      shiny::incProgress(0.10)
    })
  })

  output$descargar_word <- shiny::downloadHandler(
    filename = function() {
      ruta <- resultado()$word
      if (is.null(ruta)) "reporte_no_disponible.docx" else basename(ruta)
    },
    content = function(destino) {
      ruta <- resultado()$word
      shiny::validate(shiny::need(!is.null(ruta) && file.exists(ruta), "Primero genera un reporte."))
      file.copy(ruta, destino, overwrite = TRUE)
    }
  )
}

shiny::runApp(shiny::shinyApp(ui, server), host = "127.0.0.1", launch.browser = TRUE)
