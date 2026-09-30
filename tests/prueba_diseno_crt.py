#!/usr/bin/env python3
"""Verifica las seis tablas y conserva el texto frente a un DOCX anterior.
Uso: python tests/prueba_diseno_crt.py REPORTE.docx [REPORTE_ANTERIOR.docx]
"""
import sys
import zipfile
from xml.etree import ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'

def document(path):
    with zipfile.ZipFile(path) as z:
        return ET.fromstring(z.read('word/document.xml'))

def attr(node, name):
    assert node is not None, 'Falta una propiedad de diseño'
    return node.get(W + name)

def text(root):
    return [n.text or '' for n in root.findall('.//w:t', NS)]

root = document(sys.argv[1])
tables = root.findall('.//w:tbl', NS)
assert len(tables) == 6
for section, table in enumerate(tables, 1):
    rows = table.findall('w:tr', NS)
    assert table.find('w:tblPr/w:tblpPr', NS) is None
    assert attr(table.find('w:tblPr/w:tblCellSpacing', NS), 'w') == '0'
    assert rows[0].find('w:trPr/w:tblHeader', NS) is not None
    for i, row in enumerate(rows):
        assert row.find('w:trPr/w:cantSplit', NS) is not None
        assert attr(row.find('w:trPr/w:trHeight', NS), 'hRule') == 'atLeast'
        cells = row.findall('w:tc', NS)
        for j, cell in enumerate(cells):
            props = cell.find('w:tcPr', NS)
            fill = attr(props.find('w:shd', NS), 'fill')
            bottom = props.find('w:tcBorders/w:bottom', NS)
            if i == 0 or i == len(rows) - 1:
                for side in ('left', 'right'):
                    assert attr(props.find('w:tcBorders/w:' + side, NS), 'val') == 'nil', 'Borde lateral en cabecera/TOTAL'
            if i == 0:
                assert fill == ('098F93' if j % 2 == 0 else '1A4043')
                assert attr(bottom, 'color') == fill
            elif i == len(rows) - 1:
                assert fill == '308288'
                # Un solo separador entre "Otros" y TOTAL: lo dibuja la fila anterior.
                assert attr(props.find('w:tcBorders/w:top', NS), 'val') == 'nil'
                prev = rows[i - 1].findall('w:tc', NS)[j].find('w:tcPr/w:tcBorders/w:bottom', NS)
                assert attr(prev, 'color') == '7ECCC2' and attr(prev, 'sz') == '16'
            else:
                assert fill == ('EFEFEF' if j >= len(cells) - 2 and i % 2 == 0 else 'FFFFFF')
                assert attr(bottom, 'color') == '7ECCC2'
                assert attr(bottom, 'sz') == '16'  # 2 puntos, referencia CRT.
                for side in ('left', 'right'):
                    assert attr(props.find('w:tcBorders/w:' + side, NS), 'val') == 'nil'
    # Todos los bloques fusionados siguen presentes y tienen cierre inferior.
    for merge in table.findall('.//w:vMerge', NS):
        assert attr(merge, 'val') in ('restart', 'continue')
if len(sys.argv) > 2:
    assert text(root) == text(document(sys.argv[2])), 'Cambió el texto o alguna cifra'
ids = [n.get(W + 'val') for n in root.findall('.//w:sdtPr/w:id', NS)]
assert len(ids) == len(set(ids)), 'Hay controles de contenido con id repetido'
print('OK: diseño CRT uniforme en seis tablas, cabeceras repetidas y texto conservado.')
