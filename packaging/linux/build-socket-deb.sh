#!/bin/bash
# Arma el .deb de cdapuestas-print-service: empaqueta src/service con pkg y
# arma el payload Debian (systemd, udev, usuario de servicio) alrededor.
# Requiere: npm run build:socket:pkg ya ejecutado (genera dist/pkg/).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(node -p "require('$ROOT_DIR/package.json').version")"
STAGE_DIR="$ROOT_DIR/dist/deb-socket"
PKG_BIN="$ROOT_DIR/dist/pkg/cdapuestas-print-service-linux"

if [ ! -f "$PKG_BIN" ]; then
  echo "Falta $PKG_BIN — corre 'npm run build:socket:pkg' primero." >&2
  exit 1
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN"
mkdir -p "$STAGE_DIR/opt/cdapuestas-print-service"
mkdir -p "$STAGE_DIR/lib/systemd/system"
mkdir -p "$STAGE_DIR/etc/udev/rules.d"

cp "$ROOT_DIR/packaging/linux/debian/control" "$STAGE_DIR/DEBIAN/control"
cp "$ROOT_DIR/packaging/linux/debian/postinst" "$STAGE_DIR/DEBIAN/postinst"
cp "$ROOT_DIR/packaging/linux/debian/postrm" "$STAGE_DIR/DEBIAN/postrm"
sed -i "s/^Version:.*/Version: $VERSION/" "$STAGE_DIR/DEBIAN/control"

cp "$PKG_BIN" "$STAGE_DIR/opt/cdapuestas-print-service/cdapuestas-print-service"
chmod 755 "$STAGE_DIR/opt/cdapuestas-print-service/cdapuestas-print-service"

cp "$ROOT_DIR/packaging/linux/systemd/cdapuestas-print.service" "$STAGE_DIR/lib/systemd/system/"
cp "$ROOT_DIR/packaging/linux/systemd/70-cdapuestas-print-usb.rules" "$STAGE_DIR/etc/udev/rules.d/"

dpkg-deb --build --root-owner-group "$STAGE_DIR" "$ROOT_DIR/dist/cdapuestas-print-service-${VERSION}-amd64.deb"

echo "Generado: dist/cdapuestas-print-service-${VERSION}-amd64.deb"
