import 'package:flutter/material.dart';
import '../../services/report_service.dart';
import '../../services/transaction_service.dart';
import 'report_preview_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

/// DATABASE (Supabase): state layar yang memakai data analisis transaksi.
class _AnalysisScreenState extends State<AnalysisScreen> {
  final transactionService = TransactionService();

  bool isLoading = true;
  String? errorMessage;
  MonthlyAnalysisData? analysis;
  ReportPeriod selectedPeriod = ReportPeriod.monthly;

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  /// DATABASE (Supabase): memuat analisis bulanan melalui TransactionService.
  Future<void> loadAnalysis() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await transactionService.getAnalysis(selectedPeriod);
      setState(() {
        analysis = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD ANALYSIS ERROR: $e');
      setState(() {
        errorMessage = 'Data analisis belum bisa dimuat.';
        isLoading = false;
      });
    }
  }

  Future<void> openReportOptions() async {
    final selectedPeriod = await showModalBottomSheet<ReportPeriod>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Unduh Laporan PDF',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih periode laporan pengeluaran yang ingin diunduh.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _ReportOptionTile(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Mingguan',
                  subtitle: 'Laporan dari Senin sampai Minggu minggu ini',
                  onTap: () => Navigator.pop(context, ReportPeriod.weekly),
                ),
                _ReportOptionTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Bulanan',
                  subtitle: 'Laporan dari awal sampai akhir bulan ini',
                  onTap: () => Navigator.pop(context, ReportPeriod.monthly),
                ),
                _ReportOptionTile(
                  icon: Icons.event_available_rounded,
                  title: 'Tahunan',
                  subtitle: 'Laporan dari Januari sampai Desember tahun ini',
                  onTap: () => Navigator.pop(context, ReportPeriod.yearly),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedPeriod == null) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportPreviewScreen(period: selectedPeriod),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnalysisHeader(
              onDownload: openReportOptions,
            ),
            _PeriodTabs(
              selectedPeriod: selectedPeriod,
              onChanged: (period) {
                if (period == selectedPeriod) return;
                setState(() => selectedPeriod = period);
                loadAnalysis();
              },
            ),
            Expanded(
              child: _AnalysisContent(
                isLoading: isLoading,
                errorMessage: errorMessage,
                analysis: analysis,
                onRefresh: loadAnalysis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisContent extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final MonthlyAnalysisData? analysis;
  final Future<void> Function() onRefresh;

  const _AnalysisContent({
    required this.isLoading,
    required this.errorMessage,
    required this.analysis,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(29, 30, 29, 116),
          children: [
            _EmptyStateCard(
              icon: Icons.error_outline_rounded,
              title: errorMessage!,
              subtitle:
                  'Pastikan tabel receipt_items tersedia dan user sudah login.',
            ),
          ],
        ),
      );
    }

    final data = analysis;
    if (data == null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(29, 30, 29, 116),
          children: const [
            _EmptyStateCard(
              icon: Icons.insights_rounded,
              title: 'Belum ada data analisis.',
              subtitle: 'Scan dan simpan struk dulu untuk melihat analisis.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(29, 22, 29, 116),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExpenseChartCard(data: data),
            const SizedBox(height: 24),
            _SmartInsightCard(data: data),
            const SizedBox(height: 26),
            _CategoryDistributionCard(categories: data.categories),
          ],
        ),
      ),
    );
  }
}

class _AnalysisHeader extends StatelessWidget {
  final VoidCallback onDownload;

  const _AnalysisHeader({
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(29, 20, 29, 17),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Analisis',
              style: TextStyle(
                color: Color(0xFF0B1220),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Tooltip(
            message: 'Unduh laporan PDF',
            child: InkWell(
              onTap: onDownload,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: Color(0xFF3525CD),
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF5FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF3525CD), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final ReportPeriod selectedPeriod;
  final ValueChanged<ReportPeriod> onChanged;

  const _PeriodTabs({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(29, 0, 29, 15),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            _PeriodTab(
              label: 'Mingguan',
              isSelected: selectedPeriod == ReportPeriod.weekly,
              onTap: () => onChanged(ReportPeriod.weekly),
            ),
            _PeriodTab(
              label: 'Bulanan',
              isSelected: selectedPeriod == ReportPeriod.monthly,
              onTap: () => onChanged(ReportPeriod.monthly),
            ),
            _PeriodTab(
              label: 'Tahunan',
              isSelected: selectedPeriod == ReportPeriod.yearly,
              onTap: () => onChanged(ReportPeriod.yearly),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF3525CD)
                  : const Color(0xFF667085),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseChartCard extends StatelessWidget {
  final MonthlyAnalysisData data;

  const _ExpenseChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 244,
      padding: const EdgeInsets.fromLTRB(21, 20, 20, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Pengeluaran (${data.monthName})',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _TrendBadge(percent: data.trendPercent),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _formatCurrency(data.totalExpense),
            style: const TextStyle(
              color: Color(0xFF0B1220),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _MiniChart(
            weeklyTotals: data.weeklyTotals,
            chartLabels: data.chartLabels,
            selectedIndex: data.topWeekIndex,
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double percent;

  const _TrendBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final isUp = percent >= 0;
    final color = isUp ? const Color(0xFFEF4444) : const Color(0xFF16A34A);
    final bgColor = isUp ? const Color(0xFFFFEEF0) : const Color(0xFFE7FBEF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${percent.abs().round()}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<double> weeklyTotals;
  final List<String> chartLabels;
  final int selectedIndex;

  const _MiniChart({
    required this.weeklyTotals,
    required this.chartLabels,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = weeklyTotals.isEmpty
        ? 0
        : selectedIndex.clamp(0, weeklyTotals.length - 1) as int;
    final selectedAmount = weeklyTotals.isEmpty ? 0.0 : weeklyTotals[safeIndex];

    return SizedBox(
      height: 56,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${chartLabels.isEmpty ? '-' : chartLabels[safeIndex]} • ${_formatCompactCurrency(selectedAmount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: List.generate(chartLabels.length, (index) {
                return _ChartWeek(
                  label: chartLabels[index],
                  isSelected: selectedIndex == index,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartWeek extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _ChartWeek({
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF667085),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SmartInsightCard extends StatelessWidget {
  final MonthlyAnalysisData data;

  const _SmartInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final topCategory = data.topCategory;
    final selectedLabel = data.chartLabels.isEmpty
        ? 'periode ini'
        : data.chartLabels[data.topWeekIndex];
    final insightText = topCategory == null
        ? 'Belum ada kategori item struk yang bisa dianalisis pada ${data.monthName.toLowerCase()}.'
        : 'Pengeluaran untuk ${topCategory.label} menjadi yang terbesar pada $selectedLabel. Kategori ini mendominasi ${(topCategory.percent * 100).round()}% dari total belanja ${data.monthName.toLowerCase()}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 17, 18, 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCFE0FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF3525CD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insight Analisis Cerdas',
                  style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  insightText,
                  style: const TextStyle(
                    color: Color(0xFF24324B),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDistributionCard extends StatelessWidget {
  final List<CategoryAnalysisItem> categories;

  const _CategoryDistributionCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFFF97316),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Distribusi Kategori',
                  style: TextStyle(
                    color: Color(0xFF0B1220),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.pie_chart_rounded, color: Color(0xFF98A2B3), size: 20),
            ],
          ),
          const SizedBox(height: 18),
          if (categories.isEmpty)
            const Text(
              'Belum ada item berkategori untuk periode ini.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...categories.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == categories.length - 1 ? 0 : 15,
                ),
                child: _DistributionRow(
                  label: item.label,
                  amount: _formatCurrency(item.amount),
                  percent: item.percent.clamp(0, 1),
                  color: colors[index % colors.length],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3525CD), size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0B1220),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
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

String _formatCompactCurrency(num value) {
  if (value >= 1000000) {
    final compact = (value / 1000000).toStringAsFixed(
      value % 1000000 == 0 ? 0 : 1,
    );
    return 'Rp ${compact}M';
  }

  if (value >= 1000) {
    final compact = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
    return 'Rp ${compact}K';
  }

  return _formatCurrency(value);
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final String amount;
  final double percent;
  final Color color;

  const _DistributionRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0B1220),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF0B1220),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 5,
            backgroundColor: const Color(0xFFE4E7EC),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
