# De dónde salió este proyecto

## El problema original

Este repositorio empezó como el payload desempaquetado de un `.deb` ya
compilado (`cdapuestas-webview_1.0.0_amd64.deb`), instalado en producción. El
compañero que lo desarrolló (Javier) se fue sin compartir el repositorio, y el
remoto original (`Dataweb-C-A/printer-webview` en GitHub) quedó inaccesible.

Durante el análisis del `.deb` apareció el repositorio original completo,
intacto, en otra ruta de esta misma máquina
(`/home/erickson/Dataweb/printer-webview`), con su historial de git y una
copia local de `origin/main` que ya se había descargado antes de perder acceso
al remoto. Ese historial (21 commits) es la base de este repositorio.

## Comparación de las tres versiones del código

Antes de decidir qué usar como base, se compararon tres estados del proyecto:

| | repo local (`HEAD`, 16 commits) | `origin/main` (21 commits) | `.deb` en producción |
|---|---|---|---|
| Puerto WebSocket | `PORT \|\| 8080` | 1315 fijo | 1315 fijo |
| URL del webview | `APP_URL \|\| localhost:3000` | `APP_URL \|\| localhost:3000` | `https://cdapuestas.com` fija en el código |
| `contextIsolation` | `false` | `true` | `false` |
| Auto-updater | no existe | cableado | comentado a mano |
| Tags `[table] [NEXT] [FLUSH] [CDAPUESTAS]` | no | sí | no |
| `extension.js` (bloqueo de gestos GNOME) | no | sí (pero rota, ver abajo) | no |

**Conclusión:** el `.deb` en producción se compiló desde un punto intermedio
del historial — después del fix del puerto y el refactor de imágenes
(`aa82304 Print image in production`), pero antes de las tags nuevas y el
auto-updater (`62052bd`, `c8cf1e2`, `17accd0`). El auto-updater se desactivó a
mano en ese build porque la config de `publish` de `electron-builder` se había
quedado en un placeholder (`owner: "your-github-username"`) — nunca se
configuró de verdad.

Este repositorio se reconstruyó a partir de la punta de `origin/main` (lo más
completo que existe), no del código que corría en producción, y con el
auto-updater configurado de verdad contra
`git@github.com:ericksonmc/electron-print-view.git`.

## Qué se cambió al reorganizar

Además de mover el código a la estructura descrita en
[CLAUDE.md](../CLAUDE.md) (núcleo sin Electron + dos entrypoints), se
corrigieron varios bugs y deudas que ya estaban en `origin/main`:

- **`printer-client.html` era el único cliente de prueba**, no se cargaba
  nunca desde la app real — se movió a `tools/`.
- **`preload.js` exponía `sendToWebSocket`**, un canal IPC
  (`send-to-websocket`) que `main.js` nunca registró del lado del proceso
  principal. Era API muerta desde el primer commit — se eliminó.
- **`nodeIntegration: true` junto a `contextIsolation: true`** no tiene
  sentido (con `contextIsolation` activo, `nodeIntegration` no expone nada al
  renderer, así que solo agregaba superficie de ataque) — se quitó.
- **`new escpos.USB()` se creaba en module scope** de `printer.js`: si no
  había impresora conectada al cargar el módulo, el proceso entero (Electron o
  el daemon) reventaba al iniciar. Se pasó a inicialización perezosa por
  trabajo de impresión.
- **`src/extension.js` nunca pudo haber funcionado**: es código de GNOME
  Shell/GJS (usa `global.stage`, `global.display`) pero estaba escrito con
  `module.exports` de CommonJS, que GNOME Shell no carga así. Se movió a
  `packaging/linux/gnome-extension/` y se reescribió en el formato ESM real
  que exige GNOME Shell 45+, con su `metadata.json`. Sigue sin probarse en una
  instalación real.
- **Dependencias declaradas pero nunca usadas** (`@node-escpos/core`,
  `@node-escpos/usb-adapter`, `imagemagick`, `uuid`,
  `@electron-forge/maker-squirrel`, `electron-prebuilt-compile`): se
  eliminaron del `package.json`.
- El puerto del WebSocket estaba **hardcodeado a 1315** en `websocket.js` a
  pesar de cargar `dotenv` — ahora es configurable (`WS_PORT`) aunque el
  default sigue siendo 1315 porque el frontend de cdapuestas.com lo asume fijo.
