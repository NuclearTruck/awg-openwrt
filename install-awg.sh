#!/bin/sh
# Install AmneziaWG packages built for the exact firmware release on this router.
# Usage: install-awg.sh [--ru | --no-ru] [firmware-release-tag]
#   --ru / --no-ru   install / skip the Russian LuCI translation without asking
#   AWG_RU=y|n       same thing via an environment variable
set -e

REPO="NuclearTruck/awg-openwrt"

TAG=""
RU=""
for a in "$@"; do
  case "$a" in
    --ru)    RU=y ;;
    --no-ru) RU=n ;;
    -*)      echo "Unknown option: $a"; exit 1 ;;
    *)       TAG="$a" ;;
  esac
done
[ -n "$RU" ] || RU="${AWG_RU:-}"

if [ -z "$TAG" ]; then
  TAG=$(cat /etc/apk/repositories.d/* /etc/apk/repositories 2>/dev/null \
        | grep -oE 'ipq50xx-[0-9]{4}\.[0-9]{2}\.[0-9]{2}(-[0-9]+)?' | head -n1 || true)
fi
[ -n "$TAG" ] || { echo "Cannot detect the firmware release; pass it as an argument."; exit 1; }

# Ask about the Russian translation. stdin is the script itself when piped
# into sh, so read the answer from the terminal instead.
if [ -z "$RU" ]; then
  if ( : < /dev/tty ) 2>/dev/null; then
    printf "Install the Russian LuCI translation? [y/N]: " > /dev/tty
    read -r ans < /dev/tty || ans=""
    case "$ans" in
      y|Y|yes|YES|Yes|д|Д|да|Да) RU=y ;;
      *) RU=n ;;
    esac
  else
    RU=n
  fi
fi

BASE="https://github.com/$REPO/releases/download/awg-$TAG"
TMP=/tmp/awg-install
rm -rf "$TMP"; mkdir -p "$TMP"

echo "Firmware release: $TAG"
echo "Downloading from: $BASE"

for p in kmod-amneziawg amneziawg-tools luci-proto-amneziawg; do
  wget -O "$TMP/$p.apk" "$BASE/$p.apk" || { echo "Download failed: $BASE/$p.apk"; exit 1; }
done

HAVE_RU=""
if [ "$RU" = "y" ]; then
  echo "Downloading the Russian translation..."
  if wget -O "$TMP/luci-i18n-amneziawg-ru.apk" "$BASE/luci-i18n-amneziawg-ru.apk"; then
    HAVE_RU=1
  else
    echo "Warning: no Russian translation in release awg-$TAG, skipping it."
    rm -f "$TMP/luci-i18n-amneziawg-ru.apk"
  fi
fi

apk update || true
apk add --allow-untrusted "$TMP"/kmod-amneziawg.apk "$TMP"/amneziawg-tools.apk "$TMP"/luci-proto-amneziawg.apk
if [ -n "$HAVE_RU" ]; then
  apk add --allow-untrusted "$TMP/luci-i18n-amneziawg-ru.apk"
fi

rm -f /tmp/luci-indexcache* 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
rm -rf "$TMP"
echo "Done. Add the AmneziaWG interface in Network -> Interfaces."
