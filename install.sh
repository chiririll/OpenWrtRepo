#!/bin/sh
# Adds the razzmatazz package repository to this router.
set -eu

BASE="https://openwrt.razzmatazz.ru"
NAME="razzmatazz"

. /etc/openwrt_release
command -v apk >/dev/null || { echo "apk not found: OpenWrt 25.12+ is required" >&2; exit 1; }

echo "Release: $DISTRIB_RELEASE  Arch: $DISTRIB_ARCH  Target: $DISTRIB_TARGET"

wget -qO "/etc/apk/keys/$NAME.pem" "$BASE/keys/$NAME.pem"
mkdir -p /etc/apk/repositories.d
cat > "/etc/apk/repositories.d/$NAME.list" <<EOF
$BASE/$DISTRIB_RELEASE/packages/$DISTRIB_ARCH/packages.adb
$BASE/$DISTRIB_RELEASE/targets/$DISTRIB_TARGET/packages/packages.adb
EOF

# Keep the key and feed across sysupgrade.
for f in "/etc/apk/keys/$NAME.pem" "/etc/apk/repositories.d/$NAME.list"; do
  grep -qxF "$f" /etc/sysupgrade.conf 2>/dev/null || echo "$f" >> /etc/sysupgrade.conf
done

apk update
echo "Done. Try: apk add amneziawg-tools"
