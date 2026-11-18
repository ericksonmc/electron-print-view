# Prueba el plugin de impresión instalado en Windows: servicio, puerto 1315 y
# un ticket de prueba real por WebSocket (sale por la impresora).
# Uso: .\tools\probar-plugin.ps1   (opcional: -Url ws://127.0.0.1:1315 -SinImprimir)
param(
  [string]$Url = "ws://127.0.0.1:1315",
  [switch]$SinImprimir
)

function Paso($ok, $msg) {
  if ($ok) { Write-Host "[OK]    $msg" -ForegroundColor Green }
  else { Write-Host "[FALLO] $msg" -ForegroundColor Red; $script:fallos++ }
}
$script:fallos = 0

$svc = Get-Service cda-print-view -ErrorAction SilentlyContinue
Paso ($svc -and $svc.Status -eq "Running") "Servicio cda-print-view ($(if ($svc) { $svc.Status } else { 'no instalado' }))"

$uri = [Uri]$Url
$puerto = $uri.Port
$escucha = Get-NetTCPConnection -LocalPort $puerto -State Listen -ErrorAction SilentlyContinue
Paso ([bool]$escucha) "Puerto $puerto escuchando"

$impresora = (Get-CimInstance Win32_Printer | Where-Object Default).Name
Paso ([bool]$impresora) "Impresora predeterminada: $(if ($impresora) { $impresora } else { 'ninguna' })"

if (-not $SinImprimir) {
  $texto = "[center][bold]PRUEBA PLUGIN[/bold][/center][line]" +
           "[center]$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')[/center][line]" +
           "[center][qr width=160]https://cdapuestas.com[/qr][/center][line][line][cut]"
  $json = @{ text = $texto } | ConvertTo-Json -Compress
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $cts = New-Object System.Threading.CancellationTokenSource 15000
  try {
    $ws.ConnectAsync($uri, $cts.Token).GetAwaiter().GetResult()
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $ws.SendAsync([ArraySegment[byte]]$bytes, "Text", $true, $cts.Token).GetAwaiter().GetResult()
    $buf = New-Object byte[] 4096
    $r = $ws.ReceiveAsync([ArraySegment[byte]]$buf, $cts.Token).GetAwaiter().GetResult()
    $resp = [Text.Encoding]::UTF8.GetString($buf, 0, $r.Count)
    $ok = ($resp | ConvertFrom-Json).status -eq "success"
    Paso $ok "Respuesta del servicio: $resp"
    if ($ok) { Write-Host "        Revisa que la impresora haya sacado el ticket." }
  } catch {
    Paso $false "WebSocket: $($_.Exception.Message)"
  } finally { $ws.Dispose() }
}

$log = "$env:ProgramData\cda-print-view\logs\cda-print-view.wrapper.log"
if (Test-Path $log) { Write-Host "`nÚltimas líneas del log ($log):"; Get-Content $log -Tail 8 }

if ($script:fallos) { Write-Host "`n$($script:fallos) comprobación(es) fallaron." -ForegroundColor Red; exit 1 }
Write-Host "`nTodo OK." -ForegroundColor Green
