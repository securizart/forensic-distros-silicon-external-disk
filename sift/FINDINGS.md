# SIFT Workstation en arm64 — Findings

🇬🇧 [English version](FINDINGS.en.md)

## Resultado

`sudo cast install teamdfir/sift-saltstack` **confirmado correcto** por el usuario en VM UTM clonada de la de REMnux (Ubuntu Desktop 24.04 arm64, Salt 3008.2 masterless, mismo setup que en `remnux/FINDINGS.md`).

## Investigación previa

El repo comunitario `jonathanlooi/sift-on-arm` documentaba 3 fixes necesarios para que SIFT funcionara en arm64:

1. `docker.sls` — tenía `Architectures` hardcodeado sin variable, provocaba error de parseo YAML.
2. `ubuntu-universe.sls` — sin rama `ports.ubuntu.com` para arm64.
3. `radare2.sls` — `.deb` amd64 hardcodeado.

## Verificación contra el repo real

Se clonó `teamdfir/sift-saltstack` (versión `v2026.04.21`) y se confirmó que **los 3 fixes ya están mergeados aguas arriba**. No hace falta aplicar ningún parche manual.

## Barrido propio de arquitectura

Sobre los 316 `.sls` totales del repo:

- **~14 ficheros mencionan arquitectura**, todos ya bien resueltos:
  - Con guard limpio (`onlyif: match.grain osarch:amd64`, se saltan sin error en arm64): `aeskeyfind.sls`, `aircrack-ng.sls`, `cmospwd.sls`, `liblightgrep.sls`, `powershell.sls`, `xmount.sls`.
  - Con rama arm64 propia: `aws-cli.sls`, `claude-code.sls`, `docker.sls`, `radare2.sls`, `ubuntu-universe.sls`, `ubuntu-multiverse.sls`.

## Riesgo pendiente — NO detectable por grep

Documentado por la comunidad, **pendiente de contrastar empíricamente**:

- Toda la familia **GIFT PPA/libyal**: `libbde`, `libewf-tools`, `libfvde`, `libesedb`, `libevt(x)`, `libmsiecf`, `libolecf`, `libregf`, `libvshadow`, `libfsapfs-tools`, `libvmdk`, `python3-pytsk3`, `python3-dfvfs`, `plaso-tools`.
  - La PPA de GIFT solo publica `.deb` en amd64. Los `.sls` en sí **no** hardcodean arquitectura (por eso no aparecen al hacer `grep amd64|x86_64`), pero el paquete que intentan instalar solo existe para amd64 en esa PPA.
- `bulk_extractor` y `rar`: sin build arm64 conocido en ningún repo.

## Próximo paso

Crear un repositorio en GitHub específico para documentar esta instalación (pendiente, se decidió continuar en otro chat del proyecto), y contrastar empíricamente el riesgo GIFT/libyal — probablemente reproduciendo el mismo patrón de pruebas one-by-one usado con REMnux (snapshot antes de cada paquete, `salt-call --local state.apply <ruta> test=True` primero, luego real).
