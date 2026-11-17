# Makefile del printView (CD Apuestas WebView).
# Automatiza el build del .deb y el empaquetado de cada actualización en el
# catálogo versionado releases/ (ver releases/README.md y docs/kiosk-linux.md).
#
# Uso típico: bumpea la versión en package.json y corre `make deploy`.
# Genera dos .deb: el WebView completo (kioscos) y el plugin de impresión solo
# (PCs de agencia con navegador, sin WebView).

SHELL := /bin/bash
VERSION := $(shell node -p "require('./package.json').version" 2>/dev/null)
OUTPUT_DIR := dist/full
RELEASE_DIR := releases/$(VERSION)
AUTOSTART_TEMPLATE := releases/autostart.template.sh
PLUGIN_DEB_NAME := cdapuestas-print-service-$(VERSION)-amd64.deb
DEB ?= $(RELEASE_DIR)/cdapuestas-webview-setup-$(VERSION).deb
TS_SSH ?= tailscale ssh
TS_CONNECT_TIMEOUT ?= 30
TS_INSTALL_TIMEOUT ?= 120
TS_TRANSFER_TIMEOUT ?= 900

.DEFAULT_GOAL := help
.PHONY: help version install build build-plugin deploy release usb tailscale-check tailscale-update clean

help: ## Muestra esta ayuda
	@echo "printView — targets disponibles:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort | awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Versión actual (package.json): $(VERSION)"

version: ## Imprime la versión actual
	@echo "$(VERSION)"

install: ## Instala dependencias (npm + módulos nativos)
	npm install

build: ## Genera el .deb del build full (Linux) en dist/full/
	@test -f node_modules/@thiagoelg/node-printer/build/Release/node_printer.node || { echo "Falta node-printer compilado: CC=gcc-10 CXX=g++-10 npm install && npx electron-builder install-app-deps"; exit 1; }
	npm run build:full:linux

build-plugin: ## Genera el .deb del plugin de impresión (sin WebView) en dist/
	npm run build:socket:linux

# deploy = build + build-plugin + empaquetar la versión actual en
# releases/<version>/ con sus dos .deb y su autostart.sh. Es lo que corres para
# publicar un update.
deploy: build build-plugin release ## Genera los dos .deb y arma releases/<version>/ (todo)

release: ## Arma releases/<version>/ con el .deb del WebView (dist/full/) y el del plugin (dist/)
	@test -n "$(VERSION)" || { echo "No pude leer la versión de package.json"; exit 1; }
	@deb=$$(ls -t $(OUTPUT_DIR)/*.deb 2>/dev/null | head -n 1); \
	 if [ -z "$$deb" ]; then \
	   echo "No encontré ningún .deb en $(OUTPUT_DIR)/. Corre 'make build' primero."; exit 1; \
	 fi; \
	 test -f "dist/$(PLUGIN_DEB_NAME)" || { echo "No encontré dist/$(PLUGIN_DEB_NAME). Corre 'make build-plugin' primero."; exit 1; }; \
	 mkdir -p "$(RELEASE_DIR)"; \
	 cp "dist/$(PLUGIN_DEB_NAME)" "$(RELEASE_DIR)/"; \
	 cp "$(AUTOSTART_TEMPLATE)" "$(RELEASE_DIR)/autostart.sh"; \
	 chmod +x "$(RELEASE_DIR)/autostart.sh"; \
	 cp "$$deb" "$(RELEASE_DIR)/"; \
	 echo "Release $(VERSION) listo:"; \
	 ls -1 "$(RELEASE_DIR)"; \
	 echo "Copia la carpeta $(RELEASE_DIR)/ (o todo releases/) al pendrive con label CDAUPDATE."

# Copia el release actual al pendrive con label CDAUPDATE. Autodetecta el punto
# de montaje por el label; si no, pásalo explícito: make usb DEST=/media/.../X
usb: ## Copia releases/<version>/ al pendrive CDAUPDATE (autodetecta; o DEST=/ruta)
	@test -d "$(RELEASE_DIR)" || { echo "No existe $(RELEASE_DIR)/. Corre 'make deploy' primero."; exit 1; }
	@set -e; \
	 dest="$(DEST)"; \
	 if [ -z "$$dest" ]; then dest=$$(findmnt -frno TARGET LABEL=CDAUPDATE 2>/dev/null | head -n 1); fi; \
	 if [ -z "$$dest" ]; then dest=$$(lsblk -rno MOUNTPOINT,LABEL 2>/dev/null | awk '$$2=="CDAUPDATE"{print $$1; exit}'); fi; \
	 if [ -z "$$dest" ]; then \
	   echo "No encontré un pendrive montado con label CDAUPDATE."; \
	   echo "Conéctalo (debe automontarse) o pásalo explícito: make usb DEST=/media/.../CDAUPDATE"; exit 1; \
	 fi; \
	 echo "Pendrive CDAUPDATE en: $$dest"; \
	 mkdir -p "$$dest/releases"; \
	 rm -rf "$$dest/releases/$(VERSION)"; \
	 cp -r "$(RELEASE_DIR)" "$$dest/releases/$(VERSION)"; \
	 rm -rf "$$dest/usb-update"; \
	 cp -r tools/usb-update "$$dest/usb-update"; \
	 cp tools/usb-update/INSTRUCCIONES-PENDRIVE.txt "$$dest/INSTRUCCIONES.txt"; \
	 sync; \
	 echo "Copiado $(RELEASE_DIR) y el kit usb-update/ a $$dest. Ya puedes expulsar el USB."; \
	 echo "En un kiosko nuevo (una sola vez), por consola:"; \
	 echo "  sudo bash $$dest/usb-update/bin/cdapuestas-kiosk-bootstrap.sh"

# Valida la conectividad de Tailscale SSH sin modificar una kiosk. Ejemplos:
#   make tailscale-check KIOSK=cdakiosk-001
#   make tailscale-check KIOSK=all
tailscale-check: ## Verifica Tailscale SSH (KIOSK=<alias|all>)
	@test -n "$(KIOSK)" || { echo "Indica KIOSK=cdakiosk-001, cdapuestas-kiosk-002, cdapuestas-kiosk-002-1 o all"; exit 1; }
	@set -euo pipefail; \
	case "$(KIOSK)" in \
	  cdakiosk-001) targets='cdakiosk-001|cdakiosk01|100.109.149.26' ;; \
	  cdapuestas-kiosk-002) targets='cdapuestas-kiosk-002|cdapuestaskiosk02|100.81.227.21' ;; \
	  cdapuestas-kiosk-002-1) targets='cdapuestas-kiosk-002-1|cdapuestas02|100.65.51.32' ;; \
	  all) targets='cdakiosk-001|cdakiosk01|100.109.149.26 cdapuestas-kiosk-002|cdapuestaskiosk02|100.81.227.21 cdapuestas-kiosk-002-1|cdapuestas02|100.65.51.32' ;; \
	  *) echo "KIOSK inválido: $(KIOSK)"; exit 1 ;; \
	esac; \
	for target in $$targets; do \
	  IFS='|' read -r name user host <<< "$$target"; \
	  echo "==> $$name ($$user@$$host)"; \
	  echo "    [1/2] Comprobando red Tailscale..."; \
	  tailscale ping --c=1 --until-direct=false "$$host"; \
	  echo "    [2/2] Abriendo Tailscale SSH (máximo $(TS_CONNECT_TIMEOUT)s)..."; \
	  timeout "$(TS_CONNECT_TIMEOUT)" $(TS_SSH) "$$user@$$host" 'printf "Tailscale SSH listo: %s@%s\\n" "$$USER" "$$(hostname)"'; \
	  echo "    OK: $$name listo para actualizar"; \
	done

# Instala el .deb actual mediante Tailscale SSH. Requiere Tailscale SSH activo
# en la kiosk y una ACL que autorice al usuario de desarrollo. Ejemplos:
#   make tailscale-update KIOSK=cdakiosk-001
#   make tailscale-update KIOSK=all
# No guarda credenciales: sudo pregunta la contraseña en cada kiosk.
tailscale-update: ## Instala el .deb por Tailscale (KIOSK=<alias|all>)
	@test -n "$(KIOSK)" || { echo "Indica KIOSK=cdakiosk-001, cdapuestas-kiosk-002, cdapuestas-kiosk-002-1 o all"; exit 1; }
	@test -f "$(DEB)" || { echo "No existe $(DEB). Corre 'make deploy' o pasa DEB=/ruta/al/archivo.deb"; exit 1; }
	@set -euo pipefail; \
	case "$(KIOSK)" in \
	  cdakiosk-001) targets='cdakiosk-001|cdakiosk01|100.109.149.26' ;; \
	  cdapuestas-kiosk-002) targets='cdapuestas-kiosk-002|cdapuestaskiosk02|100.81.227.21' ;; \
	  cdapuestas-kiosk-002-1) targets='cdapuestas-kiosk-002-1|cdapuestas02|100.65.51.32' ;; \
	  all) targets='cdakiosk-001|cdakiosk01|100.109.149.26 cdapuestas-kiosk-002|cdapuestaskiosk02|100.81.227.21 cdapuestas-kiosk-002-1|cdapuestas02|100.65.51.32' ;; \
	  *) echo "KIOSK inválido: $(KIOSK)"; exit 1 ;; \
	esac; \
	deb_name="$$(basename "$(DEB)")"; \
	for target in $$targets; do \
	  IFS='|' read -r name user host <<< "$$target"; \
	  echo "==> $$name ($$user@$$host)"; \
	  echo "    [1/3] Comprobando red Tailscale..."; \
	  tailscale ping --c=1 --until-direct=false "$$host"; \
	  echo "    [2/3] Transfiriendo $$deb_name ($$(du -h "$(DEB)" | cut -f1))..."; \
	  dd if="$(DEB)" bs=1M status=progress | timeout "$(TS_TRANSFER_TIMEOUT)" $(TS_SSH) "$$user@$$host" "cat > /tmp/$$deb_name"; \
	  echo "    [3/3] Instalando y reiniciando WebView (puede pedir sudo; máximo $(TS_INSTALL_TIMEOUT)s)..."; \
	  timeout --foreground "$(TS_INSTALL_TIMEOUT)" $(TS_SSH) "$$user@$$host" -tt "set -e; sudo dpkg -i /tmp/$$deb_name; sudo pkill -f '^/opt/cdapuestas_webview/cdapuestas-webview' || true; sleep 5; dpkg -s cdapuestas-webview | sed -n 's/^Version: /cdapuestas-webview /p'; test -f /etc/udev/rules.d/99-cdapuestas-printer-usb.rules; pgrep -f '^/opt/cdapuestas_webview/cdapuestas-webview --force' >/dev/null"; \
	  echo "    OK: $$name actualizado"; \
	done

clean: ## Borra la salida de build (dist/)
	rm -rf dist
