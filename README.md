# Telegram Bash Launcher

## Tujuan

`tg-launcher.sh` menjalankan Telegram Desktop dengan `-many` dan `-workdir`, sehingga beberapa profil atau sesi Telegram dapat dijalankan menggunakan direktori kerja yang berbeda.

## File yang digunakan

Script aktif:

```text
/home/banghasan/Telegram/Session/bin/tg-launcher.sh
```

File lama `tg.sh` sudah dihapus setelah seluruh fungsinya dipindahkan ke script baru. File `REVIEW.md` juga sudah dihapus karena catatan penggunaan dan perubahan sekarang berada di README ini.

Permission script aktif adalah `755` (`-rwxr-xr-x`).

## Penggunaan dasar

```bash
./tg-launcher.sh /path/ke/workdir
```

Contoh:

```bash
./tg-launcher.sh /home/banghasan/Telegram/Session/kumpul1
```

Script menampilkan PID Telegram setelah proses berhasil memperoleh lock dan berjalan. Jika proses masih memulai, gunakan `--status` untuk memeriksanya.

## Opsi

### Bantuan dan versi

```bash
./tg-launcher.sh --help
./tg-launcher.sh --version
```

### Pemeriksaan konfigurasi

Memvalidasi executable Telegram, permission workdir, lokasi state, lokasi log, serta dependency tanpa menjalankan Telegram:

```bash
./tg-launcher.sh --check /home/banghasan/Telegram/Session/kumpul1
```

### Dry run

Menampilkan command dan lokasi state yang akan digunakan tanpa menjalankan Telegram:

```bash
./tg-launcher.sh --dry-run /home/banghasan/Telegram/Session/kumpul1
```

### Status

Memeriksa apakah instance untuk workdir tertentu sedang berjalan:

```bash
./tg-launcher.sh --status /home/banghasan/Telegram/Session/kumpul1
```

Exit status `0` berarti berjalan. Exit status `1` berarti tidak berjalan atau state-nya sudah usang.

## PID dan lock

Setiap workdir memiliki identitas hash sendiri di:

```text
~/.local/state/tg-launcher/
```

Jika `XDG_STATE_HOME` tersedia, lokasi tersebut digunakan sebagai gantinya. PID file dan lock mencegah workdir yang sama dijalankan dua kali secara tidak sengaja. Lock dilepas otomatis ketika proses launcher selesai; PID file lama dibersihkan saat peluncuran berikutnya.

## Log dan troubleshooting

Default log adalah `/dev/null`, sehingga Telegram berjalan tanpa menampilkan output ke terminal. Untuk menyimpan error dan informasi startup:

```bash
TG_LOG=/home/banghasan/Telegram/Session/telegram.log \
./tg-launcher.sh /home/banghasan/Telegram/Session/kumpul1
```

Jika launcher melaporkan proses belum siap, tunggu sebentar lalu jalankan:

```bash
./tg-launcher.sh --status /home/banghasan/Telegram/Session/kumpul1
```

## Konfigurasi opsional

Lokasi executable Telegram dan file log dapat diganti tanpa mengedit script:

```bash
TELEGRAM_BIN=/path/ke/Telegram \
TG_LOG=/path/ke/telegram.log \
./tg-launcher.sh /path/ke/workdir
```

Default:

```text
TELEGRAM_BIN=/home/banghasan/bin/Telegram
TG_LOG=/dev/null
```

File log baru yang dibuat oleh launcher diberi permission privat. Untuk troubleshooting, gunakan path log eksplisit agar error Telegram tidak hilang ke `/dev/null`.

## Integrasi desktop

Launcher menjalankan Telegram dengan `DESKTOPINTEGRATION=1`. Pengaturan ini mencegah Telegram membuat file launcher baru seperti:

```text
~/.local/share/applications/org.telegram.desktop._*.desktop
```

Konsekuensinya, integrasi launcher desktop atau handler link Telegram mungkin tidak aktif untuk instance yang dijalankan melalui script ini. File `.desktop` lama tidak dihapus otomatis.

Untuk membersihkan file lama secara manual, tutup seluruh Telegram terlebih dahulu. Periksa kandidat file:

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

Launcher tidak menjalankan cleanup tersebut secara otomatis.

## Verifikasi

Script harus dapat diperiksa tanpa menjalankan Telegram:

```bash
bash -n ./tg-launcher.sh
./tg-launcher.sh --check /path/ke/workdir
./tg-launcher.sh --dry-run /path/ke/workdir
```

Test otomatis menggunakan executable Telegram palsu, bukan Telegram asli:

```bash
./tests/test-tg-launcher.sh
```

Jika ShellCheck tersedia:

```bash
shellcheck ./tg-launcher.sh ./tests/test-tg-launcher.sh
```
