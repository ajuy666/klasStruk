import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/notification_service.dart';

/// DATABASE (Supabase): menginisialisasi koneksi backend aplikasi.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zhofqyriclaaxvvdjwix.supabase.co',
    anonKey: 'sb_publishable_0iUBJHFGCRQzNXnkbs2p1g_czEJVxVC',
  );

  await NotificationService.initialize();

  runApp(const MyApp());
}
