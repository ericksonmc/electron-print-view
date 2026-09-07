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

### 2.1. Problemas reales encontrados compilando en Windows (Node 24)

Estos cuatro problemas aparecieron, en este orden, la primera vez que se
compiló este repo en una máquina Windows limpia con Node 24. Ya están
resueltos en el código de este repo (parches en `binding.gyp` y
`node_printer_win.cc` dentro de `node_modules/@thiagoelg/node-printer` — se
pierden si se borra `node_modules` y no se vuelven a aplicar, ver más abajo),
pero se documentan por si:
- `npm install`/`npm rebuild` los vuelve a mostrar tras un `node_modules`
  limpio,
- se actualiza la versión de `@thiagoelg/node-printer` y el fix ya no aplica,
- alguien compila en otra máquina Windows desde cero.

1. **`node-gyp` no encuentra Python aunque esté instalado.** Si Python se
   instaló sin marcar "Add to PATH" (p. ej. desde el `.msi` de python.org o
   `winget install Python.Python.3.12`), Windows resuelve `python`/`python3`
   al alias stub de la Microsoft Store, y además puede haber un registro
   viejo de otra versión de Python en el sistema que `node-gyp` intenta usar
   y falla. Fijar la variable de entorno `PYTHON` a la ruta completa antes de
   instalar:
   ```powershell
   $env:PYTHON = "C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe"
   npm install
   ```

2. **`ModuleNotFoundError: No module named 'distutils'`.** Python 3.12
   eliminó `distutils` de la librería estándar, pero la versión de `gyp` que
   trae `node-gyp` todavía lo importa. Se soluciona instalando `setuptools`
   (que registra un shim de `distutils` vía un archivo `.pth` que se activa
   solo al arrancar Python, sin tocar nada más):
   ```powershell
   python -m pip install --upgrade setuptools
   ```

3. **`error MSB8020: No se pueden encontrar las herramientas de compilación
   para ClangCL`.** Los binarios oficiales de Node.js para Windows (al menos
   desde la serie 24.x) están compilados con Clang, y `node-gyp` genera
   `config.gypi` con `"clang": 1` reflejando ese dato de
   `process.config.variables.clang` del propio Node que corre `npm` —, así
   que exige el mismo toolset para los módulos nativos. El workload "Desktop
   development with C++" **no** incluye el compilador Clang por defecto; hay
   que agregar el componente aparte a una instalación de Build Tools ya
   existente:
   ```powershell
   & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify `
     --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
     --add Microsoft.VisualStudio.Component.VC.Llvm.Clang `
     --add Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset `
     --quiet --norestart
   ```
   Ojo: **no** usar `--wait` (no es una opción válida de `setup.exe modify`,
   revienta el parseo de argumentos) ni correrlo sin permisos de
   administrador (falla con "Commands with --quiet or --passive should be
   run elevated from the beginning", exit code 5007) — correrlo desde una
   PowerShell "Ejecutar como administrador". El paso de descarga puede tardar
   varios minutos en quedarse aparentemente colgado en
   "Didn't find any channel feed." — es normal, solo esperar.

4. **Con ClangCL ya instalado, sigue sin compilar `@thiagoelg/node-printer`
   por bugs propios del paquete, no del toolchain:**
   - `"C++20 or later required"` / errores de `std::optional`, `concept`,
     `requires`, etc.: el `binding.gyp` del paquete no fija ningún estándar
     de C++, y `node-gyp` genera un `LanguageStandard` en el `.vcxproj` que
     el generador de gyp para MSBuild no traduce bien al toolset ClangCL
     (aparece el warning "unrecognized setting VCCLCompilerTool/
     LanguageStandard while converting to MSBuild" y el flag se pierde).
     Solución: agregar en `binding.gyp`, dentro de `conditions`, un bloque
     `['OS=="win"', { 'msvs_settings': { 'VCCLCompilerTool': {
     'AdditionalOptions': ['/std:c++20'] } } }]` — pasa el flag directo sin
     depender de esa traducción.
   - `error: pasting formed '->pPrinterName', an invalid preprocessing
     token`: el código fuente (`src/node_printer_win.cc`, dos macros
     `ADD_V8_STRING_PROPERTY`, una para `job->` y otra para `printer->`) usa
     `job->##key` para pegar `->` con el nombre del campo — un uso inválido
     del operador de pegado de tokens `##` (solo debería usarse para pegar
     dos tokens en uno nuevo, no entre un operador y un identificador ya
     separados). El preprocesador clásico de `cl.exe` lo toleraba en modo
     no conformante; Clang lo rechaza correctamente. Fix: quitar el `##`
     sobrante, dejando simplemente `job->key` / `printer->key` en las tres
     líneas de cada macro.

   Sin este último fix, el módulo compila pero **falla en tiempo de
   ejecución** dentro del `.exe` de `pkg` con
   `Error: Module did not self-register: '...node_printer.node'` — un
   síntoma clásico de un `.node` compilado contra la ABI equivocada, pero en
   este caso la causa real era otra (el módulo ni siquiera llegaba a
   compilar correctamente contra Node puro sin los fixes de arriba; lo que
   sí quedaba compilado era el rebuild que hace `postinstall` vía
   `@electron/rebuild` para la ABI de **Electron**, incompatible con el
   Node 24 plano que usa `pkg` — ver siguiente sección).

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

**Importante — rebuild nativo antes de empaquetar:** el `postinstall` de
`npm install` (`electron-builder install-app-deps`) recompila
`@thiagoelg/node-printer` y `usb` contra la ABI de **Electron**, no la de
Node. `pkg` (usado acá para el build socket) empaqueta un Node **puro**
(target `node24-win-x64`, ver `package.json`), así que si se empaqueta el
`.node` que dejó el `postinstall` sin volver a compilarlo, el `.exe` final
arranca pero revienta al primer intento de impresión con
`Error: Module did not self-register: '...node_printer.node'` (ABI
incompatible). Por eso, después de `npm install` y **antes** de
`build:socket:win`, hay que recompilar ese módulo contra Node normal:

```powershell
$env:PYTHON = "C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe"
npm rebuild @thiagoelg/node-printer
```

(El módulo `usb` no necesita este paso — usa un binario N-API precompilado
del propio paquete en `node_modules/usb/prebuilds/`, no algo que
`node-gyp`/`electron-rebuild` recompile localmente.)

1. Compilar el binario del daemon con `pkg`:
   ```powershell
   npm run build:socket:win
   ```
   Esto genera `dist\win-socket\cda-print-view-core.exe`
   (ver `pkg.config.json` y el script `build:socket:pkg` en `package.json`).
   El target de `pkg` está fijado a `node24-win-x64` (no `node20`: la versión
   20 no tenía binario base precompilado disponible para Windows al momento
   de escribir esto, y forzaba a `pkg` a compilar Node desde cero, lo cual
   requiere el comando Unix `patch` — ausente en Windows salvo que se agregue
   `C:\Program Files\Git\usr\bin` al `PATH`). Alinear el target con Node 24
   además evita ese problema de raíz.

2. Descargar [WinSW](https://github.com/winsw/winsw/releases) (`WinSW-x64.exe`
   de la última release), renombrarlo a `cda-print-view.exe` y
   copiarlo a `dist\win-socket\` junto al `.exe` del paso anterior.

3. Instalar [NSIS](https://nsis.sourceforge.io/Download) (trae `makensis`) y
   compilar el instalador:
   ```powershell
   cd packaging\windows
   makensis installer-socket.nsi
   ```
   El resultado queda en **`dist\cda-print-view-setup.exe`** — un único
   instalador que ya trae todo adentro (el daemon, WinSW y su config). Ese es
   el archivo que se distribuye: un usuario normal solo lo descarga y lo
   ejecuta como administrador (el instalador pide elevación); no necesita
   Node, `pkg`, WinSW ni ningún paso manual — el propio instalador copia los
   tres archivos, registra el servicio de Windows con arranque **automático**
   (`<startmode>Automatic</startmode>` en `cda-print-view.xml`, así sigue
   corriendo después de reiniciar la máquina) y lo arranca de una vez — ver
   [installer-socket.nsi](../packaging/windows/installer-socket.nsi).

### 4.1. El instalador es autocontenido (no requiere internet ni nada preinstalado)

Verificado con `dumpbin /dependents` sobre los tres binarios — ninguno
depende de nada que no venga ya en Windows 10/11 de fábrica:

- `cda-print-view-core.exe` (Node 24 + `pkg`): solo DLLs base del SO
  (`KERNEL32`, `WS2_32`, `USER32`, etc.). El runtime de Node queda enlazado
  estáticamente — no requiere el Visual C++ Redistributable.
- `node_printer.node` / `usb` (`.node` nativos): solo `KERNEL32.dll` +
  `WINSPOOL.DRV` (impresora) o `USER32.dll` (usb) — nada fuera del SO.
- `cda-print-view.exe` (WinSW): es un *single-file host* de .NET
  autocontenido (trae el runtime embebido — se confirma por el símbolo
  `singlefilehost.pdb` en sus headers), no requiere tener .NET instalado.
- El instalador NSIS solo usa directivas `File` (copia local); no descarga
  nada durante la instalación.

En otras palabras: el `.exe` final se puede llevar a una máquina Windows
limpia, sin internet y sin ningún runtime preinstalado, y debería funcionar.

## 5. Verificar el servicio instalado

El servicio queda registrado con el id **`cda-print-view`** (elegido corto y
a propósito, para que sea fácil de encontrar/buscar en `services.msc` o por
línea de comandos):

```powershell
Get-Service "cda-print-view"
Get-Content "$env:ProgramData\cda-print-view\logs\cda-print-view.wrapper.log" -Tail 30
```

El servicio debe quedar escuchando en `ws://127.0.0.1:1315` (o el puerto que
se haya configurado en `.env` / la variable `PRINTER_TRANSPORT` en
`cda-print-view.xml`).

## Notas

- Todo lo de esta guía es **la contraparte Windows** de
  `packaging/linux/build-socket-deb.sh` y del build `full` para Linux — la
  arquitectura y los scripts de `package.json` son los mismos, solo cambia el
  toolchain nativo y el empaquetador final (NSIS/WinSW en vez de
  dpkg-deb/systemd).
- El build "socket" (pasos 2 a 4 de esta guía) sí se probó de punta a punta
  en una máquina Windows real: `npm install`, la compilación de `pkg` y el
  instalador NSIS completo, más una prueba funcional del `.exe` resultante
  mandándole un trabajo de impresión real por WebSocket (transporte
  `spooler`, encontró la impresora por defecto del sistema y no tiró
  errores) — ver la sección 4.1 sobre las dependencias nativas verificadas.
  El build "full" (Electron) sigue sin probarse en Windows real.
