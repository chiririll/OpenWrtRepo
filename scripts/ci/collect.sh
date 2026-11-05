#!/bin/sh
# Copy the packages listed in config.yml from ./sdk into out/<version>/..., then index and sign
# each directory. Only our own packages are published: their dependencies (libs, firmware,
# stock kmods) come from the official OpenWrt repositories.
#   out/<version>/packages/<arch>/                         scope: arch
#   out/<version>/targets/<target>/<subtarget>/packages/   scope: target (kmods)
set -eu
: "${VERSION:?}" "${TARGET:?}" "${SUBTARGET:?}" "${ARCH:?}" "${RUNNER_TEMP:?}"

apk="$PWD/sdk/staging_dir/host/bin/apk"
out="out/$VERSION"

# collect <scope> <dir>: copy every package of that scope; fail if one wasn't built.
collect() {
  scope=$1 dir=$2
  names=$(python3 scripts/ci/repo.py packages "$scope")
  [ -n "$names" ] || return 0
  mkdir -p "$dir"
  for name in $names; do
    # "<name>-<version>.apk": the digit keeps "zapret" from matching "zapret-foo-1.apk".
    found=$(find sdk/bin -name "$name-[0-9]*.apk")
    [ -n "$found" ] || { echo "not built: $name" >&2; exit 1; }
    echo "$found" | while read -r f; do cp "$f" "$dir/"; done
  done
  sh scripts/ci/index-and-sign.sh "$dir" "$RUNNER_TEMP/sign.pem" "$apk"
}

collect arch "$out/packages/$ARCH"
collect target "$out/targets/$TARGET/$SUBTARGET/packages"

rm -f "$RUNNER_TEMP/sign.pem"
cp "$RUNNER_TEMP/public.pem" out/public.pem
