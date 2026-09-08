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
    elf_out=$(file -b "$path" 2>/dev/null || echo "")
    if echo "$elf_out" | grep -qiE 'x86[_-]64'; then
        echo "  [MAL]  $name: instalado en $path pero es x86-64 (Exec format error esperado)"
        fail=1
    elif echo "$elf_out" | grep -qiE 'aarch64|arm64'; then
        echo "  [INFO] $name: instalado en $path y SÍ es arm64 (¿parche upstream? revisar)"
    else
        echo "  [WARN] $name: instalado en $path, arquitectura no determinada ($elf_out)"
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
else
    echo "RESULTADO: hay incidencias, revisa el detalle arriba."
fi

# =============================================================================
# Alternativas nativas arm64 para los binarios rotos
# =============================================================================
# NO se ejecutan solas. verify.sh sin argumentos solo verifica (arriba).
# Para instalar las alternativas: ./verify.sh --install-alternatives
#
# Cada binario usa el método que le corresponde para no arrastrar
# dependencias rotas ni pisar paquetes del sistema:
#   - docker-compose: paquete Ubuntu nativo (apt, sin repos externos)
#   - cutter:         repo oficial del proyecto (RizinOrg), pineado a
#                      baja prioridad para que NUNCA compita con el
#                      archivo de Ubuntu en otros paquetes (mismo
#                      patrón que el pin de Kali en el instalador base)
#   - redress:        toolchain nativa (golang-go de apt) + compilación
#                      propia; no toca libs del sistema más allá de compilar
#   - yr (yara-x):    rustup (toolchain Rust aislado en $HOME), NO el
#                      cargo de apt (demasiado antiguo para yara-x-cli)
#   - inspircd:       SOLO bajo flag aparte — la versión de Ubuntu
#                      (3.17.0) es 2 majors más vieja que la 4.7.0 que
#                      pide remnux, no es un sustituto limpio
#   - die/diec:       Flatpak oficial (Flathub), aislado del sistema
#                      por diseño (no toca dependencias apt en absoluto)
# =============================================================================

install_docker_compose() {
    echo "[1/6] docker-compose -> docker-compose-plugin (ya instalado como dependencia de docker-ce, arm64 nativo)"
    if [ ! -e /usr/libexec/docker/cli-plugins/docker-compose ]; then
        echo "      AVISO: no se encuentra el plugin; instalando por si acaso."
        sudo apt-get install -y docker-compose-plugin
    fi
    sudo ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    echo "      Symlink creado. Prueba: docker-compose version  (o: docker compose version)"
}

install_cutter() {
    echo "[2/6] cutter -> cutter-re (repo oficial RizinOrg, arm64, build xUbuntu_24.04)"
    echo "      AVISO: la build para xUbuntu_22.04 falla en Ubuntu 24.04 porque"
    echo "      depende de libpython3.10 (24.04 trae libpython3.12). Se usa la"
    echo "      carpeta xUbuntu_24.04 del mismo repo OBS, no confirmada al 100%"
    echo "      desde aquí (sin acceso directo al repo) — si también falla,"
    echo "      la alternativa es compilar Cutter desde fuente."
    echo "      Repo pineado a Pin-Priority 100 para que nunca sustituya"
    echo "      paquetes del archivo principal de Ubuntu."
    curl -fsSL https://download.opensuse.org/repositories/home:RizinOrg/xUbuntu_24.04/Release.key \
        | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home-rizinorg.gpg >/dev/null
    echo 'deb [signed-by=/etc/apt/trusted.gpg.d/home-rizinorg.gpg] https://download.opensuse.org/repositories/home:/RizinOrg/xUbuntu_24.04/ /' \
        | sudo tee /etc/apt/sources.list.d/home-rizinorg.list >/dev/null
    printf 'Package: *\nPin: origin download.opensuse.org\nPin-Priority: 100\n' \
        | sudo tee /etc/apt/preferences.d/rizinorg.pref >/dev/null
    sudo apt-get update
    if sudo apt-get install -y cutter-re; then
        echo "      Instalado como 'cutter-re'. El binario suele quedar en"
        echo "      /usr/bin/cutter-re o similar — revisa 'dpkg -L cutter-re'"
        echo "      si necesitas un symlink a 'cutter'."
    else
        echo "      FALLÓ también con xUbuntu_24.04. Alternativa: compilar desde"
        echo "      fuente (ver https://github.com/rizinorg/cutter, Building Docs)"
        echo "      o usar el AppImage x86_64 vía FEX-Emu/Box64 (no probado)."
    fi
}

install_redress() {
    echo "[3/6] redress -> compilado con Go nativo (golang-go, apt)"
    sudo apt-get install -y golang-go
    sudo GOBIN=/usr/local/bin go install github.com/goretk/redress@latest
    echo "      Instalado en /usr/local/bin/redress. Prueba: redress version"
}

install_yara_x() {
    echo "[4/6] yr (yara-x) -> compilado con Rust vía rustup (NO el cargo de apt)"
    echo "      El cargo/rustc de los repos de Ubuntu 24.04 es 1.75.0;"
    echo "      yara-x-cli exige rustc >= 1.93. rustup instala un toolchain"
    echo "      moderno aislado en \$HOME/.cargo, sin tocar paquetes del sistema."
    if [ ! -x "$HOME/.cargo/bin/cargo" ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    fi
    "$HOME/.cargo/bin/cargo" install yara-x-cli
    sudo ln -sf "$HOME/.cargo/bin/yr" /usr/local/bin/yr
    echo "      Instalado. Prueba: yr --version"
}

install_inspircd_downgrade() {
    echo "[5/6] inspircd -> AVISO: solo hay v3.17.0 en Ubuntu arm64,"
    echo "      remnux.sls pide v4.7.0. Esto NO es un sustituto limpio:"
    echo "      configs/módulos de la v4 pueden no funcionar en la v3."
    read -r -p "      ¿Instalar igualmente la v3.17.0 de Ubuntu? [y/N] " ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        sudo apt-get install -y inspircd
        echo "      Instalada v3.17.0 — revisa la config manualmente."
    else
        echo "      Omitido."
    fi
}

install_detect_it_easy() {
    echo "[6/6] die/diec -> Flatpak oficial (Flathub, arm64)"
    sudo apt-get install -y flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub io.github.horsicq.detect-it-easy
    sudo tee /usr/local/bin/die >/dev/null <<'WRAPPER'
#!/bin/bash
exec flatpak run io.github.horsicq.detect-it-easy "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/die
    echo "      Instalado como 'die' (wrapper a Flatpak)."
    echo "      AVISO: no confirmado si el Flatpak expone también 'diec'"
    echo "      (variante consola) como comando separado — revisar"
    echo "      manualmente con: flatpak run --command=diec io.github.horsicq.detect-it-easy --help"
}

install_arm64_alternatives() {
    install_docker_compose
    install_cutter
    install_redress
    install_yara_x
    install_detect_it_easy
    echo ""
    echo "inspircd NO incluido automáticamente (downgrade, no sustituto limpio)."
    echo "Para intentarlo: ./verify.sh --install-inspircd-downgrade"
}

case "${1:-}" in
    --install-alternatives)
        install_arm64_alternatives
        ;;
    --install-inspircd-downgrade)
        install_inspircd_downgrade
        ;;
esac

exit "$fail"
