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
WANT="$(basename "$HERE")"
PKG="cdapuestas-webview"
LOG="/var/log/cdapuestas-usb-update.log"
exec >>"$LOG" 2>&1

say() {
  echo "[$(date '+%F %T')] $*"
  [ -w /dev/tty1 ] && echo ">> CDApuestas: $*" >/dev/tty1 2>/dev/null || true
}

say "==== Actualización a $WANT ===="

DEB="$(ls -1t "$HERE"/cdapuestas-webview-*.deb 2>/dev/null | head -n 1 || true)"
if [ -z "${DEB:-}" ] || [ ! -f "$DEB" ]; then
  say "ERROR: no hay .deb en $HERE. Nada que instalar."
  exit 1
fi

say "Instalando $(basename "$DEB")..."
export DEBIAN_FRONTEND=noninteractive
if ! apt-get install -y --allow-downgrades "$DEB"; then
  say "apt-get install falló; intentando dpkg + 'apt-get -f install'..."
  dpkg -i "$DEB" || true
  apt-get -f install -y || true
fi

# Confirmar que realmente quedó instalada la versión esperada. apt/dpkg pueden
# "terminar" sin aplicar nada (p. ej. choque de archivos por otro paquete), así
# que verificamos contra dpkg antes de cantar éxito.
GOT="$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null || true)"
if [ "$GOT" != "$WANT" ]; then
  say "ERROR: la versión instalada de $PKG es '${GOT:-ninguna}', se esperaba '$WANT'. El update NO se aplicó."
  exit 1
fi
say "Versión instalada confirmada: $PKG $GOT"

# chrome-sandbox: en estos kioscos (Ubuntu 24.04, con user-namespaces no
# privilegiados restringidos por AppArmor) el sandbox SUID tiene que quedar en
# 4755 root:root. El postinst del .deb a veces lo deja en 0755 (cree que puede
# usar el sandbox de user-ns), y entonces Electron no arranca. Forzamos 4755.
SANDBOX="/opt/cdapuestas_webview/chrome-sandbox"
if [ -x /usr/local/sbin/cdapuestas-fix-sandbox ]; then
  /usr/local/sbin/cdapuestas-fix-sandbox || true
elif [ -f "$SANDBOX" ]; then
  chown root:root "$SANDBOX" || true
  chmod 4755 "$SANDBOX" || true
fi

say "Reiniciando el WebView (donde haya supervisor, lo relanzará)..."
pkill -f '^/opt/cdapuestas_webview/cdapuestas-webview( |$)' || true

say "Listo. Ya puedes retirar el USB."
