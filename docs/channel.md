# Command channel

The persistent `wss://` connection between the agent and the control plane
(`m2cloud run`). One connection's lifecycle:

1. **Dial** `wss://<endpoint>/api/v1/agent/connect?installation_id=...`
   (`ws://` only for a loopback endpoint).
2. **Handshake**: receive a challenge, sign it with the installation's
   Ed25519 key, answer with `{challenge, signature, public_key, agent_version,
   protocol_versions}`; wait for `{"type": "connected", ...}`.
3. **Two concurrent loops** until the connection ends or a signal arrives:
    - a heartbeat every 30 s;
    - a read loop dispatching every inbound `command` envelope to the
      fail-closed allow-list dispatcher and sending back its `result`.
4. **Reconnect** on any failure with bounded exponential backoff and jitter
   (base 1 s, factor 2, cap 60 s, ±20%). A connection that stayed up at least
   as long as the cap resets the attempt counter.

`SIGTERM`/`SIGINT` cancel the run loop: the connection closes with WebSocket
code `1000` (Normal Closure), no reconnect, exit 0.

## Frames and limits

- Max frame: 256 KiB, enforced identically on both ends.
- Heartbeat cadence: 30 s, enforced identically on both ends.
- Duplicate connections: the control plane closes the older one with `4001
  SUPERSEDED` — the agent treats it as any other reconnect trigger.

## Commands the agent answers

| Command | Kind | Idempotency store |
|---|---|---|
| `agent.ping` | read | — |
| `server.capabilities.report` | read | — |
| `ranking.players` / `ranking.guilds` | read | — |
| `player.lookup` | read | — |
| `account.create` | mutation | yes — replay by `request_id` |
| `account.verify` | credential read | yes — both outcomes recorded |
| `account.recovery_lookup` | read | — |
| `account.set_password` | mutation | yes — replay by `request_id` |

An agent command that answers with a list marshals an **empty list**, never
`null` — a `null` slice fails the control plane's strict validation and would
break a real user's panel.

## Why outbound-only

The agent dials the control plane, never the reverse: hosts behind NAT (the
common case for Metin2 servers) need no port forwarding and no inbound
firewall rule. The TLS `wss://` channel is also the only transport for
credential-bearing commands (`account.verify`, `account.set_password`) — there
is no public SQL interface to the game databases.
