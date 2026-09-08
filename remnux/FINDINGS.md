# REMnux en arm64 — Findings

🇬🇧 [English version](FINDINGS.en.md)

Ver también: [`DEPENDENCIES.md`](DEPENDENCIES.md) (dependencias del sistema, Cast, Salt), [`CAST-INSTALL.md`](CAST-INSTALL.md) (pasos concretos de instalación de Cast), [`install.sh`](install.sh) + [`exclude-list.txt`](exclude-list.txt) (instalación reproducible), [`verify.sh`](verify.sh) (verificación post-instalación).

## Entorno de prueba

VM UTM, Ubuntu Desktop 24.04 arm64, usuario `iac`. Cast v1.0.4 (`.deb` oficial de `ekristen/cast`, funciona nativo en Apple Silicon). `remnux/salt-states` clonado en `/home/iac/salt-states`. Salt 3008.2 instalado vía `packages.broadcom.com` en modo masterless (`file_client: local`, `file_roots → base: [/home/iac/salt-states]`). `grains osarch = arm64` confirmado. Snapshot UTM antes de cada prueba de `.sls`.

## Identificación de candidatos de riesgo

De 393 `.sls` totales:

- La mayoría usa `apt` directo (arch-neutral, sin riesgo).
- ~10 usan la macro `remnux/osarch.sls` (arch-aware, resuelven bien en arm64: `radare2.sls`, `docker.sls`, `winehq.sls`, etc.).
- **7 tenían assets amd64/x86_64 hardcodeados sin rama de arquitectura**: `packages/inspircd.sls`, `python3-packages/stpyv8.sls`, `tools/cutter.sls`, `tools/detect-it-easy.sls`, `tools/docker-compose.sls`, `tools/redress.sls`, `tools/yara-x.sls`.

## Tres patrones de fallo confirmados (7/7)

### 1. Ruidoso (vía dpkg/apt)
Salt marca `Failed`, error claro de apt sobre dependencias `:amd64`.

- `inspircd.sls`: `.deb` amd64 hardcodeado; Ubuntu universe tiene build arm64 pero solo v3.17.0 (dos versiones mayores por debajo de la v4.7.0 requerida) — **no es un drop-in viable**.
- `detect-it-easy.sls`: `.deb` amd64 hardcodeado; 10 dependencias Qt5 `:amd64` sin resolver salvo habilitando arquitectura foránea.

### 2. Silencioso (vía binario/AppImage/tarball suelto)
Salt reporta `Result: True / Succeeded`, pero el binario es ELF x86-64 y da `Exec format error` al ejecutarlo. **El más peligroso** porque no hay comprobación en tiempo de instalación.

- `docker-compose.sls`, `cutter.sls`, `redress.sls`, `yara-x.sls`.
- Nota: `redress.sls` dispara también la instalación completa de `radare2.sls`, que se completa correctamente en arm64 incluyendo plugins `r2ai`/`decai` vía `r2pm -ci` — confirma que el patrón de macro arch-aware funciona bien.

### 3. Explícito (vía pip wheel tags)
pip valida los tags de plataforma antes de instalar y rechaza con un mensaje claro.

- `stpyv8.sls`: wheel `manylinux_2_31_x86_64`; probado indirectamente vía `peepdf-3.sls`/`thug.sls`, que invocan la macro `install_stpyv8`.
- Bug aparte no relacionado con arquitectura: `STPyV8` en PyPI falla al compilar desde sdist por `ModuleNotFoundError: No module named settings` en su `setup.py`.

## Corrida completa (`remnux.addon`, sin exclusiones)

~88% instala correctamente: **889/1009 estados con éxito, 120 fallos** (~20 min).

Categorías de fallo adicionales más allá de los 7 documentados arriba:

- ~25 paquetes ausentes de los repos de Ubuntu (`ghidra`, `powershell`, `burpsuite-community`, `edb-debugger`, `flare-floss`, etc.).
- Cascada de fallos por habilitación de arquitectura i386 afectando a `wine`/`winehq-stable`/`js` (spidermonkey).
- Huecos de módulos de Salt en 3008.2 (`gem.installed`, `gem.removed`, `alternatives.install` no disponibles).
- Fallos npm sin mensaje explícito (probablemente `npm` ausente o fallo silencioso del módulo `npm.installed`): `box-js`, `js-deobfuscator`, `JStillery`, `webcrack`, `playwright`, `opencode-ai`, `@remnux/mcp-server`.
- Fallos en cascada de `file.managed`/`archive.extracted` derivados de estados previos fallidos (ej. `ghidra-data-type.zip`).

## Exclude-list validada (45 rutas activas + 1 pendiente sin excluir)

`remnux/exclude-list.txt` recoge las rutas `.sls` (en dotted-path, listas para `exclude=[...]` de Salt) que, aplicadas sobre `state.apply remnux.addon`, dejan la instalación en **0 `Failed`** en la corrida limpia sobre VM. Verificación posterior confirmó que los 7 binarios rotos conocidos (`cutter`, `redress`, `yr`, `docker-compose`, `die`, `diec`, `inspircd`) **no** quedan instalados tras aplicar la exclusión.

Desglose por categoría (recuento real del fichero):

- **2 RUIDOSO** (`.deb` amd64 con deps `:amd64` no instalables): `packages.inspircd`, `tools.detect-it-easy` (este último con 10 deps Qt5 `:amd64` sin resolver).
- **4 SILENCIOSO** (binario ELF x86-64 suelto, `Exec format error` en runtime): `tools.docker-compose`, `tools.cutter`, `tools.redress`, `tools.yara-x` (pie).
- **2 PIP-TAG / CASCADA** (wheel `manylinux_x86_64` de `stpyv8` rechazado por pip, invocado desde estos dos `.sls`): `python3-packages.peepdf-3`, `python3-packages.thug`. `stpyv8` no es un `.sls` aplicable en sí mismo, solo define un macro Jinja; al excluir estos dos enteros se pierde también el resto de paquetes que cada uno instala — alternativa: no excluirlos y aceptar esos 2 `Failed` puntuales si se quiere conservar el resto de cada paquete.
- **4 BUILD** (fallo compilando desde fuente; **no confirmado como límite duro de arm64**, podrían arreglarse actualizando herramientas de build):
  - `python3-packages.peframe`: falla compilando la extensión `readline` — `config.guess` desactualizado, no reconoce `aarch64`.
  - `python3-packages.qiling`: falla compilando `keystone-engine` — `cmake` no encontrado.
  - `python3-packages.pe-tree`: conflicto de dependencias PyQt5 (sin wheel arm64 disponible en el pin usado).
  - `python3-packages.vivisect`: PyQt5 5.15.7 falla al generar metadata (falta `qmake`/build system).
- **3 SALT-MOD** (módulo de estado no disponible en Salt 3008.2, `gem.installed`/`gem.removed`): `rubygems.origamindee`, `rubygems.pdnstool`, `rubygems.pedump`.
- **25 NO-PKG** (paquete ausente de los repos de Ubuntu para esta versión/arch): `libemu`, `baksmali`, `aeskeyfind`, `7zip`, `edb-debugger`, `xorstrings`, `bearparser`, `manalyze`, `signsrch`, `pycdc`, `powershell`, `portex`, `msoffice-crypt`, `flare-floss`, `binee`, `xorsearch`, `android-project-creator`, `sandfly-processdecloak`, `ilspy`, `ghidra`, `scdbg`, `evilclippy`, `rar`, `burpsuite-community`, `jd-gui`, `playwright`.
- **5 NPM** (fallo sin mensaje de error explícito capturado, probable ausencia de `npm` o fallo silencioso del módulo `npm.installed`): `node-packages.box-js`, `node-packages.js-deobfuscator`, `node-packages.jstillery`, `node-packages.webcrack`, `node-packages.opencode`.

**`remnux.packages.nodejs`** se deja **deliberadamente fuera** de la exclusión (comentado en el fichero): falló en la corrida completa sin causa confirmada, y excluirlo a ciegas podría arrastrar todo lo que depende de `nodejs` (todo `node-packages`). Queda pendiente investigar la causa real antes de decidir.

`remnux.packages.nodejs` **deliberadamente no excluido** — falló en la corrida completa sin mensaje de error capturado; pendiente de investigar antes de decidir si se excluye.

## Pruebas de herramientas amd64 sobre arm64 (investigación externa, contrastar solo pasos con salida real de terminal)

- **FEX-Emu + Wine nativo**: DESCARTADO — fallo estructural. FEX-Emu en sí funciona (`FEX /bin/uname -m` → `x86_64`), pero instalar Wine dentro del RootFS de FEX sobre el disco externo provoca fallos en cascada de dpkg (`unable to create /usr/lib/x86_64-linux-gnu/...`) — aparente incompatibilidad entre el overlay del RootFS de FEX y el filesystem del disco externo.
- **Docker con emulación multiarch**: CONFIRMADO funcionando para herramientas de terminal. Clave: `multiarch/qemu-user-static` está obsoleto y su script de registro es solo amd64; usar `tonistiigi/binfmt` (`docker run --rm --privileged tonistiigi/binfmt --install all`). Confirmado: `sudo docker run --platform linux/amd64 -it --rm -v $(pwd):/home/nonroot/workdir remnux/radare2` levanta una sesión real de radare2 con desensamblado correcto.
- **Contenedores GUI (Cutter, Ghidra)**: SIN RESOLVER — REMnux no publica estas como imágenes Docker independientes, son subcomandos de `remnux/remnux-distro`. Todos los intentos con X11 forwarding siguen dando `Exec format error` en `/usr/local/bin/cutter`. Ejecutar el AppImage de Cutter vía FEX-Emu es especulativo y sin probar.

## Pendiente

Clasificación fina de los ~120 fallos totales (arm64-específico vs. problema general de repo/versión de Salt), investigación de `remnux.packages.nodejs`, enfoque híbrido Cast/Docker para las herramientas GUI amd64-only que no se puedan arreglar a nivel de Salt states.
