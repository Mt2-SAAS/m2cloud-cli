# Quickstart

From zero to a connected agent in five commands.

## 1. Install

```sh
curl -fsSL https://mt2-saas.github.io/m2cloud-cli/install.sh | sh
```

## 2. Create the config

```sh
mkdir -p /etc/m2cloud /var/lib/m2cloud /etc/m2cloud/secrets
curl -fsSLO https://github.com/Mt2-SAAS/m2cloud-cli/releases/latest/download/m2cloud.example.toml
mv m2cloud.example.toml /etc/m2cloud/m2cloud.toml
```

Put each database password in its own file, mode 0600:

```sh
printf '%s' 'your-account-db-password' > /etc/m2cloud/secrets/account_password
printf '%s' 'your-player-db-password'  > /etc/m2cloud/secrets/player_password
chmod 600 /etc/m2cloud/secrets/*
```

Edit `/etc/m2cloud/m2cloud.toml`: set `api_endpoint` and the database
credentials.

## 3. Validate

```sh
m2cloud config validate /etc/m2cloud/m2cloud.toml
```

## 4. Pair

Grab a pairing token from the owner console (server → Connection), then:

```sh
m2cloud pair <pairing-token> --config /etc/m2cloud/m2cloud.toml
```

The command generates the installation's Ed25519 key pair under `data_dir`,
registers it with the control plane, and stores the non-sensitive identity
metadata. It prints the installation id — never the token, never the key.

## 5. Run

```sh
m2cloud run --config /etc/m2cloud/m2cloud.toml
```

The agent dials the control plane over `wss://` (outbound only) and stays
connected. Confirm the console shows the server as **connected**.

## Next

- Diagnose problems with [`m2cloud doctor`](commands.md#doctor)
- Read the [command channel](channel.md) design
- Harden the setup in [Security](security.md)
