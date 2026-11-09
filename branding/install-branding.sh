#!/usr/bin/env bash
# Installs the blackknight graphical boot menu into the netbootxyz container's
# volumes. Run on blackknight:  sudo bash install-branding.sh
# Undo:                         sudo bash install-branding.sh --uninstall
set -euo pipefail
CONTAINER=${CONTAINER:-netbootxyz}
ASSET_URL=${ASSET_URL:-http://10.10.10.98:8080/branding}
HERE=$(cd "$(dirname "$0")" && pwd)
TS=$(date +%Y%m%d-%H%M%S)
LINE='chain --autofree branding.ipxe || echo Branding not loaded, continuing in text mode'

mnt() { docker inspect -f "{{range .Mounts}}{{if eq .Destination \"$1\"}}{{.Source}}{{end}}{{end}}" "$CONTAINER"; }
CONFIG=$(mnt /config); ASSETS=$(mnt /assets)
[[ -d "$CONFIG/menus" ]] || { echo "Can't find /config/menus for container $CONTAINER"; exit 1; }
[[ -d "$ASSETS" ]] || { echo "Can't find /assets volume for container $CONTAINER"; exit 1; }
echo "config: $CONFIG   assets: $ASSETS"

# local-vars.ipxe is served from menus/; menus/local/ is the copy that survives
# a menu update from the web UI. Change both.
TARGETS=("$CONFIG/menus" "$CONFIG/menus/local")
mkdir -p "$CONFIG/menus/local"

if [[ "${1:-}" == "--uninstall" ]]; then
  for d in "${TARGETS[@]}"; do
    f="$d/local-vars.ipxe"
    if [[ -f "$f" ]]; then cp -a "$f" "$f.bak-$TS"; sed -i '/branding\.ipxe/d' "$f"; fi
    rm -f "$d/branding.ipxe"
  done
  rm -rf "$ASSETS/branding"
  echo "Branding removed (local-vars.ipxe backed up as *.bak-$TS). Next PXE boot is plain text."
  exit 0
fi

for f in branding.ipxe bg-1920x1080.png bg-1024x768.png; do
  [[ -f "$HERE/$f" ]] || { echo "Missing $HERE/$f (keep this script next to the other files)"; exit 1; }
done

mkdir -p "$ASSETS/branding"
install -m 644 "$HERE/bg-1920x1080.png" "$HERE/bg-1024x768.png" "$ASSETS/branding/"
for d in "${TARGETS[@]}"; do
  [[ -f "$d/branding.ipxe" ]] && cp -a "$d/branding.ipxe" "$d/branding.ipxe.bak-$TS"
  # bake ASSET_URL into the installed copy so clients fetch the pictures from it
  sed "s#^isset \${brand_url} || set brand_url .*#isset \${brand_url} || set brand_url $ASSET_URL#" \
    "$HERE/branding.ipxe" > "$d/branding.ipxe"
  chmod 644 "$d/branding.ipxe"
  f="$d/local-vars.ipxe"
  if [[ -f "$f" ]]; then
    cp -a "$f" "$f.bak-$TS"
    echo "backed up $f -> $f.bak-$TS"
  else
    printf '#!ipxe\n' > "$f"; chmod 644 "$f"
  fi
  grep -q 'branding\.ipxe' "$f" || printf '%s\n' "$LINE" >> "$f"
done
# match ownership of the existing menu files so the web UI can still edit them
OWN=$(stat -c %u:%g "$CONFIG/menus")
chown "$OWN" "$CONFIG"/menus/{branding.ipxe,local-vars.ipxe} "$CONFIG"/menus/local/{branding.ipxe,local-vars.ipxe}
chown -R "$(stat -c %u:%g "$ASSETS")" "$ASSETS/branding"

echo; echo "Checking the picture is served over HTTP..."
for p in bg-1920x1080.png bg-1024x768.png; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$ASSET_URL/$p" || true)
  echo "  $ASSET_URL/$p -> HTTP $code"
done
echo; echo "local-vars.ipxe now reads:"; sed 's/^/  /' "$CONFIG/menus/local-vars.ipxe"
echo; echo "Done. PXE boot VM 888 to see it. Undo with: sudo bash $0 --uninstall"
