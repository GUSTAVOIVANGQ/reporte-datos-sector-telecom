#!/usr/bin/env bash
set -Eeuo pipefail

if ! rpm -q libsodium-devel >/dev/null 2>&1 && \
   ! dnf --quiet list --available libsodium-devel >/dev/null 2>&1; then
  cat >&2 <<'EOF'
No se encontró libsodium-devel. En RHEL 9 este paquete se obtiene de EPEL 9.
Habilite primero los repositorios y vuelva a ejecutar este script:

  sudo subscription-manager repos \
    --enable="codeready-builder-for-rhel-9-$(arch)-rpms"
  sudo dnf install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
EOF
  exit 1
fi

sudo dnf install -y \
  R R-devel gcc gcc-c++ gcc-gfortran make cmake libxml2-devel libcurl-devel \
  openssl-devel libzip-devel libsodium-devel pkgconf-pkg-config \
  python3 python3-devel nginx libreoffice-headless libreoffice-writer curl iproute tar gzip

pkg-config --exists libsodium || {
  echo "libsodium-devel se instaló, pero pkg-config no encuentra libsodium.pc" >&2
  exit 1
}
