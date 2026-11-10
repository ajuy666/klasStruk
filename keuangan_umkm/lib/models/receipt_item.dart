/// Merepresentasikan satu baris item barang yang diekstrak dari struk.
class ReceiptItem {
  /// Nama barang atau produk.
  String name;

  /// Kuantitas barang yang tercantum pada struk.
  String? qty;

  /// Satuan untuk kuantitas barang, misalnya pcs atau kg.
  String? unit;

  /// Harga satuan barang.
  String? price;

  /// Total harga untuk item barang.
  String? amount;

  /// Sumber atau status hasil pembacaan item, misalnya hasil OCR.
  String status;

  /// Kategori barang hasil klasifikasi.
  String? category;

  /// Tingkat keyakinan model terhadap prediksi kategori.
  double? predictionConfidence;

  /// Membuat data satu item pada struk.
  ReceiptItem({
    required this.name,
    this.qty,
    this.unit,
    this.price,
    this.amount,
    required this.status,
    this.category,
    this.predictionConfidence,
  });

  /// Membuat [ReceiptItem] dari objek JSON yang dikembalikan API.
  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name']?.toString() ?? '',
      qty: json['qty']?.toString(),
      unit: json['unit']?.toString(),
      price: json['price']?.toString(),
      amount: json['amount']?.toString(),
      status: json['status']?.toString() ?? 'hasil OCR',
      category: json['category']?.toString(),
      predictionConfidence: _toDouble(json['prediction_confidence']),
    );
  }

  /// Mengubah item menjadi format JSON untuk dikirim atau disimpan.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'qty': qty,
      'unit': unit,
      'price': price,
      'amount': amount,
      'status': status,
      'category': category,
      'prediction_confidence': predictionConfidence,
    };
  }

  /// Mengonversi nilai API menjadi [double], atau `null` bila tidak tersedia.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
