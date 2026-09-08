🇬🇧 [English version](README.en.md)

# Forensic Distros sobre Apple Silicon (Asahi Linux) — arm64 testkit

**Versión: 0.1**

Proyecto satélite del instalador principal [`offensive-installer-silicon-chip`](https://github.com/securizart/offensive-installer-silicon-chip) ("Offensive Installer Silicon Chip"). Mientras que ese proyecto automatiza la instalación de distribuciones **ofensivas** (Kali Linux, Parrot Security OS) sobre un MacBook con Apple Silicon usando disco externo + Debian/Asahi Linux en el disco interno como prerrequisito, este repositorio documenta y valida, de forma independiente, la instalación de distribuciones **forenses** sobre esa misma base arm64: **SIFT Workstation**, **REMnux** y **CAINE**.

El objetivo final es fusionar (merge) esta rama de trabajo con el instalador principal, añadiendo el "modo forense" como una opción más junto a Kali/Parrot.

## Por qué existe este repo aparte

Validar cada distro forense en arm64 requiere un ciclo de pruebas propio (VM, snapshots, exclude-lists, verificación binario a binario) antes de poder integrarlo con garantías en el instalador bare-metal. Este repo recoge ese trabajo de validación; una vez maduro, se fusiona con el proyecto principal.

## Estado por distro (v0.1)

### ✅ SIFT Workstation — validado
`cast install teamdfir/sift-saltstack` confirmado funcionando en VM arm64 (Ubuntu Desktop 24.04, misma base que usa el proyecto principal vía Asahi/Debian).

- Los 3 fixes de arquitectura arm64 documentados por la comunidad (`jonathanlooi/sift-on-arm`: `docker.sls`, `ubuntu-universe.sls`, `radare2.sls`) ya están **mergeados aguas arriba** en `teamdfir/sift-saltstack` (v2026.04.21).
- Barrido propio sobre los 316 `.sls` del repo: ~14 ficheros con lógica de arquitectura, todos ya resueltos correctamente (guards `onlyif: match.grain osarch:amd64` o rama arm64 propia).
- **Riesgo pendiente, no contrastado empíricamente todavía**: familia GIFT PPA/libyal (`libbde`, `libewf-tools`, `libfvde`, `libesedb`, `libevt(x)`, `libmsiecf`, `libolecf`, `libregf`, `libvshadow`, `libfsapfs-tools`, `libvmdk`, `python3-pytsk3`, `python3-dfvfs`, `plaso-tools`) — la PPA de GIFT solo publica `.deb` en amd64. También `bulk_extractor` y `rar` sin build arm64 conocido.

Detalle completo: [`sift/FINDINGS.md`](sift/FINDINGS.md)

### 🟡 REMnux — validado al ~88%
`state.apply` completo sobre `remnux.addon`: **889/1009 estados con éxito (88%)**, 120 fallos.

Tres patrones de fallo confirmados:
1. **Ruidoso** (dpkg/apt): `inspircd.sls`, `detect-it-easy.sls` — Salt marca `Failed`, dependencias `:amd64` no instalables.
2. **Silencioso** (binario/AppImage/tarball suelto sin dpkg): `docker-compose.sls`, `cutter.sls`, `redress.sls`, `yara-x.sls` — Salt marca `Succeeded` pero el binario da `Exec format error` al ejecutarlo.
3. **Explícito** (pip wheel tags): `stpyv8.sls` (vía `peepdf-3.sls`/`thug.sls`) — pip rechaza el wheel con `not a supported wheel on this platform`.

Se ha construido una exclude-list reproducible de 46 rutas que, aplicada sobre `remnux.addon`, deja la instalación en 0 `Failed` en la corrida limpia. Detalle completo de la lista y su desglose por categoría en [`remnux/FINDINGS.md`](remnux/FINDINGS.md).

Pendiente sin clasificar del todo: ~25 paquetes `NO-PKG` (ausentes de los repos de Ubuntu, no necesariamente problema de arquitectura) y 5 paquetes npm (`box-js`, `js-deobfuscator`, `jstillery`, `webcrack`, `opencode`) sin mensaje de error capturado.

Detalle completo: [`remnux/FINDINGS.md`](remnux/FINDINGS.md)

### ⏳ CAINE — no iniciado
Sin pruebas realizadas todavía sobre esta arquitectura. CAINE no tiene, hasta donde se ha investigado, un mecanismo de conversión/instalación de paquetes propio equivalente al de REMnux (Salt states) o SIFT (Salt states vía `cast`); es una distro Live/instalable completa, así que probablemente el camino viable sea **extraer y catalogar sus herramientas forenses** una a una, y evaluar cuáles se pueden portar o reempaquetar sobre Debian/Asahi en arm64.

Ver plan en [`caine/ROADMAP.md`](caine/ROADMAP.md).

## Roadmap

- **v0.2**: cerrar el desglose fino pendiente de REMnux (NO-PKG + npm) y arrancar la primera fase de CAINE — extracción del listado de herramientas y catalogación (cuáles son solo scripts/paquetes apt portables vs. binarios amd64-only vs. herramientas con build arm64 disponible).
- **v0.3+**: pruebas empíricas de la familia GIFT/libyal para SIFT.
- **vX**: fusión de esta rama de trabajo con [`offensive-installer-silicon-chip`](https://github.com/securizart/offensive-installer-silicon-chip) como modo de instalación adicional ("forense") junto a Kali y Parrot.

## Relación con el proyecto principal

Este repo asume el mismo prerrequisito que el instalador principal: una instalación Debian/Asahi Linux funcional en el disco interno del MacBook Apple Silicon. Las pruebas de este repo se han hecho sobre VM (UTM, Ubuntu Desktop 24.04 arm64) como entorno de validación rápida antes de llevar los hallazgos al hardware real ya provisto por el instalador principal.

## Licencia

GPLv3 (misma licencia que el proyecto principal), ver [`LICENSE`](LICENSE).
