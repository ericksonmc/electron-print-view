# Actualización del printView por USB (kioscos autoservicio)

Para actualizar el printView ("full" / CD Apuestas WebView) de las máquinas
autoservicio (Ubuntu + GNOME Kiosk, sin interfaz) sin depender de internet. El
encargado enciende la máquina, inserta el USB y la actualización corre sola
(regla udev). Al terminar, el supervisor del kiosko relanza el WebView ya
actualizado.

El modelo del kiosko (instalación, supervisor, autologin) está documentado en
[`../../docs/kiosk-linux.md`](../../docs/kiosk-linux.md).

## Qué hace

1. Instala el `.deb` nuevo de CD Apuestas WebView (actualiza
   `/opt/cdapuestas_webview/...`).
2. Reaplica permisos de `chrome-sandbox` (`/usr/local/sbin/cdapuestas-fix-sandbox`).
3. Mata el proceso del WebView; el supervisor
   (`~/bin/start-cdapuestas-webview.sh`) lo relanza con el binario nuevo.

No toca autologin, sesión GNOME Kiosk ni el supervisor.

## 1. Preparar el USB (por cada actualización)

1. Etiqueta una partición del USB con el label **`CDAUPDATE`**
   (ej. `sudo mkfs.vfat -n CDAUPDATE /dev/sdX1`).
2. Copia a la **raíz** del USB:
   - El `.deb` nuevo (ej. `cdapuestas-webview-setup-1.1.0.deb`), generado con
     `npm run build:full:linux`.
   - (Opcional) copia `usb/update.env.example` como `update.env` solo si tu
     setup difiere de los defaults; en general no hace falta, el script toma el
     `.deb` más nuevo del USB.

## 2. Preparar cada máquina (una sola vez, no por actualización)

Con root en la máquina:

```bash
sudo install -m 0755 bin/cdapuestas-usb-update.sh /usr/local/bin/cdapuestas-usb-update.sh
sudo install -m 0644 udev/99-cdapuestas-usb-update.rules /etc/udev/rules.d/99-cdapuestas-usb-update.rules
sudo udevadm control --reload
```

## 3. Actualizar

Enciende la máquina, inserta el USB `CDAUPDATE` y espera. El progreso y el
resultado quedan en `/var/log/cdapuestas-usb-update.log` y, si se puede, se
muestran en la consola física (`/dev/tty1`).

## Nota sobre OTA

electron-updater (ya configurado en el printView contra GitHub releases) solo
**auto-actualiza el build AppImage**, no un paquete `.deb` instalado en `/opt`.
Como los kioscos usan `.deb`, las actualizaciones van por este USB. Si en el
futuro se migra el kiosko a AppImage, el OTA se aplicaría solo (el printView ya
hace `quitAndInstall` automático en `update-downloaded` y el supervisor
relanza). Ver [`../../docs/kiosk-linux.md`](../../docs/kiosk-linux.md).
