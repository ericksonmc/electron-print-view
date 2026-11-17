# Plugin de impresión para PCs de agencia

Segundo `.deb` del repo: solo el servicio de impresión (WebSocket `ws://127.0.0.1:1315`),
**sin WebView**. Es para las PCs de agencia donde el personal usa el navegador
normal porque vende varios productos en distintos sistemas y no se puede
restringir la máquina como en un kiosco.

| | WebView (kioscos) | Plugin (agencias) |
|---|---|---|
| Paquete | `cdapuestas-webview` | `cdapuestas-print-service` |
| Archivo | `cdapuestas-webview-setup-<ver>.deb` | `cdapuestas-print-service-<ver>-amd64.deb` |
| Qué instala | Electron a pantalla completa + servicio embebido | daemon systemd sin ventana (binario `pkg` con Node 24, todo embebido) |
| Ruta | `/opt/cdapuestas_webview/` | `/opt/cdapuestas-print-service/` |
| Corre como | usuario de la kiosk | usuario de sistema `cdapuestas-print` (systemd `cdapuestas-print.service`) |
| Config | `.env` | `/etc/cdapuestas-print/service.env` (variables de `.env.example`) |
| Log | — | `/var/log/cdapuestas-print/service.log` |

Ambos usan el mismo núcleo (`src/core/`), así que cualquier cambio de impresión
(formatter, transportes) entra en los dos. Ambos declaran `Conflicts`/`Replaces`
entre sí: **no se instalan juntos en la misma máquina**.

## Generar

Con una sola versión en `package.json` salen los dos:

```bash
nvm use
make deploy        # build (webview) + build-plugin + release
```

- `make build-plugin` genera solo el plugin: `dist/cdapuestas-print-service-<ver>-amd64.deb`.
- `make release` copia ambos `.deb` a `releases/<ver>/`. El `autostart.sh` de los
  kioscos solo instala `cdapuestas-webview-*.deb`, así que el plugin no se
  cuela en una actualización por pendrive.

Detalles del build: `npm run build:socket:linux` corre `pkg` con
`node24-linux-x64` (`node20` obligaba a compilar Node desde fuente y fallaba) y
luego `packaging/linux/build-socket-deb.sh`.

## Dependencias: qué trae cada instalador

El objetivo es que instalar no falle por dependencias ni necesite internet.

**`.deb` (Linux)**
- Node va **embebido** en el binario (`pkg`, Node 24); no hace falta Node en la máquina.
- `libusb` viene compilado dentro del módulo `usb`; su única librería extra,
  `libudev.so.1`, se empaqueta en `/opt/cdapuestas-print-service/lib/`
  (copia en `packaging/linux/lib/`, para que el build sea igual en cualquier
  máquina) y el servicio la carga con `LD_LIBRARY_PATH` desde la unit systemd.
- `Depends` solo pide `libc6 (>= 2.31)`, `libstdc++6` y `libgcc-s1`, que están
  en cualquier Ubuntu 20.04+/Debian 11+ de escritorio o servidor.
- El `postinst` usa `groupadd`/`useradd` (base del sistema), no `adduser`.
- Probado: `dpkg -i` en contenedores limpios de Ubuntu 24.04 y Debian 11 sin
  instalar nada más (en Ubuntu 20.04 el binario arrancó, no se repitió la
  instalación completa tras el último cambio). Requisito: amd64 con systemd.

**`.exe` (Windows)**
- `cda-print-view-core.exe` lleva Node embebido y no necesita el Visual C++
  Redistributable (solo DLLs del propio Windows).
- El `node_printer.node` solo usa `KERNEL32` y `WINSPOOL.DRV`; `usb` usa su
  binario N-API precompilado.
- WinSW (`WinSW-x64.exe` v2.12.0) es un ejecutable de .NET autocontenido: no
  requiere tener .NET instalado. El script avisa si lo descargado pesa muy poco
  (señal de que sería la variante que sí lo necesita).
- El instalador NSIS solo copia archivos; no descarga nada.
- Windows 10/11 x64.

## Instalar / actualizar en una agencia

Copia el `.deb` a la PC y, con la misma versión nueva encima de la vieja:

```bash
sudo apt install ./cdapuestas-print-service-<ver>-amd64.deb
```

El `postinst` crea el usuario de servicio, instala la regla udev, habilita y
reinicia el servicio. Comprobar:

```bash
systemctl status cdapuestas-print.service
dpkg -s cdapuestas-print-service | grep ^Version
```

## Permisos USB

Se instala la misma regla udev que usa el WebView
(`/etc/udev/rules.d/99-cdapuestas-printer-usb.rules`, `MODE="0666"` para
cualquier dispositivo con interfaz de impresora, clase 07). Sin ella libusb da
`LIBUSB_ERROR_ACCESS` porque el servicio no corre como root.

## Probar sin impresora

```bash
WS_PORT=13150 PRINTER_TRANSPORT=null dist/pkg/cdapuestas-print-service-linux
```

Con `PRINTER_TRANSPORT=usb` y sin impresora debe responder
`Can not find printer`; si aparece un error de módulo, el empaquetado falló.

## Instalador Windows (.exe) del plugin

Es el mismo plugin pero como servicio de Windows (WinSW, id `cda-print-view`,
arranque automático, puerto 1315): `dist\cda-print-view-setup-<ver>.exe`.
Se compila **en una máquina Windows** (los módulos nativos no se cruzan desde
Linux). Detalle de cada problema de toolchain en
[windows-build.md](windows-build.md).

### Requisitos (una sola vez en la máquina de build)

- **Node 24** (`node -v` debe dar `v24.x`; `.nvmrc` lo pide).
- **Python 3.12** con `setuptools` (`python -m pip install --upgrade setuptools`)
  y la variable `PYTHON` apuntando al `python.exe` real si `node-gyp` no lo
  encuentra (`$env:PYTHON = "C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe"`).
- **Visual Studio Build Tools 2022**: workload "Desktop development with C++"
  **más** los componentes Clang (`VC.Llvm.Clang` y `VC.Llvm.ClangToolset`).
- **Git para Windows** y **NSIS** (`makensis` en el `PATH`:
  `winget install NSIS.NSIS`, luego reabrir la terminal).
- Acceso a GitHub: el script descarga `WinSW-x64.exe` (v2.12.0, formato de
  XML v2 que usa `cda-print-view.xml`; no subir a v3 sin revisar el XML).

### Pasos

```powershell
git clone git@github.com:ericksonmc/electron-print-view.git
cd electron-print-view
.\packaging\windows\build-socket-exe.ps1
```

El script hace, en orden: `npm ci`, `npm rebuild @thiagoelg/node-printer`
(ABI de Node, no de Electron), `npm run build:socket:win` (`pkg` →
`dist\win-socket\cda-print-view-core.exe`), descarga WinSW como
`dist\win-socket\cda-print-view.exe`, `makensis installer-socket.nsi` y renombra
el resultado con la versión de `package.json`. Si algo falla, los pasos manuales
equivalentes están en [windows-build.md](windows-build.md), sección 4.

> El script está escrito a partir de esa guía pero **no se ha corrido todavía**;
> si falla, usa los pasos manuales y corrige el script.

### Instalar y verificar en la agencia

1. Ejecutar el `.exe` como administrador. Si ya había una versión, la detiene,
   la reemplaza y vuelve a registrar el servicio.
2. La impresora debe estar instalada en Windows; el transporte por defecto
   (`auto`) usa el spooler con la impresora predeterminada del sistema.
   Para otra, define `PRINTER_NAME` en `packaging\windows\cda-print-view.xml`
   antes de compilar.
3. Comprobar:
   ```powershell
   Get-Service cda-print-view
   Get-Content "$env:ProgramData\cda-print-view\logs\cda-print-view.wrapper.log" -Tail 30
   ```
4. Si hay problemas de impresión, `installer-socket-debug.nsi` genera una
   variante con log detallado (se compila igual, cambiando el `.nsi`).

No hay versión de Windows para el WebView de kioscos: los kioscos son Linux.

## Pendiente

- No se probó la instalación en una PC de agencia real (solo el build, el
  contenido del `.deb` y el binario en local). Probar en una antes de repartirlo.
- El `.exe` no se ha generado con `build-socket-exe.ps1` (el build manual sí se probó, ver `windows-build.md`).
- El transporte `spooler` (CUPS) no va en el plugin: `node-printer` está
  compilado contra Electron, no contra Node. En Linux el default es `usb`.
