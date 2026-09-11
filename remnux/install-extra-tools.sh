#!/bin/bash
#
# install-extra-tools.sh — Instala alternativas nativas arm64 para las
# herramientas de la categoría "NO-PKG" de REMnux: paquetes que
# remnux.addon intenta traer desde ppa:remnux/stable, pero que ese PPA
# SOLO compila para amd64 (ver FINDINGS.md, sección "PPA de REMnux
# amd64-only"). Cada función de este script instala la herramienta
# desde el binario/repo/fuente OFICIAL del proyecto correspondiente,
# no desde el PPA de REMnux — mismo patrón ya usado en el test-kit
# para docker-compose/redress/yr/die (ver verify.sh).
#
# Ejecutar DESPUÉS de install.sh + cleanup.sh + verify.sh (es decir,
# sobre una base ya validada del test-kit).
#
# Requisitos previos:
#   - Ubuntu/Debian arm64 con salida a internet
#   - sudo configurado para el usuario actual
#
set -uo pipefail

WORKDIR="${WORKDIR:-$HOME/remnux-extra-tools-build}"
mkdir -p "$WORKDIR"

# =============================================================================
# Resueltos SIN MATICES (funcionan al 100% en arm64, verificado en la práctica)
# 20 de ~24 candidatos NO-PKG de REMnux resueltos. Ver FINDINGS-extra-tools-arm64.md
# =============================================================================

install_powershell() {
    echo "[powershell] .deb oficial arm64 de Microsoft"
    local url
    url=$(curl -s https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
        | grep -o 'https://[^"]*deb_arm64\.deb' | head -1)
    if [ -z "$url" ]; then
        echo "      No se pudo resolver la URL automáticamente, usando versión conocida 7.6.6"
        url="https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/powershell_7.6.6-1.deb_arm64.deb"
    fi
    curl -fsSL -o "$WORKDIR/powershell-arm64.deb" "$url"
    sudo apt-get install -y "$WORKDIR/powershell-arm64.deb"
    echo "      Prueba: pwsh --version"
}

install_7zz() {
    echo "[7zz] binario oficial arm64 de 7-zip.org"
    local rel
    rel=$(curl -s https://www.7-zip.org/download.html | grep -oE 'a/7z[0-9]+-linux-arm64\.tar\.xz' | head -1)
    if [ -z "$rel" ]; then
        echo "      No se pudo resolver la URL automáticamente, sáltate este paso o revisa https://www.7-zip.org/download.html"
        return 1
    fi
    curl -fsSL -o "$WORKDIR/7zz-linux-arm64.tar.xz" "https://www.7-zip.org/$rel"
    mkdir -p "$WORKDIR/7zz-install"
    tar xf "$WORKDIR/7zz-linux-arm64.tar.xz" -C "$WORKDIR/7zz-install"
    sudo install -m 755 "$WORKDIR/7zz-install/7zz" /usr/local/bin/7zz
    echo "      Prueba: 7zz i"
}

install_unrar() {
    echo "[unrar] compilado desde fuente oficial de rarlab.com (solo EXTRACCIÓN; 'rar', el"
    echo "        archivador completo para CREAR .rar, es Categoría A: RARLAB no publica"
    echo "        binario arm64 Linux del 'rar' propietario, solo vía emulación QEMU/FEX)"
    curl -fsSL -o "$WORKDIR/unrarsrc.tar.gz" https://www.rarlab.com/rar/unrarsrc-7.2.4.tar.gz
    (cd "$WORKDIR" && tar xzf unrarsrc.tar.gz && cd unrar && make -f makefile)
    sudo install -v -m755 "$WORKDIR/unrar/unrar" /usr/local/bin/
    echo "      Prueba: unrar"
}

install_aeskeyfind() {
    echo "[aeskeyfind] compilado desde fuente (mbroz/aeskeyfind)"
    git clone --depth 1 https://github.com/mbroz/aeskeyfind.git "$WORKDIR/aeskeyfind" 2>/dev/null \
        || (cd "$WORKDIR/aeskeyfind" && git pull)
    (cd "$WORKDIR/aeskeyfind" && make)
    sudo install -m755 "$WORKDIR/aeskeyfind/aeskeyfind" /usr/local/bin/
    echo "      Prueba: aeskeyfind -h"
}

install_xorsearch() {
    echo "[xorsearch] vía la versión Python de DidierStevensSuite (agnóstica de arquitectura)"
    echo "            NOTA: 'xorstrings' NO tiene equivalente resuelto en este mirror - sigue"
    echo "            pendiente, se omite deliberadamente (ver FINDINGS.md)"
    git clone --depth 1 https://github.com/DidierStevens/DidierStevensSuite.git "$WORKDIR/DidierStevensSuite" 2>/dev/null \
        || (cd "$WORKDIR/DidierStevensSuite" && git pull)
    sudo tee /usr/local/bin/xorsearch >/dev/null <<WRAPPER
#!/bin/bash
exec python3 "$WORKDIR/DidierStevensSuite/xorsearch.py" "\$@"
WRAPPER
    sudo chmod +x /usr/local/bin/xorsearch
    echo "      Prueba: xorsearch -h"
}

install_jd_gui() {
    echo "[jd-gui] jar oficial (java-decompiler/jd-gui), requiere JDK"
    curl -fsSL -o "$WORKDIR/jd-gui.jar" \
        https://github.com/java-decompiler/jd-gui/releases/download/v1.6.6/jd-gui-1.6.6.jar
    sudo install -m755 -d /opt/jd-gui
    sudo install -m644 "$WORKDIR/jd-gui.jar" /opt/jd-gui/jd-gui.jar
    sudo tee /usr/local/bin/jd-gui >/dev/null <<'WRAPPER'
#!/bin/bash
exec java -jar /opt/jd-gui/jd-gui.jar "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/jd-gui
    echo "      Prueba: jd-gui (abre GUI)"
}

install_baksmali() {
    echo "[baksmali] fat jar oficial (baksmali/smali), requiere JDK"
    local url
    url=$(curl -s https://api.github.com/repos/baksmali/smali/releases/latest \
        | grep -o 'https://[^"]*baksmali-[0-9.]*-fat\.jar' | head -1)
    if [ -z "$url" ]; then
        echo "      No se pudo resolver automáticamente, usando versión conocida 3.0.10"
        url="https://github.com/baksmali/smali/releases/download/3.0.10/baksmali-3.0.10-fat.jar"
    fi
    curl -fsSL -o "$WORKDIR/baksmali.jar" "$url"
    sudo install -m755 -d /opt/baksmali
    sudo install -m644 "$WORKDIR/baksmali.jar" /opt/baksmali/baksmali.jar
    sudo tee /usr/local/bin/baksmali >/dev/null <<'WRAPPER'
#!/bin/bash
exec java -jar /opt/baksmali/baksmali.jar "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/baksmali
    echo "      Prueba: baksmali --version"
}

install_binee() {
    echo "[binee] compilado con Go (carbonblack/binee), depende de Unicorn Engine"
    sudo apt-get install -y libunicorn-dev golang-go
    git clone --depth 1 https://github.com/carbonblack/binee.git "$WORKDIR/binee" 2>/dev/null \
        || (cd "$WORKDIR/binee" && git pull)
    (cd "$WORKDIR/binee" && go build -o binee .)
    sudo install -m755 "$WORKDIR/binee/binee" /usr/local/bin/
    echo "      Prueba: binee -h"
}

install_manalyze() {
    echo "[manalyze] compilado con CMake (JusticeRage/Manalyze)"
    sudo apt-get install -y libboost-regex-dev libboost-program-options-dev \
        libboost-system-dev libboost-filesystem-dev libssl-dev cmake
    git clone --depth 1 https://github.com/JusticeRage/Manalyze.git "$WORKDIR/Manalyze" 2>/dev/null \
        || (cd "$WORKDIR/Manalyze" && git pull)
    (cd "$WORKDIR/Manalyze" && cmake . && make -j"$(nproc)")
    sudo install -m755 "$WORKDIR/Manalyze/bin/manalyze" /usr/local/bin/
    echo "      Prueba: manalyze --version"
}

install_bearparser() {
    echo "[bearparser] compilado con CMake + Qt5 (hasherezade/bearparser)"
    sudo apt-get install -y qtbase5-dev cmake
    git clone --depth 1 https://github.com/hasherezade/bearparser.git "$WORKDIR/bearparser-src" 2>/dev/null \
        || (cd "$WORKDIR/bearparser-src" && git pull)
    mkdir -p "$WORKDIR/bearparser-build"
    (cd "$WORKDIR/bearparser-build" && cmake -G "Unix Makefiles" "$WORKDIR/bearparser-src/" && make -j"$(nproc)")
    sudo install -m755 "$WORKDIR/bearparser-build/commander/bearcommander" /usr/local/bin/
    echo "      Prueba: bearcommander"
}

install_pycdc() {
    echo "[pycdc/pycdas] compilado con CMake, sin dependencias externas (zrax/pycdc)"
    sudo apt-get install -y cmake
    git clone --depth 1 https://github.com/zrax/pycdc.git "$WORKDIR/pycdc" 2>/dev/null \
        || (cd "$WORKDIR/pycdc" && git pull)
    mkdir -p "$WORKDIR/pycdc/build"
    (cd "$WORKDIR/pycdc/build" && cmake -DCMAKE_BUILD_TYPE=Release .. && make -j"$(nproc)")
    sudo install -m755 "$WORKDIR/pycdc/build/pycdc" /usr/local/bin/
    sudo install -m755 "$WORKDIR/pycdc/build/pycdas" /usr/local/bin/
    echo "      Prueba: pycdas --help"
}

install_msoffice_crypt() {
    echo "[msoffice-crypt] compilado con make (herumi/msoffice + herumi/cybozulib)"
    mkdir -p "$WORKDIR/msoffice-work" && cd "$WORKDIR/msoffice-work"
    git clone --depth 1 https://github.com/herumi/cybozulib 2>/dev/null || (cd cybozulib && git pull)
    git clone --depth 1 https://github.com/herumi/msoffice 2>/dev/null || true
    (cd msoffice && mkdir -p bin && make -j"$(nproc)" RELEASE=1)
    sudo install -m755 "$WORKDIR/msoffice-work/msoffice/bin/msoffice-crypt.exe" /usr/local/bin/msoffice-crypt
    cd - >/dev/null
    echo "      Prueba: msoffice-crypt -h  (nota: se instala sin el sufijo .exe)"
}

install_portex() {
    echo "[portex] CLI ya compilada (PortexAnalyzer.jar, struppigel/PortEx), requiere JDK"
    curl -fsSL -o "$WORKDIR/PortexAnalyzer.jar" \
        https://github.com/struppigel/PortEx/releases/latest/download/PortexAnalyzer.jar
    sudo install -m755 -d /opt/portex
    sudo install -m644 "$WORKDIR/PortexAnalyzer.jar" /opt/portex/PortexAnalyzer.jar
    sudo tee /usr/local/bin/portex >/dev/null <<'WRAPPER'
#!/bin/bash
exec java -jar /opt/portex/PortexAnalyzer.jar "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/portex
    echo "      Prueba: portex -v"
}

install_signsrch() {
    echo "[signsrch] compilado con make (mirror sandsmark/signsrch del original de Luigi Auriemma)"
    git clone --depth 1 https://github.com/sandsmark/signsrch.git "$WORKDIR/signsrch" 2>/dev/null \
        || (cd "$WORKDIR/signsrch" && git pull)
    (cd "$WORKDIR/signsrch" && make)
    sudo install -m755 "$WORKDIR/signsrch/signsrch" /usr/local/bin/
    echo "      Prueba: signsrch"
    echo "      NOTA: para uso real hace falta también signsrch.sig (fichero de firmas),"
    echo "      descarga aparte de http://aluigi.org/mytoolz/signsrch.sig.zip"
}

install_ilspycmd() {
    echo "[ilspycmd] herramienta dotnet (ICSharpCode.ILSpy), requiere .NET SDK 8"
    sudo apt-get install -y dotnet-sdk-8.0 2>/dev/null \
        || { wget -q https://dot.net/v1/dotnet-install.sh -O "$WORKDIR/dotnet-install.sh" \
             && bash "$WORKDIR/dotnet-install.sh" --channel 8.0; }
    export PATH="$PATH:$HOME/.dotnet:$HOME/.dotnet/tools"
    # La resolución "sin versión" puede fallar por metadata NuGet incompleta -
    # se fija una versión conocida-buena directamente.
    dotnet nuget locals all --clear >/dev/null 2>&1 || true
    dotnet tool install --global ilspycmd --version 9.1.0.7988 \
        || dotnet tool update --global ilspycmd --version 9.1.0.7988 --allow-downgrade
    echo "      Prueba: ilspycmd --version  (asegúrate de tener \$HOME/.dotnet/tools en el PATH)"
}

install_flare_floss() {
    echo "[flare-floss] Mandiant FLARE team, vía pip (incluye vivisect, sin problema en arm64)"
    pip install flare-floss --break-system-packages
    echo "      Prueba: floss --help  (asegúrate de tener \$HOME/.local/bin en el PATH)"
}

install_evilclippy() {
    echo "[evilclippy] compilado con Mono (outflanknl/EvilClippy, no distribuye binario)"
    sudo apt-get install -y mono-complete
    git clone --depth 1 https://github.com/outflanknl/EvilClippy.git "$WORKDIR/EvilClippy" 2>/dev/null \
        || (cd "$WORKDIR/EvilClippy" && git pull)
    (cd "$WORKDIR/EvilClippy" && mcs /reference:OpenMcdf.dll,System.IO.Compression.FileSystem.dll -out:EvilClippy.exe *.cs)
    sudo install -m755 -d /opt/evilclippy
    sudo install -m644 "$WORKDIR/EvilClippy/EvilClippy.exe" /opt/evilclippy/
    sudo tee /usr/local/bin/evilclippy >/dev/null <<'WRAPPER'
#!/bin/bash
exec mono /opt/evilclippy/EvilClippy.exe "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/evilclippy
    echo "      Prueba: evilclippy -h"
}

install_android_project_creator() {
    echo "[android-project-creator] jar oficial con dependencias (ThisIsLibra/AndroidProjectCreator), requiere JDK"
    local url
    url=$(curl -s https://api.github.com/repos/ThisIsLibra/AndroidProjectCreator/releases/latest \
        | grep -o 'https://[^"]*\.jar' | head -1)
    if [ -z "$url" ]; then
        echo "      No se pudo resolver automáticamente, usando versión conocida 1.5.2-stable"
        url="https://github.com/ThisIsLibra/AndroidProjectCreator/releases/download/1.5.2-stable/AndroidProjectCreator-1.5.2-stable-jar-with-dependencies.jar"
    fi
    curl -fsSL -o "$WORKDIR/AndroidProjectCreator.jar" "$url"
    sudo install -m755 -d /opt/android-project-creator
    sudo install -m644 "$WORKDIR/AndroidProjectCreator.jar" /opt/android-project-creator/
    sudo tee /usr/local/bin/AndroidProjectCreator >/dev/null <<'WRAPPER'
#!/bin/bash
exec java -jar /opt/android-project-creator/AndroidProjectCreator.jar "$@"
WRAPPER
    sudo chmod +x /usr/local/bin/AndroidProjectCreator
    echo "      Prueba: AndroidProjectCreator -h"
}

install_sandfly_processdecloak() {
    echo "[sandfly-processdecloak] compilado con Go (sandflysecurity/sandfly-processdecloak)"
    sudo apt-get install -y golang-go
    git clone --depth 1 https://github.com/sandflysecurity/sandfly-processdecloak.git "$WORKDIR/sandfly-processdecloak" 2>/dev/null \
        || (cd "$WORKDIR/sandfly-processdecloak" && git pull)
    (cd "$WORKDIR/sandfly-processdecloak" && go build -o sandfly-processdecloak .)
    sudo install -m755 "$WORKDIR/sandfly-processdecloak/sandfly-processdecloak" /usr/local/bin/
    echo "      Prueba: sandfly-processdecloak"
}

# =============================================================================
# Resuelto CON MATIZ: funciona pero con una limitación real conocida
# =============================================================================

install_ghidra() {
    echo "[ghidra] release oficial multiplataforma (NationalSecurityAgency/ghidra)"
    echo "         AVISO: la GUI y el desensamblador funcionan perfectamente en arm64,"
    echo "         pero el DECOMPILADOR NATIVO no tiene build linux_arm_64 oficial y"
    echo "         compilarlo choca con un bug conocido y sin resolver de Ghidra (issues"
    echo "         #7958/#5204 upstream). Ghidra queda utilizable para desensamblador,"
    echo "         navegación y scripting, SIN decompilador. Ver FINDINGS.md para detalle."
    sudo apt-get install -y openjdk-21-jdk unzip
    curl -fsSL -o "$WORKDIR/ghidra.zip" \
        https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.3_build/ghidra_12.1.3_PUBLIC_20260817.zip
    echo "93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54  $WORKDIR/ghidra.zip" | sha256sum -c - \
        || { echo "      ERROR: el hash SHA256 no coincide, aborta (puede que haya salido una versión nueva)"; return 1; }
    sudo unzip -q -o "$WORKDIR/ghidra.zip" -d /opt
    sudo ln -sf /opt/ghidra_12.1.3_PUBLIC/ghidraRun /usr/local/bin/ghidra
    echo "      Prueba: ghidra (abre GUI, con warning esperado de componentes nativos)"
}

# =============================================================================
# NO se instala aquí (requiere interacción manual / licencia) — solo guía
# =============================================================================

guide_burpsuite() {
    cat <<'EOF'
[burpsuite-community] NO se puede automatizar con una URL fija: PortSwigger
sirve el instalador desde un formulario de descarga, no una URL estática.
Pasos manuales (confirmado funcionando):
  1. Abre un navegador DENTRO de la VM arm64
  2. Ve a https://portswigger.net/burp/communitydownload
  3. Elige explícitamente la build "Linux (ARM)" (NO "Linux (x64)")
  4. chmod +x burpsuite_community_linux_v*.sh && sudo ./burpsuite_community_linux_v*.sh
Incluye su propia JRE embebida, sin depender de pkgrepo:remnux.
EOF
}

# =============================================================================
# Dispatcher
# =============================================================================

install_all_no_matices() {
    install_powershell
    install_7zz
    install_unrar
    install_aeskeyfind
    install_xorsearch
    install_jd_gui
    install_baksmali
    install_binee
    install_manalyze
    install_bearparser
    install_pycdc
    install_msoffice_crypt
    install_portex
    install_signsrch
    install_ilspycmd
    install_flare_floss
    install_evilclippy
    install_android_project_creator
    install_sandfly_processdecloak
}

case "${1:-}" in
    --all)
        install_all_no_matices
        echo ""
        echo "Ghidra y Burp Suite Community requieren pasos aparte:"
        echo "  ./install-extra-tools.sh --ghidra"
        echo "  ./install-extra-tools.sh --burpsuite-guide"
        ;;
    --ghidra)
        install_ghidra
        ;;
    --burpsuite-guide)
        guide_burpsuite
        ;;
    --powershell) install_powershell ;;
    --7zz) install_7zz ;;
    --unrar) install_unrar ;;
    --aeskeyfind) install_aeskeyfind ;;
    --xorsearch) install_xorsearch ;;
    --jd-gui) install_jd_gui ;;
    --baksmali) install_baksmali ;;
    --binee) install_binee ;;
    --manalyze) install_manalyze ;;
    --bearparser) install_bearparser ;;
    --pycdc) install_pycdc ;;
    --msoffice-crypt) install_msoffice_crypt ;;
    --portex) install_portex ;;
    --signsrch) install_signsrch ;;
    --ilspycmd) install_ilspycmd ;;
    --flare-floss) install_flare_floss ;;
    --evilclippy) install_evilclippy ;;
    --android-project-creator) install_android_project_creator ;;
    --sandfly-processdecloak) install_sandfly_processdecloak ;;
    *)
        echo "Uso: $0 --all | --ghidra | --burpsuite-guide | --<herramienta>"
        echo ""
        echo "Herramientas individuales disponibles:"
        echo "  powershell 7zz unrar aeskeyfind xorsearch jd-gui baksmali binee"
        echo "  manalyze bearparser pycdc msoffice-crypt portex signsrch"
        echo "  ilspycmd flare-floss evilclippy android-project-creator sandfly-processdecloak"
        echo ""
        echo "--all instala las 20 resueltas sin matices de una vez."
        echo "Ghidra (con matiz: sin decompilador nativo) y Burp Suite Community"
        echo "(requiere descarga manual con licencia) van aparte."
        exit 1
        ;;
esac
