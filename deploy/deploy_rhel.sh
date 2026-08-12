#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_USER="${APP_USER:-$(id -un)}"
APP_GROUP="${APP_GROUP:-$(id -gn "${APP_USER}")}"
APP_DIR="${APP_DIR:-/data/${APP_USER}/reporte-telecom}"
APP_PORT="${APP_PORT:-3838}"
API_PORT="${API_PORT:-8000}"
SERVER_NAME="${SERVER_NAME:-172.17.42.163}"
TMP_BUILD="${APP_DIR}/tmp-build"

command -v Rscript >/dev/null || { echo "Falta Rscript; ejecute deploy/requisitos_rhel.sh" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Falta Python 3" >&2; exit 1; }
command -v libreoffice >/dev/null || { echo "Falta LibreOffice; ejecute deploy/requisitos_rhel.sh" >&2; exit 1; }
command -v pkg-config >/dev/null || { echo "Falta pkg-config; ejecute deploy/requisitos_rhel.sh" >&2; exit 1; }
pkg-config --exists libsodium || {
  echo "Falta libsodium-devel; ejecute deploy/requisitos_rhel.sh antes de restaurar renv." >&2
  exit 1
}

sudo install -d -o "${APP_USER}" -g "${APP_GROUP}" -m 0750 \
  "${APP_DIR}" "${APP_DIR}/entrada/datos_bit" "${APP_DIR}/salidas" "${TMP_BUILD}"

if [[ "$(realpath "${SOURCE_DIR}")" != "$(realpath "${APP_DIR}")" ]]; then
  echo "Copiando código a ${APP_DIR}; se conservan CSV y salidas existentes..."
  (
    cd "${SOURCE_DIR}"
    find . -type f \
      ! -path './.git/*' \
      ! -path './entrada/datos_bit/*.csv' \
      ! -path './entrada/datos_bit/_cache_reporte/*' \
      ! -path './salidas/*' -print0 | tar --null --files-from=- -cf -
  ) | \
      sudo -u "${APP_USER}" tar -xf - -C "${APP_DIR}"
else
  echo "El proyecto ya está en APP_DIR; no es necesario copiarlo."
fi

sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"
sudo -u "${APP_USER}" env APP_DIR="${APP_DIR}" TMPDIR="${TMP_BUILD}" TMP="${TMP_BUILD}" TEMP="${TMP_BUILD}" \
  Rscript "${APP_DIR}/deploy/install_server.R"

if [[ ! -x "${APP_DIR}/.venv/bin/python" ]]; then
  sudo -u "${APP_USER}" python3 -m venv "${APP_DIR}/.venv"
fi
sudo -u "${APP_USER}" env TMPDIR="${TMP_BUILD}" \
  "${APP_DIR}/.venv/bin/python" -m pip install --no-cache-dir -r "${APP_DIR}/requirements-python.txt"

PYTHON_SITE="$("${APP_DIR}/.venv/bin/python" - <<'PY'
import os, sysconfig
paths = [sysconfig.get_path("purelib"), sysconfig.get_path("platlib")]
print(os.pathsep.join(dict.fromkeys(path for path in paths if path)))
PY
)"
sudo -u "${APP_USER}" env PYTHONPATH="${PYTHON_SITE}" \
  "${APP_DIR}/.venv/bin/python" -c 'from PIL import Image, ImageDraw, ImageFont; print("Pillow OK", Image.__version__)'

env_tmp="$(mktemp "${TMP_BUILD}/env.XXXXXXXXXX")"
trap 'rm -f "${env_tmp}"' EXIT
cat >"${env_tmp}" <<EOF
REPORTE_RAIZ=${APP_DIR}
REPORTE_MODO_SERVIDOR=true
REPORTE_INSTALL_PACKAGES=false
REPORTE_CRAN=https://packagemanager.posit.co/cran/2026-08-03
REPORTE_R_LIB=${APP_DIR}/.R/library
REPORTE_PYTHON=${APP_DIR}/.venv/bin/python
REPORTE_PYTHONPATH=${PYTHON_SITE}
PYTHONPATH=${PYTHON_SITE}
REPORTE_LIBREOFFICE=/usr/bin/libreoffice
REPORTE_DATOS_DIR=${APP_DIR}/entrada/datos_bit
REPORTE_SALIDAS_DIR=${APP_DIR}/salidas
REPORTE_OBSERVABILIDAD_DIR=${APP_DIR}/salidas/observabilidad
REPORTE_CATALOGO=${APP_DIR}/config/reporte-datos-sector-telecomunicaciones.xlsx
REPORTE_HOST=127.0.0.1
REPORTE_PORT=${APP_PORT}
REPORTE_API_HOST=127.0.0.1
REPORTE_API_PORT=${API_PORT}
TMPDIR=${TMP_BUILD}
TMP=${TMP_BUILD}
TEMP=${TMP_BUILD}
EOF
sudo install -m 0640 -o root -g "${APP_GROUP}" "${env_tmp}" /etc/sysconfig/reporte-telecom

render_template() {
  sed -e "s|__APP_USER__|${APP_USER}|g" -e "s|__APP_GROUP__|${APP_GROUP}|g" \
      -e "s|__APP_DIR__|${APP_DIR}|g" -e "s|__APP_PORT__|${APP_PORT}|g" \
      -e "s|__API_PORT__|${API_PORT}|g" -e "s|__SERVER_NAME__|${SERVER_NAME}|g" "$1"
}

for unidad in \
  reporte-telecom.service reporte-telecom-api.service reporte-telecom-alerta@.service \
  reporte-telecom-health.service reporte-telecom-health.timer; do
  render_template "${APP_DIR}/deploy/${unidad}" | sudo tee "/etc/systemd/system/${unidad}" >/dev/null
done
render_template "${APP_DIR}/deploy/nginx-reporte-telecom.conf" | \
  sudo tee /etc/nginx/conf.d/reporte-telecom.conf >/dev/null
render_template "${APP_DIR}/deploy/logrotate-reporte-telecom" | \
  sudo tee /etc/logrotate.d/reporte-telecom >/dev/null
sudo chmod 0750 "${APP_DIR}/deploy/alerta_servicio.sh" "${APP_DIR}/deploy/verificar_salud.sh"

sudo nginx -t
sudo systemctl daemon-reload
sudo systemctl enable --now nginx reporte-telecom.service reporte-telecom-api.service \
  reporte-telecom-health.timer
sudo systemctl restart nginx reporte-telecom.service reporte-telecom-api.service

esperar_http() {
  local etiqueta="$1"
  local url="$2"
  local patron="$3"
  local unidad="$4"
  local respuesta=""
  local intento
  for intento in $(seq 1 30); do
    if respuesta="$(curl --fail --silent "${url}" 2>/dev/null)" && \
       { [[ -z "${patron}" ]] || grep -q "${patron}" <<<"${respuesta}"; }; then
      echo "${etiqueta} lista después de ${intento} intento(s)."
      return 0
    fi
    sleep 2
  done
  echo "${etiqueta} no respondió correctamente en 60 segundos: ${url}" >&2
  sudo systemctl status "${unidad}" --no-pager -l || true
  sudo journalctl -u "${unidad}" -n 80 --no-pager || true
  return 1
}

esperar_http "API" "http://127.0.0.1:${API_PORT}/salud" "\"estado\"" \
  reporte-telecom-api.service
esperar_http "Interfaz" "http://127.0.0.1:${APP_PORT}/" "reporte-telecom-app" \
  reporte-telecom.service
echo "Despliegue v3.6.7 terminado: http://${SERVER_NAME}/telecom/"
echo "Swagger: http://${SERVER_NAME}/telecom/api/__docs__/"
