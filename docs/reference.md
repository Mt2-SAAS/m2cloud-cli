# Command reference

Full flag-level reference, generated conventions first.

## Global flags

| Flag | Applies to | Purpose |
|---|---|---|
| `--config <path.toml>` | `pair`, `authenticate`, `run`, `doctor`, `status` | explicit config path |
| `--help` | all | per-command help |

Configuration is selected in this order: `--config`, `M2_CONFIG`, then
`/etc/m2cloud/agent.toml` on Linux or `/usr/local/etc/m2cloud/agent.toml` on
FreeBSD. `config validate` keeps its explicit path argument.

## m2cloud version

Prints `version`, `commit`, `build date`. No config required.

## m2cloud config validate `<path.toml>`

Exit 0 = valid. See [Configuration](configuration.md) for every rule.

## m2cloud pair `[pairing-token]`

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | optional override |
| `--token-file <path>` | read the token from a file |
| `--endpoint <url>` | override `agent.api_endpoint` for this pairing only |

Token sources, in order of preference: positional argument, `--token-file`,
stdin. There is deliberately **no** `--token` flag (shell history / process
table).

## m2cloud authenticate

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | optional override |

## m2cloud run

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | optional override |

Signals: `SIGTERM`/`SIGINT` → clean close (1000), exit 0.

## m2cloud doctor

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | optional override |
| `--json` | machine-readable report |

Exit codes: 0 compatible · 2 partial · 3 incompatible/unknown · 4 invalid
configuration · 5 database unreachable.

## m2cloud status

Shows the local configuration, pairing metadata, latest runtime observation and
the last `doctor` report. It never connects to the Control API or a database.
Use `--json` for machine-readable output. A runtime state that has not been
updated in 90 seconds — or one recorded for a different installation or
endpoint, or timestamped in the future — is reported as `stale`.

## m2cloud update `[--check]`

Stub — prints `not implemented yet`, exit 3.

## Exit codes (all commands)

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the command ran and failed |
| 2 | usage error |
| 3 | not implemented yet |
| 4–5 | doctor-specific: invalid config · DB unreachable |
