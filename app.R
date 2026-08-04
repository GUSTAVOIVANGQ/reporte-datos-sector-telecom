# Interfaz local mínima. Se inicia únicamente desde main.R.
raiz <- getOption("reporte.raiz", getwd())
options(shiny.maxRequestSize = 50 * 1024^2)

excel_prueba <- file.path(raiz, "entrada", "Entrada_Reporte_Telecom_PRUEBA.xlsx")
plantilla_defecto <- file.path(
  raiz, "plantilla", "Plantilla_Reporte_Telecom_Automatizable.docx"
)
salidas_defecto <- file.path(raiz, "salidas")
carpeta_google_defecto <- "Reporte_de_Datos_del_Sector_de_Telecomunicaciones"
alcances_google <- c(
  "https://www.googleapis.com/auth/drive",
  "https://www.googleapis.com/auth/spreadsheets"
)

log_terminal <- function(etapa, estado, detalle) {
  message(sprintf(
    "[%s] [%s] %s - %s",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"), estado, etapa, detalle
  ))
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

abrir_directorio <- function(ruta) {
  ruta <- normalizePath(ruta, winslash = "\\", mustWork = TRUE)
  if (.Platform$OS.type == "windows") {
    shell.exec(ruta)
  } else if (identical(Sys.info()[["sysname"]], "Darwin")) {
    system2("open", shQuote(ruta), wait = FALSE, stdout = FALSE, stderr = FALSE)
  } else {
    system2("xdg-open", shQuote(ruta), wait = FALSE, stdout = FALSE, stderr = FALSE)
  }
  invisible(TRUE)
}

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$title("Reporte de telecomunicaciones"),
    shiny::tags$style(shiny::HTML("
      :root { --tinta:#173f43; --verde:#008f98; --fondo:#e9f3f3; }
      body { background:linear-gradient(135deg,#f8fbfb,#e4f0f0); color:var(--tinta);
             font-family:'Segoe UI',Arial,sans-serif; min-height:100vh; }
      .container-fluid { max-width:720px; padding:40px 20px; }
      .panel-app { background:#fff; border-radius:20px; padding:30px;
                   box-shadow:0 16px 42px rgba(23,63,67,.14); }
      h2 { margin:0 0 24px; font-weight:750; }
      .form-control { min-height:42px; border-radius:10px; border-color:#bdd2d3; }
      .form-control:focus { border-color:var(--verde); box-shadow:0 0 0 3px rgba(0,143,152,.14); }
      .auto-note { color:#587477; font-size:13px; margin:-4px 0 20px; }
      .btn-run { width:100%; background:var(--verde); border:0; border-radius:11px; color:white;
                 padding:13px; font-size:16px; font-weight:700; margin-top:4px; }
      .btn-run:hover,.btn-run:focus { background:#007780; color:white; }
      .status-box { margin-top:18px; background:#f2f8f8; border-left:5px solid var(--verde);
                    border-radius:10px; padding:13px 15px; }
      .acciones { display:flex; gap:10px; margin-top:14px; }
      .acciones .btn { flex:1; border-radius:10px; padding:10px; }
      @media (max-width:560px) { .container-fluid { padding:18px 10px; }
                                 .panel-app { padding:22px; } .acciones { flex-direction:column; } }
    "))
  ),
  shiny::div(class = "panel-app",
    shiny::h2("Reporte de telecomunicaciones"),
    shiny::fileInput(
      "excel", "Excel de entrada", accept = ".xlsx",
      buttonLabel = "Seleccionar", placeholder = "Excel de prueba incluido"
    ),
    shiny::textInput("carpeta_salida", "Carpeta de salida", value = salidas_defecto),
    shiny::textInput(
      "google_email", "Cuenta Google", value = Sys.getenv("GOOGLE_USER_EMAIL", ""),
      placeholder = "nombre@gmail.com"
    ),
    shiny::div(class = "auto-note", "Drive y Sheets se generan automáticamente."),
    shiny::actionButton(
      "generar", "Generar reporte", class = "btn-run", icon = shiny::icon("play")
    ),
    shiny::uiOutput("estado"),
    shiny::div(class = "acciones",
      shiny::downloadButton(
        "descargar_word", "Descargar Word", class = "btn-default"
      ),
      shiny::actionButton(
        "abrir_carpeta", "Abrir carpeta", class = "btn-default",
        icon = shiny::icon("folder-open")
      )
    )
  )
)

server <- function(input, output, session) {
  resultado <- shiny::reactiveVal(list(
    tipo = "listo", mensaje = "Listo.", word = NULL, carpeta = NULL
  ))
  cuenta_google <- shiny::reactiveVal("")

  output$estado <- shiny::renderUI({
    x <- resultado()
    color <- switch(
      x$tipo, error = "#b54a4a", ok = "#168160",
      advertencia = "#d17d22", "#008f98"
    )
    shiny::div(
      class = "status-box", style = paste0("border-left-color:", color, ";"),
      x$mensaje
    )
  })

  shiny::observeEvent(input$generar, {
    excel <- if (!is.null(input$excel)) input$excel$datapath else excel_prueba
    salidas <- trimws(input$carpeta_salida)
    errores <- character()
    if (!file.exists(excel)) errores <- c(errores, "No se encontró el Excel.")
    if (!file.exists(plantilla_defecto)) errores <- c(errores, "No se encontró la plantilla Word.")
    if (!nzchar(salidas)) errores <- c(errores, "Indica una carpeta de salida.")
    if (length(errores)) {
      resultado(list(
        tipo = "error", mensaje = paste(errores, collapse = " "),
        word = NULL, carpeta = NULL
      ))
      return(invisible(NULL))
    }

    dir.create(salidas, recursive = TRUE, showWarnings = FALSE)
    resultado(list(tipo = "proceso", mensaje = "Generando…", word = NULL, carpeta = NULL))
    log_terminal("Interfaz", "Inicio", paste("Excel seleccionado:", normalizePath(excel)))
    log_terminal("Interfaz", "Información", paste("Carpeta de salida:", normalizePath(salidas)))

    shiny::withProgress(message = "Generando reporte", value = 0.10, {
      correo_google <- trimws(input$google_email)
      correo_guardado <- cuenta_google()
      if (nzchar(correo_guardado) &&
          (!nzchar(correo_google) || identical(correo_google, correo_guardado))) {
        correo_google <- correo_guardado
      } else {
        log_terminal("Google", "Inicio", "Autorizando la cuenta personal")
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
          log_terminal("Google", "Reintento", "Renovando los permisos OAuth")
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
          log_terminal("Google", "Completado", paste("Cuenta autorizada:", correo_google))
        } else {
          log_terminal(
            "Google", "Advertencia",
            paste(autenticacion$mensaje, "El Word local continuará.")
          )
        }
      }
      shiny::incProgress(0.20)

      rscript <- file.path(
        R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
      )
      argumentos <- c(
        shQuote(file.path(raiz, "main.R")), "--automatico",
        shQuote(excel), shQuote(plantilla_defecto), shQuote(salidas),
        shQuote("--google-enabled=true"),
        shQuote(paste0("--google-email=", correo_google)),
        shQuote(paste0("--google-folder-name=", carpeta_google_defecto)),
        shQuote("--google-folder-id="),
        shQuote("--google-upload-files=true"),
        shQuote("--google-create-sheets=true")
      )
      codigo <- tryCatch(
        system2(rscript, args = argumentos, stdout = "", stderr = ""),
        error = function(e) {
          log_terminal("Ejecución", "Error", conditionMessage(e))
          1L
        }
      )
      shiny::incProgress(0.60)

      carpetas <- list.dirs(salidas, recursive = FALSE, full.names = TRUE)
      carpetas <- carpetas[file.info(carpetas)$isdir %in% TRUE]
      ultima <- if (length(carpetas)) {
        carpetas[which.max(file.info(carpetas)$mtime)]
      } else {
        NULL
      }
      words <- if (!is.null(ultima)) {
        list.files(ultima, pattern = "^Reporte_.*\\.docx$", full.names = TRUE)
      } else {
        character()
      }
      word <- if (length(words)) words[which.max(file.info(words)$mtime)] else NULL

      if (identical(as.integer(codigo), 0L) && !is.null(word)) {
        resultado(list(
          tipo = "ok", mensaje = "Reporte completado.",
          word = word, carpeta = ultima
        ))
      } else {
        resultado(list(
          tipo = "error", mensaje = "No se completó. Revisa la terminal.",
          word = NULL, carpeta = ultima
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
      shiny::validate(shiny::need(
        !is.null(ruta) && file.exists(ruta), "Primero genera un reporte."
      ))
      file.copy(ruta, destino, overwrite = TRUE)
    }
  )

  shiny::observeEvent(input$abrir_carpeta, {
    ruta <- resultado()$carpeta
    if (is.null(ruta) || !dir.exists(ruta)) ruta <- trimws(input$carpeta_salida)
    if (!dir.exists(ruta)) dir.create(ruta, recursive = TRUE, showWarnings = FALSE)
    tryCatch(
      {
        abrir_directorio(ruta)
        log_terminal("Carpeta local", "Completado", normalizePath(ruta))
      },
      error = function(e) {
        log_terminal("Carpeta local", "Error", conditionMessage(e))
        resultado(list(
          tipo = "error", mensaje = "No fue posible abrir la carpeta.",
          word = resultado()$word, carpeta = resultado()$carpeta
        ))
      }
    )
  })
}

shiny::runApp(
  shiny::shinyApp(ui, server), host = "127.0.0.1", launch.browser = TRUE
)
