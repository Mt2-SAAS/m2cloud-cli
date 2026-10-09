# Security notes

Threat model and guarantees for the agent side of m2cloud. The control plane
enforces its own side; this page covers what runs on **your** host.

## Outbound only

The agent never listens on a port. `m2cloud run` dials the control plane over
`wss://` (TLS); every command it executes arrives on that authenticated
channel. There is no inbound surface to firewall beyond what your game server
already exposes.

## Installation identity

- `pair` generates an Ed25519 key pair under `data_dir` (`identity.key`, mode
  0600). The key is the installation's identity — always reused, never
  regenerated.
- The pairing token is one-use and short-lived; it is never accepted as a
  `--token` flag, never logged, never echoed.
- Each reconnect re-proves the identity with a signed challenge (the same
  exchange `authenticate` runs over HTTP).

## Secrets handling

- Database passwords live in `password_file` (mode 0600, checked by
  `config validate`) or `password_env` — never on the command line, never in
  config values committed anywhere.
- `config validate` fails when a referenced secret file is group/world
  readable.
- The idempotency store (`state.db`) is mode 0600 and stores only payload
  digests and sanitized results — never plaintext passwords or legacy hashes.
- Player passwords hashed with the serverfile's own convention (MySQL 4.1
  native), set and compared in constant time; credentials never enter logs.

## Command allow-list

The dispatcher is **fail-closed**: an inbound command not on the allow-list is
rejected without executing. The current surface: `agent.ping`,
`server.capabilities.report`, `ranking.players`, `ranking.guilds`,
`account.create`, `account.verify`, `account.recovery_lookup`,
`account.set_password`, `player.lookup`.

## Idempotency

Mutating commands (`account.create`, `account.set_password`) run through a
local idempotency store keyed by the control plane's `request_id`/`operation_id`:
a replay with the same payload returns the recorded result (`replayed: true`)
without re-executing; the same id with a different payload fails closed. A
redelivered command can never double-create an account.

## Rate limits and uniform failures

Unknown login, wrong password and banned account are indistinguishable on the
public surface (same 401) — the agent cannot be used to enumerate accounts.
The WSS handshake is rate-limited per peer IP.

## Revoking an installation

Revoke from the owner console (the control plane then refuses the
installation's key). On the host, removing `data_dir` destroys the identity;
a fresh `pair` with a new token mints a new installation.

## Exit codes on failure

`run` exits `1` before dialing if the idempotency store cannot open — the
agent must never execute a mutation without idempotency protection.
