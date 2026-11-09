#!/usr/bin/env bash
#
# "Ventana" de actualización para los kioscos sin escritorio. La abre el
# lanzador (cdapuestas-usb-update.sh) con `openvt -s -w` en una consola virtual
# nueva: el operador ve a pantalla completa un banner + el progreso en vivo, y al
# terminar el lanzador vuelve al VT del WebView. No depende de la GUI (solo kbd).
#
# Su stdout/stderr van al VT (openvt los conecta), así que lo que imprime se ve
# en pantalla. El trabajo real (autostart.sh) manda su salida al LOG; aquí la
# mostramos con `tail -f` para que se vea el avance sin perder el log.
set -uo pipefail

VERDIR="${1:?uso: $0 <carpeta-de-version>}"
VER="$(basename "$VERDIR")"
LOG="/var/log/cdapuestas-usb-update.log"

printf '\033[2J\033[H'
cat <<BANNER

  ========================================================
     CD APUESTAS  -  ACTUALIZACION EN CURSO
     Version: $VER
     NO apague el equipo. Puede tardar un par de minutos.
  ========================================================

BANNER

bash "$VERDIR/autostart.sh" >>"$LOG" 2>&1 &
pid=$!
# Mostrar el log en vivo en el VT hasta que el instalador termine.
tail -n 0 -f --pid="$pid" "$LOG" 2>/dev/null &
tailpid=$!
wait "$pid"; rc=$?
kill "$tailpid" 2>/dev/null || true

echo
if [ "$rc" -eq 0 ]; then
  echo "  ====================================================="
  echo "     ACTUALIZACION COMPLETA. Ya puede retirar el USB."
  echo "  ====================================================="
else
  echo "  ====================================================="
  echo "     ERROR EN LA ACTUALIZACION (codigo $rc)."
  echo "     Revise $LOG"
  echo "  ====================================================="
fi
# Dar tiempo a que el operador lo lea antes de volver al WebView.
sleep 6
exit "$rc"
