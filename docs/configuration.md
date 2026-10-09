# Configuration

Every command takes `--config <path.toml>` explicitly — there is **no default
path**. Start from the annotated example shipped with every release:

```sh
curl -fsSLO https://github.com/Mt2-SAAS/m2cloud-cli/releases/latest/download/m2cloud.example.toml
```

Then validate before first use:

```sh
m2cloud config validate m2cloud.example.toml
```

## Reference

```toml
[agent]
# Local state directory: identity.json, identity.key (0600) and the
# idempotency store. Absolute path, owned by the service account.
data_dir = "/var/lib/m2cloud"

# One of: DEBUG, INFO, WARN, ERROR, CRITICAL.
log_level = "INFO"

# The Control API this installation pairs and talks to. Absolute https:// URL
# (http:// is only accepted for loopback hosts: localhost, 127.0.0.1, ::1).
# `m2cloud pair --endpoint ...` overrides it; there is no default host.
api_endpoint = "https://api.m2cloud.example"

[database.account]
# The Metin2 account database (accounts, login).
host = "127.0.0.1"
port = 3306
database = "account"
user = "m2cloud_account"
password_file = "/etc/m2cloud/secrets/account_password"

[database.player]
# The Metin2 player database (characters, guilds, rankings).
host = "127.0.0.1"
port = 3306
database = "player"
user = "m2cloud_player"
password_file = "/etc/m2cloud/secrets/player_password"
```

## Secret sources

Each database section sets its password through **exactly one** of:

| Key | Use for |
|---|---|
| `password_file` | preferred — a file, mode 0600, read at connect time |
| `password_env` | containers / systemd `LoadCredential`-style setups |
| `password` | local tests only — the validator warns about it |

Secrets never go on the command line: a flag value ends up in the shell
history and in the process table. `config validate` checks that a referenced
file exists and is not readable by group/others, and never prints a secret
value.

## Prefixes

If your serverfile uses prefixed database names (`srv1_account`,
`srv1_player`), put the full name in `database` — the adapter detects the
schema from what it finds, and both conventions are supported.

## Validation rules

`config validate` fails when:

- the TOML is malformed or a section is missing;
- `api_endpoint` is not an absolute `https://` URL (loopback `http://`
  excepted);
- a `password_file` does not exist or is group/world-readable;
- more than one secret source is set in the same section.
