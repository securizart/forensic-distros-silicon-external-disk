# Dependencies found — REMnux / SIFT on arm64

## Base environment

- **VM**: UTM (Apple Silicon host)
- **Guest OS**: Ubuntu Desktop 24.04 arm64
- **Test user**: `iac`

## System dependencies

| Package | Reason |
|---|---|
| `git` | `cast install <owner>/<repo>` clones the Salt-states repo internally; without `git` installed, `cast install` fails. Confirmed and handled idempotently in the main installer via `install_cast_arm64` (`lib/common.sh`). |
| `curl` / `wget` | Needed for the Salt bootstrap (`packages.broadcom.com`) and to download the Cast `.deb`. |
| `dpkg` | To install the official Cast `.deb`. |
| `file` | Used in `verify.sh` to check the ELF architecture of installed binaries. |

## Cast

- **Tested version**: v1.0.4
- **Source**: official `.deb` from `ekristen/cast` (GitHub Releases)
- **Architecture**: native arm64 build — no emulation needed
- Concrete steps in [`CAST-INSTALL.md`](CAST-INSTALL.md)

## Salt

- **Tested version**: 3008.2
- **Source**: official bootstrap script via `packages.broadcom.com` (Salt moved to Broadcom; the `salt` package in Ubuntu 24.04's repos may be outdated or not match this version)
- **Mode**: masterless (no remote master)
- **Key config** in `/etc/salt/minion.d/local.conf`:

```yaml
file_client: local
file_roots:
  base:
    - /home/iac/salt-states
```

- Expected architecture grain: `osarch: arm64` (check with `sudo salt-call --local grains.get osarch`)

## Salt states repos

| Repo | Use |
|---|---|
| `remnux/salt-states` | Cloned to `/home/iac/salt-states`, applied with `state.apply remnux.addon` |
| `teamdfir/sift-saltstack` | Installed directly with `cast install teamdfir/sift-saltstack` |

## Notes

- `packages.broadcom.com` and `archive.ubuntu.com`/`security.ubuntu.com` need to be reachable from the VM; if the VM sits behind a proxy or a restricted network, adjust before starting.
- No Salt master is needed at all: everything runs masterless with `salt-call --local`.
