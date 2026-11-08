#!/usr/bin/env bash
#
# Autostart de actualización del kiosko (CD Apuestas WebView), versión de ESTA
# carpeta. Lo ejecuta el lanzador de tools/usb-update al conectar el pendrive,
# o se puede correr a mano con root para rollback a esta versión.
#
# Instala el .deb que está junto a este script, reaplica el fix de chrome-sandbox
# y reinicia el WebView (el supervisor del kiosko lo relanza con la versión nueva).
# Modelo del kiosko: ../../docs/kiosk-linux.md
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/log/cdapuestas-usb-update.log"
exec >>"$LOG" 2>&1

say() {
  echo "[$(date '+%F %T')] $*"
  [ -w /dev/tty1 ] && echo ">> CDApuestas: $*" >/dev/tty1 2>/dev/null || true
}

say "==== Actualización a $(basename "$HERE") ===="

DEB="$(ls -1t "$HERE"/cdapuestas-webview-*.deb 2>/dev/null | head -n 1 || true)"
if [ -z "${DEB:-}" ] || [ ! -f "$DEB" ]; then
  say "ERROR: no hay .deb en $HERE. Nada que instalar."
  exit 1
fi

say "Instalando $(basename "$DEB")..."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get install -y "$DEB"; then
  say "apt falló; reparando dependencias..."
  dpkg -i "$DEB" || true
  apt-get -f install -y
fi

if [ -x /usr/local/sbin/cdapuestas-fix-sandbox ]; then
  /usr/local/sbin/cdapuestas-fix-sandbox || true
fi

say "Reiniciando el WebView (el supervisor lo relanzará)..."
pkill -f '^/opt/cdapuestas_webview/cdapuestas-webview( |$)' || true

say "Listo. Ya puedes retirar el USB."
