# Running as a service

`m2cloud run` never daemonizes: it stays in the foreground, reconnects on its
own, and expects the host's supervisor to restart it on crash and deliver
`SIGTERM` on shutdown. Ship one of these supervision models — the artifacts
are installed as-is, not copied as starting examples.

## systemd (Linux)

```sh
sudo useradd --system --home-dir /var/lib/m2cloud --shell /usr/sbin/nologin m2cloud
sudo install -m 0755 m2cloud /usr/local/bin/m2cloud
sudo mkdir -p /etc/m2cloud
sudo install -m 0640 -o root -g m2cloud agent.toml /etc/m2cloud/agent.toml
sudo install -m 0644 packaging/systemd/m2cloud-agent.service /etc/systemd/system/m2cloud-agent.service
sudo systemctl daemon-reload
sudo systemctl enable --now m2cloud-agent
```

`StateDirectory=m2cloud` makes systemd create and own `/var/lib/m2cloud`
(mode 0700); the installation identity is written there by `pair`/`run` under
the `m2cloud` user. The unit is hardened (`NoNewPrivileges`,
`ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`, dropped capability set,
restricted syscall filter).

**Update:** replace the binary and restart — the identity lives in the state
directory, not in the binary, so no re-pairing:

```sh
sudo install -m 0755 m2cloud-new /usr/local/bin/m2cloud
sudo systemctl restart m2cloud-agent
```

## rc.d (FreeBSD)

```sh
sudo install -m 0755 m2cloud /usr/local/bin/m2cloud
sudo install -m 0755 packaging/freebsd-rc.d/m2cloud_agent /usr/local/etc/rc.d/m2cloud_agent
# /etc/rc.conf:
#   m2cloud_agent_enable="YES"
#   m2cloud_agent_config="/etc/m2cloud/m2cloud.toml"
sudo service m2cloud_agent start
```

## Docker / Podman

```sh
docker build -f packaging/docker/Dockerfile -t m2cloud-agent .
docker compose -f packaging/docker/docker-compose.example.yml up -d
```

The agent still connects **outbound only** — no ports published.
