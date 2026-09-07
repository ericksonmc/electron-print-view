# Compilar en Windows

Esta guía es para compilar el proyecto **directamente en una máquina
Windows** (no cruzado desde Linux con `wine`). Hace falta sobre todo para
compilar los módulos nativos (`usb`, `escpos-usb`, `@thiagoelg/node-printer`),
que en Linux fallaron en esta sesión por un compilador viejo (ver
[CLAUDE.md](../CLAUDE.md)) — en Windows el compilador es otro (MSVC, no g++) y
no debería tener ese problema, pero sí necesita su propio toolchain.

## 1. Requisitos previos

- **Node 24 LTS** — instalar desde [nodejs.org](https://nodejs.org/) (el
  instalador `.msi` ya trae `npm`) o con
  [nvm-windows](https://github.com/coreybutler/nvm-windows`).
  Verificar con `.nvmrc` en la raíz del proyecto (pide `24`).
- **Python 3.x** — lo usa `node-gyp` para generar los archivos de build.
  Instalar desde [python.org](https://python.org) marcando "Add python.exe to
  PATH", o con `winget install Python.Python.3.12`.
- **Visual Studio Build Tools** con el workload **"Desktop development with
  C++"**. Es lo que reemplaza a g++/make en Windows y trae el compilador MSVC
  + el Windows SDK (necesario para `@thiagoelg/node-printer`, que habla con
  `winspool.drv`).
  - Instalar desde
    [visualstudio.microsoft.com/downloads](https://visualstudio.microsoft.com/downloads/)
    → "Build Tools for Visual Studio" → seleccionar el workload
    "Desktop development with C++".
  - Alternativa rápida por línea de comandos (PowerShell como administrador):
    ```powershell
    winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
    ```
- **Git para Windows** (con OpenSSH incluido, para clonar por SSH si aplica).
- Confirmar que `node-gyp` encuentra el toolchain:
  ```powershell
  npx node-gyp configure
  ```
  Si falla pidiendo compilador, correr `npm config set msvs_version 2022`
  (ajustar al año de VS instalado) y reintentar.

## 2. Instalar dependencias del proyecto

```powershell
git clone git@github.com:ericksonmc/electron-print-view.git
cd electron-print-view
nvm use 24        # o confirmar `node -v` si Node 24 ya es el activo
npm install
```

Con Build Tools instalado correctamente, `npm install` debería compilar sin
problema tanto `usb`/`escpos-usb` (transporte USB/libusb) como
`@thiagoelg/node-printer` (transporte `spooler`, el que se usa por defecto en
Windows — ver `PRINTER_TRANSPORT=auto` en `src/core/transports/index.js`).

Si `postinstall` (`electron-builder install-app-deps`) falla igual, correrlo
a mano para ver el error completo:

```powershell
npx electron-builder install-app-deps
```

## 3. Impresora: spooler vs USB

- **Transporte `spooler` (default en Windows, recomendado):** no requiere
  nada especial — la impresora debe estar instalada normalmente en Windows
  (Configuración → Impresoras). `PRINTER_NAME` en `.env` puede dejarse vacío
  para usar la impresora por defecto del sistema.
- **Transporte `usb` (forzado con `PRINTER_TRANSPORT=usb`):** requiere
  reemplazar el driver de la impresora con
  [Zadig](https://zadig.akeo.ie/) por **WinUSB**, lo que la saca del spooler
  normal de Windows. Solo usar esto si `spooler` no funciona con el modelo de
  impresora en cuestión.

## 4. Compilar los dos productos

### Build "full" (ventana + servicio embebido)

```powershell
npm run build:full:win
```

Genera el instalador NSIS en `dist\full\` según
[electron-builder.full.yml](../electron-builder.full.yml) (targets `nsis`
x64 e ia32).

### Build "socket" (solo el servicio, sin ventana)

1. Compilar el binario del daemon con `pkg`:
   ```powershell
   npm run build:socket:win
   ```
   Esto genera `dist\win-socket\cdapuestas-print-service-core.exe`
   (ver `pkg.config.json` y el script `build:socket:pkg` en `package.json`).

2. Descargar [WinSW](https://github.com/winsw/winsw/releases) (`WinSW-x64.exe`
   de la última release), renombrarlo a `cdapuestas-print-service.exe` y
   copiarlo a `dist\win-socket\` junto al `.exe` del paso anterior.

3. Instalar [NSIS](https://nsis.sourceforge.io/Download) (trae `makensis`) y
   compilar el instalador:
   ```powershell
   cd packaging\windows
   makensis installer-socket.nsi
   ```
   El resultado queda en `dist\cdapuestas-print-service-setup.exe`. Ese
   instalador copia los tres archivos, registra el servicio de Windows vía
   WinSW (usando `cdapuestas-print.xml`) y lo arranca — ver
   [installer-socket.nsi](../packaging/windows/installer-socket.nsi).

## 5. Verificar el servicio instalado

```powershell
Get-Service "CDApuestas Print Service"
Get-Content "$env:ProgramData\cdapuestas-print\logs\cdapuestas-print-service.wrapper.log" -Tail 30
```

El servicio debe quedar escuchando en `ws://127.0.0.1:1315` (o el puerto que
se haya configurado en `.env` / la variable `PRINTER_TRANSPORT` en
`cdapuestas-print.xml`).

## Notas

- Todo lo de esta guía es **la contraparte Windows** de
  `packaging/linux/build-socket-deb.sh` y del build `full` para Linux — la
  arquitectura y los scripts de `package.json` son los mismos, solo cambia el
  toolchain nativo y el empaquetador final (NSIS/WinSW en vez de
  dpkg-deb/systemd).
- Nada de esto se pudo probar en una máquina Windows real durante esta
  sesión (se hizo desde Ubuntu) — antes de confiar en el instalador para
  producción, correrlo una vez en un Windows limpio y confirmar que imprime.
