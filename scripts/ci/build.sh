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
# Build only the selected packages (plus their dependencies). A plain `make package/compile`
# also builds everything the target profile pulls in (u-boot, ATF, mac80211, perl, ...), ~90 min.
targets=""
for p in $(python3 "$repo/scripts/ci/repo.py" packages); do
  targets="$targets package/$p/compile"
done
# Parallel first; on failure rerun single-threaded so the real error is readable.
# shellcheck disable=SC2086
make -j"$(nproc)" $targets V=s || make -j1 $targets V=s
