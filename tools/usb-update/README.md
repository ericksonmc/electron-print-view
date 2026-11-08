# Actualización del printView por USB (kioscos autoservicio)

Actualiza el printView ("full" / CD Apuestas WebView) de las máquinas
autoservicio (Ubuntu + GNOME Kiosk, sin interfaz) sin depender de internet. El
encargado enciende la máquina, inserta el USB y la actualización corre sola
(regla udev); el supervisor del kiosko relanza el WebView ya actualizado.

Modelo del kiosko: [`../../docs/kiosk-linux.md`](../../docs/kiosk-linux.md).
Las actualizaciones (el `.deb` + su `autostart.sh`) viven versionadas en
[`../../releases/`](../../releases/) — ver su README para la regla.

## Dos piezas

- **En la máquina (una sola vez):** la regla udev + este lanzador. El lanzador
  NO instala nada; monta el USB, busca la versión más alta bajo `releases/` y
  corre su `autostart.sh`.
- **En el USB (por cada update):** la carpeta de release (`releases/<ver>/`) con
  su `.deb` y su `autostart.sh`, que es quien instala realmente.

## 1. Preparar cada máquina (una sola vez)

Con root en la máquina:

```bash
sudo install -m 0755 bin/cdapuestas-usb-update.sh /usr/local/bin/cdapuestas-usb-update.sh
sudo install -m 0644 udev/99-cdapuestas-usb-update.rules /etc/udev/rules.d/99-cdapuestas-usb-update.rules
sudo udevadm control --reload
```

## 2. Preparar el USB (por cada actualización)

1. Etiqueta una partición del USB con el label **`CDAUPDATE`**
   (ej. `sudo mkfs.vfat -n CDAUPDATE /dev/sdX1`).
2. Copia a la raíz del USB la carpeta `releases/` (o al menos la carpeta de la
   versión a instalar), con el `.deb` dentro de cada versión.

El lanzador aplica la **versión más alta** presente. Para un rollback, deja en
el USB solo la carpeta de la versión anterior.

## 3. Actualizar

Enciende la máquina e inserta el USB `CDAUPDATE`. Progreso y resultado quedan en
`/var/log/cdapuestas-usb-update.log` y, si se puede, en la consola física
(`/dev/tty1`).
