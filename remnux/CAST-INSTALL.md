# Instalación de Cast en arm64 — pasos concretos

🇬🇧 [English version](CAST-INSTALL.en.md)

`cast` es el instalador oficial de distribuciones basadas en Salt como SIFT y REMnux (`ekristen/cast`). Publica un `.deb` arm64 nativo en cada release, con el patrón de nombre `cast-v<VERSION>-linux-arm64.deb`.

## 1. Instalar `git` primero

`cast install <owner>/<repo>` clona el repo de Salt states del distro internamente. Sin `git`, `cast install` falla.

```bash
sudo apt update
sudo apt install -y git curl
```

## 2. Descargar e instalar el `.deb` de Cast

```bash
CAST_VERSION="1.0.4"   # comprobar la última versión en https://github.com/ekristen/cast/releases
wget "https://github.com/ekristen/cast/releases/download/v${CAST_VERSION}/cast-v${CAST_VERSION}-linux-arm64.deb"
sudo dpkg -i "cast-v${CAST_VERSION}-linux-arm64.deb"
```

Verificar:

```bash
cast --version
# cast version v1.0.4
```

## 3. Instalar Salt en modo masterless

Cast necesita Salt instalado. Se probó con Salt 3008.2 vía el script de bootstrap oficial (Salt pasó a manos de Broadcom):

```bash
curl -L https://bootstrap.saltstack.com -o bootstrap-salt.sh
sudo sh bootstrap-salt.sh -X   # -X = solo minion, sin arrancar el servicio como si hubiera master
```

El paquete `salt` se resuelve, en este bootstrap, contra los repos de `packages.broadcom.com` (Salt Project pasó a manos de Broadcom) en lugar de los repos genéricos de Ubuntu — de ahí la versión 3008.2 usada en las pruebas, que puede no coincidir con la que trae `apt install salt-minion` de los repos de Ubuntu 24.04.

Configurar modo masterless en `/etc/salt/minion.d/local.conf`:

```yaml
file_client: local
file_roots:
  base:
    - /home/iac/salt-states
```

Comprobar arquitectura detectada por Salt:

```bash
sudo salt-call --local grains.get osarch
# arm64
```

## 4. Instalar el distro con Cast

### REMnux

```bash
sudo cast install remnux/salt-states
```

Esto clona `remnux/salt-states` (por defecto en el `file_roots` configurado, p. ej. `/home/iac/salt-states`) y queda listo para `state.apply remnux.addon`.

### SIFT

```bash
sudo cast install teamdfir/sift-saltstack
```

Confirmado funcionando directamente en arm64 sin pasos adicionales — los 3 fixes de arquitectura documentados por la comunidad ya están mergeados aguas arriba (ver [`sift/FINDINGS.md`](../sift/FINDINGS.md)).

## Notas

- Cast requiere salida a internet a `github.com`/`codeload.github.com` (para clonar los repos) y a `packages.broadcom.com` (para el bootstrap de Salt).
- Si `cast install` falla con un error relacionado con `git`, confirma que `git --version` funciona antes de reintentar.
