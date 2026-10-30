#!/bin/sh
# Install AmneziaWG packages built for the exact firmware release on this router.
# Usage: install-awg.sh [firmware-release-tag]
set -e

REPO="NuclearTruck/awg-openwr"          # <-- replace with your fork, e.g. myname/awg-openwrt
TAG="$1"

if [ -z "$TAG" ]; then
  TAG=$(cat /etc/apk/repositories.d/* /etc/apk/repositories 2>/dev/null \
        | grep -oE 'ipq50xx-[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[0-9]+)?' | head -n1 || true)
fi
[ -n "$TAG" ] || { echo "Cannot detect the firmware release; pass it as an argument."; exit 1; }

BASE="https://github.com/$REPO/releases/download/awg-$TAG"
TMP=/tmp/awg-install
rm -rf "$TMP"; mkdir -p "$TMP"

echo "Firmware release: $TAG"
echo "Downloading from: $BASE"

for p in kmod-amneziawg amneziawg-tools luci-proto-amneziawg; do
  wget -O "$TMP/$p.apk" "$BASE/$p.apk" || { echo "Download failed: $BASE/$p.apk"; exit 1; }
done
# optional Russian translation
wget -q -O "$TMP/luci-i18n-amneziawg-ru.apk" "$BASE/luci-i18n-amneziawg-ru.apk" 2>/dev/null || rm -f "$TMP/luci-i18n-amneziawg-ru.apk"

apk update || true
apk add --allow-untrusted "$TMP"/kmod-amneziawg.apk "$TMP"/amneziawg-tools.apk "$TMP"/luci-proto-amneziawg.apk
[ -f "$TMP/luci-i18n-amneziawg-ru.apk" ] && apk add --allow-untrusted "$TMP/luci-i18n-amneziawg-ru.apk" || true

rm -f /tmp/luci-indexcache* 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
rm -rf "$TMP"
echo "Done. Add the AmneziaWG interface in Network -> Interfaces."
