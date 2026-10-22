import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/db_helper.dart';
import 'design_system/app_theme.dart';
import 'services/github_report_service.dart';
import 'services/language_service.dart';
import 'services/exam_service.dart';
import 'services/premium_service.dart';
import 'screens/splash_sync_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The typography is bundled with the app, so fonts are never downloaded at
  // runtime.  This keeps the exam screen stable (and instantly rendered) on a
  // slow or missing connection.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Desktop FFI initialization if running on Windows desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize saved language preference
  await LanguageService.instance.init();

  // Initialize selected exam (UTET vs CTET)
  await ExamService.instance.init();

  // The premium state is restored from the local database first and the Play
  // Store is only contacted afterwards.  The app must start instantly even
  // with no connection, so the store call is never awaited here.
  unawaited(PremiumService.instance.init());

  runApp(const TetApp());

  // Error reports that were collected while the device was offline are sent
  // in the background.  This is best effort and never blocks the app.
  unawaited(_flushPendingReports());
}

/// Sends locally stored question reports to the tracker once a connection is
/// available.  Everything is stored in SQLite first, so nothing is lost when
/// the device is offline.
Future<void> _flushPendingReports() async {
  try {
    await DbHelper.instance.ensureBundledAssetLoaded();
    await GitHubReportService.instance.syncPendingReports();
  } catch (_) {
    // Offline - the reports stay in the local database.
  }
}

class TetApp extends StatelessWidget {
  const TetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: LanguageService.instance.currentLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'TET Rank — UTET & CTET',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          // A phone whose system font size is set larger must not tear the
          // layout apart: the reading sizes stay under the tester's control,
          // the chrome scales only a little.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final rawScale = media.textScaler.scale(1.0);
            final clampedScale = rawScale.clamp(1.0, 1.25).toDouble();
            final scaler = clampedScale == rawScale
                ? media.textScaler
                : TextScaler.linear(clampedScale);
            return MediaQuery(
              data: media.copyWith(textScaler: scaler),
              child: child!,
            );
          },
          home: const SplashSyncScreen(),
        );
      },
    );
  }
}
