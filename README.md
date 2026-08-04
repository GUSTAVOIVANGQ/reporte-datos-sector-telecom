# Automatización del Reporte de Telecomunicaciones

Este proyecto toma el Excel procesado, crea primero seis copias CSV y seis gráficas PNG de monitoreo y después genera una copia actualizada de la plantilla Word. Nunca sobrescribe los archivos de entrada. Las gráficas conservan la composición, paleta, márgenes y tamaño tipográfico del documento de referencia.

## Primera ejecución

1. Instale R 4.3 o superior.
2. Abra una terminal dentro de esta carpeta.
3. Ejecute `Rscript instalar_paquetes.R` una sola vez.
4. Ejecute `Rscript generar_reporte.R` o, en Windows, abra `ejecutar_reporte.bat`.

Los resultados se guardan en una carpeta nueva dentro de `salidas/`, con fecha y hora. Cada ejecución contiene:

- `monitoreo/tabla_1.csv` a `tabla_6.csv`.
- `monitoreo/grafica_1.png` a `grafica_6.png`.
- `control_ejecucion.csv`.
- El reporte Word actualizado.

## Google Drive opcional

Si Google Drive para escritorio está instalado, indique la carpeta local sincronizada antes de ejecutar:

PowerShell:

```powershell
$env:REPORTE_DRIVE="G:\Mi unidad\Reportes de Telecomunicaciones"
Rscript generar_reporte.R
```

macOS o Linux:

```bash
export REPORTE_DRIVE="$HOME/Google Drive/Reportes de Telecomunicaciones"
Rscript generar_reporte.R
```

Las tablas y gráficas se copian a esa carpeta antes de crear el Word. Si no se configura, las copias se conservan solamente en `salidas/.../monitoreo` y el control lo registra como `Local`.

## Cambiar los archivos de entrada

La forma normal es reemplazar el Excel de `entrada/` manteniendo el mismo nombre y estructura. También pueden pasarse rutas distintas:

```bash
Rscript generar_reporte.R ruta/entrada.xlsx ruta/plantilla.docx ruta/salidas
```

No cambie los nombres de las hojas ni las dimensiones de las seis tablas. El script se detiene si la estructura o los totales no coinciden.

El proceso también se detiene si el XML contiene texto con codificación inválida o si el DOCX queda con archivos duplicados o sin sus carpetas internas. El empaquetado usa explícitamente el modo `mirror` para conservar rutas como `word/document.xml`. Esto evita producir documentos que Word no pueda abrir.

## Revisión final

Abra el Word generado y confirme que conserva 19 páginas. Revise especialmente tablas extensas, saltos de página y las seis gráficas antes de publicar el reporte.
