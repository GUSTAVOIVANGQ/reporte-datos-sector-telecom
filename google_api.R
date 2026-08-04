# Respaldo opcional mediante OAuth con una cuenta personal de Google.
respaldar_google <- function(archivo_excel, salida_word, carpeta_ejecucion,
                             carpeta_monitoreo, id_ejecucion, tablas,
                             registrar, asegurar_paquetes) {
  correo <- trimws(Sys.getenv("GOOGLE_USER_EMAIL", ""))
  carpeta_id <- trimws(Sys.getenv("GOOGLE_DRIVE_FOLDER_ID", ""))
  carpeta_nombre <- trimws(Sys.getenv(
    "GOOGLE_DRIVE_FOLDER_NAME",
    "Reporte_de_Datos_del_Sector_de_Telecomunicaciones"
  ))

  variable_logica <- function(nombre, defecto = FALSE) {
    valor_defecto <- if (defecto) "true" else "false"
    tolower(trimws(Sys.getenv(nombre, valor_defecto))) %in% c("1", "true", "si", "sí", "yes")
  }
  google_activo <- variable_logica("GOOGLE_ENABLED", TRUE)
  subir_archivos <- variable_logica("GOOGLE_UPLOAD_FILES", TRUE)
  crear_sheets <- variable_logica("GOOGLE_CREATE_SHEETS", TRUE)

  if (!google_activo) {
    registrar("Google", "Omitido", "Integración opcional desactivada; la salida local está completa")
    return(invisible(list(ok = TRUE, omitido = TRUE)))
  }
  if (!subir_archivos && !crear_sheets) {
    registrar("Google", "Omitido", "No se seleccionó ninguna salida de Google")
    return(invisible(list(ok = TRUE, omitido = TRUE)))
  }
  if (!nzchar(carpeta_id) && !nzchar(carpeta_nombre)) {
    registrar("Google", "Advertencia", "Falta el nombre o el ID de la carpeta; se conservó la salida local")
    return(invisible(list(ok = FALSE, omitido = FALSE)))
  }
  if (!asegurar_paquetes(c("googledrive", "googlesheets4"), obligatorios = FALSE)) {
    registrar("Google", "Advertencia", "No fue posible instalar los paquetes de Google; se conservó la salida local")
    return(invisible(list(ok = FALSE, omitido = FALSE)))
  }

  mensaje_seguro <- function(e) conditionMessage(e)
  preparar_tabla <- function(x) {
    x <- as.data.frame(x, check.names = FALSE, stringsAsFactors = FALSE)
    nombres <- names(x)
    vacios <- is.na(nombres) | !nzchar(trimws(nombres))
    nombres[vacios] <- paste0("Columna_", which(vacios))
    names(x) <- make.unique(nombres, sep = "_")
    x
  }
  localizar_destino <- function() {
    if (nzchar(carpeta_id)) {
      encontrado <- googledrive::drive_get(googledrive::as_id(carpeta_id))
      if (nrow(encontrado) != 1) stop("El ID no identifica una carpeta accesible de Drive")
      registrar("Carpeta Google", "Completado", paste("Carpeta localizada por ID:", carpeta_id))
      return(encontrado)
    }

    nombre_q <- gsub("'", "\\'", carpeta_nombre, fixed = TRUE)
    candidatos <- googledrive::drive_find(
      type = "folder", corpus = "user",
      q = paste0("name = '", nombre_q, "'"), n_max = Inf
    )
    candidatos <- candidatos[trimws(candidatos$name) == carpeta_nombre, , drop = FALSE]
    if (!nrow(candidatos)) {
      creada <- googledrive::drive_mkdir(carpeta_nombre, overwrite = FALSE)
      registrar(
        "Carpeta Google", "Completado",
        paste("Carpeta creada en Mi unidad:", carpeta_nombre)
      )
      return(creada)
    }
    if (nrow(candidatos) > 1) {
      candidatos <- candidatos[order(as.character(candidatos$id)), , drop = FALSE]
      registrar(
        "Carpeta Google", "Advertencia",
        paste(
          "Hay varias carpetas con el nombre predeterminado; se usará automáticamente el ID",
          candidatos$id[[1]]
        )
      )
    } else {
      registrar(
        "Carpeta Google", "Completado",
        paste("Carpeta predeterminada localizada:", carpeta_nombre)
      )
    }
    candidatos[1, , drop = FALSE]
  }

  resultado <- tryCatch({
    options(googledrive_quiet = TRUE, googlesheets4_quiet = TRUE)
    registrar(
      "Google", "Inicio",
      paste("Destino automático:", carpeta_nombre, "| Drive: activo | Sheets: activo")
    )
    objetivo <- if (nzchar(correo)) correo else TRUE
    alcances_google <- c(
      "https://www.googleapis.com/auth/drive",
      "https://www.googleapis.com/auth/spreadsheets"
    )
    googledrive::drive_auth(
      email = objetivo, scopes = alcances_google, cache = TRUE
    )
    googlesheets4::gs4_auth(token = googledrive::drive_token())
    googledrive::drive_find(n_max = 1)
    usuario <- googledrive::drive_user()
    correo_autorizado <- if (!is.null(usuario$emailAddress)) {
      usuario$emailAddress
    } else {
      correo
    }
    registrar(
      "Cuenta Google", "Completado",
      paste("OAuth y permisos verificados para", correo_autorizado)
    )

    destino_base <- localizar_destino()
    destino <- googledrive::drive_mkdir(
      id_ejecucion, path = destino_base, overwrite = FALSE
    )
    enlace_carpeta <- googledrive::drive_link(destino)[[1]]
    enlace_sheets <- character()
    enlace_excel_drive <- character()
    enlace_word_drive <- character()
    registrar(
      "Carpeta de ejecución", "Completado",
      paste("Subcarpeta creada:", id_ejecucion)
    )

    if (subir_archivos) {
      destino_monitoreo <- googledrive::drive_mkdir(
        "monitoreo", path = destino, overwrite = FALSE
      )
      for (archivo in unique(c(archivo_excel, salida_word))) {
        subido <- googledrive::drive_upload(
          archivo, path = destino, name = basename(archivo), overwrite = FALSE
        )
        enlace_archivo <- googledrive::drive_link(subido)[[1]]
        if (identical(normalizePath(archivo), normalizePath(archivo_excel))) {
          enlace_excel_drive <- enlace_archivo
        }
        if (identical(normalizePath(archivo), normalizePath(salida_word))) {
          enlace_word_drive <- enlace_archivo
        }
      }
      archivos_monitoreo <- list.files(carpeta_monitoreo, full.names = TRUE)
      for (archivo in archivos_monitoreo) {
        googledrive::drive_upload(
          archivo, path = destino_monitoreo, name = basename(archivo), overwrite = FALSE
        )
      }
      registrar(
        "Google Drive", "Completado",
        paste(
          "Excel, Word y", length(archivos_monitoreo),
          "archivos de monitoreo subidos mediante API"
        )
      )
    } else {
      registrar("Google Drive", "Omitido", "La carga de archivos fue desactivada por el usuario")
    }

    if (crear_sheets) {
      estado_sheets <- tryCatch({
        archivo_sheet <- googledrive::drive_create(
          paste0("Monitoreo_", id_ejecucion),
          path = destino, type = "spreadsheet", overwrite = FALSE
        )
        sheet_id <- googlesheets4::as_sheets_id(archivo_sheet$id[[1]])
        control_sheet <- utils::read.csv(
          file.path(carpeta_ejecucion, "control_ejecucion.csv"),
          check.names = FALSE, fileEncoding = "UTF-8"
        )
        googlesheets4::sheet_write(control_sheet, ss = sheet_id, sheet = "Control")
        for (i in seq_len(6)) {
          googlesheets4::sheet_write(
            preparar_tabla(tablas[[i]]), ss = sheet_id, sheet = paste0("Tabla_", i)
          )
        }
        if ("Sheet1" %in% googlesheets4::sheet_names(sheet_id)) {
          googlesheets4::sheet_delete(sheet_id, "Sheet1")
        }
        control_sheet <- rbind(control_sheet, data.frame(
          Etapa = "Google Sheets", Estado = "Completado",
          Fecha = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          Detalle = "Libro creado con Control y seis tablas",
          stringsAsFactors = FALSE
        ))
        googlesheets4::sheet_write(control_sheet, ss = sheet_id, sheet = "Control")
        enlace_sheets <- googledrive::drive_link(archivo_sheet)[[1]]
        registrar(
          "Google Sheets", "Completado",
          "Libro creado con siete pestañas: Control y Tabla_1 a Tabla_6"
        )
        TRUE
      }, error = function(e) {
        registrar("Google Sheets", "Advertencia", mensaje_seguro(e))
        FALSE
      })
    } else {
      estado_sheets <- TRUE
      registrar("Google Sheets", "Omitido", "La copia de tablas fue desactivada por el usuario")
    }

    ruta_excel_local <- normalizePath(archivo_excel, winslash = "/", mustWork = FALSE)
    ruta_word_local <- normalizePath(salida_word, winslash = "/", mustWork = FALSE)
    lineas_enlaces <- c(
      paste("Excel local:", ruta_excel_local),
      paste("Word local:", ruta_word_local),
      paste("Carpeta Drive:", enlace_carpeta)
    )
    if (length(enlace_excel_drive)) {
      lineas_enlaces <- c(lineas_enlaces, paste("Excel en Drive:", enlace_excel_drive))
    }
    if (length(enlace_word_drive)) {
      lineas_enlaces <- c(lineas_enlaces, paste("Word en Drive:", enlace_word_drive))
    }
    if (length(enlace_sheets)) {
      lineas_enlaces <- c(lineas_enlaces, paste("Google Sheets:", enlace_sheets))
    }
    ruta_enlaces <- file.path(carpeta_ejecucion, "enlaces_google.txt")
    conexion_enlaces <- file(ruta_enlaces, open = "w", encoding = "UTF-8")
    writeLines(enc2utf8(lineas_enlaces), conexion_enlaces, useBytes = TRUE)
    close(conexion_enlaces)

    registrar("Excel local", "Información", ruta_excel_local)
    registrar("Word local", "Información", ruta_word_local)
    registrar("Carpeta Drive", "Información", enlace_carpeta)
    if (length(enlace_excel_drive)) {
      registrar("Excel en Drive", "Información", enlace_excel_drive)
    }
    if (length(enlace_word_drive)) {
      registrar("Word en Drive", "Información", enlace_word_drive)
    }
    if (length(enlace_sheets)) {
      registrar("Google Sheets", "Información", enlace_sheets)
    }

    if (subir_archivos) {
      for (archivo in c(
        file.path(carpeta_ejecucion, "control_ejecucion.csv"),
        file.path(carpeta_ejecucion, "ejecucion.log"),
        ruta_enlaces
      )) {
        googledrive::drive_upload(
          archivo, path = destino, name = basename(archivo), overwrite = FALSE
        )
      }
    }
    invisible(list(
      ok = isTRUE(estado_sheets), omitido = FALSE,
      carpeta = enlace_carpeta,
      sheets = if (length(enlace_sheets)) enlace_sheets else NA_character_,
      excel_drive = if (length(enlace_excel_drive)) enlace_excel_drive else NA_character_,
      word_drive = if (length(enlace_word_drive)) enlace_word_drive else NA_character_
    ))
  }, error = function(e) {
    detalle <- mensaje_seguro(e)
    if (grepl("insufficient|403|permission", detalle, ignore.case = TRUE)) {
      detalle <- paste(
        "Permisos de Google insuficientes.",
        "Vuelva a generar y acepte la renovación de permisos en el navegador."
      )
    }
    registrar(
      "Google", "Advertencia",
      paste(detalle, "La salida local permanece completa.")
    )
    invisible(list(ok = FALSE, omitido = FALSE))
  })

  invisible(resultado)
}
