# Install

## One line

FreeBSD / Linux, amd64 or arm64 — downloads the latest release binary from the
public [m2cloud-cli](https://github.com/Mt2-SAAS/m2cloud-cli) repo, verifies it
against the release's `checksums.txt` (sha256), and installs to
`/usr/local/bin/m2cloud` (or `~/.local/bin` without root):

```sh
curl -fsSL https://mt2-saas.github.io/m2cloud-cli/install.sh | sh
```

On FreeBSD without `curl`:

```sh
fetch -o - https://mt2-saas.github.io/m2cloud-cli/install.sh | sh
```

## What the installer does

1. Detects OS and architecture (`uname -s` / `uname -m`).
2. Downloads the matching binary from the latest GitHub release.
3. Verifies the sha256 against the release's `checksums.txt` — a mismatch
   aborts the install.
4. Installs to `/usr/local/bin` elevating **only** when the target dir is not
   user-writable; otherwise `~/.local/bin`.
5. Prints `m2cloud version` as a smoke test.

## Overrides

| Variable | Purpose |
|---|---|
| `M2_INSTALL_DIR` | install prefix (default `/usr/local/bin`, or `~/.local/bin` without root) |
| `M2_DOWNLOAD_BASE` | pin a version, e.g. `.../releases/download/v0.1.25` |

```sh
M2_INSTALL_DIR="$HOME/.local/bin" curl -fsSL https://mt2-saas.github.io/m2cloud-cli/install.sh | sh
```

## Verify a binary manually

```sh
sha256sum -c checksums.txt   # Linux
sha256 -c checksums.txt      # FreeBSD
```

## Uninstall

The installer touches only the binary:

```sh
rm /usr/local/bin/m2cloud    # or ~/.local/bin/m2cloud
```

Agent state (identity, idempotency store) lives under the configured
`data_dir` (default `/var/lib/m2cloud`) and survives reinstalls — delete it
only if you intend to revoke the installation (see
[Security](security.md#revoking-an-installation)).

## After install

```sh
m2cloud version
m2cloud --help
```

Continue with [Configuration](configuration.md).
