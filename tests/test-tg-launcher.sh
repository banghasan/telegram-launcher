#!/usr/bin/env bash

set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
launcher="$test_dir/../tg-launcher.sh"
tmp_dir=$(mktemp -d)
fake_bin="$tmp_dir/fake-telegram"
workdir="$tmp_dir/workdir"
state_dir="$tmp_dir/state"
log_file="$tmp_dir/telegram.log"

cleanup() {
    if [[ -n "${telegram_pid:-}" ]]; then
        kill "$telegram_pid" 2>/dev/null || true
        wait "$telegram_pid" 2>/dev/null || true
    fi
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

mkdir -p -- "$workdir"

cat >"$fake_bin" <<'FAKE_TELEGRAM'
#!/usr/bin/env bash
trap 'exit 0' INT TERM
while :; do
    sleep 1
done
FAKE_TELEGRAM
chmod 755 "$fake_bin"

run_launcher() {
    TELEGRAM_BIN="$fake_bin" \
    TG_LOG="$log_file" \
    XDG_STATE_HOME="$state_dir" \
    "$launcher" "$@"
}

run_launcher --version >/dev/null
run_launcher --check "$workdir" >/dev/null
run_launcher --dry-run "$workdir" >/dev/null

launch_output=$(run_launcher "$workdir")
telegram_pid=$(printf '%s\n' "$launch_output" | awk '/PID:/ { print $NF; exit }')
[[ "$telegram_pid" =~ ^[0-9]+$ ]]

status_output=$(run_launcher --status "$workdir")
grep -q 'Status: berjalan' <<<"$status_output"

if run_launcher "$workdir" >/dev/null 2>&1; then
    printf '%s\n' 'Test gagal: duplicate launch seharusnya ditolak.' >&2
    exit 1
fi

kill "$telegram_pid"
for _ in {1..20}; do
    if ! run_launcher --status "$workdir" >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.1
done

printf '%s\n' 'Test gagal: status tidak berubah menjadi tidak berjalan.' >&2
exit 1
