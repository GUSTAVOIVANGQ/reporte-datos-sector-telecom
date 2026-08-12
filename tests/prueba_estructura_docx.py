#!/usr/bin/env python3
"""Valida agrupación por Empresa e hipervínculos de fuente en un DOCX generado."""

from __future__ import annotations

import re
import sys
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET

W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS = {"w": W, "r": R}


def text(node: ET.Element) -> str:
    return "".join(item.text or "" for item in node.findall(".//w:t", NS)).strip()


def attr(node: ET.Element, namespace: str, name: str) -> str | None:
    return node.get(f"{{{namespace}}}{name}")


def validate(path: Path) -> None:
    with zipfile.ZipFile(path) as zf:
        document = ET.fromstring(zf.read("word/document.xml"))
        rels = ET.fromstring(zf.read("word/_rels/document.xml.rels"))

    relationships = {rel.get("Id"): rel for rel in list(rels)}
    source_paragraphs = [
        paragraph for paragraph in document.findall(".//w:p", NS)
        if text(paragraph).startswith("Fuente:")
    ]
    if len(source_paragraphs) != 12:
        raise AssertionError(f"Se esperaban 12 pies de fuente; se encontraron {len(source_paragraphs)}")
    for paragraph in source_paragraphs:
        links = paragraph.findall("./w:hyperlink", NS)
        if len(links) != 1:
            raise AssertionError("Cada pie de fuente debe contener exactamente un hipervínculo")
        rid = attr(links[0], R, "id")
        rel = relationships.get(rid)
        target = None if rel is None else rel.get("Target")
        if rel is None or rel.get("TargetMode") != "External" or not target.startswith("https://"):
            raise AssertionError("El hipervínculo no tiene una relación externa HTTPS válida")
        if text(links[0]) != target:
            raise AssertionError("El texto visible del hipervínculo no coincide con su URL")
        colors = [attr(item, W, "val") for item in links[0].findall(".//w:color", NS)]
        underlines = [attr(item, W, "val") for item in links[0].findall(".//w:u", NS)]
        if "0000FF" not in colors or "single" not in underlines:
            raise AssertionError("El enlace no tiene el formato azul subrayado esperado")

    tables_checked = 0
    for table in document.findall(".//w:tbl", NS):
        tags = [attr(item, W, "val") or "" for item in table.findall(".//w:tag", NS)]
        match = next((re.match(r"T(0[1-6])_", tag) for tag in tags if re.match(r"T(0[1-6])_", tag)), None)
        if match is None:
            continue
        tables_checked += 1
        section = int(match.group(1))
        rows = table.findall("./w:tr", NS)[1:]
        current_group = ""
        blocks: list[tuple[str, str]] = []
        for row in rows:
            cells = row.findall("./w:tc", NS)
            if not cells:
                continue
            values = [text(cell) for cell in cells]
            if values[0] == "TOTAL":
                break
            if values[0]:
                current_group = values[0]
            company_index = 1 if section <= 2 else 2
            company_status = cells[company_index].find("./w:tcPr/w:vMerge", NS)
            if values[company_index]:
                blocks.append((current_group, values[company_index]))
            elif company_status is None or attr(company_status, W, "val") != "continue":
                continue
        duplicates = [key for key, count in Counter(blocks).items() if count > 1 and all(key)]
        if duplicates:
            raise AssertionError(f"Tabla {section}: Empresa dividida en bloques: {duplicates}")
    if tables_checked != 6:
        raise AssertionError(f"Se esperaban 6 tablas del reporte; se validaron {tables_checked}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Uso: python tests/prueba_estructura_docx.py REPORTE.docx")
    target = Path(sys.argv[1]).resolve()
    validate(target)
    print("OK: empresas agrupadas y 12 hipervínculos de fuente válidos.")
