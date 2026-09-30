#!/usr/bin/env python3
"""Verifica que las 6 tablas y las 6 gráficas cierren con la misma estructura:
párrafo "Fuente:" (sin saltos de línea) seguido de párrafo "Nota(s):" con
'“Otros” incluye N empresas' (N entero).
Uso: python tests/prueba_notas_uniformes.py REPORTE.docx
"""
import re
import sys
import zipfile
from xml.etree import ElementTree as ET

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'
root = ET.fromstring(zipfile.ZipFile(sys.argv[1]).read('word/document.xml'))
body = list(root.find('w:body', NS))
text = lambda e: ''.join(t.text or '' for t in e.iter(W + 't'))
bloques = 0
for i, e in enumerate(body):
    t = text(e).strip()
    if e.tag != W + 'p' or not t.startswith('Fuente:'):
        continue
    bloques += 1
    assert e.find('.//w:br', NS) is None, f'Fuente y Nota en el mismo párrafo: {t[:50]}'
    nota = text(body[i + 1]).strip()
    assert re.match(r'^Notas?:\s+“Otros” incluye \d+ empresas\.', nota), \
        f'Falta o es inválida la nota tras: {t[-60:]} -> {nota[:60]!r}'
assert bloques == 12, f'Se esperaban 12 bloques Fuente/Nota y hay {bloques}'
print('OK: 12 bloques (6 tablas + 6 gráficas) con Fuente y Nota uniformes.')
