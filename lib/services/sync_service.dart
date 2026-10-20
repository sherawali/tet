import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';
import '../models/question.dart';
import '../models/passage.dart';
import 'premium_service.dart';
import 'github_report_service.dart';

typedef SyncProgressCallback = void Function(double progress, String status);

class SyncResult {
  final bool success;
  final bool isUpToDate;
  final int previousCount;
  final int newQuestionsAdded;
  final int totalCount;
  final String? message;

  const SyncResult({
    required this.success,
    this.isUpToDate = false,
    this.previousCount = 0,
    this.newQuestionsAdded = 0,
    this.totalCount = 0,
    this.message,
  });
}

class SyncService {
  /// Broadcast notifier so UI (HomeScreen etc.) can instantly reload when background/foreground sync completes
  static final ValueNotifier<DateTime?> onDatabaseUpdated = ValueNotifier(null);

  /// Master switch: Remote sync enabled for GitHub CDN updates
  static const bool enableRemoteSync = true;

  /// Priority candidate URLs for CDN / GitHub sync
  /// 1. Raw GitHub main branch (Real-time updates without CDN cache delay)
  /// 2. Main branch on jsDelivr
  static const List<String> candidateUrls = [
    'https://raw.githubusercontent.com/sherawali/tet/main/cdn',
    'https://cdn.jsdelivr.net/gh/sherawali/tet@main/cdn',
  ];

  static const List<String> rawGitHubUrls = [
    'https://raw.githubusercontent.com/sherawali/tet/main/cdn',
    'https://cdn.jsdelivr.net/gh/sherawali/tet@main/cdn',
  ];

  final DbHelper db = DbHelper.instance;

  /// Resolves the best available working baseUrl and manifest
  /// If forceBypassCache is true, prioritizes direct raw GitHub to bypass CDN 24h caching
  Future<Map<String, dynamic>?> _resolveManifest({bool forceBypassCache = false}) async {
    final urlsToTry = forceBypassCache ? rawGitHubUrls : candidateUrls;
    for (final url in urlsToTry) {
      try {
        final cacheBuster = forceBypassCache ? '?_ts=${DateTime.now().millisecondsSinceEpoch}' : '';
        final res = await http.get(
          Uri.parse('$url/manifest.json$cacheBuster'),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final manifest = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          // Update remote free/paid mock configuration immediately
          if (manifest.containsKey('remote_config') && manifest['remote_config'] is Map) {
            PremiumService.instance.updateRemoteConfig(Map<String, dynamic>.from(manifest['remote_config']));
          }
          return {
            'baseUrl': url,
            'manifest': manifest,
          };
        }
      } catch (_) {}
    }
    return null;
  }

  static String _computePacksSignature(List<dynamic> packs) {
    return packs.map((p) => '${p['file'] ?? ''}_${p['sha256'] ?? ''}').join(';');
  }

  /// Check if update is available without downloading all packs
  Future<bool> isUpdateAvailable({bool checkRawGitHub = false}) async {
    // If remote sync is disabled, always return false to ensure 100% offline vault usage
    if (!enableRemoteSync) return false;
    try {
      final resolved = await _resolveManifest(forceBypassCache: checkRawGitHub);
      if (resolved == null) return false;

      final manifest = resolved['manifest'] as Map<String, dynamic>;
      final remoteVersion = (manifest['bank_version'] as num?)?.toInt() ?? 0;
      final remoteTotal = (manifest['total'] as num?)?.toInt() ?? 0;
      final remotePacks = manifest['packs'] as List<dynamic>? ?? [];
      final remoteSig = _computePacksSignature(remotePacks);

      final localVersionStr = await db.getMeta('bank_version');
      final localVersionDigits = localVersionStr?.replaceAll(RegExp(r'\D'), '');
      final localVersion = int.tryParse(localVersionDigits ?? '0') ?? 0;
      final localQCount = await db.getQuestionCount();
      final localSig = await db.getMeta('packs_signature');

      // Anti-downgrade safeguard: Never downgrade local 9,720 database if remote has fewer questions
      if (remoteTotal < 9720 && localQCount >= 9720) return false;
      if (remoteVersion < localVersion && localVersion > 0) return false;

      // Trigger update if higher version, different count, or any pack content hash changed on GitHub
      if (remoteVersion > localVersion) return true;
      if (remoteTotal > 0 && remoteTotal != localQCount) return true;
      if (localSig != null && localSig != remoteSig) return true;
      if (localSig == null && localQCount < remoteTotal) return true;

      return false;
    } catch (_) {}
    return false;
  }

  /// Perform full atomic sync from CDN / GitHub to local SQLite.
  /// Guarantees:
  /// 1. Zero corruption: All packs are downloaded into memory before writing to SQLite.
  /// 2. If network cuts off mid-download, the existing database is left 100% untouched.
  /// 3. Any modified question, translation, or deleted question in Git is accurately reflected.
  /// 4. User's test history and mistake tracking are completely preserved.
  Future<SyncResult> syncQuestionBank({
    SyncProgressCallback? onProgress,
    bool force = false,
    bool bypassCache = false,
  }) async {
    if (!enableRemoteSync) {
      final int count = await db.getQuestionCount();
      onProgress?.call(1.0, 'ऑफलाइन डेटाबेस सक्रिय है ($count प्रश्न)');
      return SyncResult(
        success: true,
        previousCount: count,
        totalCount: count,
        message: 'ऑफलाइन डेटाबेस सक्रिय है ($count प्रश्न) / 100% Offline Active',
      );
    }
    try {
      final int previousCount = await db.getQuestionCount();
      final localVersionStr = await db.getMeta('bank_version');
      final localVersionDigits = (localVersionStr ?? '').replaceAll(RegExp(r'\D'), '');
      final localVersion = int.tryParse(localVersionDigits) ?? 0;

      onProgress?.call(0.05, 'बैंक घोषणा पत्र (manifest.json) जाँचा जा रहा है...');

      final resolved = await _resolveManifest(forceBypassCache: force || bypassCache);
      if (resolved == null) {
        onProgress?.call(0.0, 'डाउनलोड विफल: GitHub/CDN सर्वर से संपर्क नहीं हो सका');
        return SyncResult(
          success: false,
          previousCount: previousCount,
          totalCount: previousCount,
          message: 'GitHub/CDN सर्वर से संपर्क नहीं हो सका। कृपया इंटरनेट जांचें।',
        );
      }

      final String activeBaseUrl = resolved['baseUrl'] as String;
      final Map<String, dynamic> manifest = resolved['manifest'] as Map<String, dynamic>;

      final int bankVersion = (manifest['bank_version'] as num?)?.toInt() ?? 0;
      final int totalQuestions = (manifest['total'] as num?)?.toInt() ?? 0;
      final List<String> topics = List<String>.from(manifest['topics'] ?? []);
      final List<dynamic> packs = manifest['packs'] ?? [];
      final String remoteSig = _computePacksSignature(packs);
      final String? localSig = await db.getMeta('packs_signature');

      // Never let an older remote CDN overwrite a newer bundled/local vault.
      // (Without this guard, a v16 manifest silently reverted every local
      // database repair on the next online launch.)
      if (!force && !bypassCache && bankVersion > 0 && localVersion > 0 && bankVersion < localVersion) {
        onProgress?.call(1.0, 'स्थानीय प्रश्न बैंक नवीनतम है (डाउनग्रेड रोका गया)');
        return SyncResult(
          success: true,
          isUpToDate: true,
          previousCount: previousCount,
          newQuestionsAdded: 0,
          totalCount: previousCount,
          message: 'आपका स्थानीय प्रश्न बैंक सर्वर से नवीनतम है।',
        );
      }

      // Check if already up to date without re-downloading 40 packs (saving battery & bandwidth)
      final bool signatureMatches = localSig != null && localSig == remoteSig;
      if (!force && !bypassCache && previousCount > 0 && bankVersion <= localVersion && totalQuestions == previousCount && signatureMatches) {
        onProgress?.call(1.0, 'प्रश्न बैंक पहले से ही पूरी तरह अद्यतन (Up-to-Date) है!');
        return SyncResult(
          success: true,
          isUpToDate: true,
          previousCount: previousCount,
          newQuestionsAdded: 0,
          totalCount: previousCount,
          message: 'आपका प्रश्न बैंक पहले से ही नवीनतम है।',
        );
      }

      onProgress?.call(0.10, '$totalQuestions प्रश्नों के ${packs.length} पैक डाउनलोड किए जा रहे हैं...');

      final List<Passage> allPassages = [];
      final List<Question> allQuestions = [];

      int processedPacks = 0;
      for (final packInfo in packs) {
        final String packFile = packInfo['file'] as String;
        final cacheBuster = (force || bypassCache) ? '?_ts=${DateTime.now().millisecondsSinceEpoch}' : '';
        final packUrl = '$activeBaseUrl/$packFile$cacheBuster';

        http.Response? packRes;
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            packRes = await http.get(
              Uri.parse(packUrl),
              headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
            ).timeout(const Duration(seconds: 15));
            if (packRes.statusCode == 200) break;
          } catch (_) {
            if (attempt == 1) rethrow;
          }
        }

        if (packRes == null || packRes.statusCode != 200) {
          onProgress?.call(0.0, 'डाउनलोड विफल: पैक $packFile लोड नहीं हो सका। पुराना बैंक सुरक्षित है।');
          return SyncResult(
            success: false,
            previousCount: previousCount,
            totalCount: previousCount,
            message: 'पैक $packFile लोड नहीं हो सका। पुराना बैंक सुरक्षित है।',
          );
        }

        final packData = jsonDecode(utf8.decode(packRes.bodyBytes));

        // 1. Passages in pack
        if (packData['p'] != null && packData['p'] is List) {
          for (final p in packData['p']) {
            allPassages.add(Passage.fromJson(p));
          }
        }

        // 2. Questions in pack
        if (packData['q'] != null && packData['q'] is List) {
          for (final q in packData['q']) {
            final tIndex = (q['t'] as num?)?.toInt() ?? 0;
            final tName = (tIndex >= 0 && tIndex < topics.length) ? topics[tIndex] : null;
            allQuestions.add(Question.fromPackJson(q, topic: tName));
          }
        }

        processedPacks++;
        final progress = 0.10 + (0.75 * (processedPacks / packs.length));
        onProgress?.call(progress, 'पैक $processedPacks/${packs.length} प्राप्त हुआ...');
      }

      // Step 2.5: Download papers.json if available to sync new mock papers & appearances
      List<Map<String, dynamic>>? downloadedForms;
      List<dynamic>? downloadedAppearances;
      try {
        final papersInfo = manifest['papers_file'];
        final papersPath = (papersInfo is Map && papersInfo['file'] != null) ? papersInfo['file'] as String : 'papers.json';
        final papersUrl = '$activeBaseUrl/$papersPath${(force || bypassCache) ? '?_ts=${DateTime.now().millisecondsSinceEpoch}' : ''}';
        final papersRes = await http.get(
          Uri.parse(papersUrl),
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 15));

        if (papersRes.statusCode == 200) {
          final papersData = jsonDecode(utf8.decode(papersRes.bodyBytes));
          if (papersData['forms'] is List) {
            downloadedForms = List<Map<String, dynamic>>.from(papersData['forms']);
          }
          if (papersData['appearances'] is List) {
            downloadedAppearances = List<dynamic>.from(papersData['appearances']);
          }
        }
      } catch (_) {}

      // Step 3: All packs and papers successfully downloaded in memory!
      // Now perform safe atomic replacement in SQLite (zero data corruption guarantee)
      onProgress?.call(0.90, 'डेटाबेस को सुरक्षित रूप से अद्यतन (Atomic Sync) किया जा रहा है...');
      await db.atomicUpdateBank(
        questions: allQuestions,
        passages: allPassages,
        bankVersion: bankVersion,
        topics: topics,
        packsSignature: remoteSig,
        paperForms: downloadedForms,
        appearances: downloadedAppearances,
      );

      // Trigger instant UI refresh across the app
      onDatabaseUpdated.value = DateTime.now();

      // Automatically sync any pending offline student question reports to GitHub
      unawaited(GitHubReportService.instance.syncPendingReports());

      final finalCount = allQuestions.length;
      final diff = finalCount - previousCount;
      final added = diff > 0 ? diff : 0;

      onProgress?.call(1.0, added > 0 ? 'शानदार! $added नए प्रश्न जुड़े! कुल प्रश्न: $finalCount' : 'प्रश्न बैंक अद्यतन हुआ! कुल: $finalCount');
      return SyncResult(
        success: true,
        isUpToDate: added == 0,
        previousCount: previousCount,
        newQuestionsAdded: added,
        totalCount: finalCount,
        message: added > 0
            ? 'शानदार! $added नए प्रश्न सफलतापूर्वक जुड़ गए हैं!'
            : 'प्रश्न बैंक पूरी तरह अद्यतन व सुरक्षित है!',
      );
    } catch (e) {
      onProgress?.call(0.0, 'सिंक त्रुटि: $e');
      return SyncResult(
        success: false,
        message: 'सिंक के दौरान त्रुटि: $e',
      );
    }
  }

  /// Clean & Re-sync: Force fresh download directly from Git, wiping old questions
  /// and replacing them with pure updated questions from repository, keeping test history 100% safe.
  Future<SyncResult> cleanResyncQuestionBank({SyncProgressCallback? onProgress}) async {
    if (!enableRemoteSync) {
      await db.ensureBundledAssetLoaded();
      final int count = await db.getQuestionCount();
      onProgress?.call(1.0, 'ऑफलाइन डेटाबेस सफलतापूर्वक लोड हुआ ($count प्रश्न)');
      return SyncResult(
        success: true,
        previousCount: count,
        totalCount: count,
        message: 'ऑफलाइन मास्टर डेटाबेस सक्रिय है ($count प्रश्न)',
      );
    }
    return await syncQuestionBank(
      onProgress: onProgress,
      force: true,
      bypassCache: true,
    );
  }
}
