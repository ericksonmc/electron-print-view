# Estado del printView y reglas de trabajo (2026-11-10)

Resumen de lo que pasó el 2026-11-10 con la impresión en las kioscos, cómo
quedó cada máquina y, sobre todo, **qué se debe y qué no se debe hacer** con el
printView. Si vas a tocar este repo, lee primero la sección de reglas.

## Cómo imprime una kiosk

```
taquilla web (v0-animalitos / v0-triples, en iframe)
  └─ WebSocket ws://127.0.0.1:1315   { text: "[img]logo[/img]\n<ticket>[CUT]" }
       └─ src/core/server.js → formatter.js (tags → bytes ESC/POS)
            └─ transports/index.js  'auto' en Linux:
                 1. usb.js     → escpos-usb → libusb → impresora térmica
                 2. spooler.js → @thiagoelg/node-printer → CUPS   (solo si USB falla)
```

El mensaje "No hay una impresora por defecto configurada" **no es la causa**:
sale del fallback al spooler cuando el USB ya falló. Hay que mirar por qué
falló el USB.

## Qué se rompió y por qué (cronología)

| Versión | Qué pasó |
|---|---|
| 1.1.0 | Se subió `usb` a 3.x (`3b296c8`) para compilar contra Electron 34. `usb` 3.x es una reescritura estilo WebUSB **sin la API clásica**: `escpos-usb` fallaba con `usb.getDeviceList is not a function`. **El USB quedó roto desde aquí.** |
| 1.1.1 | Fija `executableName`. Salió **sin** `@thiagoelg/node-printer`: es `optionalDependency`, falló al compilar con `g++` 9 y `npm` la dejó vacía sin avisar. Error visible: `Cannot find module '@thiagoelg/node-printer'`. |
| 1.1.2 | Incluye `node-printer` (compilado con `CC=gcc-10 CXX=g++-10`), lo agrega a `asarUnpack` y `make build` falla si falta el `.node`. |
| 1.1.3 | `usb` vuelve a 2.x (`^2.14.0`, 2.19.1). Todavía fallaba (`usb.on is not a function`). **No se commiteó** (`releases/1.1.3/` sin versionar). |
| 1.1.4 | Shim en `src/core/transports/usb.js` (los eventos de `usb` 2.x viven en `usb.usb`) y regla udev por fabricante en el `.deb`. Funciona con la Masung (`0519`); no cubría la STMicro (`0483`). |
| 1.1.5 | Regla udev genérica por clase de impresora (`ID_USB_INTERFACES=*:0701*`), reemplaza la de 1.1.4. **Versión estable actual.** |
| 1.1.6 | Agrega `[qr size=N]`/`[qr width=N]` y evita el salto extra después de `[CUT]`. Se probó localmente, pero no se instaló en la flota. |
| 1.1.7 | Rebuild trazable de esos cambios. Instalado y probado el 2026-11-17 en `cda-kiosk-calendario`: el WebSocket confirmó una impresión de QR `[qr size=5]`. |
| 1.1.8 | Reduce de dos a una línea el espacio que deja `[CDAPUESTAS]` tras el logo. Instalado como prueba; reveló que el postinst dejaba el sandbox de Chromium sin SUID en Ubuntu. |
| 1.1.9 | Conserva el ajuste de logo y corrige el postinst: `chrome-sandbox` queda siempre `root:root 4755`. Instalado y relanzado correctamente en `cda-kiosk-calendario` el 2026-11-17. |
| 1.1.10 | Aplica la separación de una línea al tag `[img]`, que es el que usan los tickets de animalitos y triples para su logo. Instalado en `cda-kiosk-calendario` el 2026-11-17. |

Además hay un permiso: la app corre como el usuario de la kiosk, que no está en
el grupo `lp`; sin regla udev `libusb` devuelve `LIBUSB_ERROR_ACCESS`. El
`after-install` del `.deb` (`build/linux/after-install.tpl`) crea
`/etc/udev/rules.d/99-cdapuestas-printer-usb.rules` y borra la de 1.1.4.

## Inventario de kioscos (2026-11-10)

| Kiosk | Acceso | Impresora | Versión |
|---|---|---|---|
| `cda-kiosk-calendario` (oficina) | `cda-kiosk-calendario@192.168.0.30` (LAN) | Masung `0519:2013` | **1.1.10** (probado 2026-11-17) |
| `cdakiosk-001` | `cdakiosk01@100.109.149.26` (Tailscale) | STMicro `0483:5743` | 1.1.5 |
| `cdapuestas-kiosk-002` | `cdapuestaskiosk02@100.81.227.21` (Tailscale) | STMicro `0483:5743` | 1.1.5 |
| `cdapuestas-kiosk-002-1` | `cdapuestas02@100.65.51.32` (Tailscale) | STMicro `0483:5743` | 1.1.5 |

- Dos máquinas comparten el hostname `cdapuestas-kiosk-002`; se distinguen por IP y por usuario.
- Tailscale rechaza SSH con un usuario que no sea el de esa máquina
  (`tailnet policy does not permit you to SSH as user ...`).
- La contraseña de `sudo` la escribe quien actualiza; nunca se guarda en el repo.

## Cómo se actualiza una kiosk por Tailscale

Desde la PC de desarrollo (la kiosk debe estar `Connected` en Tailscale):

```bash
KIOSK=<usuario>@100.x.y.z
scp releases/<ver>/cdapuestas-webview-setup-<ver>.deb $KIOSK:/tmp/
ssh -t $KIOSK 'sudo dpkg -i /tmp/cdapuestas-webview-setup-<ver>.deb \
  && sudo chmod 4755 /opt/cdapuestas_webview/chrome-sandbox; \
  sudo pkill -f "^/opt/cdapuestas_webview/cdapuestas-webview"; \
  dpkg -l cdapuestas-webview | tail -1'
```

El supervisor (`~/bin/start-cdapuestas-webview.sh`) relanza la app a los pocos
segundos. Por USB (pendrive) sigue valiendo `make usb`.

También existe el comando de distribución por lote del `Makefile`:

```bash
# Una kiosk por alias
make tailscale-check KIOSK=cdakiosk-001 # solo prueba la conexión, no instala
make tailscale-update KIOSK=cdakiosk-001
make tailscale-update KIOSK=cdapuestas-kiosk-002
make tailscale-update KIOSK=cdapuestas-kiosk-002-1

# Las tres kioscos, en ese orden
make tailscale-update KIOSK=all
```

El target envía el `.deb` por la entrada estándar de `tailscale ssh`, instala
con `sudo`, reinicia el WebView y valida la versión, la regla udev y el proceso.
No usa `scp` ni guarda la contraseña de `sudo`. Requiere que cada kiosk tenga
**Tailscale SSH habilitado** (`sudo tailscale set --ssh`) y que la ACL del
tailnet autorice el usuario de desarrollo; estar `Connected` o responder a
`tailscale ping` no habilita por sí solo una sesión SSH.

`make tailscale-check KIOSK=<alias|all>` muestra primero el estado de red y
luego intenta una sesión sin modificar nada. Tanto el chequeo como la
actualización tienen timeout, y `tailscale-update` imprime las etapas
`[1/3] red`, `[2/3] transferencia` (con progreso en MB) y `[3/3] instalación`;
si queda esperando, el último mensaje indica exactamente en cuál etapa.

### Deploy paso a paso desde la PC de desarrollo

1. **Ruta de Tailscale (solo si usas la VPN WireGuard `wg0`).** Una VPN full
   tunnel tiene una regla de ruteo (prioridad 99) que le gana a la de Tailscale
   (5270): el TCP hacia `100.x` sale por `wg0` y se pierde. Síntomas: `tailscale
   ping` responde pero `ssh`/`tailscale ssh` dan timeout y tu nodo aparece
   `offline`. Arreglo (se pierde al reiniciar la PC):

   ```bash
   sudo ip rule add to 100.64.0.0/10 lookup 52 priority 90
   ip route get 100.109.149.26   # debe decir "dev tailscale0"
   ```

2. **Verificación de identidad de Tailscale.** Si la ACL usa `check`, el primer
   `tailscale ssh` imprime `To authenticate, visit: https://login.tailscale.com/a/...`.
   Ábrela y aprueba; queda recordado unas horas. Si no hay nadie para aprobar el
   Makefile corta por timeout: sube `TS_CONNECT_TIMEOUT=120`.

3. **Versión y `.deb`.** `node -p "require('./package.json').version"` y
   `ls releases/<ver>/*.deb`. Para una versión nueva: bumpea `package.json` y
   corre `make deploy`.

4. **Instalar, una kiosk a la vez** (pide la contraseña de `sudo` de cada kiosk):

   ```bash
   make tailscale-check KIOSK=cdakiosk-001
   make tailscale-update KIOSK=cdakiosk-001
   make tailscale-update KIOSK=cdapuestas-kiosk-002
   make tailscale-update KIOSK=cdapuestas-kiosk-002-1
   ```

   Empieza por una sola, imprime un ticket real y solo entonces sigue con las
   demás. Límites ajustables: `TS_CONNECT_TIMEOUT` (30 s), `TS_TRANSFER_TIMEOUT` (900 s; el
   `.deb` pesa ~76 MB y por el relay DERP va a ~0,5 MB/s) y `TS_INSTALL_TIMEOUT` (120 s).

5. **Rollback.** Si falla `dpkg`, la versión anterior sigue funcionando. Para
   volver: `DEB=releases/<ver-anterior>/cdapuestas-webview-setup-<ver-anterior>.deb make tailscale-update KIOSK=<alias>`.

Verificación después de actualizar (no dar por buena una kiosk sin esto):

1. `dpkg -l cdapuestas-webview` muestra la versión nueva.
2. Existe `/etc/udev/rules.d/99-cdapuestas-printer-usb.rules` y el nodo
   `/dev/bus/usb/BBB/DDD` de la impresora es `crw-rw-rw-`.
3. Prueba USB directa bajo la ABI de Electron:
   `ELECTRON_RUN_AS_NODE=1 NODE_PATH=/opt/cdapuestas_webview/resources/app.asar/node_modules /opt/cdapuestas_webview/cdapuestas-webview -e '...printUsb(...)'`.
4. Prueba por el socket real: `ws://127.0.0.1:1315` debe responder
   `{"status":"success","message":"Impresión completada."}`.
5. Un ticket de verdad desde la taquilla.

## Reglas: qué se debe hacer

- Cada `.deb` nuevo se instala y prueba primero en
  `cda-kiosk-calendario@192.168.0.30` cuando el kiosco local esté disponible,
  antes de distribuirlo a otras máquinas.
- **Node 24 y `nvm use`** antes de cualquier `npm`/`node`.
- **Compilar `node-printer` con GCC 10+**: `CC=gcc-10 CXX=g++-10 npm install`
  y luego `npx electron-builder install-app-deps` (recompila contra Electron).
  Comprobar que existe
  `node_modules/@thiagoelg/node-printer/build/Release/node_printer.node`.
- **Subir la versión en cada `.deb` que llegue a una máquina**, aunque el
  cambio sea chico. Las kioscos ya tienen instaladas versiones rotas; reinstalar
  el mismo número no deja rastro de qué tenía cada una.
- **Probar bajo Electron, no solo con Node.** El módulo nativo y el shim de
  `usb` se prueban con `ELECTRON_RUN_AS_NODE=1` (ver arriba), porque Node 24 y
  Electron 34 tienen ABI distinta.
- **Mantener `usb` en `^2.x`** y el shim de `usb.js` mientras se use `escpos-usb`.
- **Probar el cambio de impresión en una kiosk real** (hay una en la oficina)
  antes de tocar las demás.
- **Comprobar que la app corre con** `pgrep -f "^/opt/cdapuestas_webview/cdapuestas-webview --force"`.
  El supervisor la abre con `--force-device-scale-factor=2`; un `pgrep` con `$`
  al final da falso negativo.
- **Anclar el patrón del `pkill`** con `^` para no matar la propia sesión SSH.
- **Documentar y commitear** `package.json`, `package-lock.json`, `electron-builder.full.yml`,
  `build/linux/after-install.tpl` y `releases/<ver>/autostart.sh` (el `.deb` no se commitea: está en `.gitignore`).

## Reglas: qué NO se debe hacer

- **No actualizar kioscos sin que el dueño lo pida.** El 2026-11-10 se dijo
  explícitamente: *"si hay que actualizar el printView no lo hagas"*. Si una
  solución exige un printView nuevo, hay que **proponerla y esperar**, y buscar
  primero una alternativa que se resuelva solo en las taquillas web.
- **No subir `usb` a 3.x.** No tiene la API clásica y rompe `escpos-usb`
  (la impresión cae al spooler y falla).
- **No quitar ni "limpiar" el `asarUnpack` de `node-printer`** ni el guard del
  `Makefile`.
- **No tocar la gramática de tags ni el puerto 1315** sin coordinar con las
  taquillas. `[qr]` sin atributos imprime a `size: 10` (~57 mm para una URL
  larga); cupones y tokens dependen de ese tamaño.
- **No usar OTA ni AppImage** en las kioscos: `electron-updater` no actualiza un
  `.deb`. Los errores `No published versions on GitHub` del log son inofensivos.
- **No editar a mano las reglas udev ni `chrome-sandbox`** como solución
  permanente; las gestiona el `.deb`. (`cdakiosk-001` conserva una regla manual
  vieja, `99-usb-printer.rules`, que es inofensiva.)
- **No commitear el `.deb`, contraseñas ni claves de Tailscale.**

## Pendiente (a 2026-11-10)

1. Validar visualmente el ticket de prueba con logo de `1.1.10` en
   `cda-kiosk-calendario`. El servicio confirmó la impresión el 2026-11-17.
2. Antes de instalar `1.1.10` en otra máquina, conservar esa validación y seguir el
   procedimiento de actualización de este documento.
3. `releases/1.1.3/` es una versión intermedia con el shim incompleto; no usarla.
