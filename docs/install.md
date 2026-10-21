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

## FreeBSD: guided install (binary + service)

The one-liner above installs **only the binary**. On FreeBSD, the guided
installer sets up the whole agent — binary, `m2cloud` service user,
configuration, database password files, rc.d service, pairing and a
`m2cloud doctor` check — by asking a handful of questions. It is the
recommended path if the agent will run as a background service on the server.

Download the installer and the rc.d script it installs (both live in the
public repo's `packaging/` tree), then run it as root:

```sh
fetch -o install.sh https://raw.githubusercontent.com/Mt2-SAAS/m2cloud-cli/main/packaging/freebsd-rc.d/install.sh
fetch -o m2cloud_agent https://raw.githubusercontent.com/Mt2-SAAS/m2cloud-cli/main/packaging/freebsd-rc.d/m2cloud_agent
sudo sh install.sh
```

It asks for (Enter accepts the default shown in brackets):

- the Control API endpoint (`https://…`, required);
- database host `127.0.0.1`, port `3306`, account database `account`,
  player database `player`, database user `mt2` — one user for both
  databases;
- the database password, twice without echo — the **same password** is
  written to both password files (`0600`, owned by the service user);
- the pairing token (no echo), used to run `m2cloud pair` for you.

If no `m2cloud` binary is found next to the script or in `/usr/local/bin`,
it offers to download the latest `m2cloud-freebsd-amd64` release and verify
it against `checksums.txt`. It ends with `m2cloud doctor` and prints the two
commands to enable and start the service — it never enables or starts the
service itself. Re-running is safe (an existing `agent.toml` is backed up
first). See [Service > rc.d](service.md#rcd-freebsd) for what it installs
and the manual equivalent.

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
| `M2_DOWNLOAD_BASE` | pin a version, e.g. `.../releases/download/v0.1.37` |

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
