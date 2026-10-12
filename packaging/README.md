# Packaging — running `m2cloud run` as a supervised service

M2C-013A. `m2cloud run` (`apps/m2-cli`) never daemonizes itself (ADR-009): it stays in the
foreground, reconnects on its own with bounded backoff (ADR-011), and expects the host's
supervisor to restart it on crash and to deliver `SIGTERM` on shutdown. This directory holds
one supervision model per target platform. Every artifact here is meant to be installed as-is,
not copied as a starting-point example.

| Directory       | Platform                      | Supervisor  |
| --------------- | ------------------------------ | ----------- |
| `systemd/`      | Linux with systemd              | systemd     |
| `freebsd-rc.d/` | FreeBSD                         | rc.d + daemon(8) |
| `docker/`       | Any host running Docker/Podman  | the container runtime |

## systemd (`systemd/m2cloud-agent.service`)

```sh
sudo useradd --system --home-dir /var/lib/m2cloud --shell /usr/sbin/nologin m2cloud
sudo install -m 0755 m2cloud /usr/local/bin/m2cloud
sudo mkdir -p /etc/m2cloud
sudo install -m 0640 -o root -g m2cloud agent.toml /etc/m2cloud/agent.toml
sudo install -m 0644 packaging/systemd/m2cloud-agent.service /etc/systemd/system/m2cloud-agent.service
sudo systemctl daemon-reload
sudo systemctl enable --now m2cloud-agent
```

`StateDirectory=m2cloud` makes systemd create and own `/var/lib/m2cloud` (mode 0700) for the
service; the installation identity (`identity.json`, `identity.key` at 0600) is written there by
`m2cloud pair` / `m2cloud run` under the `m2cloud` user (ADR-009, ADR-004 — the private key is
never group- or world-readable). The unit is hardened
(`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, a minimal
`ReadWritePaths`, capability bounding set dropped to nothing, a restricted syscall filter).

**Update:** replace the binary and restart — the running process does not need to be paired
again, the identity lives in the state directory, not in the binary.

```sh
sudo install -m 0755 m2cloud-new /usr/local/bin/m2cloud
sudo systemctl restart m2cloud-agent
```

**Logs:** `journalctl -u m2cloud-agent -f` (the agent logs structured JSON to stderr, which
systemd captures into the journal).

## FreeBSD rc.d (`freebsd-rc.d/m2cloud_agent`)

```sh
sudo pw useradd m2cloud -d /var/db/m2cloud -s /usr/sbin/nologin -m
sudo install -m 0755 m2cloud /usr/local/bin/m2cloud
sudo mkdir -p /usr/local/etc/m2cloud
sudo install -m 0640 -o root -g m2cloud agent.toml /usr/local/etc/m2cloud/agent.toml
sudo install -m 0555 packaging/freebsd-rc.d/m2cloud_agent /usr/local/etc/rc.d/m2cloud_agent
sudo sysrc m2cloud_agent_enable=YES
sudo service m2cloud_agent start
```

The script follows the standard rc.d skeleton (`PROVIDE`, `REQUIRE: NETWORKING DAEMON`, `rcvar`,
`command`, `pidfile`, `command_args`, `run_rc_command "$1"`) and runs `m2cloud run` in the
foreground under `daemon(8)` (`/usr/sbin/daemon -f -p $pidfile -u $user m2cloud run --config ...`),
which tracks the child in the pidfile so `service m2cloud_agent status|stop` work. `data_dir` in
`agent.toml` should point at a directory owned by the dedicated user (for example
`/var/db/m2cloud`, created with `-m` above).

**Update:** same pattern as systemd — replace the binary, `service m2cloud_agent restart`.

## Docker (`docker/Dockerfile`)

```sh
docker build -f packaging/docker/Dockerfile -t m2cloud-agent:latest .
docker volume create m2cloud-state
docker run -d --name m2cloud-agent --restart unless-stopped \
  -v m2cloud-state:/var/lib/m2cloud \
  -v "$(pwd)/agent.toml:/etc/m2cloud/agent.toml:ro" \
  -v "$(pwd)/secrets:/etc/m2cloud/secrets:ro" \
  m2cloud-agent:latest
```

Multi-stage build: a `golang:1.27-alpine` stage compiles the binary from source
(`CGO_ENABLED=0 -trimpath`, the same flags `scripts/build-cli.sh` uses), the runtime stage is
`gcr.io/distroless/static-debian12:nonroot` — no shell, no package manager, runs as uid 65532.
`/var/lib/m2cloud` is a declared `VOLUME` because the installation identity must survive
container recreation; the config file is not baked into the image and is bind-mounted read-only.
`ENTRYPOINT` is the binary itself (`/usr/local/bin/m2cloud run`, `CMD` supplies the default
`--config` flag), not a fixed `run` command line, so administrative commands work with
`--entrypoint`:

```sh
docker run --rm --entrypoint /usr/local/bin/m2cloud m2cloud-agent:latest version
docker run --rm --entrypoint /usr/local/bin/m2cloud \
  -v "$(pwd)/agent.toml:/etc/m2cloud/agent.toml:ro" \
  m2cloud-agent:latest config validate /etc/m2cloud/agent.toml
```

See `packaging/docker/docker-compose.example.yml` for the same setup as a compose file (not
wired into the repository's root `compose.yaml`, which runs local development infrastructure,
not a customer's agent).

**Update:** rebuild the image with the new source (or pull a new tag) and recreate the
container; the named volume keeps the identity.

## What is actually verified, and what is not (honest, per D12)

| Claim | Verified how | Verified where |
| --- | --- | --- |
| systemd unit is syntactically valid and self-consistent | `systemd-analyze verify` | CI (`ci.yml`), after installing a real binary at `/usr/local/bin/m2cloud` |
| systemd unit actually supervises the agent (restart on crash, `StateDirectory` permissions, hardening does not break startup) | manual run on a systemd host | **not verified in CI** — no systemd container/VM in this pipeline |
| rc.d script is syntactically valid `sh` | `sh -n` | CI (`ci.yml`) |
| rc.d script actually supervises the agent under FreeBSD (`daemon(8)` behaviour, user/permissions, `service ... stop` signal delivery, log rotation) | — | **not verified in CI** (ADR-014, D12): GitHub Actions has no native FreeBSD runner. The plan's `vmactions/freebsd-vm` smoke test (per-release `version`/`config validate`/`doctor`/`run` startup) covers the binary itself, not the rc.d supervision path. This closes against a real FreeBSD host (or a local VM) at the first FreeBSD beta customer, per ADR-014's trigger. |
| Docker image builds and the binary runs inside it (`version`, `config validate`) | `docker build` + `docker run --entrypoint ... version` | CI (`ci.yml`), when the runner permits Docker-in-Docker in reasonable time |
| Docker image under real supervision (`restart: unless-stopped`, graceful `SIGTERM` shutdown, volume persistence across recreation) | — | **not verified in CI** |
| Release binaries are reproducible byte-for-byte across two builds | `sha256sum` comparison of two `make release` runs | local verification (see the PR's report) and `make release` itself is exercised in CI with an ephemeral signing key |

Nothing above should be read as "packaging is production-hardened." It is the packaging that
satisfies the M2C-013A ticket's contract; the rc.d and systemd supervision paths get their first
real-world exercise in the beta rollout.
