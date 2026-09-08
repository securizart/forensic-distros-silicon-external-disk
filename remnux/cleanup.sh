#!/bin/bash
#
# cleanup.sh — Limpieza posterior a install.sh (remnux.addon SIN exclude=).
#
# remnux.addon deja instalados en silencio (Salt: Result: True) algunos
# binarios sueltos ELF x86-64 que en arm64 dan "Exec format error" al
# ejecutarlos, porque sus .sls solo hacen file.managed/archive.extracted
# con verificación de hash, sin comprobar arquitectura. Este script los
# localiza y los mueve a una carpeta de backup (no los borra sin más, por
# si se quiere inspeccionar o el usuario ya los había sustituido a mano).
#
# Categorías [RUIDOSO] (inspircd, detect-it-easy) NO dejan binario a medio
# instalar: su pkg.installed vía apt/dpkg aborta la transacción por
# dependencias :amd64 no resolubles, así que no hay nada que limpiar ahí
# salvo, potencialmente, el estado "held broken packages" de apt — ver la
# sección APT al final de este script.
#
set -uo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/remnux-broken-binaries-backup}"
mkdir -p "$BACKUP_DIR"

# comando -> paquete/.sls de origen (solo referencia informativa)
declare -A BROKEN_BINARIES=(
    [cutter]="remnux.tools.cutter"
    [redress]="remnux.tools.redress"
    [yr]="remnux.python3-packages.yara-x"
    [docker-compose]="remnux.tools.docker-compose"
)

moved=0
echo "== Buscando binarios amd64 conocidos como rotos en arm64 =="
for bin in "${!BROKEN_BINARIES[@]}"; do
    src="remnux.addon:${BROKEN_BINARIES[$bin]}"
    path=$(command -v "$bin" 2>/dev/null || true)
    if [ -z "$path" ]; then
        echo "  [--]   $bin: no está instalado, nada que hacer"
        continue
    fi
    elf_arch=$(file -b "$path" 2>/dev/null | grep -oE 'ARM aarch64|x86-64' || echo "desconocido")
    if [ "$elf_arch" != "x86-64" ]; then
        echo "  [SKIP] $bin: instalado en $path pero NO es x86-64 (arch: $elf_arch) — no se toca"
        continue
    fi
    dest="$BACKUP_DIR/$(basename "$path").x86_64.bak"
    echo "  [MOVE] $bin: $path (x86-64) -> $dest  [origen: $src]"
    if sudo mv "$path" "$dest" 2>/dev/null; then
        moved=$((moved + 1))
    else
        echo "         ERROR moviendo $path, revisa permisos manualmente"
    fi
done

echo ""
echo "== Binarios movidos a backup: $moved (en $BACKUP_DIR) =="

# --- APT: comprobar si quedaron paquetes "held broken" tras los intentos
#     fallidos de instalar inspircd.sls / detect-it-easy.sls ---
echo ""
echo "== Comprobando estado de apt tras los intentos fallidos de RUIDOSO =="
if sudo apt-get check >/tmp/remnux-apt-check.log 2>&1; then
    echo "  [OK] apt-get check no reporta problemas."
else
    echo "  [AVISO] apt-get check reporta problemas, ver /tmp/remnux-apt-check.log"
    echo "  Puedes intentar arreglarlo con:"
    echo "    sudo apt --fix-broken install"
fi

echo ""
echo "Limpieza terminada. Ejecuta ./verify.sh para confirmar el resultado final."
