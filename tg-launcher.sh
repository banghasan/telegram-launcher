#!/usr/bin/env bash

# Telegram Bash Launcher

set -u
set -o pipefail

# ===== Konfigurasi =====
# Dapat dioverride tanpa mengubah file:
# TELEGRAM_BIN=/path/ke/Telegram TG_LOG=/path/telegram.log ./tg-launcher.sh /path/workdir
readonly TELEGRAM_BIN="${TELEGRAM_BIN:-/home/banghasan/bin/Telegram}"
readonly TG_LOG="${TG_LOG:-/dev/null}"
# =======================

readonly PROGRAM="TBL"
readonly DESCRIPTION="Telegram Bash Launcher"
readonly VERSION="1.2.0"
readonly RELEASE="11 September 2026"
readonly AUTHOR="bangHasan <banghasan@gmail.com>"
readonly WEBSITE="https://www.banghasan.com"
readonly CHANNEL="Telegram Grup @botIndonesia"

script_source="${BASH_SOURCE[0]}"
script_dir=$(cd -- "$(dirname -- "$script_source")" && pwd -P) || exit 1
readonly SCRIPT_PATH="$script_dir/$(basename -- "$script_source")"

if [[ -n "${XDG_STATE_HOME:-}" ]]; then
    readonly STATE_DIR="${XDG_STATE_HOME%/}/tg-launcher"
elif [[ -n "${HOME:-}" ]]; then
    readonly STATE_DIR="${HOME%/}/.local/state/tg-launcher"
else
    readonly STATE_DIR=""
fi

usage() {
    printf '%s v%s\n' "$PROGRAM" "$VERSION"
    printf '   %s\n' "$DESCRIPTION"
    printf '   Rilis: %s\n' "$RELEASE"
    printf '   %s\n' "$AUTHOR"
    printf '   %s\n' "$WEBSITE"
    printf '   Diskusi: %s\n\n' "$CHANNEL"
    printf 'Menjalankan Telegram dengan mode multiple apps.\n\n'
    printf 'Penggunaan:\n'
    printf '   %s [opsi] <workdir>\n\n' "${0##*/}"
    printf 'Opsi:\n'
    printf '   -h, --help       Tampilkan bantuan\n'
    printf '   -V, --version    Tampilkan versi\n'
    printf '   --check          Validasi konfigurasi tanpa menjalankan Telegram\n'
    printf '   --dry-run        Tampilkan rencana eksekusi tanpa menjalankan Telegram\n'
    printf '   --status         Tampilkan status instance untuk workdir\n\n'
    printf 'Contoh:\n'
    printf '   %s /home/data/telegram/1\n' "${0##*/}"
    printf '   %s --check /home/data/telegram/1\n' "${0##*/}"
    printf '   %s --status /home/data/telegram/1\n\n' "${0##*/}"
    printf 'Variabel opsional:\n'
    printf '   TELEGRAM_BIN=/path/Telegram TG_LOG=/path/telegram.log %s <workdir>\n' "${0##*/}"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "command tidak ditemukan: $1"
}

worker_mode() {
    [[ $# -eq 4 ]] || exit 2

    local lock_file="$2"
    local pid_file="$3"
    local workdir="$4"
    local telegram_pid
    local telegram_status

    exec 9>"$lock_file" || exit 1
    flock -n 9 || exit 75

    cleanup_pid_file() {
        rm -f -- "$pid_file"
    }

    trap cleanup_pid_file EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    DESKTOPINTEGRATION=1 "$TELEGRAM_BIN" -many -workdir "$workdir" &
    telegram_pid=$!
    printf '%s\n' "$telegram_pid" >"$pid_file" || exit 1
    chmod 600 "$pid_file" 2>/dev/null || true

    wait "$telegram_pid"
    telegram_status=$?
    exit "$telegram_status"
}

# Mode internal untuk menjaga lock tetap aktif selama Telegram berjalan.
if [[ "${1:-}" == "--worker" ]]; then
    require_command flock
    worker_mode "$@"
fi

require_command flock
require_command sha256sum

check_telegram() {
    [[ -n "$TELEGRAM_BIN" ]] || die 'TELEGRAM_BIN tidak boleh kosong'
    [[ -f "$TELEGRAM_BIN" && -x "$TELEGRAM_BIN" ]] \
        || die "program Telegram tidak ditemukan atau tidak executable: $TELEGRAM_BIN"
}

resolve_workdir() {
    local input="$1"

    [[ -d "$input" ]] || die "workdir bukan direktori: $input"
    [[ -r "$input" && -w "$input" && -x "$input" ]] \
        || die "workdir harus memiliki izin baca, tulis, dan akses: $input"

    if ! workdir=$(cd -- "$input" && pwd -P); then
        die "tidak dapat membaca workdir: $input"
    fi
}

prepare_state_paths() {
    local digest

    [[ -n "$STATE_DIR" ]] || die 'HOME atau XDG_STATE_HOME tidak tersedia'

    if ! digest=$(printf '%s' "$workdir" | sha256sum); then
        die 'gagal membuat identitas workdir'
    fi

    workdir_key="${digest%% *}"
    pid_file="$STATE_DIR/$workdir_key.pid"
    lock_file="$STATE_DIR/$workdir_key.lock"
}

check_state_location() {
    local parent

    [[ -n "$STATE_DIR" ]] || die 'HOME atau XDG_STATE_HOME tidak tersedia'

    if [[ -e "$STATE_DIR" ]]; then
        [[ -d "$STATE_DIR" && -w "$STATE_DIR" && -x "$STATE_DIR" ]] \
            || die "state directory tidak dapat digunakan: $STATE_DIR"
        return
    fi

    parent="$STATE_DIR"
    while [[ ! -e "$parent" && "$parent" != "/" ]]; do
        parent="${parent%/*}"
        [[ -n "$parent" ]] || parent="/"
    done

    [[ -d "$parent" && -w "$parent" && -x "$parent" ]] \
        || die "tidak dapat membuat state directory di: $STATE_DIR"
}

ensure_state_directory() {
    mkdir -p -- "$STATE_DIR" || die "gagal membuat state directory: $STATE_DIR"
    chmod 700 "$STATE_DIR" 2>/dev/null || true
}

check_log_target() {
    local log_parent

    [[ -n "$TG_LOG" ]] || die 'TG_LOG tidak boleh kosong'

    [[ "$TG_LOG" == "/dev/null" ]] && return

    if [[ -e "$TG_LOG" ]]; then
        [[ -f "$TG_LOG" && -w "$TG_LOG" ]] \
            || die "file log tidak dapat ditulis: $TG_LOG"
        return
    fi

    log_parent="${TG_LOG%/*}"
    [[ "$log_parent" == "$TG_LOG" ]] && log_parent="."
    [[ -d "$log_parent" && -w "$log_parent" && -x "$log_parent" ]] \
        || die "direktori file log tidak dapat ditulis: $log_parent"
}

ensure_log_file() {
    [[ "$TG_LOG" == "/dev/null" ]] && return

    if [[ ! -e "$TG_LOG" ]]; then
        (umask 077; : >"$TG_LOG") \
            || die "gagal membuat file log: $TG_LOG"
    fi

    [[ -f "$TG_LOG" && -w "$TG_LOG" ]] \
        || die "file log tidak dapat ditulis: $TG_LOG"
}

lock_is_held() {
    [[ -e "$lock_file" ]] || return 1

    if flock -n "$lock_file" -c ':' >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

read_pid() {
    local value

    [[ -s "$pid_file" ]] || return 1
    value=$(<"$pid_file")
    [[ "$value" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$value"
}

active_pid() {
    local known_pid

    known_pid=$(read_pid) || return 1
    kill -0 "$known_pid" 2>/dev/null || return 1
    lock_is_held || return 1
    printf '%s\n' "$known_pid"
}

show_status() {
    local known_pid

    if known_pid=$(active_pid); then
        printf 'Status: berjalan\n'
        printf '   Workdir: %s\n' "$workdir"
        printf '   PID: %s\n' "$known_pid"
        printf '   State: %s\n' "$STATE_DIR"
        return 0
    fi

    printf 'Status: tidak berjalan\n'
    printf '   Workdir: %s\n' "$workdir"
    [[ -e "$pid_file" ]] && printf '   Catatan: PID file tidak aktif atau sudah usang.\n'
    return 1
}

action="launch"

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

case "$1" in
    -h|--help)
        [[ $# -eq 1 ]] || die 'opsi bantuan tidak boleh disertai argumen lain'
        usage
        exit 0
        ;;
    -V|--version)
        [[ $# -eq 1 ]] || die 'opsi versi tidak boleh disertai argumen lain'
        printf '%s v%s\n' "$PROGRAM" "$VERSION"
        exit 0
        ;;
    --check|--dry-run|--status)
        action="${1#--}"
        shift
        ;;
esac

[[ $# -eq 1 ]] || {
    printf 'Error: jumlah argumen workdir harus tepat satu.\n\n' >&2
    usage >&2
    exit 2
}

check_telegram
resolve_workdir "$1"
prepare_state_paths

case "$action" in
    check)
        check_state_location
        check_log_target
        printf 'Konfigurasi valid. Telegram tidak dijalankan.\n'
        printf '   Telegram: %s\n' "$TELEGRAM_BIN"
        printf '   Workdir: %s\n' "$workdir"
        printf '   Log: %s\n' "$TG_LOG"
        printf '   State: %s\n' "$STATE_DIR"
        ;;
    dry-run)
        check_state_location
        check_log_target
        printf 'Dry run: Telegram tidak dijalankan.\n'
        printf '   DESKTOPINTEGRATION=1 %q -many -workdir %q\n' "$TELEGRAM_BIN" "$workdir"
        printf '   Log: %s\n' "$TG_LOG"
        printf '   PID/lock: %s / %s\n' "$pid_file" "$lock_file"
        ;;
    status)
        show_status
        ;;
    launch)
        check_state_location
        check_log_target
        ensure_state_directory
        ensure_log_file

        if known_pid=$(active_pid); then
            die "workdir sudah berjalan dengan PID $known_pid: $workdir"
        fi

        if lock_is_held; then
            die "workdir sedang dalam proses peluncuran: $workdir"
        fi

        rm -f -- "$pid_file"

        printf 'Menjalankan Telegram...\n'
        printf '   Workdir: %s\n' "$workdir"
        printf '   Log: %s\n' "$TG_LOG"

        nohup "$SCRIPT_PATH" --worker "$lock_file" "$pid_file" "$workdir" \
            </dev/null >>"$TG_LOG" 2>&1 &
        launcher_pid=$!

        for _ in {1..10}; do
            [[ -s "$pid_file" ]] && break
            kill -0 "$launcher_pid" 2>/dev/null || break
            sleep 0.1
        done

        if known_pid=$(active_pid); then
            printf 'Telegram telah diluncurkan. PID: %s\n' "$known_pid"
            exit 0
        fi

        if ! kill -0 "$launcher_pid" 2>/dev/null; then
            die "Telegram gagal diluncurkan; periksa log: $TG_LOG"
        fi

        printf 'Launcher telah dimulai, tetapi PID Telegram belum tersedia.\n'
        printf 'Gunakan --status untuk memeriksa: %s\n' "$workdir"
        ;;
esac
