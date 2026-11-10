# Pengujian Black-Box SmartStok Pancanitis

## Informasi Pengujian

| Item | Keterangan |
|---|---|
| Metode | Black-box testing |
| Objek uji | Aplikasi Android SmartStok Pancanitis |
| Fokus | Kesesuaian fungsi dari masukan pengguna dan keluaran aplikasi |
| Penguji | ................................ |
| Tanggal pengujian | ................................ |
| Perangkat | ................................ |
| Versi aplikasi | ................................ |

Pengujian black-box dilakukan tanpa memeriksa struktur kode program. Setiap kasus berikut diuji dari antarmuka aplikasi berdasarkan masukan, proses, dan keluaran yang terlihat oleh pengguna.

## Ketentuan Status

| Status | Arti |
|---|---|
| Berhasil | Keluaran aplikasi sesuai hasil yang diharapkan |
| Gagal | Keluaran aplikasi tidak sesuai hasil yang diharapkan |
| Belum diuji | Kasus belum dijalankan pada perangkat |

## Data Uji yang Disarankan

- Akun valid yang sudah terdaftar.
- Akun dengan email atau kata sandi salah.
- Foto struk yang jelas serta memiliki item, qty, harga, dan total.
- Foto bukan struk atau foto buram.
- Produk inventori: **Pop Mie Ayam 75g**, **Pop Mie Pedas Dower Ayam 75g**, dan produk lain yang berbeda.

## A. Autentikasi

| ID | Fitur | Skenario / Langkah Uji | Data Masukan | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|---|
| BB-01 | Registrasi | Isi seluruh data registrasi valid, lalu tekan **Daftar**. | Nama, email baru, kata sandi valid | Akun berhasil dibuat dan pengguna mendapat informasi/verifikasi yang sesuai. |  | Belum diuji |
| BB-02 | Registrasi | Kirim formulir dengan kolom wajib kosong. | Nama/email/kata sandi kosong | Aplikasi menolak proses dan menampilkan pesan validasi. |  | Belum diuji |
| BB-03 | Registrasi | Daftarkan email yang sudah digunakan. | Email terdaftar | Aplikasi menampilkan pesan bahwa email tidak dapat digunakan/akun sudah ada. |  | Belum diuji |
| BB-04 | Login | Masukkan email dan kata sandi yang valid, lalu tekan **Masuk**. | Akun valid | Pengguna masuk dan diarahkan ke halaman utama/dashboard. | Login berhasil. Panduan penggunaan pertama kali tampil, lalu pengguna diarahkan ke dashboard. | Berhasil |
| BB-05 | Login | Masukkan email atau kata sandi tidak valid. | Akun/kata sandi salah | Login ditolak dan ditampilkan pesan kesalahan. |  | Belum diuji |
| BB-06 | Logout | Tekan tombol keluar pada profil dan konfirmasi bila diminta. | - | Sesi pengguna berakhir dan aplikasi kembali ke halaman login. |  | Belum diuji |

## B. Dashboard dan Analisis

| ID | Fitur | Skenario / Langkah Uji | Data Masukan | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|---|
| BB-07 | Dashboard | Buka aplikasi setelah login. | Akun valid | Nama pengguna, kartu total pengeluaran, ringkasan kategori, dan struk terakhir tampil tanpa elemen saling menutupi. | Dashboard berhasil terbuka. Pada APK terbaru, kartu total berada di bawah area nama/email dan foto profil, sehingga tidak ada tumpang-tindih. | Berhasil |
| BB-08 | Dashboard | Akses dashboard ketika belum ada transaksi bulan berjalan. | Akun tanpa transaksi | Total pengeluaran bernilai Rp 0, jumlah struk/item bernilai 0, dan aplikasi tidak error. | Dashboard bulan berjalan menampilkan Rp 0, 0 struk, 0 item, serta kategori kosong tanpa error. | Berhasil |
| BB-09 | Dashboard | Tekan **Lihat Detail** atau kartu total bulanan. | Transaksi tersedia | Halaman analisis bulanan terbuka dan data sesuai transaksi pengguna. | Kartu total berhasil membuka halaman Analisis. Pada bulan tanpa transaksi, aplikasi menampilkan total Rp 0 dan pesan belum ada kategori. | Berhasil |
| BB-10 | Riwayat | Buka tab **Riwayat**, lalu pilih satu transaksi. | Transaksi tersedia | Daftar riwayat tampil dan detail transaksi yang dipilih dapat dibuka. | Riwayat menampilkan 16 transaksi; salah satu transaksi dapat dibuka ke halaman hasil ekstraksi. | Berhasil |
| BB-11 | Laporan | Buat/lihat pratinjau laporan dari halaman analisis. | Rentang data tersedia | Ringkasan dan data laporan tampil sesuai transaksi yang ada. |  | Belum diuji |

## C. Scan Struk, OCR, Gemini, dan Klasifikasi

| ID | Fitur | Skenario / Langkah Uji | Data Masukan | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|---|
| BB-12 | Kamera | Buka tab **Scan** dan izinkan akses kamera. | Izin kamera diberikan | Pratinjau kamera atau pilihan pengambilan foto dapat digunakan. | Halaman Scan Struk terbuka dan menampilkan status “Kamera aktif realtime”. | Berhasil |
| BB-13 | Scan struk | Ambil/pilih foto struk yang jelas dan tekan proses OCR. | Foto struk valid | Aplikasi menampilkan proses pemindaian lalu halaman hasil scan. |  | Belum diuji |
| BB-14 | Validasi foto | Tekan proses scan tanpa memilih foto. | Tidak ada foto | Aplikasi menampilkan pesan bahwa foto struk harus dipilih terlebih dahulu. |  | Belum diuji |
| BB-15 | OCR gagal | Proses foto buram atau bukan struk. | Foto tidak valid | Aplikasi tidak berhenti/crash dan menampilkan pesan kegagalan OCR atau hasil yang dapat diperiksa pengguna. |  | Belum diuji |
| BB-16 | Hasil OCR | Periksa merchant, item, qty, harga, total, dan kategori pada hasil scan. | Foto struk valid | Data hasil OCR/Gemini tampil dan dapat ditinjau sebelum disimpan. Kategori berasal dari model LSTM/BiLSTM. |  | Belum diuji |
| BB-17 | Edit hasil scan | Ubah item, qty, harga, atau kategori pada hasil scan. | Nilai perubahan valid | Nilai pada tabel berubah sesuai masukan pengguna dan total diperbarui sesuai aturan aplikasi. |  | Belum diuji |
| BB-18 | Simpan transaksi | Tekan **Simpan** pada hasil scan valid. | Hasil scan valid | Muncul pesan transaksi berhasil disimpan; transaksi muncul pada riwayat dan dashboard diperbarui. |  | Belum diuji |
| BB-19 | Raw OCR | Buka bagian **Raw OCR** pada hasil scan. | Hasil scan valid | Teks mentah dari OCR dapat dilihat untuk kebutuhan pengecekan hasil ekstraksi. | Raw OCR tampil pada halaman detail transaksi beserta item dan hasil klasifikasi LSTM. | Berhasil |

## D. Inventori dan Chat Stok

| ID | Fitur | Skenario / Langkah Uji | Data Masukan | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|---|
| BB-20 | Tambah stok manual | Tekan tambah stok, isi nama produk, jumlah, pilih **Stok masuk**, lalu simpan. | Produk baru, jumlah positif | Produk/stok tersimpan dan tampil pada katalog inventori. |  | Belum diuji |
| BB-21 | Validasi stok | Simpan stok dengan nama kosong atau jumlah tidak valid. | Nama kosong / jumlah nol / teks | Aplikasi menolak penyimpanan dan menampilkan pesan kesalahan yang sesuai. |  | Belum diuji |
| BB-22 | Pencarian inventori | Masukkan nama produk, kategori, atau supplier pada kolom pencarian. | Kata kunci `Pop` | Kolom menerima kata kunci dan daftar menyisakan Pop Mie Pedas Dower Ayam serta Pop Mie Ayam. | Berhasil |
| BB-23 | Filter kategori | Pilih salah satu kategori inventori. | Kategori tertentu | Hanya produk dari kategori terpilih yang ditampilkan. |  | Belum diuji |
| BB-24 | Ubah produk | Pilih **Ubah produk**, perbarui nama/kategori/satuan/batas minimum, lalu simpan. | Data produk valid | Perubahan produk tersimpan dan terlihat pada katalog. |  | Belum diuji |
| BB-25 | Hapus produk | Pilih **Hapus produk**, konfirmasi penghapusan. | Produk tersedia | Produk dan riwayat stok terkait dihapus setelah konfirmasi; batal tidak menghapus data. |  | Belum diuji |
| BB-26 | Stok menipis | Atur stok di bawah batas minimum. | Produk dengan stok positif dan batas minimum Rp 0/0 pcs | Produk tetap ditandai “Menipis” meskipun stok, misalnya Pop Mie Ayam = 4 pcs, berada di atas batas minimum 0 pcs. Perlu perbaikan logika status stok menipis. | Gagal |
| BB-27 | Chat stok | Ketik “Pop Mie Ayam 75g terjual 1 pcs”, lalu tekan periksa stok. | Produk dan jumlah valid | Sistem menemukan produk yang tepat dan menampilkan konfirmasi pengurangan stok. | Sistem menemukan **Pop Mie Ayam** (bukan Pop Mie Pedas Dower Ayam), serta menampilkan stok 4 → 3 pcs. | Berhasil |
| BB-28 | Konfirmasi chat stok | Pada dialog konfirmasi, tekan **Setuju**. | Hasil BB-27 | Stok produk yang sama berkurang sesuai jumlah dan katalog diperbarui. |  | Belum diuji |
| BB-29 | Batal chat stok | Tutup dialog konfirmasi tanpa menekan **Setuju**. | Hasil BB-27 | Stok tidak berubah. | Dialog dibatalkan sebelum persetujuan; tidak ada aksi simpan atau pengurangan stok yang dikirim. | Berhasil |
| BB-30 | Produk mirip | Ketik penjualan untuk produk bernama mirip, misalnya “Pop Mie Ayam 75g terjual 1 pcs” ketika ada “Pop Mie Pedas Dower Ayam 75g”. | Nama produk spesifik | Sistem memilih produk yang namanya paling sesuai; tidak mengurangi stok produk lain yang hanya mirip. |  | Belum diuji |

## E. Profil dan Batas Pengeluaran

| ID | Fitur | Skenario / Langkah Uji | Data Masukan | Hasil yang Diharapkan | Hasil Aktual | Status |
|---|---|---|---|---|---|---|
| BB-31 | Edit profil | Ubah nama pemilik dan nama usaha, lalu simpan. | Nilai valid | Profil diperbarui dan nama baru tampil pada dashboard/profil. |  | Belum diuji |
| BB-32 | Validasi profil | Simpan edit profil dengan nama pemilik atau nama usaha kosong. | Nilai kosong | Penyimpanan ditolak dan muncul pesan “Nama pemilik dan nama usaha wajib diisi.” |  | Belum diuji |
| BB-33 | Foto profil | Pilih dan simpan foto profil baru. | File gambar valid | Foto berhasil diperbarui dan tampil pada profil/dashboard. |  | Belum diuji |
| BB-34 | Batas pengeluaran aktif | Atur batas melalui slider ke nilai lebih dari Rp 0 dan simpan. | Contoh Rp 500.000 | Nilai batas tersimpan; notifikasi peringatan dapat diproses ketika total pengeluaran mencapai batas. |  | Belum diuji |
| BB-35 | Batas pengeluaran nonaktif | Atur slider ke Rp 0 dan simpan. | Rp 0 | Batas pengeluaran dinonaktifkan dan aplikasi tidak mengirim notifikasi batas pengeluaran. |  | Belum diuji |

## Kesimpulan Pengujian

Isi setelah seluruh kasus diuji.

| Jumlah kasus | Berhasil | Gagal | Belum diuji |
|---:|---:|---:|---:|
| 35 | 10 | 1 | 24 |

Kesimpulan: ....................................................................................................................................
