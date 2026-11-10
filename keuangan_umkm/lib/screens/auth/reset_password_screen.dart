import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _authService = AuthService();

  Timer? _timer;
  var _isOtpStep = false;
  var _isLoading = false;
  var _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  bool get _hasValidEmail {
    final email = _email.text.trim();
    return email.isNotEmpty && email.contains('@');
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    if (!_hasValidEmail) {
      _showMessage('Masukkan alamat email yang valid.', backgroundColor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.requestPasswordReset(email: _email.text.trim());
      if (!mounted) return;
      setState(() => _isOtpStep = true);
      _startResendCountdown();
      _showMessage(
        isResend
            ? 'OTP baru telah dikirim. Periksa email Anda.'
            : 'Jika email terdaftar, OTP reset password telah dikirim.',
        backgroundColor: Colors.green,
      );
    } on AuthException catch (e) {
      _showMessage('Gagal mengirim OTP: ${e.message}', backgroundColor: Colors.red);
    } catch (_) {
      _showMessage('OTP belum dapat dikirim. Coba lagi.', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewPassword() async {
    final otp = _otp.text.trim();
    final password = _password.text;
    final confirmation = _confirmPassword.text;

    if (otp.length != 8 || !RegExp(r'^\d{8}$').hasMatch(otp)) {
      _showMessage('Masukkan 8 digit OTP dari email.', backgroundColor: Colors.red);
      return;
    }
    if (password.length < 6) {
      _showMessage('Password baru minimal 6 karakter.', backgroundColor: Colors.red);
      return;
    }
    if (password != confirmation) {
      _showMessage('Konfirmasi password belum sama.', backgroundColor: Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyPasswordResetOtp(
        email: _email.text.trim(),
        token: otp,
      );
      await _authService.updatePassword(password: password);
      if (!mounted) return;
      _showMessage('Password berhasil diperbarui. Silakan masuk.', backgroundColor: Colors.green);
      Navigator.pop(context);
    } on AuthException catch (e) {
      _showMessage('OTP atau password tidak valid: ${e.message}', backgroundColor: Colors.red);
    } catch (_) {
      _showMessage('Gagal memperbarui password. Coba lagi.', backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isOtpStep ? 'Masukkan OTP dan password baru' : 'Lupa password?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpStep
                        ? 'Masukkan kode 8 digit yang dikirim ke ${_email.text.trim()}.'
                        : 'Masukkan email akun untuk menerima kode OTP reset password.',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    enabled: !_isOtpStep && !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Email akun', hint: 'nama@email.com'),
                  ),
                  if (_isOtpStep) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otp,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: _inputDecoration('Kode OTP', hint: '12345678'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      enabled: !_isLoading,
                      obscureText: true,
                      decoration: _inputDecoration('Password baru'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPassword,
                      enabled: !_isLoading,
                      obscureText: true,
                      onSubmitted: (_) => _saveNewPassword(),
                      decoration: _inputDecoration('Konfirmasi password baru'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : _isOtpStep
                        ? _saveNewPassword
                        : _sendOtp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isOtpStep ? 'Simpan password baru' : 'Kirim OTP'),
                  ),
                  if (_isOtpStep) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading || _secondsRemaining > 0
                          ? null
                          : () => _sendOtp(isResend: true),
                      child: Text(
                        _secondsRemaining > 0
                            ? 'Kirim ulang OTP dalam $_secondsRemaining detik'
                            : 'Kirim ulang OTP',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
