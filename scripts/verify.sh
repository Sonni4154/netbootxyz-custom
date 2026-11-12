#!/usr/bin/env bash
# verify.sh: check the netboot.xyz container is up and serving TFTP and HTTP on the LAN IP.
# Exits non-zero on the first failure. Run from anywhere.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[ -f .env ] || { echo "verify: .env missing (cp .env.example .env)" >&2; exit 1; }
set -a; . ./.env; set +a

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

# The admin UI has no login: it must never listen on the LAN or all interfaces.
case "${NETBOOT_ADMIN_IP:-}" in
  127.0.0.1|::1) ok "admin UI bound to loopback (${NETBOOT_ADMIN_IP})" ;;
  *) fail "NETBOOT_ADMIN_IP=${NETBOOT_ADMIN_IP:-unset}; the admin UI has no auth, set it to 127.0.0.1" ;;
esac

state="$(docker inspect -f '{{.State.Health.Status}}' netbootxyz 2>/dev/null)" || fail "container netbootxyz not found"
[ "$state" = "healthy" ] || fail "container health is '$state'"
ok "container healthy"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for f in netboot.xyz.kpxe netboot.xyz.efi; do
  curl -sf --max-time 10 -o "$tmp/$f" "tftp://${NETBOOT_LAN_IP}:${NETBOOT_TFTP_PORT:-69}/$f" || fail "TFTP fetch of $f"
  [ -s "$tmp/$f" ] || fail "TFTP $f is empty"
  ok "TFTP serves $f ($(stat -c %s "$tmp/$f") bytes)"
done

curl -sf --max-time 10 -o /dev/null "http://${NETBOOT_LAN_IP}:${NETBOOT_ASSETS_PORT:-8080}/" || fail "asset mirror HTTP"
ok "asset mirror answers on ${NETBOOT_LAN_IP}:${NETBOOT_ASSETS_PORT:-8080}"

curl -sf --max-time 10 -o /dev/null "http://${NETBOOT_ADMIN_IP}:${NETBOOT_ADMIN_PORT:-3001}/" || fail "admin UI"
ok "admin UI answers on ${NETBOOT_ADMIN_IP}:${NETBOOT_ADMIN_PORT:-3001}"
