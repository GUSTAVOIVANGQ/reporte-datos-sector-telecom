# Datos BIT locales

En el repositorio Git estos CSV normalmente no se distribuyen porque cambian cuando el CRT publica
ajustes. Este paquete de entrega **sí incluye los seis archivos usados para validar 2026Q1**, con el
fin de permitir una reproducción sin red. El programa sigue leyendo las URL del catálogo
`config/reporte-datos-sector-telecomunicaciones.xlsx` y puede actualizar o descargar cada archivo.

Este directorio se monta como volumen persistente en Docker. La subcarpeta `_cache_reporte/` se
genera automáticamente y se invalida cuando cambia el tamaño o la fecha del CSV original.
