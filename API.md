# API v1

La documentación ejecutable está disponible en `/__docs__/`. El prefijo público recomendado en
RHEL es `/telecom/api/`.

## Generación

`POST /v1/reportes` acepta JSON:

```json
{
  "anio": 2024,
  "trimestre": "todos",
  "actualizar": false,
  "permitir_red": true
}
```

`trimestre` admite `todos`, `1`, `2`, `3`, `4`, `Q1`, `Q2`, `Q3` o `Q4`. Una respuesta exitosa
incluye el identificador de ejecución, los trimestres generados, advertencias y la ruta de descarga.

## Estados HTTP

| Código | Significado |
|---:|---|
| 200 | Consulta o generación completada |
| 302 | Redirección `/docs` a Swagger |
| 400 | Año o parámetros inválidos |
| 404 | Ejecución o archivo no encontrado |
| 422 | Fuentes insuficientes o error de generación |
| 503 | Dependencia crítica no disponible en `/salud` |

La API no expone rutas absolutas del servidor. La descarga valida el identificador y limita las
extensiones a DOCX, ZIP, CSV y TXT.
