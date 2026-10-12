# Commands

All commands take `--config <path.toml>` where they need configuration. Run
`m2cloud <command> --help` for the authoritative flags.

## version

```sh
m2cloud version
```

Prints the agent version, commit and build date.

## config validate

```sh
m2cloud config validate <path.toml>
```

Validates a configuration file without connecting anywhere. See
[Configuration](configuration.md#validation-rules) for the rules it enforces.

## pair

```sh
m2cloud pair <pairing-token> --config /etc/m2cloud/m2cloud.toml
m2cloud pair --config m2cloud.toml --token-file /run/secrets/pairing-token
echo "$TOKEN" | m2cloud pair --config m2cloud.toml
```

Exchanges a one-use pairing token for this installation's identity:

1. loads its configuration — an explicit `--config <path.toml>`, `M2_CONFIG`,
   or the platform default (`/etc/m2cloud/agent.toml` on Linux,
   `/usr/local/etc/m2cloud/agent.toml` on FreeBSD);
2. ensures an Ed25519 installation key pair exists under `agent.data_dir`,
   generating one on first use. An existing key is always reused, never
   regenerated: it is the installation's identity;
3. `POST`s the pairing token, the public key, the agent version and a stable
   host fingerprint to `<endpoint>/api/v1/agent/pair`;
4. on success, persists the endpoint, server id and installation id in
   `identity.json` (mode 0644, public metadata only).

Provide the token, in order of preference, as the positional argument, as
`--token-file <path>`, or on stdin. It is never accepted as a `--token` flag
and never echoed back.

## authenticate

```sh
m2cloud authenticate --config /etc/m2cloud/m2cloud.toml
```

Proves this installation's identity to the Control API over HTTP without
going through `pair` again. Requires a previously paired identity. It signs a
short-lived, single-use challenge with the installation's Ed25519 key; a
revoked installation, an expired challenge and an invalid signature are all
reported uniformly as `401 AGENT_AUTH_FAILED` (no state enumeration).

## run

```sh
m2cloud run --config /etc/m2cloud/m2cloud.toml
```

Runs the persistent agent channel. It does not daemonise: run it in the
foreground or through a systemd/rc.d unit. Requires a previously paired
identity. `SIGTERM`/`SIGINT` close the connection with code 1000 and exit 0.
See [Command channel](channel.md) for the protocol.

## doctor

```sh
m2cloud doctor --config /etc/m2cloud/m2cloud.toml
m2cloud doctor --config /etc/m2cloud/m2cloud.toml --json
```

Diagnoses the local installation and Metin2 databases: configuration,
connectivity, schema compatibility and database privileges. The report
against the pre-configured fixture schema reports `UNKNOWN` rather than
`COMPATIBLE` — compatibility is only ever asserted against a detected real
schema.

Exit codes: `0` compatible, `2` partial, `3` incompatible/unknown, `4` invalid
configuration, `5` database unreachable.

## status

```sh
m2cloud status --config /etc/m2cloud/m2cloud.toml
m2cloud status --json
```

Shows the local installation's status without contacting the Control API or a
database:

- the resolved configuration path, endpoint and CLI version;
- pairing state — paired, installation id, server id;
- the latest runtime observation left by `m2cloud run` — state, observed at,
  agent version, last command. A state older than 90 seconds, one recorded for
  a different installation or endpoint, or one timestamped in the future is
  reported as `stale`;
- the last `doctor` report — generated at, adapter, result.

Empty fields print as `unknown`; `--json` prints the machine-readable report.
Configuration resolves like every other command: `--config`, `M2_CONFIG`, then
the platform default. Exit codes: `0` success, `1` failure (e.g. the
configuration cannot be loaded or is invalid), `2` usage error.

## update

```sh
m2cloud update --check
m2cloud update
```

Checks the latest public release from `Mt2-SAAS/m2cloud-cli` through the
GitHub API against the running binary's injected semver (`vX.Y.Z`). No config
required. `--check` only reports availability on stdout and always exits `0`,
even if the check fails or the current binary is unversioned (`dev`, bare SHA).

`update` downloads `m2cloud-<GOOS>-<GOARCH>`, streams and verifies SHA-256
against the release's currently unsigned `checksums.txt`, stages in the same
directory, and atomically replaces the binary with mode `0755`. The previous
binary is kept as `<name>.old`; on failure the installed binary stays untouched.
It prints a reminder to restart any running service; see
[Running as a service](service.md).

Exit codes: `0` success/no update or any `--check` result; `1` operational
failure (HTTP, checksum mismatch, unwritable install directory, or refusal to
install from an unversioned binary); `2` usage error. See the
[command reference](reference.md#m2cloud-update-check) for output details.
