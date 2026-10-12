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

Fetches the latest public release from `Mt2-SAAS/m2cloud-cli` through the
GitHub API (`https://api.github.com`) and compares it with the running binary's
injected semver (`vX.Y.Z`). No config required. `M2_UPDATE_API` overrides the
API base URL, primarily for testing.

| Flag | Purpose |
|---|---|
| `--check` | report availability without installing; exits 0 on any completed check, 1 on operational failure |

`--check` reports `update available: vX.Y.Z (current vW.X.Y)` or
`no update available (current …, latest …)` on stdout. If the running binary is
unversioned (such as `dev` or a bare SHA), it reports that on stdout and still
exits **0**.

Without `--check`, an available update downloads `m2cloud-<GOOS>-<GOARCH>`,
streams and verifies its SHA-256 against the release's `checksums.txt`, and
stages it in the installed binary's directory. It atomically renames the new
binary over the running binary, with mode `0755`, keeping the previous binary
as `<name>.old`. A failure leaves the installed binary untouched. The install
directory must be writable. After installation it prints a reminder to restart
any running service; see [Running as a service](service.md).

The release checksums are currently **unsigned**. Signature verification will
be added when the release channel signs checksums.

Exit codes: **0** for success, no update, or any completed `--check` result
(including an unversioned binary); **1** for operational failures — HTTP or
manifest errors (also under `--check`), checksum mismatch, unwritable install
directory, or refusal to install from an unversioned binary; **2** for usage
errors (invalid flags or extra arguments).

## Exit codes (all commands)

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | the command ran and failed |
| 2 | usage error |
| 3 | not implemented yet |
| 4–5 | doctor-specific: invalid config · DB unreachable |
