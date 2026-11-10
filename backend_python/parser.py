"""Mengubah hasil OCR menjadi data struk terstruktur.

Gemini bertugas membaca dan merapikan isi struk, sedangkan LSTM menentukan
kategori item supaya klasifikasi tidak bergantung pada keluaran Gemini.
"""

import os
import re
import json
import traceback
from datetime import datetime
from nlp_preprocessing import preprocess_text, is_valid_item
from lstm_model import LSTMClassifier


def _load_local_env():
    """Muat .env lokal tanpa menimpa environment variable sistem."""
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if not os.path.exists(env_path):
        return

    # utf-8-sig juga menangani BOM yang otomatis ditambahkan beberapa editor
    # Windows saat menyimpan file .env.
    with open(env_path, "r", encoding="utf-8-sig") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_local_env()

try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None
    types = None


# API key harus diberikan lewat environment variable, bukan disimpan di kode.
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

if genai and GEMINI_API_KEY.strip():
    client = genai.Client(api_key=GEMINI_API_KEY.strip())
else:
    client = None


# LOAD LSTM MODEL
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(BASE_DIR, "data", "dataset_300.csv")

lstm_model = LSTMClassifier()
try:
    lstm_model.train(DATASET_PATH)
    print("LSTM aktif")
except Exception as e:
    print("Gagal load/train LSTM:", e)


def parse_receipt(lines, image_bytes=None):
    """Parse baris OCR; kembalikan respons aman bila layanan AI gagal."""
    gemini_result = parse_receipt_with_gemini(lines, image_bytes)
    if gemini_result is not None:
        return gemini_result

    # Tidak menggunakan parser berbasis aturan sebagai fallback. Pengguna
    # harus mencoba scan ulang ketika Gemini/API tidak dapat menghasilkan data.
    return {
        "merchant": "",
        "supplier": "",
        "transaction_date": None,
        "items": [{
            "name": "Perlu scan ulang",
            "clean_name": "",
            "category": "lainnya",
            "qty": None,
            "unit": None,
            "price": None,
            "amount": None,
            "status": "perlu cek",
        }],
        "total": 0,
        "total_item_count": 1,
        "detected_item_count": 0,
        "missing_item_count": 1,
        "has_missing_items": True,
        "notes": [
                "Gemini tidak dapat memproses foto struk. Periksa log backend lalu coba scan ulang."
        ],
    }


def parse_receipt_with_gemini(lines, image_bytes=None):
    """Kirim OCR atau gambar ke Gemini lalu normalisasi respons JSON-nya."""
    if not client:
        print("Model AI tidak aktif")
        return None

    # Bersihkan artefak OCR sebelum teks dimasukkan ke prompt AI.
    cleaned_lines = [_normalize_line(x) for x in lines if x and str(x).strip()]
    cleaned_lines = [x for x in cleaned_lines if x]
    ocr_text = "\n".join(cleaned_lines)

    if not ocr_text.strip() and not image_bytes:
        return {
            "merchant": "",
            "supplier": "",
            "transaction_date": None,
            "items": [{
                "name": "Perlu koreksi manual",
                "clean_name": "",
                "category": "lainnya",
                "qty": None,
                "unit": None,
                "price": None,
                "amount": None,
                "status": "perlu cek"
            }],
            "total": 0,
            "total_item_count": 1,
            "detected_item_count": 0,
            "missing_item_count": 1,
            "has_missing_items": True,
            "notes": ["Teks OCR kosong atau tidak terbaca."]
        }

    if image_bytes:
        source_instruction = """Analyze the receipt image directly. Extract every value from
the image itself; OCR is not used in this request."""
    else:
        source_instruction = "Analyze the receipt OCR text below."

    prompt = f"""
{source_instruction}

Return ONLY valid JSON in this exact format:
{{
  "merchant": "string",
  "transaction_date": "YYYY-MM-DD or null",
  "raw_text": "string",
  "gemini_reading_confidence": 0,
    "items": [
    {{
      "name": "string",
      "qty": number,
      "price": null,
      "amount": null
    }}
  ],
  "total": number
}}

Rules:
- `raw_text` is your plain-text transcription of the visible receipt. Preserve
  readable lines and do not invent unreadable text.
- `gemini_reading_confidence` is an integer from 0 to 100 representing only
  your confidence in reading this image. It is not the LSTM category confidence.
- Include only real purchased items.
- Ignore subtotal, tax, ppn, payment, cash, debit, credit, qris, change, promo, hemat, discount, card, approval code, footer text.
- Ignore phone numbers, addresses, cashier info, transaction codes, member info, and thank-you text.
- Extract transaction date from receipt if present and convert it to YYYY-MM-DD.
- If date is unclear, use null.
- If qty is missing, use 1.
- `price` is the purchase unit price from an item row, never a product size
  (such as 600ML or 250GR).
- For every purchased item, read its numeric price and item total from the
  receipt table whenever they are visible. Do not leave every item price empty
  when the receipt contains item-price columns.
- Never use HARGA JUAL, voucher, discount, subtotal, or TOTAL as an item price.
- If a price cannot be read reliably, return null. Never return 0.
- Only copy amount to price when qty is exactly 1.
- For table rows, read the final numeric columns as: qty, purchase unit price,
  then item total. Example: "LE MINERALE 600ML 2 3500 7,000" means qty=2,
  price=3500, amount=7000.
- Normalize each product name to its standard Indonesian brand/product spelling.
  Keep the brand and product variant, but remove store codes, column values,
  and packaging sizes such as 600ML, 1L, 250GR, 1KG, or 5PCS.
- Correct common OCR substitutions. Examples: "M1e 1ndomie" becomes
  "Mie Indomie"; "Knzler Sngles Hot 65" becomes "Kanzler Singles Hot 65";
  "KNZLER SNGL.ES KJU" becomes "Kanzler Singles Keju"; and
  "POP MIE PD.DWR AYM75" becomes "Pop Mie Pedas Dower Ayam 75G".
- Do not explain anything.
- Return JSON only.

OCR text:
\"\"\"
{ocr_text}
\"\"\"
"""

    try:
        contents = prompt
        if image_bytes:
            # Teks instruksi ditempatkan sebelum gambar, sesuai rekomendasi
            # Gemini untuk satu gambar yang berisi teks.
            contents = [
                prompt,
                types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
            ]

        # Flash lebih akurat membaca kolom angka struk; Lite menjadi cadangan
        # saat layanan utama sedang penuh atau tidak tersedia.
        response = None
        last_model_error = None
        for model_name in (
            "gemini-2.5-flash",
            "gemini-3.5-flash-lite",
            "gemini-3-flash-preview",
        ):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        max_output_tokens=4096,
                    ),
                )
                print(f"Gemini model dipakai: {model_name}")
                break
            except Exception as model_error:
                last_model_error = model_error
                print(f"Gemini model gagal ({model_name}):", repr(model_error))

        if response is None:
            raise last_model_error or RuntimeError("Tidak ada model Gemini yang tersedia")

        raw = getattr(response, "text", "") or ""
        cleaned = _clean_json(raw)
        data = json.loads(cleaned)

        merchant = str(data.get("merchant", "")).strip()
        if not merchant or merchant.lower() == "tidak terdeteksi":
            merchant = ""

        transaction_date = _normalize_transaction_date(
            data.get("transaction_date")
        )
        gemini_raw_text = str(data.get("raw_text", "")).strip()
        gemini_reading_confidence = max(
            0, min(100, _safe_to_int(data.get("gemini_reading_confidence", 0)))
        )

        raw_items = data.get("items", [])
        total = _safe_to_int(data.get("total", 0))

        # Setiap item Gemini divalidasi lalu dikategorikan oleh model lokal.
        items = []
        for item in raw_items:
            if not isinstance(item, dict):
                continue

            name = str(item.get("name", "")).strip()
            if not name:
                continue

            qty_val = item.get("qty", 1)
            price_val = item.get("price", item.get("amount", ""))
            amount_val = item.get("amount", item.get("price", ""))

            qty = _string_or_none(qty_val)
            price_number = _safe_to_int(price_val)
            amount_number = _safe_to_int(amount_val)
            price = _string_or_none(price_number) if price_number > 0 else None
            amount = _string_or_none(amount_number) if amount_number > 0 else None

            if price is None and amount is not None and qty in ["1", "1.0"]:
                price = amount

            if _looks_like_noise_item(name):
                continue

            normalized_name = _normalize_item_name(name)
            clean_name = preprocess_text(normalized_name)

            if not is_valid_item(clean_name):
                continue

            # Gemini hanya merapikan teks. Label kategori selalu dari LSTM.
            try:
                prediction = lstm_model.predict_with_confidence(clean_name)
                category = prediction["category"]
                confidence = prediction["confidence"]
            except Exception:
                category = "lainnya"
                confidence = 0.0

            items.append({
                "name": normalized_name,
                "clean_name": clean_name,
                "category": category,
                "prediction_confidence": confidence,
                "qty": qty if qty not in ["0", "", None] else "1",
                "unit": None,
                "price": price,
                "amount": amount if amount is not None else price,
                "status": "hasil OCR"
            })

        items = _dedupe_item_objects(items)

        detected_item_count = len(items)
        total_item_count = detected_item_count
        missing_item_count = 0
        has_missing_items = False
        notes = []

        if not items:
            has_missing_items = True
            total_item_count = 1
            missing_item_count = 1
            items = [{
                "name": "Perlu koreksi manual",
                "clean_name": "",
                "category": "lainnya",
                "qty": None,
                "unit": None,
                "price": None,
                "amount": None,
                "status": "perlu cek"
            }]
            notes.append("AI tidak berhasil menemukan item dengan yakin. Mohon cek dan edit manual.")

        supplier = ""

        return {
            "merchant": merchant,
            "supplier": supplier,
            "transaction_date": transaction_date,
            "raw_text": gemini_raw_text,
            "gemini_reading_confidence": gemini_reading_confidence,
            "items": items,
            "total": total,
            "total_item_count": total_item_count,
            "detected_item_count": detected_item_count,
            "missing_item_count": missing_item_count,
            "has_missing_items": has_missing_items,
            "notes": _dedupe_text(notes),
        }

    except Exception as e:
        print("AI Gemini Vision gagal:", repr(e))
        traceback.print_exc()
        return None


def _clean_json(text: str):
    """Buang code fence atau teks tambahan agar respons Gemini dapat di-JSON parse."""
    text = text.strip()
    text = re.sub(r"^```json\s*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"^```\s*", "", text)
    text = re.sub(r"\s*```$", "", text)

    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        text = text[start:end + 1]

    return text.strip()


def _string_or_none(value):
    if value is None:
        return None
    s = str(value).strip()
    return s if s else None


def _safe_to_int(value):
    """Ubah berbagai format nominal struk (Rp, titik, koma) menjadi integer."""
    if value is None:
        return 0

    if isinstance(value, int):
        return value

    if isinstance(value, float):
        return int(round(value))

    s = str(value).strip()
    if not s:
        return 0

    s = s.replace("Rp", "").replace("rp", "").strip()
    s = s.replace(" ", "")

    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
            try:
                return int(float(s))
            except Exception:
                pass
        else:
            s = s.replace(",", "")
            try:
                return int(float(s))
            except Exception:
                pass

    s = s.replace(".", "").replace(",", "")

    try:
        return int(float(s))
    except Exception:
        return 0


def _looks_like_noise_item(name: str):
    """Deteksi baris total/pembayaran/footer agar tidak dianggap sebagai produk."""
    up = name.upper().strip()
    blocked = [
        "TOTAL", "SUBTOTAL", "SUB TOTAL", "GRAND TOTAL",
        "PPN", "PAJAK", "TAX", "PAYMENT", "PEMBAYARAN",
        "CHANGE", "CASH", "DEBIT", "CREDIT", "CARD", "QRIS",
        "PROMO", "DISCOUNT", "HEMAT", "KEMBALI", "BAYAR",
        "APPROVAL", "NO REF", "REFERENCE", "TERIMA KASIH", "THANK YOU",
        "TELP", "PHONE", "HP", "ADDRESS", "ALAMAT", "CASHIER", "KASIR",
        "MEMBER", "POINT", "LOYALTY", "DATE", "TIME", "JAM"
    ]
    return any(x in up for x in blocked)


def _dedupe_item_objects(items):
    """Hilangkan item ganda yang mungkin terbaca dua kali oleh AI."""
    seen = set()
    result = []
    for item in items:
        key = (
            str(item.get("name", "")).strip().upper(),
            str(item.get("qty", "")).strip(),
            str(item.get("amount", "")).strip()
        )
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result

def _normalize_line(text):
    """Bersihkan karakter salah baca OCR tanpa menghapus angka dan tanda nominal."""
    text = str(text).strip()

    replacements = {
        "|": "I",
        "!": "I",
        "`": "",
        "'": "",
        '"': "",
        "*": "",
        "_": " ",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"[^\w\s.,:/\-&()]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()

    return text


def _normalize_item_name(text):
    """Koreksi variasi OCR yang dikenal dan hilangkan ukuran kemasan."""
    t = text.upper().strip()
    t = re.sub(r"\s+", " ", t)

    replacements = {
        "AJINOMOTO BB MSK": "AJINOMOTO MSG",
        "AJINOMOTO BBMSK": "AJINOMOTO MSG",
        "AJINUMOTO BB MSK": "AJINOMOTO MSG",
        "BAWAN MERAH": "BAWANG MERAH",
        "BAWAN3 MERAH": "BAWANG MERAH",
        "CABE RAW MERAH": "CABE RAWIT MERAH",
        "CABE RAWIT MERAH": "CABE RAWIT MERAH",
        "BUAH NAGA MRH": "BUAH NAGA",
        "BUAH NAGAMR": "BUAH NAGA",
        "BIO BROKULI": "BROKOLI",
        "BROKULI": "BROKOLI",
        "AYAM KAMPU": "AYAM KAMPUNG",
        "AYAM KAMPUNG": "AYAM KAMPUNG",
        "SEMANKA": "SEMANGKA",
        "SEMANGKA": "SEMANGKA",
        "KANGKLNG": "KANGKUNG AKAR",
        "KANGKUNG AKAR": "KANGKUNG AKAR",
        "SELADA AIR GR": "SELADA AIR",
        "SELADA AIR": "SELADA AIR",
        "DAUN SEREH OUGR T": "DAUN SEREH",
        "DAUN SEREH": "DAUN SEREH",
        "PLASTIC SHOPBAG": "PLASTIC SHOP BAG",
        "PLASTIC SHOP BAG": "PLASTIC SHOP BAG",
    }

    for wrong, right in replacements.items():
        if wrong in t:
            return right

    if "MINYAK" in t:
        return "365 MINYAK"
    if "AJIN" in t:
        return "AJINOMOTO MSG"
    if "BAWANG" in t or "BAWAN" in t:
        return "BAWANG MERAH"
    if "CABE" in t and "MERAH" in t:
        return "CABE RAWIT MERAH"
    if "NAGA" in t:
        return "BUAH NAGA"
    if "BROK" in t:
        return "BROKOLI"
    if "AYAM" in t and "KAMP" in t:
        return "AYAM KAMPUNG"
    if "SEMANG" in t:
        return "SEMANGKA"
    if "KANGKUNG" in t:
        return "KANGKUNG AKAR"
    if "SELADA AIR" in t:
        return "SELADA AIR"
    if "DAUN SEREH" in t:
        return "DAUN SEREH"
    if "PLASTIC" in t and "SHOP" in t:
        return "PLASTIC SHOP BAG"

    return _strip_packaging_size(t).title()


def _strip_packaging_size(text):
    """Hapus ukuran kemasan dari nama tabel, bukan dari raw OCR."""
    cleaned = re.sub(
        r"(?<![A-Z0-9])\d+(?:[.,]\d+)?\s*(?:ML|MLT|L|LTR|LITER|GR|G|KG|PCS|PC)\b",
        " ",
        str(text).upper(),
        flags=re.IGNORECASE,
    )
    return re.sub(r"\s+", " ", cleaned).strip()


def _normalize_transaction_date(value):
    """Validasi tanggal keluaran Gemini agar selalu memakai YYYY-MM-DD."""
    if value is None:
        return None

    text = str(value).strip()
    if not text:
        return None

    text = text.replace("\\", "/").replace(".", "/").replace("-", "/")
    for date_format in ("%Y/%m/%d", "%d/%m/%Y", "%m/%d/%Y", "%d/%m/%y", "%m/%d/%y"):
        try:
            date_value = datetime.strptime(text, date_format)
            if date_value.year < 2000:
                date_value = date_value.replace(year=date_value.year + 2000)
            return date_value.strftime("%Y-%m-%d")
        except ValueError:
            continue

    return None


def _dedupe_text(items):
    """Hilangkan pesan catatan yang sama sambil mempertahankan urutan awal."""
    seen = set()
    result = []
    for item in items:
        key = str(item).upper().strip()
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result
