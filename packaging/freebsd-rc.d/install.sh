#!/bin/sh
#
# Guided installer for the m2cloud agent on FreeBSD.
#
# Usage (as root, from a checkout or an unpacked release directory):
#
#   sh packaging/freebsd-rc.d/install.sh [path/to/m2cloud]
#
# Asks for the Control API endpoint, database settings, database password and
# pairing token; creates the `m2cloud` service user, installs the binary,
# config, secrets and rc.d script; pairs; runs `m2cloud doctor`. It does NOT
# enable or start the service: that stays the operator's explicit action.
#
# Safe to re-run: an existing agent.toml is backed up before it is replaced.

set -eu

SVC_USER="m2cloud"
BIN_DST="/usr/local/bin/m2cloud"
ETC_DIR="/usr/local/etc/m2cloud"
SECRETS_DIR="${ETC_DIR}/secrets"
CONFIG="${ETC_DIR}/agent.toml"
DATA_DIR="/var/db/m2cloud"
RCD_DST="/usr/local/etc/rc.d/m2cloud_agent"
RELEASE_REPO="Mt2-SAAS/m2cloud-cli"
ASSET="m2cloud-freebsd-amd64"
RELEASE_URL="https://github.com/${RELEASE_REPO}/releases/latest/download"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RCD_SRC="${SCRIPT_DIR}/m2cloud_agent"

STAGE_DIR=""
TOKEN_FILE=""
TTY_ECHO_OFF=0

die()
{
	printf 'error: %s\n' "$*" >&2
	exit 1
}

info()
{
	printf '==> %s\n' "$*"
}

cleanup()
{
	if [ "$TTY_ECHO_OFF" -eq 1 ]; then
		stty echo 2>/dev/null || true
	fi
	if [ -n "$TOKEN_FILE" ]; then
		rm -f "$TOKEN_FILE"
	fi
	if [ -n "$STAGE_DIR" ]; then
		rm -rf "$STAGE_DIR"
	fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ask PROMPT DEFAULT -> sets ANSWER (empty input = DEFAULT).
ask()
{
	if [ -n "$2" ]; then
		printf '%s [%s]: ' "$1" "$2"
	else
		printf '%s: ' "$1"
	fi
	read -r ANSWER || die "no input (stdin closed)"
	if [ -z "$ANSWER" ]; then
		ANSWER=$2
	fi
}

# ask_secret PROMPT -> sets ANSWER without echoing the input.
ask_secret()
{
	printf '%s: ' "$1"
	if [ -t 0 ]; then
		stty -echo
		TTY_ECHO_OFF=1
	fi
	if ! read -r ANSWER; then
		die "no input (stdin closed)"
	fi
	if [ "$TTY_ECHO_OFF" -eq 1 ]; then
		stty echo
		TTY_ECHO_OFF=0
	fi
	printf '\n'
}

# yes_no PROMPT -> returns 0 on yes (default), 1 on no.
yes_no()
{
	printf '%s [Y/n]: ' "$1"
	read -r ANSWER || die "no input (stdin closed)"
	case "$ANSWER" in
	"" | [Yy] | [Yy][Ee][Ss]) return 0 ;;
	*) return 1 ;;
	esac
}

# Values are interpolated into TOML basic strings; keep them free of
# characters that would need escaping.
toml_safe()
{
	case "$1" in
	*'"'* | *'\'* ) return 1 ;;
	esac
	return 0
}

# --- 1. Preflight -----------------------------------------------------------

[ "$(uname -s)" = "FreeBSD" ] || die "this installer only supports FreeBSD (found $(uname -s))"
[ "$(id -u)" -eq 0 ] || die "must run as root (try: sudo sh $0)"
[ -f "$RCD_SRC" ] || die "rc.d script not found next to the installer: $RCD_SRC"

BIN_SRC=""
if [ $# -ge 1 ] && [ -n "$1" ]; then
	[ -f "$1" ] || die "binary not found: $1"
	BIN_SRC=$1
elif [ -f ./m2cloud ]; then
	BIN_SRC=./m2cloud
elif [ -f "$BIN_DST" ]; then
	BIN_SRC=$BIN_DST
fi

if [ -z "$BIN_SRC" ]; then
	if [ "$(uname -m)" != "amd64" ]; then
		die "no m2cloud binary found and no prebuilt release exists for $(uname -m); build it and pass its path: sh $0 /path/to/m2cloud"
	fi
	info "No m2cloud binary found (looked at ./m2cloud and ${BIN_DST})."
	if ! yes_no "Download the latest ${ASSET} from github.com/${RELEASE_REPO}?"; then
		die "no binary; download it from ${RELEASE_URL}/${ASSET} and pass its path: sh $0 /path/to/m2cloud"
	fi
	STAGE_DIR=$(mktemp -d -t m2cloud-install) || die "cannot create a staging directory"
	fetch -o "${STAGE_DIR}/${ASSET}" "${RELEASE_URL}/${ASSET}" || die "download failed: ${RELEASE_URL}/${ASSET}"
	fetch -o "${STAGE_DIR}/checksums.txt" "${RELEASE_URL}/checksums.txt" || die "download failed: ${RELEASE_URL}/checksums.txt"
	expected=$(awk -v a="$ASSET" '$2 == a || $2 == "*" a { print $1; exit }' "${STAGE_DIR}/checksums.txt")
	[ -n "$expected" ] || die "checksums.txt has no entry for ${ASSET}"
	actual=$(sha256 -q "${STAGE_DIR}/${ASSET}") || die "cannot hash ${ASSET}"
	[ "$actual" = "$expected" ] || die "checksum mismatch for ${ASSET}; refusing to install it"
	chmod 0755 "${STAGE_DIR}/${ASSET}"
	BIN_SRC="${STAGE_DIR}/${ASSET}"
	info "Downloaded and verified ${ASSET}."
fi
info "Using binary: ${BIN_SRC}"

# --- 2. Interactive prompts -------------------------------------------------

printf '\nAnswer the questions below. Press Enter to accept the [default].\n\n'

while :; do
	ask "Control API endpoint (https://...)" ""
	case "$ANSWER" in
	https://?*)
		if toml_safe "$ANSWER"; then
			break
		fi
		echo "The endpoint must not contain quotes or backslashes."
		;;
	*) echo "The endpoint must start with https://" ;;
	esac
done
API_ENDPOINT=$ANSWER

while :; do
	ask "Database host" "127.0.0.1"
	if [ -n "$ANSWER" ] && toml_safe "$ANSWER"; then break; fi
	echo "Invalid host."
done
DB_HOST=$ANSWER

while :; do
	ask "Database port" "3306"
	case "$ANSWER" in
	"" | *[!0-9]*) echo "The port must be a number." ;;
	*)
		if [ "$ANSWER" -ge 1 ] && [ "$ANSWER" -le 65535 ]; then break; fi
		echo "The port must be between 1 and 65535."
		;;
	esac
done
DB_PORT=$ANSWER

while :; do
	ask "Account database name" "account"
	if [ -n "$ANSWER" ] && toml_safe "$ANSWER"; then break; fi
	echo "Invalid database name."
done
DB_ACCOUNT=$ANSWER

while :; do
	ask "Player database name" "player"
	if [ -n "$ANSWER" ] && toml_safe "$ANSWER"; then break; fi
	echo "Invalid database name."
done
DB_PLAYER=$ANSWER

while :; do
	ask "Database user (used for both databases)" "mt2"
	if [ -n "$ANSWER" ] && toml_safe "$ANSWER"; then break; fi
	echo "Invalid user name."
done
DB_USER=$ANSWER

while :; do
	ask_secret "Database password"
	if [ -z "$ANSWER" ]; then
		echo "The password must not be empty."
		continue
	fi
	DB_PASSWORD=$ANSWER
	ask_secret "Repeat the database password"
	if [ "$ANSWER" = "$DB_PASSWORD" ]; then break; fi
	echo "The passwords do not match; try again."
done
ANSWER=""

while :; do
	ask_secret "Pairing token"
	if [ -n "$ANSWER" ]; then break; fi
	echo "The pairing token must not be empty."
done
PAIR_TOKEN=$ANSWER
ANSWER=""

echo

# --- 3. Service user --------------------------------------------------------

if pw usershow "$SVC_USER" >/dev/null 2>&1; then
	USER_STATUS="already existed"
else
	info "Creating service user ${SVC_USER}"
	pw useradd "$SVC_USER" -d "$DATA_DIR" -s /usr/sbin/nologin -m || die "cannot create user ${SVC_USER}"
	USER_STATUS="created"
fi

# --- 4. Files ---------------------------------------------------------------

if [ "$BIN_SRC" != "$BIN_DST" ]; then
	info "Installing ${BIN_DST}"
	install -m 0755 "$BIN_SRC" "$BIN_DST" || die "cannot install ${BIN_DST}"
else
	chmod 0755 "$BIN_DST" || die "cannot chmod ${BIN_DST}"
fi

mkdir -p "$SECRETS_DIR" || die "cannot create ${SECRETS_DIR}"
chown root:"$SVC_USER" "$SECRETS_DIR" || die "cannot chown ${SECRETS_DIR}"
chmod 0750 "$SECRETS_DIR" || die "cannot chmod ${SECRETS_DIR}"

# write_secret DEST: writes $DB_PASSWORD plus one newline, 0600 m2cloud-owned.
# The umask makes the temp file 0600 from creation, so the password is never
# group/other-readable, not even transiently; printf is a builtin, so the
# password never appears in the process table.
write_secret()
{
	tmp="${1}.tmp.$$"
	rm -f "$tmp"
	(umask 077 && printf '%s\n' "$DB_PASSWORD" >"$tmp") || die "cannot write $1"
	chown "$SVC_USER":"$SVC_USER" "$tmp" || die "cannot chown $1"
	chmod 0600 "$tmp" || die "cannot chmod $1"
	mv -f "$tmp" "$1" || die "cannot install $1"
}

info "Writing database password files in ${SECRETS_DIR}"
write_secret "${SECRETS_DIR}/account_password"
write_secret "${SECRETS_DIR}/player_password"
DB_PASSWORD=""
unset DB_PASSWORD

if [ -f "$CONFIG" ]; then
	BACKUP="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
	cp -p "$CONFIG" "$BACKUP" || die "cannot back up ${CONFIG}"
	info "Existing config backed up to ${BACKUP}"
fi

info "Writing ${CONFIG}"
CONFIG_TMP="${CONFIG}.tmp.$$"
(
	umask 077
	cat >"$CONFIG_TMP" <<EOF
# m2cloud agent configuration — generated by install.sh on $(date)

[agent]
data_dir = "${DATA_DIR}"
log_level = "INFO"
api_endpoint = "${API_ENDPOINT}"

[database.account]
host = "${DB_HOST}"
port = ${DB_PORT}
database = "${DB_ACCOUNT}"
user = "${DB_USER}"
password_file = "${SECRETS_DIR}/account_password"

[database.player]
host = "${DB_HOST}"
port = ${DB_PORT}
database = "${DB_PLAYER}"
user = "${DB_USER}"
password_file = "${SECRETS_DIR}/player_password"
EOF
) || die "cannot write ${CONFIG}"
install -m 0640 -o root -g "$SVC_USER" "$CONFIG_TMP" "$CONFIG" || die "cannot install ${CONFIG}"
rm -f "$CONFIG_TMP"

info "Installing ${RCD_DST}"
install -m 0555 "$RCD_SRC" "$RCD_DST" || die "cannot install ${RCD_DST}"

mkdir -p "$DATA_DIR" || die "cannot create ${DATA_DIR}"
chown -R "$SVC_USER":"$SVC_USER" "$DATA_DIR" || die "cannot chown ${DATA_DIR}"
FILES_STATUS="installed"

# --- 5. Pair ----------------------------------------------------------------

# The token goes through a 0600 temp file readable only by the service user:
# never on the command line (shell history, process table).
TOKEN_FILE=$(mktemp -t m2cloud-token) || die "cannot create a temp file for the token"
chmod 0600 "$TOKEN_FILE"
printf '%s\n' "$PAIR_TOKEN" >"$TOKEN_FILE"
PAIR_TOKEN=""
unset PAIR_TOKEN
chown "$SVC_USER" "$TOKEN_FILE" || die "cannot chown the token file"

info "Pairing with ${API_ENDPOINT}"
if su -m "$SVC_USER" -c "${BIN_DST} pair --token-file ${TOKEN_FILE} --config ${CONFIG}"; then
	PAIR_RC=0
else
	PAIR_RC=$?
	echo "Pairing FAILED (exit ${PAIR_RC}); running doctor anyway to help find the cause." >&2
fi
rm -f "$TOKEN_FILE"
TOKEN_FILE=""

# --- 6. Doctor --------------------------------------------------------------

info "Running m2cloud doctor"
if su -m "$SVC_USER" -c "${BIN_DST} doctor --config ${CONFIG}"; then
	DOCTOR_RC=0
else
	DOCTOR_RC=$?
fi

# --- 7. Summary -------------------------------------------------------------

status_of()
{
	if [ "$1" -eq 0 ]; then echo "ok"; else echo "FAILED (exit $1)"; fi
}

cat <<EOF

================ m2cloud install summary ================
  Service user ${SVC_USER} : ${USER_STATUS}
  Files                : ${FILES_STATUS}
  Pair                 : $(status_of "$PAIR_RC")
  Doctor               : $(status_of "$DOCTOR_RC")

  Config   : ${CONFIG}
  Secrets  : ${SECRETS_DIR}
  Data dir : ${DATA_DIR}
  Status   : service m2cloud_agent status
=========================================================
EOF

if [ "$PAIR_RC" -eq 0 ] && [ "$DOCTOR_RC" -eq 0 ]; then
	cat <<EOF

Everything checks out. The service is installed but NOT enabled.
To enable and start it, run:

    sysrc m2cloud_agent_enable=YES
    service m2cloud_agent start

EOF
	exit 0
fi

cat <<EOF

Some steps failed (see the output above). Fix the cause and re-run this
installer; it is safe to re-run (the current agent.toml is backed up first).

Once pair and doctor succeed, enable and start the service with:

    sysrc m2cloud_agent_enable=YES
    service m2cloud_agent start

EOF
exit 1
