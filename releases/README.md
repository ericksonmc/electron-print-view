# Releases del kiosko (actualizaciones por USB)

Catálogo de actualizaciones del printView ("full" / CD Apuestas WebView) para
los kioscos Ubuntu. Cada actualización es una carpeta versionada **autocontenida**
que se copia tal cual a un pendrive.

## La regla

1. Cada release vive en su propia carpeta nombrada por la versión del `.deb`:

   ```text
   releases/
     1.0.0/
     1.1.0/
     1.2.0/
     ...
   ```

2. Dentro de cada carpeta **siempre** van dos cosas:
   - el `.deb` de esa versión (`cdapuestas-webview-setup-<ver>.deb`), generado
     con `npm run build:full:linux`;
   - `autostart.sh`, el script que se ejecuta al conectar el pendrive e instala
     el `.deb` de **esa misma carpeta**.

3. **Nunca se borra una carpeta anterior.** Se conservan para poder volver a una
   versión previa si una actualización falla (rollback): basta correr el
   `autostart.sh` de la carpeta vieja.

4. Para publicar un update nuevo: crea la carpeta de la nueva versión, copia
   dentro el `.deb` nuevo y una copia de `autostart.sh`, y listo.

## Cómo se aplica en la máquina

El kiosko tiene instalada (una sola vez) la regla udev y el lanzador de
`tools/usb-update/` (ver su README). Al insertar un pendrive con label
`CDAUPDATE`, el lanzador busca en el pendrive la carpeta de versión **más alta**
bajo `releases/` y ejecuta su `autostart.sh`, que:

1. instala el `.deb` de esa carpeta (`apt-get install`),
2. reaplica permisos de `chrome-sandbox`,
3. mata el proceso del WebView; el supervisor lo relanza con la versión nueva.

Para un **rollback** manual: en el pendrive deja solo la carpeta de la versión
anterior (o corre a mano su `autostart.sh`).

## Nota sobre los `.deb` en git

Los `.deb` son binarios grandes (Electron) y **no se versionan en git**
(`.gitignore` los excluye). Lo que se versiona es la estructura y los
`autostart.sh`. El `.deb` de cada versión se coloca físicamente en su carpeta
al preparar el pendrive / en el almacén de releases. Si se quisiera versionar
los binarios, habría que usar Git LFS.

## Por qué `.deb` y no AppImage / OTA

Decisión de diseño documentada en
[`../docs/CD-APUESTAS-KIOSK-DECISIONES-FINALES.md`](../docs/CD-APUESTAS-KIOSK-DECISIONES-FINALES.md):
el `.deb` instala la app formalmente, con rutas estables, permisos y
administración centralizada. AppImage quedó descartado. Por eso electron-updater
(que solo auto-actualiza AppImage) no es la vía, y las actualizaciones van por
este mecanismo de USB.
