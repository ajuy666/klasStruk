import 'package:supabase_flutter/supabase_flutter.dart';

/// DATABASE (Supabase): mengelola autentikasi dan data profil pengguna.
class AuthService {
  final supabase = Supabase.instance.client;

  /// DATABASE (Supabase Auth): membuat akun pengguna baru.
  Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
  }) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'business_name': businessName},
    );
  }

  /// DATABASE (Supabase): membuat atau memperbarui profiles dan business_profiles.
  Future<void> insertUserProfile({
    required String userId,
    required String fullName,
    required String businessName,
  }) async {
    await supabase.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
    });

    final existingBusinessProfile = await supabase
        .from('business_profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    final businessProfileData = {
      'user_id': userId,
      'business_name': businessName,
      'owner_name': fullName,
    };

    if (existingBusinessProfile == null) {
      await supabase.from('business_profiles').insert(businessProfileData);
      return;
    }

    await supabase
        .from('business_profiles')
        .update(businessProfileData)
        .eq('id', existingBusinessProfile['id']);
  }

  /// DATABASE (Supabase): memastikan profil pengguna aktif tersimpan.
  Future<void> ensureCurrentUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? {};
    final fullName =
        metadata['full_name']?.toString().trim().isNotEmpty == true
        ? metadata['full_name'].toString().trim()
        : user.email ?? 'Pengguna';
    final businessName =
        metadata['business_name']?.toString().trim().isNotEmpty == true
        ? metadata['business_name'].toString().trim()
        : 'Usaha Saya';

    await insertUserProfile(
      userId: user.id,
      fullName: fullName,
      businessName: businessName,
    );
  }

  /// DATABASE (Supabase Auth): mengirim ulang verifikasi pendaftaran.
  Future<void> resendSignupVerification({required String email}) async {
    await supabase.auth.resend(type: OtpType.signup, email: email);
  }

  /// DATABASE (Supabase Auth): memverifikasi OTP akun.
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    return await supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  /// DATABASE (Supabase Auth): autentikasi pengguna.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// DATABASE (Supabase Auth): mengirim OTP pemulihan kata sandi ke email.
  Future<void> requestPasswordReset({required String email}) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  /// DATABASE (Supabase Auth): memverifikasi OTP pemulihan dan membuat sesi sementara.
  Future<AuthResponse> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    return await supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  /// DATABASE (Supabase Auth): menyimpan kata sandi baru setelah OTP valid.
  Future<void> updatePassword({required String password}) async {
    await supabase.auth.updateUser(UserAttributes(password: password));
  }

  /// DATABASE (Supabase Auth): mengakhiri sesi pengguna.
  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
