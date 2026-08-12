FROM rocker/r-ver:4.6.1

ARG PYTHON_VERSION=3.9.25
ARG RENV_VERSION=1.1.4

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/python/bin:/opt/venv/bin:${PATH} \
    REPORTE_RAIZ=/app \
    RENV_VERSION=${RENV_VERSION} \
    REPORTE_CRAN=https://packagemanager.posit.co/cran/2026-08-03 \
    REPORTE_MODO_SERVIDOR=true \
    REPORTE_INSTALL_PACKAGES=false \
    REPORTE_PYTHON=/opt/venv/bin/python \
    REPORTE_LIBREOFFICE=/usr/bin/libreoffice \
    REPORTE_DATOS_DIR=/app/entrada/datos_bit \
    REPORTE_SALIDAS_DIR=/app/salidas \
    REPORTE_OBSERVABILIDAD_DIR=/app/salidas/observabilidad \
    TMPDIR=/app/tmp-build \
    TMP=/app/tmp-build \
    TEMP=/app/tmp-build

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl xz-utils \
      libbz2-dev libffi-dev liblzma-dev libncursesw5-dev libreadline-dev \
      libsqlite3-dev libssl-dev tk-dev uuid-dev zlib1g-dev \
      libcurl4-openssl-dev libxml2-dev libzip-dev libsodium-dev pkg-config \
      libreoffice-writer fonts-dejavu-core \
    && curl -fsSLO "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
    && tar -xzf "Python-${PYTHON_VERSION}.tgz" \
    && cd "Python-${PYTHON_VERSION}" \
    && ./configure --prefix=/opt/python --with-ensurepip=install --enable-optimizations \
    && make -j"$(nproc)" \
    && make install \
    && /opt/python/bin/python3.9 -m venv /opt/venv \
    && rm -rf "/Python-${PYTHON_VERSION}" "/Python-${PYTHON_VERSION}.tgz" /var/lib/apt/lists/*

WORKDIR /app
COPY requirements-python.txt renv.lock ./
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements-python.txt \
    && R -q -e "install.packages(sprintf('https://cran.r-project.org/src/contrib/Archive/renv/renv_%s.tar.gz', Sys.getenv('RENV_VERSION', '1.1.4')), repos=NULL, type='source')" \
    && R -q -e "renv::restore(lockfile='renv.lock', prompt=FALSE)"

COPY . /app
RUN mkdir -p /app/entrada/datos_bit /app/salidas /app/tmp-build \
    && chmod 0775 /app/entrada/datos_bit /app/salidas /app/tmp-build

EXPOSE 3838 8000
CMD ["Rscript", "main.R", "--ui", "--host=0.0.0.0", "--port=3838", "--no-browser"]
