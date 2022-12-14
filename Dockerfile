#
# Aerospike Tools Dockerfile
#
# http://github.com/aerospike/aerospike-tools.docker
#
FROM debian:bullseye-slim AS build

ARG TARGETARCH

RUN \
  apt-get update -y \
  && apt-get install -y \
  wget \
  build-essential \
  zlib1g-dev \
  libncurses5-dev \
  libgdbm-dev \
  libnss3-dev \
  libssl-dev \
  libreadline-dev \
  libffi-dev \
  libsqlite3-dev \
  libbz2-dev

# Build and Install Python from source
RUN \
  wget https://www.python.org/ftp/python/3.10.9/Python-3.10.9.tgz \
  && tar -xf Python-*.tgz \
  && cd Python-*/ \
  && ./configure --enable-optimizations \
  && make

ARG TOOLS_VERSION=8.0.4
ARG TOOLS_ARTIFACT_URL_BASE="https://artifacts.aerospike.com/aerospike-tools/${TOOLS_VERSION}/aerospike-tools_${TOOLS_VERSION}_debian11"

RUN \
  if [ "${TARGETARCH}" = "arm64" ]; then \
    export PKG_TARGETARCH="aarch64"; \
  elif [ "${TARGETARCH}" = "amd64" ]; then \
    export PKG_TARGETARCH="x86_64"; \
  else \
    exit 1; \
  fi; \
  wget "${TOOLS_ARTIFACT_URL_BASE}_${PKG_TARGETARCH}.tgz" -O aerospike-tools.tgz \
  && mkdir aerospike \
  && tar xzf aerospike-tools.tgz --strip-components=1 -C aerospike \
  && TOOLS_SHA256=$(wget "${TOOLS_ARTIFACT_URL_BASE}_${PKG_TARGETARCH}.tgz.sha256" \
  && cat *aerospike-tools*.sha256 | cut -d' ' -f1) \
  && echo "$TOOLS_SHA256 *aerospike-tools.tgz" | sha256sum -c -

FROM debian:bullseye-slim as install

# Work from /aerospike
WORKDIR /install

# Install Aerospike

COPY --from=build Python-* /install/Python
COPY --from=build aerospike/aerospike-tools*.deb /install/aerospike/
COPY --from=build /usr/bin/make /usr/bin/

RUN ls /install && ls /install/Python && make -C Python install && dpkg -i /install/aerospike/aerospike-tools*.deb \
  && rm -rf install

# Addition of wrapper script
ADD wrapper.sh /aerospike/wrapper

# Wrapper script entrypoint
ENTRYPOINT ["wrapper"]
