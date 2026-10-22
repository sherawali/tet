import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_message.dart';
import '../database/db_helper.dart';
import 'bank_facts.dart';

/// The kind of place a flash message can send the candidate to.
enum FlashTargetType {
  /// The message carries no destination at all.
  none,

  /// A screen of the app (a route).
  route,

  /// A paper form of the vault - the booklet of that paper is opened.
  paper,

  /// A link that is opened in the browser.
  external,
}

/// The in-app screens a flash message can name.
class FlashRoutes {
  const FlashRoutes._();

  /// The mock series / model test papers.
  static const String mockSeries = 'mock_series';

  /// The previous year (PYQ) vault.
  static const String pyqVault = 'pyq_vault';
}

/// The resolved destination of a flash message.
///
/// A message may name its destination in three different ways, and every one
/// of them has to work:
///
///  * `action_url` = `https://...`          -> the browser
///  * `action_url` = `paper:<form id>`      -> the booklet of that paper
///  * `action_url` = `route:mock_series`    -> a screen of the app
///
/// When the message does not carry an `action_url` at all, the destination is
/// derived from the wording of the message (its id and its button label), so
/// the live messages of the CDN always open something sensible as well.
class FlashTarget {
  final FlashTargetType type;

  /// The key of the screen, see [FlashRoutes].
  final String? route;

  /// The id of the paper form of the vault.
  final String? paperId;

  /// The external link.
  final String? url;

  const FlashTarget._(this.type, {this.route, this.paperId, this.url});

  const FlashTarget.none() : this._(FlashTargetType.none);

  const FlashTarget.route(String route)
      : this._(FlashTargetType.route, route: route);

  const FlashTarget.paper(String paperId)
      : this._(FlashTargetType.paper, paperId: paperId);

  const FlashTarget.external(String url)
      : this._(FlashTargetType.external, url: url);

  bool get hasTarget => type != FlashTargetType.none;

  @override
  String toString() => 'FlashTarget(${type.name}, '
      'route: $route, paper: $paperId, url: $url)';
}

class FlashMessageService {
  static final FlashMessageService _instance = FlashMessageService._internal();
  factory FlashMessageService() => _instance;
  FlashMessageService._internal();

  static const String cdnUrl =
      'https://cdn.jsdelivr.net/gh/sherawali/tet@main/cdn/flash_messages.json';
  static const String rawUrl =
      'https://raw.githubusercontent.com/sherawali/tet/main/cdn/flash_messages.json';

  /// The dismissal is stored per message id, so a *new* message is shown again
  /// while the message the candidate closed stays closed forever.
  static const String _dismissPrefKey = 'flash_message_dismissals';
  static const String _dismissMetaKey = 'flash_message_dismissals';

  /// The key that older builds used - it is still read and still written, so a
  /// dismissal of an older version of the app is not lost.
  static const String _legacyDismissKey = 'dismissed_flash_ids';

  final DbHelper _db = DbHelper.instance;

  /// Words that point at the mock series / model test papers.
  static const List<String> _mockWords = [
    'mock',
    'मॉक',
    'मॉडल',
    'model test',
    'series',
    'सेट',
  ];

  /// Words that point at the previous year (PYQ) vault.
  static const List<String> _vaultWords = [
    'pyq',
    'विगत वर्ष',
    'previous year',
    'vault',
  ];

  /// Words that only describe the *action* of a button and therefore never
  /// name a paper.
  static const List<String> _actionWords = [
    'view',
    'see',
    'open',
    'start',
    'begin',
    'solve',
    'practice',
    'download',
    'update',
    'now',
    'go',
    'try',
    'attempt',
    'omr',
    'sheet',
    'answer',
    'देखें',
    'देखो',
    'खोलें',
    'खोलो',
    'शुरू',
    'करें',
    'हल',
    'अभ्यास',
    'अब',
    'जाएं',
    'उत्तर',
  ];

  /// Fetch active flash messages from GitHub CDN or local fallback
  Future<List<FlashMessage>> getActiveMessages() async {
    List<FlashMessage> allMessages = [];

    // The counts in the built-in broadcasts come from the bank itself.
    await BankFacts.refresh(_db);

    // 1. Try raw GitHub / CDN URL with cache busting
    try {
      final rawRes = await http.get(
        Uri.parse('$rawUrl?_ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 4));

      if (rawRes.statusCode == 200) {
        allMessages = _parseJson(utf8.decode(rawRes.bodyBytes));
        await _db.setMeta('cached_flash_json', utf8.decode(rawRes.bodyBytes));
      } else {
        final res = await http.get(Uri.parse(cdnUrl)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          allMessages = _parseJson(utf8.decode(res.bodyBytes));
          await _db.setMeta('cached_flash_json', utf8.decode(res.bodyBytes));
        }
      }
    } catch (_) {
      // 2. Read from cached DB meta on offline/error
      final cachedJson = await _db.getMeta('cached_flash_json');
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        allMessages = _parseJson(cachedJson);
      }
    }

    // 3. Define master multi-slide broadcasts with 100% pure Hindi and pure English
    final defaultBroadcasts = [
      FlashMessage(
        id: 'live_flash_2026_master',
        title: '🔥 UTET एवं CTET 2026: ${BankFacts.format(BankFacts.questionCount)} प्रश्नों का सम्पूर्ण बैंक उपलब्ध!',
        message: 'सभी ${BankFacts.paperCount} प्रामाणिक बोर्ड प्रश्न-पत्र एवं मॉडल सेट्स सम्पूर्ण हल सहित उपलब्ध हैं। OMR एवं CBT मोड में अभ्यास करें।',
        titleEn: '🔥 UTET & CTET 2026: ${BankFacts.format(BankFacts.questionCount)} Question Bank Live!',
        messageEn: 'All ${BankFacts.paperCount} authentic board solved papers and model test sets with complete solutions. Practice in OMR & CBT mode.',
        type: 'notice',
        actionLabel: 'मॉडल प्रश्न-पत्र देखें',
        actionLabelEn: 'View Mock Series',
        actionUrl: 'route:${FlashRoutes.mockSeries}',
        isDismissible: true,
      ),
      const FlashMessage(
        id: 'remote_cloud_sync_notice',
        title: '⚡ लाइव क्लाउड सिंक सक्रिय',
        message: 'नवीनतम प्रश्न-पत्र, प्रश्न सुधार एवं नए अपडेट्स सीधे आपके फोन में स्वतः सुरक्षित होते हैं।',
        titleEn: '⚡ Live Cloud Sync Active',
        messageEn: 'Latest question papers, verified corrections, and fresh updates sync directly to your device.',
        type: 'update',
        actionLabel: 'अभ्यास प्रश्न-पत्र देखें',
        actionLabelEn: 'View Practice Tests',
        actionUrl: 'route:${FlashRoutes.mockSeries}',
        isDismissible: true,
      ),
      const FlashMessage(
        id: 'offline_cbt_omr_mode',
        title: '📝 वास्तविक परीक्षा अनुरूप अभ्यास',
        message: 'समय सीमा, नेगेटिव मार्किंग एवं विस्तृत व्याख्या सहित अपनी परीक्षा तैयारी का मूल्यांकन करें।',
        titleEn: '📝 Realistic OMR & CBT Exam Simulation',
        messageEn: 'Assess your real exam readiness with countdown timer, negative marking, and detailed solutions.',
        type: 'success',
        actionLabel: 'अभ्यास शुरू करें',
        actionLabelEn: 'Start Practice',
        actionUrl: 'route:${FlashRoutes.mockSeries}',
        isDismissible: true,
      ),
    ];

    // Ensure all fresh multi-slide broadcasts are present alongside remote messages
    for (final def in defaultBroadcasts) {
      if (!allMessages.any((m) => m.id == def.id)) {
        allMessages.add(def);
      }
    }

    // 4. Filter out the messages the candidate closed before.  The dismissal
    //    is stored per message id, so a brand new message still shows up.
    final dismissedSet = await _getDismissedIds();
    final visible = allMessages
        .where((m) => !m.isDismissible || !dismissedSet.contains(m.id))
        .toList();

    return visible;
  }

  List<FlashMessage> _parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['messages'] is List) {
        list = decoded['messages'] as List<dynamic>;
      } else {
        return [];
      }
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          // A message that is switched off in the CDN must not be shown.
          .where((e) => e['active'] is! bool || e['active'] == true)
          .map(FlashMessage.fromJson)
          .toList();
    } catch (_) {}
    return [];
  }

  /// Mark single message as dismissed by user
  Future<void> dismissMessage(String id) async {
    final dismissed = await _getDismissedIds();
    dismissed.add(id);
    await _saveDismissedIds(dismissed);
  }

  /// Mark multiple messages as dismissed at once (e.g. when user closes banner)
  Future<void> dismissAll(List<String> ids) async {
    final dismissed = await _getDismissedIds();
    dismissed.addAll(ids);
    await _saveDismissedIds(dismissed);
  }

  /// The ids of the messages the candidate closed.
  Future<Set<String>> _getDismissedIds() async {
    final result = <String>{};

    Future<void> collect(String? raw) async {
      if (raw == null || raw.trim().isEmpty) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          result.addAll(decoded.keys.map((k) => k.toString()));
        } else if (decoded is List) {
          result.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {
        // A plain (not json) list is still understood.
        result.addAll(
          raw
              .split(RegExp(r'[,\s]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await collect(prefs.getString(_dismissPrefKey));
      final legacy = prefs.getStringList(_legacyDismissKey);
      if (legacy != null) result.addAll(legacy);
    } catch (_) {}

    try {
      await collect(await _db.getMeta(_dismissMetaKey));
      await collect(await _db.getMeta(_legacyDismissKey));
    } catch (_) {}

    return result;
  }

  Future<void> _saveDismissedIds(Set<String> dismissed) async {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = jsonEncode(<String, String>{
      for (final id in dismissed) id: stamp,
    });
    final legacyList = dismissed.toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissPrefKey, payload);
      // The legacy list is kept in sync, so an older build of the app also
      // keeps the closed message closed.
      await prefs.setStringList(_legacyDismissKey, legacyList);
    } catch (_) {}

    try {
      await _db.setMeta(_dismissMetaKey, payload);
      await _db.setMeta(_legacyDismissKey, jsonEncode(legacyList));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Where does the message send the candidate?
  // ---------------------------------------------------------------------

  /// Resolves the destination of a message without touching the database.
  ///
  /// The result is only a *guess* for the route based targets - the paper
  /// targets are verified against the vault by [resolveTarget].
  FlashTarget resolveTarget(FlashMessage message) {
    final raw = (message.actionUrl ?? '').trim();
    if (raw.isNotEmpty) {
      final lower = raw.toLowerCase();

      // An external link is opened in the browser.
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        return FlashTarget.external(raw);
      }

      // A paper of the vault.
      for (final prefix in const ['paper:', 'form:', 'paperform:', 'paper_form:']) {
        if (lower.startsWith(prefix)) {
          final id = raw.substring(prefix.length).trim();
          if (id.isNotEmpty) return FlashTarget.paper(id);
        }
      }

      // A screen of the app.
      for (final prefix in const ['route:', 'app://', 'tet://', 'screen:']) {
        if (lower.startsWith(prefix)) {
          final key = raw.substring(prefix.length).trim().toLowerCase()
              .replaceAll('-', '_')
              .replaceAll(' ', '_');
          if (key.isNotEmpty) return FlashTarget.route(key);
        }
      }

      // Anything else that looks like a link is a link.
      if (lower.contains('://')) {
        return FlashTarget.external(raw);
      }
    }

    return _inferTarget(message);
  }

  /// Resolves the destination of a message and checks it against the vault.
  ///
  /// A message that names a paper which really exists opens that paper, even
  /// when the message does not carry an `action_url`.
  Future<FlashTarget> resolveTargetOf(FlashMessage message) async {
    final target = resolveTarget(message);

    if (target.type == FlashTargetType.paper) {
      final form = await findPaperForm(target.paperId!);
      if (form != null) {
        return FlashTarget.paper((form['id'] ?? '').toString());
      }
      // The named paper does not exist - fall back to the screen of the app.
      return _inferTarget(message);
    }

    if (target.type == FlashTargetType.none) return target;

    // The button of the message may name a paper of the vault.
    final named = await _paperNamedBy(message);
    if (named != null) return FlashTarget.paper(named);

    return target;
  }

  /// The screen the message points at, derived from its wording.
  FlashTarget _inferTarget(FlashMessage message) {
    // The label of the button is the strongest hint, because that is the
    // text the candidate reads before tapping.
    final labels = <String>[
      if (message.actionLabelEn != null) message.actionLabelEn!,
      if (message.actionLabel != null) message.actionLabel!,
    ];
    for (final label in labels) {
      final target = _targetFromWords(label);
      if (target != null) return target;
    }

    // Then the id of the message, then its title.
    for (final field in <String>[
      message.id,
      message.titleEn ?? '',
      message.title,
    ]) {
      final target = _targetFromWords(field);
      if (target != null) return target;
    }

    // The mock series is the place where every practice paper of the app
    // lives, so it is the safe default.
    return const FlashTarget.route(FlashRoutes.mockSeries);
  }

  FlashTarget? _targetFromWords(String text) {
    final lower = text.toLowerCase();
    if (lower.trim().isEmpty) return null;
    for (final word in _vaultWords) {
      if (lower.contains(word)) return const FlashTarget.route(FlashRoutes.pyqVault);
    }
    for (final word in _mockWords) {
      if (lower.contains(word)) return const FlashTarget.route(FlashRoutes.mockSeries);
    }
    return null;
  }

  /// The paper of the vault that the button of the message names.
  Future<String?> _paperNamedBy(FlashMessage message) async {
    final labels = <String>[
      if (message.actionLabel != null) message.actionLabel!,
      if (message.actionLabelEn != null) message.actionLabelEn!,
    ];

    for (final label in labels) {
      final hint = _paperHint(label);
      if (hint == null) continue;
      final form = await findPaperForm(hint);
      if (form != null) return (form['id'] ?? '').toString();
    }
    return null;
  }

  /// Strips the action words from a button label.  What is left has to be the
  /// name of a paper, e.g. "UTET 2023 पेपर-1".
  String? _paperHint(String label) {
    var text = label.toLowerCase();
    // Emoji never belong to a paper name.
    text = String.fromCharCodes(
      text.runes.where(
        (r) =>
            !(r >= 0x1F300 && r <= 0x1FAFF) &&
            !(r >= 0x2600 && r <= 0x27BF) &&
            r != 0xFE0F,
      ),
    );
    final kept = text
        .split(RegExp(r'[\s\-–_/:,.;!?()\[\]{}"“”‘’|]+'))
        .where((w) => w.isNotEmpty && !_actionWords.contains(w))
        .toList();
    if (kept.length < 2) return null;
    // A hint without a digit is never the name of a paper.
    if (!kept.any((w) => RegExp(r'\d').hasMatch(w))) return null;
    return kept.join(' ');
  }

  /// Lower cases a text and removes every punctuation, so that two spellings
  /// of the same name can be compared ("पेपर-1" and "पेपर 1").
  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[-_/\\.,:;!?()\[\]{}"“”‘’|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Looks for a paper form of the vault.
  ///
  /// The [hint] may be the id of the form (`utet-p1-set-b`), its set code
  /// (`MOCK 01`) or the name of the paper (`UTET 2023 पेपर-1`).
  Future<Map<String, dynamic>?> findPaperForm(String hint) async {
    final raw = hint.trim();
    if (raw.isEmpty) return null;
    final needle = raw.toLowerCase();
    try {
      await _db.ensureBundledAssetLoaded();
      final db = await _db.database;

      final byId = await db.query(
        'paper_forms',
        where: 'LOWER(id) = ?',
        whereArgs: [needle],
        limit: 1,
      );
      if (byId.isNotEmpty) return byId.first;

      final bySet = await db.query(
        'paper_forms',
        where: 'LOWER(set_code) = ?',
        whereArgs: [needle],
        limit: 1,
      );
      if (bySet.isNotEmpty) return bySet.first;

      // The name of the paper: every word of the hint has to be part of the
      // title of the form.
      final words = _normalize(raw)
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.length < 2) return null;

      final rows = await db.query('paper_forms');
      for (final row in rows) {
        final title = _normalize((row['title'] ?? '').toString());
        if (title.isEmpty) continue;
        if (words.every(title.contains)) return row;
      }
    } catch (_) {}
    return null;
  }
}
