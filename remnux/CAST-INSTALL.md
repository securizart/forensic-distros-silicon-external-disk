# Installing Cast on arm64 — concrete steps

`cast` is the official installer for Salt-based distros like SIFT and REMnux (`ekristen/cast`). It publishes a native arm64 `.deb` on every release, following the naming pattern `cast-v<VERSION>-linux-arm64.deb`.

## 1. Install `git` first

`cast install <owner>/<repo>` clones the distro's Salt-states repo internally. Without `git`, `cast install` fails.

```bash
sudo apt update
sudo apt install -y git curl
```

## 2. Download and install the Cast `.deb`

```bash
CAST_VERSION="1.0.4"   # check the latest version at https://github.com/ekristen/cast/releases
wget "https://github.com/ekristen/cast/releases/download/v${CAST_VERSION}/cast-v${CAST_VERSION}-linux-arm64.deb"
sudo dpkg -i "cast-v${CAST_VERSION}-linux-arm64.deb"
```

Verify:

```bash
cast --version
# cast version v1.0.4
```

## 3. Install Salt in masterless mode

Cast needs Salt installed. This was tested with Salt 3008.2 via the official bootstrap script (Salt Project is now under Broadcom):

```bash
curl -L https://bootstrap.saltstack.com -o bootstrap-salt.sh
sudo sh bootstrap-salt.sh -X   # -X = minion only, don't start it as if a master existed
```

In this bootstrap, the `salt` package resolves against `packages.broadcom.com`'s repos rather than Ubuntu's generic repos — hence the 3008.2 version used in testing, which may not match what `apt install salt-minion` pulls from Ubuntu 24.04's own repos.

Configure masterless mode in `/etc/salt/minion.d/local.conf`:

```yaml
file_client: local
file_roots:
  base:
    - /home/iac/salt-states
```

Check the architecture grain Salt detected:

```bash
sudo salt-call --local grains.get osarch
# arm64
```

## 4. Install the distro with Cast

### REMnux

```bash
sudo cast install remnux/salt-states
```

This clones `remnux/salt-states` (into the configured `file_roots`, e.g. `/home/iac/salt-states`) and leaves it ready for `state.apply remnux.addon`.

### SIFT

```bash
sudo cast install teamdfir/sift-saltstack
```

Confirmed working directly on arm64 with no extra steps — the 3 arm64 fixes documented by the community are already merged upstream (see [`sift/FINDINGS.md`](../sift/FINDINGS.md)).

## Notes

- Cast needs outbound access to `github.com`/`codeload.github.com` (to clone the repos) and to `packages.broadcom.com` (for the Salt bootstrap).
- If `cast install` fails with a `git`-related error, confirm `git --version` works before retrying.
