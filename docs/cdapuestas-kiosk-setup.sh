#!/usr/bin/env bash
# Configurador automático de CD Apuestas WebView en modo GNOME Kiosk.
# Uso recomendado:
#   chmod +x cdapuestas-kiosk-setup.sh
#   ./cdapuestas-kiosk-setup.sh
#
# Opciones:
#   --user=USUARIO   Fuerza el usuario del kiosk.
#   --reboot         Reinicia automáticamente al finalizar.
#   --no-reboot      No pregunta ni reinicia al finalizar.

set -Eeuo pipefail

APP_NAME="CD Apuestas WebView"
DEB_FILENAME="cdapuestas-webview-setup-1.0.0.deb"
APP_LAUNCHER="/usr/bin/cdapuestas-webview"
APP_REAL="/opt/cdapuestas_webview/cdapuestas-webview"
SANDBOX_FILE="/opt/cdapuestas_webview/chrome-sandbox"
SCALE_FACTOR="2.00"
KIOSK_URL="https://cdapuestas.com"
TARGET_USER_ARG=""
REBOOT_MODE="ask"

for arg in "$@"; do
  case "$arg" in
    --user=*)
      TARGET_USER_ARG="${arg#*=}"
      ;;
    --reboot)
      REBOOT_MODE="yes"
      ;;
    --no-reboot)
      REBOOT_MODE="no"
      ;;
    -h|--help)
      sed -n '1,14p' "$0"
      exit 0
      ;;
    *)
      echo "Argumento desconocido: $arg" >&2
      exit 2
      ;;
  esac
done

# Elevar privilegios conservando SUDO_USER para detectar al usuario real.
if [[ ${EUID} -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

LOG_FILE="/var/log/cdapuestas-kiosk-setup.log"
touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

retry() {
  local attempts="$1"
  local delay="$2"
  shift 2
  local n=1

  until "$@"; do
    if (( n >= attempts )); then
      return 1
    fi
    log "El comando falló. Reintentando en ${delay}s (${n}/${attempts})..."
    sleep "$delay"
    ((n++))
  done
}

detect_target_user() {
  local candidate=""

  if [[ -n "$TARGET_USER_ARG" ]]; then
    candidate="$TARGET_USER_ARG"
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    candidate="$SUDO_USER"
  else
    candidate="$(loginctl list-sessions --no-legend 2>/dev/null | awk '$4=="seat0" && $3!="gdm" {print $3; exit}')"
  fi

  if [[ -z "$candidate" || "$candidate" == "root" ]]; then
    candidate="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $1 != "nobody" && $6 ~ /^\/home\// && $7 !~ /(nologin|false)$/ {print $1; exit}')"
  fi

  [[ -n "$candidate" ]] || return 1
  id "$candidate" >/dev/null 2>&1 || return 1
  printf '%s\n' "$candidate"
}

set_ini_key() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  local tmp

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || printf '[%s]\n' "$section" > "$file"
  tmp="$(mktemp)"

  awk -v wanted_section="$section" -v wanted_key="$key" -v wanted_value="$value" '
    BEGIN {
      in_section = 0
      section_found = 0
      key_written = 0
    }

    {
      if ($0 ~ "^[[:space:]]*\\[" wanted_section "\\][[:space:]]*$") {
        if (in_section && !key_written) {
          print wanted_key "=" wanted_value
          key_written = 1
        }
        in_section = 1
        section_found = 1
        print
        next
      }

      if ($0 ~ "^[[:space:]]*\\[.*\\][[:space:]]*$") {
        if (in_section && !key_written) {
          print wanted_key "=" wanted_value
          key_written = 1
        }
        in_section = 0
      }

      if (in_section && $0 ~ "^[#;]?[[:space:]]*" wanted_key "[[:space:]]*=") {
        if (!key_written) {
          print wanted_key "=" wanted_value
          key_written = 1
        }
        next
      }

      print
    }

    END {
      if (in_section && !key_written) {
        print wanted_key "=" wanted_value
      } else if (!section_found) {
        print ""
        print "[" wanted_section "]"
        print wanted_key "=" wanted_value
      }
    }
  ' "$file" > "$tmp"

  cat "$tmp" > "$file"
  rm -f "$tmp"
}

TARGET_USER="$(detect_target_user)" || fail "No fue posible detectar el usuario de Ubuntu. Usa --user=USUARIO."
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_GID="$(id -g "$TARGET_USER")"

[[ -d "$TARGET_HOME" ]] || fail "El directorio personal de $TARGET_USER no existe: $TARGET_HOME"

log "Usuario detectado: $TARGET_USER (UID $TARGET_UID)"
log "Directorio personal: $TARGET_HOME"

DESKTOP_DIR="$(runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" xdg-user-dir DESKTOP 2>/dev/null || true)"
DEB_PATH=""

for candidate_dir in "$DESKTOP_DIR" "$TARGET_HOME/Desktop" "$TARGET_HOME/Escritorio"; do
  [[ -n "$candidate_dir" ]] || continue
  if [[ -f "$candidate_dir/$DEB_FILENAME" ]]; then
    DEB_PATH="$candidate_dir/$DEB_FILENAME"
    break
  fi
done

[[ -n "$DEB_PATH" ]] || fail "No encontré $DEB_FILENAME en el Desktop/Escritorio de $TARGET_USER."
log "Instalador encontrado: $DEB_PATH"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="/var/backups/cdapuestas-kiosk-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

for path in \
  /etc/gdm3/custom.conf \
  "/var/lib/AccountsService/users/$TARGET_USER" \
  "$TARGET_HOME/.local/bin/gnome-kiosk-script" \
  "$TARGET_HOME/bin/start-cdapuestas-webview.sh" \
  /etc/dconf/profile/user \
  /etc/dconf/db/local.d/00-cdapuestas-kiosk \
  /etc/systemd/system/cdapuestas-sandbox-fix.service \
  /usr/local/sbin/cdapuestas-fix-sandbox; do
  if [[ -e "$path" ]]; then
    cp -a --parents "$path" "$BACKUP_DIR" 2>/dev/null || true
  fi
done
log "Respaldo creado en: $BACKUP_DIR"

export DEBIAN_FRONTEND=noninteractive
log "Actualizando repositorios..."
retry 5 5 apt-get update || fail "No fue posible actualizar los repositorios de Ubuntu."

log "Instalando dependencias requeridas..."
apt-get install -y curl gnome-kiosk util-linux network-manager || fail "No fue posible instalar las dependencias."

log "Instalando $DEB_FILENAME..."
if ! apt-get install -y "$DEB_PATH"; then
  log "La instalación directa falló; intentando reparar dependencias..."
  dpkg -i "$DEB_PATH" || true
  apt-get -f install -y
fi

[[ -x "$APP_LAUNCHER" || -x "$APP_REAL" ]] || fail "La aplicación no quedó instalada correctamente."

# Determinar la sesión kiosk disponible instalada por gnome-kiosk.
SESSION_DESKTOP="/usr/share/wayland-sessions/gnome-kiosk-script-wayland.desktop"
if [[ ! -f "$SESSION_DESKTOP" ]]; then
  SESSION_DESKTOP="$(find /usr/share/wayland-sessions -maxdepth 1 -type f -iname '*kiosk*script*.desktop' | head -n 1 || true)"
fi
[[ -n "$SESSION_DESKTOP" && -f "$SESSION_DESKTOP" ]] || fail "No se encontró una sesión GNOME Kiosk Script para Wayland."
SESSION_NAME="$(basename "$SESSION_DESKTOP" .desktop)"
log "Sesión kiosk detectada: $SESSION_NAME"

log "Corrigiendo permisos de chrome-sandbox..."
if [[ -e "$SANDBOX_FILE" ]]; then
  chown root:root "$SANDBOX_FILE"
  chmod 4755 "$SANDBOX_FILE"
else
  fail "No existe $SANDBOX_FILE después de instalar el paquete."
fi

# Asegurar que los permisos se reparen también después de actualizaciones/reinicios.
cat > /usr/local/sbin/cdapuestas-fix-sandbox <<'SANDBOX_EOF'
#!/usr/bin/env bash
set -e
SANDBOX="/opt/cdapuestas_webview/chrome-sandbox"
if [[ -e "$SANDBOX" ]]; then
  chown root:root "$SANDBOX"
  chmod 4755 "$SANDBOX"
fi
SANDBOX_EOF
chmod 0755 /usr/local/sbin/cdapuestas-fix-sandbox

cat > /etc/systemd/system/cdapuestas-sandbox-fix.service <<'SERVICE_EOF'
[Unit]
Description=Corrige permisos del sandbox de CD Apuestas WebView
Before=display-manager.service
ConditionPathExists=/opt/cdapuestas_webview/chrome-sandbox

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cdapuestas-fix-sandbox
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now cdapuestas-sandbox-fix.service

log "Creando supervisor del WebView..."
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GID" "$TARGET_HOME/bin"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GID" "$TARGET_HOME/.cache"

cat > "$TARGET_HOME/bin/start-cdapuestas-webview.sh" <<SUPERVISOR_EOF
#!/usr/bin/env bash
set -u

LOG="\$HOME/cdapuestas-webview.log"
APP="$APP_REAL"
LOCK="\$HOME/.cache/cdapuestas-webview-supervisor.lock"
SCALE="$SCALE_FACTOR"
URL="$KIOSK_URL"
APP_PID=""

mkdir -p "\$HOME/.cache"
exec 9>"\$LOCK"

if ! flock -n 9; then
  echo "\$(date) - Ya existe un supervisor activo" >> "\$LOG"
  exit 0
fi

cleanup() {
  if [[ -n "\${APP_PID:-}" ]]; then
    kill -TERM -- "-\$APP_PID" 2>/dev/null || true
    sleep 1
    kill -KILL -- "-\$APP_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Limpiar instancias anteriores que pudieran haber quedado huérfanas.
pkill -TERM -u "\$UID" -f '^/opt/cdapuestas_webview/cdapuestas-webview( |\$)' 2>/dev/null || true
sleep 2
pkill -KILL -u "\$UID" -f '^/opt/cdapuestas_webview/cdapuestas-webview( |\$)' 2>/dev/null || true

echo "========================================" >> "\$LOG"
echo "\$(date) - Supervisor iniciado PID=\$\$" >> "\$LOG"

while true; do
  echo "\$(date) - Esperando conectividad" >> "\$LOG"
  intento=0

  until ip -4 addr show scope global | grep -q 'inet ' \
    && ip route show default | grep -q '^default ' \
    && getent hosts cdapuestas.com >/dev/null 2>&1 \
    && curl -kLsS --connect-timeout 3 --max-time 8 -o /dev/null "\$URL"; do
      intento=\$((intento + 1))
      if (( intento == 1 || intento % 10 == 0 )); then
        echo "\$(date) - La red todavía no está disponible. Intento=\$intento" >> "\$LOG"
      fi
      sleep 3
  done

  echo "\$(date) - Red disponible; abriendo WebView con escala \$SCALE" >> "\$LOG"

  exit_code=0
  setsid "\$APP" \
    --force-device-scale-factor="\$SCALE" \
    >> "\$LOG" 2>&1 &
  APP_PID=\$!

  echo "\$(date) - WebView iniciado PID=\$APP_PID" >> "\$LOG"
  wait "\$APP_PID" || exit_code=\$?

  # Eliminar cualquier subproceso Electron que haya quedado huérfano.
  kill -TERM -- "-\$APP_PID" 2>/dev/null || true
  sleep 1
  kill -KILL -- "-\$APP_PID" 2>/dev/null || true
  APP_PID=""

  echo "\$(date) - WebView terminó. Código=\$exit_code" >> "\$LOG"
  echo "\$(date) - Reiniciando en 3 segundos" >> "\$LOG"
  sleep 3
done
SUPERVISOR_EOF

chown "$TARGET_USER:$TARGET_GID" "$TARGET_HOME/bin/start-cdapuestas-webview.sh"
chmod 0755 "$TARGET_HOME/bin/start-cdapuestas-webview.sh"

log "Creando script principal de la sesión GNOME Kiosk..."
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GID" "$TARGET_HOME/.local/bin"

cat > "$TARGET_HOME/.local/bin/gnome-kiosk-script" <<'KIOSK_EOF'
#!/usr/bin/env bash

LOG="$HOME/gnome-kiosk-session.log"
SUPERVISOR="$HOME/bin/start-cdapuestas-webview.sh"

while true; do
  echo "$(date) - Iniciando supervisor del kiosk" >> "$LOG"
  "$SUPERVISOR" >> "$LOG" 2>&1
  code=$?
  echo "$(date) - El supervisor terminó con código $code; reiniciando en 3 segundos" >> "$LOG"
  sleep 3
done
KIOSK_EOF

chown "$TARGET_USER:$TARGET_GID" "$TARGET_HOME/.local/bin/gnome-kiosk-script"
chmod 0755 "$TARGET_HOME/.local/bin/gnome-kiosk-script"

# Desactivar el autoarranque antiguo para impedir instancias duplicadas.
if [[ -f "$TARGET_HOME/.config/autostart/cdapuestas-webview.desktop" ]]; then
  mv "$TARGET_HOME/.config/autostart/cdapuestas-webview.desktop" \
     "$TARGET_HOME/.config/autostart/cdapuestas-webview.desktop.disabled-$TIMESTAMP"
fi

log "Configurando inicio automático de sesión para $TARGET_USER..."
GDM_CONF="/etc/gdm3/custom.conf"
[[ -f "$GDM_CONF" ]] || printf '[daemon]\n' > "$GDM_CONF"
set_ini_key "$GDM_CONF" "daemon" "AutomaticLoginEnable" "true"
set_ini_key "$GDM_CONF" "daemon" "AutomaticLogin" "$TARGET_USER"

ACCOUNT_FILE="/var/lib/AccountsService/users/$TARGET_USER"
[[ -f "$ACCOUNT_FILE" ]] || printf '[User]\n' > "$ACCOUNT_FILE"
set_ini_key "$ACCOUNT_FILE" "User" "Session" "$SESSION_NAME"
set_ini_key "$ACCOUNT_FILE" "User" "XSession" "$SESSION_NAME"
set_ini_key "$ACCOUNT_FILE" "User" "SystemAccount" "false"
chmod 0600 "$ACCOUNT_FILE"

log "Desactivando bloqueo, suspensión e inactividad de pantalla..."
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
if [[ ! -f /etc/dconf/profile/user ]]; then
  cat > /etc/dconf/profile/user <<'DCONF_PROFILE_EOF'
user-db:user
system-db:local
DCONF_PROFILE_EOF
elif ! grep -qx 'system-db:local' /etc/dconf/profile/user; then
  printf '\nsystem-db:local\n' >> /etc/dconf/profile/user
fi

cat > /etc/dconf/db/local.d/00-cdapuestas-kiosk <<'DCONF_EOF'
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/screensaver]
lock-enabled=false

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
DCONF_EOF

dconf update || true

log "Configurando reconexión automática de NetworkManager..."
if command -v nmcli >/dev/null 2>&1; then
  while IFS=: read -r conn_uuid conn_type; do
    [[ -n "$conn_uuid" ]] || continue
    case "$conn_type" in
      802-3-ethernet|802-11-wireless)
        nmcli connection modify uuid "$conn_uuid" connection.autoconnect yes || true
        nmcli connection modify uuid "$conn_uuid" connection.autoconnect-retries 0 || true
        nmcli connection modify uuid "$conn_uuid" connection.permissions "" || true
        nmcli connection modify uuid "$conn_uuid" connection.wait-device-timeout 30000 || true
        ;;
    esac
  done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null || true)
fi

systemctl enable NetworkManager.service >/dev/null 2>&1 || true
systemctl enable NetworkManager-wait-online.service >/dev/null 2>&1 || true

log "Verificando configuración..."
[[ "$(stat -c '%U:%G' "$SANDBOX_FILE")" == "root:root" ]] || fail "Propietario incorrecto en chrome-sandbox."
[[ "$(stat -c '%a' "$SANDBOX_FILE")" == "4755" ]] || fail "Permisos incorrectos en chrome-sandbox."
[[ -x "$TARGET_HOME/.local/bin/gnome-kiosk-script" ]] || fail "No se creó el script de GNOME Kiosk."
[[ -x "$TARGET_HOME/bin/start-cdapuestas-webview.sh" ]] || fail "No se creó el supervisor."

log "Configuración terminada correctamente."
echo
echo "Resumen:"
echo "  Usuario kiosk:       $TARGET_USER"
echo "  Instalador:          $DEB_PATH"
echo "  Sesión:              $SESSION_NAME"
echo "  Escala de Electron:  $SCALE_FACTOR"
echo "  Respaldo:            $BACKUP_DIR"
echo "  Log de instalación:  $LOG_FILE"
echo

case "$REBOOT_MODE" in
  yes)
    log "Reiniciando el equipo..."
    sleep 3
    systemctl reboot -i
    ;;
  no)
    log "No se reiniciará automáticamente. Ejecuta: sudo systemctl reboot -i"
    ;;
  ask)
    if [[ -t 0 ]]; then
      read -r -p "¿Reiniciar ahora para activar el modo kiosk? [S/n]: " answer
      if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        log "Reiniciando el equipo..."
        sleep 3
        systemctl reboot -i
      else
        log "Reinicio pendiente. Ejecuta: sudo systemctl reboot -i"
      fi
    else
      log "Instalación completada. Reinicia con: sudo systemctl reboot -i"
    fi
    ;;
esac
