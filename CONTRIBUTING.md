# Contributing

## Prinsip

- Pertahankan kompatibilitas penggunaan lama: `./tg-launcher.sh <workdir>` tetap berarti `start`.
- Jangan menjalankan Telegram asli dalam test otomatis.
- Jangan membuat installer atau symlink otomatis; instalasi manual berada di luar cakupan proyek.
- Jangan menghapus file pengguna secara otomatis.
- Hindari `source` config file; parser config harus memperlakukan isinya sebagai data.

## Sebelum membuat commit

Jalankan:

```bash
bash -n ./tg-launcher.sh
bash -n ./tests/test-tg-launcher.sh
./tests/test-tg-launcher.sh
shellcheck ./tg-launcher.sh ./tests/test-tg-launcher.sh
```

Jika ShellCheck belum tersedia, pasang melalui package manager sistem sebelum mengirim pull request.

## Perubahan command line

Jika menambah atau mengubah command/option:

1. Perbarui `README.md`.
2. Tambahkan atau perbarui test otomatis.
3. Tambahkan catatan pada `CHANGELOG.md`.
4. Pastikan error mengembalikan exit status non-zero.
5. Pertahankan quoting seluruh path dan argumen.

## Commit

Gunakan subject singkat dan jelas, misalnya:

```text
Add per-workdir log rotation
Fix status when Telegram binary is unavailable
```
