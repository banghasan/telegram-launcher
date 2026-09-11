#!/usr/bin/env bash

set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
launcher="$test_dir/../tg-launcher.sh"
tmp_dir=$(mktemp -d)
fake_bin="$tmp_dir/fake-telegram"
workdir="$tmp_dir/workdir"
state_dir="$tmp_dir/state"
config_state_dir="$tmp_dir/config-state"
log_file="$tmp_dir/telegram.log"
config_dir="$tmp_dir/config"
config_file="$config_dir/config"
local_launcher_dir="$tmp_dir/local-launcher"
local_launcher="$local_launcher_dir/tg-launcher.sh"
local_workdir="$tmp_dir/local-workdir"
user_config_dir="$tmp_dir/user-config"
user_config_file="$user_config_dir/tg-launcher/config"
telegram_pid=""

cleanup() {
    if [[ -n "$telegram_pid" ]]; then
        kill "$telegram_pid" 2>/dev/null || true
        wait "$telegram_pid" 2>/dev/null || true
    fi
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

mkdir -p -- "$workdir" "$config_dir" "$local_launcher_dir" "$local_workdir" "$user_config_dir/tg-launcher"

cat >"$fake_bin" <<'FAKE_TELEGRAM'
#!/usr/bin/env bash
printf '%s\n' "${DESKTOPINTEGRATION-}" >"${FAKE_TELEGRAM_ENV_FILE:?}"
trap 'exit 0' INT TERM
while :; do
    sleep 1
done
FAKE_TELEGRAM
chmod 755 "$fake_bin"

cp -- "$launcher" "$local_launcher"
chmod 755 "$local_launcher"

cat >"$user_config_file" <<USER_CONFIG
TELEGRAM_BIN=/path/yang/tidak/ada
TG_LOG=$tmp_dir/user.log
USER_CONFIG
chmod 600 "$user_config_file"

cat >"$local_launcher_dir/tg-launcher.conf" <<LOCAL_CONFIG
TELEGRAM_BIN=$fake_bin
TG_LOG=$tmp_dir/local.log
LOCAL_CONFIG
chmod 600 "$local_launcher_dir/tg-launcher.conf"

cat >"$config_file" <<CONFIG
TELEGRAM_BIN=$fake_bin
TG_LOG=$tmp_dir/config.log
LOG_MAX_BYTES=5242880
LOG_BACKUPS=3
DESKTOP_INTEGRATION=1
CONFIG
chmod 600 "$config_file"

run_launcher() {
    TELEGRAM_BIN="$fake_bin" \
    TG_LOG="$log_file" \
    FAKE_TELEGRAM_ENV_FILE="$tmp_dir/desktop-integration.env" \
    XDG_STATE_HOME="$state_dir" \
    "$launcher" "$@"
}

run_config_launcher() {
    FAKE_TELEGRAM_ENV_FILE="$tmp_dir/desktop-integration-config.env" \
    TG_CONFIG="$config_file" \
    XDG_STATE_HOME="$config_state_dir" \
    "$launcher" "$@"
}

extract_pid() {
    awk '/PID proses/ { print $NF; exit }'
}

run_launcher --version >/dev/null
run_launcher --check "$workdir" >/dev/null
run_launcher --dry-run "$workdir" >/dev/null
plain_output=$(run_launcher --dry-run "$workdir")
[[ "$plain_output" != *$'\033['* ]]
colored_output=$(run_launcher --color always --dry-run "$workdir")
[[ "$colored_output" == *$'\033['* ]]
no_color_output=$(run_launcher --color always --no-color --dry-run "$workdir")
[[ "$no_color_output" != *$'\033['* ]]

config_check=$(run_config_launcher check "$workdir")
grep -q "Executable       : $fake_bin" <<<"$config_check"

local_config_check=$(TG_CONFIG="" \
    XDG_CONFIG_HOME="$user_config_dir" \
    XDG_STATE_HOME="$tmp_dir/local-state" \
    "$local_launcher" check "$local_workdir")
grep -q "Executable       : $fake_bin" <<<"$local_config_check"

launch_output=$(run_launcher start "$workdir")
telegram_pid=$(printf '%s\n' "$launch_output" | extract_pid)
[[ "$telegram_pid" =~ ^[0-9]+$ ]]
grep -qx '1' "$tmp_dir/desktop-integration.env"

status_output=$(run_launcher --status "$workdir")
grep -q 'Telegram sedang berjalan' <<<"$status_output"

status_with_missing_binary=$(TELEGRAM_BIN=/path/yang/tidak/ada \
    TG_LOG="$log_file" \
    XDG_STATE_HOME="$state_dir" \
    "$launcher" status "$workdir")
grep -q 'Telegram sedang berjalan' <<<"$status_with_missing_binary"

if run_launcher start "$workdir" >/dev/null 2>&1; then
    printf '%s\n' 'Test gagal: duplicate launch seharusnya ditolak.' >&2
    exit 1
fi

logs_output=$(run_launcher logs "$workdir")
grep -q 'Menampilkan 100 baris log terakhir' <<<"$logs_output"

run_launcher stop "$workdir" >/dev/null
if run_launcher status "$workdir" >/dev/null 2>&1; then
    printf '%s\n' 'Test gagal: status seharusnya tidak berjalan.' >&2
    exit 1
fi
telegram_pid=""

auto_workdir="$tmp_dir/auto-workdir"
auto_state_dir="$tmp_dir/auto-state"
mkdir -p -- "$auto_workdir"
auto_output=$(TELEGRAM_BIN="$fake_bin" \
    FAKE_TELEGRAM_ENV_FILE="$tmp_dir/desktop-integration-auto.env" \
    XDG_STATE_HOME="$auto_state_dir" \
    "$launcher" start "$auto_workdir")
telegram_pid=$(printf '%s\n' "$auto_output" | extract_pid)
[[ "$telegram_pid" =~ ^[0-9]+$ ]]
auto_log_file=$(find "$auto_state_dir" -type f -name '*.log' -print -quit)
[[ -n "$auto_log_file" ]]
TELEGRAM_BIN="$fake_bin" \
    XDG_STATE_HOME="$auto_state_dir" \
    "$launcher" stop "$auto_workdir" >/dev/null
telegram_pid=""

no_desktop_workdir="$tmp_dir/no-desktop-workdir"
mkdir -p -- "$no_desktop_workdir"
no_desktop_output=$(run_launcher --no-desktop-integration start "$no_desktop_workdir")
telegram_pid=$(printf '%s\n' "$no_desktop_output" | extract_pid)
[[ "$telegram_pid" =~ ^[0-9]+$ ]]
[[ "$(<"$tmp_dir/desktop-integration.env")" == "" ]]
run_launcher stop "$no_desktop_workdir" >/dev/null
telegram_pid=""

printf '0123456789' >"$log_file"
restart_output=$(LOG_MAX_BYTES=1 LOG_BACKUPS=2 run_launcher restart "$workdir" 2>&1)
telegram_pid=$(printf '%s\n' "$restart_output" | extract_pid)
[[ "$telegram_pid" =~ ^[0-9]+$ ]]
[[ -f "$log_file.1" ]]
run_launcher stop "$workdir" >/dev/null
telegram_pid=""

printf '%s\n' 'Semua test tg-launcher berhasil.'
