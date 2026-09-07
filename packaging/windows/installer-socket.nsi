; Instalador NSIS del build "socket": copia el ejecutable del servicio
; (generado por pkg) junto con WinSW ya renombrado, y registra/arranca el
; servicio de Windows en la instalación. Se compila desde Ubuntu con
; `makensis` (mismo paquete que usa electron-builder) o con `wine` si no
; está disponible nativo.
;
; Requiere en dist/win-socket/ antes de compilar:
;   cdapuestas-print-service-core.exe   (salida de pkg para win-x64)
;   cdapuestas-print-service.exe        (WinSW-x64.exe descargado y renombrado)
;   cdapuestas-print.xml                (packaging/windows/cdapuestas-print.xml)

!define APP_NAME "CDApuestas Print Service"
!define INSTALL_DIR "$PROGRAMFILES64\CDApuestasPrintService"

Name "${APP_NAME}"
OutFile "..\..\dist\cdapuestas-print-service-setup.exe"
InstallDir "${INSTALL_DIR}"
RequestExecutionLevel admin

Section "Install"
  SetOutPath "$INSTDIR"
  File "..\..\dist\win-socket\cdapuestas-print-service-core.exe"
  File "..\..\dist\win-socket\cdapuestas-print-service.exe"
  File /oname=cdapuestas-print-service.xml "cdapuestas-print.xml"

  ExecWait '"$INSTDIR\cdapuestas-print-service.exe" install'
  ExecWait '"$INSTDIR\cdapuestas-print-service.exe" start'

  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  ExecWait '"$INSTDIR\cdapuestas-print-service.exe" stop'
  ExecWait '"$INSTDIR\cdapuestas-print-service.exe" uninstall'
  Delete "$INSTDIR\*.*"
  RMDir "$INSTDIR"
SectionEnd
