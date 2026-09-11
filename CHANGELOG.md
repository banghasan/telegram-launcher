# Changelog

Semua perubahan penting pada proyek ini dicatat di file ini.

## [2.0.1] - 2026-09-11

### Added

- Dukungan `tg-launcher.conf` di direktori launcher.
- Prioritas config lokal di atas config user.
- Test untuk memastikan prioritas config lokal.

## [2.0.0] - 2026-09-11

### Added

- Config file user-level dengan precedence CLI, environment, config, lalu default.
- Perintah `start`, `stop`, `restart`, `status`, `logs`, `check`, dan `dry-run`.
- PID dan lock per workdir.
- Log otomatis per workdir dengan rotasi ukuran dan backup.
- Test otomatis menggunakan executable Telegram palsu.
- GitHub Actions untuk ShellCheck, syntax check, dan test.
- Dokumentasi kontribusi dan lisensi MIT.

### Changed

- `status` tidak lagi membutuhkan executable Telegram yang masih tersedia.
- Permission state directory, PID file, dan log diperketat.
- `DESKTOPINTEGRATION=1` tetap menjadi default untuk mencegah launcher `.desktop` per instance.

### Removed

- `tg.sh` lama.
- `REVIEW.md` lama.

## [1.2.0] - 2026-09-11

- Menambahkan `--check`, `--dry-run`, `--status`, PID, lock, logging opsional, dan validasi awal.

## [1.1.1] - 2026-09-11

- Memindahkan pengaturan `TELEGRAM_BIN` dan `TG_LOG` ke blok konfigurasi di bagian atas.
- Menonaktifkan pembuatan launcher desktop per instance melalui `DESKTOPINTEGRATION=1`.
