#!/usr/bin/env bash

# Telegram Bash Launcher

set -u
set -o pipefail

readonly PROGRAM="TBL"
readonly DESCRIPTION="Telegram Bash Launcher"
readonly VERSION="2.0.2"
readonly RELEASE="11 September 2026"
readonly AUTHOR="bangHasan <banghasan@gmail.com>"
readonly WEBSITE="https://www.banghasan.com"
readonly CHANNEL="Telegram Grup @botIndonesia"

script_source="${BASH_SOURCE[0]}"
script_dir=$(cd -- "$(dirname -- "$script_source")" && pwd -P) || exit 1
readonly SCRIPT_PATH="$script_dir/$(basename -- "$script_source")"

if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    user_config_file="${XDG_CONFIG_HOME%/}/tg-launcher/config"
elif [[ -n "${HOME:-}" ]]; then
    user_config_file="${HOME%/}/.config/tg-launcher/config"
else
    user_config_file=""
fi
readonly USER_CONFIG_FILE="$user_config_file"
readonly LOCAL_CONFIG_FILE="$script_dir/tg-launcher.conf"
readonly EXPLICIT_CONFIG_FILE="${TG_CONFIG:-}"

# ===== Default konfigurasi =====
# Nilai ini dapat dioverride oleh config file, environment variable, atau CLI.
readonly DEFAULT_TELEGRAM_BIN="/home/banghasan/bin/Telegram"
telegram_bin="$DEFAULT_TELEGRAM_BIN"
tg_log=""
log_max_bytes="5242880"
log_backups="3"
desktop_integration="1"
# ===============================

color_mode="auto"
if [[ -n "${NO_COLOR:-}" || "${CLICOLOR:-1}" == "0" ]]; then
    color_mode="never"
elif [[ "${CLICOLOR_FORCE:-0}" == "1" ]]; then
    color_mode="always"
fi

setup_colors() {
    local use_color=0

    case "$color_mode" in
        auto)
            [[ -t 1 ]] && use_color=1
            ;;
        always)
            use_color=1
            ;;
        never)
            use_color=0
            ;;
        *)
            die "mode warna tidak dikenal: $color_mode"
            ;;
    esac

    if (( use_color )); then
        color_info=$'\033[36m'
        color_ok=$'\033[32m'
        color_warn=$'\033[33m'
        color_error=$'\033[31m'
        color_reset=$'\033[0m'
    else
        color_info=""
        color_ok=""
        color_warn=""
        color_error=""
        color_reset=""
    fi
}

info() {
    printf '%b[INFO]%b %s\n' "$color_info" "$color_reset" "$*"
}

ok() {
    printf '%b[ OK ]%b %s\n' "$color_ok" "$color_reset" "$*"
}

warn() {
    printf '%b[WARN]%b %s\n' "$color_warn" "$color_reset" "$*" >&2
}

error() {
    printf '%b[ERROR]%b %s\n' "$color_error" "$color_reset" "$*" >&2
}

detail() {
    printf '       %-17s: %s\n' "$1" "$2"
}

detail_error() {
    printf '       %-17s: %s\n' "$1" "$2" >&2
}

die() {
    error "$*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "command tidak ditemukan: $1"
}

trim_value() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

load_config_file() {
    local config_path="$1"
    local line key value config_permissions

    [[ -n "$config_path" && -e "$config_path" ]] || return 0
    [[ -f "$config_path" && -r "$config_path" ]] \
        || die "config file tidak dapat dibaca: $config_path"
    [[ -O "$config_path" ]] \
        || die "config file harus dimiliki oleh user saat ini: $config_path"

    config_permissions=$(stat -c '%A' "$config_path") \
        || die "tidak dapat membaca permission config file: $config_path"
    [[ "${config_permissions:5:1}" == "-" && "${config_permissions:8:1}" == "-" ]] \
        || die "config file tidak boleh writable oleh group atau user lain: $config_path"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value=$(trim_value "${BASH_REMATCH[2]}")
        else
            die "format config tidak valid: $line"
        fi

        case "$key" in
            TELEGRAM_BIN)
                telegram_bin="$value"
                ;;
            TG_LOG)
                tg_log="$value"
                ;;
            LOG_MAX_BYTES)
                log_max_bytes="$value"
                ;;
            LOG_BACKUPS)
                log_backups="$value"
                ;;
            DESKTOP_INTEGRATION)
                desktop_integration="$value"
                ;;
            *)
                die "config key tidak dikenal: $key"
                ;;
        esac
    done <"$config_path"
}

apply_environment() {
    [[ -n "${TELEGRAM_BIN+x}" ]] && telegram_bin="$TELEGRAM_BIN"
    [[ -n "${TG_LOG+x}" ]] && tg_log="$TG_LOG"
    [[ -n "${LOG_MAX_BYTES+x}" ]] && log_max_bytes="$LOG_MAX_BYTES"
    [[ -n "${LOG_BACKUPS+x}" ]] && log_backups="$LOG_BACKUPS"
    [[ -n "${DESKTOP_INTEGRATION+x}" ]] && desktop_integration="$DESKTOP_INTEGRATION"
}

validate_config_values() {
    [[ -n "$telegram_bin" ]] || die 'TELEGRAM_BIN tidak boleh kosong'
    [[ "$log_max_bytes" =~ ^[1-9][0-9]*$ ]] \
        || die "LOG_MAX_BYTES harus berupa angka positif: $log_max_bytes"
    [[ "$log_backups" =~ ^[0-9]+$ ]] \
        || die "LOG_BACKUPS harus berupa angka nol atau lebih: $log_backups"
    (( log_backups <= 99 )) \
        || die 'LOG_BACKUPS tidak boleh lebih besar dari 99'
    [[ "$desktop_integration" == "0" || "$desktop_integration" == "1" ]] \
        || die 'DESKTOP_INTEGRATION hanya boleh bernilai 0 atau 1'
}

setup_colors
require_command stat
load_config_file "$USER_CONFIG_FILE"
load_config_file "$LOCAL_CONFIG_FILE"
if [[ -n "$EXPLICIT_CONFIG_FILE" ]]; then
    load_config_file "$EXPLICIT_CONFIG_FILE"
fi
apply_environment
require_command flock
require_command sha256sum

usage() {
    printf '%s v%s\n' "$PROGRAM" "$VERSION"
    printf '   %s\n' "$DESCRIPTION"
    printf '   Rilis: %s\n' "$RELEASE"
    printf '   %s\n' "$AUTHOR"
    printf '   %s\n' "$WEBSITE"
    printf '   Diskusi: %s\n\n' "$CHANNEL"
    printf 'Penggunaan lama:\n'
    printf '   %s <workdir>\n\n' "${0##*/}"
    printf 'Perintah:\n'
    printf '   start <workdir>      Jalankan Telegram\n'
    printf '   stop <workdir>       Hentikan Telegram dengan aman\n'
    printf '   restart <workdir>    Restart instance Telegram\n'
    printf '   status <workdir>     Tampilkan status instance\n'
    printf '   logs <workdir>       Tampilkan log terakhir\n'
    printf '   check <workdir>      Validasi konfigurasi tanpa menjalankan\n'
    printf '   dry-run <workdir>    Tampilkan rencana eksekusi\n\n'
    printf 'Alias kompatibilitas:\n'
    printf '   --check, --dry-run, --status\n\n'
    printf 'Opsi:\n'
    printf '   --telegram-bin PATH  Override lokasi executable Telegram\n'
    printf '   --log PATH           Override lokasi log; kosong berarti auto\n'
    printf '   --log-max-bytes N    Batas rotasi log dalam byte\n'
    printf '   --log-backups N      Jumlah file backup log\n'
    printf '   --no-desktop-integration\n'
    printf '   --desktop-integration\n'
    printf '   --color MODE        auto, always, atau never\n'
    printf '   --no-color          Alias untuk --color never\n'
    printf '   -h, --help           Tampilkan bantuan\n'
    printf '   -V, --version        Tampilkan versi\n\n'
    printf 'Contoh:\n'
    printf '   %s start /home/data/telegram/1\n' "${0##*/}"
    printf '   %s --status /home/data/telegram/1\n' "${0##*/}"
    printf '   %s --log /tmp/tg.log logs /home/data/telegram/1\n\n' "${0##*/}"
    printf 'Config file:\n'
    printf '   User: %s\n' "${USER_CONFIG_FILE:-none}"
    printf '   Lokal: %s\n' "$LOCAL_CONFIG_FILE"
    if [[ -n "$EXPLICIT_CONFIG_FILE" ]]; then
        printf '   Explicit TG_CONFIG: %s\n' "$EXPLICIT_CONFIG_FILE"
    fi
}

check_telegram() {
    [[ -f "$telegram_bin" && -x "$telegram_bin" ]] \
        || die "program Telegram tidak ditemukan atau tidak executable: $telegram_bin"
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

    if [[ -n "${XDG_STATE_HOME:-}" ]]; then
        state_dir="${XDG_STATE_HOME%/}/tg-launcher"
    elif [[ -n "${HOME:-}" ]]; then
        state_dir="${HOME%/}/.local/state/tg-launcher"
    else
        state_dir=""
    fi

    [[ -n "$state_dir" ]] || die 'HOME atau XDG_STATE_HOME tidak tersedia'

    if ! digest=$(printf '%s' "$workdir" | sha256sum); then
        die 'gagal membuat identitas workdir'
    fi

    workdir_key="${digest%% *}"
    pid_file="$state_dir/$workdir_key.pid"
    lock_file="$state_dir/$workdir_key.lock"
    log_dir="$state_dir/logs"

    if [[ -n "$tg_log" ]]; then
        log_file="$tg_log"
        auto_log=0
    else
        log_file="$log_dir/$workdir_key.log"
        auto_log=1
    fi
}

check_state_location() {
    local parent

    if [[ -e "$state_dir" ]]; then
        [[ -d "$state_dir" && -w "$state_dir" && -x "$state_dir" ]] \
            || die "state directory tidak dapat digunakan: $state_dir"
        return
    fi

    parent="$state_dir"
    while [[ ! -e "$parent" && "$parent" != "/" ]]; do
        parent="${parent%/*}"
        [[ -n "$parent" ]] || parent="/"
    done

    [[ -d "$parent" && -w "$parent" && -x "$parent" ]] \
        || die "tidak dapat membuat state directory di: $state_dir"
}

ensure_state_directory() {
    mkdir -p -- "$state_dir" || die "gagal membuat state directory: $state_dir"
    chmod 700 "$state_dir" 2>/dev/null || true

    if (( auto_log )); then
        mkdir -p -- "$log_dir" || die "gagal membuat direktori log: $log_dir"
        chmod 700 "$log_dir" 2>/dev/null || true
    fi
}

check_log_target() {
    local log_parent

    if [[ "$log_file" == "/dev/null" ]]; then
        return
    fi

    if (( auto_log )); then
        if [[ -e "$log_dir" ]]; then
            [[ -d "$log_dir" && -w "$log_dir" && -x "$log_dir" ]] \
                || die "direktori log tidak dapat digunakan: $log_dir"
        else
            [[ -d "$state_dir" && -w "$state_dir" && -x "$state_dir" ]] \
                || check_state_location
        fi
        return
    fi

    [[ ! -L "$log_file" ]] || die "file log tidak boleh berupa symlink: $log_file"

    if [[ -e "$log_file" ]]; then
        [[ -f "$log_file" && -w "$log_file" ]] \
            || die "file log tidak dapat ditulis: $log_file"
        return
    fi

    log_parent="${log_file%/*}"
    [[ "$log_parent" == "$log_file" ]] && log_parent="."
    [[ -d "$log_parent" && -w "$log_parent" && -x "$log_parent" ]] \
        || die "direktori file log tidak dapat ditulis: $log_parent"
}

ensure_log_file() {
    [[ "$log_file" == "/dev/null" ]] && return

    [[ ! -L "$log_file" ]] || die "file log tidak boleh berupa symlink: $log_file"

    if [[ ! -e "$log_file" ]]; then
        (umask 077; : >"$log_file") \
            || die "gagal membuat file log: $log_file"
    fi

    [[ -f "$log_file" && -w "$log_file" ]] \
        || die "file log tidak dapat ditulis: $log_file"

    if (( auto_log )); then
        chmod 600 "$log_file" 2>/dev/null || true
    fi
}

rotate_log() {
    local size index

    [[ "$log_file" == "/dev/null" || ! -f "$log_file" ]] && return

    size=$(wc -c <"$log_file") || die "tidak dapat membaca ukuran log: $log_file"
    (( size < log_max_bytes )) && return

    if (( log_backups == 0 )); then
        (umask 077; : >"$log_file") \
            || die "gagal merotasi log: $log_file"
        return
    fi

    for ((index = log_backups - 1; index >= 1; index--)); do
        if [[ -e "$log_file.$index" ]]; then
            mv -f -- "$log_file.$index" "$log_file.$((index + 1))" \
                || die "gagal merotasi backup log: $log_file.$index"
        fi
    done

    mv -f -- "$log_file" "$log_file.1" \
        || die "gagal memindahkan log lama: $log_file"
    (umask 077; : >"$log_file") \
        || die "gagal membuat log baru: $log_file"
    chmod 600 "$log_file" 2>/dev/null || true
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
        ok 'Telegram sedang berjalan'
        detail 'Direktori kerja' "$workdir"
        detail 'PID proses' "$known_pid"
        detail 'File log' "$log_file"
        detail 'State' "$state_dir"
        return 0
    fi

    warn 'Telegram tidak sedang berjalan'
    detail_error 'Direktori kerja' "$workdir"
    detail_error 'File log' "$log_file"
    if [[ -e "$pid_file" ]]; then
        detail_error 'Catatan' 'PID file tidak aktif atau sudah usang'
    fi
    return 1
}

show_logs() {
    require_command tail

    if [[ "$log_file" == "/dev/null" || ! -f "$log_file" ]]; then
        warn 'Belum ada file log untuk direktori kerja ini'
        detail_error 'File log' "$log_file"
        return 0
    fi

    info 'Menampilkan 100 baris log terakhir'
    detail 'File log' "$log_file"
    tail -n 100 -- "$log_file"
}

worker_mode() {
    [[ $# -eq 4 ]] || exit 2

    local worker_lock_file="$2"
    local worker_pid_file="$3"
    local worker_workdir="$4"
    local telegram_pid telegram_status

    [[ -f "$telegram_bin" && -x "$telegram_bin" ]] || exit 1
    exec 9>"$worker_lock_file" || exit 1
    flock -n 9 || exit 75

    cleanup_pid_file() {
        rm -f -- "$worker_pid_file"
    }

    trap cleanup_pid_file EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if [[ "$desktop_integration" == "1" ]]; then
        DESKTOPINTEGRATION=1 "$telegram_bin" -many -workdir "$worker_workdir" &
    else
        unset DESKTOPINTEGRATION
        "$telegram_bin" -many -workdir "$worker_workdir" &
    fi
    telegram_pid=$!
    printf '%s\n' "$telegram_pid" >"$worker_pid_file" || exit 1
    chmod 600 "$worker_pid_file" 2>/dev/null || true

    wait "$telegram_pid"
    telegram_status=$?
    exit "$telegram_status"
}

start_instance() {
    local launcher_pid known_pid

    validate_config_values
    check_telegram
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
    rotate_log

    info 'Memulai Telegram'
    detail 'Direktori kerja' "$workdir"
    detail 'File log' "$log_file"

    TELEGRAM_BIN="$telegram_bin" \
    TG_LOG="$log_file" \
    DESKTOP_INTEGRATION="$desktop_integration" \
    nohup "$SCRIPT_PATH" --worker "$lock_file" "$pid_file" "$workdir" \
        </dev/null >>"$log_file" 2>&1 &
    launcher_pid=$!

    for _ in {1..10}; do
        [[ -s "$pid_file" ]] && break
        kill -0 "$launcher_pid" 2>/dev/null || break
        sleep 0.1
    done

    if known_pid=$(active_pid); then
        ok 'Telegram berhasil dimulai'
        detail 'PID proses' "$known_pid"
        return 0
    fi

    if ! kill -0 "$launcher_pid" 2>/dev/null; then
        die "Telegram gagal diluncurkan; periksa log: $log_file"
    fi

    warn 'Launcher sudah dimulai, tetapi PID Telegram belum tersedia'
    detail_error 'Perintah' "${0##*/} status $workdir"
}

stop_instance() {
    local known_pid

    if ! known_pid=$(active_pid); then
        warn 'Telegram tidak sedang berjalan untuk direktori kerja ini'
        detail_error 'Direktori kerja' "$workdir"
        return 3
    fi

    info "Menghentikan Telegram (PID $known_pid)"
    kill -TERM "$known_pid" 2>/dev/null \
        || die "gagal mengirim signal ke PID $known_pid"

    for _ in {1..50}; do
        if ! active_pid >/dev/null; then
            ok 'Telegram berhasil dihentikan'
            return 0
        fi
        sleep 0.1
    done

    warn 'Telegram belum berhenti setelah 5 detik; SIGKILL tidak dikirim otomatis'
    return 1
}

parse_arguments() {
    action=""
    workdir_input=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -V|--version)
                printf '%s v%s\n' "$PROGRAM" "$VERSION"
                exit 0
                ;;
            --telegram-bin)
                [[ $# -ge 2 ]] || die '--telegram-bin membutuhkan path'
                telegram_bin="$2"
                shift 2
                ;;
            --log)
                [[ $# -ge 2 ]] || die '--log membutuhkan path atau /dev/null'
                tg_log="$2"
                shift 2
                ;;
            --log-max-bytes)
                [[ $# -ge 2 ]] || die '--log-max-bytes membutuhkan angka'
                log_max_bytes="$2"
                shift 2
                ;;
            --log-backups)
                [[ $# -ge 2 ]] || die '--log-backups membutuhkan angka'
                log_backups="$2"
                shift 2
                ;;
            --color)
                [[ $# -ge 2 ]] || die '--color membutuhkan mode: auto, always, atau never'
                color_mode="$2"
                shift 2
                ;;
            --color=*)
                color_mode="${1#--color=}"
                shift
                ;;
            --no-color)
                color_mode="never"
                shift
                ;;
            --no-desktop-integration)
                desktop_integration="0"
                shift
                ;;
            --desktop-integration)
                desktop_integration="1"
                shift
                ;;
            --check|check)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="check"
                shift
                ;;
            --dry-run|dry-run)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="dry-run"
                shift
                ;;
            --status|status)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="status"
                shift
                ;;
            start)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="start"
                shift
                ;;
            stop)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="stop"
                shift
                ;;
            restart)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="restart"
                shift
                ;;
            logs)
                [[ -z "$action" ]] || die 'perintah lebih dari satu'
                action="logs"
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    [[ -z "$workdir_input" ]] || die 'workdir lebih dari satu'
                    workdir_input="$1"
                    shift
                done
                ;;
            --*)
                die "opsi tidak dikenal: $1"
                ;;
            *)
                [[ -z "$workdir_input" ]] || die 'workdir lebih dari satu'
                workdir_input="$1"
                shift
                ;;
        esac
    done

    [[ -n "$action" ]] || action="start"
    [[ -n "$workdir_input" ]] || {
        usage >&2
        exit 2
    }
}

# Mode internal untuk menjaga lock tetap aktif selama Telegram berjalan.
if [[ "${1:-}" == "--worker" ]]; then
    worker_mode "$@"
    exit $?
fi

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

parse_arguments "$@"
setup_colors
resolve_workdir "$workdir_input"
prepare_state_paths

case "$action" in
    start)
        start_instance
        ;;
    stop)
        stop_instance
        ;;
    restart)
        if stop_instance; then
            :
        else
            stop_status=$?
            (( stop_status == 3 )) || exit "$stop_status"
        fi
        start_instance
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    check)
        validate_config_values
        check_telegram
        check_state_location
        check_log_target
        ok 'Konfigurasi valid; Telegram tidak dijalankan'
        detail 'Executable' "$telegram_bin"
        detail 'Direktori kerja' "$workdir"
        detail 'File log' "$log_file"
        detail 'State' "$state_dir"
        detail 'Config user' "${USER_CONFIG_FILE:-none}"
        detail 'Config lokal' "$LOCAL_CONFIG_FILE"
        if [[ -n "$EXPLICIT_CONFIG_FILE" ]]; then
            detail 'Config explicit' "$EXPLICIT_CONFIG_FILE"
        fi
        ;;
    dry-run)
        validate_config_values
        check_telegram
        check_state_location
        check_log_target
        info 'Dry run; Telegram tidak dijalankan'
        detail 'Direktori kerja' "$workdir"
        detail 'File log' "$log_file"
        detail 'PID/lock' "$pid_file / $lock_file"
        printf '       Command           : '
        if [[ "$desktop_integration" == "1" ]]; then
            printf 'DESKTOPINTEGRATION=1 '
        fi
        printf '%q -many -workdir %q\n' "$telegram_bin" "$workdir"
        ;;
    *)
        die "perintah tidak didukung: $action"
        ;;
esac
