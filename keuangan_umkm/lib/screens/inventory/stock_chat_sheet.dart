import 'package:flutter/material.dart';

import '../../services/inventory_service.dart';
import '../../services/receipt_service.dart';

class StockChatPage extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final VoidCallback onSaved;

  const StockChatPage({
    super.key,
    required this.products,
    required this.onSaved,
  });

  @override
  State<StockChatPage> createState() => _StockChatPageState();
}

/// DATABASE (Supabase): state layar yang menyimpan stok keluar melalui InventoryService.
class _StockChatPageState extends State<StockChatPage> {
  final _input = TextEditingController();
  String _message = 'Contoh: Pop Mie Pedas terjual 8 pcs';
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  /// DATABASE (Supabase): mencatat pergerakan stok setelah perintah disetujui.
  Future<void> _readCommand() async {
    final command = _input.text.trim();
    final quantityMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(command);
    final actionMatch = RegExp(
      r'\b(terjual|jual|keluar|kurangi|kurangin|kurang)\b',
      caseSensitive: false,
    ).firstMatch(command);

    if (quantityMatch == null || actionMatch == null) {
      setState(() {
        _message = 'Tulis nama produk dan jumlahnya, misalnya “Pop Mie Ayam terjual 2 pcs”.';
      });
      return;
    }

    final quantity = double.parse(quantityMatch.group(1)!.replaceAll(',', '.'));
    final namePart = _productPhrase(command, actionMatch, quantityMatch);
    final matchedProduct = _findExactProduct(namePart);

    if (matchedProduct == null) {
      setState(() {
        _message =
            'Produk belum cocok secara tepat. Tulis nama seperti di Inventori agar stok barang lain tidak ikut berkurang.';
      });
      return;
    }

    final before = _number(matchedProduct['current_stock']);
    if (quantity > before) {
      setState(() {
        _message =
            'Stok ${matchedProduct['name']} hanya ${before.toStringAsFixed(0)} pcs.';
      });
      return;
    }

    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi pengurangan stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              matchedProduct['name']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('Aksi: Stok keluar'),
            Text('Jumlah: ${quantity.toStringAsFixed(0)} pcs'),
            Text(
              'Stok: ${before.toStringAsFixed(0)} → '
              '${(before - quantity).toStringAsFixed(0)} pcs',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setuju'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _busy = true);
    try {
      final user = await ReceiptService().getCurrentUserContext();
      await InventoryService().recordMovement(
        businessProfileId: user['business_profile_id'] as String,
        name: matchedProduct['name'].toString(),
        quantity: quantity,
        movementType: 'out',
        category: matchedProduct['category']?.toString() ?? 'lainnya',
        unit: matchedProduct['unit']?.toString() ?? 'pcs',
        note: 'Stok keluar dari Chat Stok',
      );
      widget.onSaved();
      if (mounted) {
        setState(() {
          _input.clear();
          _message = 'Stok berhasil dikurangi.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok berhasil dikurangi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Gagal menyimpan: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengurangi stok: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Map<String, dynamic>? _findExactProduct(String typedName) {
    final queryTokens = _nameTokens(typedName);
    if (queryTokens.isEmpty) return null;

    final candidates = <_ProductCandidate>[];
    for (final product in widget.products) {
      final productTokens = _nameTokens(product['name']?.toString() ?? '');
      if (productTokens.isEmpty || !queryTokens.every(productTokens.contains)) {
        continue;
      }
      candidates.add(_ProductCandidate(product, productTokens.length - queryTokens.length));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.extraTokens.compareTo(b.extraTokens));
    final best = candidates.first;

    // Nama persis boleh langsung dipakai. Untuk nama singkat, hanya izinkan
    // satu kata tambahan (misalnya ukuran yang tidak ikut ditulis); jika ada
    // varian lain seperti Pedas/Dower, minta pengguna mengetik lebih spesifik.
    final tied = candidates.where((item) => item.extraTokens == best.extraTokens);
    if (best.extraTokens > 1 || tied.length != 1) return null;
    return best.product;
  }

  String _productPhrase(
    String command,
    Match actionMatch,
    Match quantityMatch,
  ) {
    // Mendukung dua gaya: "Pop Mie Ayam terjual 2" dan
    // "kurangi stok Pop Mie Ayam 2".
    var phrase = actionMatch.start == 0
        ? command.substring(actionMatch.end)
        : command.substring(0, actionMatch.start);
    phrase = phrase.replaceFirst(quantityMatch.group(0)!, ' ');
    return phrase.replaceFirst(RegExp(r'^\s*stok\s*', caseSensitive: false), '').trim();
  }

  List<String> _nameTokens(String value) {
    var normalized = value.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'pop\s*mie|popmie'), 'pop mie');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    normalized = normalized.replaceAll(
      RegExp(r'\b\d+(?:ml|gr|g|kg|pcs|pc)?\b'),
      ' ',
    );
    const ignored = {'produk', 'barang', 'stok', 'stik', 'pcs', 'pc'};
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1 && !ignored.contains(token))
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Chat Stok'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Tulis stok barang yang terjual. Contoh: “Pop Mie Pedas terjual 8 pcs”. Saya akan meminta persetujuan sebelum stok berubah.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2DFFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(_message),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.fromLTRB(20, 12, 20, keyboardBottom + 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _busy ? null : _readCommand(),
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Pop Mie Pedas terjual 8 pcs',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: FilledButton(
                      onPressed: _busy ? null : _readCommand,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCandidate {
  final Map<String, dynamic> product;
  final int extraTokens;

  const _ProductCandidate(this.product, this.extraTokens);
}
