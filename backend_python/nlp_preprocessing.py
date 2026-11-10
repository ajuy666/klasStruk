"""Normalisasi teks nama produk sebelum training dan prediksi LSTM.

Fungsi di modul ini harus dipakai pada kedua proses agar bentuk input model
tetap sama meskipun teks berasal dari dataset atau OCR/Gemini.
"""

import re


# Kata yang bukan nama item (noise dari OCR/Gemini)
INVALID_NAMES = {
    "item",
    "menu",
    "barang",
    "produk",
    "qty",
    "jumlah",
}


# Normalisasi typo / variasi kata
NORMALIZATION_MAP = {
    "cabe": "cabai",
    "mie": "mi",
    "indomiee": "indomie",
    "baksoo": "bakso",
    "capcay": "cap cay",
    "capjay": "cap jay",
}


def preprocess_text(text: str) -> str:
    """Ubah teks menjadi token huruf kecil yang bersih dan sudah dinormalisasi."""
    if not text:
        return ""

    text = text.lower().strip()
    text = re.sub(r"[^a-z\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()

    if text in NORMALIZATION_MAP:
        text = NORMALIZATION_MAP[text]

    tokens = text.split()
    tokens = [NORMALIZATION_MAP.get(t, t) for t in tokens]

    return " ".join(tokens)


def is_valid_item(name: str) -> bool:
    """Tolak label pendek atau generik yang bukan nama produk sebenarnya."""
    if not name:
        return False

    clean = name.lower().strip()

    if clean in INVALID_NAMES:
        return False

    if len(clean) < 3:
        return False

    return True
