paquetes <- c("readxl", "xml2", "zip")
faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltan)) install.packages(faltan, repos = "https://cloud.r-project.org")
message("Paquetes listos: ", paste(paquetes, collapse = ", "))
