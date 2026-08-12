# Despliegue en RHEL 9.7

## Requisitos del sistema

`plumber` usa el paquete R `sodium`; al compilarlo en RHEL se requieren los encabezados de
`libsodium-devel`, disponibles en EPEL 9. En una instalación de RHEL sin EPEL habilitado ejecute una
sola vez:

```bash
sudo subscription-manager repos \
  --enable="codeready-builder-for-rhel-9-$(arch)-rpms"
sudo dnf install -y \
  https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
```

Después instale todos los requisitos:

```bash
bash deploy/requisitos_rhel.sh
```

La instalación de paquetes requiere acceso administrativo y repositorios RHEL habilitados.
LibreOffice se instala para la previsualización PDF.

Compruebe la dependencia criptográfica antes del despliegue con:

```bash
pkg-config --modversion libsodium
```

## Despliegue

Desde la carpeta descomprimida:

```bash
APP_USER=gustavo.garcia \
APP_DIR=/data/gustavo.garcia/reporte-telecom \
APP_PORT=3838 \
API_PORT=8000 \
SERVER_NAME=172.17.42.163 \
bash deploy/deploy_rhel.sh
```

El instalador:

1. conserva `entrada/datos_bit/*.csv` y `salidas` existentes;
2. restaura las dependencias R con `renv`;
3. crea `.venv` e instala Pillow 11.3.0;
4. configura `PYTHONPATH` con `purelib` y `platlib` para RHEL;
5. usa `APP_DIR/tmp-build`, evitando `/tmp` montado con `noexec`;
6. instala los servicios Shiny/API, Nginx, logrotate, alertas y un health check de proceso y puerto
   cada dos minutos, sin interrumpir reportes o vistas previas en ejecución;
7. ejecuta los health checks finales.

## Verificación

```bash
sudo systemctl status reporte-telecom reporte-telecom-api
sudo journalctl -u reporte-telecom -n 100 --no-pager
sudo journalctl -u reporte-telecom-api -n 100 --no-pager
curl -fsS http://127.0.0.1:8000/salud
curl -fsS http://172.17.42.163/telecom/api/salud
```

- UI: `http://172.17.42.163/telecom/`
- API: `http://172.17.42.163/telecom/api/`
- Swagger: `http://172.17.42.163/telecom/api/__docs__/`

## Alertas

Agregue al final de `/etc/sysconfig/reporte-telecom`:

```text
REPORTE_ALERT_WEBHOOK_URL=https://servidor/endpoint-seguro
```

Después reinicie ambos servicios. No guarde la URL del webhook en Git.

## Actualización

Vuelva a ejecutar `deploy/deploy_rhel.sh` desde una nueva versión. El código se actualiza, pero los
CSV, cachés y resultados permanecen en `/data/gustavo.garcia/reporte-telecom`.
