🇪🇸 [Versión en español](README.md)

# Forensic Distros on Apple Silicon (Asahi Linux) — arm64 testkit

**Version: 0.1**

Satellite project of the main installer [`offensive-installer-silicon-chip`](https://github.com/securizart/offensive-installer-silicon-chip) ("Offensive Installer Silicon Chip"). While that project automates the installation of **offensive** distros (Kali Linux, Parrot Security OS) on an Apple Silicon MacBook using an external disk plus a Debian/Asahi Linux install on the internal disk as a prerequisite, this repository documents and validates, independently, the installation of **forensic** distros on that same arm64 base: **SIFT Workstation**, **REMnux** and **CAINE**.

The end goal is to merge this line of work into the main installer, adding a "forensics mode" as an extra option alongside Kali/Parrot.

## Why a separate repo

Validating each forensic distro on arm64 needs its own test cycle (VM, snapshots, exclude-lists, binary-by-binary verification) before it can be reliably integrated into the bare-metal installer. This repo collects that validation work; once mature, it gets merged into the main project.

## Status per distro (v0.1)

### ✅ SIFT Workstation — validated
`cast install teamdfir/sift-saltstack` confirmed working on an arm64 VM (Ubuntu Desktop 24.04, the same base the main project uses via Asahi/Debian).

- The 3 arm64 architecture fixes documented by the community (`jonathanlooi/sift-on-arm`: `docker.sls`, `ubuntu-universe.sls`, `radare2.sls`) are already **merged upstream** in `teamdfir/sift-saltstack` (v2026.04.21).
- Own sweep across the 316 `.sls` files: ~14 files with architecture logic, all already handled correctly (either an `onlyif: match.grain osarch:amd64` guard, or their own arm64 branch).
- **Pending risk, not empirically checked yet**: the GIFT PPA/libyal family (`libbde`, `libewf-tools`, `libfvde`, `libesedb`, `libevt(x)`, `libmsiecf`, `libolecf`, `libregf`, `libvshadow`, `libfsapfs-tools`, `libvmdk`, `python3-pytsk3`, `python3-dfvfs`, `plaso-tools`) — the GIFT PPA only publishes amd64 `.deb`s. Also `bulk_extractor` and `rar` with no known arm64 build.

Full detail: [`sift/FINDINGS.md`](sift/FINDINGS.md)

### 🟡 REMnux — ~88% validated, with native alternatives for 4/6 broken binaries
Full `state.apply` on `remnux.addon`: **889/1009 states succeeded (88%)**, 120 failures.

Three confirmed failure patterns:
1. **Noisy** (dpkg/apt): `inspircd.sls`, `detect-it-easy.sls` — Salt marks `Failed`, unresolvable `:amd64` dependencies.
2. **Silent** (loose binary/AppImage/tarball, no dpkg involved): `docker-compose.sls`, `cutter.sls`, `redress.sls`, `yara-x.sls` — Salt reports `Succeeded` but the binary throws `Exec format error` when run.
3. **Explicit** (pip wheel tags): `stpyv8.sls` (via `peepdf-3.sls`/`thug.sls`) — pip rejects the wheel with `not a supported wheel on this platform`.

Install flow **empirically validated on a VM**: `install.sh` (full `remnux.addon` run, no exclusions) → `cleanup.sh` (removes the SILENT binaries) → `verify.sh` (confirms the result and, with no flags needed, automatically installs the confirmed native arm64 alternatives for `docker-compose`, `redress`, `yr` and `die`). `cutter` still has no confirmed native alternative; `inspircd` only installs behind an explicit flag, since it's a version downgrade, not a clean substitute.

Still not fully triaged: ~25 `NO-PKG` packages (missing from Ubuntu's repos, not necessarily an architecture issue) and 5 npm packages (`box-js`, `js-deobfuscator`, `jstillery`, `webcrack`, `opencode`) with no captured error message.

Full detail: [`remnux/FINDINGS.md`](remnux/FINDINGS.md)

### ⏳ CAINE — not started
No testing has been done yet on this architecture. As far as investigated, CAINE doesn't have a package installation/conversion mechanism of its own equivalent to REMnux's (Salt states) or SIFT's (Salt states via `cast`); it's a full Live/installable distro, so the likely viable path is to **extract and catalog its forensic tools** one by one, and assess which can be ported or repackaged on Debian/Asahi arm64.

See the plan in [`caine/ROADMAP.md`](caine/ROADMAP.md).

## Roadmap

- **v0.2**: finish the fine-grained triage still pending for REMnux (NO-PKG + npm) and start the first phase of CAINE — extracting the tool list and cataloging it (which are plain portable apt packages/scripts vs. amd64-only binaries vs. tools with an available arm64 build).
- **v0.3+**: empirical testing of the GIFT/libyal family for SIFT.
- **vX**: merge this line of work into [`offensive-installer-silicon-chip`](https://github.com/securizart/offensive-installer-silicon-chip) as an additional install mode ("forensics") alongside Kali and Parrot.

## Relation to the main project

This repo assumes the same prerequisite as the main installer: a working Debian/Asahi Linux install on the internal disk of the Apple Silicon MacBook. Testing here has been done on a VM (UTM, Ubuntu Desktop 24.04 arm64) as a fast validation environment before taking the findings to the real hardware already provisioned by the main installer.

## License

GPLv3 (same license as the main project), see [`LICENSE`](LICENSE).
