# CAINE on arm64 — Roadmap (v0.3)

## Current status

No testing done yet. Unlike REMnux (Salt states via `remnux/salt-states`) and SIFT (Salt states via `teamdfir/sift-saltstack`, installed with `cast`), **CAINE has no known package-conversion mechanism of its own**: it's a Live/installable distro meant to boot from ISO/USB with its own preinstalled toolset, not an "addon" applied on top of an existing Debian base.

This means the approach used with REMnux and SIFT (clone the states repo, apply on top of Debian/Asahi, exclude what fails) likely **doesn't apply directly** to CAINE.

## Plan for v0.2

1. **Inventory CAINE's tools.** Extract the full list of packages/tools shipped in the official ISO (via `dpkg -l` on a reference install, or by reviewing its repo/build scripts if public).
2. **Classify each tool** as:
   - Standard Debian/Ubuntu apt package → likely portable with no changes.
   - CAINE's own script/tool (Python/Bash) → portable after checking dependencies.
   - Binary compiled only for amd64 with no known arm64 build → candidate to drop or replace.
3. **Prioritize** "core" forensic tools (disk-image acquisition, filesystem analysis, timelining) over secondary utilities, using the same risk criteria as REMnux (loud/silent/explicit).
4. **Test on the arm64 VM** (same UTM + Ubuntu Desktop 24.04 environment used for REMnux/SIFT) the candidate tools, with a snapshot before each test.
5. Document results in this same file / in a `FINDINGS.md` analogous to REMnux's and SIFT's once there's real data.

## Note

This section will be updated as it gets investigated in future versions. In v0.1 it's intentionally left as a placeholder, so as not to mix real findings (SIFT, REMnux) with unvalidated content.
