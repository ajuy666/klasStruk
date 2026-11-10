# Pengujian Black-Box dengan Equivalence Partitioning

## Informasi Pengujian

| Item | Keterangan |
|---|---|
| Metode | Black-box testing dengan Equivalence Partitioning |
| Objek uji | Aplikasi SmartStok Pancanitis |
| Tujuan | Memastikan setiap kelas masukan valid dan tidak valid menghasilkan respons yang sesuai. |
| Penguji | ................................ |
| Tanggal pengujian | ................................ |
| Perangkat | ................................ |
| Versi aplikasi | ................................ |

Equivalence Partitioning membagi masukan ke dalam kelas yang dianggap memiliki perilaku sama. Satu data perwakilan dari setiap kelas diuji; pengujian berikut hanya mencakup fungsi yang tersedia pada implementasi aplikasi saat ini.

## Tabel Pengujian

| ID | Kebutuhan Fungsional | Skenario Pengujian | Kelas Ekuivalensi | Data Uji | Hasil yang Diharapkan | Hasil Pengujian | Kesimpulan |
|---|---|---|---|---|---|---|---|
| EP-01 | Autentikasi pengguna | Mengisi nama, nama usaha, email baru, dan kata sandi valid lalu menekan **Daftar Sekarang**. | Valid | Nama: Budi; Usaha: Toko Maju; email baru; password `rahasia1` | Sistem membuat akun dan meminta pengguna melakukan verifikasi email/OTP. |  |  |
| EP-02 | Autentikasi pengguna | Mengirim registrasi dengan kolom wajib kosong atau kata sandi kurang dari 6 karakter. | Tidak valid | Kolom kosong / password 1--5 karakter | Sistem menolak registrasi dan menampilkan pesan validasi yang sesuai. |  |  |
| EP-03 | Autentikasi pengguna | Masukkan email dan kata sandi akun yang sudah diverifikasi. | Valid | Email dan password benar | Sistem berhasil masuk ke dashboard. |  |  |
| EP-04 | Autentikasi pengguna | Masukkan email/kata sandi salah atau gunakan akun yang belum diverifikasi. | Tidak valid | Kredensial salah / akun belum terkonfirmasi | Sistem menolak login dan menampilkan pesan kesalahan atau permintaan verifikasi email. |  |  |
| EP-05 | Input gambar struk | Memilih foto dari galeri atau mengambil foto dari kamera. | Valid | Berkas gambar melalui `ImagePicker`/kamera | Foto ditampilkan pada layar Scan Struk dan siap diproses. |  |  |
| EP-06 | Input gambar struk | Menekan tombol scan tanpa mengambil atau memilih foto terlebih dahulu. | Tidak valid | Tidak ada foto | Sistem menampilkan pesan “Foto struk dulu ya.” dan tidak mengirim permintaan scan. |  |  |
| EP-07 | Ekstraksi informasi struk (OCR) | Memindai foto struk yang jelas. | Valid | Foto struk terbaca | Sistem menampilkan hasil merchant, item, qty, harga/jumlah, dan total untuk ditinjau pengguna. |  |  |
| EP-08 | Ekstraksi informasi struk (OCR) | Memindai foto buram, gelap, atau bukan struk. | Tidak valid | Foto tidak layak dibaca | Sistem tidak berhenti; pengguna menerima pesan kesalahan scan atau hasil yang meminta scan ulang/koreksi manual. |  |  |
| EP-09 | Kategorisasi produk (LSTM) | Mengklasifikasikan nama item yang sesuai pola data latih. | Valid | `Pop Mie Ayam` | Sistem menampilkan kategori produk beserta confidence hasil LSTM. |  |  |
| EP-10 | Kategorisasi produk (LSTM) | Mengklasifikasikan nama item dengan confidence di bawah ambang. | Tidak valid | Teks produk tidak dikenal/acak | Sistem menggunakan kategori fallback `lainnya` apabila confidence prediksi kurang dari 0,50. |  |  |
| EP-11 | Penyimpanan hasil | Menekan **Simpan** pada hasil scan yang telah ditinjau. | Valid | Foto dan hasil scan tersedia | Gambar struk, transaksi, item, kategori, dan pergerakan stok masuk tersimpan di Supabase; notifikasi berhasil ditampilkan. |  |  |
| EP-12 | Menampilkan inventori | Membuka tab Inventori setelah data inventori tersedia. | Valid | Pengguna login dengan produk tersimpan | Sistem menampilkan data produk, jumlah stok, harga terakhir, dan nilai stok terkini. |  |  |
| EP-13 | Menampilkan riwayat transaksi | Membuka tab Riwayat. | Valid | Pengguna login | Sistem menampilkan daftar transaksi pembelian; detail struk dan item dapat dibuka apabila data tersedia. |  |  |
| EP-14 | Dashboard dan kategori produk | Membuka dashboard pada akun dengan atau tanpa transaksi bulan berjalan. | Valid | Akun pengguna | Sistem menampilkan ringkasan pembelian dan informasi/persentase kategori produk tanpa error. |  |  |

## Rekapitulasi

| Jumlah kasus | Berhasil | Gagal | Belum diuji |
|---:|---:|---:|---:|
| 14 |  |  |  |

Catatan: kolom **Hasil Pengujian** dan **Kesimpulan** diisi setelah setiap kasus dijalankan pada APK/perangkat uji. Jangan menandai kasus berhasil sebelum pengujian aktual dilakukan.
