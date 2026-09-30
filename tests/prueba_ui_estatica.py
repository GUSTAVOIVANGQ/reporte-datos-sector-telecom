#!/usr/bin/env python3
"""Comprobaciones estáticas de los activos de la interfaz institucional."""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    app = (ROOT / "app.R").read_text(encoding="utf-8")
    deploy = (ROOT / "deploy" / "deploy_rhel.sh").read_text(encoding="utf-8")
    server_test = (ROOT / "tests" / "prueba_ui_servidor.R").read_text(encoding="utf-8")
    sources = (ROOT / "fuentes_bit.R").read_text(encoding="utf-8")
    api = (ROOT / "api" / "plumber.R").read_text(encoding="utf-8")
    css = (ROOT / "www" / "app.css").read_text(encoding="utf-8")
    js = (ROOT / "www" / "app.js").read_text(encoding="utf-8")
    logo = ROOT / "www" / "logo_crt_blanco.png"

    required_ids = {
        "reporte-telecom-app",
        "barra_lateral",
        "contenido-principal",
        "nav_generar",
        "nav_historial",
        "nav_fuentes",
        "actualizar_fuentes",
        "nav_configuracion",
        "generar",
        "anio",
        "trimestre",
    }
    missing_ids = sorted(item for item in required_ids if f'"{item}"' not in app)
    if missing_ids:
        raise AssertionError(f"Faltan identificadores de UI: {missing_ids}")

    for asset in ("app.css", "app.js", "logo_crt_blanco.png"):
        if asset not in app:
            raise AssertionError(f"app.R no referencia {asset}")

    for snippet in (
        'prefijo_activos <- "reporte-activos"',
        "shiny::addResourcePath(prefijo_activos, ruta_activos)",
        'url_activo("app.css")',
        'url_activo("app.js")',
        'url_activo("logo_crt_blanco.png")',
    ):
        if snippet not in app:
            raise AssertionError(f"La aplicación no publica correctamente sus activos: {snippet}")

    for snippet in (
        "htmltools::renderTags(ui)",
        "renderizado_ui$head",
        "renderizado_ui$html",
    ):
        if snippet not in server_test:
            raise AssertionError(f"La prueba Shiny no inspecciona el documento completo: {snippet}")

    for public_asset in (
        "/telecom/reporte-activos/app.css",
        "/telecom/reporte-activos/app.js",
        "/telecom/reporte-activos/logo_crt_blanco.png",
    ):
        if public_asset not in deploy:
            raise AssertionError(f"El despliegue no comprueba el activo público: {public_asset}")

    for selector in (
        ".app-sidebar",
        ".workspace-grid",
        ".preview-frame",
        ".workflow-steps",
        ".source-grid",
        ".btn-update-sources",
        ".source-update-status",
        "@media (max-width: 960px)",
        "@media (prefers-reduced-motion: reduce)",
    ):
        if selector not in css:
            raise AssertionError(f"Falta regla de diseño: {selector}")

    if "addCustomMessageHandler(\"navegacion\"" not in js:
        raise AssertionError("El JavaScript no registra la navegación enviada por Shiny")
    if not re.search(r"localStorage\.setItem\(.+theme", js):
        raise AssertionError("El selector de tema no conserva la preferencia")

    if not logo.is_file() or logo.stat().st_size < 10_000:
        raise AssertionError("El logotipo institucional está ausente o incompleto")
    with Image.open(logo) as image:
        if image.format != "PNG" or image.mode != "RGBA":
            raise AssertionError("El logotipo debe conservar su formato PNG con transparencia")
        if image.width < 1000 or image.height < 500:
            raise AssertionError("El logotipo no conserva resolución suficiente")

    if "shiny::small" in app or "shiny::tags$small" not in app:
        raise AssertionError("La interfaz usa una función small incompatible con Shiny")

    for snippet in (
        "descargar_archivo_completo <- function",
        "actualizar_todas_fuentes <- function",
        "reemplazar_lote_fuentes <- function",
        ".actualizacion_fuentes.lock",
    ):
        if snippet not in sources:
            raise AssertionError(f"Falta el control de actualización segura: {snippet}")
    if "@post /v1/fuentes/actualizar" not in api:
        raise AssertionError("La API no expone la actualización transaccional de fuentes")

    print("OK: estructura, activos, accesibilidad adaptable y logotipo de la UI válidos.")


if __name__ == "__main__":
    main()
