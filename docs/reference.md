# Command reference

Full flag-level reference, generated conventions first.

## Global flags

| Flag | Applies to | Purpose |
|---|---|---|
| `--config <path.toml>` | `pair`, `authenticate`, `run`, `doctor` | explicit config path (no default) |
| `--help` | all | per-command help |

## m2cloud version

Prints `version`, `commit`, `build date`. No config required.

## m2cloud config validate `<path.toml>`

Exit 0 = valid. See [Configuration](configuration.md) for every rule.

## m2cloud pair `[pairing-token]`

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | required |
| `--token-file <path>` | read the token from a file |
| `--endpoint <url>` | override `agent.api_endpoint` for this pairing only |

Token sources, in order of preference: positional argument, `--token-file`,
stdin. There is deliberately **no** `--token` flag (shell history / process
table).

## m2cloud authenticate

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | required |

## m2cloud run

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | required |

Signals: `SIGTERM`/`SIGINT` → clean close (1000), exit 0.

## m2cloud doctor

| Flag | Purpose |
|---|---|
| `--config <path.toml>` | required |
| `--json` | machine-readable report |

Exit codes: 0 compatible · 2 partial · 3 incompatible/unknown · 4 invalid
configuration · 5 database unreachable.

## m2cloud status / m2cloud update `[--check]`

Stubs — print `not implemented yet`, exit 3.

## Exit codes (all commands)

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the command ran and failed |
| 2 | usage error |
| 3 | not implemented yet |
| 4–5 | doctor-specific: invalid config · DB unreachable |
