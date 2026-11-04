#!/bin/sh
# Select the packages from config.yml (enabled feeds only) and build them with the SDK in ./sdk.
set -eu
repo=$PWD

cd sdk
{
  python3 "$repo/scripts/ci/repo.py" kconfig
  # The SDK defaults to building every package (CONFIG_ALL*); build only the ones selected here.
  echo "# CONFIG_ALL is not set"
  echo "# CONFIG_ALL_NONSHARED is not set"
  echo "# CONFIG_ALL_KMODS is not set"
} > .config
make defconfig
# Parallel first; on failure rerun single-threaded so the real error is readable.
make -j"$(nproc)" package/compile V=s || make -j1 package/compile V=s
