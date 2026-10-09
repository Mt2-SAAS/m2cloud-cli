# m2cloud CLI & agent

The `m2cloud` binary is the **CLI and persistent agent** for Metin2 server
owners. One static Go binary, no runtime dependencies, runs on FreeBSD and
Linux (amd64/arm64) directly on the host that owns the Metin2 databases.

```sh
curl -fsSL https://mt2-saas.github.io/m2cloud-cli/install.sh | sh
```

## What it does

- **`pair`** — exchange a one-use pairing token (issued by your control plane's
  owner console) for this installation's identity.
- **`authenticate`** — prove the installation's identity over HTTP.
- **`run`** — keep a persistent outbound `wss://` channel to the control plane
  and answer its commands (rankings, account creation, player lookup, password
  recovery …).
- **`doctor`** — diagnose the local installation: connectivity, schema
  compatibility and database privileges.
- **`config validate`** — validate a config file without connecting anywhere.

## How it fits together

```text
Metin2 serverfiles ── MySQL/MariaDB ──┐
                                       │  sql, localhost only
                            ┌──────────▼──────────┐
                            │   m2cloud agent     │
                            │  (m2cloud run)      │
                            └──────────┬──────────┘
                                       │  outbound wss:// (TLS)
                            ┌──────────▼──────────┐
                            │  m2cloud control    │
                            │  plane + portals    │
                            └─────────────────────┘
```

The agent only ever connects **outbound** — it never listens on a port, so it
introduces no new inbound surface on your game host.

## Support matrix

| Command | State |
|---|---|
| `m2cloud version` | implemented |
| `m2cloud --help` / `help` | implemented |
| `m2cloud config validate <path.toml>` | implemented |
| `m2cloud pair [pairing-token]` | implemented |
| `m2cloud authenticate` | implemented |
| `m2cloud run` | implemented |
| `m2cloud doctor` | implemented |
| `m2cloud status` | stub — exit code 3 |
| `m2cloud update [--check]` | stub — exit code 3 |

Stubs print `not implemented yet` and exit **3**, so scripts can tell "not
built yet" apart from "failed" (1) and "misused" (2).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the command ran and failed |
| 2 | usage error |
| 3 | not implemented yet |
