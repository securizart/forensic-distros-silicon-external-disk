# Dependencias encontradas — REMnux / SIFT en arm64

🇬🇧 [English version](DEPENDENCIES.en.md)

## Entorno base

- **VM**: UTM (host Apple Silicon)
- **Guest OS**: Ubuntu Desktop 24.04 arm64
- **Usuario de pruebas**: `iac`

## Dependencias del sistema

| Paquete | Motivo |
|---|---|
| `git` | `cast install <owner>/<repo>` clona el repo de Salt states internamente; sin `git` instalado, `cast install` falla. Confirmado y resuelto de forma idempotente en el instalador principal vía `install_cast_arm64` (`lib/common.sh`). |
| `curl` / `wget` | Necesarios para el bootstrap de Salt (`packages.broadcom.com`) y para descargar el `.deb` de Cast. |
| `dpkg` | Instalación del `.deb` oficial de Cast. |
| `file` | Usado en `verify.sh` para comprobar la arquitectura ELF de los binarios instalados. |

## Cast

- **Versión probada**: v1.0.4
- **Fuente**: `.deb` oficial de `ekristen/cast` (GitHub Releases)
- **Arquitectura**: build arm64 nativa — no requiere emulación
- Ver pasos concretos en [`CAST-INSTALL.md`](CAST-INSTALL.md)

## Salt

- **Versión probada**: 3008.2
- **Fuente**: script de bootstrap oficial vía `packages.broadcom.com` (Salt pasó a manos de Broadcom; el paquete `salt` de los repos de Ubuntu 24.04 puede estar desactualizado o no coincidir con esta versión)
- **Modo**: masterless (sin master remoto)
- **Configuración clave** en `/etc/salt/minion.d/local.conf`:

```yaml
file_client: local
file_roots:
  base:
    - /home/iac/salt-states
```

- Grain de arquitectura esperado: `osarch: arm64` (comprobar con `sudo salt-call --local grains.get osarch`)

## Repos de Salt states

| Repo | Uso |
|---|---|
| `remnux/salt-states` | Clonado en `/home/iac/salt-states`, aplicado con `state.apply remnux.addon` |
| `teamdfir/sift-saltstack` | Instalado directamente con `cast install teamdfir/sift-saltstack` |

## Notas

- `packages.broadcom.com` y `archive.ubuntu.com`/`security.ubuntu.com` deben ser alcanzables desde la VM; si la VM está detrás de un proxy o red restringida, ajustar antes de empezar.
- No se necesita ningún master de Salt: todo el trabajo se hace en modo masterless con `salt-call --local`.
