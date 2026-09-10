# NO-PKG en arm64: causa raíz y alternativas nativas

Este documento complementa `FINDINGS.md` del test-kit. Cubre la categoría de
paquetes que `remnux.addon` no puede instalar en arm64 porque su origen
(`ppa:remnux/stable`) simplemente no los compila para esa arquitectura — es
decir, el software en sí no es el problema, es el *packaging* de REMnux.

## Causa raíz única

Consultando `dists/noble/Release` del PPA de REMnux
(`https://ppa.launchpadcontent.net/remnux/stable/ubuntu/`), el índice
`main/binary-arm64/Packages` (y también `armhf`/`i386`/`ppc64el`/`riscv64`/`s390x`)
tiene el mismo hash y tamaño diminuto (548 bytes) frente a `binary-amd64/Packages`
(19774 bytes). Descomprimiendo el de arm64 solo aparece **un** paquete:
`dex2jar` (`Architecture: all`, JAR puro). Conclusión: **el PPA de REMnux nunca
ha compilado nada específico de arquitectura salvo amd64** — no es una carencia
individual de cada herramienta, es sistémico del PPA.

(Para contraste: el PPA propio de SIFT, `ppa:sift/stable`, tiene su índice
arm64 completamente **vacío** — 0 bytes. SIFT evita el problema con guards
`onlyif: match.grain osarch:amd64` que omiten limpiamente esas herramientas
en vez de intentar instalarlas y fallar.)

## Resultado de la investigación práctica (probado en VM real, no solo en teoría)

### Resueltos sin matices — funcionan al 100% en arm64

| Herramienta | Fuente de la alternativa | Notas |
|---|---|---|
| `powershell` | `.deb` oficial arm64 de Microsoft | — |
| `7zz` | Binario oficial arm64 de 7-zip.org | — |
| `unrar` | Compilado desde fuente oficial (rarlab.com) | Solo extracción |
| `aeskeyfind` | Compilado desde `mbroz/aeskeyfind` | — |
| `xorsearch` | `xorsearch.py` de `DidierStevens/DidierStevensSuite` | Python, agnóstico de arch |
| `jd-gui` | Jar oficial `java-decompiler/jd-gui` v1.6.6 | Requiere JDK |
| `baksmali` | Fat jar de `baksmali/smali` releases | Requiere JDK |
| `burpsuite-community` | Instalador oficial PortSwigger, build "Linux (ARM)" | Requiere descarga manual (licencia) |
| `binee` | Compilado con Go (`carbonblack/binee`) | Depende de `libunicorn-dev` |
| `manalyze` | Compilado con CMake (`JusticeRage/Manalyze`) | Depende de boost/openssl |
| `bearparser` | Compilado con CMake (`hasherezade/bearparser`) | Depende de Qt5 |
| `pycdc`/`pycdas` | Compilado con CMake (`zrax/pycdc`) | Sin dependencias externas |
| `msoffice-crypt` | Compilado con make (`herumi/msoffice`) | Binario se llama `.exe` aunque sea nativo Linux |
| `portex` | Jar precompilado `PortexAnalyzer.jar` (`struppigel/PortEx`) | Requiere JDK |
| `signsrch` | Compilado con make (mirror `sandsmark/signsrch`) | Requiere `signsrch.sig` aparte para uso real |

### Resuelto con matiz

- **`ghidra`**: el release oficial multiplataforma arranca y funciona en arm64
  (GUI, desensamblador, navegación, scripting) pero el **decompilador nativo
  en C++ no tiene build `linux_arm_64` oficial**, y compilarlo localmente
  choca con un bug conocido y sin resolver del propio proyecto Ghidra
  (issues `#7958`/`#5204`). Además, el script `support/buildNatives` ya no
  se incluye en los releases recientes (issue `#7881`). Sin solución práctica
  a corto plazo — Ghidra queda utilizable salvo por el decompilador.

### Categoría A confirmada (sin build arm64 en ningún sitio)

- **`rar`** (el archivador propietario para *crear* `.rar`, no confundir con
  `unrar`): RARLAB no publica ningún binario arm64 Linux. Única vía es
  emulación x86_64 (QEMU o FEX), sin alternativa nativa.

### Sin resolver / pendientes (no investigado a fondo todavía)

`xorstrings` (aparcado — el mirror con fuente Python/C no está disponible,
la fusión con `-S` de XORSearch descrita por Didier Stevens no aplica a este
mirror concreto), `android-project-creator`, `edb-debugger` (soporte arm64
upstream inmaduro, issue abierto `eteran/edb-debugger#855`), `scdbg`,
`sandfly-processdecloak`, `ilspycmd`, `evilclippy`, `flare-floss` (estos
tres últimos con alta probabilidad teórica de funcionar sin parches por ser
Java/.NET/Python puros, pero sin verificación práctica).

## Uso del script

Ver `install-extra-tools.sh` en este mismo directorio. Ejecutar **después**
de `install.sh` + `cleanup.sh` + `verify.sh` del test-kit (es decir, sobre
una base ya validada):

```bash
sudo ./install-extra-tools.sh --all              # las 14 sin matices
sudo ./install-extra-tools.sh --ghidra            # con el matiz del decompilador
./install-extra-tools.sh --burpsuite-guide        # pasos manuales (licencia)
```

O instalar una sola herramienta con `--<nombre>` (ver `--help` del script).
