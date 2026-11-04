#!/bin/sh
# Collect built apks from ./sdk into out/<version>/..., then index and sign each directory.
#   out/<version>/packages/<arch>/                     arch packages
#   out/<version>/targets/<target>/<subtarget>/packages/   kmod-* packages
set -eu
: "${VERSION:?}" "${TARGET:?}" "${SUBTARGET:?}" "${ARCH:?}" "${RUNNER_TEMP:?}"

apk="$PWD/sdk/staging_dir/host/bin/apk"
out="out/$VERSION"
arch_dir="$out/packages/$ARCH"
kmod_dir="$out/targets/$TARGET/$SUBTARGET/packages"

mkdir -p "$arch_dir" "$kmod_dir"
find sdk/bin/packages -name '*.apk' ! -name 'kmod-*' -exec cp {} "$arch_dir/" \;
find sdk/bin -name 'kmod-*.apk' -exec cp {} "$kmod_dir/" \;

for d in "$arch_dir" "$kmod_dir"; do
  if ls "$d"/*.apk >/dev/null 2>&1; then
    sh scripts/ci/index-and-sign.sh "$d" "$RUNNER_TEMP/sign.pem" "$apk"
  else
    echo "no packages in $d" >&2
    rmdir "$d"
  fi
done

rm -f "$RUNNER_TEMP/sign.pem"
cp "$RUNNER_TEMP/public.pem" out/public.pem
