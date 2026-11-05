#!/bin/sh
# Download and unpack the OpenWrt SDK for $VERSION/$TARGET/$SUBTARGET into ./sdk.
set -eu
: "${VERSION:?}" "${TARGET:?}" "${SUBTARGET:?}"

base=$(python3 scripts/ci/repo.py get sdk_base)
url="$base/$VERSION/targets/$TARGET/$SUBTARGET"

sums=$(wget -qO- "$url/sha256sums" | tr -d '*')
file=$(echo "$sums" | awk '{print $2}' | grep -E '^openwrt-sdk-.*\.tar\.(zst|xz)$' | head -n1)
[ -n "$file" ] || { echo "SDK not found at $url" >&2; exit 1; }

# SDK_CACHE: optional directory that keeps the tarball between runs (actions/cache in CI).
cache=${SDK_CACHE:-.}
mkdir -p "$cache"
sum=$(echo "$sums" | grep " $file\$")
if [ -f "$cache/$file" ] && (cd "$cache" && echo "$sum" | sha256sum -c - >/dev/null 2>&1); then
  echo "SDK tarball from cache: $file"
else
  rm -f "$cache/$file"
  wget -q -P "$cache" "$url/$file"
  (cd "$cache" && echo "$sum" | sha256sum -c -)
fi

mkdir sdk
tar -xf "$cache/$file" -C sdk --strip-components=1
[ -n "${SDK_CACHE:-}" ] || rm -f "$file"
