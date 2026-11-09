# Makefile del printView (CD Apuestas WebView).
# Automatiza el build del .deb y el empaquetado de cada actualización en el
# catálogo versionado releases/ (ver releases/README.md y docs/kiosk-linux.md).
#
# Uso típico: bumpea la versión en package.json y corre `make deploy`.

SHELL := /bin/bash
VERSION := $(shell node -p "require('./package.json').version" 2>/dev/null)
OUTPUT_DIR := dist/full
RELEASE_DIR := releases/$(VERSION)
AUTOSTART_TEMPLATE := releases/autostart.template.sh

.DEFAULT_GOAL := help
.PHONY: help version install build deploy release usb clean

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
	npm run build:full:linux

# deploy = build + empaquetar la versión actual en releases/<version>/ con su
# .deb y su autostart.sh. Es lo que corres para publicar un update.
deploy: build release ## Genera el binario y arma releases/<version>/ (todo)

release: ## Arma releases/<version>/ a partir del .deb ya construido en dist/full/
	@test -n "$(VERSION)" || { echo "No pude leer la versión de package.json"; exit 1; }
	@deb=$$(ls -t $(OUTPUT_DIR)/*.deb 2>/dev/null | head -n 1); \
	 if [ -z "$$deb" ]; then \
	   echo "No encontré ningún .deb en $(OUTPUT_DIR)/. Corre 'make build' primero."; exit 1; \
	 fi; \
	 mkdir -p "$(RELEASE_DIR)"; \
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
	 sync; \
	 echo "Copiado $(RELEASE_DIR) y el kit usb-update/ a $$dest. Ya puedes expulsar el USB."; \
	 echo "En un kiosko nuevo (una sola vez), por consola:"; \
	 echo "  sudo bash $$dest/usb-update/bin/cdapuestas-kiosk-bootstrap.sh"

clean: ## Borra la salida de build (dist/)
	rm -rf dist
