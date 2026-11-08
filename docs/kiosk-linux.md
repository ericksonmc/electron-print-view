# Kiosko autoservicio (Ubuntu + GNOME Kiosk)

Cómo quedan configuradas las máquinas autoservicio que corren el build **full**
(CD Apuestas WebView). Documenta lo que hace el instalador
[`cdapuestas-kiosk-setup.sh`](cdapuestas-kiosk-setup.sh) para que se pueda
mantener y actualizar sin reversa. Las instrucciones paso a paso para el
operador están en
[`INSTRUCCIONES-CD-APUESTAS-KIOSK.md`](INSTRUCCIONES-CD-APUESTAS-KIOSK.md), y el
**porqué** de cada decisión (por qué `.deb` y no AppImage, GNOME Kiosk,
supervisor, espera de red, escala, etc.) en
[`CD-APUESTAS-KIOSK-DECISIONES-FINALES.md`](CD-APUESTAS-KIOSK-DECISIONES-FINALES.md).

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
| Escala de Electron | `--force-device-scale-factor` (ver nota) |

**Watcher / relanzado:** la sesión corre `gnome-kiosk-script` (un `while true`)
que ejecuta el supervisor, y el supervisor espera conectividad, lanza el binario
con `setsid` y lo **vuelve a abrir si se cierra**. El supervisor identifica el
proceso con el patrón `^/opt/cdapuestas_webview/cdapuestas-webview( |$)` — el
mismo que se usa para reiniciarlo desde fuera (`pkill -f`).

> **Escala:** el setup de referencia usa `--force-device-scale-factor=2.00`,
> pero según la nota en DECISIONES-FINALES el valor final pudo quedar en `1` o
> `1.25` (sin confirmar contra las máquinas). **No cambiar sin verificar** el
> script real de la máquina — el valor equivocado descuadra la interfaz.

## Actualizar el printView (USB, mecanismo oficial)

La vía oficial es por **USB**, porque la app se distribuye como `.deb`
(decisión documentada en DECISIONES-FINALES; AppImage quedó descartado).

- Las actualizaciones viven versionadas en [`../releases/`](../releases/):
  una carpeta por versión (`1.0.0/`, `1.1.0/`, …), cada una con su `.deb` y su
  `autostart.sh`. **Se conservan las versiones anteriores para rollback.** Ver
  [`../releases/README.md`](../releases/README.md).
- En cada máquina se instala una sola vez la regla udev + el lanzador de
  [`../tools/usb-update/`](../tools/usb-update/). Al insertar un USB con label
  `CDAUPDATE`, el lanzador busca la versión más alta bajo `releases/` y corre su
  `autostart.sh`, que instala el `.deb`, reaplica el fix de sandbox y reinicia
  el WebView (el supervisor lo relanza con la versión nueva).

### Sobre el OTA (no se usa)

El printView tiene electron-updater configurado (GitHub releases
`ericksonmc/electron-print-view`, chequeo al arrancar y cada hora, con
`quitAndInstall` automático en `update-downloaded`). Pero electron-updater
**solo auto-actualiza el build AppImage, no un `.deb`** en `/opt`, y el `.deb`
es la decisión oficial. Por eso el OTA **no es la vía** en los kioscos; el
código queda por si algún día se evalúa AppImage, pero las actualizaciones van
por el USB de arriba.
