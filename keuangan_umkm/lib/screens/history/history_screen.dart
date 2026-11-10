import 'package:flutter/material.dart';
import '../../services/transaction_service.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

/// DATABASE (Supabase): state layar yang menampilkan data transaksi.
class _HistoryScreenState extends State<HistoryScreen> {
  final transactionService = TransactionService();
  final searchController = TextEditingController();

  List<Map<String, dynamic>> transactions = [];
  HistoryPeriodFilter selectedFilter = HistoryPeriodFilter.week;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// DATABASE (Supabase): memuat transaksi melalui TransactionService.
  Future<void> loadTransactions() async {
    try {
      final data = await transactionService.getTransactions();

      setState(() {
        transactions = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal memuat transaksi.';
        isLoading = false;
      });
    }
  }

  String formatCurrency(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount.toString()) ?? 0;
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  String formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';

    try {
      final parsed = DateTime.parse(date);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      return date;
    }
  }

  String formatSource(String? source) {
    if (source == null) return '-';

    switch (source) {
      case 'ocr':
        return 'OCR';
      case 'ai':
        return 'AI';
      case 'manual_review':
        return 'Manual';
      default:
        return source;
    }
  }

  List<Map<String, dynamic>> get filteredTransactions {
    final query = searchController.text.trim().toLowerCase();

    return transactions.where((trx) {
      final title = trx['title']?.toString().toLowerCase() ?? '';
      final description = trx['description']?.toString().toLowerCase() ?? '';
      final matchesQuery =
          query.isEmpty || title.contains(query) || description.contains(query);

      if (!matchesQuery) return false;

      final date = DateTime.tryParse(
        trx['transaction_date']?.toString() ?? '',
      );
      return _matchesPeriod(date);
    }).toList();
  }

  double get filteredTotal {
    return filteredTransactions.fold<double>(0, (sum, trx) {
      final amount = trx['amount'];
      if (amount is num) return sum + amount.toDouble();
      return sum + (double.tryParse(amount?.toString() ?? '') ?? 0);
    });
  }

  bool _matchesPeriod(DateTime? date) {
    if (date == null) return false;

    final now = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    switch (selectedFilter) {
      case HistoryPeriodFilter.week:
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return normalizedDate.isAtSameMomentAs(weekStart) ||
            (normalizedDate.isAfter(weekStart) && normalizedDate.isBefore(weekEnd));
      case HistoryPeriodFilter.month:
        return date.year == now.year && date.month == now.month;
      case HistoryPeriodFilter.year:
        return date.year == now.year;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FB),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat Transaksi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadTransactions,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              )
            : transactions.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Text(
                      'Belum ada transaksi.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              )
            : _HistoryList(
                transactions: filteredTransactions,
                totalAmount: formatCurrency(filteredTotal),
                searchController: searchController,
                selectedFilter: selectedFilter,
                onSearchChanged: (_) => setState(() {}),
                onFilterChanged: (filter) {
                  setState(() {
                    selectedFilter = filter;
                  });
                },
                formatDate: formatDate,
                formatSource: formatSource,
                formatCurrency: formatCurrency,
              ),
      ),
    );
  }
}

enum HistoryPeriodFilter { week, month, year }

class _HistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final String totalAmount;
  final TextEditingController searchController;
  final HistoryPeriodFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HistoryPeriodFilter> onFilterChanged;
  final String Function(String? date) formatDate;
  final String Function(String? source) formatSource;
  final String Function(dynamic amount) formatCurrency;

  const _HistoryList({
    required this.transactions,
    required this.totalAmount,
    required this.searchController,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.formatDate,
    required this.formatSource,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 118),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _HistorySearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 12),
                _HistoryFilterChips(
                  selectedFilter: selectedFilter,
                  onChanged: onFilterChanged,
                ),
                const SizedBox(height: 14),
                _HistorySummary(
                  count: transactions.length,
                  totalAmount: totalAmount,
                ),
                const SizedBox(height: 16),
                if (transactions.isEmpty)
                  const _FilteredEmptyCard()
                else
                  ...transactions.map((trx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _HistoryCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HistoryDetailScreen(
                                transactionId: trx['id'].toString(),
                                receiptId: trx['receipt_id']?.toString(),
                              ),
                            ),
                          );
                        },
                        title: trx['title']?.toString() ?? '-',
                        subtitle:
                            '${formatDate(trx['transaction_date']?.toString())} | ${formatSource(trx['source_input']?.toString())}',
                        amount: formatCurrency(trx['amount']),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _HistorySearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Cari merchant atau transaksi',
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF94A3B8),
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF94A3B8),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3525CD), width: 1.4),
        ),
      ),
    );
  }
}

class _HistoryFilterChips extends StatelessWidget {
  final HistoryPeriodFilter selectedFilter;
  final ValueChanged<HistoryPeriodFilter> onChanged;

  const _HistoryFilterChips({
    required this.selectedFilter,
    required this.onChanged,
  });

  static const labels = {
    HistoryPeriodFilter.week: 'Minggu',
    HistoryPeriodFilter.month: 'Bulan',
    HistoryPeriodFilter.year: 'Tahun',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HistoryPeriodFilter.values.map((filter) {
          final isSelected = filter == selectedFilter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[filter]!),
              selected: isSelected,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              selectedColor: const Color(0xFFEFF5FF),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF3525CD)
                    : const Color(0xFFE2E8F0),
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF3525CD)
                    : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final int count;
  final String totalAmount;

  const _HistorySummary({required this.count, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3525CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count transaksi ditemukan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE5EDFF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            totalAmount,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyCard extends StatelessWidget {
  const _FilteredEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            color: Color(0xFF94A3B8),
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            'Tidak ada riwayat yang cocok.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Coba ubah kata kunci atau periode filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final String amount;

  const _HistoryCard({
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
