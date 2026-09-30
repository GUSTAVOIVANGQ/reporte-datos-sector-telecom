# Interfaz Shiny: navegación institucional, previsualización y generación.
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
version_app <- trimws(readLines(file.path(raiz, "VERSION"), warn = FALSE)[[1]])
ruta_activos <- normalizePath(file.path(raiz, "www"), mustWork = TRUE)
prefijo_activos <- "reporte-activos"
rutas_registradas <- shiny::resourcePaths()
if (prefijo_activos %in% names(rutas_registradas)) {
  shiny::removeResourcePath(prefijo_activos)
}
shiny::addResourcePath(prefijo_activos, ruta_activos)
url_activo <- function(nombre) paste0(prefijo_activos, "/", nombre, "?v=", version_app)

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

listar_reportes_docx <- function(ruta) {
  if (!dir.exists(ruta)) return(character())
  archivos <- list.files(ruta, pattern = "\\.docx$", recursive = TRUE, full.names = TRUE)
  archivos <- archivos[file.exists(archivos)]
  if (!length(archivos)) return(character())
  archivos[order(file.info(archivos)$mtime, decreasing = TRUE, na.last = TRUE)]
}

formatear_tamano <- function(bytes) {
  bytes <- suppressWarnings(as.numeric(bytes))
  if (!length(bytes) || !is.finite(bytes)) return("—")
  unidades <- c("B", "KB", "MB", "GB")
  indice <- min(4L, max(1L, floor(log(max(bytes, 1), 1024)) + 1L))
  paste0(format(round(bytes / 1024^(indice - 1L), 1L), trim = TRUE), " ", unidades[[indice]])
}

formatear_fecha <- function(fecha) {
  if (!length(fecha) || is.na(fecha)) return("Fecha no disponible")
  format(as.POSIXct(fecha), "%d/%m/%Y %H:%M")
}

crear_estado <- function(tipo = "listo", mensaje, entregable = NULL, carpeta = NULL,
                         reportes = character(), etapa = 0L, duracion = NA_real_,
                         advertencias = character()) {
  list(
    tipo = tipo, mensaje = as.character(mensaje), entregable = entregable,
    carpeta = carpeta, reportes = reportes, etapa = as.integer(etapa),
    duracion = as.numeric(duracion), advertencias = unique(as.character(advertencias))
  )
}

enlace_navegacion <- function(id, etiqueta, icono, activo = FALSE) {
  shiny::actionLink(
    id, shiny::tagList(shiny::icon(icono), shiny::span(etiqueta)),
    class = paste("nav-item", if (activo) "active" else ""), title = etiqueta,
    `aria-current` = if (activo) "page" else NULL
  )
}

panel_configuracion <- if (modo_servidor) {
  shiny::div(
    class = "settings-readonly",
    shiny::div(class = "settings-icon", shiny::icon("server")),
    shiny::div(
      shiny::strong("Configuración administrada por el servidor"),
      shiny::p("Las fuentes, la actualización y las rutas se controlan mediante el servicio.")
    )
  )
} else {
  shiny::div(
    class = "settings-form",
    shiny::checkboxInput(
      "actualizar", "Forzar actualización de los seis CSV antes de generar", value = FALSE
    ),
    shiny::checkboxInput(
      "permitir_red", "Descargar o reemplazar una fuente ausente o inválida", value = TRUE
    ),
    shiny::textInput("catalogo", "Catálogo de enlaces", value = catalogo_defecto),
    shiny::textInput("cache", "Carpeta de CSV", value = cache_defecto),
    shiny::textInput("carpeta_salida", "Carpeta de salida", value = salidas_defecto)
  )
}

panel_generar <- shiny::tagList(
  shiny::div(
    class = "workspace-grid",
    shiny::tags$section(
      class = "surface preview-card",
      shiny::div(
        class = "surface-header preview-toolbar",
        shiny::uiOutput("metadatos_preview"),
        shiny::uiOutput("selector_preview", class = "selector-preview")
      ),
      shiny::div(class = "preview-body", shiny::uiOutput("preview_documento"))
    ),
    shiny::tags$aside(
      class = "surface config-card",
      shiny::div(
        class = "surface-header config-heading",
        shiny::div(
          shiny::h3("Configuración del reporte"),
          shiny::p("Selecciona el periodo que deseas procesar.")
        )
      ),
      shiny::div(
        class = "config-body",
        shiny::numericInput(
          "anio", "Año del reporte", value = 2024, min = 2013, max = 2100, step = 1
        ),
        shiny::radioButtons(
          "trimestre", "Trimestres a generar",
          choices = c(
            "Todos los disponibles" = "todos",
            "Q1" = "1", "Q2" = "2", "Q3" = "3", "Q4" = "4"
          ),
          selected = "todos", inline = TRUE
        ),
        shiny::uiOutput("resumen_sistema"),
        shiny::actionButton(
          "generar", "Validar fuentes y generar", class = "btn-run", icon = shiny::icon("play")
        )
      ),
      shiny::div(
        class = "config-status", shiny::uiOutput("estado"),
        shiny::uiOutput("ultimo_documento"), shiny::uiOutput("acciones_resultado")
      )
    )
  ),
  shiny::div(
    class = "workflow-row",
    shiny::tags$section(class = "surface workflow-card", shiny::uiOutput("flujo_estado")),
    shiny::tags$section(class = "surface time-card", shiny::uiOutput("tiempo_estimado"))
  )
)

panel_historial <- shiny::tags$section(
  class = "page-section",
  shiny::div(
    class = "section-heading",
    shiny::div(
      shiny::h2("Historial de reportes"),
      shiny::p("Consulta y vuelve a previsualizar los documentos almacenados en el servidor.")
    ),
    shiny::div(class = "section-badge", shiny::icon("clock"), " Salidas locales")
  ),
  shiny::uiOutput("historial_ui")
)

panel_fuentes <- shiny::tags$section(
  class = "page-section",
  shiny::div(
    class = "section-heading",
    shiny::div(
      shiny::h2("Fuentes de datos"),
      shiny::p("Estado de los seis archivos del Banco de Información de Telecomunicaciones.")
    ),
    shiny::div(
      class = "source-actions",
      shiny::actionButton(
        "actualizar_fuentes", "Actualizar los seis CSV", icon = shiny::icon("arrows-rotate"),
        class = "btn-update-sources"
      ),
      shiny::actionButton(
        "ir_generar_fuentes", "Generar reporte", icon = shiny::icon("arrow-right"),
        class = "btn-secondary"
      )
    )
  ),
  shiny::uiOutput("estado_actualizacion_fuentes"),
  shiny::uiOutput("fuentes_ui")
)

panel_ajustes <- shiny::tags$section(
  class = "page-section",
  shiny::div(
    class = "section-heading",
    shiny::div(
      shiny::h2("Configuración"),
      shiny::p("Parámetros técnicos, entorno certificado y opciones de ejecución.")
    )
  ),
  shiny::div(
    class = "settings-grid",
    shiny::tags$section(
      class = "surface settings-card", shiny::h3("Ejecución y almacenamiento"),
      panel_configuracion
    ),
    shiny::tags$section(
      class = "surface settings-card",
      shiny::h3("Entorno del proyecto"),
      shiny::tags$dl(
        class = "definition-list",
        shiny::tags$dt("Versión"), shiny::tags$dd(version_app),
        shiny::tags$dt("R certificado"), shiny::tags$dd("4.6.1"),
        shiny::tags$dt("Python certificado"), shiny::tags$dd("3.9.25"),
        shiny::tags$dt("Modo"), shiny::tags$dd(if (modo_servidor) "Servidor" else "Local")
      ),
      shiny::tags$a(
        class = "text-link", href = "api/__docs__/", target = "_blank",
        rel = "noopener noreferrer", shiny::icon("code"), " Abrir documentación de la API"
      )
    ),
    shiny::tags$section(
      class = "surface settings-card settings-wide",
      shiny::h3("Métricas de generación"), shiny::uiOutput("metricas_ui")
    )
  )
)

ui <- shiny::fluidPage(
  shiny::tags$head(
    shiny::tags$title("Reporte del sector de telecomunicaciones"),
    shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    shiny::tags$link(
      rel = "stylesheet", type = "text/css", href = url_activo("app.css")
    ),
    shiny::tags$script(src = url_activo("app.js"))
  ),
  shiny::tags$a(class = "skip-link", href = "#contenido-principal", "Saltar al contenido"),
  shiny::div(
    id = "reporte-telecom-app", class = "app-shell",
    shiny::tags$aside(
      id = "barra_lateral", class = "app-sidebar",
      shiny::div(
        class = "brand-block",
        shiny::tags$img(
          src = url_activo("logo_crt_blanco.png"),
          alt = "Comisión Reguladora de Telecomunicaciones",
          class = "brand-logo"
        ),
        shiny::span("Reporte del sector", class = "brand-product")
      ),
      shiny::tags$nav(
        class = "sidebar-nav", `aria-label` = "Navegación principal",
        enlace_navegacion("nav_generar", "Generar reporte", "file-circle-plus", TRUE),
        enlace_navegacion("nav_historial", "Historial de reportes", "clock-rotate-left"),
        enlace_navegacion("nav_fuentes", "Fuentes de datos", "database"),
        enlace_navegacion("nav_configuracion", "Configuración", "gear")
      ),
      shiny::div(
        class = "sidebar-footer",
        shiny::div(
          class = "user-card", shiny::div(class = "user-avatar", shiny::icon("user")),
          shiny::div(shiny::strong("Usuario"), shiny::span(if (modo_servidor) "Servidor" else "Local"))
        ),
        shiny::actionLink(
          "tema", shiny::tagList(shiny::icon("circle-half-stroke"), shiny::span("Tema oscuro")),
          class = "theme-toggle", title = "Cambiar contraste", `aria-pressed` = "false"
        )
      )
    ),
    shiny::div(class = "sidebar-backdrop", id = "sidebar_backdrop"),
    shiny::tags$main(
      id = "contenido-principal", class = "app-main",
      shiny::tags$header(
        class = "topbar",
        shiny::div(
          class = "topbar-title",
          shiny::actionButton(
            "menu_movil", label = NULL, icon = shiny::icon("bars"),
            class = "menu-button", title = "Abrir menú",
            `aria-controls` = "barra_lateral", `aria-expanded` = "false"
          ),
          shiny::div(shiny::uiOutput("titulo_pagina"), shiny::uiOutput("subtitulo_pagina"))
        ),
        shiny::div(
          class = "topbar-actions",
          shiny::actionLink(
            "ayuda", shiny::tagList(shiny::icon("circle-question"), shiny::span("Ayuda")),
            class = "topbar-link"
          ),
          shiny::actionLink(
            "notificaciones",
            shiny::tagList(
              shiny::icon("bell"), shiny::span("Avisos", class = "sr-only"),
              shiny::uiOutput("badge_avisos", inline = TRUE)
            ),
            class = "topbar-link icon-link", title = "Avisos del proceso"
          )
        )
      ),
      shiny::div(
        class = "main-content",
        shiny::tabsetPanel(
          id = "seccion_principal", type = "hidden", selected = "generar",
          shiny::tabPanel("Generar", value = "generar", panel_generar),
          shiny::tabPanel("Historial", value = "historial", panel_historial),
          shiny::tabPanel("Fuentes", value = "fuentes", panel_fuentes),
          shiny::tabPanel("Configuración", value = "configuracion", panel_ajustes)
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

  resultado <- shiny::reactiveVal(crear_estado(
    mensaje = "Listo para validar las fuentes y generar el reporte."
  ))
  preview <- shiny::reactiveVal(list(pdf = NULL, error = NULL))
  documento_preview <- shiny::reactiveVal(NULL)
  seccion_activa <- shiny::reactiveVal("generar")
  revision_fuentes <- shiny::reactiveVal(0L)
  estado_actualizacion <- shiny::reactiveVal(list(
    tipo = "listo", mensaje = "Los CSV existentes se conservarán hasta validar las seis descargas."
  ))

  carpeta_cache_actual <- shiny::reactive({
    if (modo_servidor || is.null(input$cache) || !nzchar(trimws(input$cache))) {
      cache_defecto
    } else {
      trimws(input$cache)
    }
  })

  navegar <- function(seccion) {
    shiny::updateTabsetPanel(session, "seccion_principal", selected = seccion)
    seccion_activa(seccion)
    session$sendCustomMessage("navegacion", list(seccion = seccion))
  }

  shiny::observeEvent(input$nav_generar, navegar("generar"))
  shiny::observeEvent(input$nav_historial, navegar("historial"))
  shiny::observeEvent(input$nav_fuentes, navegar("fuentes"))
  shiny::observeEvent(input$nav_configuracion, navegar("configuracion"))
  shiny::observeEvent(input$ir_generar_fuentes, navegar("generar"))

  output$titulo_pagina <- shiny::renderUI({
    titulos <- c(
      generar = "Generar reporte", historial = "Historial de reportes",
      fuentes = "Fuentes de datos", configuracion = "Configuración"
    )
    shiny::h1(titulos[[seccion_activa()]])
  })

  output$subtitulo_pagina <- shiny::renderUI({
    subtitulos <- c(
      generar = "Selecciona las opciones y genera el reporte trimestral del sector.",
      historial = "Revisa los documentos creados en ejecuciones anteriores.",
      fuentes = "Comprueba la disponibilidad local de los archivos BIT.",
      configuracion = "Consulta los parámetros operativos del servicio."
    )
    shiny::p(subtitulos[[seccion_activa()]])
  })

  output$estado <- shiny::renderUI({
    x <- resultado()
    icono <- switch(
      x$tipo, error = "circle-xmark", ok = "circle-check",
      advertencia = "triangle-exclamation", proceso = "spinner", "circle-info"
    )
    shiny::div(
      class = paste("status-box status", x$tipo),
      shiny::div(class = "status-icon", shiny::icon(icono)),
      shiny::div(
        shiny::strong(switch(
          x$tipo, error = "No fue posible completar el proceso",
          ok = "Reporte generado correctamente", advertencia = "Reporte generado con advertencias",
          proceso = "Procesando datos", "Sistema listo"
        )),
        shiny::p(x$mensaje)
      )
    )
  })

  output$resumen_sistema <- shiny::renderUI({
    revision_fuentes()
    carpeta <- carpeta_cache_actual()
    archivos <- vapply(ESPECIFICACIONES_FUENTES, function(x) {
      file.exists(file.path(carpeta, x$archivo))
    }, logical(1))
    presentes <- sum(archivos)
    shiny::div(
      class = paste("system-summary", if (presentes == 6L) "ready" else "partial"),
      shiny::div(class = "system-icon", shiny::icon(if (presentes == 6L) "check" else "download")),
      shiny::div(
        shiny::strong(if (presentes == 6L) "Sistema listo" else "Fuentes locales parciales"),
        shiny::span(if (presentes == 6L) {
          "Los seis CSV están presentes y se reutilizarán."
        } else {
          paste0(presentes, " de 6 CSV presentes; los faltantes se descargarán si la red está habilitada.")
        })
      )
    )
  })

  output$badge_avisos <- shiny::renderUI({
    x <- resultado()
    cantidad <- length(x$advertencias) + as.integer(identical(x$tipo, "error"))
    if (!cantidad) return(NULL)
    shiny::span(class = "notification-badge", cantidad)
  })

  shiny::observeEvent(input$ayuda, {
    shiny::showModal(shiny::modalDialog(
      title = "Cómo generar un reporte",
      shiny::tags$ol(
        shiny::tags$li("Selecciona el año del reporte."),
        shiny::tags$li("Elige todos los trimestres disponibles o un trimestre específico."),
        shiny::tags$li("Opcionalmente actualiza los seis CSV desde la sección Fuentes de datos."),
        shiny::tags$li("Pulsa “Validar fuentes y generar”."),
        shiny::tags$li("Revisa la vista previa y descarga el Word o ZIP resultante.")
      ),
      shiny::p("Si una fuente no contiene el periodo, la sección se marca con '-' y el resto continúa."),
      easyClose = TRUE, footer = shiny::modalButton("Cerrar")
    ))
  })

  shiny::observeEvent(input$notificaciones, {
    x <- resultado()
    contenido <- if (identical(x$tipo, "error")) {
      shiny::div(class = "modal-alert error", x$mensaje)
    } else if (length(x$advertencias)) {
      shiny::tags$ul(lapply(x$advertencias, shiny::tags$li))
    } else {
      shiny::p("No hay avisos pendientes en esta sesión.")
    }
    shiny::showModal(shiny::modalDialog(
      title = "Avisos del proceso", contenido, easyClose = TRUE,
      footer = shiny::modalButton("Cerrar")
    ))
  })

  output$selector_preview <- shiny::renderUI({
    reportes <- resultado()$reportes
    if (length(reportes) <= 1L) return(NULL)
    shiny::selectInput(
      "reporte_preview", NULL,
      choices = stats::setNames(reportes, sub("^Reporte_Telecomunicaciones_", "", basename(reportes))),
      selected = reportes[[1]], width = "100%"
    )
  })

  output$metadatos_preview <- shiny::renderUI({
    docx <- documento_preview()
    if (is.null(docx) || !length(docx) || !file.exists(docx)) {
      return(shiny::div(
        class = "file-meta empty", shiny::icon("file-word"),
        shiny::span("Vista previa del documento")
      ))
    }
    info <- file.info(docx)
    shiny::div(
      class = "file-meta", shiny::div(class = "word-icon", "W"),
      shiny::div(
        shiny::strong(basename(docx)),
        shiny::span(paste(formatear_tamano(info$size), "·", formatear_fecha(info$mtime)))
      )
    )
  })

  output$preview_documento <- shiny::renderUI({
    actual <- preview()
    if (!is.null(actual$error)) {
      return(shiny::div(
        class = "preview-message warning", shiny::icon("file-circle-exclamation"),
        shiny::h3("Vista previa no disponible"), shiny::p(actual$error),
        shiny::p("El archivo Word puede descargarse normalmente.")
      ))
    }
    if (is.null(actual$pdf) || !file.exists(actual$pdf)) {
      return(shiny::div(
        class = "preview-message",
        shiny::div(class = "preview-placeholder-icon", shiny::icon("file-word")),
        shiny::h3("El documento aparecerá aquí"),
        shiny::p("Genera un reporte o selecciónalo en el historial para activar la vista previa.")
      ))
    }
    version <- as.numeric(file.info(actual$pdf)$mtime)
    shiny::tags$iframe(
      class = "preview-frame", title = "Vista previa PDF del reporte",
      src = paste0(prefijo_preview, "/", basename(actual$pdf), "?v=", version)
    )
  })

  actualizar_preview <- function(docx) {
    preview(list(pdf = NULL, error = NULL))
    documento_preview(NULL)
    if (is.null(docx) || !length(docx) || !file.exists(docx)) return(invisible(NULL))
    documento_preview(normalizePath(docx, winslash = "/", mustWork = TRUE))
    convertido <- tryCatch(crear_vista_previa_docx(docx, carpeta_preview), error = function(e) e)
    if (inherits(convertido, "error")) {
      preview(list(pdf = NULL, error = conditionMessage(convertido)))
    } else {
      preview(list(pdf = convertido, error = NULL))
    }
    invisible(convertido)
  }

  output$ultimo_documento <- shiny::renderUI({
    docx <- documento_preview()
    if (is.null(docx) || !length(docx) || !file.exists(docx)) {
      return(shiny::div(
        class = "latest-document empty", shiny::strong("Último documento generado"),
        shiny::span("Todavía no hay un documento seleccionado en esta sesión.")
      ))
    }
    info <- file.info(docx)
    shiny::div(
      class = "latest-document", shiny::strong("Último documento generado"),
      shiny::div(
        class = "document-row", shiny::div(class = "word-icon", "W"),
        shiny::div(
          shiny::span(class = "document-name", basename(docx)),
          shiny::tags$small(paste("Disponible desde", formatear_fecha(info$mtime)))
        )
      )
    )
  })

  output$acciones_resultado <- shiny::renderUI({
    ruta <- resultado()$entregable
    habilitado <- !is.null(ruta) && length(ruta) && file.exists(ruta)
    shiny::div(
      class = "result-actions",
      if (habilitado) {
        shiny::downloadButton(
          "descargar", "Descargar resultado", class = "btn-download",
          icon = shiny::icon("download")
        )
      } else {
        shiny::tags$button(
          type = "button", class = "btn-download disabled", disabled = "disabled",
          shiny::icon("download"), " Descargar resultado"
        )
      },
      if (!modo_servidor) shiny::actionButton(
        "abrir_carpeta", "Abrir carpeta", class = "btn-open", icon = shiny::icon("folder-open")
      )
    )
  })

  output$flujo_estado <- shiny::renderUI({
    x <- resultado()
    etapa <- max(0L, min(4L, x$etapa))
    etiquetas <- c("Validando fuentes", "Procesando datos", "Generando documento", "Finalizando")
    detalles <- c("6 fuentes BIT", "Agregación y controles", "Word y gráficas", "Controles de salida")
    pasos <- lapply(seq_along(etiquetas), function(i) {
      clase <- if (identical(x$tipo, "error") && i == etapa) {
        "error"
      } else if (identical(x$tipo, "ok") || identical(x$tipo, "advertencia")) {
        "done"
      } else if (i < etapa) {
        "done"
      } else if (i == etapa && etapa > 0L) {
        "active"
      } else {
        "pending"
      }
      shiny::tags$li(
        class = paste("workflow-step", clase),
        shiny::div(
          class = "step-marker", if (identical(clase, "done")) shiny::icon("check") else i
        ),
        shiny::div(
          class = "step-copy", shiny::strong(etiquetas[[i]]),
          shiny::span(if (identical(clase, "active")) "En progreso…" else detalles[[i]])
        )
      )
    })
    shiny::tags$ol(class = "workflow-steps", pasos)
  })

  output$tiempo_estimado <- shiny::renderUI({
    x <- resultado()
    segundos <- x$duracion
    etiqueta <- "Tiempo estimado"
    if (!is.finite(segundos)) {
      metricas <- resumen_metricas()
      segundos <- metricas$duracion_promedio_segundos
    } else {
      etiqueta <- "Tiempo empleado"
    }
    valor <- if (length(segundos) && is.finite(segundos)) {
      sprintf("%02d:%02d min", floor(segundos / 60), round(segundos %% 60))
    } else {
      "—"
    }
    shiny::div(
      class = "time-content", shiny::icon("stopwatch"),
      shiny::div(shiny::span(etiqueta), shiny::strong(valor))
    )
  })

  reportes_disponibles <- shiny::reactive({
    resultado()
    listar_reportes_docx(salidas_defecto)
  })

  output$historial_ui <- shiny::renderUI({
    documentos <- reportes_disponibles()
    if (!length(documentos)) {
      return(shiny::div(
        class = "surface empty-state", shiny::icon("folder-open"),
        shiny::h3("Aún no hay reportes"),
        shiny::p("Los documentos generados aparecerán en esta sección."),
        shiny::actionButton("historial_ir_generar", "Generar el primero", class = "btn-run compact")
      ))
    }
    info <- file.info(documentos)
    filas <- lapply(seq_len(min(length(documentos), 30L)), function(i) {
      shiny::div(
        class = "history-row", shiny::div(class = "word-icon", "W"),
        shiny::div(
          class = "history-name", shiny::strong(basename(documentos[[i]])),
          shiny::span(formatear_fecha(info$mtime[[i]]))
        ),
        shiny::span(class = "history-size", formatear_tamano(info$size[[i]]))
      )
    })
    shiny::tagList(
      shiny::div(
        class = "surface history-controls",
        shiny::selectInput(
          "historial_documento", "Documento",
          choices = stats::setNames(documentos, basename(documentos)), width = "100%"
        ),
        shiny::div(
          class = "history-actions",
          shiny::actionButton(
            "historial_ver", "Ver documento", icon = shiny::icon("eye"), class = "btn-secondary"
          ),
          shiny::downloadButton(
            "descargar_historial", "Descargar", icon = shiny::icon("download"),
            class = "btn-download secondary"
          )
        )
      ),
      shiny::div(class = "surface history-list", filas)
    )
  })

  shiny::observeEvent(input$historial_ir_generar, navegar("generar"))
  shiny::observeEvent(input$historial_ver, {
    ruta <- input$historial_documento
    if (is.null(ruta) || !file.exists(ruta)) return(invisible(NULL))
    resultado(crear_estado(
      mensaje = paste0("Mostrando el documento del historial: ", basename(ruta)),
      entregable = ruta, carpeta = dirname(ruta), reportes = ruta
    ))
    actualizar_preview(ruta)
    navegar("generar")
  })

  output$fuentes_ui <- shiny::renderUI({
    revision_fuentes()
    carpeta <- carpeta_cache_actual()
    tarjetas <- lapply(ESPECIFICACIONES_FUENTES, function(especificacion) {
      ruta <- file.path(carpeta, especificacion$archivo)
      existe <- file.exists(ruta)
      info <- if (existe) file.info(ruta) else NULL
      shiny::tags$article(
        class = paste("surface source-card", if (existe) "available" else "missing"),
        shiny::div(
          class = "source-status", shiny::icon(if (existe) "circle-check" else "circle-xmark"),
          if (existe) "Disponible" else "Ausente"
        ),
        shiny::h3(especificacion$etiqueta), shiny::tags$code(especificacion$archivo),
        shiny::div(
          class = "source-meta",
          shiny::span(shiny::icon("hard-drive"), " ", if (existe) formatear_tamano(info$size) else "—"),
          shiny::span(
            shiny::icon("calendar"), " ",
            if (existe) formatear_fecha(info$mtime) else "Sin archivo local"
          )
        )
      )
    })
    shiny::div(class = "source-grid", tarjetas)
  })

  output$estado_actualizacion_fuentes <- shiny::renderUI({
    x <- estado_actualizacion()
    icono <- switch(
      x$tipo, error = "circle-xmark", ok = "circle-check",
      proceso = "spinner", "shield-halved"
    )
    shiny::div(
      class = paste("source-update-status", x$tipo),
      shiny::div(class = "status-icon", shiny::icon(icono)),
      shiny::div(
        shiny::strong(switch(
          x$tipo, error = "Actualización no completada", ok = "Fuentes actualizadas",
          proceso = "Descargando y validando", "Reemplazo seguro"
        )),
        shiny::p(x$mensaje)
      )
    )
  })

  shiny::observeEvent(input$actualizar_fuentes, {
    catalogo <- if (modo_servidor) catalogo_defecto else trimws(input$catalogo)
    cache <- carpeta_cache_actual()
    estado_actualizacion(list(
      tipo = "proceso",
      mensaje = "Preparando la descarga completa de las seis fuentes BIT…"
    ))
    inicio <- Sys.time()
    registrar_log("INFO", "actualizacion_fuentes_iniciada", "Actualización solicitada desde la UI")
    actualizadas <- shiny::withProgress(
      message = "Actualizando las seis fuentes BIT", value = 0,
      {
        tryCatch({
          enlaces <- leer_catalogo_fuentes(catalogo)
          actualizar_todas_fuentes(
            catalogo = enlaces, carpeta_cache = cache,
            progreso = function(indice, total, especificacion, etapa) {
              if (identical(etapa, "reemplazo")) {
                shiny::setProgress(value = 0.98, detail = "Instalando el lote validado")
              } else {
                shiny::setProgress(
                  value = (indice - 1L) / total,
                  detail = paste("Descargando", especificacion$archivo)
                )
              }
            }
          )
        }, error = function(e) e)
      }
    )
    duracion <- as.numeric(difftime(Sys.time(), inicio, units = "secs"))
    revision_fuentes(revision_fuentes() + 1L)
    if (inherits(actualizadas, "error")) {
      detalle <- conditionMessage(actualizadas)
      estado_actualizacion(list(
        tipo = "error",
        mensaje = paste0(detalle, " Los CSV válidos anteriores no fueron reemplazados.")
      ))
      registrar_log(
        "ERROR", "actualizacion_fuentes_fallida", detalle,
        list(duracion_segundos = round(duracion, 2))
      )
      return(invisible(NULL))
    }
    total_bytes <- sum(actualizadas$bytes)
    estado_actualizacion(list(
      tipo = "ok",
      mensaje = paste0(
        "Se reemplazaron 6 de 6 CSV (", formatear_tamano(total_bytes),
        ") después de validar estructura y contenido. Duración: ", round(duracion, 1), " s."
      )
    ))
    registrar_log(
      "INFO", "actualizacion_fuentes_completada", "Se reemplazaron las seis fuentes",
      list(duracion_segundos = round(duracion, 2), bytes = total_bytes)
    )
    invisible(actualizadas)
  })

  output$metricas_ui <- shiny::renderUI({
    metricas <- resumen_metricas()
    tasa <- if (is.finite(metricas$tasa_exito)) {
      paste0(round(100 * metricas$tasa_exito, 1), "%")
    } else {
      "—"
    }
    promedio <- if (is.finite(metricas$duracion_promedio_segundos)) {
      paste0(metricas$duracion_promedio_segundos, " s")
    } else {
      "—"
    }
    shiny::div(
      class = "metrics-grid",
      shiny::div(class = "metric", shiny::span("Generaciones"), shiny::strong(metricas$total)),
      shiny::div(class = "metric", shiny::span("Tasa de éxito"), shiny::strong(tasa)),
      shiny::div(class = "metric", shiny::span("Duración promedio"), shiny::strong(promedio)),
      shiny::div(class = "metric", shiny::span("Fallos registrados"), shiny::strong(metricas$fallos))
    )
  })

  session$onFlushed(function() {
    tryCatch({
      existentes <- listar_reportes_docx(salidas_defecto)
      reportes_actuales <- shiny::isolate(resultado()$reportes)
      if (!length(existentes) || length(reportes_actuales)) return(invisible(NULL))
      reciente <- existentes[[1]]
      resultado(crear_estado(
        mensaje = paste0("Mostrando el documento existente más reciente: ", basename(reciente)),
        entregable = reciente, carpeta = dirname(reciente), reportes = reciente
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

  shiny::observeEvent(input$reporte_preview, actualizar_preview(input$reporte_preview), ignoreInit = TRUE)

  shiny::observeEvent(input$generar, {
    anio <- suppressWarnings(as.integer(input$anio))
    if (is.na(anio) || anio < 2013L || anio > 2100L) {
      resultado(crear_estado(
        tipo = "error", mensaje = "Indica un año entre 2013 y 2100.", etapa = 1L
      ))
      return(invisible(NULL))
    }
    catalogo <- if (modo_servidor) catalogo_defecto else trimws(input$catalogo)
    cache <- if (modo_servidor) cache_defecto else trimws(input$cache)
    carpeta_salida <- if (modo_servidor) salidas_defecto else trimws(input$carpeta_salida)
    actualizar <- if (modo_servidor) FALSE else isTRUE(input$actualizar)
    permitir_red <- if (modo_servidor) {
      valor_logico_app("REPORTE_PERMITIR_RED", TRUE)
    } else {
      isTRUE(input$permitir_red)
    }
    if (any(!nzchar(c(catalogo, cache, carpeta_salida)))) {
      resultado(crear_estado(
        tipo = "error", mensaje = "Completa las tres rutas de configuración.", etapa = 1L
      ))
      return(invisible(NULL))
    }

    resultado(crear_estado(
      tipo = "proceso",
      mensaje = paste0("Validando fuentes y procesando los datos de ", anio, "…"),
      etapa = 2L
    ))
    preview(list(pdf = NULL, error = NULL))
    documento_preview(NULL)
    inicio <- Sys.time()
    generado <- shiny::withProgress(
      message = "Generando reporte de telecomunicaciones", detail = "Validando fuentes BIT",
      value = 0.10,
      {
        salida <- tryCatch(
          ejecutar_generacion(
            raiz = raiz, anio = anio, trimestre = input$trimestre,
            carpeta_salidas = carpeta_salida, catalogo_excel = catalogo,
            carpeta_cache = cache, actualizar = actualizar, permitir_red = permitir_red
          ),
          error = function(e) e
        )
        shiny::incProgress(0.90, detail = "Finalizando documento")
        salida
      }
    )
    duracion <- as.numeric(difftime(Sys.time(), inicio, units = "secs"))

    if (inherits(generado, "error")) {
      detalle <- conditionMessage(generado)
      registrar_log(
        "ERROR", "generacion_fallida", detalle,
        list(anio = anio, trimestre = input$trimestre)
      )
      registrar_metrica_generacion(FALSE, duracion, anio, input$trimestre, detalle)
      resultado(crear_estado(
        tipo = "error",
        mensaje = if (modo_servidor) {
          "No fue posible generar el reporte. Revisa el registro del servicio."
        } else {
          detalle
        },
        etapa = 2L, duracion = duracion
      ))
      return(invisible(NULL))
    }

    q <- paste0("Q", generado$trimestres_generados, collapse = ", ")
    advertencias <- generado$advertencias
    registrar_log(
      "INFO", "generacion_completada", paste0("Trimestres: ", q),
      list(anio = anio, duracion_segundos = generado$duracion_segundos)
    )
    registrar_metrica_generacion(
      TRUE, generado$duracion_segundos, anio, input$trimestre,
      paste(advertencias, collapse = " | ")
    )
    evaluar_alertas_fuentes(advertencias)
    resultado(crear_estado(
      tipo = if (length(advertencias)) "advertencia" else "ok",
      mensaje = paste0(
        "Trimestres generados: ", q, ". El diagnóstico quedó guardado con la salida.",
        if (length(advertencias)) paste0("\n", paste(advertencias, collapse = " | ")) else ""
      ),
      entregable = generado$entregable, carpeta = generado$carpeta,
      reportes = generado$reportes, etapa = 4L,
      duracion = generado$duracion_segundos, advertencias = advertencias
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
      shiny::validate(shiny::need(
        !is.null(ruta) && file.exists(ruta), "Primero genera o selecciona un reporte."
      ))
      if (!file.copy(ruta, destino, overwrite = TRUE)) stop("No se pudo copiar el resultado")
    }
  )

  output$descargar_historial <- shiny::downloadHandler(
    filename = function() {
      ruta <- input$historial_documento
      if (is.null(ruta)) "reporte_no_disponible.docx" else basename(ruta)
    },
    content = function(destino) {
      ruta <- input$historial_documento
      shiny::validate(shiny::need(
        !is.null(ruta) && file.exists(ruta), "Selecciona un documento del historial."
      ))
      if (!file.copy(ruta, destino, overwrite = TRUE)) stop("No se pudo copiar el documento")
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
