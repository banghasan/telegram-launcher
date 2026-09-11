# Telegram Bash Launcher

## Tujuan

`tg-launcher.sh` menjalankan Telegram Desktop dengan `-many` dan `-workdir`, sehingga beberapa profil atau sesi Telegram dapat dijalankan menggunakan direktori kerja yang berbeda.

Script tetap kompatibel dengan penggunaan lama:

```bash
./tg-launcher.sh /path/ke/workdir
```

Perintah tersebut sama dengan `start`.

## File proyek

```text
tg-launcher.sh
tg-launcher.conf       # lokal, tidak dilacak Git
config.example
README.md
CHANGELOG.md
CONTRIBUTING.md
LICENSE
tests/test-tg-launcher.sh
```

File lama `tg.sh` dan `REVIEW.md` sudah dihapus. Installer dan symlink ke `~/.local/bin` tidak dibuat oleh proyek ini; instalasi manual sengaja diserahkan kepada pengguna.

Permission launcher dan test adalah `755` (`-rwxr-xr-x`).

## Perintah

```bash
./tg-launcher.sh start /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh stop /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh restart /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh status /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh logs /home/banghasan/Telegram/Session/kumpul1
```

Alias kompatibilitas:

```bash
./tg-launcher.sh --status /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh --check /home/banghasan/Telegram/Session/kumpul1
./tg-launcher.sh --dry-run /home/banghasan/Telegram/Session/kumpul1
```

`stop` mengirim `SIGTERM` dan menunggu maksimal lima detik. `SIGKILL` tidak dikirim otomatis agar proses Telegram tidak dihentikan secara paksa tanpa konfirmasi.

## Tampilan console

Output console memakai label warna untuk membedakan informasi:

```text
[INFO] Memulai Telegram
       Direktori kerja : /path/workdir
       File log        : /path/telegram.log
[ OK ] Telegram berhasil dimulai
       PID proses      : 12345
```

Mode warna default adalah `auto`: warna hanya aktif ketika output menuju terminal. Warna otomatis tidak digunakan saat output dipipe atau diarahkan ke file. Log Telegram tetap tidak diberi escape code warna.

Pengaturan manual:

```bash
./tg-launcher.sh --color auto /path/ke/workdir
./tg-launcher.sh --color always /path/ke/workdir
./tg-launcher.sh --no-color /path/ke/workdir
NO_COLOR=1 ./tg-launcher.sh /path/ke/workdir
```

## Validasi dan dry run

Validasi executable, workdir, config, state, dan log tanpa menjalankan Telegram:

```bash
./tg-launcher.sh check /home/banghasan/Telegram/Session/kumpul1
```

Melihat command yang akan digunakan tanpa menjalankan Telegram:

```bash
./tg-launcher.sh dry-run /home/banghasan/Telegram/Session/kumpul1
```

## Konfigurasi

Config file user:

```text
~/.config/tg-launcher/config
```

Jika `XDG_CONFIG_HOME` tersedia, lokasi menjadi `$XDG_CONFIG_HOME/tg-launcher/config`. Lokasi custom dapat diberikan melalui `TG_CONFIG`.

Config file lokal di direktori launcher:

```text
/home/banghasan/Telegram/Session/bin/tg-launcher.conf
```

Config lokal memiliki prioritas lebih tinggi daripada config user. File ini sengaja diabaikan oleh Git agar konfigurasi/path pribadi tidak ikut ter-commit.

Buat config file dengan permission privat, misalnya `600`:

Template tersedia di [config.example](config.example). Salin secara manual jika diperlukan:

```bash
mkdir -p ~/.config/tg-launcher
cp ./config.example ~/.config/tg-launcher/config
chmod 600 ~/.config/tg-launcher/config
```

```text
TELEGRAM_BIN=/home/banghasan/bin/Telegram
TG_LOG=
LOG_MAX_BYTES=5242880
LOG_BACKUPS=3
DESKTOP_INTEGRATION=1
```

`TG_LOG` kosong berarti log otomatis per workdir. Gunakan `TG_LOG=/dev/null` jika ingin menonaktifkan log.

Prioritas konfigurasi:

```text
opsi command line > environment variable > TG_CONFIG > config lokal > config user > default
```

Contoh override tanpa mengubah config file:

```bash
TELEGRAM_BIN=/path/ke/Telegram \
TG_LOG=/tmp/telegram.log \
./tg-launcher.sh start /path/ke/workdir
```

Atau dengan opsi command line:

```bash
./tg-launcher.sh \
    --telegram-bin /path/ke/Telegram \
    --log /tmp/telegram.log \
    start /path/ke/workdir
```

Opsi konfigurasi yang tersedia:

```text
--telegram-bin PATH
--log PATH
--log-max-bytes N
--log-backups N
--desktop-integration
--no-desktop-integration
--color auto|always|never
--no-color
```

Config file memakai format `KEY=VALUE` sederhana. Jangan menggunakan `source` atau menaruh command shell di dalamnya; file dibaca sebagai data dan key yang tidak dikenal akan ditolak.

## PID, lock, dan state

State disimpan di:

```text
~/.local/state/tg-launcher/
```

Jika `XDG_STATE_HOME` tersedia, lokasi tersebut digunakan sebagai gantinya. Setiap workdir memiliki PID file dan lock berbasis hash. Lock mencegah workdir yang sama dijalankan dua kali.

`status` tidak bergantung pada keberadaan executable Telegram saat status sedang diperiksa. Ini memungkinkan status tetap dilihat meskipun binary dipindah sementara.

## Logging dan rotasi

Jika `TG_LOG` tidak diatur, log otomatis dibuat di:

```text
~/.local/state/tg-launcher/logs/<hash-workdir>.log
```

Default rotasi:

```text
LOG_MAX_BYTES=5242880
LOG_BACKUPS=3
```

Saat ukuran maksimum tercapai, log lama digeser menjadi `.1`, `.2`, dan seterusnya. File log otomatis dan state directory dibuat dengan permission privat.

Melihat log terakhir:

```bash
./tg-launcher.sh logs /home/banghasan/Telegram/Session/kumpul1
```

## Integrasi desktop

Default launcher menggunakan `DESKTOP_INTEGRATION=1`, yang diteruskan sebagai `DESKTOPINTEGRATION=1` ke Telegram. Ini mencegah Telegram membuat file seperti:

```text
~/.local/share/applications/org.telegram.desktop._*.desktop
```

Konsekuensinya, launcher desktop atau handler link Telegram mungkin tidak aktif untuk instance tersebut. Jika integrasi desktop memang diperlukan, gunakan:

```bash
./tg-launcher.sh --desktop-integration start /path/ke/workdir
```

File `.desktop` lama tidak dihapus otomatis. Untuk membersihkannya secara manual, tutup seluruh Telegram terlebih dahulu, lalu periksa:

```bash
find "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    -maxdepth 1 -type f -name 'org.telegram.desktop._*.desktop' -print
```

Jika daftar sudah dipastikan benar, hapus dengan konfirmasi per file:

```bash
find "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
    -maxdepth 1 -type f -name 'org.telegram.desktop._*.desktop' \
    -exec rm -i -- {} +
```

## Pengembangan dan test

Pemeriksaan syntax:

```bash
bash -n ./tg-launcher.sh
bash -n ./tests/test-tg-launcher.sh
```

Test otomatis menggunakan executable Telegram palsu, bukan Telegram asli:

```bash
./tests/test-tg-launcher.sh
```

ShellCheck:

```bash
shellcheck ./tg-launcher.sh ./tests/test-tg-launcher.sh
```

Workflow GitHub Actions di `.github/workflows/ci.yml` menjalankan ShellCheck, syntax check, dan test otomatis pada push serta pull request.

## Lisensi dan kontribusi

Lihat [LICENSE](LICENSE) untuk lisensi MIT dan [CONTRIBUTING.md](CONTRIBUTING.md) untuk alur perubahan.
