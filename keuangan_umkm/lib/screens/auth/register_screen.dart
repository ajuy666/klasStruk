import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../main/main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// DATABASE (Supabase Auth): state layar untuk pendaftaran dan profil awal.
class _RegisterScreenState extends State<RegisterScreen> {
  final fullNameController = TextEditingController();
  final businessNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final verificationCodeController = TextEditingController();

  final authService = AuthService();

  bool isLoading = false;
  bool isWaitingForVerification = false;
  int resendCountdown = 0;
  Timer? resendTimer;

  @override
  void dispose() {
    resendTimer?.cancel();
    fullNameController.dispose();
    businessNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    verificationCodeController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFFBFCFE),
      prefixIcon: Icon(icon),
      prefixIconColor: const Color(0xFF94A3B8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
    );
  }

  void showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void startResendCountdown() {
    resendTimer?.cancel();
    setState(() {
      resendCountdown = 30;
    });

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (resendCountdown <= 1) {
        timer.cancel();
        setState(() {
          resendCountdown = 0;
        });
        return;
      }

      setState(() {
        resendCountdown--;
      });
    });
  }

  /// DATABASE (Supabase Auth): mengirim ulang OTP verifikasi.
  Future<void> handleResendVerification() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      showMessage('Format email tidak valid.', backgroundColor: Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await authService.resendSignupVerification(email: email);

      if (!mounted) return;

      showMessage(
        'Email verifikasi dikirim ulang. Cek inbox atau spam.',
        backgroundColor: Colors.green,
      );
      startResendCountdown();
    } on AuthException catch (e) {
      String message = 'Gagal mengirim ulang email verifikasi.';
      final lowerMessage = e.message.toLowerCase();

      if (lowerMessage.contains('rate limit') ||
          lowerMessage.contains('over_email_send_rate_limit')) {
        message = 'Terlalu sering meminta email. Coba lagi sekitar 1 menit.';
      }

      showMessage(message, backgroundColor: Colors.red);
    } catch (e) {
      showMessage(
        'Gagal mengirim ulang email verifikasi: $e',
        backgroundColor: Colors.red,
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  /// DATABASE (Supabase Auth): memverifikasi OTP dan menyimpan profil awal.
  Future<void> handleVerifyCode() async {
    final email = emailController.text.trim();
    final code = verificationCodeController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final fullName = fullNameController.text.trim();
    final businessName = businessNameController.text.trim();

    if (code.length != 8) {
      showMessage(
        'Masukkan kode 8 angka dari email.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await authService.verifySignupOtp(
        email: email,
        token: code,
      );
      final user = response.user;

      if (user == null) {
        throw Exception('Kode berhasil dicek, tapi user tidak ditemukan.');
      }

      await authService.insertUserProfile(
        userId: user.id,
        fullName: fullName,
        businessName: businessName,
      );

      if (!mounted) return;

      showMessage('Email berhasil diverifikasi.', backgroundColor: Colors.green);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(),
        ),
      );
    } on AuthException catch (e) {
      String message = 'Kode verifikasi salah atau sudah kedaluwarsa.';
      final lowerMessage = e.message.toLowerCase();

      if (lowerMessage.contains('expired')) {
        message = 'Kode sudah kedaluwarsa. Kirim ulang kode verifikasi.';
      }

      showMessage(message, backgroundColor: Colors.red);
    } catch (e) {
      showMessage(
        'Gagal verifikasi kode: $e',
        backgroundColor: Colors.red,
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  /// DATABASE (Supabase Auth): mendaftarkan akun dan menyiapkan profil awal.
  Future<void> handleRegister() async {
    final fullName = fullNameController.text.trim();
    final businessName = businessNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (fullName.isEmpty ||
        businessName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showMessage('Semua field wajib diisi.', backgroundColor: Colors.red);
      return;
    }

    if (!email.contains('@')) {
      showMessage('Format email tidak valid.', backgroundColor: Colors.red);
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Kata sandi minimal 6 karakter.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final authResponse = await authService.registerUser(
        email: email,
        password: password,
        fullName: fullName,
        businessName: businessName,
      );

      final user = authResponse.user;

      if (user == null) {
        throw Exception('User tidak berhasil dibuat.');
      }

      if (!mounted) return;

      if (authResponse.session == null) {
        setState(() {
          isWaitingForVerification = true;
          isLoading = false;
        });
        startResendCountdown();
        showMessage(
          'Registrasi berhasil. Cek email untuk verifikasi akun.',
          backgroundColor: Colors.green,
        );
        return;
      }

      await authService.insertUserProfile(
        userId: user.id,
        fullName: fullName,
        businessName: businessName,
      );

      if (!mounted) return;

      showMessage('Registrasi berhasil.', backgroundColor: Colors.green);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigationScreen(),
        ),
      );
    } on AuthException catch (e) {
      String message = 'Registrasi gagal. Silakan coba lagi.';
      final lowerMessage = e.message.toLowerCase();

      if (lowerMessage.contains('rate limit') ||
          lowerMessage.contains('email rate limit') ||
          lowerMessage.contains('over_email_send_rate_limit')) {
        message =
            'Terlalu banyak permintaan email verifikasi. Tunggu beberapa menit, lalu coba kirim ulang OTP.';
      } else if (lowerMessage.contains('user already registered') ||
          lowerMessage.contains('already registered') ||
          lowerMessage.contains('already exists')) {
        setState(() {
          isWaitingForVerification = true;
          isLoading = false;
        });
        startResendCountdown();
        showMessage(
          'Email sudah terdaftar. Masukkan OTP yang sudah dikirim, atau kirim ulang setelah timer selesai.',
          backgroundColor: Colors.orange,
        );
        return;
      } else if (lowerMessage.contains('password')) {
        message = 'Kata sandi tidak memenuhi syarat.';
      } else if (lowerMessage.contains('sending confirmation email') ||
          lowerMessage.contains('unexpected_failure')) {
        message =
            'Gagal mengirim email OTP. Periksa konfigurasi SMTP di Supabase.';
      } else {
        message = 'Registrasi gagal: ${e.message}';
      }

      showMessage(message, backgroundColor: Colors.red);
    } on PostgrestException catch (e) {
      showMessage(
        'Akun dibuat, tapi profil gagal disimpan: ${e.message}',
        backgroundColor: Colors.red,
      );
    } catch (e) {
      showMessage(
        'Terjadi kesalahan saat registrasi: $e',
        backgroundColor: Colors.red,
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const SizedBox(height: 72),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF5FF),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF2563EB),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Buat Akun',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Daftarkan usaha Anda untuk mulai mengelola\nstruk',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 34),
                  TextField(
                    controller: fullNameController,
                    decoration: inputDecoration(
                      hint: 'Nama Lengkap',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: businessNameController,
                    decoration: inputDecoration(
                      hint: 'Nama Usaha (Toko/UMKM)',
                      icon: Icons.storefront_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: inputDecoration(
                      hint: 'Email',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: inputDecoration(
                      hint: 'Password',
                      icon: Icons.lock_rounded,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: isLoading || isWaitingForVerification
                          ? null
                          : handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shadowColor: const Color(
                          0xFF2563EB,
                        ).withValues(alpha: 0.35),
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : isWaitingForVerification
                          ? const Text(
                              'Menunggu Verifikasi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : const Text(
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  if (isWaitingForVerification) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Kode verifikasi sudah dikirim ke email. Cek inbox atau spam, lalu masukkan kode 8 angka di bawah ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: verificationCodeController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      decoration: inputDecoration(
                        hint: 'Kode 8 angka',
                        icon: Icons.pin_rounded,
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : handleVerifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Verifikasi Kode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            isLoading || resendCountdown > 0
                            ? null
                            : handleResendVerification,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          resendCountdown > 0
                              ? 'Kirim ulang email dalam $resendCountdown detik'
                              : 'Kirim Ulang Email Verifikasi',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Flexible(
                        child: Text(
                          'Sudah punya akun? ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Masuk di sini',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
