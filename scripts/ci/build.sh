#!/bin/sh
# Select the packages from config.yml (enabled feeds only) and build them with the SDK in ./sdk.
set -eu
repo=$PWD
meta=razzmatazz-build

cd sdk

# download.pl tries the mirrors of a source in order, but curl waits on a stalled one forever.
# Give up on a connection slower than 50 KB/s for 20 s (no same-mirror retries) so the next
# mirror is tried. Override with CURL_OPTIONS in the environment.
export CURL_OPTIONS="${CURL_OPTIONS:---speed-limit 51200 --speed-time 20 --retry 0}"

# `make package/a/compile package/b/compile` runs every goal as its own sub-make, so shared
# dependencies (toolchain, linux-firmware, package/kernel/linux) are rebuilt once per goal.
# A throwaway package that depends on all of ours gives make a single goal instead.
deps=$(python3 "$repo/scripts/ci/repo.py" packages | sed -E 's/[^ ]+/+&/g')
mkdir -p "package/$meta"
sed -e "s/@NAME@/$meta/g" -e "s/@DEPENDS@/$deps/" "$repo/scripts/ci/meta-package.mk.in" > "package/$meta/Makefile"

{
  python3 "$repo/scripts/ci/repo.py" kconfig
  echo "CONFIG_PACKAGE_$meta=m"
  # The SDK defaults to building every package (CONFIG_ALL*); build only the ones selected here.
  echo "# CONFIG_ALL is not set"
  echo "# CONFIG_ALL_NONSHARED is not set"
  echo "# CONFIG_ALL_KMODS is not set"
} > .config
make defconfig

# Only the meta package (and so our packages and their dependencies) is built. A plain
# `make package/compile` also builds everything the target profile pulls in (u-boot, ATF,
# mac80211, perl, ...), ~90 min.
# Parallel first; on failure rerun single-threaded so the real error is readable.
make -j"$(nproc)" "package/$meta/compile" V=s || make -j1 "package/$meta/compile" V=s
