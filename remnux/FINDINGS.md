# REMnux en arm64 — Findings

🇬🇧 [English version](FINDINGS.en.md)

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

## Test-kit `remnux-arm64-testkit` (completado, entregado por separado)

Repo local con `README.md`, `FINDINGS.md`, `exclude-list.txt` (46 rutas), `install.sh`, `verify.sh`. Validado en VM limpia: `install.sh` corre `state.apply remnux.addon` excluyendo las 46 rutas → **0 `Failed`** en el log. `verify.sh` confirma que los 7 binarios rotos conocidos (`cutter`, `redress`, `yr`, `docker-compose`, `die`, `diec`, `inspircd`) **no** quedan instalados.

Desglose del exclude-list por categoría: 2 ruidosos, 4 silenciosos, 2 pip-tag (ambos vía macro stpyv8), 4 de build sin confirmar como límite duro de arm64 (`peframe`, `qiling`, `pe-tree`, `vivisect`), 3 de módulo Salt (rubygems: `origamindee`/`pdnstool`/`pedump`), ~25 NO-PKG, 5 npm sin clasificar.

`remnux.packages.nodejs` **deliberadamente no excluido** — falló en la corrida completa sin mensaje de error capturado; pendiente de investigar antes de decidir si se excluye.

## Pruebas de herramientas amd64 sobre arm64 (investigación externa, contrastar solo pasos con salida real de terminal)

- **FEX-Emu + Wine nativo**: DESCARTADO — fallo estructural. FEX-Emu en sí funciona (`FEX /bin/uname -m` → `x86_64`), pero instalar Wine dentro del RootFS de FEX sobre el disco externo provoca fallos en cascada de dpkg (`unable to create /usr/lib/x86_64-linux-gnu/...`) — aparente incompatibilidad entre el overlay del RootFS de FEX y el filesystem del disco externo.
- **Docker con emulación multiarch**: CONFIRMADO funcionando para herramientas de terminal. Clave: `multiarch/qemu-user-static` está obsoleto y su script de registro es solo amd64; usar `tonistiigi/binfmt` (`docker run --rm --privileged tonistiigi/binfmt --install all`). Confirmado: `sudo docker run --platform linux/amd64 -it --rm -v $(pwd):/home/nonroot/workdir remnux/radare2` levanta una sesión real de radare2 con desensamblado correcto.
- **Contenedores GUI (Cutter, Ghidra)**: SIN RESOLVER — REMnux no publica estas como imágenes Docker independientes, son subcomandos de `remnux/remnux-distro`. Todos los intentos con X11 forwarding siguen dando `Exec format error` en `/usr/local/bin/cutter`. Ejecutar el AppImage de Cutter vía FEX-Emu es especulativo y sin probar.

## Pendiente

Clasificación fina de los ~120 fallos totales (arm64-específico vs. problema general de repo/versión de Salt), investigación de `remnux.packages.nodejs`, enfoque híbrido Cast/Docker para las herramientas GUI amd64-only que no se puedan arreglar a nivel de Salt states.
