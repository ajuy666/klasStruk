import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/receipt_item.dart';
import 'notification_service.dart';

/// DATABASE (Supabase): akses tabel dan pergerakan inventori.
class InventoryService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// DATABASE (Supabase): membaca produk dari inventory_products.
  Future<List<Map<String, dynamic>>> getProducts() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User belum login.');
    final data = await supabase
        .from('inventory_products')
        .select()
        .eq('user_id', user.id)
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// DATABASE (Supabase): menjalankan RPC record_inventory_movement.
  Future<void> recordMovement({
    required String businessProfileId,
    required String name,
    required double quantity,
    required String movementType,
    String category = 'lainnya',
    String? unit,
    double unitPrice = 0,
    String? note,
    String? referenceId,
  }) async {
    await supabase.rpc('record_inventory_movement', params: {
      'p_business_profile_id': businessProfileId,
      'p_name': name.trim(),
      'p_normalized_name': _normalize(name),
      'p_category': category,
      'p_unit': unit,
      'p_quantity': quantity,
      'p_movement_type': movementType,
      'p_unit_price': unitPrice,
      'p_note': note,
      'p_reference_id': referenceId,
    });

    final product = await supabase
        .from('inventory_products')
        .select('name, current_stock')
        .eq('business_profile_id', businessProfileId)
        .eq('normalized_name', _normalize(name))
        .maybeSingle();
    final stock = product?['current_stock'] is num
        ? (product!['current_stock'] as num).toDouble()
        : double.tryParse(product?['current_stock']?.toString() ?? '') ?? 0;
    if (stock <= 10) {
      await NotificationService.showLowStockWarning(
        productName: product?['name']?.toString() ?? name,
        stock: stock,
      );
    }
  }

  /// DATABASE (Supabase): memperbarui produk di inventory_products.
  Future<void> updateProduct({
    required String id,
    required String name,
    required String category,
    String? unit,
    required double minimumStock,
  }) async {
    await supabase
        .from('inventory_products')
        .update({
          'name': name.trim(),
          'normalized_name': _normalize(name),
          'category': category,
          'unit': (unit?.trim().isEmpty ?? true) ? null : unit!.trim(),
          'minimum_stock': minimumStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// DATABASE (Supabase): menghapus produk dari inventory_products.
  Future<void> deleteProduct(String id) async {
    await supabase.from('inventory_products').delete().eq('id', id);
  }

  /// DATABASE (Supabase): menyimpan pergerakan stok dari item struk.
  Future<void> recordReceiptItems({
    required String businessProfileId,
    required String receiptId,
    required List<ReceiptItem> items,
  }) async {
    for (final item in items) {
      if (item.name.trim().isEmpty) continue;
      await recordMovement(
        businessProfileId: businessProfileId,
        name: item.name,
        quantity: _number(item.qty, fallback: 1),
        movementType: 'in',
        category: item.category ?? 'lainnya',
        unit: item.unit,
        unitPrice: _number(item.price),
        note: 'Stok masuk dari scan struk',
        referenceId: receiptId,
      );
    }
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  double _number(String? value, {double fallback = 0}) {
    if (value == null) return fallback;
    final cleaned = value.replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? fallback;
  }
}
