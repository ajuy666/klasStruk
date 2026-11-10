import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../inventory/inventory_screen.dart';
import '../profile/profile_screen.dart';
import '../scan/scan_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

/// DATABASE (Supabase Auth): state navigasi yang membaca ID pengguna aktif.
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;
  int dashboardRefreshToken = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialIfNeeded();
    });
  }

  /// DATABASE (Supabase Auth): memakai ID sesi pengguna untuk status tutorial lokal.
  Future<void> _showTutorialIfNeeded() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    final preferenceKey = 'main_menu_tutorial_completed_$userId';
    final tutorialCompleted = preferences.getBool(preferenceKey) ?? false;

    if (tutorialCompleted || !mounted) return;

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _MainMenuTutorialDialog(),
    );

    if (completed == true) {
      await preferences.setBool(preferenceKey, true);
    }
  }

  void onTabTapped(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  Future<void> openScanScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );

    if (!mounted) return;

    setState(() {
      currentIndex = 0;
      dashboardRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          DashboardScreen(refreshToken: dashboardRefreshToken),
          const InventoryScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFC7C4D8))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.home_outlined, label: 'Home', isActive: currentIndex == 0, onTap: () => onTabTapped(0)),
                  _NavItem(icon: Icons.inventory_2_outlined, label: 'Inventori', isActive: currentIndex == 1, onTap: () => onTabTapped(1)),
                  _ScanNavButton(onTap: openScanScreen),
                  _NavItem(icon: Icons.history_outlined, label: 'Riwayat', isActive: currentIndex == 2, onTap: () => onTabTapped(2)),
                  _NavItem(icon: Icons.person_outline_rounded, label: 'Profil', isActive: currentIndex == 3, onTap: () => onTabTapped(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainMenuTutorialDialog extends StatelessWidget {
  const _MainMenuTutorialDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Selamat Datang!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Yuk, kenali menu utama agar pencatatan keuangan jadi lebih mudah.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 21),
              const _TutorialMenuItem(
                icon: Icons.camera_alt_rounded,
                title: 'Scan Struk',
                description:
                    'Tekan tombol Scan untuk memotret struk dan mencatat pengeluaran otomatis.',
                color: Color(0xFF2563EB),
              ),
              const _TutorialMenuItem(
                icon: Icons.pie_chart_rounded,
                title: 'Analisis',
                description:
                    'Lihat ringkasan dan pembagian pengeluaran usaha berdasarkan kategori.',
                color: Color(0xFF8B5CF6),
              ),
              const _TutorialMenuItem(
                icon: Icons.history_rounded,
                title: 'Riwayat',
                description:
                    'Periksa kembali semua struk dan transaksi yang pernah disimpan.',
                color: Color(0xFFF59E0B),
              ),
              const _TutorialMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Profil',
                description:
                    'Kelola data pemilik, informasi usaha, dan pengaturan akun.',
                color: Color(0xFF10B981),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'Oke, Saya Mengerti',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Panduan ini hanya tampil sekali.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TutorialMenuItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    height: 1.35,
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

class _ScanNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6BEF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2F6BEF).withValues(alpha: 0.34),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 8,
              child: Text(
                'Scan',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF005236) : const Color(0xFF464555);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6CF8BB) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
