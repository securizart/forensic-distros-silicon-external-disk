# REMnux on arm64 — Findings

🇪🇸 [Versión en español](FINDINGS.md)

See also: [`DEPENDENCIES.en.md`](DEPENDENCIES.en.md) (system dependencies, Cast, Salt), [`CAST-INSTALL.en.md`](CAST-INSTALL.en.md) (concrete Cast install steps), [`install.sh`](install.sh) + [`exclude-list.txt`](exclude-list.txt) (reproducible install), [`verify.sh`](verify.sh) (post-install verification).

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

## Validated exclude-list (46 paths)

A 46-path `.sls` exclude-list was built which, applied on `state.apply remnux.addon` (`salt-call --local state.apply remnux.addon exclude=<46 paths>`), leaves the install at **0 `Failed`** on a clean VM run. Subsequent verification confirmed the 7 known-broken binaries (`cutter`, `redress`, `yr`, `docker-compose`, `die`, `diec`, `inspircd`) are **not** installed after applying the exclusion.

Exclude-list breakdown by category:

- **2 loud**: `inspircd`, `detect-it-easy`
- **4 silent**: `docker-compose`, `cutter`, `redress`, `yara-x`
- **2 pip-tag**: `peepdf-3`, `thug` (both via the `install_stpyv8` macro)
- **4 build-related, not confirmed as a hard arm64 limit**: `peframe`, `qiling`, `pe-tree`, `vivisect`
- **3 Salt-module related** (rubygems, `gem.installed` unavailable in Salt 3008.2): `origamindee`, `pdnstool`, `pedump`
- **~25 NO-PKG**: packages absent from Ubuntu's repos (not confirmed as an architecture issue)
- **5 unclassified npm**

`remnux.packages.nodejs` **deliberately not excluded** — it failed on the full run with no captured error message; pending investigation before deciding whether to exclude it.

## amd64-tool execution on arm64 (external research, only trust steps with real terminal output)

- **FEX-Emu + native Wine**: DISCARDED — structural failure. FEX-Emu itself works (`FEX /bin/uname -m` → `x86_64`), but installing Wine inside the FEX RootFS on the external disk causes dpkg cascade failures (`unable to create /usr/lib/x86_64-linux-gnu/...`) — an apparent incompatibility between FEX's RootFS overlay and the external disk's filesystem.
- **Docker with multiarch emulation**: CONFIRMED WORKING for terminal tools. Key point: `multiarch/qemu-user-static` is obsolete and its registration script is amd64-only; use `tonistiigi/binfmt` instead (`docker run --rm --privileged tonistiigi/binfmt --install all`). Confirmed: `sudo docker run --platform linux/amd64 -it --rm -v $(pwd):/home/nonroot/workdir remnux/radare2` runs a real radare2 session with correct disassembly output.
- **GUI containers (Cutter, Ghidra)**: UNRESOLVED — REMnux doesn't publish these as standalone Docker images; they're subcommands of `remnux/remnux-distro`. All attempts with X11 forwarding still give `Exec format error` on `/usr/local/bin/cutter`. Running the Cutter AppImage via FEX-Emu is speculative and untested.

## Pending

Fine-grained classification of the ~120 total failures (arm64-specific vs. general repo/Salt-version issue), investigation of `remnux.packages.nodejs`, and a hybrid Cast/Docker approach for the amd64-only GUI tools that can't be fixed at the Salt-states level.
