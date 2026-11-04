#!/bin/sh
# Download and unpack the OpenWrt SDK for $VERSION/$TARGET/$SUBTARGET into ./sdk.
set -eu
: "${VERSION:?}" "${TARGET:?}" "${SUBTARGET:?}"

base=$(python3 scripts/ci/repo.py get sdk_base)
url="$base/$VERSION/targets/$TARGET/$SUBTARGET"

file=$(wget -qO- "$url/sha256sums" | awk '{print $2}' | tr -d '*' | grep -E '^openwrt-sdk-.*\.tar\.(zst|xz)$' | head -n1)
[ -n "$file" ] || { echo "SDK not found at $url" >&2; exit 1; }

wget -q "$url/$file"
mkdir sdk
tar -xf "$file" -C sdk --strip-components=1
rm -f "$file"
