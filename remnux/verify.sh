#!/bin/bash
#
# verify.sh — Ejecutar DESPUÉS de install.sh + cleanup.sh. Comprueba
# que los binarios amd64-only conocidos como rotos en arm64 ya NO
# están presentes (cleanup.sh los mueve a backup), y que los binarios
# sí soportados (radare2, vía la macro osarch.sls) funcionan
# correctamente.
#
set -uo pipefail

# Binario -> comando de comprobación de arquitectura del ELF.
# Si el comando falla o el binario no existe, se considera "OK, no instalado".
declare -A BROKEN_BINARIES=(
    [cutter]="cutter"
    [redress]="redress"
    [yr]="yr"
    [docker-compose]="docker-compose"
    [die]="die"
    [diec]="diec"
    [inspircd]="inspircd"
)

fail=0

echo "== Comprobando que los binarios amd64-only NO están instalados =="
for name in "${!BROKEN_BINARIES[@]}"; do
    bin="${BROKEN_BINARIES[$name]}"
    path=$(command -v "$bin" 2>/dev/null || true)
    if [ -z "$path" ]; then
        echo "  [OK]   $name: no instalado"
        continue
    fi
    elf_arch=$(file -b "$path" 2>/dev/null | grep -oE 'ARM aarch64|x86-64' || echo "desconocido")
    if [ "$elf_arch" = "x86-64" ]; then
        echo "  [MAL]  $name: instalado en $path pero es x86-64 (Exec format error esperado)"
        fail=1
    elif [ "$elf_arch" = "ARM aarch64" ]; then
        echo "  [INFO] $name: instalado en $path y SÍ es arm64 (¿parche upstream? revisar)"
    else
        echo "  [WARN] $name: instalado en $path, arquitectura no determinada"
        fail=1
    fi
done

echo ""
echo "== Comprobando que radare2 (macro osarch.sls) funciona =="
if command -v r2 >/dev/null 2>&1; then
    if r2 -v >/dev/null 2>&1; then
        echo "  [OK]   radare2 responde correctamente: $(r2 -v | head -1)"
    else
        echo "  [MAL]  radare2 instalado pero falla al ejecutar"
        fail=1
    fi
else
    echo "  [WARN] radare2 no está instalado (revisar log de install.sh)"
fi

echo ""
if [ "$fail" -eq 0 ]; then
    echo "RESULTADO: verificación OK."
    exit 0
else
    echo "RESULTADO: hay incidencias, revisa el detalle arriba."
    exit 1
fi
