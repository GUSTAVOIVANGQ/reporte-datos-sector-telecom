# Interfaz local. Se inicia únicamente desde main.R.
raiz <- getOption("reporte.raiz", getwd())
options(shiny.maxRequestSize = 50 * 1024^2)
excel_prueba <- file.path(raiz, "entrada", "Entrada_Reporte_Telecom_PRUEBA.xlsx")
plantilla_defecto <- file.path(raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx")
salidas_defecto <- file.path(raiz, "salidas")
json_sugerido <- paste0(
  "C:\\Users\\gustavo.garcia\\Documents\\GitHub\\",
  "reporte-datos-sector-telecom\\animated-radar-504520-c3-279497a6262f.json"
)

valor_logico <- function(nombre, defecto = TRUE) {
  valor <- tolower(trimws(Sys.getenv(nombre, if (defecto) "true" else "false")))
  valor %in% c("1", "true", "si", "sí", "yes")
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
            value = valor_logico("GOOGLE_ENABLED", TRUE)
          ),
          shiny::conditionalPanel(
            "input.usar_google",
            shiny::textInput(
              "credencial", "Ruta de la llave JSON",
              value = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS", json_sugerido)
            ),
            shiny::fileInput(
              "credencial_archivo", "O seleccionar otra llave JSON", accept = ".json",
              buttonLabel = "Seleccionar", placeholder = "Se usará la ruta escrita arriba"
            ),
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
            shiny::helpText("La llave nunca se copia al proyecto. La cuenta de servicio debe tener permiso de escritura en una unidad compartida.")
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

  shiny::observeEvent(input$generar, {
    excel <- if (!is.null(input$excel)) input$excel$datapath else excel_prueba
    plantilla <- trimws(input$plantilla)
    salidas <- trimws(input$carpeta_salida)
    credencial <- if (!is.null(input$credencial_archivo)) {
      input$credencial_archivo$datapath
    } else {
      trimws(input$credencial)
    }
    errores <- character()
    if (!file.exists(excel)) errores <- c(errores, "No se encontró el Excel.")
    if (!file.exists(plantilla)) errores <- c(errores, "No se encontró la plantilla Word.")
    if (!nzchar(salidas)) errores <- c(errores, "Indica una carpeta de salida.")
    if (isTRUE(input$usar_google) && !file.exists(credencial)) {
      errores <- c(errores, "No se encontró la llave JSON. Corrige la ruta o desactiva Google.")
    }
    if (isTRUE(input$usar_google) &&
        !nzchar(trimws(input$carpeta_google_id)) && !nzchar(trimws(input$carpeta_google))) {
      errores <- c(errores, "Indica el nombre o el ID de la carpeta de Drive.")
    }
    if (isTRUE(input$usar_google) && !isTRUE(input$subir_archivos) && !isTRUE(input$crear_sheets)) {
      errores <- c(errores, "Activa al menos una salida de Google o desactiva Google.")
    }
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
      rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
      argumentos <- c(
        shQuote(file.path(raiz, "main.R")), "--automatico",
        shQuote(excel), shQuote(plantilla), shQuote(salidas)
      )
      variables <- c(
        paste0("GOOGLE_ENABLED=", tolower(as.character(input$usar_google))),
        paste0("GOOGLE_APPLICATION_CREDENTIALS=", credencial),
        paste0("GOOGLE_DRIVE_FOLDER_NAME=", trimws(input$carpeta_google)),
        paste0("GOOGLE_DRIVE_FOLDER_ID=", trimws(input$carpeta_google_id)),
        paste0("GOOGLE_UPLOAD_FILES=", tolower(as.character(input$subir_archivos))),
        paste0("GOOGLE_CREATE_SHEETS=", tolower(as.character(input$crear_sheets)))
      )
      salida <- tryCatch(
        system2(rscript, args = argumentos, stdout = TRUE, stderr = TRUE, env = variables),
        error = function(e) structure(conditionMessage(e), status = 1L)
      )
      shiny::incProgress(0.75)
      codigo <- attr(salida, "status")
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
