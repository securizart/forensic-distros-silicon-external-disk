# REMnux on arm64 — Findings

🇪🇸 [Versión en español](FINDINGS.md)

See also: [`DEPENDENCIES.en.md`](DEPENDENCIES.en.md) (system dependencies, Cast, Salt), [`CAST-INSTALL.en.md`](CAST-INSTALL.en.md) (concrete Cast install steps), [`install.sh`](install.sh) (full `remnux.addon` install), [`cleanup.sh`](cleanup.sh) (post-install cleanup of amd64 binaries), [`verify.sh`](verify.sh) (final verification), [`exclude-list.txt`](exclude-list.txt) (reference documentation of known failures).

## Test environment

UTM VM, Ubuntu Desktop 24.04 arm64, user `iac`. Cast v1.0.4 (official `.deb` from `ekristen/cast`, works natively on Apple Silicon). `remnux/salt-states` cloned to `/home/iac/salt-states`. Salt 3008.2 installed via `packages.broadcom.com` in masterless mode (`file_client: local`, `file_roots → base: [/home/iac/salt-states]`). `grains osarch = arm64` confirmed. UTM snapshot before each `.sls` test.

## Risk-candidate identification

Out of 393 total `.sls` files:

- Most use plain `apt` (architecture-neutral, no risk).
- ~10 use the `remnux/osarch.sls` macro (arch-aware, resolve correctly on arm64: `radare2.sls`, `docker.sls`, `winehq.sls`, etc.).
- **7 had hardcoded amd64/x86_64 assets with no architecture branch**: `packages/inspircd.sls`, `python3-packages/stpyv8.sls`, `tools/cutter.sls`, `tools/detect-it-easy.sls`, `tools/docker-compose.sls`, `tools/redress.sls`, `tools/yara-x.sls`.

## Three confirmed failure patterns (7/7)

### 1. Loud (via dpkg/apt)
Salt marks `Failed`, a clear apt error about `:amd64` dependencies.

- `inspircd.sls`: hardcoded amd64 `.deb`; Ubuntu universe has an arm64 build but only v3.17.0 (two majors below the required v4.7.0) — **not a viable drop-in**.
- `detect-it-easy.sls`: hardcoded amd64 `.deb`; 10 unresolvable Qt5 `:amd64` dependencies without enabling a foreign architecture.

### 2. Silent (via loose binary/AppImage/tarball)
Salt reports `Result: True / Succeeded`, but the binary is ELF x86-64 and throws `Exec format error` at runtime. **The most dangerous one**, since there's no check at install time.

- `docker-compose.sls`, `cutter.sls`, `redress.sls`, `yara-x.sls`.
- Note: `redress.sls` also triggers a full `radare2.sls` install, which completes correctly on arm64 including the `r2ai`/`decai` plugins via `r2pm -ci` — confirming the arch-aware macro pattern works.

### 3. Explicit (via pip wheel tags)
pip validates platform tags before installing and rejects with a clear message.

- `stpyv8.sls`: `manylinux_2_31_x86_64` wheel; tested indirectly via `peepdf-3.sls`/`thug.sls`, which invoke the `install_stpyv8` macro.
- Separate, non-architecture bug: `STPyV8` on PyPI fails to build from sdist due to `ModuleNotFoundError: No module named settings` in its `setup.py`.

## Full run (`remnux.addon`, no exclusions)

~88% installs correctly: **889/1009 states succeeded, 120 failures** (~20 min).

Additional failure categories beyond the 7 documented above:

- ~25 packages absent from Ubuntu's repos entirely (`ghidra`, `powershell`, `burpsuite-community`, `edb-debugger`, `flare-floss`, etc.).
- i386 architecture-enablement cascade failures affecting `wine`/`winehq-stable`/`js` (spidermonkey).
- Salt module gaps in 3008.2 (`gem.installed`, `gem.removed`, `alternatives.install` unavailable).
- npm failures with no explicit error (likely missing `npm` or a silent `npm.installed` module failure): `box-js`, `js-deobfuscator`, `JStillery`, `webcrack`, `playwright`, `opencode-ai`, `@remnux/mcp-server`.
- Cascade `file.managed`/`archive.extracted` failures from earlier failed states (e.g. `ghidra-data-type.zip`).

## Exclude-list: why it was abandoned as an install mechanism

**Important finding**: applying `state.apply remnux.addon` with `exclude=[...]` (using the exclude-list below) **doesn't work** — it fails during the *high-state* compile phase, before touching a single package, with errors like:

```
Data failed to compile:
    Referenced state does not exist for requisite [require: (sls: remnux.tools.docker-compose)] in state [docker-ce] in SLS [remnux.packages.docker]
    Referenced state does not exist for requisite [require: (sls: remnux.packages.ghidra)] in state [/usr/local/src/remnux/files/ghidra-data-type.zip] in SLS [remnux.config.ghidra]
    ... (19 errors of this kind, confirmed on a real run)
```

When a `.sls` is excluded with `exclude=`, Salt removes it entirely from the state tree — but other `.sls` files with a `require: sls: <the excluded one>` still point at it, and Salt's masterless compiler (3008.2) validates those references at compile time and aborts if the target no longer exists. This happens even for states with no apparent architecture connection: `docker-ce` requires `remnux.tools.docker-compose` (excluded as SILENT), `remnux.config.ghidra` requires `remnux.packages.ghidra` (excluded as NO-PKG), etc. The result is that **nothing gets installed at all**, not even packages with no architecture issue whatsoever, like radare2.

**Current approach (`install.sh` / `cleanup.sh` / `verify.sh`)**: instead of excluding `.sls` files, `remnux.addon` is run in full (accepting the ~120 `Failed` states documented below) and cleaned up afterwards with `cleanup.sh`, which finds and removes the SILENT binaries (x86-64 ELF) that Salt marks as successfully installed but are useless on arm64. LOUD `.sls` files (`inspircd`, `detect-it-easy`) don't leave a half-installed binary because apt/dpkg aborts the whole transaction over unresolvable `:amd64` dependencies — `cleanup.sh` only checks that `apt` wasn't left in a "held broken packages" state after those attempts.

`exclude-list.txt` is kept as **reference documentation** (categorization of the ~46 known failure points), not as a functional input to `install.sh`.

## Known exclude-list (documentation, no longer used as `exclude=`)

`remnux/exclude-list.txt` holds the `.sls` paths (dotted-path, ready for Salt's `exclude=[...]`) which, applied on `state.apply remnux.addon`, leave the install at **0 `Failed`** on a clean VM run. Subsequent verification confirmed the 7 known-broken binaries (`cutter`, `redress`, `yr`, `docker-compose`, `die`, `diec`, `inspircd`) are **not** installed after applying the exclusion.

Breakdown by category (actual count from the file):

- **2 LOUD** (amd64 `.deb` with unresolvable `:amd64` deps): `packages.inspircd`, `tools.detect-it-easy` (the latter with 10 unresolvable Qt5 `:amd64` deps).
- **4 SILENT** (loose ELF x86-64 binary, `Exec format error` at runtime): `tools.docker-compose`, `tools.cutter`, `tools.redress`, `tools.yara-x` (pie).
- **2 PIP-TAG / CASCADE** (`stpyv8`'s `manylinux_x86_64` wheel rejected by pip, invoked from these two `.sls`): `python3-packages.peepdf-3`, `python3-packages.thug`. `stpyv8` isn't an applicable `.sls` on its own, it only defines a Jinja macro; excluding these two whole files also drops the rest of the packages each one installs — alternative: don't exclude them and accept those 2 point `Failed` states if you want to keep the rest of each package.
- **4 BUILD** (fails compiling from source; **not confirmed as a hard arm64 limit**, could potentially be fixed by updating build tools):
  - `python3-packages.peframe`: fails compiling the `readline` extension — outdated `config.guess`, doesn't recognize `aarch64`.
  - `python3-packages.qiling`: fails compiling `keystone-engine` — `cmake` not found.
  - `python3-packages.pe-tree`: PyQt5 dependency conflict (no arm64 wheel available at the pinned version).
  - `python3-packages.vivisect`: PyQt5 5.15.7 fails generating metadata (missing `qmake`/build system).
- **3 SALT-MOD** (state module unavailable in Salt 3008.2, `gem.installed`/`gem.removed`): `rubygems.origamindee`, `rubygems.pdnstool`, `rubygems.pedump`.
- **25 NO-PKG** (package absent from Ubuntu's repos for this version/arch): `libemu`, `baksmali`, `aeskeyfind`, `7zip`, `edb-debugger`, `xorstrings`, `bearparser`, `manalyze`, `signsrch`, `pycdc`, `powershell`, `portex`, `msoffice-crypt`, `flare-floss`, `binee`, `xorsearch`, `android-project-creator`, `sandfly-processdecloak`, `ilspy`, `ghidra`, `scdbg`, `evilclippy`, `rar`, `burpsuite-community`, `jd-gui`, `playwright`.
- **5 NPM** (fails with no explicit error captured, likely missing `npm` or a silent `npm.installed` module failure): `node-packages.box-js`, `node-packages.js-deobfuscator`, `node-packages.jstillery`, `node-packages.webcrack`, `node-packages.opencode`.

**`remnux.packages.nodejs`** is **deliberately left out** of the exclusion (commented out in the file): it failed on the full run with no confirmed cause, and excluding it blindly could drag down everything that depends on `nodejs` (all of `node-packages`). Investigating the real cause is still pending.

`remnux.packages.nodejs` **deliberately not excluded** — it failed on the full run with no captured error message; pending investigation before deciding whether to exclude it.

## amd64-tool execution on arm64 (external research, only trust steps with real terminal output)

- **FEX-Emu + native Wine**: DISCARDED — structural failure. FEX-Emu itself works (`FEX /bin/uname -m` → `x86_64`), but installing Wine inside the FEX RootFS on the external disk causes dpkg cascade failures (`unable to create /usr/lib/x86_64-linux-gnu/...`) — an apparent incompatibility between FEX's RootFS overlay and the external disk's filesystem.
- **Docker with multiarch emulation**: CONFIRMED WORKING for terminal tools. Key point: `multiarch/qemu-user-static` is obsolete and its registration script is amd64-only; use `tonistiigi/binfmt` instead (`docker run --rm --privileged tonistiigi/binfmt --install all`). Confirmed: `sudo docker run --platform linux/amd64 -it --rm -v $(pwd):/home/nonroot/workdir remnux/radare2` runs a real radare2 session with correct disassembly output.
- **GUI containers (Cutter, Ghidra)**: UNRESOLVED — REMnux doesn't publish these as standalone Docker images; they're subcommands of `remnux/remnux-distro`. All attempts with X11 forwarding still give `Exec format error` on `/usr/local/bin/cutter`. Running the Cutter AppImage via FEX-Emu is speculative and untested.

## Pending

Fine-grained classification of the ~120 total failures (arm64-specific vs. general repo/Salt-version issue), investigation of `remnux.packages.nodejs`, and a hybrid Cast/Docker approach for the amd64-only GUI tools that can't be fixed at the Salt-states level.
