# CLAUDE.md

Guía para trabajar en este repositorio. Ver también
[docs/historia.md](docs/historia.md) para el contexto completo de cómo se
recuperó y reorganizó el proyecto,
[docs/windows-build.md](docs/windows-build.md) para compilar en Windows
(toolchain nativo, `pkg`, WinSW, NSIS), y
[docs/kiosk-linux.md](docs/kiosk-linux.md) para cómo quedan configuradas las
máquinas autoservicio (Ubuntu + GNOME Kiosk, instalación por `.deb`, supervisor,
autologin) y cómo se actualizan (USB en `tools/usb-update/`, y el límite del OTA
con `.deb`).

**Antes de tocar impresión o de actualizar una kiosk, lee
[docs/estado-y-reglas-2026-11-10.md](docs/estado-y-reglas-2026-11-10.md):** estado
de cada máquina, qué se rompió (`usb` 3.x, `node-printer` sin compilar, permisos
udev) y las reglas de qué se debe y qué no se debe hacer. La más importante:
**no actualices kioscos sin que te lo pidan**; si una solución exige un printView
nuevo, propónla y espera.

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
  `libcups2-dev` (`sudo apt install libcups2-dev`) **y** un `g++` con soporte
  para `-std=gnu++20` (GCC 10+) — con GCC 9.x (p. ej. Ubuntu 20.04 de fábrica)
  falla con `unrecognized command line option '-std=gnu++20'`. El transporte
  `usb` no necesita ninguna de las dos cosas.
- `usb` 2.x trae binarios N-API precompilados, así que ya no se compila. El
  `postinstall` sí recompila `node-printer` contra Electron: en una máquina con
  GCC 9 por defecto, exporta `CC=gcc-10 CXX=g++-10` antes de `npm install`.
- `@thiagoelg/node-printer` es `optionalDependency`: si el compilador del
  sistema no cumple lo anterior, `npm install` lo deja sin compilar pero no
  falla — solo queda inutilizable el transporte `spooler` en esa máquina en
  particular (el resto de la app funciona normal).

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
  transporte `spooler`, no el resto de la app. **Pero un `.deb` sin él sale roto
  sin aviso** (pasó con 1.1.1): compílalo con `CC=gcc-10 CXX=g++-10 npm install`
  y `npx electron-builder install-app-deps`; `make build` falla si falta el `.node`.
- **`usb` debe quedarse en `^2.x`.** La 3.x no tiene la API clásica que usa
  `escpos-usb` (`usb.getDeviceList`) y la impresión por USB deja de funcionar.
  `usb.js` lleva un shim porque en 2.x los eventos viven en `usb.usb`.
- Los permisos USB los da `build/linux/after-install.tpl` (regla udev genérica
  para clase impresora). Sin ella, `LIBUSB_ERROR_ACCESS`.
- `[qr]` se ajusta a un ancho máximo de 160 puntos (~20 mm). El frontend lo
  cambia con `[qr width=N]` (puntos, 8 ≈ 1 mm) o fija el módulo con
  `[qr size=N]`. Hasta la 1.1.5 era `size: 10` fijo (~57 mm) y los atributos se
  ignoraban.
- "No hay una impresora por defecto configurada" viene del fallback al spooler:
  la causa real casi siempre es que falló el USB.

## Contribuir / dónde tocar qué

- Cambios a la gramática de tags o al formateo del ticket → `src/core/formatter.js`.
- Nuevo transporte de impresión → agregar en `src/core/transports/` y
  registrarlo en `transports/index.js`.
- Cambios de la ventana/kiosko (teclas bloqueadas, URL, auto-updater) →
  `src/app/main.js`.
- Empaquetado del servicio → `packaging/linux/` y `packaging/windows/`.
