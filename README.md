# cdapuestas print-view

App de escritorio de cdapuestas: contenedor/webview a pantalla completa +
servicio de impresión ESC/POS por WebSocket. Se compila como dos productos
independientes — ver [CLAUDE.md](CLAUDE.md) para la arquitectura completa y
[docs/historia.md](docs/historia.md) para de dónde salió este código.

## Requisitos

- Node 24 (`nvm use`)
- Linux: `libcups2-dev` si vas a usar/compilar el transporte `spooler`
- Windows/Linux con impresora térmica ESC/POS conectada por USB, o instalada
  en el sistema (spooler)

## Instalación

```bash
nvm use
npm install
cp .env.example .env   # ajustar APP_URL / PRINTER_TRANSPORT / PRINTER_NAME
```

## Desarrollo

```bash
npm run dev          # modo full: ventana Electron + servicio de impresión
npm run dev:socket   # solo el servicio de impresión (sin Electron)
```

Para probar la impresión sin hardware: `PRINTER_TRANSPORT=null npm run
dev:socket` y abrir `tools/printer-client.html` en el navegador para mandar
tickets de prueba por WebSocket.

## Configuración (`.env`)

| Variable | Default | Descripción |
|---|---|---|
| `APP_URL` | `https://cdapuestas.com` | URL que abre el modo full |
| `WS_HOST` | `127.0.0.1` | host del WebSocket de impresión |
| `WS_PORT` | `1315` | puerto del WebSocket (el frontend lo asume fijo) |
| `PRINTER_TRANSPORT` | `auto` | `auto` \| `usb` \| `spooler` \| `null` |
| `PRINTER_NAME` | (vacío) | nombre de impresora en el spooler; vacío = por defecto |

## Builds

```bash
npm run build:full:linux    # .deb / AppImage con ventana + servicio embebido
npm run build:full:win      # instalador NSIS con ventana + servicio embebido
npm run build:socket:linux  # .deb del servicio, sin ventana (systemd)
npm run build:socket:win    # instalador NSIS del servicio, sin ventana (WinSW)
```

Ambos productos pueden convivir en la misma máquina: si el servicio de
impresión ya está corriendo, el build full no levanta un segundo servidor en
el puerto 1315.

## Licencia

MIT — ver [LICENSE](LICENSE).
