# Changelog

Free-form format, reverse chronological order (most recent on top). This project uses `0.x` versioning during the validation phase; it doesn't follow strict SemVer.

## v0.2

- **REMnux — install flow empirically validated on a VM**, not just designed: `install.sh` (full `remnux.addon`, no exclusions) → `cleanup.sh` (removes broken binaries) → `verify.sh` (confirms the result and installs alternatives).
- **Abandoned Salt's `exclude=` mechanism** for REMnux: excluding `.sls` files breaks high-state compilation when other states have a `require:` pointing at the excluded one (confirmed with a real log). `exclude-list.txt` becomes reference documentation, not a functional argument.
- **Confirmed native arm64 alternatives** for 4 of the 6 broken REMnux binaries:
  - `docker-compose` → `docker-compose-plugin` (already ships as a `docker-ce` dependency, only needs a symlink).
  - `redress` → compiled with `golang-go` (apt) + `go install`.
  - `yr` (yara-x) → compiled with `rustup` (apt's `cargo`, 1.75.0, is too old for `yara-x-cli`, which requires ≥1.93).
  - `die`/`diec` → official Flatpak (Flathub, `io.github.horsicq.detect-it-easy`, `aarch64` supported).
  - `cutter` still has no confirmed native alternative (RizinOrg's OBS repo tried on both `xUbuntu_22.04` and `xUbuntu_24.04`, each failing for a different reason).
  - `inspircd` deliberately left out of the automatic flow (Ubuntu arm64 only has v3.17.0 vs. the required v4.7.0 — a downgrade, not a clean substitute).
- **Real bug found and fixed**: the string `x86-64` appears twice in `file`'s output for dynamically-linked binaries (architecture field + `interpreter /lib64/ld-linux-x86-64.so.2`), which broke the exact-string-comparison detection in `cleanup.sh`/`verify.sh`. Fixed with a boolean `grep -q` check.
- `verify.sh` fixed so it no longer flags the alternatives' own scripts/symlinks as suspicious (it used to treat them as "architecture undetermined").
- SIFT: confirmed 100% working on a VM, no changes needed.
- Terminology: replaced "corrida" with "ejecución" throughout the Spanish-language docs.

## v0.1

- First version of the repository. Initial status of the three distros:
  - **SIFT**: validated — the 3 community-documented architecture fixes are already merged upstream; pending risk in the GIFT/libyal family not empirically confirmed yet.
  - **REMnux**: ~88% validated (889/1009 states) via a full `state.apply remnux.addon`. Three failure patterns catalogued (loud/silent/explicit). Initial 45-active-path `exclude-list.txt` built as a clean-install attempt (mechanism abandoned in v0.2, see above).
  - **CAINE**: not started, only a roadmap for how to approach it (no package-conversion mechanism of its own, likely needs tool-by-tool cataloging).
- `LICENSE` with the full GPLv3 text.
