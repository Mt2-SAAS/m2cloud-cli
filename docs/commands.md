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

1. loads `--config <path.toml>` (required — there is no default path);
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

## status / update

Stubs — they print `not implemented yet` and exit `3`.
