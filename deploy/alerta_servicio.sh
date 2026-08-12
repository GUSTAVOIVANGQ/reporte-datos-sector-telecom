#!/usr/bin/env bash
set -Eeuo pipefail

servicio="${1:-reporte-telecom.service}"
mensaje="El servicio ${servicio} falló en $(hostname -f) a las $(date --iso-8601=seconds)."
logger -t reporte-telecom-alerta -- "${mensaje}"

webhook="${REPORTE_ALERT_WEBHOOK_URL:-}"
if [[ -n "${webhook}" ]] && command -v curl >/dev/null 2>&1; then
  cuerpo="$(python3 -c 'import json,sys; print(json.dumps({"title":"Fallo de servicio","text":sys.argv[1]}))' "${mensaje}")"
  curl --fail --silent --show-error --max-time 15 \
    -H 'Content-Type: application/json' --data-binary "${cuerpo}" "${webhook}" >/dev/null
fi
