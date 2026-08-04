# Control de cambios del proyecto

| Etapa | Estado | Evidencia |
|---|---|---|
| Plan general 1–5 | Completado | Reglas y monitoreo incluidos en el Excel |
| Excel de entrada de ejemplo | Completado | Seis tablas y parámetros del periodo |
| Plantilla Word automatizable | Completado | 249 celdas, 63 tipos de texto y 6 imágenes identificadas |
| Código R | Corregido | UTF-8 validado, DOCX sin duplicados y gráficas fieles al diseño de referencia |
| Prueba estructural del Word | Completado | Archivo válido y conservación de 19 páginas |
| Prueba directa con R | Pendiente | El entorno de construcción no dispone de R; ejecutar en el equipo de operación |

El programa crea una carpeta nueva por ejecución y nunca sobrescribe el Excel ni la plantilla.

Corrección 2026-08-04: se eliminó la duplicación de archivos internos del DOCX, se forzó la escritura UTF-8 y se sustituyó el diseño genérico de treemap por composiciones deterministas para las seis secciones.

Corrección 2026-08-04 (segunda ejecución): `zipr()` aplanaba las carpetas internas del DOCX porque su modo predeterminado es `cherry-pick`. Se cambió a `zip()` con `mode = "mirror"` y se añadió un diagnóstico que enumera las rutas faltantes si la estructura no es válida.
