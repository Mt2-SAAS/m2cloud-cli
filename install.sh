#!/bin/sh
#
# m2cloud CLI installer (POSIX sh; FreeBSD / Linux).
#
# One-line install:
#   curl -fsSL https://Mt2-SAAS.github.io/m2cloud-cli/install.sh | sh
# or, equivalently:
#   fetch -o - https://Mt2-SAAS.github.io/m2cloud-cli/install.sh | sh
#
# Downloads the release binary for the detected GOOS/GOARCH from the PUBLIC
# m2cloud-cli repo (GitHub Releases), verifies it against the release's
# checksums.txt, and installs it to /usr/local/bin/m2cloud (root) or
# ~/.local/bin (unprivileged, with a PATH warning).
#
# Needs config too? `sh install.sh --with-config` additionally creates
# /etc/m2cloud/agent.toml (Linux) or /usr/local/etc/m2cloud/agent.toml
# (FreeBSD) from the release's annotated example plus empty password secret
# files — everything the agent needs except the secrets' contents and the
# control-plane URL the user fills in after install.
#
# Environment overrides:
#   M2_DOWNLOAD_BASE  release download base (default: the public repo's latest)
#   M2_INSTALL_DIR    install prefix (default: /usr/local/bin, or ~/.local/bin)
#   M2_BIN_NAME       binary name (default: m2cloud)
#   M2_SKIP_CONFIG=1  disable the default local config layout (see below)
set -eu

DOWNLOAD_BASE="${M2_DOWNLOAD_BASE:-https://github.com/Mt2-SAAS/m2cloud-cli/releases/latest/download}"
INSTALL_DIR="${M2_INSTALL_DIR:-}"
BIN_NAME="${M2_BIN_NAME:-m2cloud}"

fail() { printf 'm2cloud-installer: %s\n' "$1" >&2; exit 1; }

# ── flag parsing ─────────────────────────────────────────────────────────────
WITH_CONFIG=0
if [ $# -gt 0 ]; then
  case "$1" in
    --with-config) WITH_CONFIG=1; shift ;;
    --help|-h)
      printf 'usage: sh %s [--with-config]\n' "$0"
      printf '  --with-config  also create the config directory, agent.toml and empty secret files\n'
      exit 0
      ;;
    *) fail "unknown argument: $1 (try --with-config)" ;;
  esac
fi

# ── platform detection ───────────────────────────────────────────────────────
GOOS=$(uname -s | tr '[:upper:]' '[:lower:]')
GOARCH=$(uname -m)
case "$GOOS" in
  freebsd|linux) ;;
  *) fail "unsupported OS: $(uname -s) (supported: FreeBSD, Linux)" ;;
esac
case "$GOARCH" in
  amd64|x86_64) GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) fail "unsupported architecture: $GOARCH (supported: amd64, arm64)" ;;
esac
ASSET="${BIN_NAME}-${GOOS}-${GOARCH}"

# ── download helper (curl preferred; fetch is FreeBSD base) ──────────────────
download() { # download <url> <dest>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v fetch >/dev/null 2>&1; then
    fetch -q -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fail "need curl, fetch or wget to download"
  fi
}

# ── sha256 helper (FreeBSD: sha256; Linux: sha256sum; macOS fallback: shasum) ─
verify_sha256() { # verify_sha256 <file> <expected>
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s  %s\n' "$2" "$1" | sha256sum -c - >/dev/null 2>&1
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s  %s\n' "$2" "$1" | shasum -a 256 -c - >/dev/null 2>&1
  elif command -v sha256 >/dev/null 2>&1; then
    [ "$2" = "$(sha256 -q "$1")" ]
  else
    fail "need sha256sum, shasum or sha256 to verify the download"
  fi
}

# ── privilege / install dir ──────────────────────────────────────────────────
SUDO=""
if [ "$(id -u)" != 0 ]; then
  if command -v doas >/dev/null 2>&1; then SUDO=doas
  elif command -v sudo >/dev/null 2>&1; then SUDO=sudo
  fi
fi
if [ -z "$INSTALL_DIR" ]; then
  if [ "$(id -u)" = 0 ] || [ -n "$SUDO" ]; then
    INSTALL_DIR=/usr/local/bin
  else
    INSTALL_DIR="${HOME}/.local/bin"
  fi
fi

# ── config layout (only with --with-config) ────────────────────────────────
# Root install: /etc/m2cloud (Linux) or /usr/local/etc/m2cloud (FreeBSD).
# Unprivileged install: ~/.config/m2cloud (XDG). No elevation for this part,
# and the paths inside the TOML are rewritten to match where files were
# actually created.
CONFIG_DIR=""
TOML_PATH=""
SECRETS_DIR=""
STATE_DIR=""
if [ "$WITH_CONFIG" = 1 ]; then
  if [ "$(id -u)" = 0 ]; then
    case "$GOOS" in
      linux)   CONFIG_DIR=/etc/m2cloud ;;
      freebsd) CONFIG_DIR=/usr/local/etc/m2cloud ;;
    esac
  else
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/m2cloud"
  fi
  TOML_PATH="$CONFIG_DIR/agent.toml"
  SECRETS_DIR="$CONFIG_DIR/secrets"
  STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/m2cloud"
  if [ "$(id -u)" = 0 ]; then STATE_DIR=/var/lib/m2cloud; fi
fi

# ── download + verify ────────────────────────────────────────────────────────
TMP=$(mktemp -d) || fail "mktemp failed"
trap 'rm -rf "$TMP"' EXIT INT TERM

printf '==> downloading %s\n' "$ASSET"
download "$DOWNLOAD_BASE/$ASSET" "$TMP/$ASSET" || fail "download failed: $DOWNLOAD_BASE/$ASSET"
download "$DOWNLOAD_BASE/checksums.txt" "$TMP/checksums.txt" || fail "download failed: checksums.txt"

EXPECTED=$(grep " $ASSET\$" "$TMP/checksums.txt" | awk '{print $1}')
[ -n "$EXPECTED" ] || fail "no checksum entry for $ASSET in checksums.txt"
printf '==> verifying sha256\n'
verify_sha256 "$TMP/$ASSET" "$EXPECTED" || fail "checksum mismatch for $ASSET — do NOT use this download"

if [ "$WITH_CONFIG" = 1 ]; then
  download "$DOWNLOAD_BASE/m2cloud.example.toml" "$TMP/m2cloud.example.toml" \
    || fail "download failed: m2cloud.example.toml"
fi

# ── install ──────────────────────────────────────────────────────────────────
printf '==> installing to %s/%s\n' "$INSTALL_DIR" "$BIN_NAME"
mkdir -p "$INSTALL_DIR" || fail "cannot create $INSTALL_DIR"
# Only elevate when the target directory is not writable by the current user
# (a user-specified M2_INSTALL_DIR or ~/.local/bin must not require root).
if [ ! -w "$INSTALL_DIR" ] || { [ -e "$INSTALL_DIR/$BIN_NAME" ] && [ ! -w "$INSTALL_DIR/$BIN_NAME" ]; }; then
  [ -n "$SUDO" ] || [ "$(id -u)" = 0 ] || fail "no write access to $INSTALL_DIR and no doas/sudo available"
  $SUDO install -m 0755 "$TMP/$ASSET" "$INSTALL_DIR/$BIN_NAME" || fail "install failed"
else
  install -m 0755 "$TMP/$ASSET" "$INSTALL_DIR/$BIN_NAME" || fail "install failed"
fi

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) printf 'warning: %s is not in your PATH\n' "$INSTALL_DIR" >&2 ;;
esac

# ── write config skeleton + empty secrets (only with --with-config) ─────────
if [ "$WITH_CONFIG" = 1 ]; then
  # Elevate only when the target is not writable by the current user — with
  # M2_INSTALL_DIR pointed at a writable dir + root-owned XDG_CONFIG_HOME the
  # whole skeleton creation needs no sudo at all.
  M=""
  if ! mkdir -p "$SECRETS_DIR" "$STATE_DIR" 2>/dev/null; then
    [ -n "$SUDO" ] || [ "$(id -u)" = 0 ] || fail "no write access to $CONFIG_DIR and no doas/sudo available"
    $SUDO mkdir -p "$SECRETS_DIR" "$STATE_DIR" || fail "cannot create $CONFIG_DIR"
    M="$SUDO"
  fi

  # Rewrite the skeleton's paths to where files were actually created. The
  # example's paths are the Linux defaults; on FreeBSD both the config dir and
  # the secret paths must move to /usr/local/etc/m2cloud, and data_dir to the
  # real state dir. sed handles the simple global ones; the two password_file
  # lines get their per-database paths from awk (portable on FreeBSD base).
  $M install -m 0644 "$TMP/m2cloud.example.toml" "$TOML_PATH.tmp" || fail "cannot stage agent.toml"
  $M sed -i \
    -e "s|data_dir = \"[^\"]*\"|data_dir = \"$STATE_DIR\"|" \
    -e "s|api_endpoint = \"[^\"]*\"|api_endpoint = \"https://YOUR-M2CLOUD-ENDPOINT.example\"|" \
    -e "s|password_file = \"[^\"]*account_password\"|password_file = \"$SECRETS_DIR/account_password\"|" \
    -e "s|password_file = \"[^\"]*player_password\"|password_file = \"$SECRETS_DIR/player_password\"|" \
    "$TOML_PATH.tmp" || fail "cannot rewrite agent.toml"
  $M mv "$TOML_PATH.tmp" "$TOML_PATH"

  for SPEC in account:account_password player:player_password; do
    srv=${SPEC%%:*}; name=${SPEC#*:}
    if [ -s "$SECRETS_DIR/$name" ]; then
      printf '   (keeping existing non-empty secrets/%s)\n' "$name"
    elif [ -e "$SECRETS_DIR/$name" ]; then
      # exists but empty: fine, that is exactly the skeleton state
      printf '   secrets/%s exists (empty, ready for your password)\n' "$name"
    else
      $M install -m 0600 /dev/null "$SECRETS_DIR/$name" || fail "cannot create $SECRETS_DIR/$name"
      printf '   created secrets/%s (empty — write your password into it)\n' "$name"
    fi
  done

  # Validate the skeleton with the binary we just installed: the empty secret
  # files make it valid; a wrong rewrite would fail loudly here.
  "$INSTALL_DIR/$BIN_NAME" config validate "$TOML_PATH" \
    || fail "config skeleton self-validation failed — inspect $TOML_PATH"
  printf '==> config skeleton OK (validate passed)\n'

  cat <<NNN

Config created. What is left for you:
  1. Edit $TOML_PATH: set agent.api_endpoint to your control plane URL.
  2. Write the DB passwords into the secret files (mode 0600 already set):
       $SECRETS_DIR/account_password
       $SECRETS_DIR/player_password
  3. Pair the agent with your control plane token:
       $INSTALL_DIR/$BIN_NAME pair <token> --config $TOML_PATH
NNN
fi

"$INSTALL_DIR/$BIN_NAME" version
printf '==> done. Next: %s pair <token>\n' "$BIN_NAME"
