# Build environment matching the CI runner's OpenWrt SDK dependencies.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential clang flex bison g++ gawk gettext git libncurses-dev libssl-dev \
      python3 python3-yaml python3-setuptools rsync swig unzip zlib1g-dev file wget zstd \
      ca-certificates curl xz-utils patch \
 && rm -rf /var/lib/apt/lists/*
# Node for the landing page (the CI runner uses Node 22).
RUN set -eu; arch=$(dpkg --print-architecture | sed 's/amd64/x64/;s/arm64/arm64/'); \
    curl -fsSL "https://nodejs.org/dist/v22.11.0/node-v22.11.0-linux-$arch.tar.xz" | tar -xJ -C /usr/local --strip-components=1
# OpenWrt refuses to build as root. /work/sdk is a named volume and inherits this ownership.
RUN useradd -m builder && mkdir -p /work/sdk && chown -R builder /work
USER builder
WORKDIR /work
