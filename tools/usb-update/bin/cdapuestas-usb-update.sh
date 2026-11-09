#!/usr/bin/env bash
#
# Lanzador de actualización por USB para los kioscos (Ubuntu + GNOME Kiosk).
# Lo dispara la regla udev al insertar un USB con label CDAUPDATE (ver
# ../udev/99-cdapuestas-usb-update.rules). Instalar en /usr/local/bin/ en la
# máquina, una sola vez (ver README.md).
#
# No instala nada por sí mismo: monta el pendrive, busca bajo releases/ la
# carpeta de versión MÁS ALTA y ejecuta su autostart.sh (que instala el .deb de
# esa carpeta). Así cada update es autocontenido y se conservan versiones
# anteriores para rollback (ver ../../releases/README.md).
set -euo pipefail

DEV="${1:?uso: $0 /dev/sdX1}"
LOG="/var/log/cdapuestas-usb-update.log"
exec >>"$LOG" 2>&1

HERE="$(cd "$(dirname "$0")" && pwd)"
UI="$HERE/cdapuestas-usb-update-ui.sh"

say() {
  echo "[$(date '+%F %T')] $*"
  [ -w /dev/tty1 ] && echo ">> CDApuestas: $*" >/dev/tty1 2>/dev/null || true
}

say "==== USB de actualización detectado en $DEV ===="

MNT="$(mktemp -d /run/cdapuestas-usb.XXXXXX)"
ORIG_VT=""
cleanup() {
  umount "$MNT" 2>/dev/null || true
  rmdir "$MNT" 2>/dev/null || true
  # Volver siempre al VT original (donde está el WebView), pase lo que pase.
  [ -n "$ORIG_VT" ] && chvt "$ORIG_VT" 2>/dev/null || true
}
trap cleanup EXIT

mount -o ro "$DEV" "$MNT"

# El catálogo puede estar en releases/ o directo en la raíz del USB.
REL="$MNT/releases"
[ -d "$REL" ] || REL="$MNT"

# Carpeta de versión más alta que tenga autostart.sh (orden natural de versión).
VERDIR=""
while IFS= read -r dir; do
  [ -f "$dir/autostart.sh" ] && VERDIR="$dir"
done < <(find "$REL" -mindepth 1 -maxdepth 1 -type d | sort -V)

if [ -z "$VERDIR" ]; then
  say "ERROR: no encontré ninguna carpeta de versión con autostart.sh en el USB."
  exit 1
fi

say "Aplicando versión $(basename "$VERDIR")..."
# El pendrive es un medio de confianza preparado por nosotros; se ejecuta su
# autostart.sh (vive junto al .deb de esa versión).
#
# Feedback en pantalla: con kbd (openvt/fgconsole) abrimos un VT nuevo que
# muestra banner + progreso en vivo, y al terminar la trap vuelve al WebView.
# Sin kbd, corre igual pero el avance solo queda en el log.
if [ -f "$UI" ] && command -v openvt >/dev/null 2>&1 && command -v fgconsole >/dev/null 2>&1; then
  ORIG_VT="$(fgconsole 2>/dev/null || true)"
  say "Mostrando ventana de actualización en consola (VT)."
  openvt -s -w -- bash "$UI" "$VERDIR" || say "La ventana de actualización terminó con error."
else
  say "Sin kbd o UI; aplico el update sin ventana."
  bash "$VERDIR/autostart.sh"
fi
say "Proceso de actualización finalizado."
