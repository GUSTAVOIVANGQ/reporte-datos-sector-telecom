#!/usr/bin/env python3
"""Genera las seis gráficas jerárquicas del reporte institucional.

R conserva la descarga, validación, agregación y construcción del DOCX. Este
programa recibe únicamente dos columnas (grupo, valor) y crea un PNG.
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:  # pragma: no cover - depende del entorno del usuario
    raise SystemExit(
        "Falta Pillow. Instálelo con: python -m pip install -r requirements-python.txt"
    ) from exc


VERSION = "1.1.0"
ANCHO = 2048
ALTURAS = {1: 1483, 2: 1483, 3: 1481, 4: 1481, 5: 1481, 6: 1483}
DPI = 200

COLORES = {
    "América Móvil": "#1E6284",
    "AT&T": "#667489",
    "Telefónica": "#368491",
    "Grupo Walmart": "#1B4044",
    "Grupo Televisa": "#ED8945",
    "Grupo Salinas": "#99B554",
    "Megacable-MCM": "#5844A0",
    "Altán": "#8E244D",
    "Axtel": "#994010",
    "Dish": "#0F9ED5",
    "Otros": "#728781",
}

ETIQUETAS = {
    1: {
        "América Móvil": "América Móvil (Telcel)",
        "AT&T": "AT&T",
        "Telefónica": "Telefónica (Movistar)",
        "Grupo Walmart": "Grupo Walmart (Bait)",
    },
    2: {
        "América Móvil": "América Móvil (Telcel)",
        "AT&T": "AT&T",
        "Telefónica": "Telefónica (Movistar)",
        "Grupo Walmart": "Grupo Walmart (Bait)",
    },
    3: {},
    4: {
        "América Móvil": "América Móvil (Telmex-Telnor)",
        "Grupo Televisa": "Grupo Televisa (Izzi, Sky)",
        "Grupo Salinas": "Grupo Salinas (Totalplay)",
    },
    5: {
        "América Móvil": "América Móvil (Telmex-Telnor)",
        "Grupo Televisa": "Grupo Televisa (Izzi, Sky)",
        "Grupo Salinas": "Grupo Salinas (Totalplay)",
    },
    6: {
        "Grupo Televisa": "Grupo Televisa (Izzi, Sky)",
        "Grupo Salinas": "Grupo Salinas (Totalplay)",
    },
}

GRUPOS_REQUERIDOS = {
    1: {"América Móvil", "AT&T", "Telefónica", "Grupo Walmart", "Otros"},
    2: {"América Móvil", "AT&T", "Telefónica", "Grupo Walmart", "Otros"},
    3: {
        "América Móvil", "AT&T", "Grupo Televisa", "Grupo Salinas",
        "Megacable-MCM", "Telefónica", "Otros", "Grupo Walmart", "Altán", "Axtel",
    },
    4: {"América Móvil", "Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Otros"},
    5: {"América Móvil", "Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Otros"},
    6: {"Grupo Televisa", "Megacable-MCM", "Grupo Salinas", "Dish", "Otros"},
}


@dataclass(frozen=True)
class Rectangulo:
    grupo: str
    xmin: float
    xmax: float
    ymin: float
    ymax: float


def _cociente(numerador: float, denominador: float, contexto: str) -> float:
    if not math.isfinite(denominador) or denominador <= 0:
        raise ValueError(f"No puede calcularse la geometría de {contexto}: denominador no positivo")
    return numerador / denominador


def _suma(valores: dict[str, float], grupos: Iterable[str]) -> float:
    return sum(valores[grupo] for grupo in grupos)


def diseno_rectangulos(valores: dict[str, float], seccion: int) -> list[Rectangulo]:
    """Replica la geometría fija del documento histórico."""
    p = valores.__getitem__
    total = sum(valores.values())

    if seccion == 1:
        x = _cociente(p("América Móvil"), total, "América Móvil")
        resto = total - p("América Móvil")
        h1 = _cociente(p("AT&T"), resto, "AT&T")
        h3 = _cociente(p("Otros"), resto, "Otros")
        xm = x + (1 - x) * _cociente(
            p("Telefónica"), _suma(valores, ("Telefónica", "Grupo Walmart")),
            "Telefónica y Grupo Walmart",
        )
        return [
            Rectangulo("América Móvil", 0, x, 0, 1),
            Rectangulo("AT&T", x, 1, 0, h1),
            Rectangulo("Telefónica", x, xm, h1, 1 - h3),
            Rectangulo("Grupo Walmart", xm, 1, h1, 1 - h3),
            Rectangulo("Otros", x, 1, 1 - h3, 1),
        ]

    if seccion == 2:
        x = _cociente(p("América Móvil"), total, "América Móvil")
        resto = total - p("América Móvil")
        h = _cociente(_suma(valores, ("AT&T", "Telefónica")), resto, "AT&T y Telefónica")
        xt = x + (1 - x) * _cociente(
            p("AT&T"), _suma(valores, ("AT&T", "Telefónica")), "AT&T y Telefónica"
        )
        xb = x + (1 - x) * _cociente(
            p("Grupo Walmart"), _suma(valores, ("Grupo Walmart", "Otros")),
            "Grupo Walmart y Otros",
        )
        return [
            Rectangulo("América Móvil", 0, x, 0, 1),
            Rectangulo("AT&T", x, xt, 0, h),
            Rectangulo("Telefónica", xt, 1, 0, h),
            Rectangulo("Grupo Walmart", x, xb, h, 1),
            Rectangulo("Otros", xb, 1, h, 1),
        ]

    if seccion == 3:
        x = _cociente(p("América Móvil"), total, "América Móvil")
        resto_total = total - p("América Móvil")
        h1 = _cociente(
            _suma(valores, ("AT&T", "Grupo Televisa")), resto_total,
            "AT&T y Grupo Televisa",
        )
        xt = x + (1 - x) * _cociente(
            p("AT&T"), _suma(valores, ("AT&T", "Grupo Televisa")),
            "AT&T y Grupo Televisa",
        )
        nombres_resto = (
            "Grupo Salinas", "Megacable-MCM", "Telefónica", "Otros",
            "Grupo Walmart", "Altán", "Axtel",
        )
        resto = _suma(valores, nombres_resto)
        xm = x + (1 - x) * _cociente(
            _suma(valores, ("Grupo Salinas", "Megacable-MCM")), resto,
            "bloque inferior izquierdo",
        )
        hs = h1 + (1 - h1) * _cociente(
            p("Grupo Salinas"), _suma(valores, ("Grupo Salinas", "Megacable-MCM")),
            "Grupo Salinas y Megacable-MCM",
        )
        resto_derecho = _suma(
            valores, ("Telefónica", "Otros", "Grupo Walmart", "Altán", "Axtel")
        )
        hr = h1 + (1 - h1) * _cociente(
            _suma(valores, ("Telefónica", "Otros")), resto_derecho,
            "bloque inferior derecho",
        )
        xo = xm + (1 - xm) * _cociente(
            p("Telefónica"), _suma(valores, ("Telefónica", "Otros")),
            "Telefónica y Otros",
        )
        xa = xm + (1 - xm) * _cociente(
            _suma(valores, ("Grupo Walmart", "Altán")),
            _suma(valores, ("Grupo Walmart", "Altán", "Axtel")),
            "Grupo Walmart, Altán y Axtel",
        )
        hw = hr + (1 - hr) * _cociente(
            p("Grupo Walmart"), _suma(valores, ("Grupo Walmart", "Altán")),
            "Grupo Walmart y Altán",
        )
        return [
            Rectangulo("América Móvil", 0, x, 0, 1),
            Rectangulo("AT&T", x, xt, 0, h1),
            Rectangulo("Grupo Televisa", xt, 1, 0, h1),
            Rectangulo("Grupo Salinas", x, xm, h1, hs),
            Rectangulo("Megacable-MCM", x, xm, hs, 1),
            Rectangulo("Telefónica", xm, xo, h1, hr),
            Rectangulo("Otros", xo, 1, h1, hr),
            Rectangulo("Grupo Walmart", xm, xa, hr, hw),
            Rectangulo("Altán", xm, xa, hw, 1),
            Rectangulo("Axtel", xa, 1, hr, 1),
        ]

    if seccion in (4, 5):
        x = _cociente(p("América Móvil"), total, "América Móvil")
        resto = total - p("América Móvil")
        h = _cociente(
            _suma(valores, ("Grupo Televisa", "Megacable-MCM")), resto,
            "Grupo Televisa y Megacable-MCM",
        )
        xt = x + (1 - x) * _cociente(
            p("Grupo Televisa"), _suma(valores, ("Grupo Televisa", "Megacable-MCM")),
            "Grupo Televisa y Megacable-MCM",
        )
        xb = x + (1 - x) * _cociente(
            p("Grupo Salinas"), _suma(valores, ("Grupo Salinas", "Otros")),
            "Grupo Salinas y Otros",
        )
        return [
            Rectangulo("América Móvil", 0, x, 0, 1),
            Rectangulo("Grupo Televisa", x, xt, 0, h),
            Rectangulo("Megacable-MCM", xt, 1, 0, h),
            Rectangulo("Grupo Salinas", x, xb, h, 1),
            Rectangulo("Otros", xb, 1, h, 1),
        ]

    x = _cociente(p("Grupo Televisa"), total, "Grupo Televisa")
    resto = total - p("Grupo Televisa")
    h = _cociente(p("Megacable-MCM"), resto, "Megacable-MCM")
    xb = x + (1 - x) * _cociente(
        p("Grupo Salinas"), _suma(valores, ("Grupo Salinas", "Dish", "Otros")),
        "Grupo Salinas, Dish y Otros",
    )
    hd = h + (1 - h) * _cociente(
        p("Dish"), _suma(valores, ("Dish", "Otros")), "Dish y Otros"
    )
    return [
        Rectangulo("Grupo Televisa", 0, x, 0, 1),
        Rectangulo("Megacable-MCM", x, 1, 0, h),
        Rectangulo("Grupo Salinas", x, xb, h, 1),
        Rectangulo("Dish", xb, 1, h, hd),
        Rectangulo("Otros", xb, 1, hd, 1),
    ]


def diseno_rectangulos_flexible(valores: dict[str, float]) -> list[Rectangulo]:
    """Distribución binaria segura cuando algún grupo publicado vale cero."""
    elementos = sorted(
        ((grupo, valor) for grupo, valor in valores.items() if valor > 0),
        key=lambda item: (-item[1], item[0]),
    )
    salida: list[Rectangulo] = []

    def dividir(
        items: list[tuple[str, float]], xmin: float, xmax: float, ymin: float, ymax: float
    ) -> None:
        if len(items) == 1:
            salida.append(Rectangulo(items[0][0], xmin, xmax, ymin, ymax))
            return
        total = sum(valor for _, valor in items)
        acumulado = 0.0
        corte = 1
        mejor = float("inf")
        for indice in range(1, len(items)):
            acumulado += items[indice - 1][1]
            diferencia = abs(total / 2 - acumulado)
            if diferencia < mejor:
                mejor = diferencia
                corte = indice
        izquierda = items[:corte]
        derecha = items[corte:]
        proporcion = sum(valor for _, valor in izquierda) / total
        if (xmax - xmin) >= (ymax - ymin):
            xmedio = xmin + (xmax - xmin) * proporcion
            dividir(izquierda, xmin, xmedio, ymin, ymax)
            dividir(derecha, xmedio, xmax, ymin, ymax)
        else:
            ymedio = ymin + (ymax - ymin) * proporcion
            dividir(izquierda, xmin, xmax, ymin, ymedio)
            dividir(derecha, xmin, xmax, ymedio, ymax)

    if elementos:
        dividir(elementos, 0, 1, 0, 1)
    return salida


def leer_datos(ruta: Path, seccion: int) -> dict[str, float]:
    if not ruta.is_file():
        raise FileNotFoundError(f"No existe el CSV para la gráfica: {ruta}")
    valores: dict[str, float] = {}
    with ruta.open("r", encoding="utf-8-sig", newline="") as archivo:
        lector = csv.DictReader(archivo)
        if lector.fieldnames is None or not {"grupo", "valor"}.issubset(lector.fieldnames):
            raise ValueError("El CSV de la gráfica debe contener las columnas grupo y valor")
        for numero_fila, fila in enumerate(lector, start=2):
            grupo = (fila.get("grupo") or "").strip()
            if not grupo:
                raise ValueError(f"Grupo vacío en la fila {numero_fila}")
            if grupo in valores:
                raise ValueError(f"Grupo duplicado en la gráfica: {grupo}")
            try:
                valor = float(fila.get("valor") or "")
            except ValueError as exc:
                raise ValueError(f"Valor no numérico para {grupo}") from exc
            if not math.isfinite(valor) or valor < 0:
                raise ValueError(f"Valor no válido para {grupo}: {valor}")
            valores[grupo] = valor

    faltantes = sorted(GRUPOS_REQUERIDOS[seccion] - valores.keys())
    if faltantes:
        raise ValueError(f"Faltan grupos en la sección {seccion}: {', '.join(faltantes)}")
    if sum(valores.values()) <= 0:
        raise ValueError(f"La sección {seccion} no contiene un total positivo")
    return valores


def localizar_fuente() -> str:
    configurada = os.environ.get("REPORTE_FUENTE_GRAFICAS", "").strip()
    candidatos = [
        configurada,
        str(Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts" / "arialbd.ttf"),
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "DejaVuSans-Bold.ttf",
        "Arial Bold.ttf",
    ]
    for candidato in candidatos:
        if not candidato:
            continue
        try:
            ImageFont.truetype(candidato, 20)
            return candidato
        except OSError:
            continue
    raise RuntimeError(
        "No se encontró una fuente sans serif en negritas. Defina "
        "REPORTE_FUENTE_GRAFICAS con la ruta de un archivo TTF."
    )


def _ancho_texto(dibujo: ImageDraw.ImageDraw, texto: str, fuente: ImageFont.FreeTypeFont) -> int:
    caja = dibujo.textbbox((0, 0), texto, font=fuente)
    return caja[2] - caja[0]


def ajustar_rotulo(
    dibujo: ImageDraw.ImageDraw,
    texto: str,
    ancho: float,
    alto: float,
    ruta_fuente: str,
) -> tuple[str, ImageFont.FreeTypeFont, int] | None:
    if ancho <= 0 or alto <= 0:
        return None
    palabras = texto.split()
    maximo = round(18 * DPI / 72)
    minimo = max(9, round(3.5 * DPI / 72))

    for tamano in range(maximo, minimo - 1, -1):
        fuente = ImageFont.truetype(ruta_fuente, tamano)
        lineas: list[str] = []
        actual = ""
        for palabra in palabras:
            prueba = f"{actual} {palabra}".strip()
            if actual and _ancho_texto(dibujo, prueba, fuente) > ancho:
                lineas.append(actual)
                actual = palabra
            else:
                actual = prueba
        lineas.append(actual)

        anchos = [_ancho_texto(dibujo, linea, fuente) for linea in lineas]
        espaciado = max(1, round(tamano * 0.18))
        texto_final = "\n".join(lineas)
        caja = dibujo.multiline_textbbox(
            (0, 0), texto_final, font=fuente, spacing=espaciado, align="left"
        )
        alto_texto = caja[3] - caja[1]
        if max(anchos) <= ancho * 0.92 and alto_texto <= alto * 0.90:
            return texto_final, fuente, espaciado
    return None


def generar_grafica(valores: dict[str, float], seccion: int, salida: Path) -> None:
    alto = ALTURAS[seccion]
    imagen = Image.new("RGB", (ANCHO, alto), "white")
    dibujo = ImageDraw.Draw(imagen)
    ruta_fuente = localizar_fuente()

    margen_total_mm = 5.08 if seccion in (3, 4, 5) else 4.0
    margen_total_px = margen_total_mm * DPI / 25.4
    margen_x = margen_total_px / 2
    margen_y = margen_total_px / 2
    ancho_area = ANCHO - margen_total_px
    alto_area = alto - margen_total_px
    padding_x = 0.008 * ancho_area
    padding_y = 0.008 * alto_area
    try:
        geometria = diseno_rectangulos(valores, seccion)
    except ValueError:
        geometria = diseno_rectangulos_flexible(valores)

    for rectangulo in geometria:
        x0 = margen_x + rectangulo.xmin * ancho_area
        x1 = margen_x + rectangulo.xmax * ancho_area
        y0 = margen_y + rectangulo.ymin * alto_area
        y1 = margen_y + rectangulo.ymax * alto_area
        color = "#683E5D" if seccion <= 2 and rectangulo.grupo == "América Móvil" else COLORES[rectangulo.grupo]
        dibujo.rectangle(
            (round(x0), round(y0), round(x1), round(y1)),
            fill=color,
            outline="white",
            width=3,
        )

        valor = valores[rectangulo.grupo] if seccion == 3 else valores[rectangulo.grupo] / 1_000_000
        etiqueta = ETIQUETAS[seccion].get(rectangulo.grupo, rectangulo.grupo)
        rotulo = f"{etiqueta}, {valor:,.2f}"
        ajuste = ajustar_rotulo(
            dibujo,
            rotulo,
            (x1 - x0) - 2 * padding_x,
            (y1 - y0) - 2 * padding_y,
            ruta_fuente,
        )
        if ajuste is None:
            continue
        texto, fuente, espaciado = ajuste
        caja = dibujo.multiline_textbbox(
            (0, 0), texto, font=fuente, spacing=espaciado, align="left"
        )
        origen_x = x0 + padding_x - caja[0]
        origen_y = y1 - padding_y - caja[3]
        dibujo.multiline_text(
            (round(origen_x), round(origen_y)),
            texto,
            font=fuente,
            fill="white",
            spacing=espaciado,
            align="left",
        )

    salida.parent.mkdir(parents=True, exist_ok=True)
    imagen.save(salida, format="PNG", dpi=(DPI, DPI), optimize=True)
    if not salida.is_file() or salida.stat().st_size <= 0:
        raise RuntimeError(f"No se creó correctamente la gráfica {seccion}: {salida}")
    with Image.open(salida) as verificacion:
        if verificacion.size != (ANCHO, alto) or verificacion.format != "PNG":
            raise RuntimeError(f"La gráfica {seccion} no pasó la validación de dimensiones o formato")


def generar_grafica_sin_datos(seccion: int, salida: Path, periodo: str) -> None:
    """Crea un marcador institucional cuando el BIT no publicó esa sección."""
    alto = ALTURAS[seccion]
    imagen = Image.new("RGB", (ANCHO, alto), "white")
    dibujo = ImageDraw.Draw(imagen)
    ruta_fuente = localizar_fuente()
    titulo = ImageFont.truetype(ruta_fuente, 78)
    detalle = ImageFont.truetype(ruta_fuente, 44)
    color = "#2F858B"
    gris = "#60666A"
    caja = (120, 120, ANCHO - 120, alto - 120)
    dibujo.rounded_rectangle(caja, radius=32, outline=color, width=7, fill="#F4F8F8")
    lineas = ["Datos no disponibles", "en el CSV oficial del BIT"]
    if periodo.strip():
        lineas.append(periodo.strip())
    bloques = [(lineas[0], titulo, color), (lineas[1], detalle, gris)]
    if len(lineas) > 2:
        bloques.append((lineas[2], detalle, gris))
    alturas = []
    for texto, fuente, _ in bloques:
        limite = dibujo.textbbox((0, 0), texto, font=fuente)
        alturas.append(limite[3] - limite[1])
    separacion = 34
    y = (alto - sum(alturas) - separacion * (len(bloques) - 1)) / 2
    for (texto, fuente, relleno), altura_texto in zip(bloques, alturas):
        limite = dibujo.textbbox((0, 0), texto, font=fuente)
        ancho_texto = limite[2] - limite[0]
        dibujo.text(((ANCHO - ancho_texto) / 2, y), texto, font=fuente, fill=relleno)
        y += altura_texto + separacion
    salida.parent.mkdir(parents=True, exist_ok=True)
    imagen.save(salida, format="PNG", dpi=(DPI, DPI), optimize=True)


def construir_argumentos() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Genera una gráfica jerárquica PNG para una sección del reporte."
    )
    parser.add_argument("--seccion", type=int, choices=range(1, 7))
    parser.add_argument("--entrada", type=Path)
    parser.add_argument("--salida", type=Path)
    parser.add_argument("--sin-datos", action="store_true")
    parser.add_argument("--periodo", default="")
    parser.add_argument("--check", action="store_true", help="Comprueba Pillow y la fuente.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    argumentos = parser.parse_args()
    if not argumentos.check and (argumentos.seccion is None or argumentos.salida is None):
        parser.error("--seccion y --salida son obligatorios salvo con --check")
    if not argumentos.check and not argumentos.sin_datos and argumentos.entrada is None:
        parser.error("--entrada es obligatorio cuando no se usa --sin-datos")
    return argumentos


def main() -> int:
    argumentos = construir_argumentos()
    try:
        fuente = localizar_fuente()
        if argumentos.check:
            print(f"OK: Pillow disponible; fuente={fuente}")
            return 0
        if argumentos.sin_datos:
            generar_grafica_sin_datos(
                argumentos.seccion, argumentos.salida, argumentos.periodo
            )
        else:
            valores = leer_datos(argumentos.entrada, argumentos.seccion)
            generar_grafica(valores, argumentos.seccion, argumentos.salida)
        print(f"OK: gráfica jerárquica {argumentos.seccion} creada en {argumentos.salida}")
        return 0
    except Exception as exc:  # mensaje breve para que R lo muestre al usuario
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
