# CLAUDE.md

Guía para trabajar en este repositorio. Ver también [docs/historia.md](docs/historia.md)
para el contexto completo de cómo se recuperó y reorganizó el proyecto.

## Qué es esto

App de escritorio de cdapuestas con dos funciones que se pueden compilar por
separado:

1. **Contenedor/webview** ("full"): ventana Electron a pantalla completa que
   abre `APP_URL` (cdapuestas.com) como un kiosko, con `F11`/`F12`/`Escape`
   bloqueadas.
2. **Servicio de impresión** ("socket"): servidor WebSocket en el puerto
   `1315` que recibe texto con tags y lo imprime en una impresora térmica
   ESC/POS.

Ambas comparten el mismo núcleo de impresión (`src/core/`) y se pueden instalar
juntas o por separado en la misma máquina — ver "Los dos builds" abajo.

## Requisitos

- **Node 24** (`.nvmrc`). Corre `nvm use` antes de cualquier `npm` o `node`.
  Cada shell nuevo necesita `nvm use` explícito; no asumas que el Node del
  `PATH` es el correcto sin comprobarlo (`node -v`).
- Linux: para compilar el transporte `spooler` (CUPS) hace falta
  `libcups2-dev` (`sudo apt install libcups2-dev`). El transporte `usb` no lo
  necesita.
- Para el build `full`, recompilar el módulo nativo `usb` contra Electron
  (`postinstall`) requiere un `g++` con soporte para `-std=gnu++20` (GCC 10+).
  En máquinas con un compilador más viejo, `npm install` deja el resto de las
  dependencias instaladas igual; ese paso solo hace falta antes de un build
  `full` real con acceso a USB.

## Arquitectura

```
src/core/            núcleo sin Electron, usable desde el daemon o desde Electron
  config.js          lee .env / variables de entorno con sus defaults
  formatter.js       tags → bytes ESC/POS (ver "Gramática de tags" abajo)
  printer.js         format() + transports.send() en un solo print(texto)
  server.js          servidor WebSocket (start/stop), puerto 1315
  transports/
    usb.js           libusb vía escpos-usb (funciona hoy en Linux)
    spooler.js       RAW al spooler del SO (winspool en Windows, CUPS en Linux)
    hexdump.js       no imprime nada, solo vuelca hex — para pruebas sin impresora
    index.js         resuelve 'auto' según la plataforma, con fallback
  assets/logo.js     logo base64 usado por la tag [CDAPUESTAS]

src/service/index.js  entrypoint del build "socket": arranca core/server, sin Electron
src/app/main.js        entrypoint del build "full": ventana Electron + auto-updater
src/app/preload.js     preload de la ventana (contextIsolation: true)

packaging/linux/       systemd, udev, control/postinst/postrm del .deb del servicio,
                        y la extensión de GNOME que bloquea gestos en kiosko
packaging/windows/     config de WinSW + instalador NSIS del servicio
electron-builder.full.yml   config de electron-builder para el build "full"
```

## Los dos builds

| | comando | qué produce |
|---|---|---|
| Full (Electron) | `npm run build:full:linux` / `:win` | `.deb`/AppImage o `.exe` NSIS con la ventana + el servicio embebido |
| Solo socket | `npm run build:socket:linux` / `:win` | daemon empaquetado con `pkg`, instalado como servicio systemd o de Windows (WinSW), sin ventana |

En dev: `npm run dev` (full, abre Electron) o `npm run dev:socket` (solo el
daemon, `node src/service/index.js`).

Si ambos productos están instalados en la misma máquina, **el build full
detecta si el puerto 1315 ya está en uso** por el servicio `socket` y no
levanta un segundo servidor — ver `startPrintServerIfNeeded()` en
`src/app/main.js`. El `.deb` del servicio (`packaging/linux/debian/control`)
declara `Conflicts`/`Replaces` contra el `.deb` full para que no compitan por
el puerto si alguien intenta instalar los dos paquetes Debian del mismo tipo.

## Gramática de tags (contrato con el frontend)

El texto que llega por WebSocket como `{ text: "..." }` puede traer estas tags
(ver `src/core/formatter.js`, no se debe romper esta gramática sin coordinar
con el equipo de frontend de cdapuestas.com):

`[center] [left] [right] [bold] [underline] [big]` (con su cierre `[/tag]`),
`[line]`, `[cut]`, `[bar]...[/bar]`, `[qr]...[/qr]`, `[img]...[/img]`
(base64), `[table]col1|col2|col3[/table]` (hasta 4 columnas), `[NEXT]`
(salto de línea — funciona como *separador* de línea, así que `[NEXT]`
literal nunca aparece dentro de una línea ya partida), `[FLUSH]` (en el
modelo actual, donde todo el ticket se formatea a un solo buffer antes de
enviarse al transporte, se trata como un salto de línea más — no cierra ni
reabre una conexión real como hacía en el código legado con USB directo) y
`[CDAPUESTAS]` (imprime el logo de `src/core/assets/logo.js`).

## Transporte de impresión

`PRINTER_TRANSPORT` en `.env` (ver `.env.example`):

- `auto` (default): `spooler` en Windows, `usb` en Linux, con fallback al otro
  si el primero falla.
- `usb`: fuerza libusb. Requiere reemplazar el driver de la impresora con
  Zadig/WinUSB en Windows — por eso no es el default ahí.
- `spooler`: fuerza el spooler del sistema (RAW). Usa `PRINTER_NAME` o la
  impresora por defecto.
- `null`: no imprime nada, solo vuelca los bytes ESC/POS en hex — para probar
  el formateador sin hardware.

## Trampas conocidas

- El puerto WebSocket está fijo en `1315` en el código legado que corría en
  producción; en este repo es configurable (`WS_PORT`) pero **el frontend de
  cdapuestas.com asume 1315** — no cambiar el default sin coordinar.
- `packaging/linux/gnome-extension/` es una extensión real de **GNOME
  Shell/GJS**, no código de Electron. El `.deb` original la tenía en
  `src/extension.js` con `module.exports` de CommonJS, que GNOME Shell no
  entiende — nunca llegó a ejecutarse en producción. Se reescribió en formato
  ESM (GNOME Shell 45+) pero no está probada en una instalación real; instalar
  y probar antes de asumir que bloquea gestos.
- `usb` y `escpos-usb` inicializan la impresora de forma perezosa por trabajo
  de impresión (`src/core/transports/usb.js`), no en module scope: la versión
  legada hacía `new escpos.USB()` al cargar el módulo, así que si no había
  impresora conectada el proceso completo reventaba al iniciar.
- Node 24 no tiene binarios precompilados para `@thiagoelg/node-printer`
  todavía en algunas plataformas; por eso es `optionalDependency` y
  `spooler.js` lo `require()` de forma perezosa. Si falta, solo falla el
  transporte `spooler`, no el resto de la app.

## Contribuir / dónde tocar qué

- Cambios a la gramática de tags o al formateo del ticket → `src/core/formatter.js`.
- Nuevo transporte de impresión → agregar en `src/core/transports/` y
  registrarlo en `transports/index.js`.
- Cambios de la ventana/kiosko (teclas bloqueadas, URL, auto-updater) →
  `src/app/main.js`.
- Empaquetado del servicio → `packaging/linux/` y `packaging/windows/`.
