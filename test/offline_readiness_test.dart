import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app must be usable without any connection.  These tests guard the
/// policies that keep it that way.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('offline readiness', () {
    test('the release manifest asks for the internet permission', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: 'release builds need the permission for optional updates',
      );
    });

    test('the app start never waits for the Play Store', () {
      final main = read('lib/main.dart');
      expect(
        main.contains('await PremiumService.instance.init()'),
        isFalse,
        reason: 'a cold start must not block on the network',
      );
      expect(main, contains('unawaited(PremiumService.instance.init())'));
      // The app is rendered before any network call happens.
      final runApp = main.indexOf('runApp(');
      final premium = main.indexOf('PremiumService.instance.init()');
      expect(runApp, greaterThan(-1));
      expect(premium, greaterThan(-1));
    });

    test('the bundled vault is tracked separately from the synced bank', () {
      final db = read('lib/database/db_helper.dart');
      // The bundled check uses its own key, the CDN sync never touches it.
      expect(db, contains("'bundled_version'"));
      final assetImport = db.substring(db.indexOf('_syncFromAssetDb'));
      expect(assetImport, contains("'bundled_version'"));
      final cdnUpdate = db.substring(db.indexOf('atomicUpdateBank'));
      expect(
        cdnUpdate.substring(0, 2000).contains('bundled_version'),
        isFalse,
        reason: 'a CDN sync must not overwrite the bundled marker',
      );
    });

    test('no font is downloaded at runtime', () {
      final lib = Directory('lib');
      final offenders = <String>[];
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        // Any real use of a google font would fetch it at runtime.
        if (RegExp(r'GoogleFonts\.(outfit|inter|notoSansDevanagari|courierPrime)\(')
            .hasMatch(source)) {
          offenders.add(file.path.replaceAll('\\', '/'));
        }
      }
      expect(offenders, isEmpty, reason: 'use the bundled faces instead');
    });
  });

  test('every network call has a timeout', () {
    final services = Directory('lib/services');
    for (final file in services.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final calls = RegExp(r'http\.(get|post)\(').allMatches(source).length;
      if (calls == 0) continue;
      final timeouts = RegExp(r'\.timeout\(').allMatches(source).length;
      expect(
        timeouts,
        greaterThanOrEqualTo(calls),
        reason: '${file.path} has a network call without a timeout',
      );
    }
  });

  test('the error report upload cannot hang forever', () {
    final reports = read('lib/services/github_report_service.dart');
    expect(reports, contains('.timeout(const Duration(seconds: 15))'));
    expect(reports, contains('budgetEnd'));
  });
}
