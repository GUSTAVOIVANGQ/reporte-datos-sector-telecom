#!/usr/bin/env python3
"""Prueba reproducible del generador Python de las seis gráficas."""

from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


RAIZ = Path(__file__).resolve().parents[1]
SCRIPT = RAIZ / "python" / "graficas_jerarquia.py"
ALTURAS = {1: 1483, 2: 1483, 3: 1481, 4: 1481, 5: 1481, 6: 1483}
DATOS = {
    1: {
        "América Móvil": 83_780_000, "AT&T": 22_860_000,
        "Telefónica": 21_630_000, "Grupo Walmart": 18_060_000, "Otros": 6_150_000,
    },
    2: {
        "América Móvil": 81_090_000, "AT&T": 20_910_000,
        "Telefónica": 9_480_000, "Grupo Walmart": 18_240_000, "Otros": 6_090_000,
    },
    3: {
        "América Móvil": 88_450.81, "AT&T": 20_936.86, "Grupo Televisa": 14_130.48,
        "Grupo Salinas": 9_276.73, "Megacable-MCM": 8_834.29, "Telefónica": 7_329.63,
        "Otros": 5_772.56, "Grupo Walmart": 2_275.67, "Altán": 2_823.52, "Axtel": 3_307.36,
    },
    4: {
        "América Móvil": 10_160_000, "Grupo Televisa": 8_340_000,
        "Megacable-MCM": 6_120_000, "Grupo Salinas": 6_090_000, "Otros": 650_000,
    },
    5: {
        "América Móvil": 11_210_000, "Grupo Televisa": 5_970_000,
        "Megacable-MCM": 5_320_000, "Grupo Salinas": 5_310_000, "Otros": 1_190_000,
    },
    6: {
        "Grupo Televisa": 11_550_000, "Megacable-MCM": 5_850_000,
        "Grupo Salinas": 2_480_000, "Dish": 1_130_000, "Otros": 780_000,
    },
}


class GraficasJerarquiaTest(unittest.TestCase):
    def test_seis_png(self) -> None:
        with tempfile.TemporaryDirectory(prefix="graficas_python_") as temporal:
            carpeta = Path(temporal)
            for seccion, valores in DATOS.items():
                entrada = carpeta / f"datos_{seccion}.csv"
                salida = carpeta / f"grafica_{seccion}.png"
                with entrada.open("w", encoding="utf-8", newline="") as archivo:
                    escritor = csv.DictWriter(archivo, fieldnames=("grupo", "valor"))
                    escritor.writeheader()
                    for grupo, valor in valores.items():
                        escritor.writerow({"grupo": grupo, "valor": valor})
                proceso = subprocess.run(
                    [
                        sys.executable, str(SCRIPT), "--seccion", str(seccion),
                        "--entrada", str(entrada), "--salida", str(salida),
                    ],
                    check=False,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                )
                self.assertEqual(proceso.returncode, 0, proceso.stdout + proceso.stderr)
                self.assertTrue(salida.is_file() and salida.stat().st_size > 0)
                with Image.open(salida) as imagen:
                    self.assertEqual(imagen.format, "PNG")
                    self.assertEqual(imagen.size, (2048, ALTURAS[seccion]))

    def test_rechaza_grupo_faltante(self) -> None:
        with tempfile.TemporaryDirectory(prefix="grafica_invalida_") as temporal:
            carpeta = Path(temporal)
            entrada = carpeta / "datos.csv"
            salida = carpeta / "grafica.png"
            with entrada.open("w", encoding="utf-8", newline="") as archivo:
                escritor = csv.DictWriter(archivo, fieldnames=("grupo", "valor"))
                escritor.writeheader()
                escritor.writerow({"grupo": "América Móvil", "valor": 1})
            proceso = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--seccion", "1",
                    "--entrada", str(entrada), "--salida", str(salida),
                ],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertNotEqual(proceso.returncode, 0)
            self.assertIn("Faltan grupos", proceso.stderr)
            self.assertFalse(salida.exists())

    def test_marcador_sin_datos(self) -> None:
        with tempfile.TemporaryDirectory(prefix="grafica_sin_datos_") as temporal:
            salida = Path(temporal) / "sin_datos.png"
            proceso = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--seccion", "5",
                    "--salida", str(salida), "--sin-datos", "--periodo", "2025Q4",
                ],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(proceso.returncode, 0, proceso.stdout + proceso.stderr)
            with Image.open(salida) as imagen:
                self.assertEqual(imagen.size, (2048, ALTURAS[5]))

    def test_grupos_en_cero_usan_diseno_flexible(self) -> None:
        with tempfile.TemporaryDirectory(prefix="grafica_ceros_") as temporal:
            carpeta = Path(temporal)
            entrada = carpeta / "datos.csv"
            salida = carpeta / "grafica.png"
            valores = dict(DATOS[4])
            valores["Grupo Televisa"] = 0
            valores["Megacable-MCM"] = 0
            with entrada.open("w", encoding="utf-8", newline="") as archivo:
                escritor = csv.DictWriter(archivo, fieldnames=("grupo", "valor"))
                escritor.writeheader()
                for grupo, valor in valores.items():
                    escritor.writerow({"grupo": grupo, "valor": valor})
            proceso = subprocess.run(
                [
                    sys.executable, str(SCRIPT), "--seccion", "4",
                    "--entrada", str(entrada), "--salida", str(salida),
                ],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(proceso.returncode, 0, proceso.stdout + proceso.stderr)
            self.assertTrue(salida.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
