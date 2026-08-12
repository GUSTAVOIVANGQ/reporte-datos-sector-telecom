# Datos BIT locales

Los CSV no se distribuyen en Git porque son archivos grandes y cambian cuando el CRT publica
ajustes. El programa lee las URL del catálogo
`config/reporte-datos-sector-telecomunicaciones.xlsx` y descarga cada archivo cuando falta.

Este directorio se monta como volumen persistente en Docker. La subcarpeta `_cache_reporte/` se
genera automáticamente y se invalida cuando cambia el tamaño o la fecha del CSV original.
