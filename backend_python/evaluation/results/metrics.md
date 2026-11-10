# Hasil Evaluasi LSTM

## Ringkasan

- Dataset: `D:\flutter_project\backend_python\data\dataset_300.csv`
- Total data: 758
- Data training: 606
- Data testing: 152
- Test split: 20%
- Random state: 42

## Metrik

- Accuracy: 88.16%
- Precision macro: 88.28%
- Recall macro: 88.33%
- F1-score macro: 88.1%
- F1-score weighted: 88.0%

## Performa

- Waktu training: 10.640534 detik
- Waktu prediksi total: 0.57746 detik
- Rata-rata waktu prediksi per item: 3.799081 ms

## Confusion Matrix

| Aktual \ Prediksi | bahan_pokok | kebutuhan_rumah_tangga | makanan | minuman |
|---|---|---|---|---|
| bahan_pokok | 32 | 1 | 5 | 0 |
| kebutuhan_rumah_tangga | 0 | 37 | 0 | 0 |
| makanan | 6 | 4 | 29 | 0 |
| minuman | 0 | 1 | 1 | 36 |
