#!/usr/bin/env bash
#
# Actualiza el printView ("full" / CD Apuestas WebView) de un kiosko Ubuntu
# desde un USB. Lo dispara la regla udev al insertar un USB con label CDAUPDATE
# (ver ../udev/99-cdapuestas-usb-update.rules). Instalar en /usr/local/bin/ en
# la máquina (ver README.md).
#
# Modelo del kiosko (ver ../../docs/kiosk-linux.md): la app se instala como
# paquete .deb (binario en /opt/cdapuestas_webview/cdapuestas-webview) y un
# supervisor de usuario la relanza si muere. Por eso este update:
#   1) instala el .deb nuevo,
#   2) corrige permisos de chrome-sandbox,
#   3) mata el proceso; el supervisor relanza el binario ya actualizado.
# Después, si en el futuro se migra a AppImage, las actualizaciones podrían
# entrar por OTA (electron-updater no auto-actualiza paquetes .deb).
set -euo pipefail

DEV="${1:?uso: $0 /dev/sdX1}"
LOG="/var/log/cdapuestas-usb-update.log"
exec >>"$LOG" 2>&1

# Mensaje al log y, si se puede, a la consola física (tty1): el kiosko no tiene
# interfaz de escritorio, pero la sesión corre en un VT.
say() {
  echo "[$(date '+%F %T')] $*"
  [ -w /dev/tty1 ] && echo ">> CDApuestas: $*" >/dev/tty1 2>/dev/null || true
}

say "==== Actualización de printView desde $DEV ===="

MNT="$(mktemp -d /run/cdapuestas-usb.XXXXXX)"
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

mount -o ro "$DEV" "$MNT"

# Defaults; el update.env del USB (medio de confianza, preparado por nosotros)
# los sobrescribe. DEB_FILE vacío = usar el .deb más nuevo que haya en el USB.
DEB_FILE=""
PROCESS_MATCH='^/opt/cdapuestas_webview/cdapuestas-webview( |$)'
SANDBOX_FIX="/usr/local/sbin/cdapuestas-fix-sandbox"
# shellcheck disable=SC1091
[ -f "$MNT/update.env" ] && . "$MNT/update.env"

# Resolver el .deb a instalar.
if [ -n "$DEB_FILE" ]; then
  DEB_PATH="$MNT/$DEB_FILE"
else
  DEB_PATH="$(ls -1t "$MNT"/cdapuestas-webview-*.deb 2>/dev/null | head -n 1 || true)"
fi
if [ -z "${DEB_PATH:-}" ] || [ ! -f "$DEB_PATH" ]; then
  say "ERROR: no se encontró el .deb de CD Apuestas WebView en el USB."
  exit 1
fi
say "Instalando $(basename "$DEB_PATH")..."

export DEBIAN_FRONTEND=noninteractive
if ! apt-get install -y "$DEB_PATH"; then
  say "apt falló; reparando dependencias..."
  dpkg -i "$DEB_PATH" || true
  apt-get -f install -y
fi

# Reaplicar permisos del sandbox de Chromium (chrome-sandbox root:root 4755).
if [ -x "$SANDBOX_FIX" ]; then
  "$SANDBOX_FIX" || true
fi

say "Reiniciando el WebView (el supervisor lo relanzará)..."
pkill -f "$PROCESS_MATCH" || true

say "Listo. Ya puedes retirar el USB."
