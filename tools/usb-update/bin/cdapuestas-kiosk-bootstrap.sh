#!/usr/bin/env bash
#
# Bootstrap manual del update por USB para los kioscos (Ubuntu + GNOME Kiosk).
# Se corre UNA VEZ por máquina, a mano y con root, desde el pendrive:
#
#   sudo bash /media/<usuario>/CDAUPDATE/usb-update/bin/cdapuestas-kiosk-bootstrap.sh
#
# Hace dos cosas de una:
#   1. Instala el kit de update por USB (regla udev + lanzador) para que, de aquí
#      en adelante, solo insertar el pendrive dispare la actualización sola.
#   2. Aplica ya la actualización: corre el autostart.sh de la versión más alta
#      bajo releases/ del pendrive (instala el .deb, arregla el sandbox, reinicia).
#
# Pensado para kioscos tras NAT (sin IP pública, sin SSH entrante): este es el
# único toque manual; los updates siguientes entran solos por USB.
set -euo pipefail

if [ "$(id -u)" != 0 ]; then
  echo "Debe correr como root. Usa: sudo bash $0" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"   # .../usb-update/bin
KIT="$(cd "$HERE/.." && pwd)"           # .../usb-update
USBROOT="$(cd "$KIT/.." && pwd)"        # raíz del pendrive (CDAUPDATE)

LAUNCHER="$KIT/bin/cdapuestas-usb-update.sh"
RULES="$KIT/udev/99-cdapuestas-usb-update.rules"
for f in "$LAUNCHER" "$RULES"; do
  [ -f "$f" ] || { echo "ERROR: no encuentro $f en el pendrive." >&2; exit 1; }
done

echo ">> 1/2 Instalando el kit de update por USB (una sola vez)..."
install -m 0755 "$LAUNCHER" /usr/local/bin/cdapuestas-usb-update.sh
install -m 0644 "$RULES" /etc/udev/rules.d/99-cdapuestas-usb-update.rules
udevadm control --reload
echo "   Listo: a partir de ahora, insertar el pendrive CDAUPDATE actualiza solo."

echo ">> 2/2 Aplicando la actualización desde el pendrive..."
REL="$USBROOT/releases"
[ -d "$REL" ] || REL="$USBROOT"
VERDIR=""
while IFS= read -r dir; do
  [ -f "$dir/autostart.sh" ] && VERDIR="$dir"
done < <(find "$REL" -mindepth 1 -maxdepth 1 -type d | sort -V)

if [ -z "$VERDIR" ]; then
  echo "ERROR: no hay ninguna carpeta de versión con autostart.sh en $REL." >&2
  echo "El kit quedó instalado igual; copia releases/ al pendrive y reinserta." >&2
  exit 1
fi

echo "   Versión a aplicar: $(basename "$VERDIR")"
bash "$VERDIR/autostart.sh"

echo ">> Bootstrap completo. Puedes retirar el pendrive."
echo "   Detalle en /var/log/cdapuestas-usb-update.log"
