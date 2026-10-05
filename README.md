# m2cloud CLI — public releases

This repository publishes the **prebuilt `m2cloud` CLI binaries** so they can be
downloaded anonymously. The source code lives in the private `m2cloud` repo;
every release here mirrors the same semver tag automatically from its release
pipeline.

## Install (one line)

FreeBSD / Linux, amd64 or arm64:

```sh
curl -fsSL https://Mt2-SAAS.github.io/m2cloud-cli/install.sh | sh
```

On FreeBSD without curl: `fetch -o - https://Mt2-SAAS.github.io/m2cloud-cli/install.sh | sh`

The script detects your OS/arch, downloads the matching binary from the latest
release, verifies it against the release's `checksums.txt` (sha256), and
installs it to `/usr/local/bin/m2cloud` (or `~/.local/bin` without root
privileges).

Verify a downloaded binary manually:

```sh
sha256 -c checksums.txt   # FreeBSD (use sha256sum on Linux)
```

## Downloads

- `m2cloud-freebsd-amd64`
- `m2cloud-freebsd-arm64`
- `m2cloud-linux-amd64`
- `m2cloud-linux-arm64`
- `checksums.txt`

## Next steps after install

```sh
m2cloud version
m2cloud pair <pairing-token>
```

The agent connects outbound-only (WSS) to the m2cloud control plane; no inbound
ports are required.
