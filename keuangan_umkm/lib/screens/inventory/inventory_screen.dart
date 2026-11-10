import 'package:flutter/material.dart';

import '../../services/inventory_service.dart';
import '../../services/receipt_service.dart';
import 'stock_chat_sheet.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

/// DATABASE (Supabase): state layar yang memakai InventoryService.
class _InventoryScreenState extends State<InventoryScreen> {
  final _service = InventoryService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  String _category = 'Semua';
  bool _loading = true;
  String? _error;

  void _showMessage(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// DATABASE (Supabase): memuat produk dari InventoryService.
  Future<void> _loadProducts() async {
    setState(() { _loading = true; _error = null; });
    try { _products = await _service.getProducts(); } catch (e) { _error = '$e'; }
    if (mounted) setState(() => _loading = false);
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _qty(dynamic value) { final n = _number(value); return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2); }
  String _rupiah(dynamic value) {
    final number = _number(value).round().toString();
    final chars = number.split('').reversed.toList();
    final result = StringBuffer();
    for (var i = 0; i < chars.length; i++) { if (i > 0 && i % 3 == 0) result.write('.'); result.write(chars[i]); }
    return 'Rp ${result.toString().split('').reversed.join()}';
  }

  static const _categories = [
    'Semua',
    'Makanan',
    'Minuman',
    'Bahan Pokok',
    'Kebutuhan Rumah Tangga',
    'Lainnya',
  ];

  String _categoryLabel(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.contains('minum')) return 'Minuman';
    if (normalized.contains('makan')) return 'Makanan';
    if (normalized.contains('bahan') || normalized.contains('pokok')) return 'Bahan Pokok';
    if (normalized.contains('rumah') || normalized.contains('kebutuhan')) {
      return 'Kebutuhan Rumah Tangga';
    }
    return 'Lainnya';
  }
  List<Map<String, dynamic>> get _filtered {
    final query = _search.text.trim().toLowerCase();
    return _products.where((p) {
      final category = _categoryLabel(p['category']);
      return (_category == 'Semua' || category == _category) &&
          (query.isEmpty || '${p['name']}'.toLowerCase().contains(query));
    }).toList();
  }

  /// DATABASE (Supabase): menyimpan pergerakan stok melalui InventoryService.
  Future<void> _adjustStock({Map<String, dynamic>? product}) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final quantity = TextEditingController();
    var movement = 'out';
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: StatefulBuilder(builder: (context, setModal) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product == null ? 'Tambah stok manual' : 'Sesuaikan stok', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: name, enabled: product == null, decoration: const InputDecoration(labelText: 'Nama produk', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Jumlah', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'in', label: Text('Stok masuk')), ButtonSegment(value: 'out', label: Text('Stok keluar'))], selected: {movement}, onSelectionChanged: (value) => setModal(() => movement = value.first)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () async {
            final amount = double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0;
            if (name.text.trim().isEmpty || amount <= 0) {
              _showMessage('Nama produk dan jumlah stok wajib diisi.', success: false);
              return;
            }
            try {
              final user = await ReceiptService().getCurrentUserContext();
              await _service.recordMovement(businessProfileId: user['business_profile_id'] as String, name: name.text, quantity: amount, movementType: movement, category: product?['category']?.toString() ?? 'lainnya', unit: product?['unit']?.toString());
              if (context.mounted) Navigator.pop(context);
              await _loadProducts();
              _showMessage('Stok berhasil diperbarui.', success: true);
            } catch (e) { _showMessage('Gagal menyimpan stok: $e', success: false); }
          }, child: const Text('Simpan')),
        ]))),
      )),
    );
    // Controller masih dipakai TextField saat animasi bottom sheet ditutup.
    // Jangan dispose di sini agar Flutter tidak memicu assertion dependents.
  }

  /// DATABASE (Supabase): memperbarui produk melalui InventoryService.
  Future<void> _editProduct(Map<String, dynamic> product) async {
    final name = TextEditingController(text: product['name']?.toString() ?? '');
    final unit = TextEditingController(text: product['unit']?.toString() ?? '');
    final minimum = TextEditingController(text: _qty(product['minimum_stock']));
    var category = _categoryLabel(product['category']);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: StatefulBuilder(builder: (context, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ubah Produk', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama produk', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()), items: _categories.where((item) => item != 'Semua').map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setModal(() => category = value ?? category)),
            const SizedBox(height: 12),
            TextField(controller: unit, decoration: const InputDecoration(labelText: 'Satuan (contoh: Pcs, Botol)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: minimum, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Batas stok minimum', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            FilledButton(onPressed: () async {
              if (name.text.trim().isEmpty) {
                _showMessage('Nama produk wajib diisi.', success: false);
                return;
              }
              try {
                await _service.updateProduct(id: product['id'].toString(), name: name.text, category: category.toLowerCase(), unit: unit.text, minimumStock: double.tryParse(minimum.text.replaceAll(',', '.')) ?? 0);
                if (context.mounted) Navigator.pop(context);
                await _loadProducts();
                _showMessage('Produk berhasil diperbarui.', success: true);
              } catch (e) { _showMessage('Gagal mengubah produk: $e', success: false); }
            }, child: const Text('Simpan Perubahan')),
          ],
        ))),
      )),
    );
    // Lihat catatan pada modal penyesuaian stok di atas.
  }

  /// DATABASE (Supabase): menghapus produk melalui InventoryService.
  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Hapus produk?'), content: Text('Produk “${product['name']}” dan riwayat stoknya akan dihapus.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Hapus'))]));
    if (confirmed != true) return;
    try {
      await _service.deleteProduct(product['id'].toString());
      await _loadProducts();
      _showMessage('Produk berhasil dihapus.', success: true);
    } catch (e) { _showMessage('Gagal menghapus produk: $e', success: false); }
  }

  @override
  Widget build(BuildContext context) {
    final low = _products.where((p) => _number(p['current_stock']) <= 10).length;
    final stockValue = _products.fold<double>(0, (sum, p) => sum + _number(p['current_stock']) * _number(p['last_unit_price']));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [FloatingActionButton.small(onPressed: () => _adjustStock(), backgroundColor: Colors.white, foregroundColor: const Color(0xFF3525CD), child: const Icon(Icons.add)), const SizedBox(height: 12), FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockChatPage(products: _products, onSaved: _loadProducts))), backgroundColor: const Color(0xFF3525CD), foregroundColor: Colors.white, icon: const Icon(Icons.chat_bubble_outline), label: const Text('Chat Stok'))]),
      body: SafeArea(child: RefreshIndicator(onRefresh: _loadProducts, child: ListView(padding: const EdgeInsets.fromLTRB(10, 16, 10, 92), children: [
        TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6C63FF)), hintText: 'Cari produk, kategori, atau supplier...', hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD8DEEC))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFD8DEEC))))),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _StatCard(title: 'Total Produk', value: '${_products.length}', color: const Color(0xFF1F2937))), const SizedBox(width: 12), Expanded(child: _StatCard(title: 'Nilai Stok', value: _rupiah(stockValue), color: const Color(0xFF1F2937)))]),
        const SizedBox(height: 18),
        Container(height: 112, padding: const EdgeInsets.symmetric(horizontal: 28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8, offset: const Offset(0, 3))]), child: Row(children: [Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Peringatan Stok Menipis', style: TextStyle(fontSize: 17, color: Color(0xFF37364A))), const SizedBox(height: 8), Text(low.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)))])), Container(width: 78, height: 78, decoration: const BoxDecoration(color: Color(0xFFFFD9D6), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Color(0xFF9B111E), size: 39))])),
        const SizedBox(height: 22),
        SizedBox(height: 34, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _categories.length, separatorBuilder: (_, __) => const SizedBox(width: 7), itemBuilder: (context, index) { final label = _categories[index]; final active = label == _category; return ChoiceChip(label: Text(label == 'Semua' ? 'Semua (${_products.length})' : label, style: TextStyle(fontSize: 10, color: active ? Colors.white : const Color(0xFF475569))), selected: active, onSelected: (_) => setState(() => _category = label), selectedColor: const Color(0xFF5B42D6), backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5), side: const BorderSide(color: Color(0xFFE2E8F0))), showCheckmark: false); })),
        const SizedBox(height: 14),
        Row(children: [const Expanded(child: Text('Katalog Produk & Stok Real-Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)))), Text('Urutkan: Stok Terendah', style: TextStyle(fontSize: 9, color: Colors.deepPurple.shade300))]),
        const SizedBox(height: 8),
        if (_loading) const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
        else if (_error != null) _InventoryMessage(text: 'Inventori belum siap. Jalankan inventory_schema.sql di Supabase.', onRetry: _loadProducts)
        else if (_filtered.isEmpty) const _InventoryMessage(text: 'Belum ada produk. Scan struk atau tambah stok manual.')
        else ..._filtered.map((p) => _ProductTile(product: p, category: _categoryLabel(p['category']), qty: _qty(p['current_stock']), rupiah: _rupiah, low: _number(p['current_stock']) <= 10, onTap: () => _adjustStock(product: p), onEdit: () => _editProduct(p), onDelete: () => _deleteProduct(p))),
      ]))),
    );
  }
}

class _StatCard extends StatelessWidget { final String title, value; final Color color; final bool alert; const _StatCard({required this.title, required this.value, required this.color, this.alert = false}); @override Widget build(BuildContext context) => Container(height: 110, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8, offset: const Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF37364A))), const Spacer(), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w800))])); }
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final String category;
  final String qty;
  final String Function(dynamic) rupiah;
  final bool low;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProductTile({required this.product, required this.category, required this.qty, required this.rupiah, required this.low, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final unit = product['unit']?.toString() ?? 'Pcs';
    final shortCategory = category.substring(0, category.length.clamp(0, 3) as int);
    final categoryColor = switch (category) {
      'Makanan' => const Color(0xFFFFE8D0),
      'Minuman' => const Color(0xFFDCEBFF),
      'Bahan Pokok' => const Color(0xFFFFF1BF),
      'Kebutuhan Rumah Tangga' => const Color(0xFFE5D9FF),
      _ => const Color(0xFFE2E8F0),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xFFE3E8F1))),
      child: InkWell(onTap: onTap, child: Row(children: [
        Container(width: 40, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(5)), child: Text(shortCategory.toUpperCase(), style: const TextStyle(fontSize: 7, color: Color(0xFF64748B)))),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)), const SizedBox(height: 9), Text('$category • ${rupiah(product['last_unit_price'])}', style: const TextStyle(fontSize: 7, color: Color(0xFF64748B)))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Stok: $qty $unit', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(low ? 'Batas Min: ${product['minimum_stock'] ?? 0} $unit' : 'Stok aman', style: const TextStyle(fontSize: 7, color: Color(0xFF94A3B8)))]),
        PopupMenuButton<String>(iconSize: 18, padding: EdgeInsets.zero, onSelected: (value) { if (value == 'edit') onEdit(); if (value == 'delete') onDelete(); }, itemBuilder: (context) => const [PopupMenuItem(value: 'edit', child: Text('Ubah produk')), PopupMenuItem(value: 'delete', child: Text('Hapus produk'))]),
        const SizedBox(width: 3),
        Container(width: 60, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: low ? const Color(0xFFFFDFDF) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)), child: Text(low ? 'Menipis' : 'Aman', style: TextStyle(fontSize: 8, color: low ? const Color(0xFFEF4444) : const Color(0xFF16A34A)))),
      ])),
    );
  }
}
class _InventoryMessage extends StatelessWidget { final String text; final VoidCallback? onRetry; const _InventoryMessage({required this.text, this.onRetry}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 56), child: Column(children: [const Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 42), const SizedBox(height: 9), Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))), if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Coba lagi'))])); }
