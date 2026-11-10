import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';

class HistoryDetailScreen extends StatefulWidget {
  final String transactionId;
  final String? receiptId;

  const HistoryDetailScreen({
    super.key,
    required this.transactionId,
    this.receiptId,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

/// DATABASE (Supabase): state layar yang menampilkan detail transaksi dan struk.
class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final transactionService = TransactionService();

  bool isLoading = true;
  String? errorMessage;
  ReceiptExtractionDetail? detail;

  @override
  void initState() {
    super.initState();
    loadDetail();
  }

  /// DATABASE (Supabase): memuat detail transaksi melalui TransactionService.
  Future<void> loadDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await transactionService.getReceiptExtractionDetail(
        transactionId: widget.transactionId,
        receiptId: widget.receiptId,
      );

      setState(() {
        detail = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD HISTORY DETAIL ERROR: $e');
      setState(() {
        errorMessage = 'Gagal memuat hasil ekstraksi.';
        isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0;
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';

    try {
      final parsed = DateTime.parse(date);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$day-$month-${parsed.year}';
    } catch (_) {
      return date;
    }
  }

  String _prettyCategory(String? category) {
    final value = category?.trim();
    if (value == null || value.isEmpty) return 'Lainnya';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Hasil Ekstraksi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadDetail,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _EmptyCard(
                    title: errorMessage!,
                    subtitle: 'Tarik ke bawah untuk mencoba lagi.',
                  ),
                ],
              )
            : _DetailContent(
                detail: detail!,
                formatCurrency: _formatCurrency,
                formatDate: _formatDate,
                prettyCategory: _prettyCategory,
              ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final ReceiptExtractionDetail detail;
  final String Function(dynamic amount) formatCurrency;
  final String Function(String? date) formatDate;
  final String Function(String? category) prettyCategory;

  const _DetailContent({
    required this.detail,
    required this.formatCurrency,
    required this.formatDate,
    required this.prettyCategory,
  });

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;
    final receipt = detail.receipt;
    final rawText = receipt?['ocr_raw_text']?.toString().trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                _SummaryCard(
                  title: transaction['title']?.toString() ?? '-',
                  merchant: receipt?['merchant_name']?.toString(),
                  date: formatDate(
                    receipt?['receipt_date']?.toString() ??
                        transaction['transaction_date']?.toString(),
                  ),
                  amount: formatCurrency(
                    receipt?['extracted_total'] ?? transaction['amount'],
                  ),
                  status: receipt?['status']?.toString() ?? 'processed',
                ),
                const SizedBox(height: 18),
                _ClassificationCard(
                  items: detail.items,
                  prettyCategory: prettyCategory,
                ),
                const SizedBox(height: 18),
                _ItemsCard(
                  items: detail.items,
                  formatCurrency: formatCurrency,
                  prettyCategory: prettyCategory,
                ),
                const SizedBox(height: 18),
                if (rawText.isNotEmpty)
                  _RawTextCard(rawText: rawText)
                else
                  const _EmptyCard(
                    title: 'Raw OCR tidak tersedia',
                    subtitle:
                        'Transaksi ini belum memiliki teks hasil ekstraksi.',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
//class histori
class _SummaryCard extends StatelessWidget {
  final String title;
  final String? merchant;
  final String date;
  final String amount;
  final String status;

  const _SummaryCard({
    required this.title,
    required this.merchant,
    required this.date,
    required this.amount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      merchant?.isNotEmpty == true
                          ? merchant!
                          : 'Hasil scan struk',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryInfo(label: 'Tanggal', value: date),
              ),
              Expanded(
                child: _SummaryInfo(label: 'Status', value: status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Terdeteksi',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryInfo extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(String? category) prettyCategory;

  const _ClassificationCard({
    required this.items,
    required this.prettyCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hasil Klasifikasi LSTM',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Belum ada hasil klasifikasi untuk struk ini.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...items.map((item) {
              final category = prettyCategory(
                item['predicted_category_name']?.toString(),
              );
              final confidence = item['prediction_confidence'];

              return _ClassificationRow(
                itemName: item['item_name']?.toString() ?? '-',
                category: category,
                confidence: confidence,
              );
            }),
        ],
      ),
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  final String itemName;
  final String category;
  final dynamic confidence;

  const _ClassificationRow({
    required this.itemName,
    required this.category,
    required this.confidence,
  });

  String get confidenceLabel {
    final value = confidence is num
        ? (confidence as num).toDouble()
        : double.tryParse(confidence?.toString() ?? '');

    if (value == null || value <= 0) return 'Akurasi LSTM (confidence) -';
    final percent = value <= 1 ? value * 100 : value;
    return 'Akurasi LSTM (confidence) ${percent.round()}%';
  }

  Color get confidenceColor {
    final value = confidence is num
        ? (confidence as num).toDouble()
        : double.tryParse(confidence?.toString() ?? '');

    if (value == null || value <= 0) return const Color(0xFF64748B);
    final percent = value <= 1 ? value * 100 : value;
    if (percent >= 80) return const Color(0xFF16A34A);
    if (percent >= 60) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFF2F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 138),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            confidenceLabel,
            style: TextStyle(
              color: confidenceColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(dynamic amount) formatCurrency;
  final String Function(String? category) prettyCategory;

  const _ItemsCard({
    required this.items,
    required this.formatCurrency,
    required this.prettyCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Item',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Belum ada item tersimpan untuk struk ini.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...items.map((item) {
              return _ItemRow(
                name: item['item_name']?.toString() ?? '-',
                quantity: item['quantity']?.toString() ?? '1',
                unit: item['unit']?.toString(),
                amount: formatCurrency(item['total_price']),
                category: prettyCategory(
                  item['predicted_category_name']?.toString(),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String name;
  final String quantity;
  final String? unit;
  final String amount;
  final String category;

  const _ItemRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.amount,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEFF2F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$quantity ${unit ?? ''} | $category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawTextCard extends StatelessWidget {
  final String rawText;

  const _RawTextCard({required this.rawText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Raw OCR',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            rawText,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2563EB),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFEFF2F6)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
