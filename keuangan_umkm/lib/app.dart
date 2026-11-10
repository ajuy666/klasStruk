import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_navigation_screen.dart';

/// DATABASE (Supabase Auth): memilih layar awal berdasarkan sesi pengguna.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartStok Pancanitis',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3525CD),
          primary: const Color(0xFF3525CD),
          secondary: const Color(0xFF006C49),
          surface: const Color(0xFFF7F9FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F9FB),
          foregroundColor: Color(0xFF191C1E),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFC7C4D8)),
          ),
        ),
      ),
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginScreen()
          : const MainNavigationScreen(),
    );
  }
}
