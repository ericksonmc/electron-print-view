# Actualización del printView por USB (kioscos autoservicio)

Para actualizar el printView de las máquinas autoservicio (Linux headless, sin
interfaz, con un watcher bash que relanza el AppImage) sin depender de internet.
El encargado enciende la máquina, inserta el USB y la actualización corre sola
(regla udev). Al terminar, el watcher relanza el printView ya actualizado.

**Una vez instalada esta versión, las siguientes actualizaciones entran solas
por OTA** (el fix de `quitAndInstall` automático ya va incluido en el build que
distribuyas por este USB).

## Qué actualiza

Reemplaza el AppImage del build "full" (`npm run build:full:linux`) por uno
nuevo y reinicia el proceso. No toca autologin, GUI ni el watcher.

## 1. Preparar el USB (una vez por jornada de actualización)

1. Formatea/etiqueta una partición del USB con el label **`CDAUPDATE`**
   (ej. `sudo mkfs.vfat -n CDAUPDATE /dev/sdX1`, o renómbralo con tu gestor).
2. Copia a la **raíz** del USB:
   - El AppImage nuevo (ej. `cdapuestas-webview.AppImage`).
   - El archivo `usb/update.env` de esta carpeta, **ajustado** a tu kiosko
     (`APPIMAGE_FILE`, `INSTALL_PATH`, `PROCESS_MATCH`).

## 2. Preparar cada máquina (una sola vez, no por actualización)

Con permisos de root en la máquina:

```bash
sudo install -m 0755 cdapuestas-usb-update.sh /usr/local/bin/cdapuestas-usb-update.sh
sudo install -m 0644 99-cdapuestas-usb-update.rules /etc/udev/rules.d/99-cdapuestas-usb-update.rules
sudo udevadm control --reload
```

(`cdapuestas-usb-update.sh` está en `bin/`, la regla en `udev/`.)

## 3. Actualizar

Enciende la máquina, inserta el USB `CDAUPDATE` y espera. El script:

1. Monta el USB en solo lectura.
2. Lee `update.env`.
3. Copia el AppImage nuevo (reemplazo atómico) sobre `INSTALL_PATH`.
4. Hace `pkill -f PROCESS_MATCH`; el watcher relanza el AppImage actualizado.

Progreso y resultado quedan en `/var/log/cdapuestas-usb-update.log` y, si se
puede, se muestran en la consola física (`/dev/tty1`).

## Valores a confirmar (⚠️ no están documentados en el repo)

`INSTALL_PATH` y `PROCESS_MATCH` dependen de cómo se instaló el kiosko (el
script de instalación/autologin/watcher vive fuera de este repo). Confírmalos en
una máquina real con `ps aux | grep -i appimage` y revisando el watcher, y
ajústalos en `update.env` antes de distribuir el USB. Los valores actuales son
ejemplos.
