import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DATABASE (Supabase): membaca dan memperbarui profil serta profil usaha.
class ProfileService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// DATABASE (Supabase): membaca profiles dan business_profiles pengguna aktif.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('id, full_name, phone, profile_image, created_at, updated_at')
        .eq('id', user.id)
        .maybeSingle();

    final businessProfile = await supabase
        .from('business_profiles')
        .select(
          'id, user_id, business_name, owner_name, business_type, address, created_at, updated_at',
        )
        .eq('user_id', user.id)
        .maybeSingle();

    String? profileImageUrl = profile?['profile_image'];

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      profileImageUrl =
          '$profileImageUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    }

    return {
      'profile': {...?profile, 'profile_image': profileImageUrl},
      'business_profile': businessProfile,
    };
  }

  /// DATABASE (Supabase Storage + tabel profiles): mengunggah foto profil.
  Future<String> uploadProfileImage(XFile file) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final originalName = file.name.isNotEmpty ? file.name : file.path;
    final fileExt = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '${user.id}_profile.$fileExt';
    final filePath = 'profiles/$fileName';
    final bytes = await file.readAsBytes();

    await supabase.storage
        .from('profile-images')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = supabase.storage
        .from('profile-images')
        .getPublicUrl(filePath);

    await supabase
        .from('profiles')
        .update({
          'profile_image': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);

    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// DATABASE (Supabase): memperbarui data profiles dan business_profiles.
  Future<void> updateBasicProfile({
    required String fullName,
    required String businessName,
    String? phone,
    String? businessType,
    String? address,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    await supabase
        .from('profiles')
        .update({
          'full_name': fullName,
          'phone': phone,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);

    await supabase
        .from('business_profiles')
        .update({
          'business_name': businessName,
          'owner_name': fullName,
          'business_type': businessType,
          'address': address,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id);
  }
}
