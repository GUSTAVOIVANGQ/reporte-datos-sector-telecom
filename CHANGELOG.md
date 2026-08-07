# Historial de cambios

Todos los cambios notables de este proyecto se documentan en este archivo.

## v3.0.0

- Integración de las seis fuentes BIT del reporte completo.
- Selección de año y generación de uno o todos los trimestres comunes.
- Uso del cierre mensual de marzo, junio, septiembre y diciembre para indicadores mensuales.
- Catálogo Excel de enlaces identificado por nombre canónico de archivo.
- Caché local con descarga automática cuando un CSV no existe.
- Actualización de una fuente cuando le falta el periodo solicitado.
- Diagnóstico anual por sección: ausente, parcial o completo.
- Registro de cobertura, codificación, valores vacíos, negativos, duplicados y MD5.
- Imputación auditable a cero para totales vacíos publicados, sin ocultar la incidencia.
- Conservación de ajustes negativos de ingresos y filas duplicadas oficiales.
- Salida anual con un Word por trimestre, ZIP y archivos de control.
- Interfaz y línea de comandos actualizadas para año, trimestre, red, caché y catálogo.
- Prueba reproducible de cobertura y conciliación de 2024.

## v2.0.0

- Sustitución del Excel manual por el CSV `TD_INGRESOS_TELECOM_ITE_VA.csv`.
- Descarga automática desde el BIT con respaldo local si la red no está disponible.
- Filtrado explícito de registros trimestrales para evitar mezclar observaciones anuales.
- Selección de último periodo, un periodo `AAAAQN` o todos los periodos existentes.
- Generación de un Word por trimestre y ZIP consolidado en modo `todos`.
- Tabla dinámica por grupo, empresa y concesionario.
- Gráfica de participación de los grupos principales.
- Registro de controles de calidad por periodo.
- Nueva interfaz Shiny y nuevas opciones de línea de comandos.
- Alcance limitado a ingresos, única métrica contenida en la nueva fuente.

## v1.3.0

- Interfaz reducida a los campos y acciones esenciales.
- Eliminación del panel de registros de la interfaz.
- Drive y Sheets activados y configurados automáticamente.
- Selección de carpeta de Drive eliminada de la interfaz.
- Botón para abrir la carpeta local de resultados.
- Resumen final con rutas y enlaces en la terminal.
- Registros más descriptivos para autenticación, cargas, archivos y duración.
