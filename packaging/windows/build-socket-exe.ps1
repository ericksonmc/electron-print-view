# Genera el instalador Windows del plugin de impresión (sin WebView):
# dist\cda-print-view-setup-<version>.exe. Guía: docs/plugin-impresion-agencias.md
# Uso (PowerShell, desde la raíz del repo): .\packaging\windows\build-socket-exe.ps1
param([string]$WinSwVersion = "v2.12.0")
$ErrorActionPreference = "Stop"

$root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $root

foreach ($tool in "node", "npm", "makensis") {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Falta '$tool' en el PATH (ver docs/plugin-impresion-agencias.md, sección Windows)."
  }
}
if (-not (node -v).StartsWith("v24")) { throw "Se requiere Node 24 (node -v = $(node -v))." }

$version = node -p "require('./package.json').version"
$outDir = "dist\win-socket"
New-Item -ItemType Directory -Force $outDir | Out-Null

# El postinstall deja node-printer compilado para Electron; pkg necesita la ABI de Node.
npm ci
npm rebuild "@thiagoelg/node-printer"
if (-not (Test-Path "node_modules\@thiagoelg\node-printer\build\Release\node_printer.node")) {
  throw "node-printer no compiló: revisa Python/Build Tools (docs/windows-build.md, sección 2.1)."
}

npm run build:socket:win
if (-not (Test-Path "$outDir\cda-print-view-core.exe")) { throw "pkg no generó cda-print-view-core.exe" }

$winsw = "$outDir\cda-print-view.exe"
if (-not (Test-Path $winsw)) {
  Invoke-WebRequest "https://github.com/winsw/winsw/releases/download/$WinSwVersion/WinSW-x64.exe" -OutFile $winsw
  if ((Get-Item $winsw).Length -lt 3MB) {
    throw "WinSW pesa muy poco: no parece la variante autocontenida (requeriría .NET en la agencia)."
  }
}

Push-Location packaging\windows
makensis installer-socket.nsi
if ($LASTEXITCODE -ne 0) { throw "makensis falló" }
Pop-Location

$final = "dist\cda-print-view-setup-$version.exe"
Move-Item -Force "dist\cda-print-view-setup.exe" $final
Write-Host "Listo: $final"
