# Evaluasi Model LSTM

Folder ini dipakai untuk mengevaluasi performa algoritma klasifikasi kategori item.

Alur utama aplikasi Keuangan UMKM dapat dilihat pada [sequence diagram](sequence_diagram.md).

Model yang dievaluasi:

- Algoritma: LSTM satu arah (standard LSTM)
- Fitur teks: urutan token nama produk, embedding 32 dimensi, dan LSTM 32 unit
- Dataset: `../data/dataset_300.csv`

## Cara Menjalankan

Dari folder `backend_python`:

```bash
python evaluation/evaluate_model.py
```

Atau dari root project:

```bash
python backend_python/evaluation/evaluate_model.py
```

## File Hasil

Setelah dijalankan, hasil evaluasi akan muncul di folder `results`:

- `metrics.md`: ringkasan hasil evaluasi yang mudah dibaca.
- `summary.json`: ringkasan metrik dalam format JSON.
- `confusion_matrix.csv`: confusion matrix aktual vs prediksi.
- `confusion_matrix.svg`: gambar confusion matrix yang bisa dibuka di browser.
- `classification_report.csv`: precision, recall, F1-score, dan support per kategori.
- `test_predictions.csv`: daftar data uji, label asli, label prediksi, dan status benar/salah.

## Rumus Metrik

Accuracy:

```text
jumlah prediksi benar / jumlah seluruh data uji
```

Precision:

```text
true positive / (true positive + false positive)
```

Recall:

```text
true positive / (true positive + false negative)
```

F1-score:

```text
2 x (precision x recall) / (precision + recall)
```

Confusion matrix menunjukkan berapa banyak data dari kategori asli yang diprediksi ke masing-masing kategori.
