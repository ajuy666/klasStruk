"""Persiapan gambar ringan untuk Gemini Vision tanpa memuat PaddleOCR.

Modul ini terpisah agar gambar untuk AI dapat diperkecil dan dikompresi tanpa
memulai engine OCR, misalnya saat dipakai oleh skrip atau endpoint lain.
"""
import cv2
import numpy as np


def prepare_gemini_image(file_bytes):
    """Konversi bytes gambar menjadi JPEG maksimal 1600 px untuk Gemini."""
    npimg = np.frombuffer(file_bytes, np.uint8)
    image = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Gambar tidak bisa dibaca")

    height, width = image.shape[:2]
    max_side = max(height, width)
    # Batasi resolusi untuk mengurangi ukuran request dan waktu inferensi.
    if max_side > 1600:
        scale = 1600 / max_side
        image = cv2.resize(
            image, None, fx=scale, fy=scale, interpolation=cv2.INTER_AREA
        )

    # JPEG kualitas 85 memberi ukuran kecil tanpa menghilangkan teks struk.
    success, encoded = cv2.imencode(
        ".jpg", image, [int(cv2.IMWRITE_JPEG_QUALITY), 85]
    )
    if not success:
        raise ValueError("Gambar tidak bisa disiapkan untuk Gemini")
    return encoded.tobytes()
