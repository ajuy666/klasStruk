import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/expense_limit_service.dart';
import '../../services/profile_service.dart';
import '../../services/transaction_service.dart';
import '../analysis/analysis_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int refreshToken;

  const DashboardScreen({super.key, this.refreshToken = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// DATABASE (Supabase): state layar yang memuat profil dan ringkasan transaksi.
class _DashboardScreenState extends State<DashboardScreen> {
  final profileService = ProfileService();
  final transactionService = TransactionService();
  final expenseLimitService = ExpenseLimitService();

  String businessName = 'Usaha Saya';
  String ownerName = 'Pengguna';
  String? profileImageUrl;

  bool isLoadingProfile = true;
  bool isLoadingTransactions = true;

  double totalExpense = 0;
  double? monthOverMonthTrend;
  int monthlyTransactionCount = 0;
  String topSourceName = '-';
  int topSourceCount = 0;
  List<Map<String, dynamic>> latestTransactions = [];
  List<CategoryAnalysisItem> categoryAnalysis = [];

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        isLoadingProfile = true;
        isLoadingTransactions = true;
      });
      loadAllData();
    }
  }

  /// DATABASE (Supabase): memuat seluruh data ringkasan dashboard.
  Future<void> loadAllData() async {
    await Future.wait([loadProfile(), loadDashboardTransactions()]);
  }

  /// DATABASE (Supabase): memuat profil melalui ProfileService.
  Future<void> loadProfile() async {
    try {
      final data = await profileService.getCurrentUserProfile();

      if (data == null) {
        setState(() => isLoadingProfile = false);
        return;
      }

      final profile = data['profile'] as Map<String, dynamic>?;
      final businessProfile = data['business_profile'] as Map<String, dynamic>?;

      setState(() {
        ownerName = profile?['full_name'] ?? 'Pengguna';
        businessName = businessProfile?['business_name'] ?? 'Usaha Saya';
        profileImageUrl = profile?['profile_image']?.toString();
        isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('LOAD DASHBOARD PROFILE ERROR: $e');
      setState(() => isLoadingProfile = false);
    }
  }

  /// DATABASE (Supabase): memuat ringkasan dan analisis transaksi.
  Future<void> loadDashboardTransactions() async {
    try {
      final total = await transactionService.getCurrentMonthExpenseTotal();
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await expenseLimitService.notifyIfNeeded(
          userId: user.id,
          currentExpense: total,
        );
      }
      final count = await transactionService.getCurrentMonthTransactionCount();
      final topSource = await transactionService
          .getTopTransactionSourceThisMonth();
      final latest = await transactionService.getLatestTransactions(limit: 3);
      MonthlyAnalysisData? analysis;

      try {
        analysis = await transactionService.getCurrentMonthAnalysis();
      } catch (e) {
        debugPrint('LOAD DASHBOARD CATEGORY ANALYSIS ERROR: $e');
      }

      setState(() {
        totalExpense = total;
        monthOverMonthTrend = analysis?.trendPercent;
        monthlyTransactionCount = count;
        topSourceName = topSource?['name']?.toString() ?? '-';
        topSourceCount = topSource?['count'] is int
            ? topSource!['count'] as int
            : int.tryParse(topSource?['count']?.toString() ?? '') ?? 0;
        latestTransactions = latest;
        categoryAnalysis = analysis?.categories ?? [];
        isLoadingTransactions = false;
      });
    } catch (e) {
      debugPrint('LOAD DASHBOARD TRANSACTIONS ERROR: $e');
      setState(() => isLoadingTransactions = false);
    }
  }

  String formatCurrency(num value) {
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
    if (date == null || date.isEmpty) return 'Hari ini';

    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      if (parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day) {
        return 'Hari ini';
      }

      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$day/$month/${parsed.year}';
    } catch (_) {
      return date;
    }
  }

  double _amountFrom(Map<String, dynamic> trx) {
    final amount = trx['amount'];
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount.toString()) ?? 0;
  }

  List<_CategorySummary> get categorySummaries {
    if (isLoadingTransactions) {
      return const [
        _CategorySummary(
          title: 'Memuat Data',
          percent: 0.65,
          color: Color(0xFF3B82F6),
          icon: Icons.inventory_2_rounded,
        ),
      ];
    }

    if (categoryAnalysis.isEmpty) {
      return const [
        _CategorySummary(
          title: 'Belum Ada Kategori',
          percent: 0,
          color: Color(0xFF3B82F6),
          icon: Icons.inventory_2_rounded,
        ),
      ];
    }

    return categoryAnalysis.take(3).map((item) {
      final color = _categoryColor(item.label);
      return _CategorySummary(
        title: item.label,
        percent: item.percent.clamp(0, 1),
        color: color,
        icon: _categoryIcon(item.label),
      );
    }).toList();
  }

  Color _categoryColor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('mandi') || normalized.contains('cuci')) {
      return const Color(0xFF22C55E);
    }
    if (normalized.contains('makanan')) return const Color(0xFFF97316);
    return const Color(0xFF3B82F6);
  }

  IconData _categoryIcon(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('mandi') || normalized.contains('cuci')) {
      return Icons.shopping_bag_rounded;
    }
    if (normalized.contains('makanan')) return Icons.fastfood_rounded;
    return Icons.business_center_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 24.0 : 34.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: RefreshIndicator(
        onRefresh: loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 128),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderSection(
                ownerName: isLoadingProfile ? 'Memuat...' : ownerName,
                businessName: isLoadingProfile ? 'Memuat usaha' : businessName,
                profileImageUrl: profileImageUrl,
                onProfileTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                  await loadProfile();
                },
                totalExpense: isLoadingTransactions
                    ? 'Memuat...'
                    : formatCurrency(totalExpense),
                receiptCount: monthlyTransactionCount,
                itemCount: monthlyTransactionCount,
                isLoading: isLoadingTransactions,
                monthOverMonthTrend: monthOverMonthTrend,
                onMonthlyTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                  );
                },
              ),
              // Ruang ini mengikuti kartu yang sengaja dibuat lebih rendah
              // agar tidak menutupi sapaan pada layar Android yang pendek.
              const SizedBox(height: 112),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      title: 'Ringkasan Kategori',
                      action: 'Lihat Detail',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AnalysisScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _CategoryCard(items: categorySummaries),
                    const SizedBox(height: 25),
                    const _SectionTitle(title: 'Struk Terakhir'),
                    const SizedBox(height: 14),
                    if (isLoadingTransactions)
                      const _LoadingCard()
                    else if (latestTransactions.isEmpty)
                      const _EmptyReceiptCard()
                    else
                      Column(
                        children: latestTransactions.map((trx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReceiptCard(
                              title: trx['title']?.toString() ?? '-',
                              subtitle:
                                  '${formatDate(trx['transaction_date']?.toString())} WIB',
                              amount: formatCurrency(_amountFrom(trx)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//class dan data base
class _HeaderSection extends StatelessWidget {
  final String ownerName;
  final String businessName;
  final String? profileImageUrl;
  final VoidCallback onProfileTap;
  final String totalExpense;
  final int receiptCount;
  final int itemCount;
  final bool isLoading;
  final double? monthOverMonthTrend;
  final VoidCallback onMonthlyTap;

  const _HeaderSection({
    required this.ownerName,
    required this.businessName,
    required this.profileImageUrl,
    required this.onProfileTap,
    required this.totalExpense,
    required this.receiptCount,
    required this.itemCount,
    required this.isLoading,
    required this.monthOverMonthTrend,
    required this.onMonthlyTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 380 ? 24.0 : 34.0;
    // Kartu ringkasan tidak boleh menimpa nama pengguna maupun tombol profil.
    // Layar Android yang sempit memerlukan header sedikit lebih tinggi.
    final headerHeight = screenWidth < 380 ? 324.0 : 304.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: headerHeight,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 16, 28, 0),
          decoration: const BoxDecoration(
            color: Color(0xFF3525CD),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selamat Datang,',
                        style: TextStyle(
                          color: Color(0xFFE5EDFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 178),
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      image:
                          profileImageUrl != null && profileImageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profileImageUrl == null || profileImageUrl!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: horizontalPadding,
          right: horizontalPadding,
          // Kartu dimulai setelah seluruh area sambutan dan profil.
          bottom: -96,
          child: _MonthlyCard(
            totalExpense: totalExpense,
            receiptCount: receiptCount,
            itemCount: itemCount,
            isLoading: isLoading,
            monthOverMonthTrend: monthOverMonthTrend,
            onTap: onMonthlyTap,
          ),
        ),
      ],
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  final String totalExpense;
  final int receiptCount;
  final int itemCount;
  final bool isLoading;
  final double? monthOverMonthTrend;
  final VoidCallback onTap;

  const _MonthlyCard({
    required this.totalExpense,
    required this.receiptCount,
    required this.itemCount,
    required this.isLoading,
    required this.monthOverMonthTrend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trend = monthOverMonthTrend;
    final isIncrease = (trend ?? 0) > 0;
    final trendLabel = trend == null
        ? '-'
        : '${isIncrease ? '+' : ''}${trend.toStringAsFixed(0)}%';
    final trendColor = isIncrease
        ? const Color(0xFFEF4444)
        : const Color(0xFF16A34A);
    final trendBackground = isIncrease
        ? const Color(0xFFFFEEF0)
        : const Color(0xFFE7FBEF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Pengeluaran Bulan Ini',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: trendBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  trendLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            totalExpense,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  title: 'Struk Diproses',
                  value: isLoading ? '...' : '$receiptCount',
                  suffix: 'struk',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  title: 'Item Diklasifikasi',
                  value: isLoading ? '...' : '$itemCount',
                  suffix: 'item',
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;

  const _StatBox({
    required this.title,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11.5,
              height: 1.12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontSize: 11,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;

  const _SectionTitle({required this.title, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action!,
              style: const TextStyle(
                color: Color(0xFF3525CD),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final List<_CategorySummary> items;

  const _CategoryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _CategoryRow(item: item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _CategorySummary item;

  const _CategoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(item.percent * 100).round()}%';

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, color: item.color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    percentLabel,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: item.percent,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE4E7EC),
                  valueColor: AlwaysStoppedAnimation<Color>(item.color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final VoidCallback onTap;

  const _ReceiptCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 75),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xFF667085)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amount,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7FBEF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyReceiptCard extends StatelessWidget {
  const _EmptyReceiptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Belum ada struk tersimpan.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF667085),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CategorySummary {
  final String title;
  final double percent;
  final Color color;
  final IconData icon;

  const _CategorySummary({
    required this.title,
    required this.percent,
    required this.color,
    required this.icon,
  });
}
