"""Layanan PaddleOCR untuk membaca dan mengelompokkan teks pada struk.

Hasil OCR diurutkan kembali berdasarkan posisi agar nilai yang berada pada
baris tabel struk yang sama dikirim ke parser sebagai satu baris teks.
"""

import os

import cv2
import numpy as np
from paddleocr import PaddleOCR

# Backend berjalan di VPS Ubuntu, sehingga MKLDNN dapat dipakai untuk
# mempercepat inferensi OCR berbasis CPU. Nilai environment tetap dapat
# diubah dari systemd tanpa mengedit kode lagi.
OCR_CPU_THREADS = int(os.getenv("OCR_CPU_THREADS", "4"))
OCR_MAX_SIDE = int(os.getenv("OCR_MAX_SIDE", "1280"))

ocr = PaddleOCR(
    use_textline_orientation=False,
    lang="en",
    enable_mkldnn=True,
    cpu_threads=OCR_CPU_THREADS,
)


def preprocess_image(file_bytes):
    """Preprocessing notebook, dengan batas ukuran aman untuk respons API."""
    npimg = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    if img is None:
        raise ValueError("Gambar tidak bisa dibaca")

    # OCR pada foto kamera 4K jauh lebih lambat, padahal detail huruf struk
    # masih terbaca baik pada sisi terpanjang 1280 px. Pengubahan ukuran hanya
    # diterapkan untuk mengecilkan gambar, tidak pernah memperbesar gambar.
    height, width = img.shape[:2]
    max_side = max(height, width)
    if max_side > OCR_MAX_SIDE:
        scale = OCR_MAX_SIDE / max_side
        img = cv2.resize(
            img, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA
        )

    # Grayscale dan sedikit peningkatan kontras membantu teks termal struk.
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return cv2.convertScaleAbs(gray, alpha=1.25, beta=5)


def prepare_gemini_image(file_bytes):
    """Siapkan foto struk yang cukup tajam, tetapi ringan untuk dikirim ke Gemini."""
    npimg = np.frombuffer(file_bytes, np.uint8)
    image = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("Gambar tidak bisa dibaca")

    height, width = image.shape[:2]
    max_side = max(height, width)
    if max_side > 1600:
        scale = 1600 / max_side
        image = cv2.resize(
            image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA
        )

    success, encoded = cv2.imencode(
        ".jpg", image, [int(cv2.IMWRITE_JPEG_QUALITY), 85]
    )
    if not success:
        raise ValueError("Gambar tidak bisa disiapkan untuk Gemini")
    return encoded.tobytes()


def _box_position(box):
    """Ambil posisi kiri dan tengah vertikal kotak hasil PaddleOCR."""
    values = np.asarray(box, dtype=float).flatten()
    if values.size == 4:
        x1, y1, x2, y2 = values
        return x1, (y1 + y2) / 2, max(1, abs(y2 - y1))

    points = values.reshape(-1, 2)
    return points[:, 0].min(), points[:, 1].mean(), max(1, np.ptp(points[:, 1]))


def _run_ocr(image):
    """Baca teks lalu satukan kolom-kolom yang berada pada baris struk sama."""
    entries = []
    total_score = 0

    if len(image.shape) == 2:
        image = cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)

    result = ocr.predict(
        image,
        use_doc_unwarping=False,
        use_textline_orientation=False,
    )

    if result:
        for block in result:
            if not block:
                continue

            if isinstance(block, dict) or hasattr(block, "get"):
                # PaddleOCR dapat mengembalikan list atau NumPy array. Jangan
                # memakai `or []` di sini karena nilai boolean NumPy array
                # dengan banyak elemen bersifat ambigu.
                texts = block.get("rec_texts", [])
                scores = block.get("rec_scores", [])
                boxes = block.get("rec_boxes", [])
                texts = [] if texts is None else texts
                scores = [] if scores is None else scores
                boxes = [] if boxes is None else boxes
                for index, (text, score) in enumerate(zip(texts, scores)):
                    if score < 0.35:
                        continue

                    if text and str(text).strip():
                        x, y, height = (
                            _box_position(boxes[index])
                            if index < len(boxes)
                            else (index * 100, index * 30, 20)
                        )
                        entries.append({
                            "text": str(text).strip(),
                            "x": x,
                            "y": y,
                            "height": height,
                        })
                        total_score += score

                continue

            for word in block:
                text = word[1][0]
                score = word[1][1]

                if score < 0.35:
                    continue

                if text and text.strip():
                    # Format PaddleOCR lama mengembalikan quadrilateral pada
                    # word[0], sehingga tetap dapat dikelompokkan per baris.
                    x, y, height = _box_position(word[0])
                    entries.append({
                        "text": text.strip(),
                        "x": x,
                        "y": y,
                        "height": height,
                    })
                    total_score += score

    if not entries:
        return [], total_score, 0

    entries.sort(key=lambda entry: entry["y"])
    tolerance = max(12, np.median([entry["height"] for entry in entries]) * 0.75)
    rows = []

    for entry in entries:
        row = next(
            (row for row in rows if abs(entry["y"] - row["y"]) <= tolerance),
            None,
        )
        if row is None:
            rows.append({"y": entry["y"], "entries": [entry]})
            continue

        row["entries"].append(entry)
        row["y"] = np.mean([item["y"] for item in row["entries"]])

    lines = [
        " ".join(item["text"] for item in sorted(row["entries"], key=lambda item: item["x"]))
        for row in rows
    ]
    return lines, total_score, len(entries)


def extract_text(file_bytes):
    """Versi ringkas OCR ketika pemanggil tidak membutuhkan confidence."""
    # Satu kali OCR, dengan kolom pada baris struk yang sama disatukan.
    lines, _, _ = _run_ocr(preprocess_image(file_bytes))
    return lines


def extract_text_with_confidence(file_bytes):
    """OCR sekali dan kembalikan teks serta rata-rata confidence 0--100."""
    lines, total_score, detected_text_count = _run_ocr(preprocess_image(file_bytes))
    confidence = (total_score / detected_text_count * 100) if detected_text_count else 0
    return lines, round(min(100, confidence), 1)
