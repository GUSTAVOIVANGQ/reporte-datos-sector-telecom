# Interfaz Shiny: previsualización del documento y controles de generación.
raiz <- getOption("reporte.raiz", getwd())
options(shiny.maxRequestSize = 100 * 1024^2)

valor_logico_app <- function(nombre, defecto = FALSE) {
  valor <- tolower(trimws(Sys.getenv(nombre, unset = if (defecto) "true" else "false")))
  valor %in% c("1", "true", "si", "sí", "yes", "on")
}

modo_servidor <- valor_logico_app("REPORTE_MODO_SERVIDOR", FALSE)
salidas_defecto <- Sys.getenv("REPORTE_SALIDAS_DIR", unset = file.path(raiz, "salidas"))
catalogo_defecto <- Sys.getenv(
  "REPORTE_CATALOGO",
  unset = file.path(raiz, "config", "reporte-datos-sector-telecomunicaciones.xlsx")
)
cache_defecto <- Sys.getenv("REPORTE_DATOS_DIR", unset = file.path(raiz, "entrada", "datos_bit"))

source(file.path(raiz, "vista_previa.R"), local = globalenv(), encoding = "UTF-8")

abrir_directorio <- function(ruta) {
  ruta <- normalizePath(ruta, winslash = "\\", mustWork = TRUE)
  if (.Platform$OS.type == "windows") {
    shell.exec(ruta)
  } else if (identical(Sys.info()[["sysname"]], "Darwin")) {
    system2("open", ruta, wait = FALSE, stdout = FALSE, stderr = FALSE)
  } else {
    system2("xdg-open", ruta, wait = FALSE, stdout = FALSE, stderr = FALSE)
  }
  invisible(TRUE)
}

panel_configuracion <- if (modo_servidor) {
  shiny::div(
    class = "modo-servidor",
    "Modo servidor: las fuentes, la actualización y las rutas están administradas por el servicio."
  )
} else {
  shiny::tagList(
    shiny::div(
      class = "opciones",
      shiny::checkboxInput(
        "actualizar", "Forzar actualización de los seis CSV antes de generar", value = FALSE
      ),
      shiny::checkboxInput(
        "permitir_red", "Descargar un CSV cuando falte o reemplazarlo si es inválido", value = TRUE
      )
    ),
    shiny::tags$details(
      class = "rutas-avanzadas",
      shiny::tags$summary("Rutas avanzadas"),
      shiny::textInput("catalogo", "Catálogo de enlaces", value = catalogo_defecto),
      shiny::textInput("cache", "Carpeta de CSV", value = cache_defecto),
      shiny::textInput("carpeta_salida", "Carpeta de salida", value = salidas_defecto)
    )
  )
}

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$title("Reporte del sector de telecomunicaciones"),
    shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    shiny::tags$style(shiny::HTML("
      :root { --tinta:#173f43; --verde:#008f98; --fondo:#e9f3f3; --gris:#587477; }
      html,body { min-height:100%; }
      body { background:linear-gradient(135deg,#f8fbfb,#e4f0f0); color:var(--tinta);
             font-family:'Segoe UI',Arial,sans-serif; }
      .container-fluid { max-width:1560px; padding:24px; }
      .app-grid { display:grid; grid-template-columns:minmax(0,1.65fr) minmax(390px,.75fr);
                  gap:22px; align-items:stretch; min-height:calc(100vh - 48px); }
      .panel-app { background:#fff; border-radius:20px; box-shadow:0 16px 42px rgba(23,63,67,.14); }
      .panel-preview { min-height:720px; overflow:hidden; display:flex; flex-direction:column; }
      .preview-header { display:flex; justify-content:space-between; gap:12px; align-items:center;
                        padding:18px 22px; border-bottom:1px solid #dce8e8; }
      .preview-title { font-size:18px; font-weight:750; margin:0; }
      .preview-body { flex:1; min-height:650px; background:#eef3f3; }
      .preview-empty { height:100%; min-height:650px; display:flex; align-items:center;
                       justify-content:center; padding:45px; text-align:center; color:var(--gris); }
      .preview-empty .glyphicon { display:block; font-size:54px; color:#8eb5b8; margin-bottom:18px; }
      .preview-frame { width:100%; height:calc(100vh - 145px); min-height:650px; border:0; background:white; }
      .preview-error { margin:28px; background:#fff; border-left:5px solid #d17d22;
                       border-radius:10px; padding:16px; color:#6d541e; }
      .panel-controls { padding:28px; align-self:start; position:sticky; top:20px; }
      h2 { margin:0 0 8px; font-size:27px; line-height:1.18; font-weight:750; }
      .subtitulo { color:var(--gris); margin-bottom:22px; }
      .form-control { min-height:42px; border-radius:10px; border-color:#bdd2d3; }
      .form-control:focus { border-color:var(--verde); box-shadow:0 0 0 3px rgba(0,143,152,.14); }
      .radio-inline { margin-right:16px; }
      .ayuda { color:var(--gris); font-size:13px; margin:12px 0 16px; }
      .opciones,.modo-servidor { background:#f3f8f8; border-radius:12px; padding:14px 16px 5px; margin:12px 0; }
      .modo-servidor { padding:14px 16px; }
      .rutas-avanzadas { margin:12px 0 16px; color:var(--gris); }
      .rutas-avanzadas summary { cursor:pointer; font-weight:650; color:var(--tinta); margin-bottom:12px; }
      .btn-run { width:100%; background:var(--verde); border:0; border-radius:11px; color:white;
                 padding:13px; font-size:16px; font-weight:700; margin-top:8px; }
      .btn-run:hover,.btn-run:focus { background:#007780; color:white; }
      .status-box { margin-top:18px; background:#f2f8f8; border-left:5px solid var(--verde);
                    border-radius:10px; padding:13px 15px; white-space:pre-line; overflow-wrap:anywhere; }
      .acciones { display:flex; gap:10px; margin-top:14px; }
      .acciones .btn { flex:1; border-radius:10px; padding:10px; }
      .selector-preview { min-width:230px; margin:-12px 0; }
      .selector-preview .form-group { margin-bottom:0; }
      @media (max-width:1050px) {
        .app-grid { grid-template-columns:1fr; }
        .panel-controls { grid-row:1; position:static; }
        .panel-preview { grid-row:2; min-height:620px; }
        .preview-frame,.preview-empty { min-height:560px; height:70vh; }
      }
      @media (max-width:560px) { .container-fluid { padding:10px; }
        .panel-controls { padding:22px; } .acciones { flex-direction:column; }
        .preview-header { align-items:flex-start; flex-direction:column; }
        .selector-preview { width:100%; } }
    "))
  ),
  shiny::div(
    id = "reporte-telecom-app",
    class = "app-grid",
    shiny::div(
      class = "panel-app panel-preview",
      shiny::div(
        class = "preview-header",
        shiny::div(class = "preview-title", "Vista previa del documento"),
        shiny::uiOutput("selector_preview", class = "selector-preview")
      ),
      shiny::div(class = "preview-body", shiny::uiOutput("preview_documento"))
    ),
    shiny::div(
      class = "panel-app panel-controls",
      shiny::h2("Reporte de Datos del Sector de Telecomunicaciones"),
      shiny::div(
        class = "subtitulo",
        paste(
          "Selecciona un año. El sistema comprueba las seis fuentes y genera un Word por",
          "trimestre presente; las secciones aún no publicadas se marcan con '-'."
        )
      ),
      shiny::numericInput("anio", "Año del reporte", value = 2024, min = 2013, max = 2100, step = 1),
      shiny::radioButtons(
        "trimestre", "Reportes a generar",
        choices = c(
          "Todos los trimestres disponibles" = "todos",
          "Q1" = "1", "Q2" = "2", "Q3" = "3", "Q4" = "4"
        ),
        selected = "todos", inline = TRUE
      ),
      panel_configuracion,
      shiny::div(
        class = "ayuda",
        paste(
          "Los CSV locales válidos se reutilizan. Si una sección está ausente, se registra",
          "una advertencia y el reporte continúa. La vista previa se habilita al terminar."
        )
      ),
      shiny::actionButton(
        "generar", "Validar fuentes y generar", class = "btn-run", icon = shiny::icon("play")
      ),
      shiny::uiOutput("estado"),
      shiny::div(
        class = "acciones",
        shiny::downloadButton("descargar", "Descargar resultado", class = "btn-default"),
        if (!modo_servidor) shiny::actionButton(
          "abrir_carpeta", "Abrir carpeta", class = "btn-default", icon = shiny::icon("folder-open")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  token <- gsub("[^A-Za-z0-9]", "", session$token)
  carpeta_preview <- file.path(tempdir(), paste0("reporte_preview_", token))
  dir.create(carpeta_preview, recursive = TRUE, showWarnings = FALSE)
  prefijo_preview <- paste0("preview-", token)
  shiny::addResourcePath(prefijo_preview, carpeta_preview)
  session$onSessionEnded(function() {
    try(shiny::removeResourcePath(prefijo_preview), silent = TRUE)
    unlink(carpeta_preview, recursive = TRUE, force = TRUE)
  })

  resultado <- shiny::reactiveVal(list(
    tipo = "listo",
    mensaje = "Listo para validar las fuentes y generar el reporte.",
    entregable = NULL, carpeta = NULL, reportes = character()
  ))
  preview <- shiny::reactiveVal(list(pdf = NULL, error = NULL))

  output$estado <- shiny::renderUI({
    x <- resultado()
    color <- switch(x$tipo, error = "#b54a4a", ok = "#168160", advertencia = "#d17d22", "#008f98")
    shiny::div(class = "status-box", style = paste0("border-left-color:", color, ";"), x$mensaje)
  })

  output$selector_preview <- shiny::renderUI({
    reportes <- resultado()$reportes
    if (length(reportes) <= 1L) return(NULL)
    shiny::selectInput(
      "reporte_preview", NULL,
      choices = stats::setNames(reportes, sub("^Reporte_Telecomunicaciones_", "", basename(reportes))),
      selected = reportes[[1]]
    )
  })

  output$preview_documento <- shiny::renderUI({
    actual <- preview()
    if (!is.null(actual$error)) {
      return(shiny::div(
        class = "preview-error", shiny::strong("Vista previa no disponible. "), actual$error
      ))
    }
    if (is.null(actual$pdf) || !file.exists(actual$pdf)) {
      return(shiny::div(
        class = "preview-empty",
        shiny::div(shiny::icon("file-word"), shiny::h4("El documento aparecerá aquí"),
                   shiny::p("Genera un reporte para activar la vista previa."))
      ))
    }
    version <- as.numeric(file.info(actual$pdf)$mtime)
    shiny::tags$iframe(
      class = "preview-frame",
      title = "Vista previa PDF del reporte",
      src = paste0(prefijo_preview, "/", basename(actual$pdf), "?v=", version)
    )
  })

  actualizar_preview <- function(docx) {
    preview(list(pdf = NULL, error = NULL))
    if (is.null(docx) || !length(docx) || !file.exists(docx)) return(invisible(NULL))
    convertido <- tryCatch(
      crear_vista_previa_docx(docx, carpeta_preview),
      error = function(e) e
    )
    if (inherits(convertido, "error")) {
      preview(list(pdf = NULL, error = conditionMessage(convertido)))
    } else {
      preview(list(pdf = convertido, error = NULL))
    }
    invisible(convertido)
  }

  session$onFlushed(function() {
    tryCatch({
      existentes <- if (dir.exists(salidas_defecto)) {
        list.files(salidas_defecto, pattern = "\\.docx$", recursive = TRUE, full.names = TRUE)
      } else {
        character()
      }
      existentes <- existentes[file.exists(existentes)]
      reportes_actuales <- shiny::isolate(resultado()$reportes)
      if (!length(existentes) || length(reportes_actuales)) return(invisible(NULL))
      reciente <- existentes[[which.max(file.info(existentes)$mtime)]]
      resultado(list(
        tipo = "listo",
        mensaje = paste0("Mostrando el documento existente más reciente: ", basename(reciente)),
        entregable = reciente,
        carpeta = dirname(reciente),
        reportes = reciente
      ))
      actualizar_preview(reciente)
      invisible(NULL)
    }, error = function(e) {
      registrar_log("WARN", "preview_inicial", conditionMessage(e))
      preview(list(
        pdf = NULL,
        error = paste("No fue posible cargar el documento existente:", conditionMessage(e))
      ))
      invisible(NULL)
    })
  }, once = TRUE)

  shiny::observeEvent(input$reporte_preview, {
    actualizar_preview(input$reporte_preview)
  }, ignoreInit = TRUE)

  shiny::observeEvent(input$generar, {
    anio <- suppressWarnings(as.integer(input$anio))
    if (is.na(anio) || anio < 2013L || anio > 2100L) {
      resultado(list(tipo = "error", mensaje = "Indica un año entre 2013 y 2100.",
                     entregable = NULL, carpeta = NULL, reportes = character()))
      return(invisible(NULL))
    }
    catalogo <- if (modo_servidor) catalogo_defecto else trimws(input$catalogo)
    cache <- if (modo_servidor) cache_defecto else trimws(input$cache)
    carpeta_salida <- if (modo_servidor) salidas_defecto else trimws(input$carpeta_salida)
    actualizar <- if (modo_servidor) FALSE else isTRUE(input$actualizar)
    permitir_red <- if (modo_servidor) valor_logico_app("REPORTE_PERMITIR_RED", TRUE) else isTRUE(input$permitir_red)
    if (any(!nzchar(c(catalogo, cache, carpeta_salida)))) {
      resultado(list(tipo = "error", mensaje = "Completa las tres rutas.",
                     entregable = NULL, carpeta = NULL, reportes = character()))
      return(invisible(NULL))
    }

    resultado(list(tipo = "proceso", mensaje = paste0("Validando fuentes y generando ", anio, "…"),
                   entregable = NULL, carpeta = NULL, reportes = character()))
    preview(list(pdf = NULL, error = NULL))
    inicio <- Sys.time()
    generado <- shiny::withProgress(message = "Procesando fuentes BIT", value = 0.10, {
      salida <- tryCatch(
        ejecutar_generacion(
          raiz = raiz, anio = anio, trimestre = input$trimestre,
          carpeta_salidas = carpeta_salida, catalogo_excel = catalogo,
          carpeta_cache = cache, actualizar = actualizar, permitir_red = permitir_red
        ), error = function(e) e
      )
      shiny::incProgress(0.90)
      salida
    })
    duracion <- as.numeric(difftime(Sys.time(), inicio, units = "secs"))

    if (inherits(generado, "error")) {
      detalle <- conditionMessage(generado)
      registrar_log("ERROR", "generacion_fallida", detalle, list(anio = anio, trimestre = input$trimestre))
      registrar_metrica_generacion(FALSE, duracion, anio, input$trimestre, detalle)
      resultado(list(tipo = "error", mensaje = if (modo_servidor) {
        "No fue posible generar el reporte. Revise el registro del servicio."
      } else detalle, entregable = NULL, carpeta = NULL, reportes = character()))
      return(invisible(NULL))
    }

    q <- paste0("Q", generado$trimestres_generados, collapse = ", ")
    advertencias <- generado$advertencias
    registrar_log("INFO", "generacion_completada", paste0("Trimestres: ", q),
                  list(anio = anio, duracion_segundos = generado$duracion_segundos))
    registrar_metrica_generacion(TRUE, generado$duracion_segundos, anio, input$trimestre,
                                 paste(advertencias, collapse = " | "))
    evaluar_alertas_fuentes(advertencias)
    resultado(list(
      tipo = if (length(advertencias)) "advertencia" else "ok",
      mensaje = paste0(
        "Proceso completado. Trimestres generados: ", q, ".\n",
        "Diagnóstico guardado en diagnostico_fuentes.csv.",
        if (length(advertencias)) paste0("\nAdvertencias: ", paste(advertencias, collapse = " | ")) else ""
      ),
      entregable = generado$entregable, carpeta = generado$carpeta, reportes = generado$reportes
    ))
    actualizar_preview(generado$reportes[[1]])
  })

  output$descargar <- shiny::downloadHandler(
    filename = function() {
      ruta <- resultado()$entregable
      if (is.null(ruta)) "reporte_no_disponible.zip" else basename(ruta)
    },
    content = function(destino) {
      ruta <- resultado()$entregable
      shiny::validate(shiny::need(!is.null(ruta) && file.exists(ruta), "Primero genera el reporte."))
      file.copy(ruta, destino, overwrite = TRUE)
    }
  )

  if (!modo_servidor) shiny::observeEvent(input$abrir_carpeta, {
    ruta <- resultado()$carpeta
    if (is.null(ruta) || !dir.exists(ruta)) ruta <- trimws(input$carpeta_salida)
    if (!dir.exists(ruta)) dir.create(ruta, recursive = TRUE, showWarnings = FALSE)
    tryCatch(abrir_directorio(ruta), error = function(e) registrar_log(
      "WARN", "abrir_carpeta", conditionMessage(e), list(ruta = ruta)
    ))
  })
}

aplicacion_shiny <- shiny::shinyApp(ui, server)
if (!valor_logico_app("REPORTE_NO_RUN_APP", FALSE)) {
  shiny::runApp(
    aplicacion_shiny,
    host = getOption("shiny.host", "127.0.0.1"),
    port = getOption("shiny.port", NULL),
    launch.browser = getOption("shiny.launch.browser", !modo_servidor)
  )
}
