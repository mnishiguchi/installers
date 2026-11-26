# Docker development with Colima on macOS

Use the same `docker` and `docker compose` commands as on LMDE. Colima runs a
Linux VM using Lima; Docker Desktop is not required. Homebrew owns the CLI
packages and the macOS Keychain credential helper.

## Install and check

```bash
./macos-bootstrap.sh --only colima
./macos-bootstrap.sh --only colima --check
```

The opt-in section installs `Brewfile.colima` and merges the Homebrew plugin
path into `~/.docker/config.json`. It preserves unrelated keys, custom plugin
paths and non-Desktop credential stores. A missing or obsolete Desktop global
credential store becomes `osxkeychain`; registry credentials are **not**
migrated. Log in again as needed. Existing config is backed up privately before
replacement. A custom `DOCKER_CONFIG`, conflicting user plugins, malformed
JSON, or Desktop per-registry helpers require manual review. Neither install
nor check starts a VM or changes the current Docker context. A stopped VM is
not a setup error.

## Start on demand (Apple Silicon)

For the first start on a 32 GB Mac, use these initial resource settings:

```bash
colima start --runtime docker --cpu 4 --memory 8 --disk 60 \
  --vm-type vz --mount-type virtiofs
docker context use colima
```

Colima persists the profile configuration. These are suggested values, not
mandatory settings. For an existing VM use `colima start` without flags to
retain its configuration. Do not delete or recreate an existing VM to change
settings. Do not enable a login service unless you want the VM to start at login.

```bash
colima status
docker --context colima version
docker compose version
docker buildx version
colima stop
```

## Test

With the default Colima VM running on native Apple Silicon macOS:

```bash
bash bin/colima-smoke-test
```

The smoke test downloads public images, builds a disposable web image, checks
read-only host mounts, Compose startup, port forwarding, DNS and PostgreSQL
volume persistence, and removes its own project resources. It does not prune
other Docker resources. Base images and build cache remain. Override the
localhost test port with `COLIMA_SMOKE_PORT=18081` if needed. This does not test
private registry credentials or application-specific behavior.

## Migrating from Docker Desktop

Docker Desktop uninstall destroys its local container data. Inspect and back
up any valuable images, volumes and databases before using the [official
uninstaller](https://docs.docker.com/desktop/uninstall/). Preserve the Docker CLI
configuration privately; it may contain secrets. The installer refuses to
migrate a detected Desktop installation automatically. Remove only confirmed
obsolete Desktop plugin symlinks and contexts after uninstalling; never delete
all of `~/.docker` or globally prune Docker data. See the [Colima
project](https://github.com/abiosoft/colima) for VM and runtime details.
