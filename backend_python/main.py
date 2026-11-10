"""Titik masuk API backend untuk pemindaian struk.

Alur endpoint ``POST /scan``: menerima foto -> OCR -> parser Gemini ->
klasifikasi kategori produk dengan LSTM -> mengirim JSON ke aplikasi Flutter.
"""

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from ocr_service import extract_text_with_confidence
from parser import parse_receipt

# Objek aplikasi yang dijalankan Uvicorn dan menerima request dari Flutter.
app = FastAPI(title="SmartStok Pancanitis API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    """Endpoint sederhana untuk mengecek bahwa API sudah hidup."""
    return {"message": "SmartStok Pancanitis API berjalan"}


@app.post("/scan")
async def scan_receipt(file: UploadFile = File(...)):
    """Terima satu gambar struk dan kembalikan hasil OCR serta data terstruktur."""
    try:
        contents = await file.read()
        print("File diterima")

        # Satu kali PaddleOCR: cepat dan memberi confidence pembacaan asli.
        print("OCR mulai...")
        lines, ocr_confidence = extract_text_with_confidence(contents)
        print(f"OCR selesai ({ocr_confidence}%):", lines)

        # Gemini hanya merapikan teks OCR dan menyusun data JSON.
        print("Merapiakan teks OCR dengan Gemini...")
        parsed = parse_receipt(lines)
        print("Parsing selesai:", parsed)

        # Format respons ini dikonsumsi ReceiptService pada aplikasi Flutter.
        return {
            # Raw text adalah hasil OCR yang telah dirapikan Gemini.
            "raw_text": parsed.get("raw_text", ""),
            "ocr_confidence": ocr_confidence,
            "result": parsed
        }

    except Exception as e:
        print("ERROR:", e)
        return {"error": str(e)}


if __name__ == "__main__":
    # Dapat diakses HP yang berada pada Wi-Fi/hotspot yang sama.
    uvicorn.run("main:app", host="0.0.0.0", port=8020, reload=True)
