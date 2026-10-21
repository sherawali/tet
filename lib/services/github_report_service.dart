import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';

/// Service to securely sync student error reports directly to GitHub Issues on `sherawali/tet`
class GitHubReportService {
  static final GitHubReportService instance = GitHubReportService._internal();
  GitHubReportService._internal();

  static const String repoOwner = 'sherawali/tet';
  static const String _prefTokenKey = 'custom_gh_report_token_v2';
  static const String _xorKeyPhrase = 'TET_MASTER_VAULT_2026_SECRET';

  /// Pre-configured encrypted token string (Base64 XOR).
  /// To generate: run `python bin/encrypt_api_key.py <your_token>`
  /// or call `GitHubReportService.encryptToken('<your_token>')`.
  static const String _bundledEncryptedToken =
      'MywgNzgjDCQkJgBncBcfFRZmY3sGHAFzBTgxHCIwOBsnHhYXDAQyNzY7NhE1S1UGeRc6Mg0/cQAdfDgyCAk6Iyw4NgIpNyUbPFFcAEYdBh11CxUAYycXEHkGYwAy';

  // Backward compatibility placeholder
  static final List<int> _defaultEncryptedBytes = [];

  /// Simple & Secure XOR + Base64 encryption
  static String encryptToken(String token) {
    if (token.trim().isEmpty) return '';
    final rawBytes = utf8.encode(token.trim());
    final keyBytes = utf8.encode(_xorKeyPhrase);
    final enc = List<int>.generate(
      rawBytes.length,
      (i) => rawBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64.encode(enc);
  }

  /// Decrypts obfuscated Base64 token into plaintext in memory
  static String decryptToken(String encryptedBase64) {
    if (encryptedBase64.trim().isEmpty) return '';
    try {
      final enc = base64.decode(encryptedBase64.trim());
      final keyBytes = utf8.encode(_xorKeyPhrase);
      final dec = List<int>.generate(
        enc.length,
        (i) => enc[i] ^ keyBytes[i % keyBytes.length],
      );
      return utf8.decode(dec);
    } catch (_) {
      return '';
    }
  }

  /// Saves an encrypted token to local device storage
  Future<void> setCustomEncryptedToken(String rawToken) async {
    final enc = encryptToken(rawToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, enc);
  }

  /// Clears custom saved token
  Future<void> clearCustomToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenKey);
  }

  /// Verifies token validity by querying repository metadata
  Future<bool> verifyToken(String token) async {
    if (token.trim().isEmpty) return false;
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer ${token.trim()}',
          'User-Agent': 'TET-App-Report-Engine',
        },
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves the active GitHub token in memory
  Future<String> getActiveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefTokenKey);
      if (savedStr != null && savedStr.trim().isNotEmpty) {
        final token = decryptToken(savedStr);
        if (token.isNotEmpty) return token;
      }
    } catch (_) {}

    if (_bundledEncryptedToken.trim().isNotEmpty) {
      final token = decryptToken(_bundledEncryptedToken);
      if (token.isNotEmpty) return token;
    }

    if (_defaultEncryptedBytes.isNotEmpty) {
      final dec = List<int>.generate(
        _defaultEncryptedBytes.length,
        (i) => _defaultEncryptedBytes[i] ^ (0x5A + (i % 7)),
      );
      return utf8.decode(dec);
    }
    return '';
  }

  /// Checks if a valid token is configured
  Future<bool> hasConfiguredToken() async {
    final token = await getActiveToken();
    return token.trim().isNotEmpty;
  }

  /// Posts a single report to GitHub Issues
  Future<bool> sendReportToGitHub({
    required int reportId,
    required String questionId,
    required int questionNumber,
    required String paperTitle,
    required String reason,
    String? comment,
    String? suggestedOption,
    String? questionStem,
    int? userAnswer,
    int? correctAnswer,
  }) async {
    final token = await getActiveToken();
    if (token.isEmpty) {
      debugPrint('GitHubReportService: No active token configured. Report saved locally in SQLite.');
      return false;
    }

    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/issues');
      final userOpt = userAnswer != null && userAnswer >= 0 && userAnswer <= 3
          ? String.fromCharCode(65 + userAnswer)
          : 'छोड़ा गया (Not Attempted)';
      final correctOpt = correctAnswer != null && correctAnswer >= 0 && correctAnswer <= 3
          ? String.fromCharCode(65 + correctAnswer)
          : 'N/A';

      final title = '[Report #$reportId] Q$questionNumber ($paperTitle) - $reason';

      final bodyBuffer = StringBuffer();
      bodyBuffer.writeln('### 🚩 Student Question Error Report #$reportId\n');
      bodyBuffer.writeln('| विवरण (Field) | जानकारी (Details) |');
      bodyBuffer.writeln('|---|---|');
      bodyBuffer.writeln('| **परीक्षा / पेपर** | $paperTitle |');
      bodyBuffer.writeln('| **प्रश्न संख्या** | Q$questionNumber (ID: `$questionId`) |');
      bodyBuffer.writeln('| **त्रुटि का प्रकार** | $reason |');
      bodyBuffer.writeln('| **ऐप में सही उत्तर** | Option ($correctOpt) |');
      bodyBuffer.writeln('| **छात्र द्वारा चयन** | Option ($userOpt) |');
      if (suggestedOption != null && suggestedOption.trim().isNotEmpty) {
        bodyBuffer.writeln('| **छात्र द्वारा सुझाया गया विकल्प** | Option ($suggestedOption) |');
      }
      bodyBuffer.writeln('| **दिनांक** | ${DateTime.now().toLocal().toString().split('.')[0]} |');
      bodyBuffer.writeln('\n---\n');

      if (questionStem != null && questionStem.trim().isNotEmpty) {
        bodyBuffer.writeln('#### 📝 प्रश्न का अंश (Question Stem):');
        bodyBuffer.writeln('> ${questionStem.trim().replaceAll('\n', '\n> ')}\n');
      }

      bodyBuffer.writeln('#### 💬 छात्र की टिप्पणी (Student Comment):');
      if (comment != null && comment.trim().isNotEmpty) {
        bodyBuffer.writeln(comment.trim());
      } else {
        bodyBuffer.writeln('_कोई अतिरिक्त टिप्पणी नहीं दी गई।_');
      }

      bodyBuffer.writeln('\n---\n*Reported via TET App Master Offline System*');

      final payload = jsonEncode({
        'title': title,
        'body': bodyBuffer.toString(),
        'labels': ['question-report', 'student-flag'],
      });

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $token',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
          'User-Agent': 'TET-App-Report-Engine',
        },
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        debugPrint('GitHubReportService: Report #$reportId posted to GitHub Issue successfully!');
        await DbHelper.instance.markReportSynced(reportId);
        return true;
      } else {
        debugPrint('GitHubReportService: Failed to post issue (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('GitHubReportService error: $e');
      return false;
    }
  }

  /// Syncs all pending offline reports stored in SQLite to GitHub.
  ///
  /// The whole loop has a time budget: a device without a connection must
  /// not spend minutes on a socket that never answers.
  Future<int> syncPendingReports() async {
    final pending = await DbHelper.instance.getPendingReports();
    if (pending.isEmpty) return 0;

    final budgetEnd = DateTime.now().add(const Duration(seconds: 45));
    int syncedCount = 0;
    for (final r in pending) {
      if (DateTime.now().isAfter(budgetEnd)) break;
      final id = r['id'] as int? ?? 0;
      final qId = r['question_id']?.toString() ?? '';
      final qNum = r['question_number'] as int? ?? 0;
      final paper = r['paper_form_id']?.toString() ?? 'TET Paper';
      final reason = r['reason']?.toString() ?? 'त्रुटि';
      final comment = r['comment']?.toString();
      final opt = r['suggested_option']?.toString();
      final stem = r['question_stem']?.toString();
      final userAns = r['user_answer'] as int?;
      final correctAns = r['correct_answer'] as int?;

      final success = await sendReportToGitHub(
        reportId: id,
        questionId: qId,
        questionNumber: qNum,
        paperTitle: paper,
        reason: reason,
        comment: comment,
        suggestedOption: opt,
        questionStem: stem,
        userAnswer: userAns,
        correctAnswer: correctAns,
      );

      if (success) {
        syncedCount++;
      }
    }

    return syncedCount;
  }
}
