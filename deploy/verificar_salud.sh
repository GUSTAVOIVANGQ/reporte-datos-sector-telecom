#!/usr/bin/env bash
set -Eeuo pipefail

app_port="${REPORTE_PORT:-3838}"
api_port="${REPORTE_API_PORT:-8000}"

escucha_puerto() {
  local puerto="$1"
  ss -H -ltn "sport = :${puerto}" 2>/dev/null | grep -q .
}

servicio_disponible() {
  local servicio="$1"
  local puerto="$2"
  systemctl is-active --quiet "${servicio}" && escucha_puerto "${puerto}"
}

verificar_servicio() {
  local servicio="$1"
  local puerto="$2"
  if servicio_disponible "${servicio}" "${puerto}"; then
    return 0
  fi

  # Evita reiniciar durante la breve ventana normal de arranque. Una tarea
  # larga puede demorar las respuestas HTTP, pero mantiene el puerto abierto;
  # por eso no se usa curl como criterio de reinicio.
  sleep 5
  if servicio_disponible "${servicio}" "${puerto}"; then
    return 0
  fi

  /usr/bin/bash "$(dirname "$0")/alerta_servicio.sh" \
    "${servicio}: proceso inactivo o puerto ${puerto} cerrado" || true
  systemctl restart "${servicio}"
  return 1
}

fallo=0
verificar_servicio reporte-telecom.service "${app_port}" || fallo=1
verificar_servicio reporte-telecom-api.service "${api_port}" || fallo=1
exit "${fallo}"
