import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/receipt_item.dart';
import '../../models/receipt_result.dart';
import '../../services/receipt_service.dart';
import '../../widgets/editable_receipt_table.dart';

class ScanResultScreen extends StatefulWidget {
  final ReceiptResult result;
  final XFile imageFile;

  const ScanResultScreen({
    super.key,
    required this.result,
    required this.imageFile,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

/// DATABASE (Supabase): state layar yang menyimpan hasil scan struk.
class _ScanResultScreenState extends State<ScanResultScreen> {
  final ReceiptService receiptService = ReceiptService();
  bool isSaving = false;
  late List<ReceiptItem> receiptItems;

  @override
  void initState() {
    super.initState();
    receiptItems = widget.result.items
        .map(
          (item) => ReceiptItem(
            name: item.name,
            qty: item.qty,
            unit: item.unit,
            price: item.price,
            amount: item.amount,
            status: item.status,
            category: item.category,
            predictionConfidence: item.predictionConfidence,
          ),
        )
        .toList();
  }

  String _formatCurrency(num value) {
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String _todayString() {
    final now = DateTime.now();
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '${now.day} ${months[now.month]} ${now.year} $hour:$minute';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String _transactionTitle() {
    if (_hasText(widget.result.merchant)) return widget.result.merchant;
    if (_hasText(widget.result.supplier)) return widget.result.supplier;
    return 'Transaksi OCR';
  }

  /// DATABASE (Supabase): mengunggah foto lalu menyimpan struk dan transaksi.
  Future<void> _saveToDatabase() async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final imageUrl = await receiptService.uploadReceiptImage(
        widget.imageFile,
      );

      await receiptService.saveReceiptAndTransaction(
        imagePath: imageUrl,
        title: _transactionTitle(),
        amount: widget.result.total.toDouble(),
        transactionDate: DateTime.now(),
        merchantName: _hasText(widget.result.merchant)
            ? widget.result.merchant
            : widget.result.supplier,
        ocrRawText: widget.result.rawText,
        items: receiptItems,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Struk dan transaksi berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan ke database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6F52C8);

    final hasMerchant = _hasText(widget.result.merchant);
    final hasSupplier = _hasText(widget.result.supplier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Hasil Scan',
          style: TextStyle(
            color: Color(0xFF152238),
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF152238)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.check, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ekstraksi Berhasil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hasil pembacaan OCR',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EAF2)),
              ),
              child: Column(
                children: [
                  if (hasMerchant && hasSupplier) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBox(
                            icon: Icons.storefront_outlined,
                            title: 'Merchant',
                            value: widget.result.merchant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoBox(
                            icon: Icons.inventory_2_outlined,
                            title: 'Supplier',
                            value: widget.result.supplier,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 16),
                  ] else if (hasMerchant) ...[
                    _InfoBox(
                      icon: Icons.storefront_outlined,
                      title: 'Merchant',
                      value: widget.result.merchant,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 16),
                  ] else if (hasSupplier) ...[
                    _InfoBox(
                      icon: Icons.inventory_2_outlined,
                      title: 'Supplier',
                      value: widget.result.supplier,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _InfoBox(
                          icon: Icons.calendar_month_outlined,
                          title: 'Tanggal Pembelian',
                          value: _todayString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoBox(
                          icon: Icons.receipt_long_outlined,
                          title: 'Total Item Struk',
                          value: '${widget.result.detectedItemCount} Item',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoBox(
                    icon: Icons.verified_outlined,
                    title: 'Akurasi OCR',
                    value: '${widget.result.ocrConfidence.toStringAsFixed(0)}%',
                    valueStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 16),
                  _InfoBox(
                    icon: Icons.payments_outlined,
                    title: 'Total Harga Terdeteksi',
                    value: _formatCurrency(widget.result.total),
                    valueStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF152238),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            EditableReceiptTable(
              initialItems: receiptItems,
              total: widget.result.total,
              accentColor: purple,
              onItemsChanged: (items) {
                receiptItems = items;
              },
            ),
            if (widget.result.rawText.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _GeminiRawTextCard(rawText: widget.result.rawText),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveToDatabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB9ADDF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Icon(Icons.save_alt_rounded),
                label: Text(
                  isSaving ? 'Menyimpan...' : 'Simpan ke Database',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final TextStyle? valueStyle;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF2ECFF),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Icon(icon, color: const Color(0xFF6F52C8), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6F52C8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style:
                    valueStyle ??
                    const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF152238),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GeminiRawTextCard extends StatelessWidget {
  final String rawText;

  const _GeminiRawTextCard({required this.rawText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_snippet_outlined, color: Color(0xFF6F52C8)),
              SizedBox(width: 8),
              Text('Raw OCR', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(rawText, style: const TextStyle(color: Color(0xFF334155), height: 1.4)),
        ],
      ),
    );
  }
}
