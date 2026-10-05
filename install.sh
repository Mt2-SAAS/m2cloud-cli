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
# Environment overrides:
#   M2_DOWNLOAD_BASE  release download base (default: the public repo's latest)
#   M2_INSTALL_DIR    install prefix (default: /usr/local/bin, or ~/.local/bin)
#   M2_BIN_NAME       binary name (default: m2cloud)
set -eu

DOWNLOAD_BASE="${M2_DOWNLOAD_BASE:-https://github.com/Mt2-SAAS/m2cloud-cli/releases/latest/download}"
INSTALL_DIR="${M2_INSTALL_DIR:-}"
BIN_NAME="${M2_BIN_NAME:-m2cloud}"

fail() { printf 'm2cloud-installer: %s\n' "$1" >&2; exit 1; }

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

"$INSTALL_DIR/$BIN_NAME" version
printf '==> done. Next: %s pair <token>\n' "$BIN_NAME"
