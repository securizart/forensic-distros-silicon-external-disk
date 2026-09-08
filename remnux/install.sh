#!/bin/bash
#
# install.sh — Ejecuta remnux.addon COMPLETO en arm64 (Ubuntu Desktop
# 24.04 / Debian Asahi), sin exclude=.
#
# Por qué sin exclude=: usar exclude=[...] con los .sls conocidos como
# rotos en arm64 hace que el COMPILADOR de Salt (masterless, 3008.2)
# aborte antes de ejecutar nada, porque otros .sls tienen un
# `require: sls: <el excluido>` y Salt valida esas referencias en
# tiempo de compilación. Ver remnux/FINDINGS.md, sección "Por qué no
# se usa exclude=", para el detalle y el log real que confirmó esto.
#
# Enfoque en su lugar: dejar que remnux.addon se aplique entero,
# aceptando los ~120 estados "Failed" ya documentados (~88% de éxito),
# y ejecutar después cleanup.sh para eliminar los binarios rotos que
# SÍ quedan instalados de forma silenciosa (Salt los marca Succeeded
# aunque el binario sea x86-64 y no ejecute en arm64).
#
# Requisitos previos (ver DEPENDENCIES.md):
#   - Ubuntu/Debian arm64 con salida a internet
#   - Cast v1.0.4+ instalado (ver CAST-INSTALL.md)
#   - Salt 3008.2 instalado en modo masterless (ver CAST-INSTALL.md)
#   - remnux/salt-states clonado, normalmente vía:
#       cast install remnux/salt-states
#     (cast clona el repo internamente; requiere `git` instalado)
#
set -uo pipefail

SALT_STATES_DIR="${SALT_STATES_DIR:-$HOME/salt-states}"
LOG_FILE="${LOG_FILE:-$HOME/remnux-install-$(date +%Y%m%d-%H%M%S).log}"

if [ ! -d "$SALT_STATES_DIR" ]; then
    echo "ERROR: no se encuentra $SALT_STATES_DIR. Instala primero con:"
    echo "  cast install remnux/salt-states"
    echo "o ajusta la variable SALT_STATES_DIR."
    exit 1
fi

echo "== Verificando arquitectura =="
ARCH=$(sudo salt-call --local grains.get osarch --out=txt | awk -F': ' '{print $2}')
echo "grains osarch = $ARCH"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    echo "AVISO: arquitectura detectada '$ARCH', este flujo se validó en arm64."
    read -r -p "¿Continuar de todas formas? [y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || exit 1
fi

echo "== Aplicando remnux.addon COMPLETO, sin exclude= (esto puede tardar ~20 min) =="
echo "Se esperan del orden de ~120 estados fallidos conocidos (~88% de éxito)."
echo "Al terminar, ejecuta ./cleanup.sh para eliminar los binarios rotos y"
echo "./verify.sh para confirmar el resultado."
echo ""

sudo salt-call --local state.apply remnux.addon \
    --state-output=changes --log-level=info 2>&1 | tee "$LOG_FILE"

SUCCEEDED=$(grep -c 'Result: True' "$LOG_FILE" || true)
FAILED=$(grep -c 'Result: False' "$LOG_FILE" || true)
echo ""
echo "== Resultado =="
echo "Log completo en: $LOG_FILE"
echo "Estados con Result: True  -> $SUCCEEDED"
echo "Estados con Result: False -> $FAILED"
echo ""
echo "Siguiente paso: sudo ./cleanup.sh   (elimina binarios rotos conocidos)"
echo "Después:        ./verify.sh         (confirma que ya no están y que radare2 funciona)"
