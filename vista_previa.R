# Conversión opcional del DOCX a PDF para la previsualización web.

resolver_libreoffice <- function() {
  configurado <- trimws(Sys.getenv("REPORTE_LIBREOFFICE", unset = ""))
  candidatos <- unique(c(
    configurado,
    if (.Platform$OS.type == "windows") {
      c(
        file.path(Sys.getenv("ProgramFiles"), "LibreOffice", "program", "soffice.exe"),
        file.path(Sys.getenv("ProgramFiles(x86)"), "LibreOffice", "program", "soffice.exe"),
        "soffice.exe"
      )
    } else {
      c("libreoffice", "soffice")
    }
  ))
  candidatos <- candidatos[nzchar(candidatos)]
  for (candidato in candidatos) {
    ruta <- if (file.exists(candidato)) {
      normalizePath(candidato, winslash = "/", mustWork = TRUE)
    } else {
      unname(Sys.which(candidato))
    }
    if (!nzchar(ruta)) next
    version <- suppressWarnings(system2(ruta, "--version", stdout = TRUE, stderr = TRUE))
    estado <- attr(version, "status")
    if (is.null(estado) || identical(as.integer(estado), 0L)) return(ruta)
  }
  ""
}

crear_vista_previa_docx <- function(docx, carpeta_destino) {
  if (!file.exists(docx)) stop("No existe el documento para previsualizar: ", docx)
  if (!identical(tolower(tools::file_ext(docx)), "docx")) {
    stop("La vista previa solo admite documentos DOCX")
  }
  libreoffice <- resolver_libreoffice()
  if (!nzchar(libreoffice)) {
    stop(
      "LibreOffice no está instalado. El DOCX sí fue generado y puede descargarse, ",
      "pero la vista previa PDF no está disponible."
    )
  }
  dir.create(carpeta_destino, recursive = TRUE, showWarnings = FALSE)
  perfil <- tempfile("lo_profile_", tmpdir = carpeta_destino)
  dir.create(perfil, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(perfil, recursive = TRUE, force = TRUE), add = TRUE)
  argumentos <- c(
    "--headless", "--nologo", "--nodefault", "--nolockcheck", "--nofirststartwizard",
    paste0("-env:UserInstallation=file://", normalizePath(perfil, winslash = "/", mustWork = TRUE)),
    "--convert-to", "pdf:writer_pdf_Export",
    "--outdir", shQuote(normalizePath(carpeta_destino, winslash = "/", mustWork = TRUE)),
    shQuote(normalizePath(docx, winslash = "/", mustWork = TRUE))
  )
  salida <- suppressWarnings(system2(
    libreoffice, args = argumentos, stdout = TRUE, stderr = TRUE,
    env = c(paste0(
      "HOME=", shQuote(normalizePath(carpeta_destino, winslash = "/", mustWork = TRUE))
    ))
  ))
  estado <- attr(salida, "status")
  if (is.null(estado)) estado <- 0L
  pdf <- file.path(carpeta_destino, paste0(tools::file_path_sans_ext(basename(docx)), ".pdf"))
  if (as.integer(estado) != 0L || !file.exists(pdf) || file.info(pdf)$size <= 0) {
    detalle <- trimws(paste(salida, collapse = "\n"))
    if (!nzchar(detalle)) detalle <- paste0("código de salida ", estado)
    stop("LibreOffice no pudo crear la vista previa: ", detalle)
  }
  normalizePath(pdf, winslash = "/", mustWork = TRUE)
}
