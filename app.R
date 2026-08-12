# Interfaz local para generar el reporte anual por trimestres con seis fuentes BIT.
raiz <- getOption("reporte.raiz", getwd())
options(shiny.maxRequestSize = 100 * 1024^2)

salidas_defecto <- file.path(raiz, "salidas")
catalogo_defecto <- file.path(raiz, "config", "reporte-datos-sector-telecomunicaciones.xlsx")
cache_defecto <- file.path(raiz, "entrada", "datos_bit")

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

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$meta(charset = "UTF-8"),
    shiny::tags$title("Reporte del sector de telecomunicaciones"),
    shiny::tags$style(shiny::HTML("
      :root { --tinta:#173f43; --verde:#008f98; --fondo:#e9f3f3; --gris:#587477; }
      body { background:linear-gradient(135deg,#f8fbfb,#e4f0f0); color:var(--tinta);
             font-family:'Segoe UI',Arial,sans-serif; min-height:100vh; }
      .container-fluid { max-width:860px; padding:34px 20px; }
      .panel-app { background:#fff; border-radius:20px; padding:30px;
                   box-shadow:0 16px 42px rgba(23,63,67,.14); }
      h2 { margin:0 0 8px; font-weight:750; }
      .subtitulo { color:var(--gris); margin-bottom:22px; }
      .form-control { min-height:42px; border-radius:10px; border-color:#bdd2d3; }
      .form-control:focus { border-color:var(--verde); box-shadow:0 0 0 3px rgba(0,143,152,.14); }
      .radio-inline { margin-right:18px; }
      .ayuda { color:var(--gris); font-size:13px; margin:-2px 0 16px; }
      .opciones { background:#f6fafa; border-radius:12px; padding:14px 16px 5px; margin:12px 0; }
      .btn-run { width:100%; background:var(--verde); border:0; border-radius:11px; color:white;
                 padding:13px; font-size:16px; font-weight:700; margin-top:8px; }
      .btn-run:hover,.btn-run:focus { background:#007780; color:white; }
      .status-box { margin-top:18px; background:#f2f8f8; border-left:5px solid var(--verde);
                    border-radius:10px; padding:13px 15px; white-space:pre-line; }
      .acciones { display:flex; gap:10px; margin-top:14px; }
      .acciones .btn { flex:1; border-radius:10px; padding:10px; }
      @media (max-width:560px) { .container-fluid { padding:18px 10px; }
        .panel-app { padding:22px; } .acciones { flex-direction:column; } }
    "))
  ),
  shiny::div(
    class = "panel-app",
    shiny::h2("Reporte de Datos del Sector de Telecomunicaciones"),
    shiny::div(
      class = "subtitulo",
      paste(
        "Selecciona un año. El sistema comprueba las seis fuentes y genera un Word por trimestre",
        "presente; las secciones aún no publicadas se marcan con '-'."
      )
    ),
    shiny::numericInput("anio", "Año del reporte", value = 2024, min = 2013, max = 2100, step = 1),
    shiny::radioButtons(
      "trimestre", "Reportes a generar",
      choices = c(
        "Todos los trimestres disponibles" = "todos",
        "Q1" = "1", "Q2" = "2", "Q3" = "3", "Q4" = "4"
      ),
      selected = "todos",
      inline = TRUE
    ),
    shiny::div(
      class = "opciones",
      shiny::checkboxInput(
        "actualizar", "Forzar actualización de los seis CSV antes de generar", value = FALSE
      ),
      shiny::checkboxInput(
        "permitir_red", "Descargar un CSV cuando falte o reemplazarlo si es inválido", value = TRUE
      )
    ),
    shiny::div(
      class = "ayuda",
      paste(
        "Los CSV locales válidos se reutilizan sin volver a descargarlos.",
        "Para buscar periodos nuevos en el BIT, usa Forzar actualización.",
        "Si una sección está ausente, se muestra una advertencia y el reporte continúa.",
        "R procesa las fuentes y Python crea únicamente las seis gráficas jerárquicas."
      )
    ),
    shiny::textInput("catalogo", "Catálogo de enlaces", value = catalogo_defecto),
    shiny::textInput("cache", "Carpeta de CSV", value = cache_defecto),
    shiny::textInput("carpeta_salida", "Carpeta de salida", value = salidas_defecto),
    shiny::actionButton(
      "generar", "Validar fuentes y generar", class = "btn-run", icon = shiny::icon("play")
    ),
    shiny::uiOutput("estado"),
    shiny::div(
      class = "acciones",
      shiny::downloadButton("descargar", "Descargar resultado", class = "btn-default"),
      shiny::actionButton(
        "abrir_carpeta", "Abrir carpeta", class = "btn-default",
        icon = shiny::icon("folder-open")
      )
    )
  )
)

server <- function(input, output, session) {
  resultado <- shiny::reactiveVal(list(
    tipo = "listo",
    mensaje = paste(
      "Listo. 2024 tiene cobertura completa en los archivos de referencia incluidos.",
      "La disponibilidad de otros a\u00f1os se vuelve a comprobar al ejecutar."
    ),
    entregable = NULL,
    carpeta = NULL
  ))

  output$estado <- shiny::renderUI({
    x <- resultado()
    color <- switch(x$tipo, error = "#b54a4a", ok = "#168160", advertencia = "#d17d22", "#008f98")
    msg <- tryCatch(enc2utf8(x$mensaje), error = function(e) x$mensaje)
    shiny::div(class = "status-box", style = paste0("border-left-color:", color, ";"), msg)
  })

  shiny::observeEvent(input$generar, {
    anio <- suppressWarnings(as.integer(input$anio))
    if (is.na(anio) || anio < 2013L || anio > 2100L) {
      resultado(list(tipo = "error", mensaje = "Indica un a\u00f1o entre 2013 y 2100.", entregable = NULL, carpeta = NULL))
      return(invisible(NULL))
    }
    rutas <- trimws(c(input$catalogo, input$cache, input$carpeta_salida))
    if (any(!nzchar(rutas))) {
      resultado(list(tipo = "error", mensaje = "Completa las tres rutas.", entregable = NULL, carpeta = NULL))
      return(invisible(NULL))
    }

    resultado(list(
      tipo = "proceso",
      mensaje = paste0("Procesando el a\u00f1o ", anio, "..."),
      entregable = NULL,
      carpeta = NULL
    ))

    generado <- shiny::withProgress(message = "Procesando fuentes BIT", value = 0.10, {
      salida <- tryCatch(
        ejecutar_generacion(
          raiz = raiz,
          anio = anio,
          trimestre = input$trimestre,
          carpeta_salidas = input$carpeta_salida,
          catalogo_excel = input$catalogo,
          carpeta_cache = input$cache,
          actualizar = isTRUE(input$actualizar),
          permitir_red = isTRUE(input$permitir_red)
        ),
        error = function(e) e
      )
      shiny::incProgress(0.90)
      salida
    })

    if (inherits(generado, "error")) {
      detalle <- tryCatch(enc2utf8(conditionMessage(generado)), error = function(e) "Error interno")
      message("ERROR en generacion: ", detalle)
      # Mensaje representativo para la UI sin detalles internos crudos.
      msg_ui <- if (grepl("UTF-8|encoding|xml", detalle, ignore.case = TRUE)) {
        "Error de codificacion al generar el documento. Revise la terminal para mas detalles."
      } else if (grepl("Python|python", detalle)) {
        "No se pudo ejecutar Python para crear las graficas. Revise la terminal."
      } else if (grepl("plantilla|Word|DOCX", detalle, ignore.case = TRUE)) {
        "Error al procesar la plantilla Word. Revise la terminal para mas detalles."
      } else if (grepl("fuente|CSV|BIT", detalle, ignore.case = TRUE)) {
        "Error al procesar las fuentes de datos. Revise la terminal para mas detalles."
      } else {
        paste0("Error: ", detalle)
      }
      resultado(list(tipo = "error", mensaje = msg_ui, entregable = NULL, carpeta = NULL))
      return(invisible(NULL))
    }

    q <- paste0("Q", generado$trimestres_generados, collapse = ", ")
    advertencias <- generado$advertencias
    # Imprimir todo el detalle en la terminal.
    message("Proceso completado. Trimestres generados: ", q)
    message("Diagnostico guardado en diagnostico_fuentes.csv")
    if (length(advertencias)) {
      message("Advertencias:")
      for (adv in advertencias) message("  - ", tryCatch(enc2utf8(adv), error = function(e) adv))
    }
    message("Entregable: ", generado$entregable)
    message("Duracion: ", generado$duracion_segundos, " s")
    # Mensaje representativo y limpio para la UI.
    mensaje_ui <- paste0(
      "Proceso completado. Trimestres generados: ", q, ".",
      if (length(advertencias)) paste0("\n", length(advertencias), " advertencia(s); consulte la terminal.") else ""
    )
    resultado(list(
      tipo = if (length(advertencias)) "advertencia" else "ok",
      mensaje = mensaje_ui,
      entregable = generado$entregable,
      carpeta = generado$carpeta
    ))
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

  shiny::observeEvent(input$abrir_carpeta, {
    ruta <- resultado()$carpeta
    if (is.null(ruta) || !dir.exists(ruta)) ruta <- trimws(input$carpeta_salida)
    if (!dir.exists(ruta)) dir.create(ruta, recursive = TRUE, showWarnings = FALSE)
    tryCatch(abrir_directorio(ruta), error = function(e) {
      resultado(list(
        tipo = "error", mensaje = "No fue posible abrir la carpeta.",
        entregable = resultado()$entregable, carpeta = resultado()$carpeta
      ))
    })
  })
}

shiny::runApp(shiny::shinyApp(ui, server), host = "127.0.0.1", launch.browser = TRUE)
