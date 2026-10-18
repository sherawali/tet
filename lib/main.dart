import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'design_system/app_theme.dart';
import 'services/language_service.dart';
import 'services/exam_service.dart';
import 'services/premium_service.dart';
import 'screens/splash_sync_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop FFI initialization if running on Windows desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize saved language preference
  await LanguageService.instance.init();

  // Initialize selected exam (UTET vs CTET)
  await ExamService.instance.init();

  // Initialize In-App Purchases (IAP) & Premium Pass
  await PremiumService.instance.init();

  runApp(const TetApp());
}

class TetApp extends StatelessWidget {
  const TetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'TET Mock Master — UTET & CTET',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const SplashSyncScreen(),
        );
      },
    );
  }
}
