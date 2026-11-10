import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ReportPeriod { weekly, monthly, yearly }

/// DATABASE (Supabase): mengambil data struk dan item untuk laporan.
class ReportService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// DATABASE (Supabase): membaca receipts dan receipt_items untuk laporan.
  Future<ExpenseReportData> getExpenseReport(ReportPeriod period) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    final range = _dateRangeForPeriod(period);

    final receiptsResponse = await supabase
        .from('receipts')
        .select('id, merchant_name, receipt_date, created_at')
        .eq('user_id', user.id)
        .gte('receipt_date', _dateOnly(range.start))
        .lt('receipt_date', _dateOnly(range.end))
        .order('receipt_date', ascending: true);

    final receipts = List<Map<String, dynamic>>.from(receiptsResponse);
    final receiptIds = receipts
        .map((receipt) => receipt['id'])
        .whereType<String>()
        .toList();

    if (receiptIds.isEmpty) {
      return ExpenseReportData(
        period: period,
        startDate: range.start,
        endDate: range.end,
        rows: const [],
      );
    }

    final receiptMap = {
      for (final receipt in receipts)
        receipt['id'].toString(): Map<String, dynamic>.from(receipt),
    };

    final itemsResponse = await supabase
        .from('receipt_items')
        .select('''
          receipt_id,
          item_name,
          quantity,
          unit,
          total_price,
          predicted_category_name,
          created_at
        ''')
        .inFilter('receipt_id', receiptIds)
        .order('created_at', ascending: true);

    final items = List<Map<String, dynamic>>.from(itemsResponse);
    final rows = <ExpenseReportRow>[];

    for (final item in items) {
      final receiptId = item['receipt_id']?.toString();
      final receipt = receiptMap[receiptId];
      if (receipt == null) continue;

      rows.add(
        ExpenseReportRow(
          merchant: receipt['merchant_name']?.toString().trim().isNotEmpty ==
                  true
              ? receipt['merchant_name'].toString()
              : 'Tanpa Merchant',
          date: DateTime.tryParse(receipt['receipt_date']?.toString() ?? ''),
          itemName: item['item_name']?.toString() ?? '-',
          quantity: _quantityLabel(item['quantity'], item['unit']),
          category: _prettyCategory(
            item['predicted_category_name']?.toString(),
          ),
          amount: _amountFrom(item['total_price']),
        ),
      );
    }

    return ExpenseReportData(
      period: period,
      startDate: range.start,
      endDate: range.end,
      rows: rows,
    );
  }

  Future<void> downloadExpenseReport(ReportPeriod period) async {
    final data = await getExpenseReport(period);
    final bytes = await buildExpenseReportPdf(data);

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'laporan_pengeluaran_${data.fileSuffix}.pdf',
    );
  }

  Future<Uint8List> buildExpenseReportPdf(ExpenseReportData data) async {
    final document = pw.Document();
    final total = data.rows.fold<double>(0, (sum, row) => sum + row.amount);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Text(
              'Laporan Pengeluaran UMKM',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${data.periodLabel} | ${_formatDate(data.startDate)} - ${_formatDate(data.endDate.subtract(const Duration(days: 1)))}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.SizedBox(height: 18),
            if (data.rows.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Text(
                  'Belum ada data pengeluaran pada periode ini.',
                  textAlign: pw.TextAlign.center,
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey500),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(1.1),
                  2: const pw.FlexColumnWidth(1.35),
                  3: const pw.FixedColumnWidth(42),
                  4: const pw.FlexColumnWidth(0.85),
                  5: const pw.FixedColumnWidth(64),
                },
                headers: const [
                  'No',
                  'Merchant',
                  'Item',
                  'Qty',
                  'Kategori',
                  'Harga',
                ],
                data: data.rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return [
                    '${index + 1}',
                    row.merchant,
                    row.itemName,
                    row.quantity,
                    row.category,
                    _formatCurrency(row.amount),
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  border: pw.Border.all(color: PdfColors.green600),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _formatCurrency(total),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  ({DateTime start, DateTime end}) _dateRangeForPeriod(ReportPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case ReportPeriod.weekly:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      case ReportPeriod.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        return (start: start, end: end);
      case ReportPeriod.yearly:
        final start = DateTime(now.year, 1, 1);
        return (start: start, end: DateTime(now.year + 1, 1, 1));
    }
  }

  String _quantityLabel(dynamic quantity, dynamic unit) {
    final qty = quantity?.toString().trim();
    final unitText = unit?.toString().trim();
    final parsedQty = double.tryParse(qty ?? '');
    final qtyLabel = qty == null || qty.isEmpty
        ? '1'
        : parsedQty != null && parsedQty == parsedQty.roundToDouble()
        ? parsedQty.toStringAsFixed(0)
        : qty;

    if (unitText == null || unitText.isEmpty) return qtyLabel;
    return '$qtyLabel $unitText';
  }

  String _prettyCategory(String? rawCategory) {
    final category = rawCategory?.trim();
    if (category == null || category.isEmpty) return 'Lainnya';

    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  double _amountFrom(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '') ?? 0;
  }

  String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String _formatCurrency(num value) {
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}

class ExpenseReportData {
  final ReportPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final List<ExpenseReportRow> rows;

  const ExpenseReportData({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.rows,
  });

  String get periodLabel {
    switch (period) {
      case ReportPeriod.weekly:
        return 'Mingguan';
      case ReportPeriod.monthly:
        return 'Bulanan';
      case ReportPeriod.yearly:
        return 'Tahunan';
    }
  }

  String get fileSuffix {
    final start = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
    final end = endDate.subtract(const Duration(days: 1));
    final endLabel = '${end.year}${end.month.toString().padLeft(2, '0')}${end.day.toString().padLeft(2, '0')}';
    return '${periodLabel.toLowerCase()}_${start}_$endLabel';
  }
}

class ExpenseReportRow {
  final String merchant;
  final DateTime? date;
  final String itemName;
  final String quantity;
  final String category;
  final double amount;

  const ExpenseReportRow({
    required this.merchant,
    required this.date,
    required this.itemName,
    required this.quantity,
    required this.category,
    required this.amount,
  });
}
