#!/bin/sh
# Reproduce the CI build in Docker, without spending Actions minutes. Works with a remote
# Docker context: the repo is streamed in over stdin and the SDK lives in a named volume
# (openwrt-repo-sdk) on the Docker host, so it is reused between runs.
#
#   scripts/local/build.sh [all | package ...]
#
# No arguments or "all": the full CI build (scripts/ci/build.sh).
# Package names (e.g. zapret luci-app-zapret): build only those.
# Target comes from VERSION/TARGET/SUBTARGET env vars (default: openwrt_version from config.yml, mediatek filogic).
# Start over with: docker volume rm openwrt-repo-sdk
set -eu
cd "$(dirname "$0")/../.."

docker build -q -t openwrt-repo-build scripts/local >/dev/null
tar -c --exclude=./sdk --exclude=./.git --exclude=node_modules --exclude=./out --exclude=./build . |
docker run --rm -i -v openwrt-repo-sdk:/work/sdk \
  -e VERSION="${VERSION:-$(sed -n "s/^openwrt_version: *\([0-9.]*\).*/\1/p" config.yml)}" -e TARGET="${TARGET:-mediatek}" -e SUBTARGET="${SUBTARGET:-filogic}" \
  -e PKGS="${*:-all}" openwrt-repo-build sh -euc '
    tar -x -C /work
    [ -e sdk/Makefile ] || sh scripts/ci/download-sdk.sh
    sh scripts/ci/setup-feeds.sh
    if [ "$PKGS" = all ]; then sh scripts/ci/build.sh; exit; fi
    cd sdk
    for p in $PKGS; do echo "CONFIG_PACKAGE_$p=m"; done > .config
    printf "# CONFIG_%s is not set\n" ALL ALL_NONSHARED ALL_KMODS >> .config
    make defconfig
    make -j"$(nproc)" $(for p in $PKGS; do echo "package/$p/compile"; done) V=s
  '
