#!/bin/bash
#
# install.sh — Instala REMnux sobre arm64 (Ubuntu Desktop 24.04 / Debian
# Asahi) aplicando el exclude-list validado para dejar la corrida en
# 0 estados "Failed".
#
# Requisitos previos (ver DEPENDENCIES.md):
#   - Ubuntu/Debian arm64 con salida a internet
#   - Cast v1.0.4+ instalado (ver CAST-INSTALL.md)
#   - Salt 3008.2 instalado en modo masterless (ver CAST-INSTALL.md)
#   - remnux/salt-states clonado, normalmente vía:
#       cast install remnux/salt-states
#     (cast clona el repo internamente; requiere `git` instalado)
#
set -euo pipefail

SALT_STATES_DIR="${SALT_STATES_DIR:-$HOME/salt-states}"
EXCLUDE_FILE="$(dirname "$0")/exclude-list.txt"
LOG_FILE="${LOG_FILE:-$HOME/remnux-install-$(date +%Y%m%d-%H%M%S).log}"

if [ ! -d "$SALT_STATES_DIR" ]; then
    echo "ERROR: no se encuentra $SALT_STATES_DIR. Instala primero con:"
    echo "  cast install remnux/salt-states"
    echo "o ajusta la variable SALT_STATES_DIR."
    exit 1
fi

if [ ! -f "$EXCLUDE_FILE" ]; then
    echo "ERROR: no se encuentra $EXCLUDE_FILE"
    exit 1
fi

echo "== Verificando arquitectura =="
ARCH=$(sudo salt-call --local grains.get osarch --out=txt | awk -F': ' '{print $2}')
echo "grains osarch = $ARCH"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    echo "AVISO: arquitectura detectada '$ARCH', este exclude-list se validó en arm64."
    read -r -p "¿Continuar de todas formas? [y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || exit 1
fi

# Construye la lista de exclusión en formato YAML-list para salt,
# ignorando líneas vacías y comentarios (#) del fichero.
EXCLUDE_ITEMS=$(grep -v '^\s*#' "$EXCLUDE_FILE" | grep -v '^\s*$' | sed 's#/#.#g; s#\.sls$##' | paste -sd, -)

echo "== Rutas excluidas (${EXCLUDE_ITEMS//,/$'\n'}) =="

echo "== Aplicando remnux.addon (esto puede tardar ~20 min) =="
sudo salt-call --local state.apply remnux.addon "exclude=[${EXCLUDE_ITEMS}]" \
    --state-output=changes --log-level=info 2>&1 | tee "$LOG_FILE"

FAILED=$(grep -c 'Result: False' "$LOG_FILE" || true)
echo ""
echo "== Resultado =="
echo "Log completo en: $LOG_FILE"
echo "Estados con Result: False -> $FAILED"

if [ "$FAILED" -eq 0 ]; then
    echo "OK: 0 estados fallidos. Ejecuta ./verify.sh para comprobar binarios."
else
    echo "AVISO: hay estados fallidos no cubiertos por el exclude-list actual."
    echo "Revisa $LOG_FILE y añade las rutas correspondientes a exclude-list.txt."
fi
