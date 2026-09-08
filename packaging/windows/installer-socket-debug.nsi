; Variante "debug" de installer-socket.nsi: instala el mismo servicio pero
; con cda-print-view-debug.xml (agrega DEBUG_LOG=true), para reinstalar
; temporalmente en una máquina con problemas de impresión y obtener un log
; detallado en C:\Users\Public\Desktop\cda-print-view-debug.log en vez de
; tener que ir a buscar el log de WinSW en ProgramData.
;
; Usa el mismo <id> de servicio y la misma carpeta de instalación que el
; build normal, así que instalar esto reemplaza en el lugar cualquier
; instalación previa (normal o debug) — no corren los dos a la vez. No hace
; falta recompilar nada: DEBUG_LOG es una variable de entorno que lee el
; mismo cda-print-view-core.exe, no un build de pkg aparte.
;
; Requiere en dist/win-socket/ lo mismo que installer-socket.nsi:
;   cda-print-view-core.exe   (salida de pkg para win-x64)
;   cda-print-view.exe        (WinSW-x64.exe descargado y renombrado)
;   cda-print-view-debug.xml  (packaging/windows/cda-print-view-debug.xml)

!define APP_NAME "CDA Print View (Debug)"
!define INSTALL_DIR "$PROGRAMFILES64\CDAPrintView"
!define DEBUG_LOG_PATH "$%PROGRAMDATA%\cda-print-view\logs\cda-print-view-debug.log"

Name "${APP_NAME}"
OutFile "..\..\dist\cda-print-view-debug-setup.exe"
InstallDir "${INSTALL_DIR}"
RequestExecutionLevel admin

Section "Install"
  ; Si ya hay un servicio instalado (build normal o debug previo), lo
  ; detenemos y desregistramos antes de sobreescribir los binarios: Windows
  ; no deja reemplazar el .exe mientras el servicio lo tiene abierto.
  IfFileExists "$INSTDIR\cda-print-view.exe" 0 skip_stop
    ExecWait '"$INSTDIR\cda-print-view.exe" stop'
    ExecWait '"$INSTDIR\cda-print-view.exe" uninstall'
  skip_stop:

  SetOutPath "$INSTDIR"
  File "..\..\dist\win-socket\cda-print-view-core.exe"
  File "..\..\dist\win-socket\cda-print-view.exe"
  File /oname=cda-print-view.xml "cda-print-view-debug.xml"

  ExecWait '"$INSTDIR\cda-print-view.exe" install'
  ExecWait '"$INSTDIR\cda-print-view.exe" start'

  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; Acceso directo en el escritorio de TODOS los usuarios apuntando al log
  ; de debug real (en %ProgramData%, no el escritorio: ver la nota en
  ; src/core/config.js sobre por qué "Acceso a carpetas controlado" de
  ; Windows Defender bloquea silenciosamente escrituras directas ahí). El
  ; archivo puede no existir todavía hasta el primer trabajo de impresión;
  ; el acceso directo igual queda apuntando a la ruta correcta.
  SetShellVarContext all
  CreateShortCut "$DESKTOP\Log de impresion (debug).lnk" "${DEBUG_LOG_PATH}"
SectionEnd

Section "Uninstall"
  ExecWait '"$INSTDIR\cda-print-view.exe" stop'
  ExecWait '"$INSTDIR\cda-print-view.exe" uninstall'
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"

  SetShellVarContext all
  Delete "$DESKTOP\Log de impresion (debug).lnk"
SectionEnd
