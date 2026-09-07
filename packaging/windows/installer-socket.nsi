; Instalador NSIS del build "socket": copia el ejecutable del servicio
; (generado por pkg) junto con WinSW ya renombrado, y registra/arranca el
; servicio de Windows en la instalación. Pensado para que un usuario normal
; solo baje este .exe y lo ejecute — sin pasos manuales de por medio (WinSW,
; el XML de configuración y el registro/arranque del servicio ya quedan
; resueltos por el instalador). El servicio queda con arranque automático
; (<startmode>Automatic</startmode> en cda-print-view.xml), así que sigue
; corriendo después de reiniciar sin que el usuario tenga que hacer nada más.
;
; Se compila desde Ubuntu con `makensis` (mismo paquete que usa
; electron-builder) o con `wine` si no está disponible nativo.
;
; Requiere en dist/win-socket/ antes de compilar:
;   cda-print-view-core.exe   (salida de pkg para win-x64)
;   cda-print-view.exe        (WinSW-x64.exe descargado y renombrado)
;   cda-print-view.xml        (packaging/windows/cda-print-view.xml)

!define APP_NAME "CDA Print View"
!define INSTALL_DIR "$PROGRAMFILES64\CDAPrintView"

Name "${APP_NAME}"
OutFile "..\..\dist\cda-print-view-setup.exe"
InstallDir "${INSTALL_DIR}"
RequestExecutionLevel admin

Section "Install"
  SetOutPath "$INSTDIR"
  File "..\..\dist\win-socket\cda-print-view-core.exe"
  File "..\..\dist\win-socket\cda-print-view.exe"
  File /oname=cda-print-view.xml "cda-print-view.xml"

  ; Instala, registra el arranque automático (viene definido en el XML) y
  ; arranca el servicio de una vez — el usuario no tiene que abrir services.msc
  ; ni la consola para nada.
  ExecWait '"$INSTDIR\cda-print-view.exe" install'
  ExecWait '"$INSTDIR\cda-print-view.exe" start'

  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  ExecWait '"$INSTDIR\cda-print-view.exe" stop'
  ExecWait '"$INSTDIR\cda-print-view.exe" uninstall'
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"
SectionEnd
