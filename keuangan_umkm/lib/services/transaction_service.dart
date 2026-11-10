import 'package:supabase_flutter/supabase_flutter.dart';

import 'report_service.dart';

/// DATABASE (Supabase): akses baca data transaksi, struk, dan item struk.
class TransactionService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// DATABASE (Supabase): membaca daftar transaksi pengguna.
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final response = await supabase
        .from('transactions')
        .select('''
          id,
          title,
          description,
          amount,
          transaction_date,
          transaction_type,
          source_input,
          receipt_id,
          created_at
        ''')
        .eq('user_id', user.id)
        .order('transaction_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// DATABASE (Supabase): menghitung total pengeluaran bulan ini dari transactions.
  Future<double> getCurrentMonthExpenseTotal() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    final response = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id)
        .eq('transaction_type', 'expense')
        .gte('transaction_date', firstDay.toIso8601String().split('T').first)
        .lt('transaction_date', nextMonth.toIso8601String().split('T').first);

    final data = List<Map<String, dynamic>>.from(response);

    double total = 0;
    for (final item in data) {
      final amount = item['amount'];
      if (amount is num) {
        total += amount.toDouble();
      } else {
        total += double.tryParse(amount.toString()) ?? 0;
      }
    }

    return total;
  }

  /// DATABASE (Supabase): menghitung jumlah transaksi bulan ini.
  Future<int> getCurrentMonthTransactionCount() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    final response = await supabase
        .from('transactions')
        .select('id')
        .eq('user_id', user.id)
        .eq('transaction_type', 'expense')
        .gte('transaction_date', firstDay.toIso8601String().split('T').first)
        .lt('transaction_date', nextMonth.toIso8601String().split('T').first);

    return List<Map<String, dynamic>>.from(response).length;
  }

  /// DATABASE (Supabase): membaca sumber transaksi terbanyak bulan ini.
  Future<Map<String, dynamic>?> getTopTransactionSourceThisMonth() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    final response = await supabase
        .from('transactions')
        .select('title, description')
        .eq('user_id', user.id)
        .eq('transaction_type', 'expense')
        .gte('transaction_date', firstDay.toIso8601String().split('T').first)
        .lt('transaction_date', nextMonth.toIso8601String().split('T').first);

    final data = List<Map<String, dynamic>>.from(response);
    if (data.isEmpty) return null;

    final counts = <String, int>{};
    for (final item in data) {
      final source = (item['description'] ?? item['title'] ?? '-')
          .toString()
          .trim();
      if (source.isEmpty || source == '-') continue;
      counts[source] = (counts[source] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {'name': entries.first.key, 'count': entries.first.value};
  }

  /// DATABASE (Supabase): membaca transaksi terbaru.
  Future<List<Map<String, dynamic>>> getLatestTransactions({
    int limit = 3,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final response = await supabase
        .from('transactions')
        .select('''
          id,
          title,
          amount,
          transaction_date,
          source_input
        ''')
        .eq('user_id', user.id)
        .order('transaction_date', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// DATABASE (Supabase): membaca detail transaksi, struk, dan item struk.
  Future<ReceiptExtractionDetail> getReceiptExtractionDetail({
    required String transactionId,
    String? receiptId,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final transaction = await supabase
        .from('transactions')
        .select('''
          id,
          title,
          description,
          amount,
          transaction_date,
          source_input,
          receipt_id
        ''')
        .eq('id', transactionId)
        .eq('user_id', user.id)
        .single();

    final resolvedReceiptId =
        receiptId ?? transaction['receipt_id']?.toString();

    Map<String, dynamic>? receipt;
    var items = <Map<String, dynamic>>[];

    if (resolvedReceiptId != null && resolvedReceiptId.isNotEmpty) {
      receipt = await supabase
          .from('receipts')
          .select('''
            id,
            image_path,
            merchant_name,
            receipt_date,
            total_amount,
            ocr_raw_text,
            extracted_total,
            extraction_method,
            classification_method,
            status,
            created_at
          ''')
          .eq('id', resolvedReceiptId)
          .eq('user_id', user.id)
          .maybeSingle();

      items = await _getReceiptItemsByReceiptId(resolvedReceiptId);
    }

    if (items.isEmpty) {
      final merchantName =
          receipt?['merchant_name']?.toString() ??
          transaction['description']?.toString() ??
          transaction['title']?.toString();

      items = await _getReceiptItemsByMerchant(
        userId: user.id,
        merchantName: merchantName,
        receiptDate:
            receipt?['receipt_date']?.toString() ??
            transaction['transaction_date']?.toString(),
      );
    }

    return ReceiptExtractionDetail(
      transaction: Map<String, dynamic>.from(transaction),
      receipt: receipt == null ? null : Map<String, dynamic>.from(receipt),
      items: items,
    );
  }

  /// DATABASE (Supabase): membaca receipt_items berdasarkan ID struk.
  Future<List<Map<String, dynamic>>> _getReceiptItemsByReceiptId(
    String receiptId,
  ) async {
    final response = await supabase
        .from('receipt_items')
        .select('''
          id,
          receipt_id,
          item_name,
          normalized_item_name,
          quantity,
          unit,
          unit_price,
          total_price,
          predicted_category_name,
          prediction_confidence,
          created_at
        ''')
        .eq('receipt_id', receiptId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// DATABASE (Supabase): mencari receipt_items berdasarkan merchant dan tanggal.
  Future<List<Map<String, dynamic>>> _getReceiptItemsByMerchant({
    required String userId,
    required String? merchantName,
    required String? receiptDate,
  }) async {
    final merchant = merchantName?.trim();
    if (merchant == null || merchant.isEmpty || merchant == '-') {
      return <Map<String, dynamic>>[];
    }

    var receiptQuery = supabase
        .from('receipts')
        .select('id')
        .eq('user_id', userId)
        .ilike('merchant_name', '%$merchant%');

    if (receiptDate != null && receiptDate.isNotEmpty) {
      receiptQuery = receiptQuery.eq('receipt_date', receiptDate);
    }

    final receiptRows = await receiptQuery
        .order('created_at', ascending: false)
        .limit(8);
    final receiptIds = List<Map<String, dynamic>>.from(
      receiptRows,
    ).map((row) => row['id']).whereType<String>().toList();

    if (receiptIds.isEmpty) return <Map<String, dynamic>>[];

    final response = await supabase
        .from('receipt_items')
        .select('''
          id,
          receipt_id,
          item_name,
          normalized_item_name,
          quantity,
          unit,
          unit_price,
          total_price,
          predicted_category_name,
          prediction_confidence,
          created_at
        ''')
        .inFilter('receipt_id', receiptIds)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// DATABASE (Supabase): membaca transaksi dan item struk untuk analisis bulanan.
  Future<MonthlyAnalysisData> getCurrentMonthAnalysis() {
    return getAnalysis(ReportPeriod.monthly);
  }

  /// DATABASE (Supabase): membaca transaksi dan item struk sesuai periode.
  Future<MonthlyAnalysisData> getAnalysis(ReportPeriod period) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final range = _analysisRangeFor(period);

    final transactions = await supabase
        .from('transactions')
        .select('amount, transaction_date')
        .eq('user_id', user.id)
        .eq('transaction_type', 'expense')
        .gte('transaction_date', _dateOnly(range.start))
        .lt('transaction_date', _dateOnly(range.end));

    final previousTransactions = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', user.id)
        .eq('transaction_type', 'expense')
        .gte(
          'transaction_date',
          _dateOnly(range.previousStart),
        )
        .lt('transaction_date', _dateOnly(range.start));

    final transactionData = List<Map<String, dynamic>>.from(transactions);
    final previousTransactionData = List<Map<String, dynamic>>.from(
      previousTransactions,
    );

    var itemData = <Map<String, dynamic>>[];
    try {
      final receiptRows = await supabase
          .from('receipts')
          .select('id')
          .eq('user_id', user.id)
          .gte('receipt_date', _dateOnly(range.start))
          .lt('receipt_date', _dateOnly(range.end));

      final receiptIds = List<Map<String, dynamic>>.from(
        receiptRows,
      ).map((row) => row['id']).where((id) => id != null).toList();

      itemData = receiptIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await supabase
                  .from('receipt_items')
                  .select('predicted_category_name, total_price')
                  .inFilter('receipt_id', receiptIds),
            );
    } catch (_) {
      itemData = <Map<String, dynamic>>[];
    }

    final totalExpense = transactionData.fold<double>(
      0,
      (sum, item) => sum + _amountFrom(item['amount']),
    );
    final previousTotalExpense = previousTransactionData.fold<double>(
      0,
      (sum, item) => sum + _amountFrom(item['amount']),
    );

    final weeklyTotals = List<double>.filled(range.chartLabels.length, 0);
    for (final trx in transactionData) {
      final date = DateTime.tryParse(trx['transaction_date']?.toString() ?? '');
      if (date == null) continue;

      final index = range.bucketIndex(date);
      if (index >= 0 && index < weeklyTotals.length) {
        weeklyTotals[index] += _amountFrom(trx['amount']);
      }
    }

    final categoryTotals = <String, double>{};
    for (final item in itemData) {
      final category = _displayCategory(
        item['predicted_category_name']?.toString(),
      );
      final amount = _amountFrom(item['total_price']);
      if (amount <= 0) continue;

      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    final categorySummaries =
        categoryTotals.entries
            .map(
              (entry) => CategoryAnalysisItem(
                label: entry.key,
                amount: entry.value,
                percent: totalExpense == 0 ? 0 : entry.value / totalExpense,
              ),
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return MonthlyAnalysisData(
      monthName: range.title,
      totalExpense: totalExpense,
      previousTotalExpense: previousTotalExpense,
      weeklyTotals: weeklyTotals,
      chartLabels: range.chartLabels,
      categories: categorySummaries.take(5).toList(),
    );
  }

  _AnalysisRange _analysisRangeFor(ReportPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case ReportPeriod.weekly:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return _AnalysisRange(
          start: start,
          end: start.add(const Duration(days: 7)),
          previousStart: start.subtract(const Duration(days: 7)),
          title: 'Minggu ini',
          chartLabels: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
          bucketIndex: (date) => DateTime(date.year, date.month, date.day)
              .difference(start)
              .inDays,
        );
      case ReportPeriod.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final previousStart = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
        return _AnalysisRange(
          start: start,
          end: end,
          previousStart: previousStart,
          title: _monthName(now.month),
          chartLabels: const ['Mg 1', 'Mg 2', 'Mg 3', 'Mg 4'],
          bucketIndex: (date) => ((date.day - 1) ~/ 7).clamp(0, 3),
        );
      case ReportPeriod.yearly:
        final start = DateTime(now.year, 1, 1);
        return _AnalysisRange(
          start: start,
          end: DateTime(now.year + 1, 1, 1),
          previousStart: DateTime(now.year - 1, 1, 1),
          title: 'Tahun ${now.year}',
          chartLabels: const [
            'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
            'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
          ],
          bucketIndex: (date) => date.month - 1,
        );
    }
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;

  double _amountFrom(dynamic amount) {
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount?.toString() ?? '') ?? 0;
  }

  String _displayCategory(String? rawCategory) {
    final category = (rawCategory ?? '').trim().toLowerCase();

    switch (category) {
      case 'bahan baku':
      case 'sembako':
      case 'bahan baku (sembako)':
        return 'Bahan Baku (Sembako)';
      case 'mandi':
      case 'cuci':
      case 'peralatan mandi/cuci':
      case 'peralatan mandi':
        return 'Peralatan Mandi/Cuci';
      case 'makanan':
      case 'makanan ringan':
        return 'Makanan';
      case 'lainnya':
      case '':
        return 'Lainnya';
      default:
        return rawCategory!.trim();
    }
  }

  String _monthName(int month) {
    const names = [
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

    return names[month];
  }
}

class MonthlyAnalysisData {
  final String monthName;
  final double totalExpense;
  final double previousTotalExpense;
  final List<double> weeklyTotals;
  final List<String> chartLabels;
  final List<CategoryAnalysisItem> categories;

  const MonthlyAnalysisData({
    required this.monthName,
    required this.totalExpense,
    required this.previousTotalExpense,
    required this.weeklyTotals,
    required this.chartLabels,
    required this.categories,
  });

  double get trendPercent {
    if (previousTotalExpense <= 0) return totalExpense > 0 ? 100 : 0;
    return ((totalExpense - previousTotalExpense) / previousTotalExpense) * 100;
  }

  int get topWeekIndex {
    if (weeklyTotals.isEmpty) return 0;

    var selectedIndex = 0;
    for (var i = 1; i < weeklyTotals.length; i++) {
      if (weeklyTotals[i] > weeklyTotals[selectedIndex]) {
        selectedIndex = i;
      }
    }

    return selectedIndex;
  }

  CategoryAnalysisItem? get topCategory {
    if (categories.isEmpty) return null;
    return categories.first;
  }
}

class CategoryAnalysisItem {
  final String label;
  final double amount;
  final double percent;

  const CategoryAnalysisItem({
    required this.label,
    required this.amount,
    required this.percent,
  });
}

class ReceiptExtractionDetail {
  final Map<String, dynamic> transaction;
  final Map<String, dynamic>? receipt;
  final List<Map<String, dynamic>> items;

  const ReceiptExtractionDetail({
    required this.transaction,
    required this.receipt,
    required this.items,
  });
}

class _AnalysisRange {
  final DateTime start;
  final DateTime end;
  final DateTime previousStart;
  final String title;
  final List<String> chartLabels;
  final int Function(DateTime date) bucketIndex;

  const _AnalysisRange({
    required this.start,
    required this.end,
    required this.previousStart,
    required this.title,
    required this.chartLabels,
    required this.bucketIndex,
  });
}
