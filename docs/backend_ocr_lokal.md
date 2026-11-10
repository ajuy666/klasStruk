# Menjalankan Backend OCR Lokal

1. Pastikan laptop dan HP berada pada Wi-Fi atau hotspot yang sama.
2. Buka PowerShell pada folder `backend_python` dan aktifkan virtual environment.
3. Jalankan API lokal:

```powershell
.\run_local_api.ps1
```

API berjalan pada port `8020`. Flutter memakai `http://192.168.1.7:8020`
sebagai alamat awal.

Jika IP laptop berubah, lihat alamat `IPv4 Address` dengan perintah berikut:

```powershell
ipconfig
```

Lalu jalankan Flutter memakai alamat baru tanpa mengubah kode:

```powershell
flutter run --dart-define=OCR_BACKEND_URL=http://IP_LAPTOP:8020
```

Contoh:

```powershell
flutter run --dart-define=OCR_BACKEND_URL=http://192.168.43.25:8020
```

Untuk emulator Android gunakan `http://10.0.2.2:8020`. Untuk HP fisik,
gunakan IP Wi-Fi laptop, bukan `localhost`.
