#!/usr/bin/env bash
#
# Actualiza el printView del kiosko autoservicio desde un USB.
# Lo dispara la regla udev al insertar un USB con label CDAUPDATE (ver
# ../udev/99-cdapuestas-usb-update.rules). Instala en /usr/local/bin/ en la
# máquina (ver README.md).
#
# Flujo: monta el USB (solo lectura), lee la config (update.env del USB),
# copia el AppImage nuevo de forma atómica sobre la ruta que lanza el watcher,
# y mata el proceso para que el watcher relance el AppImage ya actualizado.
# De ahí en adelante las próximas actualizaciones entran solas por OTA.
set -euo pipefail

DEV="${1:?uso: $0 /dev/sdX1}"
LOG="/var/log/cdapuestas-usb-update.log"
exec >>"$LOG" 2>&1

# Muestra el mensaje en el log y, si se puede, en la consola física (tty1),
# para que el encargado vea algo en una máquina sin interfaz gráfica.
say() {
  echo "[$(date '+%F %T')] $*"
  [ -w /dev/tty1 ] && echo ">> CDApuestas: $*" >/dev/tty1 2>/dev/null || true
}

say "==== Actualización desde $DEV ===="

MNT="$(mktemp -d /run/cdapuestas-usb.XXXXXX)"
cleanup() { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT

mount -o ro "$DEV" "$MNT"

# Defaults; el update.env del USB los sobrescribe. El USB es un medio de
# confianza preparado por nosotros, por eso se puede 'source'.
APPIMAGE_FILE="cdapuestas-webview.AppImage"
INSTALL_PATH="/opt/cdapuestas/printview.AppImage"
PROCESS_MATCH="printview.AppImage"
# shellcheck disable=SC1091
[ -f "$MNT/update.env" ] && . "$MNT/update.env"

SRC="$MNT/$APPIMAGE_FILE"
if [ ! -f "$SRC" ]; then
  say "ERROR: no se encontró $APPIMAGE_FILE en el USB. Nada que instalar."
  exit 1
fi

say "Instalando printView nuevo..."
install -d "$(dirname "$INSTALL_PATH")"
TMP="${INSTALL_PATH}.new"
cp "$SRC" "$TMP"
chmod +x "$TMP"
mv -f "$TMP" "$INSTALL_PATH"   # reemplazo atómico
say "AppImage instalado en $INSTALL_PATH"

say "Reiniciando printView (el watcher lo relanzará)..."
pkill -f "$PROCESS_MATCH" || true

say "Listo. Ya puedes retirar el USB."
