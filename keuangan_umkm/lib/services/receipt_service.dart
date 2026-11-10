import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt_item.dart';
import 'expense_limit_service.dart';
import 'inventory_service.dart';
import 'transaction_service.dart';

/// DATABASE (Supabase): menyimpan struk, transaksi, item struk, dan stok.
class ReceiptService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Backend OCR lokal. Untuk HP fisik gunakan IP LAN laptop, bukan localhost.
  // Nilai dapat diganti saat build lewat --dart-define=OCR_BACKEND_URL=...
  static const String _localBackendUrl = String.fromEnvironment(
    'OCR_BACKEND_URL',
    defaultValue: 'http://10.235.222.54:8020',
  );

  static const List<String> backendUrls = [_localBackendUrl];

  /// DATABASE (Supabase): membaca atau membuat business_profiles pengguna aktif.
  Future<Map<String, dynamic>> getCurrentUserContext() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final businessProfile = await supabase
        .from('business_profiles')
        .select('id, business_name')
        .eq('user_id', user.id)
        .maybeSingle();

    if (businessProfile != null) {
      return {
        'user_id': user.id,
        'business_profile_id': businessProfile['id'],
        'business_name': businessProfile['business_name'],
      };
    }

    final profile = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();

    final ownerName =
        profile?['full_name']?.toString() ?? user.email ?? 'Pengguna';

    final createdBusinessProfile = await supabase
        .from('business_profiles')
        .insert({
          'user_id': user.id,
          'business_name': 'Usaha Saya',
          'owner_name': ownerName,
        })
        .select('id, business_name')
        .single();

    return {
      'user_id': user.id,
      'business_profile_id': createdBusinessProfile['id'],
      'business_name': createdBusinessProfile['business_name'],
    };
  }

  /// DATABASE (Supabase Storage): mengunggah gambar struk.
  Future<String> uploadReceiptImage(XFile file) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final originalName = file.name.isNotEmpty ? file.name : file.path;
    final fileExt = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'receipts/$fileName';
    final bytes = await file.readAsBytes();

    await supabase.storage
        .from('receipt-images')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = supabase.storage
        .from('receipt-images')
        .getPublicUrl(filePath);
    return publicUrl;
  }

  Future<Map<String, dynamic>> scanReceipt(XFile imageFile) async {
    Exception? lastError;

    for (final baseUrl in backendUrls) {
      try {
        final uri = Uri.parse('$baseUrl/scan');
        final bytes = await imageFile.readAsBytes();
        final fileName = imageFile.name.isNotEmpty
            ? imageFile.name
            : 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final request = http.MultipartRequest('POST', uri);
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );

        // Jangan biarkan UI menunggu tanpa batas ketika VPS/OCR bermasalah.
        // OCR normal dapat memakan beberapa detik, sehingga batas 45 detik
        // masih cukup longgar untuk foto struk yang jelas.
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
        );
        final response = await http.Response.fromStream(streamedResponse)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        } else {
          lastError = Exception(
            'Gagal scan struk di $baseUrl: ${response.body}',
          );
        }
      } catch (e) {
        lastError = Exception('Error koneksi ke $baseUrl: $e');
      }
    }

    throw lastError ?? Exception('Semua backend gagal dihubungi.');
  }

  /// DATABASE (Supabase): menyimpan receipts, transactions, receipt_items, dan inventori.
  Future<void> saveReceiptAndTransaction({
    required String imagePath,
    required String title,
    required double amount,
    required DateTime transactionDate,
    String? merchantName,
    String? ocrRawText,
    List<ReceiptItem> items = const [],
    String sourceInput = 'ocr',
  }) async {
    final context = await getCurrentUserContext();
    final userId = context['user_id'] as String;
    final businessProfileId = context['business_profile_id'] as String;

    final receiptResponse = await supabase
        .from('receipts')
        .insert({
          'user_id': userId,
          'business_profile_id': businessProfileId,
          'image_path': imagePath,
          'merchant_name': merchantName,
          'receipt_date': transactionDate.toIso8601String().split('T').first,
          'total_amount': amount,
          'ocr_raw_text': ocrRawText,
          'extracted_total': amount,
          'extraction_method': 'python_ocr',
          'classification_method': 'lstm',
          'status': 'processed',
        })
        .select('id')
        .single();

    final receiptId = receiptResponse['id'];

    await supabase.from('transactions').insert({
      'user_id': userId,
      'business_profile_id': businessProfileId,
      'receipt_id': receiptId,
      'title': title,
      'description': merchantName ?? 'Hasil scan struk',
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      'transaction_type': 'expense',
      'source_input': sourceInput,
    });

    final itemRows = items.where((item) => item.name.trim().isNotEmpty).map((
      item,
    ) {
      return {
        'user_id': userId,
        'business_profile_id': businessProfileId,
        'receipt_id': receiptId,
        'item_name': item.name.trim(),
        'normalized_item_name': _normalizeItemName(item.name),
        'quantity': _parseQuantity(item.qty),
        'unit': item.unit,
        'unit_price': _parseNumber(item.price),
        'total_price': _parseNumber(item.amount),
        'predicted_category_name': _normalizeCategory(item.category),
        'prediction_confidence': item.predictionConfidence,
      };
    }).toList();

    if (itemRows.isNotEmpty) {
      await supabase.from('receipt_items').insert(itemRows);

      // Pembelian dari struk menjadi stok masuk. Jika skema inventori belum
      // dipasang, penyimpanan struk tetap berhasil dan pengguna diberi tahu
      // lewat layar Inventori.
      try {
        await InventoryService().recordReceiptItems(
          businessProfileId: businessProfileId,
          receiptId: receiptId.toString(),
          items: items,
        );
      } catch (_) {}
    }

    final currentExpense = await TransactionService()
        .getCurrentMonthExpenseTotal();
    await ExpenseLimitService().notifyIfNeeded(
      userId: userId,
      currentExpense: currentExpense,
    );
  }

  double _parseNumber(String? value) {
    if (value == null) return 0;

    final cleaned = value
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return double.tryParse(cleaned) ?? 0;
  }

  double _parseQuantity(String? value) {
    final quantity = _parseNumber(value);
    return quantity > 0 ? quantity : 1;
  }

  String _normalizeCategory(String? value) {
    final category = value?.trim();
    if (category == null || category.isEmpty) return 'lainnya';
    return category;
  }

  String _normalizeItemName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
