# SIFT Workstation on arm64 — Findings

🇪🇸 [Versión en español](FINDINGS.md)

## Result

`sudo cast install teamdfir/sift-saltstack` **confirmed working** by the user on a UTM VM cloned from the REMnux one (Ubuntu Desktop 24.04 arm64, Salt 3008.2 masterless, same setup as in `remnux/FINDINGS.md`).

## Prior research

The community repo `jonathanlooi/sift-on-arm` documented 3 fixes needed for SIFT to work on arm64:

1. `docker.sls` — had `Architectures` hardcoded without a variable, causing a YAML parsing error.
2. `ubuntu-universe.sls` — no `ports.ubuntu.com` branch for arm64.
3. `radare2.sls` — hardcoded amd64 `.deb`.

## Verification against the real repo

`teamdfir/sift-saltstack` (version `v2026.04.21`) was cloned and it was confirmed that **all 3 fixes are already merged upstream**. No manual patching needed.

## Own architecture sweep

Across the 316 total `.sls` files in the repo:

- **~14 files mention architecture**, all already well handled:
  - With a clean guard (`onlyif: match.grain osarch:amd64`, skipped without error on arm64): `aeskeyfind.sls`, `aircrack-ng.sls`, `cmospwd.sls`, `liblightgrep.sls`, `powershell.sls`, `xmount.sls`.
  - With their own arm64 branch: `aws-cli.sls`, `claude-code.sls`, `docker.sls`, `radare2.sls`, `ubuntu-universe.sls`, `ubuntu-multiverse.sls`.

## Pending risk — NOT detectable by grep

Documented by the community, **still pending empirical confirmation**:

- The whole **GIFT PPA/libyal** family: `libbde`, `libewf-tools`, `libfvde`, `libesedb`, `libevt(x)`, `libmsiecf`, `libolecf`, `libregf`, `libvshadow`, `libfsapfs-tools`, `libvmdk`, `python3-pytsk3`, `python3-dfvfs`, `plaso-tools`.
  - The GIFT PPA only publishes `.deb`s for amd64. The `.sls` files themselves do **not** hardcode architecture (which is why they don't show up when grepping for amd64/x86_64), but the package they try to install only exists for amd64 in that PPA.
- `bulk_extractor` and `rar`: no known arm64 build in any repo.

## Next step

Create a dedicated GitHub repo to document this install (pending, decided to continue in another project chat), and empirically confirm the GIFT/libyal risk — likely reproducing the same one-by-one test pattern used with REMnux (snapshot before each package, `salt-call --local state.apply <path> test=True` first, then the real run).
