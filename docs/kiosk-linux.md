# Kiosko autoservicio (Ubuntu + GNOME Kiosk)

Cómo quedan configuradas las máquinas autoservicio que corren el build **full**
(CD Apuestas WebView). Documenta lo que hace el instalador
[`cdapuestas-kiosk-setup.sh`](cdapuestas-kiosk-setup.sh) para que se pueda
mantener y actualizar sin reversa. Las instrucciones paso a paso para el
operador están en
[`INSTRUCCIONES-CD-APUESTAS-KIOSK.md`](INSTRUCCIONES-CD-APUESTAS-KIOSK.md).

## Qué es

- **Ubuntu** con sesión **GNOME Kiosk sobre Wayland**
  (`gnome-kiosk-script-wayland`), autologin, sin escritorio ni barras.
- La app se instala como **paquete `.deb`** (`cdapuestas-webview-setup-X.Y.Z.deb`),
  **no** como AppImage. Esto es clave para las actualizaciones (ver abajo).

## Instalación (resumen del script)

`cdapuestas-kiosk-setup.sh` (se ejecuta con sudo; detecta el usuario o se pasa
`--user=`):

1. Respalda la config previa en `/var/backups/cdapuestas-kiosk-FECHA-HORA`.
2. `apt-get install` de dependencias (`gnome-kiosk`, `network-manager`, `curl`,
   `util-linux`) y del `.deb` del Desktop.
3. Corrige permisos de `chrome-sandbox` y deja un servicio systemd
   (`cdapuestas-sandbox-fix.service`) que los reaplica en cada arranque.
4. Crea el **supervisor** y el **script de sesión** (ver abajo).
5. Configura **autologin** en gdm3 y fija la sesión del usuario a
   `gnome-kiosk-script-wayland`.
6. Desactiva bloqueo/suspensión/inactividad de pantalla (dconf) y deja
   NetworkManager con autoconnect.
7. Reinicia (`--reboot`).

Log de instalación: `/var/log/cdapuestas-kiosk-setup.log`.

## Rutas y procesos (lo que hay que conocer para actualizar)

| Qué | Dónde |
|---|---|
| Lanzador | `/usr/bin/cdapuestas-webview` |
| Binario real (Electron) | `/opt/cdapuestas_webview/cdapuestas-webview` |
| chrome-sandbox | `/opt/cdapuestas_webview/chrome-sandbox` (root:root, 4755) |
| Fix de sandbox | `/usr/local/sbin/cdapuestas-fix-sandbox` + `cdapuestas-sandbox-fix.service` |
| Script de sesión (loop) | `~/.local/bin/gnome-kiosk-script` |
| Supervisor (relanza la app) | `~/bin/start-cdapuestas-webview.sh` |
| Autologin | `/etc/gdm3/custom.conf` + `/var/lib/AccountsService/users/<usuario>` |
| Escala de Electron | `--force-device-scale-factor=2.00` |

**Watcher / relanzado:** la sesión corre `gnome-kiosk-script` (un `while true`)
que ejecuta el supervisor, y el supervisor espera conectividad, lanza el binario
con `setsid` y lo **vuelve a abrir si se cierra**. El supervisor identifica el
proceso con el patrón `^/opt/cdapuestas_webview/cdapuestas-webview( |$)` — el
mismo que se usa para reiniciarlo desde fuera (`pkill -f`).

## Actualizar el printView

### Vía USB (actual) — offline

Kit en [`../tools/usb-update/`](../tools/usb-update/): regla udev que, al
insertar un USB con label `CDAUPDATE`, instala el `.deb` nuevo, reaplica el fix
de sandbox y mata el proceso para que el supervisor relance el binario
actualizado. Ver su README.

### Vía OTA (futuro)

El printView ya tiene electron-updater apuntando a GitHub releases
(`ericksonmc/electron-print-view`), chequea al arrancar y cada hora, y aplica
la descarga sola (`quitAndInstall` automático en `update-downloaded`; el
supervisor relanza). **Pero electron-updater solo auto-actualiza el build
AppImage, no un `.deb` instalado en `/opt`.** Como los kioscos usan `.deb`, hoy
el OTA no se auto-aplica; para habilitarlo habría que migrar el kiosko a
AppImage (y ajustar el supervisor a la ruta del AppImage). Mientras tanto, las
actualizaciones van por USB.
