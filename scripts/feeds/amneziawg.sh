#!/bin/sh
# Setup for the amneziawg feed (see feeds.yml).
#
# The OpenWrt SDK ships a prepared kernel tree without driver sources (only built .ko files),
# but kmod-amneziawg copies drivers/net/wireguard/*.c from it. Put the stock sources back.
#
# Usage: amneziawg.sh <sdk_dir>
set -eu
sdk=$1

linux_dir=$(ls -d "$sdk"/build_dir/target-*/linux-*/linux-[0-9]* | head -n1)
[ -d "$linux_dir" ] || { echo "kernel build dir not found in $sdk" >&2; exit 1; }
ver=${linux_dir##*/linux-}
echo "Kernel $ver in $linux_dir"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Stable tree mirror; supports partial clone, much faster than kernel.org.
git clone -q --depth 1 --filter=blob:none --no-checkout --branch "v$ver" \
  https://github.com/gregkh/linux.git "$work/linux"
git -C "$work/linux" sparse-checkout set --no-cone /drivers/net/wireguard/ /include/uapi/linux/wireguard.h
git -C "$work/linux" checkout -q

mkdir -p "$linux_dir/drivers/net/wireguard" "$linux_dir/include/uapi/linux"
cp -r "$work/linux/drivers/net/wireguard/." "$linux_dir/drivers/net/wireguard/"
cp "$work/linux/include/uapi/linux/wireguard.h" "$linux_dir/include/uapi/linux/wireguard.h"

ls "$linux_dir/drivers/net/wireguard/"*.c >/dev/null

# The module defines wg_get_random_u32_inclusive() in send.c without a prototype, and the
# kernel build treats -Wmissing-prototypes as an error. Downgrade it to a warning.
mk="$sdk/feeds/amneziawg/kmod-amneziawg/src/Makefile"
[ -f "$mk" ] || { echo "feed Makefile not found: $mk" >&2; exit 1; }
grep -q 'Wno-error=missing-prototypes' "$mk" || \
  echo 'ccflags-y += -Wno-error=missing-prototypes' >> "$mk"

# luci-proto-amneziawg sets PKG_VERSION:=0.0.1-1; luci.mk appends -r<release>, and apk rejects
# the resulting "0.0.1-1-r1" as an invalid version. Drop the "-1" (the release is added anyway).
luci_mk="$sdk/feeds/amneziawg/luci-proto-amneziawg/Makefile"
[ -f "$luci_mk" ] || { echo "feed Makefile not found: $luci_mk" >&2; exit 1; }
sed -i 's/^PKG_VERSION:=\(.*\)-1$/PKG_VERSION:=\1/' "$luci_mk"
