import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/expense_limit_service.dart';
import '../../services/profile_service.dart';
import '../../services/transaction_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// DATABASE (Supabase): state layar yang membaca dan memperbarui profil pengguna.
class _ProfileScreenState extends State<ProfileScreen> {
  final profileService = ProfileService();
  final transactionService = TransactionService();
  final expenseLimitService = ExpenseLimitService();
  final imagePicker = ImagePicker();

  String ownerName = 'Pengguna';
  String businessName = 'Usaha Saya';
  String role = 'Pemilik UMKM';
  String address = '-';
  String email = '-';
  String phone = '-';
  String? profileImageUrl;
  double monthlyLimit = 0;
  double currentExpense = 0;

  bool isLoading = true;
  bool isUploading = false;
  bool isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  /// DATABASE (Supabase): memuat profil pengguna melalui ProfileService.
  Future<void> loadProfile() async {
    try {
      final data = await profileService.getCurrentUserProfile();
      final user = Supabase.instance.client.auth.currentUser;
      final limit = user == null
          ? 0.0
          : await expenseLimitService.getMonthlyLimit(user.id);
      final total = user == null
          ? 0.0
          : await transactionService.getCurrentMonthExpenseTotal();

      if (data == null) {
        setState(() {
          email = user?.email ?? '-';
          monthlyLimit = limit;
          currentExpense = total;
          isLoading = false;
        });
        return;
      }

      final profile = data['profile'] as Map<String, dynamic>?;
      final businessProfile = data['business_profile'] as Map<String, dynamic>?;

      setState(() {
        ownerName = profile?['full_name']?.toString() ?? 'Pengguna';
        businessName =
            businessProfile?['business_name']?.toString() ?? 'Usaha Saya';
        role =
            businessProfile?['business_type']?.toString().trim().isNotEmpty ==
                true
            ? businessProfile!['business_type'].toString()
            : 'Pemilik UMKM';
        address =
            businessProfile?['address']?.toString().trim().isNotEmpty == true
            ? businessProfile!['address'].toString()
            : '-';
        email = user?.email ?? '-';
        phone = profile?['phone']?.toString().trim().isNotEmpty == true
            ? profile!['phone'].toString()
            : '-';
        profileImageUrl = profile?['profile_image']?.toString();
        monthlyLimit = limit;
        currentExpense = total;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatCurrency(double amount) {
    final raw = amount.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  Future<void> openExpenseLimitDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    var selectedLimit = monthlyLimit.clamp(0, 100000000).toDouble();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Batas Pengeluaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatCurrency(selectedLimit),
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                selectedLimit == 0
                    ? 'Nonaktif — tidak ada notifikasi batas pengeluaran.'
                    : 'Notifikasi muncul saat pengeluaran mencapai 80%.',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Slider(
                value: selectedLimit,
                min: 0,
                max: 100000000,
                divisions: 100,
                label: formatCurrency(selectedLimit),
                onChanged: (value) => setDialogState(() => selectedLimit = value),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rp 0', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                  Text('Rp 100 jt', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedLimit),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    await expenseLimitService.saveMonthlyLimit(user.id, result);
    await expenseLimitService.notifyIfNeeded(
      userId: user.id,
      currentExpense: currentExpense,
    );
    await loadProfile();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result <= 0
              ? 'Batas pengeluaran dihapus.'
              : 'Batas pengeluaran berhasil disimpan.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  String emptyIfDash(String value) {
    return value == '-' ? '' : value;
  }

  /// DATABASE (Supabase): menyimpan perubahan profil melalui ProfileService.
  Future<void> openEditProfileDialog() async {
    final fullNameController = TextEditingController(text: ownerName);
    final businessNameController = TextEditingController(text: businessName);
    final businessTypeController = TextEditingController(
      text: role == 'Pemilik UMKM' ? '' : role,
    );
    final addressController = TextEditingController(text: emptyIfDash(address));
    final phoneController = TextEditingController(text: emptyIfDash(phone));

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profil Usaha'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EditProfileField(
                  controller: fullNameController,
                  label: 'Nama Pemilik',
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 12),
                _EditProfileField(
                  controller: businessNameController,
                  label: 'Nama Usaha',
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(height: 12),
                _EditProfileField(
                  controller: businessTypeController,
                  label: 'Jenis Usaha',
                  icon: Icons.badge_rounded,
                ),
                const SizedBox(height: 12),
                _EditProfileField(
                  controller: addressController,
                  label: 'Alamat',
                  icon: Icons.location_on_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _EditProfileField(
                  controller: phoneController,
                  label: 'Nomor Telepon',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      fullNameController.dispose();
      businessNameController.dispose();
      businessTypeController.dispose();
      addressController.dispose();
      phoneController.dispose();
      return;
    }

    final fullName = fullNameController.text.trim();
    final updatedBusinessName = businessNameController.text.trim();
    final businessType = businessTypeController.text.trim();
    final updatedAddress = addressController.text.trim();
    final updatedPhone = phoneController.text.trim();

    fullNameController.dispose();
    businessNameController.dispose();
    businessTypeController.dispose();
    addressController.dispose();
    phoneController.dispose();

    if (fullName.isEmpty || updatedBusinessName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama pemilik dan nama usaha wajib diisi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSavingProfile = true;
    });

    try {
      await profileService.updateBasicProfile(
        fullName: fullName,
        businessName: updatedBusinessName,
        businessType: businessType.isEmpty ? null : businessType,
        address: updatedAddress.isEmpty ? null : updatedAddress,
        phone: updatedPhone.isEmpty ? null : updatedPhone,
      );

      await loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      isSavingProfile = false;
    });
  }

  /// DATABASE (Supabase Storage): mengunggah dan menyimpan foto profil.
  Future<void> pickAndUploadImage() async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() {
        isUploading = true;
      });

      final imageUrl = await profileService.uploadProfileImage(pickedFile);

      setState(() {
        profileImageUrl = imageUrl;
        isUploading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isUploading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload foto profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: RefreshIndicator(
        onRefresh: loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 118),
          child: Column(
            children: [
              _ProfileHeader(
                ownerName: isLoading ? 'Memuat...' : ownerName,
                role: isLoading ? 'Memuat data...' : role,
                profileImageUrl: profileImageUrl,
                isUploading: isUploading,
                onEditPhoto: pickAndUploadImage,
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _ProfileInfoCard(
                      title: 'INFORMASI USAHA',
                      actionLabel: isSavingProfile ? 'Menyimpan...' : 'Edit',
                      onActionTap: isSavingProfile ? null : openEditProfileDialog,
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.storefront_rounded,
                          label: 'Nama Usaha',
                          value: isLoading ? 'Memuat...' : businessName,
                        ),
                        const SizedBox(height: 18),
                        _ProfileInfoRow(
                          icon: Icons.location_on_rounded,
                          label: 'Alamat',
                          value: isLoading ? 'Memuat...' : address,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ProfileInfoCard(
                      title: 'INFORMASI KONTAK',
                      actionLabel: isSavingProfile ? 'Menyimpan...' : 'Edit',
                      onActionTap: isSavingProfile ? null : openEditProfileDialog,
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: isLoading ? 'Memuat...' : email,
                          showChevron: true,
                        ),
                        const Divider(height: 26, color: Color(0xFFEFF2F6)),
                        _ProfileInfoRow(
                          icon: Icons.phone_rounded,
                          label: 'Nomor Telepon',
                          value: isLoading ? 'Memuat...' : phone,
                          showChevron: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ExpenseLimitCard(
                      currentExpense: currentExpense,
                      monthlyLimit: monthlyLimit,
                      formatCurrency: formatCurrency,
                      onEdit: openExpenseLimitDialog,
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

class _ProfileHeader extends StatelessWidget {
  final String ownerName;
  final String role;
  final String? profileImageUrl;
  final bool isUploading;
  final VoidCallback onEditPhoto;

  const _ProfileHeader({
    required this.ownerName,
    required this.role,
    required this.profileImageUrl,
    required this.isUploading,
    required this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF2F6BEF),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 28),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: const Color(0xFFDBEAFE),
                    image:
                        profileImageUrl != null && profileImageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profileImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profileImageUrl == null || profileImageUrl!.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: Color(0xFF2563EB),
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: isUploading ? null : onEditPhoto,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE5EDFF),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final List<Widget> children;

  const _ProfileInfoCard({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onActionTap,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _EditProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
    );
  }
}

class _ExpenseLimitCard extends StatelessWidget {
  final double currentExpense;
  final double monthlyLimit;
  final String Function(double amount) formatCurrency;
  final VoidCallback onEdit;

  const _ExpenseLimitCard({
    required this.currentExpense,
    required this.monthlyLimit,
    required this.formatCurrency,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = monthlyLimit > 0;
    final progress = isEnabled
        ? (currentExpense / monthlyLimit).clamp(0.0, 1.0)
        : 0.0;
    final percent = isEnabled
        ? ((currentExpense / monthlyLimit) * 100).clamp(0, 999).round()
        : 0;
    final color = !isEnabled
        ? const Color(0xFF64748B)
        : currentExpense >= monthlyLimit
        ? const Color(0xFFEF4444)
        : percent >= 80
        ? const Color(0xFFF97316)
        : const Color(0xFF2563EB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              const Expanded(
                child: Text(
                  'BATAS PENGELUARAN',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isEnabled ? 'Ubah' : 'Atur',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnabled
                          ? '${formatCurrency(currentExpense)} / ${formatCurrency(monthlyLimit)}'
                          : 'Belum ada batas pengeluaran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isEnabled
                          ? '$percent% dari batas bulan ini'
                          : 'Atur nominal agar app bisa mengingatkan.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isEnabled ? color : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFEFF2F6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showChevron;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF5FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFCBD5E1),
            size: 24,
          ),
        ],
      ],
    );
  }
}
