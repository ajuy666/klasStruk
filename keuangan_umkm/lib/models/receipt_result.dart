import 'receipt_item.dart';

/// Menyimpan hasil lengkap pembacaan struk dari proses OCR dan Gemini.
class ReceiptResult {
  /// Nama toko atau merchant yang tercantum pada struk.
  final String merchant;

  /// Nama pemasok yang teridentifikasi dari struk.
  final String supplier;

  /// Nilai total transaksi pada struk.
  final int total;

  /// Jumlah seluruh item yang seharusnya ditemukan pada struk.
  final int totalItemCount;

  /// Jumlah item yang berhasil dikenali oleh sistem.
  final int detectedItemCount;

  /// Jumlah item yang belum berhasil dikenali.
  final int missingItemCount;

  /// Menandakan apakah masih ada item yang belum terdeteksi.
  final bool hasMissingItems;

  /// Catatan atau peringatan yang dihasilkan saat pembacaan struk.
  final List<String> notes;

  /// Daftar item yang berhasil diekstrak dari struk.
  final List<ReceiptItem> items;

  /// Teks mentah hasil OCR sebelum diproses menjadi data terstruktur.
  final String rawText;

  /// Tingkat keyakinan Gemini saat membaca informasi struk.
  final double geminiReadingConfidence;

  /// Tingkat keyakinan mesin OCR saat mengenali teks struk.
  final double ocrConfidence;

  /// Membuat objek hasil pembacaan struk.
  ReceiptResult({
    required this.merchant,
    required this.supplier,
    required this.total,
    required this.totalItemCount,
    required this.detectedItemCount,
    required this.missingItemCount,
    required this.hasMissingItems,
    required this.notes,
    required this.items,
    required this.rawText,
    required this.geminiReadingConfidence,
    required this.ocrConfidence,
  });

  /// Membuat [ReceiptResult] dari respons API, termasuk respons yang dibungkus
  /// dalam properti `result`.
  factory ReceiptResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? json;
    final rawText = json['raw_text'];

    return ReceiptResult(
      merchant: result['merchant']?.toString() ?? '',
      supplier: result['supplier']?.toString() ?? '',
      total: result['total'] ?? 0,
      totalItemCount: result['total_item_count'] ?? 0,
      detectedItemCount: result['detected_item_count'] ?? 0,
      missingItemCount: result['missing_item_count'] ?? 0,
      hasMissingItems: result['has_missing_items'] ?? false,
      notes: (result['notes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      items: (result['items'] as List<dynamic>? ?? [])
          .map((e) => ReceiptItem.fromJson(e))
          .toList(),
      rawText: rawText is List
          ? rawText.map((e) => e.toString()).join('\n')
          : rawText?.toString() ?? '',
      geminiReadingConfidence: _toDouble(result['gemini_reading_confidence']),
      ocrConfidence: _toDouble(json['ocr_confidence']),
    );
  }

  /// Mengonversi nilai numerik dari API menjadi [double] dengan nilai aman 0.
  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
